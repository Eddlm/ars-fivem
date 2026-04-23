# performancetuning

## Runtime

- Dependencies:
  - `ScaleformUI_Assets`
  - `ScaleformUI_Lua`
- `shared_script`: `shared/Config.lua`
- `client_scripts`: see `fxmanifest.lua`
- `server_scripts`:
  - `server/UpdateNotifier.lua`
  - `server/server.lua`

## Commands

- `+ptmenu`
  - Opens the performance tuning menu.
  - Key mapping is registered in `client/scaleformui_menus.lua`.
  - Default key is `F6` only when `vehiclemanager` is not started; otherwise no default key is bound.

- `/ptlaptimes [list|clear] [MODEL|all]`
  - Server command in `server/server.lua`.

## Exports

- `GetCurrentVehicle`
- `GetMaterialTyreGrip`
- `GetHandlingField`
- `SetHandlingField`
- `ResetHandlingField`
- `ResetAllHandling`
- `InferHandlingFieldType`
- `GetPerformancePanelMetrics`
- `DrawPerformanceIndexPanel`
- `DrawPerformanceIndexPanelInstance`
- `SetKeepPersonalPiPanelActive`
- `SetPanelDrawRequest`
- `ClearPanelDrawRequest`
- `OpenPerformanceTuningMenu`
- `GetPiDisplayModeIndex`
- `SetPiDisplayModeIndex`
- `GetPerformanceBarsDisplayMode`
- `SetPerformanceBarsDisplayMode`
- `GetCurrentVehicleRevLimiterEnabled`
- `SetCurrentVehicleRevLimiterEnabled`
- `GetCurrentVehicleSteeringLockMode`
- `SetCurrentVehicleSteeringLockMode`

## Used Convars

- `ars_skip_uptodate_print`
  - Read via: `GetConvarBool`
  - Effective default: `false`
  - Example: `setr ars_skip_uptodate_print true`

- `pt_engine_swaps`
  - Read via: `GetConvar`
  - Effective default: `''` (empty CSV)
  - Example: `setr pt_engine_swaps "dominator,gauntlet3,comet,vagner,nero"`

- `pt_nitrous_shot_cooldown_ms`
  - Read via: `GetConvarInt`
  - Effective default: `0`
  - Example: `setr pt_nitrous_shot_cooldown_ms 4000`
