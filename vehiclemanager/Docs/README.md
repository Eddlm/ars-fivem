# Vehicle Manager
- Requires `ScaleformUI_Assets` and. `ScaleformUI_Lua`.

## Interactions
- Can open and coordinate with `performancetuning` menu and state.
- Persists saved vehicle payloads server-side and re-applies tuning/entity state on load.

## How To Use
1. Start dependencies first, then start `vehiclemanager`.
2. Open the menu with `F5` (default mapping) and use save/load/customize actions.
3. Save a vehicle once to create a persistent slot, then updates are written back to that saved entry.
4. Use server commands `vm_save_inspect <saveId>` and `vm_save_delete <saveId>` for admin troubleshooting.

## Configuration Variables
| Path | Default | What it controls |
| --- | --- | --- |
| `menu.keybindCommand` | `"+vehiclemanager_menu"` | Command used for key mapping/menu open. |
| `menu.defaultKey` | `"F5"` | Default key binding for menu open. |
| `save.ownerIdentifierPrefixes` | `license/license2/fivem/steam/discord` | Identifier priority used for save ownership. |
| `appearance.*` | see file | Paint/xenon/color option lists and paint categories. |
| `categories.partsVehicleModCategories` | see file | Cosmetic mod categories shown in Parts menu. |
| `categories.statsVehicleModCategories` | see file | Performance-related mod categories in Stats menu. |
| `categories.wheelCategories` | see file | Wheel type categories shown in Wheels menu. |
| `constants.DOOR_MAPPING` | see file | Door mapping used for saved door state payloads. |
| `constants.TYRE_MAPPING` | see file | Tyre mapping used for saved tyre state payloads. |
| `constants.TUNING_SELECTION_SCHEMA` | see file | Serialization schema for tuning selection persistence. |
| `ui.menuXPosition` | `20` | Main menu horizontal position. |
| `ui.menuTitle` | `"Vehicle Manager"` | Main menu title. |
| `ui.menuSubtitle` | `"Fix, customize and save your vehicle"` | Main menu subtitle. |
| `ui.menuAvailabilityRefreshMs` | `200` | Refresh cadence for vehicle availability checks. |
| `ui.performanceSettingsPiOptions` | `{ "No", "Yes" }` | PI display options text. |
| `ui.performanceSettingsRevLimiterOptions` | `{ "Off", "On" }` | Rev limiter options text. |
| `ui.performanceSettingsSteeringLockModeOptions` | `{ "Stock", "Balanced", "Aggro", "Very Aggro", "Very Smooth", "Smooth" }` | Steering mode options text. |
| `ui.tuneStateBagKey` | `"performancetuning:tuneState"` | State bag key for tuning selections. |
| `ui.handlingStateBagKey` | `"performancetuning:handlingState"` | State bag key for handling state. |
| `ui.saveIdStateBagKey` | `"vehiclemanager:saveId"` | State bag key for save ID tracking. |
| `updateCheck.*` | see file | GitHub update check behavior and timeout settings. |

