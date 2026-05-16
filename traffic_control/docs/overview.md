# Traffic Control — Overview

Traffic Control is a **density enforcement** resource that forces ambient traffic and pedestrian population to configured values. It provides a client/server request system so that any script or admin can set traffic density, with the lowest active request always winning.

## What It Does

- Continuously enforces a traffic/ped density multiplier every frame.
- Accepts density requests from **server scripts**, **client events**, and a **server convar default**.
- Uses a competitive model — when multiple requests are active, the **lowest density wins**.
- Falls back to the convar default when no requests are active.

## Quick Start

1. Drop `traffic_control` into your resources directory.
2. Add `ensure traffic_control` to your `server.cfg`.
3. Optionally set a default density: `setr tControlDefault 0.5` (values 0.0 → 1.0).

## How Density Works

The density value is a multiplier from `0.0` (no traffic) to `1.0` (full GTA default). Each frame, the resource applies the effective density to all five GTA density natives:

| Native                                       | Effect                        |
| -------------------------------------------- | ----------------------------- |
| `SetVehicleDensityMultiplierThisFrame`       | Ambient vehicle traffic       |
| `SetRandomVehicleDensityMultiplierThisFrame` | Random/scenario vehicles      |
| `SetParkedVehicleDensityMultiplierThisFrame` | Parked vehicles               |
| `SetPedDensityMultiplierThisFrame`           | Ambient pedestrians           |
| `SetScenarioPedDensityMultiplierThisFrame`   | Scenario/spawning pedestrians |

## Request System

### From a Server Script

```lua
TriggerClientEvent('traffic_control:setMode', -1, 0.3, 'race_active', 'my_race_script')
-- Later, release the request:
TriggerClientEvent('traffic_control:setMode', -1, nil, 'race_over', 'my_race_script')
```

### From a Client Script

```lua
TriggerServerEvent('traffic_control:requestDensity', 0.0, 'cutscene_active', 'my_cutscene')
-- Later, release:
TriggerServerEvent('traffic_control:requestDensity', nil, 'cutscene_over', 'my_cutscene')
```

Passing `nil` as the density **releases** that request key, allowing the next-lowest request or the convar default to take effect.

### Request Resolution

Every frame, the client rebuilds its state:

1. **Lowest active request wins** — if multiple scripts request different densities, the smallest value is applied.
2. **No active requests** → falls back to the `tControlDefault` convar.
3. **No convar default** → does nothing (GTA default density).

Request keys are namespaced:

- Server-sourced: `server:<requestKey>`
- Client-sourced: `client:<playerSource>:<requestKey>`

This prevents cross-source key collisions.

## See Also

- [Configuration reference](configuration.md)
- [Update Notifier](update-notifier.md)
