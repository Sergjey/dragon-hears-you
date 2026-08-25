---
name: roblox-remotes
description: >-
  Design secure client-server remotes for Roblox (RemoteEvent/RemoteFunction).
  Use when adding networking, remotes, replication, multiplayer actions, or
  when the user mentions RemoteEvent, RemoteFunction, or never-trust-client.
---

# Secure remotes

## Rules
1. **Server owns truth** — client requests; server decides.
2. One remote ≈ one intent (`RequestJump`, not `DoAnything`).
3. Validate on server: player identity, types, ranges, cooldowns, ownership of instances.
4. Prefer `RemoteEvent` for fire-and-forget; `RemoteFunction` only when the client must await a result (keep handlers fast).

## Placement
- Create remotes under a Folder in ReplicatedStorage (e.g. `ReplicatedStorage.Remotes`) — either as Rojo instances under `src/shared` or a small bootstrap that ensures they exist on the server.
- Server connects `.OnServerEvent` / `.OnServerInvoke`.
- Client only `:FireServer` / `:InvokeServer` / listens to client events the server fires.

## Validation sketch

```luau
-- server
remote.OnServerEvent:Connect(function(player: Player, amount: unknown)
	if typeof(amount) ~= "number" then
		return
	end
	amount = math.floor(amount :: number)
	if amount < 1 or amount > 100 then
		return
	end
	-- apply authoritative change...
end)
```

## Anti-patterns
- Trusting client-sent scores, cash, inventory tables, or “I hit X for Y damage” without server checks
- Exposing admin remotes without rank/permission checks
- Huge payloads every frame — batch or use attributes/replication where appropriate
