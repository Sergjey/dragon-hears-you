local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MultiplayerConfig = require(ReplicatedStorage.Shared.Config.MultiplayerConfig)
local RemotesClient = require(ReplicatedStorage.Shared.Net.RemotesClient)
local MultiplayerTypes = require(ReplicatedStorage.Shared.Types.MultiplayerTypes)
local Tokens = require(script.Parent.Parent.UI.Tokens)

type RosterStatePayload = MultiplayerTypes.RosterStatePayload

local DownedController = {}

local player = Players.LocalPlayer
local vignette: Frame?
local hintLabel: TextLabel?
local gui: ScreenGui?
local nearbyDowned: Player? = nil
local localBleedout: number? = nil

local function ensureGui()
	if gui and gui.Parent then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local existing = playerGui:FindFirstChild("GorynychDowned")
	if existing then
		existing:Destroy()
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "GorynychDowned"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 15
	gui.Parent = playerGui

	vignette = Instance.new("Frame")
	vignette.Name = "Vignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundColor3 = Tokens.Danger
	vignette.BackgroundTransparency = 1
	vignette.BorderSizePixel = 0
	vignette.Visible = false
	vignette.Parent = gui

	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.45, 0.85),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	gradient.Rotation = 90
	gradient.Parent = vignette

	hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "ReviveHint"
	hintLabel.AnchorPoint = Vector2.new(0.5, 1)
	hintLabel.Position = UDim2.fromScale(0.5, 0.82)
	hintLabel.Size = UDim2.fromScale(0.5, 0.06)
	hintLabel.BackgroundColor3 = Tokens.Panel
	hintLabel.BackgroundTransparency = 0.15
	hintLabel.BorderSizePixel = 0
	hintLabel.Font = Enum.Font.GothamBold
	hintLabel.TextSize = 18
	hintLabel.TextColor3 = Tokens.TextPrimary
	hintLabel.Text = ""
	hintLabel.Visible = false
	hintLabel.Parent = gui

	local hintCorner = Instance.new("UICorner")
	hintCorner.CornerRadius = UDim.new(0, 10)
	hintCorner.Parent = hintLabel

	local hintStroke = Instance.new("UIStroke")
	hintStroke.Color = Tokens.AccentGold
	hintStroke.Transparency = 0.4
	hintStroke.Parent = hintLabel
end

local function setSelfDowned(active: boolean)
	ensureGui()
	if not vignette or not hintLabel then
		return
	end
	if active then
		vignette.Visible = true
		TweenService:Create(vignette, TweenInfo.new(0.25), { BackgroundTransparency = 0.55 }):Play()
		local secs = if localBleedout then math.ceil(localBleedout) else MultiplayerConfig.BleedoutSeconds
		hintLabel.Visible = true
		hintLabel.Text = string.format("DOWNED — bleedout %ds", secs)
		hintLabel.TextColor3 = Tokens.Danger
	else
		TweenService:Create(vignette, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
		task.delay(0.2, function()
			if vignette and player:GetAttribute("MatchStatus") ~= "Downed" then
				vignette.Visible = false
			end
		end)
		if not nearbyDowned then
			hintLabel.Visible = false
		end
	end
end

local function findNearbyDowned(): Player?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local status = player:GetAttribute("MatchStatus")
	if status == "Downed" or status == "Dead" or status == "Extracted" then
		return nil
	end

	local best: Player? = nil
	local bestDist = MultiplayerConfig.ReviveMaxDistance
	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		if other:GetAttribute("MatchStatus") ~= "Downed" then
			continue
		end
		local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if otherRoot and otherRoot:IsA("BasePart") then
			local dist = (otherRoot.Position - root.Position).Magnitude
			if dist <= bestDist then
				bestDist = dist
				best = other
			end
		end
	end
	return best
end

local function updateHints()
	ensureGui()
	if not hintLabel then
		return
	end

	local selfStatus = player:GetAttribute("MatchStatus")
	if selfStatus == "Downed" then
		local secs = if localBleedout then math.ceil(localBleedout) else MultiplayerConfig.BleedoutSeconds
		hintLabel.Visible = true
		hintLabel.Text = string.format("DOWNED — bleedout %ds", secs)
		hintLabel.TextColor3 = Tokens.Danger
		return
	end

	nearbyDowned = findNearbyDowned()
	if nearbyDowned then
		hintLabel.Visible = true
		hintLabel.Text = string.format("Hold prompt near %s to revive (%.0fs)", nearbyDowned.DisplayName, MultiplayerConfig.ReviveHoldSeconds)
		hintLabel.TextColor3 = Tokens.AccentGold
	else
		hintLabel.Visible = false
	end
end

function DownedController.start()
	ensureGui()

	player:GetAttributeChangedSignal("MatchStatus"):Connect(function()
		local status = player:GetAttribute("MatchStatus")
		if status == "Downed" then
			setSelfDowned(true)
		else
			localBleedout = nil
			setSelfDowned(false)
		end
	end)

	RemotesClient.rosterState().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" or typeof(payload.Entries) ~= "table" then
			return
		end
		local roster = payload :: RosterStatePayload
		for _, entry in roster.Entries do
			if entry.UserId == player.UserId and entry.Status == "Downed" then
				localBleedout = entry.BleedoutRemaining
				break
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		local status = player:GetAttribute("MatchStatus")
		if status == "Downed" then
			if vignette and vignette.Visible then
				local pulse = 0.5 + 0.08 * math.sin(os.clock() * 3)
				vignette.BackgroundTransparency = pulse
			end
		end
		updateHints()
	end)
end

return DownedController
