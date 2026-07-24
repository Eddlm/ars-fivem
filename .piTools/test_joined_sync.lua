-- Phase 3 joined-racer synchronization unit tests.
-- Executes production race_instances.lua with mocked FiveM/server dependencies.
-- Run from repository root: lua .piTools/test_joined_sync.lua

local passed = 0
local failed = 0

local function expect(label, condition, message)
    if condition then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write(('FAIL [%s]: %s\n'):format(label, message or 'condition was false'))
    end
end

local function expectEqual(label, actual, expected)
    expect(label, actual == expected, ('expected %s, got %s'):format(tostring(expected), tostring(actual)))
end

local standingsCalls = 0
local standingsSnapshots = {}
local lapEvents = {}
local gameTimer = 1000

GetGameTimer = function()
    gameTimer = gameTimer + 100
    return gameTimer
end
TriggerClientEvent = function(name, target, payload)
    if name == 'racingsystem:race:lapCompleted' then
        lapEvents[#lapEvents + 1] = { target = target, payload = payload }
    end
end

RacingSystem = {
    States = {
        idle = 'idle',
        staging = 'staging',
        running = 'running',
        finished = 'finished',
    },
    Config = {
        playerCanInvokeMultipleRaces = false,
        lateJoinProgressLimitPercent = 50,
    },
    Trim = function(value) return tostring(value or '') end,
    NormalizeRaceName = function(value)
        local text = tostring(value or '')
        return text ~= '' and text:lower() or nil
    end,
    Server = {
        Instances = {},
        State = {
            raceInstancesById = {},
            nextRaceInstanceId = 1,
        },
        Snapshot = {
            findEntrantInRaceInstance = function(instance, source)
                for _, entrant in ipairs(instance.entrants or {}) do
                    if tonumber(entrant.source) == tonumber(source) then
                        return entrant
                    end
                end
                return nil
            end,
            getLapTriggerCheckpoint = function(_, totalCheckpoints)
                return totalCheckpoints
            end,
            getRaceStartCheckpoint = function()
                return 1
            end,
            buildOrderedEntrants = function(instance)
                for index, entrant in ipairs(instance.entrants or {}) do entrant.position = index end
                return instance.entrants or {}
            end,
            broadcastInstanceStandings = function(instance)
                standingsCalls = standingsCalls + 1
                local entrant = instance.entrants[1]
                standingsSnapshots[#standingsSnapshots + 1] = {
                    currentCheckpoint = entrant.currentCheckpoint,
                    currentLap = entrant.currentLap,
                    finishedAt = entrant.finishedAt,
                }
            end,
        },
        Logging = {
            logLevelOne = function() end,
            logError = function() end,
            logVerbose = function() end,
            resolvePlayerLogLabel = function(source) return tostring(source) end,
            resolveReadablePlayerName = function(source) return tostring(source) end,
            shouldLogCheckpointAnomaly = function() return false end,
            shouldLogLifecycleAnomaly = function() return false end,
        },
        Parsing = {},
        Catalog = {},
        Repository = {},
    },
}

dofile('racingsystem/server/race_instances.lua')
local handleCheckpointPassed = RacingSystem.Server.Instances.handleCheckpointPassed

local missingJoin, missingJoinError = RacingSystem.Server.Instances.joinRaceInstanceById(11, 999)
expect('invalid join rejected', missingJoin == nil)
expectEqual('invalid join useful reason', missingJoinError, 'That race instance does not exist.')

local function buildInstance()
    return {
        id = 7,
        name = 'Test Race',
        state = RacingSystem.States.running,
        laps = 1,
        pointToPoint = false,
        checkpoints = {
            { index = 1 },
            { index = 2 },
            { index = 3 },
        },
        entrants = {
            {
                entrantId = 'entrant-1',
                source = 11,
                name = 'Driver One',
                currentCheckpoint = 1,
                currentLap = 1,
                checkpointsPassed = 0,
                lapIncrementUnlocked = false,
                lapTimes = {},
            },
            {
                entrantId = 'entrant-2',
                source = 22,
                name = 'Driver Two',
                currentCheckpoint = 1,
                currentLap = 1,
                checkpointsPassed = 0,
                lapIncrementUnlocked = false,
                lapTimes = {},
            },
        },
    }
end

-- Every accepted checkpoint mutation immediately publishes standings/state bags.
local instance = buildInstance()
RacingSystem.Server.State.raceInstancesById[instance.id] = instance
standingsCalls = 0
standingsSnapshots = {}
local result, resultError = handleCheckpointPassed(11, instance.id, 1, nil)
expect('checkpoint accepted', result == instance, tostring(resultError))
expectEqual('checkpoint advances target', instance.entrants[1].currentCheckpoint, 2)
expectEqual('checkpoint increments absolute progress', instance.entrants[1].checkpointsPassed, 1)
expectEqual('checkpoint standings exactly once', standingsCalls, 1)
expectEqual('checkpoint standings sees new target', standingsSnapshots[1].currentCheckpoint, 2)

-- Rejected/out-of-order input does not publish a state mutation.
standingsCalls = 0
result, resultError = handleCheckpointPassed(11, instance.id, 1, nil)
expect('out of order rejected', result == nil)
expectEqual('out of order reason', resultError, 'Ignored out-of-order checkpoint pass.')
expectEqual('out of order no standings', standingsCalls, 0)

-- A finishing entrant publishes finished progress once before aggregate cleanup.
instance = buildInstance()
instance.startedAt = 500
instance.entrants[1].lapStartedAt = 700
instance.entrants[1].currentCheckpoint = 3
instance.entrants[1].lapIncrementUnlocked = true
RacingSystem.Server.State.raceInstancesById[instance.id] = instance
standingsCalls = 0
standingsSnapshots = {}
lapEvents = {}
result, resultError = handleCheckpointPassed(11, instance.id, 3, {
    lapTimeMs = 5000,
    totalTimeMs = 5000,
})
expect('finish checkpoint accepted', result == instance, tostring(resultError))
expectEqual('finish target passes route end', instance.entrants[1].currentCheckpoint, 4)
expect('finish timestamp set', tonumber(instance.entrants[1].finishedAt) ~= nil)
expectEqual('finish standings exactly once', standingsCalls, 1)
expect('finish standings includes timestamp', tonumber(standingsSnapshots[1].finishedAt) ~= nil)
expectEqual('other entrant prevents aggregate finish', instance.state, RacingSystem.States.running)
expectEqual('server owns lap timing', instance.entrants[1].lapTimes[1], instance.entrants[1].finishedAt - 700)
expectEqual('server owns total timing', instance.entrants[1].totalTimeMs, instance.entrants[1].finishedAt - 500)
expect('client timing payload ignored', instance.entrants[1].lapTimes[1] ~= 5000)
expectEqual('lap completion sent once', #lapEvents, 1)
expectEqual('lap completion sent to owner', lapEvents[1] and lapEvents[1].target, 11)
expectEqual('lap completion carries server time', lapEvents[1] and lapEvents[1].payload.lapTimeMs, instance.entrants[1].lapTimes[1])

-- Point-to-point routes are normalized to one lap regardless of client input.
RacingSystem.Server.Repository.loadCustomRace = function()
    return {
        name = 'Point To Point',
        checkpoints = {
            { x = 0, y = 0, z = 0, radius = 8 },
            { x = 1000, y = 0, z = 0, radius = 8 },
        },
        props = {},
        modelHides = {},
        raceMetadata = {},
    }
end
RacingSystem.Server.Repository.loadBundledOnlineRace = function() return nil end
RacingSystem.Server.Parsing.sanitizeLapCount = function(value) return math.max(1, math.floor(tonumber(value) or 3)) end
RacingSystem.Server.Catalog.cloneCheckpoints = function(value) return value end
RacingSystem.Server.Catalog.cloneMissionValue = function(value) return value end
RacingSystem.Server.Snapshot.cloneOnlineRaceProps = function(value) return value or {} end
RacingSystem.Server.Snapshot.cloneOnlineRaceModelHides = function(value) return value or {} end
RacingSystem.Server.Snapshot.isPointToPointByCheckpointDistance = function() return true end
RacingSystem.Server.Snapshot.findRaceInstanceByName = function() return nil end
RacingSystem.Server.Snapshot.buildEntrant = function(source)
    return { entrantId = 'entrant-' .. tostring(source), source = source }
end
RacingSystem.Server.Snapshot.upsertEntrantState = function() end
RacingSystem.Server.Snapshot.indexRaceInstanceName = function() end
RacingSystem.Server.Logging.setRaceStateBag = function() end
RacingSystem.Server.State.nextRaceInstanceId = 20
local pointToPointInstance, invokeError = RacingSystem.Server.Instances.invokeRaceInstance(33, 'Point To Point', 5)
expect('point-to-point invoke succeeds', pointToPointInstance ~= nil, tostring(invokeError))
expectEqual('point-to-point lap count normalized', pointToPointInstance and pointToPointInstance.laps, 1)

local total = passed + failed
io.write(('\n%d / %d assertions passed'):format(passed, total))
if failed > 0 then
    io.write((', %d FAILED\n'):format(failed))
    os.exit(1)
end
io.write(' — ALL PASSED\n')
