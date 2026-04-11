# CustomCam Resource Call Tree

**Purpose** – Custom vehicle camera behavior with follow/hood modes, look-back support, virtual mirror rendering, and a separate update checker.

---

## Entry Points
| File | Trigger | What it does |
|---|---|---|
| `fxmanifest.lua` | Resource load | Declares `Config.lua`, `client/client.lua`, and `UpdateNotifier.lua`. |
| `client/client.lua` | Client script load | Initializes camera state, validates config, and starts the runtime loops. |
| `UpdateNotifier.lua` | `onResourceStart` + command | Runs delayed GitHub version check and exposes manual command. |

---

## Module Overview
| Module | Responsibility |
|---|---|
| `Config.lua` | Defines `CustomCam.Config` used by client logic. |
| `client/client.lua` | Camera activation/deactivation, follow update, virtual mirror update/draw, cleanup on resource stop. |
| `UpdateNotifier.lua` | Update check helper (`/ccamupdatecheck`). |

---

## Call Hierarchy (Simplified)

```text
fxmanifest.lua
│
├─ Config.lua
│   └─ CustomCam.Config
│
├─ client/client.lua
│   ├─ validateConfig()
│   ├─ CreateThread: virtual mirror vehicle polling loop
│   ├─ CreateThread: main camera runtime loop (toggle/update/draw)
│   └─ AddEventHandler('onResourceStop') -> cleanupCamera()
│
└─ UpdateNotifier.lua
    ├─ RegisterCommand('ccamupdatecheck') -> performUpdateCheck()
    └─ AddEventHandler('onResourceStart') -> CreateThread -> delayed performUpdateCheck()
```

---

## Key Runtime Flow
1. Resource starts and loads shared config, client runtime, and the server-side update checker.
2. `client/client.lua` validates the config, then waits for the player to hold the configured toggle control long enough to switch the custom camera on or off.
3. When active, the main client loop keeps the follow camera or hood camera updated, disables conflicting controls, and draws the mirror overlay.
4. The virtual-mirror polling loop runs independently to maintain the tracked vehicle set used by the overlay.
5. `UpdateNotifier.lua` optionally checks the upstream version at startup and also responds to `/ccamupdatecheck`.
6. On resource stop, the active scripted camera is always cleaned up.

---

## Accuracy Notes
- There is **no `/ccam` command** in current implementation.
- `client/client.lua` currently exposes **no `exports(...)` API**.
- Runtime has **two long-running client threads** (plus one delayed one-shot update-check thread in `UpdateNotifier.lua`).
- Debug/config warning logging in `client.lua` is intentionally silent (`warnConfig` does not print).
