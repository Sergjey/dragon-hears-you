local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ReplayConfig = require(ReplicatedStorage.Shared.Config.ReplayConfig)
local ReplayTypes = require(ReplicatedStorage.Shared.Types.ReplayTypes)
local SeededRandom = require(ReplicatedStorage.Shared.Utils.SeededRandom)
local Remotes = require(script.Parent.Parent.Net.Remotes)

local DragonService = require(script.Parent.DragonService)
local NoiseService = require(script.Parent.NoiseService)
local ReplayService = require(script.Parent.ReplayService)

type MatchEventKind = ReplayTypes.MatchEventKind
type MatchEventPayload = ReplayTypes.MatchEventPayload

local EventService = {}

local started = false
local running = false
local accumulator = 0
local rng = SeededRandom.new(1)
local lastKindIndex = 0

local function broadcast(kind: MatchEventKind)
	local message = ReplayConfig.EventMessages[kind] or kind
	local payload: MatchEventPayload = {
		Kind = kind,
		Message = message,
	}
	Remotes.matchEvent():FireAllClients(payload)
end

local function pickKind(): MatchEventKind
	local kinds = ReplayConfig.EventKinds
	lastKindIndex = (lastKindIndex % #kinds) + 1
	-- Mix seeded pick with rotation so we get variety
	local idx = rng:NextInt(1, #kinds)
	if idx == lastKindIndex then
		idx = (idx % #kinds) + 1
	end
	lastKindIndex = idx
	return kinds[idx] :: MatchEventKind
end

local function fireEvent(kind: MatchEventKind)
	local amount = ReplayConfig.EventNoise[kind] or 5
	local center = Vector3.new(0, 4, 5)
	if kind == "BriefStir" then
		NoiseService.add(amount, "BriefStir", center)
		DragonService.briefStir()
	elseif kind == "TrapClick" then
		NoiseService.add(amount, "TrapClick", Vector3.new(rng:NextInt(-20, 20), 3, rng:NextInt(-30, 30)))
	elseif kind == "FootfallEcho" then
		NoiseService.add(amount, "FootfallEcho", Vector3.new(rng:NextInt(-18, 18), 3, rng:NextInt(-40, 40)))
	else
		NoiseService.add(amount, "NoiseSpike", center)
	end
	broadcast(kind)
end

function EventService.start(matchSeed: number)
	EventService.stop()
	running = true
	accumulator = 0
	rng = SeededRandom.new(matchSeed + 917)
	lastKindIndex = 0
end

function EventService.stop()
	running = false
	accumulator = 0
end

function EventService.init()
	if started then
		return
	end
	started = true

	RunService.Heartbeat:Connect(function(dt)
		if not running or not NoiseService.isMatchActive() then
			return
		end
		local interval = ReplayService.getMultipliers().EventIntervalSeconds
		accumulator += dt
		if accumulator < interval then
			return
		end
		accumulator = 0
		-- Only fire if at least one Alive player
		local anyAlive = false
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("MatchStatus") == "Alive" then
				anyAlive = true
				break
			end
		end
		if not anyAlive then
			return
		end
		fireEvent(pickKind())
	end)
end

return EventService
