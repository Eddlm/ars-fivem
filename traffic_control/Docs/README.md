# traffic_control

## Requirements
- No external dependency is required.
- Native traffic multipliers are applied clientside by this resource.

## Interactions
- `racingsystem` can request temporary traffic density while race participants are active.
- Other resources can request/clear density through server events using request keys.

## How To Use
1. Start `traffic_control`.
2. Optional baseline density: `setr tControlDefault <number>` (for example `0.0` or `1.0`).
3. From client scripts:
   - `TriggerServerEvent('traffic_control:requestDensity', density, reason, requestKey)`
   - Clear by sending `density = nil` with the same `requestKey`.
4. From server scripts:
   - `TriggerEvent('traffic_control:requestDensity', density, reason, requestKey)`
   - Clear by sending `density = nil` with the same `requestKey`.
5. Request keying on server:
   - Client-origin key: `client:<playerSource>:<requestKey>`
   - Server-origin key: `server:<requestKey>` (prefix configurable).
6. Optional request log printing:
   - `setr tControlPrintRequests "true"`
   - Allowed values: `true`, `false`.

## Runtime Rules
- Requests are numeric-only (numeric strings are accepted).
- Non-numeric non-`nil` values are ignored and do not mutate existing request state.
- `nil` clears the specified key.
- Effective density is always the lowest active keyed request.
- If no requests are active, `tControlDefault` is used only when numeric; otherwise, runtime is idle.
- If `tControlPrintRequests` is `true`, request set/clear/reject activity is printed to the server console.

