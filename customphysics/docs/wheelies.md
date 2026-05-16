# Wheelie Control

The wheelie system allows rear-wheel-drive and muscle vehicles to perform controlled wheelies from a standstill using a handbrake-launch mechanic. It also suppresses GTA's native wheelie state during launch to prevent conflicts.

## How It Works

### Launch Sequence

Wheelies use a three-stage state machine:

| Stage        | Condition                                                                                                                                                        |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Off**      | Default. No wheelie active.                                                                                                                                      |
| **Prepared** | Player was accelerating + holding brake → releases brake while still accelerating and handbrake is held, with RPM above threshold and speed below arm threshold. |
| **Active**   | Handbrake released while RPM > 0.9 and speed ≤ 1.0 m/s. Force is applied.                                                                                        |

The arming sequence:

1. Player holds **accelerate + brake** (revving in place).
2. Player releases brake and holds **handbrake** instead → enters **Prepared**.
3. Player **releases handbrake** while still accelerating, RPM > 0.9, speed ≤ 1.0 m/s → enters **Active**.

### Native Suppression

When `cp_wheelies_native_disabled` is true, the system forces GTA's `SetVehicleWheelieState` to `1` (disabled) during the launch phase. This prevents GTA's built-in wheelie behaviour from fighting the custom system.

Suppression is activated when:

- Handbrake held **and** RPM > 0.9 **and** accelerating.
  Suppression is released when:
- Vehicle speed exceeds 0.5 m/s.

### Force Model

Active wheelies apply force via two `ApplyForceToEntity` calls per frame:

1. A **rearward downward force** at `frontOffset = 2.0 × vehicleLength` ahead of centre — this lifts the front.
2. A **forward upward force** at the same offset — this drives the vehicle forward while nose-up.

The force magnitude is controlled by a **proportional controller**:

- Target pitch = `wheelPowerNorm × targetPitchFactor` (default 40°).
- Error = target pitch − current pitch.
- Controller output = `error × proportionalGain − pitchRate`.
- The force ramps up/down at `forceRampRate` (1.0 /s).

### Drive Bias

Rear-wheel-drive bias is factored in:

- `fDriveBiasFront` is mapped from the range `[0.2, 0.0]` → `[0.0, 1.0]` as a rear-bias multiplier.
- Full AWD (0.5+) gets near-zero wheelie force. Full RWD (0.0) gets full force.

### Muscle-Only Gate

When `cp_wheelies_muscle_only` is true (default), only vehicle class 4 (muscle cars) can wheelie. Other classes skip the entire update.

### Slope Awareness

The pitch controller measures **slope-relative pitch** — it raycasts the ground ahead and behind the vehicle, then subtracts the ground slope angle from the vehicle's world pitch. This means wheelies behave correctly on hills.

## Parameters

| Parameter                          | Default | Unit | Description                                       |
| ---------------------------------- | ------- | ---- | ------------------------------------------------- |
| `armSpeedThresholdMetersPerSecond` | `1.0`   | m/s  | Max speed to arm/launch a wheelie.                |
| `forceMultiplier`                  | `0.4`   | —    | Base force multiplier applied per frame.          |
| `frontOffsetLengthMultiplier`      | `2.0`   | ×    | Multiplied by vehicle length to get force offset. |

### Internal Constants (not in Config)

| Constant                            | Default       | Description                                            |
| ----------------------------------- | ------------- | ------------------------------------------------------ |
| `suppressionRpmThreshold`           | `0.9`         | RPM above which native suppression activates.          |
| `suppressionSpeedThreshold`         | `0.5` m/s     | Speed above which native suppression deactivates.      |
| `rpmLaunchThreshold`                | `0.9`         | RPM above which the handbrake release triggers Active. |
| `targetPitchFactor`                 | `40.0`        | Target pitch in degrees at full wheel power.           |
| `proportionalGain`                  | `0.5`         | Controller P-gain.                                     |
| `forceRampRate`                     | `1.0`         | Force ramp speed (per second).                         |
| `wheelPowerNormClamp`               | `0.9`         | Clamp for normalised driven wheel power.               |
| `driveBiasInMin` / `driveBiasInMax` | `0.2` / `0.0` | Input range for rear-bias mapping.                     |

## Convars

| Convar                        | Type | Default | Description                                  |
| ----------------------------- | ---- | ------- | -------------------------------------------- |
| `cp_wheelies_enabled`         | bool | `true`  | Master toggle for wheelies.                  |
| `cp_wheelies_muscle_only`     | bool | `true`  | Restrict to muscle car class.                |
| `cp_wheelies_native_disabled` | bool | `true`  | Suppress GTA's native wheelie during launch. |
