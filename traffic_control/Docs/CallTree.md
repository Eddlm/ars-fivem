# traffic_control Resource Call Tree

**Purpose** – Enforce ambient traffic density using keyed numeric requests and lowest-value priority.

---

## Entry Points
| File | Trigger | What it does |
|---|---|---|
| `fxmanifest.lua` | Resource load | Declares `shared/Config.lua`, `client/traffic_task.lua`, and `server/server.lua`. |
| `shared/Config.lua` | Shared script load | Defines `TrafficControl.Config` server/update-check tunables. |
| `client/traffic_task.lua` | Client script load | Maintains local keyed state and applies per-frame density natives. |
| `server/server.lua` | Server script load | Accepts request events and routes them to client runtime via broadcast/targeted events. |

---

## Module Overview
| Module | Responsibility |
|---|---|
| `shared/Config.lua` | Static config table for server prefix and update checker options. |
| `client/traffic_task.lua` | Keyed request ingestion, lowest-request selection, default fallback resolution, per-frame density enforcement. |
| `server/server.lua` | Server-side request routing via the `requestDensity` event (`nil` clears). |

---

## Call Hierarchy (Simplified)

```text
fxmanifest.lua
│
├─ shared/Config.lua
│   └─ TrafficControl.Config
│
├─ client/traffic_task.lua
│   ├─ RegisterNetEvent('traffic_control:setMode')
│   │   └─ applyTrafficRequest(...)
│   │       └─ rebuildState() [lowest request or numeric default or idle]
│   └─ CreateThread: per-frame density natives (only when effective density is numeric)
│
└─ server/server.lua
    ├─ RegisterNetEvent('traffic_control:requestDensity')
    │   └─ emitDensityRequest(...) [numeric sets, nil clears]
```

---

## Key Runtime Flow
1. Scripts send request events to server (`traffic_control:requestDensity`).
2. Server builds request keys and routes traffic updates:
   - client-origin requests target only that client,
   - server-origin requests broadcast to all clients.
3. Client runtime stores each key with a numeric value, or clears key when `density=nil`.
4. Client picks the lowest active keyed value as effective density.
5. If no keys are active, client reads `tControlDefault` and uses it only if numeric.
6. If both request set and default are invalid/empty, client stays idle.
7. Per-frame thread applies traffic multipliers only when effective density is numeric.

---

## Accuracy Notes
- Active execution is client-side; server acts as broadcaster/orchestrator.
- Request ownership uses keys (resource fallback or explicit request key) so multiple request sources can coexist safely.
- Request conflict policy is deterministic: lowest numeric request always wins.
