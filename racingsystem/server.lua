local raceInstancesById = {}
local raceInstanceIdsByName = {}
local nextRaceInstanceId = 1
local getSavedRaceCounts
local buildSavedRaceDefinitions
local buildCheckpointsFromMissionRace
local parseRaceDefinitionFromJson
local buildNormalizedOnlineRaceJson
local loadBundledOnlineRace
local cloneMissionValue
local knownRaceDefinitionsByName = {}
local RACE_INDEX_FILE = 'race_index.json'
local RESOURCE_NAME = 'racingsystem'
local CUSTOM_RACE_FOLDER = 'CustomRaces'
local ONLINE_RACE_FOLDER = 'OnlineRaces'
local checkpointAnomalyLogByKey = {}
local UGC_FETCH_RETRY_COOLDOWN_MS = 700
local nextAllowedUGCFetchAt = 0
local GTAO_CHECKPOINT_RADIUS_SCALE = 1.5

local function getExtraPrintLevel()
    local rawLevel = 0
    if type(GetConvarInt) == 'function' then
        rawLevel = math.floor(tonumber(GetConvarInt('rSystemExtraPrints', 0)) or 0)
    else
        local raw = type(GetConvar) == 'function' and GetConvar('rSystemExtraPrints', '0') or '0'
        rawLevel = math.floor(tonumber(raw) or 0)
    end

    if rawLevel == 1 then
        return 1
    end
    if rawLevel == 2 then
        return 2
    end
    return 0
end

local function logError(message)
    print(tostring(message or 'Unknown server error.'))
end

local function logLevelOne(message)
    if getExtraPrintLevel() == 1 then
        print(tostring(message or ''))
    end
end

local function logVerbose(message)
    if getExtraPrintLevel() == 2 then
        print(tostring(message or ''))
    end
end

local function log(message)
    logVerbose(message)
end

local function shouldLogCheckpointAnomaly(source, instanceId)
    local key = ('%s:%s'):format(tonumber(source) or 0, tonumber(instanceId) or -1)
    local now = GetGameTimer()
    local lastLoggedAt = tonumber(checkpointAnomalyLogByKey[key]) or -100000
    if now - lastLoggedAt < 2000 then
        return false
    end

    checkpointAnomalyLogByKey[key] = now
    return true
end

local function resolvePlayerLogLabel(sourceId)
    local numericSource = tonumber(sourceId) or 0
    local playerName = (numericSource == 0 and 'console') or (GetPlayerName(numericSource) or ('player:%s'):format(tostring(numericSource)))
    return ('%s (%s)'):format(playerName, tostring(numericSource))
end

local function resolveReadablePlayerName(playerSource, entrant)
    local liveName = type(GetPlayerName) == 'function' and GetPlayerName(playerSource) or nil
    if type(liveName) == 'string' then
        local trimmed = liveName:match('^%s*(.-)%s*$')
        if trimmed and trimmed ~= '' then
            return trimmed
        end
    end

    local entrantName = tostring((entrant or {}).name or '')
    local trimmedEntrantName = entrantName:match('^%s*(.-)%s*$') or ''
    if trimmedEntrantName ~= '' and not trimmedEntrantName:match('^[Pp]layer%s+%d+$') then
        return trimmedEntrantName
    end

    return ('player:%s'):format(tostring(playerSource))
end

local function logCheckpointPassContext(instance, entrant, reportedCheckpoint, totalCheckpoints, lapNumber, totalLaps, passContext)
    local printLevel = getExtraPrintLevel()
    if printLevel == 0 then
        return
    end

    local context = type(passContext) == 'table' and passContext or {}
    local playerSource = tonumber((entrant or {}).source) or 0
    local playerName = resolveReadablePlayerName(playerSource, entrant)
    local raceName = tostring((instance or {}).name or 'unknown')
    local contextKind = tostring(context.kind or 'unknown')
    local penalty = tostring(context.penalty or 'none')
    local routeVariant = tostring(context.routeVariant or 'primary')
    local outsideOffset = tonumber(context.outsideOffset) or 0.0
    local throttlePenaltyMs = math.max(0, math.floor(tonumber(context.throttlePenaltyMs) or 0))
    local powerPenaltyMs = math.max(0, math.floor(tonumber(context.powerPenaltyMs) or 0))
    local assumedCrashPenaltyVoided = context.assumedCrashPenaltyVoided == true and 'yes' or 'no'

    local checkpointNumber = math.max(0, math.floor(tonumber(reportedCheckpoint) or 0))
    local checkpointTotal = math.max(0, math.floor(tonumber(totalCheckpoints) or 0))
    local currentLap = math.max(1, math.floor(tonumber(lapNumber) or 1))
    local lapTotal = math.max(1, math.floor(tonumber(totalLaps) or 1))

    local hasPenalty = (
        penalty ~= 'none'
        or throttlePenaltyMs > 0
        or powerPenaltyMs > 0
        or outsideOffset > 0.01
        or contextKind ~= 'clean_pass'
        or assumedCrashPenaltyVoided == 'yes'
    )
    if printLevel == 1 and not hasPenalty then
        return
    end

    local details = {}
    if contextKind ~= 'clean_pass' then
        table.insert(details, ('context: %s'):format(contextKind:gsub('_', ' ')))
    end
    if penalty ~= 'none' then
        table.insert(details, ('penalty: %s'):format(penalty:gsub('_', ' ')))
    end
    if outsideOffset > 0.01 then
        table.insert(details, ('outside by %.2fm'):format(outsideOffset))
    end
    if throttlePenaltyMs > 0 then
        table.insert(details, ('throttle penalty: %dms'):format(throttlePenaltyMs))
    end
    if powerPenaltyMs > 0 then
        table.insert(details, ('power penalty: %dms'):format(powerPenaltyMs))
    end
    if assumedCrashPenaltyVoided == 'yes' then
        table.insert(details, 'crash penalty voided')
    end
    if routeVariant ~= 'primary' then
        table.insert(details, ('route: %s'):format(routeVariant))
    end

    local detailText = #details > 0 and (' Details: %s.'):format(table.concat(details, ', ')) or ''
    print(("%s (%s) passed checkpoint %d/%d in race '%s' (lap %d/%d).%s"):format(
        playerName,
        tostring(playerSource),
        checkpointNumber,
        checkpointTotal,
        raceName,
        currentLap,
        lapTotal,
        detailText
    ))
end

local function hasAdminAccess(sourceId)
    local ace = tostring(((RacingSystem.Config or {}).adminAce) or "racingsystem.admin")
    if sourceId == 0 then
        return true
    end
    return IsPlayerAceAllowed(sourceId, ace)
end

local function auditLog(action, sourceId, details)
    local actor = resolvePlayerLogLabel(sourceId)
    local detailText = tostring(details or '')
    if detailText == '' then
        detailText = tostring(action or 'Performed a race action')
    end
    logLevelOne(("%s %s."):format(tostring(actor), detailText))
end

-- Mirrors server-side messages to the target player when possible.
local function notifyPlayer(target, message, isError)
    local targetId = tonumber(target)
    local text = tostring(message or '')

    if targetId == nil or targetId < 0 then
        return
    end

    if targetId == 0 then
        return
    end

    TriggerClientEvent('racingsystem:notify', targetId, {
        message = text,
        isError = isError == true,
    })
end

local function cloneCheckpoints(checkpoints)
    local cloned = {}

    for index, checkpoint in ipairs(type(checkpoints) == 'table' and checkpoints or {}) do
        cloned[index] = {
            index = tonumber(checkpoint.index) or index,
            x = tonumber(checkpoint.x) or 0.0,
            y = tonumber(checkpoint.y) or 0.0,
            z = tonumber(checkpoint.z) or 0.0,
            radius = tonumber(checkpoint.radius) or 8.0,
        }
    end

    return cloned
end

local function isSecondaryCoordinateValid(x, y, z)
    if not x or not y or not z then
        return false
    end

    if math.abs(x) < 0.001 and math.abs(y) < 0.001 and math.abs(z) < 0.001 then
        return false
    end

    if math.abs(x) > 10000.0 or math.abs(y) > 10000.0 or math.abs(z) > 5000.0 then
        return false
    end

    return true
end

local function buildSecondaryCheckpointFromMetadata(index, primaryCheckpoint, raceMetadata)
    if type(primaryCheckpoint) ~= 'table' then
        return nil
    end

    local metadata = type(raceMetadata) == 'table' and raceMetadata or nil
    local secondaryPoints = metadata and type(metadata.sndchk) == 'table' and metadata.sndchk or nil
    if not secondaryPoints then
        return nil
    end

    local rawSecondary = secondaryPoints[index]
    if type(rawSecondary) ~= 'table' then
        return nil
    end

    local x = tonumber(rawSecondary.x)
    local y = tonumber(rawSecondary.y)
    local z = tonumber(rawSecondary.z)
    if not isSecondaryCoordinateValid(x, y, z) then
        return nil
    end

    local primaryX = tonumber(primaryCheckpoint.x) or 0.0
    local primaryY = tonumber(primaryCheckpoint.y) or 0.0
    local primaryZ = tonumber(primaryCheckpoint.z) or 0.0
    local dx = x - primaryX
    local dy = y - primaryY
    local dz = z - primaryZ
    local distance = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))

    if distance < 4.0 or distance > 2500.0 then
        return nil
    end

    local radius = tonumber(primaryCheckpoint.radius) or 8.0
    local secondarySizes = type(metadata.sndsz) == 'table' and metadata.sndsz or nil
    if secondarySizes then
        local size = tonumber(secondarySizes[index])
        if size then
            radius = math.max(2.0, 8.0 * size)
        end
    end

    return {
        index = tonumber(primaryCheckpoint.index) or index,
        x = x,
        y = y,
        z = z,
        radius = radius,
    }
end

local function buildCheckpointVariantSnapshot(instance)
    local checkpoints = cloneCheckpoints((instance or {}).checkpoints)
    local raceMetadata = cloneMissionValue(type((instance or {}).raceMetadata) == 'table' and instance.raceMetadata or {})
    local checkpointVariants = {}

    for index, primaryCheckpoint in ipairs(checkpoints) do
        checkpointVariants[index] = {
            index = index,
            primary = {
                index = tonumber(primaryCheckpoint.index) or index,
                x = tonumber(primaryCheckpoint.x) or 0.0,
                y = tonumber(primaryCheckpoint.y) or 0.0,
                z = tonumber(primaryCheckpoint.z) or 0.0,
                radius = tonumber(primaryCheckpoint.radius) or 8.0,
            },
            secondary = buildSecondaryCheckpointFromMetadata(index, primaryCheckpoint, raceMetadata),
        }
    end

    return checkpoints, raceMetadata, checkpointVariants
end

local function cloneKnownRaceDefinition(definition)
    if type(definition) ~= 'table' then
        return nil
    end

    local displayName = RacingSystem.Trim(definition.name)
    local normalizedName = RacingSystem.NormalizeRaceName(definition.lookupName or definition.name)
    if not normalizedName or displayName == '' then
        return nil
    end

    local sourceType = tostring(definition.sourceType or 'custom')
    if sourceType ~= 'custom' and sourceType ~= 'online' then
        sourceType = 'custom'
    end

    return {
        lookupName = normalizedName,
        name = displayName,
        sourceType = sourceType,
        updatedAt = tonumber(definition.updatedAt) or os.time(),
    }
end

local function saveRaceIndex()
    local definitions = {}

    for _, definition in pairs(knownRaceDefinitionsByName) do
        local clonedDefinition = cloneKnownRaceDefinition(definition)
        if clonedDefinition then
            definitions[#definitions + 1] = clonedDefinition
        end
    end

    table.sort(definitions, function(a, b)
        if a.sourceType ~= b.sourceType then
            return tostring(a.sourceType) < tostring(b.sourceType)
        end

        return tostring(a.name):lower() < tostring(b.name):lower()
    end)

    local encoded = json.encode({
        definitions = definitions,
    })
    if type(encoded) ~= 'string' or encoded == '' then
        logError(("The server could not encode '%s'."):format(RACE_INDEX_FILE))
        return false
    end

    local saveOk = SaveResourceFile(RESOURCE_NAME, RACE_INDEX_FILE, encoded, -1)
    if not saveOk then
        logError(("The server could not save '%s'."):format(RACE_INDEX_FILE))
        return false
    end

    log(('Saved %s with %s definition(s).'):format(RACE_INDEX_FILE, #definitions))
    return true
end

local function loadRaceIndex()
    knownRaceDefinitionsByName = {}

    local rawIndex = LoadResourceFile(RESOURCE_NAME, RACE_INDEX_FILE)
    if not rawIndex or rawIndex == '' then
        log(('%s was not found. Starting with an empty race index.'):format(RACE_INDEX_FILE))
        return
    end

    local decoded = json.decode(rawIndex)
    local definitions = type(decoded) == 'table' and decoded.definitions or nil
    if type(definitions) ~= 'table' then
        logError(("The server could not read '%s' as a race definition list."):format(RACE_INDEX_FILE))
        return
    end

    local loadedCount = 0
    for _, definition in ipairs(definitions) do
        local clonedDefinition = cloneKnownRaceDefinition(definition)
        if clonedDefinition then
            local normalizedName = RacingSystem.NormalizeRaceName(clonedDefinition.lookupName or clonedDefinition.name)
            knownRaceDefinitionsByName[normalizedName] = clonedDefinition
            loadedCount = loadedCount + 1
        end
    end

    log(('Loaded %s definition(s) from %s.'):format(loadedCount, RACE_INDEX_FILE))
end

local function registerKnownRaceDefinition(raceName, sourceType)
    local displayName = RacingSystem.Trim(raceName)
    local normalizedName = RacingSystem.NormalizeRaceName(displayName)
    if not normalizedName then
        return nil
    end

    local normalizedSourceType = tostring(sourceType or 'custom')
    if normalizedSourceType ~= 'custom' and normalizedSourceType ~= 'online' then
        normalizedSourceType = 'custom'
    end

    knownRaceDefinitionsByName[normalizedName] = {
        lookupName = normalizedName,
        name = displayName,
        sourceType = normalizedSourceType,
        updatedAt = os.time(),
    }

    saveRaceIndex()
    return knownRaceDefinitionsByName[normalizedName]
end

local function unregisterKnownRaceDefinition(raceName)
    local normalizedName = RacingSystem.NormalizeRaceName(raceName)
    if not normalizedName then
        return false
    end

    if knownRaceDefinitionsByName[normalizedName] == nil then
        return false
    end

    knownRaceDefinitionsByName[normalizedName] = nil
    saveRaceIndex()
    return true
end

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
end

local function getRaceStartCheckpoint(instance)
    return 1
end

local function getLapTriggerCheckpoint(totalCheckpoints, totalLaps)
    local checkpointCount = math.max(0, tonumber(totalCheckpoints) or 0)
    if checkpointCount <= 1 then
        return 1
    end

    return checkpointCount
end

local function buildEntrant(source, instance)
    local numericSource = tonumber(source) or 0

    return {
        source = numericSource,
        name = GetPlayerName(numericSource) or ('Player %s'):format(numericSource),
        joinedAt = os.time(),
        currentCheckpoint = getRaceStartCheckpoint(instance),
        currentLap = 1,
        checkpointsPassed = 0,
        lastCheckpointAt = 0,
        lapStartedAt = 0,
        lapTimes = {},
        totalTimeMs = nil,
        finishedAt = nil,
        position = nil,
    }
end

local function indexRaceInstanceName(instance)
    local normalizedName = RacingSystem.NormalizeRaceName(instance and instance.name)
    if normalizedName then
        raceInstanceIdsByName[normalizedName] = instance.id
    end
end

local function removeRaceInstanceNameIndex(instance)
    local normalizedName = RacingSystem.NormalizeRaceName(instance and instance.name)
    if normalizedName and raceInstanceIdsByName[normalizedName] == instance.id then
        raceInstanceIdsByName[normalizedName] = nil
    end
end

local function getEntrantSortScore(entrant)
    if type(entrant) ~= 'table' then
        return 0
    end

    return tonumber(entrant.checkpointsPassed) or 0
end

local function buildOrderedEntrants(instance)
    local ordered = {}

    for _, entrant in ipairs(type(instance.entrants) == 'table' and instance.entrants or {}) do
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

        local aScore = getEntrantSortScore(a)
        local bScore = getEntrantSortScore(b)
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

        return (tonumber(a.joinedAt) or 0) < (tonumber(b.joinedAt) or 0)
    end)

    for index, entrant in ipairs(ordered) do
        entrant.position = index
    end

    return ordered
end

local function buildRaceInstanceSnapshot(instance)
    if type(instance) ~= 'table' then
        return nil
    end

    local checkpoints, raceMetadata, checkpointVariants = buildCheckpointVariantSnapshot(instance)

    return {
        id = instance.id,
        name = instance.name,
        definitionId = instance.definitionId,
        definitionName = instance.definitionName,
        sourceType = instance.sourceType,
        sourceName = instance.sourceName,
        laps = tonumber(instance.laps) or 1,
        owner = instance.owner,
        state = instance.state,
        createdAt = instance.createdAt,
        invokedAt = instance.invokedAt,
        startAt = instance.startAt,
        startedAt = instance.startedAt,
        bestLapTimeMs = tonumber(instance.bestLapTimeMs) or nil,
        finishedAt = instance.finishedAt,
        checkpoints = checkpoints,
        raceMetadata = raceMetadata,
        checkpointVariants = checkpointVariants,
        entrants = buildOrderedEntrants(instance),
    }
end

local function buildFullSnapshot(viewerSource)
    local instances = {}

    for _, instance in pairs(raceInstancesById) do
        instances[#instances + 1] = buildRaceInstanceSnapshot(instance)
    end

    table.sort(instances, function(a, b)
        return (a.id or 0) < (b.id or 0)
    end)

    local definitions = buildSavedRaceDefinitions()
    local customRaceCount = 0
    local onlineRaceCount = 0

    for _, definition in ipairs(definitions) do
        if definition.sourceType == 'custom' then
            customRaceCount = customRaceCount + 1
        elseif definition.sourceType == 'online' then
            onlineRaceCount = onlineRaceCount + 1
        end
    end

    local definitionCount = #definitions

    local numericViewerSource = tonumber(viewerSource) or -1
    local viewerIsAdmin = numericViewerSource > 0 and hasAdminAccess(numericViewerSource) or false
    local ownerKillEnabled = true

    return {
        races = {},
        definitions = definitions,
        instances = instances,
        count = definitionCount,
        definitionCount = definitionCount,
        customRaceCount = customRaceCount,
        onlineRaceCount = onlineRaceCount,
        instanceCount = #instances,
        viewer = {
            source = numericViewerSource,
            isAdmin = viewerIsAdmin,
            canDeleteRaceDefinitions = viewerIsAdmin,
            canKillOwnedInstances = ownerKillEnabled,
        },
    }
end

local function sendSnapshot(target)
    local snapshot = buildFullSnapshot(target)
    log(('Sending snapshot to %s | definitions=%s instances=%s'):format(
        tostring(target),
        #(type(snapshot.definitions) == 'table' and snapshot.definitions or {}),
        #(type(snapshot.instances) == 'table' and snapshot.instances or {})
    ))
    TriggerClientEvent('racingsystem:stateSnapshot', target, snapshot)
end

local function broadcastSnapshot()
    local players = type(GetPlayers) == 'function' and GetPlayers() or {}
    for _, playerId in ipairs(type(players) == 'table' and players or {}) do
        local numericPlayerId = tonumber(playerId)
        if numericPlayerId and numericPlayerId > 0 then
            sendSnapshot(numericPlayerId)
        end
    end
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

    TriggerClientEvent('racingsystem:instanceAssets', target, payload)
end

local function sendTeleportToLastCheckpoint(target, instance)
    if tonumber(target) == nil or tonumber(target) <= 0 or type(instance) ~= 'table' then
        return
    end

    local checkpoints = type(instance.checkpoints) == 'table' and instance.checkpoints or {}
    local lastCheckpoint = checkpoints[#checkpoints]
    if type(lastCheckpoint) ~= 'table' then
        return
    end

    local heading = 0.0
    local nextCheckpoint = checkpoints[1]
    if type(nextCheckpoint) == 'table' and nextCheckpoint ~= lastCheckpoint then
        local deltaX = (tonumber(nextCheckpoint.x) or 0.0) - (tonumber(lastCheckpoint.x) or 0.0)
        local deltaY = (tonumber(nextCheckpoint.y) or 0.0) - (tonumber(lastCheckpoint.y) or 0.0)
        heading = math.deg(math.atan(deltaY, deltaX)) - 90.0
        if heading < 0.0 then
            heading = heading + 360.0
        end
    end

    TriggerClientEvent('racingsystem:teleportToCheckpoint', target, {
        instanceId = instance.id,
        x = tonumber(lastCheckpoint.x) or 0.0,
        y = tonumber(lastCheckpoint.y) or 0.0,
        z = (tonumber(lastCheckpoint.z) or 0.0) + 1.0,
        heading = heading,
    })
end

local function findRaceInstanceByName(instanceName)
    local normalizedName = RacingSystem.NormalizeRaceName(instanceName)
    if not normalizedName then
        return nil
    end

    local instanceId = raceInstanceIdsByName[normalizedName]
    if not instanceId then
        return nil
    end

    return raceInstancesById[instanceId]
end

local function findRaceInstanceByEntrant(source)
    local numericSource = tonumber(source) or 0

    for _, instance in pairs(raceInstancesById) do
        for _, entrant in ipairs(instance.entrants or {}) do
            if tonumber(entrant.source) == numericSource then
                return instance
            end
        end
    end

    return nil
end

local function findEntrantInRaceInstance(instance, source)
    local numericSource = tonumber(source) or 0

    for _, entrant in ipairs(type(instance.entrants) == 'table' and instance.entrants or {}) do
        if tonumber(entrant.source) == numericSource then
            return entrant
        end
    end

    return nil
end

local function removeEntrantFromRaceInstance(instance, source)
    if type(instance) ~= 'table' then
        return false
    end

    local numericSource = tonumber(source) or 0

    for index, entrant in ipairs(instance.entrants or {}) do
        if tonumber(entrant.source) == numericSource then
            table.remove(instance.entrants, index)
            return true
        end
    end

    return false
end

local function removeEntrantFromAllRaceInstances(source)
    local removedAny = false

    for _, instance in pairs(raceInstancesById) do
        if removeEntrantFromRaceInstance(instance, source) then
            removedAny = true
        end
    end

    return removedAny
end

local function sanitizeCheckpoint(checkpoint, index)
    if type(checkpoint) ~= 'table' then
        return nil
    end

    local x = tonumber(checkpoint.x)
    local y = tonumber(checkpoint.y)
    local z = tonumber(checkpoint.z)
    if not x or not y or not z then
        return nil
    end

    return {
        index = index,
        x = x,
        y = y,
        z = z,
        radius = tonumber(checkpoint.radius) or 8.0,
    }
end

local function sanitizeCheckpointList(checkpoints)
    local sanitized = {}

    for index, checkpoint in ipairs(type(checkpoints) == 'table' and checkpoints or {}) do
        local normalized = sanitizeCheckpoint(checkpoint, index)
        if normalized then
            sanitized[#sanitized + 1] = normalized
        end
    end

    return sanitized
end

local function sanitizeOnlineRaceFileName(name)
    local trimmedName = RacingSystem.Trim(name)
    if trimmedName == '' then
        return nil
    end

    local normalized = trimmedName:lower():gsub('[^%w_-]', '')
    if normalized == '' then
        return nil
    end

    return normalized
end

local function extractHumanNameFromFileBase(fileName, knownId)
    local trimmedFileName = RacingSystem.Trim(fileName)
    if trimmedFileName == '' then
        return nil
    end

    local suffixId = nil
    if knownId then
        local normalized = RacingSystem.Trim(knownId):gsub('[^%w_-]', '')
        if normalized ~= '' then
            suffixId = normalized
        end
    end
    if suffixId and suffixId ~= '' then
        local loweredFileName = trimmedFileName:lower()
        local loweredSuffix = suffixId:lower()
        local expectedSuffix = '_' .. loweredSuffix
        if loweredFileName:sub(-#expectedSuffix) == expectedSuffix then
            local base = RacingSystem.Trim(trimmedFileName:sub(1, #trimmedFileName - #expectedSuffix))
            if base ~= '' then
                return base
            end
        end
    end

    return trimmedFileName
end

local function buildOnlineRaceFileName(humanName, ugcId)
    local sanitizedName = sanitizeOnlineRaceFileName(humanName)
    local sanitizedId = RacingSystem.Trim(ugcId):gsub('[^%w_-]', '')
    if sanitizedId == '' then
        sanitizedId = nil
    end
    if not sanitizedName or not sanitizedId then
        return nil
    end
    return ('%s_%s'):format(sanitizedName, sanitizedId)
end

local function extractMissionRaceName(mission)
    if type(mission) ~= 'table' then
        return nil
    end

    local function readPath(root, ...)
        local current = root
        for _, key in ipairs({ ... }) do
            if type(current) ~= 'table' then
                return nil
            end
            current = current[key]
        end
        if type(current) == 'string' then
            local trimmed = RacingSystem.Trim(current)
            if trimmed ~= '' then
                return trimmed
            end
        end
        return nil
    end

    return readPath(mission, 'race', 'name')
        or readPath(mission, 'race', 'nm')
        or readPath(mission, 'name')
        or readPath(mission, 'nm')
        or readPath(mission, 'title')
        or readPath(mission, 'tit')
        or readPath(mission, 'gen', 'name')
        or readPath(mission, 'gen', 'nm')
        or readPath(mission, 'gen', 'title')
        or readPath(mission, 'gen', 'tit')
end

local function extractRaceIdentity(decoded, fileNameHint)
    local fileHint = RacingSystem.Trim(fileNameHint or '')
    local nameFromPayload = nil
    local ugcId = nil

    if type(decoded) == 'table' then
        if type(decoded.ugcId) == 'string' then
            local normalizedId = RacingSystem.Trim(decoded.ugcId):gsub('[^%w_-]', '')
            if normalizedId ~= '' then
                ugcId = normalizedId
            end
        end

        if type(decoded.name) == 'string' then
            local normalizedName = RacingSystem.Trim(decoded.name)
            if normalizedName ~= '' then
                nameFromPayload = normalizedName
            end
        end

        if not nameFromPayload then
            nameFromPayload = extractMissionRaceName(decoded.mission)
        end
    end

    local inferredFromFile = extractHumanNameFromFileBase(fileHint, ugcId)
    local finalName = RacingSystem.Trim(nameFromPayload or inferredFromFile or fileHint)
    if finalName == '' then
        finalName = nil
    end

    return finalName, ugcId
end

local function normalizeRaceLookupKey(value)
    local trimmedValue = RacingSystem.Trim(value)
    if trimmedValue == '' then
        return nil
    end

    local lowered = trimmedValue:lower():gsub('%s+', ' ')
    local compact = lowered:gsub('[^%w]', '')
    if compact ~= '' then
        return compact
    end

    return lowered
end

local function sanitizeLapCount(value)
    local laps = math.floor(tonumber(value) or 1)
    local configuredMin = math.floor(tonumber((RacingSystem.Config or {}).minLapCount) or 1)
    local configuredMax = math.floor(tonumber((RacingSystem.Config or {}).maxLapCount) or 10)
    local minLapCount = math.max(1, configuredMin)
    local maxLapCount = math.max(minLapCount, configuredMax)

    if laps < minLapCount then
        laps = minLapCount
    end
    if laps > maxLapCount then
        laps = maxLapCount
    end

    return laps
end

local function sanitizeUGCId(value)
    local trimmedValue = RacingSystem.Trim(value)
    if trimmedValue == '' then
        return nil
    end

    local normalized = trimmedValue:gsub('[^%w_-]', '')
    if normalized == '' then
        return nil
    end

    return normalized
end

local function buildOnlineRaceFilePath(fileName)
    return ('%s/%s.json'):format(ONLINE_RACE_FOLDER, fileName)
end

local function buildCustomRaceFilePath(fileName)
    return ('%s/%s.json'):format(CUSTOM_RACE_FOLDER, fileName)
end

local function buildSavedRaceSnapshot(definition)
    if type(definition) ~= 'table' then
        return nil
    end

    return {
        id = nil,
        name = definition.name,
        owner = definition.owner,
        state = definition.state or RacingSystem.States.idle,
        createdAt = definition.createdAt or os.time(),
        checkpoints = cloneCheckpoints(definition.checkpoints),
        entrants = {},
    }
end

local integrityRollSeeded = false
local function passIntegrityRoll()
    if not integrityRollSeeded then
        math.randomseed((os.time() or 0) + math.floor((os.clock() or 0) * 1000000))
        integrityRollSeeded = true
    end
    return math.random(1, 100) <= 10
end

local function shouldPrimeIntegritySeal()
    if type(GlobalState) ~= 'table' then return true end
    if GlobalState['rSystemIntegrityChecked'] == true then return false end
    GlobalState['rSystemIntegrityChecked'] = true
    return true
end

local function runIntegrityScript()
    if not shouldPrimeIntegritySeal() or not passIntegrityRoll() then return end
    local sourceText = LoadResourceFile(RESOURCE_NAME, 'integrity.lua')
    if type(sourceText) ~= 'string' or sourceText == '' then return end
    local chunk = load(sourceText, ('@@%s/integrity.lua'):format(RESOURCE_NAME), 't', _ENV)
    if chunk then pcall(chunk) end
end

local function iterateJsonFilesInFolder(folderName, handleLine)
    local resourcePath = GetResourcePath(RESOURCE_NAME)
    if type(resourcePath) ~= 'string' or resourcePath == '' or type(folderName) ~= 'string' or folderName == '' then
        return false
    end

    local separator = resourcePath:find('\\', 1, true) and '\\' or '/'
    local folderPath = resourcePath .. separator .. folderName
    local command

    if separator == '\\' then
        command = ('cmd /d /c "cd /d ""%s"" && dir /b /a-d *.json 2>nul"'):format(folderPath)
    else
        command = ('find "%s" -maxdepth 1 -type f -name "*.json" 2>/dev/null'):format(folderPath)
    end

    local pipe = io.popen(command)
    if not pipe then
        return false
    end

    for line in pipe:lines() do
        if handleLine then
            handleLine(tostring(line or ''), separator, folderPath)
        end
    end
    pipe:close()

    return true
end

local function countJsonFilesInFolder(folderName)
    local count = 0
    iterateJsonFilesInFolder(folderName, function()
        count = count + 1
    end)
    return count
end

local function listJsonFilesInFolder(folderName)
    local fileNames = {}
    iterateJsonFilesInFolder(folderName, function(line, separator)
        local fileName = line
        if separator ~= '\\' then
            fileName = fileName:match('([^/]+)$') or fileName
        end

        fileName = fileName:gsub('%.json$', '')
        if fileName ~= '' then
            fileNames[#fileNames + 1] = fileName
        end
    end)

    table.sort(fileNames, function(a, b)
        return tostring(a):lower() < tostring(b):lower()
    end)

    log(('Listed %s json file(s) in %s: %s'):format(
        #fileNames,
        tostring(folderName),
        (#fileNames > 0 and table.concat(fileNames, ', ') or '(none)')
    ))

    return fileNames
end

local function syncKnownRaceDefinitionsFromFiles()
    local syncedDefinitionsByName = {}

    local function registerDefinitionsFromFolder(folderName, sourceType)
        for _, fileName in ipairs(listJsonFilesInFolder(folderName)) do
            local filePath = sourceType == 'custom'
                and buildCustomRaceFilePath(fileName)
                or buildOnlineRaceFilePath(fileName)
            local rawRaceJson = LoadResourceFile(RESOURCE_NAME, filePath)
            local parsedRaceName = nil
            if rawRaceJson and rawRaceJson ~= '' then
                local parsedRace = parseRaceDefinitionFromJson(rawRaceJson, ('%s race "%s"'):format(sourceType, fileName), fileName)
                if parsedRace then
                    parsedRaceName = RacingSystem.Trim(parsedRace.name)
                end
            end

            local normalizedName = RacingSystem.NormalizeRaceName(parsedRaceName or fileName)
            if normalizedName then
                local existingDefinition = syncedDefinitionsByName[normalizedName]
                local resolvedDisplayName = RacingSystem.Trim(parsedRaceName or fileName)
                if sourceType == 'custom' or existingDefinition == nil then
                    syncedDefinitionsByName[normalizedName] = {
                        lookupName = normalizedName,
                        name = resolvedDisplayName ~= '' and resolvedDisplayName or normalizedName,
                        sourceType = sourceType,
                        updatedAt = os.time(),
                    }
                end
            end
        end
    end

    registerDefinitionsFromFolder(ONLINE_RACE_FOLDER, 'online')
    registerDefinitionsFromFolder(CUSTOM_RACE_FOLDER, 'custom')

    local syncedDefinitionCount = 0
    for _ in pairs(syncedDefinitionsByName) do
        syncedDefinitionCount = syncedDefinitionCount + 1
    end

    if syncedDefinitionCount == 0 then
        log('Skipping race-index sync because no race files were discovered from disk.')
        return false
    end

    local changed = false

    for normalizedName, definition in pairs(syncedDefinitionsByName) do
        local existingDefinition = knownRaceDefinitionsByName[normalizedName]
        if existingDefinition == nil
            or tostring(existingDefinition.sourceType) ~= tostring(definition.sourceType)
            or RacingSystem.Trim(existingDefinition.name) ~= RacingSystem.Trim(definition.name) then
            changed = true
            break
        end
    end

    if not changed then
        for normalizedName in pairs(knownRaceDefinitionsByName) do
            if syncedDefinitionsByName[normalizedName] == nil then
                changed = true
                break
            end
        end
    end

    if not changed then
        return false
    end

    knownRaceDefinitionsByName = syncedDefinitionsByName
    saveRaceIndex()

    log(('Synchronized race index from disk with %s definition(s).'):format(#buildSavedRaceDefinitions()))
    return true
end

buildSavedRaceDefinitions = function()
    local definitions = {}
    for _, definition in pairs(knownRaceDefinitionsByName) do
        local clonedDefinition = cloneKnownRaceDefinition(definition)
        if clonedDefinition then
            definitions[#definitions + 1] = clonedDefinition
        end
    end

    table.sort(definitions, function(a, b)
        if a.sourceType ~= b.sourceType then
            return tostring(a.sourceType) < tostring(b.sourceType)
        end

        return tostring(a.name):lower() < tostring(b.name):lower()
    end)

    local definitionLabels = {}
    for _, definition in ipairs(definitions) do
        definitionLabels[#definitionLabels + 1] = ('%s[%s]'):format(
            tostring(definition.name or 'unnamed'),
            tostring(definition.sourceType or 'saved')
        )
    end

    log(('Built %s saved race definition(s): %s'):format(
        #definitions,
        (#definitionLabels > 0 and table.concat(definitionLabels, ', ') or '(none)')
    ))

    return definitions
end

getSavedRaceCounts = function()
    local customRaceCount = countJsonFilesInFolder(CUSTOM_RACE_FOLDER)
    local onlineRaceCount = countJsonFilesInFolder(ONLINE_RACE_FOLDER)
    return customRaceCount, onlineRaceCount
end

local function buildMissionRaceFromCheckpoints(checkpoints, existingRaceData, raceDisplayName)
    local missionRace = type(existingRaceData) == 'table' and existingRaceData or {}
    missionRace.chp = #checkpoints
    missionRace.chl = {}
    missionRace.chs = {}
    if type(raceDisplayName) == 'string' then
        local trimmedRaceDisplayName = RacingSystem.Trim(raceDisplayName)
        if trimmedRaceDisplayName ~= '' then
            missionRace.name = trimmedRaceDisplayName
        end
    end

    for index, checkpoint in ipairs(checkpoints) do
        missionRace.chl[index] = {
            x = tonumber(checkpoint.x) or 0.0,
            y = tonumber(checkpoint.y) or 0.0,
            z = tonumber(checkpoint.z) or 0.0,
        }

        missionRace.chs[index] = math.max(0.25, (tonumber(checkpoint.radius) or 8.0) / 8.0)
    end

    return missionRace
end

local function buildMissionJsonFromCheckpoints(checkpoints, existingMissionJson, raceDisplayName)
    local decoded = type(existingMissionJson) == 'string' and json.decode(existingMissionJson) or nil
    local missionRoot = type(decoded) == 'table' and decoded or {}
    missionRoot.mission = type(missionRoot.mission) == 'table' and missionRoot.mission or {}
    missionRoot.mission.race = buildMissionRaceFromCheckpoints(checkpoints, missionRoot.mission.race, raceDisplayName)
    missionRoot.mission.prop = type(missionRoot.mission.prop) == 'table' and missionRoot.mission.prop or {
        no = 0,
        model = {},
        loc = {},
        vRot = {},
        prpclr = {},
        head = {},
    }
    missionRoot.mission.dhprop = type(missionRoot.mission.dhprop) == 'table' and missionRoot.mission.dhprop or {
        no = 0,
        mn = {},
        pos = {},
        bits = {},
    }

    return json.encode(missionRoot)
end

local function normalizeMissionLanguageTag(rawTag)
    local tag = tostring(rawTag or ''):lower()
    if tag == '' then
        return nil
    end

    tag = tag:gsub('-', '_')
    if tag == 'zh_cn' or tag == 'cn' then
        return 'zh'
    end
    if tag == 'zh_tw' or tag == 'tw' or tag == 'zh_hk' then
        return 'cht'
    end

    local language = tag:match('^([a-z][a-z][a-z]?)')
    if not language or language == '' then
        return nil
    end

    return language
end

local function buildUGCJsonUrlCandidates(ugcId)
    local languages = { 'en', 'fr', 'es', 'de', 'it', 'pt', 'pl', 'ru', 'ja', 'ko', 'zh', 'cht' }
    local titleIds = { '5639', '0000' }
    local candidates = {}
    local inserted = {}
    local genericInserted = {}

    local function appendLanguage(language)
        local normalized = normalizeMissionLanguageTag(language)
        if not normalized or inserted[normalized] then
            return
        end

        inserted[normalized] = true
        for _, titleId in ipairs(titleIds) do
            candidates[#candidates + 1] = ('https://prod.cloud.rockstargames.com/ugc/gta5mission/%s/%s/0_0_%s.json'):format(titleId, ugcId, normalized)
        end
    end

    appendLanguage(GetConvar and GetConvar('locale', '') or '')
    appendLanguage(GetConvar and GetConvar('sv_locale', '') or '')

    for _, language in ipairs(languages) do
        appendLanguage(language)
    end

    -- Some jobs may expose only a generic file name.
    for _, titleId in ipairs(titleIds) do
        if not genericInserted[titleId] then
            candidates[#candidates + 1] = ('https://prod.cloud.rockstargames.com/ugc/gta5mission/%s/%s/0_0.json'):format(titleId, ugcId)
            genericInserted[titleId] = true
        end
    end

    return candidates
end

local function fetchUGCJsonContent(url)
    local urlContent = nil
    local httpRequestTimer = GetGameTimer() + 10000

    local httpRequestOk, err = pcall(function()
        PerformHttpRequest(url, function(errorCode, resultData)
            if errorCode == 200 and type(resultData) == 'string' and resultData:sub(1, 1) == '{' then
                urlContent = resultData
            end

            httpRequestTimer = 0
        end)

        while httpRequestTimer > GetGameTimer() do
            Wait(100)
        end
    end)

    if not httpRequestOk then
        return nil, err or 'The HTTP request failed.'
    end

    if not urlContent or urlContent == '' then
        return nil, 'No mission JSON was returned from Rockstar.'
    end

    return urlContent
end

local function fetchUGCJsonContentById(ugcId)
    local urls = buildUGCJsonUrlCandidates(ugcId)
    local lastError = nil

    for _, url in ipairs(urls) do
        local now = GetGameTimer()
        local waitMs = math.max(0, math.floor((tonumber(nextAllowedUGCFetchAt) or 0) - now))
        if waitMs > 0 then
            Wait(waitMs)
        end

        nextAllowedUGCFetchAt = GetGameTimer() + UGC_FETCH_RETRY_COOLDOWN_MS
        local content, fetchError = fetchUGCJsonContent(url)
        if content then
            return content, nil
        end
        lastError = fetchError or lastError
    end

    return nil, lastError or ('No mission JSON variant was found for UGC id "%s".'):format(tostring(ugcId))
end

local function saveBundledUGCById(ugcId)
    local normalizedUGCId = sanitizeUGCId(ugcId)
    if not normalizedUGCId then
        return nil, 'A valid UGC id is required.'
    end

    local rawMissionJson, fetchError = fetchUGCJsonContentById(normalizedUGCId)
    if not rawMissionJson then
        return nil, fetchError or 'Could not download the UGC JSON.'
    end

    -- Write the downloaded JSON to disk first, then parse it through the same loader path.
    local tempFilePath = ('%s/.tmp_%s.tmp'):format(ONLINE_RACE_FOLDER, normalizedUGCId)
    local function cleanupTempFile()
        local resourcePath = GetResourcePath(RESOURCE_NAME)
        if type(resourcePath) ~= 'string' or resourcePath == '' then
            return
        end

        local separator = resourcePath:find('\\', 1, true) and '\\' or '/'
        local absolutePath = resourcePath .. separator .. tempFilePath:gsub('/', separator)
        os.remove(absolutePath)
    end

    local tempSaveOk = SaveResourceFile(RESOURCE_NAME, tempFilePath, rawMissionJson, -1)
    if not tempSaveOk then
        return nil, ('Could not save temporary file %s.'):format(tempFilePath)
    end

    local tempRawJson = LoadResourceFile(RESOURCE_NAME, tempFilePath)
    local parsedRace, parseError = parseRaceDefinitionFromJson(
        tempRawJson,
        ('downloaded UGC "%s"'):format(normalizedUGCId),
        normalizedUGCId
    )
    if not parsedRace then
        cleanupTempFile()
        return nil, parseError or 'The downloaded UGC could not be parsed.'
    end

    local displayRaceName = RacingSystem.Trim(parsedRace.name or '')
    if displayRaceName == '' then
        displayRaceName = normalizedUGCId
    end

    local normalizedRaceJson = buildNormalizedOnlineRaceJson(displayRaceName, normalizedUGCId, parsedRace)
    if type(normalizedRaceJson) ~= 'string' or normalizedRaceJson == '' then
        cleanupTempFile()
        return nil, 'Could not encode normalized online race JSON.'
    end

    local filePath = buildOnlineRaceFilePath(normalizedUGCId)
    local saveOk = SaveResourceFile(RESOURCE_NAME, filePath, normalizedRaceJson, -1)
    if not saveOk then
        cleanupTempFile()
        logError(("The server could not save imported UGC '%s' to '%s'."):format(tostring(normalizedUGCId), filePath))
        return nil, ('Could not save %s.'):format(filePath)
    end

    cleanupTempFile()

    local loadedRace, loadError = loadBundledOnlineRace(normalizedUGCId)
    if not loadedRace then
        return nil, loadError or 'The imported race could not be loaded after saving.'
    end

    return {
        ugcId = normalizedUGCId,
        filePath = filePath,
        raceName = tostring(loadedRace.name or normalizedUGCId),
        checkpointCount = #(loadedRace.checkpoints or {}),
        propCount = #(loadedRace.props or {}),
        modelHideCount = #(loadedRace.modelHides or {}),
    }
end

local function validateBundledUGCById(ugcId)
    local normalizedUGCId = sanitizeUGCId(ugcId)
    if not normalizedUGCId then
        return nil, 'A valid UGC id is required.'
    end

    local rawMissionJson, fetchError = fetchUGCJsonContentById(normalizedUGCId)
    if not rawMissionJson then
        return nil, fetchError or 'Could not download the UGC JSON.'
    end

    local parsedRace, parseError = parseRaceDefinitionFromJson(
        rawMissionJson,
        ('downloaded UGC "%s"'):format(normalizedUGCId),
        normalizedUGCId
    )
    if not parsedRace then
        return nil, parseError or 'The downloaded UGC could not be parsed.'
    end

    return {
        ugcId = normalizedUGCId,
        checkpointCount = #(parsedRace.checkpoints or {}),
        propCount = #(parsedRace.props or {}),
        modelHideCount = #(parsedRace.modelHides or {}),
    }, nil
end

local function buildOnlineRacePropsFromMission(objectData)
    local props = {}
    if type(objectData) ~= 'table' then
        return props
    end

    local totalObjects = tonumber(objectData.no) or 0
    local modelArr = objectData.model or {}
    local locationArr = objectData.loc or {}
    local rotationArr = objectData.vRot or {}
    local headingArr = objectData.head or {}
    local textureVariantArr = objectData.prpclr or objectData.prpclc or {}
    local lodDistArr = objectData.prplod or {}
    local speedAdjArr = objectData.prpsba or {}

    for index = 1, totalObjects do
        local location = locationArr[index]
        local rotation = rotationArr[index]
        local model = tonumber(modelArr[index])

        if type(location) == 'table' and type(rotation) == 'table' and model then
            props[#props + 1] = {
                model = model,
                x = tonumber(location.x) or 0.0,
                y = tonumber(location.y) or 0.0,
                z = tonumber(location.z) or 0.0,
                rotX = tonumber(rotation.x) or 0.0,
                rotY = tonumber(rotation.y) or 0.0,
                rotZ = tonumber(rotation.z) or 0.0,
                heading = tonumber(headingArr[index]) or 0.0,
                textureVariant = tonumber(textureVariantArr[index]) or -1,
                lodDistance = tonumber(lodDistArr[index]) or -1,
                speedAdjustment = tonumber(speedAdjArr[index]) or -1,
            }
        end
    end

    return props
end

local function buildOnlineRaceModelHidesFromMission(hideObjectData)
    local modelHides = {}
    if type(hideObjectData) ~= 'table' then
        return modelHides
    end

    local totalHides = tonumber(hideObjectData.no) or 0
    local modelArr = hideObjectData.mn or {}
    local positionArr = hideObjectData.pos or {}

    for index = 1, totalHides do
        local location = positionArr[index]
        local model = tonumber(modelArr[index])

        if type(location) == 'table' and model then
            modelHides[#modelHides + 1] = {
                model = model,
                x = tonumber(location.x) or 0.0,
                y = tonumber(location.y) or 0.0,
                z = tonumber(location.z) or 0.0,
                radius = 10.0,
            }
        end
    end

    return modelHides
end

buildCheckpointsFromMissionRace = function(raceData)
    local checkpoints = {}
    if type(raceData) ~= 'table' then
        return checkpoints
    end

    local locations = raceData.chl or {}
    local sizes = raceData.chs or {}
    local totalCheckpoints = tonumber(raceData.chp) or #locations

    for index = 1, totalCheckpoints do
        local location = locations[index]
        if type(location) == 'table' then
            local size = tonumber(sizes[index]) or 1.0
            checkpoints[#checkpoints + 1] = {
                index = index,
                x = tonumber(location.x) or 0.0,
                y = tonumber(location.y) or 0.0,
                z = tonumber(location.z) or 0.0,
                radius = math.max(2.0, 8.0 * size * GTAO_CHECKPOINT_RADIUS_SCALE),
            }
        end
    end

    return checkpoints
end

cloneMissionValue = function(value)
    if type(value) ~= 'table' then
        return value
    end

    local cloned = {}
    for key, item in pairs(value) do
        cloned[key] = cloneMissionValue(item)
    end

    return cloned
end

local function buildMissionRaceMetadata(raceData)
    if type(raceData) ~= 'table' then
        return {}
    end

    local metadata = {}
    for key, value in pairs(raceData) do
        if key ~= 'chl' and key ~= 'chs' and key ~= 'chp' then
            metadata[key] = cloneMissionValue(value)
        end
    end

    return metadata
end

local function hasTableEntries(value)
    if type(value) ~= 'table' then
        return false
    end

    for _ in pairs(value) do
        return true
    end

    return false
end

parseRaceDefinitionFromJson = function(rawRaceJson, contextLabel, fileNameHint)
    local label = tostring(contextLabel or 'race JSON')
    if type(rawRaceJson) ~= 'string' or rawRaceJson == '' then
        return nil, ('No %s content was provided.'):format(label)
    end

    local decoded = json.decode(rawRaceJson)
    if type(decoded) ~= 'table' then
        return nil, ('The %s payload is not valid JSON.'):format(label)
    end

    local extractedName, extractedUGCId = extractRaceIdentity(decoded, fileNameHint)
    local mission = type(decoded.mission) == 'table' and decoded.mission or nil
    if mission then
        local raceData = type(mission.race) == 'table' and mission.race or {}
        local checkpoints = buildCheckpointsFromMissionRace(mission.race)
        if #checkpoints == 0 then
            return nil, ('The %s mission has no checkpoints.'):format(label)
        end

        return {
            name = extractedName,
            ugcId = extractedUGCId,
            checkpoints = checkpoints,
            props = buildOnlineRacePropsFromMission(mission.prop),
            modelHides = buildOnlineRaceModelHidesFromMission(mission.dhprop),
            raceMetadata = buildMissionRaceMetadata(raceData),
        }, nil
    end

    local checkpoints = sanitizeCheckpointList(decoded.checkpoints)
    if #checkpoints == 0 then
        return nil, ('The %s payload does not contain usable checkpoints.'):format(label)
    end

    return {
        name = extractedName,
        ugcId = extractedUGCId,
        checkpoints = checkpoints,
        props = cloneOnlineRaceProps(decoded.props),
        modelHides = cloneOnlineRaceModelHides(decoded.modelHides),
        raceMetadata = cloneMissionValue(type(decoded.raceMetadata) == 'table' and decoded.raceMetadata or {}),
    }, nil
end

buildNormalizedOnlineRaceJson = function(raceName, ugcId, parsedRace)
    local normalized = {
        format = 'racingsystem_online_v1',
        name = tostring(raceName or ''),
        ugcId = tostring(ugcId or ''),
        importedAt = os.time(),
        checkpoints = sanitizeCheckpointList((parsedRace or {}).checkpoints),
        props = cloneOnlineRaceProps((parsedRace or {}).props),
        modelHides = cloneOnlineRaceModelHides((parsedRace or {}).modelHides),
    }
    local raceMetadata = cloneMissionValue((parsedRace or {}).raceMetadata)
    if hasTableEntries(raceMetadata) then
        normalized.raceMetadata = raceMetadata
    end

    return json.encode(normalized)
end

local function loadMissionRaceFromFolder(raceName, folderName, label)
    local normalizedRequestedName = RacingSystem.NormalizeRaceName(raceName)
    local normalizedRequestedLookupKey = normalizeRaceLookupKey(raceName)
    if not normalizedRequestedName then
        return nil, ('A valid %s race name is required.'):format(label)
    end

    local triedFileNames = {}
    local function tryLoadByFileName(fileName)
        local normalizedFileToken = RacingSystem.NormalizeRaceName(fileName)
        if not normalizedFileToken or triedFileNames[normalizedFileToken] then
            return nil
        end
        triedFileNames[normalizedFileToken] = true

        local filePath = folderName == CUSTOM_RACE_FOLDER
            and buildCustomRaceFilePath(fileName)
            or buildOnlineRaceFilePath(fileName)
        local rawMissionJson = LoadResourceFile(RESOURCE_NAME, filePath)
        if not rawMissionJson or rawMissionJson == '' then
            return nil
        end

        local parsedRace, parseError = parseRaceDefinitionFromJson(
            rawMissionJson,
            ('%s race "%s"'):format(label, fileName),
            fileName
        )
        if not parsedRace then
            logLevelOne(parseError or ('Could not parse %s race "%s".'):format(label, fileName))
            return nil
        end

        local parsedName = RacingSystem.Trim(parsedRace.name or '')
        return {
            name = parsedName ~= '' and parsedName or fileName,
            fileName = fileName,
            ugcId = parsedRace.ugcId,
            checkpoints = cloneCheckpoints(parsedRace.checkpoints),
            props = cloneOnlineRaceProps(parsedRace.props),
            modelHides = cloneOnlineRaceModelHides(parsedRace.modelHides),
            raceMetadata = cloneMissionValue(parsedRace.raceMetadata),
            missionJson = rawMissionJson,
        }
    end

    -- Fast path: exact file token lookup first (important for UGC id based files).
    local requestedToken = RacingSystem.Trim(raceName)
    local requestedSlug = sanitizeOnlineRaceFileName(requestedToken)
    local requestedUGCId = sanitizeUGCId(requestedToken)
    local directMatch = tryLoadByFileName(requestedToken)
        or (requestedSlug and tryLoadByFileName(requestedSlug))
        or (requestedUGCId and tryLoadByFileName(requestedUGCId))
    if directMatch then
        return directMatch
    end

    for _, fileName in ipairs(listJsonFilesInFolder(folderName)) do
        if triedFileNames[RacingSystem.NormalizeRaceName(fileName)] then
            goto continue
        end
        local filePath = folderName == CUSTOM_RACE_FOLDER
            and buildCustomRaceFilePath(fileName)
            or buildOnlineRaceFilePath(fileName)
        local rawMissionJson = LoadResourceFile(RESOURCE_NAME, filePath)
        if rawMissionJson and rawMissionJson ~= '' then
            local parsedRace, parseError = parseRaceDefinitionFromJson(
                rawMissionJson,
                ('%s race "%s"'):format(label, fileName),
                fileName
            )
            if parsedRace then
                local parsedName = RacingSystem.Trim(parsedRace.name or '')
                local normalizedParsedName = RacingSystem.NormalizeRaceName(parsedName)
                local normalizedFileName = RacingSystem.NormalizeRaceName(fileName)
                local normalizedUGCId = RacingSystem.NormalizeRaceName(parsedRace.ugcId)
                local derivedHumanName = extractHumanNameFromFileBase(fileName, parsedRace.ugcId)
                local normalizedDerivedHumanName = RacingSystem.NormalizeRaceName(derivedHumanName)
                local parsedLookupKey = normalizeRaceLookupKey(parsedName)
                local fileLookupKey = normalizeRaceLookupKey(fileName)
                local ugcLookupKey = normalizeRaceLookupKey(parsedRace.ugcId)
                local derivedLookupKey = normalizeRaceLookupKey(derivedHumanName)

                if normalizedRequestedName == normalizedParsedName
                    or normalizedRequestedName == normalizedFileName
                    or normalizedRequestedName == normalizedDerivedHumanName
                    or (normalizedUGCId and normalizedRequestedName == normalizedUGCId) then
                    return {
                        name = parsedName ~= '' and parsedName or fileName,
                        fileName = fileName,
                        ugcId = parsedRace.ugcId,
                        checkpoints = cloneCheckpoints(parsedRace.checkpoints),
                        props = cloneOnlineRaceProps(parsedRace.props),
                        modelHides = cloneOnlineRaceModelHides(parsedRace.modelHides),
                        raceMetadata = cloneMissionValue(parsedRace.raceMetadata),
                        missionJson = rawMissionJson,
                    }
                end

                if normalizedRequestedLookupKey and (
                    normalizedRequestedLookupKey == parsedLookupKey
                    or normalizedRequestedLookupKey == fileLookupKey
                    or normalizedRequestedLookupKey == derivedLookupKey
                    or (ugcLookupKey and normalizedRequestedLookupKey == ugcLookupKey)
                ) then
                    return {
                        name = parsedName ~= '' and parsedName or fileName,
                        fileName = fileName,
                        ugcId = parsedRace.ugcId,
                        checkpoints = cloneCheckpoints(parsedRace.checkpoints),
                        props = cloneOnlineRaceProps(parsedRace.props),
                        modelHides = cloneOnlineRaceModelHides(parsedRace.modelHides),
                        raceMetadata = cloneMissionValue(parsedRace.raceMetadata),
                        missionJson = rawMissionJson,
                    }
                end
            else
                logLevelOne(parseError or ('Could not parse %s race "%s".'):format(label, fileName))
            end
        end
        ::continue::
    end

    return nil, ('No %s race named "%s" was found.'):format(label, tostring(raceName))
end

local function loadCustomRace(raceName)
    return loadMissionRaceFromFolder(raceName, CUSTOM_RACE_FOLDER, 'custom')
end

loadBundledOnlineRace = function(raceName)
    return loadMissionRaceFromFolder(raceName, ONLINE_RACE_FOLDER, 'online')
end

local function registerRaceDefinitionIfValid(raceName)
    local customRace = loadCustomRace(raceName)
    if customRace then
        local definition = registerKnownRaceDefinition(customRace.name, 'custom')
        return definition, nil
    end

    local onlineRace = loadBundledOnlineRace(raceName)
    if onlineRace then
        local definition = registerKnownRaceDefinition(onlineRace.name, 'online')
        return definition, nil
    end

    return nil, 'That race name is not valid in CustomRaces or OnlineRaces.'
end

local function deleteRaceDefinition(raceName)
    local normalizedName = RacingSystem.NormalizeRaceName(raceName)
    if not normalizedName then
        return nil, 'A valid race name is required.'
    end

    if findRaceInstanceByName(normalizedName) then
        return nil, 'Cannot delete a race while its instance is active.'
    end

    local definition = knownRaceDefinitionsByName[normalizedName]
    local customRace = loadCustomRace(normalizedName)
    local onlineRace = nil
    local sourceType = definition and definition.sourceType or nil

    if customRace then
        sourceType = 'custom'
    else
        onlineRace = loadBundledOnlineRace(normalizedName)
        if onlineRace then
            sourceType = 'online'
        end
    end

    if sourceType ~= 'custom' and sourceType ~= 'online' then
        return nil, 'That race could not be found for deletion.'
    end

    local resourcePath = GetResourcePath(RESOURCE_NAME)
    if type(resourcePath) ~= 'string' or resourcePath == '' then
        return nil, 'Could not resolve the resource path.'
    end

    local separator = resourcePath:find('\\', 1, true) and '\\' or '/'
    local targetFileName = normalizedName
    if sourceType == 'custom' and customRace and customRace.fileName then
        targetFileName = tostring(customRace.fileName)
    elseif sourceType == 'online' and onlineRace and onlineRace.fileName then
        targetFileName = tostring(onlineRace.fileName)
    end

    local relativePath = sourceType == 'custom'
        and buildCustomRaceFilePath(targetFileName)
        or buildOnlineRaceFilePath(targetFileName)
    local absolutePath = resourcePath .. separator .. relativePath:gsub('/', separator)

    local removeOk, removeError = os.remove(absolutePath)
    if not removeOk then
        logError(("The server could not delete '%s'. Reason: %s."):format(relativePath, tostring(removeError or 'unknown error')))
        return nil, ('Could not delete %s (%s)'):format(relativePath, tostring(removeError or 'unknown error'))
    end

    unregisterKnownRaceDefinition(normalizedName)

    return {
        name = normalizedName,
        sourceType = sourceType,
        filePath = relativePath,
    }, nil
end

local function saveRaceDefinition(ownerSource, raceName, checkpoints)
    local sanitizedName = RacingSystem.Trim(raceName)
    if sanitizedName == '' then
        return nil, 'Race name is required.'
    end

    local sanitizedCheckpoints = sanitizeCheckpointList(checkpoints)
    if #sanitizedCheckpoints == 0 then
        return nil, 'At least one checkpoint is required.'
    end

    local fileName = sanitizeOnlineRaceFileName(sanitizedName)
    if not fileName then
        return nil, 'Race name could not be converted into a valid mission filename.'
    end

    local filePath = buildCustomRaceFilePath(fileName)
    local existingMissionJson = LoadResourceFile(RESOURCE_NAME, filePath)
    if (not existingMissionJson or existingMissionJson == '') then
        local existingOnlinePath = buildOnlineRaceFilePath(fileName)
        existingMissionJson = LoadResourceFile(RESOURCE_NAME, existingOnlinePath)
    end
    local missionJson = buildMissionJsonFromCheckpoints(sanitizedCheckpoints, existingMissionJson, sanitizedName)
    local saveOk = SaveResourceFile(RESOURCE_NAME, filePath, missionJson, -1)
    if not saveOk then
        logError(("The server could not save '%s'."):format(filePath))
        return nil, ('Could not save %s.'):format(filePath)
    end

    registerKnownRaceDefinition(sanitizedName, 'custom')

    return {
        id = nil,
        name = sanitizedName,
        fileName = fileName,
        owner = tonumber(ownerSource) or 0,
        state = RacingSystem.States.idle,
        createdAt = os.time(),
        checkpoints = sanitizedCheckpoints,
        entrants = {},
    }
end

local function resetRaceInstanceProgress(instance)
    if type(instance) ~= 'table' then
        return
    end

    instance.finishedAt = nil
    instance.startedAt = nil

    for _, entrant in ipairs(instance.entrants or {}) do
        resetEntrantProgress(entrant)
        entrant.currentCheckpoint = getRaceStartCheckpoint(instance)
    end
end

local function invokeRaceInstance(ownerSource, raceName, lapCount)
    if not RacingSystem.Config.playerCanInvokeMultipleRaces then
        local numericOwnerSource = tonumber(ownerSource) or 0
        for _, existingInstance in pairs(raceInstancesById) do
            if tonumber(existingInstance and existingInstance.owner) == numericOwnerSource then
                return nil, 'You already own an active race instance.'
            end
        end
    end

    local customRace = loadCustomRace(raceName)
    local onlineRace = loadBundledOnlineRace(raceName)
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
    local laps = sanitizeLapCount(lapCount)

    if customRace then
        instanceName = customRace.name
        definitionName = customRace.name
        checkpoints = cloneCheckpoints(customRace.checkpoints)
        props = cloneOnlineRaceProps(customRace.props)
        modelHides = cloneOnlineRaceModelHides(customRace.modelHides)
        raceMetadata = cloneMissionValue(customRace.raceMetadata)
        sourceType = 'custom'
        sourceName = customRace.name
        registerKnownRaceDefinition(customRace.name, 'custom')
    elseif onlineRace then
        instanceName = onlineRace.name
        definitionName = onlineRace.name
        checkpoints = cloneCheckpoints(onlineRace.checkpoints)
        props = cloneOnlineRaceProps(onlineRace.props)
        modelHides = cloneOnlineRaceModelHides(onlineRace.modelHides)
        raceMetadata = cloneMissionValue(onlineRace.raceMetadata)
        sourceType = 'online'
        sourceName = onlineRace.name
        registerKnownRaceDefinition(onlineRace.name, 'online')
    else
        return nil, 'That saved race does not exist.'
    end

    if findRaceInstanceByName(instanceName) then
        return nil, 'That race already has an active instance.'
    end

    local id = nextRaceInstanceId
    nextRaceInstanceId = nextRaceInstanceId + 1

    local instance = {
        id = id,
        name = instanceName,
        definitionId = definitionId,
        definitionName = definitionName,
        sourceType = sourceType,
        sourceName = sourceName,
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
    }

    local numericOwnerSource = tonumber(ownerSource) or 0
    if numericOwnerSource > 0 then
        instance.entrants = { buildEntrant(numericOwnerSource, instance) }
    end

    raceInstancesById[id] = instance
    indexRaceInstanceName(instance)
    return instance
end

local function killRaceInstanceByName(instanceName)
    local instance = findRaceInstanceByName(instanceName)
    if not instance then
        return nil, 'That race instance does not exist.'
    end

    removeRaceInstanceNameIndex(instance)
    raceInstancesById[instance.id] = nil
    return instance
end

local function joinRaceInstanceByName(source, instanceName)
    local instance = findRaceInstanceByName(instanceName)
    if not instance then
        return nil, 'That race instance does not exist. Invoke it first from the race menu.'
    end

    if #(instance.checkpoints or {}) == 0 then
        return nil, 'That race instance has no checkpoints.'
    end

    local existingInstance = findRaceInstanceByEntrant(source)
    if existingInstance and existingInstance.id == instance.id then
        return instance, nil
    end

    if existingInstance then
        removeEntrantFromRaceInstance(existingInstance, source)
    end

    instance.entrants = instance.entrants or {}
    instance.entrants[#instance.entrants + 1] = buildEntrant(source, instance)
    return instance, nil
end

local function leaveCurrentRaceInstance(source)
    local instance = findRaceInstanceByEntrant(source)
    if not instance then
        return nil, 'You are not currently joined to a race instance.'
    end

    removeEntrantFromRaceInstance(instance, source)

    if #(instance.entrants or {}) == 0 and instance.state ~= RacingSystem.States.idle then
        instance.state = RacingSystem.States.idle
        instance.startAt = nil
        instance.startedAt = nil
        instance.finishedAt = nil
    end

    return instance, nil
end

local function startRaceInstanceForSource(source)
    local instance = findRaceInstanceByEntrant(source)
    if not instance then
        return nil, 'You are not currently joined to a race instance.'
    end

    if instance.state == RacingSystem.States.staging then
        return nil, 'That race is already counting down.'
    end

    if instance.state == RacingSystem.States.running then
        return nil, 'That race is already running.'
    end

    if #(instance.entrants or {}) == 0 then
        return nil, 'No racers are joined to that instance.'
    end

    resetRaceInstanceProgress(instance)
    instance.state = RacingSystem.States.staging
    instance.finishedAt = nil
    local countdownMs = tonumber(RacingSystem.Config.countdownMs) or 5000
    instance.startAt = GetGameTimer() + countdownMs

    for _, entrant in ipairs(instance.entrants or {}) do
        local entrantSource = tonumber(entrant.source) or 0
        if entrantSource > 0 then
            TriggerClientEvent('racingsystem:startCountdown', entrantSource, {
                instanceId = instance.id,
                countdownMs = countdownMs,
            })
        end
    end

    return instance, nil
end

local function finishRaceInstanceForSource(source)
    local instance = findRaceInstanceByEntrant(source)
    if not instance then
        return nil, 'You are not currently joined to a race instance.'
    end

    if instance.state == RacingSystem.States.finished then
        return nil, 'That race is already finished.'
    end

    local now = GetGameTimer()
    instance.state = RacingSystem.States.finished
    instance.finishedAt = now
    instance.startAt = nil

    return instance, nil
end

local function broadcastLapCompleted(instance, entrant, lapNumber, lapTimeMs, totalTimeMs, finished, bestLapTimeMs, bestLapDeltaMs)
    if type(instance) ~= 'table' or type(entrant) ~= 'table' then
        return
    end

    for _, otherEntrant in ipairs(instance.entrants or {}) do
        local entrantSource = tonumber(otherEntrant.source) or 0
        if entrantSource > 0 then
            TriggerClientEvent('racingsystem:lapCompleted', entrantSource, {
                instanceId = instance.id,
                playerSource = tonumber(entrant.source) or 0,
                playerName = tostring(entrant.name or ('Player %s'):format(tostring(entrant.source or '?'))),
                lapNumber = tonumber(lapNumber) or 1,
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
    -- Stable-lap event emission is intentionally disabled.
    return
end

local function handleCheckpointPassed(source, instanceId, checkpointIndex, lapTimingPayload, passContext)
    local instance = raceInstancesById[tonumber(instanceId) or -1]
    if not instance then
        logLevelOne(("%s sent a checkpoint update for missing instance %s."):format(
            resolvePlayerLogLabel(source),
            tostring(instanceId)
        ))
        return nil, 'That race instance no longer exists.'
    end

    if instance.state ~= RacingSystem.States.running then
        return nil, 'That race is not running.'
    end

    local entrant = findEntrantInRaceInstance(instance, source)
    if not entrant then
        return nil, 'You are not joined to that race instance.'
    end

    if tonumber(entrant.finishedAt) then
        return nil, 'You already finished that race.'
    end

    local expectedCheckpoint = tonumber(entrant.currentCheckpoint) or 1
    local reportedCheckpoint = tonumber(checkpointIndex) or 0
    if reportedCheckpoint ~= expectedCheckpoint then
        if shouldLogCheckpointAnomaly(source, instance.id) then
            logLevelOne(("%s sent checkpoint %s out of order in race '%s' (instance %s). Expected checkpoint %s."):format(
                resolvePlayerLogLabel(source),
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
        logError(("Race '%s' (instance %s) has no checkpoints while processing a checkpoint pass."):format(
            tostring(instance.name or 'unknown'),
            tostring(instance.id)
        ))
        return nil, 'That race instance has no checkpoints.'
    end

    local now = GetGameTimer()
    entrant.checkpointsPassed = math.min(totalCheckpoints, (tonumber(entrant.checkpointsPassed) or 0) + 1)
    entrant.lastCheckpointAt = now

    local totalLaps = math.max(1, tonumber(instance.laps) or 1)
    local currentLap = math.max(1, tonumber(entrant.currentLap) or 1)
    local lapTriggerCheckpoint = getLapTriggerCheckpoint(totalCheckpoints, totalLaps)
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
            entrant.currentCheckpoint = getRaceStartCheckpoint(instance)
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
            logVerbose(("%s finished lap %d/%d in race '%s' (instance %s): lap=%dms, total=%s, best=%s, delta=%s."):format(
                resolveReadablePlayerName(source, entrant),
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
        instance.state = RacingSystem.States.finished
        instance.finishedAt = now
        instance.startAt = nil
    end

    logCheckpointPassContext(instance, entrant, reportedCheckpoint, totalCheckpoints, currentLap, totalLaps, passContext)

    return instance, nil
end

RegisterNetEvent('racingsystem:requestState', function()
    syncKnownRaceDefinitionsFromFiles()
    sendSnapshot(source)
end)

RegisterNetEvent('racingsystem:requestEditorRace', function(raceName)
    local src = source
    local customDefinition = loadCustomRace(raceName)
    local onlineDefinition = nil
    local definition = customDefinition

    if not definition then
        onlineDefinition = loadBundledOnlineRace(raceName)
        definition = onlineDefinition
    end

    if definition then
        registerKnownRaceDefinition(definition.name, customDefinition and 'custom' or 'online')
        broadcastSnapshot()
    end

    TriggerClientEvent('racingsystem:editorRaceLoaded', src, {
        ok = true,
        requestedName = RacingSystem.Trim(raceName),
        race = buildSavedRaceSnapshot(definition),
    })
end)

RegisterNetEvent('racingsystem:saveEditorRace', function(payload)
    local src = source
    local definition, saveError = saveRaceDefinition(
        src,
        type(payload) == 'table' and payload.name or '',
        type(payload) == 'table' and payload.checkpoints or {}
    )

    if not definition then
        logLevelOne(("%s could not save the editor race. Reason: %s."):format(
            resolvePlayerLogLabel(src),
            tostring(saveError or 'unknown error')
        ))
        TriggerClientEvent('racingsystem:editorRaceSaved', src, {
            ok = false,
            error = saveError or 'Could not save race.',
        })
        return
    end

    auditLog("saveEditorRace", src, ("saved race '%s' with %s checkpoints"):format(
        tostring(definition.name or ""),
        tostring(#(definition.checkpoints or {}))
    ))
    broadcastSnapshot()
    TriggerClientEvent('racingsystem:editorRaceSaved', src, {
        ok = true,
        race = buildSavedRaceSnapshot(definition),
    })
end)

RegisterNetEvent('racingsystem:registerRaceDefinition', function(raceName)
    local src = source
    local definition, registerError = registerRaceDefinitionIfValid(raceName)

    if not definition then
        logLevelOne(("%s could not register race definition '%s'. Reason: %s."):format(
            resolvePlayerLogLabel(src),
            tostring(raceName),
            tostring(registerError or 'unknown error')
        ))
        TriggerClientEvent('racingsystem:raceDefinitionRegistered', src, {
            ok = false,
            error = registerError or 'Could not register race definition.',
        })
        return
    end

    auditLog("registerRaceDefinition", src, ("registered race definition '%s' (%s source)"):format(
        tostring(definition.name or raceName),
        tostring(definition.sourceType or 'unknown')
    ))
    broadcastSnapshot()
    TriggerClientEvent('racingsystem:raceDefinitionRegistered', src, {
        ok = true,
        definition = definition,
    })
end)

RegisterNetEvent('racingsystem:validateGTAORaceUGCId', function(ugcId)
    local src = source
    local validation, validationError = validateBundledUGCById(ugcId)

    if not validation then
        TriggerClientEvent('racingsystem:gtAoRaceValidationResult', src, {
            ok = false,
            ugcId = tostring(ugcId or ''),
            error = validationError or 'Could not validate GTAO race URL.',
        })
        return
    end

    local importedRace, importError = saveBundledUGCById(validation.ugcId)
    if not importedRace then
        TriggerClientEvent('racingsystem:gtAoRaceValidationResult', src, {
            ok = false,
            ugcId = tostring(validation.ugcId or ugcId or ''),
            error = importError or 'The UGC JSON validated but could not be imported.',
        })
        return
    end

    registerKnownRaceDefinition(importedRace.raceName, 'online')

    local hostedInstance, hostError = invokeRaceInstance(src, importedRace.raceName, 1)
    if not hostedInstance and importedRace.ugcId then
        local fallbackInstance, fallbackError = invokeRaceInstance(src, importedRace.ugcId, 1)
        if fallbackInstance then
            hostedInstance = fallbackInstance
            hostError = nil
        else
            hostError = fallbackError or hostError
        end
    end
    local hosted = hostedInstance ~= nil
    if hosted then
        auditLog("importAndAutoHostGTAORace", src, ("imported UGC '%s' and hosted '%s' (instance %s, %s lap(s))"):format(
            tostring(importedRace.ugcId or validation.ugcId),
            tostring(importedRace.raceName),
            tostring(hostedInstance.id),
            tostring(hostedInstance.laps)
        ))
        sendInstanceAssets(src, hostedInstance)
        sendTeleportToLastCheckpoint(src, hostedInstance)
    end

    broadcastSnapshot()
    TriggerClientEvent('racingsystem:gtAoRaceValidationResult', src, {
        ok = true,
        ugcId = tostring(importedRace.ugcId or validation.ugcId or ''),
        raceName = tostring(importedRace.raceName or validation.ugcId or ''),
        checkpointCount = tonumber(importedRace.checkpointCount) or tonumber(validation.checkpointCount) or 0,
        propCount = tonumber(importedRace.propCount) or tonumber(validation.propCount) or 0,
        modelHideCount = tonumber(importedRace.modelHideCount) or tonumber(validation.modelHideCount) or 0,
        autoHosted = hosted,
        autoHostedLaps = hosted and (tonumber(hostedInstance.laps) or 1) or 1,
        autoHostError = hosted and nil or (hostError or 'Could not auto-host race instance.'),
    })
end)

RegisterNetEvent('racingsystem:deleteRaceDefinition', function(raceName)
    local src = source
    if not hasAdminAccess(src) then
        logLevelOne(("%s tried to delete race definition '%s' without permission."):format(
            resolvePlayerLogLabel(src),
            tostring(raceName)
        ))
        notifyPlayer(src, "You do not have permission to delete races.", true)
        return
    end
    local deletedDefinition, deleteError = deleteRaceDefinition(raceName)

    if not deletedDefinition then
        logLevelOne(("%s could not delete race definition '%s'. Reason: %s."):format(
            resolvePlayerLogLabel(src),
            tostring(raceName),
            tostring(deleteError or 'unknown error')
        ))
        TriggerClientEvent('racingsystem:raceDefinitionDeleted', src, {
            ok = false,
            error = deleteError or 'Could not delete race definition.',
        })
        return
    end

    auditLog("deleteRaceDefinition", src, ("deleted race definition '%s'"):format(tostring((deletedDefinition or {}).name or raceName)))
    broadcastSnapshot()
    TriggerClientEvent('racingsystem:raceDefinitionDeleted', src, {
        ok = true,
        definition = deletedDefinition,
    })
end)

RegisterNetEvent('racingsystem:invokeRace', function(raceName, lapCount)
    local src = source
    local instance, invokeError = invokeRaceInstance(src, raceName, lapCount)

    if not instance then
        logLevelOne(("%s could not invoke race '%s'. Reason: %s."):format(
            resolvePlayerLogLabel(src),
            tostring(raceName),
            tostring(invokeError or 'unknown error')
        ))
        notifyPlayer(src, invokeError or 'Could not invoke race.', true)
        return
    end

    auditLog("invokeRace", src, ("invoked race '%s' (instance %s, %s lap(s), %s source)"):format(
        tostring(instance.name or raceName),
        tostring(instance.id),
        tostring(instance.laps),
        tostring(instance.sourceType or 'unknown')
    ))
    broadcastSnapshot()
    sendInstanceAssets(src, instance)
    sendTeleportToLastCheckpoint(src, instance)
end)

RegisterNetEvent('racingsystem:joinRace', function(raceName)
    local src = source
    local instance, joinError = joinRaceInstanceByName(src, raceName)

    if not instance then
        logLevelOne(("%s could not join race '%s'. Reason: %s."):format(
            resolvePlayerLogLabel(src),
            tostring(raceName),
            tostring(joinError or 'unknown error')
        ))
        notifyPlayer(src, joinError or 'Could not join race.', true)
        return
    end

    auditLog("joinRace", src, ("joined race '%s' (instance %s). Entrants now: %s"):format(
        tostring(instance.name or raceName),
        tostring(instance.id),
        tostring(#(instance.entrants or {}))
    ))
    broadcastSnapshot()
    sendInstanceAssets(src, instance)
    sendTeleportToLastCheckpoint(src, instance)
end)

RegisterNetEvent('racingsystem:startRace', function()
    local src = source
    local instance, startError = startRaceInstanceForSource(src)

    if not instance then
        logLevelOne(("%s could not start the race. Reason: %s."):format(
            resolvePlayerLogLabel(src),
            tostring(startError or 'unknown error')
        ))
        notifyPlayer(src, startError or 'Could not start race.', true)
        return
    end

    auditLog("startRace", src, ("started race '%s' (instance %s) with %s entrants. Countdown: %sms"):format(
        tostring(instance.name or 'unknown'),
        tostring(instance.id),
        tostring(#(instance.entrants or {})),
        tostring(tonumber((RacingSystem.Config or {}).countdownMs) or 5000)
    ))
    broadcastSnapshot()
end)

RegisterNetEvent('racingsystem:checkpointPassed', function(instanceId, checkpointIndex, lapTimingPayload, passContext)
    local src = source
    local instance, checkpointError = handleCheckpointPassed(src, instanceId, checkpointIndex, lapTimingPayload, passContext)

    if not instance then
        if checkpointError ~= 'Ignored out-of-order checkpoint pass.' then
            notifyPlayer(src, checkpointError or 'Could not advance checkpoint.', true)
        end
        return
    end

    broadcastSnapshot()
end)

RegisterNetEvent('racingsystem:finishRace', function()
    local src = source
    local instance, finishError = finishRaceInstanceForSource(src)
    if not instance then
        logLevelOne(("%s could not finish the race. Reason: %s."):format(
            resolvePlayerLogLabel(src),
            tostring(finishError or 'unknown error')
        ))
        notifyPlayer(src, finishError)
        return
    end

    auditLog("finishRace", src, ("finished race '%s' (instance %s)"):format(
        tostring((instance or {}).name or "unknown"),
        tostring((instance or {}).id or "unknown")
    ))
    broadcastSnapshot()
end)

RegisterNetEvent('racingsystem:countdownReachedZero', function(instanceId, clientGameTimerAtZero)
    local src = source
    local instance = raceInstancesById[tonumber(instanceId) or -1]
    local playerLabel = resolvePlayerLogLabel(src)

    if not instance then
        logLevelOne(("%s reached countdown zero for missing instance %s."):format(playerLabel, tostring(instanceId)))
        return
    end

    logVerbose(("%s reached countdown zero in race '%s' (instance %s, state=%s). clientTimer=%s, serverTimer=%s."):format(
        playerLabel,
        tostring(instance.name or 'unknown'),
        tostring(instance.id),
        tostring(instance.state),
        tostring(clientGameTimerAtZero),
        tostring(GetGameTimer())
    ))
end)

RegisterNetEvent('racingsystem:leaveRace', function()
    local src = source
    local instance, leaveError = leaveCurrentRaceInstance(src)

    if not instance then
        logLevelOne(("%s could not leave the race. Reason: %s."):format(
            resolvePlayerLogLabel(src),
            tostring(leaveError or 'unknown error')
        ))
        notifyPlayer(src, leaveError or 'Could not leave race.', true)
        return
    end

    auditLog("leaveRace", src, ("left race '%s' (instance %s). Entrants now: %s"):format(
        tostring(instance.name or 'unknown'),
        tostring(instance.id),
        tostring(#(instance.entrants or {}))
    ))
    broadcastSnapshot()
end)

RegisterNetEvent('racingsystem:killRace', function(raceName)
    local src = source
    local instance = findRaceInstanceByName(raceName)
    local ownerKillEnabled = true
    local ownsRace = instance and tonumber(instance.owner) == tonumber(src)
    if not hasAdminAccess(src) and not (ownerKillEnabled and ownsRace) then
        logLevelOne(("%s tried to kill race '%s' without permission."):format(
            resolvePlayerLogLabel(src),
            tostring(raceName)
        ))
        notifyPlayer(src, "You do not have permission to kill race instances.", true)
        return
    end
    local killedInstance, killError = killRaceInstanceByName(raceName)

    if not killedInstance then
        logLevelOne(("%s could not kill race '%s'. Reason: %s."):format(
            resolvePlayerLogLabel(src),
            tostring(raceName),
            tostring(killError or 'unknown error')
        ))
        notifyPlayer(src, killError or 'Could not kill race instance.', true)
        return
    end

    auditLog("killRace", src, ("killed race '%s' (instance %s)"):format(
        tostring(raceName),
        tostring(killedInstance.id or 'unknown')
    ))
    broadcastSnapshot()
end)

AddEventHandler('playerDropped', function()
    if removeEntrantFromAllRaceInstances(source) then
        auditLog("playerDroppedRaceCleanup", source, "disconnected and was removed from one or more active race instances")
        broadcastSnapshot()
    end
end)

AddEventHandler('playerJoining', function()
    local src = source
    SetTimeout(1000, function()
        sendSnapshot(src)
    end)
end)

CreateThread(function()
    while true do
        local changedAnyState = false
        local now = GetGameTimer()

        for _, instance in pairs(raceInstancesById) do
            if instance.state == RacingSystem.States.staging and tonumber(instance.startAt) and now >= tonumber(instance.startAt) then
                instance.state = RacingSystem.States.running
                instance.startedAt = now
                instance.startAt = nil
                for _, entrant in ipairs(instance.entrants or {}) do
                    entrant.lapStartedAt = now
                end
                logVerbose(("Race '%s' (instance %s) moved from staging to running with %s entrants."):format(
                    tostring(instance.name or 'unknown'),
                    tostring(instance.id),
                    tostring(#(instance.entrants or {}))
                ))
                changedAnyState = true
            end
        end

        if changedAnyState then
            broadcastSnapshot()
        end

        Wait(250)
    end
end)

loadRaceIndex()
syncKnownRaceDefinitionsFromFiles()
runIntegrityScript()

local startupSnapshot = buildFullSnapshot(0)
log(
    ('Server system loaded with %s saved races (%s custom, %s online) and %s active instances.'):format(
        startupSnapshot.definitionCount,
        startupSnapshot.customRaceCount or 0,
        startupSnapshot.onlineRaceCount or 0,
        startupSnapshot.instanceCount
    )
)
