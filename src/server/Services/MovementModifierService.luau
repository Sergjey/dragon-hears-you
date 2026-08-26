local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local NoiseConfig = require(ReplicatedStorage.Shared.Config.NoiseConfig)

local BackpackService = require(script.Parent.BackpackService)
local NoiseService = require(script.Parent.NoiseService)

local MovementModifierService = {}

type PlayerMoveState = {
	WasJumping: boolean,
	LastY: number?,
	FootstepAcc: number,
}

local states: { [Player]: PlayerMoveState } = {}
local freezeUntil: { [Player]: number } = {}
local slowUntil: { [Player]: { Until: number, Multiplier: number } } = {}
local heartbeatConn: RBXScriptConnection? = nil

local function getTier(fillRatio: number): { SpeedMultiplier: number, FootstepNoiseMultiplier: number }
	local tiers = GameConfig.BagFillTiers
	for _, tier in tiers do
		if fillRatio <= tier.MaxFill then
			return tier
		end
	end
	return tiers[#tiers]
end

local function ensureState(player: Player): PlayerMoveState
	local state = states[player]
	if not state then
		state = {
			WasJumping = false,
			LastY = nil,
			FootstepAcc = 0,
		}
		states[player] = state
	end
	return state
end

function MovementModifierService.applyForPlayer(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local matchStatus = player:GetAttribute("MatchStatus")
	if matchStatus == "Downed" or matchStatus == "Dead" or matchStatus == "Extracted" then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		return
	end

	local now = os.clock()
	if freezeUntil[player] and freezeUntil[player] > now then
		humanoid.WalkSpeed = 0
		return
	end

	local fill = BackpackService.getFillRatio(player)
	local tier = getTier(fill)
	local speed = GameConfig.DefaultWalkSpeed * tier.SpeedMultiplier
	local slow = slowUntil[player]
	if slow and slow.Until > now then
		speed *= slow.Multiplier
	end
	humanoid.WalkSpeed = speed
	humanoid.JumpPower = 50
end

function MovementModifierService.freeze(player: Player, duration: number)
	freezeUntil[player] = os.clock() + duration
	MovementModifierService.applyForPlayer(player)
end

function MovementModifierService.applySlow(player: Player, duration: number, multiplier: number)
	slowUntil[player] = { Until = os.clock() + duration, Multiplier = multiplier }
	MovementModifierService.applyForPlayer(player)
end

function MovementModifierService.getFootstepMultiplier(player: Player): number
	return getTier(BackpackService.getFillRatio(player)).FootstepNoiseMultiplier
end

local function samplePlayer(player: Player, dt: number)
	if not NoiseService.isMatchActive() then
		return
	end

	local matchStatus = player:GetAttribute("MatchStatus")
	if matchStatus == "Downed" or matchStatus == "Dead" or matchStatus == "Extracted" then
		return
	end

	local now = os.clock()
	if freezeUntil[player] and freezeUntil[player] <= now then
		freezeUntil[player] = nil
		MovementModifierService.applyForPlayer(player)
	end
	if slowUntil[player] and slowUntil[player].Until <= now then
		slowUntil[player] = nil
		MovementModifierService.applyForPlayer(player)
	end

	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end

	if freezeUntil[player] and freezeUntil[player] > now then
		return
	end

	local state = ensureState(player)
	local footMul = MovementModifierService.getFootstepMultiplier(player)

	-- Jump noise on rising edge of Jump state
	local isJumping = humanoid:GetState() == Enum.HumanoidStateType.Jumping
	if isJumping and not state.WasJumping then
		NoiseService.add(NoiseConfig.JumpNoise * footMul, "Jump", root.Position)
	end
	state.WasJumping = isJumping

	-- Fall noise when landing after vertical drop
	local y = root.Position.Y
	if state.LastY ~= nil then
		local falling = humanoid:GetState() == Enum.HumanoidStateType.Freefall
		if not falling and state.LastY - y > 3 then
			local drop = state.LastY - y
			local t = math.clamp(drop / NoiseConfig.FallStudsForMax, 0, 1)
			local fallNoise = NoiseConfig.FallNoiseMin + (NoiseConfig.FallNoiseMax - NoiseConfig.FallNoiseMin) * t
			NoiseService.add(fallNoise * footMul, "Fall", root.Position)
		end
	end
	if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		-- keep LastY as peak while falling
		if state.LastY == nil or y > state.LastY then
			state.LastY = y
		end
	elseif humanoid.FloorMaterial ~= Enum.Material.Air then
		state.LastY = y
	end

	-- Continuous walk/run noise
	local moving = humanoid.MoveDirection.Magnitude > 0.1 and humanoid.FloorMaterial ~= Enum.Material.Air
	if moving then
		local speed = root.AssemblyLinearVelocity.Magnitude
		local rate = if speed >= NoiseConfig.RunSpeedThreshold
			then NoiseConfig.RunNoisePerSecond
			else NoiseConfig.WalkNoisePerSecond
		state.FootstepAcc += rate * footMul * dt
		if state.FootstepAcc >= 0.1 then
			local chunk = state.FootstepAcc
			state.FootstepAcc = 0
			NoiseService.add(chunk, "Footstep", root.Position)
		end
	end
end

function MovementModifierService.init()
	BackpackService.onChanged(function(player)
		MovementModifierService.applyForPlayer(player)
		-- Refresh HUD bag numbers for this player's bag via NoiseService broadcast
		NoiseService.broadcastMatchState()
	end)

	local function hookCharacter(player: Player, character: Model)
		ensureState(player)
		task.defer(function()
			MovementModifierService.applyForPlayer(player)
		end)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				-- Future: drop loot on death; Phase 1 clears nothing special yet
			end)
		end
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			hookCharacter(player, character)
		end)
		if player.Character then
			hookCharacter(player, player.Character)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		freezeUntil[player] = nil
		slowUntil[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(character)
			hookCharacter(player, character)
		end)
		if player.Character then
			hookCharacter(player, player.Character)
		end
	end

	if not heartbeatConn then
		heartbeatConn = RunService.Heartbeat:Connect(function(dt)
			for _, player in Players:GetPlayers() do
				samplePlayer(player, dt)
			end
		end)
	end
end

return MovementModifierService
