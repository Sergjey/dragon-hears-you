local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ClassConfig = require(ReplicatedStorage.Shared.Config.ClassConfig)
local ClassTypes = require(ReplicatedStorage.Shared.Types.ClassTypes)
local Remotes = require(script.Parent.Parent.Net.Remotes)

local DamageService = require(script.Parent.DamageService)
local EconomyService = require(script.Parent.EconomyService)
local MovementModifierService = require(script.Parent.MovementModifierService)
local NoiseService = require(script.Parent.NoiseService)

type ClassId = ClassTypes.ClassId
type ClassStatePayload = ClassTypes.ClassStatePayload
type AbilityFxPayload = ClassTypes.AbilityFxPayload

local ClassService = {}

local CLASS_ATTR = "ClassId"
local SILENT_UNTIL_ATTR = "SilentStepUntil"
local SENSE_UNTIL_ATTR = "TreasureSenseUntil"
local SHIELD_ATTR = "ShieldCharges"

local started = false
local cooldownUntil: { [Player]: number } = {}
local matchLocked: { [Player]: boolean } = {}

local function now(): number
	return os.clock()
end

local function getClassId(player: Player): ClassId
	local id = player:GetAttribute(CLASS_ATTR)
	if ClassConfig.isValid(id) then
		return id :: ClassId
	end
	return ClassConfig.DefaultClassId
end

function ClassService.getClassId(player: Player): ClassId
	return getClassId(player)
end

function ClassService.getDefinition(player: Player)
	return ClassConfig.get(getClassId(player))
end

local function fireClassState(player: Player)
	local def = ClassService.getDefinition(player)
	local cdLeft = 0
	local untilT = cooldownUntil[player]
	if untilT then
		cdLeft = math.max(0, untilT - now())
	end
	local silentLeft = 0
	local silentUntil = player:GetAttribute(SILENT_UNTIL_ATTR)
	if typeof(silentUntil) == "number" then
		silentLeft = math.max(0, (silentUntil :: number) - now())
	end
	local senseLeft = 0
	local senseUntil = player:GetAttribute(SENSE_UNTIL_ATTR)
	if typeof(senseUntil) == "number" then
		senseLeft = math.max(0, (senseUntil :: number) - now())
	end
	local shield = player:GetAttribute(SHIELD_ATTR)
	local payload: ClassStatePayload = {
		ClassId = def.Id,
		AbilityId = def.AbilityId,
		AbilityName = def.AbilityName,
		CooldownRemaining = cdLeft,
		SilentStepRemaining = if silentLeft > 0 then silentLeft else nil,
		TreasureSenseRemaining = if senseLeft > 0 then senseLeft else nil,
		ShieldCharges = if typeof(shield) == "number" and shield > 0 then shield :: number else nil,
	}
	Remotes.classState():FireClient(player, payload)
end

function ClassService.broadcastClassState(player: Player?)
	if player then
		fireClassState(player)
		return
	end
	for _, p in Players:GetPlayers() do
		fireClassState(p)
	end
end

function ClassService.setClass(player: Player, classId: string): boolean
	if not ClassConfig.isValid(classId) then
		return false
	end
	if matchLocked[player] or player:GetAttribute("GamePhase") == "Match" then
		return false
	end
	if not EconomyService.isClassUnlocked(player, classId) then
		return false
	end
	player:SetAttribute(CLASS_ATTR, classId)
	cooldownUntil[player] = nil
	player:SetAttribute(SILENT_UNTIL_ATTR, nil)
	player:SetAttribute(SENSE_UNTIL_ATTR, nil)
	player:SetAttribute(SHIELD_ATTR, 0)
	fireClassState(player)
	return true
end

function ClassService.lockForMatch(player: Player)
	matchLocked[player] = true
	if not ClassConfig.isValid(player:GetAttribute(CLASS_ATTR)) then
		player:SetAttribute(CLASS_ATTR, ClassConfig.DefaultClassId)
	end
	DamageService.resetPlayer(player)
	MovementModifierService.applyForPlayer(player)
	fireClassState(player)
end

function ClassService.unlockAfterMatch(player: Player)
	matchLocked[player] = nil
	cooldownUntil[player] = nil
	player:SetAttribute(SILENT_UNTIL_ATTR, nil)
	player:SetAttribute(SENSE_UNTIL_ATTR, nil)
	player:SetAttribute(SHIELD_ATTR, 0)
	fireClassState(player)
end

function ClassService.absorbDamage(player: Player, amount: number): number
	-- DamageService consumes ShieldCharges; this hook only fires FX / state sync.
	fireClassState(player)
	Remotes.abilityFx():FireAllClients({
		UserId = player.UserId,
		AbilityId = "Shield",
	} :: AbilityFxPayload)
	return 0
end

local function canUseAbility(player: Player): boolean
	if player:GetAttribute("GamePhase") ~= "Match" then
		return false
	end
	local status = player:GetAttribute("MatchStatus")
	if status ~= nil and status ~= "Alive" then
		return false
	end
	local untilT = cooldownUntil[player]
	if untilT and untilT > now() then
		return false
	end
	return true
end

local function startCooldown(player: Player, seconds: number)
	cooldownUntil[player] = now() + seconds
	fireClassState(player)
end

local function useSilentStep(player: Player, def)
	local duration = def.AbilityDurationSeconds or 5
	player:SetAttribute(SILENT_UNTIL_ATTR, now() + duration)
	startCooldown(player, def.AbilityCooldownSeconds)
	Remotes.abilityFx():FireAllClients({
		UserId = player.UserId,
		AbilityId = def.AbilityId,
	} :: AbilityFxPayload)
end

local function useHeal(player: Player, def)
	local range = def.AbilityRange or 18
	local fraction = def.AbilityHealFraction or 0.4
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local best: Player = player
	local bestMissing = DamageService.getMaxHP(player) - DamageService.getHP(player)
	for _, other in Players:GetPlayers() do
		if other:GetAttribute("MatchStatus") ~= nil and other:GetAttribute("MatchStatus") ~= "Alive" then
			continue
		end
		local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if not otherRoot or not otherRoot:IsA("BasePart") then
			continue
		end
		if (otherRoot.Position - root.Position).Magnitude > range then
			continue
		end
		local missing = DamageService.getMaxHP(other) - DamageService.getHP(other)
		if missing > bestMissing then
			bestMissing = missing
			best = other
		end
	end

	local maxHp = DamageService.getMaxHP(best)
	local healAmount = math.floor(maxHp * fraction)
	DamageService.setHP(best, DamageService.getHP(best) + healAmount)
	startCooldown(player, def.AbilityCooldownSeconds)
	Remotes.abilityFx():FireAllClients({
		UserId = player.UserId,
		AbilityId = def.AbilityId,
		Position = root.Position,
	} :: AbilityFxPayload)
end

local function useShield(player: Player, def)
	player:SetAttribute(SHIELD_ATTR, 1)
	startCooldown(player, def.AbilityCooldownSeconds)
	Remotes.abilityFx():FireAllClients({
		UserId = player.UserId,
		AbilityId = def.AbilityId,
	} :: AbilityFxPayload)
end

local function useNoiseMaker(player: Player, def)
	local range = def.AbilityRange or 40
	local noise = def.AbilityNoise or 18
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local look = root.CFrame.LookVector
	local origin = root.Position + Vector3.new(0, 2, 0)
	local targetPos = origin + look * range

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = Workspace:Raycast(origin, look * range, params)
	if hit then
		targetPos = hit.Position
	end

	NoiseService.add(noise, "NoiseMaker", targetPos)

	local marker = Instance.new("Part")
	marker.Name = "NoiseMakerPing"
	marker.Shape = Enum.PartType.Ball
	marker.Size = Vector3.new(2, 2, 2)
	marker.Anchored = true
	marker.CanCollide = false
	marker.Material = Enum.Material.Neon
	marker.Color = Color3.fromRGB(232, 120, 48)
	marker.CFrame = CFrame.new(targetPos)
	marker.Parent = Workspace
	task.delay(2.5, function()
		if marker.Parent then
			marker:Destroy()
		end
	end)

	startCooldown(player, def.AbilityCooldownSeconds)
	Remotes.abilityFx():FireAllClients({
		UserId = player.UserId,
		AbilityId = def.AbilityId,
		Position = targetPos,
	} :: AbilityFxPayload)
end

local function useTreasureSense(player: Player, def)
	local duration = def.AbilityDurationSeconds or 5
	player:SetAttribute(SENSE_UNTIL_ATTR, now() + duration)
	startCooldown(player, def.AbilityCooldownSeconds)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	Remotes.abilityFx():FireAllClients({
		UserId = player.UserId,
		AbilityId = def.AbilityId,
		Position = if root and root:IsA("BasePart") then root.Position else nil,
	} :: AbilityFxPayload)
end

function ClassService.tryUseAbility(player: Player): boolean
	if not canUseAbility(player) then
		return false
	end
	local def = ClassService.getDefinition(player)
	if def.AbilityId == "SilentStep" then
		useSilentStep(player, def)
	elseif def.AbilityId == "Heal" then
		useHeal(player, def)
	elseif def.AbilityId == "Shield" then
		useShield(player, def)
	elseif def.AbilityId == "NoiseMaker" then
		useNoiseMaker(player, def)
	elseif def.AbilityId == "TreasureSense" then
		useTreasureSense(player, def)
	else
		return false
	end
	return true
end

function ClassService.init()
	if started then
		return
	end
	started = true

	DamageService.bindAbsorb(ClassService.absorbDamage)

	Remotes.requestSetClass().OnServerEvent:Connect(function(player: Player, classId: unknown)
		if typeof(classId) ~= "string" then
			return
		end
		ClassService.setClass(player, classId :: string)
	end)

	Remotes.requestUseAbility().OnServerEvent:Connect(function(player: Player)
		ClassService.tryUseAbility(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		if not ClassConfig.isValid(player:GetAttribute(CLASS_ATTR)) then
			player:SetAttribute(CLASS_ATTR, ClassConfig.DefaultClassId)
		end
		player:SetAttribute(SHIELD_ATTR, 0)
		task.defer(function()
			fireClassState(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		cooldownUntil[player] = nil
		matchLocked[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		if not ClassConfig.isValid(player:GetAttribute(CLASS_ATTR)) then
			player:SetAttribute(CLASS_ATTR, ClassConfig.DefaultClassId)
		end
		fireClassState(player)
	end

	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				if player:GetAttribute("GamePhase") == "Match" then
					fireClassState(player)
				end
			end
		end
	end)
end

return ClassService
