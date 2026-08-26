local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(script.Parent.RemoteNames)

local folder: Folder? = nil

local function getFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	folder = ReplicatedStorage:WaitForChild("Remotes", 30) :: Folder
	return folder
end

local RemotesClient = {}

function RemotesClient.getEvent(name: string): RemoteEvent
	local remotes = getFolder()
	local remote = remotes:WaitForChild(name, 30)
	assert(remote and remote:IsA("RemoteEvent"), `Missing RemoteEvent {name}`)
	return remote :: RemoteEvent
end

function RemotesClient.matchState(): RemoteEvent
	return RemotesClient.getEvent(RemoteNames.MatchState)
end

function RemotesClient.extractionState(): RemoteEvent
	return RemotesClient.getEvent(RemoteNames.ExtractionState)
end

function RemotesClient.matchResult(): RemoteEvent
	return RemotesClient.getEvent(RemoteNames.MatchResult)
end

function RemotesClient.requestDropLoot(): RemoteEvent
	return RemotesClient.getEvent(RemoteNames.RequestDropLoot)
end

return RemotesClient
