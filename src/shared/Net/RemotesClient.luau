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

function RemotesClient.dragonState(): RemoteEvent
	return RemotesClient.getEvent(RemoteNames.DragonState)
end

function RemotesClient.dragonEvent(): RemoteEvent
	return RemotesClient.getEvent(RemoteNames.DragonEvent)
end

function RemotesClient.requestRevive(): RemoteEvent
	return RemotesClient.getEvent(RemoteNames.RequestRevive)
end

function RemotesClient.rosterState(): RemoteEvent
	return RemotesClient.getEvent(RemoteNames.RosterState)
end

function RemotesClient.matchEnded(): RemoteEvent
	return RemotesClient.getEvent(RemoteNames.MatchEnded)
end

function RemotesClient.lobbyPadState(): RemoteEvent
	return RemotesClient.getEvent(RemoteNames.LobbyPadState)
end

function RemotesClient.requestSetClass(): RemoteEvent
	return RemotesClient.getEvent(RemoteNames.RequestSetClass)
end

function RemotesClient.classState(): RemoteEvent
	return RemotesClient.getEvent(RemoteNames.ClassState)
end

function RemotesClient.requestUseAbility(): RemoteEvent
	return RemotesClient.getEvent(RemoteNames.RequestUseAbility)
end

function RemotesClient.abilityFx(): RemoteEvent
	return RemotesClient.getEvent(RemoteNames.AbilityFx)
end

function RemotesClient.requestBuy(): RemoteEvent
	return RemotesClient.getEvent(RemoteNames.RequestBuy)
end

function RemotesClient.requestEquipLoadout(): RemoteEvent
	return RemotesClient.getEvent(RemoteNames.RequestEquipLoadout)
end

function RemotesClient.requestUseGadget(): RemoteEvent
	return RemotesClient.getEvent(RemoteNames.RequestUseGadget)
end

function RemotesClient.economyState(): RemoteEvent
	return RemotesClient.getEvent(RemoteNames.EconomyState)
end

function RemotesClient.gadgetFx(): RemoteEvent
	return RemotesClient.getEvent(RemoteNames.GadgetFx)
end

return RemotesClient
