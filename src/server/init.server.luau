-- Server entry. Phase 4: lobby pads → match (Studio in-place or TeleportService).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyConfig = require(ReplicatedStorage.Shared.Config.LobbyConfig)
local LobbyService = require(script.Services.LobbyService)
local MatchService = require(script.Services.MatchService)
local MatchTeleport = require(script.Services.MatchTeleport)

MatchService.prepare()

MatchTeleport.bindInPlaceStart(function(players, partySize)
	MatchService.beginFromLobby(players, partySize)
end)

MatchTeleport.bindReturnToLobby(function(players)
	MatchService.teardownMatch()
	LobbyService.resumeLobby()
	LobbyService.teleportPlayersToLobbySpawn(players)
end)

local ok, err = pcall(function()
	if MatchTeleport.isReservedDungeonBoot() then
		MatchService.beginFromTeleportJoin()
		print("[Gorynych] Dungeon place boot from teleport")
	else
		LobbyService.init()
		print(`[Gorynych] Lobby boot (inPlace={LobbyConfig.shouldUseInPlace()})`)
	end
end)
if not ok then
	warn("[Gorynych] Server boot failed:", err)
end
