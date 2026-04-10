# VS Code IntelliSense for This Resource Pack

This repository includes a root `.luarc.json` so Lua Language Server can provide IntelliSense for:

- FiveM runtime globals and natives from the local FXServer source
- `ScaleformUI_Lua` symbols for the UI-heavy resources

## Recommended Setup

1. Open the repository root in VS Code.
2. Install the `Lua` extension that uses Lua Language Server.
3. Let VS Code load the repo root `.luarc.json`.
4. Reload the window if completions do not appear immediately.

## What You Should See

- Completion for common FiveM helpers such as `CreateThread`, `Wait`, `RegisterNetEvent`, `TriggerServerEvent`, and `TriggerClientEvent`
- Hover and autocomplete for `ScaleformUI.*` in `performancetuning`, `racingsystem`, and `vehiclemanager`
- Better recognition of vector helpers such as `vector3`

## Notes

- The config points at local sibling folders, so keep `FXServer` and `ScaleformUI_Lua` in the same overall workspace layout.
- `ScaleformUI_Assets` is intentionally not part of IntelliSense indexing because it does not contribute Lua symbols.
- If you move the folders later, update the two library paths in `.luarc.json`.

