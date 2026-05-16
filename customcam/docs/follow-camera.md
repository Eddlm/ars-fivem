# Follow Camera

The follow camera is a spring-damped chase camera that trails the player's vehicle with smooth acceleration, deceleration, and rotation. It is the default mode when the custom camera is active (i.e. when the vehicle view mode is **not** set to hood/first-person).

## How It Works

### Activation

1. The player holds `INPUT_NEXT_CAMERA` (default: `V`) for the configured hold time (`Config.toggleHoldMs`, default 1000 ms).
2. The camera is created as a `DEFAULT_SCRIPTED_CAMERA` and starts at `initialSpawnDistanceMeters` behind the vehicle.
3. The game's scripted camera rendering takes over (`RenderScriptCams`), and the default GTA chase camera is suppressed.

### Spring Physics Model

The follow cam uses a **spring-damper system** rather than hard-snapping to a target:

- **Desired position** is computed each frame based on the vehicle's position, heading, velocity, and the current view mode's trailing distance + height offset.
- **Velocity** is updated using an acceleration factor (`followCamAccelerationFactor`) and a damping factor (`followCamDampingFactor`):
  ```
  acceleration = (desiredVelocity - currentVelocity) × accelerationFactor − currentVelocity × dampingFactor
  velocity += acceleration × dt
  position += velocity × dt
  ```
- **Catchup** — when the camera falls behind, `followCamCatchupFactor` applies a gain based on distance error so the camera recovers more aggressively.

### Rotation Smoothing

Camera rotation uses a separate per-axis spring system:

| Parameter                                              | Default  | Purpose                            |
| ------------------------------------------------------ | -------- | ---------------------------------- |
| `followCamRotationAccelerationDegreesPerSecondSquared` | `1800.0` | Max angular acceleration           |
| `followCamRotationDampingFactor`                       | `8.0`    | Rotational drag                    |
| `followCamRotationSmoothingFactor`                     | `30.0`   | Stiffness of the rotational spring |

Higher smoothing → snappier rotation. Higher damping → slower, lazier rotation.

### View Modes

The follow cam reads GTA's built-in `GetFollowVehicleCamViewMode()` and adjusts distance and height accordingly:

| View Mode | Trailing Distance        | Height Offset                        |
| --------- | ------------------------ | ------------------------------------ |
| 0 (close) | `0.25 m` above baseline  | `0.5 m` above roof                   |
| 1 (mid)   | `1.25 m` above baseline  | `1.3 m` above roof                   |
| 2 (far)   | `2.25 m` above baseline  | `2.1 m` above roof                   |
| 4 (hood)  | Switches to **hood cam** | See [hood-camera.md](hood-camera.md) |

Baseline distance = `vehicleHalfLength + trailingDistanceByViewModeMeters[mode]`.

### Look-Ahead

When enabled, the camera's focus point shifts forward in the vehicle's travel direction by an amount proportional to forward speed and `followCamVelocityLookAheadFactor`. This causes the camera to look into turns rather than lagging behind.

Look-ahead is **disabled automatically** when:

- The vehicle flips (upright value ≤ `followCamUprightThresholdRatio`, default 0.2).
- Angular velocity on the X axis exceeds `followCamFlipAngularVelocityXRadiansPerSecond` (default 1.5 rad/s).

It **re-enables** when the vehicle is back on all wheels and upright value ≥ `followCamUprightRecoveryThresholdRatio` (default 0.9).

### Minimum Bubble (Anti-Collision)

To prevent the camera from clipping inside the vehicle:

- `followCamMinimumBubblePaddingMeters` (default 1.0 m) is added to the vehicle's half-length to form a **minimum bubble radius**.
- If the camera is inside this bubble, it accelerates outward at `followCamMinimumBubbleEscapeSpeedMetersPerSecond` (default 6.0 m/s) regardless of other physics.

### Look Behind

Pressing `INPUT_VEH_LOOK_BEHIND` (default: `C`) while the follow cam is active mirrors the camera position behind the vehicle and rotates it 180°, giving a rear-facing view without changing the underlying spring state.

### Camera Cleanup

The camera is destroyed and all state is reset when:

- The player releases the camera toggle (hold again to disable).
- The player exits the vehicle.
- The resource stops (`onResourceStop`).

## Parameters

See [configuration.md](configuration.md) → _Follow Camera_ and _Advanced Tuning → Follow_ sections for every tuneable value with defaults and units.
