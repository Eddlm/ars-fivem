# customcam — Structure

## 1) Runtime topology
- **Shared config layer:** `Config.lua` defines `CustomCam.Config` consumed by client runtime.
- **Client runtime layer:** `client.lua` owns camera activation, follow behavior, hold-control handling, mirror overlay, and cleanup.
- **Server utility layer:** `UpdateNotifier.lua` runs lightweight version checks and command-based update probing.

## 2) Client/server relationship
- The active gameplay behavior is **client-only** (camera + HUD overlay logic).
- The server-side script does **not** orchestrate camera state; it only handles update notification behavior.
- There is no heavy client↔server state sync path for runtime camera state.

## 3) Conceptual role separation
- **Configuration role:** `Config.lua`
- **Camera orchestration role:** `client.lua`
- **Operational maintenance role (updates):** `UpdateNotifier.lua`

## 4) Call tree (high-level)
1. Resource starts from `fxmanifest.lua`.
2. `Config.lua` exposes config table.
3. `client.lua` initializes state and long-running loops.
4. Player toggles camera path: hold handling only (`toggleControlId` + `toggleHoldMs`) → activation/cleanup helpers → per-frame camera update path.
5. `UpdateNotifier.lua` schedules delayed update check and exposes manual check command.

## 5) State model
- **Camera state:** active/inactive, cam handle existence, look-back status.
- **Mirror state:** tracked nearby vehicles, poll queue/index, accumulator and tracker tables.
- **Control-hint state:** hint progression and timing for tutorial-like prompts.

State ownership is local to `client.lua`; no persisted server authority for these states.

## 6) Independent threads
| Thread | Where | Role | Start condition | Loop cadence | End condition |
|---|---|---|---|---|---|
| Virtual mirror poll/render prep loop | `client.lua` | Maintains virtual mirror candidate tracking and polling windows | Client script load | Per-frame when active; throttled waits when inactive/no vehicle | Stops only on resource stop |
| Main camera runtime loop | `client.lua` | Handles toggle state, control disabling, overlay drawing, and follow-cam updates | Client script load | Per-frame while active; throttled while inactive | Stops only on resource stop |
| Delayed update-check worker | `UpdateNotifier.lua` | Waits randomized delay then runs version check | `onResourceStart` for this resource | One-shot (sleep + execute) | Ends after check completes |

## 7) Lifecycle boundaries
- **Start:** automatic when resource starts and client script is loaded.
- **Stop:** `onResourceStop` cleanup ensures scripted camera is destroyed and runtime state is reset.

## 8) Logging and diagnostics behavior
- `client.lua` does not emit startup banner prints.
- Config warning hook (`warnConfig`) is present but intentionally silent.
- Update notifier keeps operational console output for update availability checks.

