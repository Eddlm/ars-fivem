# Performance Panel

The performance panel is an on-screen HUD that displays a **Performance Index (PI)** and stat bars for the current vehicle and nearby vehicles.

## How It Works

### PI Calculation

The PI is computed from four raw vehicle stats, multiplied by distribution weights:

```
PI = (powerGs × 3000) + (topSpeedMph × 12.5) + (gripGs × 600) + (brakeGs × 400)
```

Each stat is measured from the vehicle's live handling data:

| Stat          | Source                                               | Measurement                |
| ------------- | ---------------------------------------------------- | -------------------------- |
| **Power**     | `fInitialDriveForce`, transmission upgrades, nitrous | Forward acceleration in Gs |
| **Top Speed** | `fInitialDriveMaxFlatVel`                            | Converted to mph           |
| **Grip**      | `fTractionCurveMax` + tyre compound offsets          | Lateral Gs                 |
| **Brake**     | `fBrakeForce` + brake upgrades                       | Deceleration in Gs         |

Nitrous level contributes to the power bar at `powerBarFillPerNitroLevel` (default 2 points per tier).

### Bar Fill

Each stat bar fills relative to the configured target:

| Bar       | Fill Target | Unit |
| --------- | ----------- | ---- |
| Power     | 1.0         | Gs   |
| Top Speed | 250.0       | mph  |
| Grip      | 3.5         | Gs   |
| Brake     | 3.5         | Gs   |

These targets should be adjusted to match your server's vehicle fleet — a server full of supercars may want higher targets than a server with sedans.

### Personal Panel

The player's own vehicle panel is drawn:

- To the right of the tuning menu (with a configurable gap).
- At a fixed position set by `primaryPanelLeftMargin` and `mainPanelYOffset`.
- With its height set by `defaultPanelHeightUnits`.

### Nearby Vehicle Panels

When `performanceNearbyPanels.enabled` is true (default), panels are also drawn on nearby vehicles that are within `maxDistanceMeters` (default 30 m). Up to `maxPanels` (default 6) are shown simultaneously.

Nearby panels scale down with distance:

- At closest range: `sharedPanelBaseScale` (0.95).
- At maximum distance: `sharedPanelMinScale` (0.72).
- Alpha is set by `sharedPanelAlpha` (168).

### Display Modes

The panel can operate in different display modes, configurable via exports:

- `GetPiDisplayModeIndex` / `SetPiDisplayModeIndex`
- `GetPerformanceBarsDisplayMode` / `SetPerformanceBarsDisplayMode`

### Drawing

The panel uses ScaleformUI's instrinsic drawing methods. A draw request system with `panelDrawRequestStaleMs` (default 1000 ms) prevents stale panels from persisting when vehicles are no longer valid.

## Configuration

| Field                                       | Default     | Description                     |
| ------------------------------------------- | ----------- | ------------------------------- |
| `performancePiDistribution.power`           | `3000`      | PI multiplier for power.        |
| `performancePiDistribution.topSpeed`        | `12.5`      | PI multiplier for top speed.    |
| `performancePiDistribution.grip`            | `600`       | PI multiplier for grip.         |
| `performancePiDistribution.brake`           | `400`       | PI multiplier for brake.        |
| `performanceBarFillTargets.power`           | `1.0` Gs    | Power bar 100% target.          |
| `performanceBarFillTargets.topSpeedMph`     | `250.0` mph | Top speed bar 100% target.      |
| `performanceBarFillTargets.grip`            | `3.5` Gs    | Grip bar 100% target.           |
| `performanceBarFillTargets.brake`           | `3.5` Gs    | Brake bar 100% target.          |
| `performanceNearbyPanels.enabled`           | `true`      | Show panels on nearby vehicles. |
| `performanceNearbyPanels.maxDistanceMeters` | `30.0`      | Max distance for nearby panels. |
| `performanceNearbyPanels.maxPanels`         | `6`         | Max simultaneous nearby panels. |

See [configuration.md](configuration.md) for the full panel UI settings.
