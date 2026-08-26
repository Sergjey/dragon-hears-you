local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Utils.Format)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RemotesClient = require(ReplicatedStorage.Shared.Net.RemotesClient)
local MatchTypes = require(ReplicatedStorage.Shared.Types.MatchTypes)
local Tokens = require(script.Parent.Parent.UI.Tokens)

type MatchStatePayload = MatchTypes.MatchStatePayload
type ExtractionStatePayload = MatchTypes.ExtractionStatePayload

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
	stageLabel.Text = "NOISE — " .. string.upper(payload.Stage)
	bagLabel.Text = string.format("BAG %d / %d", payload.BagUsed, payload.BagCapacity)
	goldLabel.Text = Format.gold(payload.BagValue)
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
end

return HUDController
