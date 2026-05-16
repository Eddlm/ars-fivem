# Custom Camera — Overview

Customcam is a **drone-style follow camera** for FiveM that replaces the default GTA V chase camera with a smoother, more cinematic driving view. It also includes a **hood camera** that snaps to the vehicle body, and a **virtual rear-view mirror** overlay that dots nearby vehicles on a 2D HUD strip.

## Features at a Glance

| Feature             | What it does                                                                                                                                    |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| **Follow Camera**   | A spring-damped chase cam that trails the player's vehicle with velocity look-ahead, multi-distance view modes, and flip/upright recovery.      |
| **Hood Camera**     | A first-person camera that raycasts onto the vehicle body and hard-attaches to a valid surface point. Toggled via the in-game camera view mode. |
| **Virtual Mirror**  | A screen-top HUD overlay that projects nearby rear vehicles as headlight-pair dots, colour-coded by facing direction.                           |
| **Update Notifier** | Server-side startup check that prints a console message when a newer version is available on GitHub.                                            |

## Quick Start

1. Drop the `customcam` resource folder into your server's `resources` directory.
2. Add `ensure customcam` to your `server.cfg` (or your resource's `fxmanifest.lua`).
3. While driving, **hold the "Next Camera" input** (`INPUT_NEXT_CAMERA` / `V` by default) for one second to toggle the custom camera on or off.
4. Use the in-game camera view cycle (`V` tap or `Q` on controller) to switch between follow distances and **hood view** (view mode 4).

## Controls

| Input                                  | Default Binding         | Action                                                             |
| -------------------------------------- | ----------------------- | ------------------------------------------------------------------ |
| `INPUT_NEXT_CAMERA` (control `0`)      | `V`                     | Hold for 1 s to toggle custom camera on/off                        |
| `INPUT_VEH_LOOK_BEHIND` (control `79`) | `C` (tap while driving) | Look backwards (mirrors follow cam direction, flips hood cam rear) |

Both control IDs are configurable via `Config.Controls` in `Config.lua`.

## File Layout

```
customcam/
  fxmanifest.lua        — Resource descriptor
  Config.lua            — All tuneable constants
  client/
    client.lua          — Main camera + mirror + toggle logic
  UpdateNotifier.lua    — Server-side version check
  docs/
    …                   — You are here
```

## See Also

- [Configuration reference](configuration.md)
- [Follow Camera details](follow-camera.md)
- [Hood Camera details](hood-camera.md)
- [Virtual Mirror details](virtual-mirror.md)
- [Update Notifier](update-notifier.md)
