local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Utils.Format)
local RemotesClient = require(ReplicatedStorage.Shared.Net.RemotesClient)
local MatchTypes = require(ReplicatedStorage.Shared.Types.MatchTypes)
local Tokens = require(script.Parent.Parent.UI.Tokens)

type MatchResultPayload = MatchTypes.MatchResultPayload

local ResultController = {}

local player = Players.LocalPlayer

local function showResult(payload: MatchResultPayload)
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local existing = playerGui:FindFirstChild("GorynychResult")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "GorynychResult"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = playerGui

	local dimmer = Instance.new("Frame")
	dimmer.Size = UDim2.fromScale(1, 1)
	dimmer.BackgroundColor3 = Color3.new(0, 0, 0)
	dimmer.BackgroundTransparency = 1
	dimmer.BorderSizePixel = 0
	dimmer.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.42, 0.28)
	panel.BackgroundColor3 = Tokens.Panel
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Tokens.AccentGold
	stroke.Thickness = 1.5
	stroke.Transparency = 0.25
	stroke.Parent = panel

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1.6
	aspect.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.08, 0.12)
	title.Size = UDim2.fromScale(0.84, 0.22)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 28
	title.TextColor3 = Tokens.TextPrimary
	title.Text = "LOOT SECURED"
	title.Parent = panel

	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.Position = UDim2.fromScale(0.08, 0.38)
	value.Size = UDim2.fromScale(0.84, 0.28)
	value.Font = Enum.Font.GothamBold
	value.TextSize = 36
	value.TextColor3 = Tokens.AccentGold
	value.Text = Format.gold(payload.SecuredValue)
	value.Parent = panel

	local subtitle = Instance.new("TextLabel")
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromScale(0.08, 0.7)
	subtitle.Size = UDim2.fromScale(0.84, 0.18)
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextSize = 16
	subtitle.TextColor3 = Tokens.TextMuted
	subtitle.Text = string.format("%d item(s) extracted — Phase 1 slice", payload.ItemCount)
	subtitle.Parent = panel

	panel.Size = UDim2.fromScale(0.38, 0.25)
	TweenService:Create(dimmer, TweenInfo.new(0.2), { BackgroundTransparency = 0.45 }):Play()
	TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(0.42, 0.28),
	}):Play()
end

function ResultController.start()
	RemotesClient.matchResult().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		if typeof(payload.SecuredValue) ~= "number" then
			return
		end
		showResult(payload :: MatchResultPayload)
	end)
end

return ResultController
