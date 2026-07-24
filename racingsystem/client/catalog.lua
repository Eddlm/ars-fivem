RacingSystem = RacingSystem or {}
RacingSystem.Client = RacingSystem.Client or {}

local definitions = {}
local viewer = nil

local function cloneDefinition(definition)
    return {
        lookupName = definition.lookupName,
        name = definition.name,
        sourceType = definition.sourceType,
        raceId = definition.raceId,
        updatedAt = definition.updatedAt,
        isExample = definition.isExample,
    }
end

local function cloneViewer(value)
    if type(value) ~= 'table' then
        return nil
    end
    return {
        source = value.source,
        isAdmin = value.isAdmin,
        canDeleteRaceDefinitions = value.canDeleteRaceDefinitions,
        canKillOwnedInstances = value.canKillOwnedInstances,
    }
end

function RacingSystem.Client.getRaceDefinitions()
    local cloned = {}
    for index, definition in ipairs(definitions) do
        cloned[index] = cloneDefinition(definition)
    end
    return cloned
end

function RacingSystem.Client.getCatalogViewer()
    return cloneViewer(viewer)
end

RegisterNetEvent('racingsystem:catalog:definitions', function(payload)
    if type(payload) ~= 'table'
        or type(payload.definitions) ~= 'table'
        or type(payload.viewer) ~= 'table' then
        return
    end

    definitions = payload.definitions
    viewer = payload.viewer
    TriggerEvent('racingsystem:catalog:definitionsUpdated')
end)
