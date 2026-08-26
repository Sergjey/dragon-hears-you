local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local LobbyConfig = require(ReplicatedStorage.Shared.Config.LobbyConfig)
local LobbyTypes = require(ReplicatedStorage.Shared.Types.LobbyTypes)

type TeleportPartyData = LobbyTypes.TeleportPartyData

local MatchTeleport = {}

local onInPlaceStart: (({ Player }, number) -> ())? = nil
local onReturnToLobby: (({ Player }) -> ())? = nil

function MatchTeleport.bindInPlaceStart(fn: ({ Player }, number) -> ())
	onInPlaceStart = fn
end

function MatchTeleport.bindReturnToLobby(fn: ({ Player }) -> ())
	onReturnToLobby = fn
end

local function buildTeleportData(players: { Player }, partySize: number): TeleportPartyData
	local ids = {}
	for _, player in players do
		table.insert(ids, player.UserId)
	end
	return {
		PartySize = partySize,
		MemberUserIds = ids,
		Seed = math.floor(os.clock() * 1000) % 100000,
	}
end

function MatchTeleport.startParty(players: { Player }, partySize: number)
	if #players == 0 then
		return
	end
	if #players > partySize then
		warn(`[Gorynych] Party oversized {#players} > {partySize}`)
		return
	end

	if LobbyConfig.shouldUseInPlace() then
		if onInPlaceStart then
			onInPlaceStart(players, partySize)
		end
		return
	end

	local dungeonPlaceId = LobbyConfig.DungeonPlaceId
	local ok, accessCodeOrErr = pcall(function()
		return TeleportService:ReserveServer(dungeonPlaceId)
	end)
	if not ok then
		warn("[Gorynych] ReserveServer failed:", accessCodeOrErr)
		-- Fallback in-place so Studio/misconfig still playable
		if onInPlaceStart then
			onInPlaceStart(players, partySize)
		end
		return
	end

	local teleportData = buildTeleportData(players, partySize)
	local teleportOk, teleportErr = pcall(function()
		TeleportService:TeleportToPrivateServer(
			dungeonPlaceId,
			accessCodeOrErr :: string,
			players,
			nil,
			teleportData
		)
	end)
	if not teleportOk then
		warn("[Gorynych] TeleportToPrivateServer failed:", teleportErr)
		if onInPlaceStart then
			onInPlaceStart(players, partySize)
		end
	end
end

function MatchTeleport.returnPartyToLobby(players: { Player })
	if LobbyConfig.shouldUseInPlace() then
		if onReturnToLobby then
			onReturnToLobby(players)
		end
		return
	end

	local lobbyPlaceId = LobbyConfig.LobbyPlaceId
	if lobbyPlaceId == 0 then
		if onReturnToLobby then
			onReturnToLobby(players)
		end
		return
	end

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(lobbyPlaceId, players)
	end)
	if not ok then
		warn("[Gorynych] Teleport back to lobby failed:", err)
		if onReturnToLobby then
			onReturnToLobby(players)
		end
	end
end

function MatchTeleport.readJoinPartyData(player: Player): TeleportPartyData?
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or typeof(joinData) ~= "table" then
		return nil
	end
	local teleportData = (joinData :: any).TeleportData
	if typeof(teleportData) ~= "table" then
		return nil
	end
	if typeof(teleportData.PartySize) ~= "number" or typeof(teleportData.MemberUserIds) ~= "table" then
		return nil
	end
	return teleportData :: TeleportPartyData
end

function MatchTeleport.isReservedDungeonBoot(): boolean
	if LobbyConfig.shouldUseInPlace() then
		return false
	end
	return LobbyConfig.isDungeonPlaceId(game.PlaceId)
end

return MatchTeleport
