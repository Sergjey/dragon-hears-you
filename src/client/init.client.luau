-- Client entry. Boots Phase 1 HUD and interaction.
local HUDController = require(script.Controllers.HUDController)
local InteractionController = require(script.Controllers.InteractionController)
local ResultController = require(script.Controllers.ResultController)

HUDController.start()
ResultController.start()
InteractionController.start()
