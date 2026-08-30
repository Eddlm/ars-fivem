# Live Test Checklist — Race Lifecycle

Test one full race from host to finish. Check each box as you go.

## Setup
- [ ] Server starts without errors in console
- [ ] F7 opens the racing menu
- [ ] Active Races list shows (empty at first)

## Host a Race
- [x] Pick a race from the list, set laps/traffic, hit "Host Selected Race"
- [x] Menu shows staging screen with race name, entrants (just you)
- [x] "Start Countdown" button is enabled
- [x] Race appears in Active Races for others

## Others Join
- [x] Another player sees the race in Active Races
- [x] They join — entrant count updates on both players' menus
- [x] Late joiners get the correct race assets loaded (checkpoints visible)

## Countdown
- [x] Host clicks "Start Countdown" — button greys out immediately, no flicker
- [ ] Countdown timer appears on screen (3, 2, 1, GO)
- [ ] "GO" Scaleform shard appears, race begins

## Racing — Checkpoints
- [x] Checkpoint markers/chevrons render and point the right direction
- [ ] Passing a checkpoint triggers a notification/blip update
- [ ] Leaderboard updates position after each checkpoint
- [ ] Wrong-direction checkpoint passes are ignored

## Racing — Laps
- [ ] Lap completion shows lap time notification
- [ ] "LAP X COMPLETED" shard appears
- [ ] Final lap shows "FINAL LAP" indicator
- [ ] Point-to-point races end at the terminal checkpoint (no extra lap)

## Finish
- [ ] Crossing finish on last lap shows "FINISHED" with position/time
- [ ] All finishers get notified
- [ ] After all finish, instance auto-kills
- [ ] Menu returns to neutral state
- [ ] Race assets unload (checkpoints disappear)

## Edge Cases
- [x] Leave mid-race — removed from leaderboard, assets unload
- [x] Rejoin mid-race (late join) — inherits last place progress
- [ ] Rejoin before cutoff — starts in last place, with correct checkpoint/heading/grid slot
- [ ] Rejoin after cutoff — rejected with the configured late-join message
- [ ] Client resource restart while joined — race route, entrants, assets, and position resync even after cutoff
- [ ] Host leaves mid-race — instance terminates for everyone
- [ ] Host disconnect mid-race — instance terminates for everyone
- [ ] Non-host disconnect — standings repair, race continues
- [ ] Restart after finish, then start again — works cleanly
- [ ] Kill race as host — instance destroyed, all players kicked to neutral

## Notes
Write anything weird here:

### Live-test fixes applied (2026-07-24)
- Teleport heading: `resolveTeleportHeading` now uses target→next direction instead of previous→target
- Menu refresh on open: `openRaceMenu` forces menu refresh, bypassing ScaleformUI visibility race
- Start button greyed after leave+rehost: `intendedGreyItems` list now cleared on leave and menu refresh
- Checkpoint blips: added with color coding, cleanup on leave/finish, short-range for non-target checkpoints
- Chevron positioning: simplified to point toward previous checkpoint at 40% of pass radius

