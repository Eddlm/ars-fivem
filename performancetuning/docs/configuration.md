# Configuration Reference

## Convars

| Convar                        | Type   | Default | Example                                      | Description                                                                |
| ----------------------------- | ------ | ------- | -------------------------------------------- | -------------------------------------------------------------------------- |
| `ars_skip_uptodate_print`     | bool   | `false` | `setr ars_skip_uptodate_print true`          | Suppress update notifier's "Up to date" message.                           |
| `pt_engine_swaps`             | string | `""`    | `setr pt_engine_swaps "dominator,gauntlet3"` | CSV list of vehicle models that allow engine swap packs. Empty = no swaps. |
| `pt_nitrous_shot_cooldown_ms` | int    | `0`     | `setr pt_nitrous_shot_cooldown_ms 4000`      | Cooldown between nitrous shots in milliseconds. 0 = no cooldown.           |

---

## Pack Definitions (`Config.packDefinitions`)

Each pack type has an array of pack entries. Every entry has at minimum an `id`, `label`, `enabled`, and `description`. Pack-specific fields are listed below.

### Engine Packs

| ID            | Label       | Description                               |
| ------------- | ----------- | ----------------------------------------- |
| `stock`       | Stock       | No changes.                               |
| `stage_1`     | Stage 1     | Small power and top speed rise.           |
| `stage_2`     | Stage 2     | Proper upgrades to the power and top end. |
| `stage_3`     | Stage 3     | Strongest without going to HSW.           |
| `hsw_special` | HSW Special | Absolute best this engine can do.         |

Engine packs use the `performanceModel` targets (see below) to compute handling changes.

### Transmission Packs

| ID             | Label               | `gearCountOffset` | `clutchRateOffset` | Description                           |
| -------------- | ------------------- | ----------------- | ------------------ | ------------------------------------- |
| `stock`        | Stock               | 0                 | 0                  | Original gearing and shift behaviour. |
| `tuned`        | Fluid Change        | 0                 | 2.0                | Improves shift times.                 |
| `street`       | Clutch Disc Swap    | 0                 | 4.0                | Sharper shifts, less hang.            |
| `pro`          | Pressure Plate Swap | 0                 | 6.0                | Further shift response increase.      |
| `race`         | Gearbox Swap        | 1                 | 8.0                | Extra gear + fast shifts.             |
| `race_gearbox` | Race Gearbox        | 3                 | 10.0               | Maximum gearing and shift speed.      |

### Suspension Packs

| ID      | Label  | Handling Changes                                         | Description                    |
| ------- | ------ | -------------------------------------------------------- | ------------------------------ |
| `stock` | Stock  | —                                                        | Keeps original suspension.     |
| `sport` | Medium | `fSuspensionForce` = 3.0, `fSuspensionReboundDamp` = 2.0 | All-rounder, decent stiffness. |
| `race`  | Hard   | `fSuspensionForce` = 4.0, `fSuspensionReboundDamp` = 2.0 | Less weight transfer, sharper. |
| `rally` | Soft   | `fSuspensionForce` = 2.0, `fSuspensionCompDamp` = 3.0    | More lean, softer feel.        |

### Tyre Packs

| ID          | Label     | `gripBarProgressRatio` | `compoundLossMultiplier` | `tractionLossMultiplier` | Description                               |
| ----------- | --------- | ---------------------- | ------------------------ | ------------------------ | ----------------------------------------- |
| `stock`     | Stock     | —                      | —                        | —                        | Original compound.                        |
| `street`    | Street    | 0.80                   | 0.8                      | 1.30                     | Mild grip upgrade, balanced.              |
| `sport`     | Sport     | 0.85                   | 0.8                      | 1.60                     | Sharper on-road grip.                     |
| `rally`     | Offroad   | 0.90                   | 0.8                      | 0.50                     | Better loose-surface, low-speed traction. |
| `race`      | Race Hard | 0.95                   | 0.8                      | 1.90                     | High grip, firmer breakaway.              |
| `race_soft` | Race Soft | 1.00                   | 0.8                      | 2.20                     | Maximum grip target.                      |

Rally tyres also set `lowSpeedLossMultiplier = 0.5`.

### Brake Packs

| ID        | Label   |
| --------- | ------- |
| `stock`   | Stock   |
| `level_1` | Level 1 |
| `level_2` | Level 2 |
| `level_3` | Level 3 |
| `level_4` | Level 4 |

### Handbrake Packs

| ID        | Label   |
| --------- | ------- |
| `stock`   | Stock   |
| `level_1` | Level 1 |
| `level_2` | Level 2 |
| `level_3` | Level 3 |
| `level_4` | Level 4 |

### Nitrous Packs

| ID        | Label   | `powerMultiplier` | Description       |
| --------- | ------- | ----------------- | ----------------- |
| `stock`   | Stock   | —                 | No nitrous.       |
| `level_1` | Level 1 | 0.5               | Light burst.      |
| `level_2` | Level 2 | 1.0               | Balanced burst.   |
| `level_3` | Level 3 | 1.5               | High-output.      |
| `level_4` | Level 4 | 2.0               | Maximum strength. |

---

## Performance Model (`Config.performanceModel`)

Defines how upgrades affect PI and handling:

| Category                                  | Target                                                  | Description                                   |
| ----------------------------------------- | ------------------------------------------------------- | --------------------------------------------- |
| `power.target`                            | `0.1` Gs                                                | Maximum power upgrade above stock baseline.   |
| `power.transmission.powerBonusPerUpgrade` | `0.01` Gs                                               | Extra power per transmission upgrade level.   |
| `power.nitrous.powerBarFillPerNitroLevel` | `2`                                                     | PI bar fill per nitrous tier.                 |
| `topSpeed.target`                         | `50`                                                    | Top speed upgrade (soon to be auto-adjusted). |
| `grip.target`                             | `0.5` Gs                                                | Maximum grip upgrade above stock.             |
| `grip.qualityLadder`                      | `low_end=0.25, mid_end=0.5, high_end=0.75, top_end=1.0` | Multiplier by tyre quality.                   |
| `grip.compoundRoadOffset.road`            | `0.0`                                                   | On-road grip offset.                          |
| `grip.compoundRoadOffset.rally`           | `-0.15`                                                 | Rally tyre on-road penalty.                   |
| `grip.compoundRoadOffset.offroad`         | `-0.30`                                                 | Offroad tyre on-road penalty.                 |
| `brake.target`                            | `0.25` Gs                                               | Maximum brake upgrade above stock.            |
| `handbrake.target`                        | `1.0`                                                   | Maximum handbrake upgrade multiplier.         |

## PI Distribution (`Config.performancePiDistribution`)

Multipliers that scale raw vehicle stats into PI numbers:

| Category   | Multiplier | Example                  |
| ---------- | ---------- | ------------------------ |
| `power`    | 3000       | 0.3 Gs × 3000 = 900 PI   |
| `topSpeed` | 12.5       | 100 mph × 12.5 = 1250 PI |
| `grip`     | 600        | 2.0 Gs × 600 = 1200 PI   |
| `brake`    | 400        | 0.5 Gs × 400 = 200 PI    |

## Performance Bar Fill Targets (`Config.performanceBarTargets`)

The maximum values that represent 100% on each performance bar:

| Category      | Value | Unit |
| ------------- | ----- | ---- |
| `power`       | 1.0   | Gs   |
| `topSpeedMph` | 250.0 | mph  |
| `grip`        | 3.5   | Gs   |
| `brake`       | 3.5   | Gs   |

## Nitrous (`Config.nitrous`)

| Field                   | Default | Description                                                                 |
| ----------------------- | ------- | --------------------------------------------------------------------------- |
| `baseDurationMs`        | 4000    | Duration of a single nitrous shot in ms.                                    |
| `nativePowerMultiplier` | 0.5     | Multiplier applied to `SetVehicleCheatPowerIncrease` during a shot.         |
| `shotsPerRefill`        | 3       | How many shots a full nitrous refill gives.                                 |
| `shotCooldownMs`        | 4000    | Cooldown between shots. Overridden by `pt_nitrous_shot_cooldown_ms` convar. |

## Slider Ranges (`Config.sliderRanges`)

| Slider                | Min    | Max   | Step  |
| --------------------- | ------ | ----- | ----- |
| `nitrousShotStrength` | 1.0    | 2.0   | 0.2   |
| `suspensionRaise`     | -0.300 | 0.300 | 0.010 |

## Nearby Player Panels (`Config.performanceNearbyPanels`)

| Field               | Default | Description                                      |
| ------------------- | ------- | ------------------------------------------------ |
| `enabled`           | `true`  | Whether to draw PI panels on nearby vehicles.    |
| `maxDistanceMeters` | `30.0`  | Only show panels for vehicles within this range. |
| `maxPanels`         | `6`     | Maximum number of nearby panels to draw at once. |

## Advanced — Panel UI

| Field                          | Default  | Description                                           |
| ------------------------------ | -------- | ----------------------------------------------------- |
| `sharedPanelHeightUnits`       | `0.15`   | Panel height in screen units.                         |
| `sharedPanelBaseScale`         | `0.95`   | Base scale of nearby player panels.                   |
| `sharedPanelMinScale`          | `0.72`   | Minimum scale after distance falloff.                 |
| `sharedPanelAlpha`             | `168`    | Background alpha of shared panels.                    |
| `sharedPanelFillAlpha`         | `204`    | Fill bar alpha.                                       |
| `sharedPanelHeaderHeightRatio` | `0.15`   | Header height as ratio of total.                      |
| `sharedPanelWidthUnits`        | `0.1875` | Panel width in screen units.                          |
| `defaultPanelHeightUnits`      | `0.0874` | Height of the player's own panel.                     |
| `primaryPanelLeftMargin`       | `0.014`  | Left margin for personal panel.                       |
| `menuPanelGapX`                | `0.018`  | Horizontal gap between menu and panel.                |
| `panelDrawRequestStaleMs`      | `1000`   | Time before a panel draw request is considered stale. |
