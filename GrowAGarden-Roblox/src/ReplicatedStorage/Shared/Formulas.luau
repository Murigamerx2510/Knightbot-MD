-- Formulas: calculos de valor, peso, mutacoes, variantes, ciclo do dia e formatacao.
-- Usado tanto pelo servidor quanto pelo cliente.

local Config = require(script.Parent:WaitForChild("Config"))

local Formulas = {}

---------------------------------------------------------------------
-- Mutacoes
---------------------------------------------------------------------

-- Para cada mutacao de combinacao, todas as mutacoes que ela "engole" (recursivo)
local absorbed: { [string]: { [string]: boolean } } = {}
do
	local function collect(result: string, set: { [string]: boolean })
		for _, combo in Config.MutationCombos do
			if combo.result == result then
				for _, requirement in combo.requires do
					set[requirement] = true
					collect(requirement, set)
				end
			end
		end
	end
	for _, combo in Config.MutationCombos do
		local set = absorbed[combo.result] or {}
		collect(combo.result, set)
		absorbed[combo.result] = set
	end
end

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

local function removeValue(list: { string }, value: string)
	for i = #list, 1, -1 do
		if list[i] == value then
			table.remove(list, i)
		end
	end
end

-- Adiciona uma mutacao respeitando as combinacoes. Retorna true se a lista mudou.
function Formulas.addMutation(list: { string }, id: string): boolean
	local mutation = Config.Mutations[id]
	if not mutation or table.find(list, id) then
		return false
	end
	if mutation.kind == "growth" then
		-- so uma mutacao de crescimento por fruto: fica a mais valiosa
		for _, existing in list do
			local other = Config.Mutations[existing]
			if other and other.kind == "growth" and other.mult >= mutation.mult then
				return false
			end
		end
		removeValue(list, "Gold")
		removeValue(list, "Rainbow")
		table.insert(list, id)
		return true
	end
	-- ja faz parte de uma combinacao que o fruto tem
	for _, existing in list do
		local set = absorbed[existing]
		if set and set[id] then
			return false
		end
	end
	table.insert(list, id)
	-- se ganhou a combinacao direto (ex.: Congelado pela Nevasca), remove as partes
	local own = absorbed[id]
	if own then
		for component in own do
			removeValue(list, component)
		end
	end
	-- aplica as combinacoes (podem encadear: Molhado + Arenoso = Barro; Barro + Ressecado = Ceramica)
	local changed = true
	while changed do
		changed = false
		for _, combo in Config.MutationCombos do
			if not table.find(list, combo.result) then
				local complete = true
				for _, requirement in combo.requires do
					if not table.find(list, requirement) then
						complete = false
						break
					end
				end
				if complete then
					for _, requirement in combo.requires do
						removeValue(list, requirement)
					end
					table.insert(list, combo.result)
					changed = true
				end
			end
		end
	end
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

-- Mutacao que define a aparencia do fruto (a de maior multiplicador)
function Formulas.topMutation(list: { string }?): string?
	local best, bestMult = nil, 0
	if list then
		for _, id in list do
			local mutation = Config.Mutations[id]
			if mutation and mutation.mult > bestMult then
				best, bestMult = id, mutation.mult
			end
		end
	end
	return best
end

---------------------------------------------------------------------
-- Variantes, peso, tamanho e valor
---------------------------------------------------------------------

function Formulas.variantInfo(seed, variantId: string?)
	if not variantId or not seed then
		return nil
	end
	if variantId == Config.CrystalVariant.id then
		return Config.CrystalVariant
	end
	if seed.variant and seed.variant.id == variantId then
		return seed.variant
	end
	return nil
end

-- "Morango", "Morango Branco", "Morango de Cristal"
function Formulas.fruitName(seedId: string, variantId: string?): string
	local seed = Config.Seeds[seedId]
	if not seed then
		return seedId
	end
	local variant = Formulas.variantInfo(seed, variantId)
	if variant then
		return seed.name .. " " .. variant.name
	end
	return seed.name
end

function Formulas.rollVariant(seed, rng: Random, luck: number?): string?
	local factor = 1 + (luck or 0)
	local roll = rng:NextNumber()
	if roll < Config.CrystalChance * factor then
		return Config.CrystalVariant.id
	end
	if seed.variant and roll < (Config.CrystalChance + Config.VariantChance) * factor then
		return seed.variant.id
	end
	return nil
end

-- Valor de venda de um fruto
function Formulas.fruitValue(seedId: string, weight: number, mutations: { string }?, variantId: string?): number
	local seed = Config.Seeds[seedId]
	if not seed then
		return 0
	end
	local ratio = math.max(weight / seed.baseWeight, 0.5)
	local value = seed.baseValue * ratio * ratio * Formulas.mutationMultiplier(mutations)
	local variant = Formulas.variantInfo(seed, variantId)
	if variant then
		value *= variant.mult
	end
	return math.max(1, math.floor(value + 0.5))
end

-- Sorteia o peso de um novo fruto (sizeBonus 0.3 = 30% mais pesado)
function Formulas.rollWeight(seed, rng: Random, sizeBonus: number?): number
	local mult = 0.8 + rng:NextNumber() * 0.45
	if rng:NextNumber() < Config.GiantChance then
		mult *= 1.5 + rng:NextNumber() * 1.5
	end
	mult *= 1 + math.max(sizeBonus or 0, -0.5)
	local weight = math.floor(seed.baseWeight * mult * 100 + 0.5) / 100
	return math.max(weight, 0.01)
end

function Formulas.sizeClass(seedId: string, weight: number): string
	local seed = Config.Seeds[seedId]
	if not seed then
		return ""
	end
	local ratio = weight / seed.baseWeight
	for _, class in Config.SizeClasses do
		if ratio < class.maxRatio then
			return class.name
		end
	end
	return Config.SizeClasses[#Config.SizeClasses].name
end

-- Sorteia a mutacao de crescimento (Dourado / Arco-iris) de um novo fruto
function Formulas.rollGrowthMutations(rng: Random, luck: number?, goldMult: number?, rainbowMult: number?): { string }
	local base = 1 + (luck or 0)
	local rainbowChance = Config.GrowthMutationChances.Rainbow * base * (rainbowMult or 1)
	local goldChance = Config.GrowthMutationChances.Gold * base * (goldMult or 1)
	local roll = rng:NextNumber()
	if roll < rainbowChance then
		return { "Rainbow" }
	elseif roll < rainbowChance + goldChance then
		return { "Gold" }
	end
	return {}
end

---------------------------------------------------------------------
-- Lojas e sorteios
---------------------------------------------------------------------

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
		local amount = if item.stockMax > 0 then rng:NextInteger(math.max(item.stockMin, 1), item.stockMax) else 0
		local available = item.inShop ~= false and roll <= item.stockChance
		stock[item.id] = if available then amount else 0
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

---------------------------------------------------------------------
-- Ciclo de dia e noite
---------------------------------------------------------------------

-- Retorna fase ("Day", "Sunset", "Night"), segundos restantes, hora do relogio do Roblox e numero do ciclo
function Formulas.dayPhase(now: number): (string, number, number, number)
	local dn = Config.DayNight
	local cycle = dn.dayLength + dn.sunsetLength + dn.nightLength
	local t = now % cycle
	local index = math.floor(now / cycle)
	if t < dn.dayLength then
		return "Day", dn.dayLength - t, 7 + 10.5 * (t / dn.dayLength), index
	elseif t < dn.dayLength + dn.sunsetLength then
		local s = t - dn.dayLength
		return "Sunset", dn.sunsetLength - s, 17.5 + 1.5 * (s / dn.sunsetLength), index
	end
	local n = t - dn.dayLength - dn.sunsetLength
	return "Night", dn.nightLength - n, (19 + 12 * (n / dn.nightLength)) % 24, index
end

---------------------------------------------------------------------
-- Formatacao
---------------------------------------------------------------------

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
