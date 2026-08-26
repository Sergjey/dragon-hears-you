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
- Current phase: **Scout class** shipped (info + Treasure Sense)
- Done: Phase 1–8 + Scout
- Next: CarryService runtime; Creator Store art packs
- Out of scope still: CarryService, monetization

## Classes
- Thief / Medic / Guardian / Trickster / **Scout**
- Scout: passive loot pings + dragon intel chip; Q **Treasure Sense** (5s wall highlights Rare+)
- Config: `src/shared/Config/ClassConfig.luau`; unlock price in `EconomyConfig`

## Replayability (Phase 8)
- Cave I/II/III + daily challenge; seeded loot / events / rare room
- Config: `ReplayConfig.luau`

## Economy (Phase 6)
- Extract → Gold; DataStore; bags / unlocks / gadgets

## Lobby / teleport
- Studio default: PlaceIds `0` → in-place pad → dungeon
- Published: set PlaceIds in `LobbyConfig.luau`

## Visual (graybox)
- Intentional temporary graybox; gameplay on CollectionService tags.

## Architecture
- Shared: Class (+ Scout), Economy, Replay, Audio, Feedback, …
- Server: ClassService TreasureSenseUntil; …
- Client: ScoutController + ClassSelect / Shop / Replay / …

## Agent shortcuts
- Project rules: `.cursor/rules/`
- Skills: `rojo-workflow`, `roblox-remotes`, `roblox-playtest`, `roblox-ui-polish` under `.cursor/skills/`
- MCP: `.cursor/mcp.json` → Roblox Studio built-in MCP
