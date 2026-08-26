export type ClassId = "Thief" | "Medic" | "Guardian" | "Trickster"

export type ClassDefinition = {
	Id: ClassId,
	DisplayName: string,
	Description: string,
	-- Passives
	FootstepNoiseMultiplier: number,
	WalkSpeedMultiplier: number,
	LootPromptSpeedBonus: number, -- 0.15 = 15% faster (shorter hold)
	ReviveSpeedMultiplier: number, -- 1.5 = 50% faster
	MaxHPMultiplier: number,
	-- Active
	AbilityId: string,
	AbilityName: string,
	AbilityDurationSeconds: number?,
	AbilityCooldownSeconds: number,
	AbilityNoise: number?, -- Trickster noise maker
	AbilityHealFraction: number?, -- Medic heal add as fraction of max HP
	AbilityRange: number?,
}

export type ClassStatePayload = {
	ClassId: ClassId,
	AbilityId: string,
	AbilityName: string,
	CooldownRemaining: number,
	SilentStepRemaining: number?,
	ShieldCharges: number?,
}

export type AbilityFxPayload = {
	UserId: number,
	AbilityId: string,
	Position: Vector3?,
}

return {}
