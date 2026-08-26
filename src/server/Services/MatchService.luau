local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MultiplayerConfig = require(ReplicatedStorage.Shared.Config.MultiplayerConfig)
local MultiplayerTypes = require(ReplicatedStorage.Shared.Types.MultiplayerTypes)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local DungeonBootstrap = require(script.Parent.Parent.Bootstrap.DungeonBootstrap)

local BackpackService = require(script.Parent.BackpackService)
local ClassService = require(script.Parent.ClassService)
local DamageService = require(script.Parent.DamageService)
local DownedService = require(script.Parent.DownedService)
local DragonService = require(script.Parent.DragonService)
local ExtractionService = require(script.Parent.ExtractionService)
local LootService = require(script.Parent.LootService)
local MatchTeleport = require(script.Parent.MatchTeleport)
local MovementModifierService = require(script.Parent.MovementModifierService)
local NoiseService = require(script.Parent.NoiseService)

type PlayerMatchStatus = MultiplayerTypes.PlayerMatchStatus
type RosterEntry = MultiplayerTypes.RosterEntry
type RosterStatePayload = MultiplayerTypes.RosterStatePayload
type MatchEndedPayload = MultiplayerTypes.MatchEndedPayload

local MatchService = {}

local prepared = false
local matchRunning = false
local matchEnded = false
local outcome = "Ongoing"
local status: { [Player]: PlayerMatchStatus } = {}
local securedValue: { [Player]: number } = {}
local securedItems: { [Player]: number } = {}
local lastPositions: { [Player]: Vector3 } = {}
local partyMembers: { [Player]: boolean } = {}
local characterConns: { [Player]: RBXScriptConnection } = {}

local function teleportToSpawn(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.CFrame = DungeonBootstrap.getSpawnCFrame()
	end
end

local function setStatus(player: Player, nextStatus: PlayerMatchStatus)
	status[player] = nextStatus
	player:SetAttribute("MatchStatus", nextStatus)
end

function MatchService.getStatus(player: Player): PlayerMatchStatus
	return status[player] or "Alive"
end

function MatchService.isAlive(player: Player): boolean
	return partyMembers[player] == true and MatchService.getStatus(player) == "Alive"
end

function MatchService.isMatchRunning(): boolean
	return matchRunning and not matchEnded
end

local function broadcastRoster()
	local entries: { RosterEntry } = {}
	for player in partyMembers do
		if player.Parent then
			local st = status[player] or "Alive"
			table.insert(entries, {
				UserId = player.UserId,
				Name = player.DisplayName,
				Status = st,
				HP = DamageService.getHP(player),
				MaxHP = DamageService.getMaxHP(player),
				BleedoutRemaining = if st == "Downed" then DownedService.getBleedoutRemaining(player) else nil,
			})
		end
	end
	local payload: RosterStatePayload = {
		Entries = entries,
		MatchEnded = matchEnded,
		Outcome = outcome,
	}
	Remotes.rosterState():FireAllClients(payload)
end

local function collectPartyPlayers(): { Player }
	local list = {}
	for player in partyMembers do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function endMatch(finalOutcome: string)
	if matchEnded or not matchRunning then
		return
	end
	matchEnded = true
	outcome = finalOutcome
	NoiseService.endMatch()
	DragonService.reset()
	broadcastRoster()

	local party = collectPartyPlayers()
	for _, player in party do
		local extracted = status[player] == "Extracted"
		local payload: MatchEndedPayload = {
			Outcome = finalOutcome,
			SecuredValue = securedValue[player] or 0,
			ItemCount = securedItems[player] or 0,
			Extracted = extracted,
		}
		Remotes.matchEnded():FireClient(player, payload)
		if not extracted then
			Remotes.matchResult():FireClient(player, {
				SecuredValue = securedValue[player] or 0,
				ItemCount = securedItems[player] or 0,
			})
		end
		player:SetAttribute("GamePhase", "Lobby")
	end

	task.delay(2.5, function()
		MatchTeleport.returnPartyToLobby(party)
	end)
end

local function checkMatchEnd()
	if matchEnded or not matchRunning then
		return
	end

	local anyActive = false
	local anyExtracted = false
	local anyDead = false
	local anyMember = false
	for player in partyMembers do
		if not player.Parent then
			continue
		end
		anyMember = true
		local st = status[player] or "Alive"
		if st == "Alive" or st == "Downed" then
			anyActive = true
		elseif st == "Extracted" then
			anyExtracted = true
		elseif st == "Dead" then
			anyDead = true
		end
	end

	if not anyMember then
		endMatch("TeamWipe")
		return
	end
	if anyActive then
		return
	end
	if anyExtracted then
		endMatch("Complete")
	elseif anyDead then
		endMatch("TeamWipe")
	end
end

function MatchService.setExtracted(player: Player, value: number, itemCount: number)
	if matchEnded or not partyMembers[player] then
		return
	end
	setStatus(player, "Extracted")
	securedValue[player] = value
	securedItems[player] = itemCount
	DownedService.clear(player)
	broadcastRoster()
	checkMatchEnd()
end

local function registerPlayer(player: Player)
	setStatus(player, "Alive")
	securedValue[player] = 0
	securedItems[player] = 0
	DamageService.resetPlayer(player)
	ExtractionService.resetPlayer(player)
	DownedService.clear(player)
	player:SetAttribute("GamePhase", "Match")
	broadcastRoster()
end

local function onCharacter(player: Player, character: Model)
	if not partyMembers[player] or not matchRunning then
		return
	end
	task.defer(function()
		local root = character:WaitForChild("HumanoidRootPart", 8)
		if root and root:IsA("BasePart") then
			local st = status[player]
			if st == "Dead" or st == "Extracted" then
				root.CFrame = CFrame.new(MultiplayerConfig.SpectatorSpawnOffset)
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.WalkSpeed = 0
					humanoid.JumpPower = 0
				end
			else
				teleportToSpawn(player)
			end
			lastPositions[player] = root.Position
		end
		MovementModifierService.applyForPlayer(player)
		NoiseService.broadcastMatchState(player)
		broadcastRoster()
	end)

	task.spawn(function()
		while character.Parent and player.Parent and partyMembers[player] do
			local root = character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				lastPositions[player] = root.Position
			end
			task.wait(0.5)
		end
	end)
end

local function bindDropRemote()
	Remotes.requestDropLoot().OnServerEvent:Connect(function(player: Player, mode: unknown)
		if typeof(mode) ~= "string" or mode ~= "All" then
			return
		end
		if not MatchService.isAlive(player) then
			return
		end
		local items = BackpackService.dropAll(player)
		if #items > 0 then
			local character = player.Character
			local pos: Vector3? = nil
			if character then
				local root = character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					pos = root.Position
				end
			end
			NoiseService.add(2, "DropLoot", pos)
			MovementModifierService.applyForPlayer(player)
			broadcastRoster()
		end
	end)
end

local function handleLeave(player: Player)
	if not partyMembers[player] then
		return
	end
	local st = status[player]
	if st == "Alive" or st == "Downed" then
		local pos = lastPositions[player]
		if pos then
			DamageService.dropLootAtPosition(player, pos)
		else
			DamageService.dropLootAt(player)
		end
	end
	DownedService.clear(player)
	status[player] = nil
	securedValue[player] = nil
	securedItems[player] = nil
	lastPositions[player] = nil
	partyMembers[player] = nil
	if characterConns[player] then
		characterConns[player]:Disconnect()
		characterConns[player] = nil
	end
	broadcastRoster()
	task.defer(checkMatchEnd)
end

local function hookPartyPlayer(player: Player)
	partyMembers[player] = true
	registerPlayer(player)
	if characterConns[player] then
		characterConns[player]:Disconnect()
	end
	characterConns[player] = player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		onCharacter(player, player.Character)
	else
		task.defer(function()
			teleportToSpawn(player)
		end)
	end
end

local function installStudioDebug()
	if not game:GetService("RunService"):IsStudio() then
		return
	end
	local ServerStorage = game:GetService("ServerStorage")
	local debugFolder = ServerStorage:FindFirstChild("GorynychDebug")
	if not debugFolder then
		debugFolder = Instance.new("Folder")
		debugFolder.Name = "GorynychDebug"
		debugFolder.Parent = ServerStorage
	end

	local function ensureFn(name: string, onInvoke: (...any) -> any)
		local existing = debugFolder:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
		local fn = Instance.new("BindableFunction")
		fn.Name = name
		fn.Parent = debugFolder
		fn.OnInvoke = onInvoke
	end

	ensureFn("ApplyDamage", function(userId: number, amount: number)
		local target = Players:GetPlayerByUserId(userId)
		if not target then
			return "NoPlayer"
		end
		DamageService.applyDamage(target, amount, "Debug")
		return {
			Status = target:GetAttribute("MatchStatus"),
			Downed = DownedService.isDowned(target),
			Bleedout = DownedService.getBleedoutRemaining(target),
			MatchActive = NoiseService.isMatchActive(),
			HP = DamageService.getHP(target),
		}
	end)

	ensureFn("ForceExtract", function(userId: number, value: number, items: number)
		local target = Players:GetPlayerByUserId(userId)
		if not target then
			return "NoPlayer"
		end
		MatchService.setExtracted(target, value, items)
		return {
			Status = target:GetAttribute("MatchStatus"),
			MatchActive = NoiseService.isMatchActive(),
		}
	end)

	ensureFn("ForceBleedout", function(userId: number)
		local target = Players:GetPlayerByUserId(userId)
		if not target then
			return "NoPlayer"
		end
		local ok = DownedService.debugExpireBleedout(target)
		task.wait(0.15)
		return {
			Ok = ok,
			Status = target:GetAttribute("MatchStatus"),
			MatchActive = NoiseService.isMatchActive(),
			Downed = DownedService.isDowned(target),
		}
	end)

	ensureFn("AddNoise", function(amount: number)
		NoiseService.add(amount, "Debug", Vector3.new(0, 5, 0))
		return { MatchActive = NoiseService.isMatchActive() }
	end)

	ensureFn("BeginSoloMatch", function(userId: number)
		local target = Players:GetPlayerByUserId(userId)
		if not target then
			return "NoPlayer"
		end
		MatchService.beginFromLobby({ target }, 1)
		return { Running = MatchService.isMatchRunning() }
	end)
end

function MatchService.teardownMatch()
	for _, player in Players:GetPlayers() do
		DownedService.clear(player)
		ClassService.unlockAfterMatch(player)
	end
	matchRunning = false
	matchEnded = false
	outcome = "Ongoing"
	table.clear(status)
	table.clear(securedValue)
	table.clear(securedItems)
	table.clear(lastPositions)
	table.clear(partyMembers)
	for player, conn in characterConns do
		conn:Disconnect()
		characterConns[player] = nil
	end
	local dungeon = Workspace:FindFirstChild("GorynychDungeon")
	if dungeon then
		dungeon:Destroy()
	end
	if NoiseService.isMatchActive() then
		NoiseService.endMatch()
	end
end

function MatchService.beginFromLobby(players: { Player }, partySize: number)
	if matchRunning and not matchEnded then
		warn("[Gorynych] Match already running")
		return
	end
	if #players == 0 then
		return
	end
	if #players > partySize or partySize > MultiplayerConfig.MaxPlayersInMatch then
		warn(`[Gorynych] Invalid party {#players}/{partySize}`)
		return
	end

	MatchService.teardownMatch()
	matchRunning = true
	matchEnded = false
	outcome = "Ongoing"

	DungeonBootstrap.build()
	ExtractionService.refreshZones()
	LootService.init()
	DragonService.init()
	DragonService.reset()
	NoiseService.startMatch()

	for _, player in players do
		ClassService.lockForMatch(player)
		hookPartyPlayer(player)
		teleportToSpawn(player)
	end
	broadcastRoster()
	print(`[Gorynych] Match started for party of {#players} (cap {partySize})`)
end

function MatchService.beginFromTeleportJoin()
	MatchService.prepare()
	task.defer(function()
		task.wait(1)
		local players = Players:GetPlayers()
		local partySize = MultiplayerConfig.MaxPlayersInMatch
		local first = players[1]
		if first then
			local data = MatchTeleport.readJoinPartyData(first)
			if data then
				partySize = data.PartySize
				local allowed: { [number]: boolean } = {}
				for _, id in data.MemberUserIds do
					allowed[id] = true
				end
				local filtered = {}
				for _, player in players do
					if allowed[player.UserId] then
						table.insert(filtered, player)
					end
				end
				if #filtered > 0 then
					players = filtered
				end
			end
		end
		MatchService.beginFromLobby(players, math.clamp(partySize, 1, MultiplayerConfig.MaxPlayersInMatch))
	end)
end

function MatchService.prepare()
	if prepared then
		return
	end
	prepared = true

	Remotes.init()
	NoiseService.init()
	BackpackService.init()
	MovementModifierService.init()
	ExtractionService.init()
	DownedService.init()
	DamageService.init()
	ClassService.init()
	bindDropRemote()

	DamageService.bindCanTakeDamage(function(player)
		return MatchService.isAlive(player)
	end)

	DownedService.bindMatchCallbacks({
		OnDowned = function(player)
			setStatus(player, "Downed")
			broadcastRoster()
		end,
		OnRevived = function(player)
			setStatus(player, "Alive")
			broadcastRoster()
		end,
		OnBleedoutDead = function(player)
			setStatus(player, "Dead")
			broadcastRoster()
			task.delay(1, function()
				if player.Parent and status[player] == "Dead" then
					player:LoadCharacter()
				end
			end)
			checkMatchEnd()
		end,
		CanRevive = function(player)
			return MatchService.isAlive(player)
		end,
		IsMatchActive = function()
			return NoiseService.isMatchActive() and not matchEnded and matchRunning
		end,
	})

	ExtractionService.bindCanExtract(function(player)
		return MatchService.isAlive(player) and not DownedService.isDowned(player)
	end)
	ExtractionService.bindOnExtracted(function(player, value, itemCount)
		MatchService.setExtracted(player, value, itemCount)
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			if NoiseService.isMatchActive() and not matchEnded and matchRunning then
				broadcastRoster()
			end
		end
	end)

	Players.PlayerRemoving:Connect(handleLeave)
	installStudioDebug()
end

-- Legacy always-on (tests / no lobby): start when players present
function MatchService.init()
	MatchService.prepare()
	local players = Players:GetPlayers()
	if #players > 0 then
		MatchService.beginFromLobby(players, math.min(#players, MultiplayerConfig.MaxPlayersInMatch))
	else
		Players.PlayerAdded:Once(function(player)
			MatchService.beginFromLobby({ player }, 1)
		end)
	end
end

return MatchService
