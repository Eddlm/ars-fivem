# CustomPhysics Resource Call Tree

**Purpose** – Client-side vehicle physics helpers (power, wheelies, rollovers, nitrous) with coordinated per-frame updates.

---

## Entry Points
| File | Trigger | What it does |
|---|---|---|
| `fxmanifest.lua` | Resource load | Loads `Config.lua`, subsystem modules, client orchestrator, and update notifier. |
| `client.lua` | Client script load | Starts stability sampler + per-frame coordinator threads; handles cleanup on stop. |
| `nitrous.lua` | Client script load | Registers local event handlers for nitrous shot execute/clear events. |
| `UpdateNotifier.lua` | `onResourceStart` + command | Delayed/manual update checking. |

---

## Module Overview
| Module | Responsibility |
|---|---|
| `Config.lua` | Defines `CustomPhysics.Config`. |
| `util.lua` | Shared math/geometry helpers. |
| `power.lua` | Acceleration stability, anti-boost, rev/fallback related updates. |
| `wheelies.lua` | Wheelie detection/control updates. |
| `rollovers.lua` | Rollover behavior updates/corrections. |
| `nitrous.lua` | Nitrous shot lifecycle + local event integration. |
| `client.lua` | Vehicle discovery + subsystem orchestration. |
| `UpdateNotifier.lua` | GitHub version check command + startup delayed check. |

---

## Call Hierarchy (Simplified)

```text
fxmanifest.lua
│
├─ Config.lua -> CustomPhysics.Config
├─ util.lua
├─ wheelies.lua / rollovers.lua / power.lua / nitrous.lua
│   └─ nitrous.lua AddEventHandler('customphysics:nitrous:executeShot'|'customphysics:nitrous:clear')
│
├─ client.lua
│   ├─ CreateThread: stability sampler (100ms) -> CustomPhysicsPower.sampleStability()
│   ├─ CreateThread: per-frame coordinator -> Rollovers.update(), Wheelies.update(), Power.update(), Nitrous.update()
│   └─ AddEventHandler('onResourceStop') -> clearOverrides(lastVehicle)
│
└─ UpdateNotifier.lua
    ├─ RegisterCommand('cphysicsupdatecheck') -> performUpdateCheck()
    └─ AddEventHandler('onResourceStart') -> delayed performUpdateCheck()
```

---

## Key Runtime Flow
1. Client orchestrator resolves the current driven vehicle each frame.
2. If vehicle changed, previous vehicle overrides are reset.
3. Subsystems run in fixed order each frame: rollovers → wheelies → power → nitrous.
4. A second loop samples stability every 100ms for power calculations.
5. On player exit or resource stop, cleanup path reverts active overrides.

---

## Accuracy Notes
- Update-check command name is **`/cphysicsupdatecheck`** (not `/cpupdatecheck`).
- There is **no exported API** from this resource.
