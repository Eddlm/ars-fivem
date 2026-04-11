# customcam

## Overview
- `customcam` adds a hold-to-toggle custom camera for vehicles, with follow-cam and hood-cam behavior, look-behind support, a virtual rear mirror overlay, and an update checker.
- The resource is self-contained and does not require any external dependency.

## Requirements
- No external dependency is required.
- The resource includes both client and server scripts, but the gameplay camera behavior itself runs on the client.

## Interactions
- `customcam` runs independently and does not require other modules.
- It does not expose or require cross-resource exports for normal use.
- `UpdateNotifier.lua` is a server-side helper that performs the version check and exposes `/ccamupdatecheck`.

## How To Use
1. Start the resource in your server startup list.
2. Enter a vehicle and hold the configured camera toggle control to switch the custom camera on or off.
3. Use the look-behind control while driving if you want the camera to mirror the vehicle direction.
4. If needed, run `/ccamupdatecheck` to manually check whether a newer version is available.

## Runtime Flow
- `Config.lua` defines `CustomCam.Config` and is shared by the runtime scripts.
- `client/client.lua` owns camera activation, follow-cam updates, hood-cam attachment, mirror overlay drawing, and resource-stop cleanup.
- `UpdateNotifier.lua` reads the update-check config, performs a delayed GitHub version check on resource start, and responds to the manual command.

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
