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

local function printStartupSummary()
    if not (type(Config.debug) == "table" and Config.debug.printStartupSummary == true) then
        return
    end

    print(("[customphysics] startup: nativeWheeliesDisabled=%s customWheelieEnabled=%s rolloversEnabled=%s offroadBoostEnabled=%s fallbackRevLimiterEnabled=%s"):format(
        tostring(Config.nativeWheeliesDisabled == true),
        tostring(Config.customWheelieEnabled == true),
        tostring(Config.rolloversEnabled == true),
        tostring(Config.offroadBoostEnabled == true),
        tostring(Config.fallbackRevLimiterEnabled == true)
    ))
end

-- Runtime entrypoints

-- Runs the low-rate acceleration stability sampler separately from the main per-frame power stack.
CreateThread(function()
    while true do
        local vehicle = getDriverVehicle()
        if vehicle then
            CustomPhysicsPower.sampleStability(vehicle, GetGameTimer())
        end

        Wait(100)
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

RegisterCommand((((Config.debug or {}).command) or "customphysicsdebug"), function()
    local power = (CustomPhysicsPower and CustomPhysicsPower.getDebugSnapshot and CustomPhysicsPower.getDebugSnapshot()) or {}
    local nitrous = (CustomPhysicsNitrous and CustomPhysicsNitrous.getDebugSnapshot and CustomPhysicsNitrous.getDebugSnapshot()) or {}
    print(("[customphysics] antiBoost=%.3f stabilityErr=%.3f ratio=%.3f nitrousActive=%s nitrousRemainingMs=%s fallbackRevLimiter=%s stateBagTuneKey=%s"):format(
        tonumber(power.antiBoostMultiplier) or 0.0,
        tonumber(power.stabilityError) or 0.0,
        tonumber(power.accelerationToWheelRatio) or 0.0,
        tostring(nitrous.active == true),
        tostring(math.floor(tonumber(nitrous.remainingMs) or 0)),
        tostring(Config.fallbackRevLimiterEnabled == true),
        tostring("performancetuning:tuneState")
    ))
end, false)

printStartupSummary()
