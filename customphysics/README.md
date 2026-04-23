# customphysics

## Runtime

- `shared_script`: `shared/Config.lua`
- `client_scripts`:
  - `client/util.lua`
  - `client/wheelies.lua`
  - `client/rollovers.lua`
  - `client/power.lua`
  - `client/client.lua`
- `server_script`: `server/UpdateNotifier.lua`

## Used Convars

- `ars_skip_uptodate_print`
  - Read via: `GetConvarBool`
  - Effective default: `false`
  - Example: `setr ars_skip_uptodate_print true`

- `cPhysicsPrintLevel`
  - Read via: `GetConvarInt`
  - Effective default: `0`
  - Example: `setr cPhysicsPrintLevel 2`

- `cp_offroad_boost_enabled`
  - Read via: `GetConvarBool`
  - Effective default: `true`
  - Example: `setr cp_offroad_boost_enabled true`

- `cp_offroad_max_multiplier`
  - Read via: `GetConvar`
  - Effective default: `5.0`
  - Example: `setr cp_offroad_max_multiplier 5.0`

- `cp_rollovers_enabled`
  - Read via: `GetConvarBool`
  - Effective default: `true`
  - Example: `setr cp_rollovers_enabled true`

- `cp_rollover_start_speed`
  - Read via: `GetConvar`
  - Effective default: `8.94`
  - Example: `setr cp_rollover_start_speed 8.94`

- `cp_rollover_keep_speed`
  - Read via: `GetConvar`
  - Effective default: `6.71`
  - Example: `setr cp_rollover_keep_speed 6.71`

- `cp_rollover_start_rot`
  - Read via: `GetConvar`
  - Effective default: `180.0`
  - Example: `setr cp_rollover_start_rot 180.0`

- `cp_rollover_keep_rot`
  - Read via: `GetConvar`
  - Effective default: `90.0`
  - Example: `setr cp_rollover_keep_rot 90.0`

- `cp_wheelies_enabled`
  - Read via: `GetConvarBool`
  - Effective default: `true`
  - Example: `setr cp_wheelies_enabled true`

- `cp_wheelies_muscle_only`
  - Read via: `GetConvarBool`
  - Effective default: `true`
  - Example: `setr cp_wheelies_muscle_only true`

- `cp_wheelies_native_disabled`
  - Read via: `GetConvarBool`
  - Effective default: `true`
  - Example: `setr cp_wheelies_native_disabled true`
