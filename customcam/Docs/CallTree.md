# CustomCam Resource Call Tree

**Purpose** – Custom follow/hood camera behavior with look-back and virtual mirror support.

---

## Entry Points
| File | Trigger | What it does |
|---|---|---|
| `fxmanifest.lua` | Resource load | Declares `shared.lua`, `client.lua`, and `UpdateNotifier.lua`. |
| `client.lua` | Client script load | Initializes camera state and starts runtime loops. Registers debug command. |
| `UpdateNotifier.lua` | `onResourceStart` + command | Runs delayed GitHub version check and exposes manual command. |

---

## Module Overview
| Module | Responsibility |
|---|---|
| `shared.lua` | Defines `CustomCam.Config` used by client logic. |
| `client.lua` | Camera activation/deactivation, follow update, virtual mirror update/draw, cleanup on resource stop. |
| `UpdateNotifier.lua` | Update check helper (`/ccamupdatecheck`). |

---

## Call Hierarchy (Simplified)

```text
fxmanifest.lua
│
├─ shared.lua
│   └─ CustomCam.Config
│
├─ client.lua
│   ├─ CreateThread: virtual mirror vehicle polling loop
│   ├─ CreateThread: main camera runtime loop (toggle/update/draw)
│   ├─ RegisterCommand(Config.Debug.command default "customcamdebug")
│   └─ AddEventHandler('onResourceStop') -> cleanupCamera()
│
└─ UpdateNotifier.lua
    ├─ RegisterCommand('ccamupdatecheck') -> performUpdateCheck()
    └─ AddEventHandler('onResourceStart') -> delayed performUpdateCheck()
```

---

## Key Runtime Flow
1. Resource starts and loads config + client runtime.
2. Player holds the configured camera control; main loop detects hold duration and toggles camera state.
3. While active, per-frame logic updates follow camera, disables conflicting controls, and draws mirror overlay.
4. Virtual-mirror polling loop maintains candidate vehicle tracking separately.
5. On resource stop, camera is always cleaned up.

---

## Accuracy Notes
- There is **no `/ccam` command** in current implementation.
- `client.lua` currently exposes **no `exports(...)` API**.
- Runtime has **two long-running client threads** (plus one delayed one-shot update-check thread in `UpdateNotifier.lua`).
