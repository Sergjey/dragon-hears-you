local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FeedbackConfig = require(ReplicatedStorage.Shared.Config.FeedbackConfig)
local Format = require(ReplicatedStorage.Shared.Utils.Format)
local Tags = require(ReplicatedStorage.Shared.Config.Tags)
local RemotesClient = require(ReplicatedStorage.Shared.Net.RemotesClient)
local Tokens = require(script.Parent.Parent.UI.Tokens)

local FeedbackController = {}

local player = Players.LocalPlayer
local popupGui: ScreenGui?
local bobConn: RBXScriptConnection?
local bobBases: { [BasePart]: { Origin: CFrame, Phase: number } } = {}

local function ensurePopupGui(): ScreenGui
	if popupGui and popupGui.Parent then
		return popupGui
	end
	local pg = player:WaitForChild("PlayerGui") :: PlayerGui
	local existing = pg:FindFirstChild("GorynychFeedback")
	if existing then
		existing:Destroy()
	end
	popupGui = Instance.new("ScreenGui")
	popupGui.Name = "GorynychFeedback"
	popupGui.ResetOnSpawn = false
	popupGui.IgnoreGuiInset = true
	popupGui.DisplayOrder = 15
	popupGui.Parent = pg
	return popupGui
end

local function showLootPopup(rarity: string, value: number)
	local gui = ensurePopupGui()
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.62)
	label.Size = UDim2.fromScale(0.28, 0.06)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 22
	label.TextColor3 = FeedbackConfig.rarityColor(rarity)
	label.TextStrokeTransparency = 0.5
	label.Text = string.upper(rarity) .. "  " .. Format.gold(value)
	label.TextTransparency = 1
	label.Parent = gui

	TweenService:Create(label, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
	TweenService:Create(label, TweenInfo.new(FeedbackConfig.PopupLifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.54),
		TextTransparency = 1,
	}):Play()
	task.delay(FeedbackConfig.PopupLifetime + 0.05, function()
		label:Destroy()
	end)
end

local function burstAt(position: Vector3?, color: Color3, count: number?)
	local pos = position
	if not pos then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			pos = root.Position
		else
			return
		end
	end

	local anchor = Instance.new("Part")
	anchor.Name = "FxBurst"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(pos)
	anchor.Parent = Workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.6
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.35, 0.7)
	emitter.Speed = NumberRange.new(4, 10)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(count or 18)

	task.delay(FeedbackConfig.ParticleLifetime + 0.2, function()
		if anchor.Parent then
			anchor:Destroy()
		end
	end)
end

local function trackLoot(instance: Instance)
	local part: BasePart? = if instance:IsA("BasePart") then instance else instance:FindFirstChildWhichIsA("BasePart")
	if not part then
		return
	end
	if bobBases[part] then
		return
	end
	bobBases[part] = {
		Origin = part.CFrame,
		Phase = math.random() * math.pi * 2,
	}
	local rarity = instance:GetAttribute("Rarity")
	if typeof(rarity) ~= "string" then
		local lootId = instance:GetAttribute("LootId")
		if typeof(lootId) == "string" then
			local LootConfig = require(ReplicatedStorage.Shared.Config.LootConfig)
			local def = LootConfig.get(lootId)
			if def then
				rarity = def.Rarity
			end
		end
	end
	if typeof(rarity) == "string" then
		part.Color = FeedbackConfig.rarityColor(rarity)
	end
end

local function untrackLoot(instance: Instance)
	local part: BasePart? = if instance:IsA("BasePart") then instance else instance:FindFirstChildWhichIsA("BasePart")
	if part then
		bobBases[part] = nil
	end
end

local function startLootBob()
	if bobConn then
		return
	end
	for _, inst in CollectionService:GetTagged(Tags.Loot) do
		trackLoot(inst)
	end
	CollectionService:GetInstanceAddedSignal(Tags.Loot):Connect(trackLoot)
	CollectionService:GetInstanceRemovedSignal(Tags.Loot):Connect(untrackLoot)

	bobConn = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for part, data in bobBases do
			if not part.Parent then
				bobBases[part] = nil
				continue
			end
			local y = math.sin(t * FeedbackConfig.LootBobSpeed + data.Phase) * FeedbackConfig.LootBobAmplitude
			local spin = t * FeedbackConfig.LootSpinSpeed + data.Phase
			part.CFrame = data.Origin * CFrame.new(0, y, 0) * CFrame.Angles(0, spin, 0)
		end
	end)
end

function FeedbackController.start()
	ensurePopupGui()
	startLootBob()

	RemotesClient.lootFx().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.UserId ~= player.UserId then
			return
		end
		showLootPopup(tostring(payload.Rarity or "Common"), tonumber(payload.Value) or 0)
		burstAt(payload.Position, FeedbackConfig.rarityColor(payload.Rarity), 22)
	end)

	RemotesClient.abilityFx().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" or typeof(payload.AbilityId) ~= "string" then
			return
		end
		local color = FeedbackConfig.AbilityColors[payload.AbilityId] or Tokens.Accent
		burstAt(payload.Position, color, 20)
	end)

	RemotesClient.gadgetFx().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" or typeof(payload.GadgetId) ~= "string" then
			return
		end
		local color = FeedbackConfig.AbilityColors[payload.GadgetId] or Tokens.AccentGold
		burstAt(payload.Position, color, 24)
	end)
end

return FeedbackController
