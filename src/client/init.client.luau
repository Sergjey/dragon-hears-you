-- Client entry. Boots HUD, dragon FX, and interaction.
local DragonEffectsController = require(script.Controllers.DragonEffectsController)
local HUDController = require(script.Controllers.HUDController)
local InteractionController = require(script.Controllers.InteractionController)
local ResultController = require(script.Controllers.ResultController)

HUDController.start()
DragonEffectsController.start()
ResultController.start()
InteractionController.start()
