local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local NoiseConfig = require(ReplicatedStorage.Shared.Config.NoiseConfig)
local MatchTypes = require(ReplicatedStorage.Shared.Types.MatchTypes)
local Remotes = require(script.Parent.Parent.Net.Remotes)

local BackpackService = require(script.Parent.BackpackService)

type DragonStage = MatchTypes.DragonStage
type MatchStatePayload = MatchTypes.MatchStatePayload

local NoiseService = {}

local noise = 0
local decayAccumulator = 0
local matchActive = false
local fullAwakeLocked = false
local heartbeatConn: RBXScriptConnection? = nil
local noiseListeners: { (amount: number, source: string, position: Vector3?) -> () } = {}

local function stageFromNoise(value: number): DragonStage
	if fullAwakeLocked then
		return "FullAwake"
	end
	local t = GameConfig.StageThresholds
	if value > t.PartialWake then
		return "FullAwake"
	elseif value > t.Disturbed then
		return "PartialWake"
	elseif value > t.Sleeping then
		return "Disturbed"
	end
	return "Sleeping"
end

local function clampNoise(value: number): number
	return math.clamp(value, NoiseConfig.Min, NoiseConfig.Max)
end

local function payloadFor(player: Player): MatchStatePayload
	local state = BackpackService.get(player)
	return {
		Noise = noise,
		MaxNoise = NoiseConfig.Max,
		BagUsed = state.UsedWeight,
		BagCapacity = state.Capacity,
		BagValue = state.TotalValue,
		Stage = stageFromNoise(noise),
		MatchActive = matchActive,
	}
end

function NoiseService.get(): number
	return noise
end

function NoiseService.getStage(): DragonStage
	return stageFromNoise(noise)
end

function NoiseService.isFullAwakeLocked(): boolean
	return fullAwakeLocked
end

function NoiseService.setFullAwakeLocked(locked: boolean)
	fullAwakeLocked = locked
	NoiseService.broadcastMatchState()
end

function NoiseService.isMatchActive(): boolean
	return matchActive
end

function NoiseService.onNoiseAdded(listener: (amount: number, source: string, position: Vector3?) -> ())
	table.insert(noiseListeners, listener)
end

function NoiseService.broadcastMatchState(player: Player?)
	local remote = Remotes.matchState()
	if player then
		remote:FireClient(player, payloadFor(player))
		return
	end
	for _, p in Players:GetPlayers() do
		remote:FireClient(p, payloadFor(p))
	end
end

function NoiseService.add(amount: number, source: string, position: Vector3?)
	if not matchActive or amount == 0 then
		return
	end
	noise = clampNoise(noise + amount)
	decayAccumulator = 0
	for _, listener in noiseListeners do
		listener(amount, source, position)
	end
	NoiseService.broadcastMatchState()
end

function NoiseService.set(value: number)
	noise = clampNoise(value)
	NoiseService.broadcastMatchState()
end

function NoiseService.startMatch()
	matchActive = true
	noise = 0
	decayAccumulator = 0
	fullAwakeLocked = false
	NoiseService.broadcastMatchState()
end

function NoiseService.endMatch()
	matchActive = false
	NoiseService.broadcastMatchState()
end

function NoiseService.reset()
	noise = 0
	decayAccumulator = 0
	fullAwakeLocked = false
	NoiseService.broadcastMatchState()
end

function NoiseService.init()
	if heartbeatConn then
		return
	end

	heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		if not matchActive then
			return
		end
		-- While Fully Awake, noise still can rise but decay is slower (keep pressure)
		local decayMul = if fullAwakeLocked then 0.35 else 1
		decayAccumulator += dt * decayMul
		while decayAccumulator >= NoiseConfig.DecayIntervalSeconds do
			decayAccumulator -= NoiseConfig.DecayIntervalSeconds
			if noise > NoiseConfig.Min then
				noise = clampNoise(noise - NoiseConfig.DecayAmount)
				NoiseService.broadcastMatchState()
			end
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			NoiseService.broadcastMatchState(player)
		end)
	end)
end

return NoiseService
