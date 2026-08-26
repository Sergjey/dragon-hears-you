export type PlayerMatchStatus = "Alive" | "Downed" | "Dead" | "Extracted"

export type RosterEntry = {
	UserId: number,
	Name: string,
	Status: PlayerMatchStatus,
	HP: number,
	MaxHP: number,
	BleedoutRemaining: number?, -- seconds, Downed only
}

export type RosterStatePayload = {
	Entries: { RosterEntry },
	MatchEnded: boolean,
	Outcome: string, -- Ongoing | TeamWipe | Complete
}

export type MatchEndedPayload = {
	Outcome: string,
	SecuredValue: number,
	ItemCount: number,
	Extracted: boolean,
}

return {}
