# customcam

## Requirements
- No external dependency is required.
- This resource only needs to be started on the client side.

## Interactions
- `customcam` runs independently and does not require other modules.
- It does not expose or require cross-resource exports for normal use.

## How To Use
1. Start the resource in your server startup list.
2. Enter a vehicle and use the configured camera toggle control (default GTA camera control).
3. Hold the toggle for the configured hold time to switch camera behavior.

## Configuration Variables
| Path | Default | What it controls |
| --- | --- | --- |
| `toggleHoldMs` | `1000` | Hold time in ms before the camera mode toggles. |
| `showControlHints` | `true` | Shows helper hints for camera controls. |
| `Controls.toggleControlId` | `0` | Control ID used to toggle camera behavior. |
| `Controls.lookBackControlId` | `79` | Control ID used for look-behind behavior. |
| `VirtualMirror.enabled` | `true` | Enables the virtual rear mirror overlay. |
| `VirtualMirror.*` | see file | Position and size of the virtual mirror UI block. |
| `FollowCam.initialSpawnDistanceMeters` | `3.5` | Initial follow camera spawn distance. |
| `FollowCam.trailingDistanceByViewModeMeters` | `{0=0.25,1=1.25,2=2.25}` | Follow distance by view mode. |
| `FollowCam.heightOffsetByViewModeMeters` | `{0=0.5,1=1.3,2=2.1}` | Camera height offset by view mode. |
| `HoodCam.forwardOffsetMeters` | `-2` | Hood camera forward offset. |
| `HoodCam.upOffsetMeters` | `0.08` | Hood camera vertical offset. |
| `HoodCam.rotationXDegrees` | `-10.0` | Hood camera pitch angle. |
| `Advanced.*` | see file | Fine-grained camera/mirror math, smoothing, and scan tuning. |
| `UpdateCheck.*` | see file | GitHub update check behavior and timeout settings. |
