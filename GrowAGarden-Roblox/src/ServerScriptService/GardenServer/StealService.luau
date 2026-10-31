-- StealService: roubo a noite (novidade do GAG2) e todas as defesas.
--
-- Como funciona:
--   * So a noite, e so em jardins cujo dono NAO esta dentro do proprio jardim.
--   * Gnomo ativo tambem tranca o jardim.
--   * O ladrao segura E no fruto, carrega o fruto na cabeca (mais devagar, sem teleporte)
--     e precisa leva-lo ate o PROPRIO jardim para ficar com ele.
--   * Se morrer, for atingido por certas defesas, levar uma "pazada" do dono,
--     sair do jogo ou demorar demais, o fruto volta para o dono.
--   * Plantas de defesa atacam intrusos a noite.
--   * Cogumelos: velocidade, pulo e invisibilidade (defesas nao veem, exceto perto de lanternas).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local DataService = require(script.Parent.DataService)
local DayNightService = require(script.Parent.DayNightService)
local GardenService = require(script.Parent.GardenService)
local QuestService = require(script.Parent.QuestService)
local Sync = require(script.Parent.Sync)
local Visuals = require(script.Parent.Visuals)
local WeatherService = require(script.Parent.WeatherService)

local StealService = {}

local S = Config.Stealing

type Carrier = {
	fruit: any,
	victim: Player,
	victimName: string,
	started: number,
	visual: BasePart?,
}

local carriers: { [Player]: Carrier } = {}
local lastSteal: { [Player]: number } = {}
local effects: { [Player]: { [string]: number } } = {}
local invisibleParts: { [Player]: { [Instance]: number } } = {}
local cooldowns: { [string]: number } = {}
local lockedState: { [any]: boolean } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid
end

local function effectActive(player: Player, name: string): boolean
	local list = effects[player]
	return list ~= nil and list[name] ~= nil and list[name] > os.clock()
end

local function setEffect(player: Player, name: string, duration: number)
	effects[player] = effects[player] or {}
	effects[player][name] = os.clock() + duration
end

local function ready(key: string, cooldown: number): boolean
	local now = os.clock()
	if cooldowns[key] and now < cooldowns[key] then
		return false
	end
	cooldowns[key] = now + cooldown
	return true
end

function StealService.isCarrying(player: Player): boolean
	return carriers[player] ~= nil
end

-- Jardim trancado: dono dentro do proprio jardim ou Gnomo ativo
function StealService.isLocked(garden): boolean
	if GardenService.hasActiveGnome(garden) then
		return true
	end
	local root = rootOf(garden.player)
	return root ~= nil and GardenService.isInside(garden, root.Position)
end

local function clearCarry(thief: Player)
	local carrier = carriers[thief]
	carriers[thief] = nil
	if carrier and carrier.visual then
		carrier.visual:Destroy()
	end
	thief:SetAttribute("Carrying", nil)
	thief:SetAttribute("CarryName", nil)
	thief:SetAttribute("CarryUntil", nil)
end

-- O fruto volta para o dono
local function returnLoot(thief: Player, reason: string)
	local carrier = carriers[thief]
	if not carrier then
		return
	end
	clearCarry(thief)
	local name = Formulas.fruitName(carrier.fruit.s, carrier.fruit.v)
	local victim = carrier.victim
	if victim.Parent and GardenService.getGarden(victim) then
		if GardenService.addFruit(victim, carrier.fruit) then
			Sync.notify(victim, string.format("🛡️ Seu(sua) %s foi recuperado(a)! (%s)", name, reason), "success")
		else
			Sync.notify(victim, string.format("Seu(sua) %s foi recuperado(a), mas sua mochila está cheia e ele se perdeu.", name), "error")
		end
	end
	if thief.Parent then
		Sync.notify(thief, string.format("Você perdeu o(a) %s roubado(a)! (%s)", name, reason), "error")
	end
end

local function secureLoot(thief: Player)
	local carrier = carriers[thief]
	if not carrier then
		return
	end
	if not GardenService.addFruit(thief, carrier.fruit) then
		returnLoot(thief, "mochila do ladrão cheia")
		return
	end
	clearCarry(thief)
	local name = Formulas.fruitName(carrier.fruit.s, carrier.fruit.v)
	local thiefData = DataService.get(thief)
	if thiefData then
		thiefData.stats.stolen += 1
	end
	QuestService.progress(thief, "steal", 1)
	local victimData = DataService.get(carrier.victim)
	if victimData then
		victimData.stats.stolenFrom += 1
	end
	Sync.notify(thief, string.format("🦹 Roubo garantido! Você ficou com %s.", name), "rare")
	if carrier.victim.Parent then
		Sync.notify(carrier.victim, string.format("😱 %s levou seu(sua) %s embora!", thief.DisplayName, name), "error")
	end
end

-- Tentativa de roubo (prompt "Colher" acionado por quem nao e o dono)
function StealService.trySteal(thief: Player, garden, view, slotIndex: number?)
	if not S.enabled then
		return
	end
	if not DayNightService.isNight() then
		Sync.notify(thief, "Esse jardim não é seu! Roubos só funcionam à noite.", "error")
		return
	end
	if not GardenService.getGarden(thief) then
		return
	end
	if carriers[thief] then
		Sync.notify(thief, "Você já está carregando um fruto. Leve-o ao seu jardim!", "error")
		return
	end
	if lastSteal[thief] and os.clock() - lastSteal[thief] < S.cooldown then
		return
	end
	if StealService.isLocked(garden) then
		Sync.notify(thief, "🔒 Este jardim está protegido (dono em casa ou Gnomo).", "error")
		return
	end
	local root = rootOf(thief)
	if not root then
		return
	end
	local fruitPosition = GardenService.fruitWorldPosition(view, slotIndex)
	if (root.Position - fruitPosition).Magnitude > S.maxDistance then
		return
	end
	local fruit = GardenService.takeFruit(garden, view, slotIndex)
	if not fruit then
		return
	end
	lastSteal[thief] = os.clock()
	local seed = Config.Seeds[fruit.s]
	carriers[thief] = {
		fruit = fruit,
		victim = garden.player,
		victimName = garden.player.DisplayName,
		started = os.clock(),
		visual = Visuals.carryVisual(root, seed, fruit.v),
	}
	local name = Formulas.fruitName(fruit.s, fruit.v)
	thief:SetAttribute("Carrying", true)
	thief:SetAttribute("CarryName", name)
	thief:SetAttribute("CarryUntil", os.time() + S.carryTimeout)
	Sync.notify(thief, string.format("🏃 Você pegou %s! Leve até o SEU jardim antes de ser pego!", name), "rare")
	Sync.notify(garden.player, string.format("⚠️ %s está roubando seu(sua) %s! Volte e acerte com a Pá!", thief.DisplayName, name), "error")
	local poison = seed.special and seed.special.poisonFruit
	if poison then
		local humanoid = humanoidOf(thief)
		if humanoid then
			humanoid:TakeDamage(poison.damage)
		end
		setEffect(thief, "slow", poison.slowTime)
		Sync.notify(thief, "☠️ A Maçã Envenenada te envenenou!", "error")
	end
end

-- Dono acerta o ladrao com a Pa
function StealService.bonk(owner: Player): boolean
	local root = rootOf(owner)
	if not root then
		return false
	end
	for thief, carrier in carriers do
		if carrier.victim == owner then
			local thiefRoot = rootOf(thief)
			if thiefRoot and (thiefRoot.Position - root.Position).Magnitude <= S.bonkDistance then
				setEffect(thief, "stun", S.stunTime)
				returnLoot(thief, "pazada do dono")
				return true
			end
		end
	end
	return false
end

-- Atirador de Morango: atordoa e faz soltar o fruto
function StealService.snipe(player: Player, gear, position: Vector3?)
	local root = rootOf(player)
	if not root or not position then
		return
	end
	if not ready("snipe:" .. player.UserId, gear.cooldown) then
		return
	end
	local myGarden = GardenService.getGarden(player)
	local best, bestDistance = nil, 7
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local otherRoot = rootOf(other)
			if otherRoot and (otherRoot.Position - root.Position).Magnitude <= gear.range then
				local distance = (otherRoot.Position - position).Magnitude
				local isThief = carriers[other] ~= nil and carriers[other].victim == player
				local isIntruder = myGarden ~= nil and DayNightService.isNight() and GardenService.isInside(myGarden, otherRoot.Position)
				if (isThief or isIntruder) and distance < bestDistance then
					best, bestDistance = other, distance
				end
			end
		end
	end
	Visuals.projectile(root.Position + Vector3.new(0, 1.5, 0), position, gear.color)
	if best then
		setEffect(best, "stun", S.stunTime)
		Sync.notify(best, "🍓 Você levou um morangaço e ficou atordoado!", "error")
		if carriers[best] then
			returnLoot(best, "Atirador de Morango")
		end
		Sync.notify(player, "🎯 Acertou " .. best.DisplayName .. "!", "success")
	end
end

-- Cogumelos (efeitos temporarios). Retorna true se o item foi usado.
function StealService.consume(player: Player, gear): boolean
	if not rootOf(player) then
		return false
	end
	if gear.effect == "speed" then
		setEffect(player, "speed", gear.duration)
		Sync.notify(player, string.format("🍄 Velocidade por %ds!", gear.duration), "success")
	elseif gear.effect == "jump" then
		setEffect(player, "jump", gear.duration)
		Sync.notify(player, string.format("🍄 Super pulo por %ds!", gear.duration), "success")
	elseif gear.effect == "invisible" then
		setEffect(player, "invisible", gear.duration)
		Sync.notify(player, string.format("👻 Invisível por %ds! Defesas não te veem (cuidado com lanternas).", gear.duration), "success")
	else
		return false
	end
	return true
end

local function setInvisible(player: Player, invisible: boolean)
	local character = player.Character
	if invisible then
		if invisibleParts[player] or not character then
			return
		end
		local saved = {}
		for _, descendant in character:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" and descendant.Name ~= "FrutoRoubado" then
				saved[descendant] = descendant.Transparency
				descendant.Transparency = 1
			elseif descendant:IsA("Decal") then
				saved[descendant] = descendant.Transparency
				descendant.Transparency = 1
			end
		end
		invisibleParts[player] = saved
		player:SetAttribute("Invisible", true)
	else
		local saved = invisibleParts[player]
		if not saved then
			return
		end
		invisibleParts[player] = nil
		for instance, transparency in saved do
			if instance.Parent then
				(instance :: any).Transparency = transparency
			end
		end
		player:SetAttribute("Invisible", nil)
	end
end

-- Velocidade, pulo e visibilidade de cada jogador
local function updateMovement(player: Player)
	local humanoid = humanoidOf(player)
	if not humanoid then
		return
	end
	local speed = Config.BaseWalkSpeed
	local jump = Config.BaseJumpHeight
	if effectActive(player, "speed") then
		speed += Config.Gear.SpeedMushroom.amount
	end
	if effectActive(player, "jump") then
		jump += Config.Gear.JumpMushroom.amount
	end
	if carriers[player] then
		speed = math.min(speed, S.carryWalkSpeed)
		local weather = WeatherService.getCurrentInfo()
		if weather and weather.thiefSpeedBonus then
			speed += weather.thiefSpeedBonus
		end
	end
	if effectActive(player, "slow") then
		speed = math.min(speed, 8)
	end
	if effectActive(player, "stun") then
		speed = 0
		jump = 0
	end
	speed = math.max(speed, 0)
	if math.abs(humanoid.WalkSpeed - speed) > 0.01 then
		humanoid.WalkSpeed = speed
	end
	-- alguns lugares usam JumpPower, outros JumpHeight
	if humanoid.UseJumpPower then
		local power = if jump <= 0 then 0 else 50 + (jump - Config.BaseJumpHeight) * 4.5
		if math.abs(humanoid.JumpPower - power) > 0.01 then
			humanoid.JumpPower = power
		end
	elseif math.abs(humanoid.JumpHeight - jump) > 0.01 then
		humanoid.JumpHeight = jump
	end
	setInvisible(player, effectActive(player, "invisible"))
end

local function isRevealed(garden, position: Vector3): boolean
	for _, lantern in GardenService.lanterns(garden) do
		if (lantern.position - position).Magnitude <= lantern.radius then
			return true
		end
	end
	return false
end

-- Expulsa o intruso para fora do portao
local function eject(intruder: Player, garden)
	local character = intruder.Character
	if character then
		character:PivotTo(GardenService.outsideCFrame(garden))
	end
end

local function hit(intruder: Player, garden, kind: string, amount: number?, sourceName: string, from: Vector3?)
	local root = rootOf(intruder)
	local humanoid = humanoidOf(intruder)
	if not root or not humanoid then
		return
	end
	if from then
		local color = if kind == "dragon" then Color3.fromRGB(255, 100, 20) else Color3.fromRGB(130, 230, 50)
		Visuals.projectile(from, root.Position, color)
	end
	if amount and amount > 0 then
		humanoid:TakeDamage(amount)
	end
	if kind == "poison" then
		setEffect(intruder, "slow", 3)
	elseif kind == "hypno" then
		setEffect(intruder, "stun", 1.5)
		Visuals.ring(root.Position, Color3.fromRGB(200, 90, 255), 5)
		if carriers[intruder] then
			returnLoot(intruder, sourceName)
		end
		eject(intruder, garden)
	elseif kind == "dragon" then
		if carriers[intruder] then
			returnLoot(intruder, sourceName)
		end
	end
	if not effectActive(intruder, "warned") then
		setEffect(intruder, "warned", 3)
		Sync.notify(intruder, "💥 " .. sourceName .. " te atacou! Saia desse jardim!", "error")
	end
end

-- Defesas do jardim contra intrusos (so a noite)
local function defendGarden(garden)
	if not garden.player.Parent then
		return
	end
	local defenses = GardenService.defenses(garden)
	for _, intruder in Players:GetPlayers() do
		if intruder ~= garden.player then
			local root = rootOf(intruder)
			if root and GardenService.isInside(garden, root.Position) then
				local hidden = effectActive(intruder, "invisible") and not isRevealed(garden, root.Position)
				if not hidden then
					for _, defense in defenses do
						local info = defense.defense
						local flat = Vector3.new(root.Position.X - defense.position.X, 0, root.Position.Z - defense.position.Z)
						if flat.Magnitude <= info.radius then
							local key = string.format("def:%d:%d", defense.plantId, intruder.UserId)
							if ready(key, info.cooldown) then
								local kind = info.kind
								local from = if kind == "ranged" or kind == "dragon" then defense.position else nil
								hit(intruder, garden, kind, info.damage, defense.seed.name, from)
							end
						end
					end
				end
			end
		end
	end
end

local function tick()
	local night = DayNightService.isNight()
	-- cadeados nas placas
	for _, garden in GardenService.getGardens() do
		local locked = StealService.isLocked(garden)
		if lockedState[garden] ~= locked then
			lockedState[garden] = locked
			garden.plot.model:SetAttribute("Locked", locked)
			garden.plot.signLabel.Text = "Jardim de " .. garden.player.DisplayName .. (if locked then " 🔒" else "")
		end
		if night then
			defendGarden(garden)
		end
	end
	-- ladroes carregando frutos
	for thief, carrier in carriers do
		local root = rootOf(thief)
		local humanoid = humanoidOf(thief)
		local myGarden = GardenService.getGarden(thief)
		if not root or not humanoid or humanoid.Health <= 0 then
			returnLoot(thief, "o ladrão caiu")
		elseif os.clock() - carrier.started > S.carryTimeout then
			returnLoot(thief, "demorou demais")
		elseif myGarden and GardenService.isInside(myGarden, root.Position) then
			secureLoot(thief)
		end
	end
	for _, player in Players:GetPlayers() do
		updateMovement(player)
	end
end

function StealService.start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		accumulator = 0
		local ok, err = pcall(tick)
		if not ok then
			warn("[Jardim] Erro no sistema de roubo: " .. tostring(err))
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if carriers[player] then
			returnLoot(player, "o ladrão saiu do jogo")
		end
		carriers[player] = nil
		lastSteal[player] = nil
		effects[player] = nil
		invisibleParts[player] = nil
		for garden in lockedState do
			if garden.player == player then
				lockedState[garden] = nil
			end
		end
	end)
end

return StealService
