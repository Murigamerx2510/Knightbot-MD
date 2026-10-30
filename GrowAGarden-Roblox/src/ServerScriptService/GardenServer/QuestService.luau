-- QuestService: missoes diarias (3 por dia, trocam a meia-noite UTC).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local DataService = require(script.Parent.DataService)
local Sync = require(script.Parent.Sync)

local QuestService = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

local function findTemplate(id: string)
	for _, template in Config.Quests.templates do
		if template.id == id then
			return template
		end
	end
	return nil
end

-- Recompensa cresce com o quanto o jogador ja ganhou (continua valendo a pena no fim do jogo)
local function rewardFor(template, target: number, data): number
	local scale = math.max(1, math.sqrt(math.max(data.stats.earned, 0)) / 40)
	return math.floor(template.reward * target * scale)
end

-- Gera as missoes do dia se ainda nao existirem
function QuestService.ensure(player: Player, data): boolean
	local day = today()
	if data.quests.day == day and #data.quests.list > 0 then
		return false
	end
	local rng = Random.new(day * 7919 + math.abs(player.UserId) % 100000)
	local pool = table.clone(Config.Quests.templates)
	local list = {}
	for _ = 1, math.min(Config.Quests.perDay, #pool) do
		local template = table.remove(pool, rng:NextInteger(1, #pool))
		local target = rng:NextInteger(template.min, template.max)
		table.insert(list, {
			id = template.id,
			target = target,
			progress = 0,
			reward = rewardFor(template, target, data),
			claimed = false,
		})
	end
	data.quests.day = day
	data.quests.list = list
	return true
end

function QuestService.progress(player: Player, kind: string, amount: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	QuestService.ensure(player, data)
	for _, quest in data.quests.list do
		if quest.id == kind and not quest.claimed and quest.progress < quest.target then
			quest.progress = math.min(quest.target, quest.progress + amount)
			if quest.progress >= quest.target then
				local template = findTemplate(quest.id)
				local text = if template then string.format(template.text, quest.target) else quest.id
				Sync.notify(player, "📜 Missão completa: " .. text .. "! Pegue a recompensa em Missões.", "success")
			end
			Sync.markDirty(player)
		end
	end
end

function QuestService.claim(player: Player, index: any): (boolean, string)
	local data = DataService.get(player)
	if not data then
		return false, "Seus dados ainda estão carregando."
	end
	if type(index) ~= "number" then
		return false, "Pedido inválido."
	end
	QuestService.ensure(player, data)
	local quest = data.quests.list[index]
	if not quest then
		return false, "Missão não encontrada."
	end
	if quest.claimed then
		return false, "Você já pegou essa recompensa."
	end
	if quest.progress < quest.target then
		return false, "Missão ainda não terminou."
	end
	quest.claimed = true
	data.sheckles += quest.reward
	Sync.markDirty(player)
	return true, "Recompensa: " .. Formulas.formatMoney(quest.reward) .. "!"
end

-- Lista para a interface
function QuestService.snapshot(data)
	local list = {}
	for index, quest in data.quests.list do
		local template = findTemplate(quest.id)
		table.insert(list, {
			i = index,
			icon = if template then template.icon else "📜",
			text = if template then string.format(template.text, quest.target) else quest.id,
			progress = quest.progress,
			target = quest.target,
			reward = quest.reward,
			claimed = quest.claimed,
		})
	end
	return list
end

return QuestService
