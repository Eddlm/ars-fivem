# RacingSystem Event Flows

- Client Resource Start (`onClientResourceStart`)
1. Client resource starts and calls `requestInitialRaceState()`.
2. Client sends `TriggerServerEvent('racingsystem:state:request')`.
3. Server handles `RegisterNetEvent('racingsystem:state:request')`.
4. Server calls `RacingSystem.Server.Snapshot.sendInitialState(source)`.
5. Server sends `racingsystem:catalog:definitions` to that client.
6. Server sends `racingsystem:instance:list` to that client.
7. Client caches definitions and instance summaries, rebuilds merged snapshot, and refreshes menu/runtime state.

- Server Player Joining (`playerJoining`)
1. A player begins joining and server `AddEventHandler('playerJoining')` runs.
2. Server waits 1000 ms (`SetTimeout`) before first payload push.
3. Server calls `sendInitialState(src)`.
4. Server sends `racingsystem:catalog:definitions` to the joining client.
5. Server sends `racingsystem:instance:list` to the joining client.
6. Client merges data into local caches and UI state.

- Host Race Invoke (`racingsystem:race:invoke`)
1. Host selects a saved race in menu and confirms hosting.
2. Client sends `TriggerServerEvent('racingsystem:race:invoke', payload, lapCount)`.
3. Server validates payload and resolves race source (custom/online).
4. Server creates race instance with owner, state `idle`, checkpoints, entrants.
5. Server broadcasts `racingsystem:instance:list` to all players.
6. Server broadcasts `racingsystem:instance:delta` to entrants in that instance.
7. Server broadcasts `racingsystem:state:standings` to entrants in that instance.
8. Server sends forced `racingsystem:instance:static` to host.
9. Server sends `racingsystem:race:teleportCheckpoint` (start spawn) to host.
10. Host client applies teleport and becomes staged at start.

- Join Race by ID (`racingsystem:race:joinById`)
1. Client selects an active race in menu.
2. Client sends `TriggerServerEvent('racingsystem:race:joinById', instanceId)`.
3. Server validates race state and join permissions.
4. Server inserts entrant into instance entrant state map/list.
5. Server broadcasts `racingsystem:instance:list` to all players.
6. Server broadcasts `racingsystem:instance:delta` to entrants in that instance.
7. Server broadcasts `racingsystem:state:standings` to entrants in that instance.
8. Server sends forced `racingsystem:instance:static` to the joining entrant.
9. Server chooses teleport chain:
10. If race is `running`, server sends `racingsystem:race:teleportCheckpoint` to entrant's current checkpoint.
11. If race is not `running`, server sends `racingsystem:race:teleportCheckpoint` to start checkpoint.
12. Client runs smart join teleport and is placed on grid/route.

- Join Race by Name (`racingsystem:race:joinByName`)
1. Client or external caller sends `TriggerServerEvent('racingsystem:race:joinByName', raceName)`.
2. Server resolves instance by name and validates join.
3. Server updates entrant membership.
4. Server broadcasts `racingsystem:instance:list`.
5. Server broadcasts `racingsystem:instance:delta`.
6. Server broadcasts `racingsystem:state:standings`.
7. Server sends forced `racingsystem:instance:static` to joiner.
8. Server sends `racingsystem:race:teleportCheckpoint` (running checkpoint or start checkpoint).
9. Client applies teleport and race UI adjusts to joined state.

- Start Countdown (`racingsystem:race:start`)
1. Host presses Start Countdown in menu.
2. Menu triggers local event `TriggerEvent('racingsystem:race:start')`.
3. Client pre-validates local joined instance, state, host ownership, entrant presence.
4. Client sends `TriggerServerEvent('racingsystem:race:start')`.
5. Server validates source can start current instance.
6. Server resets race progress for all entrants.
7. Server transitions instance state `idle/finished -> staging`.
8. Server sets `startAt` timer (`GetGameTimer() + countdownMs`).
9. Server sends `racingsystem:race:countdownStart` to each entrant.
10. Clients cache countdown end time and mark countdown accepted for that instance.
11. Server broadcasts `racingsystem:instance:list`.
12. Server broadcasts `racingsystem:instance:delta`.
13. Server broadcasts `racingsystem:state:standings`.

- Countdown Elapsed to Running (staging runtime thread)
1. Server runtime thread loops every ~250 ms.
2. Thread scans race instances for `state == staging` and `now >= startAt`.
3. Server transitions instance state `staging -> running`.
4. Server sets `startedAt` and clears `startAt`.
5. Server sets each entrant `lapStartedAt`.
6. Server broadcasts `racingsystem:instance:delta`.
7. Server broadcasts `racingsystem:state:standings`.
8. If any state changed, server broadcasts `racingsystem:instance:list`.
9. Clients consume deltas and update in-race rendering/logic to active running state.

- Client Countdown Zero Report (`racingsystem:race:countdownZero`)
1. Client in-race loop sees local countdown reach zero.
2. Client sends `TriggerServerEvent('racingsystem:race:countdownZero', instanceId, clientTimer)` once per instance.
3. Server receives the event and logs telemetry/context.
4. Server does not transition state from this event; runtime thread remains authoritative for stage change.

- Checkpoint Pass (`racingsystem:race:checkpointPassed`)
1. Client in-race loop detects checkpoint release crossing and builds lap/pass context payload.
2. Client sends `TriggerServerEvent('racingsystem:race:checkpointPassed', instanceId, checkpointIndex, lapTimingPayload, passContextPayload)`.
3. Server validates instance existence, running state, entrant membership, expected checkpoint order.
4. Server updates entrant checkpoint, lap, pass counts, lap timing, finish state.
5. If lap trigger checkpoint is passed, server may emit lap-complete events.
6. If all entrants finished, server transitions instance to `finished` and clears `startAt`.
7. Server broadcasts `racingsystem:instance:delta`.
8. Server broadcasts `racingsystem:state:standings`.
9. Clients merge delta/standings and update checkpoint targets and leaderboard.

- Lap Completed Broadcast (`racingsystem:race:lapCompleted`)
1. During checkpoint processing, server detects a completed lap with timing payload.
2. Server computes best-lap delta and finishing status.
3. Server emits `TriggerClientEvent('racingsystem:race:lapCompleted', entrantSource, payload)` to each entrant.
4. Each client receives event and filters for local entrant identity.
5. Local client shows lap complete / final lap / finished UI cues.

- Lap Annotation (`racingsystem:race:lapAnnotation`)
1. During checkpoint processing, server determines annotation context (instance best or delta).
2. Server emits `TriggerClientEvent('racingsystem:race:lapAnnotation', entrantSource, payload)` to relevant entrant.
3. Client receives event and displays annotation notification.

- Restart Race (`racingsystem:race:restart`)
1. Host presses Restart Race in menu.
2. Menu triggers local event `TriggerEvent('racingsystem:race:restart')`.
3. Client pre-validates joined instance, host ownership fallback, and entrant presence.
4. Client sends `TriggerServerEvent('racingsystem:race:restart')`.
5. Server validates caller is instance owner.
6. Server resets all entrant progress and clears `startAt/startedAt/finishedAt`.
7. Server transitions instance state to `idle` when required.
8. Server broadcasts `racingsystem:instance:list`.
9. Server broadcasts `racingsystem:instance:delta`.
10. Server broadcasts `racingsystem:state:standings`.
11. For each entrant, server sends `racingsystem:race:restarted`.
12. For each entrant, server sends `racingsystem:race:teleportCheckpoint` to start checkpoint.
13. Clients clear countdown-accepted lock and local race timing scratch state.
14. Clients apply start-grid teleport again.

- Leave Race (`racingsystem:race:leave`)
1. Player presses Leave Race in menu.
2. Menu triggers local event `TriggerEvent('racingsystem:race:leave')`.
3. Client immediately clears local race runtime/timing/visual state.
4. Client sends cross-resource `traffic_control:requestDensity` clear request.
5. Client sends `TriggerServerEvent('racingsystem:race:leave')`.
6. Server removes entrant from instance entrant state.
7. If instance becomes empty, server destroys the instance.
8. Server broadcasts `racingsystem:instance:list`.
9. If instance still exists, server also broadcasts `racingsystem:instance:delta` and `racingsystem:state:standings`.
10. Remaining clients refresh menu/race state from new payloads.

- Kill Race Instance (`racingsystem:race:kill`)
1. Host/admin presses Kill Race Instance in menu.
2. Client sends `TriggerServerEvent('racingsystem:race:kill', instance.name)`.
3. Server validates admin/owner permissions.
4. Server removes instance from state registry.
5. Server broadcasts `racingsystem:state:standings` for affected entrant audience.
6. Server broadcasts `racingsystem:instance:list` globally.
7. Clients detect missing instance and unload joined race context.

- Editor Load (`racingsystem:editor:load`)
1. Client editor action requests load for race name.
2. Client sends `TriggerServerEvent('racingsystem:editor:load', raceName)`.
3. Server resolves race from CustomRaces or OnlineRaces, or creates new empty definition.
4. If existing definition was resolved, server may register it and broadcast `catalog:definitions` and `instance:list`.
5. Server replies to caller with `TriggerClientEvent('racingsystem:editor:loaded', src, payload)`.
6. Client starts editor session using returned checkpoints and name.

- Editor Save (`racingsystem:editor:save`)
1. Client sends `TriggerServerEvent('racingsystem:editor:save', {name, checkpoints})`.
2. Server validates and persists definition.
3. Server broadcasts `racingsystem:catalog:definitions` globally.
4. Server finds active instances tied to saved definition.
5. Server broadcasts `racingsystem:instance:delta` for those instances.
6. Server sends forced `racingsystem:instance:static` to entrants in those instances.
7. Server replies `racingsystem:editor:saved` to requesting client.
8. Client updates editor state from authoritative saved payload.

- Definition Register (`racingsystem:def:register`)
1. Client sends `TriggerServerEvent('racingsystem:def:register', raceName)`.
2. Server validates/registers definition.
3. Server broadcasts `racingsystem:catalog:definitions`.
4. Server replies `racingsystem:def:registered` to caller.
5. Client updates pending menu selection values.

- Definition Delete (`racingsystem:def:delete`)
1. Client sends `TriggerServerEvent('racingsystem:def:delete', payload)`.
2. Server validates permissions and delete request.
3. Server deletes definition from repository.
4. Server broadcasts `racingsystem:catalog:definitions`.
5. Server replies `racingsystem:def:deleted` to caller.
6. Client clears editor delete confirmation and refreshes editor menu state.

- GTAO Import by ID (`racingsystem:ugc:importById`)
1. Client NUI submit callback extracts UGC ID from URL/input.
2. Client sends `TriggerServerEvent('racingsystem:ugc:importById', ugcId)`.
3. Server validates remote/bundled UGC metadata.
4. Server saves imported race into OnlineRaces repository.
5. Server registers imported definition in catalog.
6. Server broadcasts `racingsystem:catalog:definitions`.
7. Server replies `racingsystem:ugc:importResult` to requesting client.
8. Client updates pending host selection race name for quick host flow.

- Notification Push (`racingsystem:ui:notify`)
1. Server-side logic calls notify helper.
2. Helper sends `TriggerClientEvent('racingsystem:ui:notify', targetId, {message})`.
3. Client receives `racingsystem:ui:notify`.
4. Client displays feed notification text.

- Teleport to Checkpoint (`racingsystem:race:teleportCheckpoint`)
1. Server decides teleport target from join/restart/reset workflows.
2. Server sends `TriggerClientEvent('racingsystem:race:teleportCheckpoint', target, payload)`.
3. Client receives event and launches smart teleport thread.
4. Client resolves heading from route context when needed.
5. Client fades out, repositions ped/vehicle, applies speed rules, fades in.
6. Client resumes control at target checkpoint/start grid.

- State Delta and Static Cache Merge (`instance:list`, `instance:delta`, `instance:static`, `state:standings`)
1. Server emits list/delta/standings/static events from invoke/join/start/restart/checkpoint/leave/threads.
2. Client handlers update dedicated caches (`instanceListCache`, `instanceDynamicCacheById`, `instanceStaticCacheById`, standings cache).
3. Client rebuilds merged `latestSnapshot.instances` from cache layers.
4. Client in-race logic reads merged snapshot for joined instance, owner, entrants, checkpoints.
5. Menu logic reads merged snapshot for host controls and current state.

- Traffic Density Side-Channel (`traffic_control:requestDensity`)
1. Client joins or switches race instance and calculates desired density.
2. Client sends `TriggerServerEvent('traffic_control:requestDensity', density, reason, key)`.
3. Client also sends clear requests on leave and resource stop.
4. Traffic control resource applies density changes independently of racingsystem state events.

- Client Resource Stop (`onClientResourceStop`)
1. Client resource stop handler runs for racingsystem.
2. Client clears NUI prompt and local race visuals/state.
3. Client sends `traffic_control:requestDensity` clear request.
4. Client unloads active race assets and blips.
5. Server racingsystem state remains authoritative and continues for other entrants.

- Server Player Dropped (`playerDropped`)
1. Server receives player disconnect event.
2. Server removes player from any race instance(s).
3. If any instance changed, server broadcasts `racingsystem:instance:list`.
4. Remaining clients detect entrant/instance changes through refreshed list and subsequent deltas.
