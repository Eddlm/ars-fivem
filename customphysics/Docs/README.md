# customphysics

## Overview
- Client-side vehicle physics helpers for power, wheelies, rollovers, and nitrous behavior.
- The resource now keeps the helper surface intentionally small: behavior lives in the subsystem modules, while shared math, wheel snapshots, and subtitle output stay in `util.lua`.
- Stability sampling runs at 100ms intervals, which is 10 Hz, but only records powered-wheel samples when the driven wheels are actually producing power.
- The sampler keeps a rolling 500ms history in Gs, stores measured-acceleration and wheel-baseline entries, then compares the peak measured acceleration against the rolling baseline average.

## Requirements
- No hard dependency is required.
- Optional integration: `performancetuning` state can be read for rev-limiter related behavior.

## Interactions
- Reads tuning-related state when `performancetuning` is present.
- Can run standalone if `performancetuning` is missing, using fallback config values.
- Uses `CustomPhysicsUtil.showSubtitle()` for short debug/status messages when the power system wants to print the current multiplier and G-based stability values.

## How To Use
1. Start the resource in your server startup list.
2. Drive normally; features apply automatically based on config (wheelies, slides, offroad multiplier, rollovers, nitrous behavior).

## Helper Surface
| Module | Current surface |
| --- | --- |
| `util.lua` | `clamp`, `mapValue`, `getDeltaSeconds`, `showSubtitle`, `getPlanarAngleDegrees`, `getVehiclePlanarSpeed`, `buildWheelPowerSnapshot` |
| `power.lua` | `sampleStability`, `updateStabilityRecovery`, `update`, `getDebugSnapshot`, `reset` |
| `wheelies.lua` | wheelie lifecycle and update helpers |
| `rollovers.lua` | rollover lifecycle and update helpers |
| `nitrous.lua` | compatibility no-op exports plus nitrous event hooks |

## Runtime Cadence
- Stability sampling: every 100ms, or 10 Hz, when driven wheels are powered.
- Stability window: trailing 500ms of powered samples, stored and compared in Gs.
- Stability recovery: separate frame-derived wait based on `GetFrameTime()`.
- Main vehicle coordinator: per-frame (`Wait(0)`).

## Configuration Variables
| Path | Default | What it controls |
| --- | --- | --- |
| `nativeWheeliesDisabled` | `true` | Disables native wheelies to prefer custom wheelie logic. |
| `customWheelieEnabled` | `true` | Enables custom wheelie behavior. |
| `wheeliesMuscleOnly` | `true` | Restricts wheelies to muscle-class behavior rules. |
| `rolloversEnabled` | `true` | Enables rollover recovery/assist logic. |
| `offroadBoostEnabled` | `true` | Enables offroad speed multiplier behavior. |
| `offroadMaxMultiplier` | `5.0` | Maximum multiplier applied in offroad boost logic. |
| `fallbackRevLimiterEnabled` | `false` | Rev limiter fallback when tuning state is unavailable. |
| `slideAngleStepDegrees` | `20.0` | Step size used by powerslide multiplier curve. |
| `slideMaxMultiplier` | `5.0` | Maximum slide multiplier. |
| `slideSpeedThresholdMetersPerSecond` | `3.0` | Minimum speed before slide logic applies. |
| `nitrous.controlId` | `73` | Nitrous activation control ID. |
| `nitrous.defaultOverrideLevel` | `1.0` | Default nitrous strength override level. |
| `nitrous.defaultHudFill` | `100.0` | Default HUD nitrous fill amount. |
| `nitrous.debugStatusIntervalMs` | `1000` | Debug status cadence for nitrous diagnostics. |
| `materialTyreDragByIndex` | see file | Material-index drag modifiers used for grip/drag model. |
| `advanced.rollovers.*` | see file | Rollover threshold/force/check timing tuning. |
| `advanced.wheelies.*` | see file | Wheelie arming and force distribution tuning. |
| `updateCheck.*` | see file | GitHub update check behavior and timeout settings. |
