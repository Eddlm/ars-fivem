# customphysics Refactor Plan

## Issues Found

### 1. Dead `notify()` function and dead debug-interval block in nitrous.lua

`nitrous.lua` defines a `notify()` helper (lines 18–22) that is never called anywhere in the file or the resource. Additionally, the `debugStatusIntervalMs` interval check at lines 98–101 only updates `lastStatusNotifyAt` but does nothing else — the body has no output or side effect.

**Fix:** Remove the dead `notify()` function and collapse the dead interval block. The interval timer state (`lastStatusNotifyAt`) is also now unused, so remove it from `activeNitrousShot` and from `reset()`.

---

### 2. Redundant triple-mapper `DisableControlAction` in nitrous.lua

```lua
DisableControlAction(0, Nitrous.controlId, true)
DisableControlAction(1, Nitrous.controlId, true)
DisableControlAction(2, Nitrous.controlId, true)
```

Mappers 0, 1, and 2 cover the same physical input in practice. In FiveM, disabling on mapper 0 is sufficient for all standard input contexts. The triple call adds no correctness and is noisy.

**Decision:** Leave as-is. Disabling on all three mappers is a common defensive pattern in FiveM to guard against `IsDisabledControlPressed` usage elsewhere. The cost is negligible.

---

### 3. `getUsableDrivenWheelPower` stale-value return during shift blocks (power.lua)

`calculateOffroadTargetMultiplier()` calls `getUsableDrivenWheelPower()` which updates and returns `state.lastDrivenWheelPower`. However, when `offroadShiftBlocked` is true (line 308), the function returns `state.offroadPowerMultiplier` (the current live multiplier) instead of 1.0, so the stale hold is intentional — it freezes the multiplier in-place during gear shifts rather than spiking or dropping. The function name `getUsableDrivenWheelPower` accurately describes the intent (use last known good value). No fix needed.

---

### 4. Stale `lastRpm` in `state` is written nowhere (power.lua)

`state.lastRpm` is declared and reset to `0.0` in `reset()`, but is never written during `update()` or any other function. It is not read either. It is a leftover field from an earlier design.

**Fix:** Remove `lastRpm` from the `state` table and from `reset()`.

---

### 5. `frameTime <= 0.000001` guard duplicated in wheelies.lua and rollovers.lua

Both files have identical inline guards:
```lua
local frameTime = GetFrameTime()
if frameTime <= 0.000001 then
    frameTime = 1.0 / 60.0
end
```
`CustomPhysicsUtil.getDeltaSeconds()` in `util.lua` already does exactly this and is available to both files.

**Fix:** Replace both inline guards with `CustomPhysicsUtil.getDeltaSeconds()`.

---

### 6. `getVehicleLength` called twice per wheelie active frame (wheelies.lua)

When the wheelie is active, `CustomPhysicsWheelies.update()` calls `getVehicleLength(vehicle)` twice: once for `frontOffset` (line 225) and once inside `getSlopeRelativePitchDegrees()` via `sampleOffset` (line 103). The vehicle model dimensions don't change frame to frame, so this is a wasted native call.

**Fix:** Call `getVehicleLength(vehicle)` once, store in a local, and pass the length into `getSlopeRelativePitchDegrees` as a parameter.

---

### 7. Three alias locals with identical values in vehiclemanager.lua (not in scope here — skip)

Not applicable to customphysics.

---

## Execution Order

1. nitrous.lua — remove dead `notify()`, dead interval body, and `lastStatusNotifyAt` state field
2. power.lua — remove dead `lastRpm` from `state` table and from `reset()`
3. wheelies.lua — replace inline `frameTime` guard with `CustomPhysicsUtil.getDeltaSeconds()`; pass vehicle length into `getSlopeRelativePitchDegrees`
4. rollovers.lua — replace inline `frameTime` guard with `CustomPhysicsUtil.getDeltaSeconds()`
