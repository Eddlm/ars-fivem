RacingSystem = RacingSystem or {}
RacingSystem.Server = RacingSystem.Server or {}

CreateThread(function()
    while true do
        local changedAnyState = false
        local now = GetGameTimer()

        for _, instance in pairs(RacingSystem.Server.State.raceInstancesById) do
            if instance.state == RacingSystem.States.staging and tonumber(instance.startAt) and now >= tonumber(instance.startAt) then
                local transitionOk = RacingSystem.Server.Logging.setRaceInstanceState(
                    instance,
                    RacingSystem.States.running,
                    'countdownElapsed',
                    0,
                    nil,
                    'countdown_elapsed'
                )
                if transitionOk then
                    instance.startedAt = now
                    instance.startAt = nil
                    for _, entrant in ipairs(instance.entrants or {}) do
                        entrant.currentCheckpoint = 1
                        entrant.lapStartedAt = now
                    end
                    RacingSystem.Server.Logging.logVerbose(("Race '%s' (instance %s) moved from staging to running with %s entrants."):format(
                        tostring(instance.name or 'unknown'),
                        tostring(instance.id),
                        tostring(#(instance.entrants or {}))
                    ))
                    RacingSystem.Server.Snapshot.broadcastInstanceDelta(instance)
                    RacingSystem.Server.Snapshot.broadcastInstanceStandings(instance)
                    changedAnyState = true
                elseif RacingSystem.Server.Logging.shouldLogLifecycleAnomaly('countdownElapsed', 0, instance.id) then
                    RacingSystem.Server.Logging.logLifecycleEvent(
                        'countdownElapsed',
                        instance,
                        nil,
                        0,
                        instance.state,
                        RacingSystem.States.running,
                        'transition_rejected'
                    )
                end
            end
        end

        if changedAnyState then
            RacingSystem.Server.Snapshot.broadcastInstanceList()
        end

        Wait(250)
    end
end)

CreateThread(function()
    while true do
        RacingSystem.Server.Snapshot.runSnapshotRoundRobinTick()
    end
end)

RacingSystem.Server.Catalog.loadRaceIndex()
RacingSystem.Server.Parsing.runIntegrityScript()


