# Payload System (As-Is Before Teardown)

This document captures the original snapshot/payload model used by `racingsystem` before removal.

## 1) Server Payload Roots

- Root state namespace: `RacingSystem.Server.State`
- Key tables relevant to payload replication:
1. `raceInstancesById` (instanceId -> instance model)
2. `raceInstanceIdsByName` (normalized race name -> instanceId)
3. `knownRaceDefinitionsByName` (catalog index)
4. `instanceStaticHashByInstanceAndTarget` (per-target static signature cache)
5. `reliabilityCounters` (stale/illegal/etc counters)
6. `nextRaceInstanceId`

### Instance model (server-held)
- Scalar fields:
1. `id`, `name`, `owner`, `state`, `laps`
2. `createdAt`, `invokedAt`, `startAt`, `startedAt`, `finishedAt`
3. `sourceType`, `sourceName`, `definitionName`, `pointToPoint`
4. `trafficDensity`, `lateJoinProgressLimitPercent`, `bestLapTimeMs`
- Route/asset fields:
1. `checkpoints` (array of checkpoints)
2. `checkpointVariants` (derived for static payload)
3. `raceMetadata`
4. `props`
5. `modelHides`
- Entrant fields:
1. `entrants` (array)
2. `entrantStateById` (entrantId/src indexes)
3. `standingsVersion`

### Entrant model (server-held)
- `entrantId`, `source`, `name`, `joinedAt`
- `currentCheckpoint`, `currentLap`, `checkpointsPassed`
- `lastCheckpointAt`, `lapStartedAt`, `lapTimes`
- `totalTimeMs`, `finishedAt`, `position`

## 2) Client Payload Roots

- Root client stores in `client.lua`:
1. `latestSnapshot`
2. `definitionCache`
3. `instanceListCache`
4. `instanceDynamicCacheById`
5. `instanceStaticCacheById`
6. `latestStandingsByInstanceId`
7. `latestStandingsVersionByInstanceId`

### `latestSnapshot`
- Top-level fields:
1. `definitions`
2. `instances`
3. `viewer`
4. counts: `count`, `definitionCount`, `instanceCount`, `customRaceCount`, `onlineRaceCount`
- `instances` is rebuilt by merging list + dynamic + static cache layers.

## 3) Event Payload Contracts (Snapshot Channels)

- `racingsystem:catalog:definitions` (Server -> Client)
1. `definitions` array
2. counts (`count`, `definitionCount`, `customRaceCount`, `onlineRaceCount`)
3. `viewer`

- `racingsystem:instance:list` (Server -> Client)
1. `instances` summary array (`id`, `name`, `owner`, `state`, etc.)
2. `instanceCount`
3. `viewer`

- `racingsystem:instance:delta` (Server -> Client)
1. Dynamic instance payload (`id`, `state`, timers, entrants, laps, owner, etc.)

- `racingsystem:instance:static` (Server -> Client)
1. `instanceId`
2. `staticVersion`
3. `checkpoints`
4. `checkpointVariants`
5. `raceMetadata`
6. `props`
7. `modelHides`
8. `sourceType`, `sourceName`

- `racingsystem:state:standings` (Server -> Client)
1. `instanceId`
2. `standingsVersion`
3. `state`
4. `entrants` ordered standings array

- `racingsystem:state:snapshot` (Server -> Client, legacy/compat path)
1. `snapshotVersion`
2. full snapshot shape mirror (definitions/instances/counts/viewer)

## 4) Event-Chain Ownership (Who mutates what)

- Server `event_handlers.lua` mutates/broadcasts snapshot channels through snapshot runtime functions:
1. `sendInitialState`
2. `broadcastDefinitions`
3. `broadcastInstanceList`
4. `broadcastInstanceDelta`
5. `broadcastInstanceStandings`
6. `sendInstanceStaticIfChanged`

- Server `runtime_threads.lua` mutates race lifecycle and triggers:
1. `broadcastInstanceDelta`
2. `broadcastInstanceStandings`
3. `broadcastInstanceList`

- Client snapshot-channel handlers mutate caches:
1. `catalog:definitions` -> `definitionCache` + `latestSnapshot` counters
2. `instance:list` -> `instanceListCache` + prune dynamic/static caches
3. `instance:delta` -> `instanceDynamicCacheById`
4. `instance:static` -> `instanceStaticCacheById`
5. `state:standings` -> standings caches + merged snapshot entrant rows
6. `state:snapshot` -> version tracking (`latestSnapshotVersion`/accepted timer)

- `rebuildCompatSnapshot()` on client is the merge pivot:
1. Reads list/dynamic/static caches
2. Produces merged `latestSnapshot.instances`
3. Feeds gameplay/menu lookups (`getJoinedRaceInstance`, menu host/join lists, in-race decisions)

## 5) Table Depth Map

- Typical depth across payload structures: 3 to 5 levels.
- Deepest practical branches: ~6 levels in nested route variants/assets.

Examples:
1. `Server.State.raceInstancesById[instanceId].entrants[i].lapTimes[j]` (5)
2. `Client.instanceStaticCacheById[instanceId].checkpointVariants[k].primary.x` (6)
3. `Client.latestSnapshot.instances[i].entrants[j].currentCheckpoint` (4)

## 6) Notes

- `racingsystem:ui:notify` is non-snapshot UX channel and separate from snapshot replication.
- Teleport and lap annotation/completion channels are race-runtime events, not snapshot cache replication.
