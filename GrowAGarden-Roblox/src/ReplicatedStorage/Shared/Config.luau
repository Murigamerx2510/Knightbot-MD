-- Config: todas as regras e valores do jogo ficam aqui.
-- Para balancear o jogo (precos, tempos, chances), altere apenas este arquivo.

local Config = {}

Config.GameName = "Cultive um Jardim"
Config.CurrencyName = "Sheckles"
Config.CurrencySymbol = "¢"

Config.StartingSheckles = 20
Config.StartingSeeds = { Carrot = 1 }

Config.RestockInterval = 300 -- segundos entre reabastecimentos das lojas
Config.MaxPlantsPerGarden = 80
Config.MaxFruitsInInventory = 200
Config.MaxSprinklersPerGarden = 6
Config.MaxEggsPerGarden = 3
Config.MaxPetsOwned = 60
Config.MaxPetsEquipped = 3
Config.MinPlantSpacing = 1.6
Config.ShopInteractDistance = 30
Config.AutoSaveInterval = 90
Config.DataStoreName = "CultiveUmJardim_v1"

-- Raridades (ordem usada para cor e ordenacao nas lojas)
Config.Rarities = {
	Common = { name = "Comum", order = 1, color = Color3.fromRGB(190, 190, 190) },
	Uncommon = { name = "Incomum", order = 2, color = Color3.fromRGB(90, 220, 90) },
	Rare = { name = "Raro", order = 3, color = Color3.fromRGB(70, 150, 255) },
	Legendary = { name = "Lendário", order = 4, color = Color3.fromRGB(255, 200, 40) },
	Mythical = { name = "Mítico", order = 5, color = Color3.fromRGB(200, 90, 255) },
	Divine = { name = "Divino", order = 6, color = Color3.fromRGB(255, 120, 60) },
	Prismatic = { name = "Prismático", order = 7, color = Color3.fromRGB(255, 90, 200) },
}

--[[
	Sementes.
	multiHarvest = true  -> a planta fica no jardim e produz frutos varias vezes.
	multiHarvest = false -> a planta inteira e colhida uma unica vez.
	growTime   = segundos ate a planta ficar adulta.
	fruitTime  = segundos para cada fruto crescer (apenas multiHarvest).
	baseValue  = valor de venda de um fruto com o peso base e sem mutacoes.
	baseWeight = peso medio do fruto em kg.
	stockChance / stockMin / stockMax = chance de aparecer na loja e quantidade.
	plantType  = formato visual (veja Visuals.luau).
]]
Config.SeedList = {
	{
		id = "Carrot", name = "Cenoura", rarity = "Common", price = 10,
		multiHarvest = false, growTime = 20,
		baseValue = 18, baseWeight = 0.24,
		stockChance = 1, stockMin = 5, stockMax = 25,
		plantType = "root", height = 1.6,
		fruitColor = Color3.fromRGB(255, 140, 30), leafColor = Color3.fromRGB(70, 180, 60),
		fruitSize = Vector3.new(0.6, 1.2, 0.6),
	},
	{
		id = "Strawberry", name = "Morango", rarity = "Common", price = 50,
		multiHarvest = true, growTime = 40, fruitTime = 20, maxFruits = 4,
		baseValue = 14, baseWeight = 0.29,
		stockChance = 1, stockMin = 1, stockMax = 6,
		plantType = "bush", height = 1.8,
		fruitColor = Color3.fromRGB(225, 30, 55), leafColor = Color3.fromRGB(60, 160, 60),
		fruitSize = Vector3.new(0.5, 0.6, 0.5),
	},
	{
		id = "Blueberry", name = "Mirtilo", rarity = "Uncommon", price = 400,
		multiHarvest = true, growTime = 60, fruitTime = 25, maxFruits = 5,
		baseValue = 18, baseWeight = 0.17,
		stockChance = 1, stockMin = 1, stockMax = 5,
		plantType = "bush", height = 2,
		fruitColor = Color3.fromRGB(60, 80, 210), leafColor = Color3.fromRGB(50, 140, 70),
		fruitSize = Vector3.new(0.45, 0.45, 0.45),
	},
	{
		id = "OrangeTulip", name = "Tulipa Laranja", rarity = "Uncommon", price = 600,
		multiHarvest = false, growTime = 45,
		baseValue = 767, baseWeight = 0.05,
		stockChance = 0.8, stockMin = 1, stockMax = 20,
		plantType = "flower", height = 2.2,
		fruitColor = Color3.fromRGB(255, 130, 30), leafColor = Color3.fromRGB(70, 170, 60),
		fruitSize = Vector3.new(0.8, 0.9, 0.8),
	},
	{
		id = "Tomato", name = "Tomate", rarity = "Rare", price = 800,
		multiHarvest = true, growTime = 90, fruitTime = 35, maxFruits = 5,
		baseValue = 27, baseWeight = 0.44,
		stockChance = 0.7, stockMin = 1, stockMax = 3,
		plantType = "bush", height = 2.6,
		fruitColor = Color3.fromRGB(235, 45, 30), leafColor = Color3.fromRGB(55, 150, 55),
		fruitSize = Vector3.new(0.75, 0.65, 0.75),
	},
	{
		id = "Daffodil", name = "Narciso", rarity = "Rare", price = 1000,
		multiHarvest = false, growTime = 80,
		baseValue = 903, baseWeight = 0.16,
		stockChance = 0.5, stockMin = 1, stockMax = 7,
		plantType = "flower", height = 2.4,
		fruitColor = Color3.fromRGB(255, 230, 60), leafColor = Color3.fromRGB(80, 170, 60),
		fruitSize = Vector3.new(0.9, 0.8, 0.9),
	},
	{
		id = "Corn", name = "Milho", rarity = "Rare", price = 1300,
		multiHarvest = true, growTime = 120, fruitTime = 45, maxFruits = 3,
		baseValue = 36, baseWeight = 1.9,
		stockChance = 0.4, stockMin = 1, stockMax = 4,
		plantType = "tall", height = 4,
		fruitColor = Color3.fromRGB(255, 220, 70), leafColor = Color3.fromRGB(90, 170, 50),
		fruitSize = Vector3.new(0.5, 1.3, 0.5),
	},
	{
		id = "Watermelon", name = "Melancia", rarity = "Legendary", price = 2500,
		multiHarvest = false, growTime = 150,
		baseValue = 2708, baseWeight = 7.3,
		stockChance = 0.3, stockMin = 1, stockMax = 3,
		plantType = "ground", height = 1.8,
		fruitColor = Color3.fromRGB(55, 150, 50), leafColor = Color3.fromRGB(70, 170, 60),
		fruitSize = Vector3.new(2.4, 1.8, 1.8),
	},
	{
		id = "Pumpkin", name = "Abóbora", rarity = "Legendary", price = 3000,
		multiHarvest = false, growTime = 160,
		baseValue = 3069, baseWeight = 6.9,
		stockChance = 0.25, stockMin = 1, stockMax = 3,
		plantType = "ground", height = 1.6,
		fruitColor = Color3.fromRGB(240, 130, 20), leafColor = Color3.fromRGB(70, 160, 50),
		fruitSize = Vector3.new(2.2, 1.6, 2.2),
	},
	{
		id = "Apple", name = "Maçã", rarity = "Legendary", price = 3250,
		multiHarvest = true, growTime = 180, fruitTime = 50, maxFruits = 6,
		baseValue = 248, baseWeight = 2.85,
		stockChance = 0.25, stockMin = 1, stockMax = 3,
		plantType = "tree", height = 6,
		fruitColor = Color3.fromRGB(215, 30, 40), leafColor = Color3.fromRGB(60, 150, 50),
		fruitSize = Vector3.new(0.7, 0.7, 0.7),
	},
	{
		id = "Bamboo", name = "Bambu", rarity = "Legendary", price = 4000,
		multiHarvest = false, growTime = 170,
		baseValue = 3610, baseWeight = 3.8,
		stockChance = 0.25, stockMin = 1, stockMax = 5,
		plantType = "stalk", height = 5,
		fruitColor = Color3.fromRGB(130, 200, 80), leafColor = Color3.fromRGB(80, 170, 60),
		fruitSize = Vector3.new(0.55, 5, 0.55),
	},
	{
		id = "Coconut", name = "Coco", rarity = "Mythical", price = 6000,
		multiHarvest = true, growTime = 240, fruitTime = 70, maxFruits = 4,
		baseValue = 361, baseWeight = 13.3,
		stockChance = 0.15, stockMin = 1, stockMax = 2,
		plantType = "palm", height = 7,
		fruitColor = Color3.fromRGB(115, 75, 45), leafColor = Color3.fromRGB(60, 170, 70),
		fruitSize = Vector3.new(1, 1, 1),
	},
	{
		id = "Cactus", name = "Cacto", rarity = "Mythical", price = 15000,
		multiHarvest = true, growTime = 260, fruitTime = 80, maxFruits = 4,
		baseValue = 3069, baseWeight = 6.65,
		stockChance = 0.12, stockMin = 1, stockMax = 2,
		plantType = "cactus", height = 4,
		fruitColor = Color3.fromRGB(235, 90, 150), leafColor = Color3.fromRGB(70, 150, 70),
		fruitSize = Vector3.new(0.65, 0.65, 0.65),
	},
	{
		id = "DragonFruit", name = "Pitaya", rarity = "Mythical", price = 50000,
		multiHarvest = true, growTime = 300, fruitTime = 90, maxFruits = 4,
		baseValue = 4287, baseWeight = 11.38,
		stockChance = 0.1, stockMin = 1, stockMax = 2,
		plantType = "cactus", height = 3.5,
		fruitColor = Color3.fromRGB(235, 40, 140), leafColor = Color3.fromRGB(90, 170, 80),
		fruitSize = Vector3.new(0.9, 1.1, 0.9),
	},
	{
		id = "Mango", name = "Manga", rarity = "Mythical", price = 100000,
		multiHarvest = true, growTime = 360, fruitTime = 100, maxFruits = 5,
		baseValue = 5866, baseWeight = 14.28,
		stockChance = 0.08, stockMin = 1, stockMax = 2,
		plantType = "tree", height = 7,
		fruitColor = Color3.fromRGB(255, 170, 40), leafColor = Color3.fromRGB(50, 140, 60),
		fruitSize = Vector3.new(0.8, 1, 0.8),
	},
	{
		id = "Mushroom", name = "Cogumelo", rarity = "Divine", price = 150000,
		multiHarvest = false, growTime = 420,
		baseValue = 136278, baseWeight = 25.9,
		stockChance = 0.04, stockMin = 1, stockMax = 1,
		plantType = "mushroom", height = 2.2,
		fruitColor = Color3.fromRGB(205, 50, 50), leafColor = Color3.fromRGB(240, 230, 210),
		fruitSize = Vector3.new(2, 1.2, 2),
	},
	{
		id = "Grape", name = "Uva", rarity = "Divine", price = 850000,
		multiHarvest = true, growTime = 480, fruitTime = 120, maxFruits = 5,
		baseValue = 7085, baseWeight = 2.85,
		stockChance = 0.04, stockMin = 1, stockMax = 1,
		plantType = "bush", height = 3,
		fruitColor = Color3.fromRGB(125, 40, 155), leafColor = Color3.fromRGB(70, 150, 60),
		fruitSize = Vector3.new(0.8, 1.05, 0.8),
	},
	{
		id = "Pepper", name = "Pimenta", rarity = "Divine", price = 1000000,
		multiHarvest = true, growTime = 540, fruitTime = 130, maxFruits = 5,
		baseValue = 7220, baseWeight = 4.75,
		stockChance = 0.03, stockMin = 1, stockMax = 1,
		plantType = "bush", height = 2.6,
		fruitColor = Color3.fromRGB(225, 20, 20), leafColor = Color3.fromRGB(60, 150, 50),
		fruitSize = Vector3.new(0.4, 1, 0.4),
	},
	{
		id = "Cacao", name = "Cacau", rarity = "Divine", price = 2500000,
		multiHarvest = true, growTime = 600, fruitTime = 150, maxFruits = 4,
		baseValue = 10830, baseWeight = 7.6,
		stockChance = 0.02, stockMin = 1, stockMax = 1,
		plantType = "tree", height = 6,
		fruitColor = Color3.fromRGB(150, 90, 40), leafColor = Color3.fromRGB(50, 130, 50),
		fruitSize = Vector3.new(0.7, 1.1, 0.7),
	},
	{
		id = "Beanstalk", name = "Pé de Feijão", rarity = "Prismatic", price = 10000000,
		multiHarvest = true, growTime = 900, fruitTime = 200, maxFruits = 5,
		baseValue = 25270, baseWeight = 9.5,
		stockChance = 0.01, stockMin = 1, stockMax = 1,
		plantType = "beanstalk", height = 10,
		fruitColor = Color3.fromRGB(100, 210, 70), leafColor = Color3.fromRGB(60, 170, 60),
		fruitSize = Vector3.new(0.5, 1.2, 0.5),
	},
}

--[[
	Equipamentos.
	kind = "water"     -> Regador: acelera plantas proximas (usos).
	kind = "shovel"    -> Pa: remove plantas do seu jardim.
	kind = "sprinkler" -> colocado no jardim; acelera o crescimento ao redor por um tempo.
]]
Config.GearList = {
	{
		id = "WateringCan", name = "Regador", rarity = "Common", price = 800,
		kind = "water", uses = 10, radius = 5, boost = 0.1,
		description = "10 usos. Acelera 10% do crescimento das plantas próximas.",
		stockChance = 1, stockMin = 1, stockMax = 3,
		color = Color3.fromRGB(80, 140, 230),
	},
	{
		id = "Shovel", name = "Pá", rarity = "Common", price = 100,
		kind = "shovel", unique = true,
		description = "Remove plantas do seu jardim (clique 2x na planta).",
		stockChance = 1, stockMin = 1, stockMax = 1,
		color = Color3.fromRGB(150, 110, 70),
	},
	{
		id = "BasicSprinkler", name = "Sprinkler Básico", rarity = "Uncommon", price = 2500,
		kind = "sprinkler", duration = 300, radius = 9, growth = 0.5, wetChance = 0,
		description = "5 min. Plantas próximas crescem 50% mais rápido.",
		stockChance = 0.6, stockMin = 1, stockMax = 2,
		color = Color3.fromRGB(170, 170, 180),
	},
	{
		id = "AdvancedSprinkler", name = "Sprinkler Avançado", rarity = "Rare", price = 12000,
		kind = "sprinkler", duration = 300, radius = 11, growth = 1, wetChance = 0.002,
		description = "5 min. +100% de crescimento e chance de fruto Molhado.",
		stockChance = 0.35, stockMin = 1, stockMax = 2,
		color = Color3.fromRGB(80, 160, 230),
	},
	{
		id = "GodlySprinkler", name = "Sprinkler Divino", rarity = "Legendary", price = 120000,
		kind = "sprinkler", duration = 420, radius = 14, growth = 2, wetChance = 0.004,
		description = "7 min. +200% de crescimento e mais chance de Molhado.",
		stockChance = 0.15, stockMin = 1, stockMax = 1,
		color = Color3.fromRGB(255, 210, 60),
	},
	{
		id = "MasterSprinkler", name = "Sprinkler Mestre", rarity = "Mythical", price = 1000000,
		kind = "sprinkler", duration = 600, radius = 16, growth = 3, wetChance = 0.006,
		description = "10 min. +300% de crescimento ao redor.",
		stockChance = 0.05, stockMin = 1, stockMax = 1,
		color = Color3.fromRGB(200, 90, 255),
	},
}

-- Pets: bonusType "Growth" (crescimento), "Sell" (venda) ou "Luck" (sorte de mutacao)
Config.PetList = {
	{ id = "Dog", name = "Cachorro", rarity = "Common", bonusType = "Luck", bonus = 0.1, color = Color3.fromRGB(190, 140, 90), accent = Color3.fromRGB(120, 80, 50), size = 1 },
	{ id = "Bunny", name = "Coelho", rarity = "Common", bonusType = "Growth", bonus = 0.1, color = Color3.fromRGB(240, 240, 240), accent = Color3.fromRGB(255, 180, 200), size = 0.9 },
	{ id = "Cat", name = "Gato", rarity = "Common", bonusType = "Sell", bonus = 0.08, color = Color3.fromRGB(250, 170, 70), accent = Color3.fromRGB(255, 240, 220), size = 0.9 },
	{ id = "Chicken", name = "Galinha", rarity = "Uncommon", bonusType = "Growth", bonus = 0.15, color = Color3.fromRGB(255, 255, 250), accent = Color3.fromRGB(230, 40, 40), size = 0.9 },
	{ id = "Pig", name = "Porco", rarity = "Uncommon", bonusType = "Sell", bonus = 0.15, color = Color3.fromRGB(255, 170, 190), accent = Color3.fromRGB(230, 120, 150), size = 1 },
	{ id = "Frog", name = "Sapo", rarity = "Uncommon", bonusType = "Luck", bonus = 0.25, color = Color3.fromRGB(90, 200, 70), accent = Color3.fromRGB(240, 240, 120), size = 0.85 },
	{ id = "Fox", name = "Raposa", rarity = "Rare", bonusType = "Sell", bonus = 0.25, color = Color3.fromRGB(240, 110, 30), accent = Color3.fromRGB(255, 255, 255), size = 1 },
	{ id = "Owl", name = "Coruja", rarity = "Rare", bonusType = "Growth", bonus = 0.3, color = Color3.fromRGB(140, 100, 70), accent = Color3.fromRGB(240, 210, 120), size = 0.9 },
	{ id = "Panda", name = "Panda", rarity = "Rare", bonusType = "Luck", bonus = 0.5, color = Color3.fromRGB(250, 250, 250), accent = Color3.fromRGB(30, 30, 30), size = 1.1 },
	{ id = "Unicorn", name = "Unicórnio", rarity = "Legendary", bonusType = "Luck", bonus = 1, color = Color3.fromRGB(255, 250, 255), accent = Color3.fromRGB(255, 120, 220), size = 1.2 },
	{ id = "Dragon", name = "Dragão", rarity = "Legendary", bonusType = "Sell", bonus = 0.6, color = Color3.fromRGB(200, 40, 40), accent = Color3.fromRGB(255, 200, 40), size = 1.25 },
	{ id = "Phoenix", name = "Fênix", rarity = "Legendary", bonusType = "Growth", bonus = 0.75, color = Color3.fromRGB(255, 120, 30), accent = Color3.fromRGB(255, 230, 60), size = 1.15 },
}

Config.PetBonusNames = {
	Growth = "Crescimento",
	Sell = "Venda",
	Luck = "Sorte",
}

-- Ovos: chances = peso de cada pet dentro do ovo
Config.EggList = {
	{
		id = "CommonEgg", name = "Ovo Comum", rarity = "Common", price = 2500, hatchTime = 60,
		stockChance = 1, stockMin = 1, stockMax = 3,
		color = Color3.fromRGB(240, 235, 220),
		pets = { { pet = "Dog", weight = 45 }, { pet = "Bunny", weight = 40 }, { pet = "Cat", weight = 15 } },
	},
	{
		id = "UncommonEgg", name = "Ovo Incomum", rarity = "Uncommon", price = 12000, hatchTime = 180,
		stockChance = 0.6, stockMin = 1, stockMax = 2,
		color = Color3.fromRGB(150, 230, 140),
		pets = { { pet = "Chicken", weight = 40 }, { pet = "Pig", weight = 35 }, { pet = "Frog", weight = 25 } },
	},
	{
		id = "RareEgg", name = "Ovo Raro", rarity = "Rare", price = 60000, hatchTime = 600,
		stockChance = 0.3, stockMin = 1, stockMax = 2,
		color = Color3.fromRGB(120, 170, 255),
		pets = { { pet = "Fox", weight = 40 }, { pet = "Owl", weight = 35 }, { pet = "Panda", weight = 25 } },
	},
	{
		id = "LegendaryEgg", name = "Ovo Lendário", rarity = "Legendary", price = 500000, hatchTime = 1200,
		stockChance = 0.12, stockMin = 1, stockMax = 1,
		color = Color3.fromRGB(255, 215, 70),
		pets = { { pet = "Unicorn", weight = 45 }, { pet = "Dragon", weight = 35 }, { pet = "Phoenix", weight = 20 } },
	},
}

--[[
	Mutacoes.
	kind = "growth": aparece quando o fruto nasce (so uma por fruto). Multiplicadores nao somam.
	kind = "env": vem do clima/sprinklers. Os bonus somam: total = growth * (1 + soma(mult - 1)).
]]
Config.Mutations = {
	Gold = { name = "Dourado", kind = "growth", mult = 20, color = Color3.fromRGB(255, 205, 40), material = "Foil" },
	Rainbow = { name = "Arco-íris", kind = "growth", mult = 50, color = Color3.fromRGB(255, 120, 220), material = "SmoothPlastic" },
	Wet = { name = "Molhado", kind = "env", mult = 2, color = Color3.fromRGB(90, 160, 255), material = "Glass" },
	Chilled = { name = "Gelado", kind = "env", mult = 2, color = Color3.fromRGB(160, 215, 255), material = "SmoothPlastic" },
	Frozen = { name = "Congelado", kind = "env", mult = 10, color = Color3.fromRGB(175, 235, 255), material = "Ice" },
	Shocked = { name = "Eletrizado", kind = "env", mult = 100, color = Color3.fromRGB(110, 210, 255), material = "Neon" },
}

-- Ordem de prioridade para a aparencia do fruto (a primeira encontrada define a cor)
Config.MutationVisualPriority = { "Shocked", "Frozen", "Rainbow", "Gold", "Chilled", "Wet" }
Config.MutationOrder = { "Gold", "Rainbow", "Wet", "Chilled", "Frozen", "Shocked" }

Config.GrowthMutationChances = {
	Rainbow = 0.001,
	Gold = 0.01,
}

Config.GiantChance = 0.02 -- chance de um fruto nascer gigante (peso muito maior)

-- Clima
Config.WeatherMinInterval = 240
Config.WeatherMaxInterval = 480
Config.WeatherList = {
	{
		id = "Rain", name = "Chuva", emoji = "🌧️", weight = 50, duration = 120,
		growthBonus = 0.5, mutation = "Wet", mutationChance = 0.004,
		description = "Plantas crescem 50% mais rápido e podem ficar Molhadas (x2)!",
		clockTime = 13, brightness = 1.2, density = 0.45,
	},
	{
		id = "Frost", name = "Geada", emoji = "❄️", weight = 30, duration = 100,
		growthBonus = 0, mutation = "Chilled", mutationChance = 0.004,
		description = "Frutos podem ficar Gelados (x2). Molhado + Gelado = Congelado (x10)!",
		clockTime = 15, brightness = 1.6, density = 0.5,
	},
	{
		id = "Thunderstorm", name = "Tempestade", emoji = "⛈️", weight = 20, duration = 100,
		growthBonus = 0.5, mutation = "Wet", mutationChance = 0.004,
		strikeInterval = 8, strikeMutation = "Shocked",
		description = "Raios podem Eletrizar frutos (x100)! Plantas crescem 50% mais rápido.",
		clockTime = 19, brightness = 0.6, density = 0.55,
	},
}

-- Indices por id (preenchidos automaticamente)
local function index(list)
	local map = {}
	for i, item in list do
		item.order = i
		map[item.id] = item
	end
	return map
end

Config.Seeds = index(Config.SeedList)
Config.Gear = index(Config.GearList)
Config.Pets = index(Config.PetList)
Config.Eggs = index(Config.EggList)
Config.Weather = index(Config.WeatherList)

return Config
