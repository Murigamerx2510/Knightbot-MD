-- ShopService: lojas de sementes e equipamentos, venda de frutos
-- e reabastecimento a cada 5 minutos (estoque igual para todos os servidores).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local DataService = require(script.Parent.DataService)
local QuestService = require(script.Parent.QuestService)
local Sync = require(script.Parent.Sync)

local ShopService = {}

local shopPositions: { [string]: Vector3 } = {}

local CATEGORIES = {
	Seeds = { items = Config.Seeds, stockKey = "seeds", shop = "Seeds" },
	Gear = { items = Config.Gear, stockKey = "gear", shop = "Gear" },
}

local function currentWindow(): number
	return Formulas.restockWindow(os.time())
end

function ShopService.init(map)
	shopPositions = map.shopPositions
end

-- Atualiza o estoque do jogador se ja passou o tempo de reabastecer
function ShopService.ensureStock(data): boolean
	local window = currentWindow()
	if data.stock.window == window then
		return false
	end
	data.stock.window = window
	data.stock.seeds = Formulas.rollStock(Config.SeedList, window, 1)
	data.stock.gear = Formulas.rollStock(Config.GearList, window, 2)
	return true
end

local function isNear(player: Player, shopId: string): boolean
	local position = shopPositions[shopId]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not position or not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - position).Magnitude <= Config.ShopInteractDistance
end

function ShopService.buy(player: Player, category: any, itemId: any): (boolean, string)
	local data = DataService.get(player)
	if not data then
		return false, "Seus dados ainda estão carregando."
	end
	if type(category) ~= "string" or type(itemId) ~= "string" then
		return false, "Pedido inválido."
	end
	local info = CATEGORIES[category]
	if not info then
		return false, "Loja inválida."
	end
	local item = info.items[itemId]
	if not item then
		return false, "Item inválido."
	end
	if not isNear(player, info.shop) then
		return false, "Chegue mais perto da loja!"
	end
	ShopService.ensureStock(data)
	local stockList = data.stock[info.stockKey]
	local stock = stockList[itemId] or 0
	if stock <= 0 then
		return false, "Sem estoque! Espere o reabastecimento."
	end
	if data.sheckles < item.price then
		return false, "Sheckles insuficientes!"
	end
	if category == "Gear" and item.unique and (data.gear[itemId] or 0) > 0 then
		return false, "Você já tem " .. item.name .. "."
	end
	data.sheckles -= item.price
	stockList[itemId] = stock - 1
	if category == "Seeds" then
		data.seeds[itemId] = (data.seeds[itemId] or 0) + 1
	else
		local amount = if item.kind == "water" then item.uses else 1
		data.gear[itemId] = (data.gear[itemId] or 0) + amount
	end
	Sync.markDirty(player)
	return true, "Você comprou " .. item.name .. "!"
end

-- mode "all" vende tudo; mode "one" vende o fruto de indice index
-- (seedId e weight confirmam que e o fruto certo)
function ShopService.sell(player: Player, mode: any, index: any, seedId: any, weight: any): (boolean, string)
	local data = DataService.get(player)
	if not data then
		return false, "Seus dados ainda estão carregando."
	end
	if not isNear(player, "Sell") then
		return false, "Vá até a barraca de Venda do Steven!"
	end
	if mode == "all" then
		local count = #data.fruits
		if count == 0 then
			return false, "Você não tem frutos para vender."
		end
		local total = 0
		for _, fruit in data.fruits do
			total += Formulas.fruitValue(fruit.s, fruit.w, fruit.m, fruit.v)
		end
		table.clear(data.fruits)
		data.sheckles += total
		data.stats.earned += total
		data.stats.sold += count
		QuestService.progress(player, "sell", count)
		Sync.markDirty(player)
		return true, string.format("Vendeu %d fruto(s) por %s!", count, Formulas.formatMoney(total))
	elseif mode == "one" then
		if type(index) ~= "number" then
			return false, "Pedido inválido."
		end
		local fruit = data.fruits[index]
		if not fruit or fruit.s ~= seedId or fruit.w ~= weight then
			return false, "Fruto não encontrado. Tente de novo."
		end
		local value = Formulas.fruitValue(fruit.s, fruit.w, fruit.m, fruit.v)
		table.remove(data.fruits, index)
		data.sheckles += value
		data.stats.earned += value
		data.stats.sold += 1
		QuestService.progress(player, "sell", 1)
		Sync.markDirty(player)
		return true, string.format("Vendeu %s por %s!", Formulas.fruitName(fruit.s, fruit.v), Formulas.formatMoney(value))
	end
	return false, "Pedido inválido."
end

-- Comando de teste: enche o estoque do jogador
function ShopService.fillStock(data)
	ShopService.ensureStock(data)
	for _, info in CATEGORIES do
		for id in info.items do
			data.stock[info.stockKey][id] = math.max(data.stock[info.stockKey][id] or 0, 10)
		end
	end
end

function ShopService.start()
	task.spawn(function()
		local lastWindow = currentWindow()
		while true do
			task.wait(1)
			local window = currentWindow()
			if window ~= lastWindow then
				lastWindow = window
				for _, player in DataService.getPlayers() do
					local data = DataService.get(player)
					if data and ShopService.ensureStock(data) then
						Sync.markDirty(player)
					end
				end
				Sync.notifyAll("🌱 As lojas foram reabastecidas!", "success")
			end
		end
	end)
end

return ShopService
