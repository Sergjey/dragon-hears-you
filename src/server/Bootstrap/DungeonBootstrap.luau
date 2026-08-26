local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tags = require(ReplicatedStorage.Shared.Config.Tags)

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

local function spawnLoot(parent: Instance, lootId: string, position: Vector3, color: Color3, size: Vector3)
	local loot = part({
		Name = lootId,
		Size = size,
		CFrame = CFrame.new(position),
		Color = color,
		Material = Enum.Material.Metal,
		Parent = parent,
	})
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

function DungeonBootstrap.build(): Folder
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = FOLDER_NAME
	root.Parent = Workspace

	-- Floor: ~120 studs long cave (entrance → dragon → extraction)
	part({
		Name = "Floor",
		Size = Vector3.new(60, 2, 120),
		CFrame = CFrame.new(0, 0, 0),
		Color = Color3.fromRGB(40, 32, 28),
		Material = Enum.Material.Rock,
		Parent = root,
	})

	-- Side walls
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

	-- Spawn / entrance at -Z
	local spawnPad = part({
		Name = "SpawnPad",
		Size = Vector3.new(16, 1, 16),
		CFrame = CFrame.new(0, 1.5, -50),
		Color = Color3.fromRGB(70, 55, 40),
		Material = Enum.Material.Basalt,
		Parent = root,
	})
	spawnPad:SetAttribute("IsSpawn", true)

	-- Cover pillars
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

	-- Treasure pile under dragon (center-ish)
	part({
		Name = "TreasurePile",
		Size = Vector3.new(28, 4, 28),
		CFrame = CFrame.new(0, 3, 5),
		Color = Color3.fromRGB(180, 140, 40),
		Material = Enum.Material.Foil,
		Parent = root,
	})

	-- Sleeping dragon placeholder (3 heads)
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
		Color3.fromRGB(160, 50, 40), -- red
		Color3.fromRGB(50, 90, 160), -- blue
		Color3.fromRGB(70, 140, 60), -- green
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

	-- Loot gradient: common near entrance → valuable near dragon
	local lootFolder = Instance.new("Folder")
	lootFolder.Name = "Loot"
	lootFolder.Parent = root

	spawnLoot(
		lootFolder,
		"GoldCoin",
		Vector3.new(-8, 2.5, -40),
		Color3.fromRGB(255, 200, 40),
		Vector3.new(1.2, 0.3, 1.2)
	)
	spawnLoot(lootFolder, "Goblet", Vector3.new(10, 3, -28), Color3.fromRGB(220, 180, 60), Vector3.new(1.5, 2, 1.5))
	spawnLoot(lootFolder, "Jewel", Vector3.new(-12, 2.8, -10), Color3.fromRGB(80, 200, 255), Vector3.new(1.4, 1.4, 1.4))
	spawnLoot(lootFolder, "GoldenSword", Vector3.new(12, 3.5, 0), Color3.fromRGB(255, 215, 80), Vector3.new(1, 4, 0.4))
	spawnLoot(
		lootFolder,
		"RoyalCrown",
		Vector3.new(0, 6.5, 5),
		Color3.fromRGB(255, 180, 40),
		Vector3.new(2.5, 1.5, 2.5)
	)

	-- Extraction near +Z (far from dragon toward exit opposite entrance)
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

	local extractBeacon = part({
		Name = "ExtractionBeacon",
		Size = Vector3.new(2, 10, 2),
		CFrame = CFrame.new(0, 6, 48),
		Color = Color3.fromRGB(60, 220, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = root,
	})
	extractBeacon.Transparency = 0.2

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
