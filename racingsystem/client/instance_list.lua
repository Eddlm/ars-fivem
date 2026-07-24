RacingSystem = RacingSystem or {}
RacingSystem.Client = RacingSystem.Client or {}

local instanceList = {}
local instanceListRevision = -1

local function cloneInstanceSummary(instance)
    return {
        id = instance.id,
        name = instance.name,
        sourceType = instance.sourceType,
        owner = instance.owner,
        state = instance.state,
        laps = instance.laps,
        trafficDensity = instance.trafficDensity,
        lateJoinProgressLimitPercent = instance.lateJoinProgressLimitPercent,
        entrantCount = instance.entrantCount,
    }
end

function RacingSystem.Client.getInstanceList()
    local cloned = {}
    for index, instance in ipairs(instanceList) do
        cloned[index] = cloneInstanceSummary(instance)
    end
    return cloned
end

RegisterNetEvent('racingsystem:instance:list', function(payload)
    if type(payload) ~= 'table' or type(payload.instances) ~= 'table' then
        return
    end

    local revision = tonumber(payload.revision)
    if not revision or revision < 0 or revision < instanceListRevision then
        return
    end

    instanceList = payload.instances
    instanceListRevision = revision
    TriggerEvent('racingsystem:instance:listUpdated', revision)
end)
