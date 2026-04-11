# customphysics — Structure

## 1) Runtime topology
- **Shared config layer:** `Config.lua` defines `CustomPhysics.Config` defaults and switches.
- **Client utility layer:** `util.lua` provides shared math, vehicle snapshot, frame-timing, and subtitle helpers.
- **Client subsystem layer:** `power.lua`, `wheelies.lua`, `rollovers.lua`, `nitrous.lua` provide modular physics behaviors.
- **Client orchestration layer:** `client.lua` discovers the local driven vehicle and coordinates subsystem updates.
- **Server utility layer:** `UpdateNotifier.lua` handles delayed/manual version checks.

## 2) Client/server relationship
- Physics behavior execution is fully **client-side**.
- Server script is operational-only (update notifications), not an authority for physics state.
- Optional integration reads from other resources (e.g., tuning baseline), but synchronization is not server-driven here.

## 3) Conceptual role separation
- **Core orchestration:** `client.lua`
- **Math/geometry and text helpers:** `util.lua`
- **Power/stability control:** `power.lua`
- **Wheelie controller:** `wheelies.lua`
- **Rollover controller:** `rollovers.lua`
- **Nitrous shot runtime:** `nitrous.lua`
- **Config source:** `Config.lua`
- **Maintenance/update checks:** `UpdateNotifier.lua`

## 4) Call tree (high-level)
1. `fxmanifest.lua` loads shared/client/server scripts.
2. `client.lua` starts three long-running loops and lifecycle handlers.
3. Stability sampler loop calls power stability sampling every 100ms, which is 10 Hz, but only when driven wheels are powered; the sampler itself evaluates the rolling peak-vs-average window over the last 500ms in Gs before deciding whether to reduce anti-boost.
4. Stability recovery loop advances anti-boost using frame-derived waits between samples.
5. Main per-frame loop resolves the driven vehicle and calls subsystem updates in sequence.
6. Vehicle transition/stop triggers override cleanup/reset path.
7. `UpdateNotifier.lua` schedules delayed check and exposes manual command.

## 5) State model
- **Orchestrator state:** current/last vehicle tracking in `client.lua`.
- **Subsystem local state:** each module owns transient runtime state (e.g., active shot, stability metrics, correction state).
- **Stability window state:** `power.lua` keeps a rolling 500ms table of powered measured-acceleration and wheel-baseline entries in Gs.
- **Config state:** immutable-at-runtime defaults from `CustomPhysics.Config` (unless changed by config edits/restarts).
- **Logging state:** no active startup summary logging in `client.lua` (startup summary function is currently a no-op).

The power module no longer exposes one-line state accessors for anti-boost or stability flags; callers read those values through `getDebugSnapshot()` or through the live runtime path inside `power.lua`. The stability snapshot values themselves are now G-based.

No centralized server-managed authoritative state is required for the runtime physics loop.

## 6) Independent threads
| Thread | Where | Role | Start condition | Loop cadence | End condition |
|---|---|---|---|---|---|
| Stability sampler loop | `client.lua` | Samples powered-wheel acceleration inputs in Gs and evaluates the rolling spike check | Client script load | Every 100ms (10 Hz, powered-wheel only) | Stops on resource stop |
| Stability recovery loop | `client.lua` | Advances anti-boost recovery between stability samples | Client script load | Frame-derived wait based on `GetFrameTime()` | Stops on resource stop |
| Main coordinator loop | `client.lua` | Applies rollovers, wheelies, power, nitrous each frame | Client script load | Per-frame (`Wait(0)`) | Stops on resource stop |
| Delayed update-check worker | `UpdateNotifier.lua` | Random-delay version check | `onResourceStart` | One-shot | Ends after check completes |

## 7) Lifecycle boundaries
- **Start:** script load initializes loops and state.
- **Vehicle handoff:** if driven vehicle changes or player exits vehicle, previous vehicle overrides are cleared.
- **Stop:** `onResourceStop` forces final cleanup to prevent stale handling effects.

## 8) Logging and debug behavior (current)
- Runtime physics loops do not emit routine client console logs in current implementation.
- Update-related console output remains in `UpdateNotifier.lua` and is outside the client runtime loop.

