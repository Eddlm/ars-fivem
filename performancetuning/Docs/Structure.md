# performancetuning — Structure

## 1) Runtime topology
- **Shared definitions/config:** `Config.lua`, `definitions.lua`, `configruntime.lua`.
- **Client domain modules:** handling, vehicle state, tuning packs, surface/material grip, nitrous, performance panel, menu/runtime bindings.
- **Client composition root:** `client.lua` wires exports, local events, and UI/PI update loops.
- **Server domain module:** `server.lua` stores diagnostics-related and stable-lap related data/events.
- **Server utility module:** `UpdateNotifier.lua` for update checks.

## 2) Client/server relationship
- Client is the primary runtime owner for live vehicle interaction, UI, and handling mutations.
- Server handles selected authoritative operations:
  - stable lap sample persistence
  - player scope/drop cleanup logic used by synchronization paths.
- Bidirectional communication uses explicit net events (`TriggerServerEvent`/`RegisterNetEvent`).

## 3) Conceptual role separation
- **Public API/export façade:** `client.lua` export surface.
- **Handling IO/caching:** `handlingmanager.lua`.
- **Per-vehicle state buckets:** `vehiclemanager.lua`.
- **Pack application and option resolution:** `tuningpackmanager.lua`.
- **UI metrics/rendering:** `performancepanel.lua`, `menusliders.lua`, `scaleformui_menus.lua`.
- **Cross-module wiring/helpers:** `runtimebindings.lua`.
- **Sync diagnostics/orchestration:** `syncorchestrator.lua`.
- **Grip/nitrous subsystems:** `surfacegrip.lua`, `material_tyre_grip.lua`, `nitrous.lua`.

## 4) Call tree (high-level)
1. `fxmanifest.lua` loads shared layer, then client scripts in ordered list, then server scripts.
2. Client load path initializes runtime tables and module interlinks.
3. `client.lua` registers exports and runtime event handlers.
4. UI and PI synchronization loops run continuously while resource is active.
5. User interactions route through menu + tuning modules into handling write/reset operations.
6. Selected operations dispatch to server for stable lap persistence.
7. Server responds with confirmation events.

## 5) State model
- **Vehicle bucket state:** per-vehicle tune/PI/handling-original cache containers.
- **UI state:** panel draw requests, display mode settings, nearby panel ownership flags.
- **Runtime integration state:** temporary synchronization queues/diagnostics counters in orchestrator.
- **Persistence state:** stable lap data document (`stable_laptimes.json`) managed server-side.

Ownership is split: interactive/live state mostly client-side; persistence and selected coordination on server.

## 6) Independent threads
| Thread | Where | Role | Start condition | Loop cadence | End condition |
|---|---|---|---|---|---|
| UI/vehicle refresh loops | `client.lua` | Refresh panel visuals and periodic PI state sync | Client script load | Mix of per-frame and throttled waits | Stop on resource unload |
| Nitrous runtime loops | `nitrous.lua` | Maintain shot timing/cleanup and control behavior | Client script load | Continuous loop(s), throttled by waits | Stop on resource unload |
| Surface grip monitor loop | `surfacegrip.lua` | Tracks and applies surface/material influence updates | Client script load | Continuous throttled loop | Stop on resource unload |
| Performance panel helper loops | `performancepanel.lua` | Maintain display state and panel draw orchestration | Client script load | Continuous loops with waits | Stop on resource unload |
| Sync orchestration worker loop(s) | `syncorchestrator.lua` | Handles deferred/immediate resync workflows | Client script load / event-triggered thread spawn | Event-driven + continuous maintenance loop | Stop on resource unload |
| Update-check delayed worker | `UpdateNotifier.lua` | Randomized delayed version check | `onResourceStart` | One-shot | Ends after check |

## 7) Lifecycle boundaries
- **Start:** ordered module load from `fxmanifest.lua` establishes internals and export surface.
- **Runtime:** events/exports drive tuning operations; threads maintain live UI/sync behavior.
- **Stop:** resource unload naturally stops loops; state will be reconstructed on next load.

## 8) Configuration and logging behavior
- `performancetuning` runtime does not currently read convars for tuning behavior or diagnostics verbosity.
- `UpdateNotifier.lua` uses hardcoded update-check configuration:
  - repo: `Eddlm/ars-fivem`
  - branch: `main`
  - path: `performancetuning`
  - token: empty by default
- Update checker logging is not runtime-configurable:
  - verbose update status logging is fixed off
  - only update-available notification is printed when a newer version is detected
- Manual update check entry point remains `/ptupdatecheck`; startup check still runs once after a randomized delay.

