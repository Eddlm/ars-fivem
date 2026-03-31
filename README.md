

![Harvey](media/harvey.jpg)

# In brief:

`[ars-fivem]` is a racing/car oriented resource pack for Fivem. "ARS" comes from my ongoing singleplayer project, [Autosport Racing System](https://www.gta5-mods.com/scripts/autosport-racing-system).


| Resource | Requirements | Features | Hotkey | Interfunctionality |
| --- | --- | --- | --- | --- |
| racingsystem | [ScaleformUI](https://github.com/manups4e/ScaleformUI/releases) | Create and host checkpoint races | `F7` | Can load GTAO races |
| performancetuning | [ScaleformUI](https://github.com/manups4e/ScaleformUI/releases) | Live tuning, nitrous, PI system, handling exports | `/ptune` or via Vehicle Manager | Can be opened through `vehiclemanager` instead \| Needs `customphysics` to apply Nitro |
| vehiclemanager | [ScaleformUI](https://github.com/manups4e/ScaleformUI/releases) | Handy save/load/tune menu | `F5` | Saved cars retain `performancetuning` tweaks |
| customcam | None | Freeform follow camera, hood view, rear-look support | Hold Change Camera (`V` on PC) | None |
| customphysics | None | Powerslides, wheelies, rollovers, offroad and overspeed fixes | None | Reads `performancetuning` state for rev limiter and top-speed baseline when available |
---
## Contributing and Feedback

| Github | Discord | FiveM Server |
| --- | --- | --- |
| Use the [issues](https://github.com/Eddlm/ars-fivem/issues) system, **NOT** pull requests. | I am available on [The Nation]() and [Vanillaworks]()#handling-help |  |

# Resources

## customcam

- Toggled with holding < ChangeCamera > (V on PC) while in a car, it follows the car in a more freeform manner. Gif below.
- **No driveby support for now.**

## customphysics
Packs a few QoL systems related to car physics.
### Powerslides
Allows cars to retain their power when sliding, or adds enough to powerslide.  
Its  a rewrite of Inverse-Torque to LUA with more natural behavior.

### Wheelies
Kills the OG wheelie system and replaces it with a more natural one that targets a specific angle.  
It also has some complex logic to keep it going or kill it depending on what wheels stay in the ground, so it feels natural (even though they're magical forces pushing the car around)
- Locked to Muscles, can be unlocked for all cars.
- Can give a slight launch advantage, but not too much. 
### (Hollywood) Rollovers 
Port of the SP one, incentivates cars to roll and tumble when they're unstable an off balance.
- It can be invasive. Check its config file and adjust.
### Offroad speed
We all know cars lose way too much speed off the road.  
This counters it to allow any vehicle to reach its stop speed off the road too. At least, closer to it. Its a complicated problem.

### Over-speed issues
Deals with bugs like kerb-boosting and suspension-boosting.  
How aggresively it combats the bugs is configurable.

- Can optionally read tuning baseline data exposed by `performancetuning`.

## performancetuning

- Provides live tuning packs and tweak sliders for engine, transmission, suspension, brakes, tires, and nitrous.
- Includes a ScaleformUI tuning menu, performance panel, and PI/class display.
- Exposes handling read/write exports for other resources.

## racingsystem

- Includes an in-game race menu/editor for creating, invoking, joining, and managing races.
- Supports local custom race files and bundled online race definitions.
- Tracks live race instances, lap timing, and best laps.

## vehiclemanager

- Acts as the main vehicle hub/menu for save, load, and vehicle utility flows.
- Integrates with `performancetuning` for customization and stats access.
- Uses persistent saved vehicle JSON files stored inside the resource.

# Requirements

- A working FiveM server setup.
- [ScaleformUI](https://github.com/manups4e/ScaleformUI/releases) for `ScaleformUI_Assets` and `ScaleformUI_Lua`
- ScaleformUI is not included in this repository and is expected to exist above this folder in your server resource tree.

# Installation

1. Place or keep this repository at `resources/[CustomContent]/[eddlm]/[ars-fivem]` in your FiveM server.
2. Make sure `ScaleformUI_Assets` and `ScaleformUI_Lua` are installed in your server resources and loaded before this pack.
3. Manage startup order from `server-data/server.cfg`.
4. Add or verify the following `ensure` lines in that load order.

# Load Order

```cfg
ensure ScaleformUI_Assets
ensure ScaleformUI_Lua
ensure racingsystem
ensure performancetuning
ensure vehiclemanager
ensure customcam
ensure customphysics
```
