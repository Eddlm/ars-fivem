# Virtual Mirror

The virtual mirror is a screen-top HUD overlay that shows a **bird's-eye rear-view** of nearby vehicles as pairs of dots, simulating the left and right headlights (or taillights) of each vehicle. It only renders when the custom camera is active and the player is driving.

## How It Works

### Rendering Pipeline

Every frame while the custom camera is active:

1. **Poll nearby vehicles** using a round-robin spread over frames (see _Vehicle Polling_ below).
2. **Project** each tracked vehicle's light anchor position into the mirror's FOV.
3. **Draw** a semi-transparent rectangular overlay (frame + fill) at a fixed position on screen.
4. **Draw dots** for each vehicle that falls within the mirror's horizontal and vertical FOV.

### Mirror Overlay Layout

```
┌─────────────────────────────────────────────────┐  ← frame (dark, semi-opaque)
│  ┌─────────────────────────────────────────────┐│
│  │      ·  ·          ··        ·  ·           ││  ← fill (blue-grey, translucent)
│  │   ·  ·       ·  ·            ·  ·     ·  · ││  ← vehicle dots (yellow = facing you, red = rear lights)
│  └─────────────────────────────────────────────┘│
└─────────────────────────────────────────────────┘
```

| Parameter                               | Default                     | Description                                |
| --------------------------------------- | --------------------------- | ------------------------------------------ |
| `centerXNormalized`                     | `0.5`                       | Horizontal centre on screen (0–1).         |
| `centerYNormalized`                     | `0.08`                      | Vertical centre on screen (0–1, near top). |
| `widthNormalized`                       | `0.315`                     | Full width of the mirror including frame.  |
| `heightNormalized`                      | `0.08`                      | Full height of the mirror including frame. |
| `virtualMirrorFrameThicknessNormalized` | `0.006`                     | Border thickness in screen-ratio units.    |
| `virtualMirrorFrameColor`               | `{r=20, g=20, b=20, a=230}` | RGBA colour of the outer frame rectangle.  |
| `virtualMirrorFillColor`                | `{r=65, g=75, b=90, a=120}` | RGBA colour of the inner fill rectangle.   |

### Vehicle Polling

Scanning all vehicles every frame would be expensive, so the mirror uses a **round-robin** approach:

1. On first frame or when the queue is empty, build a list of all vehicles in the `CVehicle` pool (excluding the player's vehicle).
2. Each frame, process a budgeted number of vehicles (`checksPerSecond`, default 100, spread with delta-time accumulation).
3. For each vehicle checked:
   - Compute 2D distance from the player.
   - If within `virtualMirrorVehiclePollRadiusMeters` (default 200 m) **and** behind the player (negative longitudinal dot product), mark it as tracked.
   - Otherwise, remove it from tracking.
4. After polling, sort tracked vehicles by distance and keep up to `virtualMirrorMaxTrackedVehicles` (default 24).

### Dot Projection

Each tracked vehicle's **light anchor** (average of headlight or taillight bone positions) is projected into the mirror's field of view:

**FOV projection:**

- `virtualMirrorHorizontalFovDegrees` (default 90°) — horizontal angular range of the mirror.
- `verticalFovDegrees` (default 15°) — vertical angular range.
- `trackingHorizontalPaddingDegrees` (default 90°) — extra horizontal padding so dots at the edges aren't clipped.

**Separation (headlight pair spacing):**

- Dots are drawn as pairs spaced by `scaledPairSeparation`, which starts at the mirror's inner width and shrinks with a falloff power (`dotSeparationFalloffExponent`, default 22.0) based on distance.
- Nearby vehicles have wider pair spacing, far vehicles have narrower pairs.

**Dot size:**

- `virtualMirrorDotSizeNormalized` (default 0.007) — base dot size in screen-ratio units.
- `virtualMirrorDotSizeNearMultiplier` (default 7.5) — size multiplier at zero distance (close vehicles are bigger).
- `virtualMirrorDotScaleExponent` (default 4.0) — power curve that shrinks dots as distance increases.
- `virtualMirrorDotWidthScale` (default 0.65) — width-to-height ratio of each dot.

**Colours:**
| Situation | Colour | Default RGBA |
|---|---|---|
| Vehicle facing you (headlights) | `dotColor` | `{255, 220, 80, 235}` — warm yellow |
| Vehicle showing rear (taillights) | `dotRearColor` | `{255, 70, 60, 235}` — red |

**Sprite vs Rectangle:**

- If the texture dict `mpinventory` / `in_world_circle` is loaded (`HasStreamedTextureDictLoaded`), dots are drawn as circular sprites via `DrawSprite`.
- Otherwise, they fall back to `DrawRect` squares.

**Clipping:**

- Dots that extend outside the inner fill bounds are culled.
- `virtualMirrorDotClipPaddingPixels` (default 4 px) provides a small grace zone so dots at the very edge still render.

### Occlusion

Dots are drawn front-to-back (nearest first). Each drawn pair registers its screen bounds, and subsequent dots that fall inside an already-drawn pair's bounds are skipped to prevent overlap.

## Disabling the Mirror

Set `Config.VirtualMirror.enabled = false` in `Config.lua`. The polling thread will throttle to 250 ms intervals and all tracking state is cleared.

## Parameters

See [configuration.md](configuration.md) → _Virtual Mirror_ and _Advanced Tuning → Mirror_ sections for every tuneable value.
