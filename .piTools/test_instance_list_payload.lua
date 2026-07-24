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
        entrants[source] = {
            entrantId = ('entrant-%d'):format(source),
            source = source,
            name = ('Driver %d'):format(source),
            currentCheckpoint = 1,
            currentLap = 1,
            checkpointsPassed = 0,
            lapTimes = {},
        }
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
local lifecycleReason = nil
TriggerClientEvent = function(name, target, payload)
    clientEvents[#clientEvents + 1] = { name = name, target = target, payload = payload }
end

RacingSystem = {
    Config = {},
    Server = {
        Snapshot = {},
        State = {
            raceInstancesById = {},
            knownRaceDefinitionsByName = {
                ['z online'] = {
                    lookupName = 'z online',
                    name = 'Z Online',
                    sourceType = 'online',
                    raceId = 'online-id',
                    updatedAt = 20,
                    isExample = false,
                },
                ['a custom'] = {
                    lookupName = 'a custom',
                    name = 'A Custom',
                    sourceType = 'custom',
                    updatedAt = 10,
                    isExample = true,
                },
            },
            raceInstanceIdsByName = {},
            instanceListRevision = 0,
            reliabilityCounters = {
                emptyInstanceAutoDestroyed = 0,
            },
            config = {},
        },
        Logging = {
            hasAdminAccess = function(source) return tonumber(source) == 99 end,
            isLifecycleTransitionAllowed = function() return true end,
            logLifecycleEvent = function(_, _, _, _, _, _, reason) lifecycleReason = reason end,
            clearRaceStateBagByInstanceId = function() end,
            logVerbose = function() end,
            buildEntrantId = function(source) return ('entrant-%s'):format(tostring(source)) end,
        },
        Catalog = {},
        Instances = {},
        Parsing = {},
        Repository = {},
    },
}

dofile('racingsystem/shared/shared.lua')
dofile('racingsystem/server/race_catalog.lua')
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

-- A running race with one entrant still has a last-place progress source.
local singleEntrantInstance = activeInstance(9, RacingSystem.States.running, 1)
local singleLastPlace = Snapshot.getLastPlaceEntrant(singleEntrantInstance)
expect('server one-entrant last place exists', singleLastPlace ~= nil)
expectEqual('server one-entrant last place source', singleLastPlace and singleLastPlace.source, 1)

-- Empty-instance cleanup is idempotent even if a stale caller retries it.
local emptyInstance = {
    id = 77,
    name = 'Empty Race',
    state = RacingSystem.States.idle,
    entrants = {},
}
RacingSystem.Server.State.raceInstancesById = { [77] = emptyInstance }
RacingSystem.Server.State.raceInstanceIdsByName['empty race'] = 77
RacingSystem.Server.State.reliabilityCounters.emptyInstanceAutoDestroyed = 0
local firstCleanup = Snapshot.cleanupInstanceAfterEntrantRemoval(emptyInstance, 11, nil, 'test_cleanup')
local secondCleanup = Snapshot.cleanupInstanceAfterEntrantRemoval(emptyInstance, 11, nil, 'test_cleanup_retry')
expectEqual('server first empty cleanup succeeds', firstCleanup, true)
expectEqual('server repeated empty cleanup ignored', secondCleanup, false)
expect('server empty cleanup removes instance', RacingSystem.Server.State.raceInstancesById[77] == nil)
expectEqual('server empty cleanup counter once', RacingSystem.Server.State.reliabilityCounters.emptyInstanceAutoDestroyed, 1)

-- Disconnect cleanup immediately republishes standings for remaining entrants.
local playerStates = {}
Player = function(source)
    local numericSource = tonumber(source) or 0
    playerStates[numericSource] = playerStates[numericSource] or {}
    return { state = playerStates[numericSource] }
end
local disconnectInstance = activeInstance(78, RacingSystem.States.running, 2)
RacingSystem.Server.State.raceInstancesById = { [78] = disconnectInstance }
local removedDisconnected = Snapshot.removeEntrantFromAllRaceInstances(2, 'test_disconnect')
expectEqual('server disconnect removes entrant', removedDisconnected, true)
expectEqual('server disconnect leaves one entrant', #disconnectInstance.entrants, 1)
expectEqual('server disconnect republishes remaining position', playerStates[1]['rs:position'], 1)
expect('server disconnect retains nonempty instance', RacingSystem.Server.State.raceInstancesById[78] == disconnectInstance)

-- A race transfer republishes the old instance before the caller publishes the new one.
GetPlayerName = function(source) return ('Driver %s'):format(tostring(source)) end
dofile('racingsystem/server/race_instances.lua')
local oldInstance = activeInstance(79, RacingSystem.States.idle, 2)
local targetInstance = activeInstance(80, RacingSystem.States.idle, 1)
targetInstance.entrants[1].source = 3
targetInstance.entrants[1].entrantId = 'entrant-3'
RacingSystem.Server.State.raceInstancesById = {
    [79] = oldInstance,
    [80] = targetInstance,
}
playerStates[1] = {}
local productionBroadcastStandings = Snapshot.broadcastInstanceStandings
local transferStandingsInstanceId = nil
Snapshot.broadcastInstanceStandings = function(instance)
    transferStandingsInstanceId = tonumber(instance and instance.id)
    return productionBroadcastStandings(instance)
end
local transferredInstance, transferError = RacingSystem.Server.Instances.joinResolvedInstance(2, targetInstance)
Snapshot.broadcastInstanceStandings = productionBroadcastStandings
expect('server race transfer succeeds', transferredInstance == targetInstance, tostring(transferError))
expectEqual('server race transfer removes old entrant', #oldInstance.entrants, 1)
expectEqual('server race transfer adds target entrant', #targetInstance.entrants, 2)
expectEqual('server race transfer republishes old standings', transferStandingsInstanceId, 79)
expectEqual('server race transfer updates old position', playerStates[1]['rs:position'], 1)

-- A host disconnect terminates owned instances instead of leaving an orphaned owner.
local hostOwnedInstance = activeInstance(81, RacingSystem.States.idle, 2)
hostOwnedInstance.owner = 2
RacingSystem.Server.State.raceInstancesById = { [81] = hostOwnedInstance }
lifecycleReason = nil
local hostDropChanged, hostDropTerminated = RacingSystem.Server.Instances.removeSourceFromRaceInstances(2)
expectEqual('server host disconnect reports mutation', hostDropChanged, true)
expectEqual('server host disconnect returns terminated instance', #hostDropTerminated, 1)
expect('server host disconnect removes owned instance', RacingSystem.Server.State.raceInstancesById[81] == nil)
expectEqual('server host disconnect lifecycle reason', lifecycleReason, 'owner_disconnected')

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

-- Catalog payload is bounded, canonically sorted, and target-specific.
local definitionsPayload = Snapshot.buildDefinitionsPayload(12)
expectKeys('server catalog envelope', definitionsPayload, {
    'definitions',
    'count',
    'definitionCount',
    'customRaceCount',
    'onlineRaceCount',
    'viewer',
})
expectEqual('server catalog definition count', definitionsPayload.definitionCount, 2)
expectEqual('server catalog custom count', definitionsPayload.customRaceCount, 1)
expectEqual('server catalog online count', definitionsPayload.onlineRaceCount, 1)
expectEqual('server catalog custom sorted first', definitionsPayload.definitions[1].name, 'A Custom')
expectKeys('server catalog definition contract', definitionsPayload.definitions[1], {
    'lookupName',
    'name',
    'sourceType',
    'updatedAt',
    'isExample',
})
expect('server catalog excludes checkpoints', definitionsPayload.definitions[1].checkpoints == nil)
expect('server catalog excludes props', definitionsPayload.definitions[1].props == nil)
expectEqual('server catalog viewer source', definitionsPayload.viewer.source, 12)
expectEqual('server catalog viewer non-admin', definitionsPayload.viewer.isAdmin, false)
expectEqual('server catalog viewer cannot delete', definitionsPayload.viewer.canDeleteRaceDefinitions, false)
expectEqual('server catalog owner kill disabled by config', definitionsPayload.viewer.canKillOwnedInstances, false)
RacingSystem.Config.raceOwnerCanKillOwnedRace = true
expectEqual('server catalog owner kill enabled by config', Snapshot.buildDefinitionsPayload(12).viewer.canKillOwnedInstances, true)
RacingSystem.Config.raceOwnerCanKillOwnedRace = false

clientEvents = {}
Snapshot.sendDefinitions(99)
expectEqual('server targeted catalog count', #clientEvents, 1)
expectEqual('server targeted catalog event', clientEvents[1].name, 'racingsystem:catalog:definitions')
expectEqual('server targeted catalog target', clientEvents[1].target, 99)
expectEqual('server targeted catalog admin', clientEvents[1].payload.viewer.isAdmin, true)
expectEqual('server targeted catalog can delete', clientEvents[1].payload.viewer.canDeleteRaceDefinitions, true)

GetPlayers = function() return { '12', '99' } end
clientEvents = {}
Snapshot.broadcastDefinitions()
expectEqual('server catalog broadcast count', #clientEvents, 2)
expectEqual('server catalog broadcast first target', clientEvents[1].target, 12)
expectEqual('server catalog broadcast second target', clientEvents[2].target, 99)
expectEqual('server catalog broadcast first permissions', clientEvents[1].payload.viewer.isAdmin, false)
expectEqual('server catalog broadcast second permissions', clientEvents[2].payload.viewer.isAdmin, true)

-- Initial state sends both bounded views without advancing list revision.
clientEvents = {}
Snapshot.sendInitialState(22)
expectEqual('server initial event count', #clientEvents, 2)
expectEqual('server initial definitions event', clientEvents[1].name, 'racingsystem:catalog:definitions')
expectEqual('server initial definitions target', clientEvents[1].target, 22)
expectEqual('server initial list event', clientEvents[2].name, 'racingsystem:instance:list')
expectEqual('server initial list target', clientEvents[2].target, 22)
expectEqual('server initial revision', clientEvents[2].payload.revision, 8)
expectEqual('server initial revision unchanged', RacingSystem.Server.State.instanceListRevision, 8)

clientEvents = {}
Snapshot.sendInitialState(22)
Snapshot.sendInitialState(22)
expectEqual('server repeated initial sends event count', #clientEvents, 4)
expectEqual('server repeated initial sends revision unchanged', RacingSystem.Server.State.instanceListRevision, 8)

-- Joined-racer details and assets are targeted, bounded deliveries.
local joinedInstance = activeInstance(1, RacingSystem.States.idle, 1)
clientEvents = {}
Snapshot.sendRaceInfoToTarget(12, joinedInstance)
expectEqual('server race info event count', #clientEvents, 1)
expectEqual('server race info event name', clientEvents[1].name, 'racingsystem:race:getRaceInfo')
expectEqual('server race info target', clientEvents[1].target, 12)
expectEqual('server race info instance', clientEvents[1].payload.id, 1)
expectEqual('server race info checkpoints', #clientEvents[1].payload.checkpoints, 1)
expectEqual('server race info entrants', #clientEvents[1].payload.entrants, 1)
expect('server race info excludes props', clientEvents[1].payload.props == nil)
expect('server race info excludes model hides', clientEvents[1].payload.modelHides == nil)

clientEvents = {}
Snapshot.sendInstanceAssets(12, joinedInstance)
expectEqual('server assets event count', #clientEvents, 1)
expectEqual('server assets event name', clientEvents[1].name, 'racingsystem:race:instanceAssets')
expectEqual('server assets target', clientEvents[1].target, 12)
expectEqual('server assets instance', clientEvents[1].payload.instanceId, 1)
expectEqual('server assets props', #clientEvents[1].payload.props, 1)
expectEqual('server assets model hides', #clientEvents[1].payload.modelHides, 1)
expect('server assets excludes checkpoints', clientEvents[1].payload.checkpoints == nil)
expect('server assets excludes entrants', clientEvents[1].payload.entrants == nil)

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
receiveList({ revision = 4, instances = {} })
expectEqual('client kill/cleanup replacement clears list', #RacingSystem.Client.getInstanceList(), 0)

-- Load the real client catalog cache module with the same event mocks.
netHandlers = {}
localEvents = {}
RacingSystem = { Client = {} }
dofile('racingsystem/client/catalog.lua')
local receiveDefinitions = netHandlers['racingsystem:catalog:definitions']
expect('client catalog handler registered', type(receiveDefinitions) == 'function')
expectEqual('client catalog starts empty', #RacingSystem.Client.getRaceDefinitions(), 0)
expect('client catalog viewer starts nil', RacingSystem.Client.getCatalogViewer() == nil)

receiveDefinitions(nil)
receiveDefinitions({ definitions = {} })
expectEqual('client invalid catalog stays empty', #RacingSystem.Client.getRaceDefinitions(), 0)
expectEqual('client invalid catalog no update event', #localEvents, 0)

local catalogDefinitions = {
    {
        lookupName = 'a custom',
        name = 'A Custom',
        sourceType = 'custom',
        updatedAt = 10,
        isExample = true,
    },
    {
        lookupName = 'z online',
        name = 'Z Online',
        sourceType = 'online',
        raceId = 'online-id',
        updatedAt = 20,
        isExample = false,
    },
}
local catalogViewer = {
    source = 99,
    isAdmin = true,
    canDeleteRaceDefinitions = true,
    canKillOwnedInstances = true,
}
receiveDefinitions({ definitions = catalogDefinitions, viewer = catalogViewer })
local cachedDefinitions = RacingSystem.Client.getRaceDefinitions()
local cachedViewer = RacingSystem.Client.getCatalogViewer()
expectEqual('client catalog valid count', #cachedDefinitions, 2)
expectEqual('client catalog online id', cachedDefinitions[2].raceId, 'online-id')
expectKeys('client catalog definition contract', cachedDefinitions[2], {
    'lookupName',
    'name',
    'sourceType',
    'raceId',
    'updatedAt',
    'isExample',
})
expectEqual('client catalog viewer source', cachedViewer.source, 99)
expectEqual('client catalog viewer permission', cachedViewer.canDeleteRaceDefinitions, true)
expectEqual('client catalog update event count', #localEvents, 1)
expectEqual('client catalog update event name', localEvents[1].name, 'racingsystem:catalog:definitionsUpdated')

cachedDefinitions[1].name = 'mutated'
cachedDefinitions[2] = nil
cachedViewer.canDeleteRaceDefinitions = false
expectEqual('client catalog getter protects summary', RacingSystem.Client.getRaceDefinitions()[1].name, 'A Custom')
expectEqual('client catalog getter protects list', #RacingSystem.Client.getRaceDefinitions(), 2)
expectEqual('client catalog getter protects viewer', RacingSystem.Client.getCatalogViewer().canDeleteRaceDefinitions, true)

receiveDefinitions({
    definitions = { catalogDefinitions[2] },
    viewer = {
        source = 12,
        isAdmin = false,
        canDeleteRaceDefinitions = false,
        canKillOwnedInstances = true,
    },
})
expectEqual('client catalog complete replacement count', #RacingSystem.Client.getRaceDefinitions(), 1)
expectEqual('client catalog complete replacement identity', RacingSystem.Client.getRaceDefinitions()[1].lookupName, 'z online')
expectEqual('client catalog replacement viewer', RacingSystem.Client.getCatalogViewer().source, 12)
expectEqual('client catalog replacement update event', #localEvents, 2)

local total = passed + failed
io.write(('\n%d / %d assertions passed'):format(passed, total))
if failed > 0 then
    io.write((', %d FAILED\n'):format(failed))
    os.exit(1)
end
io.write(' — ALL PASSED\n')
