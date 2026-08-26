local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ReplayConfig = require(ReplicatedStorage.Shared.Config.ReplayConfig)
local RemotesClient = require(ReplicatedStorage.Shared.Net.RemotesClient)
local ReplayTypes = require(ReplicatedStorage.Shared.Types.ReplayTypes)
local Tokens = require(script.Parent.Parent.UI.Tokens)

type ReplayStatePayload = ReplayTypes.ReplayStatePayload
type MatchEventPayload = ReplayTypes.MatchEventPayload

local ReplayController = {}

local player = Players.LocalPlayer
local gui: ScreenGui?
local toastGui: ScreenGui?
local dailyLabel: TextLabel?
local dailyDesc: TextLabel?
local optButton: TextButton?
local caveButtons: { [string]: TextButton } = {}
local lastState: ReplayStatePayload? = nil

local function highlightCave(caveId: string)
	for id, btn in caveButtons do
		btn.BackgroundColor3 = if id == caveId then Tokens.Accent else Tokens.BgDeep
	end
end

local function applyState(payload: ReplayStatePayload)
	lastState = payload
	if dailyLabel then
		dailyLabel.Text = "DAILY · " .. payload.DailyCardName
	end
	if dailyDesc then
		dailyDesc.Text = payload.DailyCardDescription
	end
	if optButton then
		optButton.Text = if payload.DailyOptIn then "Daily: ON" else "Daily: OFF"
		optButton.BackgroundColor3 = if payload.DailyOptIn then Tokens.Safe else Tokens.BgDeep
	end
	highlightCave(payload.CaveId)
end

local function ensureLobbyGui()
	if gui and gui.Parent then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local existing = playerGui:FindFirstChild("GorynychReplay")
	if existing then
		existing:Destroy()
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "GorynychReplay"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.fromScale(0.5, -0.2)
	panel.Size = UDim2.fromScale(0.42, 0.16)
	panel.BackgroundColor3 = Tokens.Panel
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Tokens.Warning
	stroke.Transparency = 0.4
	stroke.Parent = panel

	TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.02),
	}):Play()

	dailyLabel = Instance.new("TextLabel")
	dailyLabel.BackgroundTransparency = 1
	dailyLabel.Position = UDim2.fromScale(0.04, 0.08)
	dailyLabel.Size = UDim2.fromScale(0.7, 0.28)
	dailyLabel.Font = Enum.Font.GothamBold
	dailyLabel.TextSize = 15
	dailyLabel.TextColor3 = Tokens.AccentGold
	dailyLabel.TextXAlignment = Enum.TextXAlignment.Left
	dailyLabel.Text = "DAILY"
	dailyLabel.Parent = panel

	dailyDesc = Instance.new("TextLabel")
	dailyDesc.BackgroundTransparency = 1
	dailyDesc.Position = UDim2.fromScale(0.04, 0.36)
	dailyDesc.Size = UDim2.fromScale(0.7, 0.28)
	dailyDesc.Font = Enum.Font.Gotham
	dailyDesc.TextSize = 12
	dailyDesc.TextColor3 = Tokens.TextMuted
	dailyDesc.TextXAlignment = Enum.TextXAlignment.Left
	dailyDesc.TextWrapped = true
	dailyDesc.Text = ""
	dailyDesc.Parent = panel

	optButton = Instance.new("TextButton")
	optButton.AnchorPoint = Vector2.new(1, 0)
	optButton.Position = UDim2.fromScale(0.96, 0.12)
	optButton.Size = UDim2.fromScale(0.22, 0.32)
	optButton.BackgroundColor3 = Tokens.Safe
	optButton.BorderSizePixel = 0
	optButton.AutoButtonColor = false
	optButton.Font = Enum.Font.GothamBold
	optButton.TextSize = 12
	optButton.TextColor3 = Tokens.TextPrimary
	optButton.Text = "Daily: ON"
	optButton.Parent = panel
	local optCorner = Instance.new("UICorner")
	optCorner.CornerRadius = UDim.new(0, 8)
	optCorner.Parent = optButton
	optButton.MouseButton1Click:Connect(function()
		local nextVal = true
		if lastState then
			nextVal = not lastState.DailyOptIn
		end
		RemotesClient.requestSetDailyOptIn():FireServer(nextVal)
	end)

	local caveRow = Instance.new("Frame")
	caveRow.BackgroundTransparency = 1
	caveRow.Position = UDim2.fromScale(0.04, 0.68)
	caveRow.Size = UDim2.fromScale(0.92, 0.26)
	caveRow.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0.02, 0)
	layout.Parent = caveRow

	for _, def in ReplayConfig.listCaves() do
		local btn = Instance.new("TextButton")
		btn.Name = def.Id
		btn.Size = UDim2.fromScale(0.32, 1)
		btn.BackgroundColor3 = Tokens.BgDeep
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = false
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 12
		btn.TextColor3 = Tokens.TextPrimary
		btn.Text = def.DisplayName
		btn.Parent = caveRow
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = btn
		caveButtons[def.Id] = btn
		btn.MouseButton1Click:Connect(function()
			RemotesClient.requestSetDifficulty():FireServer(def.Id)
		end)
	end
end

local function showToast(message: string)
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	if not toastGui or not toastGui.Parent then
		local existing = playerGui:FindFirstChild("GorynychMatchEvent")
		if existing then
			existing:Destroy()
		end
		toastGui = Instance.new("ScreenGui")
		toastGui.Name = "GorynychMatchEvent"
		toastGui.ResetOnSpawn = false
		toastGui.IgnoreGuiInset = true
		toastGui.DisplayOrder = 18
		toastGui.Parent = playerGui
	end

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.18)
	label.Size = UDim2.fromScale(0.55, 0.07)
	label.BackgroundColor3 = Tokens.Panel
	label.BackgroundTransparency = 0.15
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextColor3 = Tokens.Warning
	label.Text = message
	label.TextTransparency = 1
	label.Parent = toastGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	TweenService:Create(label, TweenInfo.new(0.18), { TextTransparency = 0, BackgroundTransparency = 0.12 }):Play()
	task.delay(2.4, function()
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		task.delay(0.35, function()
			label:Destroy()
		end)
	end)
end

local function refreshVisibility()
	ensureLobbyGui()
	local phase = player:GetAttribute("GamePhase")
	if gui then
		gui.Enabled = phase ~= "Match"
	end
end

function ReplayController.start()
	ensureLobbyGui()
	refreshVisibility()

	RemotesClient.replayState().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		applyState(payload :: ReplayStatePayload)
	end)

	RemotesClient.matchEvent().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" or typeof(payload.Message) ~= "string" then
			return
		end
		showToast((payload :: MatchEventPayload).Message)
	end)

	player:GetAttributeChangedSignal("GamePhase"):Connect(refreshVisibility)
end

return ReplayController
