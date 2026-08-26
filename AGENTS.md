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
- Current phase: **Phase 3 Done** (Downed/Revive, team roster, leave drops, match-end) — playtest green for closeout
- Done: Phase 1 vertical slice; Phase 2 dragon stages / AI; Phase 3 multiplayer
- Next: **Phase 4** lobby Solo/Duo/Squad pads + TeleportService
- Out of scope still: classes, CarryService runtime, DataStore economy, monetization

## Visual (graybox)
- **Intentional temporary graybox**: procedural `DungeonBootstrap` parts + placeholder dragon. Not final art.
- Gameplay binds to **CollectionService tags** (`Loot`, `Dragon`, `ExtractionZone`, `HideSpot`) so Creator Store / custom models can replace parts later without rewriting services.
- Full art / sound / animation polish = **Phase 7**. Optional short art spike after Phase 3–4 is a separate task.

## Architecture
- Shared config: `src/shared/Config/{Game,Noise,Loot,Dragon,Multiplayer,Tags}`
- Server services: Match, Noise, Loot, Backpack, MovementModifier, Extraction, Damage, Downed, Dragon, DragonPerception
- Client: HUD (team roster) / Result / Interaction / DragonEffects / Downed
- Remotes: MatchState, ExtractionState, MatchResult, RequestDropLoot, DragonState, DragonEvent, RequestRevive, RosterState, MatchEnded
- Map: procedural `DungeonBootstrap` (CollectionService tags)

## Agent shortcuts
- Project rules: `.cursor/rules/`
- Skills: `rojo-workflow`, `roblox-remotes`, `roblox-playtest`, `roblox-ui-polish` under `.cursor/skills/`
- MCP: `.cursor/mcp.json` → Roblox Studio built-in MCP
