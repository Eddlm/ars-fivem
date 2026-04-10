# traffic_control Resource Call Tree

**Purpose** – Enforce ambient traffic and population behavior using numeric density requests and a default baseline profile.

---

## Entry Points
| File | Trigger | What it does |
|---|---|---|
| `fxmanifest.lua` | Resource load | Declares `client.lua`, `traffic_task.lua`, and `server.lua`. |
| `Config.lua` | Shared script load | Defines `TrafficControl.Config` defaults/profiles and server tunables. |
| `client.lua` | Client script load | Exposes compatibility alias `TrafficControlConfig` from `TrafficControl.Config`. |
| `traffic_task.lua` | Client script load | Initializes traffic state, registers event/exports, starts enforcement threads. |
| `server.lua` | Server script load | Registers `/trafficserver` command and server exports that emit client requests. |

---

## Module Overview
| Module | Responsibility |
|---|---|
| `Config.lua` | Static config table for modes/profiles/server tunables. |
| `client.lua` | Compatibility alias setup for config table access. |
| `traffic_task.lua` | Request resolution, profile building, event handling, per-frame density enforcement. |
| `server.lua` | Server-side request routing via command and exports. |

---

## Call Hierarchy (Simplified)

```text
fxmanifest.lua
│
├─ Config.lua
│   └─ TrafficControl.Config
│
├─ client.lua
│   └─ TrafficControlConfig compatibility alias
│
├─ traffic_task.lua
│   ├─ RegisterNetEvent('traffic_control:setMode')
│   │   └─ applyMode(...) or setMultiplier(...)
│   │       └─ updateActiveState() -> applyPersistentControls(...)
│   ├─ exports('SetTrafficMode')
│   ├─ exports('SetTrafficDensity')
│   ├─ exports('GetTrafficState')
│   ├─ AddEventHandler('populationPedCreating') -> CancelEvent() when blockPopulationPeds=true
│   ├─ CreateThread: default mode + per-frame density natives
│   └─ CreateThread: periodic persistent native controls
│
└─ server.lua
    ├─ RegisterCommand('trafficserver')
    │   ├─ parseModeOrDensity(...)
    │   ├─ emitTrafficRequest(...)
    │   └─ clearTrafficRequest(...)
    ├─ exports('SetServerTrafficMode') -> emitTrafficRequest(...)
    ├─ exports('SetServerTrafficDensity') -> emitTrafficRequest(...)
    └─ exports('ClearServerTrafficRequest') -> clearTrafficRequest(...)
```

---

## Key Runtime Flow
1. `traffic_task.lua` applies configured default mode (`normal` by default) on client start.
2. Server/admin or other resources emit mode/density requests.
3. Client stores request by key, picks the newest active explicit request, and updates `trafficState`.
4. If no explicit requests remain, client falls back to the configured default profile (dormant baseline).
5. Per-frame thread applies density multipliers.
6. 1-second thread reapplies persistent controls (boats/cops/garbage/parked count).
7. Population ped creation can be blocked per profile.

---

## Accuracy Notes
- Active execution is client-side; server acts as broadcaster/orchestrator.
- Request ownership uses keys (resource or explicit request key) so multiple request sources can coexist.
- Runtime currently does not emit routine console debug prints for command/apply flow.
