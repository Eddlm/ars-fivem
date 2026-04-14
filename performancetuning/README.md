# Performance Tuning
Many of you know the live handling editors around.

Performance Tuning implements a vehicle upgrade system that consists of literal handling changes, injected onto the car. This allows much more variety of upgrades and way more granularity. 

## How it works
Most upgrades simply take the original, base stat and build an upgrade path up to base+X. This means all cars can upgrade equally as much, but no Asbo can match a Taipan.

**Absolute** paths may come later if people ask for them, where the every car follows the same stat upgrades up to the same, final target (like 200mph or 0.9G power).

## Power & Transmission
Power upgrades add straight power. They also adjust the gearing so the higher power is not wasted overrevving at top speed, so you also get higher top end with this.

Transmission improves shift times and the later upgrades add gears up to the top of 6, for better power delivery. All of them add a smidge of power emulating better transferring of what the engine is chucking out.

# Engine Swaps
These take the engine characteristics of another car and put it on yours. All of them. So sound, power and flywheel inertia (``fDriveInertia``). Top speed is adjusted for the new power.

## Tires
The compounds are entirely separate from the tire tuning.

You can choose any focus (Road, Mixed, Offroad) and then the 'quality' of that compound which is the true upgrade. The compound is just the balance you want, with its upsides and downsides.

## Brakes
These behave very much like the vanilla upgrade, but you can also upgrade the handbrakes themselves. Same idea.

## Suspension, Anti-Roll, etc
These help you adjust the behavior of the car beyond raw numbers, and you'll have to fiddle with them more. They don't count for PI yet.They might.

## Bias settings
Why not? The handling files have offsets for certain stats and I implemented them as tweaks. Things like grip bias and suspension bias are very potent in changing the way cars feel, fixing or inducing things like understeer. 

## Nitro
Uses the native nitro system but wraps a proper upgrade menu for it. Each subsequent upgrade is stronger, for the same duration. You can also be greedy and increase the throughput, but that incur a shorter shot than its worth. You may heat the engine more than usual.

The current placeholder system is made to have fun and isn't proper. You always get three shots if you stop the car. You can only regain them by stopping. You have to wait 40s between shots.

This 'balance' is for allowing some fun while letting players race without spamming or gaming the system. Will change.

# Persistence

The Vehicle Manager module is the only able to store all these upgrades for your cars. It is separate because I expect people may want to implement their own save system for their servers after this is out.

## Used Convars

- `ars_skip_uptodate_print`
  - Read via: `GetConvar`
  - Effective default: `'0'`
  - Example: `setr ars_skip_uptodate_print 1`

- `pt_engine_swaps`
  - Read via: `GetConvar`
  - Effective default: `''` (empty CSV)
  - Example: `setr pt_engine_swaps "dominator,gauntlet3,comet,vagner,nero"`
