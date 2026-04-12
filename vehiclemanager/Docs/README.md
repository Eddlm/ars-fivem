# Vehicle Manager
Standalone vehicle save/load and customization menu built on `ScaleformUI_Lua`, with optional integration for `performancetuning`.

## Dependencies
- `ScaleformUI_Assets`
- `ScaleformUI_Lua`
- `performancetuning` for the tuning bridge and state sync

## What It Does
- Opens the vehicle manager menu from `F5` by default.
- Lets players fix, teleport, delete, save, load, and customize vehicles.
- Persists saved vehicles server-side under `savedvehicles/`.
- Keeps tuning state in sync when `performancetuning` is running.
- Performs a manual or delayed update check through `UpdateNotifier.lua`.

## Main Flow
1. `client/vehiclemanager.lua` builds the menu, registers commands and net events, and keeps local vehicle state in sync.
3. `server/vehicle_saves.lua` validates ownership, reads and writes JSON payloads, and returns saved indexes or payloads.
4. `UpdateNotifier.lua` checks the GitHub manifest version on startup or when `/vmupdatecheck` is run from the console.
5. If `performancetuning` is present, the client can hand off to that menu and then return to `vehiclemanager`.

## How To Use
1. Start `ScaleformUI_Assets`, `ScaleformUI_Lua`, and `vehiclemanager`.
2. Start `performancetuning` if you want the tuning integration.
3. Press `F5` or use the mapped `+vehiclemanager_menu` command to open the menu.
4. Use `Save / Load` to manage persistent vehicle entries.
5. Use `/vm_save_inspect <saveId>` and `/vm_save_delete <saveId>` for admin troubleshooting.

