local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LobbyConfig = require(ReplicatedStorage.Shared.Config.LobbyConfig)
local Tags = require(ReplicatedStorage.Shared.Config.Tags)
local LobbyTypes = require(ReplicatedStorage.Shared.Types.LobbyTypes)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local LobbyBootstrap = require(script.Parent.Parent.Bootstrap.LobbyBootstrap)

local MatchTeleport = require(script.Parent.MatchTeleport)

type LobbyPadEntry = LobbyTypes.LobbyPadEntry
type LobbyPadStatePayload = LobbyTypes.LobbyPadStatePayload

local LobbyService = {}

type PadRuntime = {
	Part: BasePart,
	PadId: string,
	DisplayName: string,
	Capacity: number,
	Occupants: { Player },
	Countdown: number?,
	Locked: boolean,
}

local pads: { PadRuntime } = {}
local playerPad: { [Player]: string } = {}
local started = false
local phase = "Lobby"
local launching = false

local function playerInPad(player: Player, padPart: BasePart): boolean
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local relative = padPart.CFrame:PointToObjectSpace(root.Position)
	local half = padPart.Size / 2
	return math.abs(relative.X) <= half.X
		and math.abs(relative.Z) <= half.Z
		and relative.Y >= -2
		and relative.Y <= half.Y + 8
end

local function updatePadBillboard(pad: PadRuntime)
	local gui = pad.Part:FindFirstChild("PadLabel")
	local title = gui and gui:FindFirstChild("Title")
	if title and title:IsA("TextLabel") then
		local countText = string.format("%s  %d / %d", pad.DisplayName, #pad.Occupants, pad.Capacity)
		if pad.Countdown then
			countText ..= string.format("  ·  %ds", math.ceil(pad.Countdown))
		end
		if pad.Locked then
			countText ..= "  ·  GO"
		end
		title.Text = countText
	end
end

local function broadcast()
	local entries: { LobbyPadEntry } = {}
	for _, pad in pads do
		local names = {}
		for _, occupant in pad.Occupants do
			table.insert(names, occupant.DisplayName)
		end
		table.insert(entries, {
			PadId = pad.PadId,
			DisplayName = pad.DisplayName,
			Capacity = pad.Capacity,
			Occupied = #pad.Occupants,
			Countdown = pad.Countdown,
			Locked = pad.Locked,
			OccupantNames = names,
		})
		updatePadBillboard(pad)
	end
	local payload: LobbyPadStatePayload = {
		Pads = entries,
		Phase = phase,
	}
	Remotes.lobbyPadState():FireAllClients(payload)
end

local function clearOccupant(player: Player)
	local padId = playerPad[player]
	if not padId then
		return
	end
	playerPad[player] = nil
	for _, pad in pads do
		if pad.PadId == padId then
			local idx = table.find(pad.Occupants, player)
			if idx then
				table.remove(pad.Occupants, idx)
			end
			if #pad.Occupants == 0 then
				pad.Countdown = nil
			end
			break
		end
	end
end

local function tryAssign(player: Player, pad: PadRuntime): boolean
	if phase ~= "Lobby" or launching or pad.Locked then
		return false
	end
	if playerPad[player] == pad.PadId then
		return true
	end
	-- One pad at a time
	if playerPad[player] then
		clearOccupant(player)
	end
	if #pad.Occupants >= pad.Capacity then
		return false
	end
	table.insert(pad.Occupants, player)
	playerPad[player] = pad.PadId
	if pad.Countdown == nil and #pad.Occupants > 0 then
		pad.Countdown = LobbyConfig.CountdownSeconds
	end
	return true
end

local function launchPad(pad: PadRuntime)
	if launching or pad.Locked or #pad.Occupants == 0 then
		return
	end
	launching = true
	pad.Locked = true
	pad.Countdown = 0
	phase = "Match"
	broadcast()

	local party = table.clone(pad.Occupants)
	-- Clear other pads
	for _, other in pads do
		if other ~= pad then
			other.Occupants = {}
			other.Countdown = nil
			other.Locked = true
		end
	end
	for _, player in party do
		playerPad[player] = nil
	end

	MatchTeleport.startParty(party, pad.Capacity)
end

local function refreshPadsFromTags()
	table.clear(pads)
	for _, instance in CollectionService:GetTagged(Tags.TeleportPad) do
		if instance:IsA("BasePart") then
			local padId = instance:GetAttribute("PadId")
			local capacity = instance:GetAttribute("PartySize")
			local displayName = instance:GetAttribute("DisplayName")
			if typeof(padId) == "string" and typeof(capacity) == "number" then
				table.insert(pads, {
					Part = instance,
					PadId = padId,
					DisplayName = if typeof(displayName) == "string" then displayName else padId,
					Capacity = capacity,
					Occupants = {},
					Countdown = nil,
					Locked = false,
				})
			end
		end
	end
end

function LobbyService.setPhase(nextPhase: string)
	phase = nextPhase
	broadcast()
end

function LobbyService.resumeLobby()
	launching = false
	phase = "Lobby"
	playerPad = {}
	for _, pad in pads do
		pad.Occupants = {}
		pad.Countdown = nil
		pad.Locked = false
	end
	broadcast()
end

function LobbyService.teleportPlayersToLobbySpawn(players: { Player })
	local cf = LobbyBootstrap.getSpawnCFrame()
	for _, player in players do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.CFrame = cf
		end
		player:SetAttribute("MatchStatus", nil)
		player:SetAttribute("GamePhase", "Lobby")
	end
end

function LobbyService.init()
	if started then
		return
	end
	started = true

	Remotes.init()
	LobbyBootstrap.build()
	refreshPadsFromTags()
	phase = "Lobby"

	CollectionService:GetInstanceAddedSignal(Tags.TeleportPad):Connect(function()
		task.defer(function()
			if phase == "Lobby" and not launching then
				refreshPadsFromTags()
				broadcast()
			end
		end)
	end)

	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("GamePhase", "Lobby")
		task.defer(function()
			local character = player.Character or player.CharacterAdded:Wait()
			local root = character:WaitForChild("HumanoidRootPart", 8)
			if root and root:IsA("BasePart") then
				root.CFrame = LobbyBootstrap.getSpawnCFrame()
			end
			broadcast()
		end)
		player.CharacterAdded:Connect(function(character)
			if phase == "Lobby" then
				task.defer(function()
					local root = character:WaitForChild("HumanoidRootPart", 8)
					if root and root:IsA("BasePart") then
						root.CFrame = LobbyBootstrap.getSpawnCFrame()
					end
				end)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		clearOccupant(player)
		broadcast()
	end)

	for _, player in Players:GetPlayers() do
		player:SetAttribute("GamePhase", "Lobby")
		task.defer(function()
			local character = player.Character
			if character then
				local root = character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					root.CFrame = LobbyBootstrap.getSpawnCFrame()
				end
			end
		end)
	end

	RunService.Heartbeat:Connect(function(dt)
		if phase ~= "Lobby" or launching then
			return
		end

		for _, player in Players:GetPlayers() do
			local onAny = false
			for _, pad in pads do
				if playerInPad(player, pad.Part) then
					onAny = true
					tryAssign(player, pad)
					break
				end
			end
			if not onAny and playerPad[player] then
				clearOccupant(player)
			end
		end

		for _, pad in pads do
			if pad.Locked then
				continue
			end
			if #pad.Occupants == 0 then
				pad.Countdown = nil
				continue
			end
			-- Early start when full
			if #pad.Occupants >= pad.Capacity then
				launchPad(pad)
				return
			end
			if pad.Countdown then
				pad.Countdown -= dt
				if pad.Countdown <= 0 then
					launchPad(pad)
					return
				end
			end
		end

		broadcast()
	end)

	broadcast()
	print("[Gorynych] Phase 4 lobby ready (Solo/Duo/Squad pads)")
end

return LobbyService
