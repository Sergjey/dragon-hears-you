local LootTypes = require(script.Parent.Parent.Types.LootTypes)

type LootDefinition = LootTypes.LootDefinition

local definitions: { [string]: LootDefinition } = {
	GoldCoin = {
		Id = "GoldCoin",
		Value = 10,
		Weight = 1,
		PickupNoise = 1,
		Rarity = "Common",
		LootType = "Backpack",
	},
	Goblet = {
		Id = "Goblet",
		Value = 100,
		Weight = 2,
		PickupNoise = 3,
		Rarity = "Uncommon",
		LootType = "Backpack",
	},
	Jewel = {
		Id = "Jewel",
		Value = 250,
		Weight = 1,
		PickupNoise = 2,
		Rarity = "Rare",
		LootType = "Backpack",
	},
	GoldenSword = {
		Id = "GoldenSword",
		Value = 500,
		Weight = 4,
		PickupNoise = 5,
		Rarity = "Epic",
		LootType = "Backpack",
	},
	RoyalCrown = {
		Id = "RoyalCrown",
		Value = 2000,
		Weight = 5,
		PickupNoise = 8,
		Rarity = "Legendary",
		LootType = "Backpack",
	},
	SoulGem = {
		Id = "SoulGem",
		Value = 3500,
		Weight = 3,
		PickupNoise = 6,
		Rarity = "Mythic",
		LootType = "Backpack",
	},
	-- Carry examples (not spawned in Phase 1 map; architecture hooks)
	DragonEgg = {
		Id = "DragonEgg",
		Value = 8000,
		Weight = 15,
		PickupNoise = 5,
		Rarity = "Legendary",
		LootType = "Carry",
		RequiredPlayers = 1,
		CarrySpeedMultiplier = 0.75,
		NoiseMultiplier = 1.4,
		DropNoise = 12,
		DisableAbilitiesWhileCarrying = true,
		OnStealNoise = 20,
	},
	AncientChest = {
		Id = "AncientChest",
		Value = 20000,
		Weight = 25,
		PickupNoise = 8,
		Rarity = "Mythic",
		LootType = "Carry",
		RequiredPlayers = 2,
		CarrySpeedMultiplier = 0.6,
		NoiseMultiplier = 1.6,
		DropNoise = 20,
		DisableAbilitiesWhileCarrying = true,
	},
}

local LootConfig = {}

function LootConfig.get(id: string): LootDefinition?
	return definitions[id]
end

function LootConfig.getAll(): { [string]: LootDefinition }
	return definitions
end

function LootConfig.isBackpack(id: string): boolean
	local def = definitions[id]
	return def ~= nil and def.LootType == "Backpack"
end

function LootConfig.isCarry(id: string): boolean
	local def = definitions[id]
	return def ~= nil and def.LootType == "Carry"
end

return LootConfig
