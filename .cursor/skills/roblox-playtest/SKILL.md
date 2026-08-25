---
name: roblox-playtest
description: >-
  Iterative playtest loop using official Roblox Studio MCP plus fixes in src/.
  Use when playtesting, debugging runtime errors, verifying a feature in Studio,
  or when the user asks to test, play, or check Output logs.
---

# Playtest loop (Studio MCP + Rojo)

## Principles
- **Verify in Studio**, **fix in `src/`** (Rojo). Avoid rewriting the same script only through MCP.
- Prefer official Studio MCP tools (`list_roblox_studios`, playtest/start-stop, console, screen capture, `execute_luau` as needed).

## Loop (max ~5 iterations)
1. **Ensure sync** — changes are in `src/`; Rojo Connected.
2. **Start play** via MCP; note `studio_id` if multiple Studios.
3. **Reproduce** the feature path (or ask the user to click through if input is required).
4. **Read** console output / errors; capture viewport if UI-related.
5. **Fix** the Luau under `src/`; wait for Rojo sync; stop play if needed; repeat.
6. **Stop play** when done so Studio isn't left running.

## What to report
- What was tested
- Errors/logs seen
- Files changed
- Remaining risks (needs manual input, device-specific UI, etc.)

## Don't
- Leave play mode running after the task
- “Fix” by editing only the live Studio script copy when a Rojo-managed file exists
- Infinite retry — after 5 failed loops, summarize blockers and ask the user
