# RacingSystem Resource Call Tree

**Purpose** – Server-authoritative race lifecycle with client menu/editor/HUD runtime and snapshot-driven synchronization.

---

## Entry Points
| File | Trigger | What it does |
|---|---|---|
| `fxmanifest.lua` | Resource load | Loads shared script, client scripts (`util.lua`, `menu.lua`, `client.lua`), and server scripts. |
| `menu.lua` | Client script load + keybind commands | Registers `+racemenu` / `-racemenu` commands and runs editor helper thread. |
| `client.lua` | Client script load | Registers race-related net events/local events and multiple runtime loops. |
| `server.lua` | Server script load | Registers authoritative race net events and maintenance loop. |
| `integrity.lua` | Server script load | Hooks server resource start for integrity sweep scheduling. |
| `UpdateNotifier.lua` | `onResourceStart` + command | Delayed/manual update check (`/rsupdatecheck`). |

---

## Module Overview
| Module | Responsibility |
|---|---|
| `client.lua` | Snapshot consumption, race runtime state, checkpoint/reporting flow, local helper events, HUD/state loops. |
| `menu.lua` | Menu/editor input flow and local UI state orchestration. |
| `server.lua` | Race definition IO, invoke/join/start/checkpoint/finish/leave/kill authority, snapshot broadcasting. |
| `integrity.lua` | Integrity baseline/sweep logic for race data. |
| `shared.lua` | Shared constants/config/state model helpers. |
| `UpdateNotifier.lua` | Update-check command/startup behavior. |

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
│   ├─ integrity.lua -> AddEventHandler('onServerResourceStart')
│   └─ server.lua
│       ├─ RegisterNetEvent('racingsystem:requestState'|'invokeRace'|'joinRace'|'startRace'|...)
│       ├─ AddEventHandler('playerJoining'|'playerDropped')
│       └─ CreateThread(...) maintenance loop
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

