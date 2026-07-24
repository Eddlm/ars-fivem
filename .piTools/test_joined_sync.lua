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
local gameTimer = 1000

GetGameTimer = function()
    gameTimer = gameTimer + 100
    return gameTimer
end
TriggerClientEvent = function() end

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
instance.entrants[1].currentCheckpoint = 3
instance.entrants[1].lapIncrementUnlocked = true
RacingSystem.Server.State.raceInstancesById[instance.id] = instance
standingsCalls = 0
standingsSnapshots = {}
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

local total = passed + failed
io.write(('\n%d / %d assertions passed'):format(passed, total))
if failed > 0 then
    io.write((', %d FAILED\n'):format(failed))
    os.exit(1)
end
io.write(' — ALL PASSED\n')
