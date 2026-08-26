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
- Current phase: **Phase 6 economy** (sell Gold, DataStore, bags, class unlocks, gadgets)
- Done: Phase 1–5 (slice, dragon AI, multiplayer Downed/Revive, lobby pads, classes)
- Next: Phase 7 polish (anims/VFX/audio); Scout after class gameplay check
- Out of scope still: Scout, CarryService runtime, monetization, full gadget catalog

## Economy (Phase 6)
- Extract credits persistent **Gold** (server); DataStore profile with `pcall` error handling
- Lobby shop: bags (Cloth→Bag of Holding), class unlocks (Thief free), gadgets (1 slot)
- Gadgets: Feather Boots (passive), Smoke Bomb / Dragon Bait (E, once/run)
- Config: `src/shared/Config/EconomyConfig.luau`

## Classes (Phase 5)
- Lobby UI selects class → `ClassId` attribute (locked for the run on pad start; must be unlocked)
- Passives: Thief stealth/speed/loot; Medic revive speed; Guardian +30% HP
- Actives (Q): Silent Step / Heal / Shield / Noise Maker — server-validated CDs
- Config: `src/shared/Config/ClassConfig.luau`

## Lobby / teleport
- Studio default: PlaceIds `0` → in-place pad → dungeon
- Published: set PlaceIds in `LobbyConfig.luau`

## Visual (graybox)
- Intentional temporary graybox; gameplay on CollectionService tags.

## Architecture
- Shared config: Game, Noise, Loot, Dragon, Multiplayer, Lobby, Class, Economy, Tags
- Server: Data, Economy, Gadget, Class, Lobby, MatchTeleport, Match, Noise, Loot, Backpack, Movement, Extraction, Damage, Downed, Dragon…
- Client: Lobby / ClassSelect / Shop / HUD / Result / Interaction / DragonEffects / Downed
- Remotes: RequestBuy, RequestEquipLoadout, RequestUseGadget, EconomyState, GadgetFx + prior remotes

## Agent shortcuts
- Project rules: `.cursor/rules/`
- Skills: `rojo-workflow`, `roblox-remotes`, `roblox-playtest`, `roblox-ui-polish` under `.cursor/skills/`
- MCP: `.cursor/mcp.json` → Roblox Studio built-in MCP
