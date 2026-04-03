-- Tracks tuned vehicles server-side and asks scoped clients to resync them.
local ServerState = {
    tuneStateBagKey = 'performancetuning:tuneState',
    trackedTunedVehiclesByNetId = {},
    playersInScopeByPlayer = {},
}
local STABLE_LAPTIMES_FILE = 'stable_laptimes.json'

local function isVehicleEntity(entity)
    return entity and entity ~= 0 and DoesEntityExist(entity) and GetEntityType(entity) == 2
end

local function isDistinctValidPlayerPair(playerA, playerB)
    if not playerA or playerA <= 0 then
        return false
    end

    if not playerB or playerB <= 0 then
        return false
    end

    return playerA ~= playerB
end

local function getScopedPlayers(sourceId)
    local playersInScopeByPlayer = ServerState.playersInScopeByPlayer
    playersInScopeByPlayer[sourceId] = playersInScopeByPlayer[sourceId] or {}
    return playersInScopeByPlayer[sourceId]
end

local function addPlayersToScope(playerA, playerB)
    if not isDistinctValidPlayerPair(playerA, playerB) then
        return
    end

    getScopedPlayers(playerA)[playerB] = true
    getScopedPlayers(playerB)[playerA] = true
end

local function removePlayersFromScope(playerA, playerB)
    if not isDistinctValidPlayerPair(playerA, playerB) then
        return
    end

    local scopeA = ServerState.playersInScopeByPlayer[playerA]
    if scopeA then
        scopeA[playerB] = nil
    end

    local scopeB = ServerState.playersInScopeByPlayer[playerB]
    if scopeB then
        scopeB[playerA] = nil
    end
end

local function notifyScopedPlayersToResync(sourceId, netId)
    if not sourceId or sourceId <= 0 or not netId or netId <= 0 then
        return
    end

    local scopedPlayers = ServerState.playersInScopeByPlayer[sourceId]
    if type(scopedPlayers) ~= 'table' then
        return
    end

    for observerSource in pairs(scopedPlayers) do
        if observerSource ~= sourceId then
            TriggerClientEvent('performancetuning:requestVehicleResync', observerSource, netId)
        end
    end
end

local function countTrackedVehicles()
    local count = 0
    for _ in pairs(ServerState.trackedTunedVehiclesByNetId) do
        count = count + 1
    end
    return count
end

local function countScopePairs()
    local count = 0
    for _, scopedPlayers in pairs(ServerState.playersInScopeByPlayer) do
        for _ in pairs(scopedPlayers) do
            count = count + 1
        end
    end
    return count
end

local function loadStableLapDocument()
    local resourceName = GetCurrentResourceName()
    local raw = LoadResourceFile(resourceName, STABLE_LAPTIMES_FILE)
    local document = type(raw) == 'string' and raw ~= '' and json.decode(raw) or nil
    if type(document) ~= 'table' then
        document = {
            version = 2,
            records = {}
        }
    end
    if type(document.records) ~= 'table' then
        document.records = {}
    end
    return document
end

local function saveStableLapDocument(document)
    if type(document) ~= "table" then
        return false
    end
    local encoded = json.encode(document)
    if type(encoded) ~= "string" or encoded == "" then
        return false
    end
    return SaveResourceFile(GetCurrentResourceName(), STABLE_LAPTIMES_FILE, encoded, -1) == true
end

local function getPlayerCurrentVehicle(sourceId)
    local ped = GetPlayerPed(sourceId)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return nil, nil
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if not isVehicleEntity(vehicle) then
        return nil, nil
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId == 0 then
        return nil, nil
    end

    return vehicle, netId
end

local function isTrackedTunedVehicle(vehicle, netId)
    if not isVehicleEntity(vehicle) then
        return false
    end

    if not ServerState.trackedTunedVehiclesByNetId[netId] then
        return false
    end

    local state = Entity(vehicle).state[ServerState.tuneStateBagKey]
    if type(state) == 'table' then
        return true
    end

    ServerState.trackedTunedVehiclesByNetId[netId] = nil
    return false
end

local function requestVehicleResyncForPlayer(observerSource, targetSource)
    if not isDistinctValidPlayerPair(observerSource, targetSource) then
        return
    end

    local vehicle, netId = getPlayerCurrentVehicle(targetSource)
    if not vehicle or not netId then
        return
    end

    if not isTrackedTunedVehicle(vehicle, netId) then
        return
    end

    TriggerClientEvent('performancetuning:requestVehicleResync', observerSource, netId)
end

RegisterNetEvent('performancetuning:registerTunedVehicle', function(netId)
    local sourceId = source
    local numericNetId = math.floor(tonumber(netId) or 0)
    if numericNetId <= 0 then
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(numericNetId)
    if not isVehicleEntity(vehicle) then
        return
    end

    if type(Entity(vehicle).state[ServerState.tuneStateBagKey]) == 'table' then
        ServerState.trackedTunedVehiclesByNetId[numericNetId] = true
        if sourceId and sourceId > 0 then
            notifyScopedPlayersToResync(sourceId, numericNetId)
        end
    end
end)

AddEventHandler('playerEnteredScope', function(data)
    if type(data) ~= 'table' then
        return
    end

    local playerEntered = tonumber(data.player) or 0
    local playerFor = tonumber(data['for']) or 0
    if playerEntered <= 0 or playerFor <= 0 then
        return
    end

    addPlayersToScope(playerEntered, playerFor)
    requestVehicleResyncForPlayer(playerEntered, playerFor)
    requestVehicleResyncForPlayer(playerFor, playerEntered)
end)

AddEventHandler('playerLeftScope', function(data)
    if type(data) ~= 'table' then
        return
    end

    local playerLeft = tonumber(data.player) or 0
    local playerFor = tonumber(data['for']) or 0
    if playerLeft <= 0 or playerFor <= 0 then
        return
    end

    removePlayersFromScope(playerLeft, playerFor)
end)

AddEventHandler('playerDropped', function()
    local sourceId = source
    if not sourceId or sourceId <= 0 then
        return
    end

    local playersInScopeByPlayer = ServerState.playersInScopeByPlayer
    playersInScopeByPlayer[sourceId] = nil
    for _, scopedPlayers in pairs(playersInScopeByPlayer) do
        scopedPlayers[sourceId] = nil
    end
end)

local function normalizePiSnapshot(piPayload)
    local values = type(piPayload) == 'table' and piPayload or {}
    return {
        total = math.max(0, math.floor(tonumber(values.total) or 0)),
        power = math.max(0, math.floor(tonumber(values.power) or 0)),
        speed = math.max(0, math.floor(tonumber(values.speed) or 0)),
        grip = math.max(0, math.floor(tonumber(values.grip) or 0)),
        brake = math.max(0, math.floor(tonumber(values.brake) or 0)),
    }
end

local function getModelKey(model)
    local text = tostring(model or '')
    if text == '' then
        return ''
    end

    return string.lower(text)
end

local function findExistingModelPi(document, modelKey)
    if type(document) ~= 'table' or modelKey == '' then
        return nil
    end

    local records = document.records
    if type(records) == 'table' then
        for index = 1, #records do
            local record = records[index]
            if type(record) == 'table' and getModelKey(record.model) == modelKey then
                return normalizePiSnapshot(record.pi)
            end
        end
    end

    return nil
end

-- Stores one PI snapshot per vehicle model and reports comparisons when a model already exists.
RegisterNetEvent('performancetuning:storeStableLapSample', function(payload)
    if type(payload) ~= 'table' then
        return
    end

    local sourceId = source
    local resourceName = GetCurrentResourceName()
    local fileName = STABLE_LAPTIMES_FILE
    local model = tostring(payload.model or '')
    local modelKey = getModelKey(model)
    if model == '' or modelKey == '' then
        return
    end

    local currentPi = normalizePiSnapshot(payload.pi)
    local raw = LoadResourceFile(resourceName, fileName)
    local document = type(raw) == 'string' and raw ~= '' and json.decode(raw) or nil
    if type(document) ~= 'table' then
        document = {
            version = 2,
            records = {}
        }
    end

    local existingPi = findExistingModelPi(document, modelKey)
    if existingPi then
        if sourceId and sourceId > 0 then
            TriggerClientEvent('performancetuning:stableLapStored', sourceId, {
                status = 'comparison',
                model = model,
                currentPi = currentPi,
                existingPi = existingPi,
                deltaPi = {
                    total = currentPi.total - existingPi.total,
                    power = currentPi.power - existingPi.power,
                    speed = currentPi.speed - existingPi.speed,
                    grip = currentPi.grip - existingPi.grip,
                    brake = currentPi.brake - existingPi.brake,
                },
            })
        end

        return
    end

    if type(document.records) ~= 'table' then
        document.records = {}
    end

    document.records[#document.records + 1] = {
        model = model,
        pi = currentPi,
    }

    SaveResourceFile(resourceName, fileName, json.encode(document), -1)
    if sourceId and sourceId > 0 then
        TriggerClientEvent('performancetuning:stableLapStored', sourceId, {
            status = 'saved',
            model = model,
            pi = currentPi,
        })
    end
end)

RegisterNetEvent('performancetuning:requestServerDiagnostics', function()
    local src = source
    if not src or src <= 0 then
        return
    end
    local stable = loadStableLapDocument()
    TriggerClientEvent('performancetuning:serverDiagnostics', src, {
        trackedTunedVehicles = countTrackedVehicles(),
        scopePairs = countScopePairs(),
        stableLapModelCount = #((stable and stable.records) or {}),
    })
end)

RegisterCommand('ptlaptimes', function(src, args)
    local subcommand = tostring((args or {})[1] or "help"):lower()
    local model = tostring((args or {})[2] or ""):upper()
    local document = loadStableLapDocument()

    if subcommand == "help" then
        local helpText = "Usage: /ptlaptimes [list|clear] [MODEL|all]"
        if src and src > 0 then
            TriggerClientEvent('chat:addMessage', src, { args = { '^2performancetuning', helpText } })
        else
            print(helpText)
        end
        return
    end

    if subcommand == "list" then
        local count = #document.records
        local message = ("Stable lap records: %d model(s)."):format(count)
        if src and src > 0 then
            TriggerClientEvent('chat:addMessage', src, { args = { '^2performancetuning', message } })
        else
            print(message)
        end
        return
    end

    if subcommand == "clear" then
        if model == "" then
            model = "ALL"
        end

        if model == "ALL" then
            document.records = {}
            local ok = saveStableLapDocument(document)
            local message = ok and "Cleared all stable lap records." or "Failed to clear stable lap records."
            if src and src > 0 then
                TriggerClientEvent('chat:addMessage', src, { args = { '^2performancetuning', message } })
            else
                print(message)
            end
            return
        end

        local removed = 0
        for index = #document.records, 1, -1 do
            local record = document.records[index]
            if type(record) == "table" and tostring(record.model or ""):upper() == model then
                table.remove(document.records, index)
                removed = removed + 1
            end
        end

        local ok = saveStableLapDocument(document)
        local message = ok and ("Cleared %d record(s) for %s."):format(removed, model) or ("Failed to clear records for %s."):format(model)
        if src and src > 0 then
            TriggerClientEvent('chat:addMessage', src, { args = { '^2performancetuning', message } })
        else
            print(message)
        end
        return
    end

    local unknownMessage = ("Unknown subcommand '%s'. Use /ptlaptimes help."):format(subcommand)
    if src and src > 0 then
        TriggerClientEvent('chat:addMessage', src, { args = { '^2performancetuning', unknownMessage } })
    else
        print(unknownMessage)
    end
end, false)
