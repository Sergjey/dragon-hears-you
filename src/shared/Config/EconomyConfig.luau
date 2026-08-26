local EconomyTypes = require(script.Parent.Parent.Types.EconomyTypes)

type BagId = EconomyTypes.BagId
type GadgetId = EconomyTypes.GadgetId
type BagDefinition = EconomyTypes.BagDefinition
type GadgetDefinition = EconomyTypes.GadgetDefinition
type PlayerEconomyProfile = EconomyTypes.PlayerEconomyProfile

local bags: { [BagId]: BagDefinition } = {
	ClothBag = {
		Id = "ClothBag",
		DisplayName = "Cloth Bag",
		Description = "Starter sack — capacity 10",
		Price = 0,
		Capacity = 10,
		FootstepNoiseMultiplier = 1,
	},
	ThiefBackpack = {
		Id = "ThiefBackpack",
		DisplayName = "Thief Backpack",
		Description = "Capacity 20 · quieter steps",
		Price = 500,
		Capacity = 20,
		FootstepNoiseMultiplier = 0.95,
	},
	AdventurerPack = {
		Id = "AdventurerPack",
		DisplayName = "Adventurer Pack",
		Description = "Capacity 30 — more greed, more risk",
		Price = 1500,
		Capacity = 30,
		FootstepNoiseMultiplier = 1,
	},
	BagOfHolding = {
		Id = "BagOfHolding",
		DisplayName = "Bag of Holding",
		Description = "Capacity 50 — heavy haul",
		Price = 5000,
		Capacity = 50,
		FootstepNoiseMultiplier = 1,
	},
}

local gadgets: { [GadgetId]: GadgetDefinition } = {
	FeatherBoots = {
		Id = "FeatherBoots",
		DisplayName = "Feather Boots",
		Description = "Passive — quieter footsteps",
		Price = 400,
		FootstepNoiseMultiplier = 0.7,
		IsActive = false,
	},
	SmokeBomb = {
		Id = "SmokeBomb",
		DisplayName = "Smoke Bomb",
		Description = "Once/run — damp move-noise briefly",
		Price = 350,
		IsActive = true,
		AbilityDurationSeconds = 5,
		SmokeFootstepMultiplier = 0.15,
	},
	DragonBait = {
		Id = "DragonBait",
		DisplayName = "Dragon Bait",
		Description = "Once/run — noise spike at aim point",
		Price = 450,
		IsActive = true,
		AbilityNoise = 22,
		AbilityRange = 40,
	},
}

local classPrices: { [string]: number } = {
	Thief = 0,
	Medic = 300,
	Guardian = 300,
	Trickster = 400,
}

local EconomyConfig = {
	DataStoreName = "GorynychEconomy_v1",
	SaveDebounceSeconds = 2,
	DefaultBagId = "ClothBag" :: BagId,
	DefaultUnlockedClasses = { "Thief" },
	BagOrder = { "ClothBag", "ThiefBackpack", "AdventurerPack", "BagOfHolding" } :: { BagId },
	GadgetOrder = { "FeatherBoots", "SmokeBomb", "DragonBait" } :: { GadgetId },
	ClassUnlockOrder = { "Thief", "Medic", "Guardian", "Trickster" },
}

function EconomyConfig.getBag(id: string?): BagDefinition
	if id and bags[id :: BagId] then
		return bags[id :: BagId]
	end
	return bags[EconomyConfig.DefaultBagId]
end

function EconomyConfig.isValidBag(id: unknown): boolean
	return typeof(id) == "string" and bags[id :: BagId] ~= nil
end

function EconomyConfig.listBags(): { BagDefinition }
	local list = {}
	for _, id in EconomyConfig.BagOrder do
		table.insert(list, bags[id])
	end
	return list
end

function EconomyConfig.getGadget(id: string?): GadgetDefinition?
	if id and gadgets[id :: GadgetId] then
		return gadgets[id :: GadgetId]
	end
	return nil
end

function EconomyConfig.isValidGadget(id: unknown): boolean
	return typeof(id) == "string" and gadgets[id :: GadgetId] ~= nil
end

function EconomyConfig.listGadgets(): { GadgetDefinition }
	local list = {}
	for _, id in EconomyConfig.GadgetOrder do
		table.insert(list, gadgets[id])
	end
	return list
end

function EconomyConfig.getClassPrice(classId: string): number?
	return classPrices[classId]
end

function EconomyConfig.defaultProfile(): PlayerEconomyProfile
	return {
		Gold = 0,
		EquippedBagId = EconomyConfig.DefaultBagId,
		OwnedBags = { EconomyConfig.DefaultBagId },
		UnlockedClasses = table.clone(EconomyConfig.DefaultUnlockedClasses),
		OwnedGadgets = {},
		EquippedGadgetId = nil,
	}
end

return EconomyConfig
