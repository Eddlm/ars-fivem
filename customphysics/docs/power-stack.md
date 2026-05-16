# Anti-Boost & Overspeed Limiter

These two subsystems in `power.lua` form the **power stack** alongside the offroad boost and slide multiplier. They prevent cheating and enforce vehicle top speeds.

## Anti-Boost

### Purpose

Anti-boost detects when a vehicle's forward acceleration exceeds what the drivetrain should produce. This happens with cheat mods, speed hacks, or abnormal physics exploits. When detected, engine power is capped.

### How It Works

1. **Sampling at 50 ms intervals** — forward acceleration and driven wheel power are measured.
2. **Disparity** = measured acceleration (in Gs) − driven wheel power (in Gs).
3. When disparity exceeds `0.33` Gs:
   - A power ceiling is computed: `(1 + 0.33) − (disparityGs × 9.81 × 2)`, clamped to `ceilingMin` (−0.1).
   - If the vehicle has driven wheels on a drag surface, the ceiling is raised to `dragSurfaceCeilingMin` (0.8) to avoid punishing legitimate offroad acceleration.
4. The ceiling recovers toward 1.0 at 3×/s.

### Gear Change Guard

When the vehicle shifts gear, anti-boost is paused for 500 ms (`gearGuardMs`) to avoid penalising the torque spike from clutch re-engagement.

### Slide Angle Guard

Anti-boost is suppressed when the vehicle's slide angle exceeds `slideAngleGuardDegrees` (10°). During a powerslide, high disparity is expected and shouldn't be penalised.

### Internal Constants

| Constant                 | Default    | Description                                       |
| ------------------------ | ---------- | ------------------------------------------------- |
| `disparityThreshold`     | `0.33` Gs  | Minimum disparity to trigger.                     |
| `slideAngleGuardDegrees` | `10.0`     | Slide angle above which anti-boost is suppressed. |
| `gearGuardMs`            | `500`      | Pause after gear change.                          |
| `gsCalibration`          | `9.81 × 2` | Multiplier in ceiling formula.                    |
| `ceilingMin`             | `-0.1`     | Minimum power ceiling.                            |
| `dragSurfaceCeilingMin`  | `0.8`      | Minimum ceiling when on a drag surface.           |

## Overspeed Limiter

### Purpose

Vehicles with modified handling or extremely high power can exceed their intended top speed. The overspeed limiter gradually reduces engine power above the vehicle's handling top speed.

### How It Works

1. The vehicle's **handling top speed** is read from `fInitialDriveMaxFlatVel`, with a fallback to the stored original value from performancetuning state bags.
2. An **activation buffer** of `activationSpeedBufferMph` (default 10 mph) is added. Overspeed triggers when `currentSpeed ≥ topSpeed + buffer` **and** RPM ≥ 1.0.
3. When active, the multiplier drifts down from 1.0 toward `minimumPowerMultiplier` (0.5) at `fallRatePerSecond` (0.2/s).
4. When inactive, it recovers at `recoveryRatePerSecond` (0.1/s).
5. The overspeed multiplier is multiplied into the total `SetVehicleCheatPowerIncrease`.

### Smoke Effect

When the overspeed multiplier drops below 1.0, an engine smoke particle effect (`veh_plane_damage` from the `core` asset) is attached to an engine bone on the vehicle. When the multiplier recovers, the effect is removed.

### Internal Constants

| Constant                   | Default | Description                                  |
| -------------------------- | ------- | -------------------------------------------- |
| `minimumPowerMultiplier`   | `0.5`   | Floor for overspeed power reduction.         |
| `fallRatePerSecond`        | `0.2`   | How fast the multiplier drops per second.    |
| `recoveryRatePerSecond`    | `0.1`   | How fast the multiplier recovers per second. |
| `activationSpeedBufferMph` | `10.0`  | Buffer above top speed before deactivation.  |

## Power Stack Integration

The final value passed to `SetVehicleCheatPowerIncrease` each frame is:

```
cheatPower = slideMultiplier × offroadMultiplier × overspeedMultiplier × antiBoostMultiplier
```

Where:

- `slideMultiplier` — boost from powerslide angle (1.0–5.0).
- `offroadMultiplier` — boost from offroad surface drag (1.0–5.0).
- `overspeedMultiplier` — limiter from overspeed (0.5–1.0).
- `antiBoostMultiplier` — limiter from cheat detection (−0.1–1.0).

## Debug

Set `cPhysicsPrintLevel` to `2` to see:

- The current `antiBoostMultiplier` overlaid on-screen.
- The rollover debug panel.
