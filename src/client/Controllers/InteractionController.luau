local UserInputService = game:GetService("UserInputService")
local RemotesClient = require(game:GetService("ReplicatedStorage").Shared.Net.RemotesClient)

-- Phase 1+: G drops backpack when not carrying heavy loot (CarryController owns G while carrying).
local InteractionController = {}

function InteractionController.start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.G then
			-- CarryController also listens; server ignores empty backpack drops.
			RemotesClient.requestDropLoot():FireServer("All")
		end
	end)
end

return InteractionController
