# RacingSystem Resource Call Tree

**Purpose** – Server-authoritative race lifecycle with client menu/editor/HUD runtime and snapshot-driven synchronization.

---

## Entry Points
| File | Trigger | What it does |
|---|---|---|
| `fxmanifest.lua` | Resource load | Loads shared scripts, client scripts (`client/menu.lua`, `client/client.lua`), and server scripts (`server/UpdateNotifier.lua`, `server/server.lua`). |
| `client/menu.lua` | Client script load + keybind commands | Registers `+racemenu` / `-racemenu`, builds the ScaleformUI menus, and runs the editor helper thread. |
| `client/client.lua` | Client script load | Registers `RacingSystemUtil`, race-related net events/local events, snapshot handling, runtime loops, and cleanup. |
| `server/server.lua` | Server script load | Registers authoritative race net events and the maintenance loop; conditionally loads `integrity.lua` at startup via `runIntegrityScript()`. |
| `server/integrity.lua` | Conditionally executed by `server/server.lua` | Defines delayed integrity sweep behavior; execution is gated by the server integrity loader and primed once via the start hooks. |
| `server/UpdateNotifier.lua` | `onResourceStart` + command | Delayed/manual update check (`/rsupdatecheck`). |

---

## Module Overview
| Module | Responsibility |
|---|---|
| `client/client.lua` | Snapshot consumption, local utility registrations, race runtime state, checkpoint/reporting flow, local helper events, HUD/state loops. |
| `client/menu.lua` | Menu/editor input flow and local UI state orchestration. |
| `server/server.lua` | Race definition IO, invoke/join/start/checkpoint/finish/leave/kill authority, snapshot broadcasting. |
| `server/integrity.lua` | Integrity baseline/sweep logic loaded/executed by `server/server.lua` (not listed in `fxmanifest.lua` server scripts). |
| `Config.lua` | Shared admin-tunable configuration values for race behavior and advanced runtime knobs. |
| `shared.lua` | Shared state model helpers (`States`, trim/normalize/build snapshot helpers). |
| `server/UpdateNotifier.lua` | Update-check command/startup behavior (`/rsupdatecheck` and delayed startup check). |

---

## Call Hierarchy (Simplified)

```text
fxmanifest.lua
│
├─ client side
│   ├─ client/menu.lua
│   │   ├─ RegisterCommand('+racemenu') -> openRaceMenu()
│   │   ├─ RegisterCommand('-racemenu')
│   │   └─ CreateThread(...) editor checkpoint helper loop
│   │
│   └─ client/client.lua
│       ├─ RegisterNetEvent('racingsystem:stateSnapshot'|'startCountdown'|'lapCompleted'|...)
│       ├─ AddEventHandler('racingsystem:resetToLastCheckpoint'|'startRace'|'leaveRace'|'smartCheckpointTeleport')
│       ├─ CreateThread(...) runtime loops (snapshot upkeep, HUD/checkpoint/reporting, stale detection)
│       └─ AddEventHandler('onClientResourceStart'|'onClientResourceStop')
│
├─ server side
│   ├─ server/UpdateNotifier.lua
│   │   ├─ RegisterCommand('rsupdatecheck')
│   │   └─ AddEventHandler('onResourceStart') -> delayed performUpdateCheck()
│   │
│   └─ server/server.lua
│       ├─ RegisterNetEvent('racingsystem:requestState'|'invokeRace'|'joinRace'|'startRace'|...)
│       ├─ AddEventHandler('playerJoining'|'playerDropped')
│       ├─ CreateThread(...) maintenance loop
│       └─ runIntegrityScript() -> load/pcall('server/integrity.lua') [gated + probabilistic]
│
└─ server/integrity.lua
    ├─ AddEventHandler('onServerResourceStart')
    └─ queueIntegritySweep(...) -> delayed restoreBaseline(...)
```

---

## Key Runtime Flow
1. Client opens menu through `+racemenu`; selection actions trigger local events and/or server events.
2. `client/client.lua` consumes snapshots and updates local runtime (HUD, checkpoints, countdown, teleport helpers, editor state).
3. Server validates/mutates race state and broadcasts updated snapshots, standings, countdowns, and asset payloads.
4. Checkpoint passes and finish events are reported client→server; server validates, advances laps, and rebroadcasts authoritative updates.
5. `server/UpdateNotifier.lua` runs independently from the race lifecycle and can report version drift from the server console.
6. Lifecycle handlers clear/reset local state on resource stop/start.

---

## Accuracy Notes
- The client command surface is keybind-driven (`+racemenu` / `-racemenu`), not `/race` and `/raceadmin` in current code.
- Server event names are `racingsystem:*` (e.g., `racingsystem:invokeRace`, `racingsystem:checkpointPassed`), not generic `racingsystem:create`/`start`/`finish` aliases.
- RaceSystem no longer reads runtime convars for debug/locale toggles (`rSystemExtraPrints`, `locale`, `sv_locale`); those paths are hardcoded in current code.
- Verbose debug log helpers in `client/client.lua`, `client/menu.lua`, and `server/server.lua` are currently no-op functions; routine startup/debug banner prints are removed.
- Console output intentionally retained for non-debug operational signals:
  - update availability notice in `server/UpdateNotifier.lua`
  - explicit server error path via `logError(...)` in `server/server.lua`

