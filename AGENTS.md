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
- Current phase: **Phase 7 polish** (audio, VFX, loot feedback, dragon warnings, UI motion)
- Done: Phase 1–6 (slice, dragon AI, multiplayer, lobby, classes, economy)
- Next: Phase 8 replayability; Scout after class gameplay check
- Out of scope still: Scout, CarryService runtime, monetization, Creator Store art packs

## Polish (Phase 7)
- `AudioController` + `AudioConfig` — SFX on loot/extract/dragon/abilities; stage tension bus
- `FeedbackController` — loot rarity popup, AbilityFx/GadgetFx particles, loot bob/spin
- DragonEffects: stage vignette + telegraph grow; HUD noise stage pulse
- Config: `src/shared/Config/AudioConfig.luau`, `FeedbackConfig.luau`

## Economy (Phase 6)
- Extract credits persistent **Gold** (server); DataStore profile with `pcall` error handling
- Lobby shop: bags, class unlocks (Thief free), gadgets (1 slot)
- Config: `src/shared/Config/EconomyConfig.luau`

## Classes (Phase 5)
- Lobby UI selects class → `ClassId` (locked on pad start; must be unlocked)
- Actives (Q): Silent Step / Heal / Shield / Noise Maker
- Config: `src/shared/Config/ClassConfig.luau`

## Lobby / teleport
- Studio default: PlaceIds `0` → in-place pad → dungeon
- Published: set PlaceIds in `LobbyConfig.luau`

## Visual (graybox)
- Intentional temporary graybox; gameplay on CollectionService tags.

## Architecture
- Shared config: Game, Noise, Loot, Dragon, Multiplayer, Lobby, Class, Economy, Audio, Feedback, Tags
- Server: Data, Economy, Gadget, Class, Lobby, Match, Noise, Loot (+ LootFx), …
- Client: Lobby / ClassSelect / Shop / HUD / Audio / Feedback / DragonEffects / Result / Downed
- Remotes: LootFx + prior remotes

## Agent shortcuts
- Project rules: `.cursor/rules/`
- Skills: `rojo-workflow`, `roblox-remotes`, `roblox-playtest`, `roblox-ui-polish` under `.cursor/skills/`
- MCP: `.cursor/mcp.json` → Roblox Studio built-in MCP
