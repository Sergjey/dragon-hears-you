local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MultiplayerConfig = require(ReplicatedStorage.Shared.Config.MultiplayerConfig)
local Tags = require(ReplicatedStorage.Shared.Config.Tags)
local MatchTypes = require(ReplicatedStorage.Shared.Types.MatchTypes)
local Remotes = require(script.Parent.Parent.Net.Remotes)

local BackpackService = require(script.Parent.BackpackService)
local CarryService = require(script.Parent.CarryService)
local NoiseService = require(script.Parent.NoiseService)

type ExtractionStatePayload = MatchTypes.ExtractionStatePayload
type MatchResultPayload = MatchTypes.MatchResultPayload

local ExtractionService = {}

type ExtractSession = {
	Elapsed: number,
	Active: boolean,
	Completed: boolean,
}

local sessions: { [Player]: ExtractSession } = {}
local zones: { BasePart } = {}
local started = false

local canExtract: ((Player) -> boolean)? = nil
local onExtracted: ((Player, number, number) -> ())? = nil

function ExtractionService.bindCanExtract(fn: (Player) -> boolean)
	canExtract = fn
end

function ExtractionService.bindOnExtracted(fn: (Player, number, number) -> ())
	onExtracted = fn
end

local function fireExtraction(player: Player, payload: ExtractionStatePayload)
	Remotes.extractionState():FireClient(player, payload)
end

local function fireResult(player: Player, securedValue: number, itemCount: number)
	local payload: MatchResultPayload = {
		SecuredValue = securedValue,
		ItemCount = itemCount,
	}
	Remotes.matchResult():FireClient(player, payload)
end

local function playerInAnyZone(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	for _, zone in zones do
		if zone.Parent then
			local relative = zone.CFrame:PointToObjectSpace(root.Position)
			local half = zone.Size / 2
			if
				math.abs(relative.X) <= half.X
				and math.abs(relative.Z) <= half.Z
				and relative.Y >= -2
				and relative.Y <= half.Y + 6
			then
				return true
			end
		end
	end
	return false
end

local function refreshZones()
	table.clear(zones)
	for _, instance in CollectionService:GetTagged(Tags.ExtractionZone) do
		if instance:IsA("BasePart") then
			table.insert(zones, instance)
		end
	end
end

function ExtractionService.cancel(player: Player, reason: string?)
	local session = sessions[player]
	if not session or not session.Active or session.Completed then
		return
	end
	session.Active = false
	session.Elapsed = 0
	fireExtraction(player, {
		Active = false,
		Progress = 0,
		Cancelled = true,
		Success = false,
	})
	local _ = reason
end

function ExtractionService.cancelOnDamage(player: Player)
	ExtractionService.cancel(player, "Damage")
end

local function complete(player: Player)
	local session = sessions[player]
	if not session or session.Completed then
		return
	end
	session.Completed = true
	session.Active = false

	local securedValue, itemCount = BackpackService.clear(player)
	local carryValue, carryCount = CarryService.trySecureAtExtract(player)
	securedValue += carryValue
	itemCount += carryCount

	fireExtraction(player, {
		Active = false,
		Progress = 1,
		Cancelled = false,
		Success = true,
	})
	fireResult(player, securedValue, itemCount)
	NoiseService.broadcastMatchState(player)

	if onExtracted then
		onExtracted(player, securedValue, itemCount)
	end

	-- Park as spectator until match ends
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if humanoid then
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
		end
		if root and root:IsA("BasePart") then
			root.CFrame = CFrame.new(MultiplayerConfig.SpectatorSpawnOffset)
		end
	end
end

function ExtractionService.init()
	if started then
		return
	end
	started = true

	refreshZones()
	CollectionService:GetInstanceAddedSignal(Tags.ExtractionZone):Connect(function()
		refreshZones()
	end)
	CollectionService:GetInstanceRemovedSignal(Tags.ExtractionZone):Connect(function()
		refreshZones()
	end)

	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)

	RunService.Heartbeat:Connect(function(dt)
		if not NoiseService.isMatchActive() then
			return
		end

		for _, player in Players:GetPlayers() do
			local session = sessions[player]
			if not session then
				session = { Elapsed = 0, Active = false, Completed = false }
				sessions[player] = session
			end
			if session.Completed then
				continue
			end

			if canExtract and not canExtract(player) then
				if session.Active then
					ExtractionService.cancel(player, "NotEligible")
				end
				continue
			end

			local inside = playerInAnyZone(player)
			if inside then
				if not CarryService.canExtractWhileCarrying(player, playerInAnyZone) then
					if session.Active then
						ExtractionService.cancel(player, "CarryPartnersRequired")
					end
					continue
				end
				if not session.Active then
					session.Active = true
					session.Elapsed = 0
				end
				session.Elapsed += dt
				local progress = math.clamp(session.Elapsed / GameConfig.ExtractionDurationSeconds, 0, 1)
				fireExtraction(player, {
					Active = true,
					Progress = progress,
					Cancelled = false,
					Success = false,
				})
				if session.Elapsed >= GameConfig.ExtractionDurationSeconds then
					complete(player)
				end
			elseif session.Active then
				ExtractionService.cancel(player, "LeftZone")
			end
		end
	end)
end

function ExtractionService.resetPlayer(player: Player)
	sessions[player] = { Elapsed = 0, Active = false, Completed = false }
end

function ExtractionService.refreshZones()
	refreshZones()
end

return ExtractionService
