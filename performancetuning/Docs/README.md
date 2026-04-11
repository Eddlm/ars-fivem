# performancetuning

Live vehicle tuning, PI panels, nitrous, surface grip, and state synchronization for player vehicles.

## Requirements
- Requires `ScaleformUI_Assets`.
- Requires `ScaleformUI_Lua`.

## Module Layout
- `shared/Config.lua` defines the user-facing config surface.
- `client/definitions.lua` defines handling fields, pack metadata, and state bag keys.
- `client/configruntime.lua` normalizes config into runtime-ready values.
- `client/runtimebindings.lua` wires shared state and internals together.
- `client/client.lua` is the composition root, export surface, and stable-lap relay.
- `client/handlingmanager.lua` reads, writes, formats, and parses handling values.
- `client/vehiclemanager.lua` owns per-vehicle buckets, caching, and statebag sync.
- `client/tuningpackmanager.lua` applies packs and tune-state mutations.
- `client/menusliders.lua` builds and clamps ScaleformUI slider values.
- `client/scaleformui_menus.lua` builds and runs the full menu hierarchy.
- `client/performancepanel.lua` computes and draws the performance panels.
- `client/surfacegrip.lua` adjusts tire lateral grip from surface materials.
- `client/material_tyre_grip.lua` provides the material-to-grip lookup table.
- `client/nitrous.lua` handles nitrous shot execution, refill, and rev limiting.
- `client/syncorchestrator.lua` manages tracked-vehicle resync and repair loops.
- `server/server.lua` stores stable lap records and coordinates scope-based resync.
- `server/UpdateNotifier.lua` performs the startup/manual update check.

## Interactions
- `vehiclemanager` opens the menu, reads the current vehicle, and syncs tune state.
- `racingsystem` can relay `racingsystem:stableLapTime` into the stable-lap storage flow.
- `ScaleformUI_Lua` provides the menu framework used by the tuning UI.

## How To Use
1. Start `ScaleformUI_Assets` and `ScaleformUI_Lua`, then start `performancetuning`.
2. Open the tuning menu through the export surface or the bound menu command.
3. Adjust packs, sliders, rev limiter, or steering lock settings and test drive them live.
4. Use `/ptlaptimes` to inspect or clear the stored stable-lap PI records.
5. Use `/ptupdatecheck` if you want to run the update check manually.

## Configuration Variables
| Path | Default | What it controls |
| --- | --- | --- |
| `sliderRanges.nitrousShotStrength` | `min=1.0 max=2.0 step=0.2` | Range for the nitrous shot strength slider. |
| `sliderRanges.suspensionRaise` | `min=-0.300 max=0.300 step=0.010` | Range for the suspension raise slider. |
| `nitrous.baseDurationMs` | `4000` | Base nitrous duration before strength scaling. |
| `nitrous.nativePowerMultiplier` | `0.5` | Baseline nitrous power multiplier. |
| `performancePiDistribution.*` | see file | Weights used to convert measured stats into PI. |
| `performanceBarFillTargets.*` | see file | Reference values used to scale the performance bars. |
| `performanceModel.*` | see file | Upgrade model behavior for power, top speed, grip, and brake. |
| `performanceNearbyPanels.enabled` | `true` | Enables nearby vehicle PI panels. |
| `performanceNearbyPanels.maxDistanceMeters` | `30.0` | Max distance for nearby panel rendering. |
| `performanceNearbyPanels.maxPanels` | `6` | Maximum nearby panels drawn. |
| `packDefinitions.*` | see file | Available upgrade packs and their settings. |
| `engineSwaps.*` | see file | Engine swap presets and target models. |
| `advanced.panel.*` | see file | UI panel sizing, placement, and scaling constants. |
| `advanced.tuning.transmissionPowerBonusPerUpgrade` | `0.01` | Transmission power bonus scalar per upgrade step. |
| `updateCheck.*` | see file | GitHub update check behavior, repo/path, token, and timeout settings. |
