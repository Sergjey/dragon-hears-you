local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ClassConfig = require(ReplicatedStorage.Shared.Config.ClassConfig)
local LootConfig = require(ReplicatedStorage.Shared.Config.LootConfig)
local Tags = require(ReplicatedStorage.Shared.Config.Tags)

local BackpackService = require(script.Parent.BackpackService)
local NoiseService = require(script.Parent.NoiseService)
local Remotes = require(script.Parent.Parent.Net.Remotes)

local LootService = {}

local started = false
local promptConnections: { [ProximityPrompt]: RBXScriptConnection } = {}
local claimed: { [Instance]: boolean } = {}

local function getCharacterRoot(player: Player): BasePart?
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

local function tryPickup(player: Player, lootInstance: Instance)
	if claimed[lootInstance] then
		return
	end
	if not lootInstance.Parent then
		return
	end

	local matchStatus = player:GetAttribute("MatchStatus")
	if matchStatus ~= nil and matchStatus ~= "Alive" then
		return
	end

	local lootId = lootInstance:GetAttribute("LootId")
	if typeof(lootId) ~= "string" then
		return
	end

	if not LootConfig.isBackpack(lootId) then
		-- Carry loot deferred to CarryService (Phase 3+)
		return
	end

	local root = getCharacterRoot(player)
	if not root then
		return
	end

	local lootPart: BasePart? = nil
	if lootInstance:IsA("BasePart") then
		lootPart = lootInstance
	else
		lootPart = lootInstance:FindFirstChildWhichIsA("BasePart")
	end
	if not lootPart then
		return
	end

	local distance = (root.Position - lootPart.Position).Magnitude
	if distance > GameConfig.LootPickupMaxDistance then
		return
	end

	local canAdd = BackpackService.canAdd(player, lootId)
	if not canAdd then
		return
	end

	claimed[lootInstance] = true
	local added = BackpackService.add(player, lootId)
	if not added then
		claimed[lootInstance] = nil
		return
	end

	local def = LootConfig.get(lootId)
	if def then
		NoiseService.add(def.PickupNoise, "LootPickup", lootPart.Position)
		Remotes.lootFx():FireClient(player, {
			UserId = player.UserId,
			LootId = def.Id,
			Rarity = def.Rarity,
			Value = def.Value,
			Position = lootPart.Position,
		})
	end

	local prompt = lootInstance:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		local conn = promptConnections[prompt]
		if conn then
			conn:Disconnect()
			promptConnections[prompt] = nil
		end
	end

	lootInstance:Destroy()
end

local function bindLoot(instance: Instance)
	local prompt = instance:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	if promptConnections[prompt] then
		return
	end

	promptConnections[prompt] = prompt.Triggered:Connect(function(player: Player)
		tryPickup(player, instance)
	end)

	prompt.PromptButtonHoldBegan:Connect(function(player: Player)
		local bonus = ClassConfig.get(player:GetAttribute("ClassId") :: any).LootPromptSpeedBonus
		local base = 0.35
		prompt.HoldDuration = base / (1 + math.max(bonus, 0))
	end)
end

function LootService.spawnDroppedLoot(lootId: string, position: Vector3): BasePart?
	local def = LootConfig.get(lootId)
	if not def or def.LootType ~= "Backpack" then
		return nil
	end

	local parent = game:GetService("Workspace"):FindFirstChild("GorynychDungeon")
	local lootFolder = if parent then parent:FindFirstChild("Loot") else nil
	if not lootFolder then
		lootFolder = game:GetService("Workspace")
	end

	local loot = Instance.new("Part")
	loot.Name = lootId
	loot.Size = Vector3.new(1.5, 1.5, 1.5)
	loot.CFrame = CFrame.new(position + Vector3.new(0, 2, 0))
	loot.Color = Color3.fromRGB(220, 180, 60)
	loot.Material = Enum.Material.Metal
	loot.Anchored = true
	loot.CanCollide = true
	loot.Parent = lootFolder
	loot:SetAttribute("LootId", lootId)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Steal"
	prompt.ObjectText = lootId
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = loot

	CollectionService:AddTag(loot, Tags.Loot)
	return loot
end

function LootService.init()
	if started then
		for _, instance in CollectionService:GetTagged(Tags.Loot) do
			bindLoot(instance)
		end
		return
	end
	started = true

	for _, instance in CollectionService:GetTagged(Tags.Loot) do
		bindLoot(instance)
	end

	CollectionService:GetInstanceAddedSignal(Tags.Loot):Connect(function(instance)
		task.defer(function()
			bindLoot(instance)
		end)
	end)

	CollectionService:GetInstanceRemovedSignal(Tags.Loot):Connect(function(instance)
		claimed[instance] = nil
		local prompt = instance:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			local conn = promptConnections[prompt]
			if conn then
				conn:Disconnect()
				promptConnections[prompt] = nil
			end
		end
	end)
end

return LootService
