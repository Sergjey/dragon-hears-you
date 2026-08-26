# Agent notes — dragon-hears-you

Roblox experience developed with **Rojo** + **Cursor** + **official Studio MCP**.

## Stack
- Source: `src/{client,server,shared}`
- Toolchain: Rokit (`rojo`, `selene`, `stylua`)
- Ship: feature branch → PR → protected `main`

## Game
- Working title: **Gorynych Heist** (repo: dragon-hears-you)
- Elevator pitch: Team of thieves steals treasure from sleeping three-headed Zmey Gorynych — greed raises shared Noise and wakes the dragon.
- Core loop: Lobby → loadout → dungeon → loot / noise risk → extract → sell → upgrades
- Current phase: **Phase 4 lobby** (Solo/Duo/Squad pads, countdown, Studio in-place match start; TeleportService when PlaceIds set)
- Done: Phase 1 vertical slice; Phase 2 dragon AI; Phase 3 multiplayer (Downed/Revive, roster, match-end)
- Next: Phase 5+ (loadout/classes deferred); set `LobbyConfig` PlaceIds for published multi-place
- Out of scope still: classes, CarryService runtime, DataStore economy, monetization

## Lobby / teleport
- Studio default: `LobbyPlaceId` / `DungeonPlaceId` = `0` → **in-place** pad → dungeon (no TeleportService)
- Published: set PlaceIds in `src/shared/Config/LobbyConfig.luau` → `ReserveServer` + private teleport; match end returns to lobby PlaceId
- Pads: CollectionService `TeleportPad` + attributes `PadId`, `PartySize` (1/2/4)

## Visual (graybox)
- **Intentional temporary graybox**: procedural lobby pads + `DungeonBootstrap` + placeholder dragon. Not final art.
- Gameplay binds to **CollectionService tags** (`Loot`, `Dragon`, `ExtractionZone`, `HideSpot`, `TeleportPad`) so models can replace parts later.
- Full art / sound / animation polish = **Phase 7**.

## Architecture
- Shared config: `src/shared/Config/{Game,Noise,Loot,Dragon,Multiplayer,Lobby,Tags}`
- Server: Lobby, MatchTeleport, Match, Noise, Loot, Backpack, MovementModifier, Extraction, Damage, Downed, Dragon, DragonPerception
- Client: Lobby / HUD / Result / Interaction / DragonEffects / Downed
- Remotes: LobbyPadState + match remotes (MatchState, RosterState, MatchEnded, …)
- Map: `LobbyBootstrap` + procedural `DungeonBootstrap`

## Agent shortcuts
- Project rules: `.cursor/rules/`
- Skills: `rojo-workflow`, `roblox-remotes`, `roblox-playtest`, `roblox-ui-polish` under `.cursor/skills/`
- MCP: `.cursor/mcp.json` → Roblox Studio built-in MCP
