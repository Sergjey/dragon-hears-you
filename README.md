# dragon-hears-you

Roblox game built with [Rojo](https://rojo.space) and Cursor + Studio MCP.

## Stack

| Tool | Role |
|------|------|
| **Rojo** | File ↔ Studio sync (`src/` is source of truth) |
| **Rokit** | Toolchain versions (`rojo`, `selene`, `stylua`) |
| **Selene / StyLua** | Lint + format |
| **Studio MCP** | AI reads/edits DataModel, playtests (not primary script authoring) |

## One-time setup

1. Install [Rokit](https://github.com/rojo-rbx/rokit) if needed, then from repo root:
   ```bash
   rokit install
   ```
2. Install the [Rojo plugin](https://www.roblox.com/library/13916111004/Rojo-7) in Roblox Studio.
3. In Studio: **Assistant → … → Manage MCP Servers → Enable Studio as MCP server**.  
   Or use Quick connect → Cursor. Project MCP config is already in `.cursor/mcp.json`.
4. Restart Cursor so Roblox_Studio MCP loads.

## Daily workflow

```bash
git checkout -b feat/your-feature
rojo serve          # keep running
# In Studio: Plugins → Rojo → Connect
# Edit files under src/ — they sync live
git push -u origin HEAD
gh pr create        # merge into protected main only via PR
```

### Layout

```
src/
  client/   → StarterPlayer.StarterPlayerScripts.Client  (LocalScripts)
  server/   → ServerScriptService.Server                 (Scripts)
  shared/   → ReplicatedStorage.Shared                   (ModuleScripts)
```

Naming: `*.server.luau` → Script, `*.client.luau` → LocalScript, `*.luau` → ModuleScript.

### MCP vs Rojo

- Write game logic in `src/` (Rojo) so git diffs and PRs stay clean.
- Use Studio MCP for exploring instances, properties, assets, and playtests.
- Avoid letting the agent rewrite the same scripts only through MCP — Rojo will overwrite Studio script sources on sync.

### Agent rules & skills

- Always-on rules: `.cursor/rules/` (Rojo layout, security, Luau style)
- Skills: `rojo-workflow`, `roblox-remotes`, `roblox-playtest`, `roblox-ui-polish` in `.cursor/skills/`
- Visual refs: `refs/` (UI / mood / characters)
- High-level notes: `AGENTS.md`
