local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local RemotesClient = require(ReplicatedStorage.Shared.Net.RemotesClient)
local DragonTypes = require(ReplicatedStorage.Shared.Types.DragonTypes)
local Tokens = require(script.Parent.Parent.UI.Tokens)

type DragonEventPayload = DragonTypes.DragonEventPayload
type DragonStatePayload = DragonTypes.DragonStatePayload

local DragonEffectsController = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local shakeConn: RBXScriptConnection? = nil

local function ensureBanner(): TextLabel
	local pg = player:WaitForChild("PlayerGui") :: PlayerGui
	local gui = pg:FindFirstChild("GorynychDragonFX")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "GorynychDragonFX"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 25
		gui.Parent = pg
	end

	local existing = gui:FindFirstChild("Banner")
	if existing and existing:IsA("TextLabel") then
		return existing
	end

	local label = Instance.new("TextLabel")
	label.Name = "Banner"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.28)
	label.Size = UDim2.fromScale(0.7, 0.12)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 42
	label.TextColor3 = Tokens.Danger
	label.TextStrokeTransparency = 0.4
	label.Text = ""
	label.Visible = false
	label.Parent = gui
	return label
end

local function showBanner(text: string, duration: number)
	local label = ensureBanner()
	label.Text = text
	label.Visible = true
	label.TextTransparency = 1
	TweenService:Create(label, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
	task.delay(duration, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
			task.delay(0.4, function()
				if label.Text == text then
					label.Visible = false
				end
			end)
		end
	end)
end

local function shake(intensity: number, duration: number)
	if shakeConn then
		shakeConn:Disconnect()
		shakeConn = nil
	end
	camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local elapsed = 0
	shakeConn = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed >= duration then
			if shakeConn then
				shakeConn:Disconnect()
				shakeConn = nil
			end
			return
		end
		local fade = 1 - elapsed / duration
		local mag = intensity * 0.35 * fade
		camera.CFrame *= CFrame.new((math.random() - 0.5) * mag, (math.random() - 0.5) * mag, 0)
	end)
end

local function spawnTelegraphPart(position: Vector3, color: Color3, lifetime: number, size: Vector3?)
	local p = Instance.new("Part")
	p.Name = "DragonTelegraph"
	p.Anchored = true
	p.CanCollide = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.55
	p.Size = size or Vector3.new(10, 1, 10)
	p.CFrame = CFrame.new(position)
	p.Parent = Workspace
	task.delay(lifetime, function()
		if p.Parent then
			p:Destroy()
		end
	end)
end

local function handleEvent(payload: DragonEventPayload)
	local kind = payload.Kind
	local intensity = payload.Intensity or 0.5
	local duration = payload.Duration or 1

	if kind == "Growl" then
		shake(intensity, duration)
		showBanner("GROWL...", 1.2)
	elseif kind == "Earthquake" then
		shake(intensity, duration)
		showBanner("EARTHQUAKE — HOLD STILL", math.min(duration, 2.5))
	elseif kind == "HotBreathTelegraph" then
		showBanner("HOT BREATH — MOVE!", duration)
		if payload.Position then
			spawnTelegraphPart(payload.Position, Color3.fromRGB(255, 140, 40), duration, Vector3.new(16, 1, 16))
		end
	elseif kind == "HotBreathImpact" then
		shake(0.8, 0.4)
	elseif kind == "FireBreathTelegraph" then
		showBanner("FIRE!", duration)
		if payload.Position then
			spawnTelegraphPart(payload.Position, Color3.fromRGB(255, 60, 30), duration, Vector3.new(14, 1, 28))
		end
	elseif kind == "FireBreathImpact" then
		shake(1, 0.5)
	elseif kind == "Smoke" then
		showBanner("SMOKE", 1.2)
		if payload.Position then
			spawnTelegraphPart(payload.Position, Color3.fromRGB(90, 100, 130), duration, Vector3.new(20, 8, 20))
		end
	elseif kind == "Acid" then
		showBanner("ACID!", 1.2)
		if payload.Position then
			spawnTelegraphPart(payload.Position, Color3.fromRGB(100, 220, 70), duration, Vector3.new(14, 1, 14))
		end
	elseif kind == "FullAwakeBanner" then
		showBanner("GORYNYCH AWOKE — RUN!", 3.5)
		shake(1.2, 1.5)
	end
end

local function handleState(payload: DragonStatePayload)
	if payload.AiState == "Searching" then
		showBanner("HE IS LISTENING...", 1.5)
	elseif payload.AiState == "Hunting" and payload.FullAwakeLocked then
		-- Banner already from FullAwake event; keep subtle
	end
end

function DragonEffectsController.start()
	ensureBanner()

	RemotesClient.dragonEvent().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" or typeof(payload.Kind) ~= "string" then
			return
		end
		handleEvent(payload :: DragonEventPayload)
	end)

	RemotesClient.dragonState().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		handleState(payload :: DragonStatePayload)
	end)
end

return DragonEffectsController
