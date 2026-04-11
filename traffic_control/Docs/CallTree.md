# traffic_control Resource Call Tree

**Purpose** – Enforce ambient traffic and population behavior using numeric density requests and a default baseline profile.

---

## Entry Points
| File | Trigger | What it does |
|---|---|---|
| `fxmanifest.lua` | Resource load | Declares `shared/Config.lua`, `client/client.lua`, `client/traffic_task.lua`, and `server/server.lua`. |
| `shared/Config.lua` | Shared script load | Defines `TrafficControl.Config` defaults/profiles and server tunables. |
| `client/client.lua` | Client script load | Exposes compatibility alias `TrafficControlConfig` from `TrafficControl.Config`. |
| `client/traffic_task.lua` | Client script load | Initializes traffic state, registers event/exports, starts enforcement threads. |
| `server/server.lua` | Server script load | Exposes server exports that emit client requests. |

---

## Module Overview
| Module | Responsibility |
|---|---|
| `shared/Config.lua` | Static config table for modes/profiles/server tunables. |
| `client/client.lua` | Compatibility alias setup for config table access. |
| `client/traffic_task.lua` | Request resolution, profile building, event handling, per-frame density enforcement. |
| `server/server.lua` | Server-side request routing via exports. |

---

## Call Hierarchy (Simplified)

```text
fxmanifest.lua
│
├─ shared/Config.lua
│   └─ TrafficControl.Config
│
├─ client/client.lua
│   └─ TrafficControlConfig compatibility alias
│
├─ client/traffic_task.lua
│   ├─ RegisterNetEvent('traffic_control:setMode')
│   │   └─ setMultiplier(...) / applyDensity(...)
│   │       └─ updateActiveState() -> applyPersistentControls(...)
│   ├─ exports('SetTrafficMode')
│   ├─ exports('SetTrafficDensity')
│   ├─ exports('GetTrafficState')
│   ├─ AddEventHandler('populationPedCreating') -> CancelEvent() when blockPopulationPeds=true
│   ├─ CreateThread: default mode + per-frame density natives
│   └─ CreateThread: periodic persistent native controls
│
└─ server/server.lua
    ├─ exports('SetServerTrafficMode') -> emitTrafficRequest(...)
    ├─ exports('SetServerTrafficDensity') -> emitTrafficRequest(...)
    └─ exports('ClearServerTrafficRequest') -> clearTrafficRequest(...)
```

---

## Key Runtime Flow
1. `traffic_task.lua` applies configured default mode (`normal` by default) on client start.
2. Server or other resources emit mode/density requests through server exports.
3. Client stores request by key, picks the newest active explicit request, and updates `trafficState`.
4. If no explicit requests remain, client falls back to the configured default profile (dormant baseline).
5. Per-frame thread applies density multipliers.
6. 1-second thread reapplies persistent controls (boats/cops/garbage/parked count).
7. Population ped creation can be blocked per profile.

---

## Accuracy Notes
- Active execution is client-side; server acts as broadcaster/orchestrator.
- Request ownership uses keys (resource or explicit request key) so multiple request sources can coexist.
- Runtime currently does not emit routine console debug prints for request flow.
