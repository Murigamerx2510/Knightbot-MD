-- GardenServer: script principal do servidor.
-- Cria o mapa, liga os servicos e cuida da entrada/saida dos jogadores.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(script.Remotes)
local DataService = require(script.DataService)
local MapBuilder = require(script.MapBuilder)
local Sync = require(script.Sync)
local PetService = require(script.PetService)
local QuestService = require(script.QuestService)
local GardenService = require(script.GardenService)
local ShopService = require(script.ShopService)
local DayNightService = require(script.DayNightService)
local WeatherService = require(script.WeatherService)
local StealService = require(script.StealService)

local map = MapBuilder.build()
GardenService.init(map)
ShopService.init(map)

-- ligacoes entre servicos
GardenService.hooks.steal = StealService.trySteal
GardenService.hooks.bonk = StealService.bonk
GardenService.hooks.snipe = StealService.snipe
GardenService.hooks.consume = StealService.consume
GardenService.hooks.weatherTrigger = function(weatherId)
	WeatherService.trigger(weatherId)
end
PetService.onChanged(GardenService.invalidateBonuses)
Sync.addProvider(function(player, snapshot)
	local data = DataService.get(player)
	if data then
		QuestService.ensure(player, data)
		snapshot.quests = QuestService.snapshot(data)
	end
end)

Sync.start()
GardenService.start()
ShopService.start()
DayNightService.start(map)
WeatherService.start()
StealService.start()

---------------------------------------------------------------------
-- Jogadores
---------------------------------------------------------------------

local function moveCharacter(player: Player, cf: CFrame?)
	local character = player.Character
	if cf and character and character.Parent and character:FindFirstChild("HumanoidRootPart") then
		character:PivotTo(cf)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	-- CharacterAdded dispara antes do personagem entrar no Workspace
	local start = os.clock()
	while not character.Parent and os.clock() - start < 5 do
		task.wait()
	end
	task.wait(0.1)
	moveCharacter(player, GardenService.getGardenCFrame(player))
	Sync.markDirty(player) -- recria as ferramentas na mochila nova
end

local function findWeather(name: string)
	for _, weather in Config.WeatherList do
		if string.lower(weather.id) == name or string.lower(weather.name) == name then
			return weather
		end
	end
	-- aceita nomes com espaco digitados juntos ("luadesangue")
	for _, weather in Config.WeatherList do
		if string.gsub(string.lower(weather.name), " ", "") == name then
			return weather
		end
	end
	return nil
end

local function handleCommand(player: Player, message: string)
	local data = DataService.get(player)
	if not data then
		return
	end
	local words = string.split(string.lower(message), " ")
	local command = words[1]
	if command == "/sheckles" or command == "/dinheiro" then
		local amount = tonumber(words[2]) or 100000
		data.sheckles += math.floor(amount)
		Sync.notify(player, "[Teste] +" .. amount .. " Sheckles", "info")
	elseif command == "/clima" then
		local wanted = table.concat(words, "", 2)
		if wanted == "parar" then
			WeatherService.stopEvent()
		else
			local weather = findWeather(wanted)
			if weather then
				WeatherService.startEvent(weather.id)
			else
				Sync.notify(player, "[Teste] Clima não encontrado. Ex.: /clima chuva, /clima luadesangue, /clima eclipse", "error")
			end
		end
	elseif command == "/noite" then
		DayNightService.skipTo("Night")
		Sync.notify(player, "[Teste] Virou noite!", "info")
	elseif command == "/dia" then
		DayNightService.skipTo("Day")
		Sync.notify(player, "[Teste] Virou dia!", "info")
	elseif command == "/crescer" then
		GardenService.growAll(player)
		Sync.notify(player, "[Teste] Todas as plantas cresceram!", "info")
	elseif command == "/estoque" then
		ShopService.fillStock(data)
		Sync.notify(player, "[Teste] Estoque das lojas cheio!", "info")
	elseif command == "/pet" then
		local wanted = words[2] or ""
		for _, pet in Config.PetList do
			if string.lower(pet.id) == wanted or string.lower(pet.name) == wanted then
				PetService.addPet(player, data, pet.id, words[3] and string.upper(string.sub(words[3], 1, 1)) .. string.sub(words[3], 2) or nil)
				Sync.notify(player, "[Teste] Pet " .. pet.name .. " adicionado!", "info")
			end
		end
	end
	Sync.markDirty(player)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	-- ao renascer o Roblox cria uma mochila nova: recria as ferramentas
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			Sync.markDirty(player)
		end
	end)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local sheckles = Instance.new("IntValue")
	sheckles.Name = "Sheckles"
	sheckles.Value = 0
	sheckles.Parent = leaderstats
	leaderstats.Parent = player

	local data, canSave = DataService.load(player)
	if not player.Parent then
		DataService.release(player)
		return
	end
	ShopService.ensureStock(data)
	PetService.setup(player, data)
	QuestService.ensure(player, data)
	if not GardenService.assignPlot(player, data) then
		DataService.release(player)
		player:Kick("Este servidor está cheio (máximo de 6 jardins). Tente outro servidor!")
		return
	end
	Sync.markDirty(player)
	Sync.notify(player, "Bem-vindo(a) ao " .. Config.GameName .. "! Compre sementes com o Sam e plante no seu jardim.", "info")
	if not canSave then
		Sync.notify(player, "⚠️ Salvamento indisponível: seu progresso NÃO será salvo nesta sessão.", "error")
	end
	if RunService:IsStudio() then
		Sync.notify(player, "Modo Studio: /sheckles 1000, /crescer, /estoque, /noite, /dia, /clima chuva, /pet unicornio", "info")
		player.Chatted:Connect(function(message)
			handleCommand(player, message)
		end)
	end
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	DataService.save(player)
	DataService.release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- salvamento automatico
task.spawn(function()
	while true do
		task.wait(Config.AutoSaveInterval)
		for _, player in DataService.getPlayers() do
			task.spawn(DataService.save, player)
		end
	end
end)

game:BindToClose(function()
	DataService.saveAll(25)
end)

---------------------------------------------------------------------
-- Pedidos do cliente
---------------------------------------------------------------------

local function safe(handler: (...any) -> (boolean, string))
	return function(...)
		local ok, success, message = pcall(handler, ...)
		if ok then
			return success, message
		end
		warn("[Jardim] Erro: " .. tostring(success))
		return false, "Erro no servidor. Tente novamente."
	end
end

Remotes.Buy.OnServerInvoke = safe(ShopService.buy)
Remotes.Sell.OnServerInvoke = safe(ShopService.sell)
Remotes.PetAction.OnServerInvoke = safe(PetService.handleAction)
Remotes.QuestAction.OnServerInvoke = safe(QuestService.claim)

Remotes.UseItem.OnServerEvent:Connect(function(player, kind, id, position)
	GardenService.useItem(player, kind, id, position)
end)

local lastTeleport: { [Player]: number } = {}
Remotes.Teleport.OnServerEvent:Connect(function(player, place)
	if type(place) ~= "string" then
		return
	end
	if StealService.isCarrying(player) then
		Sync.notify(player, "Você não pode se teletransportar carregando um fruto roubado!", "error")
		return
	end
	local now = os.clock()
	if lastTeleport[player] and now - lastTeleport[player] < 0.8 then
		return
	end
	lastTeleport[player] = now
	local cf = if place == "Garden" then GardenService.getGardenCFrame(player) else map.locations[place]
	moveCharacter(player, cf)
end)

Players.PlayerRemoving:Connect(function(player)
	lastTeleport[player] = nil
end)

print("[Jardim] Servidor pronto!")
