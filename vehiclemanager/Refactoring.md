# Refactoring Plan: vehiclemanager

## Current Footprint Snapshot
- Resource size is ~214 KB total.
- Major script concentration in `client/vehiclemanager.lua` (~89.0 KB, ~2,541 lines), with supporting server logic in `server/vehicle_saves.lua` (~17.2 KB) and large `Config.lua` (~14.2 KB).
- Data payload includes many `savedvehicles/*.json` files (~85.3 KB total) currently listed in manifest file scope.

## Primary Filesize Reduction Opportunities
1. **Break up the large client manager script** by feature area (UI flows, actions, filters/search, integration hooks, persistence client calls).
2. **Normalize configuration into nested domain tables** (menu labels, keybinds, permissions, defaults, integration flags) to reduce repeated scalar blocks.
3. **Deduplicate repeated vehicle action handlers** (spawn/store/rename/delete/export/import patterns) through shared action pipelines.
4. **Refactor JSON storage strategy** to reduce distributed static payload when many saved vehicle records are not needed client-side at resource load time.
5. **Consolidate server validation and serialization helpers** in `server/vehicle_saves.lua`.
6. **Standardize notifier pattern** to reduce repeated cross-resource updater boilerplate.

## Step-by-Step Refactoring Plan
1. **Define client module boundaries and extract UI orchestration first**
   - **Objective:** Split `client/vehiclemanager.lua` into modules such as `ui_menu.lua`, `vehicle_actions.lua`, `filters.lua`, `integration.lua`, `state.lua`.
   - **Files/areas impacted:** `client/vehiclemanager.lua`, new `client/modules/*`, `fxmanifest.lua` ordering.
   - **Rationale for filesize reduction:** Modular extraction reveals duplicate code segments and enables targeted pruning.
   - **Risk/validation notes:** Validate all menu navigation paths and keybind actions after rewire.

2. **Centralize repeated constants/labels and action metadata**
   - **Objective:** Move repeated strings, button labels, and command metadata to dedicated constants tables.
   - **Files/areas impacted:** `Config.lua`, client modules.
   - **Rationale for filesize reduction:** Reduces repeated literals and repeated descriptor blocks in UI/action code.
   - **Risk/validation notes:** Confirm localization/display strings still render as expected.

3. **Convert config scalar groups into structured sections**
   - **Objective:** Replace flat config with grouped tables (`UI`, `Permissions`, `Storage`, `Integrations`, `Defaults`).
   - **Files/areas impacted:** `Config.lua`, all config consumers.
   - **Rationale for filesize reduction:** Table grouping reduces repetitive variable declarations and condition chains.
   - **Risk/validation notes:** Validate all call sites after key path changes and ensure backward compatibility if needed.

4. **Unify client action execution flow**
   - **Objective:** Route spawn/store/delete/etc. through one action dispatcher with shared prechecks and post-hooks.
   - **Files/areas impacted:** `client/vehiclemanager.lua` (or split action module).
   - **Rationale for filesize reduction:** Removes repeated validation and result handling code per action.
   - **Risk/validation notes:** Test each action under success/failure cases, including integration-dependent branches.

5. **Refactor server save logic into serializers + repositories**
   - **Objective:** Separate validation, file naming, serialization, and persistence operations in `server/vehicle_saves.lua`.
   - **Files/areas impacted:** `server/vehicle_saves.lua`.
   - **Rationale for filesize reduction:** Shared helper path removes repeated guard/IO code blocks and simplifies handlers.
   - **Risk/validation notes:** Validate no data loss with read/write/overwrite operations across existing save files.

6. **Reassess manifest-level JSON shipping scope**
   - **Objective:** Ensure only necessary save data is included in runtime distribution, and archive/historical files are kept out of default shipped set.
   - **Files/areas impacted:** `savedvehicles/*.json`, `fxmanifest.lua` `files` list, persistence workflow.
   - **Rationale for filesize reduction:** Reduces static file payload when large historical save sets accumulate.
   - **Risk/validation notes:** Validate loading behavior for currently needed saves and migration path for archived records.

7. **Prune legacy or unused command/event paths**
   - **Objective:** Remove dormant commands/events and one-off debug flows that are no longer exercised.
   - **Files/areas impacted:** `client/vehiclemanager.lua`, `server/vehicle_saves.lua`.
   - **Rationale for filesize reduction:** Dead-path cleanup directly shrinks scripts and reduces future maintenance overhead.
   - **Risk/validation notes:** Confirm no external resources depend on removed commands/events.

8. **Adopt shared update notifier implementation strategy**
   - **Objective:** Replace unique notifier instance with repository-standard shared pattern.
   - **Files/areas impacted:** `UpdateNotifier.lua` and internal cross-resource standard.
   - **Rationale for filesize reduction:** Prevents repeated boilerplate and drift across resources.
   - **Risk/validation notes:** Ensure update-check cadence and error reporting remain consistent.

## Quick Wins
- Extract repeated menu label/action definitions to one constants table.
- Deduplicate repeated vehicle action validation code into one helper.
- Archive or externalize stale save JSON files not required for active runtime behavior.

## Longer-Term Improvements
- Introduce schema/versioning for saved vehicle JSON to allow compaction and migration.
- Build shared UI utility layer for this resource and `performancetuning`.
- Add duplicate-code scanning to detect recurring logic across client/server paths.

## Scope Note
No files were modified other than this planning document.

