# Racing System — Overview

Racing System is a full-featured **client-server racing framework** built on ScaleformUI. It lets players create, edit, invoke, and spectate races with checkpoints, laps, late joins, traffic control, and live leaderboards.

## What It Does

| Feature             | Description                                                                                            |
| ------------------- | ------------------------------------------------------------------------------------------------------ |
| **Race Editor**     | In-game checkpoint editor with pitch controls, checkpoint sizing, and race saving.                     |
| **Race Invocation** | Host a race from saved or GTA Online race definitions with lap count, traffic, and late-join settings. |
| **Race Runtime**    | Checkpoint detection, progress tracking, lap counting, and leaderboard during a race.                  |
| **Spectator Mode**  | Free-fly camera that follows race entrants. Toggle with `/spec`.                                       |
| **Teleport**        | Teleport to race start locations or checkpoints.                                                       |
| **Late Join**       | Allow players to join an in-progress race up to a configurable progress percentage.                    |
| **Traffic Control** | Request traffic density during races (none/low/high/full) via the traffic_control resource.            |
| **Race Catalog**    | Server-side repository of saved races with index-based lookup.                                         |
| **UGC Import**      | Import GTA Online race definitions by Rockstar ID.                                                     |

## Quick Start

1. Ensure dependencies: `ensure ScaleformUI_Assets` and `ensure ScaleformUI_Lua` **before** racingsystem.
2. Add `ensure racingsystem` to your `server.cfg`.
3. Press **F7** to open the Race Control menu, or use the `+racemenu` command.

## Commands

| Command     | Default Key | Action                               |
| ----------- | ----------- | ------------------------------------ |
| `+racemenu` | `F7`        | Opens the race control menu.         |
| `-racemenu` | (release)   | Key mapping release command.         |
| `/spec`     | —           | Toggle spectator mode during a race. |

## Convars

| Convar                    | Type | Default | Example                             | Description                                         |
| ------------------------- | ---- | ------- | ----------------------------------- | --------------------------------------------------- |
| `ars_skip_uptodate_print` | bool | `false` | `setr ars_skip_uptodate_print true` | Suppress update notifier's "Up to date" message.    |
| `rSystemPrintLevel`       | int  | `0`     | `setr rSystemPrintLevel 2`          | Print verbosity. `0` = normal, `2` = verbose debug. |

## Dependencies

| Dependency           | Purpose                                   |
| -------------------- | ----------------------------------------- |
| `ScaleformUI_Assets` | UI framework assets.                      |
| `ScaleformUI_Lua`    | Lua ScaleformUI bindings for all menu UI. |

## File Layout

```
racingsystem/
  fxmanifest.lua
  shared/
    Config.lua                  — All tuneable parameters
    shared.lua                  — Shared utilities and constants
  client/
    client.lua                  — Main client loop, checkpoint detection, race state
    menu.lua                    — ScaleformUI menu construction
    RaceEditor.lua              — In-game race editor
    InRace.lua                  — Race runtime client logic (checkpoints, leaderboard)
    Spectator.lua               — Spectator camera system
    Teleport.lua                — Teleport to race locations
    util.lua                    — Client utility functions
  server/
    server.lua                  — Server entry point
    race_instances.lua          — Race lifecycle management
    snapshot_runtime.lua        — Per-entrant progress tracking
    race_parsing.lua             — Race data validation and parsing
    race_repository.lua          — Race save/load from JSON files
    race_catalog.lua             — In-memory race index
    event_handlers.lua           — Network event handlers
    logging_access.lua           — Admin logging and access control
    state_store.lua               — Global state management
    runtime_threads.lua          — Background server threads
    UpdateNotifier.lua            — Version checker
  ui/
    index.html, app.js, style.css  — NUI race editor UI
  CustomRaces/                   — Player-created race JSON files
  OnlineRaces/                   — Imported GTA Online race JSON files
  race_index.json                — Master catalog of all known races
```

## See Also

- [Configuration reference](configuration.md)
- [Race Data Format](race-format.md)
- [Server Architecture](server-architecture.md)
- [Update Notifier](update-notifier.md)
