-- Formulas: calculos de valor, peso, mutacoes, estoque e formatacao.
-- Usado tanto pelo servidor quanto pelo cliente.

local Config = require(script.Parent:WaitForChild("Config"))

local Formulas = {}

-- Multiplicador total das mutacoes de um fruto
function Formulas.mutationMultiplier(mutations: { string }?): number
	local growth = 1
	local envSum = 0
	if mutations then
		for _, id in mutations do
			local mutation = Config.Mutations[id]
			if mutation then
				if mutation.kind == "growth" then
					growth = math.max(growth, mutation.mult)
				else
					envSum += mutation.mult - 1
				end
			end
		end
	end
	return growth * (1 + envSum)
end

-- Valor de venda de um fruto
function Formulas.fruitValue(seedId: string, weight: number, mutations: { string }?, sellBonus: number?): number
	local seed = Config.Seeds[seedId]
	if not seed then
		return 0
	end
	local ratio = math.max(weight / seed.baseWeight, 0.5)
	local value = seed.baseValue * ratio * ratio * Formulas.mutationMultiplier(mutations)
	value *= 1 + (sellBonus or 0)
	return math.max(1, math.floor(value + 0.5))
end

-- Sorteia o peso de um novo fruto
function Formulas.rollWeight(seed, rng: Random): number
	local mult = 0.8 + rng:NextNumber() * 0.45
	if rng:NextNumber() < Config.GiantChance then
		mult *= 1.5 + rng:NextNumber() * 1.5
	end
	local weight = math.floor(seed.baseWeight * mult * 100 + 0.5) / 100
	return math.max(weight, 0.01)
end

-- Sorteia a mutacao de crescimento (Dourado / Arco-iris) de um novo fruto
function Formulas.rollGrowthMutations(rng: Random, luck: number?): { string }
	local factor = 1 + (luck or 0)
	local roll = rng:NextNumber()
	if roll < Config.GrowthMutationChances.Rainbow * factor then
		return { "Rainbow" }
	elseif roll < (Config.GrowthMutationChances.Rainbow + Config.GrowthMutationChances.Gold) * factor then
		return { "Gold" }
	end
	return {}
end

local function removeValue(list: { string }, value: string)
	for i = #list, 1, -1 do
		if list[i] == value then
			table.remove(list, i)
		end
	end
end

-- Adiciona uma mutacao de clima respeitando as combinacoes.
-- Retorna true se a lista mudou.
function Formulas.addMutation(list: { string }, id: string): boolean
	if not Config.Mutations[id] or table.find(list, id) then
		return false
	end
	if Config.Mutations[id].kind == "growth" then
		-- so uma mutacao de crescimento por fruto: fica a mais valiosa
		for _, existing in list do
			local other = Config.Mutations[existing]
			if other and other.kind == "growth" and other.mult >= Config.Mutations[id].mult then
				return false
			end
		end
		removeValue(list, "Gold")
		removeValue(list, "Rainbow")
		table.insert(list, id)
		return true
	end
	if id == "Wet" or id == "Chilled" then
		if table.find(list, "Frozen") then
			return false
		end
		local partner = if id == "Wet" then "Chilled" else "Wet"
		if table.find(list, partner) then
			removeValue(list, partner)
			table.insert(list, "Frozen")
			return true
		end
	end
	if id == "Frozen" then
		removeValue(list, "Wet")
		removeValue(list, "Chilled")
	end
	table.insert(list, id)
	return true
end

-- Ordena a lista de mutacoes para exibicao
function Formulas.sortMutations(list: { string }): { string }
	local sorted = table.clone(list)
	table.sort(sorted, function(a, b)
		return (table.find(Config.MutationOrder, a) or 99) < (table.find(Config.MutationOrder, b) or 99)
	end)
	return sorted
end

function Formulas.mutationNames(list: { string }?): string
	if not list or #list == 0 then
		return ""
	end
	local names = {}
	for _, id in Formulas.sortMutations(list) do
		local mutation = Config.Mutations[id]
		if mutation then
			table.insert(names, mutation.name)
		end
	end
	return table.concat(names, ", ")
end

-- Janela de reabastecimento atual (igual em todos os servidores)
function Formulas.restockWindow(now: number): number
	return math.floor(now / Config.RestockInterval)
end

-- Estoque deterministico para uma janela de tempo
function Formulas.rollStock(list, window: number, salt: number): { [string]: number }
	local rng = Random.new(window * 7 + salt * 1000003)
	local stock = {}
	for _, item in list do
		local roll = rng:NextNumber()
		local amount = rng:NextInteger(item.stockMin, item.stockMax)
		stock[item.id] = if roll <= item.stockChance then amount else 0
	end
	return stock
end

-- Escolha aleatoria com pesos. entries = { {weight = n, ...}, ... }
function Formulas.weightedPick(entries, rng: Random)
	local total = 0
	for _, entry in entries do
		total += entry.weight
	end
	local roll = rng:NextNumber() * total
	for _, entry in entries do
		roll -= entry.weight
		if roll <= 0 then
			return entry
		end
	end
	return entries[#entries]
end

-- Soma dos bonus dos pets equipados.
-- pets = { {id = number, p = petId} }, equipped = { id, ... }
function Formulas.petBonuses(pets, equipped): { Growth: number, Sell: number, Luck: number }
	local bonuses = { Growth = 0, Sell = 0, Luck = 0 }
	if type(pets) ~= "table" or type(equipped) ~= "table" then
		return bonuses
	end
	for _, pet in pets do
		if table.find(equipped, pet.id) then
			local info = Config.Pets[pet.p]
			if info and bonuses[info.bonusType] ~= nil then
				bonuses[info.bonusType] += info.bonus
			end
		end
	end
	return bonuses
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

-- 1234 -> "1,234" ; 1234567 -> "1.23M"
function Formulas.formatNumber(n: number): string
	n = math.floor(n)
	if math.abs(n) < 100000 then
		local s = tostring(math.abs(n))
		local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		if formatted:sub(1, 1) == "," then
			formatted = formatted:sub(2)
		end
		return (if n < 0 then "-" else "") .. formatted
	end
	local index = 1
	local value = n
	while math.abs(value) >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	return string.format("%.2f%s", value, SUFFIXES[index])
end

function Formulas.formatMoney(n: number): string
	return Config.CurrencySymbol .. Formulas.formatNumber(n)
end

-- 125 -> "2:05"
function Formulas.formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

function Formulas.formatWeight(kg: number): string
	return string.format("%.2fkg", kg)
end

function Formulas.formatPercent(fraction: number): string
	return string.format("%d%%", math.floor(fraction * 100 + 0.5))
end

return Formulas
