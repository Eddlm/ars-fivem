# Configuration Reference

All tuneable values live in `Config.lua`. This document lists every field, its default, unit, and effect.

## Convars

These are set in `server.cfg` and read at runtime.

| Convar                    | Type | Default | Description                                                                                                        |
| ------------------------- | ---- | ------- | ------------------------------------------------------------------------------------------------------------------ |
| `ars_skip_uptodate_print` | bool | `false` | Suppresses the "Up to date" console message from the update notifier. Set via `setr ars_skip_uptodate_print true`. |

> **Planned convar candidates** — the following `Config.lua` fields are noted as future convar candidates in the source comments. They are currently only editable in `Config.lua` directly.

| Planned convar name           | Maps to                                       | Description                                |
| ----------------------------- | --------------------------------------------- | ------------------------------------------ |
| `cc_toggle_hold_ms`           | `Config.toggleHoldMs`                         | Hold duration to toggle the camera         |
| `cc_show_control_hints`       | `Config.showControlHints`                     | Whether on-screen control hints appear     |
| `cc_virtual_mirror_enabled`   | `Config.VirtualMirror.enabled`                | Master toggle for the virtual mirror       |
| `cc_virtual_mirror_width`     | `Config.VirtualMirror.widthNormalized`        | Mirror overlay width                       |
| `cc_virtual_mirror_height`    | `Config.VirtualMirror.heightNormalized`       | Mirror overlay height                      |
| `cc_followcam_spawn_distance` | `Config.FollowCam.initialSpawnDistanceMeters` | Initial distance when follow cam activates |

---

## Toggle & Controls

| Field                        | Type   | Default | Unit     | Description                                                                                                        |
| ---------------------------- | ------ | ------- | -------- | ------------------------------------------------------------------------------------------------------------------ |
| `toggleHoldMs`               | number | `1000`  | ms       | How long the player must hold the toggle control before the custom camera switches on or off. Clamped 250–5000 ms. |
| `showControlHints`           | bool   | `true`  | —        | Show on-screen help text about toggling the camera when the player is driving.                                     |
| `Controls.toggleControlId`   | number | `0`     | input id | The control input used to toggle the camera. `0` = `INPUT_NEXT_CAMERA`.                                            |
| `Controls.lookBackControlId` | number | `79`    | input id | The control input used for look-behind. `79` = `INPUT_VEH_LOOK_BEHIND`.                                            |

---

## Virtual Mirror

All values under `Config.VirtualMirror`.

| Field               | Type   | Default | Unit  | Description                                                      |
| ------------------- | ------ | ------- | ----- | ---------------------------------------------------------------- |
| `enabled`           | bool   | `true`  | —     | Master switch for the mirror overlay.                            |
| `centerXNormalized` | number | `0.5`   | ratio | Horizontal centre of the mirror on screen (0 = left, 1 = right). |
| `centerYNormalized` | number | `0.08`  | ratio | Vertical centre of the mirror on screen (0 = top, 1 = bottom).   |
| `widthNormalized`   | number | `0.315` | ratio | Total width including the frame.                                 |
| `heightNormalized`  | number | `0.08`  | ratio | Total height including the frame.                                |

See [virtual-mirror.md](virtual-mirror.md) for the full list of advanced mirror tuning values.

---

## Follow Camera

All values under `Config.FollowCam`.

| Field                              | Type   | Default                            | Unit | Description                                                                      |
| ---------------------------------- | ------ | ---------------------------------- | ---- | -------------------------------------------------------------------------------- |
| `initialSpawnDistanceMeters`       | number | `3.5`                              | m    | Distance at which the follow cam starts behind the vehicle when first activated. |
| `trailingDistanceByViewModeMeters` | table  | `{ [0]=0.25, [1]=1.25, [2]=2.25 }` | m    | Extra trailing distance per GTA view mode. Mode 0 = close, 1 = mid, 2 = far.     |
| `heightOffsetByViewModeMeters`     | table  | `{ [0]=0.5, [1]=1.3, [2]=2.1 }`    | m    | Height above the vehicle roof per view mode.                                     |

See [follow-camera.md](follow-camera.md) for the full list of advanced follow cam physics values.

---

## Hood Camera

All values under `Config.HoodCam`.

| Field                 | Type   | Default | Unit | Description                                                                          |
| --------------------- | ------ | ------- | ---- | ------------------------------------------------------------------------------------ |
| `forwardOffsetMeters` | number | `-2`    | m    | Forward offset from the hood attach point (negative = further ahead of the vehicle). |
| `upOffsetMeters`      | number | `0.08`  | m    | Vertical offset above the hood attach surface.                                       |
| `rotationXDegrees`    | number | `-10.0` | °    | Pitch offset applied to the hood cam. Negative tilts down.                           |

See [hood-camera.md](hood-camera.md) for the scan parameters.

---

## Advanced Tuning

All values under `Config.Advanced`. These are internal physics/rendering knobs that rarely need changing.

| Field                                                  | Type   | Default                       | Unit    | Group    |
| ------------------------------------------------------ | ------ | ----------------------------- | ------- | -------- |
| `defaultGameplayCamFov`                                | number | `60.0`                        | °       | Camera   |
| `controlHintInitialDelayMs`                            | number | `30000`                       | ms      | Controls |
| `virtualMirrorHorizontalFovDegrees`                    | number | `90.0`                        | °       | Mirror   |
| `virtualMirrorVerticalFovDegrees`                      | number | `15.0`                        | °       | Mirror   |
| `virtualMirrorTrackingHorizontalPaddingDegrees`        | number | `90.0`                        | °       | Mirror   |
| `virtualMirrorVehiclePollRadiusMeters`                 | number | `200.0`                       | m       | Mirror   |
| `virtualMirrorMaxTrackedVehicles`                      | number | `24`                          | count   | Mirror   |
| `virtualMirrorFrameThicknessNormalized`                | number | `0.006`                       | ratio   | Mirror   |
| `virtualMirrorFrameColor`                              | table  | `{r=20,g=20,b=20,a=230}`      | RGBA    | Mirror   |
| `virtualMirrorFillColor`                               | table  | `{r=65,g=75,b=90,a=120}`      | RGBA    | Mirror   |
| `virtualMirrorDotSizeNormalized`                       | number | `0.007`                       | ratio   | Mirror   |
| `virtualMirrorDotSizeNearMultiplier`                   | number | `7.5`                         | ×       | Mirror   |
| `virtualMirrorDotScaleExponent`                        | number | `4.0`                         | power   | Mirror   |
| `virtualMirrorDotSeparationFalloffExponent`            | number | `22.0`                        | power   | Mirror   |
| `virtualMirrorDotWidthScale`                           | number | `0.65`                        | ratio   | Mirror   |
| `virtualMirrorDotClipPaddingPixels`                    | number | `4.0`                         | px      | Mirror   |
| `virtualMirrorDotTextureDict`                          | string | `mpinventory`                 | —       | Mirror   |
| `virtualMirrorDotTextureName`                          | string | `in_world_circle`             | —       | Mirror   |
| `virtualMirrorDotColor`                                | table  | `{r=255,g=220,b=80,a=235}`    | RGBA    | Mirror   |
| `virtualMirrorDotRearColor`                            | table  | `{r=255,g=70,b=60,a=235}`     | RGBA    | Mirror   |
| `followCamMinimumBubblePaddingMeters`                  | number | `1.0`                         | m       | Follow   |
| `followCamMinimumBubbleEscapeSpeedMetersPerSecond`     | number | `6.0`                         | m/s     | Follow   |
| `followCamSpeedMatchDistanceMeters`                    | number | `4.0`                         | m       | Follow   |
| `followCamAccelerationFactor`                          | number | `10.0`                        | —       | Follow   |
| `followCamDampingFactor`                               | number | `2.0`                         | —       | Follow   |
| `followCamCatchupFactor`                               | number | `10.0`                        | —       | Follow   |
| `followCamRotationAccelerationDegreesPerSecondSquared` | number | `1800.0`                      | °/s²    | Follow   |
| `followCamRotationDampingFactor`                       | number | `8.0`                         | —       | Follow   |
| `followCamRotationSmoothingFactor`                     | number | `30.0`                        | —       | Follow   |
| `followCamViewModePaddingMeters`                       | table  | `{[0]=0.25,[1]=0.5,[2]=0.75}` | m       | Follow   |
| `followCamFallbackDistancePaddingMeters`               | number | `0.1`                         | m       | Follow   |
| `followCamVelocityLookAheadFactor`                     | number | `0.5`                         | —       | Follow   |
| `followCamHoodViewModeId`                              | number | `4`                           | view id | Follow   |
| `followCamFlipAngularVelocityXRadiansPerSecond`        | number | `1.5`                         | rad/s   | Follow   |
| `followCamUprightThresholdRatio`                       | number | `0.2`                         | ratio   | Follow   |
| `followCamUprightRecoveryThresholdRatio`               | number | `0.9`                         | ratio   | Follow   |
| `followCamFocusHeightMeters`                           | number | `0.85`                        | m       | Follow   |
| `hoodCamScanHeightMeters`                              | number | `2.5`                         | m       | Hood     |
| `hoodCamScanStepMeters`                                | number | `0.2`                         | m       | Hood     |
| `hoodCamScanMaxAheadMeters`                            | number | `3.5`                         | m       | Hood     |
| `hoodCamRotationYDegrees`                              | number | `0.0`                         | °       | Hood     |
| `hoodCamNormalDotThresholdRatio`                       | number | `0.94`                        | ratio   | Hood     |

See the feature-specific docs for explanations of each group.
