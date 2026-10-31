-- Inventory: mantem as ferramentas (Tools) da mochila iguais aos itens salvos.
-- Sementes, equipamentos e ovos aparecem na barra de itens do Roblox.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Inventory = {}

type Wanted = { kind: string, id: string, label: string, tip: string }

local function wantedItems(data): { Wanted }
	local list = {}
	for _, seed in Config.SeedList do
		local count = data.seeds[seed.id] or 0
		if count > 0 then
			table.insert(list, {
				kind = "Seed",
				id = seed.id,
				label = string.format("Semente de %s [x%d]", seed.name, count),
				tip = "Clique na terra do seu jardim para plantar",
			})
		end
	end
	for _, gear in Config.GearList do
		local count = data.gear[gear.id] or 0
		if count > 0 then
			local label
			if gear.kind == "water" then
				label = string.format("%s [%d usos]", gear.name, count)
			elseif gear.unique then
				label = gear.name
			else
				label = string.format("%s [x%d]", gear.name, count)
			end
			table.insert(list, { kind = "Gear", id = gear.id, label = label, tip = gear.description })
		end
	end
	return list
end

local function toolKey(kind: string, id: string): string
	return kind .. ":" .. id
end

-- Atualiza as Tools da mochila/personagem do jogador
function Inventory.sync(player: Player, data)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local containers = { backpack }
	if player.Character then
		table.insert(containers, player.Character)
	end

	local existing: { [string]: Tool } = {}
	for _, container in containers do
		for _, child in container:GetChildren() do
			if child:IsA("Tool") then
				local kind = child:GetAttribute("ItemKind")
				local id = child:GetAttribute("ItemId")
				if type(kind) == "string" and type(id) == "string" then
					local key = toolKey(kind, id)
					if existing[key] then
						child:Destroy() -- duplicada
					else
						existing[key] = child
					end
				end
			end
		end
	end

	local keep = {}
	for _, item in wantedItems(data) do
		local key = toolKey(item.kind, item.id)
		keep[key] = true
		local tool = existing[key]
		if not tool then
			tool = Instance.new("Tool")
			tool.RequiresHandle = false
			tool.CanBeDropped = false
			tool:SetAttribute("ItemKind", item.kind)
			tool:SetAttribute("ItemId", item.id)
			tool.Name = item.label
			tool.ToolTip = item.tip
			tool.Parent = backpack
		elseif tool.Name ~= item.label then
			tool.Name = item.label
		end
	end

	for key, tool in existing do
		if not keep[key] then
			tool:Destroy()
		end
	end
end

return Inventory
