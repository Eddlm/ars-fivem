# VehicleManager Resource Call Tree

**Purpose** - Menu/runtime for vehicle save/load flows with server-side JSON persistence and optional `performancetuning` integration.

---

## Entry Points
| File | Trigger | What it does |
|---|---|---|
| `fxmanifest.lua` | Resource load | Loads `Config.lua`, `client/vehiclemanager.lua`, `UpdateNotifier.lua`, and `server/vehicle_saves.lua`. |
| `client/vehiclemanager.lua` | Client script load | Builds the menu, registers commands and net events, and starts refresh/worker threads. |
| `server/vehicle_saves.lua` | Server script load | Registers save/load/delete/update net events and admin maintenance commands. |
| `UpdateNotifier.lua` | `onResourceStart` + command | Runs the delayed/manual update check (`/vmupdatecheck`, server console). |

---

## Module Overview
| Module | Responsibility |
|---|---|
| `client/vehiclemanager.lua` | Menu/UI flow, vehicle inspection, spawn/load orchestration, save snapshot requests, and performancetuning handoff. |
| `server/vehicle_saves.lua` | Save index management, JSON payload persistence under `savedvehicles/`, ownership validation, and admin inspection/delete commands. |
| `Config.lua` | Labels, categories, state bag keys, menu defaults, and update-check settings. |
| `UpdateNotifier.lua` | GitHub version check using the configured repo, branch, path, token, and timeout. |

---

## Call Hierarchy (Simplified)

```text
fxmanifest.lua
│
├─ client/vehiclemanager.lua
│  ├─ RegisterCommand(MenuConfig.keybindCommand or '+vehiclemanager_menu')
│  ├─ RegisterCommand(MENU_KEYBIND_RELEASE_COMMAND)
│  ├─ RegisterNetEvent('performancetuning:menuClosed')
│  ├─ RegisterNetEvent('vehiclemanager:receiveSavedVehicleIndex')
│  ├─ RegisterNetEvent('vehiclemanager:receiveSavedVehiclePayload')
│  ├─ RegisterNetEvent('vehiclemanager:vehicleSnapshotUpdated')
│  ├─ RegisterNetEvent('vehiclemanager:vehicleSaved')
│  ├─ CreateThread(...) availability refresh loop
│  └─ CreateThread(...) one-shot spawn, autosave, and utility workers
│
├─ server/vehicle_saves.lua
│  ├─ RegisterNetEvent('vehiclemanager:saveVehicle')
│  ├─ RegisterNetEvent('vehiclemanager:requestSavedVehicleIndex')
│  ├─ RegisterNetEvent('vehiclemanager:requestSavedVehiclePayload')
│  ├─ RegisterNetEvent('vehiclemanager:forgetSavedVehicle')
│  ├─ RegisterNetEvent('vehiclemanager:updateSavedVehicleSnapshot')
│  ├─ RegisterCommand('vm_save_inspect')
│  └─ RegisterCommand('vm_save_delete')
│
└─ UpdateNotifier.lua
   ├─ RegisterCommand('vmupdatecheck')
   └─ AddEventHandler('onResourceStart') -> delayed performUpdateCheck() (3-6 min delay)
```

---

## Key Runtime Flow
1. Player opens the menu with the mapped `+vehiclemanager_menu` command or `F5` by default.
2. The client requests a saved index when the Save / Load submenu opens.
3. Selecting a saved entry requests the payload from the server.
4. The server validates the owner, reads the JSON file from `savedvehicles/`, and returns the payload.
5. The client spawns the saved vehicle, reapplies tuning and appearance state, and refreshes the menu.
6. When tuning changes occur, the client schedules a delayed snapshot update back to the server.
7. If `performancetuning` is running, `performancetuning:menuClosed` returns the user to the vehicle manager menu.

---

## Accuracy Notes
- This resource does not expose exports for other scripts to call.
- The client entry file is `client/vehiclemanager.lua`, not a root-level `client.lua`.
- Server saves are grouped by owner and stored as `savedvehicles/<owner>_<saveId>.json`, with indexes stored as `savedvehicles/index_<owner>.json`.
- `UpdateNotifier.lua` uses hardcoded GitHub repository settings from `Config.updateCheck` and does not depend on runtime convars.
