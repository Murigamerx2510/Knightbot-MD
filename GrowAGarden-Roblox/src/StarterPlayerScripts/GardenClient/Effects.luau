-- Effects: efeitos visuais so do cliente.
--  * frutos Arco-iris trocando de cor
--  * chuva, neve, areia, chocolate, raios
--  * luas, aurora, arco-iris e eclipse no ceu
--  * botoes "Colher" (seu jardim) e "Roubar" (jardins alheios, a noite)
--  * NPCs das lojas animados e falando
--  * dica ao passar o mouse nas plantas

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))

local Effects = {}

local player = Players.LocalPlayer
local FONT = Enum.Font.FredokaOne

local function localPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, sphere: boolean): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Size = size
	part.CFrame = cf
	if sphere then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.Parent = parent
	return part
end

---------------------------------------------------------------------
-- Arco-iris
---------------------------------------------------------------------

local function startRainbow()
	RunService.Heartbeat:Connect(function()
		local hue = (os.clock() * 0.25) % 1
		for index, part in CollectionService:GetTagged("RainbowFruit") do
			if part:IsA("BasePart") then
				part.Color = Color3.fromHSV((hue + index * 0.07) % 1, 0.75, 1)
			end
		end
	end)
end

---------------------------------------------------------------------
-- Clima: particulas e objetos no ceu
---------------------------------------------------------------------

local function emitter(parent: Instance, name: string, props: { [string]: any }): ParticleEmitter
	local particles = Instance.new("ParticleEmitter")
	particles.Name = name
	particles.Enabled = false
	for key, value in props do
		(particles :: any)[key] = value
	end
	particles.Parent = parent
	return particles
end

local SKY_POSITION = Vector3.new(160, 230, 320)

local function buildSkyObject(kind: string, folder: Folder)
	if kind == "bloodmoon" or kind == "goldmoon" or kind == "rainbowmoon" or kind == "megamoon" then
		local colors = {
			bloodmoon = Color3.fromRGB(220, 40, 40),
			goldmoon = Color3.fromRGB(255, 210, 80),
			rainbowmoon = Color3.fromRGB(255, 150, 255),
			megamoon = Color3.fromRGB(240, 240, 255),
		}
		local size = if kind == "megamoon" then 150 else 70
		local moon = localPart(folder, "Lua", Vector3.new(size, size, size), CFrame.new(SKY_POSITION), colors[kind], true)
		moon.Material = Enum.Material.Neon
		if kind == "rainbowmoon" then
			CollectionService:AddTag(moon, "RainbowFruit")
		end
	elseif kind == "eclipse" then
		local glow = localPart(folder, "Coroa", Vector3.new(1, 100, 100), CFrame.new(SKY_POSITION + Vector3.new(0, 0, 4)) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(255, 160, 60), false)
		glow.Shape = Enum.PartType.Cylinder
		glow.Material = Enum.Material.Neon
		glow.Transparency = 0.2
		localPart(folder, "Sol", Vector3.new(80, 80, 80), CFrame.new(SKY_POSITION), Color3.fromRGB(10, 10, 15), true)
	elseif kind == "aurora" then
		for i = 1, 6 do
			local band = localPart(folder, "Aurora", Vector3.new(160, 30, 2), CFrame.new(-200 + i * 60, 170 + (i % 2) * 12, 260 - i * 10) * CFrame.Angles(0, math.rad(15 * i), math.rad(8)), if i % 2 == 0 then Color3.fromRGB(90, 255, 170) else Color3.fromRGB(160, 110, 255), false)
			band.Material = Enum.Material.Neon
			band.Transparency = 0.6
			CollectionService:AddTag(band, "AuroraBand")
		end
	elseif kind == "rainbow" then
		local colors = { Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 160, 50), Color3.fromRGB(255, 230, 60), Color3.fromRGB(90, 220, 90), Color3.fromRGB(70, 150, 255), Color3.fromRGB(170, 90, 255) }
		for band, color in colors do
			local radius = 220 - band * 9
			for step = 0, 18 do
				local angle = math.pi * step / 18
				local position = Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius - 20, 330)
				local piece = localPart(folder, "ArcoIris", Vector3.new(9, 40, 2), CFrame.new(position) * CFrame.Angles(0, 0, angle), color, false)
				piece.Material = Enum.Material.Neon
				piece.Transparency = 0.35
			end
		end
	end
end

local function startWeather()
	local holder = localPart(workspace, "ClimaLocal", Vector3.new(120, 1, 120), CFrame.new(0, 100, 0), Color3.new(1, 1, 1), false)
	holder.Transparency = 1
	local skyFolder = Instance.new("Folder")
	skyFolder.Name = "CeuLocal"
	skyFolder.Parent = workspace

	local particles = {
		rain = emitter(holder, "Chuva", {
			Rate = 500, Lifetime = NumberRange.new(1, 1.3), Speed = NumberRange.new(60, 70),
			EmissionDirection = Enum.NormalId.Bottom, Orientation = Enum.ParticleOrientation.VelocityParallel,
			Size = NumberSequence.new(0.18), Squash = NumberSequence.new(2.5), Transparency = NumberSequence.new(0.25),
			Color = ColorSequence.new(Color3.fromRGB(175, 205, 255)), LightEmission = 0.3,
		}),
		snow = emitter(holder, "Neve", {
			Rate = 160, Lifetime = NumberRange.new(6, 8), Speed = NumberRange.new(5, 9),
			EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(25, 25), Acceleration = Vector3.new(1, -1, 0),
			Size = NumberSequence.new(0.35), Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)), LightEmission = 0.5,
			RotSpeed = NumberRange.new(-90, 90),
		}),
		heavysnow = emitter(holder, "Nevasca", {
			Rate = 450, Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(10, 16),
			EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(35, 35), Acceleration = Vector3.new(6, -2, 0),
			Size = NumberSequence.new(0.45), Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)), LightEmission = 0.5,
		}),
		sand = emitter(holder, "Areia", {
			Rate = 350, Lifetime = NumberRange.new(3, 4), Speed = NumberRange.new(20, 30),
			EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(25, -5, 0),
			Size = NumberSequence.new(0.3), Color = ColorSequence.new(Color3.fromRGB(230, 200, 140)), Transparency = NumberSequence.new(0.3),
		}),
		chocolate = emitter(holder, "Chocolate", {
			Rate = 300, Lifetime = NumberRange.new(1.4, 1.8), Speed = NumberRange.new(45, 55),
			EmissionDirection = Enum.NormalId.Bottom, Orientation = Enum.ParticleOrientation.VelocityParallel,
			Size = NumberSequence.new(0.3), Squash = NumberSequence.new(1.5),
			Color = ColorSequence.new(Color3.fromRGB(110, 60, 30)),
		}),
	}

	local function apply()
		local weatherId = workspace:GetAttribute("Weather")
		local weather = if type(weatherId) == "string" then Config.Weather[weatherId] else nil
		for name, particle in particles do
			particle.Enabled = weather ~= nil and weather.particle == name
		end
		skyFolder:ClearAllChildren()
		if weather and weather.skyObject then
			buildSkyObject(weather.skyObject, skyFolder)
		end
	end
	workspace:GetAttributeChangedSignal("Weather"):Connect(apply)
	apply()

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if camera then
			holder.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 35, 0))
		end
		local t = os.clock()
		for index, band in CollectionService:GetTagged("AuroraBand") do
			if band:IsA("BasePart") then
				band.Transparency = 0.55 + math.sin(t * 1.5 + index) * 0.2
			end
		end
	end)

	-- clarao quando cai um raio ou meteoro
	local flash = Instance.new("ColorCorrectionEffect")
	flash.Name = "ClaraoLocal"
	flash.Brightness = 0
	flash.Parent = Lighting
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "Raio" or child.Name == "Meteoro" then
			flash.Brightness = 0.45
			TweenService:Create(flash, TweenInfo.new(0.4), { Brightness = 0 }):Play()
		end
	end)
end

---------------------------------------------------------------------
-- Botoes "Colher" e "Roubar"
---------------------------------------------------------------------

local function plotOf(instance: Instance): Instance?
	local node = instance.Parent
	while node and node ~= workspace do
		if node:GetAttribute("PlotIndex") ~= nil then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function startPromptFilter()
	local prompts: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local watchedPlots: { [Instance]: boolean } = {}

	local function evaluate(prompt: ProximityPrompt)
		local owner = prompt:GetAttribute("OwnerUserId")
		if type(owner) ~= "number" or owner == 0 then
			return
		end
		if owner == player.UserId then
			prompt.Enabled = true
			if prompt:GetAttribute("Kind") == "Harvest" then
				prompt.ActionText = "Colher"
				prompt.HoldDuration = 0
			end
			return
		end
		local canSteal = prompt:GetAttribute("Kind") == "Harvest"
			and workspace:GetAttribute("StealingEnabled") == true
			and workspace:GetAttribute("Phase") == "Night"
			and player:GetAttribute("Carrying") ~= true
		local plot = plotOf(prompt)
		if plot and plot:GetAttribute("Locked") == true then
			canSteal = false
		end
		prompt.Enabled = canSteal
		if canSteal then
			prompt.ActionText = "Roubar"
			prompt.HoldDuration = Config.Stealing.holdDuration
		end
	end

	local function evaluateAll()
		for prompt in prompts do
			if prompt.Parent then
				evaluate(prompt)
			end
		end
	end

	local function track(instance: Instance)
		if instance:IsA("ProximityPrompt") and instance:GetAttribute("OwnerUserId") ~= nil then
			prompts[instance] = true
			local plot = plotOf(instance)
			if plot and not watchedPlots[plot] then
				watchedPlots[plot] = true
				plot:GetAttributeChangedSignal("Locked"):Connect(evaluateAll)
			end
			evaluate(instance)
		end
	end

	workspace.DescendantAdded:Connect(track)
	for _, descendant in workspace:GetDescendants() do
		track(descendant)
	end
	workspace:GetAttributeChangedSignal("Phase"):Connect(evaluateAll)
	player:GetAttributeChangedSignal("Carrying"):Connect(evaluateAll)
end

---------------------------------------------------------------------
-- NPCs das lojas
---------------------------------------------------------------------

local NPC_LINES = {
	Sam = { "Sementes fresquinhas!", "A loja reabastece a cada 5 minutos!", "Já viu a Semente Arco-íris?", "Plante e espere crescer!" },
	Steven = { "Compro qualquer fruto!", "Frutos mutados valem muito mais!", "Quanto mais pesado, melhor!", "Venda tudo aqui!" },
	George = { "Proteja seu jardim com um Gnomo!", "A Espátula faz fusões secretas...", "Sprinklers deixam os frutos maiores!", "Lanternas revelam ladrões invisíveis!" },
}

local function startNpcs()
	local rng = Random.new()
	local animated: { [Model]: { base: { [BasePart]: CFrame }, bubble: TextLabel?, nextLine: number } } = {}

	local function setup(npc: Instance)
		if not npc:IsA("Model") or animated[npc] then
			return
		end
		local base = {}
		for _, descendant in npc:GetDescendants() do
			if descendant:IsA("BasePart") then
				base[descendant] = descendant.CFrame
			end
		end
		local head = npc:FindFirstChild("Cabeca")
		local bubble = nil
		if head and head:IsA("BasePart") then
			local gui = Instance.new("BillboardGui")
			gui.Name = "Fala"
			gui.Size = UDim2.fromOffset(220, 46)
			gui.StudsOffset = Vector3.new(0, 5.2, 0)
			gui.MaxDistance = 60
			gui.Adornee = head
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			label.BackgroundTransparency = 0.1
			label.Font = FONT
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(50, 40, 30)
			label.Text = ""
			label.Visible = false
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0, 12)
			round.Parent = label
			label.Parent = gui
			gui.Parent = npc
			bubble = label
		end
		animated[npc] = { base = base, bubble = bubble, nextLine = os.clock() + rng:NextNumber(2, 6) }
	end

	for _, npc in CollectionService:GetTagged("LojaNpc") do
		setup(npc)
	end
	CollectionService:GetInstanceAddedSignal("LojaNpc"):Connect(setup)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for npc, info in animated do
			if not npc.Parent then
				animated[npc] = nil
				continue
			end
			local bob = math.sin(t * 2 + #npc.Name) * 0.08
			local wave = math.sin(t * 3) * 0.35
			for part, cf in info.base do
				if part.Parent then
					local offset = CFrame.new(0, bob, 0)
					if part.Name == "BracoDireito" then
						part.CFrame = offset * cf * CFrame.new(0, 0.8, 0) * CFrame.Angles(wave, 0, 0) * CFrame.new(0, -0.8, 0)
					else
						part.CFrame = offset * cf
					end
				end
			end
			if info.bubble and t >= info.nextLine then
				local lines = NPC_LINES[npc:GetAttribute("Npc") or ""] or { "Olá!" }
				info.bubble.Text = lines[rng:NextInteger(1, #lines)]
				info.bubble.Visible = not info.bubble.Visible
				info.nextLine = t + (if info.bubble.Visible then 4 else rng:NextNumber(6, 12))
			end
		end
	end)
end

---------------------------------------------------------------------
-- Dica ao passar o mouse
---------------------------------------------------------------------

local DEFENSE_TEXT = {
	contact = "🛡️ Espinhos machucam ladrões",
	poison = "🛡️ Envenena e deixa ladrões lentos",
	bite = "🛡️ Morde ladrões à noite",
	ranged = "🛡️ Cospe veneno em ladrões",
	dragon = "🛡️ Lança fogo e faz o ladrão soltar o fruto",
	hypno = "🛡️ Hipnotiza e expulsa ladrões",
}

local function describe(target: Instance): string?
	local fruitModel: Instance? = nil
	local plantModel: Instance? = nil
	local node: Instance? = target
	while node and node ~= workspace do
		if node:IsA("Model") then
			if node:GetAttribute("SeedId") ~= nil then
				plantModel = node
				break
			elseif fruitModel == nil and node:GetAttribute("Weight") ~= nil then
				fruitModel = node
			end
		end
		node = node.Parent
	end
	if not plantModel then
		return nil
	end
	local seedId = plantModel:GetAttribute("SeedId")
	local seed = Config.Seeds[seedId]
	if not seed then
		return nil
	end
	local variantId = plantModel:GetAttribute("Variant")
	local name = Formulas.fruitName(seed.id, if type(variantId) == "string" then variantId else nil)
	local source = fruitModel or plantModel
	local lines = { name .. "  (" .. Config.Rarities[seed.rarity].name .. ")" }
	local weight = source:GetAttribute("Weight")
	if type(weight) == "number" then
		local size = source:GetAttribute("Size")
		lines[1] = string.format("%s • %s%s", name, Formulas.formatWeight(weight), if type(size) == "string" then " • " .. size else "")
	end
	local mutations = source:GetAttribute("Mutations")
	if type(mutations) == "string" and mutations ~= "" then
		table.insert(lines, "✨ " .. mutations)
	end
	if source:GetAttribute("Ripe") then
		table.insert(lines, if plantModel:GetAttribute("OwnerUserId") == player.UserId then "Pronto! Aperte E para colher" else "Pronto para colher")
	elseif fruitModel then
		table.insert(lines, "Fruto amadurecendo...")
	else
		local progress = plantModel:GetAttribute("Progress")
		if type(progress) == "number" and progress >= 100 then
			table.insert(lines, "Produzindo frutos")
		elseif type(progress) == "number" and progress < Config.Growth.sproutUntil * 100 then
			table.insert(lines, "🌱 Brotando: " .. tostring(progress) .. "%")
		else
			table.insert(lines, "Crescendo: " .. tostring(progress or 0) .. "%")
		end
	end
	local defense = plantModel:GetAttribute("Defense")
	if type(defense) == "string" and DEFENSE_TEXT[defense] then
		table.insert(lines, DEFENSE_TEXT[defense])
	end
	return table.concat(lines, "\n")
end

local function startTooltip(interface)
	local mouse = player:GetMouse()
	local elapsed = 0
	RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then
			return
		end
		elapsed = 0
		local target = mouse.Target
		local message = if target and not interface.isPanelOpen() then describe(target) else nil
		interface.setTooltip(message, mouse.X, mouse.Y)
	end)
end

function Effects.start(interface)
	startRainbow()
	startWeather()
	startPromptFilter()
	startNpcs()
	startTooltip(interface)
end

return Effects
