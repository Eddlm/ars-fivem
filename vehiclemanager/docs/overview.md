# Vehicle Manager — Overview

Vehicle Manager is a **ScaleformUI-based menu** resource that lets players fix, customize, and save vehicles in-game. It integrates with **performancetuning** for tuning packs and state bag persistence.

## What It Does

| Feature                | Description                                                                                                                                  |
| ---------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| **Vehicle Fixes**      | Instantly repair vehicle damage, tyres, doors, and wash the vehicle.                                                                         |
| **Customization**      | Change paint (classic, metallic, matte, util, worn, metal, chrome), wheels, xenon headlights, neon kits, window tint, plate style, and more. |
| **Mod Menus**          | Browse and apply visual mods (spoilers, bumpers, exhausts, etc.) and stat upgrades (engine, brakes, transmission, suspension, armor).        |
| **Persistence**        | Save and load complete vehicle states (mods, colours, tuning, extras, tyres, doors) to per-player JSON files on the server.                  |
| **Performance Tuning** | Integration bridge to performancetuning's tuning packs via state bags.                                                                       |

## Quick Start

1. Ensure dependencies are loaded: `ensure ScaleformUI_Assets` and `ensure ScaleformUI_Lua` **before** vehiclemanager.
2. Add `ensure vehiclemanager` to your `server.cfg`.
3. Press **F6** (configurable) in a vehicle to open the menu.

## Keybind

| Command                | Default Key | Action                          |
| ---------------------- | ----------- | ------------------------------- |
| `+vehiclemanager_menu` | `F6`        | Opens the vehicle manager menu. |
| `-vehiclemanager_menu` | (release)   | Key mapping release command.    |

The default key is set via `Config.menu.defaultKey`. A planned convar (`vm_default_key`) will allow server-level override.

## Commands

| Command                     | Scope  | Description                                                   |
| --------------------------- | ------ | ------------------------------------------------------------- |
| `/vm_save_inspect <saveId>` | Server | Prints a summary of the specified save to the calling player. |
| `/vm_save_delete <saveId>`  | Server | Deletes the specified save for the calling player.            |

## Dependencies

| Dependency           | Purpose                                           |
| -------------------- | ------------------------------------------------- |
| `ScaleformUI_Assets` | UI framework assets.                              |
| `ScaleformUI_Lua`    | Lua ScaleformUI bindings used to build all menus. |

## File Layout

```
vehiclemanager/
  fxmanifest.lua           — Resource descriptor
  Config.lua                — Menu config, colour tables, categories, constants, UI labels
  client/
    vehiclemanager.lua      — Main menu assembly, keybind, autosave loop
    customization.lua       — Paint, wheels, xenon, neon, window tint, livery menus
    modmenus.lua            — Visual mod + stat upgrade menus
    persistence.lua         — Save/load/apply vehicle state, server events
  server/
    vehicle_saves.lua       — Server-side save file I/O, index management, commands
  UpdateNotifier.lua        — Version checker
  savedvehicles/            — Per-player save files (JSON)
```

## See Also

- [Configuration reference](configuration.md)
- [Persistence](persistence.md)
- [Update Notifier](update-notifier.md)
