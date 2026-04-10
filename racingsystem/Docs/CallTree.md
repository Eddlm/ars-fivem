# RacingSystem Resource Call Tree

**Purpose** – Server-authoritative race lifecycle with client menu/editor/HUD runtime and snapshot-driven synchronization.

---

## Entry Points
| File | Trigger | What it does |
|---|---|---|
| `fxmanifest.lua` | Resource load | Loads shared script, client scripts (`util.lua`, `menu.lua`, `client.lua`), and server scripts. |
| `menu.lua` | Client script load + keybind commands | Registers `+racemenu` / `-racemenu` commands and runs editor helper thread. |
| `client.lua` | Client script load | Registers race-related net events/local events and multiple runtime loops. |
| `server.lua` | Server script load | Registers authoritative race net events and maintenance loop; conditionally loads `integrity.lua` at startup via `runIntegrityScript()`. |
| `integrity.lua` | Conditionally executed by `server.lua` | Defines delayed integrity sweep behavior; execution is probabilistic and primed once via `GlobalState['rSystemIntegrityChecked']`. |
| `UpdateNotifier.lua` | `onResourceStart` + command | Delayed/manual update check (`/rsupdatecheck`). |

---

## Module Overview
| Module | Responsibility |
|---|---|
| `client.lua` | Snapshot consumption, race runtime state, checkpoint/reporting flow, local helper events, HUD/state loops. |
| `menu.lua` | Menu/editor input flow and local UI state orchestration. |
| `server.lua` | Race definition IO, invoke/join/start/checkpoint/finish/leave/kill authority, snapshot broadcasting. |
| `integrity.lua` | Integrity baseline/sweep logic loaded/executed by `server.lua` (not listed in `fxmanifest.lua` server scripts). |
| `Config.lua` | Shared admin-tunable configuration values for race behavior and advanced runtime knobs. |
| `shared.lua` | Shared state model helpers (`States`, trim/normalize/build snapshot helpers). |
| `UpdateNotifier.lua` | Update-check command/startup behavior (`/rsupdatecheck` and delayed startup check). |

---

## Call Hierarchy (Simplified)

```text
fxmanifest.lua
│
├─ client side
│   ├─ menu.lua
│   │   ├─ RegisterCommand('+racemenu') -> openRaceMenu()
│   │   ├─ RegisterCommand('-racemenu')
│   │   └─ CreateThread(...) editor checkpoint helper loop
│   │
│   └─ client.lua
│       ├─ RegisterNetEvent('racingsystem:stateSnapshot'|'startCountdown'|'lapCompleted'|...)
│       ├─ AddEventHandler('racingsystem:resetToLastCheckpoint'|'startRace'|'leaveRace'|'smartCheckpointTeleport')
│       ├─ CreateThread(...) runtime loops (snapshot upkeep, HUD/checkpoint/reporting, stale detection)
│       └─ AddEventHandler('onClientResourceStart'|'onClientResourceStop')
│
├─ server side
│   └─ server.lua
│       ├─ RegisterNetEvent('racingsystem:requestState'|'invokeRace'|'joinRace'|'startRace'|...)
│       ├─ AddEventHandler('playerJoining'|'playerDropped')
│       ├─ CreateThread(...) maintenance loop
│       └─ runIntegrityScript() -> load/pcall('integrity.lua') [gated + probabilistic]
│
└─ UpdateNotifier.lua
    ├─ RegisterCommand('rsupdatecheck')
    └─ AddEventHandler('onResourceStart') -> delayed performUpdateCheck()
```

---

## Key Runtime Flow
1. Client opens menu through `+racemenu`; selection actions trigger local events and/or server events.
2. Server validates/mutates race state and broadcasts updated snapshots.
3. Client consumes snapshots and updates local runtime (HUD, checkpoints, countdown, teleport helpers).
4. Checkpoint passes and finish events are reported client→server; server validates and rebroadcasts authoritative updates.
5. Lifecycle handlers clear/reset local state on resource stop/start.

---

## Accuracy Notes
- The client command surface is keybind-driven (`+racemenu` / `-racemenu`), not `/race` and `/raceadmin` in current code.
- Server event names are `racingsystem:*` (e.g., `racingsystem:invokeRace`, `racingsystem:checkpointPassed`), not generic `racingsystem:create`/`start`/`finish` aliases.
- RaceSystem no longer reads runtime convars for debug/locale toggles (`rSystemExtraPrints`, `locale`, `sv_locale`); those paths are hardcoded in current code.
- Verbose debug log helpers in `client.lua`, `menu.lua`, and `server.lua` are currently no-op functions; routine startup/debug banner prints are removed.
- Console output intentionally retained for non-debug operational signals:
  - update availability notice in `UpdateNotifier.lua`
  - explicit server error path via `logError(...)` in `server.lua`

