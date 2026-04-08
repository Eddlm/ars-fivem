# customphysics — Structure

## 1) Runtime topology
- **Shared config layer:** `shared.lua` defines `CustomPhysics.Config` defaults and switches.
- **Client subsystem layer:** `util.lua`, `power.lua`, `wheelies.lua`, `rollovers.lua`, `nitrous.lua` provide modular physics behaviors.
- **Client orchestration layer:** `client.lua` discovers local driven vehicle and coordinates subsystem updates.
- **Server utility layer:** `UpdateNotifier.lua` handles delayed/manual version checks.

## 2) Client/server relationship
- Physics behavior execution is fully **client-side**.
- Server script is operational-only (update notifications), not an authority for physics state.
- Optional integration reads from other resources (e.g., tuning baseline), but synchronization is not server-driven here.

## 3) Conceptual role separation
- **Core orchestration:** `client.lua`
- **Math/geometry helpers:** `util.lua`
- **Power/stability control:** `power.lua`
- **Wheelie controller:** `wheelies.lua`
- **Rollover controller:** `rollovers.lua`
- **Nitrous shot runtime:** `nitrous.lua`
- **Config source:** `shared.lua`
- **Maintenance/update checks:** `UpdateNotifier.lua`

## 4) Call tree (high-level)
1. `fxmanifest.lua` loads shared/client/server scripts.
2. `client.lua` starts two long-running loops and lifecycle handlers.
3. Sampler loop periodically calls power stability sampling.
4. Main per-frame loop resolves driver vehicle and calls subsystem updates in sequence.
5. Vehicle transition/stop triggers override cleanup/reset path.
6. `UpdateNotifier.lua` schedules delayed check and exposes manual command.

## 5) State model
- **Orchestrator state:** current/last vehicle tracking in `client.lua`.
- **Subsystem local state:** each module owns transient runtime state (e.g., active shot, stability metrics, correction state).
- **Config state:** immutable-at-runtime defaults from `CustomPhysics.Config` (unless changed by config edits/restarts).

No centralized server-managed authoritative state is required for the runtime physics loop.

## 6) Independent threads
| Thread | Where | Role | Start condition | Loop cadence | End condition |
|---|---|---|---|---|---|
| Stability sampler loop | `client.lua` | Samples acceleration/stability inputs for power logic | Client script load | Every ~100ms | Stops on resource stop |
| Main coordinator loop | `client.lua` | Applies rollovers, wheelies, power, nitrous each frame | Client script load | Per-frame (`Wait(0)`) | Stops on resource stop |
| Delayed update-check worker | `UpdateNotifier.lua` | Random-delay version check | `onResourceStart` | One-shot | Ends after check completes |

## 7) Lifecycle boundaries
- **Start:** script load initializes loops and debug command.
- **Vehicle handoff:** if driven vehicle changes or player exits vehicle, previous vehicle overrides are cleared.
- **Stop:** `onResourceStop` forces final cleanup to prevent stale handling effects.

