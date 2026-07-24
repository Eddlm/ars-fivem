# RacingSystem Sanity Audit and Fix Checklist

**Scope:** Entire `racingsystem` production resource, synchronized contracts, bundled race data, NUI, documentation, and production-backed `.piTools` tests.

**Method:** Audit clarity, correctness, robustness, security boundaries, lifecycle coherence, dead code, and platform fragility. Fix in criticality order, run the full production-backed suite after each logical batch, then repeat the audit from a fresh pass. Runtime-only findings remain explicitly deferred rather than marked fixed.

## Audit Pass 1 — Initial Findings

### Critical

- [x] **C1 — Repair cross-module calls that currently resolve to undefined globals.** `server/race_repository.lua` calls bare `extractHumanNameFromFileBase`, `fetchUGCJsonContentById`, and `findRaceInstanceByName`, although all three implementations are module-local and exported through `RacingSystem.Server.*`. Folder scans, GTAO imports, validation, and active-race deletion checks can therefore fail at runtime.
- [x] **C2 — Remove dynamically loaded obfuscated integrity code.** Startup randomly loads and executes `server/integrity.lua`, which decodes an unrelated accusatory console message. This is opaque executable behavior with no racing-system integrity function and conflicts with auditability.
- [x] **C3 — Make JSON decoding failure-safe at every untrusted or mutable boundary.** Malformed `race_index.json`, examples, race files, downloaded UGC, or existing editor files can currently throw through `json.decode` and abort startup/event execution.
- [x] **C4 — Eliminate raw filename/path resolution from client-controlled race names.** Repository direct lookup can pass unsanitized names into `CustomRaces/<name>.json` / `OnlineRaces/<name>.json`; deletion also has an unsanitized final filename fallback.

### High

- [x] **H1 — Fix late join when exactly one racer exists.** `getLastPlaceEntrant` returns `nil` for one entrant, so the first late join starts from pre-race progress instead of inheriting the existing racer’s progress.
- [x] **H2 — Preserve online race identity through repository load/editor registration.** Loaded repository objects omit `sourceType`; opening an online race in the editor can re-register it as custom and lose its UGC identity.
- [x] **H3 — Make deletion transactional from the catalog’s perspective.** A failed filesystem deletion currently continues by removing the catalog definition, creating a file/index divergence and explicit fallback behavior.
- [x] **H4 — Stop trusting client-provided lap and total times.** The checkpoint event accepts arbitrary timing values from the client for lap records and finishing totals despite server start/lap timestamps being available.
- [x] **H5 — Normalize point-to-point races to one lap.** Multi-lap point-to-point instances currently target the terminal checkpoint again after a lap, producing incoherent progression.
- [x] **H6 — Collapse duplicate UGC downloads and serialize imports.** Import validates by downloading/parsing once, then downloads/parses again to save; simultaneous clients can overlap a long shared HTTP/filesystem operation.
- [x] **H7 — Validate finite, bounded checkpoint coordinates/radii and cap list size.** Editor/network input can currently persist non-finite, extreme, or unbounded checkpoint payloads.
- [x] **H8 — Bound client model loading.** `loadInstanceAssets` waits forever for a requested model with no timeout/cancellation path.
- [x] **H9 — Repair teleport safety checks.** Occupancy examines only the first five global vehicles and player indices, not nearby/all active entities; teleport exceptions are swallowed without diagnostics.

### Medium

- [x] **M1 — Make `raceOwnerCanKillOwnedRace` coherent end-to-end.** The documented config is ignored by server authorization/client menu, while catalog payloads incorrectly advertise owned-instance killing as always available.
- [x] **M2 — Remove or implement dead/no-op paths.** Includes countdown visual no-ops and callers, empty stable-lap event handler, unused menu helpers/logging stub, unused client checkpoint rendering helpers, and exported server helpers with no owner.
- [x] **M3 — Propagate catalog persistence failures.** Definition registration/unregistration currently ignores `saveRaceIndex()` failure and can report success despite non-durable index changes.
- [x] **M4 — Reduce misleading spectator configuration/state.** Numerous zoom, bounds, edge-scroll, smoothing, sprint, and motion fields imply behavior that is not implemented.
- [x] **M5 — Remove stale manifest/docs metadata.** `latest_change` and any architecture/config descriptions must match the final audited behavior.

### Runtime-Dependent or Theoretical Risks

- [ ] **R1 — Verify server-side checkpoint anti-cheat feasibility in the target OneSync configuration.** Sequential event validation prevents reordering but does not prove physical proximity; adding server coordinate checks without validating native availability could reject legitimate racers.
- [ ] **R2 — Decide the intended authorization policy for editor writes and UGC import.** All clients currently may create/overwrite custom race files and initiate Rockstar downloads; this may be a product choice, but it must be confirmed in multiplayer rather than silently changed during a code sanity pass.
- [ ] **R3 — Verify `GlobalState` iteration and connected-player state-bag clearing in a real FiveM resource restart.**
- [ ] **R4 — Exercise ScaleformUI redraw, editor/freecam controls, asset streaming, model hides, and teleport safety in game.**
- [ ] **R5 — Exercise filesystem save/delete failures and Rockstar HTTP timeout/rate behavior on the deployment OS.**

## Pass 1 Verification Record

Implemented all automatable Critical, High, and Medium findings from the initial pass.

Automated verification:

- `lua .piTools/test_instance_list_payload.lua` — 128/128 assertions.
- `lua .piTools/test_joined_sync.lua` — 21/21 assertions.
- `lua .piTools/test_event_handlers.lua` — 23/23 assertions.
- `lua .piTools/test_repository_robustness.lua` — 29/29 assertions covering malformed JSON, path sanitization, online identity, exported module calls, bounded checkpoints, catalog persistence rollback, import, active-instance deletion, and filesystem-delete rollback.
- Full production/test `luac -p` sweep and `node --check racingsystem/ui/app.js` passed.
- Static closure checks found no unused local functions, obsolete integrity/countdown/stable-lap paths, or client-provided timing payload.

Runtime-dependent items R1–R5 remain open and are not implied by these checks.

## Audit Pass 2 — Fresh Review

A fresh post-commit review found the following additional issues:

### High

- [x] **P2-H1 — Bind deletion exclusively to the resolved server catalog identity.** A table request can name definition A but supply race ID B; deletion currently prefers the request race ID after resolving A and can remove the wrong online file.
- [x] **P2-H2 — Keep new editor races ephemeral until the first valid save.** Creating a new race currently persists and catalogs a zero-checkpoint mission that cannot be parsed or hosted if the editor exits before saving.
- [x] **P2-H3 — Reject stale teleport payloads and queue the latest overlapping teleport.** A delayed old-instance teleport can move a racer after transfer, while any teleport arriving during another teleport is silently dropped.
- [x] **P2-H4 — Correct the soft engine-power penalty.** FiveM uses `0.0` as normal and positive values as boosts; the configured `0.05` is a tiny boost rather than a penalty.
- [x] **P2-H5 — Ensure the lap-completion event cannot suppress the finish shard.** The handler marks the finish cue as shown without displaying it, causing the state-driven renderer to skip the visual.

### Medium

- [x] **P2-M1 — Surface editor load/save/delete errors to the player.** Client handlers silently return on structured server failures.
- [x] **P2-M2 — Put one total deadline around UGC URL candidates.** Individual 10-second timeouts across all language/title candidates can keep one import alive for several minutes.
- [x] **P2-M3 — Remove the remaining future-blip/join-hint state machine.** Blip production was removed, but state, invalidation, config, and clear calls remain.
- [x] **P2-M4 — Apply the calculated throttle-penalty duration.** The code computes 1–5 seconds but only applies one instantaneous velocity reduction; the existing duration state is otherwise unused.
- [x] **P2-M5 — Bound imported prop and model-hide counts before synchronized delivery/client spawning.** Mission-declared counts are currently unbounded.
- [x] **P2-M6 — Send lap completion only to its owning entrant.** The server sends the same event to every entrant, while every non-owner client immediately discards it.

### Low

- [x] **P2-L1 — Remove the remaining unused conversion constant and correct update-notifier version wording.**
- [x] **P2-L2 — Remove documentation for the nonexistent `rSystemPrintLevel` convar and correct packaged-data/spectator descriptions.**

### Pass 2 Verification Record

Implemented every automatable Pass 2 finding.

Automated verification:

- `lua .piTools/test_instance_list_payload.lua` — 130/130 assertions.
- `lua .piTools/test_joined_sync.lua` — 24/24 assertions, including single-recipient authoritative lap completion.
- `lua .piTools/test_event_handlers.lua` — 23/23 assertions.
- `lua .piTools/test_repository_robustness.lua` — 37/37 assertions, including total UGC deadline, ephemeral drafts, and mismatched deletion identity.
- Full production/test Lua syntax, NUI JavaScript syntax, JSON-data, network-event closure, config-use, dead-local, and obsolete-symbol checks passed.

FiveM-native teleport queuing/stale rejection, finish/final-lap visuals, timed throttle/power penalties, and editor error presentation remain runtime acceptance items under R4.

## Audit Pass 3 — Closure Review

### Critical

- [x] **P3-C1 — Remove the editor-exit call to an undefined global.** `endEditorSession()` calls `releaseEditorHelpScaleform` before a later local declaration, so Lua resolves the call as a global; that global is `nil`. The later function is itself an empty no-op.

### Medium

- [x] **P3-M1 — Repair checkpoint chevron argument/edge coherence.** The renderer computes edge coordinates and accepts caller colors but ignores both, shadows the color, and carries two additional unused parameters.

### Low

- [x] **P3-L1 — Report successful UGC imports and correct the menu description.** The result handler calculates checkpoint count but never uses it, and the menu promises immediate hosting that does not occur.
- [x] **P3-L2 — Remove unused lap-trigger helper parameters.** The helper accepts an instance and lap count but derives its answer only from checkpoint count.

### Closure Criteria

- [x] Enumerate compiled Lua `_ENV` accesses and verify every remaining global is a FiveM/ScaleformUI/Lua runtime API or an intentional resource global.
- [x] Repeat all production-backed, syntax, JSON-data, network-closure, dead-code, obsolete-symbol, config-use, and documentation-coherence checks.
- [x] Confirm only runtime-dependent/theoretical R1–R5 remain open.
- [x] Commit Pass 3 separately.

### Pass 3 Verification Record

The compiled-global review found and removed the final concrete runtime error: editor exit was calling a `nil` global because an empty local helper was declared later in the file. The closure pass also repaired chevron edge/color use, removed unused lap-trigger parameters, and completed UGC success feedback.

Automated verification:

- `lua .piTools/test_instance_list_payload.lua` — 130/130 assertions.
- `lua .piTools/test_joined_sync.lua` — 24/24 assertions.
- `lua .piTools/test_event_handlers.lua` — 23/23 assertions.
- `lua .piTools/test_repository_robustness.lua` — 37/37 assertions.
- `python .piTools/audit_lua_globals.py` — 22 compiled production Lua files and 173 intentional/runtime globals audited; no suspicious lowercase global access.
- Full production/test `luac -p`, `node --check`, JSON syntax/finite-value, literal network producer/consumer, empty-function/branch, dead-local, documentation-link, manifest-path, and config-use/documentation checks passed.

**Closure result:** No additional concrete static issue remains. The only unchecked items are R1–R5, which require a product-policy decision or a real FiveM/OneSync/ScaleformUI/filesystem/network runtime. Those risks are minimal/theoretical from static evidence and are intentionally not marked passed.

## Audit Pass 4 — Fresh Model Review

A different model re-audited the entire resource from scratch. Previous passes were thorough on correctness; this pass focuses on code organization, dead parameters, misleading control flow, and unnecessary allocation pressure.

### Medium

- [ ] **P4-M1 — `logging_access.lua` is a grab-bag of non-logging concerns.** The file exports `setRaceInstanceState`, `setRaceStateBag`, `clearRaceStateBagByInstanceId`, `isLifecycleTransitionAllowed`, `buildEntrantId`, `hasAdminAccess`, `notifyPlayer`, and `resolveReadablePlayerName`. These are lifecycle state management, entrant identity, authorization, and player notification — not logging. The module name is misleading and mixed concerns make the codebase harder to navigate. Functions work correctly; this is a maintainability issue, not a bug.

- [x] **P4-M2 — `racingsystem:editor:load` fails entirely when catalog re-registration of an already-registered race fails.** When opening an existing race in the editor, the handler calls `registerKnownRaceDefinition` which calls `saveRaceIndex()`. If the index save fails (e.g., disk full), the handler returns an error and the editor does not open — even though the race data was loaded successfully from disk. The re-registration only updates `updatedAt`; the previous definition is correctly restored in memory on failure. The handler should log the registration failure and still return the loaded race data.

**Fix:** The handler now checks whether the definition was already registered before calling `registerKnownRaceDefinition`. If it was and re-registration fails, the error is logged and the editor still opens with the loaded race data. If it was a new registration that fails, the editor load still fails (since the race can't be saved without a catalog entry).

### Low

- [x] **P4-L1 — `getFuturePreviewMarkerHeight` ignores the distance callers compute.** The function takes no parameters and always returns `3.0`, but every call site computes a 3D distance and passes it. The distance computation is wasted CPU and the function signature is misleading. Either remove the distance computation at call sites or make the function use it.

**Fix:** Removed the unused distance arguments from all three call sites and the now-dead `previewCoords`/`previewDistanceMeters` locals in the preview loop.

- [ ] **P4-L2 — `getClientExtraPrintLevel` never returns 1, making client level-1 logging dead code.** The server-side equivalent supports three levels (0=none, 1=important, 2=verbose), but the client collapses levels 0 and 1 together. The `logClientVerbose` function is the only consumer and it gates on `== 2`. There is no level-1 path.

- [ ] **P4-L3 — `racingsystem:race:invoke` handler has confusing variable shadowing.** A `do` block at the top of the handler creates locals (`raceName`, `payloadTable`, etc.) that shadow the outer handler variables. The outer `raceName` is used in the error message; the inner one is used for verbose logging. Works correctly but is confusing to read.

- [x] **P4-L4 — `InRace.lua` allocates a new `finishCueShownByInstanceId` table every ~1s when not in a race.** The main loop does `finishCueShownByInstanceId = {}` and reassigns the module field. This is redundant with the in-place clearing done in leave/restart handlers and creates unnecessary GC pressure. Clear the existing table in-place instead.

**Fix:** Replaced the table recreation + module-field reassignment with an in-place `for k in pairs(...) do ...[k] = nil end` clear. The module field already points to the same table, so no reassignment is needed.

- [ ] **P4-L5 — `leaveCurrentRaceInstance` returns a potentially destroyed instance.** When the last entrant leaves, the instance is removed from `raceInstancesById`. The `racingsystem:race:leave` handler then calls `broadcastInstanceStandings(instance)` on the now-orphaned table. Harmless (entrants list is empty) but semantically misleading.

### Pass 4 Baseline

Before any Pass 4 fixes:
- `lua .piTools/test_instance_list_payload.lua` — 130/130 assertions.
- `lua .piTools/test_joined_sync.lua` — 24/24 assertions.
- `lua .piTools/test_event_handlers.lua` — 23/23 assertions.
- `lua .piTools/test_repository_robustness.lua` — 37/37 assertions.
- `python .piTools/audit_lua_globals.py` — clean.
- Full closure checks (syntax, network events, dead code, config, docs, manifest) — all passed.

### Pass 4 Verification Record

Fixed the three automatable findings (P4-M2, P4-L1, P4-L4). The remaining items are code-organization or cosmetic:

- **P4-M1** (`logging_access.lua` mixed concerns) — invasive refactor, deferred.
- **P4-L2** (`getClientExtraPrintLevel` no level 1) — intentional design, client doesn't need level-1 logging.
- **P4-L3** (`racingsystem:race:invoke` variable shadowing) — cosmetic, works correctly.
- **P4-L5** (`leaveCurrentRaceInstance` returns destroyed instance) — harmless, entrants list is empty.

Automated verification after fixes:

- `lua .piTools/test_instance_list_payload.lua` — 130/130 assertions.
- `lua .piTools/test_joined_sync.lua` — 24/24 assertions.
- `lua .piTools/test_event_handlers.lua` — 23/23 assertions.
- `lua .piTools/test_repository_robustness.lua` — 37/37 assertions.
- `python .piTools/audit_lua_globals.py` — 22 compiled production Lua files, no suspicious globals.
- Full production/test `luac -p`, `node --check`, JSON, network-event, dead-code, config-use, documentation-link, and manifest-path checks passed.

**Pass 4 result:** Three concrete improvements (editor-load resilience, dead-computation removal, GC pressure reduction). The four deferred items are cosmetic or organizational. R1–R5 remain the only runtime-dependent items.

## Audit Pass 5 — Race Lifecycle Flow Audit

Deep trace of the full race lifecycle: host invokes → others join → countdown start → staging → running → checkpoint/lap progression → finish → cleanup. Focus on client-server state consistency, menu state machine, ScaleformUI cues, and edge cases.

### Medium

- [x] **P5-M1 — `racingsystem:race:start` client handler blocks `finished` state but server allows it.** The client handler checked `joinedInstance.state ~= RacingSystem.States.idle` and returned early for non-idle states. But the server handler also accepts `RacingSystem.States.finished` (it resets progress and transitions to staging).

**Fix:** Updated the client handler to also allow `finished` state: `if joinedInstance.state ~= RacingSystem.States.idle and joinedInstance.state ~= RacingSystem.States.finished then return end`.

- [x] **P5-M2 — Start Countdown button flickers re-enabled after click due to premature menu refresh.** The menu's `startCountdownMenuItem.Activated` set `countdownAcceptedByInstanceId[id] = true`, triggered the start event, then immediately called `refreshRaceMenuFromCurrentState()`. At that point the server hadn't processed the event yet, so the state was still `idle`. The refresh saw idle state and cleared `countdownAcceptedByInstanceId[id]`, re-enabling the button.

**Fix:** Removed the immediate `refreshRaceMenuFromCurrentState()` call. The state bag change handler already calls `applyRaceMenuStageFromCurrentState()` and `refreshRaceMenuFromCurrentState()` when the server transitions to `staging`, so the menu updates correctly without the premature refresh.

### Low

- [ ] **P5-L1 — `racingsystem:race:leave` client handler clears local state and traffic control before server confirmation.** The handler resets `localEntrantIdentity.entrantId`, pending checkpoint state, timing, blips, leaderboard, and traffic density, then sends `TriggerServerEvent('racingsystem:race:leave')`. If the server rejects the leave (e.g., state bag out of sync), the client is left in an inconsistent state: local state cleared but still in the race according to the server.

- [x] **P5-L2 — `racingsystem:race:start` client handler has a redundant staging guard.** The check `if joinedInstance.state == RacingSystem.States.staging then return end` was redundant because the next line `if joinedInstance.state ~= RacingSystem.States.idle then return end` already caught `staging`.

**Fix:** Removed the redundant staging check as part of the P5-M1 fix (consolidated into a single state check).

- [ ] **P5-L3 — `racingsystem:race:leave` client handler closes menu before server confirmation.** `MenuHandler:CloseAndClearHistory()` is called after sending the server event. If the server rejects the leave, the menu is already gone and the player has no UI to retry.

- [ ] **P5-L4 — `racingsystem:race:restart` client handler doesn't validate state.** Unlike the start handler, the restart handler only checks for a joined instance and non-empty entrants. It doesn't check that the state is `idle`, `staging`, `countdown`, or `finished`. The server validates, so this is safe, but inconsistent with the start handler's approach.

- [ ] **P5-L5 — `racingsystem:race:start` client handler has owner-fallback logic that duplicates server authorization.** When `ownerSource` is nil/0, the handler falls back to checking if the local player is the first entrant. The server already validates ownership. This client-side guard is a harmless optimization but adds complexity.

### Pass 5 Verification Record

Fixed the three automatable findings (P5-M1, P5-M2, P5-L2). The remaining items are edge-case or cosmetic:

- **P5-L1** (leave clears state before server confirmation) — edge case, requires state-bag desync to trigger.
- **P5-L3** (leave closes menu before server confirmation) — minor UX, menu can be reopened.
- **P5-L4** (restart handler doesn't validate state) — server validates, client guard is optional.
- **P5-L5** (start handler owner-fallback logic) — harmless optimization.

Automated verification after fixes:

- `lua .piTools/test_instance_list_payload.lua` — 130/130 assertions.
- `lua .piTools/test_joined_sync.lua` — 24/24 assertions.
- `lua .piTools/test_event_handlers.lua` — 23/23 assertions.
- `lua .piTools/test_repository_robustness.lua` — 37/37 assertions.
- `python .piTools/audit_lua_globals.py` — 22 compiled production Lua files, no suspicious globals.
- Full production/test `luac -p`, `node --check`, JSON, network-event, dead-code, config-use, documentation-link, and manifest-path checks passed.

**Pass 5 result:** Two lifecycle consistency fixes (client-server state guard alignment, menu flicker elimination) and one dead-code removal. The four deferred items are edge-case or cosmetic. R1–R5 remain the only runtime-dependent items.
