# racingsystem — Code Improvement Plan

## 1. Clarity Improvements

### 1a. Variable Renames

**server.lua**

| File | Current Name | Suggested Name | Reason |
|---|---|---|---|
| server.lua | `nextEntrantToken` | `nextEntrantIdToken` | Clarifies the token is part of an entrant ID |
| server.lua | `startupSnapshot` (line 3500) | `startupInfo` | It's only used for a log line, never sent as a snapshot |
| server.lua | `log(...)` alias (line 64) | Remove; call `logVerbose()` directly | `log` is just a wrapper for `logVerbose` — the alias hides what level is being used |

**client.lua**

| File | Current Name | Suggested Name | Reason |
|---|---|---|---|
| client.lua | `var1`, `var2` in `GetPropSpeedModificationParameters` | `speedTarget`, `durationTarget` | Meaningless names for speed limit and duration values |
| client.lua | `raceCountdownLocalEndByInstanceId` | `countdownEndTimeByInstanceId` | More directly describes what it stores |
| client.lua | `raceCountdownReportedZeroByInstanceId` | `countdownZeroReportedByInstanceId` | Consistent phrasing with its pair |
| client.lua | `latestSnapshotAcceptedAt` | `snapshotAcceptedAt` | `latest` is implicit since it's a scalar |
| client.lua | `lastSnapshotRequestAt` | `snapshotRequestedAt` | Consistent tense with accepted-at |
| client.lua | `clientReliabilityCounters` | `reliabilityCounters` | Mirrors the server variable name; no ambiguity since this is already in client.lua |
| client.lua | `joinTeleportInProgress` | `isTeleportInProgress` | Boolean naming convention |
| client.lua | `gtaoRaceUrlPromptOpen` | `isGTAORacePromptOpen` | Boolean naming convention |
| client.lua | `appliedTrafficMode` | `currentTrafficMode` | "Applied" is ambiguous; "current" is clearer |
| client.lua | `CHECKPOINT_PASS_RELEASE_DELTA` | `CHECKPOINT_PASS_RELEASE_THRESHOLD` | Delta implies a difference value; threshold is the intent |

**menu.lua**

| File | Current Name | Suggested Name | Reason |
|---|---|---|---|
| menu.lua | `raceMenuPendingSelectName` | `pendingSelectRaceName` | Remove redundant `raceMenu` prefix — already in menu context |
| menu.lua | `raceMenuPendingEditorName` | `pendingEditorRaceName` | Same |
| menu.lua | `raceMenuDeleteConfirmName` | `deleteConfirmRaceName` | Same |

---

### 1b. Function Clarity

**server.lua**

- **`log()` (line 64–66):** This is a pass-through alias for `logVerbose()`. Replace all `log(...)` calls with `logVerbose(...)` and delete the alias. Callers should be explicit about the log level they're using.

- **`getRaceStartCheckpoint(instance)` (line 657):** Always returns `1` and never uses its argument. Either inline the literal `1` everywhere this is called, or add a comment explaining why the argument is kept for future flexibility.

- **`getLapTriggerCheckpoint(instance, totalCheckpoints, totalLaps)` (line 661):** The `instance` argument is never used. Consider removing it from the signature.

- **`emitStableLapTimeIfReady()` (line 2834):** The function immediately returns and is described as "intentionally disabled." Consider deleting the function body entirely and leaving a clearly marked stub, or removing the function and its two call sites.

- **`buildSavedRaceSnapshot()` (line 1356):** Only used in the `requestEditorRace` response to return a fake idle race shell. Rename to `buildEditorRacePayload()` to clarify its purpose.

**client.lua**

- **`ensureEditorActive()` (line 513):** The name implies a side effect (ensuring something happens), but the function just returns a boolean with no side effects. Rename to `isEditorActive()`.

- **`clearPredictedRaceProgress` (line 1529) — indentation bug:** The `raceRuntimeState.predictedProgress = nil` on line 1536 is not indented inside the `if` block on line 1535. Lua ignores whitespace but this reads as if the nil-assignment is unconditional. Fix the indentation.

  ```lua
  -- Current (misleading):
  if instanceId == nil or tonumber(predicted.instanceId) == tonumber(instanceId) then
  raceRuntimeState.predictedProgress = nil
  end
  
  -- Fixed:
  if instanceId == nil or tonumber(predicted.instanceId) == tonumber(instanceId) then
      raceRuntimeState.predictedProgress = nil
  end
  ```

- **`resolveLocalEntrantEntry()` vs `getLocalEntrant()`:** These are two functions where one wraps the other and adds entrantId caching. This is fine but should be commented to explain the distinction.

- **Global functions (`getJoinedRaceInstance`, `endEditorSession`, `addCheckpointAtPlayer`, etc.):** These are intentionally global so menu.lua can access them. Add a short comment at each declaration to indicate that global access is intentional.

---

### 1c. Event Registration Misclassification

The following events are triggered **only client-to-client** via `TriggerEvent(...)`. They are registered with `RegisterNetEvent`, which is unnecessary and misleading — it implies the server might send them. Change to `AddEventHandler`:

| Event | File | Notes |
|---|---|---|
| `racingsystem:resetToLastCheckpoint` | client.lua line 2234 | Menu → client local event. All data resolved from snapshot. |
| `racingsystem:startRace` | client.lua line 2263 | Menu → client → then `TriggerServerEvent`. Pre-validation is UX-only. |
| `racingsystem:leaveRace` | client.lua line 2300 | Menu → client → then `TriggerServerEvent`. Local cleanup first. |
| `racingsystem:smartCheckpointTeleport` | client.lua line 2327 | Pure client teleport event. |

---

### 1d. Bug: `editorSessionActive` Reference in menu.lua

`getMenuPlayerState()` (menu.lua line 39) checks `editorSessionActive`, but this variable is **never defined** anywhere. The intended check is `editorState.active`. Because `editorSessionActive` is nil/falsy, the editor state is never detected in the menu's state machine — the menu shows 'neutral' instead of 'editing' while editing.

**Fix:** Replace `editorSessionActive` with `editorState.active` on line 39 of menu.lua.

---

## 2. Client-Server Communication Audit

### 2a. Correctly Server-Authoritative (no changes needed)

The following events correctly require server involvement and should remain as-is:

- `racingsystem:checkpointPassed` — server validates order, updates entrant state, broadcasts
- `racingsystem:startRace` → server — server enforces owner, state, and entrant count
- `racingsystem:invokeRace` — server loads race files and allocates instances
- `racingsystem:joinRace` / `racingsystem:joinRaceInstanceById` — server manages entrant lists and handles mid-race join logic
- `racingsystem:leaveRace` → server — server removes entrant and destroys empty instances
- `racingsystem:saveEditorRace` — server does disk I/O (SaveResourceFile)
- `racingsystem:requestEditorRace` — server reads from disk (LoadResourceFile)
- `racingsystem:registerRaceDefinition` — server-side index and disk
- `racingsystem:deleteRaceDefinition` — admin-gated, server does file deletion
- `racingsystem:validateGTAORaceUGCId` — server fetches external URLs (PerformHttpRequest)
- `racingsystem:killRace` — admin/owner gated, server-side authority

### 2b. Redundant Snapshot Requests (remove these)

The server **already calls `broadcastSnapshot()`** at the end of every mutating event handler. Several client-side response handlers additionally call `requestRaceStateSnapshot()`, causing the client to receive the same state twice.

**Remove `requestRaceStateSnapshot()` from the following client-side handlers:**

| Handler | File:Line | Reason |
|---|---|---|
| `racingsystem:editorRaceSaved` | client.lua line 2414 | Server broadcasts on save (server.lua line 3068) |
| `racingsystem:raceDefinitionRegistered` | client.lua line 2426 | Server broadcasts on register (server.lua line 3096) |
| `racingsystem:raceDefinitionDeleted` | client.lua line 2444 | Server broadcasts on delete (server.lua line 3191) |

In all three cases, the `broadcastSnapshot()` on the server side will reach the client with the updated state. The explicit request is redundant and wastes a network round-trip.

### 2c. Correctly Client-Side (no changes needed)

The following are correctly handled client-side using data already in `latestSnapshot`:

- **Checkpoint detection loop** (client.lua lines 2837–3083): Client detects the pass, calculates penalties locally, then reports to server. Server validates order only. Correct design.
- **Traffic mode application** (`applyJoinedInstanceTrafficMode`): Reads from snapshot, fires local `traffic_control:setMode`. No server needed.
- **Leaderboard display** (`buildLiveLeaderboardRows`): Reads from snapshot entrant list. No server needed.
- **Countdown display**: Client tracks countdown end time locally from `racingsystem:startCountdown` payload. No server polling needed.
- **No-collision between racers**: Applied each frame from snapshot's entrant list. No server needed.
- **Asset loading** (`loadInstanceAssets`): Client loads props from cached `instanceAssetCache`. Assets are sent once per join by server — correctly one-time.

---

## 3. Exports Audit

No `exports[]` are defined in [fxmanifest.lua](fxmanifest.lua). The resource does not expose a public API to other resources. Global functions used across files:

- `getJoinedRaceInstance()` — used in menu.lua
- `getOwnedRaceInstance()` — used in menu.lua (indirectly via state checks)
- `endEditorSession()`, `addCheckpointAtPlayer()` — called by menu.lua
- `refreshEditorMenu()`, `buildMenuState()` — defined in menu.lua, called in client.lua
- `beginEditorSessionUI()`, `endEditorSessionUI()` — defined in menu.lua, called in client.lua
- `isRaceMenuVisible()`, `refreshRaceMenu()` — defined in menu.lua, referenced in client.lua

These cross-file globals work because all client scripts are loaded in the same Lua context. No exports are needed. Consider adding a comment block near each global listing which file accesses it.

---

## 4. Priority Summary

| Priority | Item | Type |
|---|---|---|
| Bug | `editorSessionActive` → `editorState.active` in menu.lua | Fix |
| Bug | Indentation in `clearPredictedRaceProgress` | Fix |
| Improvement | Remove redundant `requestRaceStateSnapshot()` calls (×3) | Network |
| Improvement | `RegisterNetEvent` → `AddEventHandler` for 4 local events | Clarity |
| Improvement | Remove `log()` alias; use `logVerbose()` directly | Clarity |
| Rename | `ensureEditorActive` → `isEditorActive` | Clarity |
| Rename | `var1`/`var2` → `speedTarget`/`durationTarget` | Clarity |
| Rename | Traffic/countdown/teleport boolean variables | Clarity |
| Rename | `raceMenu*` globals in menu.lua | Clarity |
| Documentation | Comment global functions explaining cross-file access | Clarity |
