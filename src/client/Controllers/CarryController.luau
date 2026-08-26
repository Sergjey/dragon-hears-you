local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarryTypes = require(ReplicatedStorage.Shared.Types.CarryTypes)
local RemotesClient = require(ReplicatedStorage.Shared.Net.RemotesClient)
local Tokens = require(script.Parent.Parent.UI.Tokens)

type CarryStatePayload = CarryTypes.CarryStatePayload

local CarryController = {}

local player = Players.LocalPlayer
local gui: ScreenGui?
local chip: TextLabel?
local carrying = false
local canDrop = false

local function ensureGui()
	if gui and gui.Parent then
		return
	end
	local pg = player:WaitForChild("PlayerGui") :: PlayerGui
	local existing = pg:FindFirstChild("GorynychCarry")
	if existing then
		existing:Destroy()
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "GorynychCarry"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 11
	gui.Parent = pg

	chip = Instance.new("TextLabel")
	chip.Name = "CarryChip"
	chip.AnchorPoint = Vector2.new(0.5, 1)
	chip.Position = UDim2.fromScale(0.5, 0.88)
	chip.Size = UDim2.fromScale(0.36, 0.055)
	chip.BackgroundColor3 = Tokens.Panel
	chip.BackgroundTransparency = 0.15
	chip.BorderSizePixel = 0
	chip.Font = Enum.Font.GothamBold
	chip.TextSize = 14
	chip.TextColor3 = Tokens.AccentGold
	chip.Text = ""
	chip.Visible = false
	chip.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = chip
end

local function applyState(payload: CarryStatePayload)
	ensureGui()
	if not chip then
		return
	end
	carrying = payload.Active == true
	canDrop = payload.CanDrop == true
	if not carrying then
		chip.Visible = false
		chip.Text = ""
		return
	end

	chip.Visible = true
	local name = payload.DisplayName or payload.LootId or "Loot"
	if payload.Waiting then
		local need = payload.RequiredPlayers or 2
		local have = payload.CarrierCount or 1
		chip.Text = string.format("WAITING %d/%d · %s  [G drop]", have, need, name)
		chip.TextColor3 = Tokens.Warning
	else
		chip.Text = string.format("CARRYING %s  [G drop]", name)
		chip.TextColor3 = Tokens.AccentGold
	end
end

function CarryController.start()
	ensureGui()
	RemotesClient.carryState().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		applyState(payload :: CarryStatePayload)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode ~= Enum.KeyCode.G then
			return
		end
		if carrying and canDrop then
			RemotesClient.requestDropCarry():FireServer()
		end
	end)
end

return CarryController
