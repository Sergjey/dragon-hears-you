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
- Current phase: **Phase 2 dragon stages / AI** (state machine, Disturbed events, Partial/Full hunting, HP/death)
- Done: Phase 1 vertical slice (dungeon, backpack loot, noise, extraction, result UI)
- Next: Phase 3 multiplayer (shared noise already, downed/revive, team extract edge cases)
- Out of scope still: lobby pads, classes, CarryService runtime, DataStore economy, monetization

## Architecture
- Shared config: `src/shared/Config/{Game,Noise,Loot,Dragon,Tags}`
- Server services: Match, Noise, Loot, Backpack, MovementModifier, Extraction, Damage, Dragon, DragonPerception
- Client: HUD / Result / Interaction / DragonEffects
- Remotes: MatchState, ExtractionState, MatchResult, RequestDropLoot, DragonState, DragonEvent
- Map: procedural `DungeonBootstrap` (CollectionService tags)

## Visual
- Tokens + polish rules: skill `roblox-ui-polish`, rule `roblox-ui`
- Drop screenshots in `refs/ui`, `refs/mood`, `refs/chars` (see `refs/README.md`)

## Agent shortcuts
- Project rules: `.cursor/rules/`
- Skills: `rojo-workflow`, `roblox-remotes`, `roblox-playtest`, `roblox-ui-polish` under `.cursor/skills/`
- MCP: `.cursor/mcp.json` → Roblox Studio built-in MCP
