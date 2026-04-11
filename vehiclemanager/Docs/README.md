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
1. `Config.lua` loads shared labels, categories, state bag names, and update-check settings.
2. `client/vehiclemanager.lua` builds the menu, registers commands and net events, and keeps local vehicle state in sync.
3. `server/vehicle_saves.lua` validates ownership, reads and writes JSON payloads, and returns saved indexes or payloads.
4. `UpdateNotifier.lua` checks the GitHub manifest version on startup or when `/vmupdatecheck` is run from the console.
5. If `performancetuning` is present, the client can hand off to that menu and then return to `vehiclemanager`.

## How To Use
1. Start `ScaleformUI_Assets`, `ScaleformUI_Lua`, and `vehiclemanager`.
2. Start `performancetuning` if you want the tuning integration.
3. Press `F5` or use the mapped `+vehiclemanager_menu` command to open the menu.
4. Use `Save / Load` to manage persistent vehicle entries.
5. Use `/vm_save_inspect <saveId>` and `/vm_save_delete <saveId>` for admin troubleshooting.

## Configuration Variables
| Path | Default | What it controls |
| --- | --- | --- |
| `menu.keybindCommand` | `"+vehiclemanager_menu"` | Command used for the menu keybind. |
| `menu.defaultKey` | `"F5"` | Default key binding for opening the menu. |
| `save.ownerIdentifierPrefixes` | `license/license2/fivem/steam/discord` | Identifier priority used to resolve save ownership. |
| `appearance.*` | see file | Paint, xenon, and color option lists plus paint categories. |
| `categories.partsVehicleModCategories` | see file | Cosmetic mod categories shown in Parts. |
| `categories.statsVehicleModCategories` | see file | Performance-related mod categories shown in Stats. |
| `categories.wheelCategories` | see file | Wheel families shown in Wheels. |
| `constants.DOOR_MAPPING` | see file | Door mapping used in saved vehicle payloads. |
| `constants.TYRE_MAPPING` | see file | Tyre mapping used in saved vehicle payloads. |
| `constants.TUNING_SELECTION_SCHEMA` | see file | Tuning serialization schema used by server persistence. |
| `ui.menuXPosition` | `20` | Main menu horizontal position. |
| `ui.menuTitle` | `"Vehicle Manager"` | Main menu title. |
| `ui.menuSubtitle` | `"Fix, customize and save your vehicle"` | Main menu subtitle. |
| `ui.menuAvailabilityRefreshMs` | `200` | Refresh cadence for vehicle availability checks. |
| `ui.performanceSettingsPiOptions` | `{ "No", "Yes" }` | PI display options in the tuning submenu. |
| `ui.performanceSettingsRevLimiterOptions` | `{ "Off", "On" }` | Rev limiter options in the tuning submenu. |
| `ui.performanceSettingsSteeringLockModeOptions` | `{ "Stock", "Balanced", "Aggro", "Very Aggro", "Very Smooth", "Smooth" }` | Steering mode options exposed by config. |
| `ui.tuneStateBagKey` | `"performancetuning:tuneState"` | State bag key for tuning selections. |
| `ui.handlingStateBagKey` | `"performancetuning:handlingState"` | State bag key for handling state. |
| `ui.saveIdStateBagKey` | `"vehiclemanager:saveId"` | State bag key for save ID tracking. |
| `updateCheck.*` | see file | GitHub update-check repository, branch, path, token, verbosity, and timeout settings. |
