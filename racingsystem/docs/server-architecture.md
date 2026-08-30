# Server Architecture

The racingsystem server is split into focused modules for lifecycle authority, persistence, synchronization, and access control.

## Module Overview

| Module | File | Purpose |
| --- | --- | --- |
| **Race Instances** | `server/race_instances.lua` | Creates instances, manages entrants, validates checkpoint progress, and owns lifecycle mutations. |
| **Synchronization Runtime** | `server/snapshot_runtime.lua` | Builds bounded public/catalog/joined-racer payloads and synchronizes flat entrant state bags. |
| **Race Parsing** | `server/race_parsing.lua` | Validates and parses custom and GTA Online race JSON. |
| **Race Repository** | `server/race_repository.lua` | Loads, saves, imports, and deletes race files. |
| **Race Catalog** | `server/race_catalog.lua` | Maintains the server-authoritative definition index. |
| **Event Handlers** | `server/event_handlers.lua` | Validates network requests and connects them to server-owned mutations. |
| **Logging & Access** | `server/logging_access.lua` | Performs ACE checks, lifecycle state transitions, and configured logging. |
| **State Store** | `server/state_store.lua` | Owns in-memory instances, catalog maps, revisions, and reliability counters. |
| **Runtime Threads** | `server/runtime_threads.lua` | Advances staging instances to running when countdowns expire. |
| **Server Entry** | `server/server.lua` | Initializes the server namespace. |

## Authority and Synchronization Boundaries

There is no universal race snapshot. Each state category has one owner and one replication path.

### Public active-instance discovery

`racingsystem:instance:list` is a complete replacement view containing only bounded summaries for `idle`, `staging`, and `running` instances. It has a server-owned monotonic revision and excludes checkpoints, assets, and entrant rows.

The server broadcasts it after instance-list mutations and sends the current revision without advancing it for explicit/initial requests.

### Race catalog

`racingsystem:catalog:definitions` is a complete replacement view generated from the server catalog. Catalog broadcasts are sent once per player because viewer permissions are target-specific.

The server emits it on initial state and after editor load/save, import, and delete mutations. Clients do not read `race_index.json`, `CustomRaces`, or `OnlineRaces` as runtime data sources.

### Joined-racer detail

A player receives joined-instance detail only after the server accepts invoke or join:

- `racingsystem:race:getRaceInfo` seeds identity, configuration, route data, runtime fields, and participant rows.
- `racingsystem:race:instanceAssets` sends props and model hides.
- Specialized targeted events retain lap, restart, teleport, notification, and checkpoint-result responsibilities.

These payloads are not periodically resent. Client membership changes load joined assets and unload them on exit.

### State bags

Flat state bags own hot replicated state:

| Key | Owner/content |
| --- | --- |
| `rs:instanceId` | Player's joined instance ID. |
| `rs:entrantId` | Stable entrant identity. |
| `rs:position` | Server-computed race position. |
| `rs:currentLap` | Current lap. |
| `rs:currentCheckpoint` | Next expected checkpoint. |
| `rs:finishedAt` | Server finish timestamp. |
| `rs:isAdmin` | ACE-derived admin status. |
| `GlobalState['rs:raceState:<instanceId>']` | Instance lifecycle state. |

Accepted checkpoint mutations publish standings immediately. Lap and total times are derived from server-owned start timestamps; checkpoint events do not accept client timing values. Join, leave, disconnect, restart, finish, kill, and resource cleanup update or clear the corresponding flat keys.

## Race Lifecycle

```text
catalog definition
       |
       v
invoke request --server validates--> instance created (idle)
       |                               |
       |                               +--> invoking player joined
       |                                    + targeted race info/assets
       v
countdown request --> staging --> running
                               |
                               +--> checkpoint mutations
                                    + immediate entrant state-bag updates
                               |
                               v
                         finish / leave / kill
                               |
                               +--> membership and runtime keys cleared
                               +--> public instance list replaced
```

Each active instance is stored in `RacingSystem.Server.State.raceInstancesById` and contains its route/configuration, owner, entrants, lifecycle state, traffic density, and late-join cutoff. A non-host disconnect removes that entrant and immediately republishes standings for survivors. A host disconnect or intentional host leave terminates every instance owned by that source and clears guest membership state so no orphaned owner remains.

## Late Join

A running race can accept a late join only while its leader remains within `lateJoinProgressLimitPercent`. The server recalculates eligibility and never trusts the client's discovery list as join authorization. An accepted late join inherits last-place progress and receives the same targeted joined-racer initialization as an ordinary join.

## Invoking a Race

The invoke handler accepts a definition identity and instance options:

- `name` / `lookupName`
- `sourceType` (`custom` or `online`)
- `raceId` for GTA Online races
- `trafficDensity`
- `lateJoinProgressLimitPercent`
- lap count as the second event argument

The server resolves the definition from its repository, rejects duplicate/invalid instances, creates the instance, and auto-joins the invoking player.

## ACE-Based Administration

`Config.adminAce` defaults to `racingsystem.admin`. The server rechecks ACE authorization for definition deletion and race termination regardless of client menu state. When `raceOwnerCanKillOwnedRace` is enabled, the server additionally permits only the matching instance owner to terminate that instance. Admin status is replicated through `rs:isAdmin`, while target-specific catalog payloads include viewer permissions for catalog controls.

## See Also

- [Overview](overview.md)
- [Configuration reference](configuration.md)
- [Race Data Format](race-format.md)
- [Runtime synchronization rework](runtime-sync-rework.md)
