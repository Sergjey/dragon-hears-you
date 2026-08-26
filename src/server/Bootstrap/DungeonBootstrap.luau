local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FeedbackConfig = require(ReplicatedStorage.Shared.Config.FeedbackConfig)
local LootConfig = require(ReplicatedStorage.Shared.Config.LootConfig)
local ReplayConfig = require(ReplicatedStorage.Shared.Config.ReplayConfig)
local Tags = require(ReplicatedStorage.Shared.Config.Tags)
local ReplayTypes = require(ReplicatedStorage.Shared.Types.ReplayTypes)
local SeededRandom = require(ReplicatedStorage.Shared.Utils.SeededRandom)

type MatchMultipliers = ReplayTypes.MatchMultipliers

local DungeonBootstrap = {}

local FOLDER_NAME = "GorynychDungeon"

local function part(props: {
	Name: string,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Material: Enum.Material?,
	Anchored: boolean?,
	CanCollide: boolean?,
	Transparency: number?,
	Parent: Instance,
}): Part
	local p = Instance.new("Part")
	p.Name = props.Name
	p.Size = props.Size
	p.CFrame = props.CFrame
	p.Color = props.Color
	p.Material = props.Material or Enum.Material.Slate
	p.Anchored = if props.Anchored == nil then true else props.Anchored
	p.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	p.Transparency = props.Transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = props.Parent
	return p
end

local function spawnLoot(parent: Instance, lootId: string, position: Vector3)
	local def = LootConfig.get(lootId)
	local color = ReplayConfig.LootColors[lootId]
		or (def and FeedbackConfig.rarityColor(def.Rarity))
		or Color3.fromRGB(200, 180, 80)
	local size = ReplayConfig.LootSizes[lootId] or Vector3.new(1.5, 1.5, 1.5)
	local loot = part({
		Name = lootId,
		Size = size,
		CFrame = CFrame.new(position),
		Color = color,
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	loot:SetAttribute("LootId", lootId)
	if def then
		loot:SetAttribute("Rarity", def.Rarity)
	end

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

local function pickWeightedLoot(rng: SeededRandom.Rng, rarityBias: number): string
	local weights = ReplayConfig.getLootWeights()
	local total = 0
	local adjusted = {}
	for i, entry in weights do
		local w = entry.Weight * (1 + (i - 1) * 0.15 * math.max(rarityBias - 1, 0))
		adjusted[i] = w
		total += w
	end
	local roll = rng:Next() * total
	local acc = 0
	for i, entry in weights do
		acc += adjusted[i]
		if roll <= acc then
			return entry.Id
		end
	end
	return weights[#weights].Id
end

local function buildShell(root: Folder)
	part({
		Name = "Floor",
		Size = Vector3.new(60, 2, 120),
		CFrame = CFrame.new(0, 0, 0),
		Color = Color3.fromRGB(40, 32, 28),
		Material = Enum.Material.Rock,
		Parent = root,
	})
	part({
		Name = "WallLeft",
		Size = Vector3.new(2, 20, 120),
		CFrame = CFrame.new(-31, 10, 0),
		Color = Color3.fromRGB(28, 22, 18),
		Parent = root,
	})
	part({
		Name = "WallRight",
		Size = Vector3.new(2, 20, 120),
		CFrame = CFrame.new(31, 10, 0),
		Color = Color3.fromRGB(28, 22, 18),
		Parent = root,
	})
	part({
		Name = "Ceiling",
		Size = Vector3.new(60, 2, 120),
		CFrame = CFrame.new(0, 21, 0),
		Color = Color3.fromRGB(22, 18, 16),
		Transparency = 0.3,
		Parent = root,
	})

	local spawnPad = part({
		Name = "SpawnPad",
		Size = Vector3.new(16, 1, 16),
		CFrame = CFrame.new(0, 1.5, -50),
		Color = Color3.fromRGB(70, 55, 40),
		Material = Enum.Material.Basalt,
		Parent = root,
	})
	spawnPad:SetAttribute("IsSpawn", true)

	for i, offset in
		{ Vector3.new(-18, 6, -20), Vector3.new(18, 6, -15), Vector3.new(-14, 6, 10), Vector3.new(16, 6, 25) }
	do
		local pillar = part({
			Name = "Pillar" .. i,
			Size = Vector3.new(6, 12, 6),
			CFrame = CFrame.new(offset),
			Color = Color3.fromRGB(55, 48, 42),
			Material = Enum.Material.Limestone,
			Parent = root,
		})
		CollectionService:AddTag(pillar, Tags.HideSpot)
	end

	part({
		Name = "TreasurePile",
		Size = Vector3.new(28, 4, 28),
		CFrame = CFrame.new(0, 3, 5),
		Color = Color3.fromRGB(180, 140, 40),
		Material = Enum.Material.Foil,
		Parent = root,
	})

	local dragon = Instance.new("Model")
	dragon.Name = "GorynychPlaceholder"
	dragon.Parent = root
	local body = part({
		Name = "Body",
		Size = Vector3.new(18, 8, 22),
		CFrame = CFrame.new(0, 9, 8),
		Color = Color3.fromRGB(60, 90, 55),
		Material = Enum.Material.Granite,
		Parent = dragon,
	})
	dragon.PrimaryPart = body
	local headColors = {
		Color3.fromRGB(160, 50, 40),
		Color3.fromRGB(50, 90, 160),
		Color3.fromRGB(70, 140, 60),
	}
	for i, headColor in headColors do
		local x = (i - 2) * 7
		part({
			Name = "Head" .. i,
			Size = Vector3.new(6, 5, 8),
			CFrame = CFrame.new(x, 14, -2),
			Color = headColor,
			Material = Enum.Material.SmoothPlastic,
			Parent = dragon,
		})
	end
	CollectionService:AddTag(dragon, Tags.Dragon)

	local extract = part({
		Name = "ExtractionZone",
		Size = Vector3.new(18, 1, 14),
		CFrame = CFrame.new(0, 1.5, 48),
		Color = Color3.fromRGB(40, 120, 80),
		Material = Enum.Material.Neon,
		Parent = root,
	})
	extract.Transparency = 0.35
	CollectionService:AddTag(extract, Tags.ExtractionZone)

	part({
		Name = "ExtractionBeacon",
		Size = Vector3.new(2, 10, 2),
		CFrame = CFrame.new(0, 6, 48),
		Color = Color3.fromRGB(60, 220, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.2,
		Parent = root,
	})
end

local function buildRareRoom(root: Folder, lootFolder: Folder, rng: SeededRandom.Rng)
	local origin = ReplayConfig.RareRoomOrigin
	local chamber = Instance.new("Folder")
	chamber.Name = "RareRoom"
	chamber.Parent = root

	part({
		Name = "RareFloor",
		Size = Vector3.new(24, 2, 24),
		CFrame = CFrame.new(origin + Vector3.new(0, 0, 0)),
		Color = Color3.fromRGB(50, 36, 28),
		Material = Enum.Material.Rock,
		Parent = chamber,
	})
	part({
		Name = "RareWallN",
		Size = Vector3.new(24, 14, 2),
		CFrame = CFrame.new(origin + Vector3.new(0, 7, -12)),
		Color = Color3.fromRGB(32, 24, 20),
		Parent = chamber,
	})
	part({
		Name = "RareWallS",
		Size = Vector3.new(24, 14, 2),
		CFrame = CFrame.new(origin + Vector3.new(0, 7, 12)),
		Color = Color3.fromRGB(32, 24, 20),
		Parent = chamber,
	})
	part({
		Name = "RareWallE",
		Size = Vector3.new(2, 14, 24),
		CFrame = CFrame.new(origin + Vector3.new(12, 7, 0)),
		Color = Color3.fromRGB(32, 24, 20),
		Parent = chamber,
	})
	-- Opening toward main hall (west)
	part({
		Name = "RareDoorwayPad",
		Size = Vector3.new(8, 1, 6),
		CFrame = CFrame.new(origin + Vector3.new(-16, 1.5, 0)),
		Color = Color3.fromRGB(90, 60, 40),
		Material = Enum.Material.Basalt,
		Parent = chamber,
	})

	local trap = part({
		Name = "NoiseTrap",
		Size = Vector3.new(6, 0.4, 6),
		CFrame = CFrame.new(origin + Vector3.new(0, 1.4, 0)),
		Color = Color3.fromRGB(120, 40, 40),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.4,
		Parent = chamber,
	})
	CollectionService:AddTag(trap, Tags.NoiseTrap)
	trap:SetAttribute("TrapNoise", 12)

	spawnLoot(lootFolder, "GoldenSword", origin + Vector3.new(-4, 3, 4))
	spawnLoot(lootFolder, "Jewel", origin + Vector3.new(5, 2.8, -3))
	if rng:Chance(0.7) then
		spawnLoot(lootFolder, "RoyalCrown", origin + Vector3.new(0, 3.5, 0))
	end
end

function DungeonBootstrap.build(seed: number?, multipliers: MatchMultipliers?): Folder
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = FOLDER_NAME
	root.Parent = Workspace

	buildShell(root)

	local lootFolder = Instance.new("Folder")
	lootFolder.Name = "Loot"
	lootFolder.Parent = root

	local mul = multipliers
		or {
			LootValueMultiplier = 1,
			NoiseMultiplier = 1,
			EventIntervalSeconds = 28,
			RareRoomChance = 0.35,
			ArtifactChance = 0.2,
			RarityBias = 1,
			LootCount = 6,
		}
	local rng = SeededRandom.new(seed or os.time())
	root:SetAttribute("MatchSeed", seed or 0)

	local slots = ReplayConfig.LootSlotPositions
	local count = math.clamp(mul.LootCount, 3, #slots)
	-- Shuffle indices via seeded Fisher-Yates
	local order = {}
	for i = 1, #slots do
		order[i] = i
	end
	for i = #order, 2, -1 do
		local j = rng:NextInt(1, i)
		order[i], order[j] = order[j], order[i]
	end

	for n = 1, count do
		local slot = slots[order[n]]
		local lootId = pickWeightedLoot(rng, mul.RarityBias)
		spawnLoot(lootFolder, lootId, slot)
	end

	if rng:Chance(mul.ArtifactChance) then
		spawnLoot(lootFolder, ReplayConfig.ArtifactLootId, Vector3.new(0, 6.5, 5))
	end

	if rng:Chance(mul.RareRoomChance) then
		buildRareRoom(root, lootFolder, rng)
	end

	return root
end

function DungeonBootstrap.getSpawnCFrame(): CFrame
	local dungeon = Workspace:FindFirstChild(FOLDER_NAME)
	if dungeon then
		local pad = dungeon:FindFirstChild("SpawnPad")
		if pad and pad:IsA("BasePart") then
			return pad.CFrame + Vector3.new(0, 4, 0)
		end
	end
	return CFrame.new(0, 6, -50)
end

return DungeonBootstrap
