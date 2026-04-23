# proper-handling

## Runtime

- `files` manifest entry: `Active/**/*.meta`
- `data_file` registration: `HANDLING_FILE` -> `Active/**/handling_*.meta`
- `server_script`: `server/UpdateNotifier.lua`

## Active handling files (current checkout)

- `Active/handling_basegame.meta`
- `Active/handling_john_doe.meta`
- `Active/handling_mods.meta`

## Inactive by manifest pattern

The following are not loaded by the current `fxmanifest.lua` pattern:

- `Inactive/handling.meta`
- `Inactive/handling_empty.meta`
- `Inactive/handling_smukk.meta`
- `Inactive/handling_smukoffroad.meta`
- `Inactive/handling_stig.meta`
- `Inactive/handling_tidemo.meta`
- `Inactive/_handling_b_NEW.meta`
- `Inactive/_handling_c_extra.meta`
- `Inactive/_handling_z_chums.meta`
- `Inactive/_handling_z_san_andreas_drift.meta`

## Used Convars

- `ars_skip_uptodate_print`
  - Read via: `GetConvarBool`
  - Effective default: `false`
  - Example: `setr ars_skip_uptodate_print true`
