# racingsystem

## Runtime

- Dependencies:
  - `ScaleformUI_Assets`
  - `ScaleformUI_Lua`
- `ui_page`: `ui/index.html`
- `shared_scripts`:
  - `shared/Config.lua`
  - `shared/shared.lua`
- `client_scripts`: see `fxmanifest.lua`
- `server_scripts`: see `fxmanifest.lua`
- Server-owned data (not included in the client file pack):
  - generated `race_index.json`
  - `CustomRaces/*.json`
  - `OnlineRaces/*.json`

## Commands

- `+racemenu`
  - Opens race control menu.
  - Default key mapping: `F7`.

- `-racemenu`
  - Release command for key mapping.

- `/spec`
  - Toggles spectator mode.

## Used Convars

- `ars_skip_uptodate_print`
  - Read via: `GetConvarBool`
  - Effective default: `false`
  - Example: `setr ars_skip_uptodate_print true`

## Notes on host settings in menu

- `Maximum PI` is currently preview-only in UI (not enforced).
- `Late Join %` is sent in race invoke payload and used server-side (`lateJoinProgressLimitPercent`).
