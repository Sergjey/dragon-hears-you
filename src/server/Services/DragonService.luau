local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local DragonConfig = require(ReplicatedStorage.Shared.Config.DragonConfig)
local Tags = require(ReplicatedStorage.Shared.Config.Tags)
local DragonTypes = require(ReplicatedStorage.Shared.Types.DragonTypes)
local Remotes = require(script.Parent.Parent.Net.Remotes)

local DamageService = require(script.Parent.DamageService)
local DragonPerception = require(script.Parent.DragonPerception)
local MovementModifierService = require(script.Parent.MovementModifierService)
local NoiseService = require(script.Parent.NoiseService)

type AiState = DragonTypes.AiState
type HeadId = DragonTypes.HeadId
type DisturbedEventKind = DragonTypes.DisturbedEventKind
type DragonStatePayload = DragonTypes.DragonStatePayload
type DragonEventPayload = DragonTypes.DragonEventPayload

local DragonService = {}

local started = false
local aiState: AiState = "Sleeping"
local dragonModel: Model? = nil
local body: BasePart? = nil
local heads: { [HeadId]: BasePart } = {}
local headRestCFrame: { [HeadId]: CFrame } = {}
local headRaised = false

local disturbedCooldownUntil = 0
local calmTimer = 0
local huntAttackAcc = 0
local fireCd = 0
local smokeCd = 0
local acidCd = 0
local lastKnownPos: Vector3? = nil
local eventBusy = false

local function fireState()
	local active: { HeadId } = {}
	if aiState == "Searching" or aiState == "PartialWake" then
		table.insert(active, "Red")
	elseif aiState == "FullAwake" or aiState == "Hunting" then
		active = { "Red", "Blue", "Green" }
	end
	local payload: DragonStatePayload = {
		AiState = aiState,
		FullAwakeLocked = NoiseService.isFullAwakeLocked(),
		ActiveHeads = active,
	}
	Remotes.dragonState():FireAllClients(payload)
end

local function fireEvent(payload: DragonEventPayload)
	Remotes.dragonEvent():FireAllClients(payload)
end

local function setState(nextState: AiState)
	if aiState == nextState then
		return
	end
	aiState = nextState
	fireState()
end

local function getHead(id: HeadId): BasePart?
	return heads[id]
end

local function raiseHeads(which: { HeadId }, raised: boolean)
	headRaised = raised
	local rise = if raised then DragonConfig.HeadRiseStuds else 0
	for _, id in which do
		local head = heads[id]
		local rest = headRestCFrame[id]
		if head and rest then
			local goal = rest + Vector3.new(0, rise, 0)
			TweenService:Create(head, TweenInfo.new(DragonConfig.HeadRiseSeconds, Enum.EasingStyle.Quad), {
				CFrame = goal,
			}):Play()
		end
	end
end

local function resolveDragon()
	dragonModel = nil
	body = nil
	table.clear(heads)
	table.clear(headRestCFrame)

	for _, inst in CollectionService:GetTagged(Tags.Dragon) do
		if inst:IsA("Model") then
			dragonModel = inst
			break
		end
	end
	if not dragonModel then
		return
	end

	local primary = dragonModel.PrimaryPart or dragonModel:FindFirstChild("Body")
	if primary and primary:IsA("BasePart") then
		body = primary
	end

	for headId, partName in DragonConfig.Heads do
		local part = dragonModel:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			local id = headId :: HeadId
			heads[id] = part
			headRestCFrame[id] = part.CFrame
			if not part:FindFirstChild("Nostril") then
				local att = Instance.new("Attachment")
				att.Name = "Nostril"
				att.Position = Vector3.new(0, 0.5, -part.Size.Z / 2)
				att.Parent = part
			end
		end
	end
end

local function spawnZone(name: string, position: Vector3, size: Vector3, color: Color3, lifetime: number): BasePart
	local zone = Instance.new("Part")
	zone.Name = name
	zone.Size = size
	zone.CFrame = CFrame.new(position)
	zone.Anchored = true
	zone.CanCollide = false
	zone.Material = Enum.Material.Neon
	zone.Color = color
	zone.Transparency = 0.45
	zone.Parent = Workspace
	CollectionService:AddTag(zone, Tags.DragonDamageZone)
	task.delay(lifetime, function()
		if zone.Parent then
			zone:Destroy()
		end
	end)
	return zone
end

local function fireBreathAt(targetPos: Vector3)
	local head = getHead("Red")
	if not head then
		return
	end
	fireEvent({
		Kind = "FireBreathTelegraph",
		HeadId = "Red",
		Position = targetPos,
		Duration = DragonConfig.FireBreathTelegraphSeconds,
		Intensity = 1,
	})
	task.delay(DragonConfig.FireBreathTelegraphSeconds, function()
		if not NoiseService.isMatchActive() or not head.Parent then
			return
		end
		fireEvent({
			Kind = "FireBreathImpact",
			HeadId = "Red",
			Position = targetPos,
			Intensity = 1,
		})
		DamageService.applyCone(
			head.Position,
			targetPos - head.Position,
			DragonConfig.FireBreathRange,
			DragonConfig.FireBreathHalfAngleDeg,
			DragonConfig.FireBreathDamage,
			"FireBreath"
		)
	end)
end

local function castSmoke(at: Vector3)
	fireEvent({ Kind = "Smoke", HeadId = "Blue", Position = at, Duration = DragonConfig.SmokeDurationSeconds })
	spawnZone(
		"SmokeZone",
		at,
		Vector3.new(DragonConfig.SmokeRadius * 2, 6, DragonConfig.SmokeRadius * 2),
		Color3.fromRGB(80, 90, 120),
		DragonConfig.SmokeDurationSeconds
	)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - at).Magnitude <= DragonConfig.SmokeRadius then
			MovementModifierService.applySlow(
				player,
				DragonConfig.SmokeDurationSeconds,
				DragonConfig.SmokeSlowMultiplier
			)
			NoiseService.add(DragonConfig.SmokeCoughNoise, "Cough", root.Position)
		end
	end
end

local function castAcid(at: Vector3)
	fireEvent({ Kind = "Acid", HeadId = "Green", Position = at, Duration = DragonConfig.AcidDurationSeconds })
	spawnZone(
		"AcidZone",
		at - Vector3.new(0, 1, 0),
		Vector3.new(DragonConfig.AcidRadius * 2, 1, DragonConfig.AcidRadius * 2),
		Color3.fromRGB(90, 200, 60),
		DragonConfig.AcidDurationSeconds
	)
	local ticks = math.floor(DragonConfig.AcidDurationSeconds / DragonConfig.AcidTickSeconds)
	for i = 1, ticks do
		task.delay(i * DragonConfig.AcidTickSeconds, function()
			if NoiseService.isMatchActive() then
				DamageService.applyAoE(at, DragonConfig.AcidRadius, DragonConfig.AcidDamagePerTick, "Acid")
			end
		end)
	end
end

local function lockFullAwake()
	if NoiseService.isFullAwakeLocked() and (aiState == "Hunting" or aiState == "FullAwake") then
		return
	end
	NoiseService.setFullAwakeLocked(true)
	raiseHeads({ "Red", "Blue", "Green" }, true)
	setState("FullAwake")
	fireEvent({ Kind = "FullAwakeBanner", Intensity = 1 })
	setState("Hunting")
end

local function runGrowl()
	fireEvent({ Kind = "Growl", Intensity = 0.55, Duration = 1.2 })
end

local function runEarthquake()
	local duration = DragonConfig.EarthquakeDurationMin
		+ math.random() * (DragonConfig.EarthquakeDurationMax - DragonConfig.EarthquakeDurationMin)
	fireEvent({ Kind = "Earthquake", Duration = duration, Intensity = 0.9 })
	for _, player in Players:GetPlayers() do
		MovementModifierService.freeze(player, duration)
	end
	return duration
end

local function runHotBreath()
	local head = getHead("Red") or getHead("Blue") or getHead("Green")
	if not head then
		return
	end
	local impactPos = head.Position + head.CFrame.LookVector * DragonConfig.HotBreathOffsetStuds
	fireEvent({
		Kind = "HotBreathTelegraph",
		HeadId = "Red",
		Position = impactPos,
		Duration = DragonConfig.HotBreathTelegraphSeconds,
		Intensity = 0.7,
	})
	head:SetAttribute("NostrilGlow", true)
	task.wait(DragonConfig.HotBreathTelegraphSeconds)
	head:SetAttribute("NostrilGlow", false)
	local dmg = DragonConfig.HotBreathDamageMin
		+ math.random() * (DragonConfig.HotBreathDamageMax - DragonConfig.HotBreathDamageMin)
	fireEvent({
		Kind = "HotBreathImpact",
		HeadId = "Red",
		Position = impactPos,
		Intensity = 1,
	})
	spawnZone(
		"HotBreathZone",
		impactPos,
		Vector3.new(DragonConfig.HotBreathRadius * 2, 4, DragonConfig.HotBreathRadius * 2),
		Color3.fromRGB(255, 120, 40),
		1.2
	)
	DamageService.applyAoE(impactPos, DragonConfig.HotBreathRadius, dmg, "HotBreath")
end

local DISTURBED_EVENTS: { DisturbedEventKind } = { "Growl", "Earthquake", "HotBreath" }

local function beginDisturbedEvent()
	if eventBusy then
		return
	end
	eventBusy = true
	setState("Disturbed")
	local kind = DISTURBED_EVENTS[math.random(1, #DISTURBED_EVENTS)]
	task.spawn(function()
		if kind == "Growl" then
			runGrowl()
			task.wait(1.2)
		elseif kind == "Earthquake" then
			local duration = runEarthquake()
			task.wait(duration)
		else
			runHotBreath()
		end
		NoiseService.set(DragonConfig.PostDisturbedNoise)
		disturbedCooldownUntil = os.clock() + DragonConfig.DisturbedEventCooldownSeconds
		eventBusy = false
		if not NoiseService.isFullAwakeLocked() then
			setState("Sleeping")
			raiseHeads({ "Red", "Blue", "Green" }, false)
		end
	end)
end

local function tickSearching(dt: number)
	if NoiseService.get() >= 100 then
		lockFullAwake()
		return
	end

	local head = getHead("Red")
	if not head or not dragonModel then
		return
	end

	local spotted = DragonPerception.findVisiblePlayer(head, dragonModel)
	if spotted and spotted.Character then
		local root = spotted.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			lastKnownPos = root.Position
			fireBreathAt(root.Position)
			lockFullAwake()
			return
		end
	end

	local hear = DragonPerception.getLoudestRecent()
	if hear then
		lastKnownPos = hear.Position
		calmTimer = 0
		local flatTarget = Vector3.new(hear.Position.X, head.Position.Y, hear.Position.Z)
		if (flatTarget - head.Position).Magnitude > 0.5 then
			local look = CFrame.lookAt(head.Position, flatTarget)
			local raisedOffset = if headRaised then Vector3.new(0, DragonConfig.HeadRiseStuds, 0) else Vector3.zero
			head.CFrame = head.CFrame:Lerp(look + raisedOffset, math.min(1, dt * 3))
		end
	else
		calmTimer += dt
	end

	if calmTimer >= DragonConfig.PartialCalmSeconds then
		NoiseService.set(DragonConfig.PostCalmNoise)
		raiseHeads({ "Red", "Blue", "Green" }, false)
		setState("Sleeping")
		calmTimer = 0
	end
end

local function tickHunting(dt: number)
	fireCd = math.max(0, fireCd - dt)
	smokeCd = math.max(0, smokeCd - dt)
	acidCd = math.max(0, acidCd - dt)
	huntAttackAcc += dt

	local hear = DragonPerception.getLoudestRecent()
	if hear then
		lastKnownPos = hear.Position
	end
	for _, player in Players:GetPlayers() do
		if DamageService.isDead(player) then
			continue
		end
		local red = getHead("Red")
		if red and dragonModel and DragonPerception.canSeePlayer(red, player, dragonModel) then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				lastKnownPos = root.Position
			end
		end
	end

	if huntAttackAcc < DragonConfig.HuntAttackIntervalSeconds then
		return
	end
	huntAttackAcc = 0

	local target = lastKnownPos
	if not target then
		target = if body then body.Position + Vector3.new(0, 0, -20) else Vector3.new(0, 5, 0)
	end

	local options = {}
	if fireCd <= 0 then
		table.insert(options, "Fire")
	end
	if smokeCd <= 0 then
		table.insert(options, "Smoke")
	end
	if acidCd <= 0 then
		table.insert(options, "Acid")
	end
	if #options == 0 then
		return
	end
	local pick = options[math.random(1, #options)]
	if pick == "Fire" then
		fireCd = DragonConfig.FireBreathCooldownSeconds
		fireBreathAt(target)
	elseif pick == "Smoke" then
		smokeCd = DragonConfig.SmokeCooldownSeconds
		castSmoke(target)
	else
		acidCd = DragonConfig.AcidCooldownSeconds
		castAcid(target)
	end
end

local handlers: { [AiState]: (dt: number) -> () } = {
	Sleeping = function(_dt)
		local stage = NoiseService.getStage()
		if stage == "FullAwake" or NoiseService.get() >= 100 then
			lockFullAwake()
			return
		end
		if stage == "PartialWake" then
			setState("PartialWake")
			raiseHeads({ "Red" }, true)
			calmTimer = 0
			setState("Searching")
			return
		end
		if stage == "Disturbed" and os.clock() >= disturbedCooldownUntil and not eventBusy then
			beginDisturbedEvent()
		end
	end,
	Disturbed = function(_dt)
		if NoiseService.get() >= 100 then
			lockFullAwake()
		end
	end,
	PartialWake = function(dt)
		if NoiseService.get() >= 100 then
			lockFullAwake()
			return
		end
		setState("Searching")
		tickSearching(dt)
	end,
	Searching = function(dt)
		tickSearching(dt)
	end,
	FullAwake = function(_dt)
		setState("Hunting")
	end,
	Hunting = function(dt)
		tickHunting(dt)
	end,
}

function DragonService.getAiState(): AiState
	return aiState
end

function DragonService.init()
	if started then
		resolveDragon()
		return
	end
	started = true

	resolveDragon()
	DragonPerception.reset()
	aiState = "Sleeping"
	eventBusy = false
	calmTimer = 0

	NoiseService.onNoiseAdded(function(amount, source, position)
		if position then
			DragonPerception.pushHear(position, amount, source)
		end
	end)

	CollectionService:GetInstanceAddedSignal(Tags.Dragon):Connect(function()
		task.defer(resolveDragon)
	end)

	RunService.Heartbeat:Connect(function(dt)
		if not NoiseService.isMatchActive() then
			return
		end
		if not dragonModel then
			resolveDragon()
			if not dragonModel then
				return
			end
		end
		local handler = handlers[aiState]
		if handler then
			handler(dt)
		end
	end)

	fireState()
end

function DragonService.reset()
	aiState = "Sleeping"
	eventBusy = false
	calmTimer = 0
	huntAttackAcc = 0
	fireCd = 0
	smokeCd = 0
	acidCd = 0
	lastKnownPos = nil
	DragonPerception.reset()
	raiseHeads({ "Red", "Blue", "Green" }, false)
	fireState()
end

return DragonService
