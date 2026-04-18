-- Adjusts tire lateral grip at runtime based on the surfaces under the front wheels.
PerformanceTuning = PerformanceTuning or {}
PerformanceTuning.SurfaceGrip = PerformanceTuning.SurfaceGrip or {}
local function isFiniteNumber(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

function PerformanceTuning.SurfaceGrip.getMaterialTyreGripByIndex(materialIndex)
    local numericIndex = tonumber(materialIndex)
    if numericIndex == nil or type(MaterialTyreGripByIndex) ~= 'table' then
        return nil
    end

    return MaterialTyreGripByIndex[numericIndex]
end

function PerformanceTuning.SurfaceGrip.getLiveSurfaceLateralBucket(vehicle, createIfMissing)
    local vehicleManager = PerformanceTuning.VehicleManager or {}
    local handlingManager = PerformanceTuning.HandlingManager or {}
    local runtimeState = PerformanceTuning.RuntimeState or {}
    local handlingFields = (PerformanceTuning.Definitions or {}).handlingFields or {}
    local tireFields = handlingFields.tires or {}
    local key = vehicleManager.getVehicleCacheKey and vehicleManager.getVehicleCacheKey(vehicle) or nil
    if not key then
        return nil
    end

    local bucket = runtimeState.liveSurfaceLateralByVehicle[key]
    if not bucket and createIfMissing then
        bucket = {
            originalLateral = handlingManager.readHandlingValue(vehicle, 'float', tireFields.lateral)
        }
        runtimeState.liveSurfaceLateralByVehicle[key] = bucket
    end

    return bucket
end

function PerformanceTuning.SurfaceGrip.restoreLiveSurfaceLateral(vehicle)
    local vehicleManager = PerformanceTuning.VehicleManager or {}
    local handlingManager = PerformanceTuning.HandlingManager or {}
    local runtimeState = PerformanceTuning.RuntimeState or {}
    local handlingFields = (PerformanceTuning.Definitions or {}).handlingFields or {}
    local tireFields = handlingFields.tires or {}
    local key = vehicleManager.getVehicleCacheKey and vehicleManager.getVehicleCacheKey(vehicle) or nil
    if not key then
        return
    end

    local bucket = runtimeState.liveSurfaceLateralByVehicle[key]
    if not bucket or not isFiniteNumber(bucket.originalLateral) or not DoesEntityExist(vehicle) then
        return
    end

    handlingManager.writeHandlingValue(vehicle, 'float', tireFields.lateral, bucket.originalLateral)
end

function PerformanceTuning.SurfaceGrip.getAverageFrontWheelTyreGrip(vehicle)
    local leftFrontGrip = PerformanceTuning.SurfaceGrip.getMaterialTyreGripByIndex(GetVehicleWheelSurfaceMaterial(vehicle, 0))
    local rightFrontGrip = PerformanceTuning.SurfaceGrip.getMaterialTyreGripByIndex(GetVehicleWheelSurfaceMaterial(vehicle, 1))
    local totalGrip = 0.0
    local gripCount = 0

    if isFiniteNumber(leftFrontGrip) then
        totalGrip = totalGrip + leftFrontGrip
        gripCount = gripCount + 1
    end

    if isFiniteNumber(rightFrontGrip) then
        totalGrip = totalGrip + rightFrontGrip
        gripCount = gripCount + 1
    end

    if gripCount == 0 then
        return nil
    end

    return totalGrip / gripCount
end

function PerformanceTuning.SurfaceGrip.updateLiveSurfaceLateral(vehicle)
    local handlingManager = PerformanceTuning.HandlingManager or {}
    local handlingFields = (PerformanceTuning.Definitions or {}).handlingFields or {}
    local tireFields = handlingFields.tires or {}
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil
    end

    local bucket = PerformanceTuning.SurfaceGrip.getLiveSurfaceLateralBucket(vehicle, true)
    if not bucket or not isFiniteNumber(bucket.originalLateral) then
        return nil
    end

    local tyreGrip = PerformanceTuning.SurfaceGrip.getAverageFrontWheelTyreGrip(vehicle)
    if not isFiniteNumber(tyreGrip) then
        return nil
    end

    local tractionLossMult = handlingManager.readHandlingValue(vehicle, 'float', tireFields.tractionLoss)
    if not isFiniteNumber(tractionLossMult) then
        return nil
    end

    local updatedLateral = bucket.originalLateral + (((1.0 - tyreGrip) * (1 + tractionLossMult)) * 10.0)
    if not isFiniteNumber(updatedLateral) then
        return nil
    end

    handlingManager.writeHandlingValue(vehicle, 'float', tireFields.lateral, updatedLateral)
    ModifyVehicleTopSpeed(vehicle, 0.0)
    bucket.lastAppliedLateral = updatedLateral
    return tyreGrip, updatedLateral
end

CreateThread(function()
    local vehicleManager = PerformanceTuning.VehicleManager or {}
    local lastVehicleKey

    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        local currentVehicleKey = vehicleManager.getVehicleCacheKey and vehicleManager.getVehicleCacheKey(vehicle) or nil

        if lastVehicleKey and lastVehicleKey ~= currentVehicleKey then
            local lastId = tonumber(lastVehicleKey:match(':(%d+)$'))
            if lastId then
                if lastVehicleKey:sub(1, 4) == 'net:' then
                    local entity = NetworkGetEntityFromNetworkId(lastId)
                    if entity ~= 0 and DoesEntityExist(entity) then
                        PerformanceTuning.SurfaceGrip.restoreLiveSurfaceLateral(entity)
                    end
                elseif DoesEntityExist(lastId) then
                    PerformanceTuning.SurfaceGrip.restoreLiveSurfaceLateral(lastId)
                end
            end
        end

        if vehicle ~= 0 and DoesEntityExist(vehicle) then
            PerformanceTuning.SurfaceGrip.updateLiveSurfaceLateral(vehicle)
        end

        lastVehicleKey = currentVehicleKey
        Wait(500)
    end
end)

