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

Pending completion of Pass 2. The loop ends only when remaining items are runtime-dependent or theoretical and all automatable checks pass.
