# Performancetuning Resource Call Tree

**Purpose** - Client/server tuning system with live handling edits, PI/performance UI, nitrous, surface grip, and diagnostics/state sync tooling.

---

## Entry Points
| File | Trigger | What it does |
|---|---|---|
| `fxmanifest.lua` | Resource load | Loads shared config, ordered client scripts, server scripts, and exports. |
| `client/client.lua` | Client script load | Registers exports, relays stable-lap events, and runs the steering-lock / PI sync loops. |
| `client/scaleformui_menus.lua` | Client script load + menu command | Builds the menu tree, binds `+ptmenu`, and exposes menu open/close/process helpers. |
| `client/performancepanel.lua` | Client script load | Runs the panel draw and nearby-vehicle scan loops. |
| `client/nitrous.lua` | Client script load | Runs nitrous, refill, and rev-limiter loops. |
| `client/surfacegrip.lua` | Client script load | Runs the surface grip monitor loop. |
| `client/syncorchestrator.lua` | Client script load + net event | Handles `performancetuning:requestVehicleResync` and its maintenance loop. |
| `server/server.lua` | Server script load | Stores stable-lap records, handles scope cleanup, and exposes `/ptlaptimes`. |
| `server/UpdateNotifier.lua` | `onResourceStart` + command | Runs the delayed/manual update check (`/ptupdatecheck`). |

---

## Module Overview
| Module | Responsibility |
|---|---|
| `shared/Config.lua` | User config surface for packs, sliders, PI weights, and update checks. |
| `definitions.lua` | Static handling metadata, pack keys, and state bag names. |
| `configruntime.lua` | Normalized runtime config derived from the shared config. |
| `runtimebindings.lua` | Wires config, internals, helpers, and ScaleformUI services together. |
| `client.lua` | Composition root, export surface, and stable-lap relay. |
| `handlingmanager.lua` | Handling field read/write/parse/format helpers. |
| `vehiclemanager.lua` | Per-vehicle bucket ownership, serialization, and statebag sync. |
| `tuningpackmanager.lua` | Tune-pack resolution and application logic. |
| `menusliders.lua` | Slider ranges, indices, and labels. |
| `scaleformui_menus.lua` | Menu construction, selection handling, and native menu processing. |
| `performancepanel.lua` | PI metrics, panel draw pipeline, and nearby-vehicle scanning. |
| `surfacegrip.lua` | Material grip lookup and live traction adjustment. |
| `material_tyre_grip.lua` | Material index to grip multiplier table. |
| `nitrous.lua` | Nitrous shot execution, refill, and rev limiter. |
| `syncorchestrator.lua` | Resync queueing, statebag handling, and retry logic. |
| `server.lua` | Stable-lap persistence and player-scope coordination. |
| `UpdateNotifier.lua` | Version check command and startup worker. |

---

## Call Hierarchy (Simplified)

```text
fxmanifest.lua
│
├─ shared config/load order
│   ├─ shared/Config.lua
│   ├─ client/definitions.lua
│   └─ client/configruntime.lua
│
├─ client composition root
│   └─ client/client.lua
│       ├─ exports(...) public API for other resources
│       ├─ RegisterNetEvent('racingsystem:stableLapTime') -> TriggerEvent('performancetuning:stableLapTime')
│       ├─ AddEventHandler('performancetuning:stableLapTime') -> TriggerServerEvent('performancetuning:storeStableLapSample')
│       └─ CreateThread(...) steering-lock adaptation + steering-lock apply + PI sync
│
├─ client feature modules in manifest order
│   ├─ client/handlingmanager.lua -> handling parse/read/write helpers
│   ├─ client/vehiclemanager.lua -> state buckets and sync helpers
│   ├─ client/tuningpackmanager.lua -> pack application and tune state mutation
│   ├─ client/surfacegrip.lua -> surface grip monitor loop
│   ├─ client/menusliders.lua -> slider helpers and labels
│   ├─ client/performancepanel.lua -> panel draw + nearby scan loops
│   ├─ client/runtimebindings.lua -> final wiring of internals and shared state
│   ├─ client/nitrous.lua -> nitrous and rev-limiter loops
│   ├─ client/syncorchestrator.lua -> resync handler + maintenance loop
│   └─ client/scaleformui_menus.lua -> menu construction, command binding, and frame processing
│
├─ menu and display path
│   └─ client/scaleformui_menus.lua
│       ├─ openMainMenu() / closeMenu() / processFrame()
│       └─ menu selection callbacks into tuning pack and slider helpers
│
├─ runtime wiring
│   └─ client/runtimebindings.lua
│       ├─ builds PerformanceTuning._state / _internals / ScaleformUI bindings
│       └─ exposes helpers to later modules
│
├─ vehicle effect paths
│   ├─ client/nitrous.lua -> triggerShotIfAvailable() / refillAvailability() / updateRevLimiter()
│   ├─ client/surfacegrip.lua -> updateLiveSurfaceLateral()
│   └─ client/performancepanel.lua -> drawPanel() / drawPanelInstance() / nearby scan loop
│
├─ sync path
│   └─ client/syncorchestrator.lua
│       ├─ RegisterNetEvent('performancetuning:requestVehicleResync')
│       ├─ AddStateBagChangeHandler(...)
│       └─ CreateThread(...) pending resync + tracked-vehicle maintenance
│
├─ server path
│   └─ server/server.lua
│       ├─ RegisterNetEvent('performancetuning:registerTunedVehicle')
│       ├─ RegisterNetEvent('performancetuning:storeStableLapSample')
│       ├─ AddEventHandler('playerEnteredScope'|'playerLeftScope'|'playerDropped')
│       └─ RegisterCommand('ptlaptimes')
│
└─ update path
    └─ server/UpdateNotifier.lua
        ├─ RegisterCommand('ptupdatecheck')
        └─ AddEventHandler('onResourceStart') -> delayed performUpdateCheck()
```

---

## Key Runtime Flow
1. Resource starts and the manifest loads the shared config, then the client modules, then the server modules.
2. Runtime bindings wire shared state and menu helpers into `PerformanceTuning`.
3. The player opens the tuning UI from `+ptmenu` or via the exported menu API.
4. Menu selections route through `scaleformui_menus.lua` into `tuningpackmanager.lua` and `vehiclemanager.lua`.
5. Handling writes and statebag sync update the live vehicle and notify the server when needed.
6. `performancepanel.lua`, `nitrous.lua`, and `surfacegrip.lua` keep the live effects and UI current.
7. Stable-lap snapshots flow from `racingsystem` into `client.lua`, then into `server.lua`, which persists `stable_laptimes.json`.

---

## Accuracy Notes
- `performancetuning` has multiple client threads outside `client.lua`:
  - `nitrous.lua`
  - `performancepanel.lua`
  - `surfacegrip.lua`
  - `syncorchestrator.lua`
- `fxmanifest.lua` declares `ScaleformUI_Assets` and `ScaleformUI_Lua`; it does not declare `customphysics` as a dependency.
- `nitrous.lua` owns the nitrous shot, refill, and rev-limiter behavior directly.
- `UpdateNotifier.lua` uses the shared `updateCheck` config with defaults for repo, branch, path, token, and timeout.
- `UpdateNotifier.lua` prints only when an update is available unless verbose logging is enabled in config.
- The manual update command remains `/ptupdatecheck`.
