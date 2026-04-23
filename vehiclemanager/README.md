# vehiclemanager

## Runtime

- Dependencies:
  - `ScaleformUI_Assets`
  - `ScaleformUI_Lua`
- `shared_script`: `Config.lua`
- `client_scripts`: see `fxmanifest.lua`
- `server_scripts`:
  - `UpdateNotifier.lua`
  - `server/vehicle_saves.lua`
- Save files path:
  - `savedvehicles/*.json`

## Commands

- `+vehiclemanager_menu`
  - Opens/closes the Vehicle Manager menu.
  - Default key mapping comes from `Config.lua` (`menu.defaultKey`, default `F6`).

- `-vehiclemanager_menu`
  - Release command for key mapping.

- `/vm_save_inspect <saveId>`
  - Server command to print a save summary for the caller.

- `/vm_save_delete <saveId>`
  - Server command to remove a saved vehicle for the caller.

## Used Convars

- `ars_skip_uptodate_print`
  - Read via: `GetConvarBool`
  - Effective default: `false`
  - Example: `setr ars_skip_uptodate_print true`
