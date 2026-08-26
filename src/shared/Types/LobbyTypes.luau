export type LobbyPadEntry = {
	PadId: string,
	DisplayName: string,
	Capacity: number,
	Occupied: number,
	Countdown: number?, -- seconds remaining, nil if idle
	Locked: boolean, -- launching / in match
	OccupantNames: { string },
}

export type LobbyPadStatePayload = {
	Pads: { LobbyPadEntry },
	Phase: string, -- Lobby | Match
}

export type TeleportPartyData = {
	PartySize: number,
	MemberUserIds: { number },
	Seed: number?,
}

return {}
