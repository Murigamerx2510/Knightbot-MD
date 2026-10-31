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
		version = 3,
		sheckles = Config.StartingSheckles,
		seeds = deepCopy(Config.StartingSeeds),
		gear = {},
		fruits = {},
		plants = {},
		sprinklers = {},
		props = {},
		stock = { window = -1, seeds = {}, gear = {} },
		quests = { day = -1, list = {} },
		nextId = 1,
		stats = { harvested = 0, earned = 0, planted = 0, sold = 0, stolen = 0, stolenFrom = 0, merged = 0 },
	}
end

-- Troca ids antigos (de versoes anteriores) pelos novos
local function migrateIds(map: { [string]: any }, legacy: { [string]: string })
	for oldId, newId in legacy do
		local count = map[oldId]
		if type(count) == "number" then
			map[oldId] = nil
			map[newId] = (map[newId] or 0) + count
		end
	end
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
	for _, key in { "stock", "stats", "quests" } do
		for subKey, value in template[key] do
			if data[key][subKey] == nil then
				data[key][subKey] = deepCopy(value)
			end
		end
	end
	-- versoes antigas tinham pets e ovos: o jogo agora e so de plantas
	data.eggs = nil
	data.placedEggs = nil
	data.pets = nil
	data.equippedPets = nil
	data.stock.eggs = nil
	data.stats.hatched = nil
	migrateIds(data.gear, Config.LegacyIds.gear)
	migrateIds(data.seeds, Config.LegacyIds.seeds)
	for _, key in { "seeds", "gear" } do
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
	for i = #data.plants, 1, -1 do
		local plant = data.plants[i]
		if type(plant) == "table" and Config.LegacyIds.seeds[plant.s] then
			plant.s = Config.LegacyIds.seeds[plant.s]
		end
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
			if plant.v ~= nil and type(plant.v) ~= "string" then
				plant.v = nil
			end
			local fruits = if seed.multiHarvest then plant.slots else { plant.f }
			for _, fruit in fruits do
				if type(fruit.m) ~= "table" then
					fruit.m = {}
				end
				if type(fruit.w) ~= "number" then
					fruit.w = seed.baseWeight
				end
				if type(fruit.a) ~= "number" then
					fruit.a = 0
				end
			end
		end
	end
	for i = #data.fruits, 1, -1 do
		local fruit = data.fruits[i]
		if type(fruit) == "table" and Config.LegacyIds.seeds[fruit.s] then
			fruit.s = Config.LegacyIds.seeds[fruit.s]
		end
		if type(fruit) ~= "table" or not Config.Seeds[fruit.s] or type(fruit.w) ~= "number" then
			table.remove(data.fruits, i)
		elseif type(fruit.m) ~= "table" then
			fruit.m = {}
		end
	end
	for i = #data.sprinklers, 1, -1 do
		local sprinkler = data.sprinklers[i]
		if type(sprinkler) == "table" and Config.LegacyIds.gear[sprinkler.g] then
			sprinkler.g = Config.LegacyIds.gear[sprinkler.g]
		end
		if type(sprinkler) ~= "table" or not Config.Gear[sprinkler.g] then
			table.remove(data.sprinklers, i)
		end
	end
	for i = #data.props, 1, -1 do
		local prop = data.props[i]
		if type(prop) ~= "table" or not Config.Gear[prop.g] then
			table.remove(data.props, i)
		end
	end
	if type(data.quests.list) ~= "table" then
		data.quests.list = {}
	end
	-- o maior id em uso define o proximo id livre
	local maxId = 0
	for _, list in { data.plants, data.sprinklers, data.props } do
		for _, item in list do
			if type(item.id) == "number" then
				maxId = math.max(maxId, item.id)
			end
		end
	end
	data.nextId = math.max(data.nextId, maxId + 1)
	data.version = 3
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
