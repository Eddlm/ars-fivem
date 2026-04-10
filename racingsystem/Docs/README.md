# racingsystem

## Requirements
- Requires `ScaleformUI_Assets`.
- Requires `ScaleformUI_Lua`.

## Interactions
- Integrates with `traffic_control` by sending race-scoped traffic density requests while players are in races.
- Uses `ui/` NUI assets for URL/import and race-related UI flows.

## How To Use
1. Start dependencies first, then start `racingsystem`.
2. Open Race Control with `F7` (default mapping) to host, join, or manage races.
3. Use Race Editor from the same menu to create/edit checkpoints and save race definitions.
4. During hosted races, selected traffic option is mapped to density and requested through `traffic_control`.

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

