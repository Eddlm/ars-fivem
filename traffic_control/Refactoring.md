# Refactoring Plan: traffic_control

## Current Footprint Snapshot
- Resource size is ~14 KB total; very small footprint.
- Main runtime scripts are `client/traffic_task.lua` (~3.1 KB) and `server/server.lua` (~2.5 KB), plus `shared/Config.lua` and `server/UpdateNotifier.lua`.
- Even at small size, there are maintainability gains from standardizing minimal patterns and deduplicating cross-resource boilerplate.

## Primary Filesize Reduction Opportunities
1. **Consolidate config/default resolution** into table-driven logic to avoid repeated scalar handling.
2. **Unify client/server event contracts** (single constants table) to reduce repeated string literals.
3. **Collapse trivial wrapper logic** where event forwarding and guard checks duplicate structure.
4. **Standardize or externalize update notifier pattern** to remove repeated boilerplate across resources.

## Step-by-Step Refactoring Plan
1. **Convert traffic/population settings to grouped config table**
   - **Objective:** Replace scattered scalar lookups with one structured config object.
   - **Files/areas impacted:** `shared/Config.lua`, client/server config access points.
   - **Rationale for filesize reduction:** Table-driven settings remove repeated variable declarations and lookup boilerplate.
   - **Risk/validation notes:** Validate density values remain identical at runtime with default and overridden values.

2. **Create shared event/action constants**
   - **Objective:** Define one source for event names and action keys used by both scripts.
   - **Files/areas impacted:** `shared/Config.lua` or a new shared constants file, `client/traffic_task.lua`, `server/server.lua`.
   - **Rationale for filesize reduction:** Reduces repeated literal strings and prevents drift-driven duplication.
   - **Risk/validation notes:** Confirm event wiring still triggers correctly from both directions.

3. **Merge repetitive guard/validation code into helper functions**
   - **Objective:** Introduce compact helpers for permission checks, numeric clamping, and nil safety.
   - **Files/areas impacted:** `client/traffic_task.lua`, `server/server.lua`.
   - **Rationale for filesize reduction:** Small shared helpers reduce repeated defensive code blocks.
   - **Risk/validation notes:** Verify helper behavior in edge cases (missing config, invalid payloads).

4. **Prune stale debug/log scaffolding if present**
   - **Objective:** Remove non-essential debug messages and legacy branches not used in production.
   - **Files/areas impacted:** client/server scripts.
   - **Rationale for filesize reduction:** Dead-path cleanup keeps tiny resources lean and clear.
   - **Risk/validation notes:** Keep required operational logging if used for server diagnostics.

5. **Adopt shared update notifier strategy**
   - **Objective:** Align notifier implementation with cross-resource standard pattern.
   - **Files/areas impacted:** `server/UpdateNotifier.lua` plus shared internal strategy.
   - **Rationale for filesize reduction:** Removes repeated boilerplate repository-wide.
   - **Risk/validation notes:** Confirm update-check behavior remains stable.

## Quick Wins
- Move event names to one shared constants table.
- Replace repeated numeric fallback logic with one helper.
- Remove any obsolete debug toggles from runtime path.

## Longer-Term Improvements
- Consider folding this resource into a shared environment-control module if ownership/domain overlap exists.
- Add lint rule(s) for duplicate string literals and tiny-function duplication.
- Keep a template for micro-resources to avoid boilerplate growth over time.

## Scope Note
No files were modified other than this planning document.

