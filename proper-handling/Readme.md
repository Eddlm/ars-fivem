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

### Alternative / preset profiles

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

### Stock reference files (Firecul mirror)

56 raw stock handling files from the game (basegame + every DLC up to the latest), copied from the Firecul GTA-V-Default-Handling-Files repository. These are **reference only** — they hold the untouched default GTA handling values for each content pack and are not loaded by this resource. Useful for auditing which vehicles/IDs `handling_basegame.meta` may be missing.

- `Inactive/common-handling.meta`, `update-handling.meta`, `spupgrade-handling.meta` (basegame)
- `Inactive/mp*-handling.meta` and `Inactive/update-mp*-handling.meta` (all DLC packs through `mp2025_02`)

## Used Convars

- `ars_skip_uptodate_print`
  - Read via: `GetConvarBool`
  - Effective default: `false`
  - Example: `setr ars_skip_uptodate_print true`
