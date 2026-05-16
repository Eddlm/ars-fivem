# Nitrous

The nitrous system provides a burst of acceleration via `SetVehicleCheatPowerIncrease`, with refill management, cooldown, and visual effects.

## How It Works

### Activation

1. The player selects a nitrous pack via the tuning menu (stock through level 4).
2. When a nitrous pack is active, the player can activate a nitrous shot.
3. A shot temporarily multiplies the vehicle's engine power by the pack's `powerMultiplier` × the player's `nitrousShotStrength` setting.

### Shot Mechanics

| Parameter               | Default | Convar Override               | Description                                                                    |
| ----------------------- | ------- | ----------------------------- | ------------------------------------------------------------------------------ |
| `baseDurationMs`        | 4000    | —                             | How long a single shot lasts.                                                  |
| `nativePowerMultiplier` | 0.5     | —                             | Base `SetVehicleCheatPowerIncrease` during a shot, before the pack multiplier. |
| `shotsPerRefill`        | 3       | —                             | How many shots per full nitrous tank.                                          |
| `shotCooldownMs`        | 4000    | `pt_nitrous_shot_cooldown_ms` | Minimum time between shots.                                                    |

The effective power during a shot is:

```
cheatPower = nativePowerMultiplier × packPowerMultiplier × playerShotStrength
```

### Refill

After all shots are used, the player must wait for a refill. Refill timing and conditions depend on the in-game context (managed by the tuning menu).

### Visuals

Nitrous activates a particle effect (`veh_nitrous` from the `core` asset) on the vehicle's exhaust bones during a shot. The effect is started and stopped along with the shot timer.

### Nitrous Shot Strength Slider

The `nitrousShotStrength` slider (range 1.0–2.0, step 0.2) lets the player fine-tune how powerful each shot is within the pack's limits. This is stored in the vehicle's tuning selection state bag.

## Pack Details

| Pack      | `powerMultiplier` | Description             |
| --------- | ----------------- | ----------------------- |
| `stock`   | —                 | No nitrous available.   |
| `level_1` | 0.5               | Light burst.            |
| `level_2` | 1.0               | Balanced burst.         |
| `level_3` | 1.5               | High-output burst.      |
| `level_4` | 2.0               | Maximum strength burst. |

## Convar

| Convar                        | Type | Default | Description                                                          |
| ----------------------------- | ---- | ------- | -------------------------------------------------------------------- |
| `pt_nitrous_shot_cooldown_ms` | int  | `0`     | Cooldown between nitrous shots in ms. 0 = use config default (4000). |

## See Also

- [Tuning Packs](tuning-packs.md) for how nitrous fits into the overall pack system.
- [Configuration reference](configuration.md) for `Config.nitrous` values.
