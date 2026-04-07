# VehicleManager Refactoring Plan

## Overview
This is the progressive refactoring plan for vehiclemanager resource, addressing code duplication, naming clarity, architecture issues and integration with performancetuning.

---

## ✅ Refactoring Task Checklist

| # | Task | Priority | Status | Notes |
|---|---|---|---|---|
| **Phase 1 - Cleanup & Deduplication** |
| 1.1 | Rename all unclear method/variable names to consistent naming convention | HIGH | ✅ Done | All renames completed
| 1.2 | Extract all duplicated helper functions to top of file | HIGH | ☐ Not Done |
| 1.3 | Remove duplicate vehicle getter functions, standardize on one single implementation | HIGH | ✅ Done | getPlayerVehicle() / getDriverVehicle() / getManagedVehicle()
| 1.4 | Create generic state enumerator for doors/tyres/neons/proofs | MEDIUM | ✅ Done | iterateVehicleState() abstraction, cleaned up door/tyre state functions
| 1.5 | Merge duplicate map normalization functions | LOW | ✅ Done | normalizeSelectionMap() / normalizeTuningSelectionMap()
| 1.6 | Extract shared label fallback logic | LOW | ✅ Done |
| 1.7 | Standardize network state waiting loops | MEDIUM | ✅ Done | ensureVehicleNetworked() + waitForVehicleNetworkState()

| **Phase 2 - Architecture Improvements** |
|---|---|---|---|---|
| 2.1 | Split monolithic 2657 line file into logical modules | HIGH | ☐ Not Done |
| 2.2 | Add proper performancetuning dependency declaration in fxmanifest | MEDIUM | ☐ Not Done | Currently missing entirely
| 2.3 | Remove duplicate vehicle manager implementation from performancetuning | HIGH | ☐ Not Done | Two parallel implementations exist
| 2.4 | Establish official clear interface contract between resources | HIGH | ☐ Not Done |
| 2.5 | Move shared types & constants to shared.lua | MEDIUM | ☐ Not Done |

| **Phase 3 - Refinement & Quality** |
|---|---|---|---|---|
| 3.1 | Create shared library between both resources for common types | MEDIUM | ☐ Not Done |
| 3.2 | Standardize error handling patterns | LOW | ☐ Not Done |
| 3.3 | Add proper null/state guards | MEDIUM | ☐ Not Done |
| 3.4 | Document public API | LOW | ☐ Not Done |
| 3.5 | Add unit tests for utility functions | LOW | ☐ Not Done |

---

## ✅ Naming Standardization Plan

| Current Name | Proposed Name |
|---|---|
| `getManagedVehicle()` | `getCurrentVehicle()` |
| `normalizeSelectionMap()` | `cleanModSelectionMap()` |
| `ensureVehicleNetworked()` | `waitForVehicleOwnership()` |
| `buildColorLabels()` | `buildPaintColorOptionList()` |
| `getDisplayLabel()` | `getLocalizedModName()` |
| `getLabelOrFallback()` | `getSafeDisplayLabel()` |

---

## ✅ Integration Notes

✅ All current integration with performancetuning is properly implemented via exports with full safety wrapping
✅ No breaking changes required for existing functionality
✅ All refactoring can be done incrementally with zero downtime

---

*Last updated: 4/7/2026*