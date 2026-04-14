# Performance Tuning
Many of you know the live handling editors around.

Performance Tuning implements a vehicle upgrade system that consists of literal handling changes, injected onto the car. This allows much more variety of upgrades and way more granularity. 

# Tuning Categories
Performance Tuning is structured around the in-game menu and submenus:

| Main Menu Entry | Submenu | Focus |
|---|---|---|
| Power | Power | Engine output, swap baseline, drivetrain response |
| Tires | Tires | Compound profile and front/rear grip balance |
| Brakes | Brakes | Brake force, handbrake force, brake bias |
| Suspension | Suspension | Steering balance, ride profile, chassis balance |
| Anti-Roll | Anti-Roll | Roll stiffness and front/rear roll distribution |
| Nitro | Nitro | Nitrous level and shot behavior |

Below is a complete breakdown of what can be tuned in each category.

## Power
| Control | Type | What It Tunes | Notes |
|---|---|---|---|
| Engine | List | Engine upgrade stage (power/top speed progression) | Uses `Config.packDefinitions.engine` stages (`stock`, `stage_1`, ...). |
| Engine Swap | List | Baseline engine profile and engine audio source | Uses `pt_engine_swaps` model list to build swap options dynamically. |
| Transmission | List | Gearbox behavior and shift response | Uses `Config.packDefinitions.transmission` (gear count + clutch rate offsets). |

## Tires
| Control | Type | What It Tunes | Notes |
|---|---|---|---|
| Compound | List | Tire usage profile (`stock`, `road`, `mixed`, `offroad`) | Category selects broad driving surface intent. |
| Quality | List | Compound quality ladder (`low_end` to `top_end`) | Higher quality changes grip target and loss behavior, not only peak grip. |
| Grip Bias Front | Slider | Front/rear grip distribution (`fTractionBiasFront`) | Lets you tune understeer/oversteer balance. |

## Brakes
| Control | Type | What It Tunes | Notes |
|---|---|---|---|
| Brakes | List | Main brake force progression (`fBrakeForce`) | Uses `Config.packDefinitions.brakes`. |
| Handbrakes | List | Handbrake force progression (`fHandBrakeForce`) | Uses `Config.packDefinitions.handbrakes`. |
| Brake Bias Front | Slider | Front/rear brake force distribution (`fBrakeBiasFront`) | Useful to stabilize entry or increase rotation tendency. |

## Suspension
| Control | Type | What It Tunes | Notes |
|---|---|---|---|
| Steering Balance | List | Steering-lock response mode | Modes include `stock`, `balanced`, aggressive and soft variants. |
| Suspension | List | Base suspension profile (force/damping package) | Uses `Config.packDefinitions.suspension`. |
| Clearance | Slider | Ride height / suspension raise (`fSuspensionRaise`) | Also respects suspension limit adjustments. |
| Suspension Bias Front | Slider | Front/rear suspension load distribution (`fSuspensionBiasFront`) | Changes weight transfer character. |
| CG Offset | Slider | Vertical center of gravity offset | Moves CoG up/down relative to stock behavior. |

## Anti-Roll
| Control | Type | What It Tunes | Notes |
|---|---|---|---|
| Anti-Roll Bars | Slider | Overall anti-roll stiffness (`fAntiRollBarForce`) | Higher values reduce body roll but can reduce compliance. |
| Anti-Roll Bias Front | Slider | Front/rear anti-roll distribution (`fAntiRollBarBiasFront`) | Fine-tunes cornering balance. |

## Nitro
| Control | Type | What It Tunes | Notes |
|---|---|---|---|
| Nitrous | List | Nitrous power tier | Uses `Config.packDefinitions.nitrous` (`stock`, `level_1` ...). |
| Shot Strength | Slider | Shot throughput vs on-time tradeoff | Higher strength increases shove and shortens shot duration. |

Current nitro runtime behavior:

| System Rule | Value |
|---|---|
| Shots per full refill | 3 |
| Per-shot cooldown | 40 seconds |
| Refill condition | Vehicle is essentially stopped (static refill model) |
| Cooldown feedback | Subtitle: `Engine is too hot. Wait Xs.` |

## Additional Script/API Controls
| Control | Access Path | What It Tunes | Notes |
|---|---|---|---|
| Rev Limiter | Export: `SetCurrentVehicleRevLimiterEnabled(enabled)` | Throttle cut behavior at redline | Boolean per current vehicle; part of synchronized tune state. |
| Steering Balance (programmatic) | Export: `SetCurrentVehicleSteeringLockMode(mode)` | Same steering mode as Suspension menu item | Lets scripts apply `stock`/factor-based steering modes directly. |

## Notes
| Item | Description |
|---|---|
| Persistence | Tuned state is synchronized per vehicle via state bags so behavior can be reapplied consistently. |
| Data source | Pack options come from `performancetuning/shared/Config.lua`; sliders use runtime ranges from config/runtime normalization. |
| Scope | Performance Tuning applies real handling changes rather than cosmetic-only menu values. |
