-- GardenService: jardins dos jogadores, plantio, crescimento, colheita,
-- regador, pa, sprinklers e ovos.
--
-- O crescimento usa os.time(), entao as plantas continuam crescendo
-- mesmo com o jogador offline.
--   idade da planta = agora - plantadaEm + bonus
-- Chuva, sprinklers, regador e pets aumentam o "bonus".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local MapBuilder = require(script.Parent.MapBuilder)
local PetService = require(script.Parent.PetService)
local Sync = require(script.Parent.Sync)
local Visuals = require(script.Parent.Visuals)

local GardenService = {}

local L = MapBuilder.Layout
local rng = Random.new()
local plots = {}
local gardens: { [Player]: any } = {}
local weatherGrowth = 0

local function round2(n: number): number
	return math.floor(n * 100 + 0.5) / 100
end

local function plantAge(plant, now: number): number
	return now - plant.p + plant.b
end

local function weightScale(seed, weight: number): number
	return math.clamp((weight / seed.baseWeight) ^ (1 / 3), 0.7, 1.8)
end

local function newSlot(seed, luck: number, startAge: number)
	return {
		a = startAge,
		w = Formulas.rollWeight(seed, rng),
		m = Formulas.rollGrowthMutations(rng, luck),
	}
end

local function fruitLabel(seed, weight: number, mutations: { string }): string
	local text = string.format("%s (%s)", seed.name, Formulas.formatWeight(weight))
	local names = Formulas.mutationNames(mutations)
	if names ~= "" then
		text = "[" .. names .. "] " .. text
	end
	return text
end

local function makePrompt(parent: Instance, action: string, objectText: string, ownerId: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("OwnerUserId", ownerId)
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

-- Converte a posicao clicada para coordenadas locais do jardim.
-- Se o clique for invalido, tenta a posicao na frente do personagem.
local function resolvePosition(garden, position: any, check: (number, number) -> boolean): (number?, number?)
	if isValidVector(position) then
		local localPos = garden.plot.cframe:PointToObjectSpace(position)
		if check(localPos.X, localPos.Z) then
			return localPos.X, localPos.Z
		end
	end
	local character = garden.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local front = root.Position + root.CFrame.LookVector * 2.5
		local localPos = garden.plot.cframe:PointToObjectSpace(front)
		if check(localPos.X, localPos.Z) then
			return localPos.X, localPos.Z
		end
	end
	return nil, nil
end

local function isFarFromEverything(garden, lx: number, lz: number, plantSpacing: number, eggSpacing: number): boolean
	local plantMin = plantSpacing * plantSpacing
	for _, plant in garden.data.plants do
		local dx, dz = plant.x - lx, plant.z - lz
		if dx * dx + dz * dz < plantMin then
			return false
		end
	end
	local eggMin = eggSpacing * eggSpacing
	for _, egg in garden.data.placedEggs do
		local dx, dz = egg.x - lx, egg.z - lz
		if dx * dx + dz * dz < eggMin then
			return false
		end
	end
	return true
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

---------------------------------------------------------------------
-- Visual das plantas
---------------------------------------------------------------------

local harvest: (Player, any, any, number?) -> ()

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
	local offset = view.offsets[index] or Vector3.new(0, seed.height * 0.5, 0)
	model:PivotTo(view.baseCF * CFrame.new(offset))
	model:SetAttribute("Weight", slot.w)
	model.Parent = view.container
	local fruitView = { model = model, step = -1, signature = nil, prompt = nil, slot = slot }
	view.fruits[index] = fruitView
	return fruitView
end

local function updatePlantView(garden, view, now: number)
	local plant, seed = view.plant, view.seed
	local age = plantAge(plant, now)
	local growth = math.clamp(age / seed.growTime, 0, 1)
	local step = math.floor(growth * 20)
	if step ~= view.scaleStep then
		view.scaleStep = step
		local scale = 0.15 + 0.85 * step / 20
		if not seed.multiHarvest then
			scale *= weightScale(seed, plant.f.w)
		end
		view.body:ScaleTo(scale)
		view.container:SetAttribute("Progress", step * 5)
	end

	if not seed.multiHarvest then
		local signature = table.concat(plant.f.m, ",")
		if signature ~= view.signature then
			view.signature = signature
			Visuals.applyMutations(Visuals.produceParts(view.body), plant.f.m)
			view.container:SetAttribute("Mutations", Formulas.mutationNames(plant.f.m))
			if view.prompt then
				view.prompt.ObjectText = fruitLabel(seed, plant.f.w, plant.f.m)
			end
		end
		if growth >= 1 and not view.prompt then
			local target = Visuals.produceParts(view.body)[1] or primaryOf(view.body)
			if target then
				local prompt = makePrompt(target, "Colher", fruitLabel(seed, plant.f.w, plant.f.m), garden.player.UserId)
				prompt.Triggered:Connect(function(who)
					harvest(who, garden, view, nil)
				end)
				view.prompt = prompt
				view.container:SetAttribute("Ripe", true)
			end
		end
		return
	end

	if growth < 1 then
		return
	end
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
			local fruitStep = math.floor(math.clamp(progress, 0, 1) * 10)
			if fruitStep ~= fruitView.step then
				fruitView.step = fruitStep
				fruitView.model:ScaleTo(weightScale(seed, slot.w) * (0.25 + 0.75 * fruitStep / 10))
			end
			local signature = table.concat(slot.m, ",")
			if signature ~= fruitView.signature then
				fruitView.signature = signature
				Visuals.applyMutations(Visuals.produceParts(fruitView.model), slot.m)
				fruitView.model:SetAttribute("Mutations", Formulas.mutationNames(slot.m))
				if fruitView.prompt then
					fruitView.prompt.ObjectText = fruitLabel(seed, slot.w, slot.m)
				end
			end
			if progress >= 1 and not fruitView.prompt then
				local target = primaryOf(fruitView.model)
				if target then
					local slotIndex = index
					local prompt = makePrompt(target, "Colher", fruitLabel(seed, slot.w, slot.m), garden.player.UserId)
					prompt.Triggered:Connect(function(who)
						harvest(who, garden, view, slotIndex)
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
	container.Name = seed.name
	container:SetAttribute("PlantId", plant.id)
	container:SetAttribute("SeedId", seed.id)
	container:SetAttribute("OwnerUserId", garden.player.UserId)
	if not seed.multiHarvest then
		container:SetAttribute("Weight", plant.f.w)
	end
	local body = Visuals.buildPlant(seed)
	body.Parent = container
	body:PivotTo(baseCF)
	container.Parent = plot.plantsFolder
	local view = {
		plant = plant,
		seed = seed,
		container = container,
		body = body,
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

harvest = function(player: Player, garden, view, slotIndex: number?)
	if player ~= garden.player or gardens[player] ~= garden or view.destroyed then
		return
	end
	local data = garden.data
	if #data.fruits >= Config.MaxFruitsInInventory then
		Sync.notify(player, "Sua mochila está cheia! Venda seus frutos para o Steven.", "error")
		return
	end
	local seed, plant = view.seed, view.plant
	local now = os.time()
	local age = plantAge(plant, now)
	local fruit
	if slotIndex == nil then
		if age < seed.growTime then
			return
		end
		fruit = { s = seed.id, w = plant.f.w, m = table.clone(plant.f.m) }
		removePlant(garden, plant.id)
	else
		local slot = plant.slots[slotIndex]
		if not slot or age - slot.a < seed.fruitTime then
			return
		end
		fruit = { s = seed.id, w = slot.w, m = table.clone(slot.m) }
		local luck = PetService.getBonuses(data).Luck
		plant.slots[slotIndex] = newSlot(seed, luck, age)
		destroyFruitView(view, slotIndex)
	end
	table.insert(data.fruits, fruit)
	data.stats.harvested += 1
	Sync.markDirty(player)
	Sync.notify(player, "+ " .. fruitLabel(seed, fruit.w, fruit.m), if #fruit.m > 0 then "rare" else "success")
end

---------------------------------------------------------------------
-- Sprinklers e ovos
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
				local prompt = makePrompt(target, "Chocar", view.egg.name, garden.player.UserId)
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
	local info = Config.Pets[pick.pet]
	removeEgg(garden, view.entry.id)
	PetService.addPet(player, data, info.id)
	Sync.notify(
		player,
		string.format("🎉 Você chocou: %s! (%s +%s)", info.name, Config.PetBonusNames[info.bonusType], Formulas.formatPercent(info.bonus)),
		"rare"
	)
end

---------------------------------------------------------------------
-- Uso de itens (sementes, regador, pa, sprinklers, ovos)
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
	local luck = PetService.getBonuses(data).Luck
	local plant: { [string]: any } = { id = data.nextId, s = seed.id, x = round2(lx), z = round2(lz), p = os.time(), b = 0 }
	data.nextId += 1
	if seed.multiHarvest then
		plant.slots = {}
		for i = 1, seed.maxFruits do
			plant.slots[i] = newSlot(seed, luck, seed.growTime + (i - 1) * seed.fruitTime * 0.3)
		end
	else
		plant.f = { w = Formulas.rollWeight(seed, rng), m = Formulas.rollGrowthMutations(rng, luck) }
	end
	table.insert(data.plants, plant)
	data.stats.planted += 1
	createPlantView(garden, plant)
	Sync.markDirty(player)
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
	local data = garden.data
	local lx, lz = resolvePosition(garden, position, inPlot)
	if not lx or not lz then
		Sync.notify(player, "Use a pá dentro do seu jardim.", "error")
		return
	end
	local best, bestDistance = nil, math.huge
	for _, plant in data.plants do
		local seed = Config.Seeds[plant.s]
		local reach = math.max(1.5, seed.height * 0.45)
		local dx, dz = plant.x - lx, plant.z - lz
		local distance = math.sqrt(dx * dx + dz * dz)
		if distance <= reach and distance < bestDistance then
			best, bestDistance = plant, distance
		end
	end
	if not best then
		Sync.notify(player, "Clique em cima de uma planta para removê-la.", "error")
		return
	end
	local seed = Config.Seeds[best.s]
	local pending = garden.shovelPending
	if pending and pending.id == best.id and os.clock() - pending.t <= 4 then
		garden.shovelPending = nil
		removePlant(garden, best.id)
		Sync.markDirty(player)
		Sync.notify(player, seed.name .. " removida do jardim.", "info")
	else
		garden.shovelPending = { id = best.id, t = os.clock() }
		Sync.notify(player, "Clique de novo em " .. seed.name .. " para remover (não dá para desfazer)!", "error")
	end
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
		elseif gear.kind == "sprinkler" then
			placeSprinkler(player, garden, gear, position)
		end
	elseif kind == "Egg" then
		local egg = Config.Eggs[id]
		if egg and (data.eggs[id] or 0) > 0 then
			placeEgg(player, garden, egg, position)
		end
	end
end

---------------------------------------------------------------------
-- Clima (chamado pelo WeatherService)
---------------------------------------------------------------------

function GardenService.setWeatherGrowth(bonus: number)
	weatherGrowth = bonus
end

function GardenService.applyWeatherMutation(mutationId: string, chance: number)
	local now = os.time()
	for _, garden in gardens do
		local luck = PetService.getBonuses(garden.data).Luck
		for _, plant in garden.data.plants do
			applyChanceToPlant(plant, mutationId, chance * (1 + luck), now)
		end
	end
end

-- Um raio cai em um fruto aleatorio. Retorna a posicao do raio.
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
		Sync.notify(pick.garden.player, "⚡ Um raio Eletrizou um fruto de " .. seed.name .. "!", "rare")
	end
	return pick.garden.plot.cframe:PointToWorldSpace(Vector3.new(pick.plant.x, L.bedTop + seed.height * 0.6, pick.plant.z))
end

---------------------------------------------------------------------
-- Atualizacao periodica
---------------------------------------------------------------------

local function tickGarden(garden, dt: number, now: number)
	local data = garden.data
	local bonuses = PetService.getBonuses(data)
	local baseRate = weatherGrowth + bonuses.Growth

	local active = {}
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
			table.insert(active, entry)
		end
	end

	for _, plant in data.plants do
		local rate = baseRate
		local wetChance = 0
		for _, entry in active do
			local gear = Config.Gear[entry.g]
			local dx, dz = plant.x - entry.x, plant.z - entry.z
			if dx * dx + dz * dz <= gear.radius * gear.radius then
				rate += gear.growth
				wetChance += gear.wetChance
			end
		end
		if rate > 0 then
			plant.b += dt * rate
		end
		if wetChance > 0 then
			applyChanceToPlant(plant, "Wet", wetChance * dt * (1 + bonuses.Luck), now)
		end
		local view = garden.plantViews[plant.id]
		if view then
			updatePlantView(garden, view, now)
		end
	end

	for _, view in garden.eggViews do
		updateEggView(garden, view, now)
	end
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
			plot.signLabel.Text = "Jardim de " .. player.DisplayName
			local garden = {
				player = player,
				data = data,
				plot = plot,
				plantViews = {},
				sprinklerViews = {},
				eggViews = {},
				shovelPending = nil,
				lastUse = 0,
			}
			gardens[player] = garden
			player:SetAttribute("PlotIndex", plot.index)
			for _, plant in data.plants do
				createPlantView(garden, plant)
			end
			for _, entry in data.sprinklers do
				createSprinklerView(garden, entry)
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
	end
	for _, view in garden.eggViews do
		view.destroyed = true
	end
	local plot = garden.plot
	plot.plantsFolder:ClearAllChildren()
	plot.owner = nil
	plot.model:SetAttribute("OwnerUserId", 0)
	plot.signLabel.Text = "Jardim Livre"
end

function GardenService.getGardenCFrame(player: Player): CFrame?
	local garden = gardens[player]
	return if garden then garden.plot.spawnCFrame else nil
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
