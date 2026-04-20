# Refactoring Plan: performancetuning

## Current Footprint Snapshot
- Resource size is ~393 KB total, with client Lua heavily dominant (~359 KB in `client/` alone).
- Largest files: `client/tuningpackmanager.lua` (~86.2 KB), `client/performancepanel.lua` (~71.2 KB), `client/scaleformui_menus.lua` (~50.1 KB), and `client/client.lua` (~31.1 KB).
- High function count and broad responsibilities indicate a feature-dense client runtime with overlapping concerns.

## Primary Filesize Reduction Opportunities
1. **Split oversized managers by bounded context** (catalog/indexing, persistence, apply/reset, UI bindings, network sync).
2. **Deduplicate handling field definitions and slider metadata** spread across `definitions.lua`, `menusliders.lua`, `handlingmanager.lua`, and panel/menu files.
3. **Consolidate UI rendering/menu-construction helpers** shared between `performancepanel.lua` and `scaleformui_menus.lua`.
4. **Unify runtime binding/sync pathways** (`runtimebindings.lua`, `syncorchestrator.lua`, portions of `client.lua`) to remove repeated event and guard scaffolding.
5. **Move repeated string constants, labels, and keys** to centralized tables to reduce repeated literals.
6. **Retire stale toggles/legacy exports** if no longer referenced by dependents.

## Step-by-Step Refactoring Plan
1. **Perform module boundary extraction for the two largest files first**
   - **Objective:** Decompose `tuningpackmanager.lua` and `performancepanel.lua` into coherent submodules.
   - **Files/areas impacted:** `client/tuningpackmanager.lua`, `client/performancepanel.lua`, new `client/modules/*` files, `fxmanifest.lua` load order.
   - **Rationale for filesize reduction:** Smaller modules expose duplicate logic and allow targeted pruning; lowers repeated control-flow scaffolding.
   - **Risk/validation notes:** Verify menu rendering and tuning apply/reset behavior remain unchanged across all menu paths.

2. **Create shared definitions registry for handling fields and slider descriptors**
   - **Objective:** Single source of truth for field names, min/max, normalization, labels, and display formatting.
   - **Files/areas impacted:** `client/definitions.lua`, `client/menusliders.lua`, `client/handlingmanager.lua`, `client/performancepanel.lua`.
   - **Rationale for filesize reduction:** Eliminates repeated per-file metadata blocks and repeated literal definitions.
   - **Risk/validation notes:** Validate every existing slider still resolves to correct range and formatting in UI.

3. **Centralize UI component builders and shared formatting**
   - **Objective:** Build reusable constructors for repeated panel rows, menu sections, and stat displays.
   - **Files/areas impacted:** `client/scaleformui_menus.lua`, `client/performancepanel.lua`, `client/client.lua`.
   - **Rationale for filesize reduction:** Removes duplicate UI assembly code and repeated presentation strings.
   - **Risk/validation notes:** Regression test all menu trees and panel draw/update timing.

4. **Merge duplicated networking/routing patterns**
   - **Objective:** Consolidate repeated event dispatch, validation, and cooldown guards into one sync layer.
   - **Files/areas impacted:** `client/runtimebindings.lua`, `client/syncorchestrator.lua`, `server/server.lua`, parts of `client/client.lua`.
   - **Rationale for filesize reduction:** A single message-routing abstraction reduces repeated event boilerplate and validation blocks.
   - **Risk/validation notes:** Validate network events for tuning updates, ownership checks, and reconnect behavior.

5. **Compress config/runtime default handling into table-driven resolvers**
   - **Objective:** Replace repeated fallback chains with declarative resolver tables.
   - **Files/areas impacted:** `client/configruntime.lua`, `shared/Config.lua`, call sites in client managers.
   - **Rationale for filesize reduction:** Reduces repeated fallback conditionals and repetitive assignment sections.
   - **Risk/validation notes:** Confirm convar/config precedence order remains exactly the same.

6. **Audit and prune unused exports and legacy code paths**
   - **Objective:** Remove deprecated API surface and dormant code branches in `client/client.lua` and server handlers.
   - **Files/areas impacted:** `client/client.lua`, `server/server.lua`, export list in `fxmanifest.lua`.
   - **Rationale for filesize reduction:** API and dead-path trimming directly reduce code size and long-term maintenance surface.
   - **Risk/validation notes:** Cross-check all external resource calls before removing any exported function.

7. **Standardize update notifier implementation across repository**
   - **Objective:** Replace per-resource notifier variants with a shared internal implementation pattern.
   - **Files/areas impacted:** `server/UpdateNotifier.lua` and cross-resource internal standard.
   - **Rationale for filesize reduction:** Removes repeated near-identical notifier code across resources.
   - **Risk/validation notes:** Keep update-check frequency and error recovery behavior consistent.

## Quick Wins
- Extract repeated label/key strings into one constants table consumed by panel/menu files.
- Merge duplicate slider normalization helpers into a single utility function set.
- Remove commented-out/obsolete tuning presets and one-off debug traces.

## Longer-Term Improvements
- Introduce generated metadata (fields + sliders + labels) from one canonical schema file.
- Add static duplicate-literal and duplicate-function checks in CI.
- Consider shared UI utility package used by both this resource and `vehiclemanager`.

## Scope Note
No files were modified other than this planning document.

