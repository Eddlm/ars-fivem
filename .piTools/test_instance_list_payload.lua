-- Unit test: buildInstanceListPayload filtering and sorting logic
-- Run with: lua .piTools/test_instance_list_payload.lua

local pass, fail = 0, 0
local function assert_eq(label, actual, expected)
    if actual == expected then
        pass = pass + 1
    else
        fail = fail + 1
        io.stderr:write(string.format("FAIL [%s]: expected %s, got %s\n", label, tostring(expected), tostring(actual)))
    end
end
local function assert_nil(label, actual)
    if actual == nil then
        pass = pass + 1
    else
        fail = fail + 1
        io.stderr:write(string.format("FAIL [%s]: expected nil, got %s\n", label, tostring(actual)))
    end
end
local function assert_table_len(label, tbl, expected)
    local n = type(tbl) == 'table' and #tbl or -1
    if n == expected then
        pass = pass + 1
    else
        fail = fail + 1
        io.stderr:write(string.format("FAIL [%s]: expected length %d, got %d\n", label, expected, n))
    end
end

-- Mock RacingSystem namespace
RacingSystem = {
    States = {
        idle = 'idle',
        staging = 'staging',
        running = 'running',
        finished = 'finished',
    },
    Server = {
        State = {
            raceInstancesById = {},
            instanceListRevision = 0,
        },
        Logging = {
            hasAdminAccess = function() return false end,
        },
    },
}

-- Functions under test (extracted from snapshot_runtime.lua)
local function buildViewerPayload(viewerSource)
    local numericViewerSource = tonumber(viewerSource) or -1
    local viewerIsAdmin = numericViewerSource > 0 and RacingSystem.Server.Logging.hasAdminAccess(numericViewerSource) or false
    return {
        source = numericViewerSource,
        isAdmin = viewerIsAdmin,
        canDeleteRaceDefinitions = viewerIsAdmin,
        canKillOwnedInstances = true,
    }
end

local function buildInstanceSummary(instance)
    if type(instance) ~= 'table' then
        return nil
    end
    return {
        id = tonumber(instance.id) or -1,
        name = tostring(instance.name or ''),
        sourceType = tostring(instance.sourceType or ''),
        owner = tonumber(instance.owner) or 0,
        state = tostring(instance.state or RacingSystem.States.idle),
        laps = tonumber(instance.laps) or 3,
        trafficDensity = math.max(0.0, math.min(1.0, tonumber(instance.trafficDensity) or 0.0)),
        entrantCount = #(type(instance.entrants) == 'table' and instance.entrants or {}),
    }
end

local function buildInstanceListPayload(viewerSource)
    local instances = {}
    for _, instance in pairs(RacingSystem.Server.State.raceInstancesById) do
        local state = tostring(instance.state or RacingSystem.States.idle)
        if state == RacingSystem.States.idle or state == RacingSystem.States.staging or state == RacingSystem.States.running then
            local summary = buildInstanceSummary(instance)
            if summary then
                instances[#instances + 1] = summary
            end
        end
    end
    table.sort(instances, function(a, b)
        return (a.id or 0) < (b.id or 0)
    end)
    return {
        revision = tonumber(RacingSystem.Server.State.instanceListRevision) or 0,
        instances = instances,
        instanceCount = #instances,
        viewer = buildViewerPayload(viewerSource),
    }
end

-- Helper to reset state
local function resetState()
    RacingSystem.Server.State.raceInstancesById = {}
    RacingSystem.Server.State.instanceListRevision = 0
end

-- =============================================
-- Test 1: Empty state returns empty list
-- =============================================
resetState()
local result = buildInstanceListPayload(1)
assert_table_len("empty state: instances", result.instances, 0)
assert_eq("empty state: instanceCount", result.instanceCount, 0)
assert_eq("empty state: revision", result.revision, 0)
assert_eq("empty state: viewer.source", result.viewer.source, 1)

-- =============================================
-- Test 2: Only finished instances → empty list
-- =============================================
resetState()
RacingSystem.Server.State.raceInstancesById = {
    [1] = { id = 1, name = "Finished Race", state = RacingSystem.States.finished, entrants = {} },
    [2] = { id = 2, name = "Another Finished", state = RacingSystem.States.finished, entrants = {} },
}
result = buildInstanceListPayload(1)
assert_table_len("finished only: instances", result.instances, 0)
assert_eq("finished only: instanceCount", result.instanceCount, 0)

-- =============================================
-- Test 3: Mix of states — only idle/staging/running
-- =============================================
resetState()
RacingSystem.Server.State.raceInstancesById = {
    [10] = { id = 10, name = "Idle Race", state = RacingSystem.States.idle, entrants = {} },
    [20] = { id = 20, name = "Staging Race", state = RacingSystem.States.staging, entrants = {} },
    [30] = { id = 30, name = "Running Race", state = RacingSystem.States.running, entrants = {} },
    [40] = { id = 40, name = "Finished Race", state = RacingSystem.States.finished, entrants = {} },
}
result = buildInstanceListPayload(1)
assert_table_len("mixed states: instances", result.instances, 3)
assert_eq("mixed states: instanceCount", result.instanceCount, 3)

-- Verify the three included instances
local names = {}
for _, inst in ipairs(result.instances) do
    names[#names + 1] = inst.name
end
table.sort(names)
assert_eq("mixed states: first name", names[1], "Idle Race")
assert_eq("mixed states: second name", names[2], "Running Race")
assert_eq("mixed states: third name", names[3], "Staging Race")

-- =============================================
-- Test 4: Sorted by ID ascending
-- =============================================
resetState()
RacingSystem.Server.State.raceInstancesById = {
    [100] = { id = 100, name = "Z Race", state = RacingSystem.States.idle, entrants = {} },
    [5]   = { id = 5,   name = "A Race", state = RacingSystem.States.idle, entrants = {} },
    [42]  = { id = 42,  name = "M Race", state = RacingSystem.States.idle, entrants = {} },
}
result = buildInstanceListPayload(1)
assert_table_len("sorted: instances", result.instances, 3)
assert_eq("sorted: first id", result.instances[1].id, 5)
assert_eq("sorted: second id", result.instances[2].id, 42)
assert_eq("sorted: third id", result.instances[3].id, 100)

-- =============================================
-- Test 5: Revision is included
-- =============================================
resetState()
RacingSystem.Server.State.instanceListRevision = 7
RacingSystem.Server.State.raceInstancesById = {
    [1] = { id = 1, name = "Test", state = RacingSystem.States.idle, entrants = {} },
}
result = buildInstanceListPayload(1)
assert_eq("revision: value", result.revision, 7)

-- =============================================
-- Test 6: Entrant count in summary
-- =============================================
resetState()
RacingSystem.Server.State.raceInstancesById = {
    [1] = { id = 1, name = "Full Race", state = RacingSystem.States.running, entrants = { {source=1}, {source=2}, {source=3} } },
}
result = buildInstanceListPayload(1)
assert_eq("entrantCount: value", result.instances[1].entrantCount, 3)

-- =============================================
-- Test 7: Viewer payload for anonymous source (-1)
-- =============================================
resetState()
RacingSystem.Server.State.raceInstancesById = {
    [1] = { id = 1, name = "Test", state = RacingSystem.States.idle, entrants = {} },
}
result = buildInstanceListPayload(-1)
assert_eq("viewer -1: source", result.viewer.source, -1)
assert_eq("viewer -1: isAdmin", result.viewer.isAdmin, false)

-- =============================================
-- Test 8: Instance with nil state defaults to idle
-- =============================================
resetState()
RacingSystem.Server.State.raceInstancesById = {
    [1] = { id = 1, name = "No State", state = nil, entrants = {} },
}
result = buildInstanceListPayload(1)
assert_table_len("nil state: instances", result.instances, 1)
assert_eq("nil state: state value", result.instances[1].state, RacingSystem.States.idle)

-- =============================================
-- Test 9: Instance with unknown state is excluded
-- =============================================
resetState()
RacingSystem.Server.State.raceInstancesById = {
    [1] = { id = 1, name = "Unknown", state = "cancelled", entrants = {} },
}
result = buildInstanceListPayload(1)
assert_table_len("unknown state: instances", result.instances, 0)

-- =============================================
-- Summary
-- =============================================
local total = pass + fail
io.write(string.format("\n%d / %d tests passed", pass, total))
if fail > 0 then
    io.write(string.format(", %d FAILED", fail))
    os.exit(1)
else
    io.write(" — ALL PASSED\n")
end
