# Race Data Format

Races are stored as JSON files in two directories:

| Directory      | Source            | Description                                    |
| -------------- | ----------------- | ---------------------------------------------- |
| `CustomRaces/` | Player-created    | Races built using the in-game editor.          |
| `OnlineRaces/` | GTA Online import | Races imported from GTA Online by Rockstar ID. |

## Race Index

`race_index.json` is a master catalog listing all known races:

```json
{
  "definitions": [
    {
      "lookupName": "simple",
      "name": "simple",
      "sourceType": "custom",
      "updatedAt": 1776799572
    },
    {
      "lookupName": "gran prix sachs center",
      "name": "Gran Prix Sachs Center",
      "sourceType": "online",
      "raceId": "34PznEYINkmqfi_DlAXA1A",
      "updatedAt": 1776795542
    }
  ]
}
```

| Field        | Description                                                      |
| ------------ | ---------------------------------------------------------------- |
| `lookupName` | Normalised name used for search and reference.                   |
| `name`       | Display name.                                                    |
| `sourceType` | `"custom"` for player-created, `"online"` for GTA Online import. |
| `raceId`     | Rockstar race ID (only present for `online` source).             |
| `updatedAt`  | Unix timestamp of last modification.                             |

## Custom Race Format

```json
{
  "mission": {
    "race": {
      "name": "simple",
      "chp": 11,
      "chl": [
        { "x": 2939.99, "y": 4722.94, "z": 50.08 },
        { "x": 2979.04, "y": 4610.13, "z": 52.85 }
      ],
      "chs": [
        1.75, 1.75, 1.5, 1.5, 1.5, 1.125, 1.125, 1.125, 1.875, 1.875, 1.75
      ]
    },
    "prop": {
      "no": 0,
      "model": [],
      "vRot": [],
      "loc": [],
      "prpclr": [],
      "head": []
    },
    "dhprop": {
      "pos": [],
      "no": 0,
      "mn": [],
      "bits": []
    }
  }
}
```

### Fields

| Field               | Type                 | Description                                                                                       |
| ------------------- | -------------------- | ------------------------------------------------------------------------------------------------- |
| `mission.race.name` | string               | Race display name.                                                                                |
| `mission.race.chp`  | number               | Number of checkpoints.                                                                            |
| `mission.race.chl`  | array of `{x, y, z}` | Checkpoint locations (world coordinates).                                                         |
| `mission.race.chs`  | array of numbers     | Checkpoint radii (one per checkpoint, in meters).                                                 |
| `mission.prop`      | object               | Race props (cones, barriers, etc.). `no` = count, rest are arrays.                                |
| `mission.dhprop`    | object               | Dynamic/hazard props. `no` = count, `pos` = positions, `mn` = model hashes, `bits` = state flags. |

### Checkpoint Geometry

- The first checkpoint is the **start line**.
- If the last checkpoint connects back to the first, it's a **circuit** (multi-lap possible).
- If start and finish are different, it's a **point-to-point** sprint (auto-set to 1 lap if distance > `pointToPointAutodetectDistanceMeters`).

### Width / Radius

- `chs` values represent the **half-width** of each checkpoint in meters.
- The editor offers discrete width options from 2.0 m to 40.0 m (see `Config.advanced.menu.checkpointWidthOptions`).
- Valid range is `checkpointRadiusMinMeters` (2.0 m) to `checkpointRadiusMaxMeters` (40.0 m).

## Server-Side Validation

When a race is saved, the server (`race_parsing.lua`) validates:

1. `lookupName` is present, non-empty, and unique.
2. `chp` matches the length of `chl` and `chs`.
3. All checkpoint coordinates are valid numbers.
4. All checkpoint radii are within the min/max range.
5. Props and dynamic props have matching array lengths.
6. The race file is saved as a valid JSON file in the appropriate directory.

## See Also

- [Configuration reference](configuration.md) for checkpoint and validation settings.
