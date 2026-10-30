-- GardenService: jardins dos jogadores, plantio, crescimento, colheita, itens
-- (regador, pa, espatula, sprinklers, lanternas, gnomos, ovos) e habilidades dos pets.
--
-- O crescimento usa os.time(), entao as plantas continuam crescendo
-- mesmo com o jogador offline.
--   idade da planta = agora - plantadaEm + bonus
-- Clima, sprinklers, regador, lanternas e pets aumentam o "bonus".
--
-- Crescimento visivel: broto na terra -> planta jovem que vai crescendo -> adulta.
-- Os frutos nascem pequenos e verdes, crescem e mudam para a cor final ao amadurecer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local MapBuilder = require(script.Parent.MapBuilder)
local PetService = require(script.Parent.PetService)
local QuestService = require(script.Parent.QuestService)
local Sync = require(script.Parent.Sync)
local Visuals = require(script.Parent.Visuals)

local GardenService = {}

-- Ganchos ligados pelo script principal (evita dependencias circulares)
GardenService.hooks = {
	steal = nil :: ((Player, any, any, number?) -> ())?,
	bonk = nil :: ((Player) -> boolean)?,
	snipe = nil :: ((Player, any, Vector3?) -> ())?,
	consume = nil :: ((Player, any) -> boolean)?,
	weatherTrigger = nil :: ((string) -> ())?,
}

local L = MapBuilder.Layout
local rng = Random.new()
local plots = {}
local gardens: { [Player]: any } = {}
local weather = { growthBonus = 0, goldBoost = 1, rainbowBoost = 1, sizeBoost = 0 }
local phase = "Day"
local nightIndex = 0

local function round2(n: number): number
	return math.floor(n * 100 + 0.5) / 100
end

local function plantAge(plant, now: number): number
	return now - plant.p + plant.b
end

local function weightScale(seed, weight: number): number
	return math.clamp((weight / seed.baseWeight) ^ (1 / 3), 0.7, 1.8)
end

local function fruitLabel(seed, weight: number, mutations: { string }, variantId: string?): string
	local text = string.format("%s (%s)", Formulas.fruitName(seed.id, variantId), Formulas.formatWeight(weight))
	local names = Formulas.mutationNames(mutations)
	if names ~= "" then
		text = "[" .. names .. "] " .. text
	end
	return text
end

local function makePrompt(parent: Instance, action: string, objectText: string, ownerId: number, kind: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("OwnerUserId", ownerId)
	prompt:SetAttribute("Kind", kind)
	prompt.Parent = parent
	return prompt
end

local function primaryOf(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function inBeds(lx: number, lz: number): boolean
	local ax = math.abs(lx)
	return ax >= L.bedInner + 0.4 and ax <= L.bedOuter - 0.4 and lz >= L.bedZMin + 0.4 and lz <= L.bedZMax - 0.4
end

local function inPlot(lx: number, lz: number): boolean
	return math.abs(lx) <= L.plotHalfX - 1 and math.abs(lz) <= L.plotHalfZ - 1
end

local function groundHeight(lx: number, lz: number): number
	return if inBeds(lx, lz) then L.bedTop else 0.15
end

local function isValidVector(value: any): boolean
	return typeof(value) == "Vector3"
		and value.X == value.X
		and value.Y == value.Y
		and value.Z == value.Z
		and value.Magnitude < 100000
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Converte a posicao clicada para coordenadas locais do jardim.
-- Se o clique for invalido, tenta a posicao na frente do personagem.
local function resolvePosition(garden, position: any, check: (number, number) -> boolean): (number?, number?)
	if isValidVector(position) then
		local localPos = garden.plot.cframe:PointToObjectSpace(position)
		if check(localPos.X, localPos.Z) then
			return localPos.X, localPos.Z
		end
	end
	local root = rootOf(garden.player)
	if root then
		local front = root.Position + root.CFrame.LookVector * 2.5
		local localPos = garden.plot.cframe:PointToObjectSpace(front)
		if check(localPos.X, localPos.Z) then
			return localPos.X, localPos.Z
		end
	end
	return nil, nil
end

local function isFarFromEverything(garden, lx: number, lz: number, plantSpacing: number, eggSpacing: number, ignorePlantId: number?): boolean
	local plantMin = plantSpacing * plantSpacing
	for _, plant in garden.data.plants do
		if plant.id ~= ignorePlantId then
			local dx, dz = plant.x - lx, plant.z - lz
			if dx * dx + dz * dz < plantMin then
				return false
			end
		end
	end
	local eggMin = eggSpacing * eggSpacing
	for _, list in { garden.data.placedEggs, garden.data.props } do
		for _, item in list do
			local dx, dz = item.x - lx, item.z - lz
			if dx * dx + dz * dz < eggMin then
				return false
			end
		end
	end
	return true
end

local function bonusesOf(garden)
	if not garden.bonuses then
		garden.bonuses = Formulas.petBonuses(garden.data.pets, garden.data.equippedPets)
	end
	return garden.bonuses
end

local function luckOf(garden): number
	local bonuses = bonusesOf(garden)
	return bonuses.Luck + (if phase == "Night" then bonuses.NightLuck else 0)
end

-- Bonus de tamanho para frutos novos (pets, clima e sprinklers por perto)
local function sizeBonusFor(garden, plant): number
	local bonus = bonusesOf(garden).Size + weather.sizeBoost
	local best = 0
	for _, entry in garden.data.sprinklers do
		local gear = Config.Gear[entry.g]
		if gear and gear.size then
			local dx, dz = plant.x - entry.x, plant.z - entry.z
			if dx * dx + dz * dz <= gear.radius * gear.radius then
				best = math.max(best, gear.size)
			end
		end
	end
	return bonus + best
end

local function newFruit(garden, plant, seed, startAge: number?)
	local luck = luckOf(garden)
	local bonuses = bonusesOf(garden)
	local mutations = Formulas.rollGrowthMutations(
		rng,
		luck,
		(1 + bonuses.Gold) * weather.goldBoost,
		(1 + bonuses.Rainbow) * weather.rainbowBoost
	)
	local special = seed.special or {}
	if special.alwaysMutation then
		Formulas.addMutation(mutations, special.alwaysMutation)
	end
	if special.fruitMutations then
		for id, chance in special.fruitMutations do
			if rng:NextNumber() < chance * (1 + luck) then
				Formulas.addMutation(mutations, id)
			end
		end
	end
	return {
		a = startAge or 0,
		w = Formulas.rollWeight(seed, rng, sizeBonusFor(garden, plant)),
		m = mutations,
	}
end

-- Executa callback(listaDeMutacoes) para cada fruto visivel da planta
local function forEachVisibleFruit(plant, now: number, callback: ({ string }) -> ())
	local seed = Config.Seeds[plant.s]
	if not seed then
		return
	end
	if not seed.multiHarvest then
		callback(plant.f.m)
		return
	end
	local age = plantAge(plant, now)
	if age < seed.growTime then
		return
	end
	for _, slot in plant.slots do
		if age - slot.a > 0 then
			callback(slot.m)
		end
	end
end

local function applyChanceToPlant(plant, mutationId: string, chance: number, now: number)
	forEachVisibleFruit(plant, now, function(list)
		if rng:NextNumber() < chance then
			Formulas.addMutation(list, mutationId)
		end
	end)
end

local function capacityOf(garden): number
	return Config.MaxFruitsInInventory + math.max(0, bonusesOf(garden).Inventory)
end

---------------------------------------------------------------------
-- Visual das plantas
---------------------------------------------------------------------

local onPromptTriggered: (Player, any, any, number?) -> ()

local function destroyFruitView(view, index: number)
	local fruitView = view.fruits[index]
	if fruitView then
		fruitView.model:Destroy()
		view.fruits[index] = nil
	end
end

local function createFruitView(view, index: number, slot)
	local seed = view.seed
	local model = Visuals.buildFruit(seed)
	model.Name = "Fruto" .. index
	Visuals.applyVariant(Visuals.produceParts(model), seed, view.plant.v)
	local offset = view.offsets[index] or Vector3.new(0, seed.height * 0.5, 0)
	model:PivotTo(view.baseCF * CFrame.new(offset))
	model:SetAttribute("Weight", slot.w)
	model:SetAttribute("Size", Formulas.sizeClass(seed.id, slot.w))
	model.Parent = view.container
	local fruitView = { model = model, step = -1, signature = nil, prompt = nil, slot = slot }
	view.fruits[index] = fruitView
	return fruitView
end

local function updatePlantView(garden, view, now: number)
	local plant, seed = view.plant, view.seed
	local age = plantAge(plant, now)
	local growth = math.clamp(age / seed.growTime, 0, 1)
	local sproutUntil = Config.Growth.sproutUntil

	-- 1) broto
	if growth < sproutUntil then
		if not view.sprout then
			view.sprout = Visuals.buildSprout(seed)
			view.sprout:PivotTo(view.baseCF)
			view.sprout.Parent = view.container
			view.sproutStep = -1
		end
		if view.body.Parent then
			view.body.Parent = nil
		end
		local sproutStep = math.floor(growth / sproutUntil * 5)
		if sproutStep ~= view.sproutStep then
			view.sproutStep = sproutStep
			view.sprout:ScaleTo(0.5 + 0.1 * sproutStep)
			view.container:SetAttribute("Progress", math.floor(growth * 100))
		end
		return
	end
	if view.sprout then
		view.sprout:Destroy()
		view.sprout = nil
	end
	if not view.body.Parent then
		view.body.Parent = view.container
	end

	-- 2) planta crescendo
	local steps = Config.Growth.steps
	local step = math.floor(growth * steps)
	if step ~= view.scaleStep then
		view.scaleStep = step
		local scale = 0.2 + 0.8 * step / steps
		if not seed.multiHarvest then
			scale *= weightScale(seed, plant.f.w)
		end
		view.body:ScaleTo(scale)
		view.container:SetAttribute("Progress", math.floor(growth * 100))
		if not seed.multiHarvest and view.signature == "" then
			Visuals.setRipeness(Visuals.produceParts(view.body), growth)
		end
	end

	if not seed.multiHarvest then
		local signature = table.concat(plant.f.m, ",")
		if signature ~= view.signature then
			view.signature = signature
			local parts = Visuals.produceParts(view.body)
			Visuals.applyMutations(parts, plant.f.m)
			if signature == "" then
				Visuals.setRipeness(parts, growth)
			end
			view.container:SetAttribute("Mutations", Formulas.mutationNames(plant.f.m))
			if view.prompt then
				view.prompt.ObjectText = fruitLabel(seed, plant.f.w, plant.f.m, plant.v)
			end
		end
		if growth >= 1 and not view.prompt then
			local target = Visuals.produceParts(view.body)[1] or primaryOf(view.body)
			if target then
				local prompt = makePrompt(target, "Colher", fruitLabel(seed, plant.f.w, plant.f.m, plant.v), garden.player.UserId, "Harvest")
				prompt.Triggered:Connect(function(who)
					onPromptTriggered(who, garden, view, nil)
				end)
				view.prompt = prompt
				view.container:SetAttribute("Ripe", true)
			end
		end
		return
	end

	-- 3) frutos das plantas de varias colheitas
	if growth < 1 then
		return
	end
	local fruitSteps = Config.Growth.fruitSteps
	for index, slot in plant.slots do
		local progress = (age - slot.a) / seed.fruitTime
		local fruitView = view.fruits[index]
		if fruitView and fruitView.slot ~= slot then
			destroyFruitView(view, index)
			fruitView = nil
		end
		if progress <= 0 then
			if fruitView then
				destroyFruitView(view, index)
			end
		else
			if not fruitView then
				fruitView = createFruitView(view, index, slot)
			end
			local signature = table.concat(slot.m, ",")
			local fruitStep = math.floor(math.clamp(progress, 0, 1) * fruitSteps)
			if fruitStep ~= fruitView.step then
				fruitView.step = fruitStep
				fruitView.model:ScaleTo(weightScale(seed, slot.w) * (0.25 + 0.75 * fruitStep / fruitSteps))
				if signature == "" then
					Visuals.setRipeness(Visuals.produceParts(fruitView.model), fruitStep / fruitSteps)
				end
			end
			if signature ~= fruitView.signature then
				fruitView.signature = signature
				local parts = Visuals.produceParts(fruitView.model)
				Visuals.applyMutations(parts, slot.m)
				if signature == "" then
					Visuals.setRipeness(parts, fruitStep / fruitSteps)
				end
				fruitView.model:SetAttribute("Mutations", Formulas.mutationNames(slot.m))
				if fruitView.prompt then
					fruitView.prompt.ObjectText = fruitLabel(seed, slot.w, slot.m, plant.v)
				end
			end
			if progress >= 1 and not fruitView.prompt then
				local target = primaryOf(fruitView.model)
				if target then
					local slotIndex = index
					local prompt = makePrompt(target, "Colher", fruitLabel(seed, slot.w, slot.m, plant.v), garden.player.UserId, "Harvest")
					prompt.Triggered:Connect(function(who)
						onPromptTriggered(who, garden, view, slotIndex)
					end)
					fruitView.prompt = prompt
					fruitView.model:SetAttribute("Ripe", true)
				end
			end
		end
	end
end

local function createPlantView(garden, plant)
	local seed = Config.Seeds[plant.s]
	if not seed then
		return
	end
	local plot = garden.plot
	local yaw = (plant.id * 2.399) % (math.pi * 2)
	local baseCF = plot.cframe * CFrame.new(plant.x, L.bedTop, plant.z) * CFrame.Angles(0, yaw, 0)
	local container = Instance.new("Model")
	container.Name = Formulas.fruitName(seed.id, plant.v)
	container:SetAttribute("PlantId", plant.id)
	container:SetAttribute("SeedId", seed.id)
	container:SetAttribute("OwnerUserId", garden.player.UserId)
	if plant.v then
		container:SetAttribute("Variant", plant.v)
	end
	if not seed.multiHarvest then
		container:SetAttribute("Weight", plant.f.w)
		container:SetAttribute("Size", Formulas.sizeClass(seed.id, plant.f.w))
	end
	if seed.defense then
		container:SetAttribute("Defense", seed.defense.kind)
	end
	local body = Visuals.buildPlant(seed)
	Visuals.applyVariant(Visuals.produceParts(body), seed, plant.v)
	body:PivotTo(baseCF)
	container.Parent = plot.plantsFolder
	local view = {
		plant = plant,
		seed = seed,
		container = container,
		body = body,
		sprout = nil,
		sproutStep = -1,
		baseCF = baseCF,
		scaleStep = -1,
		signature = nil,
		prompt = nil,
		fruits = {},
		offsets = Visuals.fruitOffsets(seed),
		destroyed = false,
	}
	garden.plantViews[plant.id] = view
	updatePlantView(garden, view, os.time())
end

local function destroyPlantView(garden, plantId: number)
	local view = garden.plantViews[plantId]
	if view then
		view.destroyed = true
		view.container:Destroy()
		if view.body then
			view.body:Destroy()
		end
		garden.plantViews[plantId] = nil
	end
end

local function removePlant(garden, plantId: number)
	local plants = garden.data.plants
	for i = #plants, 1, -1 do
		if plants[i].id == plantId then
			table.remove(plants, i)
		end
	end
	destroyPlantView(garden, plantId)
end

---------------------------------------------------------------------
-- Colheita
---------------------------------------------------------------------

local function isFruitRipe(view, slotIndex: number?, now: number): boolean
	if view.destroyed then
		return false
	end
	local plant, seed = view.plant, view.seed
	local age = plantAge(plant, now)
	if slotIndex == nil then
		return not seed.multiHarvest and age >= seed.growTime
	end
	local slot = plant.slots[slotIndex]
	return seed.multiHarvest and slot ~= nil and age >= seed.growTime and age - slot.a >= seed.fruitTime
end

-- Tira o fruto da planta (colheita ou roubo). Retorna o fruto ou nil.
function GardenService.takeFruit(garden, view, slotIndex: number?)
	local now = os.time()
	if not isFruitRipe(view, slotIndex, now) then
		return nil
	end
	local plant, seed = view.plant, view.seed
	local fruit
	if slotIndex == nil then
		fruit = { s = seed.id, w = plant.f.w, m = table.clone(plant.f.m), v = plant.v }
		removePlant(garden, plant.id)
	else
		local slot = plant.slots[slotIndex]
		fruit = { s = seed.id, w = slot.w, m = table.clone(slot.m), v = plant.v }
		plant.slots[slotIndex] = newFruit(garden, plant, seed, plantAge(plant, now))
		destroyFruitView(view, slotIndex)
	end
	return fruit
end

-- Coloca um fruto no inventario (false se a mochila estiver cheia)
function GardenService.addFruit(player: Player, fruit): boolean
	local garden = gardens[player]
	if not garden then
		return false
	end
	if #garden.data.fruits >= capacityOf(garden) then
		return false
	end
	table.insert(garden.data.fruits, fruit)
	Sync.markDirty(player)
	return true
end

-- Colheita pelo dono (ou pelos pets do dono)
local function ownerHarvest(garden, view, slotIndex: number?, source: string?): any
	local player = garden.player
	local data = garden.data
	if #data.fruits >= capacityOf(garden) then
		if not source then
			Sync.notify(player, "Sua mochila está cheia! Venda seus frutos para o Steven.", "error")
		end
		return nil
	end
	local seed = view.seed
	local fruit = GardenService.takeFruit(garden, view, slotIndex)
	if not fruit then
		return nil
	end
	table.insert(data.fruits, fruit)
	data.stats.harvested += 1
	QuestService.progress(player, "harvest", 1)
	if #fruit.m > 0 then
		QuestService.progress(player, "mutated", 1)
	end
	Sync.markDirty(player)
	local label = fruitLabel(seed, fruit.w, fruit.m, fruit.v)
	if source then
		Sync.notify(player, source .. " colheu: " .. label, "info")
	else
		Sync.notify(player, "+ " .. label, if #fruit.m > 0 or fruit.v then "rare" else "success")
	end
	local special = seed.special or {}
	if special.triggersWeather and GardenService.hooks.weatherTrigger then
		GardenService.hooks.weatherTrigger(special.triggersWeather)
	end
	return fruit
end

onPromptTriggered = function(who: Player, garden, view, slotIndex: number?)
	if gardens[garden.player] ~= garden or view.destroyed then
		return
	end
	if who ~= garden.player then
		if GardenService.hooks.steal then
			GardenService.hooks.steal(who, garden, view, slotIndex)
		end
		return
	end
	ownerHarvest(garden, view, slotIndex, nil)
end

-- Frutos maduros do jardim: { {view, slot, value} }
local function ripeFruits(garden, now: number)
	local list = {}
	local sellBonus = bonusesOf(garden).Sell
	for _, view in garden.plantViews do
		if not view.destroyed then
			local plant, seed = view.plant, view.seed
			if seed.multiHarvest then
				for index, slot in plant.slots do
					if isFruitRipe(view, index, now) then
						table.insert(list, { view = view, slot = index, value = Formulas.fruitValue(seed.id, slot.w, slot.m, sellBonus, plant.v) })
					end
				end
			elseif isFruitRipe(view, nil, now) then
				table.insert(list, { view = view, slot = nil, value = Formulas.fruitValue(seed.id, plant.f.w, plant.f.m, sellBonus, plant.v) })
			end
		end
	end
	return list
end
GardenService.ripeFruits = ripeFruits

function GardenService.fruitWorldPosition(view, slotIndex: number?): Vector3
	if slotIndex and view.fruits[slotIndex] then
		return view.fruits[slotIndex].model:GetPivot().Position
	end
	return view.baseCF.Position + Vector3.new(0, view.seed.height * 0.5, 0)
end

---------------------------------------------------------------------
-- Sprinklers, lanternas, gnomos e ovos
---------------------------------------------------------------------

local function createSprinklerView(garden, entry)
	local gear = Config.Gear[entry.g]
	if not gear then
		return
	end
	local model = Visuals.buildSprinkler(gear)
	model:PivotTo(garden.plot.cframe * CFrame.new(entry.x, groundHeight(entry.x, entry.z), entry.z))
	model.Parent = garden.plot.plantsFolder
	garden.sprinklerViews[entry.id] = model
end

local function createPropView(garden, entry)
	local gear = Config.Gear[entry.g]
	if not gear then
		return
	end
	local model, label
	if gear.kind == "lantern" then
		model = Visuals.buildLantern(gear)
	else
		model, label = Visuals.buildGnome(gear)
	end
	model:PivotTo(garden.plot.cframe * CFrame.new(entry.x, groundHeight(entry.x, entry.z), entry.z) * CFrame.Angles(0, math.pi, 0))
	model:SetAttribute("OwnerUserId", garden.player.UserId)
	model.Parent = garden.plot.plantsFolder
	garden.propViews[entry.id] = { model = model, label = label, entry = entry }
end

local function removeProp(garden, propId: number)
	local props = garden.data.props
	for i = #props, 1, -1 do
		if props[i].id == propId then
			table.remove(props, i)
		end
	end
	local view = garden.propViews[propId]
	if view then
		view.model:Destroy()
		garden.propViews[propId] = nil
	end
end

local hatchEgg: (Player, any, any) -> ()

local function updateEggView(garden, view, now: number)
	local remaining = view.entry.t - now
	local text
	if remaining > 0 then
		text = view.egg.name .. "\n" .. Formulas.formatTime(remaining)
	else
		text = view.egg.name .. "\nPronto para chocar!"
		if not view.prompt then
			local target = primaryOf(view.model)
			if target then
				local prompt = makePrompt(target, "Chocar", view.egg.name, garden.player.UserId, "Hatch")
				prompt.Triggered:Connect(function(who)
					hatchEgg(who, garden, view)
				end)
				view.prompt = prompt
			end
		end
	end
	if view.label.Text ~= text then
		view.label.Text = text
	end
end

local function createEggView(garden, entry)
	local egg = Config.Eggs[entry.e]
	if not egg then
		return
	end
	local model, label = Visuals.buildEgg(egg)
	model:PivotTo(garden.plot.cframe * CFrame.new(entry.x, groundHeight(entry.x, entry.z), entry.z))
	model:SetAttribute("OwnerUserId", garden.player.UserId)
	model.Parent = garden.plot.plantsFolder
	local view = { entry = entry, egg = egg, model = model, label = label, prompt = nil, destroyed = false }
	garden.eggViews[entry.id] = view
	updateEggView(garden, view, os.time())
end

local function removeEgg(garden, eggId: number)
	local eggs = garden.data.placedEggs
	for i = #eggs, 1, -1 do
		if eggs[i].id == eggId then
			table.remove(eggs, i)
		end
	end
	local view = garden.eggViews[eggId]
	if view then
		view.destroyed = true
		view.model:Destroy()
		garden.eggViews[eggId] = nil
	end
end

hatchEgg = function(player: Player, garden, view)
	if player ~= garden.player or gardens[player] ~= garden or view.destroyed then
		return
	end
	if os.time() < view.entry.t then
		return
	end
	local data = garden.data
	if #data.pets >= Config.MaxPetsOwned then
		Sync.notify(player, string.format("Você já tem %d pets (máximo).", Config.MaxPetsOwned), "error")
		return
	end
	local pick = Formulas.weightedPick(view.egg.pets, rng)
	local variant = Formulas.weightedPick(Config.PetVariants, rng)
	removeEgg(garden, view.entry.id)
	local pet = PetService.addPet(player, data, pick.pet, if variant.id == "Normal" then nil else variant.id)
	garden.bonuses = nil
	data.stats.hatched += 1
	QuestService.progress(player, "hatch", 1)
	local info = Config.Pets[pick.pet]
	local strength = Formulas.petStrength(pet)
	local abilities = {}
	for _, ability in info.abilities do
		table.insert(abilities, Formulas.abilityText(ability, strength))
	end
	Sync.notify(
		player,
		string.format("🎉 Você chocou: %s (%s)! %s", Formulas.petName(pet), Config.Rarities[info.rarity].name, table.concat(abilities, " • ")),
		"rare"
	)
end

---------------------------------------------------------------------
-- Uso de itens
---------------------------------------------------------------------

local function consume(list, id: string, amount: number)
	list[id] = (list[id] or 0) - amount
	if list[id] <= 0 then
		list[id] = nil
	end
end

local function plantSeed(player: Player, garden, seed, position: any)
	local data = garden.data
	if #data.plants >= Config.MaxPlantsPerGarden then
		Sync.notify(player, string.format("Seu jardim está cheio! (máximo de %d plantas)", Config.MaxPlantsPerGarden), "error")
		return
	end
	local lx, lz = resolvePosition(garden, position, function(x, z)
		return inBeds(x, z) and isFarFromEverything(garden, x, z, Config.MinPlantSpacing, 1.8)
	end)
	if not lx or not lz then
		Sync.notify(player, "Clique em um espaço livre na terra marrom do SEU jardim!", "error")
		return
	end
	consume(data.seeds, seed.id, 1)
	local plant: { [string]: any } = {
		id = data.nextId,
		s = seed.id,
		x = round2(lx),
		z = round2(lz),
		p = os.time(),
		b = 0,
		v = Formulas.rollVariant(seed, rng, luckOf(garden)),
	}
	data.nextId += 1
	if seed.multiHarvest then
		plant.slots = {}
		for i = 1, seed.maxFruits do
			plant.slots[i] = newFruit(garden, plant, seed, seed.growTime + (i - 1) * seed.fruitTime * 0.3)
		end
	else
		plant.f = newFruit(garden, plant, seed, 0)
	end
	table.insert(data.plants, plant)
	data.stats.planted += 1
	QuestService.progress(player, "plant", 1)
	createPlantView(garden, plant)
	Sync.markDirty(player)
	if plant.v then
		Sync.notify(player, "✨ Variante rara! Você plantou: " .. Formulas.fruitName(seed.id, plant.v), "rare")
	end
end

local function nearestPlant(garden, lx: number, lz: number)
	local best, bestDistance = nil, math.huge
	for _, plant in garden.data.plants do
		local seed = Config.Seeds[plant.s]
		local reach = math.max(1.5, seed.height * 0.45)
		local dx, dz = plant.x - lx, plant.z - lz
		local distance = math.sqrt(dx * dx + dz * dz)
		if distance <= reach and distance < bestDistance then
			best, bestDistance = plant, distance
		end
	end
	return best
end

local function nearestProp(garden, lx: number, lz: number)
	local best, bestDistance = nil, 2.5
	for _, prop in garden.data.props do
		local dx, dz = prop.x - lx, prop.z - lz
		local distance = math.sqrt(dx * dx + dz * dz)
		if distance <= bestDistance then
			best, bestDistance = prop, distance
		end
	end
	return best
end

local function useWateringCan(player: Player, garden, gear, position: any)
	local data = garden.data
	local lx, lz = resolvePosition(garden, position, inPlot)
	if not lx or not lz then
		Sync.notify(player, "Use o regador dentro do seu jardim.", "error")
		return
	end
	local now = os.time()
	local count = 0
	local radius2 = gear.radius * gear.radius
	for _, plant in data.plants do
		local dx, dz = plant.x - lx, plant.z - lz
		if dx * dx + dz * dz <= radius2 then
			local seed = Config.Seeds[plant.s]
			local age = plantAge(plant, now)
			local base = if seed.multiHarvest and age >= seed.growTime then seed.fruitTime else seed.growTime
			plant.b += base * gear.boost
			count += 1
			local view = garden.plantViews[plant.id]
			if view then
				updatePlantView(garden, view, now)
			end
		end
	end
	if count == 0 then
		Sync.notify(player, "Nenhuma planta por perto. Regue mais perto das plantas!", "error")
		return
	end
	consume(data.gear, gear.id, 1)
	Visuals.splash(garden.plot.cframe:PointToWorldSpace(Vector3.new(lx, groundHeight(lx, lz) + 0.3, lz)), gear.radius)
	Sync.markDirty(player)
	Sync.notify(player, string.format("💧 %d planta(s) regada(s)!", count), "success")
end

local function useShovel(player: Player, garden, position: any)
	-- primeiro tenta acertar um ladrao para recuperar o fruto roubado
	if GardenService.hooks.bonk and GardenService.hooks.bonk(player) then
		return
	end
	local data = garden.data
	local lx, lz = resolvePosition(garden, position, inPlot)
	if not lx or not lz then
		Sync.notify(player, "Use a pá dentro do seu jardim.", "error")
		return
	end
	local plant = nearestPlant(garden, lx, lz)
	local prop = if plant then nil else nearestProp(garden, lx, lz)
	local target = plant or prop
	if not target then
		Sync.notify(player, "Clique em cima de uma planta (ou lanterna/gnomo) para remover.", "error")
		return
	end
	local name = if plant then Formulas.fruitName(plant.s, plant.v) else Config.Gear[prop.g].name
	local pending = garden.shovelPending
	if pending and pending.id == target.id and os.clock() - pending.t <= 4 then
		garden.shovelPending = nil
		if plant then
			removePlant(garden, plant.id)
		else
			removeProp(garden, prop.id)
		end
		Sync.markDirty(player)
		Sync.notify(player, name .. " removido(a) do jardim.", "info")
	else
		garden.shovelPending = { id = target.id, t = os.clock() }
		Sync.notify(player, "Clique de novo em " .. name .. " para remover (não dá para desfazer)!", "error")
	end
end

local function findRecipe(a: string, b: string)
	for _, recipe in Config.MergeRecipes do
		if (recipe.a == a and recipe.b == b) or (recipe.a == b and recipe.b == a) then
			return recipe
		end
	end
	return nil
end

-- Espatula: 1o clique escolhe a planta; 2o clique move para um lugar vazio
-- ou funde com outra planta (receitas secretas)
local function useTrowel(player: Player, garden, position: any)
	local data = garden.data
	local now = os.time()
	local lx, lz = resolvePosition(garden, position, inPlot)
	if not lx or not lz then
		Sync.notify(player, "Use a espátula dentro do seu jardim.", "error")
		return
	end
	local selected = garden.trowel
	local selectedPlant = nil
	if selected and os.clock() - selected.t <= 15 then
		for _, plant in data.plants do
			if plant.id == selected.id then
				selectedPlant = plant
			end
		end
	end
	local clicked = nearestPlant(garden, lx, lz)
	if not selectedPlant then
		if not clicked then
			Sync.notify(player, "Clique em uma planta para escolher com a espátula.", "error")
			return
		end
		garden.trowel = { id = clicked.id, t = os.clock() }
		Sync.notify(player, string.format("Espátula: %s escolhida. Clique num lugar vazio para mover ou em outra planta para tentar uma fusão.", Formulas.fruitName(clicked.s, clicked.v)), "info")
		return
	end
	garden.trowel = nil
	if clicked and clicked.id ~= selectedPlant.id then
		local recipe = findRecipe(selectedPlant.s, clicked.s)
		local seedA, seedB = Config.Seeds[selectedPlant.s], Config.Seeds[clicked.s]
		if not recipe then
			Sync.notify(player, string.format("%s e %s não se fundem.", seedA.name, seedB.name), "error")
			return
		end
		if plantAge(selectedPlant, now) < seedA.growTime or plantAge(clicked, now) < seedB.growTime then
			Sync.notify(player, "As duas plantas precisam estar adultas para a fusão!", "error")
			return
		end
		local result = Config.Seeds[recipe.result]
		local x, z = clicked.x, clicked.z
		removePlant(garden, selectedPlant.id)
		removePlant(garden, clicked.id)
		local plant: { [string]: any } = { id = data.nextId, s = result.id, x = x, z = z, p = now, b = result.growTime }
		data.nextId += 1
		plant.slots = {}
		for i = 1, result.maxFruits do
			plant.slots[i] = newFruit(garden, plant, result, result.growTime + (i - 1) * result.fruitTime * 0.3)
		end
		table.insert(data.plants, plant)
		data.stats.merged += 1
		createPlantView(garden, plant)
		Visuals.ring(garden.plot.cframe:PointToWorldSpace(Vector3.new(x, L.bedTop + 1, z)), result.fruitColor, 6)
		Sync.markDirty(player)
		Sync.notify(player, string.format("✨ FUSÃO SECRETA! %s + %s = %s!", seedA.name, seedB.name, result.name), "rare")
		return
	end
	if not inBeds(lx, lz) or not isFarFromEverything(garden, lx, lz, Config.MinPlantSpacing, 1.8, selectedPlant.id) then
		Sync.notify(player, "Esse lugar não está livre na terra do jardim.", "error")
		return
	end
	selectedPlant.x = round2(lx)
	selectedPlant.z = round2(lz)
	destroyPlantView(garden, selectedPlant.id)
	createPlantView(garden, selectedPlant)
	Sync.notify(player, Formulas.fruitName(selectedPlant.s, selectedPlant.v) .. " foi movida!", "success")
end

local function placeSprinkler(player: Player, garden, gear, position: any)
	local data = garden.data
	if #data.sprinklers >= Config.MaxSprinklersPerGarden then
		Sync.notify(player, string.format("Máximo de %d sprinklers ativos.", Config.MaxSprinklersPerGarden), "error")
		return
	end
	local lx, lz = resolvePosition(garden, position, inPlot)
	if not lx or not lz then
		Sync.notify(player, "Coloque o sprinkler dentro do seu jardim.", "error")
		return
	end
	consume(data.gear, gear.id, 1)
	local entry = { id = data.nextId, g = gear.id, x = round2(lx), z = round2(lz), t = os.time() + gear.duration }
	data.nextId += 1
	table.insert(data.sprinklers, entry)
	createSprinklerView(garden, entry)
	Sync.markDirty(player)
	Sync.notify(player, string.format("%s colocado! Dura %s.", gear.name, Formulas.formatTime(gear.duration)), "success")
end

local function placeProp(player: Player, garden, gear, position: any)
	local data = garden.data
	local count = 0
	for _, prop in data.props do
		if prop.g == gear.id then
			count += 1
		end
	end
	if count >= (gear.maxPlaced or 4) then
		Sync.notify(player, string.format("Máximo de %d %s no jardim.", gear.maxPlaced or 4, gear.name), "error")
		return
	end
	local lx, lz = resolvePosition(garden, position, function(x, z)
		return inPlot(x, z) and isFarFromEverything(garden, x, z, 1.4, 2)
	end)
	if not lx or not lz then
		Sync.notify(player, "Coloque em um espaço livre do seu jardim.", "error")
		return
	end
	consume(data.gear, gear.id, 1)
	local entry: { [string]: any } = { id = data.nextId, g = gear.id, x = round2(lx), z = round2(lz) }
	if gear.duration then
		entry.t = os.time() + gear.duration
	end
	data.nextId += 1
	table.insert(data.props, entry)
	createPropView(garden, entry)
	Sync.markDirty(player)
	if gear.kind == "gnome" then
		Sync.notify(player, string.format("🧙 Gnomo protegendo seu jardim por %s!", Formulas.formatTime(gear.duration)), "success")
	else
		Sync.notify(player, gear.name .. " colocada!", "success")
	end
end

local function placeEgg(player: Player, garden, egg, position: any)
	local data = garden.data
	if #data.placedEggs >= Config.MaxEggsPerGarden then
		Sync.notify(player, string.format("Máximo de %d ovos chocando ao mesmo tempo.", Config.MaxEggsPerGarden), "error")
		return
	end
	local lx, lz = resolvePosition(garden, position, function(x, z)
		return inPlot(x, z) and isFarFromEverything(garden, x, z, 1.8, 2.5)
	end)
	if not lx or not lz then
		Sync.notify(player, "Coloque o ovo em um espaço livre do seu jardim.", "error")
		return
	end
	consume(data.eggs, egg.id, 1)
	local entry = { id = data.nextId, e = egg.id, x = round2(lx), z = round2(lz), t = os.time() + egg.hatchTime }
	data.nextId += 1
	table.insert(data.placedEggs, entry)
	createEggView(garden, entry)
	Sync.markDirty(player)
	Sync.notify(player, string.format("🥚 %s vai chocar em %s.", egg.name, Formulas.formatTime(egg.hatchTime)), "success")
end

function GardenService.useItem(player: Player, kind: any, id: any, position: any)
	local garden = gardens[player]
	if not garden or type(kind) ~= "string" or type(id) ~= "string" then
		return
	end
	local clock = os.clock()
	if clock - garden.lastUse < 0.12 then
		return
	end
	garden.lastUse = clock
	local data = garden.data
	if kind == "Seed" then
		local seed = Config.Seeds[id]
		if seed and (data.seeds[id] or 0) > 0 then
			plantSeed(player, garden, seed, position)
		end
	elseif kind == "Gear" then
		local gear = Config.Gear[id]
		if not gear or (data.gear[id] or 0) <= 0 then
			return
		end
		if gear.kind == "water" then
			useWateringCan(player, garden, gear, position)
		elseif gear.kind == "shovel" then
			useShovel(player, garden, position)
		elseif gear.kind == "trowel" then
			useTrowel(player, garden, position)
		elseif gear.kind == "sprinkler" then
			placeSprinkler(player, garden, gear, position)
		elseif gear.kind == "lantern" or gear.kind == "gnome" then
			placeProp(player, garden, gear, position)
		elseif gear.kind == "consumable" then
			if GardenService.hooks.consume and GardenService.hooks.consume(player, gear) then
				consume(data.gear, gear.id, 1)
				Sync.markDirty(player)
			end
		elseif gear.kind == "sniper" then
			if GardenService.hooks.snipe then
				GardenService.hooks.snipe(player, gear, if isValidVector(position) then position else nil)
			end
		end
	elseif kind == "Egg" then
		local egg = Config.Eggs[id]
		if egg and (data.eggs[id] or 0) > 0 then
			placeEgg(player, garden, egg, position)
		end
	end
end

---------------------------------------------------------------------
-- Clima e ciclo do dia (chamado pelos outros servicos)
---------------------------------------------------------------------

function GardenService.setWeatherEffects(effects)
	weather.growthBonus = effects.growthBonus or 0
	weather.goldBoost = effects.goldBoost or 1
	weather.rainbowBoost = effects.rainbowBoost or 1
	weather.sizeBoost = effects.sizeBoost or 0
end

function GardenService.setPhase(newPhase: string, index: number)
	phase = newPhase
	nightIndex = index
end

function GardenService.applyWeatherMutation(mutationId: string, chance: number)
	local now = os.time()
	for _, garden in gardens do
		local luck = luckOf(garden)
		for _, plant in garden.data.plants do
			applyChanceToPlant(plant, mutationId, chance * (1 + luck), now)
		end
	end
end

-- Algo cai em um fruto aleatorio (raio, meteoro, estrela, tornado). Retorna a posicao.
function GardenService.strikeRandomFruit(mutationId: string): Vector3?
	local now = os.time()
	local candidates = {}
	for _, garden in gardens do
		for _, plant in garden.data.plants do
			forEachVisibleFruit(plant, now, function(list)
				table.insert(candidates, { garden = garden, plant = plant, list = list })
			end)
		end
	end
	if #candidates == 0 then
		return nil
	end
	local pick = candidates[rng:NextInteger(1, #candidates)]
	local seed = Config.Seeds[pick.plant.s]
	if Formulas.addMutation(pick.list, mutationId) then
		local mutation = Config.Mutations[mutationId]
		Sync.notify(pick.garden.player, string.format("✨ Um fruto de %s ficou %s!", seed.name, mutation.name), "rare")
	end
	return pick.garden.plot.cframe:PointToWorldSpace(Vector3.new(pick.plant.x, L.bedTop + seed.height * 0.6, pick.plant.z))
end

---------------------------------------------------------------------
-- Atualizacao periodica
---------------------------------------------------------------------

local function petAbilities(garden, bonuses, dt: number, now: number)
	local player = garden.player
	local data = garden.data
	garden.petTimers = garden.petTimers or {}
	for _, ability in bonuses.active do
		if ability.kind == "AutoHarvest" or ability.kind == "AutoHarvestBest" then
			local key = ability.petUid .. ability.kind
			garden.petTimers[key] = (garden.petTimers[key] or 0) + dt
			if garden.petTimers[key] >= ability.cooldown then
				garden.petTimers[key] = 0
				local ripe = ripeFruits(garden, now)
				if #ripe > 0 then
					local pick = ripe[rng:NextInteger(1, #ripe)]
					if ability.kind == "AutoHarvestBest" then
						for _, candidate in ripe do
							if candidate.value > pick.value then
								pick = candidate
							end
						end
					end
					local seedId = pick.view.seed.id
					local petName = Config.Pets[ability.petId].name
					local fruit = ownerHarvest(garden, pick.view, pick.slot, "🐾 " .. petName)
					if fruit and ability.seedChance and rng:NextNumber() < ability.seedChance and Config.Seeds[seedId].inShop then
						data.seeds[seedId] = (data.seeds[seedId] or 0) + 1
						Sync.notify(player, string.format("🐾 %s achou uma semente de %s!", petName, Config.Seeds[seedId].name), "rare")
					end
				end
			end
		elseif ability.kind == "Raccoon" and phase == "Night" and garden.raccoonNight ~= nightIndex then
			garden.raccoonNight = nightIndex
			local options = {}
			for _, other in gardens do
				if other ~= garden then
					for _, item in ripeFruits(other, now) do
						table.insert(options, item)
					end
				end
			end
			if #options > 0 then
				local pick = options[rng:NextInteger(1, #options)]
				local plant, seed = pick.view.plant, pick.view.seed
				local source = if pick.slot then plant.slots[pick.slot] else plant.f
				local copy = { s = seed.id, w = source.w, m = table.clone(source.m), v = plant.v }
				if GardenService.addFruit(player, copy) then
					Sync.notify(player, "🦝 Seu Guaxinim trouxe um fruto de outro jardim: " .. fruitLabel(seed, copy.w, copy.m, copy.v), "rare")
				end
			end
		end
	end
end

local function tickGarden(garden, dt: number, now: number)
	local data = garden.data
	local bonuses = Formulas.petBonuses(data.pets, data.equippedPets)
	garden.bonuses = bonuses
	local night = phase == "Night"
	local luck = bonuses.Luck + (if night then bonuses.NightLuck else 0)
	local baseRate = weather.growthBonus + bonuses.Growth

	local activeSprinklers = {}
	for i = #data.sprinklers, 1, -1 do
		local entry = data.sprinklers[i]
		local gear = Config.Gear[entry.g]
		if not gear or now >= entry.t then
			table.remove(data.sprinklers, i)
			local model = garden.sprinklerViews[entry.id]
			if model then
				model:Destroy()
			end
			garden.sprinklerViews[entry.id] = nil
			if gear then
				Sync.notify(garden.player, gear.name .. " acabou.", "info")
			end
		else
			table.insert(activeSprinklers, entry)
		end
	end

	local lanterns = {}
	for i = #data.props, 1, -1 do
		local entry = data.props[i]
		local gear = Config.Gear[entry.g]
		if entry.t and now >= entry.t then
			removeProp(garden, entry.id)
			Sync.notify(garden.player, gear.name .. " foi embora. Seu jardim está desprotegido!", "error")
		elseif gear.kind == "lantern" then
			table.insert(lanterns, { entry = entry, gear = gear })
		elseif entry.t then
			local view = garden.propViews[entry.id]
			if view and view.label then
				local text = gear.name .. "\n🛡️ " .. Formulas.formatTime(entry.t - now)
				if view.label.Text ~= text then
					view.label.Text = text
				end
			end
		end
	end

	local glowSources = {}
	if night then
		for _, plant in data.plants do
			local seed = Config.Seeds[plant.s]
			local aura = seed.special and seed.special.glowAura
			if aura and plantAge(plant, now) >= seed.growTime then
				table.insert(glowSources, { plant = plant, aura = aura })
			end
		end
	end

	for _, plant in data.plants do
		local seed = Config.Seeds[plant.s]
		local special = seed.special or {}
		local rate = baseRate
		local wetChance = 0
		for _, entry in activeSprinklers do
			local gear = Config.Gear[entry.g]
			local dx, dz = plant.x - entry.x, plant.z - entry.z
			if dx * dx + dz * dz <= gear.radius * gear.radius then
				rate += gear.growth
				wetChance += gear.wetChance
			end
		end
		if night then
			for _, lantern in lanterns do
				local dx, dz = plant.x - lantern.entry.x, plant.z - lantern.entry.z
				if dx * dx + dz * dz <= lantern.gear.radius * lantern.gear.radius then
					rate += lantern.gear.nightGrowth
				end
			end
			rate += (special.nightGrowth or 1) - 1
		else
			rate += (special.dayGrowth or 1) - 1
		end
		rate = math.max(rate, -0.9)
		if rate ~= 0 then
			plant.b += dt * rate
		end
		local factor = dt * (1 + luck)
		if wetChance > 0 then
			applyChanceToPlant(plant, "Wet", wetChance * factor, now)
		end
		if bonuses.Pollinate > 0 then
			applyChanceToPlant(plant, "Pollinated", bonuses.Pollinate * factor, now)
		end
		if bonuses.Ignite > 0 then
			applyChanceToPlant(plant, "Ignited", bonuses.Ignite * factor, now)
		end
		for _, source in glowSources do
			if source.plant ~= plant then
				local dx, dz = plant.x - source.plant.x, plant.z - source.plant.z
				if dx * dx + dz * dz <= source.aura.radius * source.aura.radius then
					applyChanceToPlant(plant, source.aura.mutation, source.aura.chance * factor, now)
				end
			end
		end
		local view = garden.plantViews[plant.id]
		if view then
			updatePlantView(garden, view, now)
		end
	end

	for _, view in garden.eggViews do
		updateEggView(garden, view, now)
	end

	petAbilities(garden, bonuses, dt, now)
	PetService.addXp(garden.player, data, dt)
end

---------------------------------------------------------------------
-- Jardins dos jogadores
---------------------------------------------------------------------

function GardenService.init(map)
	plots = map.plots
end

function GardenService.assignPlot(player: Player, data): boolean
	for _, plot in plots do
		if not plot.owner then
			plot.owner = player
			plot.model:SetAttribute("OwnerUserId", player.UserId)
			plot.model:SetAttribute("Locked", false)
			plot.signLabel.Text = "Jardim de " .. player.DisplayName
			local garden = {
				player = player,
				data = data,
				plot = plot,
				plantViews = {},
				sprinklerViews = {},
				propViews = {},
				eggViews = {},
				shovelPending = nil,
				trowel = nil,
				lastUse = 0,
				bonuses = nil,
				petTimers = {},
				raccoonNight = -1,
			}
			gardens[player] = garden
			player:SetAttribute("PlotIndex", plot.index)
			for _, plant in data.plants do
				createPlantView(garden, plant)
			end
			for _, entry in data.sprinklers do
				createSprinklerView(garden, entry)
			end
			for _, entry in data.props do
				createPropView(garden, entry)
			end
			for _, entry in data.placedEggs do
				createEggView(garden, entry)
			end
			return true
		end
	end
	return false
end

function GardenService.releasePlot(player: Player)
	local garden = gardens[player]
	if not garden then
		return
	end
	gardens[player] = nil
	for _, view in garden.plantViews do
		view.destroyed = true
		if view.body then
			view.body:Destroy()
		end
	end
	for _, view in garden.eggViews do
		view.destroyed = true
	end
	local plot = garden.plot
	plot.plantsFolder:ClearAllChildren()
	plot.owner = nil
	plot.model:SetAttribute("OwnerUserId", 0)
	plot.model:SetAttribute("Locked", false)
	plot.signLabel.Text = "Jardim Livre"
end

function GardenService.getGarden(player: Player)
	return gardens[player]
end

function GardenService.getGardens()
	return gardens
end

function GardenService.getGardenCFrame(player: Player): CFrame?
	local garden = gardens[player]
	return if garden then garden.plot.spawnCFrame else nil
end

-- Posicao do lado de fora do portao do jardim (para expulsar ladroes)
function GardenService.outsideCFrame(garden): CFrame
	return garden.plot.cframe * CFrame.new(0, 3, -L.plotHalfZ - 7) * CFrame.Angles(0, math.pi, 0)
end

function GardenService.isInside(garden, position: Vector3): boolean
	local localPos = garden.plot.cframe:PointToObjectSpace(position)
	return math.abs(localPos.X) <= L.plotHalfX and math.abs(localPos.Z) <= L.plotHalfZ
end

function GardenService.hasActiveGnome(garden): boolean
	local now = os.time()
	for _, prop in garden.data.props do
		local gear = Config.Gear[prop.g]
		if gear and gear.kind == "gnome" and prop.t and prop.t > now then
			return true
		end
	end
	return false
end

-- Lanternas do jardim em coordenadas do mundo
function GardenService.lanterns(garden): { { position: Vector3, radius: number } }
	local list = {}
	for _, prop in garden.data.props do
		local gear = Config.Gear[prop.g]
		if gear and gear.kind == "lantern" then
			table.insert(list, { position = garden.plot.cframe:PointToWorldSpace(Vector3.new(prop.x, 2, prop.z)), radius = gear.radius })
		end
	end
	return list
end

-- Plantas de defesa adultas: { {seed, defense, position, plantId} }
function GardenService.defenses(garden): { any }
	local list = {}
	local now = os.time()
	for _, plant in garden.data.plants do
		local seed = Config.Seeds[plant.s]
		if seed and seed.defense and plantAge(plant, now) >= seed.growTime then
			table.insert(list, {
				seed = seed,
				defense = seed.defense,
				plantId = plant.id,
				position = garden.plot.cframe:PointToWorldSpace(Vector3.new(plant.x, L.bedTop + seed.height * 0.6, plant.z)),
			})
		end
	end
	return list
end

function GardenService.bonuses(player: Player)
	local garden = gardens[player]
	if garden then
		return bonusesOf(garden)
	end
	return nil
end

function GardenService.invalidateBonuses(player: Player)
	local garden = gardens[player]
	if garden then
		garden.bonuses = nil
	end
end

-- Comando de teste: faz todas as plantas crescerem
function GardenService.growAll(player: Player)
	local garden = gardens[player]
	if not garden then
		return
	end
	for _, plant in garden.data.plants do
		local seed = Config.Seeds[plant.s]
		plant.b += seed.growTime + (seed.fruitTime or 0) * (seed.maxFruits or 1)
	end
	for _, entry in garden.data.placedEggs do
		entry.t = os.time()
	end
end

function GardenService.start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.5 then
			return
		end
		local step = math.min(accumulator, 5)
		accumulator = 0
		local now = os.time()
		for _, garden in gardens do
			local ok, err = pcall(tickGarden, garden, step, now)
			if not ok then
				warn("[Jardim] Erro ao atualizar jardim: " .. tostring(err))
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		GardenService.releasePlot(player)
	end)
end

return GardenService
