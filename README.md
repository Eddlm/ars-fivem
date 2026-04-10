

<p style="text-align:center;">[![Showcase Video](https://img.youtube.com/vi/wnlUr-YwVt0/0.jpg)](https://www.youtube.com/watch?v=wnlUr-YwVt0)</p>

# TL;DR
Its a system focused on better driving and racing, that's it. It has modules focusing on each aspect:

| Module | Hotkey / Command | Docs | What it does |
| --- | --- | --- | --- |
| `customcam` | Camera toggle control (`INPUT_NEXT_CAMERA`) | [README](customcam/Docs/README.md) | Unhooks the driving camera from the car and makes it follow freeform. This gives you a LOT more feedback on the physics of your car and what the hell it is doing. |
| `customphysics` | See readme for behavior triggers. | [README](customphysics/Docs/README.md) | Proper wheelies, proper powerslides, true speeding offroad, hollywood rollovers if you screw up.  A physics pack. |
| `performancetuning` | `F5` (`+ptmenu`), not bound if you got vehmanager. | [README](performancetuning/Docs/README.md) | Live-edits the car's handling allowing you to change top speed, grip bias, antirolls, shift speed, wheel compounds (road, offroad) etc. This one pretends to be a TUNING menu, not a handling editor like others do. |
| `racingsystem` | `F7` (`+racemenu`) | [README](racingsystem/Docs/README.md) | Implements checkpoint races and a race editor to plop your checkpoints. Also loads GTAO Races. |
| `traffic_control` | Server only. `setr tControlDefault X.X` | [README](traffic_control/Docs/README.md) | Enforces levels of traffic, can be asked by other scripts to lower it, Racing System uses it. |
| `vehiclemanager` | `F5` (`+vehiclemanager_menu`) | [README](vehiclemanager/Docs/README.md) | QoL menu to save and load your cars. Its wired to the Performance Tuning menu too, so you don't need one hotkey for each thing. |



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


# Updating and Configs
I'm still trying to figure out how to let you guys update without overriding your personal config files with the release files.

# Credits / Attributions / References

| Author | Content | Link |
| --- | --- | --- |
| MAFINS & itsjustcurtis | The entire vehicle save/load system I ripped off the Menyoo Repo. | [Menyoo Repo](https://github.com/itsjustcurtis/MenyooSP) |
| Jaymo1011 | I learned GTAO's jobs are a JSON on their site thanks to his repo. Wrote my own loader though. | [mission-json-loader Repo](https://github.com/jaymo1011/mission-json-loader) |
| ![medal](media/obamamedal_100h.jpg) | A big chunk here is a rewrite of my own older content from SP. | [My SP content](https://www.gta5-mods.com/users/eddlm) |
