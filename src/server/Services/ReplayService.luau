local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplayConfig = require(ReplicatedStorage.Shared.Config.ReplayConfig)
local ReplayTypes = require(ReplicatedStorage.Shared.Types.ReplayTypes)
local SeededRandom = require(ReplicatedStorage.Shared.Utils.SeededRandom)
local Remotes = require(script.Parent.Parent.Net.Remotes)

type CaveId = ReplayTypes.CaveId
type MatchMultipliers = ReplayTypes.MatchMultipliers
type ReplayStatePayload = ReplayTypes.ReplayStatePayload

local ReplayService = {}

local started = false
local caveByPlayer: { [Player]: CaveId } = {}
local dailyOptIn: { [Player]: boolean } = {}
local matchLocked = false
local activeSeed: number? = nil
local activeCaveId: CaveId = ReplayConfig.DefaultCaveId
local activeDailyOptIn = true
local activeMultipliers: MatchMultipliers? = nil

local function currentDailyCard()
	return ReplayConfig.dailyCardForUtcDay(SeededRandom.utcDayKey())
end

local function fireState(player: Player)
	local caveId = caveByPlayer[player] or ReplayConfig.DefaultCaveId
	local optIn = if dailyOptIn[player] == nil then true else dailyOptIn[player]
	local card = currentDailyCard()
	local payload: ReplayStatePayload = {
		CaveId = caveId,
		DailyOptIn = optIn,
		DailyCardId = card.Id,
		DailyCardName = card.DisplayName,
		DailyCardDescription = card.Description,
		MatchSeed = activeSeed,
	}
	Remotes.replayState():FireClient(player, payload)
	player:SetAttribute("CaveId", caveId)
	player:SetAttribute("DailyOptIn", optIn)
end

local function composeMultipliers(caveId: CaveId, optIn: boolean): MatchMultipliers
	local cave = ReplayConfig.getCave(caveId)
	local card = currentDailyCard()
	local lootMul = cave.LootValueMultiplier
	local noiseMul = cave.NoiseMultiplier
	local eventInterval = cave.EventIntervalSeconds
	if optIn then
		lootMul *= card.LootValueMultiplier
		noiseMul *= card.NoiseMultiplier
		eventInterval = eventInterval / math.max(card.EventRateMultiplier, 0.1)
	end
	return {
		LootValueMultiplier = lootMul,
		NoiseMultiplier = noiseMul,
		EventIntervalSeconds = eventInterval,
		RareRoomChance = cave.RareRoomChance,
		ArtifactChance = cave.ArtifactChance,
		RarityBias = cave.RarityBias,
		LootCount = cave.LootCount,
	}
end

function ReplayService.getMultipliers(): MatchMultipliers
	if activeMultipliers then
		return activeMultipliers
	end
	return composeMultipliers(ReplayConfig.DefaultCaveId, true)
end

function ReplayService.getMatchSeed(): number
	return activeSeed or 1
end

function ReplayService.getLootValueMultiplier(): number
	return ReplayService.getMultipliers().LootValueMultiplier
end

function ReplayService.getNoiseMultiplier(): number
	return ReplayService.getMultipliers().NoiseMultiplier
end

function ReplayService.setCave(player: Player, caveId: string): boolean
	if matchLocked or player:GetAttribute("GamePhase") == "Match" then
		return false
	end
	if not ReplayConfig.isValidCave(caveId) then
		return false
	end
	caveByPlayer[player] = caveId :: CaveId
	fireState(player)
	return true
end

function ReplayService.setDailyOptIn(player: Player, enabled: boolean): boolean
	if matchLocked or player:GetAttribute("GamePhase") == "Match" then
		return false
	end
	dailyOptIn[player] = enabled
	fireState(player)
	return true
end

function ReplayService.beginMatch(players: { Player }): (number, MatchMultipliers)
	matchLocked = true
	local host = players[1]
	activeCaveId = if host then (caveByPlayer[host] or ReplayConfig.DefaultCaveId) else ReplayConfig.DefaultCaveId
	activeDailyOptIn = if host then (if dailyOptIn[host] == nil then true else dailyOptIn[host]) else true

	local hash = 0
	for _, p in players do
		hash += p.UserId % 10007
	end
	activeSeed = os.time() * 1000 + hash
	activeMultipliers = composeMultipliers(activeCaveId, activeDailyOptIn)

	for _, p in players do
		fireState(p)
	end
	return activeSeed, activeMultipliers
end

function ReplayService.endMatch()
	matchLocked = false
	activeSeed = nil
	activeMultipliers = nil
	for _, p in Players:GetPlayers() do
		fireState(p)
	end
end

function ReplayService.init()
	if started then
		return
	end
	started = true

	Remotes.requestSetDifficulty().OnServerEvent:Connect(function(player: Player, caveId: unknown)
		if typeof(caveId) ~= "string" then
			return
		end
		ReplayService.setCave(player, caveId)
	end)

	Remotes.requestSetDailyOptIn().OnServerEvent:Connect(function(player: Player, enabled: unknown)
		if typeof(enabled) ~= "boolean" then
			return
		end
		ReplayService.setDailyOptIn(player, enabled)
	end)

	Players.PlayerAdded:Connect(function(player)
		caveByPlayer[player] = ReplayConfig.DefaultCaveId
		dailyOptIn[player] = true
		task.defer(function()
			fireState(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		caveByPlayer[player] = nil
		dailyOptIn[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		caveByPlayer[player] = ReplayConfig.DefaultCaveId
		dailyOptIn[player] = true
		fireState(player)
	end
end

return ReplayService
