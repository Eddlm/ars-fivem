RacingSystem = RacingSystem or {}
RacingSystem.Server = RacingSystem.Server or {}
RacingSystem.Server.Snapshot = RacingSystem.Server.Snapshot or {}

local function cloneOnlineRaceProps(props)
    local cloned = {}

    for index, prop in ipairs(type(props) == 'table' and props or {}) do
        cloned[index] = {
            model = tonumber(prop.model) or 0,
            x = tonumber(prop.x) or 0.0,
            y = tonumber(prop.y) or 0.0,
            z = tonumber(prop.z) or 0.0,
            rotX = tonumber(prop.rotX) or 0.0,
            rotY = tonumber(prop.rotY) or 0.0,
            rotZ = tonumber(prop.rotZ) or 0.0,
            heading = tonumber(prop.heading) or 0.0,
            textureVariant = tonumber(prop.textureVariant) or -1,
            lodDistance = tonumber(prop.lodDistance) or -1,
            speedAdjustment = tonumber(prop.speedAdjustment) or -1,
        }
    end

    return cloned
end

local function cloneOnlineRaceModelHides(modelHides)
    local cloned = {}

    for index, modelHide in ipairs(type(modelHides) == 'table' and modelHides or {}) do
        cloned[index] = {
            model = tonumber(modelHide.model) or 0,
            x = tonumber(modelHide.x) or 0.0,
            y = tonumber(modelHide.y) or 0.0,
            z = tonumber(modelHide.z) or 0.0,
            radius = tonumber(modelHide.radius) or 10.0,
        }
    end

    return cloned
end

local function cloneNumberArray(values)
    local cloned = {}

    for index, value in ipairs(type(values) == 'table' and values or {}) do
        cloned[index] = tonumber(value) or 0
    end

    return cloned
end

local function cloneEntrant(entrant)
    if type(entrant) ~= 'table' then
        return nil
    end

    return {
        entrantId = tostring(entrant.entrantId or ''),
        source = tonumber(entrant.source) or 0,
        name = entrant.name,
        joinedAt = tonumber(entrant.joinedAt) or 0,
        currentCheckpoint = tonumber(entrant.currentCheckpoint) or 1,
        currentLap = tonumber(entrant.currentLap) or 1,
        checkpointsPassed = tonumber(entrant.checkpointsPassed) or 0,
        lastCheckpointAt = tonumber(entrant.lastCheckpointAt) or 0,
        lapStartedAt = tonumber(entrant.lapStartedAt) or 0,
        lapTimes = cloneNumberArray(entrant.lapTimes),
        totalTimeMs = tonumber(entrant.totalTimeMs) or nil,
        finishedAt = tonumber(entrant.finishedAt) or nil,
        position = tonumber(entrant.position) or nil,
    }
end

local function getEntrantStateKeyFromEntrant(entrant)
    if type(entrant) ~= 'table' then
        return nil
    end

    local entrantId = tostring(entrant.entrantId or '')
    if entrantId ~= '' then
        return ('id:%s'):format(entrantId)
    end

    local source = tonumber(entrant.source)
    if source and source > 0 then
        return ('src:%s'):format(source)
    end

    return nil
end

local function getEntrantStateKeyFromSource(source)
    local numericSource = tonumber(source)
    if not numericSource or numericSource <= 0 then
        return nil
    end

    return ('src:%s'):format(numericSource)
end

local function ensureEntrantStateMap(instance)
    if type(instance) ~= 'table' then
        return {}
    end

    if type(instance.entrantStateById) == 'table' then
        return instance.entrantStateById
    end

    local map = {}
    for _, entrant in ipairs(type(instance.entrants) == 'table' and instance.entrants or {}) do
        local entrantKey = getEntrantStateKeyFromEntrant(entrant)
        if entrantKey then
            map[entrantKey] = entrant
        end

        local sourceKey = getEntrantStateKeyFromSource(entrant.source)
        if sourceKey then
            map[sourceKey] = entrant
        end
    end

    instance.entrantStateById = map
    return map
end

local function upsertEntrantState(instance, entrant)
    if type(instance) ~= 'table' or type(entrant) ~= 'table' then
        return
    end

    local map = ensureEntrantStateMap(instance)
    local entrantKey = getEntrantStateKeyFromEntrant(entrant)
    if entrantKey then
        map[entrantKey] = entrant
    end

    local sourceKey = getEntrantStateKeyFromSource(entrant.source)
    if sourceKey then
        map[sourceKey] = entrant
    end
end

local function removeEntrantStateBySource(instance, source)
    if type(instance) ~= 'table' then
        return
    end

    local map = ensureEntrantStateMap(instance)
    local sourceKey = getEntrantStateKeyFromSource(source)
    if not sourceKey then
        return
    end

    local entrant = map[sourceKey]
    map[sourceKey] = nil

    local entrantKey = getEntrantStateKeyFromEntrant(entrant)
    if entrantKey then
        map[entrantKey] = nil
    end
end

local function listEntrantsFromState(instance)
    if type(instance) ~= 'table' then
        return {}
    end

    local map = ensureEntrantStateMap(instance)
    local entrants = {}
    local seen = {}
    for _, entrant in pairs(map) do
        if type(entrant) == 'table' then
            local uniqueKey = tostring(entrant.entrantId or '')
            if uniqueKey == '' then
                uniqueKey = ('src:%s'):format(tostring(tonumber(entrant.source) or 0))
            end

            if not seen[uniqueKey] then
                seen[uniqueKey] = true
                entrants[#entrants + 1] = entrant
            end
        end
    end

    return entrants
end

local function resetEntrantProgress(entrant)
    if type(entrant) ~= 'table' then
        return
    end

    entrant.currentCheckpoint = 1
    entrant.currentLap = 1
    entrant.checkpointsPassed = 0
    entrant.lastCheckpointAt = 0
    entrant.lapStartedAt = 0
    entrant.lapTimes = {}
    entrant.totalTimeMs = nil
    entrant.finishedAt = nil
    entrant.position = nil
    entrant.lapIncrementUnlocked = false
end

local function getRaceStartCheckpoint(instance)
    local checkpoints = type(instance) == 'table' and type(instance.checkpoints) == 'table' and instance.checkpoints or {}
    local checkpointCount = math.max(0, #checkpoints)
    if checkpointCount <= 1 then
        return 1
    end

    if type(instance) == 'table' and instance.pointToPoint == true then
        return 1
    end

    return checkpointCount - 1
end

local function getLapTriggerCheckpoint(instance, totalCheckpoints, totalLaps)
    local checkpointCount = math.max(0, tonumber(totalCheckpoints) or 0)
    if checkpointCount <= 1 then
        return 1
    end

    return checkpointCount
end

local function getNextCheckpointIndex(totalCheckpoints, currentCheckpoint)
    local checkpointCount = math.max(1, math.floor(tonumber(totalCheckpoints) or 1))
    local index = math.max(1, math.floor(tonumber(currentCheckpoint) or 1))
    local nextIndex = index + 1
    if nextIndex > checkpointCount then
        nextIndex = 1
    end
    return nextIndex
end

local function getPreRaceExpectedCheckpoint(instance)
    local checkpoints = type(instance) == 'table' and type(instance.checkpoints) == 'table' and instance.checkpoints or {}
    local checkpointCount = math.max(1, #checkpoints)
    local startCheckpoint = getRaceStartCheckpoint(instance)
    if type(instance) == 'table' and instance.pointToPoint == true then
        return startCheckpoint
    end
    return getNextCheckpointIndex(checkpointCount, startCheckpoint)
end

local function isPointToPointByCheckpointDistance(checkpoints)
    local list = type(checkpoints) == 'table' and checkpoints or {}
    local total = #list
    if total <= 1 then
        return false
    end

    local first = list[1]
    local last = list[total]
    if type(first) ~= 'table' or type(last) ~= 'table' then
        return false
    end

    local firstX = tonumber(first.x) or 0.0
    local firstY = tonumber(first.y) or 0.0
    local lastX = tonumber(last.x) or 0.0
    local lastY = tonumber(last.y) or 0.0
    local dx = lastX - firstX
    local dy = lastY - firstY
    local distance2D = math.sqrt((dx * dx) + (dy * dy))
    return distance2D > (tonumber((RacingSystem.Server.State.config or {}).pointToPointAutodetectDistanceMeters) or 500.0)
end

local function buildEntrant(source, instance)
    local numericSource = tonumber(source) or 0

    return {
        entrantId = RacingSystem.Server.Logging.buildEntrantId(numericSource),
        source = numericSource,
        name = GetPlayerName(numericSource) or ('Player %s'):format(numericSource),
        joinedAt = os.time(),
        currentCheckpoint = getPreRaceExpectedCheckpoint(instance),
        currentLap = 1,
        checkpointsPassed = 0,
        lastCheckpointAt = 0,
        lapStartedAt = 0,
        lapTimes = {},
        totalTimeMs = nil,
        finishedAt = nil,
        position = nil,
        lapIncrementUnlocked = false,
    }
end

local function indexRaceInstanceName(instance)
    local normalizedName = RacingSystem.NormalizeRaceName(instance and instance.name)
    if normalizedName then
        RacingSystem.Server.State.raceInstanceIdsByName[normalizedName] = instance.id
    end
end

local function removeRaceInstanceNameIndex(instance)
    local normalizedName = RacingSystem.NormalizeRaceName(instance and instance.name)
    if normalizedName and RacingSystem.Server.State.raceInstanceIdsByName[normalizedName] == instance.id then
        RacingSystem.Server.State.raceInstanceIdsByName[normalizedName] = nil
    end
end

local function getEntrantSortScore(entrant, instance)
    if type(entrant) ~= 'table' then
        return 0
    end

    local checkpoints = type(instance) == 'table' and type(instance.checkpoints) == 'table' and instance.checkpoints or {}
    local totalCheckpoints = math.max(1, #checkpoints)
    local currentLap = math.max(1, math.floor(tonumber(entrant.currentLap) or 1))
    local currentCheckpoint = math.max(1, math.floor(tonumber(entrant.currentCheckpoint) or 1))
    local currentLapProgress = math.max(0, math.min(totalCheckpoints, currentCheckpoint - 1))
    local scalarProgress = ((currentLap - 1) * totalCheckpoints) + currentLapProgress
    local absolutePassCount = math.max(0, math.floor(tonumber(entrant.checkpointsPassed) or 0))
    return math.max(scalarProgress, absolutePassCount)
end

local function buildOrderedEntrants(instance)
    local ordered = {}
    local stateMap = ensureEntrantStateMap(instance)

    for _, entrant in ipairs(listEntrantsFromState(instance)) do
        if tostring(entrant.entrantId or '') == '' then
            entrant.entrantId = RacingSystem.Server.Logging.buildEntrantId(tonumber(entrant.source) or 0)
        end
        local clonedEntrant = cloneEntrant(entrant)
        if clonedEntrant then
            ordered[#ordered + 1] = clonedEntrant
        end
    end

    table.sort(ordered, function(a, b)
        local aFinishedAt = tonumber(a.finishedAt)
        local bFinishedAt = tonumber(b.finishedAt)

        if aFinishedAt and bFinishedAt and aFinishedAt ~= bFinishedAt then
            return aFinishedAt < bFinishedAt
        end

        if aFinishedAt ~= nil and bFinishedAt == nil then
            return true
        end

        if aFinishedAt == nil and bFinishedAt ~= nil then
            return false
        end

        local aScore = getEntrantSortScore(a, instance)
        local bScore = getEntrantSortScore(b, instance)
        if aScore ~= bScore then
            return aScore > bScore
        end

        local aLastCheckpointAt = tonumber(a.lastCheckpointAt) or 0
        local bLastCheckpointAt = tonumber(b.lastCheckpointAt) or 0
        if aLastCheckpointAt ~= bLastCheckpointAt then
            if aLastCheckpointAt == 0 then
                return false
            end

            if bLastCheckpointAt == 0 then
                return true
            end

            return aLastCheckpointAt < bLastCheckpointAt
        end

        local aJoinedAt = tonumber(a.joinedAt) or 0
        local bJoinedAt = tonumber(b.joinedAt) or 0
        if aJoinedAt ~= bJoinedAt then
            return aJoinedAt < bJoinedAt
        end

        return tostring(a.entrantId or '') < tostring(b.entrantId or '')
    end)

    for index, entrant in ipairs(ordered) do
        entrant.position = index
        local stateKey = getEntrantStateKeyFromEntrant(entrant)
        if stateKey and type(stateMap[stateKey]) == 'table' then
            stateMap[stateKey].position = index
        end

        local sourceKey = getEntrantStateKeyFromSource(entrant.source)
        if sourceKey and type(stateMap[sourceKey]) == 'table' then
            stateMap[sourceKey].position = index
        end
    end

    return ordered
end

local function buildInstanceStandingsPayload(instance)
    if type(instance) ~= 'table' then
        return nil
    end

    return {
        instanceId = tonumber(instance.id) or -1,
        standingsVersion = tonumber(instance.standingsVersion) or 0,
        state = tostring(instance.state or RacingSystem.States.idle),
        entrants = buildOrderedEntrants(instance),
    }
end

local function broadcastInstanceStandings(instance)
    if type(instance) ~= 'table' then
        return
    end

    local orderedEntrants = buildOrderedEntrants(instance)
    for _, entrant in ipairs(orderedEntrants) do
        local entrantSource = tonumber(entrant.source) or 0
        if entrantSource > 0 then
            local player = Player(entrantSource)
            if player and player.state then
                player.state['rs:position'] = tonumber(entrant.position) or nil
                player.state['rs:currentLap'] = tonumber(entrant.currentLap) or 1
                player.state['rs:currentCheckpoint'] = tonumber(entrant.currentCheckpoint) or 1
                player.state['rs:finishedAt'] = tonumber(entrant.finishedAt) or nil
            end
        end
    end

    return
end

local function getLeaderProgress(instance)
    if type(instance) ~= 'table' then
        return 0
    end
    local ordered = buildOrderedEntrants(instance)
    if #ordered == 0 then
        return 0
    end
    return getEntrantSortScore(ordered[1], instance)
end

local function getLastPlaceEntrant(instance)
    if type(instance) ~= 'table' then
        return nil
    end
    local ordered = buildOrderedEntrants(instance)
    if #ordered <= 1 then
        return nil
    end
    return ordered[#ordered]
end

local function calculateTotalRaceDistance(instance)
    if type(instance) ~= 'table' then
        return 0
    end
    local checkpointCount = math.max(0, #(instance.checkpoints or {}))
    local lapCount = math.max(1, tonumber(instance.laps) or 3)
    return checkpointCount * lapCount
end

local function canJoinMidRace(instance)
    if type(instance) ~= 'table' then
        return false, 'Invalid race instance.'
    end
    if instance.state ~= RacingSystem.States.running then
        return false, 'Race is not currently running.'
    end

    local leaderProgress = getLeaderProgress(instance)
    local totalDistance = calculateTotalRaceDistance(instance)
    if totalDistance <= 0 then
        return false, 'Race has no checkpoints.'
    end

    local limitPercent = tonumber(instance.lateJoinProgressLimitPercent)
    if not limitPercent or limitPercent < 0 or limitPercent > 100 then
        limitPercent = math.max(0, math.min(100, tonumber(RacingSystem.Config.lateJoinProgressLimitPercent) or 50))
    end
    local progressThreshold = totalDistance * (limitPercent / 100)

    if leaderProgress <= progressThreshold then
        return true, nil
    else
        local percentComplete = (leaderProgress / totalDistance) * 100
        return false, ('Cannot join: leader has passed the %.1f%% late-join cutoff (currently at %.1f%%).'):format(limitPercent, percentComplete)
    end
end

local function inheritLastPlaceProgress(newEntrant, lastPlaceEntrant)
    if type(newEntrant) ~= 'table' or type(lastPlaceEntrant) ~= 'table' then
        return newEntrant
    end

    newEntrant.currentCheckpoint = tonumber(lastPlaceEntrant.currentCheckpoint) or 1
    newEntrant.currentLap = tonumber(lastPlaceEntrant.currentLap) or 1
    newEntrant.checkpointsPassed = tonumber(lastPlaceEntrant.checkpointsPassed) or 0
    newEntrant.lapStartedAt = tonumber(lastPlaceEntrant.lapStartedAt) or 0
    newEntrant.lastCheckpointAt = GetGameTimer()
    newEntrant.lapTimes = cloneNumberArray(lastPlaceEntrant.lapTimes)
    newEntrant.lapIncrementUnlocked = lastPlaceEntrant.lapIncrementUnlocked == true

    return newEntrant
end


local function buildViewerPayload(viewerSource)
    local numericViewerSource = tonumber(viewerSource) or -1
    local viewerIsAdmin = numericViewerSource > 0 and RacingSystem.Server.Logging.hasAdminAccess(numericViewerSource) or false
    return {
        source = numericViewerSource,
        isAdmin = viewerIsAdmin,
        canDeleteRaceDefinitions = viewerIsAdmin,
        canKillOwnedInstances = true,
    }
end

local function buildDefinitionsPayload(viewerSource)
    local definitions = RacingSystem.Server.Catalog.buildSavedRaceDefinitions()
    local customRaceCount = 0
    local onlineRaceCount = 0
    for _, definition in ipairs(definitions) do
        if definition.sourceType == 'custom' then
            customRaceCount = customRaceCount + 1
        elseif definition.sourceType == 'online' then
            onlineRaceCount = onlineRaceCount + 1
        end
    end

    return {
        definitions = definitions,
        count = #definitions,
        definitionCount = #definitions,
        customRaceCount = customRaceCount,
        onlineRaceCount = onlineRaceCount,
        viewer = buildViewerPayload(viewerSource),
    }
end

local function buildInstanceSummary(instance)
    if type(instance) ~= 'table' then
        return nil
    end

    return {
        id = tonumber(instance.id) or -1,
        name = tostring(instance.name or ''),
        sourceType = tostring(instance.sourceType or ''),
        owner = tonumber(instance.owner) or 0,
        state = tostring(instance.state or RacingSystem.States.idle),
        laps = tonumber(instance.laps) or 3,
        trafficDensity = math.max(0.0, math.min(1.0, tonumber(instance.trafficDensity) or 0.0)),
        entrantCount = #(type(instance.entrants) == 'table' and instance.entrants or {}),
    }
end

local function buildInstanceListPayload(viewerSource)
    local instances = {}
    for _, instance in pairs(RacingSystem.Server.State.raceInstancesById) do
        local summary = buildInstanceSummary(instance)
        if summary then
            instances[#instances + 1] = summary
        end
    end

    table.sort(instances, function(a, b)
        return (a.id or 0) < (b.id or 0)
    end)

    return {
        instances = instances,
        instanceCount = #instances,
        viewer = buildViewerPayload(viewerSource),
    }
end

local function buildInstanceDynamicPayload(instance)
    if type(instance) ~= 'table' then
        return nil
    end

    return {
        id = tonumber(instance.id) or -1,
        name = tostring(instance.name or ''),
        definitionId = instance.definitionId,
        definitionName = instance.definitionName,
        sourceType = instance.sourceType,
        sourceName = instance.sourceName,
        pointToPoint = instance.pointToPoint == true,
        trafficDensity = math.max(0.0, math.min(1.0, tonumber(instance.trafficDensity) or 0.0)),
        laps = tonumber(instance.laps) or 3,
        owner = instance.owner,
        state = instance.state,
        createdAt = instance.createdAt,
        invokedAt = instance.invokedAt,
        startAt = instance.startAt,
        startedAt = instance.startedAt,
        bestLapTimeMs = tonumber(instance.bestLapTimeMs) or nil,
        finishedAt = instance.finishedAt,
        entrants = buildOrderedEntrants(instance),
    }
end

local function buildInstanceStaticPayload(instance)
    if type(instance) ~= 'table' then
        return nil
    end

    local checkpoints, raceMetadata, checkpointVariants = RacingSystem.Server.Catalog.buildCheckpointVariantSnapshot(instance)
    return {
        instanceId = tonumber(instance.id) or -1,
        sourceType = instance.sourceType,
        sourceName = instance.sourceName,
        checkpoints = checkpoints,
        raceMetadata = raceMetadata,
        checkpointVariants = checkpointVariants,
        props = cloneOnlineRaceProps(instance.props),
        modelHides = cloneOnlineRaceModelHides(instance.modelHides),
    }
end

local function getInstanceStaticSignature(instance)
    local payload = buildInstanceStaticPayload(instance)
    if type(payload) ~= 'table' then
        return nil
    end
    return json.encode(payload) or tostring(GetGameTimer())
end

local function sendDefinitions(target)
    local _ = target
    return
end

local function broadcastDefinitions()
    return
end

local function sendInstanceList(target)
    local _ = target
    return
end

local function broadcastInstanceList()
    return
end

local function sendInstanceDelta(target, instance)
    local _, _instance = target, instance
    return
end

local function broadcastInstanceDelta(instance)
    local _ = instance
    return
end

local function sendInstanceStaticIfChanged(target, instance, force)
    local _, _, _force = target, instance, force
    return
end

local function sendInitialState(target)
    local _ = target
    return
end

local function buildInstanceAssetPayload(instance)
    if type(instance) ~= 'table' then
        return nil
    end

    return {
        instanceId = instance.id,
        sourceType = instance.sourceType,
        sourceName = instance.sourceName,
        props = cloneOnlineRaceProps(instance.props),
        modelHides = cloneOnlineRaceModelHides(instance.modelHides),
    }
end

local function sendInstanceAssets(target, instance)
    if tonumber(target) == nil or tonumber(target) <= 0 then
        return
    end

    local payload = buildInstanceAssetPayload(instance)
    if not payload then
        return
    end

    TriggerClientEvent('racingsystem:race:instanceAssets', target, payload)
end

local function sendTeleportToLastCheckpoint(target, instance)
    if tonumber(target) == nil or tonumber(target) <= 0 or type(instance) ~= 'table' then
        return
    end

    local checkpoints = type(instance.checkpoints) == 'table' and instance.checkpoints or {}
    local startCheckpointIndex = getRaceStartCheckpoint(instance)
    local startCheckpoint = checkpoints[startCheckpointIndex]
    if type(startCheckpoint) ~= 'table' then
        return
    end

    TriggerClientEvent('racingsystem:race:teleportCheckpoint', target, {
        instanceId = instance.id,
        checkpointIndex = startCheckpointIndex,
        x = tonumber(startCheckpoint.x) or 0.0,
        y = tonumber(startCheckpoint.y) or 0.0,
        z = (tonumber(startCheckpoint.z) or 0.0) + 1.0,
        teleportType = 'join',
        sourceType = tostring(instance.sourceType or ''),
    })
end

local function sendTeleportToCheckpoint(target, instance, checkpointIndex)
    if tonumber(target) == nil or tonumber(target) <= 0 or type(instance) ~= 'table' then
        return
    end

    local checkpoints = type(instance.checkpoints) == 'table' and instance.checkpoints or {}
    local checkpointIdx = math.max(1, math.min(#checkpoints, math.floor(tonumber(checkpointIndex) or 1)))
    local checkpoint = checkpoints[checkpointIdx]
    if type(checkpoint) ~= 'table' then
        return
    end

    RacingSystem.Server.Logging.logVerbose(("[startfinish] teleport target=%s instance=%s requestedCheckpoint=%s resolvedCheckpoint=%s startCheckpoint=%s lapTrigger=%s heading=%s xyz=(%.2f,%.2f,%.2f)"):format(
        tostring(target),
        tostring(instance.id),
        tostring(checkpointIndex),
        tostring(checkpointIdx),
        tostring(getRaceStartCheckpoint(instance)),
        tostring(getLapTriggerCheckpoint(instance, #checkpoints, tonumber(instance.laps) or 1)),
        'client',
        tonumber(checkpoint.x) or 0.0,
        tonumber(checkpoint.y) or 0.0,
        tonumber(checkpoint.z) or 0.0
    ))

    TriggerClientEvent('racingsystem:race:teleportCheckpoint', target, {
        instanceId = instance.id,
        checkpointIndex = checkpointIdx,
        x = tonumber(checkpoint.x) or 0.0,
        y = tonumber(checkpoint.y) or 0.0,
        z = (tonumber(checkpoint.z) or 0.0) + 1.0,
        teleportType = 'join',
        sourceType = tostring(instance.sourceType or ''),
    })
end

local function findRaceInstanceByName(instanceName)
    local normalizedName = RacingSystem.NormalizeRaceName(instanceName)
    if not normalizedName then
        return nil
    end

    local instanceId = RacingSystem.Server.State.raceInstanceIdsByName[normalizedName]
    if not instanceId then
        return nil
    end

    return RacingSystem.Server.State.raceInstancesById[instanceId]
end

local function findRaceInstanceByEntrant(source)
    local numericSource = tonumber(source) or 0

    for _, instance in pairs(RacingSystem.Server.State.raceInstancesById) do
        for _, entrant in ipairs(listEntrantsFromState(instance)) do
            if tonumber(entrant.source) == numericSource then
                return instance
            end
        end
    end

    return nil
end

local function findEntrantInRaceInstance(instance, source)
    local numericSource = tonumber(source) or 0

    local map = ensureEntrantStateMap(instance)
    local sourceKey = getEntrantStateKeyFromSource(numericSource)
    if sourceKey and type(map[sourceKey]) == 'table' then
        return map[sourceKey]
    end

    for _, entrant in ipairs(type(instance.entrants) == 'table' and instance.entrants or {}) do
        if tonumber(entrant.source) == numericSource then
            return entrant
        end
    end

    return nil
end

local function removeEntrantFromRaceInstance(instance, source)
    if type(instance) ~= 'table' then
        return nil
    end

    local numericSource = tonumber(source) or 0

    for index, entrant in ipairs(instance.entrants or {}) do
        if tonumber(entrant.source) == numericSource then
            local removedEntrant = table.remove(instance.entrants, index)
            removeEntrantStateBySource(instance, numericSource)
            return removedEntrant
        end
    end

    return nil
end

local function cleanupInstanceAfterEntrantRemoval(instance, source, removedEntrant, reason)
    if type(instance) ~= 'table' then
        return false
    end

    if #(instance.entrants or {}) <= 0 then
        local previousState = instance.state
        if RacingSystem.Server.Logging.isLifecycleTransitionAllowed(previousState, 'terminated') then
            RacingSystem.Server.Logging.logLifecycleEvent('terminateRace', instance, removedEntrant, source, previousState, 'terminated', reason or 'empty_after_removal')
        end
        RacingSystem.Server.Logging.clearRaceStateBagByInstanceId(instance.id)
        removeRaceInstanceNameIndex(instance)
        RacingSystem.Server.State.raceInstancesById[instance.id] = nil
        RacingSystem.Server.State.reliabilityCounters.emptyInstanceAutoDestroyed = RacingSystem.Server.State.reliabilityCounters.emptyInstanceAutoDestroyed + 1
        return true
    end

    return false
end

local function removeEntrantFromAllRaceInstances(source, reason)
    local removedAny = false
    while true do
        local instance = findRaceInstanceByEntrant(source)
        if not instance then
            break
        end

        local removedEntrant = removeEntrantFromRaceInstance(instance, source)
        if not removedEntrant then
            break
        end

        removedAny = true
        cleanupInstanceAfterEntrantRemoval(instance, source, removedEntrant, reason or 'source_removed')
    end

    return removedAny
end

local function buildRaceInstanceSnapshot(instance)
    local dynamicPayload = buildInstanceDynamicPayload(instance)
    if type(dynamicPayload) ~= 'table' then
        return nil
    end
    local staticPayload = buildInstanceStaticPayload(instance)
    dynamicPayload.checkpoints = staticPayload and staticPayload.checkpoints or {}
    dynamicPayload.raceMetadata = staticPayload and staticPayload.raceMetadata or {}
    dynamicPayload.checkpointVariants = staticPayload and staticPayload.checkpointVariants or {}
    return dynamicPayload
end

local function sendRaceInfoToTarget(target, instance)
    local source = tonumber(target) or 0
    if source <= 0 or type(instance) ~= 'table' then
        return
    end

    local payload = buildRaceInstanceSnapshot(instance)
    if type(payload) ~= 'table' then
        return
    end

    TriggerClientEvent('racingsystem:race:getRaceInfo', source, payload)
end

local function buildFullSnapshot(viewerSource)
    local definitionsPayload = buildDefinitionsPayload(viewerSource)
    local listPayload = buildInstanceListPayload(viewerSource)
    local instances = {}
    for _, instance in pairs(RacingSystem.Server.State.raceInstancesById) do
        local snapshotInstance = buildRaceInstanceSnapshot(instance)
        if snapshotInstance then
            instances[#instances + 1] = snapshotInstance
        end
    end
    table.sort(instances, function(a, b)
        return (a.id or 0) < (b.id or 0)
    end)

    return {
        snapshotVersion = tonumber(RacingSystem.Server.State.nextSnapshotVersion) or 0,
        races = {},
        definitions = definitionsPayload.definitions,
        instances = instances,
        count = definitionsPayload.count,
        definitionCount = definitionsPayload.definitionCount,
        customRaceCount = definitionsPayload.customRaceCount,
        onlineRaceCount = definitionsPayload.onlineRaceCount,
        instanceCount = listPayload.instanceCount,
        viewer = definitionsPayload.viewer,
    }
end

local function sendSnapshot(target)
    local _ = target
    return
end

local function broadcastSnapshot()
    return
end

local snapshotRoundRobinCursor = 0

local function buildSnapshotRoundRobinTargets()
    local targets = {}
    for instanceId, instance in pairs(RacingSystem.Server.State.raceInstancesById) do
        if type(instance) == 'table' then
            local resolvedInstanceId = tonumber(instance.id) or tonumber(instanceId) or 0
            for _, entrant in ipairs(listEntrantsFromState(instance)) do
                local targetSource = tonumber(type(entrant) == 'table' and entrant.source) or 0
                if targetSource > 0 then
                    targets[#targets + 1] = {
                        instanceId = resolvedInstanceId,
                        source = targetSource,
                        instance = instance,
                    }
                end
            end
        end
    end

    table.sort(targets, function(a, b)
        if tonumber(a.instanceId) ~= tonumber(b.instanceId) then
            return (tonumber(a.instanceId) or 0) < (tonumber(b.instanceId) or 0)
        end
        return (tonumber(a.source) or 0) < (tonumber(b.source) or 0)
    end)
    return targets
end

local function runSnapshotRoundRobinTick()
    local targets = buildSnapshotRoundRobinTargets()
    local targetCount = #targets
    if targetCount <= 0 then
        snapshotRoundRobinCursor = 0
        Wait(500)
        return
    end

    if snapshotRoundRobinCursor < 1 or snapshotRoundRobinCursor > targetCount then
        snapshotRoundRobinCursor = 1
    end

    local turnTarget = targets[snapshotRoundRobinCursor]
    if type(turnTarget) == 'table' and type(turnTarget.instance) == 'table' then
        broadcastInstanceStandings(turnTarget.instance)
        sendRaceInfoToTarget(turnTarget.source, turnTarget.instance)
        sendInstanceStaticIfChanged(turnTarget.source, turnTarget.instance, false)
        sendInstanceAssets(turnTarget.source, turnTarget.instance)
    end

    snapshotRoundRobinCursor = snapshotRoundRobinCursor + 1
    if snapshotRoundRobinCursor > targetCount then
        snapshotRoundRobinCursor = 1
    end

    local minTickMs = math.max(1, math.floor(tonumber((RacingSystem.Server.State.config or {}).snapshotMinTickMs) or 1))
    local tickMs = math.max(minTickMs, math.floor(2000 / targetCount))
    Wait(tickMs)
end

RacingSystem.Server.Snapshot.cloneOnlineRaceProps = cloneOnlineRaceProps
RacingSystem.Server.Snapshot.cloneOnlineRaceModelHides = cloneOnlineRaceModelHides
RacingSystem.Server.Snapshot.cloneNumberArray = cloneNumberArray
RacingSystem.Server.Snapshot.cloneEntrant = cloneEntrant
RacingSystem.Server.Snapshot.getEntrantStateKeyFromEntrant = getEntrantStateKeyFromEntrant
RacingSystem.Server.Snapshot.getEntrantStateKeyFromSource = getEntrantStateKeyFromSource
RacingSystem.Server.Snapshot.ensureEntrantStateMap = ensureEntrantStateMap
RacingSystem.Server.Snapshot.upsertEntrantState = upsertEntrantState
RacingSystem.Server.Snapshot.removeEntrantStateBySource = removeEntrantStateBySource
RacingSystem.Server.Snapshot.listEntrantsFromState = listEntrantsFromState
RacingSystem.Server.Snapshot.resetEntrantProgress = resetEntrantProgress
RacingSystem.Server.Snapshot.getRaceStartCheckpoint = getRaceStartCheckpoint
RacingSystem.Server.Snapshot.getLapTriggerCheckpoint = getLapTriggerCheckpoint
RacingSystem.Server.Snapshot.getNextCheckpointIndex = getNextCheckpointIndex
RacingSystem.Server.Snapshot.getPreRaceExpectedCheckpoint = getPreRaceExpectedCheckpoint
RacingSystem.Server.Snapshot.isPointToPointByCheckpointDistance = isPointToPointByCheckpointDistance
RacingSystem.Server.Snapshot.buildEntrant = buildEntrant
RacingSystem.Server.Snapshot.indexRaceInstanceName = indexRaceInstanceName
RacingSystem.Server.Snapshot.removeRaceInstanceNameIndex = removeRaceInstanceNameIndex
RacingSystem.Server.Snapshot.getEntrantSortScore = getEntrantSortScore
RacingSystem.Server.Snapshot.buildOrderedEntrants = buildOrderedEntrants
RacingSystem.Server.Snapshot.buildInstanceStandingsPayload = buildInstanceStandingsPayload
RacingSystem.Server.Snapshot.broadcastInstanceStandings = broadcastInstanceStandings
RacingSystem.Server.Snapshot.getLeaderProgress = getLeaderProgress
RacingSystem.Server.Snapshot.getLastPlaceEntrant = getLastPlaceEntrant
RacingSystem.Server.Snapshot.calculateTotalRaceDistance = calculateTotalRaceDistance
RacingSystem.Server.Snapshot.canJoinMidRace = canJoinMidRace
RacingSystem.Server.Snapshot.inheritLastPlaceProgress = inheritLastPlaceProgress
RacingSystem.Server.Snapshot.buildDefinitionsPayload = buildDefinitionsPayload
RacingSystem.Server.Snapshot.sendDefinitions = sendDefinitions
RacingSystem.Server.Snapshot.broadcastDefinitions = broadcastDefinitions
RacingSystem.Server.Snapshot.buildInstanceListPayload = buildInstanceListPayload
RacingSystem.Server.Snapshot.sendInstanceList = sendInstanceList
RacingSystem.Server.Snapshot.broadcastInstanceList = broadcastInstanceList
RacingSystem.Server.Snapshot.buildInstanceDynamicPayload = buildInstanceDynamicPayload
RacingSystem.Server.Snapshot.sendInstanceDelta = sendInstanceDelta
RacingSystem.Server.Snapshot.broadcastInstanceDelta = broadcastInstanceDelta
RacingSystem.Server.Snapshot.buildInstanceStaticPayload = buildInstanceStaticPayload
RacingSystem.Server.Snapshot.sendInstanceStaticIfChanged = sendInstanceStaticIfChanged
RacingSystem.Server.Snapshot.sendInitialState = sendInitialState
RacingSystem.Server.Snapshot.buildRaceInstanceSnapshot = buildRaceInstanceSnapshot
RacingSystem.Server.Snapshot.sendRaceInfoToTarget = sendRaceInfoToTarget
RacingSystem.Server.Snapshot.buildFullSnapshot = buildFullSnapshot
RacingSystem.Server.Snapshot.sendSnapshot = sendSnapshot
RacingSystem.Server.Snapshot.broadcastSnapshot = broadcastSnapshot
RacingSystem.Server.Snapshot.runSnapshotRoundRobinTick = runSnapshotRoundRobinTick
RacingSystem.Server.Snapshot.buildInstanceAssetPayload = buildInstanceAssetPayload
RacingSystem.Server.Snapshot.sendInstanceAssets = sendInstanceAssets
RacingSystem.Server.Snapshot.sendTeleportToLastCheckpoint = sendTeleportToLastCheckpoint
RacingSystem.Server.Snapshot.sendTeleportToCheckpoint = sendTeleportToCheckpoint
RacingSystem.Server.Snapshot.findRaceInstanceByName = findRaceInstanceByName
RacingSystem.Server.Snapshot.findRaceInstanceByEntrant = findRaceInstanceByEntrant
RacingSystem.Server.Snapshot.findEntrantInRaceInstance = findEntrantInRaceInstance
RacingSystem.Server.Snapshot.removeEntrantFromRaceInstance = removeEntrantFromRaceInstance
RacingSystem.Server.Snapshot.cleanupInstanceAfterEntrantRemoval = cleanupInstanceAfterEntrantRemoval
RacingSystem.Server.Snapshot.removeEntrantFromAllRaceInstances = removeEntrantFromAllRaceInstances


