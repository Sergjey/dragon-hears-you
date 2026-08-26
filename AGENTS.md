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
- Current phase: **Phase 1 vertical slice** (solo dungeon bootstrap, backpack loot, noise meter, extraction, result UI)
- Next: Phase 2 dragon stages / AI state machine
- Out of scope for Phase 1: CarryLoot runtime, classes, lobby pads, DataStore economy, monetization

## Architecture (Phase 1)
- Shared config: `src/shared/Config/{Game,Noise,Loot,Tags}`
- Server services: Match, Noise, Loot, Backpack, MovementModifier, Extraction
- Client: HUD / Result / Interaction controllers
- Remotes created at runtime under `ReplicatedStorage.Remotes`
- Map: procedural `DungeonBootstrap` (CollectionService tags); replace with Studio art later

## Visual
- Tokens + polish rules: skill `roblox-ui-polish`, rule `roblox-ui`
- Drop screenshots in `refs/ui`, `refs/mood`, `refs/chars` (see `refs/README.md`)

## Agent shortcuts
- Project rules: `.cursor/rules/`
- Skills: `rojo-workflow`, `roblox-remotes`, `roblox-playtest`, `roblox-ui-polish` under `.cursor/skills/`
- MCP: `.cursor/mcp.json` → Roblox Studio built-in MCP
