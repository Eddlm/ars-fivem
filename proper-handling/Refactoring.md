# Refactoring Plan: proper-handling

## Current Footprint Snapshot
- Resource size is ~2.35 MB total, overwhelmingly from `.meta` handling files (~2.34 MB).
- `Active/handling_basegame.meta` alone is ~1.83 MB; additional large active/inactive handling packs are present.
- Runtime script footprint is minimal (`fxmanifest.lua` + `server/UpdateNotifier.lua`), so filesize reduction is primarily data-file focused.

## Primary Filesize Reduction Opportunities
1. **Move non-runtime handling datasets out of loaded scope** (especially inactive archives) so only required packs ship with resource runtime payload.
2. **Split oversized handling packs by vehicle class/pack role** to avoid monolithic updates and reduce active manifest glob breadth.
3. **Deduplicate repeated handling entries/values across active and inactive packs** through canonical source sets.
4. **Consolidate naming/version strategy for handling files** to prevent duplicate “variant” files that differ only minimally.
5. **Establish generation pipeline from canonical data source** to reduce manual copy-forward duplication in `.meta` files.

## Step-by-Step Refactoring Plan
1. **Classify all handling files into runtime-required vs archive-only**
   - **Objective:** Create a strict boundary for files that must be loaded by the server.
   - **Files/areas impacted:** `Active/*.meta`, `Inactive/*.meta`, manifest loading pattern.
   - **Rationale for filesize reduction:** Excluding archive-only files from runtime distribution avoids shipping unnecessary data.
   - **Risk/validation notes:** Validate that all required vehicles still resolve handling entries after classification.

2. **Replace broad glob loading with curated active list strategy**
   - **Objective:** Ensure only intentional active packs are included as `HANDLING_FILE` entries.
   - **Files/areas impacted:** `fxmanifest.lua`, `Active/` file inventory.
   - **Rationale for filesize reduction:** Prevents accidental inclusion of experimental or transitional files.
   - **Risk/validation notes:** Run startup checks for missing handling references and fallback behavior.

3. **Refactor monolithic `handling_basegame.meta` into domain shards**
   - **Objective:** Split by categories (e.g., classes, DLC groups, purpose) while preserving load semantics.
   - **Files/areas impacted:** `Active/handling_basegame.meta`, new structured active meta files.
   - **Rationale for filesize reduction:** Facilitates selective retention and easier elimination of duplicate blocks.
   - **Risk/validation notes:** Confirm data_file load order and override precedence remains correct.

4. **Deduplicate repeated handling blocks and constants**
   - **Objective:** Remove copied sections across `Active/` and `Inactive/` where values are identical or near-identical.
   - **Files/areas impacted:** All `.meta` files in `Active/` and `Inactive/`.
   - **Rationale for filesize reduction:** Directly cuts duplicated XML content bytes.
   - **Risk/validation notes:** Validate vehicle-specific tuning intent is preserved for intentional exceptions.

5. **Normalize variant naming and version policy**
   - **Objective:** Replace ad-hoc variant files with clear naming and a single canonical source per tuning family.
   - **Files/areas impacted:** `Active/*.meta`, `Inactive/*.meta`, project docs.
   - **Rationale for filesize reduction:** Prevents growth of near-duplicate files over time.
   - **Risk/validation notes:** Track migration mapping so legacy references are not lost during reorganization.

6. **Adopt generated output workflow for handling packs**
   - **Objective:** Maintain one canonical editable dataset and produce final `.meta` files through generation.
   - **Files/areas impacted:** Authoring workflow/docs and output `.meta` artifacts.
   - **Rationale for filesize reduction:** Systematic generation discourages copy/paste duplication and stale forks.
   - **Risk/validation notes:** Validate generated output equality against baseline before rollout.

7. **Standardize notifier file strategy with other resources**
   - **Objective:** Align `server/UpdateNotifier.lua` with shared cross-resource pattern.
   - **Files/areas impacted:** `server/UpdateNotifier.lua` and internal shared standard.
   - **Rationale for filesize reduction:** Reduces duplicated boilerplate maintenance across resource set.
   - **Risk/validation notes:** Keep update-check behavior unchanged.

## Quick Wins
- Remove archive-only files from runtime shipping scope.
- Split the largest active handling file into smaller targeted shards.
- Eliminate exact duplicate handling sections between active/inactive variants.

## Longer-Term Improvements
- Build tooling to diff handling entries and auto-detect duplicates/conflicts.
- Add a validation gate that blocks new duplicate entries in PR/workflow.
- Keep a compressed external archive for inactive variants outside runtime resource path.

## Scope Note
No files were modified other than this planning document.

