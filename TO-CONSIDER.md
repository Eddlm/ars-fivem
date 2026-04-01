I make sure to not lose track of the user/admin experience by regularly asking Codex to do sanity checks on features, gameplay, settings and overall experience. I keep its suggestions here, authored and adjusted by me.

# For `customcam`

Admin

- Keep only server-wide camera defaults that establish a common camera identity.
- Keep shared default follow/hood camera placement presets only if the server wants a common camera identity.

---

Player

- Allow the player to configure `customcam` clientside.
- Move `toggleHoldMs` to clientside preferences.
- Move virtual mirror on/off to clientside preferences, with an optional server default if needed.
- Add clientside preferences for virtual mirror on/off, mirror position/size, follow-camera distance/height preset, hood offset/tilt, and rear-look behavior.

---

Internal

- Trim the remaining `customcam` framing constants from server config and keep them hardcoded clientside.
- Keep camera smoothing, look-ahead logic, mirror polling/rendering constants, and attach/framing math hardcoded.

# For `customphysics`

Admin

- Keep wheelie enable/scope, rollover enable, offroad boost enable/max multiplier, fallback rev limiter, powerslide angle/max/speed threshold, and the surface drag map configurable.

---

Player

- Do not add player-specific config by default; this resource is gameplay-affecting and should stay server-authoritative.

---

Internal

- Keep wheelie force math, offroad ramp/fall rates, stabilization/controller details, and effect timing hardcoded.

# For `performancetuning`

Admin

- Keep pack behavior values, nitrous duration/power/refill rules, PI multipliers/classes, nearby PI panel enable, and the user-facing slider limits that define allowed tuning scope.
- Decide whether pack availability should remain globally configurable or become fixed content.

---

Player

- Add clientside preferences for menu keybind, PI panel visibility mode/default, panel placement/visual style, and any non-gameplay display preferences.
- Consider remembering the last-used menu state/open path as a local preference.

---

Internal

- Move pack metadata (`id`, `label`, `description`, `enabled`) out of shared config if the pack lineup is not meant to be server-edited.
- Decide whether `performancetuning` pack metadata should stay configurable or move into internal code/data.
- Move nearby PI panel range/count to internal defaults unless there is a strong admin use case for tuning HUD behavior.
- Keep UI copy, panel math constants, brake-scaling constants, normalization defaults, and menu helper text hardcoded.

# For `racingsystem`

Admin

- Keep checkpoint draw distance, marker type, checkpoint radius limits, lap count limits, countdown, and the “multiple owned races” policy configurable.

---

Player

- Add or consider clientside preferences for race menu keybind, menu placement, editor helper readability, and local race HUD verbosity only where they do not affect race logic.

---

Internal

- Keep file/folder names, resource plumbing, editor control IDs, snapshot/index persistence details, editor step size, and marker alignment internals hardcoded.

# For `vehiclemanager`

Admin

- Keep save ownership precedence configurable.
- Keep only shared menu availability/policy decisions, not local presentation details.

---

Player

- Add clientside preferences for menu keybind, menu position/alignment/theme, and any personal vehicle-manager UI behavior.

---

Internal

- Treat paint categories and mod-category visibility as internal by default, and only promote them to admin config if there is a real server-owner need to curate options.
- Decide whether `vehiclemanager` paint catalogs and category tables should remain in `shared.lua` or move into internal code/data.
- Keep menu copy, save directory/index naming, static color catalogs, livery/wheel label data, and category tables hardcoded unless there is a real server-owner need to customize them.

## Done

- Unified resource config entry points around `shared.lua`.
- Reduced the public config surface to more server-facing settings.
