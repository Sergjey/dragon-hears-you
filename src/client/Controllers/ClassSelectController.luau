local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ClassConfig = require(ReplicatedStorage.Shared.Config.ClassConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local Format = require(ReplicatedStorage.Shared.Utils.Format)
local RemotesClient = require(ReplicatedStorage.Shared.Net.RemotesClient)
local ClassTypes = require(ReplicatedStorage.Shared.Types.ClassTypes)
local Tokens = require(script.Parent.Parent.UI.Tokens)

type ClassStatePayload = ClassTypes.ClassStatePayload

local ClassSelectController = {}

local player = Players.LocalPlayer
local selectGui: ScreenGui?
local abilityGui: ScreenGui?
local abilityLabel: TextLabel?
local cdLabel: TextLabel?
local classList: Frame?
local unlockedClasses: { string } = { "Thief" }

local function listHas(list: { string }, id: string): boolean
	for _, v in list do
		if v == id then
			return true
		end
	end
	return false
end

local function refreshClassLabels()
	if not classList then
		return
	end
	for _, child in classList:GetChildren() do
		if child:IsA("TextButton") then
			local def = ClassConfig.get(child.Name)
			local price = EconomyConfig.getClassPrice(def.Id) or 0
			local unlocked = listHas(unlockedClasses, def.Id) or price <= 0
			local desc = child:FindFirstChildWhichIsA("TextLabel")
			if unlocked then
				child.Text = def.DisplayName
				child.TextColor3 = Tokens.TextPrimary
				if desc then
					desc.Text = def.Description
				end
			else
				child.Text = def.DisplayName .. " [LOCK]"
				child.TextColor3 = Tokens.TextMuted
				if desc then
					desc.Text = "Unlock " .. Format.gold(price) .. " · " .. def.Description
				end
			end
		end
	end
end

local function highlightClass(classId: string)
	if not classList then
		return
	end
	for _, child in classList:GetChildren() do
		if child:IsA("TextButton") then
			child.BackgroundColor3 = if child.Name == classId then Tokens.Accent else Tokens.BgDeep
		end
	end
end

local function ensureSelectGui()
	if selectGui and selectGui.Parent then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local existing = playerGui:FindFirstChild("GorynychClassSelect")
	if existing then
		existing:Destroy()
	end

	selectGui = Instance.new("ScreenGui")
	selectGui.Name = "GorynychClassSelect"
	selectGui.ResetOnSpawn = false
	selectGui.IgnoreGuiInset = true
	selectGui.DisplayOrder = 6
	selectGui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.fromScale(-0.25, 0.45)
	panel.Size = UDim2.fromScale(0.22, 0.5)
	panel.BackgroundColor3 = Tokens.Panel
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Parent = selectGui

	TweenService:Create(panel, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.02, 0.45),
	}):Play()

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Tokens.Accent
	stroke.Transparency = 0.4
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.12)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextColor3 = Tokens.TextPrimary
	title.Text = "CLASS"
	title.Parent = panel

	classList = Instance.new("Frame")
	classList.BackgroundTransparency = 1
	classList.Position = UDim2.fromScale(0.06, 0.14)
	classList.Size = UDim2.fromScale(0.88, 0.8)
	classList.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0.03, 0)
	layout.Parent = classList

	for _, def in ClassConfig.list() do
		local btn = Instance.new("TextButton")
		btn.Name = def.Id
		btn.Size = UDim2.fromScale(1, 0.22)
		btn.BackgroundColor3 = Tokens.BgDeep
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = false
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 14
		btn.TextColor3 = Tokens.TextPrimary
		btn.Text = def.DisplayName
		btn.Parent = classList

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 8)
		btnCorner.Parent = btn

		local desc = Instance.new("TextLabel")
		desc.BackgroundTransparency = 1
		desc.Position = UDim2.fromScale(0.05, 0.55)
		desc.Size = UDim2.fromScale(0.9, 0.4)
		desc.Font = Enum.Font.Gotham
		desc.TextSize = 11
		desc.TextColor3 = Tokens.TextMuted
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextWrapped = true
		desc.Text = def.Description
		desc.Parent = btn

		btn.MouseButton1Click:Connect(function()
			local price = EconomyConfig.getClassPrice(def.Id) or 0
			local unlocked = listHas(unlockedClasses, def.Id) or price <= 0
			if unlocked then
				RemotesClient.requestSetClass():FireServer(def.Id)
			else
				RemotesClient.requestBuy():FireServer("Class", def.Id)
			end
		end)
	end

	local current = player:GetAttribute("ClassId")
	highlightClass(if typeof(current) == "string" then current :: string else ClassConfig.DefaultClassId)
	refreshClassLabels()
end

local function ensureAbilityGui()
	if abilityGui and abilityGui.Parent then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local existing = playerGui:FindFirstChild("GorynychAbility")
	if existing then
		existing:Destroy()
	end

	abilityGui = Instance.new("ScreenGui")
	abilityGui.Name = "GorynychAbility"
	abilityGui.ResetOnSpawn = false
	abilityGui.IgnoreGuiInset = true
	abilityGui.DisplayOrder = 8
	abilityGui.Parent = playerGui

	local chip = Instance.new("Frame")
	chip.AnchorPoint = Vector2.new(1, 1)
	chip.Position = UDim2.fromScale(0.97, 0.94)
	chip.Size = UDim2.fromScale(0.2, 0.09)
	chip.BackgroundColor3 = Tokens.Panel
	chip.BackgroundTransparency = 0.12
	chip.BorderSizePixel = 0
	chip.Parent = abilityGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = chip

	local stroke = Instance.new("UIStroke")
	stroke.Color = Tokens.AccentGold
	stroke.Transparency = 0.45
	stroke.Parent = chip

	abilityLabel = Instance.new("TextLabel")
	abilityLabel.BackgroundTransparency = 1
	abilityLabel.Position = UDim2.fromScale(0.08, 0.1)
	abilityLabel.Size = UDim2.fromScale(0.84, 0.4)
	abilityLabel.Font = Enum.Font.GothamBold
	abilityLabel.TextSize = 14
	abilityLabel.TextColor3 = Tokens.TextPrimary
	abilityLabel.TextXAlignment = Enum.TextXAlignment.Left
	abilityLabel.Text = "Q — Ability"
	abilityLabel.Parent = chip

	cdLabel = Instance.new("TextLabel")
	cdLabel.BackgroundTransparency = 1
	cdLabel.Position = UDim2.fromScale(0.08, 0.52)
	cdLabel.Size = UDim2.fromScale(0.84, 0.36)
	cdLabel.Font = Enum.Font.GothamMedium
	cdLabel.TextSize = 13
	cdLabel.TextColor3 = Tokens.AccentGold
	cdLabel.TextXAlignment = Enum.TextXAlignment.Left
	cdLabel.Text = "Ready"
	cdLabel.Parent = chip
end

local function applyClassState(payload: ClassStatePayload)
	ensureAbilityGui()
	highlightClass(payload.ClassId)
	if abilityLabel then
		abilityLabel.Text = string.format("Q — %s (%s)", payload.AbilityName, payload.ClassId)
	end
	if cdLabel then
		if payload.CooldownRemaining > 0.05 then
			cdLabel.Text = string.format("CD %.0fs", payload.CooldownRemaining)
			cdLabel.TextColor3 = Tokens.TextMuted
		else
			cdLabel.Text = "Ready"
			cdLabel.TextColor3 = Tokens.Safe
		end
		if payload.SilentStepRemaining then
			cdLabel.Text ..= string.format(" · Silent %.0fs", payload.SilentStepRemaining)
		end
		if payload.ShieldCharges and payload.ShieldCharges > 0 then
			cdLabel.Text ..= " · Shield"
		end
	end
end

local function refreshVisibility()
	local phase = player:GetAttribute("GamePhase")
	if selectGui then
		selectGui.Enabled = phase ~= "Match"
	end
	if abilityGui then
		abilityGui.Enabled = phase == "Match"
	end
end

function ClassSelectController.start()
	ensureSelectGui()
	ensureAbilityGui()
	refreshVisibility()

	RemotesClient.classState().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		applyClassState(payload :: ClassStatePayload)
	end)

	RemotesClient.economyState().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" or typeof(payload.UnlockedClasses) ~= "table" then
			return
		end
		unlockedClasses = payload.UnlockedClasses
		refreshClassLabels()
	end)

	player:GetAttributeChangedSignal("GamePhase"):Connect(refreshVisibility)
	player:GetAttributeChangedSignal("ClassId"):Connect(function()
		local id = player:GetAttribute("ClassId")
		if typeof(id) == "string" then
			highlightClass(id :: string)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode ~= Enum.KeyCode.Q then
			return
		end
		if player:GetAttribute("GamePhase") ~= "Match" then
			return
		end
		RemotesClient.requestUseAbility():FireServer()
	end)
end

return ClassSelectController
