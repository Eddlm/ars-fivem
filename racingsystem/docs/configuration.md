# Configuration Reference

## Convars

| Convar                    | Type | Default | Example                             | Description                                         |
| ------------------------- | ---- | ------- | ----------------------------------- | --------------------------------------------------- |
| `ars_skip_uptodate_print` | bool | `false` | `setr ars_skip_uptodate_print true` | Suppress update notifier's "Up to date" message. |

---

## Main Config (`Config`)

### Checkpoints

| Field                          | Type   | Default | Unit | Description                             |
| ------------------------------ | ------ | ------- | ---- | --------------------------------------- |
| `checkpointDrawDistanceMeters` | number | `250.0` | m    | How far away checkpoints are rendered.  |
| `markerTypeId`                 | number | `1`     | —    | GTA marker type used for checkpoints.   |
| `visualCheckpointRadiusScale`  | number | `2.0`   | ×    | Visual size multiplier for checkpoints. |
| `checkpointRadiusMinMeters`    | number | `2.0`   | m    | Minimum checkpoint radius.              |
| `checkpointRadiusMaxMeters`    | number | `40.0`  | m    | Maximum checkpoint radius.              |

### Races

| Field                          | Type   | Default | Description                                                   |
| ------------------------------ | ------ | ------- | ------------------------------------------------------------- |
| `minLapCount`                  | number | `1`     | Minimum number of laps for a race.                            |
| `maxLapCount`                  | number | `10`    | Maximum number of laps for a race.                            |
| `playerCanInvokeMultipleRaces` | bool   | `false` | Whether a single player can host multiple simultaneous races. |
| `raceOwnerCanKillOwnedRace`    | bool   | `false` | Whether the race owner can forcibly end their own race.       |
| `countdownMs`                  | number | `5000`  | Countdown duration before race start in milliseconds.         |
| `lateJoinProgressLimitPercent` | number | `50`    | Maximum race progress (%) after which late joins are blocked. |

### Admin

| Field      | Type   | Default                | Description                                                |
| ---------- | ------ | ---------------------- | ---------------------------------------------------------- |
| `adminAce` | string | `"racingsystem.admin"` | ACE group that has admin privileges for the racing system. |

---

## Advanced — Client

| Field                                       | Type   | Default              | Unit  | Description                                                       |
| ------------------------------------------- | ------ | -------------------- | ----- | ----------------------------------------------------------------- |
| `checkpointRadiusStepMeters`                | number | `1.0`                | m     | Step size when adjusting checkpoint radius in the editor.         |
| `editorPitchUpControlId`                    | number | `111`                | input | Control ID for editor camera pitch up.                            |
| `editorPitchDownControlId`                  | number | `112`                | input | Control ID for editor camera pitch down.                          |
| `checkpointPassArmDistance`                 | number | `30.0`               | m     | Distance ahead of a checkpoint where the arm zone begins.         |
| `checkpointPassReleaseThreshold`            | number | `0.75`               | ratio | How far through the arm zone a player must be to count as a pass. |
| `checkpointRecoveryPassMaxMph`              | number | `5.0`                | mph   | Max speed for a retroactive checkpoint pass (recovery).           |
| `checkpointRecoveryForwardVelocityRatioMax` | number | `0.66`               | ratio | Max forward velocity ratio for recovery passes.                   |
| `checkpointSoftPowerPenaltyMultiplier`      | number | `-20.0`              | %     | FiveM engine-power adjustment during soft penalty (`0` normal, negative reduces power). |
| `leaderboardClientTiebreakEnabled`          | bool   | `false`              | —     | Whether the client breaks leaderboard ties.                       |
| `checkpointRuntimeZOffsetMeters`            | number | `-2.0`               | m     | Z offset applied to checkpoint markers during a race.             |
| `maxFuturePreviewCheckpoints`               | number | `3`                  | count | How many upcoming checkpoints to preview as blips.                |
| `markerTaxonomy.routeCheckpointTypeId`      | number/nil | `nil`              | —     | Optional route checkpoint marker override; `nil` uses `markerTypeId`. |
| `markerTaxonomy.routeChevronTypeId`         | number | `20`                 | —     | Marker type for chevron route markers.                            |
| `markerTaxonomy.startLineIdleTypeId`        | number | `4`                  | —     | Marker type for idle start lines.                                 |
| `markerTaxonomy.startLineIdleColor`         | table  | `{255,255,255,0}`    | RGBA  | Colour of idle start line markers.                                |
| `markerTaxonomy.startLineBlipSprite`        | number | `38`                 | —     | Blip sprite for start lines.                                      |
| `extraPrintLevel`                           | number | `0`                  | —     | Client-side extra debug print level.                              |

## Advanced — Server

| Field                                  | Type   | Default | Unit | Description                                                         |
| -------------------------------------- | ------ | ------- | ---- | ------------------------------------------------------------------- |
| `ugcFetchRetryCooldownMs`              | number | `700`   | ms   | Cooldown between UGC fetch retries for GTA Online races.            |
| `ugcFetchTotalTimeoutMs`               | number | `30000` | ms   | Total deadline across all GTA Online URL candidates.                |
| `gtaoCheckpointRadiusScale`            | number | `1.0`   | ×    | Scale factor applied to GTA Online race checkpoint radii on import. |
| `pointToPointAutodetectDistanceMeters` | number | `500.0` | m    | If start-to-finish distance exceeds this, auto-set laps to 1.       |
| `extraPrintLevel`                      | number | `0`     | —    | Server-side extra debug print level.                                |

## Advanced — Menu

| Field                    | Type   | Default                 | Description                                       |
| ------------------------ | ------ | ----------------------- | ------------------------------------------------- |
| `title`                  | string | `"Race Control"`        | Menu title.                                       |
| `subtitle`               | string | `"~b~RACINGSYSTEM"`     | Menu subtitle.                                    |
| `x`                      | number | `20`                    | Horizontal position.                              |
| `checkpointWidthOptions` | table  | 21 options (2.0–40.0 m) | Available checkpoint width options in the editor. |
| `extraPrintLevel`        | number | `0`                     | Extra debug print level for menu code.            |
