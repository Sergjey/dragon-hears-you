-- Client entry. Boots HUD, dragon FX, downed UX, and interaction.
local DragonEffectsController = require(script.Controllers.DragonEffectsController)
local DownedController = require(script.Controllers.DownedController)
local HUDController = require(script.Controllers.HUDController)
local InteractionController = require(script.Controllers.InteractionController)
local ResultController = require(script.Controllers.ResultController)

HUDController.start()
DragonEffectsController.start()
DownedController.start()
ResultController.start()
InteractionController.start()
