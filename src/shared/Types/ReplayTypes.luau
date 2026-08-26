-- Phase 8 replayability payloads.

export type CaveId = "CaveI" | "CaveII" | "CaveIII"

export type DailyCardId = "QuietSteps" | "GreedyHoard" | "RestlessDrake"

export type MatchEventKind = "NoiseSpike" | "FootfallEcho" | "BriefStir" | "TrapClick"

export type CaveDefinition = {
	Id: CaveId,
	DisplayName: string,
	Description: string,
	LootCount: number,
	LootValueMultiplier: number,
	NoiseMultiplier: number,
	EventIntervalSeconds: number,
	RareRoomChance: number,
	ArtifactChance: number,
	RarityBias: number, -- higher → richer weighted picks
}

export type DailyCardDefinition = {
	Id: DailyCardId,
	DisplayName: string,
	Description: string,
	LootValueMultiplier: number,
	NoiseMultiplier: number,
	EventRateMultiplier: number,
}

export type MatchMultipliers = {
	LootValueMultiplier: number,
	NoiseMultiplier: number,
	EventIntervalSeconds: number,
	RareRoomChance: number,
	ArtifactChance: number,
	RarityBias: number,
	LootCount: number,
}

export type ReplayStatePayload = {
	CaveId: CaveId,
	DailyOptIn: boolean,
	DailyCardId: DailyCardId,
	DailyCardName: string,
	DailyCardDescription: string,
	MatchSeed: number?,
}

export type MatchEventPayload = {
	Kind: MatchEventKind,
	Message: string,
}

return {}
