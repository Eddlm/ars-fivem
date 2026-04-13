# traffic_control — Structure

## 1) Runtime topology
- **Shared config layer:** `shared/Config.lua` defines `TrafficControl.Config` (server request prefix and update-check tunables).
- **Client runtime layer:** `client/traffic_task.lua` owns keyed density requests, computes effective density, and applies per-frame multipliers.
- **Server request layer:** `server/server.lua` broadcasts keyed numeric density requests and clear signals.

## 2) Client/server relationship
- Server does not directly set population natives.
- Scripts send request events to server (`traffic_control:requestDensity`).
- Server sends `traffic_control:setMode` events to clients with resolved request keys.
- Each client resolves active request state locally, then applies per-frame density multipliers.

## 3) Conceptual role separation
- **Configuration role:** `shared/Config.lua`
- **Execution role:** `client/traffic_task.lua`
- **Orchestration role:** `server/server.lua`

## 4) Call tree (high-level)
1. Resource starts from `fxmanifest.lua`.
2. `shared/Config.lua` initializes shared `TrafficControl.Config`.
3. `server/server.lua` registers `traffic_control:requestDensity` and routes updates to clients.
4. `client/traffic_task.lua` receives routed updates, resolves keyed requests, and starts the frame loop.
5. Client runtime enforces effective density continuously when a numeric value is available.

## 5) State model
- `requestsByKey` in `client/traffic_task.lua`: map of request key -> numeric density.
- `requestMetaByKey` in `client/traffic_task.lua`: map of request key -> last reason text.
- `state.effectiveDensity`: lowest active request density, or numeric `tControlDefault`, or `nil` (idle).
- `state.source`: `request`, `default`, or `idle`.

## 6) Independent threads
| Thread | Where | Role | Start condition | Loop cadence | End condition |
|---|---|---|---|---|---|
| Frame density enforcement | `client/traffic_task.lua` | Rebuilds effective state and applies vehicle/ped/scenario multipliers when numeric | Client script load | `Wait(0)` | Resource stop |

## 7) Lifecycle boundaries
- **Start:** request map is empty and effective state is resolved from active requests/default/idle.
- **ConVar fallback:** when no requests are active, `tControlDefault` is used only if numeric.
- **Update path:** scripts trigger `traffic_control:requestDensity`; server routes `traffic_control:setMode` updates to client runtime, and `density=nil` clears the request key.
- **Stop:** no special teardown handler is required; native effects cease when thread loop stops.

## 8) Logging and diagnostics behavior
- Runtime currently avoids routine console logging for mode/density operations.
- With `tControlPrintRequests=true`, server prints request set/clear/reject activity.
