local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Net.RemoteNames)

local Remotes = {}

local folder: Folder? = nil
local events: { [string]: RemoteEvent } = {}

function Remotes.init()
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		if existing then
			existing:Destroy()
		end
		local created = Instance.new("Folder")
		created.Name = "Remotes"
		created.Parent = ReplicatedStorage
		folder = created
	end

	local root = folder :: Folder

	local function ensure(name: string): RemoteEvent
		local child = root:FindFirstChild(name)
		if child and child:IsA("RemoteEvent") then
			events[name] = child
			return child
		end
		if child then
			child:Destroy()
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = root
		events[name] = remote
		return remote
	end

	ensure(RemoteNames.RequestDropLoot)
	ensure(RemoteNames.MatchState)
	ensure(RemoteNames.ExtractionState)
	ensure(RemoteNames.MatchResult)
	ensure(RemoteNames.DragonState)
	ensure(RemoteNames.DragonEvent)
	ensure(RemoteNames.RequestRevive)
	ensure(RemoteNames.RosterState)
	ensure(RemoteNames.MatchEnded)
	ensure(RemoteNames.LobbyPadState)
	ensure(RemoteNames.RequestSetClass)
	ensure(RemoteNames.ClassState)
	ensure(RemoteNames.RequestUseAbility)
	ensure(RemoteNames.AbilityFx)
	ensure(RemoteNames.RequestBuy)
	ensure(RemoteNames.RequestEquipLoadout)
	ensure(RemoteNames.RequestUseGadget)
	ensure(RemoteNames.EconomyState)
	ensure(RemoteNames.GadgetFx)
	ensure(RemoteNames.LootFx)
	ensure(RemoteNames.RequestSetDifficulty)
	ensure(RemoteNames.RequestSetDailyOptIn)
	ensure(RemoteNames.ReplayState)
	ensure(RemoteNames.MatchEvent)
end

function Remotes.get(name: string): RemoteEvent
	local remote = events[name]
	if remote and remote.Parent then
		return remote
	end
	if folder and folder.Parent then
		local child = folder:FindFirstChild(name)
		if child and child:IsA("RemoteEvent") then
			events[name] = child
			return child
		end
	end
	local created = ReplicatedStorage:FindFirstChild("Remotes")
	if created and created:IsA("Folder") then
		folder = created
		local child = created:FindFirstChild(name)
		if child and child:IsA("RemoteEvent") then
			events[name] = child
			return child
		end
	end
	error(`Remote not initialized: {name}`)
end

function Remotes.requestDropLoot(): RemoteEvent
	return Remotes.get(RemoteNames.RequestDropLoot)
end

function Remotes.matchState(): RemoteEvent
	return Remotes.get(RemoteNames.MatchState)
end

function Remotes.extractionState(): RemoteEvent
	return Remotes.get(RemoteNames.ExtractionState)
end

function Remotes.matchResult(): RemoteEvent
	return Remotes.get(RemoteNames.MatchResult)
end

function Remotes.dragonState(): RemoteEvent
	return Remotes.get(RemoteNames.DragonState)
end

function Remotes.dragonEvent(): RemoteEvent
	return Remotes.get(RemoteNames.DragonEvent)
end

function Remotes.requestRevive(): RemoteEvent
	return Remotes.get(RemoteNames.RequestRevive)
end

function Remotes.rosterState(): RemoteEvent
	return Remotes.get(RemoteNames.RosterState)
end

function Remotes.matchEnded(): RemoteEvent
	return Remotes.get(RemoteNames.MatchEnded)
end

function Remotes.lobbyPadState(): RemoteEvent
	return Remotes.get(RemoteNames.LobbyPadState)
end

function Remotes.requestSetClass(): RemoteEvent
	return Remotes.get(RemoteNames.RequestSetClass)
end

function Remotes.classState(): RemoteEvent
	return Remotes.get(RemoteNames.ClassState)
end

function Remotes.requestUseAbility(): RemoteEvent
	return Remotes.get(RemoteNames.RequestUseAbility)
end

function Remotes.abilityFx(): RemoteEvent
	return Remotes.get(RemoteNames.AbilityFx)
end

function Remotes.requestBuy(): RemoteEvent
	return Remotes.get(RemoteNames.RequestBuy)
end

function Remotes.requestEquipLoadout(): RemoteEvent
	return Remotes.get(RemoteNames.RequestEquipLoadout)
end

function Remotes.requestUseGadget(): RemoteEvent
	return Remotes.get(RemoteNames.RequestUseGadget)
end

function Remotes.economyState(): RemoteEvent
	return Remotes.get(RemoteNames.EconomyState)
end

function Remotes.gadgetFx(): RemoteEvent
	return Remotes.get(RemoteNames.GadgetFx)
end

function Remotes.lootFx(): RemoteEvent
	return Remotes.get(RemoteNames.LootFx)
end

function Remotes.requestSetDifficulty(): RemoteEvent
	return Remotes.get(RemoteNames.RequestSetDifficulty)
end

function Remotes.requestSetDailyOptIn(): RemoteEvent
	return Remotes.get(RemoteNames.RequestSetDailyOptIn)
end

function Remotes.replayState(): RemoteEvent
	return Remotes.get(RemoteNames.ReplayState)
end

function Remotes.matchEvent(): RemoteEvent
	return Remotes.get(RemoteNames.MatchEvent)
end

return Remotes
