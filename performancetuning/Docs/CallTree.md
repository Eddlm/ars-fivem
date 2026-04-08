# Performancetuning Resource Call Tree

**Purpose** – Client/server tuning system with live handling edits, PI/performance UI, nitrous/surface helpers, and diagnostics/state sync tooling.

---

## Entry Points
| File | Trigger | What it does |
|---|---|---|
| `fxmanifest.lua` | Resource load | Loads shared modules, ordered client modules, server modules, and exports list. |
| `client.lua` | Client script load | Registers exports, commands (`/ptune`, `/ptbarsmode`, `/ptdiag`), net events, and core runtime loops. |
| `server.lua` | Server script load | Registers persistence/diagnostic net events and server command (`/ptlaptimes`). |
| `syncorchestrator.lua` | Client script load + net event | Handles `performancetuning:requestVehicleResync` and runs orchestration worker loop. |
| `UpdateNotifier.lua` | `onResourceStart` + command | Delayed/manual update check (`/ptupdatecheck`). |

---

## Module Overview
| Module | Responsibility |
|---|---|
| `client.lua` | Runtime composition root, export surface, commands, and event bridge wiring. |
| `handlingmanager.lua` | Typed handling field read/write/reset + original value caching. |
| `vehiclemanager.lua` | Vehicle-bucket state ownership and sync helpers. |
| `tuningpackmanager.lua` | Tune pack definitions/application and menu context resolution. |
| `performancepanel.lua` | PI/performance metrics and panel draw pipeline. |
| `surfacegrip.lua` + `material_tyre_grip.lua` | Surface/material grip lookup and runtime updates. |
| `nitrous.lua` | Nitrous shot lifecycle helpers and supporting loops. |
| `syncorchestrator.lua` | Deferred/immediate resync and diagnostics transport. |
| `runtimebindings.lua` | Shared utility binding layer between modules. |
| `server.lua` | Stable-lap storage, diagnostics dispatch, player scope/drop handling. |
| `UpdateNotifier.lua` | Version check command/startup flow. |

---

## Call Hierarchy (Simplified)

```text
fxmanifest.lua
│
├─ client-side load order
│   ├─ shared/runtime definitions (shared.lua, definitions.lua, configruntime.lua)
│   ├─ domain modules (handling/vehicle/tuning/surface/nitrous/panel/sync)
│   └─ client.lua
│       ├─ exports(...): public API for other resources
│       ├─ RegisterCommand('ptune'|'ptbarsmode'|'ptdiag')
│       ├─ RegisterNetEvent('performancetuning:serverDiagnostics')
│       ├─ RegisterNetEvent('performancetuning:stableLapStored')
│       ├─ RegisterNetEvent('racingsystem:stableLapTime') -> TriggerEvent('performancetuning:stableLapTime')
│       └─ CreateThread(...) core runtime loops
│
├─ additional client worker modules
│   ├─ nitrous.lua -> CreateThread(...) x2
│   ├─ performancepanel.lua -> CreateThread(...) x2
│   ├─ surfacegrip.lua -> CreateThread(...)
│   └─ syncorchestrator.lua -> CreateThread(...) + event-spawned thread
│
├─ server.lua
│   ├─ RegisterNetEvent('performancetuning:registerTunedVehicle')
│   ├─ RegisterNetEvent('performancetuning:storeStableLapSample')
│   ├─ RegisterNetEvent('performancetuning:requestServerDiagnostics')
│   ├─ AddEventHandler('playerEnteredScope'|'playerLeftScope'|'playerDropped')
│   └─ RegisterCommand('ptlaptimes')
│
└─ UpdateNotifier.lua
    ├─ RegisterCommand('ptupdatecheck')
    └─ AddEventHandler('onResourceStart') -> delayed performUpdateCheck()
```

---

## Key Runtime Flow
1. Player opens tuning UI via `/ptune`.
2. Menu actions route through tuning/vehicle/handling managers.
3. Handling writes update live vehicle behavior and cached original values.
4. UI/performance panel + grip/nitrous loops keep runtime displays and effects updated.
5. Diagnostics requested from client (`/ptdiag`) are served via server round-trip events.
6. Stable-lap snapshots are submitted to server and persisted in `stable_laptimes.json`.

---

## Accuracy Notes
- This resource contains **multiple `CreateThread(...)` loops outside `client.lua`** (`nitrous.lua`, `performancepanel.lua`, `surfacegrip.lua`, `syncorchestrator.lua`).
- `fxmanifest.lua` currently declares ScaleformUI dependencies; it does **not** declare `customphysics` as a `dependency` entry.
