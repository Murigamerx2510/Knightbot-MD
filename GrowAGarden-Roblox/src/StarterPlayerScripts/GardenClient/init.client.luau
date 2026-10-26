-- GardenClient: script principal do jogador.
-- Liga a interface, os efeitos e o uso das ferramentas (sementes, regador, etc).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local remotes = {
	Notify = remotesFolder:WaitForChild("Notify") :: RemoteEvent,
	StateChanged = remotesFolder:WaitForChild("StateChanged") :: RemoteEvent,
	UseItem = remotesFolder:WaitForChild("UseItem") :: RemoteEvent,
	Teleport = remotesFolder:WaitForChild("Teleport") :: RemoteEvent,
	RequestState = remotesFolder:WaitForChild("RequestState") :: RemoteEvent,
	Buy = remotesFolder:WaitForChild("Buy") :: RemoteFunction,
	Sell = remotesFolder:WaitForChild("Sell") :: RemoteFunction,
	PetAction = remotesFolder:WaitForChild("PetAction") :: RemoteFunction,
}

local Interface = require(script:WaitForChild("Interface"))
local Effects = require(script:WaitForChild("Effects"))

local ui = Interface.create(remotes)
Effects.start(ui)

remotes.StateChanged.OnClientEvent:Connect(function(state)
	if type(state) == "table" then
		ui.setState(state)
	end
end)

remotes.Notify.OnClientEvent:Connect(function(message, kind)
	if type(message) == "string" then
		ui.notify(message, kind)
	end
end)

-- abrir lojas ao falar com os vendedores
ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who ~= player then
		return
	end
	local shop = prompt:GetAttribute("Shop")
	if type(shop) == "string" then
		ui.openShop(shop)
	end
end)

---------------------------------------------------------------------
-- Ferramentas: ao clicar com uma semente/item, envia a posicao para o servidor
---------------------------------------------------------------------

local mouse = player:GetMouse()
local hooked: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function hookTool(tool: Tool)
	if hooked[tool] then
		return
	end
	hooked[tool] = true
	tool.Activated:Connect(function()
		local kind = tool:GetAttribute("ItemKind")
		local id = tool:GetAttribute("ItemId")
		if type(kind) == "string" and type(id) == "string" then
			remotes.UseItem:FireServer(kind, id, mouse.Hit.Position)
		end
	end)
end

local function watchCharacter(character: Model)
	mouse.TargetFilter = character
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			hookTool(child)
		end
	end
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			hookTool(child)
		end
	end)
end

player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	watchCharacter(player.Character)
end

remotes.RequestState:FireServer()
