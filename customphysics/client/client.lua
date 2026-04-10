local lastVehicle = nil
local Config = (CustomPhysics or {}).Config or {}

-- Vehicle discovery helpers

-- Returns the local player's current vehicle only when they are the active driver.
local function getDriverVehicle()
    local ped = PlayerPedId()
    local vehicle = DoesEntityExist(ped) and GetVehiclePedIsIn(ped, false) or 0
    if vehicle == 0 or not DoesEntityExist(vehicle) or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return nil
    end

    return vehicle
end

-- Resets all subsystem overrides for the given vehicle context.
local function clearOverrides(vehicle)
    CustomPhysicsPower.reset(vehicle)
    CustomPhysicsWheelies.reset()
    CustomPhysicsRollovers.reset()
    CustomPhysicsNitrous.reset(vehicle)
end

-- Runtime entrypoints

-- Runs the stability sampler at 8 Hz so acceleration noise is smoothed before it feeds the power stack.
CreateThread(function()
    while true do
        local vehicle = getDriverVehicle()
        if vehicle then
            CustomPhysicsPower.sampleStability(vehicle, GetGameTimer())
        end

        Wait(CustomPhysicsPower.getStabilitySampleIntervalMs())
    end
end)

-- Runs the anti-boost recovery independently at a frame-timed cadence.
CreateThread(function()
    while true do
        local frameSeconds = CustomPhysicsUtil.getDeltaSeconds()
        local vehicle = getDriverVehicle()
        if vehicle then
            CustomPhysicsPower.updateStabilityRecovery(vehicle, frameSeconds)
        end

        Wait(math.max(0, math.floor(frameSeconds * 1000.0)))
    end
end)

-- Runs the main per-frame coordinator loop for the local player vehicle.
CreateThread(function()
    while true do
        local now = GetGameTimer()
        local vehicle = getDriverVehicle()

        if vehicle then
            if lastVehicle and lastVehicle ~= vehicle then
                clearOverrides(lastVehicle)
            end

            CustomPhysicsRollovers.update(vehicle)
            CustomPhysicsWheelies.update(vehicle)
            CustomPhysicsPower.update(vehicle, now)
            CustomPhysicsNitrous.update(vehicle, now)
            lastVehicle = vehicle
        else
            if lastVehicle then
                clearOverrides(lastVehicle)
                lastVehicle = nil
            end
        end

        Wait(0)
    end
end)

-- Clears active overrides when the resource stops to avoid leaving stale effects behind.
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    clearOverrides(lastVehicle)
end)
