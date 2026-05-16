# Hood Camera

The hood camera is a first-person driving view that **hard-attaches** the scripted camera to a scan point on the vehicle body. It activates automatically when the player cycles to view mode 4 (the hood/first-person view mode).

## How It Works

### Activation

When `GetFollowVehicleCamViewMode()` returns view mode `4` (configurable via `followCamHoodViewModeId`), the follow cam logic stops and the hood cam takes over:

1. A downward raycast scan finds a valid attach point on the vehicle's front body.
2. The camera is hard-attached to that point via `HardAttachCamToEntity`.
3. All spring physics are suspended — the camera moves rigidly with the vehicle.

When the player cycles away from view mode 4, the hood cam **detaches** and the follow cam re-seeds from the vehicle's current state.

### Scan Algorithm

The hood cam needs to find a point on the vehicle's geometric surface to attach to. It does this with a series of downward raycasts:

| Parameter                   | Default | Description                                                       |
| --------------------------- | ------- | ----------------------------------------------------------------- |
| `hoodCamScanHeightMeters`   | `2.5 m` | How far above the vehicle the raycasts start.                     |
| `hoodCamScanStepMeters`     | `0.2 m` | Step size when scanning forward along the vehicle's local Y axis. |
| `hoodCamScanMaxAheadMeters` | `3.5 m` | Maximum distance ahead of the bounding box to scan.               |

The scan proceeds from the vehicle's centre toward its front:

1. Starting at Y=0 in vehicle-local space, step forward by `hoodCamScanStepMeters`.
2. At each step, cast a ray from `(0, localY, maxDim.z + hoodCamScanHeightMeters)` down to `(0, localY, minDim.z - 1.0)`.
3. If the ray hits the vehicle, record the local offset.
4. If the hit surface normal points mostly upward (dot product with Z > `hoodCamNormalDotThresholdRatio`, default 0.94), **stop** — this is a valid flat surface for the camera.
5. If the scan reaches `maxDim.y + hoodCamScanMaxAheadMeters` without finding a flat surface, use the best offset found so far.

This means the camera prefers a flat horizontal surface (like a bonnet/hood) but will fall back to whatever it finds.

### Attach Offsets

Once a scan point is found, the final camera position is offset from it:

| Parameter             | Default  | Description                                                                                              |
| --------------------- | -------- | -------------------------------------------------------------------------------------------------------- |
| `forwardOffsetMeters` | `-2 m`   | Shift along the vehicle's local Y axis. Negative moves the camera forward (toward the front of the car). |
| `upOffsetMeters`      | `0.08 m` | Lift above the scan surface. Small values keep the camera grounded.                                      |
| `rotationXDegrees`    | `-10°`   | Pitch applied to the camera. Slightly looks down.                                                        |

### Look Behind in Hood Mode

When the look-behind control is held:

- `rotationZDegrees` gets +180° added, spinning the camera to face rearward.
- The attach offset stays the same — you're looking backwards from the same hood point.
- On release, the camera snaps back to the forward orientation.

### Additional Rotation

| Parameter                 | Default | Description                                          |
| ------------------------- | ------- | ---------------------------------------------------- |
| `hoodCamRotationYDegrees` | `0°`    | Roll offset (tilt).                                  |
| `hoodCamRotationZDegrees` | `0°`    | Yaw offset, overridden by +180° when looking behind. |

### Light Anchor Fallback

The hood cam (and virtual mirror) use **headlight bone positions** to determine vehicle front/rear orientation when available. If the vehicle model lacks headlight/taillight bones, it falls back to `GetEntityForwardVector`, and ultimately to the vehicle's bounding box centre.

## Parameters

See [configuration.md](configuration.md) → _Hood Camera_ and _Advanced Tuning → Hood_ sections for every tuneable value.
