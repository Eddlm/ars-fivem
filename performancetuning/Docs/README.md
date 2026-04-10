# performancetuning

## Requirements
- Requires `ScaleformUI_Assets`.
- Requires `ScaleformUI_Lua`.

## Interactions
- `vehiclemanager` can open this module's menu and reads/writes related tuning state.
- `customphysics` may read tuning-related state for runtime behavior alignment.

## How To Use
1. Start dependencies first, then start `performancetuning`.
2. Open the tuning menu via an integrated caller (for example, `vehiclemanager`) or by calling the exported open function from another resource.
3. Adjust pack selections/sliders and test drive changes live.

## Configuration Variables
| Path | Default | What it controls |
| --- | --- | --- |
| `sliderRanges.nitrousShotStrength` | `min=1.0 max=2.0 step=0.2` | Range for nitrous shot strength slider. |
| `sliderRanges.suspensionRaise` | `min=-0.300 max=0.300 step=0.010` | Range for suspension raise slider. |
| `nitrous.baseDurationMs` | `4000` | Base nitrous duration. |
| `nitrous.nativePowerMultiplier` | `0.5` | Native nitrous power multiplier baseline. |
| `performancePiDistribution.*` | see file | Weights used to convert measured stats into PI. |
| `performanceBarFillTargets.*` | see file | Max reference values used for performance bars. |
| `performanceModel.*` | see file | Upgrade model behavior for power/top speed/grip/brake. |
| `performanceNearbyPanels.enabled` | `true` | Enables nearby vehicle PI panels. |
| `performanceNearbyPanels.maxDistanceMeters` | `30.0` | Max distance for nearby panel rendering. |
| `performanceNearbyPanels.maxPanels` | `6` | Maximum nearby panels drawn. |
| `packDefinitions.*` | see file | Available upgrade packs and per-pack settings. |
| `engineSwaps.*` | see file | Engine swap presets and target models. |
| `advanced.panel.*` | see file | UI panel sizing/placement/scaling constants. |
| `advanced.tuning.transmissionPowerBonusPerUpgrade` | `0.01` | Transmission power bonus scalar per upgrade step. |
| `updateCheck.*` | see file | GitHub update check behavior and timeout settings. |

