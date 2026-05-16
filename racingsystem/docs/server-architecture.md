# Server Architecture

The racingsystem server is split into focused modules that handle race lifecycle, data persistence, and admin control.

## Module Overview

| Module               | File                          | Lines | Purpose                                                         |
| -------------------- | ----------------------------- | ----- | --------------------------------------------------------------- |
| **Race Instances**   | `server/race_instances.lua`   | ~632  | Creating, starting, and managing race instances.                |
| **Snapshot Runtime** | `server/snapshot_runtime.lua` | ~1041 | Per-entrant progress tracking, checkpoint counting, lap timing. |
| **Race Parsing**     | `server/race_parsing.lua`     | ~688  | Validation and parsing of race JSON payloads.                   |
| **Race Repository**  | `server/race_repository.lua`  | ~516  | File I/O for saving and loading race JSON.                      |
| **Race Catalog**     | `server/race_catalog.lua`     | ~329  | In-memory index of all known races.                             |
| **Event Handlers**   | `server/event_handlers.lua`   | ~645  | Network event handlers (client ↔ server).                       |
| **Logging & Access** | `server/logging_access.lua`   | ~295  | Admin ACE checks, verbose/debug logging.                        |
| **State Store**      | `server/state_store.lua`      | ~95   | Global state container for active race instances.               |
| **Runtime Threads**  | `server/runtime_threads.lua`  | ~65   | Background server threads (timeouts, cleanup).                  |
| **Server Entry**     | `server/server.lua`           | ~12   | Resource startup and initialisation.                            |

## Race Lifecycle

```
  ┌───────────┐
  │  Edit/     │
  │  Select    │
  └─────┬─────┘
        │
        ▼
  ┌───────────┐    save     ┌──────────────┐
  │  Invoke    │────────────►│ Repository   │
  │  Race      │             │ (JSON files) │
  └─────┬─────┘             └──────────────┘
        │
        ▼
  ┌───────────┐    register ┌──────────────┐
  │  Instance  │────────────►│ Catalog      │
  │  Created   │             │ (in-memory)  │
  └─────┬─────┘             └──────────────┘
        │
        ▼
  ┌───────────┐
  │  Countdown │  (5 s default)
  └─────┬─────┘
        │
        ▼
  ┌───────────┐     checkpoint     ┌───────────────┐
  │  Racing    │───────────────────►│ Snapshot      │
  │  Active    │◄──────────────────│ Runtime       │
  └─────┬─────┘    progress sync   └───────────────┘
        │
        ▼
  ┌───────────┐
  │  Finish / │
  │  DNF       │
  └───────────┘
```

## Key Concepts

### Race Instances

A race instance is created when a player invokes a race. It contains:

- The race definition (checkpoints, props).
- The owner (player who started it).
- Entrants (players who joined).
- Runtime state (started, finished, lap counts).
- Traffic density and late-join settings.

Each instance is stored in `RacingSystem.Server.State.raceInstancesById`.

### Snapshot Runtime

Each entrant has a **snapshot** that tracks:

- Current checkpoint index.
- Lap count.
- Finish time.
- Last checkpoint time.
- Progress percentage (for late-join eligibility).

Snapshots are reset when a race restarts and updated on each checkpoint pass.

### Race Catalog

The catalog is an in-memory index of all races (custom and online). It's loaded from `race_index.json` at startup and rebuilt as races are saved or deleted.

### Late Join

Players can join an in-progress race if:

1. The race allows late joins.
2. The race progress is below `lateJoinProgressLimitPercent` (default 50%).
3. The race has not been finished by all entrants.

### Invoking a Race

The invoke flow accepts either:

- A **string** race name (looked up in the catalog).
- A **table** payload with full invoke options:
  - `name` / `lookupName` — race display name and normalised name.
  - `sourceType` — `"custom"` or `"online"`.
  - `raceId` — Rockstar ID for online races.
  - `trafficDensity` or `trafficMode` — traffic level (`none`, `low`, `high`, `full`, or explicit 0.0–1.0).
  - `lateJoinProgressLimitPercent` — late join cutoff.

### ACE-Based Admin

The `Config.adminAce` value (`"racingsystem.admin"` by default) is checked against the player's ACE group. Admins can:

- Force-delete races from the catalog.
- View verbose logs when `debugLogging` is enabled.
- Access admin-only menu options.

## See Also

- [Configuration reference](configuration.md)
- [Race Data Format](race-format.md)
