-- Economy / shop / loadout payloads (Phase 6).

export type ShopKind = "Bag" | "Class" | "Gadget"

export type BagId = "ClothBag" | "ThiefBackpack" | "AdventurerPack" | "BagOfHolding"

export type GadgetId = "FeatherBoots" | "SmokeBomb" | "DragonBait"

export type BagDefinition = {
	Id: BagId,
	DisplayName: string,
	Description: string,
	Price: number,
	Capacity: number,
	FootstepNoiseMultiplier: number,
}

export type GadgetDefinition = {
	Id: GadgetId,
	DisplayName: string,
	Description: string,
	Price: number,
	-- Passive
	FootstepNoiseMultiplier: number?,
	-- Actives (once per run unless noted)
	IsActive: boolean,
	AbilityDurationSeconds: number?,
	AbilityNoise: number?,
	AbilityRange: number?,
	SmokeFootstepMultiplier: number?,
}

export type PlayerEconomyProfile = {
	Gold: number,
	EquippedBagId: BagId,
	OwnedBags: { string },
	UnlockedClasses: { string },
	OwnedGadgets: { string },
	EquippedGadgetId: string?,
}

export type EconomyStatePayload = {
	Gold: number,
	EquippedBagId: string,
	OwnedBags: { string },
	UnlockedClasses: { string },
	OwnedGadgets: { string },
	EquippedGadgetId: string?,
	GadgetReady: boolean?,
	GadgetChargesLeft: number?,
}

return {}
