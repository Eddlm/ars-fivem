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

