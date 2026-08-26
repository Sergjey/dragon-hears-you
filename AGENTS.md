# Agent notes — dragon-hears-you

Roblox experience developed with **Rojo** + **Cursor** + **official Studio MCP**.

## Stack
- Source: `src/{client,server,shared}`
- Toolchain: Rokit (`rojo`, `selene`, `stylua`)
- Ship: feature branch → PR → protected `main`

## Game
- Working title: **Gorynych Heist** (repo: dragon-hears-you)
- Elevator pitch: Team of thieves steals treasure from sleeping three-headed Zmey Gorynych — greed raises shared Noise and wakes the dragon.
- Core loop: Lobby → class select → pad → dungeon → loot / noise risk → extract → sell → upgrades
- Current phase: **Phase 8 replayability** (seeded loot, events, rare room, Cave I–III, daily card)
- Done: Phase 1–7 (slice → polish)
- Next: Scout class; CarryService; Creator Store art packs
- Out of scope still: Scout, CarryService runtime, monetization

## Replayability (Phase 8)
- Cave I/II/III + daily challenge opt-in in lobby (`ReplayController`)
- `MatchSeed` drives loot layout, rare room/SoulGem artifact, mid-match `EventService`
- Config: `src/shared/Config/ReplayConfig.luau`

## Polish (Phase 7)
- Audio / Feedback / Dragon vignette / loot bob
- Config: `AudioConfig`, `FeedbackConfig`

## Economy (Phase 6)
- Extract → Gold; DataStore; bags / class unlocks / gadgets

## Classes (Phase 5)
- Thief / Medic / Guardian / Trickster (Scout deferred)

## Lobby / teleport
- Studio default: PlaceIds `0` → in-place pad → dungeon
- Published: set PlaceIds in `LobbyConfig.luau`

## Visual (graybox)
- Intentional temporary graybox; gameplay on CollectionService tags.

## Architecture
- Shared: Game, Noise, Loot, Dragon, Multiplayer, Lobby, Class, Economy, Audio, Feedback, Replay, Tags
- Server: Replay, Event, Data, Economy, Gadget, Class, Lobby, Match, Noise, Loot, Dragon…
- Client: Lobby / Replay / ClassSelect / Shop / HUD / Audio / Feedback / DragonEffects…
- Remotes: RequestSetDifficulty, RequestSetDailyOptIn, ReplayState, MatchEvent + prior

## Agent shortcuts
- Project rules: `.cursor/rules/`
- Skills: `rojo-workflow`, `roblox-remotes`, `roblox-playtest`, `roblox-ui-polish` under `.cursor/skills/`
- MCP: `.cursor/mcp.json` → Roblox Studio built-in MCP
