-- PetService: pets chocados dos ovos, equipar/desequipar e bonus.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local DataService = require(script.Parent.DataService)
local Sync = require(script.Parent.Sync)

local PetService = {}

function PetService.getBonuses(data)
	return Formulas.petBonuses(data.pets, data.equippedPets)
end

-- Atributo lido pelos clientes para desenhar os pets seguindo o jogador
function PetService.updateAttribute(player: Player, data)
	local ids = {}
	for _, pet in data.pets do
		if table.find(data.equippedPets, pet.id) then
			table.insert(ids, pet.p)
		end
	end
	player:SetAttribute("EquippedPets", table.concat(ids, ","))
end

-- Remove ids de pets equipados que nao existem mais
local function cleanEquipped(data)
	for i = #data.equippedPets, 1, -1 do
		local id = data.equippedPets[i]
		local exists = false
		for _, pet in data.pets do
			if pet.id == id then
				exists = true
				break
			end
		end
		if not exists or i > Config.MaxPetsEquipped then
			table.remove(data.equippedPets, i)
		end
	end
end

function PetService.setup(player: Player, data)
	cleanEquipped(data)
	PetService.updateAttribute(player, data)
end

function PetService.addPet(player: Player, data, petId: string)
	local pet = { id = data.nextId, p = petId }
	data.nextId += 1
	table.insert(data.pets, pet)
	if #data.equippedPets < Config.MaxPetsEquipped then
		table.insert(data.equippedPets, pet.id)
	end
	PetService.updateAttribute(player, data)
	Sync.markDirty(player)
	return pet
end

function PetService.handleAction(player: Player, action: any, petUid: any): (boolean, string)
	local data = DataService.get(player)
	if not data then
		return false, "Seus dados ainda estão carregando."
	end
	if type(action) ~= "string" or type(petUid) ~= "number" then
		return false, "Pedido inválido."
	end
	local pet = nil
	for _, candidate in data.pets do
		if candidate.id == petUid then
			pet = candidate
			break
		end
	end
	if not pet then
		return false, "Pet não encontrado."
	end
	local info = Config.Pets[pet.p]
	local equippedIndex = table.find(data.equippedPets, pet.id)
	if action == "equip" then
		if equippedIndex then
			return false, "Esse pet já está equipado."
		end
		if #data.equippedPets >= Config.MaxPetsEquipped then
			return false, string.format("Você só pode equipar %d pets.", Config.MaxPetsEquipped)
		end
		table.insert(data.equippedPets, pet.id)
		PetService.updateAttribute(player, data)
		Sync.markDirty(player)
		return true, info.name .. " equipado!"
	elseif action == "unequip" then
		if not equippedIndex then
			return false, "Esse pet não está equipado."
		end
		table.remove(data.equippedPets, equippedIndex)
		PetService.updateAttribute(player, data)
		Sync.markDirty(player)
		return true, info.name .. " guardado."
	end
	return false, "Ação desconhecida."
end

return PetService
