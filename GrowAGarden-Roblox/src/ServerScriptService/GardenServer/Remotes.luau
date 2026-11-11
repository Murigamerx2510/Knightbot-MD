-- Remotes: cria os RemoteEvents/RemoteFunctions usados entre cliente e servidor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
end

local function make(className: string, name: string)
	local remote = folder:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
	end
	return remote
end

-- Servidor -> cliente
Remotes.Notify = make("RemoteEvent", "Notify") :: RemoteEvent
Remotes.StateChanged = make("RemoteEvent", "StateChanged") :: RemoteEvent
-- Cliente -> servidor
Remotes.UseItem = make("RemoteEvent", "UseItem") :: RemoteEvent
Remotes.Teleport = make("RemoteEvent", "Teleport") :: RemoteEvent
Remotes.RequestState = make("RemoteEvent", "RequestState") :: RemoteEvent
Remotes.Buy = make("RemoteFunction", "Buy") :: RemoteFunction
Remotes.Sell = make("RemoteFunction", "Sell") :: RemoteFunction
Remotes.QuestAction = make("RemoteFunction", "QuestAction") :: RemoteFunction

folder.Parent = ReplicatedStorage

return Remotes
