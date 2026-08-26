local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FeedbackConfig = require(ReplicatedStorage.Shared.Config.FeedbackConfig)
local RemotesClient = require(ReplicatedStorage.Shared.Net.RemotesClient)
local DragonTypes = require(ReplicatedStorage.Shared.Types.DragonTypes)
local MatchTypes = require(ReplicatedStorage.Shared.Types.MatchTypes)
local Tokens = require(script.Parent.Parent.UI.Tokens)

type DragonEventPayload = DragonTypes.DragonEventPayload
type DragonStatePayload = DragonTypes.DragonStatePayload
type MatchStatePayload = MatchTypes.MatchStatePayload

local DragonEffectsController = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local shakeConn: RBXScriptConnection? = nil
local vignette: Frame?
local lastStage: string? = nil

local function ensureGui(): ScreenGui
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
	return gui :: ScreenGui
end

local function ensureBanner(): TextLabel
	local gui = ensureGui()
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

local function ensureVignette(): Frame
	if vignette and vignette.Parent then
		return vignette
	end
	local gui = ensureGui()
	local existing = gui:FindFirstChild("Vignette")
	if existing and existing:IsA("Frame") then
		vignette = existing
		return vignette
	end
	vignette = Instance.new("Frame")
	vignette.Name = "Vignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundColor3 = Color3.fromRGB(40, 8, 8)
	vignette.BackgroundTransparency = 1
	vignette.BorderSizePixel = 0
	vignette.ZIndex = 1
	vignette.Parent = gui

	local grad = Instance.new("UIGradient")
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.45, 0.85),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	grad.Rotation = 90
	grad.Parent = vignette
	return vignette
end

local function setStageVignette(stage: string)
	local frame = ensureVignette()
	local target = FeedbackConfig.StageVignette[stage] or 0.95
	TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = target,
	}):Play()
	if stage == "FullAwake" then
		frame.BackgroundColor3 = Color3.fromRGB(90, 10, 10)
	elseif stage == "PartialWake" then
		frame.BackgroundColor3 = Color3.fromRGB(70, 20, 8)
	else
		frame.BackgroundColor3 = Color3.fromRGB(40, 8, 8)
	end
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
	local scaled = intensity * FeedbackConfig.ShakeScale
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
		local mag = scaled * 0.35 * fade
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
	p.Transparency = 0.7
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(position)
	p.Parent = Workspace

	local targetSize = size or Vector3.new(10, 1, 10)
	TweenService:Create(p, TweenInfo.new(FeedbackConfig.TelegraphFadeSeconds), {
		Size = targetSize,
		Transparency = 0.45,
	}):Play()

	task.delay(lifetime, function()
		if p.Parent then
			TweenService:Create(p, TweenInfo.new(0.2), { Transparency = 1 }):Play()
			task.delay(0.25, function()
				if p.Parent then
					p:Destroy()
				end
			end)
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
		setStageVignette("FullAwake")
	end
end

local function handleState(payload: DragonStatePayload)
	if payload.AiState == "Searching" then
		showBanner("HE IS LISTENING...", 1.5)
	elseif payload.AiState == "Hunting" and payload.FullAwakeLocked then
		setStageVignette("FullAwake")
	end
end

function DragonEffectsController.start()
	ensureBanner()
	ensureVignette()

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

	RemotesClient.matchState().OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" or typeof(payload.Stage) ~= "string" then
			return
		end
		local stage = (payload :: MatchStatePayload).Stage
		if stage ~= lastStage then
			lastStage = stage
			setStageVignette(stage)
		end
	end)
end

return DragonEffectsController
