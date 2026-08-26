local LobbyConfig = {
	-- Party capacities
	Pads = {
		Solo = 1,
		Duo = 2,
		Squad = 4,
	},
	CountdownSeconds = 5,
	-- Set to real PlaceIds when published. 0 = Studio in-place (no TeleportService).
	LobbyPlaceId = 0,
	DungeonPlaceId = 0,
	StudioInPlace = true,
	LobbySpawnOffset = Vector3.new(0, 6, -180),
}

function LobbyConfig.shouldUseInPlace(): boolean
	if LobbyConfig.DungeonPlaceId == 0 or LobbyConfig.LobbyPlaceId == 0 then
		return true
	end
	local RunService = game:GetService("RunService")
	return RunService:IsStudio() and LobbyConfig.StudioInPlace
end

function LobbyConfig.isDungeonPlaceId(placeId: number): boolean
	return LobbyConfig.DungeonPlaceId ~= 0 and placeId == LobbyConfig.DungeonPlaceId
end

function LobbyConfig.isLobbyPlaceId(placeId: number): boolean
	if LobbyConfig.LobbyPlaceId == 0 then
		return true
	end
	return placeId == LobbyConfig.LobbyPlaceId
end

return LobbyConfig
