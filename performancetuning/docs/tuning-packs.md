# Tuning Packs

Tuning packs are pre-defined sets of handling changes that can be applied to a vehicle. They are the primary way players upgrade their cars through the menu system.

## How Packs Work

Each pack type (engine, transmission, suspension, tyres, brakes, handbrakes, nitrous) has an ordered list of pack entries from `stock` (no change) to the most aggressive option.

When a pack is applied:

1. The **original handling values** are cached from the vehicle's current state.
2. The pack's **values** are written to the vehicle via handling natives.
3. The **tuning selection** is stored on the vehicle's entity state bag (`performancetuning:tuneState`).
4. The **performance panel** and **PI metrics** update immediately.

When a pack is reset to `stock`:

- All handling fields revert to the cached original values.
- The state bag is cleared for that pack type.

## Pack Types

### Engine Packs

Engine upgrades modify drive force, top speed, and inertia based on the performance model targets. Each stage progressively increases power output:

| Pack        | Effect                                                                                |
| ----------- | ------------------------------------------------------------------------------------- |
| Stock       | No change.                                                                            |
| Stage 1–3   | Incremental power and speed increases via the `performanceModel.power.target` ladder. |
| HSW Special | Maximum upgrade — the vehicle gets the full power target.                             |

If `pt_engine_swaps` convar is set, vehicles listed in it also get an **engine swap** option that provides an even higher power ceiling.

### Transmission Packs

Transmission upgrades modify clutch shift rate and gear count:

- `clutchRateOffset` is added to the vehicle's `fClutchChangeRateScaleUpShift` and `fClutchChangeRateScaleDownShift`.
- `gearCountOffset` is added to `nInitialDriveGears` (capped to the model's maximum).

### Suspension Packs

Suspension packs directly set handling fields:

| Pack  | Fields Set                                   |
| ----- | -------------------------------------------- |
| sport | `fSuspensionForce`, `fSuspensionReboundDamp` |
| race  | `fSuspensionForce`, `fSuspensionReboundDamp` |
| rally | `fSuspensionForce`, `fSuspensionCompDamp`    |

### Tyre Packs

Tyre packs modify `fTractionCurveMin`, `fTractionCurveMax`, and `fTractionCurveLateral` based on:

- `gripBarProgressRatio` — how far along the grip upgrade bar this compound sits.
- `compoundLossMultiplier` — multiplier applied to traction loss values.
- `tractionLossMultiplier` — multiplier applied to traction curve values.

Rally (offroad) tyres also use `lowSpeedLossMultiplier` to reduce low-speed traction loss.

### Brake Packs

Brake packs modify `fBrakeForce` up to the `performanceModel.brake.target` value (0.25 Gs by default), scaled by the pack level.

### Handbrake Packs

Handbrake packs modify `fHandBrakeForce` up to the `performanceModel.handbrake.target` multiplier (1.0 by default).

### Nitrous Packs

Nitrous packs determine:

- **Availability** — whether the vehicle has nitrous at all.
- **Shot strength** — `powerMultiplier` for the `SetVehicleCheatPowerIncrease` call during a shot.
- **Refill count** — defaults to 3 shots per refill.

See [nitrous.md](nitrous.md) for full details.

## Tweak Values

In addition to packs, the menu exposes fine-tuning sliders for specific handling fields:

| Slider                | Field              | Range        | Step  |
| --------------------- | ------------------ | ------------ | ----- |
| Nitrous Shot Strength | —                  | 1.0–2.0      | 0.2   |
| Suspension Raise      | `fSuspensionRaise` | −0.300–0.300 | 0.010 |
| Anti-Roll Force       | —                  | 0.0–2.0      | 0.1   |
| Brake Bias Front      | —                  | 0.0–1.0      | 0.01  |
| Grip Bias Front       | —                  | 0.0–1.0      | 0.01  |
| Anti-Roll Bias Front  | —                  | 0.0–1.0      | 0.01  |
| Suspension Bias Front | —                  | 0.0–1.0      | 0.01  |
| CG Offset Tweak       | —                  | −0.5–0.5     | 0.01  |

These are saved/loaded via the `TUNING_SELECTION_SCHEMA` in vehiclemanager.

## Dynamic Lateral Curve

When tyre compound is changed, `DynamicCurveLateral.lua` adjusts `fTractionCurveLateral` in real time based on the front wheels' surface material. This makes tyre grip feel different on road vs. off-road surfaces depending on the compound choice.

## See Also

- [Configuration reference](configuration.md) for all pack definitions and performance model values.
- [Performance Panel](performance-panel.md) for how PI is displayed.
- [Nitrous](nitrous.md) for the nitrous shot system.
