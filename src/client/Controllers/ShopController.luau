local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ClassConfig = require(ReplicatedStorage.Shared.Config.ClassConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local Format = require(ReplicatedStorage.Shared.Utils.Format)
local RemotesClient = require(ReplicatedStorage.Shared.Net.RemotesClient)
local EconomyTypes = require(ReplicatedStorage.Shared.Types.EconomyTypes)
local Tokens = require(script.Parent.Parent.UI.Tokens)

type EconomyStatePayload = EconomyTypes.EconomyStatePayload

local ShopController = {}

local player = Players.LocalPlayer
local gui: ScreenGui?
local goldTitle: TextLabel?
local listFrame: Frame?
local tabButtons: { [string]: TextButton } = {}
local currentTab = "Bags"
local lastState: EconomyStatePayload? = nil
local gadgetChipLabel: TextLabel?

local function listHas(list: { string }?, id: string): boolean
	if not list then
		return false
	end
	for _, v in list do
		if v == id then
			return true
		end
	end
	return false
end

local function clearList()
	if not listFrame then
		return
	end
	for _, child in listFrame:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function makeRow(name: string, title: string, subtitle: string, accent: boolean, onClick: () -> ())
	if not listFrame then
		return
	end
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.fromScale(1, 0)
	btn.AutomaticSize = Enum.AutomaticSize.Y
	btn.BackgroundColor3 = if accent then Tokens.Accent else Tokens.BgDeep
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 13
	btn.TextColor3 = Tokens.TextPrimary
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.Text = "  " .. title
	btn.Parent = listFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = btn

	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Size = UDim2.new(1, -16, 0, 28)
	desc.Position = UDim2.fromOffset(8, 22)
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 11
	desc.TextColor3 = Tokens.TextMuted
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextWrapped = true
	desc.Text = subtitle
	desc.Parent = btn

	btn.MouseButton1Click:Connect(onClick)
end

local function rebuild()
	clearList()
	local state = lastState
	if not state then
		return
	end
	if goldTitle then
		goldTitle.Text = "SHOP · " .. Format.gold(state.Gold)
	end

	if currentTab == "Bags" then
		for _, def in EconomyConfig.listBags() do
			local owned = listHas(state.OwnedBags, def.Id)
			local equipped = state.EquippedBagId == def.Id
			local subtitle = if equipped
				then def.Description .. " · EQUIPPED"
				elseif owned then def.Description .. " · Own · click equip"
				else def.Description .. " · " .. Format.gold(def.Price)
			makeRow(def.Id, def.DisplayName, subtitle, equipped, function()
				if owned then
					RemotesClient.requestEquipLoadout():FireServer(def.Id, state.EquippedGadgetId)
				else
					RemotesClient.requestBuy():FireServer("Bag", def.Id)
				end
			end)
		end
	elseif currentTab == "Classes" then
		for _, classId in EconomyConfig.ClassUnlockOrder do
			local def = ClassConfig.get(classId)
			local price = EconomyConfig.getClassPrice(classId) or 0
			local unlocked = listHas(state.UnlockedClasses, classId) or price <= 0
			local subtitle = if unlocked
				then def.Description .. " · UNLOCKED"
				else def.Description .. " · Unlock " .. Format.gold(price)
			makeRow(classId, def.DisplayName, subtitle, unlocked and player:GetAttribute("ClassId") == classId, function()
				if unlocked then
					RemotesClient.requestSetClass():FireServer(classId)
				else
					RemotesClient.requestBuy():FireServer("Class", classId)
				end
			end)
		end
	else
		for _, def in EconomyConfig.listGadgets() do
			local owned = listHas(state.OwnedGadgets, def.Id)
			local equipped = state.EquippedGadgetId == def.Id
			local subtitle = if equipped
				then def.Description .. " · EQUIPPED"
				elseif owned then def.Description .. " · Own · click equip"
				else def.Description .. " · " .. Format.gold(def.Price)
			makeRow(def.Id, def.DisplayName, subtitle, equipped, function()
				if owned then
					RemotesClient.requestEquipLoadout():FireServer(state.EquippedBagId, def.Id)
				else
					RemotesClient.requestBuy():FireServer("Gadget", def.Id)
				end
			end)
		end
	end
end

local function setTab(tab: string)
	currentTab = tab
	for name, btn in tabButtons do
		btn.BackgroundColor3 = if name == tab then Tokens.Accent else Tokens.BgDeep
	end
	rebuild()
end

local function ensureGui()
	if gui and gui.Parent then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local existing = playerGui:FindFirstChild("GorynychShop")
	if existing then
		existing:Destroy()
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "GorynychShop"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 7
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.fromScale(1.25, 0.45)
	panel.Size = UDim2.fromScale(0.24, 0.55)
	panel.BackgroundColor3 = Tokens.Panel
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = gui

	TweenService:Create(panel, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.98, 0.45),
	}):Play()

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Tokens.AccentGold
	stroke.Transparency = 0.35
	stroke.Parent = panel

	goldTitle = Instance.new("TextLabel")
	goldTitle.BackgroundTransparency = 1
	goldTitle.Size = UDim2.fromScale(1, 0.1)
	goldTitle.Font = Enum.Font.GothamBold
	goldTitle.TextSize = 15
	goldTitle.TextColor3 = Tokens.AccentGold
	goldTitle.Text = "SHOP · $0"
	goldTitle.Parent = panel

	local tabs = Instance.new("Frame")
	tabs.BackgroundTransparency = 1
	tabs.Position = UDim2.fromScale(0.05, 0.11)
	tabs.Size = UDim2.fromScale(0.9, 0.08)
	tabs.Parent = panel

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0.02, 0)
	tabLayout.Parent = tabs

	for _, tabName in { "Bags", "Classes", "Gadgets" } do
		local btn = Instance.new("TextButton")
		btn.Name = tabName
		btn.Size = UDim2.fromScale(0.32, 1)
		btn.BackgroundColor3 = Tokens.BgDeep
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = false
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 11
		btn.TextColor3 = Tokens.TextPrimary
		btn.Text = string.upper(tabName)
		btn.Parent = tabs
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = btn
		tabButtons[tabName] = btn
		btn.MouseButton1Click:Connect(function()
			setTab(tabName)
		end)
	end

	listFrame = Instance.new("ScrollingFrame")
	listFrame.BackgroundTransparency = 1
	listFrame.Position = UDim2.fromScale(0.05, 0.22)
	listFrame.Size = UDim2.fromScale(0.9, 0.74)
	listFrame.BorderSizePixel = 0
	listFrame.ScrollBarThickness = 4
	listFrame.CanvasSize = UDim2.fromScale(0, 0)
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.Parent = panel

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = listFrame

	-- Match gadget chip (bottom-right above ability)
	local gadgetGui = Instance.new("ScreenGui")
	gadgetGui.Name = "GorynychGadget"
	gadgetGui.ResetOnSpawn = false
	gadgetGui.IgnoreGuiInset = true
	gadgetGui.DisplayOrder = 8
	gadgetGui.Parent = playerGui

	local chip = Instance.new("Frame")
	chip.Name = "Chip"
	chip.AnchorPoint = Vector2.new(1, 1)
	chip.Position = UDim2.fromScale(0.97, 0.84)
	chip.Size = UDim2.fromScale(0.2, 0.07)
	chip.BackgroundColor3 = Tokens.Panel
	chip.BackgroundTransparency = 0.12
	chip.BorderSizePixel = 0
	chip.Parent = gadgetGui

	local chipCorner = Instance.new("UICorner")
	chipCorner.CornerRadius = UDim.new(0, 10)
	chipCorner.Parent = chip

	gadgetChipLabel = Instance.new("TextLabel")
	gadgetChipLabel.BackgroundTransparency = 1
	gadgetChipLabel.Size = UDim2.fromScale(0.9, 0.8)
	gadgetChipLabel.Position = UDim2.fromScale(0.05, 0.1)
	gadgetChipLabel.Font = Enum.Font.GothamBold
	gadgetChipLabel.TextSize = 13
	gadgetChipLabel.TextColor3 = Tokens.TextPrimary
	gadgetChipLabel.TextXAlignment = Enum.TextXAlignment.Left
	gadgetChipLabel.Text = "E — Gadget"
	gadgetChipLabel.Parent = chip

	setTab("Bags")
end

local function refreshVisibility()
	ensureGui()
	local phase = player:GetAttribute("GamePhase")
	if gui then
		gui.Enabled = phase ~= "Match"
	end
	local gadgetGui = player.PlayerGui:FindFirstChild("GorynychGadget")
	if gadgetGui and gadgetGui:IsA("ScreenGui") then
		gadgetGui.Enabled = phase == "Match"
	end
end

local function applyEconomy(payload: EconomyStatePayload)
	lastState = payload
	ensureGui()
	rebuild()
	if gadgetChipLabel then
		local gid = payload.EquippedGadgetId
		local def = EconomyConfig.getGadget(gid)
		if def then
			local ready = payload.GadgetChargesLeft and payload.GadgetChargesLeft > 0
			if def.IsActive then
				gadgetChipLabel.Text = if ready
					then string.format("E — %s · Ready", def.DisplayName)
					else string.format("E — %s · Used", def.DisplayName)
			else
				gadgetChipLabel.Text = string.format("E — %s (passive)", def.DisplayName)
			end
		else
			gadgetChipLabel.Text = "E — No gadget"
		end
	end
end

function ShopController.start()
	ensureGui()
	refreshVisibility()

	RemotesClient.economyState().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		applyEconomy(payload :: EconomyStatePayload)
	end)

	player:GetAttributeChangedSignal("GamePhase"):Connect(refreshVisibility)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode ~= Enum.KeyCode.E then
			return
		end
		if player:GetAttribute("GamePhase") ~= "Match" then
			return
		end
		RemotesClient.requestUseGadget():FireServer()
	end)
end

return ShopController
