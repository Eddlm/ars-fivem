# Configuration Reference

## Convars

These are set in `server.cfg` using `setr`.

### Master Toggles

| Convar                        | Type | Default | Example                                 | Description                                        |
| ----------------------------- | ---- | ------- | --------------------------------------- | -------------------------------------------------- |
| `cp_offroad_boost_enabled`    | bool | `true`  | `setr cp_offroad_boost_enabled true`    | Enable/disable offroad power boost.                |
| `cp_rollovers_enabled`        | bool | `true`  | `setr cp_rollovers_enabled true`        | Enable/disable rollover recovery.                  |
| `cp_wheelies_enabled`         | bool | `true`  | `setr cp_wheelies_enabled true`         | Enable/disable wheelie control.                    |
| `cp_wheelies_muscle_only`     | bool | `true`  | `setr cp_wheelies_muscle_only true`     | Restrict wheelies to muscle car class (class 4).   |
| `cp_wheelies_native_disabled` | bool | `true`  | `setr cp_wheelies_native_disabled true` | Suppress GTA's native wheelie state during launch. |

### Rollover Thresholds

| Convar                    | Type   | Default | Example                             | Description                                                     |
| ------------------------- | ------ | ------- | ----------------------------------- | --------------------------------------------------------------- |
| `cp_rollover_start_speed` | number | `8.94`  | `setr cp_rollover_start_speed 8.94` | Minimum speed (m/s, ≈20 mph) to trigger rollover recovery.      |
| `cp_rollover_keep_speed`  | number | `6.71`  | `setr cp_rollover_keep_speed 6.71`  | Speed below which rollover recovery deactivates (m/s, ≈15 mph). |
| `cp_rollover_start_rot`   | number | `180.0` | `setr cp_rollover_start_rot 180.0`  | Minimum angular velocity (°/s) on any axis to trigger.          |
| `cp_rollover_keep_rot`    | number | `90.0`  | `setr cp_rollover_keep_rot 90.0`    | Below this angular velocity, rollover recovery deactivates.     |

### Offroad

| Convar                      | Type   | Default | Example                              | Description                           |
| --------------------------- | ------ | ------- | ------------------------------------ | ------------------------------------- |
| `cp_offroad_max_multiplier` | number | `5.0`   | `setr cp_offroad_max_multiplier 5.0` | Maximum offroad power multiplier cap. |

### Debug

| Convar                    | Type | Default | Example                             | Description                                                                |
| ------------------------- | ---- | ------- | ----------------------------------- | -------------------------------------------------------------------------- |
| `cPhysicsPrintLevel`      | int  | `0`     | `setr cPhysicsPrintLevel 2`         | Print level. `2` enables on-screen debug overlays for rollovers and power. |
| `ars_skip_uptodate_print` | bool | `false` | `setr ars_skip_uptodate_print true` | Suppress the update notifier's "Up to date" message.                       |

---

## Config.lua — Shared Configuration

### Powerslides

| Field                                | Type   | Default | Description                                                                      |
| ------------------------------------ | ------ | ------- | -------------------------------------------------------------------------------- |
| `slideAngleStepDegrees`              | number | `20.0`  | Degrees per slide-multiplier step. Higher = more power per degree of slip angle. |
| `slideMaxMultiplier`                 | number | `5.0`   | Cap on the slide power multiplier.                                               |
| `slideSpeedThresholdMetersPerSecond` | number | `3.0`   | Minimum planar speed before slide physics kick in.                               |

### Surface Material Drag Table (`materialTyreDragByIndex`)

A lookup table mapping GTA surface material IDs to drag coefficients.

- **Negative values** (e.g. `-0.15`): Tarmac, concrete, and other paved surfaces. These reduce the offroad multiplier (traction is already good).
- **Positive values** (e.g. `0.15`): Dirt, sand, grass, and other offroad surfaces. These increase the offroad multiplier (GTA penalises traction on these, so power is boosted to compensate).

| Material ID | Value          | Surface       |
| ----------- | -------------- | ------------- |
| 0           | -0.15          | Default/Paved |
| 1           | -0.10          | Road          |
| 2           | -0.10          | Concrete      |
| 4–5, 7–9    | -0.10 to -0.15 | Various paved |
| 10          | -0.20          | Stone cobble  |
| 18          | 0.115          | Grass         |
| 19          | 0.08           | Dry grass     |
| 20          | 0.13           | Sand/dirt     |
| 29          | 0.15           | Deep sand     |
| 44          | 0.02           | Snow          |
| 48–49       | 0.01–0.02      | Ice           |

_(Only a subset shown — see `Config.lua` for the full 50-entry table.)_

### Advanced — Rollovers

| Field                    | Type   | Default | Unit | Description                                                                               |
| ------------------------ | ------ | ------- | ---- | ----------------------------------------------------------------------------------------- |
| `startSpeedMs`           | number | `8.94`  | m/s  | Minimum speed to trigger. Overridden by `cp_rollover_start_speed` convar.                 |
| `keepSpeedMs`            | number | `6.71`  | m/s  | Speed below which recovery stops. Overridden by `cp_rollover_keep_speed` convar.          |
| `angularStartDegrees`    | number | `180.0` | °/s  | Angular velocity to trigger. Overridden by `cp_rollover_start_rot` convar.                |
| `angularKeepDegrees`     | number | `90.0`  | °/s  | Angular velocity below which recovery stops. Overridden by `cp_rollover_keep_rot` convar. |
| `checkIntervalMs`        | number | `300`   | ms   | How often rollover conditions are re-evaluated.                                           |
| `forceHeightOffset`      | number | `4.0`   | m    | Height at which the recovery force is applied (above the vehicle).                        |
| `forceMagnitude`         | number | `1.4`   | —    | Base force magnitude of the recovery push.                                                |
| `settleDurationMs`       | number | `500`   | ms   | Time over which the initial force multiplier decays to normal.                            |
| `initialForceMultiplier` | number | `3.0`   | ×    | Force multiplier applied at the start of a rollover (decays to 1× over settle duration).  |

### Advanced — Wheelies

| Field                              | Type   | Default | Unit | Description                                                                   |
| ---------------------------------- | ------ | ------- | ---- | ----------------------------------------------------------------------------- |
| `armSpeedThresholdMetersPerSecond` | number | `1.0`   | m/s  | Maximum vehicle speed to arm the wheelie launch.                              |
| `forceMultiplier`                  | number | `0.4`   | —    | Base upward force applied during a wheelie.                                   |
| `frontOffsetLengthMultiplier`      | number | `2.0`   | ×    | Multiplied by vehicle length to get the force application offset from centre. |

## Planned Convar Candidates

The following `Config.lua` fields are annotated as future convar candidates:

| Planned convar                     | Maps to                                     |
| ---------------------------------- | ------------------------------------------- |
| `cp_slide_speed_threshold`         | `Config.slideSpeedThresholdMetersPerSecond` |
| `cp_slide_max_multiplier`          | `Config.slideMaxMultiplier`                 |
| `cp_virtual_mirror_enabled` / etc. | (from customcam, listed for completeness)   |
