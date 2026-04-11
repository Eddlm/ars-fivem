# racingsystem — Structure

## 1) Runtime topology
- **Shared configuration layer:** `Config.lua` defines admin-tunable settings used by both sides.
- **Shared model/helper layer:** `shared.lua` defines shared state/helper functions used by both sides.
- **Client runtime layer:** `client/client.lua` holds `RacingSystemUtil`, snapshot consumption, editor session state, local prediction, checkpoint handling, teleport helpers, and cleanup.
- **Client interaction layer:** `client/menu.lua` handles the ScaleformUI menu, keybind entry point, and editor UI flow.
- **Server authority layer:** `server/server.lua` owns race definitions, instances, entrant membership, progression validation, and lifecycle decisions.
- **Server integrity layer:** `server/integrity.lua` defines integrity sweep behavior and is conditionally loaded by `server/server.lua` (`runIntegrityScript()`), not directly listed in `fxmanifest.lua` server scripts.
- **Server utility layer:** `server/UpdateNotifier.lua` provides update-check behavior.

## 2) Client/server relationship
- Server is authoritative for race lifecycle (create/invoke/join/start/checkpoint/finish/leave/kill).
- Client performs local UX logic (menu/editor/HUD/countdown handling, local convenience events), then forwards authoritative actions to server.
- Snapshot/event model keeps clients synchronized with server-maintained instance state.

## 3) Conceptual role separation
- **Menu/editor UX role:** `client/menu.lua`.
- **Live race HUD + local runtime role:** `client/client.lua`.
- **Authoritative race state + file IO role:** `server/server.lua`.
- **Validation/integrity policy role:** `server/integrity.lua`.
- **Shared config role:** `Config.lua`.
- **Shared enums/helpers role:** `shared.lua`.
- **Update check role:** `server/UpdateNotifier.lua`.

## 4) Call tree (high-level)
1. `fxmanifest.lua` loads shared scripts first, then the client UI/runtime scripts, then the server update checker and authority scripts.
2. `client/menu.lua` registers `+racemenu` / `-racemenu`, builds the menu tree, and routes host/join/editor actions through local or server events.
3. `client/client.lua` registers race-related net events and local events, consumes snapshots and standings, manages editor/runtime state, and runs the main draw/update loops.
4. `server/server.lua` registers authoritative race events, loads/saves race definitions, broadcasts snapshots/standings, and advances race lifecycle state.
5. `server/UpdateNotifier.lua` runs a delayed startup check and also supports the manual `/rsupdatecheck` command.
6. `server/integrity.lua` is only executed through the server-side integrity loader and performs its own queued sweep once started.

## 5) State model
- **Server authoritative state:** race definitions index, active race instances, entrant progress, ownership, countdown/start state.
- **Client replicated/runtime state:** latest snapshot cache, local prediction/progress helpers, HUD/menu/editor transient state.
- **Asset cache state:** instance asset payloads sent by server and retained client-side for rendering/use.

Authority boundary: server mutates truth; client mirrors and presents it, with some local-only helper state.

## 6) Independent threads
| Thread | Where | Role | Start condition | Loop cadence | End condition |
|---|---|---|---|---|---|
| Editor helper loop | `client/menu.lua` | Moves grabbed checkpoints and draws editor helper visuals | Client script load | Continuous loop with waits | Stops on resource unload |
| Client runtime loops (multiple) | `client/client.lua` | Snapshot upkeep, HUD refresh, checkpoint/pass handling, stale detection, race runtime updates | Client script load | Mix of per-frame and throttled waits | Stops on resource unload |
| Server maintenance loop | `server/server.lua` | Periodic server-side upkeep for race instances/runtime maintenance | Server script load | Continuous loop with waits | Stops on resource unload |
| Update-check delayed worker | `server/UpdateNotifier.lua` | Random-delay update check | `onResourceStart` | One-shot | Ends after check |
| Integrity sweep worker | `server/integrity.lua` | Delayed integrity baseline sweep | `onServerResourceStart` plus initial queue | One-shot/queued retry | Ends after baseline print |

## 7) Lifecycle boundaries
- **Start:** resource load wires commands/events and starts background loops.
- **Integrity start path:** during server startup, `server/server.lua` may `load/pcall` `server/integrity.lua` once per process gate (`GlobalState['rSystemIntegrityChecked']`) and only when the integrity roll passes.
- **Runtime transitions:** join/leave/start/finish/checkpoint events transition entrant and race-instance state.
- **Stop:** client stop handlers clear UI/runtime data; server stop naturally drops in-memory state.

## 8) Logging and Configurability (Current)
- RaceSystem currently does not use runtime convars for debug verbosity or locale selection (`rSystemExtraPrints`, `locale`, `sv_locale` are not read).
- Debug helper loggers in `client/client.lua`, `client/menu.lua`, and `server/server.lua` are intentionally silent (no-op) in normal flow.
- Non-debug operational console output that remains:
  - update availability notice from `server/UpdateNotifier.lua`
  - explicit error output from `server/server.lua` `logError(...)`

