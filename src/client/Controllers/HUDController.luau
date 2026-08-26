local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Utils.Format)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MultiplayerConfig = require(ReplicatedStorage.Shared.Config.MultiplayerConfig)
local RemotesClient = require(ReplicatedStorage.Shared.Net.RemotesClient)
local MatchTypes = require(ReplicatedStorage.Shared.Types.MatchTypes)
local MultiplayerTypes = require(ReplicatedStorage.Shared.Types.MultiplayerTypes)
local Tokens = require(script.Parent.Parent.UI.Tokens)

type MatchStatePayload = MatchTypes.MatchStatePayload
type ExtractionStatePayload = MatchTypes.ExtractionStatePayload
type RosterStatePayload = MultiplayerTypes.RosterStatePayload
type RosterEntry = MultiplayerTypes.RosterEntry

local HUDController = {}

local player = Players.LocalPlayer
local playerGui: PlayerGui

local noiseFill: Frame
local noiseLabel: TextLabel
local bagLabel: TextLabel
local goldLabel: TextLabel
local stageLabel: TextLabel
local extractFrame: Frame
local extractFill: Frame
local extractLabel: TextLabel
local hpLabel: TextLabel
local hpFill: Frame
local rosterFrame: Frame
local rosterRows: { Frame } = {}

local function noiseColor(noise: number, maxNoise: number): Color3
	local t = GameConfig.StageThresholds
	if noise >= 100 or noise / maxNoise >= 1 then
		return Tokens.Danger
	elseif noise > t.Disturbed then
		return Tokens.Danger
	elseif noise > t.Sleeping then
		return Tokens.Warning
	end
	return Tokens.Safe
end

local function ensureGui()
	playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	local existing = playerGui:FindFirstChild("GorynychHUD")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "GorynychHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- Top noise cluster
	local top = Instance.new("Frame")
	top.Name = "NoiseCluster"
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.fromScale(0.5, 0.04)
	top.Size = UDim2.fromScale(0.42, 0.09)
	top.BackgroundColor3 = Tokens.Panel
	top.BackgroundTransparency = 0.15
	top.BorderSizePixel = 0
	top.Parent = gui

	local topCorner = Instance.new("UICorner")
	topCorner.CornerRadius = UDim.new(0, 12)
	topCorner.Parent = top

	local topStroke = Instance.new("UIStroke")
	topStroke.Color = Tokens.AccentGold
	topStroke.Transparency = 0.55
	topStroke.Thickness = 1
	topStroke.Parent = top

	local topAspect = Instance.new("UIAspectRatioConstraint")
	topAspect.AspectRatio = 5.2
	topAspect.Parent = top

	local topPad = Instance.new("UIPadding")
	topPad.PaddingLeft = UDim.new(0.04, 0)
	topPad.PaddingRight = UDim.new(0.04, 0)
	topPad.PaddingTop = UDim.new(0.12, 0)
	topPad.PaddingBottom = UDim.new(0.12, 0)
	topPad.Parent = top

	stageLabel = Instance.new("TextLabel")
	stageLabel.Name = "Stage"
	stageLabel.BackgroundTransparency = 1
	stageLabel.Size = UDim2.fromScale(1, 0.38)
	stageLabel.Font = Enum.Font.GothamBold
	stageLabel.TextSize = 16
	stageLabel.TextColor3 = Tokens.TextPrimary
	stageLabel.TextXAlignment = Enum.TextXAlignment.Left
	stageLabel.Text = "NOISE — SLEEPING"
	stageLabel.Parent = top

	noiseLabel = Instance.new("TextLabel")
	noiseLabel.Name = "NoiseValue"
	noiseLabel.BackgroundTransparency = 1
	noiseLabel.AnchorPoint = Vector2.new(1, 0)
	noiseLabel.Position = UDim2.fromScale(1, 0)
	noiseLabel.Size = UDim2.fromScale(0.3, 0.38)
	noiseLabel.Font = Enum.Font.GothamMedium
	noiseLabel.TextSize = 16
	noiseLabel.TextColor3 = Tokens.AccentGold
	noiseLabel.TextXAlignment = Enum.TextXAlignment.Right
	noiseLabel.Text = "0%"
	noiseLabel.Parent = top

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromScale(0, 0.5)
	track.Size = UDim2.fromScale(1, 0.42)
	track.BackgroundColor3 = Tokens.BgDeep
	track.BorderSizePixel = 0
	track.Parent = top

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 8)
	trackCorner.Parent = track

	noiseFill = Instance.new("Frame")
	noiseFill.Name = "Fill"
	noiseFill.Size = UDim2.fromScale(0, 1)
	noiseFill.BackgroundColor3 = Tokens.Safe
	noiseFill.BorderSizePixel = 0
	noiseFill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 8)
	fillCorner.Parent = noiseFill

	-- Bag chip bottom-left
	local bag = Instance.new("Frame")
	bag.Name = "BagChip"
	bag.AnchorPoint = Vector2.new(0, 1)
	bag.Position = UDim2.fromScale(0.03, 0.94)
	bag.Size = UDim2.fromScale(0.22, 0.1)
	bag.BackgroundColor3 = Tokens.Panel
	bag.BackgroundTransparency = 0.12
	bag.BorderSizePixel = 0
	bag.Parent = gui

	local bagCorner = Instance.new("UICorner")
	bagCorner.CornerRadius = UDim.new(0, 12)
	bagCorner.Parent = bag

	local bagStroke = Instance.new("UIStroke")
	bagStroke.Color = Tokens.Accent
	bagStroke.Transparency = 0.45
	bagStroke.Parent = bag

	local bagAspect = Instance.new("UIAspectRatioConstraint")
	bagAspect.AspectRatio = 2.4
	bagAspect.Parent = bag

	bagLabel = Instance.new("TextLabel")
	bagLabel.BackgroundTransparency = 1
	bagLabel.Position = UDim2.fromScale(0.08, 0.12)
	bagLabel.Size = UDim2.fromScale(0.84, 0.4)
	bagLabel.Font = Enum.Font.GothamBold
	bagLabel.TextSize = 18
	bagLabel.TextColor3 = Tokens.TextPrimary
	bagLabel.TextXAlignment = Enum.TextXAlignment.Left
	bagLabel.Text = "BAG 0 / 10"
	bagLabel.Parent = bag

	goldLabel = Instance.new("TextLabel")
	goldLabel.BackgroundTransparency = 1
	goldLabel.Position = UDim2.fromScale(0.08, 0.52)
	goldLabel.Size = UDim2.fromScale(0.84, 0.36)
	goldLabel.Font = Enum.Font.GothamMedium
	goldLabel.TextSize = 16
	goldLabel.TextColor3 = Tokens.AccentGold
	goldLabel.TextXAlignment = Enum.TextXAlignment.Left
	goldLabel.Text = "$0"
	goldLabel.Parent = bag

	-- HP chip top-left
	local hpChip = Instance.new("Frame")
	hpChip.Name = "HPChip"
	hpChip.AnchorPoint = Vector2.new(0, 0)
	hpChip.Position = UDim2.fromScale(0.03, 0.04)
	hpChip.Size = UDim2.fromScale(0.18, 0.07)
	hpChip.BackgroundColor3 = Tokens.Panel
	hpChip.BackgroundTransparency = 0.12
	hpChip.BorderSizePixel = 0
	hpChip.Parent = gui

	local hpCorner = Instance.new("UICorner")
	hpCorner.CornerRadius = UDim.new(0, 10)
	hpCorner.Parent = hpChip

	local hpStroke = Instance.new("UIStroke")
	hpStroke.Color = Tokens.Danger
	hpStroke.Transparency = 0.5
	hpStroke.Parent = hpChip

	hpLabel = Instance.new("TextLabel")
	hpLabel.BackgroundTransparency = 1
	hpLabel.Position = UDim2.fromScale(0.08, 0.08)
	hpLabel.Size = UDim2.fromScale(0.84, 0.4)
	hpLabel.Font = Enum.Font.GothamBold
	hpLabel.TextSize = 14
	hpLabel.TextColor3 = Tokens.TextPrimary
	hpLabel.TextXAlignment = Enum.TextXAlignment.Left
	hpLabel.Text = "HP 100"
	hpLabel.Parent = hpChip

	local hpTrack = Instance.new("Frame")
	hpTrack.Position = UDim2.fromScale(0.08, 0.58)
	hpTrack.Size = UDim2.fromScale(0.84, 0.28)
	hpTrack.BackgroundColor3 = Tokens.BgDeep
	hpTrack.BorderSizePixel = 0
	hpTrack.Parent = hpChip

	local hpTrackCorner = Instance.new("UICorner")
	hpTrackCorner.CornerRadius = UDim.new(0, 6)
	hpTrackCorner.Parent = hpTrack

	hpFill = Instance.new("Frame")
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = Tokens.Danger
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpTrack

	local hpFillCorner = Instance.new("UICorner")
	hpFillCorner.CornerRadius = UDim.new(0, 6)
	hpFillCorner.Parent = hpFill

	-- Extraction progress (hidden by default)
	extractFrame = Instance.new("Frame")
	extractFrame.Name = "Extraction"
	extractFrame.AnchorPoint = Vector2.new(0.5, 1)
	extractFrame.Position = UDim2.fromScale(0.5, 0.88)
	extractFrame.Size = UDim2.fromScale(0.36, 0.07)
	extractFrame.BackgroundColor3 = Tokens.Panel
	extractFrame.BackgroundTransparency = 0.1
	extractFrame.BorderSizePixel = 0
	extractFrame.Visible = false
	extractFrame.Parent = gui

	local exCorner = Instance.new("UICorner")
	exCorner.CornerRadius = UDim.new(0, 10)
	exCorner.Parent = extractFrame

	extractLabel = Instance.new("TextLabel")
	extractLabel.BackgroundTransparency = 1
	extractLabel.Size = UDim2.fromScale(1, 0.45)
	extractLabel.Position = UDim2.fromScale(0, 0.05)
	extractLabel.Font = Enum.Font.GothamBold
	extractLabel.TextSize = 15
	extractLabel.TextColor3 = Tokens.TextPrimary
	extractLabel.Text = "EXTRACTING..."
	extractLabel.Parent = extractFrame

	local exTrack = Instance.new("Frame")
	exTrack.Position = UDim2.fromScale(0.06, 0.58)
	exTrack.Size = UDim2.fromScale(0.88, 0.28)
	exTrack.BackgroundColor3 = Tokens.BgDeep
	exTrack.BorderSizePixel = 0
	exTrack.Parent = extractFrame

	local exTrackCorner = Instance.new("UICorner")
	exTrackCorner.CornerRadius = UDim.new(0, 6)
	exTrackCorner.Parent = exTrack

	extractFill = Instance.new("Frame")
	extractFill.Size = UDim2.fromScale(0, 1)
	extractFill.BackgroundColor3 = Tokens.Safe
	extractFill.BorderSizePixel = 0
	extractFill.Parent = exTrack

	local exFillCorner = Instance.new("UICorner")
	exFillCorner.CornerRadius = UDim.new(0, 6)
	exFillCorner.Parent = extractFill

	-- Team roster (right side)
	rosterFrame = Instance.new("Frame")
	rosterFrame.Name = "TeamRoster"
	rosterFrame.AnchorPoint = Vector2.new(1, 0)
	rosterFrame.Position = UDim2.fromScale(0.97, 0.14)
	rosterFrame.Size = UDim2.fromScale(0.2, 0.36)
	rosterFrame.BackgroundTransparency = 1
	rosterFrame.Parent = gui

	local rosterLayout = Instance.new("UIListLayout")
	rosterLayout.FillDirection = Enum.FillDirection.Vertical
	rosterLayout.Padding = UDim.new(0.03, 0)
	rosterLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rosterLayout.Parent = rosterFrame

	table.clear(rosterRows)
	for i = 1, 4 do
		local row = Instance.new("Frame")
		row.Name = "Slot" .. i
		row.Size = UDim2.fromScale(1, 0.22)
		row.BackgroundColor3 = Tokens.Panel
		row.BackgroundTransparency = 0.12
		row.BorderSizePixel = 0
		row.Visible = false
		row.LayoutOrder = i
		row.Parent = rosterFrame

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 8)
		rowCorner.Parent = row

		local rowStroke = Instance.new("UIStroke")
		rowStroke.Name = "Stroke"
		rowStroke.Color = Tokens.Accent
		rowStroke.Transparency = 0.55
		rowStroke.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Name"
		nameLabel.BackgroundTransparency = 1
		nameLabel.Position = UDim2.fromScale(0.06, 0.08)
		nameLabel.Size = UDim2.fromScale(0.58, 0.42)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 13
		nameLabel.TextColor3 = Tokens.TextPrimary
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Text = ""
		nameLabel.Parent = row

		local statusLabel = Instance.new("TextLabel")
		statusLabel.Name = "Status"
		statusLabel.BackgroundTransparency = 1
		statusLabel.AnchorPoint = Vector2.new(1, 0)
		statusLabel.Position = UDim2.fromScale(0.94, 0.08)
		statusLabel.Size = UDim2.fromScale(0.34, 0.42)
		statusLabel.Font = Enum.Font.GothamMedium
		statusLabel.TextSize = 11
		statusLabel.TextColor3 = Tokens.AccentGold
		statusLabel.TextXAlignment = Enum.TextXAlignment.Right
		statusLabel.Text = ""
		statusLabel.Parent = row

		local barTrack = Instance.new("Frame")
		barTrack.Name = "Track"
		barTrack.Position = UDim2.fromScale(0.06, 0.62)
		barTrack.Size = UDim2.fromScale(0.88, 0.24)
		barTrack.BackgroundColor3 = Tokens.BgDeep
		barTrack.BorderSizePixel = 0
		barTrack.Parent = row

		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(0, 4)
		barCorner.Parent = barTrack

		local barFill = Instance.new("Frame")
		barFill.Name = "Fill"
		barFill.Size = UDim2.fromScale(1, 1)
		barFill.BackgroundColor3 = Tokens.Safe
		barFill.BorderSizePixel = 0
		barFill.Parent = barTrack

		local barFillCorner = Instance.new("UICorner")
		barFillCorner.CornerRadius = UDim.new(0, 4)
		barFillCorner.Parent = barFill

		table.insert(rosterRows, row)
	end
end

local function statusStyle(entry: RosterEntry): (string, Color3, Color3)
	if entry.Status == "Downed" then
		local secs = if entry.BleedoutRemaining then math.ceil(entry.BleedoutRemaining) else 0
		return string.format("DOWN %ds", secs), Tokens.Danger, Tokens.Danger
	elseif entry.Status == "Dead" then
		return "OUT", Tokens.TextMuted, Tokens.TextMuted
	elseif entry.Status == "Extracted" then
		return "EXTRACTED", Tokens.AccentGold, Tokens.AccentGold
	end
	return "OK", Tokens.Safe, Tokens.Safe
end

local function applyRoster(payload: RosterStatePayload)
	local entries = payload.Entries
	for i, row in rosterRows do
		local entry = entries[i]
		if not entry then
			row.Visible = false
			continue
		end
		row.Visible = true
		local nameLabel = row:FindFirstChild("Name") :: TextLabel
		local statusLabel = row:FindFirstChild("Status") :: TextLabel
		local track = row:FindFirstChild("Track") :: Frame
		local fill = track and track:FindFirstChild("Fill") :: Frame
		local stroke = row:FindFirstChild("Stroke") :: UIStroke

		nameLabel.Text = entry.Name
		local statusText, statusColor, barColor = statusStyle(entry)
		statusLabel.Text = statusText
		statusLabel.TextColor3 = statusColor
		if stroke then
			stroke.Color = statusColor
		end

		local ratio = 0
		if entry.MaxHP > 0 then
			ratio = math.clamp(entry.HP / entry.MaxHP, 0, 1)
		end
		if entry.Status == "Downed" then
			ratio = if entry.BleedoutRemaining
				then math.clamp(entry.BleedoutRemaining / MultiplayerConfig.BleedoutSeconds, 0, 1)
				else 0
		elseif entry.Status == "Dead" or entry.Status == "Extracted" then
			ratio = 0
		end
		if fill then
			fill.Size = UDim2.fromScale(ratio, 1)
			fill.BackgroundColor3 = barColor
		end

		if entry.UserId == player.UserId then
			nameLabel.TextColor3 = Tokens.AccentGold
		else
			nameLabel.TextColor3 = Tokens.TextPrimary
		end
	end
end

local function applyMatchState(payload: MatchStatePayload)
	local ratio = 0
	if payload.MaxNoise > 0 then
		ratio = math.clamp(payload.Noise / payload.MaxNoise, 0, 1)
	end

	TweenService:Create(noiseFill, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(ratio, 1),
		BackgroundColor3 = noiseColor(payload.Noise, payload.MaxNoise),
	}):Play()

	noiseLabel.Text = string.format("%d%%", math.floor(payload.Noise + 0.5))
	local stageText = string.upper(payload.Stage)
	if payload.Stage == "FullAwake" then
		stageText = "FULL AWAKE — RUN"
	end
	stageLabel.Text = "NOISE — " .. stageText
	bagLabel.Text = string.format("BAG %d / %d", payload.BagUsed, payload.BagCapacity)
	goldLabel.Text = Format.gold(payload.BagValue)
end

local function applyHP()
	local current = player:GetAttribute("HP")
	local maxHp = player:GetAttribute("MaxHP")
	if typeof(current) ~= "number" then
		current = 100
	end
	if typeof(maxHp) ~= "number" or maxHp <= 0 then
		maxHp = 100
	end
	hpLabel.Text = string.format("HP %d", math.floor(current :: number))
	local ratio = math.clamp((current :: number) / (maxHp :: number), 0, 1)
	hpFill.Size = UDim2.fromScale(ratio, 1)
end

local function applyExtraction(payload: ExtractionStatePayload)
	if payload.Success then
		extractFrame.Visible = false
		return
	end
	if payload.Active then
		extractFrame.Visible = true
		extractLabel.Text = "EXTRACTING..."
		extractFill.Size = UDim2.fromScale(math.clamp(payload.Progress, 0, 1), 1)
	elseif payload.Cancelled then
		extractFrame.Visible = false
		extractFill.Size = UDim2.fromScale(0, 1)
	else
		extractFrame.Visible = false
	end
end

function HUDController.start()
	ensureGui()
	applyHP()

	RemotesClient.matchState().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		applyMatchState(payload :: MatchStatePayload)
	end)

	RemotesClient.extractionState().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		applyExtraction(payload :: ExtractionStatePayload)
	end)

	RemotesClient.rosterState().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" or typeof(payload.Entries) ~= "table" then
			return
		end
		applyRoster(payload :: RosterStatePayload)
	end)

	player:GetAttributeChangedSignal("HP"):Connect(applyHP)
	player:GetAttributeChangedSignal("MaxHP"):Connect(applyHP)
end

return HUDController
