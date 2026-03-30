local raceInstancesById = {}
local raceInstanceIdsByName = {}
local nextRaceInstanceId = 1
local getSavedRaceCounts
local buildSavedRaceDefinitions
local knownRaceDefinitionsByName = {}
local RACE_INDEX_FILE = 'race_index.json'

local function log(message)
    return
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

local function cloneKnownRaceDefinition(definition)
    if type(definition) ~= 'table' then
        return nil
    end

    local normalizedName = RacingSystem.NormalizeRaceName(definition.name)
    if not normalizedName then
        return nil
    end

    local sourceType = tostring(definition.sourceType or 'custom')
    if sourceType ~= 'custom' and sourceType ~= 'online' then
        sourceType = 'custom'
    end

    return {
        name = normalizedName,
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

    local saveOk = SaveResourceFile(RacingSystem.Config.resourceName, RACE_INDEX_FILE, encoded, -1)
    if not saveOk then
        log(('Failed to save %s'):format(RACE_INDEX_FILE))
        return false
    end

    log(('Saved %s with %s definition(s).'):format(RACE_INDEX_FILE, #definitions))
    return true
end

local function loadRaceIndex()
    knownRaceDefinitionsByName = {}

    local rawIndex = LoadResourceFile(RacingSystem.Config.resourceName, RACE_INDEX_FILE)
    if not rawIndex or rawIndex == '' then
        log(('%s was not found. Starting with an empty race index.'):format(RACE_INDEX_FILE))
        return
    end

    local decoded = json.decode(rawIndex)
    local definitions = type(decoded) == 'table' and decoded.definitions or nil
    if type(definitions) ~= 'table' then
        log(('%s could not be parsed as a race definition list.'):format(RACE_INDEX_FILE))
        return
    end

    local loadedCount = 0
    for _, definition in ipairs(definitions) do
        local clonedDefinition = cloneKnownRaceDefinition(definition)
        if clonedDefinition then
            local normalizedName = RacingSystem.NormalizeRaceName(clonedDefinition.name)
            knownRaceDefinitionsByName[normalizedName] = clonedDefinition
            loadedCount = loadedCount + 1
        end
    end

    log(('Loaded %s definition(s) from %s.'):format(loadedCount, RACE_INDEX_FILE))
end

local function registerKnownRaceDefinition(raceName, sourceType)
    local normalizedName = RacingSystem.NormalizeRaceName(raceName)
    if not normalizedName then
        return nil
    end

    local normalizedSourceType = tostring(sourceType or 'custom')
    if normalizedSourceType ~= 'custom' and normalizedSourceType ~= 'online' then
        normalizedSourceType = 'custom'
    end

    knownRaceDefinitionsByName[normalizedName] = {
        name = normalizedName,
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
    local laps = math.max(1, tonumber(instance and instance.laps) or 1)
    local checkpointCount = #(type(instance and instance.checkpoints) == 'table' and instance.checkpoints or {})
    if laps > 1 and checkpointCount > 1 then
        return 2
    end

    return 1
end

local function getLapTriggerCheckpoint(totalCheckpoints, totalLaps)
    local checkpointCount = math.max(0, tonumber(totalCheckpoints) or 0)
    local laps = math.max(1, tonumber(totalLaps) or 1)
    if checkpointCount <= 1 then
        return 1
    end

    if laps > 1 then
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
        checkpoints = cloneCheckpoints(instance.checkpoints),
        entrants = buildOrderedEntrants(instance),
    }
end

local function buildFullSnapshot()
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

    return {
        races = {},
        definitions = definitions,
        instances = instances,
        count = definitionCount,
        definitionCount = definitionCount,
        customRaceCount = customRaceCount,
        onlineRaceCount = onlineRaceCount,
        instanceCount = #instances,
    }
end

local function sendSnapshot(target)
    local snapshot = buildFullSnapshot()
    log(('Sending snapshot to %s | definitions=%s instances=%s'):format(
        tostring(target),
        #(type(snapshot.definitions) == 'table' and snapshot.definitions or {}),
        #(type(snapshot.instances) == 'table' and snapshot.instances or {})
    ))
    TriggerClientEvent('racingsystem:stateSnapshot', target, snapshot)
end

local function broadcastSnapshot()
    sendSnapshot(-1)
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
    return ('%s/%s.json'):format(RacingSystem.Config.onlineRaceFolder, fileName)
end

local function buildCustomRaceFilePath(fileName)
    return ('%s/%s.json'):format(RacingSystem.Config.customRaceFolder, fileName)
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

local function iterateJsonFilesInFolder(folderName, handleLine)
    local resourcePath = GetResourcePath(RacingSystem.Config.resourceName)
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
            local normalizedName = RacingSystem.NormalizeRaceName(fileName)
            if normalizedName then
                local existingDefinition = syncedDefinitionsByName[normalizedName]
                if sourceType == 'custom' or existingDefinition == nil then
                    syncedDefinitionsByName[normalizedName] = {
                        name = normalizedName,
                        sourceType = sourceType,
                        updatedAt = os.time(),
                    }
                end
            end
        end
    end

    registerDefinitionsFromFolder(RacingSystem.Config.onlineRaceFolder, 'online')
    registerDefinitionsFromFolder(RacingSystem.Config.customRaceFolder, 'custom')

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
        if existingDefinition == nil or tostring(existingDefinition.sourceType) ~= tostring(definition.sourceType) then
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
    local customRaceCount = countJsonFilesInFolder(RacingSystem.Config.customRaceFolder)
    local onlineRaceCount = countJsonFilesInFolder(RacingSystem.Config.onlineRaceFolder)
    return customRaceCount, onlineRaceCount
end

local function buildMissionRaceFromCheckpoints(checkpoints, existingRaceData)
    local missionRace = type(existingRaceData) == 'table' and existingRaceData or {}
    missionRace.chp = #checkpoints
    missionRace.chl = {}
    missionRace.chs = {}

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

local function buildMissionJsonFromCheckpoints(checkpoints, existingMissionJson)
    local decoded = type(existingMissionJson) == 'string' and json.decode(existingMissionJson) or nil
    local missionRoot = type(decoded) == 'table' and decoded or {}
    missionRoot.mission = type(missionRoot.mission) == 'table' and missionRoot.mission or {}
    missionRoot.mission.race = buildMissionRaceFromCheckpoints(checkpoints, missionRoot.mission.race)
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

local function buildUGCJsonUrl(ugcId)
    return ('https://prod.cloud.rockstargames.com/ugc/gta5mission/5639/%s/0_0_en.json'):format(ugcId)
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

local function saveBundledUGCById(ugcId)
    local normalizedUGCId = sanitizeUGCId(ugcId)
    if not normalizedUGCId then
        return nil, 'A valid UGC id is required.'
    end

    local rawMissionJson, fetchError = fetchUGCJsonContent(buildUGCJsonUrl(normalizedUGCId))
    if not rawMissionJson then
        return nil, fetchError or 'Could not download the UGC JSON.'
    end

    local decodedMissionJson = json.decode(rawMissionJson)
    local mission = type(decodedMissionJson) == 'table' and decodedMissionJson.mission or nil
    if type(mission) ~= 'table' then
        return nil, 'The downloaded UGC JSON could not be decoded back into a mission table.'
    end

    local checkpoints = buildCheckpointsFromMissionRace(mission.race)
    if #checkpoints == 0 then
        return nil, 'The downloaded UGC did not produce any usable checkpoints.'
    end

    -- Run the same extraction paths the runtime loader will use so broken payloads fail early.
    local props = buildOnlineRacePropsFromMission(mission.prop)
    local modelHides = buildOnlineRaceModelHidesFromMission(mission.dhprop)

    local filePath = buildOnlineRaceFilePath(normalizedUGCId)
    local saveOk = SaveResourceFile(RacingSystem.Config.resourceName, filePath, rawMissionJson, -1)
    if not saveOk then
        return nil, ('Could not save %s.'):format(filePath)
    end

    return {
        ugcId = normalizedUGCId,
        filePath = filePath,
        checkpointCount = #checkpoints,
        propCount = #props,
        modelHideCount = #modelHides,
    }
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

local function buildCheckpointsFromMissionRace(raceData)
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
                radius = math.max(2.0, 8.0 * size),
            }
        end
    end

    return checkpoints
end

local function loadMissionRaceFromFolder(raceName, folderName, label)
    local fileName = sanitizeOnlineRaceFileName(raceName)
    if not fileName then
        return nil, ('A valid %s race name is required.'):format(label)
    end

    local filePath
    if folderName == RacingSystem.Config.customRaceFolder then
        filePath = buildCustomRaceFilePath(fileName)
    else
        filePath = buildOnlineRaceFilePath(fileName)
    end

    local rawMissionJson = LoadResourceFile(RacingSystem.Config.resourceName, filePath)
    if not rawMissionJson or rawMissionJson == '' then
        return nil, ('No %s race named "%s" was found.'):format(label, fileName)
    end

    local decoded = json.decode(rawMissionJson)
    local mission = type(decoded) == 'table' and decoded.mission or nil
    if type(mission) ~= 'table' then
        return nil, ('The %s race "%s" could not be parsed.'):format(label, fileName)
    end

    local checkpoints = buildCheckpointsFromMissionRace(mission.race)
    if #checkpoints == 0 then
        return nil, ('The %s race "%s" has no checkpoints.'):format(label, fileName)
    end

    return {
        name = fileName,
        checkpoints = checkpoints,
        props = buildOnlineRacePropsFromMission(mission.prop),
        modelHides = buildOnlineRaceModelHidesFromMission(mission.dhprop),
        missionJson = rawMissionJson,
    }
end

local function loadCustomRace(raceName)
    return loadMissionRaceFromFolder(raceName, RacingSystem.Config.customRaceFolder, 'custom')
end

local function loadBundledOnlineRace(raceName)
    return loadMissionRaceFromFolder(raceName, RacingSystem.Config.onlineRaceFolder, 'online')
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

    local resourcePath = GetResourcePath(RacingSystem.Config.resourceName)
    if type(resourcePath) ~= 'string' or resourcePath == '' then
        return nil, 'Could not resolve the resource path.'
    end

    local separator = resourcePath:find('\\', 1, true) and '\\' or '/'
    local relativePath = sourceType == 'custom'
        and buildCustomRaceFilePath(normalizedName)
        or buildOnlineRaceFilePath(normalizedName)
    local absolutePath = resourcePath .. separator .. relativePath:gsub('/', separator)

    local removeOk, removeError = os.remove(absolutePath)
    if not removeOk then
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
    local existingMissionJson = LoadResourceFile(RacingSystem.Config.resourceName, filePath)
    if (not existingMissionJson or existingMissionJson == '') then
        local existingOnlinePath = buildOnlineRaceFilePath(fileName)
        existingMissionJson = LoadResourceFile(RacingSystem.Config.resourceName, existingOnlinePath)
    end
    local missionJson = buildMissionJsonFromCheckpoints(sanitizedCheckpoints, existingMissionJson)
    local saveOk = SaveResourceFile(RacingSystem.Config.resourceName, filePath, missionJson, -1)
    if not saveOk then
        return nil, ('Could not save %s.'):format(filePath)
    end

    registerKnownRaceDefinition(fileName, 'custom')

    return {
        id = nil,
        name = fileName,
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
    local sourceType = 'saved'
    local sourceName = nil
    local laps = sanitizeLapCount(lapCount)

    if customRace then
        instanceName = customRace.name
        definitionName = customRace.name
        checkpoints = cloneCheckpoints(customRace.checkpoints)
        props = cloneOnlineRaceProps(customRace.props)
        modelHides = cloneOnlineRaceModelHides(customRace.modelHides)
        sourceType = 'custom'
        sourceName = customRace.name
        registerKnownRaceDefinition(customRace.name, 'custom')
    elseif onlineRace then
        instanceName = onlineRace.name
        definitionName = onlineRace.name
        checkpoints = cloneCheckpoints(onlineRace.checkpoints)
        props = cloneOnlineRaceProps(onlineRace.props)
        modelHides = cloneOnlineRaceModelHides(onlineRace.modelHides)
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
        props = props,
        modelHides = modelHides,
        entrants = {},
    }

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

local function handleCheckpointPassed(source, instanceId, checkpointIndex, lapTimingPayload)
    local instance = raceInstancesById[tonumber(instanceId) or -1]
    if not instance then
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
        return nil, 'Ignored out-of-order checkpoint pass.'
    end

    local totalCheckpoints = #(instance.checkpoints or {})
    if totalCheckpoints == 0 then
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
        TriggerClientEvent('racingsystem:editorRaceSaved', src, {
            ok = false,
            error = saveError or 'Could not save race.',
        })
        return
    end

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
        TriggerClientEvent('racingsystem:raceDefinitionRegistered', src, {
            ok = false,
            error = registerError or 'Could not register race definition.',
        })
        return
    end

    broadcastSnapshot()
    TriggerClientEvent('racingsystem:raceDefinitionRegistered', src, {
        ok = true,
        definition = definition,
    })
end)

RegisterNetEvent('racingsystem:deleteRaceDefinition', function(raceName)
    local src = source
    local deletedDefinition, deleteError = deleteRaceDefinition(raceName)

    if not deletedDefinition then
        TriggerClientEvent('racingsystem:raceDefinitionDeleted', src, {
            ok = false,
            error = deleteError or 'Could not delete race definition.',
        })
        return
    end

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
        notifyPlayer(src, invokeError or 'Could not invoke race.', true)
        return
    end

    broadcastSnapshot()
end)

RegisterNetEvent('racingsystem:joinRace', function(raceName)
    local src = source
    local instance, joinError = joinRaceInstanceByName(src, raceName)

    if not instance then
        notifyPlayer(src, joinError or 'Could not join race.', true)
        return
    end

    broadcastSnapshot()
    sendInstanceAssets(src, instance)
    sendTeleportToLastCheckpoint(src, instance)
end)

RegisterNetEvent('racingsystem:startRace', function()
    local src = source
    local instance, startError = startRaceInstanceForSource(src)

    if not instance then
        notifyPlayer(src, startError or 'Could not start race.', true)
        return
    end

    broadcastSnapshot()
end)

RegisterNetEvent('racingsystem:checkpointPassed', function(instanceId, checkpointIndex, lapTimingPayload)
    local src = source
    local instance, checkpointError = handleCheckpointPassed(src, instanceId, checkpointIndex, lapTimingPayload)

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
        notifyPlayer(src, finishError)
        return
    end

    broadcastSnapshot()
end)

RegisterNetEvent('racingsystem:countdownReachedZero', function(instanceId, clientGameTimerAtZero)
    local src = source
    local instance = raceInstancesById[tonumber(instanceId) or -1]
    local playerName = GetPlayerName(src) or ('player:%s'):format(src)

    if not instance then
        log(('countdown zero <- %s (%s) for missing instance %s'):format(playerName, src, tostring(instanceId)))
        return
    end

    log(('countdown zero <- %s (%s) instance=%s state=%s clientTimer=%s serverTimer=%s'):format(
        playerName,
        src,
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
        notifyPlayer(src, leaveError or 'Could not leave race.', true)
        return
    end

    broadcastSnapshot()
end)

RegisterNetEvent('racingsystem:killRace', function(raceName)
    local src = source
    local instance, killError = killRaceInstanceByName(raceName)

    if not instance then
        notifyPlayer(src, killError or 'Could not kill race instance.', true)
        return
    end

    broadcastSnapshot()
end)

AddEventHandler('playerDropped', function()
    if removeEntrantFromAllRaceInstances(source) then
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

local startupSnapshot = buildFullSnapshot()
log(
    ('Server scaffolding loaded with %s saved races (%s custom, %s online) and %s active instances.'):format(
        startupSnapshot.definitionCount,
        startupSnapshot.customRaceCount or 0,
        startupSnapshot.onlineRaceCount or 0,
        startupSnapshot.instanceCount
    )
)
