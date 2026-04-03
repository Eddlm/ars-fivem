-- Retries vehicle tune resyncs and reapplies tracked tune states on the client.
PerformanceTuning = PerformanceTuning or {}
PerformanceTuning.SyncOrchestrator = PerformanceTuning.SyncOrchestrator or {}

local SyncOrchestrator = PerformanceTuning.SyncOrchestrator
local registeredTuneStateBagHandler = false
local pendingImmediateApplyByNetId = {}

local function isPlayersCurrentVehicle(vehicle)
    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return false
    end

    return GetVehiclePedIsIn(ped, false) == vehicle
end

local function wasTuneStateRecentlyAuthoredLocally(netId)
    local runtimeState = PerformanceTuning.RuntimeState or {}
    local numericNetId = math.floor(tonumber(netId) or 0)
    if numericNetId <= 0 then
        return false
    end

    local authoredUntilByNetId = runtimeState.localTuneAuthoredUntilByNetId or {}
    local authoredUntil = tonumber(authoredUntilByNetId[numericNetId]) or 0
    if authoredUntil <= 0 then
        return false
    end

    if authoredUntil <= GetGameTimer() then
        authoredUntilByNetId[numericNetId] = nil
        return false
    end

    return true
end

local function applyTuneStateIfNeeded(vehicle, state)
    local vehicleManager = PerformanceTuning.VehicleManager or {}
    local tuningPackManager = PerformanceTuning.TuningPackManager or {}
    if type(state) ~= 'table' then
        return false
    end

    if not vehicleManager.isVehicleEntityValid(vehicle) or not IsEntityAVehicle(vehicle) then
        return false
    end

    if vehicleManager.tuneStatesEqual(vehicleManager.getLastAppliedTuneState(vehicle), state) then
        return false
    end

    tuningPackManager.applySynchronizedTuneState(vehicle, state, {
        skipLog = true,
    })
    return true
end

function SyncOrchestrator.queueImmediateVehicleApply(netId)
    local numericNetId = math.floor(tonumber(netId) or 0)
    if numericNetId <= 0 or pendingImmediateApplyByNetId[numericNetId] then
        return
    end

    pendingImmediateApplyByNetId[numericNetId] = true
    CreateThread(function()
        Wait(0)
        pendingImmediateApplyByNetId[numericNetId] = nil

        if not NetworkDoesEntityExistWithNetworkId(numericNetId) then
            return
        end

        local vehicleManager = PerformanceTuning.VehicleManager or {}
        local stateBagKeys = (PerformanceTuning._internals or {}).StateBagKeys or {}
        local vehicle = NetworkGetEntityFromNetworkId(numericNetId)
        if not vehicleManager.isVehicleEntityValid(vehicle) or not IsEntityAVehicle(vehicle) then
            return
        end

        if vehicleManager.trackVehicle then
            vehicleManager.trackVehicle(vehicle)
        end

        applyTuneStateIfNeeded(vehicle, Entity(vehicle).state[stateBagKeys.tune])
    end)
end

function SyncOrchestrator.isTrackedVehicleKeyValid(key)
    local vehicleManager = PerformanceTuning.VehicleManager or {}
    local entity = vehicleManager.resolveTrackedVehicleEntity and vehicleManager.resolveTrackedVehicleEntity(key) or 0
    return entity ~= 0 and DoesEntityExist(entity), entity
end

function SyncOrchestrator.cleanupTrackedVehicleCaches(key)
    local runtimeState = PerformanceTuning.RuntimeState or {}
    runtimeState.originalHandlingByVehicle[key] = nil
    runtimeState.tuningStateByVehicle[key] = nil
    runtimeState.lastAppliedTuneStateByVehicle[key] = nil
    runtimeState.liveSurfaceLateralByVehicle[key] = nil
    if PerformanceTuning.VehicleManager and PerformanceTuning.VehicleManager.untrackVehicleByKey then
        PerformanceTuning.VehicleManager.untrackVehicleByKey(key)
    end
end

function SyncOrchestrator.getNextTrackedVehicleKey()
    local runtimeState = PerformanceTuning.RuntimeState or {}
    local trackedKeys = runtimeState.trackedVehicleKeys or {}
    local trackedCount = #trackedKeys
    if trackedCount == 0 then
        runtimeState.trackedVehicleIndex = 0
        return nil
    end

    local nextIndex = (tonumber(runtimeState.trackedVehicleIndex) or 0) + 1
    if nextIndex > trackedCount then
        nextIndex = 1
    end

    runtimeState.trackedVehicleIndex = nextIndex
    return trackedKeys[nextIndex]
end

function SyncOrchestrator.queuePendingVehicleResync(netId)
    local runtimeState = PerformanceTuning.RuntimeState or {}
    local numericNetId = math.floor(tonumber(netId) or 0)
    if numericNetId <= 0 or runtimeState.pendingVehicleResyncByNetId[numericNetId] then
        return
    end

    runtimeState.pendingVehicleResyncByNetId[numericNetId] = true
    local pendingNetIds = runtimeState.pendingVehicleResyncNetIds
    pendingNetIds[#pendingNetIds + 1] = numericNetId
end

function SyncOrchestrator.clearPendingVehicleResync(netId)
    local runtimeState = PerformanceTuning.RuntimeState or {}
    local numericNetId = math.floor(tonumber(netId) or 0)
    if numericNetId <= 0 or not runtimeState.pendingVehicleResyncByNetId[numericNetId] then
        return
    end

    runtimeState.pendingVehicleResyncByNetId[numericNetId] = nil

    local pendingNetIds = runtimeState.pendingVehicleResyncNetIds
    for index = #pendingNetIds, 1, -1 do
        if pendingNetIds[index] == numericNetId then
            table.remove(pendingNetIds, index)
            break
        end
    end

    if (tonumber(runtimeState.pendingVehicleResyncIndex) or 0) > #pendingNetIds then
        runtimeState.pendingVehicleResyncIndex = #pendingNetIds
    end
end

function SyncOrchestrator.getNextPendingVehicleResyncNetId()
    local runtimeState = PerformanceTuning.RuntimeState or {}
    local pendingNetIds = runtimeState.pendingVehicleResyncNetIds or {}
    local pendingCount = #pendingNetIds
    if pendingCount == 0 then
        runtimeState.pendingVehicleResyncIndex = 0
        return nil
    end

    local nextIndex = (tonumber(runtimeState.pendingVehicleResyncIndex) or 0) + 1
    if nextIndex > pendingCount then
        nextIndex = 1
    end

    runtimeState.pendingVehicleResyncIndex = nextIndex
    return pendingNetIds[nextIndex]
end

function SyncOrchestrator.movePendingVehicleResyncToBack(netId)
    local runtimeState = PerformanceTuning.RuntimeState or {}
    local numericNetId = math.floor(tonumber(netId) or 0)
    if numericNetId <= 0 then
        return
    end

    local pendingNetIds = runtimeState.pendingVehicleResyncNetIds or {}
    for index = 1, #pendingNetIds do
        if pendingNetIds[index] == numericNetId then
            table.remove(pendingNetIds, index)
            pendingNetIds[#pendingNetIds + 1] = numericNetId
            if (tonumber(runtimeState.pendingVehicleResyncIndex) or 0) >= index then
                runtimeState.pendingVehicleResyncIndex = math.max(0, (tonumber(runtimeState.pendingVehicleResyncIndex) or 0) - 1)
            end
            return
        end
    end
end

function SyncOrchestrator.getDiagnostics()
    local runtimeState = PerformanceTuning.RuntimeState or {}
    local trackedKeys = runtimeState.trackedVehicleKeys or {}
    local pendingNetIds = runtimeState.pendingVehicleResyncNetIds or {}
    return {
        trackedVehicleCount = #trackedKeys,
        pendingResyncCount = #pendingNetIds,
    }
end

function SyncOrchestrator.tryResyncVehicleByNetId(netId)
    local stateBagKeys = (PerformanceTuning._internals or {}).StateBagKeys or {}
    local vehicleManager = PerformanceTuning.VehicleManager or {}
    local numericNetId = math.floor(tonumber(netId) or 0)
    if numericNetId <= 0 or not NetworkDoesEntityExistWithNetworkId(numericNetId) then
        return false
    end

    local vehicle = NetworkGetEntityFromNetworkId(numericNetId)
    if not vehicleManager.isVehicleEntityValid(vehicle) or not IsEntityAVehicle(vehicle) then
        return false
    end

    if vehicleManager.trackVehicle then
        vehicleManager.trackVehicle(vehicle)
    end

    local state = Entity(vehicle).state[stateBagKeys.tune]
    if type(state) ~= 'table' then
        return false
    end

    applyTuneStateIfNeeded(vehicle, state)

    return true
end

function SyncOrchestrator.ensureTuneStateBagHandlerRegistered()
    if registeredTuneStateBagHandler then
        return true
    end

    local stateBagKeys = (PerformanceTuning._internals or {}).StateBagKeys or {}
    local tuneKey = stateBagKeys.tune
    if type(tuneKey) ~= 'string' or tuneKey == '' then
        return false
    end

    AddStateBagChangeHandler(tuneKey, nil, function(bagName, _, value)
        local vehicleManager = PerformanceTuning.VehicleManager or {}
        if type(value) ~= 'table' then
            return
        end

        local entity = GetEntityFromStateBagName(bagName)
        if not vehicleManager.isVehicleEntityValid(entity) or not IsEntityAVehicle(entity) then
            return
        end

        if vehicleManager.tuneStatesEqual(vehicleManager.getLastAppliedTuneState(entity), value) then
            return
        end

        local netId = NetworkGetNetworkIdFromEntity(entity)
        if netId and netId ~= 0 then
            if isPlayersCurrentVehicle(entity) then
                if wasTuneStateRecentlyAuthoredLocally(netId) then
                    SyncOrchestrator.clearPendingVehicleResync(netId)
                    return
                end

                applyTuneStateIfNeeded(entity, value)
                return
            end

            -- Defer to the next frame to avoid re-entering statebag reads/writes in the callback,
            -- but still apply fast enough to feel immediate.
            SyncOrchestrator.queueImmediateVehicleApply(netId)
            SyncOrchestrator.queuePendingVehicleResync(netId)
        end
    end)

    registeredTuneStateBagHandler = true
    return true
end

RegisterNetEvent('performancetuning:requestVehicleResync', function(netId)
    local numericNetId = math.floor(tonumber(netId) or 0)
    if numericNetId > 0 and NetworkDoesEntityExistWithNetworkId(numericNetId) then
        local vehicle = NetworkGetEntityFromNetworkId(numericNetId)
        if isPlayersCurrentVehicle(vehicle) then
            if wasTuneStateRecentlyAuthoredLocally(numericNetId) then
                SyncOrchestrator.clearPendingVehicleResync(numericNetId)
                return
            end

            SyncOrchestrator.tryResyncVehicleByNetId(numericNetId)
            SyncOrchestrator.clearPendingVehicleResync(numericNetId)
            return
        end
    end

    if not SyncOrchestrator.tryResyncVehicleByNetId(netId) then
        SyncOrchestrator.queuePendingVehicleResync(netId)
    else
        SyncOrchestrator.clearPendingVehicleResync(netId)
    end
end)

CreateThread(function()
    local runtimeState = PerformanceTuning.RuntimeState or {}
    local vehicleManager = PerformanceTuning.VehicleManager or {}
    local tuningPackManager = PerformanceTuning.TuningPackManager or {}
    while true do
        Wait(250)
        SyncOrchestrator.ensureTuneStateBagHandlerRegistered()

        local pendingNetId = SyncOrchestrator.getNextPendingVehicleResyncNetId()
        if pendingNetId then
            if SyncOrchestrator.tryResyncVehicleByNetId(pendingNetId) then
                SyncOrchestrator.clearPendingVehicleResync(pendingNetId)
            else
                SyncOrchestrator.movePendingVehicleResyncToBack(pendingNetId)
            end
        end

        local key = SyncOrchestrator.getNextTrackedVehicleKey()
        if key then
            local isValid, vehicle = SyncOrchestrator.isTrackedVehicleKeyValid(key)
            if not isValid then
                SyncOrchestrator.cleanupTrackedVehicleCaches(key)
            else
                local stateBagKeys = (PerformanceTuning._internals or {}).StateBagKeys or {}
                local state = Entity(vehicle).state[stateBagKeys.tune]
                if type(state) == 'table' and not vehicleManager.tuneStatesEqual(vehicleManager.getLastAppliedTuneState(vehicle), state) then
                    tuningPackManager.applySynchronizedTuneState(vehicle, state, {
                        skipLog = true,
                    })
                end

                if runtimeState.originalHandlingByVehicle[key] == nil
                    and runtimeState.tuningStateByVehicle[key] == nil
                    and runtimeState.lastAppliedTuneStateByVehicle[key] == nil
                    and runtimeState.liveSurfaceLateralByVehicle[key] == nil
                then
                    vehicleManager.untrackVehicleByKey(key)
                end
            end
        end
    end
end)
