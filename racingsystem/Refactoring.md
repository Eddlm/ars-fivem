# Refactoring Plan: racingsystem

## Current Footprint Snapshot
- Resource size is ~525 KB total across Lua scripts, UI assets, and race JSON datasets.
- Largest scripts are `server/server.lua` (~142 KB, ~3,878 lines) and `client/client.lua` (~122 KB, ~3,332 lines), indicating two major monoliths.
- JSON race data is substantial (~153 KB), mostly in `OnlineRaces/*.json` plus curated examples under `CustomRaces/`.
- UI footprint is relatively small (`ui/app.js`, `ui/index.html`, `ui/style.css`) but still a candidate for string/structure deduplication.

## Primary Filesize Reduction Opportunities
1. **Decompose client/server monolith scripts by domain** (race lifecycle, checkpoint logic, leaderboard/timing, validation/integrity, persistence).
2. **Centralize repeated event/validation scaffolding** currently spread across large event-heavy files.
3. **Normalize race JSON schema and deduplicate repeated per-race keys/default values** (store shared defaults once).
4. **Separate active runtime data from sample/archive race definitions** to reduce shipped payload.
5. **Consolidate repeated UI labels/constants and message contracts** between Lua and NUI layers.
6. **Evaluate manifest file list hygiene** (e.g., mismatched or legacy race index naming artifacts) to avoid shipping unused files.

## Step-by-Step Refactoring Plan
1. **Split server runtime into bounded modules**
   - **Objective:** Break `server/server.lua` into `race_state.lua`, `race_persistence.lua`, `race_events.lua`, and `integrity/rules.lua` style modules.
   - **Files/areas impacted:** `server/server.lua`, `server/integrity.lua`, new `server/modules/*`, `fxmanifest.lua`.
   - **Rationale for filesize reduction:** Modularization exposes repeated blocks and allows removal of dead handlers with less risk.
   - **Risk/validation notes:** Validate all network events still register exactly once and preserve authorization checks.

2. **Split client runtime by feature flow**
   - **Objective:** Decompose `client/client.lua` and `client/InRace.lua` into lifecycle, HUD/UI sync, waypoint/checkpoint flow, and race-state transitions.
   - **Files/areas impacted:** `client/client.lua`, `client/InRace.lua`, `client/util.lua`, new `client/modules/*`.
   - **Rationale for filesize reduction:** Eliminates duplicated race-state checks and transition code spread across multiple large blocks.
   - **Risk/validation notes:** Validate join/start/finish/disconnect/rejoin flows with real multiplayer test cases.

3. **Introduce shared event contract tables**
   - **Objective:** Centralize event names, payload keys, and validation routines used by both sides.
   - **Files/areas impacted:** `shared/shared.lua`, `server/server.lua`, `client/client.lua`.
   - **Rationale for filesize reduction:** Replaces repeated string literals and per-handler defensive scaffolding.
   - **Risk/validation notes:** Ensure compatibility with existing clients and no event name regressions.

4. **Refactor race data into normalized schema with defaults**
   - **Objective:** Move common race metadata/default values to one shared schema and keep JSON files lean.
   - **Files/areas impacted:** `CustomRaces/*.json`, `OnlineRaces/*.json`, race index handling logic.
   - **Rationale for filesize reduction:** Reduces duplicated keys and repetitive per-race metadata across many JSON files.
   - **Risk/validation notes:** Add schema validation pass to ensure backward compatibility with existing saved races.

5. **Separate examples/archive from runtime-loaded race data**
   - **Objective:** Keep only currently required race data in runtime load path; move examples/history to non-runtime documentation/archive location.
   - **Files/areas impacted:** `CustomRaces/`, `OnlineRaces/`, manifest `files` list.
   - **Rationale for filesize reduction:** Prevents unnecessary JSON payload from being distributed to all clients.
   - **Risk/validation notes:** Verify all intended race sets still appear in menu/index after reorganization.

6. **Consolidate UI message and label constants**
   - **Objective:** Centralize repeated NUI action names and labels between Lua and `ui/app.js`.
   - **Files/areas impacted:** `ui/app.js`, `client/menu.lua`, `client/client.lua`, `shared/shared.lua`.
   - **Rationale for filesize reduction:** Removes repeated string constants and duplicated formatting code.
   - **Risk/validation notes:** Validate NUI action dispatch and callback wiring after constant migration.

7. **Prune stale/legacy file references and dead code paths**
   - **Objective:** Remove obsolete index/reference files and unreachable command/debug pathways.
   - **Files/areas impacted:** `fxmanifest.lua`, race index files, `client/menu.lua`, `server/server.lua`.
   - **Rationale for filesize reduction:** Dead asset/script cleanup directly lowers resource package size.
   - **Risk/validation notes:** Confirm no external tooling depends on legacy race index filenames.

8. **Standardize update notifier approach across resources**
   - **Objective:** Align `server/UpdateNotifier.lua` with a shared repository pattern.
   - **Files/areas impacted:** `server/UpdateNotifier.lua` and internal shared strategy.
   - **Rationale for filesize reduction:** Reduces repeated boilerplate in each resource over time.
   - **Risk/validation notes:** Preserve notifier timing and error handling behavior.

## Quick Wins
- Extract event name constants into one shared table.
- Remove test/debug-only race command branches no longer used.
- Keep sample race JSON outside active runtime file list.

## Longer-Term Improvements
- Add automated schema compaction for race JSON (dedupe defaults + sorted keys).
- Introduce server/client module dependency boundaries with lint checks.
- Build a migration tool for race data versioning to safely support future compaction.

## Scope Note
No files were modified other than this planning document.

