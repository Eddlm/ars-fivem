RacingSystem = RacingSystem or {}
RacingSystem.Server = RacingSystem.Server or {}
RacingSystem.Server.Catalog = RacingSystem.Server.Catalog or {}

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

local function cloneMissionValue(value)
    if type(value) ~= 'table' then
        return value
    end

    local cloned = {}
    for key, item in pairs(value) do
        cloned[key] = cloneMissionValue(item)
    end
    return cloned
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
    local lookupName = RacingSystem.NormalizeRaceName(definition.lookupName or displayName)
    if not lookupName then
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
        lookupName = lookupName,
        name = displayName ~= '' and displayName or lookupName,
        sourceType = sourceType,
        raceId = raceId,
        updatedAt = tonumber(definition.updatedAt) or os.time(),
        isExample = definition.isExample == true,
    }
end

local function buildSavedRaceDefinitions()
    local definitions = {}
    for _, definition in pairs(RacingSystem.Server.State.knownRaceDefinitionsByName) do
        local clonedDefinition = cloneKnownRaceDefinition(definition)
        if clonedDefinition then
            definitions[#definitions + 1] = clonedDefinition
        end
    end
    table.sort(definitions, function(a, b)
        if tostring(a.sourceType or '') ~= tostring(b.sourceType or '') then
            if tostring(a.sourceType or '') == 'custom' then
                return true
            end
            if tostring(b.sourceType or '') == 'custom' then
                return false
            end
        end
        return tostring(a.name or '') < tostring(b.name or '')
    end)
    return definitions
end

local function saveRaceIndex()
    local definitions = buildSavedRaceDefinitions()
    local filteredDefinitions = {}

    for _, definition in ipairs(definitions) do
        if definition.isExample ~= true then
            local cloned = cloneKnownRaceDefinition(definition)
            if cloned then
                cloned.isExample = nil
                filteredDefinitions[#filteredDefinitions + 1] = cloned
            end
        end
    end

    local encoded = json.encode({
        definitions = filteredDefinitions,
    })

    if not encoded or encoded == '' then
        RacingSystem.Server.Logging.logError(("The server could not encode '%s'."):format(RacingSystem.Server.State.indexFile))
        return false
    end

    local saveOk = SaveResourceFile(RacingSystem.Server.State.resourceName, RacingSystem.Server.State.indexFile, encoded, -1)
    if not saveOk then
        RacingSystem.Server.Logging.logError(("The server could not save '%s'."):format(RacingSystem.Server.State.indexFile))
        return false
    end

    RacingSystem.Server.Logging.logVerbose(('Saved %s with %s definition(s).'):format(RacingSystem.Server.State.indexFile, #definitions))
    return true
end

local function clearMap(map)
    for key in pairs(map) do
        map[key] = nil
    end
end

local function loadRaceIndex()
    clearMap(RacingSystem.Server.State.knownRaceDefinitionsByName)
    clearMap(RacingSystem.Server.State.immutableExampleLookupNames)

    local function mergeExampleDefinitions(definitionsByName)
        local rawExamples = LoadResourceFile(RacingSystem.Server.State.resourceName, RacingSystem.Server.State.indexExamplesFile)
        if not rawExamples or rawExamples == '' then
            return 0
        end

        local decodedExamples = json.decode(rawExamples)
        local exampleDefinitions = type(decodedExamples) == 'table' and decodedExamples.definitions or nil
        if type(exampleDefinitions) ~= 'table' then
            RacingSystem.Server.Logging.logError(("The server could not read '%s' as a race definition list."):format(RacingSystem.Server.State.indexExamplesFile))
            return 0
        end

        local mergedCount = 0
        for _, definition in ipairs(exampleDefinitions) do
            local clonedDefinition = cloneKnownRaceDefinition(definition)
            if clonedDefinition then
                local normalizedName = RacingSystem.NormalizeRaceName(clonedDefinition.lookupName or clonedDefinition.name)
                if normalizedName then
                    clonedDefinition.isExample = true
                    definitionsByName[normalizedName] = clonedDefinition
                    RacingSystem.Server.State.immutableExampleLookupNames[normalizedName] = true
                    mergedCount = mergedCount + 1
                end
            end
        end

        return mergedCount
    end

    local exampleCount = mergeExampleDefinitions(RacingSystem.Server.State.knownRaceDefinitionsByName)
    RacingSystem.Server.Logging.logVerbose(('Loaded %s example definition(s) from %s.'):format(exampleCount, RacingSystem.Server.State.indexExamplesFile))

    local rawIndex = LoadResourceFile(RacingSystem.Server.State.resourceName, RacingSystem.Server.State.indexFile)
    if not rawIndex or rawIndex == '' then
        RacingSystem.Server.Logging.logVerbose(('%s was not found. No user race definitions loaded.'):format(RacingSystem.Server.State.indexFile))
        return
    end

    local decoded = json.decode(rawIndex)
    local definitions = type(decoded) == 'table' and decoded.definitions or nil
    if type(definitions) ~= 'table' then
        RacingSystem.Server.Logging.logError(("The server could not read '%s' as a race definition list."):format(RacingSystem.Server.State.indexFile))
        return
    end

    local loadedCount = 0
    for _, definition in ipairs(definitions) do
        local clonedDefinition = cloneKnownRaceDefinition(definition)
        if clonedDefinition then
            local normalizedName = RacingSystem.NormalizeRaceName(clonedDefinition.lookupName or clonedDefinition.name)
            if normalizedName then
                RacingSystem.Server.State.knownRaceDefinitionsByName[normalizedName] = clonedDefinition
                loadedCount = loadedCount + 1
            end
        end
    end

    RacingSystem.Server.Logging.logVerbose(('Loaded %s definition(s) from %s.'):format(loadedCount, RacingSystem.Server.State.indexFile))
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

    RacingSystem.Server.State.knownRaceDefinitionsByName[normalizedName] = {
        lookupName = normalizedName,
        name = displayName,
        sourceType = normalizedSourceType,
        raceId = normalizedRaceId,
        updatedAt = os.time(),
    }

    saveRaceIndex()
    return RacingSystem.Server.State.knownRaceDefinitionsByName[normalizedName]
end

local function unregisterKnownRaceDefinition(raceName)
    local normalizedName = RacingSystem.NormalizeRaceName(raceName)
    if not normalizedName then
        return false
    end
    if RacingSystem.Server.State.knownRaceDefinitionsByName[normalizedName] == nil then
        return false
    end

    RacingSystem.Server.State.knownRaceDefinitionsByName[normalizedName] = nil
    saveRaceIndex()
    return true
end

RacingSystem.Server.Catalog.cloneCheckpoints = cloneCheckpoints
RacingSystem.Server.Catalog.isSecondaryCoordinateValid = isSecondaryCoordinateValid
RacingSystem.Server.Catalog.buildSecondaryCheckpointFromMetadata = buildSecondaryCheckpointFromMetadata
RacingSystem.Server.Catalog.cloneMissionValue = cloneMissionValue
RacingSystem.Server.Catalog.buildCheckpointVariantSnapshot = buildCheckpointVariantSnapshot
RacingSystem.Server.Catalog.cloneKnownRaceDefinition = cloneKnownRaceDefinition
RacingSystem.Server.Catalog.buildSavedRaceDefinitions = buildSavedRaceDefinitions
RacingSystem.Server.Catalog.saveRaceIndex = saveRaceIndex
RacingSystem.Server.Catalog.loadRaceIndex = loadRaceIndex
RacingSystem.Server.Catalog.registerKnownRaceDefinition = registerKnownRaceDefinition
RacingSystem.Server.Catalog.unregisterKnownRaceDefinition = unregisterKnownRaceDefinition


