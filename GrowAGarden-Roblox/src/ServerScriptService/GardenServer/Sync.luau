-- Sync: envia o estado do jogador para a interface e mostra notificacoes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local DataService = require(script.Parent.DataService)
local Inventory = require(script.Parent.Inventory)
local Remotes = require(script.Parent.Remotes)

local Sync = {}

local dirty: { [Player]: boolean } = {}
local extraProviders: { (Player, { [string]: any }) -> () } = {}

-- Permite que outros servicos acrescentem campos ao estado enviado
function Sync.addProvider(provider: (Player, { [string]: any }) -> ())
	table.insert(extraProviders, provider)
end

function Sync.markDirty(player: Player)
	dirty[player] = true
end

function Sync.notify(player: Player, text: string, kind: string?)
	if player.Parent then
		Remotes.Notify:FireClient(player, text, kind or "info")
	end
end

function Sync.notifyAll(text: string, kind: string?)
	Remotes.Notify:FireAllClients(text, kind or "info")
end

local function buildSnapshot(player: Player, data)
	local bonuses = Formulas.petBonuses(data.pets, data.equippedPets)
	local fruits = {}
	for index, fruit in data.fruits do
		table.insert(fruits, {
			i = index,
			s = fruit.s,
			w = fruit.w,
			m = fruit.m,
			v = Formulas.fruitValue(fruit.s, fruit.w, fruit.m, bonuses.Sell),
		})
	end
	local pets = {}
	for _, pet in data.pets do
		table.insert(pets, { id = pet.id, p = pet.p, eq = table.find(data.equippedPets, pet.id) ~= nil })
	end
	local snapshot = {
		sheckles = data.sheckles,
		seeds = data.seeds,
		gear = data.gear,
		eggs = data.eggs,
		fruits = fruits,
		pets = pets,
		bonuses = bonuses,
		stock = { seeds = data.stock.seeds, gear = data.stock.gear, eggs = data.stock.eggs },
		restockAt = (data.stock.window + 1) * Config.RestockInterval,
		plantCount = #data.plants,
		stats = data.stats,
	}
	for _, provider in extraProviders do
		provider(player, snapshot)
	end
	return snapshot
end

function Sync.flush(player: Player)
	dirty[player] = nil
	local data = DataService.get(player)
	if not data or not player.Parent then
		return
	end
	Remotes.StateChanged:FireClient(player, buildSnapshot(player, data))
	Inventory.sync(player, data)
	local leaderstats = player:FindFirstChild("leaderstats")
	local sheckles = leaderstats and leaderstats:FindFirstChild("Sheckles")
	if sheckles and sheckles:IsA("IntValue") then
		sheckles.Value = data.sheckles
	end
end

function Sync.start()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.15 then
			return
		end
		elapsed = 0
		for player in dirty do
			Sync.flush(player)
		end
	end)
	Remotes.RequestState.OnServerEvent:Connect(function(player)
		Sync.markDirty(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
	end)
end

return Sync
