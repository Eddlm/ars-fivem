# performancetuning - Structure

## 1) Runtime topology
- **Shared config layer:** `shared/Config.lua`.
- **Shared metadata layer:** `client/definitions.lua`.
- **Runtime config normalization:** `client/configruntime.lua`.
- **Cross-module binding layer:** `client/runtimebindings.lua`.
- **Client composition root:** `client/client.lua`.
- **Client feature modules:** `handlingmanager.lua`, `vehiclemanager.lua`, `tuningpackmanager.lua`, `menusliders.lua`, `scaleformui_menus.lua`, `performancepanel.lua`, `surfacegrip.lua`, `material_tyre_grip.lua`, `nitrous.lua`, `syncorchestrator.lua`.
- **Server modules:** `server/server.lua` and `server/UpdateNotifier.lua`.
- **External UI dependency:** `ScaleformUI_Lua` is loaded before the menu code and provides the menu primitives the resource builds on.

## 2) Client/server relationship
- Client owns the live tuning UX, vehicle mutation, local state buckets, and most periodic loops.
- Server owns:
  - stable-lap PI persistence in `stable_laptimes.json`
  - player scope bookkeeping for resync requests
  - the `/ptlaptimes` command
- The two sides communicate through explicit events:
  - `TriggerServerEvent('performancetuning:registerTunedVehicle', ...)`
  - `TriggerServerEvent('performancetuning:storeStableLapSample', ...)`
  - `TriggerClientEvent('performancetuning:requestVehicleResync', ...)`
  - `RegisterNetEvent(...)` / `AddEventHandler(...)`

## 3) Conceptual role separation
- **Public API/export facade:** `client.lua`.
- **Handling IO and parsing:** `handlingmanager.lua`.
- **Per-vehicle state buckets and statebag sync:** `vehiclemanager.lua`.
- **Pack definitions and tune application:** `tuningpackmanager.lua`.
- **Menu slider math and labels:** `menusliders.lua`.
- **Menu assembly and input handling:** `scaleformui_menus.lua`.
- **PI metrics and panel rendering:** `performancepanel.lua`.
- **Surface/material grip lookup and runtime adjustment:** `material_tyre_grip.lua`, `surfacegrip.lua`.
- **Nitrous and rev limiter behavior:** `nitrous.lua`.
- **Resync queueing and repair loops:** `syncorchestrator.lua`.
- **Shared runtime wiring:** `runtimebindings.lua`.
- **Server persistence and update notification:** `server.lua`, `UpdateNotifier.lua`.

## 4) Call tree (high-level)
1. `fxmanifest.lua` loads `shared/Config.lua`, then the ordered client scripts, then the server scripts.
2. `client/definitions.lua` and `client/configruntime.lua` establish the static metadata and runtime config values.
3. `client/runtimebindings.lua` connects config, helpers, and module references into `PerformanceTuning._internals`, `PerformanceTuning._state`, and `PerformanceTuning.ScaleformUI`.
4. `client/client.lua` registers exports and relays `racingsystem:stableLapTime` into the server persistence path.
5. `client/scaleformui_menus.lua` builds the menu tree and routes selection changes back into tuning pack application.
6. `client/vehiclemanager.lua` serializes tune state and pushes it into entity state bags, which then feed the sync orchestrator.
7. `client/performancepanel.lua`, `client/surfacegrip.lua`, `client/nitrous.lua`, and `client/syncorchestrator.lua` run their respective maintenance loops while the resource is active.
8. `server/server.lua` stores PI records, handles scope cleanup, and requests resyncs when tuned vehicles or players change visibility.
9. `server/UpdateNotifier.lua` checks the configured GitHub branch/path on startup or when `/ptupdatecheck` is used.

## 5) State model
- **Vehicle bucket state:** per-vehicle tune state, original handling snapshots, and cached last-applied tune/PI values.
- **UI state:** menu items, slider values, panel draw requests, display modes, and nearby-panel caches.
- **Runtime integration state:** tracked vehicle keys, resync queues, and local auth windows for statebag updates.
- **Persistence state:** stable lap records stored server-side in `stable_laptimes.json`.

Ownership is mostly client-side for interactive state, with server-side ownership for persistence and resync coordination.

## 6) Independent threads
| Thread | Where | Role | Start condition | Loop cadence | End condition |
|---|---|---|---|---|---|
| Steering-lock adaptation loop | `client/client.lua` | Samples speed and updates steering lock targets | Client script load | 50-250 ms adaptive wait | Stop on resource unload |
| Steering-lock application loop | `client/client.lua` | Smoothly writes steering lock changes | Client script load | `Wait(0)` | Stop on resource unload |
| PI sync loop | `client/client.lua` | Periodically syncs vehicle PI state | Client script load | `Wait(500)` | Stop on resource unload |
| Nitrous control loop | `client/nitrous.lua` | Disables the nitrous control while a shot is active | Client script load | `Wait(0)` while active, `Wait(100)` otherwise | Stop on resource unload |
| Nitrous refill loop | `client/nitrous.lua` | Recharges nitrous when stationary | Client script load | `Wait(500)` | Stop on resource unload |
| Rev-limiter loop | `client/nitrous.lua` | Triggers shot input handling and rev limiter enforcement | Client script load | `Wait(0)` while driving, `Wait(250)` when idle | Stop on resource unload |
| Surface grip monitor loop | `client/surfacegrip.lua` | Updates and restores tire lateral grip | Client script load | `Wait(500)` | Stop on resource unload |
| Nearby vehicle scan loop | `client/performancepanel.lua` | Populates the nearby vehicle cache for PI panel rendering | Client script load | `Wait(0)` | Stop on resource unload |
| Panel/process loop | `client/performancepanel.lua` | Processes menu frame state and draws active panels | Client script load | `Wait(0)` | Stop on resource unload |
| Immediate resync thread(s) | `client/syncorchestrator.lua` | Applies queued resyncs and statebag changes | Event-triggered and client load | One-shot + `Wait(0)` per queued apply | Stop on resource unload |
| Sync maintenance loop | `client/syncorchestrator.lua` | Walks tracked vehicles and pending resyncs | Client script load | `Wait(250)` | Stop on resource unload |
| Update-check worker | `server/UpdateNotifier.lua` | Delayed startup update check | `onResourceStart` | One-shot delayed thread | Ends after the check |

## 7) Lifecycle boundaries
- **Start:** the manifest loads config, metadata, bindings, features, and server modules in a fixed order.
- **Runtime:** menu events, exports, and statebag updates drive the tuning flow while the loops keep panels, nitrous, and sync current.
- **Stop:** all threads terminate with the resource and the live state is reconstructed on the next start.

## 8) Configuration and logging behavior
- `performancetuning` supports selected convars for runtime tuning inputs (for example `pt_engine_swaps` for engine swap model sourcing).
- `UpdateNotifier.lua` reads its repo/branch/path/token/timeout from the shared `updateCheck` config, with defaults for:
  - repo: `Eddlm/ars-fivem`
  - branch: `main`
  - path: `performancetuning`
  - token: empty by default
- Update logging is intentionally minimal:
  - verbose status logging only appears when configured
  - the normal path prints only when an update is available
- The manual update entry point remains `/ptupdatecheck`.

