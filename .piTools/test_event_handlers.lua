-- Server event-handler synchronization and authorization tests.
-- Executes production event_handlers.lua with mocked FiveM/server dependencies.
-- Run from repository root: lua .piTools/test_event_handlers.lua

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

local netHandlers = {}
local localHandlers = {}
local clientEvents = {}
local notifications = {}
local playerStates = {}
local initialStateTargets = {}
local listBroadcasts = 0
local standingsBroadcasts = 0
local killCalls = 0
local resetCalls = 0
local lifecycleTransitions = 0
local adminSources = {}
local droppedResult = { changed = false, terminated = {} }

RegisterNetEvent = function(name, handler)
    netHandlers[name] = handler
end

AddEventHandler = function(name, handler)
    localHandlers[name] = handler
end

TriggerClientEvent = function(name, target, payload)
    clientEvents[#clientEvents + 1] = { name = name, target = target, payload = payload }
end

Player = function(playerSource)
    local numericSource = tonumber(playerSource) or 0
    playerStates[numericSource] = playerStates[numericSource] or {}
    return { state = playerStates[numericSource] }
end

GetPlayerName = function(playerSource)
    return ('Driver %s'):format(tostring(playerSource))
end

GetGameTimer = function() return 1000 end
GetPlayers = function() return {} end
GetCurrentResourceName = function() return 'racingsystem' end
SetTimeout = function(_, callback) callback() end
GlobalState = {}

RacingSystem = {
    Trim = function(value) return tostring(value or '') end,
    States = {
        idle = 'idle',
        staging = 'staging',
        running = 'running',
        finished = 'finished',
    },
    Config = { countdownMs = 5000 },
    Server = {
        State = { raceInstancesById = {} },
        Snapshot = {
            sendInitialState = function(target)
                initialStateTargets[#initialStateTargets + 1] = target
            end,
            broadcastInstanceList = function()
                listBroadcasts = listBroadcasts + 1
            end,
            broadcastInstanceStandings = function()
                standingsBroadcasts = standingsBroadcasts + 1
            end,
            findEntrantInRaceInstance = function(instance, playerSource)
                for _, entrant in ipairs(instance.entrants or {}) do
                    if tonumber(entrant.source) == tonumber(playerSource) then return entrant end
                end
                return nil
            end,
            sendRaceInfoToTarget = function() end,
            sendInstanceAssets = function() end,
            sendTeleportToCheckpoint = function() end,
            sendTeleportToLastCheckpoint = function() end,
            broadcastDefinitions = function() end,
        },
        Instances = {
            joinRaceInstanceById = function()
                return nil, 'That race instance does not exist.'
            end,
            resetRaceInstanceProgress = function()
                resetCalls = resetCalls + 1
            end,
            killRaceInstanceById = function(instanceId)
                killCalls = killCalls + 1
                return RacingSystem.Server.State.raceInstancesById[tonumber(instanceId)]
            end,
            removeSourceFromRaceInstances = function()
                return droppedResult.changed, droppedResult.terminated
            end,
        },
        Logging = {
            hasAdminAccess = function(playerSource)
                return adminSources[tonumber(playerSource)] == true
            end,
            resolvePlayerLogLabel = function(playerSource) return tostring(playerSource) end,
            logLevelOne = function() end,
            logVerbose = function() end,
            auditLog = function() end,
            notifyPlayer = function(target, message, isError)
                notifications[#notifications + 1] = {
                    target = target,
                    message = message,
                    isError = isError,
                }
            end,
            setRaceInstanceState = function(instance, nextState)
                lifecycleTransitions = lifecycleTransitions + 1
                instance.state = nextState
                return true, nil
            end,
        },
        Repository = {},
        Catalog = {},
        Parsing = {},
    },
}

dofile('racingsystem/server/event_handlers.lua')

-- Repeated state requests are targeted and do not require a mutating broadcast.
source = 12
netHandlers['racingsystem:state:request']()
netHandlers['racingsystem:state:request']()
expectEqual('state request count', #initialStateTargets, 2)
expectEqual('state request target', initialStateTargets[2], 12)
expectEqual('state request no list mutation', listBroadcasts, 0)

-- Invalid joins return the production handler's useful notification.
notifications = {}
netHandlers['racingsystem:race:joinById'](999)
expectEqual('invalid join notification count', #notifications, 1)
expectEqual('invalid join notification target', notifications[1].target, 12)
expectEqual('invalid join notification reason', notifications[1].message, 'That race instance does not exist.')
expectEqual('invalid join notification error flag', notifications[1].isError, true)

-- A non-owner cannot start an instance even if their state bag claims membership.
local startInstance = {
    id = 7,
    owner = 99,
    state = RacingSystem.States.idle,
    entrants = { { source = 12, entrantId = 'entrant-12' } },
}
RacingSystem.Server.State.raceInstancesById[7] = startInstance
playerStates[12] = { ['rs:instanceId'] = 7 }
notifications = {}
netHandlers['racingsystem:race:start']()
expectEqual('non-owner start notification', notifications[1].message, 'Only the host can start this race.')
expectEqual('non-owner start does not reset', resetCalls, 0)
expectEqual('non-owner start does not transition', lifecycleTransitions, 0)

-- Kill authorization is server-owned and does not trust menu state.
notifications = {}
killCalls = 0
netHandlers['racingsystem:race:kill'](7)
expectEqual('unauthorized kill blocked', killCalls, 0)
expectEqual('unauthorized kill notification', notifications[1].message, 'You do not have permission to kill races.')

adminSources[99] = true
source = 99
local killInstance = {
    id = 8,
    name = 'Kill Test',
    entrants = {
        { source = 21 },
        { source = 22 },
    },
}
RacingSystem.Server.State.raceInstancesById[8] = killInstance
playerStates[21] = {
    ['rs:instanceId'] = 8,
    ['rs:entrantId'] = 'entrant-21',
    ['rs:position'] = 1,
}
playerStates[22] = {
    ['rs:instanceId'] = 8,
    ['rs:entrantId'] = 'entrant-22',
    ['rs:position'] = 2,
}
listBroadcasts = 0
netHandlers['racingsystem:race:kill'](8)
expectEqual('authorized kill invoked', killCalls, 1)
expect('authorized kill clears first membership', playerStates[21]['rs:instanceId'] == nil)
expect('authorized kill clears second membership', playerStates[22]['rs:instanceId'] == nil)
expectEqual('authorized kill broadcasts list', listBroadcasts, 1)

-- Host-drop results clear every surviving guest represented by terminated instances.
source = 30
playerStates[30] = { ['rs:instanceId'] = 9, ['rs:entrantId'] = 'entrant-30' }
playerStates[31] = { ['rs:instanceId'] = 9, ['rs:entrantId'] = 'entrant-31', ['rs:position'] = 2 }
droppedResult = {
    changed = true,
    terminated = {
        {
            id = 9,
            entrants = {
                { source = 30 },
                { source = 31 },
            },
        },
    },
}
listBroadcasts = 0
localHandlers['playerDropped']()
expect('host drop clears host membership', playerStates[30]['rs:instanceId'] == nil)
expect('host drop clears guest membership', playerStates[31]['rs:instanceId'] == nil)
expect('host drop clears guest progress', playerStates[31]['rs:position'] == nil)
expectEqual('host drop broadcasts list', listBroadcasts, 1)

local total = passed + failed
io.write(('\n%d / %d assertions passed'):format(passed, total))
if failed > 0 then
    io.write((', %d FAILED\n'):format(failed))
    os.exit(1)
end
io.write(' — ALL PASSED\n')
