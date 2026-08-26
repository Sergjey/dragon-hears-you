-- Server entry. Boots Gorynych Heist (Phase 3 multiplayer slice).
local MatchService = require(script.Services.MatchService)

local ok, err = pcall(function()
	MatchService.init()
end)
if not ok then
	warn("[Gorynych] MatchService.init failed:", err)
end
