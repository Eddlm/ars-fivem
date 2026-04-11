# racingsystem

## Overview
- `racingsystem` is a client-server race management resource with a ScaleformUI menu front-end, editor tooling, and server-authoritative race lifecycle handling.
- The client runtime helpers live inside `client/client.lua`; there is no separate `client/util.lua` module in the current Lua layout.
- `client/menu.lua` owns menu construction and editor-facing UI flow, while `server/server.lua` owns race definitions, snapshots, and state transitions.

## Requirements
- Requires `ScaleformUI_Assets`.
- Requires `ScaleformUI_Lua`.

## Interactions
- Integrates with `traffic_control` by sending race-scoped traffic density requests while players are in races.
- Uses `ui/` NUI assets for URL/import and race-related UI flows.
- Loads `server/integrity.lua` only through `server/server.lua` during startup checks; it is not a direct server script entry in the manifest.

## Module Layout
| File | Role |
| --- | --- |
| `shared/Config.lua` | Shared tunable values used by client, menu, and server code. |
| `shared/shared.lua` | Shared state enum, trimming, and name-normalization helpers. |
| `client/client.lua` | `RacingSystemUtil` helper registrations, snapshot consumption, editor session handling, race runtime, checkpoints, teleport helpers, and cleanup. |
| `client/menu.lua` | ScaleformUI menu definitions, keybind entry points, and editor menu interaction. |
| `server/server.lua` | Authoritative race instance/state management, file IO, snapshot broadcasting, and gameplay event handling. |
| `server/integrity.lua` | Conditionally loaded integrity sweep logic. |
| `server/UpdateNotifier.lua` | Startup and manual update check flow. |

## How To Use
1. Start dependencies first, then start `racingsystem`.
2. Open Race Control with `F7` (default mapping) to host, join, or manage races.
3. Use Race Editor from the same menu to create/edit checkpoints and save race definitions.
4. During hosted races, selected traffic option is mapped to density and requested through `traffic_control`.
5. Use the update checker command from the server console if you want to compare the installed version against the upstream manifest.

## Runtime Flow
1. `fxmanifest.lua` loads shared config/helpers first, then the client menu/runtime scripts, then the server utilities and server authority module.
2. `client/menu.lua` opens the user-facing menu, routes keybinds, and triggers local or server events for host/join/editor actions.
3. `client/client.lua` consumes snapshots, drives HUD and runtime visuals, tracks the local entrant, and forwards checkpoint/race events to the server.
4. `server/server.lua` validates race mutations, persists race definitions, broadcasts snapshots/standings, and coordinates checkpoints, joins, starts, finishes, and cleanup.
5. `server/UpdateNotifier.lua` runs an on-start update check worker and also exposes `/rsupdatecheck` for manual checks.
6. `server/integrity.lua` is only loaded when the server-side integrity gate decides to run it, and it performs its own delayed sweep once loaded.

## Configuration Variables
| Path | Default | What it controls |
| --- | --- | --- |
| `checkpointDrawDistanceMeters` | `250.0` | Distance at which checkpoints/markers are drawn. |
| `markerTypeId` | `1` | Default GTA marker type for route checkpoints. |
| `visualCheckpointRadiusScale` | `2.0` | Visual scaling for rendered checkpoint radius. |
| `checkpointRadiusMinMeters` | `2.0` | Minimum checkpoint width/radius allowed in editor/runtime. |
| `checkpointRadiusMaxMeters` | `40.0` | Maximum checkpoint width/radius allowed in editor/runtime. |
| `minLapCount` | `1` | Minimum laps host can set. |
| `maxLapCount` | `10` | Maximum laps host can set. |
| `playerCanInvokeMultipleRaces` | `false` | Allows one player to host multiple active instances. |
| `raceOwnerCanKillOwnedRace` | `false` | Allows owner to kill own race instance without admin privileges. |
| `countdownMs` | `5000` | Countdown duration before race start. |
| `debugLogging` | `true` | Enables server/client debug logging pathways. |
| `adminAce` | `"racingsystem.admin"` | ACE permission required for admin actions. |
| `lateJoinProgressLimitPercent` | `50` | Default late-join cutoff for race progress. |
| `advanced.client.*` | see file | Client runtime tuning for checkpoint logic, markers, cones, and visuals. |
| `advanced.server.*` | see file | Server timing/scaling/retry and extra print tuning. |
| `advanced.menu.*` | see file | Menu title/layout/option tuning. |
| `updateCheck.*` | see file | GitHub update check behavior and timeout settings. |
