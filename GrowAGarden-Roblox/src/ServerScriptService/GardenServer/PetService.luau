-- PetService: pets chocados dos ovos, equipar/desequipar, variantes e niveis.
-- Os pets ganham XP enquanto estao equipados e ficam mais fortes a cada nivel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local DataService = require(script.Parent.DataService)
local Sync = require(script.Parent.Sync)

local PetService = {}

local listeners: { (Player) -> () } = {}

-- Avisa outros servicos quando os pets equipados mudam
function PetService.onChanged(callback: (Player) -> ())
	table.insert(listeners, callback)
end

local function changed(player: Player)
	for _, callback in listeners do
		callback(player)
	end
end

function PetService.getBonuses(data)
	return Formulas.petBonuses(data.pets, data.equippedPets)
end

-- Atributo lido pelos clientes para desenhar os pets seguindo o jogador
-- formato: "Dog:Big:12,Cat::3" (id, variante, nivel)
function PetService.updateAttribute(player: Player, data)
	local entries = {}
	for _, pet in data.pets do
		if table.find(data.equippedPets, pet.id) then
			table.insert(entries, string.format("%s:%s:%d", pet.p, pet.v or "", Formulas.petLevel(pet.xp)))
		end
	end
	player:SetAttribute("EquippedPets", table.concat(entries, ","))
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

function PetService.addPet(player: Player, data, petId: string, variantId: string?)
	local pet = { id = data.nextId, p = petId, v = variantId, xp = 0 }
	data.nextId += 1
	table.insert(data.pets, pet)
	if #data.equippedPets < Config.MaxPetsEquipped then
		table.insert(data.equippedPets, pet.id)
	end
	PetService.updateAttribute(player, data)
	Sync.markDirty(player)
	changed(player)
	return pet
end

-- XP para os pets equipados (chamado a cada meio segundo)
function PetService.addXp(player: Player, data, dt: number)
	local leveled = false
	for _, pet in data.pets do
		if table.find(data.equippedPets, pet.id) then
			local before = Formulas.petLevel(pet.xp)
			pet.xp = (pet.xp or 0) + dt
			local after = Formulas.petLevel(pet.xp)
			if after > before then
				leveled = true
				Sync.notify(player, string.format("⬆️ %s subiu para o nível %d!", Formulas.petName(pet), after), "success")
			end
		end
	end
	if leveled then
		PetService.updateAttribute(player, data)
		Sync.markDirty(player)
		changed(player)
	end
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
	local name = Formulas.petName(pet)
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
		changed(player)
		return true, name .. " equipado!"
	elseif action == "unequip" then
		if not equippedIndex then
			return false, "Esse pet não está equipado."
		end
		table.remove(data.equippedPets, equippedIndex)
		PetService.updateAttribute(player, data)
		Sync.markDirty(player)
		changed(player)
		return true, name .. " guardado."
	end
	return false, "Ação desconhecida."
end

return PetService
