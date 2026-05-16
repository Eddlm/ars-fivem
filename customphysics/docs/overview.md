# Custom Physics — Overview

Custom Physics is a **client-side** physics enhancement resource that modifies vehicle behaviour in three areas: **offroad power boost**, **rollover recovery**, and **wheelie control**. It also includes an **anti-boost** stability system and an **overspeed limiter**.

## What It Does

| Subsystem               | Purpose                                                                                                                            |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| **Offroad Power Boost** | When driving on drag surfaces (dirt, sand, mud), compensates for GTA's traction penalty by increasing engine power proportionally. |
| **Rollover Recovery**   | Detects when a vehicle is tumbling and applies a corrective force to help it land back on its wheels.                              |
| **Wheelie Control**     | Allows RWD and muscle cars to pull controlled wheelies from a standstill using a handbrake-launch mechanic.                        |
| **Anti-Boost**          | Detects forward acceleration that far exceeds what the drivetrain should produce (cheat acceleration) and caps engine power.       |
| **Overspeed Limiter**   | Reduces engine power and adds visual smoke when a vehicle exceeds its handling top speed.                                          |

## Quick Start

1. Drop `customphysics` into your resources directory.
2. Add `ensure customphysics` to your `server.cfg`.
3. All subsystems are enabled by default. Use convars to disable or tune them.

## Subsystems

- [Offroad Power Boost](offroad-boost.md)
- [Rollover Recovery](rollovers.md)
- [Wheelie Control](wheelies.md)
- [Anti-Boost & Overspeed](power-stack.md)

## File Layout

```
customphysics/
  fxmanifest.lua
  shared/Config.lua          — Tuneable constants + material drag table
  client/
    util.lua                 — Math helpers, vehicle snapshot builders
    wheelies.lua              — Wheelie subsystem
    rollovers.lua              — Rollover subsystem
    power.lua                  — Offroad boost, anti-boost, overspeed limiter
    client.lua                 — Main loop coordinator
  server/UpdateNotifier.lua
  docs/
    …                         — You are here
```

## See Also

- [Configuration reference](configuration.md)
- [Update Notifier](update-notifier.md)
