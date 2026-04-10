# vehiclemanager — Structure

## 1) Runtime topology
- **Shared config/constants layer:** `Config.lua`.
- **Client service/UI layer:** `client/vehiclemanager.lua` owns menu, spawned vehicle interaction, save/load UX, and integration hooks.
- **Server persistence layer:** `server/vehicle_saves.lua` handles save index, payload storage, deletion, and update events.
- **Server utility layer:** `UpdateNotifier.lua` handles delayed/manual update checks.
- **Logging/config posture:** no resource convar surface is used for debug logging in current runtime; server-side `logVm(...)` is intentionally silent, while update-check behavior is configured via hardcoded values inside `UpdateNotifier.lua`.

## 2) Client/server relationship
- Client drives interaction and requests persistence operations.
- Server is authoritative for saved-vehicle file operations and persistence events.
- Communication is event-based (`vehiclemanager:*` net events); client receives success/index/payload updates.

## 3) Conceptual role separation
- **Vehicle UX + runtime helpers:** `client/vehiclemanager.lua`
- **Persistence and file IO contract:** `server/vehicle_saves.lua`
- **Config/state defaults and tables:** `Config.lua`
- **Operational maintenance:** `UpdateNotifier.lua`

## 4) Call tree (high-level)
1. `fxmanifest.lua` loads shared script, client script, then server scripts.
2. Client registers keybind/menu commands and event handlers for save index/payload/ack flows.
3. Player action (save/load/delete/update snapshot) triggers corresponding server event.
4. Server validates input, performs file operation, and emits response/update events.
5. Client updates menu/runtime state from server responses.
6. Update notifier runs independently at startup delay or manual command trigger (`vmupdatecheck`, server console).

## 5) State model
- **Client transient state:** menu visibility, pending overwrite IDs, return-to-customize flags, current vehicle availability and spawned-vehicle utility state.
- **Server persisted state:** save index + per-vehicle JSON payloads under `savedvehicles/`.
- **Integration state:** bridges with `performancetuning` for customization/tune continuity when available.

Authority boundary: server owns persisted storage truth; client owns local interaction state.

## 6) Independent threads
| Thread | Where | Role | Start condition | Loop cadence | End condition |
|---|---|---|---|---|---|
| Spawn/network wait workers | `client/vehiclemanager.lua` | Asynchronous waits for network-ready vehicles and transitions during spawn/load flows | Spawn/load action creates worker thread | One-shot thread per action | Ends when operation completes/times out |
| Availability/refresh monitor loop | `client/vehiclemanager.lua` | Periodically refreshes vehicle/menu availability state | Client script load | Continuous throttled loop | Stops on resource unload |
| Update-check delayed worker | `UpdateNotifier.lua` | Random-delay startup version check (3-6 minutes) | `onResourceStart` for this resource | One-shot | Ends after check |

## 7) Lifecycle boundaries
- **Start:** command/event registration and availability monitor begin on client load.
- **Runtime:** menu actions drive server persistence operations and client refresh updates.
- **Observability:** regular persistence paths do not emit debug console logs; chat feedback is used for user-facing admin save commands, and update notifier prints only when an update is detected (or if verbosity is enabled in code).
- **Stop/restart:** transient client state resets naturally on reload; persisted files remain server-side.

