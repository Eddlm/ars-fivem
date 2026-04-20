RacingSystem = RacingSystem or {}
RacingSystem.Server = RacingSystem.Server or {}

RegisterNetEvent('racingsystem:state:request', function()
    RacingSystem.Server.Snapshot.sendInitialState(source)
end)

RegisterNetEvent('racingsystem:editor:load', function(raceName)
    local src = source
    local definition = nil

    -- Always try to load the full race data from disk first
    local customDefinition = RacingSystem.Server.Repository.loadCustomRace(raceName)
    if customDefinition then
        definition = customDefinition
        RacingSystem.Server.Logging.logVerbose(('[requestEditorRace] Loaded "%s" from CustomRaces'):format(raceName))
    end

    if not definition then
        local onlineDefinition = RacingSystem.Server.Repository.loadBundledOnlineRace(raceName)
        if onlineDefinition then
            definition = onlineDefinition
            RacingSystem.Server.Logging.logVerbose(('[requestEditorRace] Loaded "%s" from OnlineRaces'):format(raceName))
        end
    end

    if not definition then
        -- New race: create and save empty file to CustomRaces
        definition = RacingSystem.Server.Repository.createNewRaceDefinition(src, raceName)
        if not definition then
            RacingSystem.Server.Logging.logError(('[requestEditorRace] Failed to create new race "%s"'):format(raceName))
            TriggerClientEvent('racingsystem:editor:loaded', src, {
                ok = false,
                error = 'Could not load race for editor.',
                data = {
                    requestedName = RacingSystem.Trim(raceName),
                    race = nil,
                },
            })
            return
        end
        RacingSystem.Server.Logging.logVerbose(('[requestEditorRace] Created new race "%s"'):format(raceName))
    else
        -- Ensure the definition is registered
        if definition.name then
            RacingSystem.Server.Catalog.registerKnownRaceDefinition(
                definition.name,
                definition.sourceType or 'custom',
                definition.ugcId or definition.fileName
            )
            RacingSystem.Server.Snapshot.broadcastDefinitions()
            RacingSystem.Server.Snapshot.broadcastInstanceList()
        end
    end

    TriggerClientEvent('racingsystem:editor:loaded', src, {
        ok = true,
        error = nil,
        data = {
            requestedName = RacingSystem.Trim(raceName),
            race = RacingSystem.Server.Parsing.buildSavedRaceSnapshot(definition),
        },
    })
end)

RegisterNetEvent('racingsystem:editor:save', function(payload)
    local src = source
    local definition, saveError = RacingSystem.Server.Repository.saveRaceDefinition(
        src,
        type(payload) == 'table' and payload.name or '',
        type(payload) == 'table' and payload.checkpoints or {}
    )

    if not definition then
        RacingSystem.Server.Logging.logLevelOne(("%s could not save the editor race. Reason: %s."):format(
            RacingSystem.Server.Logging.resolvePlayerLogLabel(src),
            tostring(saveError or 'unknown error')
        ))
        TriggerClientEvent('racingsystem:editor:saved', src, {
            ok = false,
            error = saveError or 'Could not save race.',
            data = nil,
        })
        return
    end

    RacingSystem.Server.Logging.auditLog("saveEditorRace", src, ("saved race '%s' with %s checkpoints"):format(
        tostring(definition.name or ""),
        tostring(#(definition.checkpoints or {}))
    ))
    RacingSystem.Server.Snapshot.broadcastDefinitions()
    local savedLookup = RacingSystem.NormalizeRaceName(definition.name)
    if savedLookup then
        for _, instance in pairs(RacingSystem.Server.State.raceInstancesById) do
            local instanceLookup = RacingSystem.NormalizeRaceName(instance.definitionName or instance.name)
            if instanceLookup == savedLookup then
                RacingSystem.Server.Snapshot.broadcastInstanceDelta(instance)
                for _, entrant in ipairs(RacingSystem.Server.Snapshot.listEntrantsFromState(instance)) do
                    local target = tonumber(entrant.source) or 0
                    if target > 0 then
                        RacingSystem.Server.Snapshot.sendInstanceStaticIfChanged(target, instance, true)
                    end
                end
            end
        end
    end
    TriggerClientEvent('racingsystem:editor:saved', src, {
        ok = true,
        error = nil,
        data = {
            race = RacingSystem.Server.Parsing.buildSavedRaceSnapshot(definition),
        },
    })
end)

RegisterNetEvent('racingsystem:def:register', function(raceName)
    local src = source
    local definition, registerError = RacingSystem.Server.Repository.registerRaceDefinitionIfValid(raceName)

    if not definition then
        RacingSystem.Server.Logging.logLevelOne(("%s could not register race definition '%s'. Reason: %s."):format(
            RacingSystem.Server.Logging.resolvePlayerLogLabel(src),
            tostring(raceName),
            tostring(registerError or 'unknown error')
        ))
        TriggerClientEvent('racingsystem:def:registered', src, {
            ok = false,
            error = registerError or 'Could not register race definition.',
            data = nil,
        })
        return
    end

    RacingSystem.Server.Logging.auditLog("registerRaceDefinition", src, ("registered race definition '%s' (%s source)"):format(
        tostring(definition.name or raceName),
        tostring(definition.sourceType or 'unknown')
    ))
    RacingSystem.Server.Snapshot.broadcastDefinitions()
    TriggerClientEvent('racingsystem:def:registered', src, {
        ok = true,
        error = nil,
        data = {
            definition = definition,
        },
    })
end)

RegisterNetEvent('racingsystem:ugc:importById', function(ugcId)
    local src = source
    local validation, validationError = RacingSystem.Server.Repository.validateBundledUGCById(ugcId)

    if not validation then
        TriggerClientEvent('racingsystem:ugc:importResult', src, {
            ok = false,
            error = validationError or 'Could not validate GTAO race URL.',
            data = {
                ugcId = tostring(ugcId or ''),
            },
        })
        return
    end

    local importedRace, importError = RacingSystem.Server.Repository.saveBundledUGCById(validation.ugcId)
    if not importedRace then
        TriggerClientEvent('racingsystem:ugc:importResult', src, {
            ok = false,
            error = importError or 'The UGC JSON validated but could not be imported.',
            data = {
                ugcId = tostring(validation.ugcId or ugcId or ''),
            },
        })
        return
    end

    RacingSystem.Server.Catalog.registerKnownRaceDefinition(importedRace.raceName, 'online', importedRace.ugcId)

    RacingSystem.Server.Logging.auditLog("importGTAORace", src, ("imported UGC '%s' as '%s'"):format(
        tostring(importedRace.ugcId or validation.ugcId),
        tostring(importedRace.raceName)
    ))

    RacingSystem.Server.Snapshot.broadcastDefinitions()
    TriggerClientEvent('racingsystem:ugc:importResult', src, {
        ok = true,
        error = nil,
        data = {
            ugcId = tostring(importedRace.ugcId or validation.ugcId or ''),
            raceName = tostring(importedRace.raceName or validation.ugcId or ''),
            checkpointCount = tonumber(importedRace.checkpointCount) or tonumber(validation.checkpointCount) or 0,
            propCount = tonumber(importedRace.propCount) or tonumber(validation.propCount) or 0,
            modelHideCount = tonumber(importedRace.modelHideCount) or tonumber(validation.modelHideCount) or 0,
        },
    })
end)

RegisterNetEvent('racingsystem:def:delete', function(payload)
    local src = source
    local payloadLabel = nil
    if type(payload) == 'table' then
        payloadLabel = RacingSystem.Trim(payload.name or payload.lookupName or payload.raceId or '')
    else
        payloadLabel = tostring(payload or '')
    end

    if not RacingSystem.Server.Logging.hasAdminAccess(src) then
        RacingSystem.Server.Logging.logLevelOne(("%s tried to delete race definition '%s' without permission."):format(
            RacingSystem.Server.Logging.resolvePlayerLogLabel(src),
            tostring(payloadLabel)
        ))
        RacingSystem.Server.Logging.notifyPlayer(src, "You do not have permission to delete races.", true)
        return
    end
    local deletedDefinition, deleteError = RacingSystem.Server.Repository.deleteRaceDefinition(payload)

    if not deletedDefinition then
        RacingSystem.Server.Logging.logLevelOne(("%s could not delete race definition '%s'. Reason: %s."):format(
            RacingSystem.Server.Logging.resolvePlayerLogLabel(src),
            tostring(payloadLabel),
            tostring(deleteError or 'unknown error')
        ))
        TriggerClientEvent('racingsystem:def:deleted', src, {
            ok = false,
            error = deleteError or 'Could not delete race definition.',
            data = nil,
        })
        return
    end

    RacingSystem.Server.Logging.auditLog("RacingSystem.Server.Repository.deleteRaceDefinition", src, ("deleted race definition '%s'"):format(tostring((deletedDefinition or {}).name or payloadLabel)))
    RacingSystem.Server.Snapshot.broadcastDefinitions()
    TriggerClientEvent('racingsystem:def:deleted', src, {
        ok = true,
        error = nil,
        data = {
            definition = deletedDefinition,
        },
    })
end)

RegisterNetEvent('racingsystem:race:invoke', function(payload, lapCount)
    local invokePayload = payload
    local raceName = type(payload) == 'table' and (payload.lookupName or payload.name) or payload
    local src = source
    if type(payload) == 'table' then
        RacingSystem.Server.Logging.logVerbose(("[invoke:event] %s payload name='%s' lookupName='%s' sourceType='%s' raceId='%s' laps=%s"):format(
            RacingSystem.Server.Logging.resolvePlayerLogLabel(src),
            tostring(payload.name or ''),
            tostring(payload.lookupName or ''),
            tostring(payload.sourceType or ''),
            tostring(payload.raceId or ''),
            tostring(lapCount)
        ))
    else
        RacingSystem.Server.Logging.logVerbose(("[invoke:event] %s payload scalar raceName='%s' laps=%s"):format(
            RacingSystem.Server.Logging.resolvePlayerLogLabel(src),
            tostring(raceName),
            tostring(lapCount)
        ))
    end
    local instance, invokeError = RacingSystem.Server.Instances.invokeRaceInstance(src, invokePayload, lapCount)

    if not instance then
        RacingSystem.Server.Logging.logLevelOne(("%s could not invoke race '%s'. Reason: %s."):format(
            RacingSystem.Server.Logging.resolvePlayerLogLabel(src),
            tostring(raceName),
            tostring(invokeError or 'unknown error')
        ))
        RacingSystem.Server.Logging.notifyPlayer(src, invokeError or 'Could not invoke race.', true)
        return
    end

    RacingSystem.Server.Logging.auditLog("invokeRace", src, ("invoked race '%s' (instance %s, %s lap(s), %s source)"):format(
        tostring(instance.name or raceName),
        tostring(instance.id),
        tostring(instance.laps),
        tostring(instance.sourceType or 'unknown')
    ))
    RacingSystem.Server.Snapshot.broadcastInstanceList()
    RacingSystem.Server.Snapshot.broadcastInstanceDelta(instance)
    RacingSystem.Server.Snapshot.broadcastInstanceStandings(instance)
    RacingSystem.Server.Snapshot.sendInstanceStaticIfChanged(src, instance, true)
    RacingSystem.Server.Snapshot.sendTeleportToLastCheckpoint(src, instance)
end)

RegisterNetEvent('racingsystem:race:joinByName', function(raceName)
    local src = source
    local instance, joinError = RacingSystem.Server.Instances.joinRaceInstanceByName(src, raceName)

    if not instance then
        RacingSystem.Server.Logging.logLevelOne(("%s could not join race '%s'. Reason: %s."):format(
            RacingSystem.Server.Logging.resolvePlayerLogLabel(src),
            tostring(raceName),
            tostring(joinError or 'unknown error')
        ))
        RacingSystem.Server.Logging.notifyPlayer(src, joinError or 'Could not join race.', true)
        return
    end

    RacingSystem.Server.Logging.auditLog("joinRace", src, ("joined race '%s' (instance %s). Entrants now: %s"):format(
        tostring(instance.name or raceName),
        tostring(instance.id),
        tostring(#(instance.entrants or {}))
    ))
    RacingSystem.Server.Snapshot.broadcastInstanceList()
    RacingSystem.Server.Snapshot.broadcastInstanceDelta(instance)
    RacingSystem.Server.Snapshot.broadcastInstanceStandings(instance)
    RacingSystem.Server.Snapshot.sendInstanceStaticIfChanged(src, instance, true)

    -- For mid-race joins, teleport to the current checkpoint; otherwise use default start teleport
    if instance.state == RacingSystem.States.running then
        local joiningEntrant = instance.entrants[#instance.entrants]
        if joiningEntrant then
            RacingSystem.Server.Snapshot.sendTeleportToCheckpoint(src, instance, joiningEntrant.currentCheckpoint)
        end
    else
        RacingSystem.Server.Snapshot.sendTeleportToLastCheckpoint(src, instance)
    end
end)

RegisterNetEvent('racingsystem:race:joinById', function(instanceId)
    local src = source
    local instance, joinError = RacingSystem.Server.Instances.joinRaceInstanceById(src, instanceId)

    if not instance then
        RacingSystem.Server.Logging.logLevelOne(("%s could not join race instance %s. Reason: %s."):format(
            RacingSystem.Server.Logging.resolvePlayerLogLabel(src),
            tostring(instanceId),
            tostring(joinError or 'unknown error')
        ))
        RacingSystem.Server.Logging.notifyPlayer(src, joinError or 'Could not join race.', true)
        return
    end

    RacingSystem.Server.Logging.auditLog("RacingSystem.Server.Instances.joinRaceInstanceById", src, ("joined race instance %s ('%s'). Entrants now: %s"):format(
        tostring(instance.id),
        tostring(instance.name or 'unnamed'),
        tostring(#(instance.entrants or {}))
    ))
    RacingSystem.Server.Snapshot.broadcastInstanceList()
    RacingSystem.Server.Snapshot.broadcastInstanceDelta(instance)
    RacingSystem.Server.Snapshot.broadcastInstanceStandings(instance)
    RacingSystem.Server.Snapshot.sendInstanceStaticIfChanged(src, instance, true)

    -- For mid-race joins, teleport to the current checkpoint; otherwise use default start teleport
    if instance.state == RacingSystem.States.running then
        local joiningEntrant = instance.entrants[#instance.entrants]
        if joiningEntrant then
            RacingSystem.Server.Snapshot.sendTeleportToCheckpoint(src, instance, joiningEntrant.currentCheckpoint)
        end
    else
        RacingSystem.Server.Snapshot.sendTeleportToLastCheckpoint(src, instance)
    end
end)

RegisterNetEvent('racingsystem:race:start', function()
    local src = source
    local instance, startError = RacingSystem.Server.Instances.startRaceInstanceForSource(src)

    if not instance then
        RacingSystem.Server.Logging.logLevelOne(("%s could not start the race. Reason: %s."):format(
            RacingSystem.Server.Logging.resolvePlayerLogLabel(src),
            tostring(startError or 'unknown error')
        ))
        RacingSystem.Server.Logging.notifyPlayer(src, startError or 'Could not start race.', true)
        return
    end

    RacingSystem.Server.Logging.auditLog("startRace", src, ("started race '%s' (instance %s) with %s entrants. Countdown: %sms"):format(
        tostring(instance.name or 'unknown'),
        tostring(instance.id),
        tostring(#(instance.entrants or {})),
        tostring(tonumber((RacingSystem.Config or {}).countdownMs) or 5000)
    ))
    RacingSystem.Server.Snapshot.broadcastInstanceList()
    RacingSystem.Server.Snapshot.broadcastInstanceDelta(instance)
    RacingSystem.Server.Snapshot.broadcastInstanceStandings(instance)
end)

RegisterNetEvent('racingsystem:race:restart', function()
    local src = source
    local instance, restartError = RacingSystem.Server.Instances.restartRaceInstanceForSource(src)

    if not instance then
        RacingSystem.Server.Logging.logLevelOne(("%s could not restart the race. Reason: %s."):format(
            RacingSystem.Server.Logging.resolvePlayerLogLabel(src),
            tostring(restartError or 'unknown error')
        ))
        RacingSystem.Server.Logging.notifyPlayer(src, restartError or 'Could not restart race.', true)
        return
    end

    RacingSystem.Server.Logging.auditLog("restartRace", src, ("restarted race '%s' (instance %s) with %s entrants."):format(
        tostring(instance.name or 'unknown'),
        tostring(instance.id),
        tostring(#(instance.entrants or {}))
    ))

    RacingSystem.Server.Snapshot.broadcastInstanceList()
    RacingSystem.Server.Snapshot.broadcastInstanceDelta(instance)
    RacingSystem.Server.Snapshot.broadcastInstanceStandings(instance)

    for _, entrant in ipairs(instance.entrants or {}) do
        local entrantSource = tonumber(entrant.source) or 0
        if entrantSource > 0 then
            TriggerClientEvent('racingsystem:race:restarted', entrantSource, {
                instanceId = tonumber(instance.id) or -1,
            })
            RacingSystem.Server.Snapshot.sendTeleportToLastCheckpoint(entrantSource, instance)
        end
    end
end)

RegisterNetEvent('racingsystem:race:checkpointPassed', function(instanceId, checkpointIndex, lapTimingPayload, passContext)
    local src = source
    local instance, checkpointError = RacingSystem.Server.Instances.handleCheckpointPassed(src, instanceId, checkpointIndex, lapTimingPayload, passContext)

    if not instance then
        if checkpointError ~= 'Ignored out-of-order checkpoint pass.' then
            RacingSystem.Server.Logging.notifyPlayer(src, checkpointError or 'Could not advance checkpoint.', true)
        end
        return
    end

    RacingSystem.Server.Snapshot.broadcastInstanceDelta(instance)
    RacingSystem.Server.Snapshot.broadcastInstanceStandings(instance)
end)

RegisterNetEvent('racingsystem:race:finish', function()
    local src = source
    local instance, finishError = RacingSystem.Server.Instances.finishRaceInstanceForSource(src)
    if not instance then
        RacingSystem.Server.Logging.logLevelOne(("%s could not finish the race. Reason: %s."):format(
            RacingSystem.Server.Logging.resolvePlayerLogLabel(src),
            tostring(finishError or 'unknown error')
        ))
        RacingSystem.Server.Logging.notifyPlayer(src, finishError)
        return
    end

    RacingSystem.Server.Logging.auditLog("finishRace", src, ("finished race '%s' (instance %s)"):format(
        tostring((instance or {}).name or "unknown"),
        tostring((instance or {}).id or "unknown")
    ))
    RacingSystem.Server.Snapshot.broadcastInstanceList()
    RacingSystem.Server.Snapshot.broadcastInstanceDelta(instance)
    RacingSystem.Server.Snapshot.broadcastInstanceStandings(instance)
end)

RegisterNetEvent('racingsystem:race:countdownZero', function(instanceId, clientGameTimerAtZero)
    local src = source
    local instance = RacingSystem.Server.State.raceInstancesById[tonumber(instanceId) or -1]
    local playerLabel = RacingSystem.Server.Logging.resolvePlayerLogLabel(src)

    if not instance then
        RacingSystem.Server.Logging.logLevelOne(("%s reached countdown zero for missing instance %s."):format(playerLabel, tostring(instanceId)))
        return
    end

    RacingSystem.Server.Logging.logVerbose(("%s reached countdown zero in race '%s' (instance %s, state=%s). clientTimer=%s, serverTimer=%s."):format(
        playerLabel,
        tostring(instance.name or 'unknown'),
        tostring(instance.id),
        tostring(instance.state),
        tostring(clientGameTimerAtZero),
        tostring(GetGameTimer())
    ))
end)

RegisterNetEvent('racingsystem:race:leave', function()
    local src = source
    local instance, leaveError = RacingSystem.Server.Instances.leaveCurrentRaceInstance(src)

    if not instance then
        RacingSystem.Server.Logging.logLevelOne(("%s could not leave the race. Reason: %s."):format(
            RacingSystem.Server.Logging.resolvePlayerLogLabel(src),
            tostring(leaveError or 'unknown error')
        ))
        RacingSystem.Server.Logging.notifyPlayer(src, leaveError or 'Could not leave race.', true)
        return
    end

    RacingSystem.Server.Logging.auditLog("leaveRace", src, ("left race '%s' (instance %s). Entrants now: %s"):format(
        tostring(instance.name or 'unknown'),
        tostring(instance.id),
        tostring(#(instance.entrants or {}))
    ))
    RacingSystem.Server.Snapshot.broadcastInstanceList()
    if type(instance) == 'table' then
        RacingSystem.Server.Snapshot.broadcastInstanceDelta(instance)
        RacingSystem.Server.Snapshot.broadcastInstanceStandings(instance)
    end
end)

RegisterNetEvent('racingsystem:race:kill', function(raceName)
    local src = source
    local instance = RacingSystem.Server.Snapshot.findRaceInstanceByName(raceName)
    local ownerKillEnabled = true
    local ownsRace = instance and tonumber(instance.owner) == tonumber(src)
    if not RacingSystem.Server.Logging.hasAdminAccess(src) and not (ownerKillEnabled and ownsRace) then
        RacingSystem.Server.Logging.logLevelOne(("%s tried to kill race '%s' without permission."):format(
            RacingSystem.Server.Logging.resolvePlayerLogLabel(src),
            tostring(raceName)
        ))
        RacingSystem.Server.Logging.notifyPlayer(src, "You do not have permission to kill race instances.", true)
        return
    end
    local killedInstance, killError = RacingSystem.Server.Instances.killRaceInstanceByName(raceName)

    if not killedInstance then
        RacingSystem.Server.Logging.logLevelOne(("%s could not kill race '%s'. Reason: %s."):format(
            RacingSystem.Server.Logging.resolvePlayerLogLabel(src),
            tostring(raceName),
            tostring(killError or 'unknown error')
        ))
        RacingSystem.Server.Logging.notifyPlayer(src, killError or 'Could not kill race instance.', true)
        return
    end

    RacingSystem.Server.Logging.auditLog("killRace", src, ("killed race '%s' (instance %s)"):format(
        tostring(raceName),
        tostring(killedInstance.id or 'unknown')
    ))
    RacingSystem.Server.Snapshot.broadcastInstanceStandings(killedInstance)
    RacingSystem.Server.Snapshot.broadcastInstanceList()
end)

AddEventHandler('playerDropped', function()
    if RacingSystem.Server.Snapshot.removeEntrantFromAllRaceInstances(source, 'player_dropped') then
        RacingSystem.Server.Logging.auditLog("playerDroppedRaceCleanup", source, "disconnected and was removed from one or more active race instances")
        RacingSystem.Server.Snapshot.broadcastInstanceList()
    end
end)

AddEventHandler('playerJoining', function()
    local src = source
    SetTimeout(1000, function()
        RacingSystem.Server.Snapshot.sendInitialState(src)
    end)
end)






