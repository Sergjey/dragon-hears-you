local UserInputService = game:GetService("UserInputService")
local RemotesClient = require(game:GetService("ReplicatedStorage").Shared.Net.RemotesClient)

-- Phase 1: G drops all backpack loot (server-validated).
local InteractionController = {}

function InteractionController.start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.G then
			RemotesClient.requestDropLoot():FireServer("All")
		end
	end)
end

return InteractionController
