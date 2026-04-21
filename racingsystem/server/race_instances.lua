RacingSystem = RacingSystem or {}
RacingSystem.Server = RacingSystem.Server or {}

local function resetRaceInstanceProgress(instance)
    if type(instance) ~= 'table' then
        return
    end

    instance.finishedAt = nil
    instance.startedAt = nil

    for _, entrant in ipairs(instance.entrants or {}) do
        RacingSystem.Server.Snapshot.resetEntrantProgress(entrant)
        entrant.currentCheckpoint = RacingSystem.Server.Snapshot.getPreRaceExpectedCheckpoint(instance)
    end
end

local function invokeRaceInstance(ownerSource, raceName, lapCount)
    if not RacingSystem.Config.playerCanInvokeMultipleRaces then
        local numericOwnerSource = tonumber(ownerSource) or 0
        for _, existingInstance in pairs(RacingSystem.Server.State.raceInstancesById) do
            if tonumber(existingInstance and existingInstance.owner) == numericOwnerSource then
                return nil, 'You already own an active race instance.'
            end
        end
    end

    local invokeRequestName = raceName
    local invokeLookupName = nil
    local invokeSourceType = nil
    local invokeRaceId = nil
    local invokeTrafficDensity = 0.0
    local invokeLateJoinPercent = nil
    if type(raceName) == 'table' then
        local requestPayload = raceName
        invokeRequestName = RacingSystem.Trim(requestPayload.name or requestPayload.lookupName or '')
        invokeLookupName = RacingSystem.NormalizeRaceName(requestPayload.lookupName)
        invokeRaceId = RacingSystem.Trim(requestPayload.raceId or ''):gsub('[^%w_-]', '')
        if invokeRaceId == '' then
            invokeRaceId = nil
        end
        local normalizedSourceType = tostring(requestPayload.sourceType or ''):lower()
        if normalizedSourceType == 'custom' or normalizedSourceType == 'online' then
            invokeSourceType = normalizedSourceType
        end
        local requestedTrafficDensity = tonumber(requestPayload.trafficDensity)
        if requestedTrafficDensity ~= nil then
            if requestedTrafficDensity < 0.0 then
                requestedTrafficDensity = 0.0
            elseif requestedTrafficDensity > 1.0 then
                requestedTrafficDensity = 1.0
            end
            invokeTrafficDensity = requestedTrafficDensity
        else
            local normalizedTrafficMode = tostring(requestPayload.trafficMode or 'none'):lower()
            if normalizedTrafficMode == 'low' then
                invokeTrafficDensity = 0.35
            elseif normalizedTrafficMode == 'high' then
                invokeTrafficDensity = 0.7
            elseif normalizedTrafficMode == 'full' or normalizedTrafficMode == 'normal' then
                invokeTrafficDensity = 1.0
            else
                invokeTrafficDensity = 0.0
            end
        end
        local lateJoinPercent = tonumber(requestPayload.lateJoinProgressLimitPercent)
        if lateJoinPercent and lateJoinPercent >= 0 and lateJoinPercent <= 100 then
            invokeLateJoinPercent = lateJoinPercent
        end
    end
    RacingSystem.Server.Logging.logVerbose(("[invoke] owner=%s rawType=%s request='%s' lookup='%s' sourceType='%s' raceId='%s' laps=%s trafficDensity=%.2f"):format(
        tostring(ownerSource),
        tostring(type(raceName)),
        tostring(invokeRequestName),
        tostring(invokeLookupName),
        tostring(invokeSourceType or 'nil'),
        tostring(invokeRaceId or 'nil'),
        tostring(lapCount),
        invokeTrafficDensity
    ))

    if RacingSystem.Trim(invokeRequestName) == '' then
        return nil, 'That saved race does not exist.'
    end

    local customRace = nil
    local onlineRace = nil
    if invokeSourceType == 'online' then
        if invokeRaceId then
            onlineRace = RacingSystem.Server.Repository.loadBundledOnlineRace(invokeRaceId)
        end
        if not onlineRace then
            onlineRace = RacingSystem.Server.Repository.loadBundledOnlineRace(invokeRequestName)
        end
        if not onlineRace and invokeLookupName then
            onlineRace = RacingSystem.Server.Repository.loadBundledOnlineRace(invokeLookupName)
        end
        if not onlineRace then
            customRace = RacingSystem.Server.Repository.loadCustomRace(invokeRequestName)
        end
    elseif invokeSourceType == 'custom' then
        customRace = RacingSystem.Server.Repository.loadCustomRace(invokeRequestName)
        if not customRace and invokeLookupName then
            customRace = RacingSystem.Server.Repository.loadCustomRace(invokeLookupName)
        end
        if not customRace then
            if invokeRaceId then
                onlineRace = RacingSystem.Server.Repository.loadBundledOnlineRace(invokeRaceId)
            end
            if not onlineRace then
                onlineRace = RacingSystem.Server.Repository.loadBundledOnlineRace(invokeRequestName)
            end
        end
    else
        customRace = RacingSystem.Server.Repository.loadCustomRace(invokeRequestName)
        if invokeRaceId then
            onlineRace = RacingSystem.Server.Repository.loadBundledOnlineRace(invokeRaceId)
        end
        if not onlineRace then
            onlineRace = RacingSystem.Server.Repository.loadBundledOnlineRace(invokeRequestName)
        end
    end
    RacingSystem.Server.Logging.logVerbose(("[invoke] resolution result custom=%s online=%s (request='%s', raceId='%s')"):format(
        tostring(customRace ~= nil),
        tostring(onlineRace ~= nil),
        tostring(invokeRequestName),
        tostring(invokeRaceId or 'nil')
    ))
    local instanceName
    local definitionId = nil
    local definitionName = nil
    local createdAt = os.time()
    local checkpoints = {}
    local props = {}
    local modelHides = {}
    local raceMetadata = {}
    local sourceType = 'saved'
    local sourceName = nil
    local laps = RacingSystem.Server.Parsing.sanitizeLapCount(lapCount)

    if customRace then
        instanceName = customRace.name
        definitionName = customRace.name
        checkpoints = RacingSystem.Server.Catalog.cloneCheckpoints(customRace.checkpoints)
        props = RacingSystem.Server.Snapshot.cloneOnlineRaceProps(customRace.props)
        modelHides = RacingSystem.Server.Snapshot.cloneOnlineRaceModelHides(customRace.modelHides)
        raceMetadata = RacingSystem.Server.Catalog.cloneMissionValue(customRace.raceMetadata)
        sourceType = 'custom'
        sourceName = customRace.name
        RacingSystem.Server.Catalog.registerKnownRaceDefinition(customRace.name, 'custom')
    elseif onlineRace then
        instanceName = onlineRace.name
        definitionName = onlineRace.name
        checkpoints = RacingSystem.Server.Catalog.cloneCheckpoints(onlineRace.checkpoints)
        props = RacingSystem.Server.Snapshot.cloneOnlineRaceProps(onlineRace.props)
        modelHides = RacingSystem.Server.Snapshot.cloneOnlineRaceModelHides(onlineRace.modelHides)
        raceMetadata = RacingSystem.Server.Catalog.cloneMissionValue(onlineRace.raceMetadata)
        sourceType = 'online'
        sourceName = onlineRace.name
        RacingSystem.Server.Catalog.registerKnownRaceDefinition(onlineRace.name, 'online', onlineRace.ugcId or onlineRace.fileName)
    else
        return nil, 'That saved race does not exist.'
    end

    if RacingSystem.Server.Snapshot.findRaceInstanceByName(instanceName) then
        return nil, 'That race already has an active instance.'
    end

    local id = tonumber(RacingSystem.Server.State.nextRaceInstanceId) or 1
    RacingSystem.Server.State.nextRaceInstanceId = id + 1

    local instance = {
        id = id,
        name = instanceName,
        definitionId = definitionId,
        definitionName = definitionName,
        sourceType = sourceType,
        sourceName = sourceName,
        pointToPoint = RacingSystem.Server.Snapshot.isPointToPointByCheckpointDistance(checkpoints),
        trafficDensity = invokeTrafficDensity,
        lateJoinProgressLimitPercent = invokeLateJoinPercent,
        laps = laps,
        owner = tonumber(ownerSource) or 0,
        state = RacingSystem.States.idle,
        createdAt = createdAt,
        invokedAt = os.time(),
        startAt = nil,
        startedAt = nil,
        bestLapTimeMs = nil,
        finishedAt = nil,
        checkpoints = checkpoints,
        raceMetadata = raceMetadata,
        props = props,
        modelHides = modelHides,
        entrants = {},
        entrantStateById = {},
        standingsVersion = 0,
    }

    local numericOwnerSource = tonumber(ownerSource) or 0
    if numericOwnerSource > 0 then
        instance.entrants = { RacingSystem.Server.Snapshot.buildEntrant(numericOwnerSource, instance) }
        RacingSystem.Server.Snapshot.upsertEntrantState(instance, instance.entrants[1])
    end

    RacingSystem.Server.State.raceInstancesById[id] = instance
    RacingSystem.Server.Snapshot.indexRaceInstanceName(instance)
    RacingSystem.Server.Logging.setRaceStateBag(instance)
    return instance
end

local function killRaceInstanceByName(instanceName)
    local instance = RacingSystem.Server.Snapshot.findRaceInstanceByName(instanceName)
    if not instance then
        return nil, 'That race instance does not exist.'
    end

    local previousState = instance.state
    if RacingSystem.Server.Logging.isLifecycleTransitionAllowed(previousState, 'terminated') then
        RacingSystem.Server.Logging.logLifecycleEvent('killRace', instance, nil, 0, previousState, 'terminated', 'killed_by_command')
    end
    RacingSystem.Server.Logging.clearRaceStateBagByInstanceId(instance.id)
    RacingSystem.Server.Snapshot.removeRaceInstanceNameIndex(instance)
    RacingSystem.Server.State.raceInstancesById[instance.id] = nil
    return instance
end

local function killRaceInstanceById(instanceId)
    local numericInstanceId = tonumber(instanceId) or -1
    local instance = RacingSystem.Server.State.raceInstancesById[numericInstanceId]
    if not instance then
        return nil, 'That race instance does not exist.'
    end

    local previousState = instance.state
    if RacingSystem.Server.Logging.isLifecycleTransitionAllowed(previousState, 'terminated') then
        RacingSystem.Server.Logging.logLifecycleEvent('killRace', instance, nil, 0, previousState, 'terminated', 'killed_by_command')
    end
    RacingSystem.Server.Logging.clearRaceStateBagByInstanceId(instance.id)
    RacingSystem.Server.Snapshot.removeRaceInstanceNameIndex(instance)
    RacingSystem.Server.State.raceInstancesById[instance.id] = nil
    return instance
end

local function joinResolvedInstance(source, instance)
    if not instance then
        return nil, 'That race instance does not exist.'
    end

    if #(instance.checkpoints or {}) == 0 then
        return nil, 'That race instance has no checkpoints.'
    end

    if instance.state == RacingSystem.States.running then
        local canJoin, joinError = RacingSystem.Server.Snapshot.canJoinMidRace(instance)
        if not canJoin then
            RacingSystem.Server.State.reliabilityCounters.rejectedJoinRunning = RacingSystem.Server.State.reliabilityCounters.rejectedJoinRunning + 1
            if RacingSystem.Server.Logging.shouldLogLifecycleAnomaly('joinRace', source, instance.id) then
                RacingSystem.Server.Logging.logLifecycleEvent('joinRace', instance, nil, source, instance.state, instance.state, 'late_join_rejected_running')
            end
            return nil, joinError or 'Cannot join a race that is already running.'
        end
    elseif instance.state ~= RacingSystem.States.idle and instance.state ~= RacingSystem.States.staging then
        if RacingSystem.Server.Logging.shouldLogLifecycleAnomaly('joinRace', source, instance.id) then
            RacingSystem.Server.Logging.logLifecycleEvent('joinRace', instance, nil, source, instance.state, instance.state, 'join_rejected_invalid_state')
        end
        return nil, 'That race cannot be joined right now.'
    end

    local existingInstance = RacingSystem.Server.Snapshot.findRaceInstanceByEntrant(source)
    if existingInstance and existingInstance.id == instance.id then
        return instance, nil
    end

    if existingInstance then
        local removedEntrant = RacingSystem.Server.Snapshot.removeEntrantFromRaceInstance(existingInstance, source)
        RacingSystem.Server.Snapshot.cleanupInstanceAfterEntrantRemoval(existingInstance, source, removedEntrant, 'join_transfer')
    end

    instance.entrants = instance.entrants or {}
    local newEntrant = RacingSystem.Server.Snapshot.buildEntrant(source, instance)
    if instance.state == RacingSystem.States.running then
        local lastPlaceEntrant = RacingSystem.Server.Snapshot.getLastPlaceEntrant(instance)
        if lastPlaceEntrant then
            newEntrant = RacingSystem.Server.Snapshot.inheritLastPlaceProgress(newEntrant, lastPlaceEntrant)
        end
    end

    instance.entrants[#instance.entrants + 1] = newEntrant
    RacingSystem.Server.Snapshot.upsertEntrantState(instance, newEntrant)
    return instance, nil
end

local function joinRaceInstanceById(source, instanceId)
    return joinResolvedInstance(source, RacingSystem.Server.State.raceInstancesById[tonumber(instanceId) or -1])
end

local function leaveCurrentRaceInstance(source)
    local instance = RacingSystem.Server.Snapshot.findRaceInstanceByEntrant(source)
    if not instance then
        return nil, 'You are not currently joined to a race instance.'
    end

    local removedEntrant = RacingSystem.Server.Snapshot.removeEntrantFromRaceInstance(instance, source)
    RacingSystem.Server.Snapshot.cleanupInstanceAfterEntrantRemoval(instance, source, removedEntrant, 'leave_race')

    return instance, nil
end

local function restartRaceInstanceForSource(source)
    local instance = RacingSystem.Server.Snapshot.findRaceInstanceByEntrant(source)
    if not instance then
        return nil, 'You are not currently joined to a race instance.'
    end

    local numericSource = tonumber(source) or 0
    local ownerSource = tonumber(instance.owner) or 0
    if ownerSource ~= numericSource then
        return nil, 'Only the host can restart this race.'
    end

    if #(instance.entrants or {}) == 0 then
        return nil, 'No racers are joined to that instance.'
    end

    resetRaceInstanceProgress(instance)
    instance.startAt = nil
    instance.startedAt = nil
    instance.finishedAt = nil
    instance.lastStartRequestedAt = nil
    instance.lastStartRequestedBy = nil

    if instance.state ~= RacingSystem.States.idle then
        local transitionOk, transitionError = RacingSystem.Server.Logging.setRaceInstanceState(
            instance,
            RacingSystem.States.idle,
            'restartRace',
            source,
            nil,
            'manual_restart'
        )
        if not transitionOk then
            return nil, transitionError
        end
    end

    return instance, nil
end

local function finishRaceInstanceForSource(source)
    local instance = RacingSystem.Server.Snapshot.findRaceInstanceByEntrant(source)
    if not instance then
        return nil, 'You are not currently joined to a race instance.'
    end

    if instance.state == RacingSystem.States.finished then
        return nil, 'That race is already finished.'
    end

    if instance.state ~= RacingSystem.States.running and instance.state ~= RacingSystem.States.staging then
        if RacingSystem.Server.Logging.shouldLogLifecycleAnomaly('finishRace', source, instance.id) then
            RacingSystem.Server.Logging.logLifecycleEvent('finishRace', instance, nil, source, instance.state, instance.state, 'finish_rejected_invalid_state')
        end
        return nil, 'That race is not running.'
    end

    local now = GetGameTimer()
    local transitionOk, transitionError = RacingSystem.Server.Logging.setRaceInstanceState(
        instance,
        RacingSystem.States.finished,
        'finishRace',
        source,
        nil,
        'manual_finish'
    )
    if not transitionOk then
        return nil, transitionError
    end
    instance.finishedAt = now
    instance.startAt = nil

    return instance, nil
end

local function broadcastLapCompleted(instance, entrant, lapNumber, lapTimeMs, totalTimeMs, finished, bestLapTimeMs, bestLapDeltaMs)
    if type(instance) ~= 'table' or type(entrant) ~= 'table' then
        return
    end

    local totalLaps = math.max(1, tonumber(instance.laps) or 1)

    for _, otherEntrant in ipairs(instance.entrants or {}) do
        local entrantSource = tonumber(otherEntrant.source) or 0
        if entrantSource > 0 then
            TriggerClientEvent('racingsystem:race:lapCompleted', entrantSource, {
                instanceId = instance.id,
                entrantId = tostring(entrant.entrantId or ''),
                playerSource = tonumber(entrant.source) or 0,
                playerName = tostring(entrant.name or ('Player %s'):format(tostring(entrant.source or '?'))),
                lapNumber = tonumber(lapNumber) or 1,
                totalLaps = totalLaps,
                lapTimeMs = tonumber(lapTimeMs) or 0,
                totalTimeMs = tonumber(totalTimeMs) or 0,
                bestLapTimeMs = tonumber(bestLapTimeMs) or 0,
                bestLapDeltaMs = tonumber(bestLapDeltaMs) or 0,
                finished = finished == true,
            })
        end
    end
end

local function emitStableLapTimeIfReady(instance, entrant, lapNumber, lapTimeMs)
    return
end


local function handleCheckpointPassed(source, instanceId, checkpointIndex, lapTimingPayload)
    local instance = RacingSystem.Server.State.raceInstancesById[tonumber(instanceId) or -1]
    if not instance then
        RacingSystem.Server.Logging.logLevelOne(("%s sent a checkpoint update for missing instance %s."):format(
            RacingSystem.Server.Logging.resolvePlayerLogLabel(source),
            tostring(instanceId)
        ))
        return nil, 'That race instance no longer exists.'
    end

    if instance.state ~= RacingSystem.States.running then
        return nil, 'That race is not running.'
    end

    local entrant = RacingSystem.Server.Snapshot.findEntrantInRaceInstance(instance, source)
    if not entrant then
        return nil, 'You are not joined to that race instance.'
    end

    if tonumber(entrant.finishedAt) then
        return nil, 'You already finished that race.'
    end

    local expectedCheckpoint = tonumber(entrant.currentCheckpoint) or 1
    local reportedCheckpoint = tonumber(checkpointIndex) or 0
    if reportedCheckpoint ~= expectedCheckpoint then
        if RacingSystem.Server.Logging.shouldLogCheckpointAnomaly(source, instance.id) then
            RacingSystem.Server.Logging.logLevelOne(("%s sent checkpoint %s out of order in race '%s' (instance %s). Expected checkpoint %s."):format(
                RacingSystem.Server.Logging.resolvePlayerLogLabel(source),
                tostring(reportedCheckpoint),
                tostring(instance.name or 'unknown'),
                tostring(instance.id),
                tostring(expectedCheckpoint)
            ))
        end
        return nil, 'Ignored out-of-order checkpoint pass.'
    end

    local totalCheckpoints = #(instance.checkpoints or {})
    if totalCheckpoints == 0 then
        RacingSystem.Server.Logging.logError(("Race '%s' (instance %s) has no checkpoints while processing a checkpoint pass."):format(
            tostring(instance.name or 'unknown'),
            tostring(instance.id)
        ))
        return nil, 'That race instance has no checkpoints.'
    end

    local now = GetGameTimer()
    local totalLaps = math.max(1, tonumber(instance.laps) or 1)
    local maxProgress = math.max(totalCheckpoints, totalCheckpoints * totalLaps)
    entrant.checkpointsPassed = math.min(maxProgress, (tonumber(entrant.checkpointsPassed) or 0) + 1)
    entrant.lastCheckpointAt = now

    local currentLap = math.max(1, tonumber(entrant.currentLap) or 1)
    local lapTriggerCheckpoint = RacingSystem.Server.Snapshot.getLapTriggerCheckpoint(instance, totalCheckpoints, totalLaps)
    RacingSystem.Server.Logging.logVerbose(("[startfinish] pass player=%s race='%s' instance=%s expected=%s reported=%s lap=%s/%s lapTrigger=%s startCheckpoint=%s totalCheckpoints=%s"):format(
        RacingSystem.Server.Logging.resolveReadablePlayerName(source, entrant),
        tostring(instance.name or 'unknown'),
        tostring(instance.id),
        tostring(expectedCheckpoint),
        tostring(reportedCheckpoint),
        tostring(currentLap),
        tostring(totalLaps),
        tostring(lapTriggerCheckpoint),
        tostring(RacingSystem.Server.Snapshot.getRaceStartCheckpoint(instance)),
        tostring(totalCheckpoints)
    ))

    if reportedCheckpoint == lapTriggerCheckpoint then
        local currentLapTimeMs = tonumber(type(lapTimingPayload) == 'table' and lapTimingPayload.lapTimeMs) or nil
        local currentTotalTimeMs = tonumber(type(lapTimingPayload) == 'table' and lapTimingPayload.totalTimeMs) or nil

        if currentLapTimeMs ~= nil then
            currentLapTimeMs = math.max(0, currentLapTimeMs)
            entrant.lapTimes = entrant.lapTimes or {}
            entrant.lapTimes[#entrant.lapTimes + 1] = currentLapTimeMs
        end

        if currentLap >= totalLaps then
            entrant.currentCheckpoint = totalCheckpoints + 1
            entrant.finishedAt = now
            entrant.totalTimeMs = currentTotalTimeMs and math.max(0, currentTotalTimeMs) or nil
        else
            entrant.currentLap = currentLap + 1
            if instance.pointToPoint == true then
                entrant.currentCheckpoint = totalCheckpoints
            else
                entrant.currentCheckpoint = 1
            end
        end

        if currentLapTimeMs ~= nil then
            local previousBestLapTimeMs = tonumber(instance.bestLapTimeMs)
            local bestLapDeltaMs = 0

            if previousBestLapTimeMs then
                bestLapDeltaMs = currentLapTimeMs - previousBestLapTimeMs
                if currentLapTimeMs < previousBestLapTimeMs then
                    instance.bestLapTimeMs = currentLapTimeMs
                end
            else
                instance.bestLapTimeMs = currentLapTimeMs
            end

            broadcastLapCompleted(
                instance,
                entrant,
                currentLap,
                currentLapTimeMs,
                currentTotalTimeMs or 0,
                currentLap >= totalLaps,
                tonumber(instance.bestLapTimeMs) or currentLapTimeMs,
                bestLapDeltaMs
            )
            RacingSystem.Server.Logging.logVerbose(("%s finished lap %d/%d in race '%s' (instance %s): lap=%dms, total=%s, best=%s, delta=%s."):format(
                RacingSystem.Server.Logging.resolveReadablePlayerName(source, entrant),
                currentLap,
                totalLaps,
                tostring(instance.name or 'unknown'),
                tostring(instance.id),
                currentLapTimeMs,
                tostring(currentTotalTimeMs or 0),
                tostring(tonumber(instance.bestLapTimeMs) or currentLapTimeMs),
                tostring(bestLapDeltaMs)
            ))
            emitStableLapTimeIfReady(instance, entrant, currentLap, currentLapTimeMs)

            local entrantSource = tonumber(entrant.source) or 0
            local isFirstEntrantLap = #(entrant.lapTimes or {}) <= 1
            if entrantSource > 0 and not isFirstEntrantLap then
                TriggerClientEvent('racingsystem:race:lapAnnotation', entrantSource, {
                    isInstanceBest = bestLapDeltaMs < 0 or previousBestLapTimeMs == nil,
                    deltaMs = bestLapDeltaMs,
                })
            end
        end
    else
        local nextCheckpoint = reportedCheckpoint + 1
        if nextCheckpoint > totalCheckpoints then
            nextCheckpoint = 1
        end
        entrant.currentCheckpoint = nextCheckpoint
    end

    local allFinished = #(instance.entrants or {}) > 0
    for _, otherEntrant in ipairs(instance.entrants or {}) do
        if tonumber(otherEntrant.finishedAt) == nil then
            allFinished = false
            break
        end
    end

    if allFinished then
        local transitionOk = RacingSystem.Server.Logging.setRaceInstanceState(
            instance,
            RacingSystem.States.finished,
            'autoFinishRace',
            source,
            entrant,
            'all_entrants_finished'
        )
        if transitionOk then
            instance.finishedAt = now
            instance.startAt = nil
        else
            if RacingSystem.Server.Logging.shouldLogLifecycleAnomaly('autoFinishRace', source, instance.id) then
                RacingSystem.Server.Logging.logLifecycleEvent('autoFinishRace', instance, entrant, source, instance.state, RacingSystem.States.finished, 'failed_transition')
            end
        end
    end

    return instance, nil
end

RacingSystem.Server.Instances.resetRaceInstanceProgress = resetRaceInstanceProgress
RacingSystem.Server.Instances.invokeRaceInstance = invokeRaceInstance
RacingSystem.Server.Instances.killRaceInstanceByName = killRaceInstanceByName
RacingSystem.Server.Instances.killRaceInstanceById = killRaceInstanceById
RacingSystem.Server.Instances.joinResolvedInstance = joinResolvedInstance
RacingSystem.Server.Instances.joinRaceInstanceById = joinRaceInstanceById
RacingSystem.Server.Instances.leaveCurrentRaceInstance = leaveCurrentRaceInstance
RacingSystem.Server.Instances.restartRaceInstanceForSource = restartRaceInstanceForSource
RacingSystem.Server.Instances.finishRaceInstanceForSource = finishRaceInstanceForSource
RacingSystem.Server.Instances.broadcastLapCompleted = broadcastLapCompleted
RacingSystem.Server.Instances.emitStableLapTimeIfReady = emitStableLapTimeIfReady
RacingSystem.Server.Instances.handleCheckpointPassed = handleCheckpointPassed


