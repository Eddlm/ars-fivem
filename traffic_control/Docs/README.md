# traffic_control

## Requirements
- No external dependency is required.
- Native traffic multipliers are applied clientside by this resource.

## Interactions
- `racingsystem` can request temporary traffic density while race participants are active.
- Other resources can also request/clear density through event or exports using request keys.

## How To Use
1. Start `traffic_control`.
2. Set startup baseline density with `setr tControlDefault <number>` (for example `0.0` or `1.0`).
3. From client scripts, use `traffic_control:setMode` with a numeric density and a stable request key; pass `nil` to clear that request.
4. From client scripts, use the `SetTrafficMode`, `SetTrafficDensity`, or `GetTrafficState` exports when you want a direct API instead of an event.
5. From server scripts, use the `SetServerTrafficMode`, `SetServerTrafficDensity`, or `ClearServerTrafficRequest` exports to broadcast a keyed request to all clients.

