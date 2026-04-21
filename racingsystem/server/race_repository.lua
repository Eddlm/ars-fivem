RacingSystem = RacingSystem or {}
RacingSystem.Server = RacingSystem.Server or {}
RacingSystem.Server.Repository = RacingSystem.Server.Repository or {}

local function loadMissionRaceFromFolder(raceName, folderName, label)
    local normalizedRequestedName = RacingSystem.NormalizeRaceName(raceName)
    local normalizedRequestedLookupKey = RacingSystem.Server.Parsing.normalizeRaceLookupKey(raceName)
    if not normalizedRequestedName then
        return nil, ('A valid %s race name is required.'):format(label)
    end
    RacingSystem.Server.Logging.logVerbose(("[resolve:%s] request='%s' normalized='%s' lookupKey='%s' folder='%s'"):format(
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
        RacingSystem.Server.Logging.logVerbose(("[resolve:%s] try file token '%s' (normalized '%s')"):format(
            tostring(label),
            tostring(fileName),
            tostring(normalizedFileToken)
        ))

        local filePath = folderName == RacingSystem.Server.State.customRaceFolder
            and RacingSystem.Server.Parsing.buildCustomRaceFilePath(fileName)
            or RacingSystem.Server.Parsing.buildOnlineRaceFilePath(fileName)
        local rawMissionJson = LoadResourceFile(RacingSystem.Server.State.resourceName, filePath)
        if not rawMissionJson or rawMissionJson == '' then
            RacingSystem.Server.Logging.logVerbose(("[resolve:%s] token '%s' not found at '%s'"):format(
                tostring(label),
                tostring(fileName),
                tostring(filePath)
            ))
            return nil
        end

        local parsedRace, parseError = RacingSystem.Server.Parsing.parseRaceDefinitionFromJson(
            rawMissionJson,
            ('%s race "%s"'):format(label, fileName),
            fileName
        )
        if not parsedRace then
            RacingSystem.Server.Logging.logLevelOne(parseError or ('Could not parse %s race "%s".'):format(label, fileName))
            RacingSystem.Server.Logging.logVerbose(("[resolve:%s] token '%s' parse failed: %s"):format(
                tostring(label),
                tostring(fileName),
                tostring(parseError or 'unknown parse error')
            ))
            return nil
        end

        local parsedName = RacingSystem.Trim(parsedRace.name or '')
        RacingSystem.Server.Logging.logVerbose(("[resolve:%s] token '%s' resolved name='%s' ugcId='%s' checkpoints=%s"):format(
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
            checkpoints = RacingSystem.Server.Catalog.cloneCheckpoints(parsedRace.checkpoints),
            props = RacingSystem.Server.Snapshot.cloneOnlineRaceProps(parsedRace.props),
            modelHides = RacingSystem.Server.Snapshot.cloneOnlineRaceModelHides(parsedRace.modelHides),
            raceMetadata = RacingSystem.Server.Catalog.cloneMissionValue(parsedRace.raceMetadata),
            missionJson = rawMissionJson,
        }
    end

    local requestedToken = RacingSystem.Trim(raceName)
    local requestedSlug = RacingSystem.Server.Parsing.sanitizeOnlineRaceFileName(requestedToken)
    local requestedUGCId = RacingSystem.Server.Parsing.sanitizeUGCId(requestedToken)
    local directMatch = tryLoadByFileName(requestedToken)
        or (requestedSlug and tryLoadByFileName(requestedSlug))
        or (requestedUGCId and tryLoadByFileName(requestedUGCId))
    if directMatch then
        RacingSystem.Server.Logging.logVerbose(("[resolve:%s] direct token match success -> file='%s' name='%s' ugcId='%s'"):format(
            tostring(label),
            tostring(directMatch.fileName or 'unknown'),
            tostring(directMatch.name or 'unknown'),
            tostring(directMatch.ugcId or 'nil')
        ))
        return directMatch
    end

    for _, fileName in ipairs(RacingSystem.Server.Parsing.listJsonFilesInFolder(folderName)) do
        if triedFileNames[RacingSystem.NormalizeRaceName(fileName)] then
            goto continue
        end
        local filePath = folderName == RacingSystem.Server.State.customRaceFolder
            and RacingSystem.Server.Parsing.buildCustomRaceFilePath(fileName)
            or RacingSystem.Server.Parsing.buildOnlineRaceFilePath(fileName)
        local rawMissionJson = LoadResourceFile(RacingSystem.Server.State.resourceName, filePath)
        if rawMissionJson and rawMissionJson ~= '' then
            local parsedRace, parseError = RacingSystem.Server.Parsing.parseRaceDefinitionFromJson(
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
                local parsedLookupKey = RacingSystem.Server.Parsing.normalizeRaceLookupKey(parsedName)
                local fileLookupKey = RacingSystem.Server.Parsing.normalizeRaceLookupKey(fileName)
                local ugcLookupKey = RacingSystem.Server.Parsing.normalizeRaceLookupKey(parsedRace.ugcId)
                local derivedLookupKey = RacingSystem.Server.Parsing.normalizeRaceLookupKey(derivedHumanName)

                if normalizedRequestedName == normalizedParsedName
                    or normalizedRequestedName == normalizedFileName
                    or normalizedRequestedName == normalizedDerivedHumanName
                    or (normalizedUGCId and normalizedRequestedName == normalizedUGCId) then
                    RacingSystem.Server.Logging.logVerbose(("[resolve:%s] scan name/file match request='%s' file='%s' parsed='%s' derived='%s' ugcId='%s'"):format(
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
                        checkpoints = RacingSystem.Server.Catalog.cloneCheckpoints(parsedRace.checkpoints),
                        props = RacingSystem.Server.Snapshot.cloneOnlineRaceProps(parsedRace.props),
                        modelHides = RacingSystem.Server.Snapshot.cloneOnlineRaceModelHides(parsedRace.modelHides),
                        raceMetadata = RacingSystem.Server.Catalog.cloneMissionValue(parsedRace.raceMetadata),
                        missionJson = rawMissionJson,
                    }
                end

                if normalizedRequestedLookupKey and (
                    normalizedRequestedLookupKey == parsedLookupKey
                    or normalizedRequestedLookupKey == fileLookupKey
                    or normalizedRequestedLookupKey == derivedLookupKey
                    or (ugcLookupKey and normalizedRequestedLookupKey == ugcLookupKey)
                ) then
                    RacingSystem.Server.Logging.logVerbose(("[resolve:%s] scan lookupKey match request='%s' file='%s' parsedKey='%s' fileKey='%s' derivedKey='%s' ugcKey='%s'"):format(
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
                        checkpoints = RacingSystem.Server.Catalog.cloneCheckpoints(parsedRace.checkpoints),
                        props = RacingSystem.Server.Snapshot.cloneOnlineRaceProps(parsedRace.props),
                        modelHides = RacingSystem.Server.Snapshot.cloneOnlineRaceModelHides(parsedRace.modelHides),
                        raceMetadata = RacingSystem.Server.Catalog.cloneMissionValue(parsedRace.raceMetadata),
                        missionJson = rawMissionJson,
                    }
                end
            else
                RacingSystem.Server.Logging.logLevelOne(parseError or ('Could not parse %s race "%s".'):format(label, fileName))
            end
        end
        ::continue::
    end

    RacingSystem.Server.Logging.logVerbose(("[resolve:%s] no match for request='%s' in folder '%s'"):format(
        tostring(label),
        tostring(raceName),
        tostring(folderName)
    ))
    return nil, ('No %s race named "%s" was found.'):format(label, tostring(raceName))
end

local function loadCustomRace(raceName)
    return loadMissionRaceFromFolder(raceName, RacingSystem.Server.State.customRaceFolder, 'custom')
end

local function loadBundledOnlineRace(raceName)
    return loadMissionRaceFromFolder(raceName, RacingSystem.Server.State.onlineRaceFolder, 'online')
end

local function saveBundledUGCById(ugcId)
    local normalizedUGCId = RacingSystem.Server.Parsing.sanitizeUGCId(ugcId)
    if not normalizedUGCId then
        return nil, 'A valid UGC id is required.'
    end

    local rawMissionJson, fetchError = fetchUGCJsonContentById(normalizedUGCId)
    if not rawMissionJson then
        return nil, fetchError or 'Could not download the UGC JSON.'
    end

    local tempFilePath = ('%s/.tmp_%s.tmp'):format(RacingSystem.Server.State.onlineRaceFolder, normalizedUGCId)
    local function cleanupTempFile()
        local resourcePath = GetResourcePath(RacingSystem.Server.State.resourceName)
        if type(resourcePath) ~= 'string' or resourcePath == '' then
            return
        end

        local separator = resourcePath:find('\\', 1, true) and '\\' or '/'
        local absolutePath = resourcePath .. separator .. tempFilePath:gsub('/', separator)
        os.remove(absolutePath)
    end

    local tempSaveOk = SaveResourceFile(RacingSystem.Server.State.resourceName, tempFilePath, rawMissionJson, -1)
    if not tempSaveOk then
        return nil, ('Could not save temporary file %s.'):format(tempFilePath)
    end

    local tempRawJson = LoadResourceFile(RacingSystem.Server.State.resourceName, tempFilePath)
    local parsedRace, parseError = RacingSystem.Server.Parsing.parseRaceDefinitionFromJson(
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

    local normalizedRaceJson = RacingSystem.Server.Parsing.buildNormalizedOnlineRaceJson(displayRaceName, normalizedUGCId, parsedRace)
    if type(normalizedRaceJson) ~= 'string' or normalizedRaceJson == '' then
        cleanupTempFile()
        return nil, 'Could not encode normalized online race JSON.'
    end

    local filePath = RacingSystem.Server.Parsing.buildOnlineRaceFilePath(normalizedUGCId)
    local saveOk = SaveResourceFile(RacingSystem.Server.State.resourceName, filePath, normalizedRaceJson, -1)
    if not saveOk then
        cleanupTempFile()
        RacingSystem.Server.Logging.logError(("The server could not save imported UGC '%s' to '%s'."):format(tostring(normalizedUGCId), filePath))
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
    local normalizedUGCId = RacingSystem.Server.Parsing.sanitizeUGCId(ugcId)
    if not normalizedUGCId then
        return nil, 'A valid UGC id is required.'
    end

    local rawMissionJson, fetchError = fetchUGCJsonContentById(normalizedUGCId)
    if not rawMissionJson then
        return nil, fetchError or 'Could not download the UGC JSON.'
    end

    local parsedRace, parseError = RacingSystem.Server.Parsing.parseRaceDefinitionFromJson(
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

local function registerRaceDefinitionIfValid(raceName)
    local customRace = loadCustomRace(raceName)
    if customRace then
        local definition = RacingSystem.Server.Catalog.registerKnownRaceDefinition(customRace.name, 'custom')
        return definition, nil
    end

    local onlineRace = loadBundledOnlineRace(raceName)
    if onlineRace then
        local definition = RacingSystem.Server.Catalog.registerKnownRaceDefinition(onlineRace.name, 'online', onlineRace.ugcId or onlineRace.fileName)
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
        requestedRaceId = RacingSystem.Server.Parsing.sanitizeUGCId(request.raceId)
    else
        requestedName = RacingSystem.Trim(request or '')
        requestedLookupName = RacingSystem.NormalizeRaceName(requestedName)
    end

    if not requestedLookupName then
        return nil, 'A valid race name is required.'
    end

    local definitionLookupName = requestedLookupName
    local definition = RacingSystem.Server.State.knownRaceDefinitionsByName[definitionLookupName]

    if not definition and requestedRaceId then
        for lookupName, knownDefinition in pairs(RacingSystem.Server.State.knownRaceDefinitionsByName) do
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

    if RacingSystem.Server.State.immutableExampleLookupNames[definitionLookupName] == true then
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
    local definitionRaceId = RacingSystem.Server.Parsing.sanitizeUGCId(definition.raceId)
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
        targetFileName = (customRace and customRace.fileName) or RacingSystem.Server.Parsing.sanitizeOnlineRaceFileName(displayName) or definitionLookupName
    else
        targetFileName = (onlineRace and onlineRace.fileName) or resolvedRaceId or RacingSystem.Server.Parsing.sanitizeOnlineRaceFileName(displayName) or definitionLookupName
    end

    local relativePath = sourceType == 'custom'
        and RacingSystem.Server.Parsing.buildCustomRaceFilePath(targetFileName)
        or RacingSystem.Server.Parsing.buildOnlineRaceFilePath(targetFileName)

    local fileRemoved = false
    local fileRemoveError = nil
    local resourcePath = GetResourcePath(RacingSystem.Server.State.resourceName)
    if type(resourcePath) == 'string' and resourcePath ~= '' then
        local separator = resourcePath:find('\\', 1, true) and '\\' or '/'
        local absolutePath = resourcePath .. separator .. relativePath:gsub('/', separator)
        local removeOk, removeError = os.remove(absolutePath)
        if removeOk then
            fileRemoved = true
        else
            fileRemoveError = tostring(removeError or 'unknown error')
            RacingSystem.Server.Logging.logError(("The server could not delete '%s'. Reason: %s. Continuing with race index deletion."):format(relativePath, fileRemoveError))
        end
    else
        fileRemoveError = 'Could not resolve the resource path.'
        RacingSystem.Server.Logging.logError('Could not resolve the resource path. Continuing with race index deletion only.')
    end

    RacingSystem.Server.Catalog.unregisterKnownRaceDefinition(definitionLookupName)

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

    local fileName = RacingSystem.Server.Parsing.sanitizeOnlineRaceFileName(sanitizedName)
    if not fileName then
        return nil, 'Race name could not be converted into a valid mission filename.'
    end

    local filePath = RacingSystem.Server.Parsing.buildCustomRaceFilePath(fileName)

    local missionJson = RacingSystem.Server.Parsing.buildMissionJsonFromCheckpoints({}, nil, sanitizedName)
    local saveOk = SaveResourceFile(RacingSystem.Server.State.resourceName, filePath, missionJson, -1)
    if not saveOk then
        RacingSystem.Server.Logging.logError(("The server could not create new race '%s'."):format(filePath))
        return nil, ('Could not create %s.'):format(filePath)
    end

    RacingSystem.Server.Catalog.registerKnownRaceDefinition(sanitizedName, 'custom')
    RacingSystem.Server.Snapshot.broadcastDefinitions()

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

    local sanitizedCheckpoints = RacingSystem.Server.Parsing.sanitizeCheckpointList(checkpoints)
    if #sanitizedCheckpoints == 0 then
        return nil, 'At least one checkpoint is required.'
    end

    local fileName = RacingSystem.Server.Parsing.sanitizeOnlineRaceFileName(sanitizedName)
    if not fileName then
        return nil, 'Race name could not be converted into a valid mission filename.'
    end

    local filePath = RacingSystem.Server.Parsing.buildCustomRaceFilePath(fileName)
    local existingMissionJson = LoadResourceFile(RacingSystem.Server.State.resourceName, filePath)
    if (not existingMissionJson or existingMissionJson == '') then
        local existingOnlinePath = RacingSystem.Server.Parsing.buildOnlineRaceFilePath(fileName)
        existingMissionJson = LoadResourceFile(RacingSystem.Server.State.resourceName, existingOnlinePath)
    end
    local missionJson = RacingSystem.Server.Parsing.buildMissionJsonFromCheckpoints(sanitizedCheckpoints, existingMissionJson, sanitizedName)
    local saveOk = SaveResourceFile(RacingSystem.Server.State.resourceName, filePath, missionJson, -1)
    if not saveOk then
        RacingSystem.Server.Logging.logError(("The server could not save '%s'."):format(filePath))
        return nil, ('Could not save %s.'):format(filePath)
    end

    RacingSystem.Server.Catalog.registerKnownRaceDefinition(sanitizedName, 'custom')

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

RacingSystem.Server.Repository.loadMissionRaceFromFolder = loadMissionRaceFromFolder
RacingSystem.Server.Repository.loadCustomRace = loadCustomRace
RacingSystem.Server.Repository.loadBundledOnlineRace = loadBundledOnlineRace
RacingSystem.Server.Repository.saveBundledUGCById = saveBundledUGCById
RacingSystem.Server.Repository.validateBundledUGCById = validateBundledUGCById
RacingSystem.Server.Repository.registerRaceDefinitionIfValid = registerRaceDefinitionIfValid
RacingSystem.Server.Repository.deleteRaceDefinition = deleteRaceDefinition
RacingSystem.Server.Repository.createNewRaceDefinition = createNewRaceDefinition
RacingSystem.Server.Repository.saveRaceDefinition = saveRaceDefinition



