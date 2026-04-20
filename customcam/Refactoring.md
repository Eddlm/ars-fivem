# Refactoring Plan: customcam

## Current Footprint Snapshot
- Resource size is ~71 KB total, dominated by `client/client.lua` (~59.6 KB, ~1,390 lines).
- Most logic appears concentrated in one client script, with a separate `Config.lua` and `UpdateNotifier.lua`.
- Lua files account for almost all bytes in this resource.

## Primary Filesize Reduction Opportunities
1. **Break up the large client monolith** into role-based modules (camera state, input handling, mode switching, interpolation/smoothing, debug/diagnostics).
2. **Consolidate repeated camera parameter blocks** (FOV/offset/sensitivity groups) into shared tables to avoid repeated scalar assignments.
3. **Extract reusable utility helpers** (clamp/lerp/vector helpers, safe entity checks, notification wrappers) into a tiny shared helper file used by multiple client modules.
4. **Retire dead debug paths and legacy toggles** in `client/client.lua` if no longer used in production.
5. **Move update notifier implementation to a shared pattern** (cross-resource standard helper) to avoid maintaining near-duplicate notifier logic per resource.

## Step-by-Step Refactoring Plan
1. **Create a module map for the client runtime**
   - **Objective:** Define boundaries before splitting to prevent duplicated responsibilities.
   - **Files/areas impacted:** `client/client.lua`.
   - **Rationale for filesize reduction:** Splitting by role enables aggressive dead-code removal and avoids duplicated state logic.
   - **Risk/validation notes:** Validate camera behavior parity for all camera modes and transitions in a quick in-game smoke test.

2. **Extract configuration-shaped constants into grouped tables**
   - **Objective:** Replace repeated scalar variable sets with cohesive tables (`CameraDefaults`, `InputProfile`, `Smoothing`).
   - **Files/areas impacted:** `Config.lua`, future `client/modules/*`.
   - **Rationale for filesize reduction:** Centralized tables reduce repeated key names/assignment blocks and shrink repetitive condition branches.
   - **Risk/validation notes:** Confirm default values and convar overrides remain identical after table migration.

3. **Split the client entrypoint into modules**
   - **Objective:** Move heavy logic from `client/client.lua` into focused files (e.g., `camera_state.lua`, `camera_update.lua`, `camera_input.lua`, `camera_debug.lua`).
   - **Files/areas impacted:** `client/client.lua`, new client module files, `fxmanifest.lua` load order.
   - **Rationale for filesize reduction:** Smaller modules expose duplicated code patterns and make pruning easier; improves maintainability and reviewability.
   - **Risk/validation notes:** Validate module initialization order and thread lifecycle sequencing.

4. **Introduce a minimal local utility module**
   - **Objective:** Deduplicate helper logic repeated across camera update/input flows.
   - **Files/areas impacted:** `client/client.lua` (or split modules), new `client/util.lua`.
   - **Rationale for filesize reduction:** Shared helpers reduce repeated function bodies and reduce copy/paste drift.
   - **Risk/validation notes:** Benchmark for any frame-time regressions from helper indirection in tight loops.

5. **Prune unused diagnostics and compatibility branches**
   - **Objective:** Remove stale commands, no-op flags, and backward-compatibility code that is no longer required.
   - **Files/areas impacted:** `client/client.lua`, `Config.lua`.
   - **Rationale for filesize reduction:** Dead-path removal directly cuts script bytes and lowers maintenance overhead.
   - **Risk/validation notes:** Validate admin/debug workflows still work for required operators.

6. **Standardize update notifier strategy across resources**
   - **Objective:** Replace per-resource notifier duplication with a shared include/template approach.
   - **Files/areas impacted:** `UpdateNotifier.lua` and shared internal tooling pattern.
   - **Rationale for filesize reduction:** Reduces repeated near-identical boilerplate across repository resources.
   - **Risk/validation notes:** Confirm no behavior loss in update-check cadence and error handling.

## Quick Wins
- Remove or gate debug-only strings/messages from normal runtime paths.
- Collapse repeated camera clamp/default blocks into a single table lookup.
- Rename/internalize one-off helper functions to avoid duplicated utility code.

## Longer-Term Improvements
- Build a reusable “camera core” helper used by other camera-like resources.
- Add a lightweight lint/static pass to detect duplicated literal blocks and unused locals.
- Consider a generated config schema to keep defaults concise and consistent.

## Scope Note
No files were modified other than this planning document.

