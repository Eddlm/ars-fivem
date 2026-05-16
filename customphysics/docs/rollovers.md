# Rollover Recovery

When a vehicle is tumbling or flipped, the rollover system applies a corrective force to push it back onto its wheels. It only activates when specific speed and angular velocity thresholds are met, and gradually reduces force as the vehicle settles.

## How It Works

### Trigger Conditions

A rollover is detected when **all** of the following are true:

1. The vehicle is **not in the air** (`IsEntityInAir` = false).
2. The vehicle is **not on all wheels** (`IsVehicleOnAllWheels` = false).
3. **Either:**
   - The vehicle is "unstable" — not on all wheels, and the forward speed ratio is ≤ 0.5 (moving sideways/backwards relative to heading).
   - **Or** angular velocity on any axis exceeds `angularStartDegrees` (default 180 °/s).

### State Machine

| Transition            | Condition                                                            |
| --------------------- | -------------------------------------------------------------------- |
| **INACTIVE → ACTIVE** | Speed ≥ `startSpeed` **and** (unstable **or** high angular velocity) |
| **ACTIVE → INACTIVE** | Speed < `keepSpeed` **or** max angular velocity < `keepRot`          |

### Force Application

When active, a force is applied every frame in the direction of the vehicle's velocity:

- **On all wheels**: force at the vehicle centre (forward push).
- **Not on all wheels**: force applied with a height offset (`forceHeightOffset`, default 4.0 m) to create a torque that rights the vehicle.

#### Force Decay

- At the moment of activation, the force is multiplied by `initialForceMultiplier` (default 3.0×).
- Over `settleDurationMs` (default 500 ms), the multiplier decays linearly from 3.0× down to 1.0×.
- If the vehicle has hit a material surface (`lastHitMaterial > 0`) after settling, the force is doubled (2×) for extra ground-contact push.

### Check Interval

Rollover conditions are not evaluated every frame — they are cached and refreshed every `checkIntervalMs` (default 300 ms). This saves CPU while still being responsive enough for physics.

## Parameters

| Parameter                | Default | Unit          | Convar Override           |
| ------------------------ | ------- | ------------- | ------------------------- |
| `startSpeedMs`           | `8.94`  | m/s (≈20 mph) | `cp_rollover_start_speed` |
| `keepSpeedMs`            | `6.71`  | m/s (≈15 mph) | `cp_rollover_keep_speed`  |
| `angularStartDegrees`    | `180.0` | °/s           | `cp_rollover_start_rot`   |
| `angularKeepDegrees`     | `90.0`  | °/s           | `cp_rollover_keep_rot`    |
| `checkIntervalMs`        | `300`   | ms            | —                         |
| `forceHeightOffset`      | `4.0`   | m             | —                         |
| `forceMagnitude`         | `1.4`   | —             | —                         |
| `settleDurationMs`       | `500`   | ms            | —                         |
| `initialForceMultiplier` | `3.0`   | ×             | —                         |

## Debug Overlay

Set `cPhysicsPrintLevel` to `2` to see a live debug panel showing:

- Speed threshold status
- Unstable trigger status
- Angular velocity triggers
- Force elapsed time

## See Also

- [Configuration reference](configuration.md) for full parameter details.
