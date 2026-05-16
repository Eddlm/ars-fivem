# Configuration Reference

## Convars

| Convar                    | Type | Default | Example                             | Description                                          |
| ------------------------- | ---- | ------- | ----------------------------------- | ---------------------------------------------------- |
| `ars_skip_uptodate_print` | bool | `false` | `setr ars_skip_uptodate_print true` | Suppress the update notifier's "Up to date" message. |

## Config.lua

### Menu

| Field                 | Type   | Default                  | Description                                  |
| --------------------- | ------ | ------------------------ | -------------------------------------------- |
| `menu.keybindCommand` | string | `"+vehiclemanager_menu"` | Keybind command prefix for opening the menu. |
| `menu.defaultKey`     | string | `"F6"`                   | Default key binding.                         |

### Appearance

The appearance config contains all colour option tables used by the customization menu:

| Field                   | Type  | Description                                                                |
| ----------------------- | ----- | -------------------------------------------------------------------------- |
| `baseGlossColorOptions` | table | 75 classic/metallic GTA colour options with `{label, colorId}`.            |
| `matteColorOptions`     | table | 20 matte colour options.                                                   |
| `utilColorOptions`      | table | 22 utility colour options.                                                 |
| `wornColorOptions`      | table | 22 worn colour options.                                                    |
| `metalColorOptions`     | table | 5 metal colour options.                                                    |
| `chromeColorOptions`    | table | 1 chrome colour option.                                                    |
| `xenonColorOptions`     | table | 13 xenon headlight colour options.                                         |
| `paintCategories`       | table | Paint category definitions mapping label, paint type, and colour set name. |

Paint categories:

| Key        | Label    | Paint Type | Colour Set            |
| ---------- | -------- | ---------- | --------------------- |
| `classic`  | Classic  | 0          | baseGlossColorOptions |
| `metallic` | Metallic | 1          | baseGlossColorOptions |
| `matte`    | Matte    | 3          | matteColorOptions     |
| `util`     | Util     | 0          | utilColorOptions      |
| `worn`     | Worn     | 0          | wornColorOptions      |
| `metal`    | Metal    | 4          | metalColorOptions     |
| `chrome`   | Chrome   | 5          | chromeColorOptions    |

### Categories

| Field                       | Type  | Description                                                                         |
| --------------------------- | ----- | ----------------------------------------------------------------------------------- |
| `partsVehicleModCategories` | table | 30 visual mod categories (spoilers, bumpers, etc.) with `{modType, label}`.         |
| `statsVehicleModCategories` | table | 5 stat upgrade categories (engine, brakes, transmission, suspension, armor).        |
| `wheelCategories`           | table | 13 wheel type categories (sport, muscle, lowrider, etc.) with `{wheelType, label}`. |

### Constants

#### Door Mapping

Maps door indices to readable names:

| Index | Name           |
| ----- | -------------- |
| 0     | frontLeftDoor  |
| 1     | frontRightDoor |
| 2     | backLeftDoor   |
| 3     | backRightDoor  |
| 4     | hood           |
| 5     | trunk          |
| 6     | trunk2         |

#### Tyre Mapping

Maps tyre indices to readable names:

| Index | Name                    |
| ----- | ----------------------- |
| 0–1   | frontLeft, frontRight   |
| 2–3   | middleLeft, middleRight |
| 4–5   | backLeft, backRight     |
| 6–8   | extra6, extra7, extra8  |

#### Tuning Selection Schema

Defines the persistent tuning fields that are saved/loaded with a vehicle, along with their defaults:

| Key                    | Default     | Parse   |
| ---------------------- | ----------- | ------- |
| `enginePack`           | `"stock"`   | string  |
| `engineSwapPack`       | `"stock"`   | string  |
| `transmissionPack`     | `"stock"`   | string  |
| `suspensionPack`       | `"stock"`   | string  |
| `tireCompoundPack`     | `"stock"`   | string  |
| `tireCompoundCategory` | `"stock"`   | string  |
| `tireCompoundQuality`  | `"mid_end"` | string  |
| `brakePack`            | `"stock"`   | string  |
| `nitrousLevel`         | `"stock"`   | string  |
| `steeringLockMode`     | `"stock"`   | string  |
| `revLimiterEnabled`    | `false`     | boolean |
| `nitrousShotStrength`  | `1.0`       | number  |
| `antirollForce`        | `0.0`       | number  |
| `brakeBiasFront`       | `0.5`       | number  |
| `gripBiasFront`        | `0.5`       | number  |
| `antirollBiasFront`    | `0.5`       | number  |
| `suspensionRaise`      | `0.0`       | number  |
| `suspensionBiasFront`  | `0.5`       | number  |
| `cgOffsetTweak`        | `0.0`       | number  |

### UI

| Field                                        | Type   | Default                                  | Description                                                   |
| -------------------------------------------- | ------ | ---------------------------------------- | ------------------------------------------------------------- |
| `menuXPosition`                              | number | `20`                                     | Horizontal position of the menu on screen.                    |
| `menuTitle`                                  | string | `"Vehicle Manager"`                      | Title shown in the menu header.                               |
| `menuSubtitle`                               | string | `"Fix, customize and save your vehicle"` | Subtitle shown below the title.                               |
| `menuKeybindReleaseCommand`                  | string | `"-vehiclemanager_menu"`                 | Release command for the keybind.                              |
| `menuKeybindDescription`                     | string | `"Open the vehicle manager menu"`        | Description shown in keybind settings.                        |
| `menuAvailabilityRefreshMs`                  | number | `200`                                    | How often (ms) the menu checks if the player is in a vehicle. |
| `performanceSettingsPiOptions`               | table  | `{"No", "Yes"}`                          | Labels for PI enable/disable toggle.                          |
| `performanceSettingsRevLimiterOptions`       | table  | `{"Off", "On"}`                          | Labels for rev limiter toggle.                                |
| `performanceSettingsSteeringLockModeOptions` | table  | 12 options                               | Labels for steering lock percentage selector.                 |
| `tuneStateBagKey`                            | string | `"performancetuning:tuneState"`          | State bag key for tuning data sync.                           |
| `handlingStateBagKey`                        | string | `"performancetuning:handlingState"`      | State bag key for handling data sync.                         |
| `saveIdStateBagKey`                          | string | `"vehiclemanager:saveId"`                | State bag key for save ID.                                    |
