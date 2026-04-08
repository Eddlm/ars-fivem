# VehicleManager Resource Call Tree

**Purpose** – Client menu/runtime for vehicle save/load flows with server-side JSON persistence and optional performancetuning integration.

---

## Entry Points
| File | Trigger | What it does |
|---|---|---|
| `fxmanifest.lua` | Resource load | Loads `shared.lua`, client script (`client/vehiclemanager.lua`), server script (`server/vehicle_saves.lua`), and update notifier. |
| `client/vehiclemanager.lua` | Client script load | Registers keybind commands, net event handlers, and availability/update worker loops. |
| `server/vehicle_saves.lua` | Server script load | Registers save/load/delete/update net events and admin inspection commands. |
| `UpdateNotifier.lua` | `onResourceStart` + command | Runs delayed/manual update check (`/vmupdatecheck`). |

---

## Module Overview
| Module | Responsibility |
|---|---|
| `client/vehiclemanager.lua` | UI/menu flow, spawn/load orchestration, performancetuning bridge handling, client-side state refresh loops. |
| `server/vehicle_saves.lua` | Save index management and vehicle JSON payload persistence under `savedvehicles/`. |
| `shared.lua` | Config/constants used by client runtime. |
| `UpdateNotifier.lua` | Version-check command/startup logic. |

---

## Call Hierarchy (Simplified)

```text
fxmanifest.lua
│
├─ client/vehiclemanager.lua
│   ├─ RegisterCommand(MenuConfig.keybindCommand or '+vehiclemanager_menu')
│   ├─ RegisterCommand(MENU_KEYBIND_RELEASE_COMMAND)
│   ├─ RegisterNetEvent('vehiclemanager:receiveSavedVehicleIndex')
│   ├─ RegisterNetEvent('vehiclemanager:receiveSavedVehiclePayload')
│   ├─ RegisterNetEvent('vehiclemanager:vehicleSnapshotUpdated')
│   ├─ RegisterNetEvent('vehiclemanager:vehicleSaved')
│   ├─ RegisterNetEvent('performancetuning:menuClosed')
│   ├─ CreateThread(...) action workers (spawn/network/fade/update helpers)
│   └─ CreateThread(...) availability refresh loop
│
├─ server/vehicle_saves.lua
│   ├─ RegisterNetEvent('vehiclemanager:saveVehicle')
│   ├─ RegisterNetEvent('vehiclemanager:requestSavedVehicleIndex')
│   ├─ RegisterNetEvent('vehiclemanager:requestSavedVehiclePayload')
│   ├─ RegisterNetEvent('vehiclemanager:forgetSavedVehicle')
│   ├─ RegisterNetEvent('vehiclemanager:updateSavedVehicleSnapshot')
│   ├─ RegisterCommand('vm_save_inspect')
│   └─ RegisterCommand('vm_save_delete')
│
└─ UpdateNotifier.lua
    ├─ RegisterCommand('vmupdatecheck')
    └─ AddEventHandler('onResourceStart') -> delayed performUpdateCheck()
```

---

## Key Runtime Flow
1. Player opens menu using configured keybind command (`+vehiclemanager_menu` by default).
2. Client requests saved index/payload over `vehiclemanager:*` net events.
3. Server validates and reads/writes JSON files, then responds with index/payload/ack events.
4. Client applies spawn/load logic and updates menu/runtime state.
5. If performancetuning is involved, close/open handoff is handled via `performancetuning:menuClosed` integration event.

---

## Accuracy Notes
- This resource does **not** expose the `performancetuning`-style bucket exports described in the previous version of this document.
- Client entry file is `client/vehiclemanager.lua` (not root `client.lua`).
- Runtime includes multiple thread workers in client script, including a persistent availability refresh loop.

