local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DragonConfig = require(ReplicatedStorage.Shared.Config.DragonConfig)
local Tags = require(ReplicatedStorage.Shared.Config.Tags)
local DragonTypes = require(ReplicatedStorage.Shared.Types.DragonTypes)

type NoiseHearEvent = DragonTypes.NoiseHearEvent

local DragonPerception = {}

local hearEvents: { NoiseHearEvent } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

function DragonPerception.pushHear(position: Vector3, strength: number, source: string)
	if strength < DragonConfig.HearMinStrength then
		return
	end
	table.insert(hearEvents, {
		Position = position,
		Strength = strength,
		Source = source,
		At = os.clock(),
	})
	-- Cap memory
	while #hearEvents > 24 do
		table.remove(hearEvents, 1)
	end
end

function DragonPerception.prune()
	local cutoff = os.clock() - DragonConfig.HearMemorySeconds
	local kept = {}
	for _, ev in hearEvents do
		if ev.At >= cutoff then
			table.insert(kept, ev)
		end
	end
	hearEvents = kept
end

function DragonPerception.getLoudestRecent(): NoiseHearEvent?
	DragonPerception.prune()
	local best: NoiseHearEvent? = nil
	for _, ev in hearEvents do
		if best == nil or ev.Strength > best.Strength then
			best = ev
		end
	end
	return best
end

local function excludeList(dragon: Model): { Instance }
	local list: { Instance } = { dragon }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

function DragonPerception.hasLineOfSight(fromPos: Vector3, toPos: Vector3, dragon: Model): boolean
	rayParams.FilterDescendantsInstances = excludeList(dragon)
	local dir = toPos - fromPos
	local result = Workspace:Raycast(fromPos, dir, rayParams)
	if not result then
		return true
	end
	-- Hit something before the target — blocked (pillars / hide spots / walls)
	local hit = result.Instance
	if CollectionService:HasTag(hit, Tags.HideSpot) then
		return false
	end
	-- Allow if we nearly reached the player (within 3 studs of target)
	return (result.Position - toPos).Magnitude < 3
end

function DragonPerception.canSeePlayer(head: BasePart, player: Player, dragon: Model): boolean
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	local origin = head.Position
	local offset = root.Position - origin
	local dist = offset.Magnitude
	if dist > DragonConfig.VisionRange or dist < 0.5 then
		return false
	end

	local look = head.CFrame.LookVector
	local cosLimit = math.cos(math.rad(DragonConfig.VisionHalfAngleDeg))
	if look:Dot(offset.Unit) < cosLimit then
		return false
	end

	return DragonPerception.hasLineOfSight(origin, root.Position, dragon)
end

function DragonPerception.findVisiblePlayer(head: BasePart, dragon: Model): Player?
	for _, player in Players:GetPlayers() do
		if DragonPerception.canSeePlayer(head, player, dragon) then
			return player
		end
	end
	return nil
end

function DragonPerception.reset()
	hearEvents = {}
end

return DragonPerception
