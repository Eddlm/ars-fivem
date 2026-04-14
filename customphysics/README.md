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


# The Rollovers
If you knew Hollywood Rollovers... yeah.

Its a bit more complex, but the general rules are having at least one wheel of the ground, hitting something or rotating quite fast in any of the three axis.

This is the most WIP, subject to changes to the rules.