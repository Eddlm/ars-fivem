# racingsystem — Structure

## 1) Runtime topology
- **Shared model layer:** `shared.lua` defines shared constants/config used by both sides.
- **Client interaction layer:** `client.lua` + `menu.lua` handle UI, editor flow, local prediction, and player-facing race runtime.
- **Server authority layer:** `server.lua` owns race definitions, instances, entrant membership, progression validation, and lifecycle decisions.
- **Server integrity layer:** `integrity.lua` performs validation/sweep responsibilities.
- **Server utility layer:** `UpdateNotifier.lua` provides update-check behavior.

## 2) Client/server relationship
- Server is authoritative for race lifecycle (create/invoke/join/start/checkpoint/finish/leave/kill).
- Client performs local UX logic (menu/editor/HUD/countdown handling, local convenience events), then forwards authoritative actions to server.
- Snapshot/event model keeps clients synchronized with server-maintained instance state.

## 3) Conceptual role separation
- **Menu/editor UX role:** `menu.lua`.
- **Live race HUD + local runtime role:** `client.lua`.
- **Authoritative race state + file IO role:** `server.lua`.
- **Validation/integrity policy role:** `integrity.lua`.
- **Shared enums/config role:** `shared.lua`.
- **Update check role:** `UpdateNotifier.lua`.

## 4) Call tree (high-level)
1. `fxmanifest.lua` loads shared script, then client scripts (`util.lua`, `menu.lua`, `client.lua`), then server scripts.
2. Client requests and receives snapshots/assets; menu actions call local handlers or trigger server events.
3. Server handles all critical mutation events and broadcasts updated snapshots/countdown/lap updates.
4. Client consumes snapshot stream to update HUD, leaderboard, checkpoint behavior, and editor/race state.
5. Update notifier runs delayed check path independently.

## 5) State model
- **Server authoritative state:** race definitions index, active race instances, entrant progress, ownership, countdown/start state.
- **Client replicated/runtime state:** latest snapshot cache, local prediction/progress helpers, HUD/menu/editor transient state.
- **Asset cache state:** instance asset payloads sent by server and retained client-side for rendering/use.

Authority boundary: server mutates truth; client mirrors and presents it, with some local-only helper state.

## 6) Independent threads
| Thread | Where | Role | Start condition | Loop cadence | End condition |
|---|---|---|---|---|---|
| Editor helper loop | `menu.lua` | Moves grabbed checkpoints and editor helper visuals | Client script load | Continuous loop with waits | Stops on resource unload |
| Client runtime loops (multiple) | `client.lua` | Snapshot upkeep, HUD refresh, checkpoint/pass handling, stale detection, race runtime updates | Client script load | Mix of per-frame and throttled waits | Stops on resource unload |
| Server maintenance loop | `server.lua` | Periodic server-side upkeep for race instances/runtime maintenance | Server script load | Continuous loop with waits | Stops on resource unload |
| Update-check delayed worker | `UpdateNotifier.lua` | Random-delay update check | `onResourceStart` | One-shot | Ends after check |

## 7) Lifecycle boundaries
- **Start:** resource load wires commands/events and starts background loops.
- **Runtime transitions:** join/leave/start/finish/checkpoint events transition entrant and race-instance state.
- **Stop:** client stop handlers clear UI/runtime data; server stop naturally drops in-memory state.

