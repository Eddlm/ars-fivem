# traffic_control

## Requirements
- No external dependency is required.
- Native traffic multipliers are applied clientside by this resource.

## Interactions
- `racingsystem` can request temporary traffic density while race participants are active.
- Other resources can also request/clear density through event or exports using request keys.

## How To Use
1. Start `traffic_control`.
2. Set startup baseline density with `setr tControlDefault <number>` (for example `0.0` or `1.0`).
3. Use `/trafficserver <density>` to broadcast a server request, or `/trafficserver clear` to clear that request.
4. From scripts, use `traffic_control:setMode` with numeric density and a stable request key; pass `nil` to clear.

## Configuration Variables
| Path | Default | What it controls |
| --- | --- | --- |
| `server.requestPrefix` | `'server:'` | Prefix used for server-scoped request keys. |
| `server.commandName` | `'trafficserver'` | Admin/server command name. |
| `defaultMode` | `'normal'` | Baseline profile used when no active requests exist. |
| `profiles.normal.*` | see file | Baseline profile values and persistent native toggles. |
| `profiles.none.*` | see file | No-traffic profile values. |
| `profiles.low.*` | see file | Low-traffic profile values. |
| `profiles.high.*` | see file | High-traffic profile values. |
| `profiles.full.*` | see file | Full-traffic profile values. |
| `legacyModeDensity.*` | see file | Legacy name-to-density map used for profile fallback logic. |
| `ConVar: tControlDefault` | `'1.0'` fallback | Startup baseline density override (`0.0..2.0`). |

