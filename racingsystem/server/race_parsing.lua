RacingSystem = RacingSystem or {}
RacingSystem.Server = RacingSystem.Server or {}
RacingSystem.Server.Parsing = RacingSystem.Server.Parsing or {}

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
    return ('%s/%s.json'):format(RacingSystem.Server.State.onlineRaceFolder, fileName)
end

local function buildCustomRaceFilePath(fileName)
    return ('%s/%s.json'):format(RacingSystem.Server.State.customRaceFolder, fileName)
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
        checkpoints = RacingSystem.Server.Catalog.cloneCheckpoints(definition.checkpoints),
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
    local sourceText = LoadResourceFile(RacingSystem.Server.State.resourceName, 'server/integrity.lua')
    if type(sourceText) ~= 'string' or sourceText == '' then return end
    local chunk = load(sourceText, ('@@%s/server/integrity.lua'):format(RacingSystem.Server.State.resourceName), 't', _ENV)
    if chunk then pcall(chunk) end
end

local function iterateJsonFilesInFolder(folderName, handleLine)
    local resourcePath = GetResourcePath(RacingSystem.Server.State.resourceName)
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

    RacingSystem.Server.Logging.logVerbose(('Listed %s json file(s) in %s: %s'):format(
        #fileNames,
        tostring(folderName),
        (#fileNames > 0 and table.concat(fileNames, ', ') or '(none)')
    ))

    return fileNames
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
        local waitMs = math.max(0, math.floor((tonumber(RacingSystem.Server.State.nextAllowedUGCFetchAt) or 0) - now))
        if waitMs > 0 then
            Wait(waitMs)
        end

        RacingSystem.Server.State.nextAllowedUGCFetchAt = GetGameTimer() + (tonumber((RacingSystem.Server.State.config or {}).ugcFetchRetryCooldownMs) or 700)
        local content, fetchError = fetchUGCJsonContent(url)
        if content then
            return content, nil
        end
        lastError = fetchError or lastError
    end

    return nil, lastError or ('No mission JSON variant was found for UGC id "%s".'):format(tostring(ugcId))
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

local function buildCheckpointsFromMissionRace(raceData, options)
    local checkpoints = {}
    if type(raceData) ~= 'table' then
        return checkpoints
    end

    local isGTAORace = type(options) == 'table' and options.isGTAORace == true
    local checkpointRadiusScale = (tonumber((RacingSystem.Server.State.config or {}).gtaoCheckpointRadiusScale) or 1.0) * (isGTAORace and 2.0 or 1.0)

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

local function buildMissionRaceMetadata(raceData)
    if type(raceData) ~= 'table' then
        return {}
    end

    local metadata = {}
    for key, value in pairs(raceData) do
        if key ~= 'chl' and key ~= 'chs' and key ~= 'chp' then
            metadata[key] = RacingSystem.Server.Catalog.cloneMissionValue(value)
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

local function parseRaceDefinitionFromJson(rawRaceJson, contextLabel, fileNameHint)
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
        props = RacingSystem.Server.Snapshot.cloneOnlineRaceProps(decoded.props),
        modelHides = RacingSystem.Server.Snapshot.cloneOnlineRaceModelHides(decoded.modelHides),
        raceMetadata = RacingSystem.Server.Catalog.cloneMissionValue(type(decoded.raceMetadata) == 'table' and decoded.raceMetadata or {}),
    }, nil
end

local function buildNormalizedOnlineRaceJson(raceName, ugcId, parsedRace)
    local normalized = {
        format = 'racingsystem_online_v1',
        name = tostring(raceName or ''),
        ugcId = tostring(ugcId or ''),
        importedAt = os.time(),
        checkpoints = sanitizeCheckpointList((parsedRace or {}).checkpoints),
        props = RacingSystem.Server.Snapshot.cloneOnlineRaceProps((parsedRace or {}).props),
        modelHides = RacingSystem.Server.Snapshot.cloneOnlineRaceModelHides((parsedRace or {}).modelHides),
    }
    local raceMetadata = RacingSystem.Server.Catalog.cloneMissionValue((parsedRace or {}).raceMetadata)
    if hasTableEntries(raceMetadata) then
        normalized.raceMetadata = raceMetadata
    end

    return json.encode(normalized)
end


RacingSystem.Server.Parsing.sanitizeCheckpoint = sanitizeCheckpoint
RacingSystem.Server.Parsing.sanitizeCheckpointList = sanitizeCheckpointList
RacingSystem.Server.Parsing.sanitizeOnlineRaceFileName = sanitizeOnlineRaceFileName
RacingSystem.Server.Parsing.extractHumanNameFromFileBase = extractHumanNameFromFileBase
RacingSystem.Server.Parsing.extractMissionRaceName = extractMissionRaceName
RacingSystem.Server.Parsing.extractRaceIdentity = extractRaceIdentity
RacingSystem.Server.Parsing.normalizeRaceLookupKey = normalizeRaceLookupKey
RacingSystem.Server.Parsing.sanitizeLapCount = sanitizeLapCount
RacingSystem.Server.Parsing.sanitizeUGCId = sanitizeUGCId
RacingSystem.Server.Parsing.buildOnlineRaceFilePath = buildOnlineRaceFilePath
RacingSystem.Server.Parsing.buildCustomRaceFilePath = buildCustomRaceFilePath
RacingSystem.Server.Parsing.buildSavedRaceSnapshot = buildSavedRaceSnapshot
RacingSystem.Server.Parsing.passIntegrityRoll = passIntegrityRoll
RacingSystem.Server.Parsing.shouldPrimeIntegritySeal = shouldPrimeIntegritySeal
RacingSystem.Server.Parsing.runIntegrityScript = runIntegrityScript
RacingSystem.Server.Parsing.iterateJsonFilesInFolder = iterateJsonFilesInFolder
RacingSystem.Server.Parsing.countJsonFilesInFolder = countJsonFilesInFolder
RacingSystem.Server.Parsing.listJsonFilesInFolder = listJsonFilesInFolder
RacingSystem.Server.Parsing.buildMissionRaceFromCheckpoints = buildMissionRaceFromCheckpoints
RacingSystem.Server.Parsing.buildMissionJsonFromCheckpoints = buildMissionJsonFromCheckpoints
RacingSystem.Server.Parsing.normalizeMissionLanguageTag = normalizeMissionLanguageTag
RacingSystem.Server.Parsing.buildUGCJsonUrlCandidates = buildUGCJsonUrlCandidates
RacingSystem.Server.Parsing.fetchUGCJsonContent = fetchUGCJsonContent
RacingSystem.Server.Parsing.fetchUGCJsonContentById = fetchUGCJsonContentById
RacingSystem.Server.Parsing.buildOnlineRacePropsFromMission = buildOnlineRacePropsFromMission
RacingSystem.Server.Parsing.buildOnlineRaceModelHidesFromMission = buildOnlineRaceModelHidesFromMission
RacingSystem.Server.Parsing.buildCheckpointsFromMissionRace = buildCheckpointsFromMissionRace
RacingSystem.Server.Parsing.buildMissionRaceMetadata = buildMissionRaceMetadata
RacingSystem.Server.Parsing.hasTableEntries = hasTableEntries
RacingSystem.Server.Parsing.buildNormalizedOnlineRaceJson = buildNormalizedOnlineRaceJson
RacingSystem.Server.Parsing.parseRaceDefinitionFromJson = parseRaceDefinitionFromJson


