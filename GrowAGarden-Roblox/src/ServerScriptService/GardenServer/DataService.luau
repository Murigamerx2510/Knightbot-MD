-- DataService: carrega e salva o progresso dos jogadores com DataStore.
-- Se o DataStore nao estiver disponivel (ex.: Studio sem acesso a API),
-- o jogo continua funcionando, apenas sem salvar.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DataService = {}

type Profile = {
	data: { [string]: any },
	key: string,
	canSave: boolean,
	saving: boolean,
	userId: number,
}

local profiles: { [Player]: Profile } = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[Jardim] DataStore indisponível, o progresso não será salvo: " .. tostring(result))
	end
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

function DataService.defaultData()
	return {
		version = 1,
		sheckles = Config.StartingSheckles,
		seeds = deepCopy(Config.StartingSeeds),
		gear = {},
		eggs = {},
		fruits = {},
		plants = {},
		sprinklers = {},
		placedEggs = {},
		pets = {},
		equippedPets = {},
		stock = { window = -1, seeds = {}, gear = {}, eggs = {} },
		nextId = 1,
		stats = { harvested = 0, earned = 0, planted = 0 },
	}
end

-- Garante que dados antigos tenham todos os campos novos
-- e remove itens que nao existem mais na Config.
local function reconcile(data)
	local template = DataService.defaultData()
	for key, value in template do
		if data[key] == nil or type(data[key]) ~= type(value) then
			data[key] = deepCopy(value)
		end
	end
	for _, key in { "stock", "stats" } do
		for subKey, value in template[key] do
			if data[key][subKey] == nil then
				data[key][subKey] = deepCopy(value)
			end
		end
	end
	for _, key in { "seeds", "gear", "eggs" } do
		for id, count in data[key] do
			if type(count) ~= "number" or count <= 0 then
				data[key][id] = nil
			end
		end
	end
	for id in data.seeds do
		if not Config.Seeds[id] then
			data.seeds[id] = nil
		end
	end
	for id in data.gear do
		if not Config.Gear[id] then
			data.gear[id] = nil
		end
	end
	for id in data.eggs do
		if not Config.Eggs[id] then
			data.eggs[id] = nil
		end
	end
	for i = #data.plants, 1, -1 do
		local plant = data.plants[i]
		local seed = type(plant) == "table" and Config.Seeds[plant.s]
		local valid = seed
			and type(plant.x) == "number"
			and type(plant.z) == "number"
			and type(plant.p) == "number"
			and (if seed.multiHarvest then type(plant.slots) == "table" else type(plant.f) == "table")
		if not valid then
			table.remove(data.plants, i)
		else
			plant.b = if type(plant.b) == "number" then plant.b else 0
		end
	end
	for i = #data.fruits, 1, -1 do
		local fruit = data.fruits[i]
		if type(fruit) ~= "table" or not Config.Seeds[fruit.s] or type(fruit.w) ~= "number" then
			table.remove(data.fruits, i)
		elseif type(fruit.m) ~= "table" then
			fruit.m = {}
		end
	end
	for i = #data.sprinklers, 1, -1 do
		local sprinkler = data.sprinklers[i]
		if type(sprinkler) ~= "table" or not Config.Gear[sprinkler.g] then
			table.remove(data.sprinklers, i)
		end
	end
	for i = #data.placedEggs, 1, -1 do
		local egg = data.placedEggs[i]
		if type(egg) ~= "table" or not Config.Eggs[egg.e] then
			table.remove(data.placedEggs, i)
		end
	end
	for i = #data.pets, 1, -1 do
		local pet = data.pets[i]
		if type(pet) ~= "table" or not Config.Pets[pet.p] then
			table.remove(data.pets, i)
		end
	end
	-- o maior id em uso define o proximo id livre
	local maxId = 0
	for _, list in { data.plants, data.sprinklers, data.placedEggs, data.pets } do
		for _, item in list do
			if type(item.id) == "number" then
				maxId = math.max(maxId, item.id)
			end
		end
	end
	data.nextId = math.max(data.nextId, maxId + 1)
	return data
end

-- Erro de "Studio sem acesso a API": nao adianta tentar de novo
local function isStudioAccessError(message: string): boolean
	return string.find(message, "StudioAccessToApisNotAllowed", 1, true) ~= nil
		or string.find(message, "403", 1, true) ~= nil
end

-- Carrega os dados do jogador (pode demorar alguns segundos)
function DataService.load(player: Player): ({ [string]: any }, boolean)
	local key = "Jogador_" .. player.UserId
	local data = nil
	local loaded = false
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync(key)
			end)
			if ok then
				data = result
				loaded = true
				break
			end
			warn(string.format("[Jardim] Falha ao carregar dados de %s (tentativa %d): %s", player.Name, attempt, tostring(result)))
			if isStudioAccessError(tostring(result)) then
				break
			end
			task.wait(attempt * 1.5)
		end
	end
	if type(data) == "table" then
		data = reconcile(data)
	else
		data = DataService.defaultData()
	end
	profiles[player] = {
		data = data,
		key = key,
		canSave = loaded and store ~= nil,
		saving = false,
		userId = player.UserId,
	}
	return data, loaded and store ~= nil
end

function DataService.get(player: Player): { [string]: any }?
	local profile = profiles[player]
	return if profile then profile.data else nil
end

function DataService.save(player: Player): boolean
	local profile = profiles[player]
	if not profile or not profile.canSave or not store then
		return false
	end
	while profile.saving do
		task.wait(0.1)
	end
	profile.saving = true
	local success = false
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:SetAsync(profile.key, profile.data, { profile.userId })
		end)
		if ok then
			success = true
			break
		end
		warn(string.format("[Jardim] Falha ao salvar dados de %s (tentativa %d): %s", player.Name, attempt, tostring(err)))
		task.wait(attempt)
	end
	profile.saving = false
	return success
end

function DataService.release(player: Player)
	profiles[player] = nil
end

function DataService.getPlayers(): { Player }
	local list = {}
	for player in profiles do
		table.insert(list, player)
	end
	return list
end

-- Salva todos quando o servidor fecha
function DataService.saveAll(timeout: number)
	local pending = 0
	for player in profiles do
		pending += 1
		task.spawn(function()
			DataService.save(player)
			pending -= 1
		end)
	end
	local start = os.clock()
	while pending > 0 and os.clock() - start < timeout do
		task.wait(0.1)
	end
end

return DataService
