# performancetuning Refactor Plan

## Issues Found

### 1. Dead unused parameters (client.lua)
`requestDragRebalance` accepts `durationMs` and the inner callback accepts `dragCoeff`, but both are silently discarded with `local _ = x`. The parameters do nothing and the signatures are misleading.

**Fix:** Remove the parameters from the signatures entirely.

---

### 2. Duplicate `roundToThreeDecimals` (vehiclemanager.lua + tuningpackmanager.lua)
Identical local function defined in two files (vehiclemanager.lua:7 and tuningpackmanager.lua:705). The copy in `tuningpackmanager.lua` is never needed externally; `vehiclemanager.lua` owns the real one and exposes it via `_internals` if needed.

**Fix:** Remove the duplicate from `tuningpackmanager.lua`. Since it's only used locally there, inline the calls via `VehicleManager`-style or just re-use the one already wired into `_internals` if exposed, or keep a single shared one. Simplest: remove the duplicate and use the existing one at the top of the file, or reuse from internals if accessible.

---

### 3. Duplicate `isFiniteNumber` (client.lua + surfacegrip.lua)
Same pure function defined independently in both files. `_internals.isFiniteNumber` is only wired by `runtimebindings.lua`, which loads after `surfacegrip.lua`, so `surfacegrip.lua` cannot safely reference it at module level. Both copies are 3-line pure functions.

**Decision:** Leave both as-is. The duplication is minimal and introducing a shared utils file would add more complexity than it eliminates.

---

### 4. Inline fallback `normalizeSteeringLockMode` in vehiclemanager.lua (lines 166–184)
`serializeTuneState()` has a full inline fallback implementation of `normalizeSteeringLockMode`, used only if `internals.normalizeSteeringLockMode` is not wired yet. But `runtimebindings.lua` always wires `internals.normalizeSteeringLockMode = tuningPackManager.normalizeSteeringLockMode` before any of these functions are called. The fallback is dead code and duplicates the canonical implementation in `tuningpackmanager.lua`.

**Fix:** Remove the inline fallback. Call `internals.normalizeSteeringLockMode` directly (it is guaranteed to exist at call time).

---

### 5. Redundant raw file read in `storeStableLapSample` handler (server.lua:289–295)
`loadStableLapDocument()` already exists and encapsulates the read + decode + fallback logic. The `storeStableLapSample` handler duplicates this pattern inline (lines 289–295) instead of calling the helper.

**Fix:** Replace the inline load with a call to `loadStableLapDocument()`.

---

### 6. Double-negative enabled check in `buildTireCompoundPackOptions` (tuningpackmanager.lua:278)
```lua
local enabled = not (type(pack) ~= 'table' or pack.enabled == false)
```
This is logically correct but hard to read. Equivalent positive form is:
```lua
local enabled = type(pack) == 'table' and pack.enabled ~= false
```

**Fix:** Rewrite without double negation.

---

### 7. Redundant `NITRO_PACKS` alias in runtimebindings.lua (line 110)
```lua
internals.NITRO_PACKS = internals.NITROUS_PACKS
```
`NITRO_PACKS` is an alias that exists purely for backward compatibility with nothing — no code in this resource references `internals.NITRO_PACKS`. `internals.NITROUS_PACKS` is the used name everywhere.

**Fix:** Remove the alias line.

---

## Execution Order

1. client.lua — remove unused parameters from `notifyDragRebalanceFinished` and `requestDragRebalance`
2. tuningpackmanager.lua — remove duplicate `roundToThreeDecimals`
3. surfacegrip.lua — remove duplicate `isFiniteNumber`, use `_internals` reference
4. vehiclemanager.lua — remove inline fallback `normalizeSteeringLockMode`
5. server.lua — use `loadStableLapDocument()` in `storeStableLapSample`
6. tuningpackmanager.lua — fix double-negative enabled check
7. runtimebindings.lua — remove `NITRO_PACKS` alias
