local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ClassConfig = require(ReplicatedStorage.Shared.Config.ClassConfig)
local FeedbackConfig = require(ReplicatedStorage.Shared.Config.FeedbackConfig)
local LootConfig = require(ReplicatedStorage.Shared.Config.LootConfig)
local Tags = require(ReplicatedStorage.Shared.Config.Tags)
local RemotesClient = require(ReplicatedStorage.Shared.Net.RemotesClient)
local Tokens = require(script.Parent.Parent.UI.Tokens)

local ScoutController = {}

local player = Players.LocalPlayer
local SENSE_ATTR = "TreasureSenseUntil"

local RARITY_RANK = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
}

local highlights: { [Instance]: Highlight } = {}
local passiveMarkers: { [Instance]: BillboardGui } = {}
local stageChip: TextLabel?
local gui: ScreenGui?
local lastDragonAi: string? = nil
local lastNoiseStage: string? = nil
-- Local wall-clock end; server stores os.clock() which does not match the client.
local senseEndsAt: number? = nil

local function isScout(): boolean
	return player:GetAttribute("ClassId") == "Scout"
end

local function inMatch(): boolean
	return player:GetAttribute("GamePhase") == "Match"
		and (player:GetAttribute("MatchStatus") == nil or player:GetAttribute("MatchStatus") == "Alive")
end

local function senseActive(): boolean
	return senseEndsAt ~= nil and os.clock() < (senseEndsAt :: number)
end

local function syncSenseWindowFromServer()
	local untilT = player:GetAttribute(SENSE_ATTR)
	if typeof(untilT) == "number" then
		local duration = ClassConfig.get("Scout").AbilityDurationSeconds or 5
		senseEndsAt = os.clock() + duration
	else
		senseEndsAt = nil
	end
end

local function getLootRarity(instance: Instance): string?
	local rarity = instance:GetAttribute("Rarity")
	if typeof(rarity) == "string" then
		return rarity
	end
	local lootId = instance:GetAttribute("LootId")
	if typeof(lootId) == "string" then
		local def = LootConfig.get(lootId)
		if def then
			return def.Rarity
		end
	end
	return nil
end

local function rarityAtLeast(rarity: string?, minRarity: string): boolean
	if not rarity then
		return false
	end
	local a = RARITY_RANK[rarity] or 0
	local b = RARITY_RANK[minRarity] or 3
	return a >= b
end

local function getLootPart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end
	return instance:FindFirstChildWhichIsA("BasePart")
end

local function clearHighlights()
	for _, h in highlights do
		h:Destroy()
	end
	table.clear(highlights)
end

local function clearPassiveMarkers()
	for _, guiMarker in passiveMarkers do
		guiMarker:Destroy()
	end
	table.clear(passiveMarkers)
end

local function ensureGui(): ScreenGui
	if gui and gui.Parent then
		return gui
	end
	local pg = player:WaitForChild("PlayerGui") :: PlayerGui
	local existing = pg:FindFirstChild("GorynychScout")
	if existing then
		existing:Destroy()
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "GorynychScout"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 9
	gui.Parent = pg

	stageChip = Instance.new("TextLabel")
	stageChip.Name = "DragonIntel"
	stageChip.AnchorPoint = Vector2.new(0.5, 0)
	stageChip.Position = UDim2.fromScale(0.5, 0.12)
	stageChip.Size = UDim2.fromScale(0.28, 0.045)
	stageChip.BackgroundColor3 = Tokens.Panel
	stageChip.BackgroundTransparency = 0.2
	stageChip.BorderSizePixel = 0
	stageChip.Font = Enum.Font.GothamBold
	stageChip.TextSize = 13
	stageChip.TextColor3 = Tokens.TextMuted
	stageChip.Text = ""
	stageChip.Visible = false
	stageChip.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = stageChip

	return gui
end

local function refreshStageChip()
	ensureGui()
	if not stageChip then
		return
	end
	local show = isScout() and inMatch()
	stageChip.Visible = show
	if not show then
		return
	end
	local parts = {}
	if lastNoiseStage then
		table.insert(parts, "Noise " .. string.upper(lastNoiseStage))
	end
	if lastDragonAi then
		table.insert(parts, "AI " .. lastDragonAi)
	end
	stageChip.Text = if #parts > 0 then table.concat(parts, " · ") else "SCOUT INTEL"
	stageChip.TextColor3 = if lastNoiseStage == "FullAwake" or lastDragonAi == "Hunting" then Tokens.Danger else Tokens.AccentGold
end

local function applySenseHighlight(instance: Instance)
	if highlights[instance] then
		return
	end
	local part = getLootPart(instance)
	if not part then
		return
	end
	local rarity = getLootRarity(instance)
	local h = Instance.new("Highlight")
	h.Name = "TreasureSenseHighlight"
	h.Adornee = instance
	h.FillColor = FeedbackConfig.rarityColor(rarity)
	h.OutlineColor = Color3.fromRGB(255, 255, 255)
	h.FillTransparency = 0.45
	h.OutlineTransparency = 0.1
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = instance
	highlights[instance] = h
end

local function applyPassiveMarker(instance: Instance)
	if passiveMarkers[instance] then
		return
	end
	local part = getLootPart(instance)
	if not part then
		return
	end
	local rarity = getLootRarity(instance) or "Rare"
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ScoutLootPing"
	billboard.Size = UDim2.fromScale(0, 0)
	billboard.Size = UDim2.fromOffset(18, 18)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 90
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.Adornee = part
	billboard.Parent = part

	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromScale(1, 1)
	dot.BackgroundColor3 = FeedbackConfig.rarityColor(rarity)
	dot.BackgroundTransparency = 0.25
	dot.BorderSizePixel = 0
	dot.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot

	passiveMarkers[instance] = billboard
end

local function updateLootVisuals()
	if not isScout() or not inMatch() then
		clearHighlights()
		clearPassiveMarkers()
		return
	end

	local def = ClassConfig.get("Scout")
	local minRarity = def.SenseMinRarity or "Rare"
	local passiveRange = def.PassiveLootRange or 45
	local senseRange = def.AbilityRange or 120
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local rootPos = if root and root:IsA("BasePart") then root.Position else nil
	local sensing = senseActive()

	local seenSense: { [Instance]: boolean } = {}
	local seenPassive: { [Instance]: boolean } = {}

	for _, inst in CollectionService:GetTagged(Tags.Loot) do
		local rarity = getLootRarity(inst)
		if not rarityAtLeast(rarity, minRarity) then
			continue
		end
		local part = getLootPart(inst)
		if not part then
			continue
		end
		local dist = if rootPos then (part.Position - rootPos).Magnitude else math.huge

		if sensing and dist <= senseRange then
			applySenseHighlight(inst)
			seenSense[inst] = true
		elseif (not sensing) and dist <= passiveRange then
			applyPassiveMarker(inst)
			seenPassive[inst] = true
		end
	end

	for inst, h in highlights do
		if not seenSense[inst] then
			h:Destroy()
			highlights[inst] = nil
		end
	end
	for inst, marker in passiveMarkers do
		if sensing or not seenPassive[inst] then
			marker:Destroy()
			passiveMarkers[inst] = nil
		end
	end
end

function ScoutController.start()
	ensureGui()
	refreshStageChip()

	player:GetAttributeChangedSignal("ClassId"):Connect(function()
		refreshStageChip()
		if not isScout() then
			senseEndsAt = nil
			clearHighlights()
			clearPassiveMarkers()
		end
	end)
	player:GetAttributeChangedSignal("GamePhase"):Connect(refreshStageChip)
	player:GetAttributeChangedSignal("MatchStatus"):Connect(refreshStageChip)
	player:GetAttributeChangedSignal(SENSE_ATTR):Connect(function()
		syncSenseWindowFromServer()
		updateLootVisuals()
	end)
	syncSenseWindowFromServer()

	RemotesClient.matchState().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) == "table" and typeof(payload.Stage) == "string" then
			lastNoiseStage = payload.Stage
			refreshStageChip()
		end
	end)

	RemotesClient.dragonState().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) == "table" and typeof(payload.AiState) == "string" then
			lastDragonAi = payload.AiState
			refreshStageChip()
		end
	end)

	RemotesClient.dragonEvent().OnClientEvent:Connect(function(payload: any)
		if not isScout() or not inMatch() then
			return
		end
		if typeof(payload) ~= "table" or typeof(payload.Kind) ~= "string" then
			return
		end
		ensureGui()
		if stageChip and string.find(payload.Kind, "Telegraph") then
			local prev = stageChip.Text
			stageChip.Text = "WARN · " .. payload.Kind
			stageChip.TextColor3 = Tokens.Danger
			stageChip.Visible = true
			TweenService:Create(stageChip, TweenInfo.new(0.12), { TextTransparency = 0 }):Play()
			task.delay(1.4, function()
				if stageChip then
					stageChip.Text = prev
					refreshStageChip()
				end
			end)
		end
	end)

	RemotesClient.abilityFx().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.UserId == player.UserId and payload.AbilityId == "TreasureSense" then
			local duration = ClassConfig.get("Scout").AbilityDurationSeconds or 5
			senseEndsAt = os.clock() + duration
			updateLootVisuals()
		end
	end)

	RunService.Heartbeat:Connect(function()
		if isScout() and inMatch() then
			updateLootVisuals()
		end
	end)
end

return ScoutController
