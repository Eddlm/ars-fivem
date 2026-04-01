-- Handles performancetuning nitrous availability, refill, and shot dispatch.
PerformanceTuning = PerformanceTuning or {}
PerformanceTuning.Nitrous = PerformanceTuning.Nitrous or {}

local Nitrous = PerformanceTuning.Nitrous

local function getNitrousLevelMultiplier(nitrousLevel)
    local packs = (PerformanceTuning._internals or {}).NITROUS_PACKS or {}
    for _, pack in ipairs(packs) do
        if pack.id == nitrousLevel then
            return tonumber(pack.powerMultiplier) or 0.0
        end
    end

    return 0.0
end

function Nitrous.wasControlJustPressed()
    return IsControlJustPressed(0, 73) or IsControlJustPressed(1, 73) or IsControlJustPressed(2, 73)
end

function Nitrous.clearShot(vehicle)
    TriggerEvent('customphysics:nitrous:clear', vehicle)
end

local function dispatchShot(vehicle, instructions)
    TriggerEvent('customphysics:nitrous:executeShot', vehicle, instructions)
end

local function canTriggerShot(nitrousState, nitrousLevelMultiplier, now)
    return nitrousState ~= nil
        and nitrousLevelMultiplier > 0.0
        and nitrousState.nitrousActiveUntil <= now
        and (nitrousState.nitrousAvailableCharge or 0.0) > 0.0
end

function Nitrous.triggerShotIfAvailable(vehicle)
    local bindings = PerformanceTuning.ClientBindings or {}
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    if not PerformanceTuning.VehicleManager.isVehicleEntityValid(vehicle) then
        return
    end

    local nitrousState = bindings.ensureTuningState and bindings.ensureTuningState(vehicle) or nil
    local now = GetGameTimer()
    local nitrousLevelMultiplier = getNitrousLevelMultiplier(nitrousState and nitrousState.nitrousLevel)
    if not canTriggerShot(nitrousState, nitrousLevelMultiplier, now) then
        return
    end

    local sliderRange = (runtimeConfig.sliderRanges or {}).nitrousShotStrength or {}
    local nitrousShotStrength = math.max(tonumber(sliderRange.min) or 1.0, tonumber(nitrousState.nitrousShotStrength) or 1.0)
    local nitrousConfig = runtimeConfig.nitrous or {}
    local nitrousPower = nitrousLevelMultiplier * nitrousShotStrength * (tonumber(nitrousConfig.nativePowerMultiplier) or 0.0)
    local nitrousDurationMs = math.max(250, math.floor((tonumber(nitrousConfig.baseDurationMs) or 4000) / nitrousShotStrength))

    dispatchShot(vehicle, {
        power = nitrousPower,
        durationMs = nitrousDurationMs,
        overrideLevel = 1.0,
        hudFill = 100.0,
        disableSound = false,
    })
    nitrousState.nitrousAvailableCharge = 0.0
    nitrousState.nitrousDurationMs = nitrousDurationMs
    nitrousState.nitrousActiveUntil = now + nitrousDurationMs
    nitrousState.nitrousAvailableNotified = false
end

function Nitrous.refillAvailability(vehicle, now)
    local bindings = PerformanceTuning.ClientBindings or {}
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    local nitrousRefillConfig = runtimeConfig.nitrousRefill or {}
    if not PerformanceTuning.VehicleManager.isVehicleEntityValid(vehicle) then
        return
    end

    if GetEntitySpeed(vehicle) > (tonumber(nitrousRefillConfig.refillMaxSpeedMetersPerSecond) or 0.5) then
        return
    end

    local nitrousState = bindings.ensureTuningState and bindings.ensureTuningState(vehicle) or nil
    if not nitrousState or (nitrousState.nitrousLevel or 'stock') == 'stock' then
        return
    end

    if nitrousState.nitrousActiveUntil > now then
        return
    end

    local refillIntervalMs = tonumber(nitrousRefillConfig.refillIntervalMs) or 500
    if (now - (nitrousState.nitrousLastRefillAt or 0)) < refillIntervalMs then
        return
    end

    local refillAmount = refillIntervalMs / ((tonumber(nitrousRefillConfig.refillDurationSeconds) or 2.0) * 1000.0)
    local previousAvailableCharge = tonumber(nitrousState.nitrousAvailableCharge) or 0.0
    nitrousState.nitrousAvailableCharge = math.min(1.0, previousAvailableCharge + refillAmount)
    nitrousState.nitrousLastRefillAt = now

    if nitrousState.nitrousAvailableCharge >= 1.0 and not nitrousState.nitrousAvailableNotified then
        nitrousState.nitrousAvailableNotified = true
        if bindings.notify then
            bindings.notify('Nitrous is available.')
        end
    elseif nitrousState.nitrousAvailableCharge < 1.0 then
        nitrousState.nitrousAvailableNotified = false
    end
end

CreateThread(function()
    local vehicleManager = PerformanceTuning.VehicleManager or {}
    while true do
        local vehicle = vehicleManager.getCurrentVehicle and vehicleManager.getCurrentVehicle() or nil
        if vehicle then
            if Nitrous.wasControlJustPressed() then
                Nitrous.triggerShotIfAvailable(vehicle)
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

CreateThread(function()
    local vehicleManager = PerformanceTuning.VehicleManager or {}
    while true do
        local vehicle = vehicleManager.getCurrentVehicle and vehicleManager.getCurrentVehicle() or nil
        if vehicle then
            Nitrous.refillAvailability(vehicle, GetGameTimer())
        end
        Wait(500)
    end
end)
