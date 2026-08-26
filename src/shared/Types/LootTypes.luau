-- Type-only module for loot definitions and backpack state.
export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type LootType = "Backpack" | "Carry"

export type LootDefinition = {
	Id: string,
	Value: number,
	Weight: number,
	PickupNoise: number,
	Rarity: Rarity,
	LootType: LootType,
	RequiredPlayers: number?,
	CarrySpeedMultiplier: number?,
	NoiseMultiplier: number?,
	DropNoise: number?,
	DisableAbilitiesWhileCarrying: boolean?,
	OnStealNoise: number?,
}

export type BackpackItem = {
	Id: string,
	Value: number,
	Weight: number,
	Rarity: Rarity,
}

export type BackpackState = {
	Items: { BackpackItem },
	UsedWeight: number,
	Capacity: number,
	TotalValue: number,
}

return {}
