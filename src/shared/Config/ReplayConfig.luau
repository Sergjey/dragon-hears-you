local ReplayTypes = require(script.Parent.Parent.Types.ReplayTypes)

type CaveId = ReplayTypes.CaveId
type DailyCardId = ReplayTypes.DailyCardId
type CaveDefinition = ReplayTypes.CaveDefinition
type DailyCardDefinition = ReplayTypes.DailyCardDefinition

local caves: { [CaveId]: CaveDefinition } = {
	CaveI = {
		Id = "CaveI",
		DisplayName = "Cave I",
		Description = "Standard lair — learn the loop",
		LootCount = 6,
		LootValueMultiplier = 1,
		NoiseMultiplier = 1,
		EventIntervalSeconds = 28,
		RareRoomChance = 0.35,
		ArtifactChance = 0.2,
		RarityBias = 1,
	},
	CaveII = {
		Id = "CaveII",
		DisplayName = "Cave II",
		Description = "Richer piles, louder risks",
		LootCount = 8,
		LootValueMultiplier = 1.25,
		NoiseMultiplier = 1.15,
		EventIntervalSeconds = 22,
		RareRoomChance = 0.55,
		ArtifactChance = 0.4,
		RarityBias = 1.35,
	},
	CaveIII = {
		Id = "CaveIII",
		DisplayName = "Cave III",
		Description = "Greedy vault — restless dragon",
		LootCount = 10,
		LootValueMultiplier = 1.5,
		NoiseMultiplier = 1.3,
		EventIntervalSeconds = 16,
		RareRoomChance = 0.75,
		ArtifactChance = 0.6,
		RarityBias = 1.7,
	},
}

local dailyCards: { [DailyCardId]: DailyCardDefinition } = {
	QuietSteps = {
		Id = "QuietSteps",
		DisplayName = "Quiet Steps",
		Description = "Footfalls and spikes make less Noise",
		LootValueMultiplier = 1,
		NoiseMultiplier = 0.85,
		EventRateMultiplier = 1,
	},
	GreedyHoard = {
		Id = "GreedyHoard",
		DisplayName = "Greedy Hoard",
		Description = "+25% loot value · slightly louder",
		LootValueMultiplier = 1.25,
		NoiseMultiplier = 1.1,
		EventRateMultiplier = 1,
	},
	RestlessDrake = {
		Id = "RestlessDrake",
		DisplayName = "Restless Drake",
		Description = "More mid-run events · tense Noise",
		LootValueMultiplier = 1,
		NoiseMultiplier = 1.15,
		EventRateMultiplier = 1.45,
	},
}

-- Backpack loot spawn weights (base). Bias raises higher-index / rarer entries.
local lootWeights: { { Id: string, Weight: number } } = {
	{ Id = "GoldCoin", Weight = 40 },
	{ Id = "Goblet", Weight = 28 },
	{ Id = "Jewel", Weight = 18 },
	{ Id = "GoldenSword", Weight = 10 },
	{ Id = "RoyalCrown", Weight = 4 },
}

local ReplayConfig = {
	DefaultCaveId = "CaveI" :: CaveId,
	CaveOrder = { "CaveI", "CaveII", "CaveIII" } :: { CaveId },
	DailyCardOrder = { "QuietSteps", "GreedyHoard", "RestlessDrake" } :: { DailyCardId },
	ArtifactLootId = "SoulGem",
	EventKinds = { "NoiseSpike", "FootfallEcho", "BriefStir", "TrapClick" },
	EventMessages = {
		NoiseSpike = "Something clatters in the dark…",
		FootfallEcho = "Echoes of footsteps bounce off the stone",
		BriefStir = "Gorynych stirs in his sleep…",
		TrapClick = "A hidden trap clicks!",
	},
	EventNoise = {
		NoiseSpike = 8,
		FootfallEcho = 5,
		BriefStir = 3,
		TrapClick = 10,
	},
	LootSlotPositions = {
		Vector3.new(-8, 2.5, -40),
		Vector3.new(10, 3, -28),
		Vector3.new(-12, 2.8, -10),
		Vector3.new(12, 3.5, 0),
		Vector3.new(-16, 2.8, 15),
		Vector3.new(14, 3, 22),
		Vector3.new(-6, 3, -18),
		Vector3.new(8, 2.6, -5),
		Vector3.new(-10, 3.2, 30),
		Vector3.new(6, 3, 35),
	},
	RareRoomOrigin = Vector3.new(42, 0, -5),
	LootColors = {
		GoldCoin = Color3.fromRGB(255, 200, 40),
		Goblet = Color3.fromRGB(220, 180, 60),
		Jewel = Color3.fromRGB(80, 200, 255),
		GoldenSword = Color3.fromRGB(255, 215, 80),
		RoyalCrown = Color3.fromRGB(255, 180, 40),
		SoulGem = Color3.fromRGB(200, 80, 255),
	},
	LootSizes = {
		GoldCoin = Vector3.new(1.2, 0.3, 1.2),
		Goblet = Vector3.new(1.5, 2, 1.5),
		Jewel = Vector3.new(1.4, 1.4, 1.4),
		GoldenSword = Vector3.new(1, 4, 0.4),
		RoyalCrown = Vector3.new(2.5, 1.5, 2.5),
		SoulGem = Vector3.new(1.8, 1.8, 1.8),
	},
}

function ReplayConfig.getCave(id: string?): CaveDefinition
	if id and caves[id :: CaveId] then
		return caves[id :: CaveId]
	end
	return caves[ReplayConfig.DefaultCaveId]
end

function ReplayConfig.isValidCave(id: unknown): boolean
	return typeof(id) == "string" and caves[id :: CaveId] ~= nil
end

function ReplayConfig.listCaves(): { CaveDefinition }
	local list = {}
	for _, id in ReplayConfig.CaveOrder do
		table.insert(list, caves[id])
	end
	return list
end

function ReplayConfig.getDailyCard(id: string?): DailyCardDefinition
	if id and dailyCards[id :: DailyCardId] then
		return dailyCards[id :: DailyCardId]
	end
	return dailyCards.QuietSteps
end

function ReplayConfig.listDailyCards(): { DailyCardDefinition }
	local list = {}
	for _, id in ReplayConfig.DailyCardOrder do
		table.insert(list, dailyCards[id])
	end
	return list
end

function ReplayConfig.dailyCardForUtcDay(dayKey: number): DailyCardDefinition
	local idx = (math.abs(dayKey) % #ReplayConfig.DailyCardOrder) + 1
	return dailyCards[ReplayConfig.DailyCardOrder[idx]]
end

function ReplayConfig.getLootWeights(): { { Id: string, Weight: number } }
	return lootWeights
end

return ReplayConfig
