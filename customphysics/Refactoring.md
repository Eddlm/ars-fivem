# Refactoring Plan: customphysics

## Current Footprint Snapshot
- Resource size is ~62 KB total across 11 files.
- Client logic is moderately split already, with notable weight in `client/power.lua` (~21.1 KB), `client/wheelies.lua` (~9.6 KB), and `client/rollovers.lua` (~9.0 KB).
- Utility/config/update scripts are smaller but still candidates for centralization (`client/util.lua`, `shared/Config.lua`, `server/UpdateNotifier.lua`).

## Primary Filesize Reduction Opportunities
1. **Deduplicate vehicle-physics math and state checks** repeated across `power.lua`, `wheelies.lua`, and `rollovers.lua`.
2. **Move repeated tunables/thresholds into structured config tables** in `shared/Config.lua` (instead of scattered scalar locals).
3. **Consolidate nitrous and power-path overlap** (shared boost/torque guard logic) between `nitrous.lua` and `power.lua`.
4. **Introduce single event/state gateway in `client/client.lua`** to reduce repeated polling/thread wrappers.
5. **Standardize update notifier pattern** across resources to avoid copy-maintenance overhead.

## Step-by-Step Refactoring Plan
1. **Inventory duplicated helpers across client modules**
   - **Objective:** Identify common formulas and checks (speed normalization, traction loss tests, airborne checks, wheel contact gating).
   - **Files/areas impacted:** `client/power.lua`, `client/wheelies.lua`, `client/rollovers.lua`, `client/util.lua`.
   - **Rationale for filesize reduction:** A shared helper module prevents repeated function bodies and repeated conditional chains.
   - **Risk/validation notes:** Validate helper output equivalence with before/after telemetry logs for key scenarios.

2. **Create a single physics utility module and rewire imports**
   - **Objective:** Move common logic into one utility namespace and consume it from feature modules.
   - **Files/areas impacted:** `client/util.lua`, feature files in `client/*.lua`, `fxmanifest.lua` load order.
   - **Rationale for filesize reduction:** Removes duplicate code chunks from multiple large files.
   - **Risk/validation notes:** Ensure module load order is deterministic and nil-safe on startup.

3. **Normalize configuration into grouped tables by subsystem**
   - **Objective:** Organize rollover, wheelie, power, and nitrous settings into nested tables.
   - **Files/areas impacted:** `shared/Config.lua`, references in `client/*.lua`.
   - **Rationale for filesize reduction:** Reduces repeated variable naming/assignment boilerplate and simplifies access patterns.
   - **Risk/validation notes:** Confirm all convar policies still map correctly and defaults remain unchanged.

4. **Collapse redundant threads into one orchestration tick where safe**
   - **Objective:** Replace overlapping loops with a single scheduler that dispatches subsystem updates.
   - **Files/areas impacted:** `client/client.lua`, `client/power.lua`, `client/rollovers.lua`.
   - **Rationale for filesize reduction:** Shared loop scaffolding avoids repeated tick wrappers and repeated guard code.
   - **Risk/validation notes:** Verify update cadence for each subsystem remains functionally equivalent.

5. **Prune dead feature flags and dormant code paths**
   - **Objective:** Remove stale experimental branches and disabled tuning branches no longer in use.
   - **Files/areas impacted:** `client/power.lua`, `client/wheelies.lua`, `client/rollovers.lua`, possibly `shared/Config.lua`.
   - **Rationale for filesize reduction:** Dead code removal directly decreases script payload and maintenance burden.
   - **Risk/validation notes:** Run regression checks for edge cases (high-speed rollover prevention and wheelie triggers).

6. **Apply shared update notifier strategy**
   - **Objective:** Use a centralized notifier include/template pattern rather than unique per-resource copies.
   - **Files/areas impacted:** `server/UpdateNotifier.lua` plus cross-resource internal standard.
   - **Rationale for filesize reduction:** Repository-level deduplication reduces repeated boilerplate and future drift.
   - **Risk/validation notes:** Validate periodic checks and fallback behavior remain intact.

## Quick Wins
- Merge duplicate clamp/interpolation helpers into `client/util.lua`.
- Convert repeated threshold locals into grouped config maps.
- Remove commented-out legacy experimental blocks in client modules.

## Longer-Term Improvements
- Define a shared “vehicle physics primitives” module reused by multiple resources.
- Add a duplication audit script to flag identical or near-identical Lua blocks.
- Introduce config schema validation to prevent drift and one-off keys.

## Scope Note
No files were modified other than this planning document.

