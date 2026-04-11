# traffic_control — Structure

## 1) Runtime topology
- **Shared config layer:** `shared/Config.lua` defines `TrafficControl.Config` (default mode, named profiles, legacy mode densities, and server request tunables).
- **Client compatibility layer:** `client/client.lua` exposes `TrafficControlConfig` as a legacy alias for `TrafficControl.Config`.
- **Client runtime layer:** `client/traffic_task.lua` owns active traffic state, applies density/profile values, and handles client-side events/exports.
- **Server request layer:** `server/server.lua` broadcasts mode/density requests and exposes server-side exports for keyed requests.

## 2) Client/server relationship
- Server does not directly set population natives.
- Server sends `traffic_control:setMode` events to clients with a request key.
- Each client resolves active request state locally, then applies per-frame density and periodic persistent controls.

## 3) Conceptual role separation
- **Configuration role:** `shared/Config.lua`
- **Compatibility role:** `client/client.lua`
- **Execution role:** `client/traffic_task.lua`
- **Orchestration role:** `server/server.lua`

## 4) Call tree (high-level)
1. Resource starts from `fxmanifest.lua`.
2. `shared/Config.lua` initializes shared `TrafficControl.Config`.
3. `client/client.lua` provides the legacy `TrafficControlConfig` alias.
4. `client/traffic_task.lua` applies default mode, registers net event/exports, and starts runtime threads.
5. `server/server.lua` exposes exports that emit request events to clients.
6. Client runtime resolves active request and enforces traffic/ped behavior continuously.

## 5) State model
- `trafficState` in `client/traffic_task.lua`: current mode/profile/reason.
- `trafficRequests` in `client/traffic_task.lua`: map of request-owner key -> request payload (`mode` or `multiplier`).
- Active request is selected as the newest explicit request in the map and converted into runtime profile data.
- If there are no explicit requests, runtime falls back to `TrafficControl.Config.defaultMode`.

## 6) Independent threads
| Thread | Where | Role | Start condition | Loop cadence | End condition |
|---|---|---|---|---|---|
| Frame density enforcement | `client/traffic_task.lua` | Applies vehicle/ped/scenario density multipliers each frame from active profile | Client script load | `Wait(0)` | Resource stop |
| Persistent control enforcement | `client/traffic_task.lua` | Re-applies boats/garbage/cops/parked-vehicle controls | Client script load | `Wait(1000)` | Resource stop |

## 7) Lifecycle boundaries
- **Start:** default mode is applied from `TrafficControl.Config.defaultMode` (`normal` by default).
- **ConVar override:** `tControlDefault` overrides startup baseline density (e.g. `1.0`).
- **Update path:** `traffic_control:setMode` updates request map and active state; server exports emit the same event to all clients.
- **Stop:** no special teardown handler is required; native effects cease when thread loop stops.

## 8) Logging and diagnostics behavior
- Runtime currently avoids routine console logging for mode/density operations.
- The server exports do not print usage/status output in current implementation.
- No convar-driven debug toggle is used.
