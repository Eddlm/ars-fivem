# Offroad Power Boost

When driving on surfaces that GTA penalises (dirt, sand, grass, mud), the offroad boost system compensates by increasing engine power via `SetVehicleCheatPowerIncrease`. This prevents vehicles from feeling sluggish on loose terrain and ensures acceleration stays responsive.

## How It Works

### Material Detection

Each frame (at the configurable update interval), the system reads `GetVehicleWheelSurfaceMaterial` for every wheel. It looks up each material ID in `Config.materialTyreDragByIndex`. If **all wheels** are on surfaces with a positive drag value (i.e. offroad), the boost activates.

### Acceleration-to-Power Ratio

The boost multiplier is calculated from the ratio between **measured forward acceleration** and **driven wheel power**:

```
accelerationToPowerFactor = max(0, planarAcceleration) / drivenWheelPower
```

- If the factor is **above** `targetAccelerationToPowerFactor` (default 0.5), the vehicle is accelerating well enough — no boost needed → multiplier = 1.0.
- If the factor is **below** the target, the vehicle is under-accelerating on a drag surface → the multiplier rises proportionally.

The target multiplier is:

```
rawTarget = targetAccelerationToPowerFactor / max(accelerationFactor, minimumAccelerationToPowerFactor)
```

Clamped between `1.0` and `cp_offroad_max_multiplier` (default 5.0).

### Ramp and Fall Rates

The live multiplier doesn't jump instantly — it ramps up and falls down at configured rates:

| Parameter           | Default | Description                                                  |
| ------------------- | ------- | ------------------------------------------------------------ |
| `rampStepPerSecond` | `2.0`   | How fast the multiplier increases per second.                |
| `fallStepPerSecond` | `100.0` | How fast the multiplier decreases per second (near-instant). |

### Shift Blocking

When the vehicle changes gear, the system pauses boost calculation for `shiftBlockDurationMs` (350 ms). This prevents gear-shift torque interruptions from being misread as surface drag.

### Integration with the Power Stack

The offroad multiplier is multiplied into the overall `SetVehicleCheatPowerIncrease` value:

```
cheatPower = slideMultiplier × offroadMultiplier × overspeedMultiplier × antiBoostMultiplier
```

## Convars

| Convar                      | Default | Description                                          |
| --------------------------- | ------- | ---------------------------------------------------- |
| `cp_offroad_boost_enabled`  | `true`  | Master toggle. Disabling sets the multiplier to 1.0. |
| `cp_offroad_max_multiplier` | `5.0`   | Maximum offroad power multiplier. Minimum 1.0.       |

## See Also

- [Configuration reference](configuration.md) for `materialTyreDragByIndex` and internal parameters.
