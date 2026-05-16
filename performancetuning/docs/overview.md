# Performance Tuning — Overview

Performance Tuning is a **ScaleformUI-based menu and runtime system** that lets players apply tuning packs, tweak handling parameters, view performance metrics, and manage nitrous. It writes live handling changes via GTA natives and syncs state across clients through entity state bags.

## What It Does

| Subsystem                       | Purpose                                                                                                                 |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| **Tuning Packs**                | Apply pre-built or custom tuning presets (engine stages, suspension, tyres, transmission, brakes, handbrakes, nitrous). |
| **Handling Manager**            | Read, write, format, and reset individual handling fields on live vehicles.                                             |
| **Dynamic Lateral Curve**       | Adjusts `fTractionCurveLateral` in real time based on front-tyre surface grip.                                          |
| **Performance Panel**           | Draws an on-screen performance index (PI) panel showing power, top speed, grip, and brake scores.                       |
| **Surface Grip**                | Maps GTA surface material IDs to per-tyre grip multipliers.                                                             |
| **Nitrous**                     | Manages nitrous availability, refill timers, shot dispatch, and visual effects.                                         |
| **Sync Orchestrator**           | Retries and reapplies tuning state across clients via state bags.                                                       |
| **Vehicle Manager Integration** | Tracks per-vehicle tuning buckets, caches handling values, and coordinates with the vehiclemanager resource.            |

## Quick Start

1. Ensure dependencies: `ensure ScaleformUI_Assets` and `ensure ScaleformUI_Lua` **before** performancetuning.
2. Add `ensure performancetuning` to your `server.cfg`.
3. Press **F6** (only when `vehiclemanager` is not running) or call the `OpenPerformanceTuningMenu` export to open the menu.

## Keybind

| Command   | Default                                    | Action                             |
| --------- | ------------------------------------------ | ---------------------------------- |
| `+ptmenu` | F6 (only if vehiclemanager is not running) | Opens the performance tuning menu. |

When `vehiclemanager` is running, performancetuning's menu is integrated into the vehicle manager menu instead, and no default key is bound.

## Exports

| Export                                                                      | Description                                             |
| --------------------------------------------------------------------------- | ------------------------------------------------------- |
| `GetCurrentVehicle`                                                         | Returns the player's current vehicle entity.            |
| `GetMaterialTyreGrip`                                                       | Returns grip multiplier for a surface material index.   |
| `GetHandlingField` / `SetHandlingField`                                     | Read/write a single handling field on a vehicle.        |
| `ResetHandlingField` / `ResetAllHandling`                                   | Reset one or all handling fields to original values.    |
| `InferHandlingFieldType`                                                    | Determine if a handling field is float, int, or vector. |
| `GetPerformancePanelMetrics`                                                | Returns PI metrics for the current vehicle.             |
| `DrawPerformanceIndexPanel`                                                 | Draws the PI panel for the specified vehicle.           |
| `OpenPerformanceTuningMenu`                                                 | Programmatically opens the tuning menu.                 |
| `GetPiDisplayModeIndex` / `SetPiDisplayModeIndex`                           | Get/set the PI display mode.                            |
| `GetPerformanceBarsDisplayMode` / `SetPerformanceBarsDisplayMode`           | Get/set how performance bars are shown.                 |
| `GetCurrentVehicleRevLimiterEnabled` / `SetCurrentVehicleRevLimiterEnabled` | Get/set rev limiter state.                              |
| `GetCurrentVehicleSteeringLockMode` / `SetCurrentVehicleSteeringLockMode`   | Get/set steering lock mode.                             |

## Dependencies

| Dependency           | Purpose                                   |
| -------------------- | ----------------------------------------- |
| `ScaleformUI_Assets` | UI framework assets.                      |
| `ScaleformUI_Lua`    | Lua ScaleformUI bindings for all menu UI. |

## File Layout

```
performancetuning/
  fxmanifest.lua
  shared/Config.lua                — Pack definitions, PI distribution, slider ranges, UI config
  client/
    client.lua                     — Main loop, state management, feature coordination
    definitions.lua                — Handling field metadata and constants
    configruntime.lua              — Config normalization and slider range merging
    handlingmanager.lua            — Read/write/reset handling fields
    vehiclemanager.lua             — Per-vehicle tuning tracking, caching, statebag sync
    tuningpackmanager.lua          — Apply tuning packs and tweak values
    material_tyre_grip.lua         — Surface material → grip multiplier mapping
    surfacegrip.lua                — Public API for material grip lookup
    DynamicCurveLateral.lua        — Live lateral traction adjustment
    menusliders.lua                — ScaleformUI slider value builders
    performancepanel.lua           — PI panel computation and rendering
    nitrous.lua                    — Nitrous shot, refill, and visual system
    syncorchestrator.lua           — State bag retry and reapplication
    runtimebindings.lua            — Wires state and ScaleformUI across modules
    scaleformui_menus.lua          — Full menu hierarchy construction
    utils.lua                      — Shared helpers
  server/
    server.lua                     — Server-side lap times, engine swaps convar
    UpdateNotifier.lua             — Version checker
```

## See Also

- [Configuration reference](configuration.md)
- [Tuning Packs](tuning-packs.md)
- [Performance Panel](performance-panel.md)
- [Nitrous](nitrous.md)
- [Update Notifier](update-notifier.md)
