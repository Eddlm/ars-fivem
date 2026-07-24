-- Phase 1 synchronization unit tests.
-- Executes production server/client modules with FiveM event mocks.
-- Run from repository root: lua .piTools/test_instance_list_payload.lua

local passed = 0
local failed = 0

local function fail(label, message)
    failed = failed + 1
    io.stderr:write(('FAIL [%s]: %s\n'):format(label, message))
end

local function expect(label, condition, message)
    if condition then
        passed = passed + 1
    else
        fail(label, message or 'condition was false')
    end
end

local function expectEqual(label, actual, expected)
    expect(label, actual == expected, ('expected %s, got %s'):format(tostring(expected), tostring(actual)))
end

local function expectKeys(label, value, expectedKeys)
    local expected = {}
    for _, key in ipairs(expectedKeys) do
        expected[key] = true
    end
    for key in pairs(value) do
        if not expected[key] then
            fail(label, ('unexpected key %s'):format(tostring(key)))
            return
        end
        expected[key] = nil
    end
    for key in pairs(expected) do
        fail(label, ('missing key %s'):format(tostring(key)))
        return
    end
    passed = passed + 1
end

local function activeInstance(id, state, entrantCount)
    local entrants = {}
    for source = 1, entrantCount do
        entrants[source] = { source = source }
    end
    return {
        id = id,
        name = ('Race %d'):format(id),
        sourceType = 'custom',
        owner = 42,
        state = state,
        laps = 2,
        trafficDensity = 0.25,
        lateJoinProgressLimitPercent = 50,
        entrantCount = entrantCount,
        entrants = entrants,
        checkpoints = { { x = 1, y = 2, z = 3 } },
        props = { { model = 1 } },
        modelHides = { { model = 2 } },
    }
end

-- Load the real server implementation. Unresolved FiveM globals are safe until
-- the corresponding exported function is invoked; invoked event APIs are mocked.
local clientEvents = {}
TriggerClientEvent = function(name, target, payload)
    clientEvents[#clientEvents + 1] = { name = name, target = target, payload = payload }
end

RacingSystem = {
    States = {
        idle = 'idle',
        staging = 'staging',
        running = 'running',
        finished = 'finished',
    },
    Config = {},
    NormalizeRaceName = function(value) return value end,
    Server = {
        Snapshot = {},
        State = {
            raceInstancesById = {},
            raceInstanceIdsByName = {},
            instanceListRevision = 0,
            config = {},
        },
        Logging = {
            hasAdminAccess = function() return false end,
        },
        Catalog = {},
    },
}

dofile('racingsystem/server/snapshot_runtime.lua')
local Snapshot = RacingSystem.Server.Snapshot

-- Empty payload and exact envelope.
local payload = Snapshot.buildInstanceListPayload()
expectKeys('server empty envelope', payload, { 'revision', 'instances' })
expectEqual('server empty revision', payload.revision, 0)
expectEqual('server empty list', #payload.instances, 0)

-- Include only public lifecycle states and sort by numeric ID.
RacingSystem.Server.State.raceInstancesById = {
    [30] = activeInstance(30, RacingSystem.States.running, 3),
    [10] = activeInstance(10, RacingSystem.States.idle, 1),
    [40] = activeInstance(40, RacingSystem.States.finished, 4),
    [20] = activeInstance(20, RacingSystem.States.staging, 2),
    [50] = activeInstance(50, 'unknown', 5),
}
payload = Snapshot.buildInstanceListPayload()
expectEqual('server visible count', #payload.instances, 3)
expectEqual('server sorted id 1', payload.instances[1].id, 10)
expectEqual('server sorted id 2', payload.instances[2].id, 20)
expectEqual('server sorted id 3', payload.instances[3].id, 30)
expectKeys('server summary contract', payload.instances[1], {
    'id',
    'name',
    'sourceType',
    'owner',
    'state',
    'laps',
    'trafficDensity',
    'lateJoinProgressLimitPercent',
    'entrantCount',
})
expectEqual('server entrant count', payload.instances[3].entrantCount, 3)
expectEqual('server late join limit', payload.instances[1].lateJoinProgressLimitPercent, 50)
expect('server excludes checkpoints', payload.instances[1].checkpoints == nil)
expect('server excludes props', payload.instances[1].props == nil)
expect('server excludes model hides', payload.instances[1].modelHides == nil)
expect('server excludes entrant rows', payload.instances[1].entrants == nil)

-- A missing/invalid lifecycle state is not silently treated as a visible state.
RacingSystem.Server.State.raceInstancesById = {
    [1] = activeInstance(1, nil, 0),
    [2] = activeInstance(2, 'cancelled', 0),
}
payload = Snapshot.buildInstanceListPayload()
expectEqual('server invalid states excluded', #payload.instances, 0)

-- Targeted sends retain the current revision.
RacingSystem.Server.State.raceInstancesById = {
    [1] = activeInstance(1, RacingSystem.States.idle, 1),
}
RacingSystem.Server.State.instanceListRevision = 7
clientEvents = {}
Snapshot.sendInstanceList(12)
expectEqual('server targeted event count', #clientEvents, 1)
expectEqual('server targeted event name', clientEvents[1].name, 'racingsystem:instance:list')
expectEqual('server targeted event target', clientEvents[1].target, 12)
expectEqual('server targeted revision payload', clientEvents[1].payload.revision, 7)
expectEqual('server targeted revision unchanged', RacingSystem.Server.State.instanceListRevision, 7)

-- Invalid targets produce no event.
clientEvents = {}
Snapshot.sendInstanceList(0)
Snapshot.sendInstanceList(nil)
expectEqual('server invalid target ignored', #clientEvents, 0)

-- Broadcast advances once and sends one common payload to all clients.
clientEvents = {}
Snapshot.broadcastInstanceList()
expectEqual('server broadcast event count', #clientEvents, 1)
expectEqual('server broadcast target', clientEvents[1].target, -1)
expectEqual('server broadcast revision state', RacingSystem.Server.State.instanceListRevision, 8)
expectEqual('server broadcast revision payload', clientEvents[1].payload.revision, 8)

-- Initial state is a targeted read and does not advance the revision.
clientEvents = {}
Snapshot.sendInitialState(22)
expectEqual('server initial event count', #clientEvents, 1)
expectEqual('server initial target', clientEvents[1].target, 22)
expectEqual('server initial revision', clientEvents[1].payload.revision, 8)
expectEqual('server initial revision unchanged', RacingSystem.Server.State.instanceListRevision, 8)

-- Load the real client cache module with event registration mocks.
local netHandlers = {}
local localEvents = {}
RegisterNetEvent = function(name, handler)
    netHandlers[name] = handler
end
TriggerEvent = function(name, ...)
    localEvents[#localEvents + 1] = { name = name, args = { ... } }
end
RacingSystem = { Client = {} }

dofile('racingsystem/client/instance_list.lua')
local receiveList = netHandlers['racingsystem:instance:list']
expect('client handler registered', type(receiveList) == 'function')
expect('client cache not exposed', RacingSystem.Client.instanceListCache == nil)
expectEqual('client starts empty', #RacingSystem.Client.getInstanceList(), 0)

-- Invalid envelopes/revisions do not replace the cache or emit an update event.
receiveList(nil)
receiveList({ instances = {} })
receiveList({ revision = -1, instances = {} })
expectEqual('client invalid payload stays empty', #RacingSystem.Client.getInstanceList(), 0)
expectEqual('client invalid payload no update event', #localEvents, 0)

-- A valid complete payload replaces the cache and emits the local refresh event.
local sourceInstances = {
    activeInstance(10, 'idle', 1),
    activeInstance(20, 'running', 2),
}
receiveList({ revision = 3, instances = sourceInstances })
local cached = RacingSystem.Client.getInstanceList()
expectEqual('client valid list count', #cached, 2)
expectEqual('client valid first id', cached[1].id, 10)
expectEqual('client update event count', #localEvents, 1)
expectEqual('client update event name', localEvents[1].name, 'racingsystem:instance:listUpdated')
expectEqual('client update event revision', localEvents[1].args[1], 3)
expectKeys('client getter summary contract', cached[1], {
    'id',
    'name',
    'sourceType',
    'owner',
    'state',
    'laps',
    'trafficDensity',
    'lateJoinProgressLimitPercent',
    'entrantCount',
})

-- Getter results cannot mutate the internal cache.
cached[1].name = 'mutated'
cached[2] = nil
local cachedAgain = RacingSystem.Client.getInstanceList()
expectEqual('client getter protects summary', cachedAgain[1].name, 'Race 10')
expectEqual('client getter protects list', #cachedAgain, 2)

-- An older revision is stale; an equal revision is a valid targeted refresh.
receiveList({ revision = 2, instances = { activeInstance(99, 'idle', 0) } })
expectEqual('client stale revision ignored', RacingSystem.Client.getInstanceList()[1].id, 10)
receiveList({ revision = 3, instances = { activeInstance(30, 'staging', 0) } })
expectEqual('client equal revision replaces', RacingSystem.Client.getInstanceList()[1].id, 30)
expectEqual('client replacement update event', #localEvents, 2)

local total = passed + failed
io.write(('\n%d / %d assertions passed'):format(passed, total))
if failed > 0 then
    io.write((', %d FAILED\n'):format(failed))
    os.exit(1)
end
io.write(' — ALL PASSED\n')
