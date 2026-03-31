
# In brief:

`[ars-fivem]` is a racing/car oriented resource pack for Fivem. "ARS" comes from my ongoing singleplayer project, [Autosport Racing System](https://www.gta5-mods.com/scripts/autosport-racing-system).


**This is FiveM only, Server-install only. no SP.**

| Resource | Requirements | Features | Hotkey | Interfunctionality |
| --- | --- | --- | --- | --- |
| racingsystem | [ScaleformUI](https://github.com/manups4e/ScaleformUI/releases) | Create and host checkpoint races | `F7` | Can load GTAO races |
| performancetuning | [ScaleformUI](https://github.com/manups4e/ScaleformUI/releases) | Live tuning, nitrous, PI system, handling exports | `/ptune` | Can be opened through `vehiclemanager` instead. Needs `customphysics` to apply Nitro |
| vehiclemanager | [ScaleformUI](https://github.com/manups4e/ScaleformUI/releases) | Handy save/load/tune menu | `F5` | Saved cars retain `performancetuning` tweaks |
| customcam | None | Freeform follow camera, hood view, rear-look support | Hold Change Camera (`V` on PC) | None |
| customphysics | None | Powerslides, wheelies, rollovers, offroad and overspeed fixes | None | Reads `performancetuning` state for rev limiter and top-speed baseline when available |

---
<br>

# Installation
Each resource can go anywhere inside `server-data\resources`, ensure them one by one. I reccomend `[eddlm]` or `[ars-fivem]` for clarity when going through your folders. Do not ensure the entire folder, they need a special order to load. 

[Proper Handling](https://github.com/Eddlm/TheNewHandlingProject) goes well with this pack.

### Load Order

```cfg
ensure ScaleformUI_Assets
ensure ScaleformUI_Lua

ensure racingsystem
ensure performancetuning
ensure vehiclemanager
ensure customcam
ensure customphysics
```

Remember you do not need to install all, they don't require each other. You can just install racingsystem or customphysics or whatever.

## Contributing and Feedback

| Github | Discord | FiveM Server |
| --- | --- | --- |
| Use the [issues](https://github.com/Eddlm/ars-fivem/issues) system, **NOT** pull requests. | I am available on [The Nation]() and [Vanillaworks]()#handling-help | Join [Server](https://servers.fivem.net/servers/detail/2ryx47), tour the features, complain. |


### Focus on improvements and not new features.

# In Depth

## Resource customcam

- It follows the car in a more freeform manner and has some logic to stay useful while sliding, stopped, reversing, tumbling around... etc. Gif below.
- **No driveby support for now.**

## Resource customphysics
Packs a few QoL systems related to car physics.

### The Powerslides
Allows cars to retain their power when sliding, or adds enough to powerslide.  
Its  a rewrite of Inverse-Torque to LUA with more natural behavior.

### The Wheelies
Kills the OG wheelie system and replaces it with a more natural one that targets a specific angle.  
It also has some complex logic to keep it going or kill it depending on what wheels stay in the ground, so it feels natural (even though they're magical forces pushing the car around)
- Locked to Muscles, can be unlocked for all cars.
- Can give a slight launch advantage, but not too much. 
### The (Hollywood) Rollovers 
Port of the SP one, incentivates cars to roll and tumble when they're unstable an off balance.
- It can be invasive. Check its config file and adjust.
### The Offroad speed
We all know cars lose way too much speed off the road.  
This counters it to allow any vehicle to reach its stop speed off the road too. At least, closer to it. Its a complicated problem.

### The Over-speed issues
Deals with bugs like kerb-boosting and suspension-boosting.  
How aggresively it combats the bugs is configurable.

- Can optionally read tuning baseline data exposed by `performancetuning`.

## Resource performancetuning

- Provides live tuning packs and tweak sliders for engine, transmission, suspension, brakes, tires, and nitrous.
- Includes a ScaleformUI tuning menu, performance panel, and PI/class display.
- Exposes handling read/write exports for other resources.

## Resource racingsystem

- Includes an in-game race menu/editor for creating, invoking, joining, and managing races.
- Supports local custom race files and bundled online race definitions.
- Tracks live race instances, lap timing, and best laps.

## Resource vehiclemanager

- Acts as the main vehicle hub/menu for save, load, and vehicle utility flows.
- Integrates with `performancetuning` for customization and stats access.
- Uses persistent saved vehicle JSON files stored inside the resource.

# Credits / Attributions / References

| Author | Content | Link |
| --- | --- | --- |
| MAFINS & itsjustcurtis | The entire vehicle save/load system I ripped off the Menyoo Repo. | [Menyoo Repo](https://github.com/itsjustcurtis/MenyooSP) |
| Jaymo1011 | I learned GTAO's jobs are a JSON on their site thanks to his repo. Wrote my own loader though. | [mission-json-loader Repo](https://github.com/jaymo1011/mission-json-loader) |
| ![medal](media/obamamedal_100h.jpg) | A big chunk here is a rewrite of my own older content from SP. | [My SP content](https://www.gta5-mods.com/users/eddlm) |
