-- Repository/parsing robustness tests using production modules and mocked FiveM APIs.
-- Run from repository root: lua .piTools/test_repository_robustness.lua

local passed, failed = 0, 0
local function expect(label, condition, message)
    if condition then passed = passed + 1 else
        failed = failed + 1
        io.stderr:write(('FAIL [%s]: %s\n'):format(label, message or 'condition was false'))
    end
end
local function expectEqual(label, actual, expected)
    expect(label, actual == expected, ('expected %s, got %s'):format(tostring(expected), tostring(actual)))
end

json = {
    decode = function(raw)
        if raw == 'MALFORMED' then error('mock malformed JSON') end
        if raw == 'CUSTOM' then
            return { name = 'Safe Race', checkpoints = { { x = 1, y = 2, z = 3, radius = 8 } } }
        end
        if raw == 'ONLINE' then
            return { name = 'Online Race', ugcId = 'ugc123', checkpoints = { { x = 4, y = 5, z = 6, radius = 10 } } }
        end
        error('unexpected JSON fixture: ' .. tostring(raw))
    end,
    encode = function(value)
        if type(value) == 'table' and value.format == 'racingsystem_online_v1' then
            return 'ONLINE'
        end
        return 'INDEX'
    end,
}

local loadedPaths = {}
local files = {
    ['CustomRaces/safe.json'] = 'CUSTOM',
    ['OnlineRaces/ugc123.json'] = 'ONLINE',
    ['race_index_examples.json'] = 'MALFORMED',
    ['race_index.json'] = 'MALFORMED',
}
LoadResourceFile = function(_, path)
    loadedPaths[#loadedPaths + 1] = path
    return files[path]
end
local saveShouldFail = false
SaveResourceFile = function(_, path, content)
    if saveShouldFail then return false end
    files[path] = content
    return true
end
GetResourcePath = function() return 'C:/mock/racingsystem' end
GetGameTimer = function() return 1000 end
Wait = function() end
PerformHttpRequest = function() error('HTTP should be mocked before use') end

RacingSystem = {
    Config = {
        minLapCount = 1,
        maxLapCount = 10,
        checkpointRadiusMinMeters = 2,
        checkpointRadiusMaxMeters = 40,
    },
    States = { idle = 'idle', staging = 'staging', running = 'running', finished = 'finished' },
    Server = {
        State = {
            resourceName = 'racingsystem',
            indexFile = 'race_index.json',
            indexExamplesFile = 'race_index_examples.json',
            customRaceFolder = 'CustomRaces',
            onlineRaceFolder = 'OnlineRaces',
            knownRaceDefinitionsByName = {},
            immutableExampleLookupNames = {},
            raceInstancesById = {},
            raceInstanceIdsByName = {},
            config = {
                gtaoCheckpointRadiusScale = 1,
                ugcFetchRetryCooldownMs = 0,
            },
        },
        Catalog = {},
        Parsing = {},
        Repository = {},
        Snapshot = {
            cloneOnlineRaceProps = function(value) return type(value) == 'table' and value or {} end,
            cloneOnlineRaceModelHides = function(value) return type(value) == 'table' and value or {} end,
            findRaceInstanceByName = function() return nil end,
            broadcastDefinitions = function() end,
        },
        Logging = {
            logError = function() end,
            logLevelOne = function() end,
            logVerbose = function() end,
        },
    },
}

dofile('racingsystem/shared/shared.lua')
dofile('racingsystem/server/race_catalog.lua')

local okCatalog, catalogError = pcall(RacingSystem.Server.Catalog.loadRaceIndex)
expect('malformed catalog files do not throw', okCatalog, tostring(catalogError))
expectEqual('malformed catalog loads no definitions', #RacingSystem.Server.Catalog.buildSavedRaceDefinitions(), 0)

dofile('racingsystem/server/race_parsing.lua')
RacingSystem.Server.Parsing.listJsonFilesInFolder = function(folder)
    if folder == 'CustomRaces' then return { 'bad', 'safe' } end
    if folder == 'OnlineRaces' then return { 'ugc123' } end
    return {}
end
dofile('racingsystem/server/race_repository.lua')

local parsed, parseError = RacingSystem.Server.Parsing.parseRaceDefinitionFromJson('MALFORMED', 'malformed fixture', 'bad')
expect('malformed race JSON rejected', parsed == nil)
expect('malformed race JSON useful error', type(parseError) == 'string' and parseError:find('mock malformed JSON', 1, true) ~= nil, tostring(parseError))

local missionJson, missionError = RacingSystem.Server.Parsing.buildMissionJsonFromCheckpoints({}, 'MALFORMED', 'Bad Existing Race')
expect('malformed existing mission rejected', missionJson == nil)
expect('malformed existing mission useful error', type(missionError) == 'string' and missionError ~= '', tostring(missionError))

local bounded = RacingSystem.Server.Parsing.sanitizeCheckpointList({
    { x = 1, y = 2, z = 3, radius = -100 },
    { x = 20000, y = 2, z = 3, radius = 8 },
    { x = 4, y = 5, z = 6, radius = 100 },
})
expectEqual('invalid checkpoint coordinate rejected', #bounded, 2)
expectEqual('checkpoint radius clamps to configured minimum', bounded[1].radius, 2)
expectEqual('checkpoint radius clamps to configured maximum', bounded[2].radius, 40)
local oversized = {}
for index = 1, 1005 do oversized[index] = { x = index, y = 0, z = 0, radius = 8 } end
expectEqual('checkpoint list capped', #RacingSystem.Server.Parsing.sanitizeCheckpointList(oversized), 1000)

files['CustomRaces/bad.json'] = 'MALFORMED'
local invalidRace, invalidError, invalidStatus = RacingSystem.Server.Repository.loadCustomRace('bad')
expect('malformed direct race rejected', invalidRace == nil)
expectEqual('malformed direct race status', invalidStatus, 'invalid')
expect('malformed direct race reports decode error', type(invalidError) == 'string' and invalidError ~= '')

loadedPaths = {}
local customRace, customError = RacingSystem.Server.Repository.loadCustomRace('../safe')
expect('sanitized custom lookup resolves', customRace ~= nil, tostring(customError))
expectEqual('custom source identity retained', customRace and customRace.sourceType, 'custom')
for _, path in ipairs(loadedPaths) do
    expect('custom lookup never loads traversal path', not path:find('..', 1, true), path)
end

local onlineRace, onlineError = RacingSystem.Server.Repository.loadBundledOnlineRace('ugc123')
expect('online lookup resolves', onlineRace ~= nil, tostring(onlineError))
expectEqual('online source identity retained', onlineRace and onlineRace.sourceType, 'online')
expectEqual('online race id retained', onlineRace and onlineRace.raceId, 'ugc123')

saveShouldFail = true
local failedDefinition, failedDefinitionError = RacingSystem.Server.Catalog.registerKnownRaceDefinition('Not Durable', 'custom')
saveShouldFail = false
expect('catalog registration failure reported', failedDefinition == nil and type(failedDefinitionError) == 'string')
expect('catalog registration rollback restores memory', RacingSystem.Server.State.knownRaceDefinitionsByName['not durable'] == nil)

local productionFetchUGCById = RacingSystem.Server.Parsing.fetchUGCJsonContentById
RacingSystem.Server.Parsing.fetchUGCJsonContentById = function(ugcId)
    expectEqual('UGC validation uses exported fetch helper', ugcId, 'ugc123')
    return 'ONLINE', nil
end
local imported, importError = RacingSystem.Server.Repository.saveBundledUGCById('ugc123')
expect('UGC import succeeds through exported helper', imported ~= nil, tostring(importError))
expectEqual('UGC import checkpoint count', imported and imported.checkpointCount, 1)

local originalGetGameTimer = GetGameTimer
local originalWait = Wait
local originalPerformHttpRequest = PerformHttpRequest
local fetchTimer = 1000
local fetchCalls = 0
GetGameTimer = function() return fetchTimer end
Wait = function(ms) fetchTimer = fetchTimer + (tonumber(ms) or 0) end
PerformHttpRequest = function(_, callback)
    fetchCalls = fetchCalls + 1
    callback(404, '', {})
end
RacingSystem.Server.State.config.ugcFetchTotalTimeoutMs = 1000
RacingSystem.Server.State.config.ugcFetchRetryCooldownMs = 700
RacingSystem.Server.State.nextAllowedUGCFetchAt = 0
local timedOutContent = productionFetchUGCById('timeout-id')
expect('UGC total deadline returns no content', timedOutContent == nil)
expect('UGC total deadline bounds candidate attempts', fetchCalls <= 2, tostring(fetchCalls))
GetGameTimer = originalGetGameTimer
Wait = originalWait
PerformHttpRequest = originalPerformHttpRequest

local draft = RacingSystem.Server.Repository.createNewRaceDraft(12, 'Unsaved Draft')
expect('new editor draft created in memory', draft ~= nil)
expect('new editor draft not written to disk', files['CustomRaces/unsaveddraft.json'] == nil)
expect('new editor draft not added to catalog', RacingSystem.Server.State.knownRaceDefinitionsByName['unsaved draft'] == nil)

RacingSystem.Server.State.knownRaceDefinitionsByName['safe race'] = {
    lookupName = 'safe race', name = 'Safe Race', sourceType = 'custom',
}
RacingSystem.Server.Snapshot.findRaceInstanceByName = function(name)
    expectEqual('delete checks active instance through exported helper', name, 'safe race')
    return { id = 1 }
end
local deleted, deleteError = RacingSystem.Server.Repository.deleteRaceDefinition({ lookupName = 'safe race' })
expect('active definition deletion rejected', deleted == nil)
expectEqual('active definition deletion reason', deleteError, 'Cannot delete a race while its instance is active.')

RacingSystem.Server.Snapshot.findRaceInstanceByName = function() return nil end
local originalRemove = os.remove
os.remove = function() return nil, 'mock locked file' end
local failedDelete, failedDeleteError = RacingSystem.Server.Repository.deleteRaceDefinition({ lookupName = 'safe race' })
os.remove = originalRemove
expect('filesystem delete failure reported', failedDelete == nil and type(failedDeleteError) == 'string')
expect('filesystem delete failure restores catalog', RacingSystem.Server.State.knownRaceDefinitionsByName['safe race'] ~= nil)

files['OnlineRaces/a.json'] = 'ONLINE'
files['OnlineRaces/b.json'] = 'ONLINE'
RacingSystem.Server.State.knownRaceDefinitionsByName['online a'] = {
    lookupName = 'online a', name = 'Online A', sourceType = 'online', raceId = 'a',
}
RacingSystem.Server.State.knownRaceDefinitionsByName['online b'] = {
    lookupName = 'online b', name = 'Online B', sourceType = 'online', raceId = 'b',
}
local removedAbsolutePath = nil
os.remove = function(path)
    removedAbsolutePath = path
    return true
end
local mismatchedDelete, mismatchedDeleteError = RacingSystem.Server.Repository.deleteRaceDefinition({
    lookupName = 'online a',
    sourceType = 'online',
    raceId = 'b',
})
os.remove = originalRemove
expect('mismatched delete request succeeds against resolved identity', mismatchedDelete ~= nil, tostring(mismatchedDeleteError))
expect('mismatched delete removes definition-owned file', type(removedAbsolutePath) == 'string' and removedAbsolutePath:match('a%.json$') ~= nil, tostring(removedAbsolutePath))
expect('mismatched delete preserves unrelated definition', RacingSystem.Server.State.knownRaceDefinitionsByName['online b'] ~= nil)

local total = passed + failed
io.write(('\n%d / %d assertions passed'):format(passed, total))
if failed > 0 then
    io.write((', %d FAILED\n'):format(failed))
    os.exit(1)
end
io.write(' — ALL PASSED\n')
