-- Dynamically updates fTractionCurveLateral based on front-wheel surface grip.
PerformanceTuning = PerformanceTuning or {}

local function showSubtitle(text, durationMs)
    BeginTextCommandPrint('STRING')
    AddTextComponentSubstringPlayerName(tostring(text or ''))
    EndTextCommandPrint(math.max(0, math.floor(tonumber(durationMs) or 1000)), true)
end

local function getLiveSurfaceLateralBucket(vehicle, createIfMissing)
    local key = PerformanceTuning.VehicleManager.getVehicleCacheKey(vehicle)
    if not key then
        return nil
    end

    local buckets = PerformanceTuning.RuntimeState.liveSurfaceLateralByVehicle
    local bucket = buckets[key]
    if not bucket and createIfMissing then
        bucket = {
            originalLateral = PerformanceTuning.HandlingManager.readHandlingValue(
                vehicle,
                'float',
                PerformanceTuning.Definitions.handlingFields.tires.lateral
            )
        }
        buckets[key] = bucket
    end

    return bucket
end

local function restoreLiveSurfaceLateral(vehicle)
    local key = PerformanceTuning.VehicleManager.getVehicleCacheKey(vehicle)
    if not key then
        return
    end

    local bucket = PerformanceTuning.RuntimeState.liveSurfaceLateralByVehicle[key]
    if not bucket or bucket.originalLateral == nil or not DoesEntityExist(vehicle) then
        return
    end

    PerformanceTuning.HandlingManager.writeHandlingValue(
        vehicle,
        'float',
        PerformanceTuning.Definitions.handlingFields.tires.lateral,
        bucket.originalLateral
    )
end

local function restoreAllLiveSurfaceLateral()
    local runtimeState = PerformanceTuning.RuntimeState or {}
    local buckets = runtimeState.liveSurfaceLateralByVehicle or {}
    local vehicleManager = PerformanceTuning.VehicleManager or {}

    for key in pairs(buckets) do
        local entity = vehicleManager.resolveTrackedVehicleEntity and vehicleManager.resolveTrackedVehicleEntity(key) or 0
        if entity ~= 0 and DoesEntityExist(entity) then
            restoreLiveSurfaceLateral(entity)
        end
    end

    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        restoreLiveSurfaceLateral(vehicle)
    end
end

local function getAverageFrontWheelTyreGrip(vehicle)
    local leftFrontGrip = PerformanceTuning.SurfaceGrip.getMaterialTyreGripByIndex(GetVehicleWheelSurfaceMaterial(vehicle, 0))
    local rightFrontGrip = PerformanceTuning.SurfaceGrip.getMaterialTyreGripByIndex(GetVehicleWheelSurfaceMaterial(vehicle, 1))

    if leftFrontGrip ~= nil and rightFrontGrip ~= nil then
        return (leftFrontGrip + rightFrontGrip) * 0.5
    end

    return nil
end

local function updateLiveSurfaceLateral(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil
    end

    local bucket = getLiveSurfaceLateralBucket(vehicle, true)
    if not bucket or bucket.originalLateral == nil then
        return nil
    end

    local tyreGrip = getAverageFrontWheelTyreGrip(vehicle)
    if tyreGrip == nil then
        return nil
    end

    local tractionLossMult = PerformanceTuning.HandlingManager.readHandlingValue(
        vehicle,
        'float',
        PerformanceTuning.Definitions.handlingFields.tires.tractionLoss
    )
    if tractionLossMult == nil then
        return nil
    end

    local updatedLateral = bucket.originalLateral + (((1.0 - tyreGrip) * (1 + tractionLossMult)) * 10.0)

    PerformanceTuning.HandlingManager.writeHandlingValue(
        vehicle,
        'float',
        PerformanceTuning.Definitions.handlingFields.tires.lateral,
        updatedLateral
    )
    if bucket.lastAppliedLateral ~= updatedLateral then
        ModifyVehicleTopSpeed(vehicle, 0.01)
    end
    bucket.lastAppliedLateral = updatedLateral
    return tyreGrip, updatedLateral
end

CreateThread(function()
    local vehicleManager = PerformanceTuning.VehicleManager
    local lastVehicleKey

    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        local currentVehicleKey = vehicleManager.getVehicleCacheKey(vehicle)

        if lastVehicleKey and lastVehicleKey ~= currentVehicleKey then
            local entity = vehicleManager.resolveTrackedVehicleEntity(lastVehicleKey)
            if entity ~= 0 and DoesEntityExist(entity) then
                restoreLiveSurfaceLateral(entity)
            end
        end

        if vehicle ~= 0 and DoesEntityExist(vehicle) then
            updateLiveSurfaceLateral(vehicle)
        end

        lastVehicleKey = currentVehicleKey
        Wait(500)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    restoreAllLiveSurfaceLateral()
end)
