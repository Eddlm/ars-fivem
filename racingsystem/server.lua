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
local immutableExampleLookupNames = {}
local RACE_INDEX_FILE = 'race_index.json'
local RACE_INDEX_EXAMPLES_FILE = 'race_index_examples.json'
local RESOURCE_NAME = 'racingsystem'
local CUSTOM_RACE_FOLDER = 'CustomRaces'
local ONLINE_RACE_FOLDER = 'OnlineRaces'
local checkpointAnomalyLogByKey = {}
local lifecycleAnomalyLogByKey = {}
local ServerAdvancedConfig = (((RacingSystem or {}).Config or {}).advanced or {}).server or {}
local UGC_FETCH_RETRY_COOLDOWN_MS = math.max(0, math.floor(tonumber(ServerAdvancedConfig.ugcFetchRetryCooldownMs) or 700))
local nextAllowedUGCFetchAt = 0
local GTAO_CHECKPOINT_RADIUS_SCALE = tonumber(ServerAdvancedConfig.gtaoCheckpointRadiusScale) or 1.0
local nextEntrantIdToken = 1
local nextSnapshotVersion = 0
local reliabilityCounters = {
    rejectedJoinRunning = 0,
    emptyInstanceAutoDestroyed = 0,
    illegalLifecycleRequests = 0,
}
local SERVER_EXTRA_PRINT_LEVEL = math.floor(tonumber(ServerAdvancedConfig.extraPrintLevel) or 0)

local function getExtraPrintLevel()
    if SERVER_EXTRA_PRINT_LEVEL == 1 then
        return 1
    end
    if SERVER_EXTRA_PRINT_LEVEL == 2 then
        return 2
    end
    return 0
end

local function logError(message)
    print(tostring(message or 'Unknown server error.'))
end

local function logLevelOne(message)
    local _ = message
end

local function logVerbose(message)
    local _ = message
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

local function shouldLogLifecycleAnomaly(eventName, source, instanceId)
    local key = ('%s:%s:%s'):format(tostring(eventName or 'unknown'), tonumber(source) or 0, tonumber(instanceId) or -1)
    local now = GetGameTimer()
    local lastLoggedAt = tonumber(lifecycleAnomalyLogByKey[key]) or -100000
    if now - lastLoggedAt < 2000 then
        return false
    end

    lifecycleAnomalyLogByKey[key] = now
    return true
end

local function logLifecycleEvent(eventName, instance, entrant, source, oldState, newState, reason)
    logLevelOne(("[lifecycle] event=%s instanceId=%s entrantId=%s source=%s from=%s to=%s reason=%s"):format(
        tostring(eventName or 'unknown'),
        tostring(type(instance) == 'table' and instance.id or 'nil'),
        tostring(type(entrant) == 'table' and entrant.entrantId or 'nil'),
        tostring(tonumber(source) or 0),
        tostring(oldState or 'nil'),
        tostring(newState or 'nil'),
        tostring(reason or 'none')
    ))
end

local function buildEntrantId(source)
    local token = nextEntrantIdToken
    nextEntrantIdToken = nextEntrantIdToken + 1
    return ('%s-%s-%s'):format(
        tostring(tonumber(source) or 0),
        tostring(math.floor(tonumber(os.time()) or 0)),
        tostring(token)
    )
end

local function isLifecycleTransitionAllowed(fromState, toState)
    if fromState == toState then
        return true
    end

    local stateRules = {
        [RacingSystem.States.idle] = {
            [RacingSystem.States.staging] = true,
            terminated = true,
        },
        [RacingSystem.States.staging] = {
            [RacingSystem.States.running] = true,
            [RacingSystem.States.idle] = true,
            terminated = true,
        },
        [RacingSystem.States.running] = {
            [RacingSystem.States.finished] = true,
            [RacingSystem.States.idle] = true,
            terminated = true,
        },
        [RacingSystem.States.finished] = {
            [RacingSystem.States.staging] = true,
            [RacingSystem.States.idle] = true,
            terminated = true,
        },
    }

    local allowedTargets = stateRules[fromState]
    if type(allowedTargets) ~= 'table' then
        return false
    end

    return allowedTargets[toState] == true
end

local function setRaceInstanceState(instance, nextState, eventName, source, entrant, reason)
    if type(instance) ~= 'table' then
        return false, 'Missing race instance.'
    end

    local currentState = tostring(instance.state or RacingSystem.States.idle)
    local targetState = tostring(nextState or currentState)
    if currentState == targetState then
        return true
    end

    if not isLifecycleTransitionAllowed(currentState, targetState) then
        reliabilityCounters.illegalLifecycleRequests = reliabilityCounters.illegalLifecycleRequests + 1
        if shouldLogLifecycleAnomaly(eventName, source, instance.id) then
            logLifecycleEvent(eventName, instance, entrant, source, currentState, targetState, reason or 'illegal_transition')
        end
        return false, ('Illegal lifecycle transition (%s -> %s).'):format(currentState, targetState)
    end

    instance.state = targetState
    logLifecycleEvent(eventName, instance, entrant, source, currentState, targetState, reason or 'state_transition')
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

    local _ = {
        playerName = playerName,
        playerSource = playerSource,
        checkpointNumber = checkpointNumber,
        checkpointTotal = checkpointTotal,
        raceName = raceName,
        currentLap = currentLap,
        lapTotal = lapTotal,
        details = details,
    }
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
    local raceId = RacingSystem.Trim(definition.raceId or ''):gsub('[^%w_-]', '')
    if raceId == '' then
        raceId = nil
    end

    return {
        lookupName = normalizedName,
        name = displayName,
        sourceType = sourceType,
        raceId = raceId,
        updatedAt = tonumber(definition.updatedAt) or os.time(),
    }
end

local function saveRaceIndex()
    local definitions = {}

    for _, definition in pairs(knownRaceDefinitionsByName) do
        if not definition.isExample then
            local clonedDefinition = cloneKnownRaceDefinition(definition)
            if clonedDefinition then
                definitions[#definitions + 1] = clonedDefinition
            end
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

    logVerbose(('Saved %s with %s definition(s).'):format(RACE_INDEX_FILE, #definitions))
    return true
end

local function loadRaceIndex()
    knownRaceDefinitionsByName = {}

    local function mergeExampleDefinitions(definitionsByName)
        immutableExampleLookupNames = {}

        local rawExamples = LoadResourceFile(RESOURCE_NAME, RACE_INDEX_EXAMPLES_FILE)
        if not rawExamples or rawExamples == '' then
            return 0
        end

        local decodedExamples = json.decode(rawExamples)
        local exampleDefinitions = type(decodedExamples) == 'table' and decodedExamples.definitions or nil
        if type(exampleDefinitions) ~= 'table' then
            logError(("The server could not read '%s' as a race definition list."):format(RACE_INDEX_EXAMPLES_FILE))
            return 0
        end

        local mergedCount = 0
        for _, definition in ipairs(exampleDefinitions) do
            local clonedDefinition = cloneKnownRaceDefinition(definition)
            if clonedDefinition then
                local normalizedName = RacingSystem.NormalizeRaceName(clonedDefinition.lookupName or clonedDefinition.name)
                clonedDefinition.isExample = true
                definitionsByName[normalizedName] = clonedDefinition
                immutableExampleLookupNames[normalizedName] = true
                mergedCount = mergedCount + 1
            end
        end

        return mergedCount
    end

    local exampleCount = mergeExampleDefinitions(knownRaceDefinitionsByName)
    logVerbose(('Loaded %s example definition(s) from %s.'):format(exampleCount, RACE_INDEX_EXAMPLES_FILE))

    local rawIndex = LoadResourceFile(RESOURCE_NAME, RACE_INDEX_FILE)
    if not rawIndex or rawIndex == '' then
        logVerbose(('%s was not found. No user race definitions loaded.'):format(RACE_INDEX_FILE))
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

    logVerbose(('Loaded %s definition(s) from %s.'):format(loadedCount, RACE_INDEX_FILE))
end

local function registerKnownRaceDefinition(raceName, sourceType, raceId)
    local displayName = RacingSystem.Trim(raceName)
    local normalizedName = RacingSystem.NormalizeRaceName(displayName)
    if not normalizedName then
        return nil
    end

    local normalizedSourceType = tostring(sourceType or 'custom')
    if normalizedSourceType ~= 'custom' and normalizedSourceType ~= 'online' then
        normalizedSourceType = 'custom'
    end
    local normalizedRaceId = RacingSystem.Trim(raceId or ''):gsub('[^%w_-]', '')
    if normalizedRaceId == '' then
        normalizedRaceId = nil
    end

    knownRaceDefinitionsByName[normalizedName] = {
        lookupName = normalizedName,
        name = displayName,
        sourceType = normalizedSourceType,
        raceId = normalizedRaceId,
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
end

local function getRaceStartCheckpoint(instance)
    local checkpoints = type(instance) == 'table' and type(instance.checkpoints) == 'table' and instance.checkpoints or {}
    local checkpointCount = math.max(0, #checkpoints)
    if checkpointCount <= 1 then
        return 1
    end

    if type(instance) == 'table' and instance.pointToPoint == true then
        -- Point-to-point races start on the first checkpoint.
        return 1
    end

    -- Coherency rule: start line is always the final checkpoint in the route.
    return checkpointCount
end

local function getLapTriggerCheckpoint(instance, totalCheckpoints, totalLaps)
    local checkpointCount = math.max(0, tonumber(totalCheckpoints) or 0)
    if checkpointCount <= 1 then
        return 1
    end

    -- Coherency rule: finish/lap trigger is always the final checkpoint.
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
        -- Point-to-point races expect the starting checkpoint first.
        return startCheckpoint
    end
    -- Spawn can stay on start/finish, but expected pass must be the next checkpoint.
    return getNextCheckpointIndex(checkpointCount, startCheckpoint)
end

local POINT_TO_POINT_AUTODETECT_DISTANCE_METERS = tonumber(ServerAdvancedConfig.pointToPointAutodetectDistanceMeters) or 500.0

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
    return distance2D > POINT_TO_POINT_AUTODETECT_DISTANCE_METERS
end

local function buildEntrant(source, instance)
    local numericSource = tonumber(source) or 0

    return {
        entrantId = buildEntrantId(numericSource),
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
            entrant.entrantId = buildEntrantId(tonumber(entrant.source) or 0)
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

    local entrants = listEntrantsFromState(instance)
    if #entrants <= 0 then
        return
    end

    instance.standingsVersion = (tonumber(instance.standingsVersion) or 0) + 1
    local payload = buildInstanceStandingsPayload(instance)
    if type(payload) ~= 'table' then
        return
    end

    for _, entrant in ipairs(entrants) do
        local target = tonumber(entrant.source) or 0
        if target > 0 then
            TriggerClientEvent('racingsystem:standingsUpdate', target, payload)
        end
    end
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

    -- Use instance-specific late join limit if set, otherwise fall back to global config
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

    return newEntrant
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
        snapshotVersion = tonumber(nextSnapshotVersion) or 0,
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
    nextSnapshotVersion = nextSnapshotVersion + 1
    local snapshot = buildFullSnapshot(target)
    logVerbose(('Sending snapshot to %s | version=%s definitions=%s instances=%s rejectedJoinRunning=%s emptyDestroyed=%s illegalLifecycle=%s'):format(
        tostring(target),
        tostring(snapshot.snapshotVersion or 0),
        #(type(snapshot.definitions) == 'table' and snapshot.definitions or {}),
        #(type(snapshot.instances) == 'table' and snapshot.instances or {}),
        tostring(reliabilityCounters.rejectedJoinRunning or 0),
        tostring(reliabilityCounters.emptyInstanceAutoDestroyed or 0),
        tostring(reliabilityCounters.illegalLifecycleRequests or 0)
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
    local startCheckpointIndex = getRaceStartCheckpoint(instance)
    local startCheckpoint = checkpoints[startCheckpointIndex]
    if type(startCheckpoint) ~= 'table' then
        return
    end

    TriggerClientEvent('racingsystem:teleportToCheckpoint', target, {
        instanceId = instance.id,
        checkpointIndex = startCheckpointIndex,
        x = tonumber(startCheckpoint.x) or 0.0,
        y = tonumber(startCheckpoint.y) or 0.0,
        z = (tonumber(startCheckpoint.z) or 0.0) + 1.0,
        teleportType = 'join',
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

    logVerbose(("[startfinish] teleport target=%s instance=%s requestedCheckpoint=%s resolvedCheckpoint=%s startCheckpoint=%s lapTrigger=%s heading=%s xyz=(%.2f,%.2f,%.2f)"):format(
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

    TriggerClientEvent('racingsystem:teleportToCheckpoint', target, {
        instanceId = instance.id,
        checkpointIndex = checkpointIdx,
        x = tonumber(checkpoint.x) or 0.0,
        y = tonumber(checkpoint.y) or 0.0,
        z = (tonumber(checkpoint.z) or 0.0) + 1.0,
        teleportType = 'join',
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
        if isLifecycleTransitionAllowed(previousState, 'terminated') then
            logLifecycleEvent('terminateRace', instance, removedEntrant, source, previousState, 'terminated', reason or 'empty_after_removal')
        end
        removeRaceInstanceNameIndex(instance)
        raceInstancesById[instance.id] = nil
        reliabilityCounters.emptyInstanceAutoDestroyed = reliabilityCounters.emptyInstanceAutoDestroyed + 1
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
    local laps = math.floor(tonumber(value) or 3)
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

    logVerbose(('Listed %s json file(s) in %s: %s'):format(
        #fileNames,
        tostring(folderName),
        (#fileNames > 0 and table.concat(fileNames, ', ') or '(none)')
    ))

    return fileNames
end

local function syncKnownRaceDefinitionsFromFiles()
    local syncedDefinitionsByName = {}
    local onlineFileCount = countJsonFilesInFolder(ONLINE_RACE_FOLDER)
    local customFileCount = countJsonFilesInFolder(CUSTOM_RACE_FOLDER)

    local function mergeExampleDefinitions(definitionsByName)
        immutableExampleLookupNames = {}

        local rawExamples = LoadResourceFile(RESOURCE_NAME, RACE_INDEX_EXAMPLES_FILE)
        if not rawExamples or rawExamples == '' then
            return 0
        end

        local decodedExamples = json.decode(rawExamples)
        local exampleDefinitions = type(decodedExamples) == 'table' and decodedExamples.definitions or nil
        if type(exampleDefinitions) ~= 'table' then
            logError(("The server could not read '%s' as a race definition list."):format(RACE_INDEX_EXAMPLES_FILE))
            return 0
        end

        local mergedCount = 0
        for _, definition in ipairs(exampleDefinitions) do
            local clonedDefinition = cloneKnownRaceDefinition(definition)
            if clonedDefinition then
                local normalizedName = RacingSystem.NormalizeRaceName(clonedDefinition.lookupName or clonedDefinition.name)
                clonedDefinition.isExample = true
                definitionsByName[normalizedName] = clonedDefinition
                immutableExampleLookupNames[normalizedName] = true
                mergedCount = mergedCount + 1
            end
        end

        return mergedCount
    end

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
                    local normalizedRaceId = nil
                    if sourceType == 'online' then
                        normalizedRaceId = RacingSystem.Trim((parsedRace and parsedRace.ugcId) or fileName):gsub('[^%w_-]', '')
                        if normalizedRaceId == '' then
                            normalizedRaceId = nil
                        end
                    end
                    syncedDefinitionsByName[normalizedName] = {
                        lookupName = normalizedName,
                        name = resolvedDisplayName ~= '' and resolvedDisplayName or normalizedName,
                        sourceType = sourceType,
                        raceId = normalizedRaceId,
                        updatedAt = os.time(),
                    }
                end
            end
        end
    end

    registerDefinitionsFromFolder(ONLINE_RACE_FOLDER, 'online')
    registerDefinitionsFromFolder(CUSTOM_RACE_FOLDER, 'custom')
    local exampleCount = mergeExampleDefinitions(syncedDefinitionsByName)
    logLevelOne(("[race-index] sync scan onlineFiles=%s customFiles=%s exampleDefs=%s"):format(
        tostring(onlineFileCount),
        tostring(customFileCount),
        tostring(exampleCount)
    ))
    logVerbose(('Merged %s immutable example definition(s) from %s during sync.'):format(exampleCount, RACE_INDEX_EXAMPLES_FILE))

    local syncedDefinitionCount = 0
    for _ in pairs(syncedDefinitionsByName) do
        syncedDefinitionCount = syncedDefinitionCount + 1
    end

    if syncedDefinitionCount == 0 then
        logVerbose('Skipping race-index sync because no race files were discovered from disk.')
        return false
    end

    local changed = false

    for normalizedName, definition in pairs(syncedDefinitionsByName) do
        local existingDefinition = knownRaceDefinitionsByName[normalizedName]
        if existingDefinition == nil
            or tostring(existingDefinition.sourceType) ~= tostring(definition.sourceType)
            or RacingSystem.Trim(existingDefinition.name) ~= RacingSystem.Trim(definition.name)
            or RacingSystem.Trim(existingDefinition.raceId or '') ~= RacingSystem.Trim(definition.raceId or '')
            or (existingDefinition.isExample == true) ~= (definition.isExample == true) then
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
    logLevelOne(("[race-index] sync apply changed=true syncedDefinitionCount=%s (examples excluded on save)"):format(
        tostring(syncedDefinitionCount)
    ))
    saveRaceIndex()

    logVerbose(('Synchronized race index from disk with %s definition(s).'):format(#buildSavedRaceDefinitions()))
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

    logVerbose(('Built %s saved race definition(s): %s'):format(
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

buildCheckpointsFromMissionRace = function(raceData, options)
    local checkpoints = {}
    if type(raceData) ~= 'table' then
        return checkpoints
    end

    local isGTAORace = type(options) == 'table' and options.isGTAORace == true
    local checkpointRadiusScale = GTAO_CHECKPOINT_RADIUS_SCALE * (isGTAORace and 2.0 or 1.0)

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
                radius = math.max(2.0, 8.0 * size * checkpointRadiusScale),
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
        local checkpoints = buildCheckpointsFromMissionRace(mission.race, {
            isGTAORace = extractedUGCId ~= nil,
        })
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
    logVerbose(("[resolve:%s] request='%s' normalized='%s' lookupKey='%s' folder='%s'"):format(
        tostring(label),
        tostring(raceName),
        tostring(normalizedRequestedName),
        tostring(normalizedRequestedLookupKey),
        tostring(folderName)
    ))

    local triedFileNames = {}
    local function tryLoadByFileName(fileName)
        local normalizedFileToken = RacingSystem.NormalizeRaceName(fileName)
        if not normalizedFileToken or triedFileNames[normalizedFileToken] then
            return nil
        end
        triedFileNames[normalizedFileToken] = true
        logVerbose(("[resolve:%s] try file token '%s' (normalized '%s')"):format(
            tostring(label),
            tostring(fileName),
            tostring(normalizedFileToken)
        ))

        local filePath = folderName == CUSTOM_RACE_FOLDER
            and buildCustomRaceFilePath(fileName)
            or buildOnlineRaceFilePath(fileName)
        local rawMissionJson = LoadResourceFile(RESOURCE_NAME, filePath)
        if not rawMissionJson or rawMissionJson == '' then
            logVerbose(("[resolve:%s] token '%s' not found at '%s'"):format(
                tostring(label),
                tostring(fileName),
                tostring(filePath)
            ))
            return nil
        end

        local parsedRace, parseError = parseRaceDefinitionFromJson(
            rawMissionJson,
            ('%s race "%s"'):format(label, fileName),
            fileName
        )
        if not parsedRace then
            logLevelOne(parseError or ('Could not parse %s race "%s".'):format(label, fileName))
            logVerbose(("[resolve:%s] token '%s' parse failed: %s"):format(
                tostring(label),
                tostring(fileName),
                tostring(parseError or 'unknown parse error')
            ))
            return nil
        end

        local parsedName = RacingSystem.Trim(parsedRace.name or '')
        logVerbose(("[resolve:%s] token '%s' resolved name='%s' ugcId='%s' checkpoints=%s"):format(
            tostring(label),
            tostring(fileName),
            tostring(parsedName ~= '' and parsedName or fileName),
            tostring(parsedRace.ugcId or 'nil'),
            tostring(#(parsedRace.checkpoints or {}))
        ))
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
        logVerbose(("[resolve:%s] direct token match success -> file='%s' name='%s' ugcId='%s'"):format(
            tostring(label),
            tostring(directMatch.fileName or 'unknown'),
            tostring(directMatch.name or 'unknown'),
            tostring(directMatch.ugcId or 'nil')
        ))
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
                    logVerbose(("[resolve:%s] scan name/file match request='%s' file='%s' parsed='%s' derived='%s' ugcId='%s'"):format(
                        tostring(label),
                        tostring(normalizedRequestedName),
                        tostring(fileName),
                        tostring(normalizedParsedName),
                        tostring(normalizedDerivedHumanName),
                        tostring(normalizedUGCId or 'nil')
                    ))
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
                    logVerbose(("[resolve:%s] scan lookupKey match request='%s' file='%s' parsedKey='%s' fileKey='%s' derivedKey='%s' ugcKey='%s'"):format(
                        tostring(label),
                        tostring(normalizedRequestedLookupKey),
                        tostring(fileName),
                        tostring(parsedLookupKey),
                        tostring(fileLookupKey),
                        tostring(derivedLookupKey),
                        tostring(ugcLookupKey or 'nil')
                    ))
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

    logVerbose(("[resolve:%s] no match for request='%s' in folder '%s'"):format(
        tostring(label),
        tostring(raceName),
        tostring(folderName)
    ))
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
        local definition = registerKnownRaceDefinition(onlineRace.name, 'online', onlineRace.ugcId or onlineRace.fileName)
        return definition, nil
    end

    return nil, 'That race name is not valid in CustomRaces or OnlineRaces.'
end

local function deleteRaceDefinition(request)
    local requestedName = nil
    local requestedLookupName = nil
    local requestedSourceType = nil
    local requestedRaceId = nil

    if type(request) == 'table' then
        requestedName = RacingSystem.Trim(request.name or request.lookupName or '')
        requestedLookupName = RacingSystem.NormalizeRaceName(request.lookupName or request.name)
        local normalizedSourceType = tostring(request.sourceType or ''):lower()
        if normalizedSourceType == 'custom' or normalizedSourceType == 'online' then
            requestedSourceType = normalizedSourceType
        end
        requestedRaceId = sanitizeUGCId(request.raceId)
    else
        requestedName = RacingSystem.Trim(request or '')
        requestedLookupName = RacingSystem.NormalizeRaceName(requestedName)
    end

    if not requestedLookupName then
        return nil, 'A valid race name is required.'
    end

    local definitionLookupName = requestedLookupName
    local definition = knownRaceDefinitionsByName[definitionLookupName]

    if not definition and requestedRaceId then
        for lookupName, knownDefinition in pairs(knownRaceDefinitionsByName) do
            if tostring(knownDefinition.sourceType) == 'online'
                and RacingSystem.Trim(knownDefinition.raceId or '') == requestedRaceId then
                definitionLookupName = lookupName
                definition = knownDefinition
                break
            end
        end
    end

    if not definition then
        return nil, 'That race could not be found in race_index for deletion.'
    end

    if immutableExampleLookupNames[definitionLookupName] == true then
        return nil, 'That race is an immutable example and cannot be deleted.'
    end

    if findRaceInstanceByName(definitionLookupName) then
        return nil, 'Cannot delete a race while its instance is active.'
    end

    local sourceType = tostring(definition.sourceType or requestedSourceType or 'custom')
    if sourceType ~= 'custom' and sourceType ~= 'online' then
        sourceType = requestedSourceType or 'custom'
    end

    local displayName = RacingSystem.Trim(definition.name or requestedName or definitionLookupName)
    local definitionRaceId = sanitizeUGCId(definition.raceId)
    local resolvedRaceId = requestedRaceId or definitionRaceId

    local customRace = nil
    local onlineRace = nil
    if sourceType == 'custom' then
        customRace = loadCustomRace(displayName) or loadCustomRace(definitionLookupName)
    else
        if resolvedRaceId then
            onlineRace = loadBundledOnlineRace(resolvedRaceId)
        end
        if not onlineRace then
            onlineRace = loadBundledOnlineRace(displayName) or loadBundledOnlineRace(definitionLookupName)
        end
    end

    local targetFileName = nil
    if sourceType == 'custom' then
        targetFileName = (customRace and customRace.fileName) or sanitizeOnlineRaceFileName(displayName) or definitionLookupName
    else
        targetFileName = (onlineRace and onlineRace.fileName) or resolvedRaceId or sanitizeOnlineRaceFileName(displayName) or definitionLookupName
    end

    local relativePath = sourceType == 'custom'
        and buildCustomRaceFilePath(targetFileName)
        or buildOnlineRaceFilePath(targetFileName)

    local fileRemoved = false
    local fileRemoveError = nil
    local resourcePath = GetResourcePath(RESOURCE_NAME)
    if type(resourcePath) == 'string' and resourcePath ~= '' then
        local separator = resourcePath:find('\\', 1, true) and '\\' or '/'
        local absolutePath = resourcePath .. separator .. relativePath:gsub('/', separator)
        local removeOk, removeError = os.remove(absolutePath)
        if removeOk then
            fileRemoved = true
        else
            fileRemoveError = tostring(removeError or 'unknown error')
            logError(("The server could not delete '%s'. Reason: %s. Continuing with race index deletion."):format(relativePath, fileRemoveError))
        end
    else
        fileRemoveError = 'Could not resolve the resource path.'
        logError('Could not resolve the resource path. Continuing with race index deletion only.')
    end

    unregisterKnownRaceDefinition(definitionLookupName)

    return {
        name = displayName ~= '' and displayName or definitionLookupName,
        lookupName = definitionLookupName,
        sourceType = sourceType,
        raceId = resolvedRaceId,
        filePath = relativePath,
        fileRemoved = fileRemoved,
        fileRemoveError = fileRemoveError,
    }, nil
end

local function createNewRaceDefinition(ownerSource, raceName)
    local sanitizedName = RacingSystem.Trim(raceName)
    if sanitizedName == '' then
        return nil, 'Race name is required.'
    end

    local fileName = sanitizeOnlineRaceFileName(sanitizedName)
    if not fileName then
        return nil, 'Race name could not be converted into a valid mission filename.'
    end

    local filePath = buildCustomRaceFilePath(fileName)

    -- Create empty mission JSON structure
    local missionJson = buildMissionJsonFromCheckpoints({}, nil, sanitizedName)
    local saveOk = SaveResourceFile(RESOURCE_NAME, filePath, missionJson, -1)
    if not saveOk then
        logError(("The server could not create new race '%s'."):format(filePath))
        return nil, ('Could not create %s.'):format(filePath)
    end

    registerKnownRaceDefinition(sanitizedName, 'custom')
    broadcastSnapshot()

    return {
        id = nil,
        name = sanitizedName,
        fileName = fileName,
        owner = tonumber(ownerSource) or 0,
        state = RacingSystem.States.idle,
        createdAt = os.time(),
        checkpoints = {},
        entrants = {},
    }
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
        entrant.currentCheckpoint = getPreRaceExpectedCheckpoint(instance)
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
    logVerbose(("[invoke] owner=%s rawType=%s request='%s' lookup='%s' sourceType='%s' raceId='%s' laps=%s trafficDensity=%.2f"):format(
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
            onlineRace = loadBundledOnlineRace(invokeRaceId)
        end
        if not onlineRace then
            onlineRace = loadBundledOnlineRace(invokeRequestName)
        end
        if not onlineRace and invokeLookupName then
            onlineRace = loadBundledOnlineRace(invokeLookupName)
        end
        if not onlineRace then
            customRace = loadCustomRace(invokeRequestName)
        end
    elseif invokeSourceType == 'custom' then
        customRace = loadCustomRace(invokeRequestName)
        if not customRace and invokeLookupName then
            customRace = loadCustomRace(invokeLookupName)
        end
        if not customRace then
            if invokeRaceId then
                onlineRace = loadBundledOnlineRace(invokeRaceId)
            end
            if not onlineRace then
                onlineRace = loadBundledOnlineRace(invokeRequestName)
            end
        end
    else
        customRace = loadCustomRace(invokeRequestName)
        if invokeRaceId then
            onlineRace = loadBundledOnlineRace(invokeRaceId)
        end
        if not onlineRace then
            onlineRace = loadBundledOnlineRace(invokeRequestName)
        end
    end
    logVerbose(("[invoke] resolution result custom=%s online=%s (request='%s', raceId='%s')"):format(
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
        registerKnownRaceDefinition(onlineRace.name, 'online', onlineRace.ugcId or onlineRace.fileName)
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
        pointToPoint = isPointToPointByCheckpointDistance(checkpoints),
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
        instance.entrants = { buildEntrant(numericOwnerSource, instance) }
        upsertEntrantState(instance, instance.entrants[1])
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

    local previousState = instance.state
    if isLifecycleTransitionAllowed(previousState, 'terminated') then
        logLifecycleEvent('killRace', instance, nil, 0, previousState, 'terminated', 'killed_by_command')
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

    if instance.state == RacingSystem.States.running then
        local canJoin, joinError = canJoinMidRace(instance)
        if not canJoin then
            reliabilityCounters.rejectedJoinRunning = reliabilityCounters.rejectedJoinRunning + 1
            if shouldLogLifecycleAnomaly('joinRace', source, instance.id) then
                logLifecycleEvent('joinRace', instance, nil, source, instance.state, instance.state, 'late_join_rejected_running')
            end
            return nil, joinError or 'Cannot join a race that is already running.'
        end
        -- Mid-race join is allowed, continue to join flow below
    elseif instance.state ~= RacingSystem.States.idle and instance.state ~= RacingSystem.States.staging then
        if shouldLogLifecycleAnomaly('joinRace', source, instance.id) then
            logLifecycleEvent('joinRace', instance, nil, source, instance.state, instance.state, 'join_rejected_invalid_state')
        end
        return nil, 'That race cannot be joined right now.'
    end

    local existingInstance = findRaceInstanceByEntrant(source)
    if existingInstance and existingInstance.id == instance.id then
        return instance, nil
    end

    if existingInstance then
        local removedEntrant = removeEntrantFromRaceInstance(existingInstance, source)
        cleanupInstanceAfterEntrantRemoval(existingInstance, source, removedEntrant, 'join_transfer')
    end

    instance.entrants = instance.entrants or {}
    local newEntrant = buildEntrant(source, instance)

    -- Handle mid-race join: inherit last-place racer's progress
    if instance.state == RacingSystem.States.running then
        local lastPlaceEntrant = getLastPlaceEntrant(instance)
        if lastPlaceEntrant then
            newEntrant = inheritLastPlaceProgress(newEntrant, lastPlaceEntrant)
        end
    end

    instance.entrants[#instance.entrants + 1] = newEntrant
    upsertEntrantState(instance, newEntrant)
    return instance, nil
end

local function joinRaceInstanceById(source, instanceId)
    local instance = raceInstancesById[tonumber(instanceId) or -1]
    if not instance then
        return nil, 'That race instance does not exist.'
    end

    if #(instance.checkpoints or {}) == 0 then
        return nil, 'That race instance has no checkpoints.'
    end

    if instance.state == RacingSystem.States.running then
        local canJoin, joinError = canJoinMidRace(instance)
        if not canJoin then
            reliabilityCounters.rejectedJoinRunning = reliabilityCounters.rejectedJoinRunning + 1
            if shouldLogLifecycleAnomaly('joinRace', source, instance.id) then
                logLifecycleEvent('joinRace', instance, nil, source, instance.state, instance.state, 'late_join_rejected_running')
            end
            return nil, joinError or 'Cannot join a race that is already running.'
        end
        -- Mid-race join is allowed, continue to join flow below
    elseif instance.state ~= RacingSystem.States.idle and instance.state ~= RacingSystem.States.staging then
        if shouldLogLifecycleAnomaly('joinRace', source, instance.id) then
            logLifecycleEvent('joinRace', instance, nil, source, instance.state, instance.state, 'join_rejected_invalid_state')
        end
        return nil, 'That race cannot be joined right now.'
    end

    local existingInstance = findRaceInstanceByEntrant(source)
    if existingInstance and existingInstance.id == instance.id then
        return instance, nil
    end

    if existingInstance then
        local removedEntrant = removeEntrantFromRaceInstance(existingInstance, source)
        cleanupInstanceAfterEntrantRemoval(existingInstance, source, removedEntrant, 'join_transfer')
    end

    instance.entrants = instance.entrants or {}
    local newEntrant = buildEntrant(source, instance)

    -- Handle mid-race join: inherit last-place racer's progress
    if instance.state == RacingSystem.States.running then
        local lastPlaceEntrant = getLastPlaceEntrant(instance)
        if lastPlaceEntrant then
            newEntrant = inheritLastPlaceProgress(newEntrant, lastPlaceEntrant)
        end
    end

    instance.entrants[#instance.entrants + 1] = newEntrant
    upsertEntrantState(instance, newEntrant)
    return instance, nil
end

local function leaveCurrentRaceInstance(source)
    local instance = findRaceInstanceByEntrant(source)
    if not instance then
        return nil, 'You are not currently joined to a race instance.'
    end

    local removedEntrant = removeEntrantFromRaceInstance(instance, source)
    cleanupInstanceAfterEntrantRemoval(instance, source, removedEntrant, 'leave_race')

    return instance, nil
end

local function startRaceInstanceForSource(source)
    local instance = findRaceInstanceByEntrant(source)
    if not instance then
        return nil, 'You are not currently joined to a race instance.'
    end

    local now = GetGameTimer()
    if instance.state == RacingSystem.States.staging then
        local lastStartRequestedAt = tonumber(instance.lastStartRequestedAt) or 0
        local lastStartRequestedBy = tonumber(instance.lastStartRequestedBy) or 0
        if lastStartRequestedBy == tonumber(source) and now - lastStartRequestedAt <= 1000 then
            return instance, nil
        end
        return nil, 'That race is already counting down.'
    end

    if instance.state == RacingSystem.States.running then
        return nil, 'That race is already running.'
    end

    if instance.state ~= RacingSystem.States.idle and instance.state ~= RacingSystem.States.finished then
        if shouldLogLifecycleAnomaly('startRace', source, instance.id) then
            logLifecycleEvent('startRace', instance, nil, source, instance.state, instance.state, 'start_rejected_invalid_state')
        end
        return nil, 'That race cannot be started right now.'
    end

    if #(instance.entrants or {}) == 0 then
        return nil, 'No racers are joined to that instance.'
    end

    resetRaceInstanceProgress(instance)
    local transitionOk, transitionError = setRaceInstanceState(
        instance,
        RacingSystem.States.staging,
        'startRace',
        source,
        nil,
        'countdown_started'
    )
    if not transitionOk then
        return nil, transitionError
    end
    instance.lastStartRequestedAt = now
    instance.lastStartRequestedBy = tonumber(source) or 0
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

    if instance.state ~= RacingSystem.States.running and instance.state ~= RacingSystem.States.staging then
        if shouldLogLifecycleAnomaly('finishRace', source, instance.id) then
            logLifecycleEvent('finishRace', instance, nil, source, instance.state, instance.state, 'finish_rejected_invalid_state')
        end
        return nil, 'That race is not running.'
    end

    local now = GetGameTimer()
    local transitionOk, transitionError = setRaceInstanceState(
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

    for _, otherEntrant in ipairs(instance.entrants or {}) do
        local entrantSource = tonumber(otherEntrant.source) or 0
        if entrantSource > 0 then
            TriggerClientEvent('racingsystem:lapCompleted', entrantSource, {
                instanceId = instance.id,
                entrantId = tostring(entrant.entrantId or ''),
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
    local totalLaps = math.max(1, tonumber(instance.laps) or 1)
    local maxProgress = math.max(totalCheckpoints, totalCheckpoints * totalLaps)
    entrant.checkpointsPassed = math.min(maxProgress, (tonumber(entrant.checkpointsPassed) or 0) + 1)
    entrant.lastCheckpointAt = now

    local currentLap = math.max(1, tonumber(entrant.currentLap) or 1)
    local lapTriggerCheckpoint = getLapTriggerCheckpoint(instance, totalCheckpoints, totalLaps)
    logVerbose(("[startfinish] pass player=%s race='%s' instance=%s expected=%s reported=%s lap=%s/%s lapTrigger=%s startCheckpoint=%s totalCheckpoints=%s"):format(
        resolveReadablePlayerName(source, entrant),
        tostring(instance.name or 'unknown'),
        tostring(instance.id),
        tostring(expectedCheckpoint),
        tostring(reportedCheckpoint),
        tostring(currentLap),
        tostring(totalLaps),
        tostring(lapTriggerCheckpoint),
        tostring(getRaceStartCheckpoint(instance)),
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
                -- Point-to-point keeps finish on last checkpoint; no wrap back to checkpoint 1.
                entrant.currentCheckpoint = totalCheckpoints
            else
                -- Circuit mode: after crossing the finish line, next target becomes checkpoint 1.
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
        local transitionOk = setRaceInstanceState(
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
            if shouldLogLifecycleAnomaly('autoFinishRace', source, instance.id) then
                logLifecycleEvent('autoFinishRace', instance, entrant, source, instance.state, RacingSystem.States.finished, 'failed_transition')
            end
        end
    end

    logCheckpointPassContext(instance, entrant, reportedCheckpoint, totalCheckpoints, currentLap, totalLaps, passContext)

    return instance, nil
end

RegisterNetEvent('racingsystem:requestState', function()
    sendSnapshot(source)
end)

RegisterNetEvent('racingsystem:requestEditorRace', function(raceName)
    local src = source
    local definition = nil

    -- Always try to load the full race data from disk first
    local customDefinition = loadCustomRace(raceName)
    if customDefinition then
        definition = customDefinition
        logVerbose(('[requestEditorRace] Loaded "%s" from CustomRaces'):format(raceName))
    end

    if not definition then
        local onlineDefinition = loadBundledOnlineRace(raceName)
        if onlineDefinition then
            definition = onlineDefinition
            logVerbose(('[requestEditorRace] Loaded "%s" from OnlineRaces'):format(raceName))
        end
    end

    if not definition then
        -- New race: create and save empty file to CustomRaces
        definition = createNewRaceDefinition(src, raceName)
        if not definition then
            logError(('[requestEditorRace] Failed to create new race "%s"'):format(raceName))
            TriggerClientEvent('racingsystem:editorRaceLoaded', src, {
                ok = false,
                requestedName = RacingSystem.Trim(raceName),
                race = nil,
            })
            return
        end
        logVerbose(('[requestEditorRace] Created new race "%s"'):format(raceName))
    else
        -- Ensure the definition is registered
        if definition.name then
            registerKnownRaceDefinition(
                definition.name,
                definition.sourceType or 'custom',
                definition.ugcId or definition.fileName
            )
            broadcastSnapshot()
        end
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

    registerKnownRaceDefinition(importedRace.raceName, 'online', importedRace.ugcId)

    auditLog("importGTAORace", src, ("imported UGC '%s' as '%s'"):format(
        tostring(importedRace.ugcId or validation.ugcId),
        tostring(importedRace.raceName)
    ))

    broadcastSnapshot()
    TriggerClientEvent('racingsystem:gtAoRaceValidationResult', src, {
        ok = true,
        ugcId = tostring(importedRace.ugcId or validation.ugcId or ''),
        raceName = tostring(importedRace.raceName or validation.ugcId or ''),
        checkpointCount = tonumber(importedRace.checkpointCount) or tonumber(validation.checkpointCount) or 0,
        propCount = tonumber(importedRace.propCount) or tonumber(validation.propCount) or 0,
        modelHideCount = tonumber(importedRace.modelHideCount) or tonumber(validation.modelHideCount) or 0,
    })
end)

RegisterNetEvent('racingsystem:deleteRaceDefinition', function(payload)
    local src = source
    local payloadLabel = nil
    if type(payload) == 'table' then
        payloadLabel = RacingSystem.Trim(payload.name or payload.lookupName or payload.raceId or '')
    else
        payloadLabel = tostring(payload or '')
    end

    if not hasAdminAccess(src) then
        logLevelOne(("%s tried to delete race definition '%s' without permission."):format(
            resolvePlayerLogLabel(src),
            tostring(payloadLabel)
        ))
        notifyPlayer(src, "You do not have permission to delete races.", true)
        return
    end
    local deletedDefinition, deleteError = deleteRaceDefinition(payload)

    if not deletedDefinition then
        logLevelOne(("%s could not delete race definition '%s'. Reason: %s."):format(
            resolvePlayerLogLabel(src),
            tostring(payloadLabel),
            tostring(deleteError or 'unknown error')
        ))
        TriggerClientEvent('racingsystem:raceDefinitionDeleted', src, {
            ok = false,
            error = deleteError or 'Could not delete race definition.',
        })
        return
    end

    auditLog("deleteRaceDefinition", src, ("deleted race definition '%s'"):format(tostring((deletedDefinition or {}).name or payloadLabel)))
    broadcastSnapshot()
    TriggerClientEvent('racingsystem:raceDefinitionDeleted', src, {
        ok = true,
        definition = deletedDefinition,
    })
end)

RegisterNetEvent('racingsystem:invokeRace', function(payload, lapCount)
    local invokePayload = payload
    local raceName = type(payload) == 'table' and (payload.lookupName or payload.name) or payload
    local src = source
    if type(payload) == 'table' then
        logVerbose(("[invoke:event] %s payload name='%s' lookupName='%s' sourceType='%s' raceId='%s' laps=%s"):format(
            resolvePlayerLogLabel(src),
            tostring(payload.name or ''),
            tostring(payload.lookupName or ''),
            tostring(payload.sourceType or ''),
            tostring(payload.raceId or ''),
            tostring(lapCount)
        ))
    else
        logVerbose(("[invoke:event] %s payload scalar raceName='%s' laps=%s"):format(
            resolvePlayerLogLabel(src),
            tostring(raceName),
            tostring(lapCount)
        ))
    end
    local instance, invokeError = invokeRaceInstance(src, invokePayload, lapCount)

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
    broadcastInstanceStandings(instance)
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
    broadcastInstanceStandings(instance)
    sendInstanceAssets(src, instance)

    -- For mid-race joins, teleport to the current checkpoint; otherwise use default start teleport
    if instance.state == RacingSystem.States.running then
        local joiningEntrant = instance.entrants[#instance.entrants]
        if joiningEntrant then
            sendTeleportToCheckpoint(src, instance, joiningEntrant.currentCheckpoint)
        end
    else
        sendTeleportToLastCheckpoint(src, instance)
    end
end)

RegisterNetEvent('racingsystem:joinRaceInstanceById', function(instanceId)
    local src = source
    local instance, joinError = joinRaceInstanceById(src, instanceId)

    if not instance then
        logLevelOne(("%s could not join race instance %s. Reason: %s."):format(
            resolvePlayerLogLabel(src),
            tostring(instanceId),
            tostring(joinError or 'unknown error')
        ))
        notifyPlayer(src, joinError or 'Could not join race.', true)
        return
    end

    auditLog("joinRaceInstanceById", src, ("joined race instance %s ('%s'). Entrants now: %s"):format(
        tostring(instance.id),
        tostring(instance.name or 'unnamed'),
        tostring(#(instance.entrants or {}))
    ))
    broadcastSnapshot()
    broadcastInstanceStandings(instance)
    sendInstanceAssets(src, instance)

    -- For mid-race joins, teleport to the current checkpoint; otherwise use default start teleport
    if instance.state == RacingSystem.States.running then
        local joiningEntrant = instance.entrants[#instance.entrants]
        if joiningEntrant then
            sendTeleportToCheckpoint(src, instance, joiningEntrant.currentCheckpoint)
        end
    else
        sendTeleportToLastCheckpoint(src, instance)
    end
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
    broadcastInstanceStandings(instance)
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
    broadcastInstanceStandings(instance)
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
    broadcastInstanceStandings(instance)
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
    if type(instance) == 'table' then
        broadcastInstanceStandings(instance)
    end
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
    broadcastInstanceStandings(killedInstance)
    broadcastSnapshot()
end)

AddEventHandler('playerDropped', function()
    if removeEntrantFromAllRaceInstances(source, 'player_dropped') then
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
                local transitionOk = setRaceInstanceState(
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
                        entrant.lapStartedAt = now
                    end
                    logVerbose(("Race '%s' (instance %s) moved from staging to running with %s entrants."):format(
                        tostring(instance.name or 'unknown'),
                        tostring(instance.id),
                        tostring(#(instance.entrants or {}))
                    ))
                    broadcastInstanceStandings(instance)
                    changedAnyState = true
                elseif shouldLogLifecycleAnomaly('countdownElapsed', 0, instance.id) then
                    logLifecycleEvent(
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
            broadcastSnapshot()
        end

        Wait(250)
    end
end)

loadRaceIndex()
runIntegrityScript()

