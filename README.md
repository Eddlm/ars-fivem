

## Youtube "showcase"
[![Showcase Video](https://img.youtube.com/vi/wnlUr-YwVt0/0.jpg)](https://www.youtube.com/watch?v=wnlUr-YwVt0)

### In active development. Each script will print when there is an update in your FXServer, ~weekly.

# TL;DR
Its a system focused on better driving and racing, that's it. It has modules focusing on each aspect:

| Module | Hotkey / Command | Requirements | Readme | What it does |
| --- | --- | --- | --- | --- |
| `racingsystem` | `F7` (`+racemenu`) | [ScaleformUI](https://github.com/manups4e/ScaleformUI/releases) | [README](racingsystem/README.md) | Implements checkpoint races and a race editor to plop your checkpoints. Also loads GTAO Races. |
| `performancetuning` | `F6` (`+ptmenu`), not bound if you got vehmanager. | [ScaleformUI](https://github.com/manups4e/ScaleformUI/releases) | [README](performancetuning/README.md) | A live handling editor, but this one pretends to be a tuning menu and has a PI system. |
| `vehiclemanager` | `F6` (`+vehiclemanager_menu`) | [ScaleformUI](https://github.com/manups4e/ScaleformUI/releases) | [README](vehiclemanager/README.md) | QoL menu to save and load your cars. Its wired to the Performance Tuning menu too, so you don't need one hotkey for each thing. |
| `customphysics` | See readme for behavior triggers. | None | [README](customphysics/README.md) | Proper wheelies, proper powerslides, true speeding offroad, hollywood rollovers if you screw up.  A physics pack. |
| `customcam` | Camera toggle control (`INPUT_NEXT_CAMERA`) | None | [README](customcam/README.md) | WAY more freeform chase camera. Really lets you see the physics. |
| `traffic_control` | Server only. `setr tControlDefault X.X` | None | [README](traffic_control/README.md) | Enforces levels of traffic, can be asked by other scripts to lower it, Racing System uses it. |

Shiz's complicated, ensure you check out their readmes to know what the thing actually does, and convars.


### Interfunctionality

| Resource | Benefits from |  Behavior |
| --- | --- | --- |
| `racingsystem` | `performancetunint` | PI maximum option repects PT instead of vanilla stats. |
| `performancetuning`| `vehiclemanager`,`customphysics` | Can be opened through `vehiclemanager` instead and will unbind its hotkey if found.|
| `vehiclemanager` |`performancetuning`| Saved cars with it retain `performancetuning` tweaks. |
| `customcam` | |None yet. |
| `customphysics`  | `performancetuning`| None yet. |

###  Installation
From releases, drop the [ars-fivem] folder in `server-data\resources`. 

### Load Order

```cfg
ensure ScaleformUI_Assets
ensure ScaleformUI_Lua

ensure racingsystem --requires Scaleform
ensure performancetuning --requires Scaleform
ensure vehiclemanager --requires Scaleform
ensure customcam
ensure customphysics
```


### Extras
[Proper Handling](https://github.com/Eddlm/TheNewHandlingProject) goes well with this pack and may be folded into it.

## Contributing and Feedback

| Github | Discord | FiveM Server |
| --- | --- | --- |
| I prefer the [issues](https://github.com/Eddlm/ars-fivem/issues) system over pull requests. | I am available on [The Nation]() and [Vanillaworks]()#handling-help | Join the  [Dev server](https://servers.fivem.net/servers/detail/2ryx47), tour the features, complain. |

 
# Credits / Attributions / References

| Author | Content | Link |
| --- | --- | --- |
| MAFINS & itsjustcurtis | The entire vehicle save/load system I ripped off the Menyoo Repo. | [Menyoo Repo](https://github.com/itsjustcurtis/MenyooSP) |
| Jaymo1011 | I learned GTAO's jobs are a JSON on their site thanks to his repo. Wrote my own loader though. | [mission-json-loader Repo](https://github.com/jaymo1011/mission-json-loader) |
| ![medal](media/obamamedal_100h.jpg) | A big chunk here is a rewrite of my own older content from SP. | [My SP content](https://www.gta5-mods.com/users/eddlm) |
