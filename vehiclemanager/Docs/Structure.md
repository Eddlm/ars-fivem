# vehiclemanager - Structure

## 1) Runtime Topology
- **Shared config layer:** `Config.lua` defines labels, categories, bag keys, and update-check settings.
- **Client runtime/UI layer:** `client/vehiclemanager.lua` owns the menu, vehicle inspection, save/load flow, customization, and performancetuning integration.
- **Server persistence layer:** `server/vehicle_saves.lua` owns JSON file storage, save indexes, ownership checks, and admin maintenance commands.
- **Update utility layer:** `UpdateNotifier.lua` performs the delayed and manual version check.
- **Manifest wiring:** `fxmanifest.lua` loads the config, client script, server scripts, and ScaleformUI dependency in the expected order.

## 2) Client/Server Relationship
- The client handles interaction, menu state, and vehicle capture/restoration.
- The server is authoritative for saved data stored under `savedvehicles/`.
- Communication is event-driven through `vehiclemanager:*` net events.
- Client save IDs and tuning state are mirrored with state bags so the tuning bridge can persist correctly.

## 3) Conceptual Role Separation
- **Menu construction and runtime helpers:** `client/vehiclemanager.lua`
- **Persistence and file IO contract:** `server/vehicle_saves.lua`
- **Config defaults and lookup tables:** `Config.lua`
- **Version checking and operator alerts:** `UpdateNotifier.lua`

## 4) Call Tree at a Glance
1. `fxmanifest.lua` loads `Config.lua`, `client/vehiclemanager.lua`, `UpdateNotifier.lua`, and `server/vehicle_saves.lua`.
2. The client registers the menu commands, net events, and its refresh/worker threads.
3. Player actions request a saved index, payload, or snapshot update from the server.
4. The server validates ownership, reads or writes JSON files, and sends response events back to the client.
5. The client rebuilds menus, spawns saved vehicles, or updates tuning and save-state mirrors.
6. `UpdateNotifier.lua` runs a delayed startup check or a manual console check.

## 5) State Model
- **Client transient state:** menu visibility, selected vehicle state, pending overwrite confirmation, tuning autosave timers, and cached menu entries.
- **Server persisted state:** per-owner index files and vehicle payload files in `savedvehicles/`.
- **Integration state:** tuning and handling state bags, plus the save ID bag used to keep `performancetuning` and `vehiclemanager` in sync.

Authority boundary: the server owns persisted storage truth, while the client owns interaction and temporary UI state.

## 6) Independent Threads
| Thread | Where | Role | Start condition | Loop cadence | End condition |
|---|---|---|---|---|---|
| Availability refresh loop | `client/vehiclemanager.lua` | Keeps vehicle availability and driver-seat state fresh for the menu | Client script load | Every `ui.menuAvailabilityRefreshMs` (200 ms by default) | Stops on resource unload |
| Spawn/network worker threads | `client/vehiclemanager.lua` | Waits for network ownership and performs one-shot vehicle spawn/load steps | Spawn/load actions | One-shot | Ends when the action completes or times out |
| Tuning autosave worker threads | `client/vehiclemanager.lua` | Delays a snapshot update after tuning changes | Tuning menu actions | One-shot with a 6000 ms delay | Ends after the save request fires or is superseded |
| Delayed update-check worker | `UpdateNotifier.lua` | Runs the startup version check after a random delay | `onResourceStart` for this resource | One-shot, 3 to 6 minutes after start | Ends after check |

## 7) Lifecycle Boundaries
- **Start:** config loads, menu items are built, handlers register, and the client availability loop begins.
- **Runtime:** menu actions drive server persistence, tuning sync, and vehicle restoration.
- **Observability:** normal persistence paths stay quiet, while admin commands and update checks print user-facing feedback only when needed.
- **Stop/restart:** client state resets naturally; persisted JSON files remain on disk under `savedvehicles/`.
