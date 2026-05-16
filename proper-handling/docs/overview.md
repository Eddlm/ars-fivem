# Proper Handling — Overview

Proper Handling Physics is a **data-only** resource that overrides GTA V's default vehicle handling with a curated set of physics profiles. It has no client or server logic beyond the update notifier — all behaviour comes from `.meta` handling files loaded by FiveM's `HANDLING_FILE` data mechanism.

## What It Does

- Replaces the base game handling for **640 vehicles** with custom-tuned values inspired by a mix of GTA IV and GTA V physics.
- Adds handling overrides for **69 mod vehicles** and **42 "John Doe" placeholders**.
- Provides a set of **inactive** alternative handling profiles that can be manually swapped in.

## Quick Start

1. Drop `proper-handling` into your resources directory.
2. Add `ensure proper-handling` to your `server.cfg`.
3. FiveM loads all `.meta` files matching `Active/**/handling_*.meta` as handling overrides.

## How to Switch Handling Profiles

The resource uses two folders:

| Folder      | Loaded by FiveM?                                                             | Purpose                                         |
| ----------- | ---------------------------------------------------------------------------- | ----------------------------------------------- |
| `Active/`   | ✅ Yes — matched by the `files` and `data_file` patterns in `fxmanifest.lua` | Currently active handling overrides             |
| `Inactive/` | ❌ No — not referenced by the manifest                                       | Available but disabled profiles you can swap in |

To activate a different profile, move the `.meta` file from `Inactive/` into `Active/` and restart the resource. To deactivate, move it back.

## Active Handling Files

| File                     | Vehicles | Description                                       |
| ------------------------ | -------- | ------------------------------------------------- |
| `handling_basegame.meta` | 640      | Overhauls all base-game vehicle handling          |
| `handling_mods.meta`     | 69       | Handling for common add-on/mod vehicles           |
| `handling_john_doe.meta` | 42       | Placeholder handling for vehicles not yet covered |

## Inactive Handling Files

| File                                 | Description                       |
| ------------------------------------ | --------------------------------- |
| `handling.meta`                      | Legacy/stock handling             |
| `handling_empty.meta`                | Empty template                    |
| `handling_smukk.meta`                | Smukk handling preset             |
| `handling_smukoffroad.meta`          | Smukk off-road variant            |
| `handling_stig.meta`                 | Stig handling preset              |
| `handling_tidemo.meta`               | TideMo handling preset            |
| `_handling_b_NEW.meta`               | Newer experimental base handling  |
| `_handling_c_extra.meta`             | Extra vehicle handling supplement |
| `_handling_z_chums.meta`             | Chums handling preset             |
| `_handling_z_san_andreas_drift.meta` | San Andreas drift handling preset |

⚠️ Files prefixed with `_` in the `Inactive/` folder are intentionally sorted to the end by convention — they are alternative presets, not default overrides.

## See Also

- [Update Notifier](update-notifier.md)
