# Custom Physics

Most of this resource uses live power adjustments to enhance the experience or deal with native problems. One by one:

# The Powerslides

If you knew InverseTorque, this is it, reworked.

It tries to keep power up while you slide to allow powerslides to happen. The numbers can be tweaked, but the default is a balance and not over the top.

# The Offroading speed

GTA tries very hard to limit your speed off the road. This system attempts to undo that effect by giving the car just enough power to keep accelerating to last gear while offroad. Mainly any surface that has drag defined in materials.dat.

# The Speed Glitches

We deal with speed glitches like Kerb-boosting or suspension boosting in a very simple way, we simply compare the intended acceleration (wheels deliver power in Gs) with the true physical acceleration the vehicle is experienced. Wheel's acceleration is pretty reliable, glitches show as spikes compared against it.

This extra acceleration comes from the wheels, who are deliverling way more power than they intend. We can notice that disparity and adjust their power so they stop instantly.


For context, a disparity of 2Gs is a sudden extra acceleration of ~48mph PER SECOND. 

# The Wheelies
Another rework of old... work. While you're doing a burnout, hold the handbrake, lift the brake. When you launch (lifting the handbrake), you'll do a wheelie. Muscles only! If you want.

# The Rollovers
If you knew Hollywood Rollovers... yeah.

Its a bit more complex, but the general rules are having at least one wheel of the ground, hitting something or rotating quite fast in any of the three axis.

This is the most WIP, subject to changes to the rules.

## Used Convars

- `ars_skip_uptodate_print`
  - Read via: `GetConvar`
  - Effective default: `'0'`
  - Example: `setr ars_skip_uptodate_print 1`

- `cPhysicsExtraPrints`
  - Read via: `GetConvarInt`
  - Effective default: `0`
  - Example: `setr cPhysicsExtraPrints 1`

- `cp_rollover_start_speed`
  - Read via: `GetConvar`
  - Effective default: `8.94`
  - Example: `setr cp_rollover_start_speed 8.94`

- `cp_rollover_keep_speed`
  - Read via: `GetConvar`
  - Effective default: `6.71`
  - Example: `setr cp_rollover_keep_speed 6.71`

- `cp_rollover_start_rot`
  - Read via: `GetConvar`
  - Effective default: `180.0`
  - Example: `setr cp_rollover_start_rot 180.0`

- `cp_rollover_keep_rot`
  - Read via: `GetConvar`
  - Effective default: `90.0`
  - Example: `setr cp_rollover_keep_rot 90.0`

- `cp_wheelies_enabled`
  - Read via: `GetConvarBool`
  - Effective default: `true`
  - Example: `setr cp_wheelies_enabled true`

- `cp_wheelies_muscle_only`
  - Read via: `GetConvarBool`
  - Effective default: `true`
  - Example: `setr cp_wheelies_muscle_only true`