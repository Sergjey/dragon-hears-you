local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragonConfig = require(ReplicatedStorage.Shared.Config.DragonConfig)
local MultiplayerConfig = require(ReplicatedStorage.Shared.Config.MultiplayerConfig)
local MultiplayerTypes = require(ReplicatedStorage.Shared.Types.MultiplayerTypes)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local DungeonBootstrap = require(script.Parent.Parent.Bootstrap.DungeonBootstrap)

local BackpackService = require(script.Parent.BackpackService)
local DamageService = require(script.Parent.DamageService)
local DownedService = require(script.Parent.DownedService)
local DragonService = require(script.Parent.DragonService)
local ExtractionService = require(script.Parent.ExtractionService)
local LootService = require(script.Parent.LootService)
local MovementModifierService = require(script.Parent.MovementModifierService)
local NoiseService = require(script.Parent.NoiseService)

type PlayerMatchStatus = MultiplayerTypes.PlayerMatchStatus
type RosterEntry = MultiplayerTypes.RosterEntry
type RosterStatePayload = MultiplayerTypes.RosterStatePayload
type MatchEndedPayload = MultiplayerTypes.MatchEndedPayload

local MatchService = {}

local started = false
local matchEnded = false
local outcome = "Ongoing"
local status: { [Player]: PlayerMatchStatus } = {}
local securedValue: { [Player]: number } = {}
local securedItems: { [Player]: number } = {}
local lastPositions: { [Player]: Vector3 } = {}

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
	return MatchService.getStatus(player) == "Alive"
end

local function broadcastRoster()
	local entries: { RosterEntry } = {}
	for _, player in Players:GetPlayers() do
		local st = status[player] or "Alive"
		table.insert(entries, {
			UserId = player.UserId,
			Name = player.DisplayName,
			Status = st,
			HP = DamageService.getHP(player),
			MaxHP = DragonConfig.MaxPlayerHP,
			BleedoutRemaining = if st == "Downed" then DownedService.getBleedoutRemaining(player) else nil,
		})
	end
	local payload: RosterStatePayload = {
		Entries = entries,
		MatchEnded = matchEnded,
		Outcome = outcome,
	}
	Remotes.rosterState():FireAllClients(payload)
end

local function endMatch(finalOutcome: string)
	if matchEnded then
		return
	end
	matchEnded = true
	outcome = finalOutcome
	NoiseService.endMatch()
	DragonService.reset()
	broadcastRoster()

	for _, player in Players:GetPlayers() do
		local extracted = status[player] == "Extracted"
		local payload: MatchEndedPayload = {
			Outcome = finalOutcome,
			SecuredValue = securedValue[player] or 0,
			ItemCount = securedItems[player] or 0,
			Extracted = extracted,
		}
		Remotes.matchEnded():FireClient(player, payload)
		-- Also fire classic result for extractors who already saw it; others get summary
		if not extracted then
			Remotes.matchResult():FireClient(player, {
				SecuredValue = securedValue[player] or 0,
				ItemCount = securedItems[player] or 0,
			})
		end
	end
end

local function checkMatchEnd()
	if matchEnded then
		return
	end
	local players = Players:GetPlayers()
	if #players == 0 then
		return
	end

	local anyActive = false
	local anyExtracted = false
	local anyDead = false
	for _, player in players do
		local st = status[player] or "Alive"
		if st == "Alive" or st == "Downed" then
			anyActive = true
		elseif st == "Extracted" then
			anyExtracted = true
		elseif st == "Dead" then
			anyDead = true
		end
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
	if matchEnded then
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
	local count = #Players:GetPlayers()
	if count > MultiplayerConfig.MaxPlayersInMatch then
		warn(`[Gorynych] Match soft-cap {MultiplayerConfig.MaxPlayersInMatch} exceeded ({count})`)
	end
	setStatus(player, "Alive")
	securedValue[player] = 0
	securedItems[player] = 0
	DamageService.resetPlayer(player)
	ExtractionService.resetPlayer(player)
	DownedService.clear(player)
	broadcastRoster()
end

local function onCharacter(player: Player, character: Model)
	task.defer(function()
		local root = character:WaitForChild("HumanoidRootPart", 8)
		if root and root:IsA("BasePart") then
			local st = status[player]
			if st == "Dead" or st == "Extracted" then
				-- Spectator: park near spawn, freeze
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

	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid and humanoid:IsA("Humanoid") then
		-- Track position for leave drops
		task.spawn(function()
			while character.Parent and player.Parent do
				local root = character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					lastPositions[player] = root.Position
				end
				task.wait(0.5)
			end
		end)
	end
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
	broadcastRoster()
	task.defer(checkMatchEnd)
end

function MatchService.init()
	if started then
		return
	end

	Remotes.init()
	NoiseService.init()
	NoiseService.startMatch()
	BackpackService.init()
	MovementModifierService.init()
	ExtractionService.init()
	DownedService.init()
	DamageService.init()
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
			-- Respawn as spectator corpse cleared
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
			return NoiseService.isMatchActive() and not matchEnded
		end,
	})

	ExtractionService.bindCanExtract(function(player)
		return MatchService.isAlive(player) and not DownedService.isDowned(player)
	end)
	ExtractionService.bindOnExtracted(function(player, value, itemCount)
		MatchService.setExtracted(player, value, itemCount)
	end)

	DungeonBootstrap.build()
	ExtractionService.refreshZones()
	LootService.init()
	DragonService.init()
	DragonService.reset()
	matchEnded = false
	outcome = "Ongoing"

	-- Roster heartbeat for bleedout remaining UI
	task.spawn(function()
		while true do
			task.wait(0.5)
			if NoiseService.isMatchActive() and not matchEnded then
				broadcastRoster()
			end
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		registerPlayer(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
		task.defer(function()
			NoiseService.broadcastMatchState(player)
			broadcastRoster()
		end)
	end)

	Players.PlayerRemoving:Connect(handleLeave)

	for _, player in Players:GetPlayers() do
		registerPlayer(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
	end
	broadcastRoster()
	started = true

	if game:GetService("RunService"):IsStudio() then
		local ServerStorage = game:GetService("ServerStorage")
		local debugFolder = ServerStorage:FindFirstChild("GorynychDebug")
		if not debugFolder then
			debugFolder = Instance.new("Folder")
			debugFolder.Name = "GorynychDebug"
			debugFolder.Parent = ServerStorage
		end
		local existing = debugFolder:FindFirstChild("ApplyDamage")
		if existing then
			existing:Destroy()
		end
		local applyDamageFn = Instance.new("BindableFunction")
		applyDamageFn.Name = "ApplyDamage"
		applyDamageFn.Parent = debugFolder
		applyDamageFn.OnInvoke = function(userId: number, amount: number)
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
		end

		local existingExtract = debugFolder:FindFirstChild("ForceExtract")
		if existingExtract then
			existingExtract:Destroy()
		end
		local extractFn = Instance.new("BindableFunction")
		extractFn.Name = "ForceExtract"
		extractFn.Parent = debugFolder
		extractFn.OnInvoke = function(userId: number, value: number, items: number)
			local target = Players:GetPlayerByUserId(userId)
			if not target then
				return "NoPlayer"
			end
			MatchService.setExtracted(target, value, items)
			return {
				Status = target:GetAttribute("MatchStatus"),
				MatchActive = NoiseService.isMatchActive(),
			}
		end

		local existingBleed = debugFolder:FindFirstChild("ForceBleedout")
		if existingBleed then
			existingBleed:Destroy()
		end
		local bleedFn = Instance.new("BindableFunction")
		bleedFn.Name = "ForceBleedout"
		bleedFn.Parent = debugFolder
		bleedFn.OnInvoke = function(userId: number)
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
		end

		local existingNoise = debugFolder:FindFirstChild("AddNoise")
		if existingNoise then
			existingNoise:Destroy()
		end
		local noiseFn = Instance.new("BindableFunction")
		noiseFn.Name = "AddNoise"
		noiseFn.Parent = debugFolder
		noiseFn.OnInvoke = function(amount: number)
			NoiseService.add(amount, "Debug", Vector3.new(0, 5, 0))
			return {
				MatchActive = NoiseService.isMatchActive(),
			}
		end
	end

	print("[Gorynych] Phase 3 match started (Downed/Revive + roster)")
end

return MatchService
