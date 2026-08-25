---
name: rojo-workflow
description: >-
  Rojo file layout, naming, serve/connect sync for this Roblox project.
  Use when adding scripts, moving modules, setting up sync, or when the user
  mentions Rojo, default.project.json, or src/client|server|shared.
---

# Rojo workflow

## Before coding
1. Confirm `default.project.json` maps match the folder you edit.
2. If Studio is open, assume `rojo serve` may already be running — don't spawn a second serve unless needed.
3. Put new code in the correct tree:
   - server-only → `src/server/`
   - client-only → `src/client/`
   - shared modules → `src/shared/`

## Naming
| File | Instance |
|------|----------|
| `Foo.luau` | ModuleScript `Foo` |
| `Foo.server.luau` | Script `Foo` |
| `Foo.client.luau` | LocalScript `Foo` |
| `init.server.luau` in folder `Bar/` | Script named `Bar` |
| `init.client.luau` in folder `Bar/` | LocalScript named `Bar` |
| `init.luau` in folder `Bar/` | ModuleScript named `Bar` |

## Do / don't
- **Do** require shared via `ReplicatedStorage.Shared....`
- **Don't** invent parallel trees outside `src/` without updating `default.project.json`
- **Don't** commit `.rbxl` / `.rbxlx` place binaries for routine work

## After changes
- Tell the user to verify Rojo is Connected in Studio if sync looks stale.
- Optionally run `selene src` / `stylua --check src` when touching many files.
