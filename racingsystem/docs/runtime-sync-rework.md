# Racing System Runtime Synchronization Rework

## Purpose

Reconstruct and finish the synchronization rewrite that was started in April 2026 and left the **Active Races** discovery/join flow disabled.

Work will be completed in small phases. Each phase has a code boundary, automated checks where possible, and an in-game acceptance gate. We do not proceed to the next phase until the current phase has been understood and tested.

## Phase 0 — Reconstruct the Original Intention

**Status:** Complete — approved July 24, 2026

The original plan was not preserved in current documentation. The commits that performed the rewrite have minimal messages, and the temporary design documents were deleted one commit after they were introduced. Phase 0 therefore treats Git history as primary evidence and separates confirmed intent from a new proposal.

### Sources examined

- Local history from the working Active Races implementation through current `main`.
- The versions of `client/client.lua`, `client/menu.lua`, and `server/server.lua` immediately before the rewrite.
- Deleted historical files from commit `c692123a`:
  - `racingsystem/Refactoring.md`
  - `racingsystem/Payload.md`
  - `racingsystem/Events.md`
- The intermediate granular cache/event implementation in `c692123a`.
- The state-bag conversion in `0de0d216`.
- The targeted round-robin refresh work in `b5947f10`.
- Later April and May commits to determine whether synchronization work resumed.
- Repository branches, issues, pull requests, commit bodies, and commit comments on GitHub.
- Available indexed coding sessions. No historical session discussing this rewrite was found.

### Reconstructed timeline

#### Before April 20: working but expensive full snapshots

The Active Races flow was working by commit `2de4643` on April 6. The menu read `RacingSystem.Client.latestSnapshot.instances` and joined the selected numeric instance ID.

Immediately before `c692123a`, synchronization worked as follows:

1. The client requested `racingsystem:requestState`.
2. The server built one full snapshot containing:
   - every race definition;
   - every active instance;
   - every instance's dynamic fields and entrant rows;
   - checkpoint geometry, race metadata, and checkpoint variants.
3. The server sent `racingsystem:stateSnapshot`.
4. The full snapshot was broadcast to every connected player after catalog changes and nearly every race mutation, including every accepted checkpoint pass.
5. Standings were additionally sent to entrants through `racingsystem:standingsUpdate`.
6. A client reconciliation loop requested another full snapshot when its copy became stale.

This made `latestSnapshot` a convenient universal client model, but caused unrelated players to repeatedly receive static route data, all definitions, and all active instances when one racer advanced a checkpoint.

#### April 20: de-monolith and payload teardown scaffold

Commit `c692123a` (`refactor`) split the 3,877-line server monolith into focused server modules. Its retained `Refactoring.md` explicitly prioritized decomposition of the client/server monoliths, reducing shipped/runtime payload, and separating active runtime data from race definitions.

That commit also documented a proposed granular payload/cache stack:

- `racingsystem:catalog:definitions`
- `racingsystem:instance:list`
- `racingsystem:instance:delta`
- `racingsystem:instance:static`
- `racingsystem:state:standings`
- `racingsystem:state:snapshot`

However, it did **not** activate that stack:

- `RacingSystem.Client.PayloadSystemDisabled = true` was introduced.
- The client request function returned without sending anything.
- Every new server emitter returned without emitting anything.
- Comments explicitly said each payload channel was “disabled during rewrite”.
- `Payload.md` described the system as “As-Is Before Teardown”.

The granular cache stack was therefore an intermediate decomposition/scaffold, not evidence that all of those channels were approved as the final architecture.

#### April 21: granular caches removed; state bags become the live path

Commit `0de0d216` (`compaction`) deleted all three temporary planning/contract documents and removed the granular client caches and handlers. It introduced the architecture that still drives joined gameplay:

- Player state bags for membership, entrant identity, position, lap, checkpoint, and finish state.
- A flat global state key for each instance's lifecycle state.
- `racingsystem:race:getRaceInfo` for a joined player's detailed instance/route data.
- State-bag change handlers to update menu state and entrant progress.

The disabled flag remained, and the Active Races menu's former snapshot reads were replaced with literal empty lists. This is the point where discovery was knowingly left unavailable.

#### April 21–22: split client load and spread joined-racer refreshes

Commit `2229c1be` moved editor and teleport work out of `client.lua`; this was structural load spreading, not a synchronization decision.

Commit `b5947f10` consolidated invoke/join completion and added a round-robin server thread. It refreshes one joined target at a time with:

- standings through state bags;
- targeted `racingsystem:race:getRaceInfo`;
- instance assets;
- the still-disabled static emitter.

This reinforces that the direction after teardown was **state bags for hot state plus targeted detail for entrants**, rather than restoring global full snapshots.

#### April 22 onward: runtime catalog becomes generated data

`race_index.json` was removed from version control and is ignored by `.gitignore`; `race_index_examples.json` remains the tracked seed/example catalog. The current local `race_index.json` is generated runtime data.

The client-side menu later began reading this generated file directly because the catalog payload path was disabled. That can work for the copy downloaded when a resource starts, but it is not a coherent live synchronization mechanism for definitions created, imported, or deleted while clients are connected.

#### May: feature work continued without finishing synchronization

The May commits added editor/UI work, documentation, and all-finished cleanup. They preserved the disabled flag, no-op emitters, state-bag architecture, empty Active Races lists, and targeted race-info refreshes. No later commit completed or replaced discovery/catalog synchronization.

### Confirmed original intentions

Confidence is based on code changes rather than commit-message wording.

| Intention | Confidence | Evidence |
| --- | --- | --- |
| Retire the broadcast-to-everyone full snapshot as the primary runtime model | High | Full broadcasts were disabled, then their consumers were removed. |
| Decompose the client and server monoliths by responsibility | High | Historical refactoring plan and resulting module split. |
| Keep the server authoritative for instances, lifecycle, membership, and progress | High | All mutations remained server-side throughout the rewrite. |
| Use flat state bags for frequently changing membership/progress/lifecycle state | High | State-bag conversion in `0de0d216` and all subsequent runtime work. |
| Send large route/detail data only to joined racers | High | `race:getRaceInfo`, assets, join completion, and round-robin target selection. |
| Spread reconciliation work instead of broadcasting large synchronized bursts | High | Round-robin target refresh introduced in `b5947f10`. |
| Preserve Active Races discovery and late joining as product features | High | Existing menu, `joinById`, late-join rules, and inherited progress were retained rather than deleted. |
| Use the entire six-channel granular cache stack as the final design | Low / contradicted | It was disabled on introduction and its client implementation was deleted in the next commit. |

### The thread that was actually lost

The rewrite successfully replaced joined-racer hot-state synchronization, but never designed the small amount of **public discovery state** still needed by players who have not joined a race:

- Which active instances exist, with enough summary data to select one.
- Which race definitions currently exist after runtime catalog mutations.

State bags currently cannot supply those views by themselves:

- `GlobalState['rs:raceState:<id>']` exposes only an ID and lifecycle string.
- Player state bags expose entrants only after membership exists.
- Neither source supplies the race name, owner, lap configuration, traffic mode, entrant count, definition source, or current catalog.

The old universal snapshot supplied this information accidentally because it supplied everything. The state-bag replacement supplied joined gameplay deliberately, but left discovery/catalog without an owner.

### Phase 0 decision

Approved July 24, 2026:

> The intended direction was not to revive the old full snapshot and was probably not to preserve the intermediate compatibility snapshot/cache stack. The intended direction was a server-authoritative, de-monolithized runtime using flat state bags for hot replicated state and targeted events for large entrant-only data. To finish that direction, add minimal bounded server-owned views for active-instance discovery and the live race catalog, then remove the abandoned compatibility machinery.

This is partly reconstruction and partly the smallest design needed to close the historical gap. No surviving artifact specifies the exact final event contract for public discovery.

### Frozen Phase 1 public instance contract

The server emits a complete replacement view through `racingsystem:instance:list`:

```lua
{
    revision = 0,
    instances = {
        {
            id = 1,
            name = 'Example Race',
            sourceType = 'custom',
            owner = 12,
            state = 'idle',
            laps = 2,
            trafficDensity = 0.0,
            lateJoinProgressLimitPercent = 50,
            entrantCount = 1,
        },
    },
}
```

Contract rules:

- `revision` is a server-owned monotonic integer for the current resource lifetime.
- The revision advances once for each broadcast-worthy list mutation, not for a read-only targeted request.
- `instances` completely replaces the client discovery cache.
- Entries are sorted by numeric instance ID.
- Only `idle`, `staging`, and `running` instances are included.
- The list contains summaries only: no checkpoints, metadata, variants, props, model hides, lap times, or entrant rows.
- The server remains authoritative for join acceptance and rechecks the selected numeric instance ID.
- A running instance may still reject a join at the configured progress cutoff.
- There is no disk, global-state reconstruction, or stale-cache fallback.
- Administrative status remains in `rs:isAdmin`; the list payload does not duplicate viewer permissions.

Delivery rules:

- `sendInstanceList(target)` sends the current revision and view to one target.
- `broadcastInstanceList()` advances the revision and sends one common view to all clients.
- `sendInitialState(target)` includes the current instance list.
- The client explicitly requests initial state after resource start and refreshes when Active Races is opened.
- Existing lifecycle mutation sites remain responsible for requesting a list broadcast.

### Frozen later catalog boundary

Phase 2 will define the exact catalog field contract, but its ownership boundary is fixed now:

- The server catalog is authoritative.
- The server sends a complete replacement catalog view on initial state and catalog mutations.
- The client does not use generated `race_index.json` as a runtime menu source or fallback.
- Catalog payloads contain definition summaries only, never complete checkpoint/mission data.
- Catalog synchronization remains outside Phase 1.

### Current synchronization inventory

The dispositions below are approved as the working direction. Items assigned to Phase 3 remain intentionally undecided until joined-runtime behavior is measured.

| Current function/path | Current state | Disposition | Reason |
| --- | --- | --- | --- |
| `buildDefinitionsPayload` | Builds a bounded catalog view | Keep | It already expresses the public catalog data missing from state bags. |
| `sendDefinitions` / `broadcastDefinitions` | No-op; broadcast callers retained | Restore narrowly | Required for live catalog changes; do not rebuild `latestSnapshot`. |
| `buildInstanceListPayload` | Builds bounded summaries | Keep | It already expresses the public discovery data missing from state bags. |
| `sendInstanceList` / `broadcastInstanceList` | No-op; lifecycle callers retained | Restore narrowly | Required for Active Races and stale-entry removal. |
| `sendInitialState` | No-op; request/join callers retained | Restore as coordinator | It should send only the bounded public views approved in Phase 0. |
| `buildInstanceDynamicPayload` | Used inside joined-racer race info | Keep for now | It supplies identity/config/runtime/entrant data to joined racers. |
| `buildInstanceStaticPayload` | Used inside joined-racer race info | Keep for now | It supplies route geometry and metadata to joined racers. |
| `buildRaceInstanceSnapshot` / `race:getRaceInfo` | Active targeted path | Keep, then measure | This is the post-teardown detailed joined-racer path. |
| `broadcastInstanceStandings` | Active state-bag writer | Keep | It publishes hot entrant progress without large global payloads. |
| `sendInstanceAssets` | Active targeted path | Keep, then measure refresh frequency | Assets belong only to joined racers, but periodic resends may be excessive. |
| `sendInstanceDelta` / `broadcastInstanceDelta` | No-op; many mutation callers retained | Decide in Phase 3 | Do not restore automatically; targeted race-info refresh may replace these calls. |
| `getInstanceStaticSignature` / `sendInstanceStaticIfChanged` | Signature builder plus no-op sender | Decide in Phase 3 | Detailed race info already contains static route data. |
| `buildInstanceStandingsPayload` and `standingsVersion` | Legacy payload shape; state bags bypass it | Likely delete | No current event consumes this payload/version. |
| `buildFullSnapshot` | Dead builder | Delete after replacement gates pass | Recreates the architecture the teardown was removing. |
| `sendSnapshot` / `broadcastSnapshot` | Dead no-ops with no callers | Delete | No final owner or consumer remains. |
| `nextSnapshotVersion` and stale-snapshot bookkeeping | Legacy remnants | Delete with full snapshot | The current client has no full-snapshot consumer. |
| Round-robin joined-target refresh | Active every roughly two seconds per full cycle | Keep initially, then measure | It was the explicit load-spreading/reconciliation step added after teardown. |
| Client `LoadResourceFile('race_index.json')` | Active menu source | Replace, not retain as fallback | The index is generated/ignored runtime data and cannot provide coherent live mutations. |
| `PayloadSystemDisabled` and empty Active Races lists | Active feature gate | Delete after public discovery works | These are migration scaffolding, not architecture. |

### Phase 0 checklist

- [x] Establish the last known working Active Races design.
- [x] Identify why the old full snapshot was unsuitable.
- [x] Recover and inspect deleted planning/contract documents.
- [x] Trace the granular payload scaffold and its deletion.
- [x] Trace the state-bag and targeted-detail replacement.
- [x] Check later commits, branches, GitHub discussions, and indexed sessions for continuation.
- [x] Agree on the reconstructed architectural direction.
- [x] Inventory every current no-op synchronization function under the approved phase assignments.
- [x] Freeze the Phase 1 public instance-summary contract.
- [x] Freeze the later catalog contract boundary.

## Current Situation

The current resource uses two incomplete synchronization designs at once:

- Flat player state bags hold race membership and hot entrant progress:
  - `rs:instanceId`
  - `rs:entrantId`
  - `rs:position`
  - `rs:currentLap`
  - `rs:currentCheckpoint`
  - `rs:finishedAt`
- `GlobalState['rs:raceState:<instanceId>']` holds instance lifecycle state.
- `racingsystem:race:getRaceInfo` sends detailed data to joined racers.
- `racingsystem:race:instanceAssets` sends props and model hides to joined racers.
- The client reads `race_index.json` directly for its race-definition menus.
- The intended catalog, instance-list, delta, static, initial-state, and full-snapshot emitters in `server/snapshot_runtime.lua` are no-ops.
- `RacingSystem.Client.PayloadSystemDisabled` remains as migration scaffolding. `menu.lua` captures it before `client.lua` assigns it because of manifest load order, so the menu guard is not reliable in the current build.
- The **Active Races** menu is unconditionally nonfunctional because both browse and join paths use empty local instance lists.

The server-side instance creation, `joinById`, late-join validation, entrant insertion, and teleport flow are already implemented.

## Target Architecture

Use one explicit synchronization responsibility for each kind of state.

### State bags

State bags remain the live, granular replication mechanism for:

- Local race membership and entrant identity.
- Entrant position, lap, checkpoint, and finish state.
- Instance lifecycle state through a flat global key.
- Administrative status.

State bags must continue to use flat bracket keys. Do not introduce nested state or `state:set(...)`.

### Server-to-client payloads

Bounded events carry data that does not fit state bags:

- `racingsystem:catalog:definitions`: complete current race-definition list.
- `racingsystem:instance:list`: complete current active-instance summary list.
- `racingsystem:race:getRaceInfo`: detailed data for an instance the receiving player has joined.
- `racingsystem:race:instanceAssets`: assets for an instance the receiving player has joined.

A complete list payload replaces the corresponding client cache. It is not merged with disk data or used as a fallback layer.

### Server authority

The server remains authoritative for:

- Which instances exist.
- Which players belong to each instance.
- Whether an instance can be joined.
- Late-join eligibility.
- Lifecycle transitions.
- Entrant checkpoint and lap progression.

The client may present state and submit an instance ID, but it must not decide that a join is valid.

## Non-Goals

- Do not restore the old monolithic full-snapshot system.
- Do not replicate checkpoints, props, or full entrant data to players who have not joined an instance.
- Do not add polling loops when lifecycle broadcasts and explicit requests are sufficient.
- Do not add fallback reads when a server payload is unavailable.
- Do not change checkpoint, lap, teleport, spectator, or editor behavior unless required by the synchronization boundary.
- Do not enforce the preview-only Maximum PI option as part of this work.

## Phase 1 — Restore Active-Instance Discovery and Joining

**Status:** Not started

### Server work

- [ ] Implement `sendInstanceList(target)` in `server/snapshot_runtime.lua`.
- [ ] Implement `broadcastInstanceList()` in `server/snapshot_runtime.lua`.
- [ ] Emit `racingsystem:instance:list` with the frozen summary-only contract.
- [ ] Add and advance the server-owned list revision only on broadcast-worthy mutations.
- [ ] Include only `idle`, `staging`, and `running` instances, sorted by numeric ID.
- [ ] Ensure a targeted response is sent by `racingsystem:state:request` without advancing the revision.
- [ ] Retain existing lifecycle calls to `broadcastInstanceList()` after invoke, join, start, restart, leave, finish, kill, automatic cleanup, and disconnect cleanup.
- [ ] Confirm the list contains summaries only and does not expose checkpoints, props, model hides, or full entrant records.

### Client work

- [ ] Add one client cache for the latest complete instance-summary list.
- [ ] Register `racingsystem:instance:list` and replace the cache on every valid payload.
- [ ] Export a narrow getter for the menu instead of exposing a mutable shared snapshot structure.
- [ ] Request initial state after the client resource starts.
- [ ] Request a fresh list when the player opens **Active Races**.
- [ ] Replace both `local instances = {}` placeholders in `client/menu.lua` with the cached server list.
- [ ] Keep menu selection tied to the selected numeric instance ID, not only its display label or array position.
- [ ] Display each instance with enough context to distinguish it, including name, lifecycle state, and entrant count.
- [ ] Show a clear empty-list item when no active instances exist.
- [ ] Keep `racingsystem:race:joinById` as the only join submission path.

### Disable-switch cleanup

- [ ] Remove the Active Races guard that reports “Snapshot payload system disabled”.
- [ ] Do not remove the global disable flag or unrelated dead snapshot code until Phase 4, unless the flag has no remaining readers after Phase 1.

### Automated verification

- [ ] Lua syntax check all changed Lua files with `luac -p`.
- [ ] Search for remaining empty Active Races list placeholders.
- [ ] Search all invoke/join/leave/finish/kill paths for the expected list broadcast.
- [ ] Confirm the client sends `racingsystem:state:request` and handles `racingsystem:instance:list`.

### In-game acceptance gate

Use two clients where noted.

- [ ] With no hosted race, **Active Races** opens and reports no active races without errors.
- [ ] Client A hosts a race; Client B sees it without restarting the resource.
- [ ] Client B sees the correct name, state, and entrant count.
- [ ] Client B joins by selecting that instance.
- [ ] Both clients show two entrants after the join.
- [ ] Client B leaves; Client A remains in the race and the list returns to one entrant.
- [ ] Killing or automatically removing the instance removes it from Client B's list.
- [ ] Opening the menu repeatedly does not duplicate entries.
- [ ] A client that connects after the race was hosted receives the current list.

## Phase 2 — Make the Race Catalog Server-Synchronized

**Status:** Blocked by Phase 1

### Server work

- [ ] Implement `sendDefinitions(target)`.
- [ ] Implement `broadcastDefinitions()`.
- [ ] Include the catalog and viewer permissions from `buildDefinitionsPayload(viewerSource)`.
- [ ] Verify broadcasts occur after create, save, register, import, and delete operations that change the catalog.
- [ ] Include definitions in `sendInitialState(target)`.

### Client work

- [ ] Add one complete race-definition cache populated by `racingsystem:catalog:definitions`.
- [ ] Replace the cache rather than merging it with packaged JSON.
- [ ] Make Host and Edit Existing read the server-provided cache.
- [ ] Remove runtime menu dependence on client-side `LoadResourceFile(..., 'race_index.json')`.
- [ ] Refresh an open relevant menu when a catalog update arrives without corrupting its current selection.

### In-game acceptance gate

- [ ] Client A creates/saves a custom race; Client B sees it without a resource restart.
- [ ] An imported GTA Online race appears for both clients.
- [ ] An authorized deletion disappears for both clients.
- [ ] A late-joining client receives the same catalog.
- [ ] Host and editor selections still resolve the correct source type and race ID.

## Phase 3 — Resolve Dynamic and Static Instance Channels

**Status:** Blocked by Phase 2; design review required before implementation

The current joined-racer path already receives detailed `racingsystem:race:getRaceInfo` payloads and hot progress through state bags. Before restoring any old delta/static channel, measure what is still missing.

### Review questions

- [ ] Does every joined racer receive initial route/config data immediately after invoke or join?
- [ ] Are lifecycle fields updated promptly enough through `GlobalState` and targeted race info?
- [ ] Does entrant membership remain correct after joins, leaves, and disconnects?
- [ ] Does the round-robin race-info refresh duplicate data unnecessarily?
- [ ] Is `sendInstanceStaticIfChanged()` needed, or is detailed initial race info sufficient?
- [ ] Is `broadcastInstanceDelta()` needed, or should membership changes trigger bounded targeted race-info refreshes?

### Decision rule

Choose one joined-instance detail path. Do not keep two event systems as mutual fallbacks.

- If targeted race info plus state bags fully covers joined gameplay, remove obsolete delta/static machinery.
- If a separate dynamic channel is required, define its audience and fields explicitly and stop sending unchanged static route data with dynamic updates.

### In-game acceptance gate

- [ ] Invoke and ordinary join initialize checkpoints and route markers immediately.
- [ ] Late join initializes the inherited checkpoint and route correctly.
- [ ] Countdown, running, restart, finish, and leave transitions update every entrant.
- [ ] Entrant positions and progress remain synchronized during a multiplayer race.
- [ ] Props and model hides load once when appropriate and unload on exit.

## Phase 4 — Remove the Abandoned Snapshot Rewrite

**Status:** Blocked by Phase 3

- [ ] Remove `RacingSystem.Client.PayloadSystemDisabled` and its notification path.
- [ ] Remove obsolete full-snapshot builders, version fields, counters, and no-op exports that have no owner in the chosen architecture.
- [ ] Remove obsolete event names and dead client caches.
- [ ] Remove no-op forwarding functions rather than retaining compatibility shims.
- [ ] Update `docs/overview.md` and `docs/server-architecture.md` to describe the final synchronization model.
- [ ] Update this document with the final Phase 3 decision.

### Verification

- [ ] Search for `PayloadSystemDisabled`, disabled-rewrite messages, snapshot stubs, and unregistered event names.
- [ ] Run Lua syntax checks.
- [ ] Restart the resource with players connected and confirm state bags are cleared and rebuilt correctly.
- [ ] Repeat the Phase 1–3 acceptance gates after cleanup.

## Phase 5 — Reliability and Diagnostic Cleanup

**Status:** Blocked by Phase 4

- [ ] Remove unconditional `[DEBUG]` prints from finish and standings synchronization.
- [ ] Route useful diagnostics through the existing configured logging levels.
- [ ] Verify no undefined diagnostic variables remain.
- [ ] Confirm empty instances are destroyed exactly once.
- [ ] Confirm stale menu entries disappear after kill, all-finished cleanup, and host disconnect.
- [ ] Confirm unauthorized and invalid joins fail server-side with a useful notification.
- [ ] Confirm repeated state requests do not mutate server state.

## Manual Test Reporting Template

For each in-game gate, record:

```text
Phase:
Test case:
Clients used:
Steps:
Expected:
Observed:
Client console errors:
Server console errors:
Result: PASS / FAIL
Notes:
```

When a test fails, capture the exact server/client console output and stop that phase. Fix and repeat the failed case before moving forward.

## Completion Criteria

The rework is complete when:

- Players can discover and join active race instances through the menu.
- Catalog changes propagate without a resource restart.
- Joined racers receive exactly the runtime data needed for gameplay.
- State bags and payload events have non-overlapping, documented responsibilities.
- No disabled payload flag, empty instance placeholder, abandoned snapshot handler, or synchronization no-op remains.
- All phase acceptance gates pass in multiplayer testing.
