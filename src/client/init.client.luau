-- Client entry. Lobby + dungeon HUD/controllers.
local DragonEffectsController = require(script.Controllers.DragonEffectsController)
local DownedController = require(script.Controllers.DownedController)
local HUDController = require(script.Controllers.HUDController)
local InteractionController = require(script.Controllers.InteractionController)
local LobbyController = require(script.Controllers.LobbyController)
local ResultController = require(script.Controllers.ResultController)

LobbyController.start()
HUDController.start()
DragonEffectsController.start()
DownedController.start()
ResultController.start()
InteractionController.start()
