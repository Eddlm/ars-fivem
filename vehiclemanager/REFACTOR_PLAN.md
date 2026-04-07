# VehicleManager Refactoring Plan

## Overview
This is the progressive refactoring plan for vehiclemanager resource, addressing code duplication, naming clarity, architecture issues and integration with performancetuning.

---

## ✅ Completed Tasks
All Phase 1 Cleanup & Deduplication tasks are now complete:

✅ **1.1** Rename all unclear method/variable names to consistent naming convention
✅ **1.2** Extract all duplicated helper functions to top of file
✅ **1.3** Remove duplicate vehicle getter functions, standardize on one single implementation
✅ **1.4** Create generic state enumerator for doors/tyres/neons/proofs
✅ **1.5** Merge duplicate map normalization functions
✅ **1.6** Extract shared label fallback logic
✅ **1.7** Standardize network state waiting loops

---

## ☐ Pending Tasks

### Phase 2 - Architecture Improvements
| # | Task | Priority | Status | Notes |
|---|---|---|---|---|
| 2.1 | Split monolithic 2657 line file into logical modules | HIGH | ☐ Not Done |
| 2.2 | Add proper performancetuning dependency declaration in fxmanifest | MEDIUM | ☐ Not Done | Currently missing entirely
| 2.3 | Remove duplicate vehicle manager implementation from performancetuning | HIGH | ☐ Not Done | Two parallel implementations exist
| 2.4 | Establish official clear interface contract between resources | HIGH | ☐ Not Done |
| 2.5 | Move shared types & constants to shared.lua | MEDIUM | ✅ Done | Color tables already in shared.lua, duplicates removed from client

### Phase 3 - Refinement & Quality
| # | Task | Priority | Status | Notes |
|---|---|---|---|---|
| 3.1 | Create shared library between both resources for common types | MEDIUM | ☐ Not Done |
| 3.2 | Standardize error handling patterns | LOW | ☐ Not Done |
| 3.3 | Add proper null/state guards | MEDIUM | ☐ Not Done |
| 3.4 | Document public API | LOW | ☐ Not Done |
| 3.5 | Add unit tests for utility functions | LOW | ☐ Not Done |

### Optimization / Dead Code Removal
| # | Task | Lines | Status | Notes |
|---|---|---|---|---|
| **1.** | Remove empty VMUI stub methods | 8 | ✅ Done |
| **2.** | Remove debug placeholder commented code blocks | 47 | ✅ Done | Already clean, no comment blocks found
| **3.** | Remove v0 -> v1 save format migration code | 62 | ☐ Not Done | Ran once, will never execute again
| **4.** | Remove unused dead network event handlers | 21 | ☐ Not Done | Old events no longer sent by server

---

## ✅ Naming Standardization Plan

All naming standardization items are complete.

---

## ✅ Integration Notes

✅ All current integration with performancetuning is properly implemented via exports with full safety wrapping
✅ No breaking changes required for existing functionality
✅ All refactoring can be done incrementally with zero downtime

---

*Last updated: 4/7/2026*