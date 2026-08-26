-- Type-only module for match / extraction replication payloads.
export type DragonStage = "Sleeping" | "Disturbed" | "PartialWake" | "FullAwake"

export type MatchStatePayload = {
	Noise: number,
	MaxNoise: number,
	BagUsed: number,
	BagCapacity: number,
	BagValue: number,
	Stage: DragonStage,
	MatchActive: boolean,
}

export type ExtractionStatePayload = {
	Active: boolean,
	Progress: number,
	Cancelled: boolean,
	Success: boolean,
}

export type MatchResultPayload = {
	SecuredValue: number,
	ItemCount: number,
}

return {}
