local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesClient = require(ReplicatedStorage.Shared.Net.RemotesClient)
local LobbyTypes = require(ReplicatedStorage.Shared.Types.LobbyTypes)
local Tokens = require(script.Parent.Parent.UI.Tokens)

type LobbyPadStatePayload = LobbyTypes.LobbyPadStatePayload
type LobbyPadEntry = LobbyTypes.LobbyPadEntry

local LobbyController = {}

local player = Players.LocalPlayer
local gui: ScreenGui?
local phaseLabel: TextLabel?
local listFrame: Frame?
local rows: { Frame } = {}

local function ensureGui()
	if gui and gui.Parent then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local existing = playerGui:FindFirstChild("GorynychLobby")
	if existing then
		existing:Destroy()
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "GorynychLobby"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "PadPanel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.fromScale(0.5, 0.92)
	panel.Size = UDim2.fromScale(0.55, 0.16)
	panel.BackgroundColor3 = Tokens.Panel
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Tokens.AccentGold
	stroke.Transparency = 0.45
	stroke.Parent = panel

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 4.2
	aspect.Parent = panel

	phaseLabel = Instance.new("TextLabel")
	phaseLabel.BackgroundTransparency = 1
	phaseLabel.Position = UDim2.fromScale(0.04, 0.08)
	phaseLabel.Size = UDim2.fromScale(0.92, 0.28)
	phaseLabel.Font = Enum.Font.GothamBold
	phaseLabel.TextSize = 18
	phaseLabel.TextColor3 = Tokens.TextPrimary
	phaseLabel.TextXAlignment = Enum.TextXAlignment.Left
	phaseLabel.Text = "LOBBY — stand on a pad"
	phaseLabel.Parent = panel

	listFrame = Instance.new("Frame")
	listFrame.BackgroundTransparency = 1
	listFrame.Position = UDim2.fromScale(0.04, 0.4)
	listFrame.Size = UDim2.fromScale(0.92, 0.5)
	listFrame.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0.03, 0)
	layout.Parent = listFrame

	table.clear(rows)
	for i = 1, 3 do
		local row = Instance.new("Frame")
		row.Size = UDim2.fromScale(0.3, 1)
		row.BackgroundColor3 = Tokens.BgDeep
		row.BackgroundTransparency = 0.2
		row.BorderSizePixel = 0
		row.LayoutOrder = i
		row.Parent = listFrame

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 8)
		rowCorner.Parent = row

		local name = Instance.new("TextLabel")
		name.Name = "Name"
		name.BackgroundTransparency = 1
		name.Size = UDim2.fromScale(1, 0.45)
		name.Position = UDim2.fromScale(0, 0.08)
		name.Font = Enum.Font.GothamBold
		name.TextSize = 14
		name.TextColor3 = Tokens.AccentGold
		name.Text = "—"
		name.Parent = row

		local count = Instance.new("TextLabel")
		count.Name = "Count"
		count.BackgroundTransparency = 1
		count.Size = UDim2.fromScale(1, 0.4)
		count.Position = UDim2.fromScale(0, 0.5)
		count.Font = Enum.Font.GothamMedium
		count.TextSize = 13
		count.TextColor3 = Tokens.TextPrimary
		count.Text = "0 / 0"
		count.Parent = row

		table.insert(rows, row)
	end
end

local function applyPad(entry: LobbyPadEntry, row: Frame)
	local name = row:FindFirstChild("Name") :: TextLabel
	local count = row:FindFirstChild("Count") :: TextLabel
	name.Text = entry.DisplayName
	local text = string.format("%d / %d", entry.Occupied, entry.Capacity)
	if entry.Countdown then
		text ..= string.format(" · %ds", math.ceil(entry.Countdown))
	end
	if entry.Locked then
		text ..= " · GO"
		name.TextColor3 = Tokens.Safe
	else
		name.TextColor3 = Tokens.AccentGold
	end
	count.Text = text
end

local function applyState(payload: LobbyPadStatePayload)
	ensureGui()
	if not gui or not phaseLabel then
		return
	end
	gui.Enabled = payload.Phase == "Lobby"
	if payload.Phase == "Lobby" then
		phaseLabel.Text = "LOBBY — stand on a pad to queue"
	else
		phaseLabel.Text = "MATCH STARTING…"
	end
	for i, row in rows do
		local entry = payload.Pads[i]
		if entry then
			row.Visible = true
			applyPad(entry, row)
		else
			row.Visible = false
		end
	end
end

function LobbyController.start()
	ensureGui()
	RemotesClient.lobbyPadState().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" or typeof(payload.Pads) ~= "table" then
			return
		end
		applyState(payload :: LobbyPadStatePayload)
	end)

	player:GetAttributeChangedSignal("GamePhase"):Connect(function()
		local phase = player:GetAttribute("GamePhase")
		if gui then
			gui.Enabled = phase ~= "Match"
		end
	end)
end

return LobbyController
