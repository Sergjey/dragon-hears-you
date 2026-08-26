export type HeadId = "Red" | "Blue" | "Green"

export type AiState = "Sleeping" | "Disturbed" | "PartialWake" | "Searching" | "FullAwake" | "Hunting"

export type DisturbedEventKind = "Growl" | "Earthquake" | "HotBreath"

export type DragonStatePayload = {
	AiState: AiState,
	FullAwakeLocked: boolean,
	ActiveHeads: { HeadId },
}

export type DragonEventPayload = {
	Kind: string, -- Growl | Earthquake | HotBreathTelegraph | HotBreathImpact | FireBreathTelegraph | FireBreathImpact | Smoke | Acid | FullAwakeBanner
	HeadId: HeadId?,
	Position: Vector3?,
	Duration: number?,
	Intensity: number?,
}

export type NoiseHearEvent = {
	Position: Vector3,
	Strength: number,
	Source: string,
	At: number,
}

return {}
