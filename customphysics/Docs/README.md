# customphysics

## Requirements
- No hard dependency is required.
- Optional integration: `performancetuning` state can be read for rev-limiter related behavior.

## Interactions
- Reads tuning-related state when `performancetuning` is present.
- Can run standalone if `performancetuning` is missing, using fallback config values.

## How To Use
1. Start the resource in your server startup list.
2. Drive normally; features apply automatically based on config (wheelies, slides, offroad multiplier, rollovers, nitrous behavior).

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
