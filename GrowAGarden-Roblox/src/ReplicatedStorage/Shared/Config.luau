-- Config: todas as regras e valores do jogo ficam aqui.
-- Para balancear o jogo (precos, tempos, chances), altere apenas este arquivo.
--
-- Conteudo baseado no Grow a Garden 2 (plantas, raridades, clima, roubo a noite,
-- defesas, equipamentos e pets) com as mecanicas do Grow a Garden original
-- (mutacoes que se combinam, clima que muta frutos, crescimento offline, ovos no jardim)
-- e varias novidades: variantes de cor, tamanhos, combinacoes de mutacoes,
-- fusoes secretas, niveis de pets, ovos com variantes e missoes diarias.

local Config = {}

Config.GameName = "Cultive um Jardim"
Config.CurrencyName = "Sheckles"
Config.CurrencySymbol = "¢"

Config.StartingSheckles = 20
Config.StartingSeeds = { Carrot = 2 }

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

-- Raridades (iguais as do Grow a Garden 2)
Config.Rarities = {
	Common = { name = "Comum", order = 1, color = Color3.fromRGB(190, 190, 190) },
	Uncommon = { name = "Incomum", order = 2, color = Color3.fromRGB(90, 220, 90) },
	Rare = { name = "Raro", order = 3, color = Color3.fromRGB(70, 150, 255) },
	Epic = { name = "Épico", order = 4, color = Color3.fromRGB(170, 90, 255) },
	Legendary = { name = "Lendário", order = 5, color = Color3.fromRGB(255, 200, 40) },
	Mythic = { name = "Mítico", order = 6, color = Color3.fromRGB(255, 90, 160) },
	Super = { name = "Super", order = 7, color = Color3.fromRGB(255, 120, 40) },
	Secret = { name = "Secreto", order = 8, color = Color3.fromRGB(40, 40, 40) },
}

---------------------------------------------------------------------
-- Ciclo de dia e noite (igual ao GAG2: 7,5 min de dia, 30 s de por do sol, 2 min de noite)
---------------------------------------------------------------------

Config.DayNight = {
	dayLength = 450,
	sunsetLength = 30,
	nightLength = 120,
	moonlitChance = 0.002, -- chance por segundo de um fruto ficar Lunar durante a noite
	nightEventChance = 0.6, -- chance de uma lua especial em cada noite
	dayEventChance = 0.75, -- chance de um clima durante o dia
	dayEventDelayMin = 40,
	dayEventDelayMax = 200,
}

---------------------------------------------------------------------
-- Roubo a noite (novidade do GAG2)
---------------------------------------------------------------------

Config.Stealing = {
	enabled = true,
	holdDuration = 1.2, -- segurar E por este tempo para roubar
	maxDistance = 12, -- distancia maxima do fruto
	cooldown = 4, -- segundos entre roubos
	carryWalkSpeed = 12, -- quem carrega um fruto roubado anda mais devagar
	carryTimeout = 90, -- se nao levar ao jardim neste tempo, o fruto volta ao dono
	bonkDistance = 9, -- distancia para recuperar o fruto acertando o ladrao com a Pa
	stunTime = 3,
}

--[[
	Sementes.
	multiHarvest = true  -> a planta fica no jardim e produz frutos varias vezes.
	multiHarvest = false -> a planta inteira e colhida uma unica vez.
	growTime / fruitTime = segundos para a planta crescer / cada fruto crescer.
	baseValue / baseWeight = valor e peso medio de um fruto sem mutacoes.
	plantType = formato do modelo 3D (veja Visuals.luau).
	variant = variante de cor rara (aparece em ~4% das plantas e vale mais).
	defense = planta de defesa contra ladroes (so funciona a noite e adulta).
	special = efeitos especiais da planta.
	inShop = false -> nao aparece na loja (plantas secretas de fusao).
	classic = true -> planta do Grow a Garden original.
]]
Config.SeedList = {
	-- Comum
	{
		id = "Carrot", name = "Cenoura", rarity = "Common", price = 1,
		multiHarvest = false, growTime = 15,
		baseValue = 5, baseWeight = 0.24,
		stockChance = 1, stockMin = 5, stockMax = 25,
		plantType = "root", height = 1.6,
		fruitColor = Color3.fromRGB(255, 140, 30), leafColor = Color3.fromRGB(70, 180, 60),
		fruitSize = Vector3.new(0.6, 1.2, 0.6),
		variant = { id = "Purple", name = "Roxa", color = Color3.fromRGB(130, 50, 170), mult = 1.6 },
	},
	{
		id = "Strawberry", name = "Morango", rarity = "Common", price = 10,
		multiHarvest = true, growTime = 30, fruitTime = 15, maxFruits = 4,
		baseValue = 3, baseWeight = 0.29,
		stockChance = 1, stockMin = 1, stockMax = 8,
		plantType = "bush", height = 1.8,
		fruitColor = Color3.fromRGB(225, 30, 55), leafColor = Color3.fromRGB(60, 160, 60),
		fruitSize = Vector3.new(0.5, 0.6, 0.5),
		variant = { id = "White", name = "Branco", color = Color3.fromRGB(250, 245, 240), mult = 1.6 },
	},
	{
		id = "Blueberry", name = "Mirtilo", rarity = "Common", price = 25,
		multiHarvest = true, growTime = 40, fruitTime = 18, maxFruits = 5,
		baseValue = 5, baseWeight = 0.17,
		stockChance = 1, stockMin = 1, stockMax = 6,
		plantType = "bush", height = 2,
		fruitColor = Color3.fromRGB(60, 80, 210), leafColor = Color3.fromRGB(50, 140, 70),
		fruitSize = Vector3.new(0.45, 0.45, 0.45),
		variant = { id = "Pink", name = "Rosa", color = Color3.fromRGB(255, 140, 200), mult = 1.6 },
	},
	-- Incomum
	{
		id = "Tulip", name = "Tulipa", rarity = "Uncommon", price = 40,
		multiHarvest = false, growTime = 45,
		baseValue = 60, baseWeight = 0.05,
		stockChance = 0.9, stockMin = 1, stockMax = 15,
		plantType = "flower", height = 2.2,
		fruitColor = Color3.fromRGB(240, 70, 110), leafColor = Color3.fromRGB(70, 170, 60),
		fruitSize = Vector3.new(0.8, 0.9, 0.8),
		variant = { id = "Black", name = "Negra", color = Color3.fromRGB(45, 30, 55), mult = 1.8 },
	},
	{
		id = "Tomato", name = "Tomate", rarity = "Uncommon", price = 200,
		multiHarvest = true, growTime = 60, fruitTime = 25, maxFruits = 5,
		baseValue = 9, baseWeight = 0.44,
		stockChance = 0.9, stockMin = 1, stockMax = 4,
		plantType = "bush", height = 2.6,
		fruitColor = Color3.fromRGB(235, 45, 30), leafColor = Color3.fromRGB(55, 150, 55),
		fruitSize = Vector3.new(0.75, 0.65, 0.75),
		variant = { id = "Yellow", name = "Amarelo", color = Color3.fromRGB(255, 210, 40), mult = 1.6 },
	},
	{
		id = "Apple", name = "Maçã", rarity = "Uncommon", price = 400,
		multiHarvest = true, growTime = 90, fruitTime = 30, maxFruits = 6,
		baseValue = 11, baseWeight = 2.85,
		stockChance = 0.9, stockMin = 1, stockMax = 3,
		plantType = "tree", height = 6,
		fruitColor = Color3.fromRGB(215, 30, 40), leafColor = Color3.fromRGB(60, 150, 50),
		fruitSize = Vector3.new(0.7, 0.7, 0.7),
		variant = { id = "Green", name = "Verde", color = Color3.fromRGB(140, 210, 60), mult = 1.6 },
	},
	-- Raro
	{
		id = "Bamboo", name = "Bambu", rarity = "Rare", price = 700,
		multiHarvest = false, growTime = 110,
		baseValue = 900, baseWeight = 3.8,
		stockChance = 0.6, stockMin = 1, stockMax = 5,
		plantType = "stalk", height = 5,
		fruitColor = Color3.fromRGB(130, 200, 80), leafColor = Color3.fromRGB(80, 170, 60),
		fruitSize = Vector3.new(0.55, 5, 0.55),
		variant = { id = "Black", name = "Negro", color = Color3.fromRGB(55, 55, 50), mult = 1.6 },
	},
	{
		id = "Daffodil", name = "Narciso", rarity = "Rare", price = 1500, classic = true,
		multiHarvest = false, growTime = 80,
		baseValue = 2400, baseWeight = 0.16,
		stockChance = 0.5, stockMin = 1, stockMax = 6,
		plantType = "flower", height = 2.4,
		fruitColor = Color3.fromRGB(255, 230, 60), leafColor = Color3.fromRGB(80, 170, 60),
		fruitSize = Vector3.new(0.9, 0.8, 0.9),
		variant = { id = "White", name = "Branco", color = Color3.fromRGB(250, 250, 240), mult = 1.6 },
	},
	{
		id = "Corn", name = "Milho", rarity = "Rare", price = 2500,
		multiHarvest = true, growTime = 140, fruitTime = 40, maxFruits = 4,
		baseValue = 60, baseWeight = 1.9,
		stockChance = 0.55, stockMin = 1, stockMax = 3,
		plantType = "tall", height = 4,
		fruitColor = Color3.fromRGB(255, 220, 70), leafColor = Color3.fromRGB(90, 170, 50),
		fruitSize = Vector3.new(0.5, 1.3, 0.5),
		variant = { id = "Blue", name = "Azul", color = Color3.fromRGB(70, 90, 200), mult = 1.6 },
	},
	{
		id = "Cactus", name = "Cacto", rarity = "Rare", price = 5000,
		multiHarvest = true, growTime = 170, fruitTime = 45, maxFruits = 4,
		baseValue = 110, baseWeight = 6.65,
		stockChance = 0.5, stockMin = 1, stockMax = 3,
		plantType = "cactus", height = 4,
		fruitColor = Color3.fromRGB(235, 90, 150), leafColor = Color3.fromRGB(70, 150, 70),
		fruitSize = Vector3.new(0.65, 0.65, 0.65),
		defense = { kind = "contact", radius = 2.5, damage = 8, cooldown = 1 },
		variant = { id = "Blue", name = "Azul", color = Color3.fromRGB(120, 170, 230), mult = 1.6 },
	},
	{
		id = "Pineapple", name = "Abacaxi", rarity = "Rare", price = 10000,
		multiHarvest = true, growTime = 190, fruitTime = 50, maxFruits = 3,
		baseValue = 250, baseWeight = 2.4,
		stockChance = 0.45, stockMin = 1, stockMax = 2,
		plantType = "pineapple", height = 2.4,
		fruitColor = Color3.fromRGB(240, 190, 40), leafColor = Color3.fromRGB(60, 150, 60),
		fruitSize = Vector3.new(0.8, 1.1, 0.8),
		variant = { id = "Red", name = "Vermelho", color = Color3.fromRGB(220, 80, 40), mult = 1.6 },
	},
	-- Epico
	{
		id = "Banana", name = "Banana", rarity = "Epic", price = 30000,
		multiHarvest = true, growTime = 230, fruitTime = 55, maxFruits = 5,
		baseValue = 400, baseWeight = 1.4,
		stockChance = 0.35, stockMin = 1, stockMax = 2,
		plantType = "palm", height = 6,
		fruitColor = Color3.fromRGB(250, 220, 60), leafColor = Color3.fromRGB(70, 170, 70),
		fruitSize = Vector3.new(0.45, 1.2, 0.45),
		variant = { id = "Red", name = "Vermelha", color = Color3.fromRGB(190, 60, 60), mult = 1.6 },
	},
	{
		id = "Grape", name = "Uva", rarity = "Epic", price = 50000,
		multiHarvest = true, growTime = 250, fruitTime = 60, maxFruits = 5,
		baseValue = 600, baseWeight = 2.85,
		stockChance = 0.32, stockMin = 1, stockMax = 2,
		plantType = "vine", height = 3,
		fruitColor = Color3.fromRGB(125, 40, 155), leafColor = Color3.fromRGB(70, 150, 60),
		fruitSize = Vector3.new(0.8, 1.05, 0.8),
		variant = { id = "Green", name = "Verde", color = Color3.fromRGB(170, 220, 90), mult = 1.6 },
	},
	{
		id = "Watermelon", name = "Melancia", rarity = "Epic", price = 60000, classic = true,
		multiHarvest = false, growTime = 240,
		baseValue = 100000, baseWeight = 7.3,
		stockChance = 0.3, stockMin = 1, stockMax = 2,
		plantType = "ground", height = 1.8,
		fruitColor = Color3.fromRGB(55, 150, 50), leafColor = Color3.fromRGB(70, 170, 60),
		fruitSize = Vector3.new(2.4, 1.8, 1.8),
		variant = { id = "Yellow", name = "Amarela", color = Color3.fromRGB(240, 210, 60), mult = 1.6 },
	},
	{
		id = "GlowMushroom", name = "Cogumelo Brilhante", rarity = "Epic", price = 75000,
		multiHarvest = true, growTime = 270, fruitTime = 70, maxFruits = 4,
		baseValue = 1200, baseWeight = 1.2,
		stockChance = 0.3, stockMin = 1, stockMax = 2,
		plantType = "glowshroom", height = 2,
		fruitColor = Color3.fromRGB(90, 230, 255), leafColor = Color3.fromRGB(240, 230, 210),
		fruitSize = Vector3.new(0.5, 0.5, 0.5),
		special = { glowAura = { radius = 6, mutation = "Glowing", chance = 0.003 } },
		variant = { id = "Purple", name = "Roxo", color = Color3.fromRGB(190, 90, 255), mult = 1.6 },
	},
	{
		id = "Pumpkin", name = "Abóbora", rarity = "Epic", price = 80000, classic = true,
		multiHarvest = false, growTime = 260,
		baseValue = 135000, baseWeight = 6.9,
		stockChance = 0.28, stockMin = 1, stockMax = 2,
		plantType = "ground", height = 1.6,
		fruitColor = Color3.fromRGB(240, 130, 20), leafColor = Color3.fromRGB(70, 160, 50),
		fruitSize = Vector3.new(2.2, 1.6, 2.2),
		variant = { id = "White", name = "Branca", color = Color3.fromRGB(245, 240, 230), mult = 1.6 },
	},
	{
		id = "GreenBean", name = "Feijão Verde", rarity = "Epic", price = 90000,
		multiHarvest = true, growTime = 280, fruitTime = 60, maxFruits = 6,
		baseValue = 800, baseWeight = 0.9,
		stockChance = 0.28, stockMin = 1, stockMax = 2,
		plantType = "vine", height = 3.2,
		fruitColor = Color3.fromRGB(90, 190, 60), leafColor = Color3.fromRGB(60, 150, 50),
		fruitSize = Vector3.new(0.35, 1.1, 0.35),
		variant = { id = "Purple", name = "Roxo", color = Color3.fromRGB(120, 60, 160), mult = 1.6 },
	},
	{
		id = "Mushroom", name = "Cogumelo", rarity = "Epic", price = 100000,
		multiHarvest = false, growTime = 300,
		baseValue = 165000, baseWeight = 25.9,
		stockChance = 0.25, stockMin = 1, stockMax = 1,
		plantType = "mushroom", height = 2.2,
		fruitColor = Color3.fromRGB(205, 50, 50), leafColor = Color3.fromRGB(240, 230, 210),
		fruitSize = Vector3.new(2, 1.2, 2),
		variant = { id = "Blue", name = "Azul", color = Color3.fromRGB(60, 110, 220), mult = 1.6 },
	},
	{
		id = "Coconut", name = "Coco", rarity = "Epic", price = 140000,
		multiHarvest = true, growTime = 320, fruitTime = 80, maxFruits = 4,
		baseValue = 2600, baseWeight = 13.3,
		stockChance = 0.22, stockMin = 1, stockMax = 1,
		plantType = "palm", height = 7,
		fruitColor = Color3.fromRGB(115, 75, 45), leafColor = Color3.fromRGB(60, 170, 70),
		fruitSize = Vector3.new(1, 1, 1),
		variant = { id = "Green", name = "Verde", color = Color3.fromRGB(120, 180, 70), mult = 1.6 },
	},
	{
		id = "Mango", name = "Manga", rarity = "Epic", price = 300000,
		multiHarvest = true, growTime = 340, fruitTime = 90, maxFruits = 5,
		baseValue = 4500, baseWeight = 14.28,
		stockChance = 0.2, stockMin = 1, stockMax = 1,
		plantType = "tree", height = 7,
		fruitColor = Color3.fromRGB(255, 170, 40), leafColor = Color3.fromRGB(50, 140, 60),
		fruitSize = Vector3.new(0.8, 1, 0.8),
		variant = { id = "Red", name = "Vermelha", color = Color3.fromRGB(230, 70, 50), mult = 1.6 },
	},
	-- Lendario
	{
		id = "DragonFruit", name = "Pitaya", rarity = "Legendary", price = 600000,
		multiHarvest = true, growTime = 380, fruitTime = 100, maxFruits = 4,
		baseValue = 10000, baseWeight = 11.38,
		stockChance = 0.18, stockMin = 1, stockMax = 1,
		plantType = "cactus", height = 3.5,
		fruitColor = Color3.fromRGB(235, 40, 140), leafColor = Color3.fromRGB(90, 170, 80),
		fruitSize = Vector3.new(0.9, 1.1, 0.9),
		variant = { id = "Yellow", name = "Amarela", color = Color3.fromRGB(250, 220, 60), mult = 1.6 },
	},
	{
		id = "Cherry", name = "Cereja", rarity = "Legendary", price = 1200000,
		multiHarvest = true, growTime = 400, fruitTime = 100, maxFruits = 6,
		baseValue = 13000, baseWeight = 0.6,
		stockChance = 0.17, stockMin = 1, stockMax = 1,
		plantType = "tree", height = 5.5,
		fruitColor = Color3.fromRGB(200, 20, 40), leafColor = Color3.fromRGB(60, 150, 60),
		fruitSize = Vector3.new(0.5, 0.5, 0.5),
		variant = { id = "White", name = "Branca", color = Color3.fromRGB(250, 230, 200), mult = 1.6 },
	},
	{
		id = "Acorn", name = "Bolota", rarity = "Legendary", price = 2000000,
		multiHarvest = true, growTime = 420, fruitTime = 110, maxFruits = 5,
		baseValue = 29000, baseWeight = 0.8,
		stockChance = 0.15, stockMin = 1, stockMax = 1,
		plantType = "tree", height = 7,
		fruitColor = Color3.fromRGB(150, 100, 50), leafColor = Color3.fromRGB(70, 130, 50),
		fruitSize = Vector3.new(0.55, 0.7, 0.55),
		variant = { id = "Gold", name = "Dourada", color = Color3.fromRGB(240, 190, 60), mult = 1.6 },
	},
	{
		id = "PoisonIvy", name = "Hera Venenosa", rarity = "Legendary", price = 2500000,
		multiHarvest = true, growTime = 430, fruitTime = 110, maxFruits = 4,
		baseValue = 45000, baseWeight = 1.1,
		stockChance = 0.14, stockMin = 1, stockMax = 1,
		plantType = "vine", height = 3,
		fruitColor = Color3.fromRGB(150, 230, 60), leafColor = Color3.fromRGB(50, 120, 40),
		fruitSize = Vector3.new(0.5, 0.5, 0.5),
		defense = { kind = "poison", radius = 4, damage = 5, cooldown = 1, slow = 8, slowTime = 3 },
		variant = { id = "Purple", name = "Roxa", color = Color3.fromRGB(150, 70, 190), mult = 1.6 },
	},
	{
		id = "FireFern", name = "Samambaia de Fogo", rarity = "Legendary", price = 3500000,
		multiHarvest = true, growTime = 450, fruitTime = 120, maxFruits = 4,
		baseValue = 70000, baseWeight = 1.6,
		stockChance = 0.12, stockMin = 1, stockMax = 1,
		plantType = "fern", height = 2.6,
		fruitColor = Color3.fromRGB(255, 110, 30), leafColor = Color3.fromRGB(210, 80, 30),
		fruitSize = Vector3.new(0.55, 0.55, 0.55),
		special = { fruitMutations = { Ignited = 0.03 } },
		variant = { id = "Blue", name = "Azul", color = Color3.fromRGB(60, 140, 255), mult = 1.6 },
	},
	{
		id = "CherryBlossom", name = "Cerejeira", rarity = "Legendary", price = 4000000,
		multiHarvest = true, growTime = 460, fruitTime = 115, maxFruits = 6,
		baseValue = 51000, baseWeight = 3,
		stockChance = 0.11, stockMin = 1, stockMax = 1,
		plantType = "blossom", height = 6.5,
		fruitColor = Color3.fromRGB(255, 160, 200), leafColor = Color3.fromRGB(255, 185, 215),
		fruitSize = Vector3.new(0.7, 0.6, 0.7),
		special = { petals = true, fruitMutations = { Pollinated = 0.05 } },
		variant = { id = "White", name = "Branca", color = Color3.fromRGB(255, 250, 250), mult = 1.6 },
	},
	{
		id = "Sunflower", name = "Girassol", rarity = "Legendary", price = 5000000,
		multiHarvest = true, growTime = 470, fruitTime = 120, maxFruits = 3,
		baseValue = 130000, baseWeight = 3.5,
		stockChance = 0.1, stockMin = 1, stockMax = 1,
		plantType = "sunflower", height = 5,
		fruitColor = Color3.fromRGB(250, 210, 40), leafColor = Color3.fromRGB(70, 160, 60),
		fruitSize = Vector3.new(0.9, 0.9, 0.5),
		variant = { id = "Red", name = "Vermelho", color = Color3.fromRGB(200, 60, 40), mult = 1.6 },
	},
	{
		id = "RocketPop", name = "Picolé Foguete", rarity = "Legendary", price = 8000000, limited = true,
		multiHarvest = false, growTime = 480,
		baseValue = 14000000, baseWeight = 0.9,
		stockChance = 0.04, stockMin = 1, stockMax = 1,
		plantType = "popsicle", height = 2.4,
		fruitColor = Color3.fromRGB(230, 40, 50), leafColor = Color3.fromRGB(80, 170, 70),
		fruitSize = Vector3.new(0.7, 1.6, 0.4),
		variant = { id = "Grape", name = "de Uva", color = Color3.fromRGB(140, 60, 200), mult = 1.6 },
	},
	-- Mitico
	{
		id = "VenusFlyTrap", name = "Dioneia", rarity = "Mythic", price = 7000000,
		multiHarvest = true, growTime = 520, fruitTime = 130, maxFruits = 3,
		baseValue = 170000, baseWeight = 2.85,
		stockChance = 0.08, stockMin = 1, stockMax = 1,
		plantType = "flytrap", height = 3,
		fruitColor = Color3.fromRGB(220, 40, 60), leafColor = Color3.fromRGB(90, 180, 60),
		fruitSize = Vector3.new(0.6, 0.6, 0.6),
		defense = { kind = "bite", radius = 4.5, damage = 75, cooldown = 6 },
		variant = { id = "Purple", name = "Roxa", color = Color3.fromRGB(150, 40, 170), mult = 1.6 },
	},
	{
		id = "Pepper", name = "Pimenta", rarity = "Mythic", price = 9000000, classic = true,
		multiHarvest = true, growTime = 520, fruitTime = 130, maxFruits = 5,
		baseValue = 140000, baseWeight = 4.75,
		stockChance = 0.08, stockMin = 1, stockMax = 1,
		plantType = "bush", height = 2.6,
		fruitColor = Color3.fromRGB(225, 20, 20), leafColor = Color3.fromRGB(60, 150, 50),
		fruitSize = Vector3.new(0.4, 1, 0.4),
		variant = { id = "Green", name = "Verde", color = Color3.fromRGB(60, 180, 50), mult = 1.6 },
	},
	{
		id = "Pomegranate", name = "Romã", rarity = "Mythic", price = 10000000,
		multiHarvest = true, growTime = 540, fruitTime = 130, maxFruits = 5,
		baseValue = 145000, baseWeight = 2.2,
		stockChance = 0.07, stockMin = 1, stockMax = 1,
		plantType = "tree", height = 6,
		fruitColor = Color3.fromRGB(190, 30, 50), leafColor = Color3.fromRGB(60, 140, 60),
		fruitSize = Vector3.new(0.75, 0.75, 0.75),
		variant = { id = "Pink", name = "Rosa", color = Color3.fromRGB(250, 150, 170), mult = 1.6 },
	},
	{
		id = "PoisonApple", name = "Maçã Envenenada", rarity = "Mythic", price = 14000000,
		multiHarvest = true, growTime = 560, fruitTime = 140, maxFruits = 4,
		baseValue = 270000, baseWeight = 2.9,
		stockChance = 0.06, stockMin = 1, stockMax = 1,
		plantType = "tree", height = 6,
		fruitColor = Color3.fromRGB(120, 40, 160), leafColor = Color3.fromRGB(40, 90, 50),
		fruitSize = Vector3.new(0.7, 0.7, 0.7),
		special = { poisonFruit = { damage = 30, slow = 6, slowTime = 6 } },
		variant = { id = "Black", name = "Negra", color = Color3.fromRGB(35, 30, 40), mult = 1.6 },
	},
	{
		id = "VenomSpitter", name = "Cuspidor de Veneno", rarity = "Mythic", price = 18000000,
		multiHarvest = true, growTime = 580, fruitTime = 140, maxFruits = 3,
		baseValue = 465000, baseWeight = 4,
		stockChance = 0.05, stockMin = 1, stockMax = 1,
		plantType = "spitter", height = 3,
		fruitColor = Color3.fromRGB(130, 230, 50), leafColor = Color3.fromRGB(60, 130, 50),
		fruitSize = Vector3.new(0.7, 0.7, 0.7),
		defense = { kind = "ranged", radius = 12, damage = 15, cooldown = 2 },
		variant = { id = "Blue", name = "Azul", color = Color3.fromRGB(60, 150, 240), mult = 1.6 },
	},
	{
		id = "Cacao", name = "Cacau", rarity = "Mythic", price = 20000000, classic = true,
		multiHarvest = true, growTime = 600, fruitTime = 150, maxFruits = 4,
		baseValue = 420000, baseWeight = 7.6,
		stockChance = 0.05, stockMin = 1, stockMax = 1,
		plantType = "tree", height = 6,
		fruitColor = Color3.fromRGB(150, 90, 40), leafColor = Color3.fromRGB(50, 130, 50),
		fruitSize = Vector3.new(0.7, 1.1, 0.7),
		variant = { id = "White", name = "Branco", color = Color3.fromRGB(240, 230, 200), mult = 1.6 },
	},
	{
		id = "GhostPepper", name = "Pimenta Fantasma", rarity = "Mythic", price = 24000000,
		multiHarvest = true, growTime = 600, fruitTime = 150, maxFruits = 5,
		baseValue = 400000, baseWeight = 1.2,
		stockChance = 0.05, stockMin = 1, stockMax = 1,
		plantType = "bush", height = 2.6,
		fruitColor = Color3.fromRGB(235, 235, 245), leafColor = Color3.fromRGB(90, 120, 110),
		fruitSize = Vector3.new(0.4, 1, 0.4),
		special = { ghostly = true },
		variant = { id = "Red", name = "Vermelha", color = Color3.fromRGB(230, 40, 40), mult = 1.6 },
	},
	{
		id = "RainbowSeed", name = "Semente Arco-íris", rarity = "Mythic", price = 30000000,
		multiHarvest = true, growTime = 620, fruitTime = 150, maxFruits = 4,
		baseValue = 12500, baseWeight = 1,
		stockChance = 0.04, stockMin = 1, stockMax = 1,
		plantType = "bloom", height = 3,
		fruitColor = Color3.fromRGB(255, 120, 220), leafColor = Color3.fromRGB(80, 170, 80),
		fruitSize = Vector3.new(0.7, 0.7, 0.7),
		special = { alwaysMutation = "Rainbow", rainbowPetals = true },
	},
	-- Super
	{
		id = "MoonBloom", name = "Flor da Lua", rarity = "Super", price = 75000000,
		multiHarvest = true, growTime = 700, fruitTime = 160, maxFruits = 3,
		baseValue = 1650000, baseWeight = 7,
		stockChance = 0.03, stockMin = 1, stockMax = 1,
		plantType = "bloom", height = 4,
		fruitColor = Color3.fromRGB(170, 200, 255), leafColor = Color3.fromRGB(60, 120, 140),
		fruitSize = Vector3.new(0.9, 0.9, 0.9),
		special = { nightGrowth = 2, dayGrowth = 0.75, glow = true },
		variant = { id = "Pink", name = "Rosa", color = Color3.fromRGB(255, 170, 220), mult = 1.6 },
	},
	{
		id = "DragonsBreath", name = "Sopro do Dragão", rarity = "Super", price = 100000000,
		multiHarvest = true, growTime = 720, fruitTime = 170, maxFruits = 3,
		baseValue = 2350000, baseWeight = 6,
		stockChance = 0.025, stockMin = 1, stockMax = 1,
		plantType = "spitter", height = 3.6,
		fruitColor = Color3.fromRGB(255, 80, 20), leafColor = Color3.fromRGB(160, 40, 30),
		fruitSize = Vector3.new(0.8, 0.8, 0.8),
		defense = { kind = "dragon", radius = 14, damage = 10, cooldown = 2.5 },
		variant = { id = "Blue", name = "Azul", color = Color3.fromRGB(60, 120, 255), mult = 1.6 },
	},
	{
		id = "SunBloom", name = "Flor do Sol", rarity = "Super", price = 110000000,
		multiHarvest = true, growTime = 740, fruitTime = 170, maxFruits = 3,
		baseValue = 2600000, baseWeight = 9,
		stockChance = 0.025, stockMin = 1, stockMax = 1,
		plantType = "bloom", height = 4.2,
		fruitColor = Color3.fromRGB(255, 200, 40), leafColor = Color3.fromRGB(90, 160, 60),
		fruitSize = Vector3.new(0.9, 0.9, 0.9),
		special = { dayGrowth = 2, nightGrowth = 0.5, glow = true },
		variant = { id = "Red", name = "Vermelha", color = Color3.fromRGB(255, 90, 40), mult = 1.6 },
	},
	{
		id = "HypnoBloom", name = "Flor Hipnótica", rarity = "Super", price = 150000000,
		multiHarvest = true, growTime = 760, fruitTime = 180, maxFruits = 3,
		baseValue = 3750000, baseWeight = 5,
		stockChance = 0.02, stockMin = 1, stockMax = 1,
		plantType = "bloom", height = 4,
		fruitColor = Color3.fromRGB(200, 90, 255), leafColor = Color3.fromRGB(90, 60, 140),
		fruitSize = Vector3.new(0.85, 0.85, 0.85),
		defense = { kind = "hypno", radius = 10, cooldown = 8 },
		special = { glow = true },
		variant = { id = "Green", name = "Verde", color = Color3.fromRGB(90, 230, 140), mult = 1.6 },
	},
	{
		id = "Beanstalk", name = "Pé de Feijão", rarity = "Super", price = 200000000, classic = true,
		multiHarvest = true, growTime = 780, fruitTime = 180, maxFruits = 5,
		baseValue = 3000000, baseWeight = 9.5,
		stockChance = 0.02, stockMin = 1, stockMax = 1,
		plantType = "beanstalk", height = 10,
		fruitColor = Color3.fromRGB(100, 210, 70), leafColor = Color3.fromRGB(60, 170, 60),
		fruitSize = Vector3.new(0.5, 1.2, 0.5),
		variant = { id = "Gold", name = "Dourado", color = Color3.fromRGB(240, 200, 60), mult = 1.6 },
	},
	{
		id = "StarFruit", name = "Carambola", rarity = "Super", price = 315000000,
		multiHarvest = true, growTime = 800, fruitTime = 190, maxFruits = 4,
		baseValue = 6200000, baseWeight = 1.5,
		stockChance = 0.015, stockMin = 1, stockMax = 1,
		plantType = "tree", height = 6.5,
		fruitColor = Color3.fromRGB(255, 230, 80), leafColor = Color3.fromRGB(70, 160, 90),
		fruitSize = Vector3.new(0.7, 0.9, 0.7),
		special = { fruitMutations = { Starstruck = 0.02 } },
		variant = { id = "Green", name = "Verde", color = Color3.fromRGB(180, 230, 90), mult = 1.6 },
	},
	-- Secreto (so por fusao com a Espatula)
	{
		id = "EclipseBloom", name = "Flor do Eclipse", rarity = "Secret", price = 0, inShop = false,
		multiHarvest = true, growTime = 760, fruitTime = 180, maxFruits = 3,
		baseValue = 5000000, baseWeight = 9,
		stockChance = 0, stockMin = 0, stockMax = 0,
		plantType = "bloom", height = 4.5,
		fruitColor = Color3.fromRGB(90, 60, 140), leafColor = Color3.fromRGB(40, 30, 60),
		fruitSize = Vector3.new(0.95, 0.95, 0.95),
		special = { triggersWeather = "Eclipse", glow = true },
	},
	{
		id = "InfernoPepper", name = "Pimenta Infernal", rarity = "Secret", price = 0, inShop = false,
		multiHarvest = true, growTime = 600, fruitTime = 140, maxFruits = 5,
		baseValue = 600000, baseWeight = 1.5,
		stockChance = 0, stockMin = 0, stockMax = 0,
		plantType = "bush", height = 2.8,
		fruitColor = Color3.fromRGB(255, 60, 20), leafColor = Color3.fromRGB(120, 40, 30),
		fruitSize = Vector3.new(0.45, 1.05, 0.45),
		special = { fruitMutations = { Ignited = 0.12 } },
	},
	{
		id = "GalaxyFruit", name = "Fruta Galáctica", rarity = "Secret", price = 0, inShop = false,
		multiHarvest = true, growTime = 820, fruitTime = 190, maxFruits = 4,
		baseValue = 9000000, baseWeight = 2,
		stockChance = 0, stockMin = 0, stockMax = 0,
		plantType = "tree", height = 6.5,
		fruitColor = Color3.fromRGB(80, 60, 200), leafColor = Color3.fromRGB(40, 40, 90),
		fruitSize = Vector3.new(0.8, 0.8, 0.8),
		special = { fruitMutations = { Starstruck = 0.06 }, glow = true },
	},
}

-- Fusoes com a Espatula: duas plantas adultas viram uma planta secreta
Config.MergeRecipes = {
	{ a = "SunBloom", b = "MoonBloom", result = "EclipseBloom" },
	{ a = "GhostPepper", b = "FireFern", result = "InfernoPepper" },
	{ a = "StarFruit", b = "RainbowSeed", result = "GalaxyFruit" },
}

-- Crescimento visivel: broto -> planta jovem -> adulta; frutos verdes que amadurecem
Config.Growth = {
	sproutUntil = 0.15, -- ate 15% do crescimento aparece so um broto na terra
	steps = 40, -- quantos "degraus" de tamanho a planta tem ate ficar adulta
	fruitSteps = 12,
	unripeColor = Color3.fromRGB(130, 200, 80), -- cor do fruto verde (antes de amadurecer)
}

Config.BaseWalkSpeed = 16
Config.BaseJumpHeight = 7.2

-- Variante "Cristal": pode aparecer em qualquer planta (mais rara que a variante de cor)
Config.CrystalVariant = { id = "Crystal", name = "de Cristal", color = Color3.fromRGB(190, 235, 255), mult = 2.5 }
Config.VariantChance = 0.04
Config.CrystalChance = 0.01

-- Tamanhos (pelo peso em relacao ao peso medio)
Config.SizeClasses = {
	{ maxRatio = 0.85, name = "Pequeno" },
	{ maxRatio = 1.15, name = "Normal" },
	{ maxRatio = 1.6, name = "Grande" },
	{ maxRatio = 2.5, name = "Enorme" },
	{ maxRatio = 4, name = "Gigante" },
	{ maxRatio = math.huge, name = "Colossal" },
}

--[[
	Equipamentos.
	kind = "water"      -> Regador: acelera plantas proximas (usos).
	kind = "shovel"     -> Pa: remove plantas e recupera frutos roubados acertando o ladrao.
	kind = "trowel"     -> Espatula: move plantas e faz fusoes.
	kind = "sprinkler"  -> acelera o crescimento e deixa os frutos maiores por um tempo.
	kind = "consumable" -> cogumelos com efeito temporario no personagem.
	kind = "lantern"    -> luz fixa no jardim: revela ladroes invisiveis e ajuda a crescer a noite.
	kind = "gnome"      -> protege o jardim contra roubos por um tempo.
	kind = "sniper"     -> atira morangos nos ladroes (atordoa e faz soltar o fruto).
]]
Config.GearList = {
	{
		id = "WateringCan", name = "Regador", rarity = "Common", price = 2000,
		kind = "water", uses = 10, radius = 5, boost = 0.1,
		description = "10 usos. Acelera 10% do crescimento das plantas próximas.",
		stockChance = 0.9, stockMin = 1, stockMax = 3, color = Color3.fromRGB(80, 140, 230),
	},
	{
		id = "Trowel", name = "Espátula", rarity = "Common", price = 1000,
		kind = "trowel", unique = true,
		description = "Move plantas. Use em duas plantas adultas certas para fazer uma fusão secreta!",
		stockChance = 0.9, stockMin = 1, stockMax = 1, color = Color3.fromRGB(170, 170, 180),
	},
	{
		id = "Shovel", name = "Pá", rarity = "Common", price = 500,
		kind = "shovel", unique = true,
		description = "Remove plantas (clique 2x). Acerte um ladrão para recuperar seu fruto.",
		stockChance = 1, stockMin = 1, stockMax = 1, color = Color3.fromRGB(150, 110, 70),
	},
	{
		id = "SpeedMushroom", name = "Cogumelo da Velocidade", rarity = "Common", price = 1500,
		kind = "consumable", effect = "speed", amount = 8, duration = 45,
		description = "Corre mais rápido por 45 segundos.",
		stockChance = 0.8, stockMin = 1, stockMax = 3, color = Color3.fromRGB(80, 200, 255),
	},
	{
		id = "JumpMushroom", name = "Cogumelo do Pulo", rarity = "Common", price = 1800,
		kind = "consumable", effect = "jump", amount = 6, duration = 45,
		description = "Pula mais alto por 45 segundos.",
		stockChance = 0.8, stockMin = 1, stockMax = 3, color = Color3.fromRGB(120, 230, 90),
	},
	{
		id = "CommonSprinkler", name = "Sprinkler Comum", rarity = "Common", price = 3000,
		kind = "sprinkler", duration = 300, radius = 8, growth = 0.5, size = 0.1, wetChance = 0,
		description = "5 min. +50% de crescimento e frutos 10% maiores.",
		stockChance = 0.85, stockMin = 1, stockMax = 3, color = Color3.fromRGB(170, 170, 180),
	},
	{
		id = "UncommonSprinkler", name = "Sprinkler Incomum", rarity = "Uncommon", price = 10000,
		kind = "sprinkler", duration = 300, radius = 9, growth = 0.75, size = 0.15, wetChance = 0.001,
		description = "5 min. +75% de crescimento, frutos 15% maiores e chance de Molhado.",
		stockChance = 0.6, stockMin = 1, stockMax = 2, color = Color3.fromRGB(90, 210, 90),
	},
	{
		id = "Lantern", name = "Lanterna", rarity = "Uncommon", price = 12000,
		kind = "lantern", radius = 12, nightGrowth = 0.25, maxPlaced = 4,
		description = "Fica no jardim. Revela ladrões invisíveis e acelera plantas à noite.",
		stockChance = 0.5, stockMin = 1, stockMax = 2, color = Color3.fromRGB(255, 210, 120),
	},
	{
		id = "InvisibilityMushroom", name = "Cogumelo da Invisibilidade", rarity = "Rare", price = 30000,
		kind = "consumable", effect = "invisible", duration = 30,
		description = "Fica invisível por 30 s. Defesas não te veem (a não ser perto de Lanternas).",
		stockChance = 0.35, stockMin = 1, stockMax = 1, color = Color3.fromRGB(200, 200, 255),
	},
	{
		id = "RareSprinkler", name = "Sprinkler Raro", rarity = "Rare", price = 80000,
		kind = "sprinkler", duration = 300, radius = 11, growth = 1, size = 0.2, wetChance = 0.002,
		description = "5 min. +100% de crescimento, frutos 20% maiores e chance de Molhado.",
		stockChance = 0.4, stockMin = 1, stockMax = 1, color = Color3.fromRGB(80, 160, 230),
	},
	{
		id = "Gnome", name = "Gnomo", rarity = "Epic", price = 100000,
		kind = "gnome", duration = 600, maxPlaced = 2,
		description = "Protege seu jardim contra roubos por 10 minutos.",
		stockChance = 0.3, stockMin = 1, stockMax = 1, color = Color3.fromRGB(220, 50, 50),
	},
	{
		id = "LegendarySprinkler", name = "Sprinkler Lendário", rarity = "Legendary", price = 1200000,
		kind = "sprinkler", duration = 420, radius = 14, growth = 1.5, size = 0.3, wetChance = 0.003,
		description = "7 min. +150% de crescimento, frutos 30% maiores.",
		stockChance = 0.15, stockMin = 1, stockMax = 1, color = Color3.fromRGB(255, 210, 60),
	},
	{
		id = "SuperSprinkler", name = "Sprinkler Super", rarity = "Super", price = 3000000,
		kind = "sprinkler", duration = 600, radius = 16, growth = 2.5, size = 0.4, wetChance = 0.004,
		description = "10 min. +250% de crescimento, frutos 40% maiores.",
		stockChance = 0.06, stockMin = 1, stockMax = 1, color = Color3.fromRGB(255, 120, 40),
	},
	{
		id = "StrawberrySniper", name = "Atirador de Morango", rarity = "Mythic", price = 13000000,
		kind = "sniper", unique = true, range = 45, cooldown = 3,
		description = "Atira em ladrões: atordoa e faz soltar o fruto roubado.",
		stockChance = 0.05, stockMin = 1, stockMax = 1, color = Color3.fromRGB(225, 30, 55),
	},
}

-- Ids antigos que mudaram de nome (para dados salvos de versoes anteriores)
Config.LegacyIds = {
	gear = {
		BasicSprinkler = "CommonSprinkler",
		AdvancedSprinkler = "UncommonSprinkler",
		GodlySprinkler = "LegendarySprinkler",
		MasterSprinkler = "SuperSprinkler",
	},
	seeds = {
		OrangeTulip = "Tulip",
	},
	pets = {
		Fox = "Deer",
		Panda = "Bear",
	},
}

---------------------------------------------------------------------
-- Pets: cada pet tem uma ou mais habilidades
---------------------------------------------------------------------
--[[
	Tipos de habilidade:
	  Growth, Sell, Luck, NightLuck, Gold, Rainbow, Size  -> bonus em fracao (0.1 = +10%)
	  Speed, Jump, Inventory                              -> bonus fixo
	  AutoHarvest (cooldown, seedChance)  -> colhe um fruto maduro sozinho
	  AutoHarvestBest (cooldown)          -> colhe o fruto mais valioso
	  GuardStun / GuardSting / GuardLaunch / GuardEject (cooldown) -> ataca ladroes no seu jardim
	  Pollinate / Ignite (chance)         -> aplica mutacao nos seus frutos
	  Raccoon                             -> uma vez por noite copia um fruto maduro de outro jardim
]]
Config.PetList = {
	{ id = "Frog", name = "Sapo", rarity = "Common", color = Color3.fromRGB(90, 200, 70), accent = Color3.fromRGB(240, 240, 120), size = 0.85,
		abilities = { { kind = "Jump", value = 4 } } },
	{ id = "Bunny", name = "Coelho", rarity = "Common", color = Color3.fromRGB(240, 240, 240), accent = Color3.fromRGB(255, 180, 200), size = 0.9,
		abilities = { { kind = "Speed", value = 3 } } },
	{ id = "Cat", name = "Gato", rarity = "Common", color = Color3.fromRGB(250, 170, 70), accent = Color3.fromRGB(255, 240, 220), size = 0.9,
		abilities = { { kind = "Sell", value = 0.05 } } },
	{ id = "Owl", name = "Coruja", rarity = "Uncommon", color = Color3.fromRGB(140, 100, 70), accent = Color3.fromRGB(240, 210, 120), size = 0.9,
		abilities = { { kind = "NightLuck", value = 0.3 } } },
	{ id = "Dog", name = "Cachorro", rarity = "Uncommon", color = Color3.fromRGB(190, 140, 90), accent = Color3.fromRGB(120, 80, 50), size = 1,
		abilities = { { kind = "GuardStun", value = 1, cooldown = 12 } } },
	{ id = "Chicken", name = "Galinha", rarity = "Uncommon", color = Color3.fromRGB(255, 255, 250), accent = Color3.fromRGB(230, 40, 40), size = 0.9,
		abilities = { { kind = "Growth", value = 0.08 } } },
	{ id = "Deer", name = "Cervo", rarity = "Rare", color = Color3.fromRGB(170, 110, 60), accent = Color3.fromRGB(250, 240, 220), size = 1.1,
		abilities = { { kind = "Growth", value = 0.1 } } },
	{ id = "Turtle", name = "Tartaruga", rarity = "Rare", color = Color3.fromRGB(90, 160, 80), accent = Color3.fromRGB(150, 110, 60), size = 1,
		abilities = { { kind = "Inventory", value = 10 }, { kind = "Speed", value = -2 } } },
	{ id = "Pig", name = "Porco", rarity = "Rare", color = Color3.fromRGB(255, 170, 190), accent = Color3.fromRGB(230, 120, 150), size = 1,
		abilities = { { kind = "Sell", value = 0.1 } } },
	{ id = "Robin", name = "Pintarroxo", rarity = "Legendary", color = Color3.fromRGB(120, 90, 70), accent = Color3.fromRGB(240, 110, 50), size = 0.8,
		abilities = { { kind = "AutoHarvest", value = 1, cooldown = 30, seedChance = 0.1 } } },
	{ id = "Bee", name = "Abelha", rarity = "Legendary", color = Color3.fromRGB(255, 210, 40), accent = Color3.fromRGB(30, 30, 30), size = 0.8,
		abilities = { { kind = "GuardSting", value = 12, cooldown = 4 }, { kind = "Pollinate", value = 0.002 } } },
	{ id = "Butterfly", name = "Borboleta", rarity = "Legendary", color = Color3.fromRGB(120, 160, 255), accent = Color3.fromRGB(255, 150, 220), size = 0.8,
		abilities = { { kind = "Growth", value = 0.2 } } },
	{ id = "Monkey", name = "Macaco", rarity = "Mythic", color = Color3.fromRGB(140, 90, 60), accent = Color3.fromRGB(240, 200, 160), size = 1,
		abilities = { { kind = "AutoHarvestBest", value = 1, cooldown = 45 } } },
	{ id = "Bear", name = "Urso", rarity = "Mythic", color = Color3.fromRGB(120, 80, 50), accent = Color3.fromRGB(80, 50, 30), size = 1.3,
		abilities = { { kind = "GuardLaunch", value = 1, cooldown = 15 } } },
	{ id = "Unicorn", name = "Unicórnio", rarity = "Mythic", color = Color3.fromRGB(255, 250, 255), accent = Color3.fromRGB(255, 120, 220), size = 1.2,
		abilities = { { kind = "Rainbow", value = 1 } } },
	{ id = "GoldenDragonfly", name = "Libélula Dourada", rarity = "Mythic", color = Color3.fromRGB(255, 200, 40), accent = Color3.fromRGB(255, 240, 150), size = 0.8,
		abilities = { { kind = "Gold", value = 1 } } },
	{ id = "Firefly", name = "Vagalume", rarity = "Mythic", color = Color3.fromRGB(60, 60, 40), accent = Color3.fromRGB(230, 255, 100), size = 0.7,
		abilities = { { kind = "Size", value = 0.25 } } },
	{ id = "BaldEagle", name = "Águia", rarity = "Mythic", color = Color3.fromRGB(110, 70, 40), accent = Color3.fromRGB(255, 255, 255), size = 1.1,
		abilities = { { kind = "GuardEject", value = 1, cooldown = 20 } } },
	{ id = "Dragon", name = "Dragão", rarity = "Super", color = Color3.fromRGB(200, 40, 40), accent = Color3.fromRGB(255, 200, 40), size = 1.25,
		abilities = { { kind = "Ignite", value = 0.0006 }, { kind = "Sell", value = 0.15 } } },
	{ id = "Phoenix", name = "Fênix", rarity = "Super", color = Color3.fromRGB(255, 120, 30), accent = Color3.fromRGB(255, 230, 60), size = 1.15,
		abilities = { { kind = "Growth", value = 0.35 }, { kind = "Luck", value = 0.2 } } },
	{ id = "Raccoon", name = "Guaxinim", rarity = "Secret", color = Color3.fromRGB(120, 120, 130), accent = Color3.fromRGB(40, 40, 45), size = 1,
		abilities = { { kind = "Raccoon", value = 1 } } },
	{ id = "Kitsune", name = "Kitsune", rarity = "Secret", color = Color3.fromRGB(255, 160, 60), accent = Color3.fromRGB(255, 255, 255), size = 1.1,
		abilities = { { kind = "Luck", value = 0.6 }, { kind = "Gold", value = 0.5 }, { kind = "Rainbow", value = 0.5 } } },
}

Config.PetAbilityText = {
	Growth = "Crescimento +%s",
	Sell = "Venda +%s",
	Luck = "Sorte de mutação +%s",
	NightLuck = "Sorte à noite +%s",
	Gold = "Chance de Dourado +%s",
	Rainbow = "Chance de Arco-íris +%s",
	Size = "Frutos maiores +%s",
	Speed = "Velocidade %s",
	Jump = "Pulo %s",
	Inventory = "Mochila %s espaços",
	AutoHarvest = "Colhe um fruto sozinho a cada %ds",
	AutoHarvestBest = "Colhe o fruto mais valioso a cada %ds",
	GuardStun = "Atordoa ladrões (a cada %ds)",
	GuardSting = "Ferroa ladrões (a cada %ds)",
	GuardLaunch = "Arremessa ladrões para fora (a cada %ds)",
	GuardEject = "Expulsa ladrões voando (a cada %ds)",
	Pollinate = "Poliniza seus frutos",
	Ignite = "Incendeia seus frutos (Inflamado)",
	Raccoon = "Copia 1 fruto de outro jardim por noite",
}

-- Variantes de pet ao chocar (novidade inspirada nos ovos Big/Rainbow/Mega do GAG2)
Config.PetVariants = {
	{ id = "Normal", name = "", weight = 85, mult = 1, scale = 1 },
	{ id = "Big", name = "Grande", weight = 10, mult = 1.5, scale = 1.3 },
	{ id = "Rainbow", name = "Arco-íris", weight = 4, mult = 2, scale = 1.1 },
	{ id = "Mega", name = "Mega", weight = 1, mult = 3, scale = 1.8 },
}
Config.PetMaxLevel = 50
Config.PetXpPerLevel = 20 -- nivel = 1 + raiz(xp / 20)
Config.PetLevelBonus = 0.02 -- +2% de forca por nivel

-- Ovos (pesos = chance de cada pet)
Config.EggList = {
	{
		id = "CommonEgg", name = "Ovo Comum", rarity = "Common", price = 10000, hatchTime = 60,
		stockChance = 1, stockMin = 1, stockMax = 3, color = Color3.fromRGB(240, 235, 220),
		pets = { { pet = "Frog", weight = 30 }, { pet = "Bunny", weight = 30 }, { pet = "Cat", weight = 25 }, { pet = "Owl", weight = 10 }, { pet = "Dog", weight = 5 } },
	},
	{
		id = "UncommonEgg", name = "Ovo Incomum", rarity = "Uncommon", price = 50000, hatchTime = 180,
		stockChance = 0.7, stockMin = 1, stockMax = 2, color = Color3.fromRGB(150, 230, 140),
		pets = { { pet = "Owl", weight = 30 }, { pet = "Dog", weight = 30 }, { pet = "Chicken", weight = 30 }, { pet = "Deer", weight = 10 } },
	},
	{
		id = "RareEgg", name = "Ovo Raro", rarity = "Rare", price = 300000, hatchTime = 360,
		stockChance = 0.45, stockMin = 1, stockMax = 2, color = Color3.fromRGB(120, 170, 255),
		pets = { { pet = "Deer", weight = 35 }, { pet = "Turtle", weight = 30 }, { pet = "Pig", weight = 30 }, { pet = "Robin", weight = 5 } },
	},
	{
		id = "LegendaryEgg", name = "Ovo Lendário", rarity = "Legendary", price = 2500000, hatchTime = 600,
		stockChance = 0.2, stockMin = 1, stockMax = 1, color = Color3.fromRGB(255, 215, 70),
		pets = { { pet = "Robin", weight = 30 }, { pet = "Bee", weight = 30 }, { pet = "Butterfly", weight = 30 }, { pet = "Monkey", weight = 10 } },
	},
	{
		id = "MythicEgg", name = "Ovo Mítico", rarity = "Mythic", price = 25000000, hatchTime = 900,
		stockChance = 0.08, stockMin = 1, stockMax = 1, color = Color3.fromRGB(255, 110, 180),
		pets = {
			{ pet = "Monkey", weight = 15 }, { pet = "Bear", weight = 25 }, { pet = "Unicorn", weight = 15 },
			{ pet = "GoldenDragonfly", weight = 15 }, { pet = "Firefly", weight = 20 }, { pet = "BaldEagle", weight = 10 },
		},
	},
	{
		id = "SuperEgg", name = "Ovo Super", rarity = "Super", price = 150000000, hatchTime = 1200,
		stockChance = 0.03, stockMin = 1, stockMax = 1, color = Color3.fromRGB(255, 140, 50),
		pets = { { pet = "Dragon", weight = 45 }, { pet = "Phoenix", weight = 45 }, { pet = "Raccoon", weight = 6 }, { pet = "Kitsune", weight = 4 } },
	},
}

---------------------------------------------------------------------
-- Mutacoes
---------------------------------------------------------------------
--[[
	kind = "growth": aparece quando o fruto nasce (so uma por fruto, fica a melhor).
	kind = "env": vem do clima, da noite, de pets, plantas e sprinklers.
	Valor final = crescimento x (1 + soma(mult - 1) das mutacoes de ambiente).
	effect = efeito visual no fruto (sparkles, fire, smoke ou nenhum).
]]
Config.Mutations = {
	Gold = { name = "Dourado", kind = "growth", mult = 20, color = Color3.fromRGB(255, 205, 40), material = "Foil", effect = "sparkles", source = "Chance ao nascer (Lua Dourada aumenta)" },
	Rainbow = { name = "Arco-íris", kind = "growth", mult = 50, color = Color3.fromRGB(255, 120, 220), material = "SmoothPlastic", effect = "sparkles", rainbow = true, source = "Chance ao nascer (Lua/Clima Arco-íris aumenta)" },
	Wet = { name = "Molhado", kind = "env", mult = 2, color = Color3.fromRGB(90, 160, 255), material = "Glass", blend = 0.45, source = "Chuva, Tempestade e Sprinklers" },
	Chilled = { name = "Gelado", kind = "env", mult = 2, color = Color3.fromRGB(160, 215, 255), material = "SmoothPlastic", blend = 0.55, source = "Geada" },
	Choc = { name = "Chocolate", kind = "env", mult = 2, color = Color3.fromRGB(110, 60, 30), material = "SmoothPlastic", blend = 0.6, source = "Chuva de Chocolate" },
	Moonlit = { name = "Lunar", kind = "env", mult = 3, color = Color3.fromRGB(170, 170, 255), material = "SmoothPlastic", blend = 0.5, effect = "sparkles", source = "Noite" },
	Pollinated = { name = "Polinizado", kind = "env", mult = 3, color = Color3.fromRGB(255, 220, 60), material = "SmoothPlastic", blend = 0.4, source = "Pet Abelha" },
	Sandy = { name = "Arenoso", kind = "env", mult = 3, color = Color3.fromRGB(225, 200, 140), material = "Sand", blend = 0.6, source = "Tempestade de Areia" },
	Clay = { name = "Barro", kind = "env", mult = 5, color = Color3.fromRGB(170, 110, 70), material = "Slate", source = "Molhado + Arenoso" },
	Frozen = { name = "Congelado", kind = "env", mult = 10, color = Color3.fromRGB(175, 235, 255), material = "Ice", effect = "sparkles", source = "Molhado + Gelado, ou Nevasca" },
	Glowing = { name = "Brilhante", kind = "env", mult = 12, color = Color3.fromRGB(120, 255, 230), material = "Neon", source = "Cogumelo Brilhante por perto à noite" },
	Electric = { name = "Elétrico", kind = "env", mult = 25, color = Color3.fromRGB(120, 200, 255), material = "SmoothPlastic", effect = "sparkles", source = "Tempestade" },
	Twisted = { name = "Torcido", kind = "env", mult = 30, color = Color3.fromRGB(170, 170, 160), material = "SmoothPlastic", blend = 0.5, effect = "smoke", source = "Tornado" },
	Ceramic = { name = "Cerâmica", kind = "env", mult = 30, color = Color3.fromRGB(235, 225, 210), material = "SmoothPlastic", source = "Barro + Ressecado" },
	Aurora = { name = "Aurora", kind = "env", mult = 45, color = Color3.fromRGB(90, 255, 170), material = "Neon", effect = "sparkles", source = "Aurora" },
	Starstruck = { name = "Estelar", kind = "env", mult = 50, color = Color3.fromRGB(255, 240, 150), material = "Neon", effect = "sparkles", source = "Chuva de Estrelas" },
	Bloodlit = { name = "Sangrento", kind = "env", mult = 60, color = Color3.fromRGB(200, 20, 30), material = "SmoothPlastic", effect = "smoke", source = "Lua de Sangue" },
	Ignited = { name = "Inflamado", kind = "env", mult = 60, color = Color3.fromRGB(255, 110, 20), material = "Neon", effect = "fire", source = "Explosão Solar e plantas de fogo" },
	Sundried = { name = "Ressecado", kind = "env", mult = 85, color = Color3.fromRGB(170, 110, 50), material = "Sand", source = "Onda de Calor" },
	Shocked = { name = "Eletrizado", kind = "env", mult = 100, color = Color3.fromRGB(110, 210, 255), material = "Neon", effect = "sparkles", source = "Raio da Tempestade" },
	Celestial = { name = "Celestial", kind = "env", mult = 120, color = Color3.fromRGB(200, 160, 255), material = "Neon", effect = "sparkles", source = "Chuva de Meteoros" },
	Eclipsed = { name = "Eclipsado", kind = "env", mult = 150, color = Color3.fromRGB(60, 30, 90), material = "Neon", effect = "smoke", source = "Eclipse (colha uma Flor do Eclipse)" },
	Plasma = { name = "Plasma", kind = "env", mult = 180, color = Color3.fromRGB(255, 80, 255), material = "Neon", effect = "fire", source = "Eletrizado + Inflamado" },
	Abyssal = { name = "Abissal", kind = "env", mult = 240, color = Color3.fromRGB(30, 10, 60), material = "Neon", effect = "smoke", source = "Eclipsado + Sangrento" },
	Cosmic = { name = "Cósmico", kind = "env", mult = 300, color = Color3.fromRGB(110, 70, 255), material = "Neon", effect = "sparkles", source = "Celestial + Estelar" },
}

-- Combinacoes: quando o fruto tem todas as mutacoes de "requires", elas viram "result"
Config.MutationCombos = {
	{ requires = { "Wet", "Chilled" }, result = "Frozen" },
	{ requires = { "Wet", "Sandy" }, result = "Clay" },
	{ requires = { "Clay", "Sundried" }, result = "Ceramic" },
	{ requires = { "Shocked", "Ignited" }, result = "Plasma" },
	{ requires = { "Eclipsed", "Bloodlit" }, result = "Abyssal" },
	{ requires = { "Celestial", "Starstruck" }, result = "Cosmic" },
}

-- Ordem de exibicao (a mutacao de maior multiplicador define a aparencia)
Config.MutationOrder = {
	"Gold", "Rainbow", "Wet", "Chilled", "Choc", "Moonlit", "Pollinated", "Sandy", "Clay", "Frozen",
	"Glowing", "Electric", "Twisted", "Ceramic", "Aurora", "Starstruck", "Bloodlit", "Ignited",
	"Sundried", "Shocked", "Celestial", "Eclipsed", "Plasma", "Abyssal", "Cosmic",
}

Config.GrowthMutationChances = {
	Rainbow = 0.001,
	Gold = 0.01,
}

Config.GiantChance = 0.02 -- chance de um fruto nascer gigante (peso muito maior)

---------------------------------------------------------------------
-- Clima
---------------------------------------------------------------------
--[[
	period = "day" (so de dia), "night" (luas, so a noite) ou "special" (Eclipse).
	mutations = chance por segundo de cada fruto ganhar a mutacao.
	strike = algo cai do ceu em um fruto aleatorio a cada "interval" segundos.
	goldBoost / rainbowBoost = multiplicam a chance de frutos novos nascerem Dourados/Arco-iris.
	sizeBoost = frutos novos nascem maiores.
	particle / skyObject = efeitos visuais no cliente.
]]
Config.WeatherList = {
	-- Dia
	{
		id = "Rain", name = "Chuva", emoji = "🌧️", period = "day", weight = 30, duration = 300,
		growthBonus = 1, mutations = { Wet = 0.004 }, particle = "rain",
		sky = { brightness = 1.3, density = 0.45, color = Color3.fromRGB(170, 180, 200) },
		description = "Plantas crescem 2x mais rápido e podem ficar Molhadas (x2).",
	},
	{
		id = "Thunderstorm", name = "Tempestade", emoji = "⛈️", period = "day", weight = 12, duration = 150,
		growthBonus = 1, mutations = { Wet = 0.003, Electric = 0.0008 }, particle = "rain",
		strike = { interval = 8, mutation = "Shocked", visual = "lightning" },
		sky = { brightness = 0.7, density = 0.55, color = Color3.fromRGB(110, 110, 140) },
		description = "Raios Eletrizam frutos (x100) e o ar deixa frutos Elétricos (x25)!",
	},
	{
		id = "Frost", name = "Geada", emoji = "❄️", period = "day", weight = 14, duration = 150,
		growthBonus = 0, mutations = { Chilled = 0.004 }, particle = "snow",
		sky = { brightness = 1.6, density = 0.5, color = Color3.fromRGB(210, 230, 255) },
		description = "Frutos ficam Gelados (x2). Molhado + Gelado = Congelado (x10)!",
	},
	{
		id = "Snowfall", name = "Nevasca", emoji = "🌨️", period = "day", weight = 8, duration = 150,
		growthBonus = 0, mutations = { Chilled = 0.003, Frozen = 0.0015 }, particle = "heavysnow",
		sky = { brightness = 1.5, density = 0.6, color = Color3.fromRGB(230, 240, 255) },
		description = "Neve forte: frutos Gelados e Congelados (x10)!",
	},
	{
		id = "Sandstorm", name = "Tempestade de Areia", emoji = "🏜️", period = "day", weight = 8, duration = 150,
		growthBonus = 0, mutations = { Sandy = 0.004 }, particle = "sand",
		sky = { brightness = 1.4, density = 0.6, color = Color3.fromRGB(230, 200, 140) },
		description = "Frutos ficam Arenosos (x3). Arenoso + Molhado = Barro (x5)!",
	},
	{
		id = "Heatwave", name = "Onda de Calor", emoji = "🔥", period = "day", weight = 5, duration = 120,
		growthBonus = 0.5, mutations = { Sundried = 0.0015 }, particle = nil,
		sky = { brightness = 2.4, density = 0.4, color = Color3.fromRGB(255, 190, 120) },
		description = "Calor extremo: frutos Ressecados (x85). Barro + Ressecado = Cerâmica!",
	},
	{
		id = "Tornado", name = "Tornado", emoji = "🌪️", period = "day", weight = 5, duration = 120,
		growthBonus = 0, mutations = {}, particle = nil,
		strike = { interval = 3, mutation = "Twisted", visual = "tornado" },
		sky = { brightness = 1, density = 0.55, color = Color3.fromRGB(160, 160, 160) },
		description = "Um tornado passa pelos jardins deixando frutos Torcidos (x30)!",
	},
	{
		id = "RainbowWeather", name = "Arco-íris", emoji = "🌈", period = "day", weight = 4, duration = 150,
		growthBonus = 0.5, mutations = { Rainbow = 0.0004 }, rainbowBoost = 10, skyObject = "rainbow",
		sky = { brightness = 2.2, density = 0.3, color = Color3.fromRGB(255, 230, 255) },
		description = "Frutos novos têm 10x mais chance de nascer Arco-íris (x50)!",
	},
	{
		id = "Sunburst", name = "Explosão Solar", emoji = "☀️", period = "day", weight = 4, duration = 120,
		growthBonus = 0.5, mutations = { Ignited = 0.0012 }, particle = nil,
		sky = { brightness = 3, density = 0.3, color = Color3.fromRGB(255, 230, 150) },
		description = "O sol queima: frutos Inflamados (x60)! Eletrizado + Inflamado = Plasma!",
	},
	{
		id = "ChocolateRain", name = "Chuva de Chocolate", emoji = "🍫", period = "day", weight = 3, duration = 150,
		growthBonus = 0.5, mutations = { Choc = 0.004 }, particle = "chocolate",
		sky = { brightness = 1.4, density = 0.45, color = Color3.fromRGB(200, 160, 130) },
		description = "Chove chocolate! Frutos de Chocolate (x2).",
	},
	-- Noite (luas)
	{
		id = "BloodMoon", name = "Lua de Sangue", emoji = "🩸", period = "night", weight = 25, duration = 120,
		growthBonus = 0, mutations = { Bloodlit = 0.004 }, skyObject = "bloodmoon",
		sky = { brightness = 1, density = 0.5, color = Color3.fromRGB(200, 60, 60) },
		description = "Frutos ficam Sangrentos (x60)! Ladrões ficam mais rápidos...",
		thiefSpeedBonus = 4,
	},
	{
		id = "GoldMoon", name = "Lua Dourada", emoji = "🌕", period = "night", weight = 20, duration = 120,
		growthBonus = 0, mutations = { Gold = 0.0006 }, goldBoost = 10, skyObject = "goldmoon",
		sky = { brightness = 1.2, density = 0.4, color = Color3.fromRGB(255, 220, 120) },
		description = "Frutos novos têm 10x mais chance de nascer Dourados (x20)!",
	},
	{
		id = "RainbowMoon", name = "Lua Arco-íris", emoji = "🌙", period = "night", weight = 10, duration = 120,
		growthBonus = 0, mutations = { Rainbow = 0.0003 }, rainbowBoost = 10, skyObject = "rainbowmoon",
		sky = { brightness = 1.2, density = 0.4, color = Color3.fromRGB(255, 160, 255) },
		description = "Frutos novos têm 10x mais chance de nascer Arco-íris (x50)!",
	},
	{
		id = "MegaMoon", name = "Lua Gigante", emoji = "🌝", period = "night", weight = 15, duration = 120,
		growthBonus = 0.5, mutations = {}, sizeBoost = 0.6, skyObject = "megamoon",
		sky = { brightness = 1.3, density = 0.35, color = Color3.fromRGB(230, 230, 255) },
		description = "Frutos novos nascem 60% maiores e plantas crescem mais rápido!",
	},
	{
		id = "MeteorShower", name = "Chuva de Meteoros", emoji = "☄️", period = "night", weight = 12, duration = 120,
		growthBonus = 0, mutations = {},
		strike = { interval = 6, mutation = "Celestial", visual = "meteor" },
		sky = { brightness = 1, density = 0.4, color = Color3.fromRGB(170, 140, 255) },
		description = "Meteoros caem nos frutos: Celestial (x120)!",
	},
	{
		id = "Aurora", name = "Aurora", emoji = "🌌", period = "night", weight = 10, duration = 120,
		growthBonus = 0.25, mutations = { Aurora = 0.002 }, skyObject = "aurora",
		sky = { brightness = 1.1, density = 0.35, color = Color3.fromRGB(120, 255, 200) },
		description = "Luzes no céu: frutos Aurora (x45)!",
	},
	{
		id = "Starfall", name = "Chuva de Estrelas", emoji = "🌠", period = "night", weight = 10, duration = 120,
		growthBonus = 0, mutations = {},
		strike = { interval = 5, mutation = "Starstruck", visual = "star", count = 2 },
		sky = { brightness = 1.1, density = 0.35, color = Color3.fromRGB(255, 240, 180) },
		description = "Estrelas cadentes deixam frutos Estelares (x50)! Celestial + Estelar = Cósmico!",
	},
	-- Especial
	{
		id = "Eclipse", name = "Eclipse", emoji = "🌑", period = "special", weight = 0, duration = 120,
		growthBonus = 0, mutations = { Eclipsed = 0.0015 }, skyObject = "eclipse",
		sky = { brightness = 0.5, density = 0.5, color = Color3.fromRGB(80, 60, 120) },
		description = "O sol escureceu! Frutos Eclipsados (x150). Eclipsado + Sangrento = Abissal!",
		cooldown = 900,
	},
}

---------------------------------------------------------------------
-- Missoes diarias (novidade)
---------------------------------------------------------------------

Config.Quests = {
	perDay = 3,
	templates = {
		{ id = "harvest", icon = "🧺", text = "Colha %d frutos", min = 20, max = 60, reward = 25 },
		{ id = "plant", icon = "🌱", text = "Plante %d sementes", min = 5, max = 20, reward = 60 },
		{ id = "mutated", icon = "✨", text = "Colha %d frutos com mutação", min = 3, max = 12, reward = 400 },
		{ id = "sell", icon = "💰", text = "Venda %d frutos", min = 20, max = 80, reward = 30 },
		{ id = "steal", icon = "🦝", text = "Roube %d fruto(s) à noite", min = 1, max = 3, reward = 1500 },
		{ id = "hatch", icon = "🥚", text = "Choque %d ovo(s)", min = 1, max = 2, reward = 2500 },
	},
}

---------------------------------------------------------------------
-- Indices por id (preenchidos automaticamente)
---------------------------------------------------------------------

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

for _, seed in Config.SeedList do
	if seed.inShop == nil then
		seed.inShop = true
	end
end

return Config
