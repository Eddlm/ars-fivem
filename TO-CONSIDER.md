I make sure to not lose track of the user/admin experience by regularly asking Codex to do sanity checks on features, gameplay, settings and overall experience. I keep its suggestions here, authored and adjusted by me.

# For `customcam`
## Internal code improvements
- Split `client.lua` into follow-cam, hood-cam, and virtual-mirror modules to reduce coupling and regression risk. | Simplicity (4 of 9)
- Move remaining hardcoded constants/input IDs into `shared.lua` and validate ranges at startup. | On it
- Add safer handoff/seed guards when vehicles/entities become invalid mid-transition. | On it
## Admin experience
- Add a debug command to print active camera mode/state and loaded config values. | On it
- Emit startup warnings when camera config values are out of sensible ranges. | On it
## Player experience
- Smooth follow/hood handoffs to reduce abrupt camera snaps. | Simplicity (4 of 9)

# For `customphysics`
## Internal code improvements
- Decompose `power.lua` into subsystem-focused flows (overspeed, offroad, stability, rev limiter). | Simplicity (4 of 9)
- Centralize vehicle guard/reset logic in `client.lua` so all subsystems share one consistency path. | Simplicity (6 of 9)
- Replace tuning magic numbers with config-backed keys and defaults. | On it
## Admin experience
- Document how behavior changes when `performancetuning` state bags are unavailable. | On it
## Player experience
- Smooth ramp-up/ramp-down of power changes after offroad/overspeed events. | Simplicity (5 of 9)
- Tune threshold flicker handling to reduce snap-like wheelie/rollover behavior. | Simplicity (6 of 9)
- Add clearer nitrous active/remaining feedback. | On it

# For `performancetuning`
## Internal code improvements
- Split `tuningpackmanager.lua` and unify tune sync/refresh helpers used across client modules. | Simplicity (3 of 9)
- Harden runtime config coercion/validation so malformed PI/performance values fail predictably. | Simplicity (6 of 9)
- Reuse a shared tune-bucket initializer across serialize/resync/apply paths. | Simplicity (5 of 9)
## Admin experience
- Add maintenance commands to inspect/clean `stable_laptimes.json` by model. | On it
## Player experience
- Show explicit reasons for disabled pack options. | Simplicity (6 of 9)
- Surface PI bars mode (`absolute_benchmark` vs `vehicle_relative`) more clearly. | On it
- Add visible nitrous charge/refill status and quick per-category reset actions. | Simplicity (5 of 9)

# For `racingsystem`
## Internal code improvements
- Consolidate race definition lifecycle helpers (load/save/sync/delete) to remove duplicated naming/path logic. | Simplicity (4 of 9)
- Unify checkpoint serialization between editor/runtime/mission JSON paths. | Simplicity (5 of 9)
- Replace no-op logging with configurable debug logging. | On it
- **ScaleformUI patch candidate:** `UIMenu:GoLeft` and `UIMenu:GoRight` in `ScaleformUI.lua` (lines ~14460 and ~14492) never call `AddTextEntry("UIMenu_Current_Description", self:CurrentItem():Description())`, unlike `GoUp`/`GoDown` which do. This causes the visible description to stay stale (showing the last item that had `:Description()` called on it) when scrolling list items left/right. One-line fix in each function, same pattern as GoUp/GoDown.
## Admin experience
- Gate destructive actions (`kill`, `delete`) behind ACE/role checks. | On it
- Add audit logging for `invoke`, `save`, `delete`, `kill`, and race-completion lifecycle events. | On it
- Expand destructive confirmations with clearer impact scope. | Simplicity (6 of 9)
## Player experience
- Improve clarity of penalty/correction feedback while racing. | On it
- Add a stronger “race started” cue when countdown completes. | On it
- Enrich join/invoke browser and race-finish summary details. | Simplicity (5 of 9)

# For `vehiclemanager`
## Internal code improvements
- Split `client/vehiclemanager.lua` into menu, appearance, persistence, and PT integration modules. | Simplicity (3 of 9)
- Replace duplicated menu branch logic with shared action dispatchers. | Simplicity (5 of 9)
- Move large static appearance/category datasets into dedicated data modules. | Simplicity (6 of 9)
- Strengthen validation/logging across save/update/load payload flows. | On it
## Admin experience
- Add maintenance commands to inspect/list/repair `index_*.json` and payload consistency. | Simplicity (6 of 9)
- Add server tools to delete/inspect saves by ID without manual file edits. | On it
- Emit structured logs for save/update/load/delete requests. | On it
## Player experience
- Improve saved vehicle row metadata (name, plate, time, PI) and overwrite confirmations. | On it
- Improve autosave and load/save status feedback. | On it
- Improve empty-state guidance for “not in vehicle” and “not driver seat” flows. | On it

# Cross-resource priorities (high to lower)
- High: Add explicit admin permission + audit paths for destructive operations (`racingsystem`, `vehiclemanager`).
- High: Standardize debug/diagnostic visibility for live runtime state (`customcam`, `customphysics`, `performancetuning`).
- Medium: Modularize the largest client scripts to reduce regression risk and speed up iteration.
- Medium: Improve player-facing messaging for hidden systems (race penalties/start cues, PI mode, nitrous state).
- Lower: Standardize config validation and startup warnings across all resources.
