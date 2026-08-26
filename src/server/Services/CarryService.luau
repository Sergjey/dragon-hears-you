local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local LootConfig = require(ReplicatedStorage.Shared.Config.LootConfig)
local Tags = require(ReplicatedStorage.Shared.Config.Tags)
local CarryTypes = require(ReplicatedStorage.Shared.Types.CarryTypes)
local Remotes = require(script.Parent.Parent.Net.Remotes)

local NoiseService = require(script.Parent.NoiseService)
local ReplayService = require(script.Parent.ReplayService)

type CarryStatePayload = CarryTypes.CarryStatePayload

type CarrySession = {
	Instance: BasePart,
	LootId: string,
	Carriers: { Player },
	Waiting: boolean,
	Weld: WeldConstraint?,
	Prompt: ProximityPrompt?,
}

local CarryService = {}

local started = false
local sessionsByLoot: { [BasePart]: CarrySession } = {}
local sessionByPlayer: { [Player]: CarrySession } = {}
local promptConnections: { [ProximityPrompt]: RBXScriptConnection } = {}

local function getMovement()
	return require(script.Parent.MovementModifierService)
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function isAliveInMatch(player: Player): boolean
	if player:GetAttribute("GamePhase") ~= "Match" then
		return false
	end
	local status = player:GetAttribute("MatchStatus")
	return status == nil or status == "Alive"
end

local function requiredPlayers(lootId: string): number
	local def = LootConfig.get(lootId)
	return (def and def.RequiredPlayers) or 1
end

local function fireState(player: Player, payload: CarryStatePayload)
	Remotes.carryState():FireClient(player, payload)
end

local function clearState(player: Player)
	fireState(player, {
		Active = false,
		LootId = nil,
		DisplayName = nil,
		Waiting = false,
		RequiredPlayers = nil,
		CarrierCount = nil,
		CanDrop = false,
	})
end

local function broadcastSession(session: CarrySession)
	local required = requiredPlayers(session.LootId)
	local payload: CarryStatePayload = {
		Active = true,
		LootId = session.LootId,
		DisplayName = session.LootId,
		Waiting = session.Waiting,
		RequiredPlayers = required,
		CarrierCount = #session.Carriers,
		CanDrop = true,
	}
	for _, carrier in session.Carriers do
		fireState(carrier, payload)
	end
end

local function refreshPrompt(session: CarrySession)
	local prompt = session.Prompt or session.Instance:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	session.Prompt = prompt
	local required = requiredPlayers(session.LootId)
	if #session.Carriers >= required and not session.Waiting then
		prompt.Enabled = false
	else
		prompt.Enabled = true
		prompt.ActionText = if required > 1 then `Carry ({#session.Carriers}/{required})` else "Carry"
		prompt.ObjectText = session.LootId
	end
end

local function detachVisual(session: CarrySession)
	if session.Weld then
		session.Weld:Destroy()
		session.Weld = nil
	end
	session.Instance.Anchored = true
	session.Instance.CanCollide = true
	session.Instance.Massless = false
end

local function attachVisual(session: CarrySession)
	local primary = session.Carriers[1]
	local root = primary and getRoot(primary)
	if not root then
		return
	end
	detachVisual(session)
	session.Instance.Anchored = false
	session.Instance.CanCollide = false
	session.Instance.Massless = true
	session.Instance.CFrame = root.CFrame * CFrame.new(0, 2.4, -1.2)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = session.Instance
	weld.Parent = session.Instance
	session.Weld = weld
end

local function applyMoveToCarriers(session: CarrySession)
	local movement = getMovement()
	for _, carrier in session.Carriers do
		movement.applyForPlayer(carrier)
	end
end

function CarryService.isCarrying(player: Player): boolean
	return sessionByPlayer[player] ~= nil
end

function CarryService.abilitiesDisabled(player: Player): boolean
	local session = sessionByPlayer[player]
	if not session then
		return false
	end
	local def = LootConfig.get(session.LootId)
	return def ~= nil and def.DisableAbilitiesWhileCarrying == true
end

function CarryService.getCarrySpeedMultiplier(player: Player): number
	local session = sessionByPlayer[player]
	if not session then
		return 1
	end
	local def = LootConfig.get(session.LootId)
	return (def and def.CarrySpeedMultiplier) or 1
end

function CarryService.getCarryNoiseMultiplier(player: Player): number
	local session = sessionByPlayer[player]
	if not session then
		return 1
	end
	local def = LootConfig.get(session.LootId)
	return (def and def.NoiseMultiplier) or 1
end

function CarryService.canExtractWhileCarrying(player: Player, playerInZone: (Player) -> boolean): boolean
	local session = sessionByPlayer[player]
	if not session then
		return true
	end
	if session.Waiting then
		return false
	end
	local required = requiredPlayers(session.LootId)
	if #session.Carriers < required then
		return false
	end
	for _, carrier in session.Carriers do
		if not playerInZone(carrier) then
			return false
		end
	end
	return true
end

local function dropSession(session: CarrySession, reason: string?, addDropNoise: boolean)
	local lootPart = session.Instance
	local def = LootConfig.get(session.LootId)
	local carriers = table.clone(session.Carriers)

	sessionsByLoot[lootPart] = nil
	for _, carrier in carriers do
		sessionByPlayer[carrier] = nil
		clearState(carrier)
	end

	detachVisual(session)
	local dropPos = lootPart.Position
	local primaryRoot = carriers[1] and getRoot(carriers[1])
	if primaryRoot then
		dropPos = primaryRoot.Position + Vector3.new(0, 1.5, 0)
	end
	lootPart.CFrame = CFrame.new(dropPos)
	lootPart.Anchored = true
	lootPart.CanCollide = true

	session.Carriers = {}
	session.Waiting = false
	refreshPrompt(session)

	if addDropNoise and def and def.DropNoise then
		NoiseService.add(def.DropNoise, reason or "CarryDrop", dropPos)
	end

	for _, carrier in carriers do
		getMovement().applyForPlayer(carrier)
	end
end

function CarryService.dropForPlayer(player: Player, addDropNoise: boolean?)
	local session = sessionByPlayer[player]
	if not session then
		return
	end
	dropSession(session, "CarryDrop", if addDropNoise == nil then true else addDropNoise)
end

function CarryService.trySecureAtExtract(player: Player): (number, number)
	local session = sessionByPlayer[player]
	if not session or session.Waiting then
		return 0, 0
	end
	local required = requiredPlayers(session.LootId)
	if #session.Carriers < required then
		return 0, 0
	end

	local def = LootConfig.get(session.LootId)
	if not def then
		return 0, 0
	end

	local value = math.floor(def.Value * ReplayService.getLootValueMultiplier() + 0.5)
	local lootPart = session.Instance
	local carriers = table.clone(session.Carriers)

	sessionsByLoot[lootPart] = nil
	for _, carrier in carriers do
		sessionByPlayer[carrier] = nil
		clearState(carrier)
		getMovement().applyForPlayer(carrier)
	end

	if session.Weld then
		session.Weld:Destroy()
		session.Weld = nil
	end
	local prompt = session.Prompt or lootPart:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		local conn = promptConnections[prompt]
		if conn then
			conn:Disconnect()
			promptConnections[prompt] = nil
		end
	end
	lootPart:Destroy()

	return value, 1
end

local function ensureSession(lootPart: BasePart, lootId: string): CarrySession
	local existing = sessionsByLoot[lootPart]
	if existing then
		return existing
	end
	local session: CarrySession = {
		Instance = lootPart,
		LootId = lootId,
		Carriers = {},
		Waiting = false,
		Weld = nil,
		Prompt = lootPart:FindFirstChildOfClass("ProximityPrompt"),
	}
	sessionsByLoot[lootPart] = session
	return session
end

local function tryInteract(player: Player, lootInstance: Instance)
	if not isAliveInMatch(player) then
		return
	end
	if sessionByPlayer[player] then
		return
	end
	if not lootInstance:IsA("BasePart") then
		return
	end
	local lootPart = lootInstance :: BasePart
	if not CollectionService:HasTag(lootPart, Tags.CarryLoot) then
		return
	end
	local lootId = lootPart:GetAttribute("LootId")
	if typeof(lootId) ~= "string" or not LootConfig.isCarry(lootId) then
		return
	end

	local root = getRoot(player)
	if not root then
		return
	end
	if (root.Position - lootPart.Position).Magnitude > GameConfig.CarryInteractMaxDistance then
		return
	end

	local session = ensureSession(lootPart, lootId)
	local required = requiredPlayers(lootId)

	-- Already fully carried by others
	if #session.Carriers >= required and not session.Waiting then
		return
	end

	-- Join waiting / start carry
	if table.find(session.Carriers, player) then
		return
	end

	table.insert(session.Carriers, player)
	sessionByPlayer[player] = session

	if #session.Carriers >= required then
		session.Waiting = false
		attachVisual(session)
		refreshPrompt(session)
		local def = LootConfig.get(lootId)
		if def then
			NoiseService.add(def.PickupNoise, "CarryPickup", lootPart.Position)
			if def.OnStealNoise and #session.Carriers == 1 and required == 1 then
				NoiseService.add(def.OnStealNoise, "CarrySteal", lootPart.Position)
			end
		end
	else
		session.Waiting = true
		attachVisual(session)
		refreshPrompt(session)
		local def = LootConfig.get(lootId)
		if def then
			NoiseService.add(def.PickupNoise, "CarryPickup", lootPart.Position)
		end
	end

	broadcastSession(session)
	applyMoveToCarriers(session)
end

local function bindCarry(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local prompt = instance:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	if promptConnections[prompt] then
		return
	end

	local lootId = instance:GetAttribute("LootId")
	if typeof(lootId) == "string" then
		local required = requiredPlayers(lootId)
		prompt.ActionText = if required > 1 then `Carry (0/{required})` else "Carry"
		prompt.ObjectText = lootId
	end

	promptConnections[prompt] = prompt.Triggered:Connect(function(player: Player)
		tryInteract(player, instance)
	end)
end

function CarryService.init()
	if started then
		return
	end
	started = true

	for _, instance in CollectionService:GetTagged(Tags.CarryLoot) do
		bindCarry(instance)
	end
	CollectionService:GetInstanceAddedSignal(Tags.CarryLoot):Connect(bindCarry)
	CollectionService:GetInstanceRemovedSignal(Tags.CarryLoot):Connect(function(instance)
		if instance:IsA("BasePart") then
			local session = sessionsByLoot[instance]
			if session then
				dropSession(session, "CarryRemoved", false)
			end
		end
		local prompt = instance:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			local conn = promptConnections[prompt]
			if conn then
				conn:Disconnect()
				promptConnections[prompt] = nil
			end
		end
	end)

	Remotes.requestCarryInteract().OnServerEvent:Connect(function(player: Player, target: unknown)
		if typeof(target) ~= "Instance" then
			return
		end
		tryInteract(player, target :: Instance)
	end)

	Remotes.requestDropCarry().OnServerEvent:Connect(function(player: Player)
		if not isAliveInMatch(player) then
			return
		end
		CarryService.dropForPlayer(player, true)
	end)

	Players.PlayerRemoving:Connect(function(player)
		CarryService.dropForPlayer(player, true)
	end)

	RunService.Heartbeat:Connect(function()
		if not NoiseService.isMatchActive() then
			return
		end
		local maxDist = GameConfig.CarryMaxCarrierDistance
		for lootPart, session in sessionsByLoot do
			if not lootPart.Parent then
				continue
			end
			if #session.Carriers < 2 then
				-- Keep weld glued to primary while waiting or 1p
				if #session.Carriers == 1 and session.Weld == nil then
					attachVisual(session)
				end
				continue
			end
			local a = getRoot(session.Carriers[1])
			local b = getRoot(session.Carriers[2])
			if not a or not b then
				dropSession(session, "CarryDrop", true)
				continue
			end
			if (a.Position - b.Position).Magnitude > maxDist then
				dropSession(session, "CarrySeparate", true)
			end
		end
	end)
end

function CarryService.resetMatch()
	local parts = {}
	for part in sessionsByLoot do
		table.insert(parts, part)
	end
	for _, part in parts do
		local session = sessionsByLoot[part]
		if session then
			dropSession(session, "MatchReset", false)
		end
	end
end

return CarryService
