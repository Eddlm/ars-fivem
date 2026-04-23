# traffic_control

## Runtime

- `shared_script`: `shared/Config.lua`
- `client_script`: `client/traffic_task.lua`
- `server_scripts`:
  - `server/UpdateNotifier.lua`
  - `server/server.lua`

## Network Events

- Client/Server request event:
  - `traffic_control:requestDensity`
  - Usage: `TriggerServerEvent('traffic_control:requestDensity', value, reason, requestKey)`
- Server -> client apply event:
  - `traffic_control:setMode`

## Used Convars

- `ars_skip_uptodate_print`
  - Read via: `GetConvarBool`
  - Effective default: `false`
  - Example: `setr ars_skip_uptodate_print true`

- `tControlDefault`
  - Read via: `GetConvar`
  - Effective default: no default (`tonumber('')` -> `nil`)
  - Example: `setr tControlDefault 0.5`

- `tControlPrintRequests`
  - Read via: `GetConvarBool`
  - Effective default: `false`
  - Example: `setr tControlPrintRequests true`
