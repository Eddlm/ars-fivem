-- Handles performancetuning nitrous availability, refill, and shot dispatch.
-- Shot execution (native calls) lives here directly; customphysics is not required for nitrous.
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

-- Shot state
local activeShot = {
    vehicle = nil,
    activeUntil = 0,
}

local function stopNitrousOverride(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    SetOverrideNitrousLevel(vehicle, false, 10.0, 0.0, 100.0, true)
    SetVehicleHudSpecialAbilityBarActive(vehicle, false)
end

local function executeShot(vehicle, instructions)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or type(instructions) ~= 'table' then return end
    local durationMs = math.max(250, math.floor(tonumber(instructions.durationMs) or 0))
    local power = math.max(0.0, tonumber(instructions.power) or 0.0)
    if durationMs <= 0 or power <= 0.0 then return end
    FullyChargeNitrous(vehicle)
    Citizen.InvokeNative(0xC8E9B6B71B8E660D, vehicle, true, tonumber(instructions.overrideLevel) or 1.0, power, tonumber(instructions.hudFill) or 100.0, instructions.disableSound == true)
    SetVehicleHudSpecialAbilityBarActive(vehicle, false)
    activeShot.vehicle = vehicle
    activeShot.activeUntil = GetGameTimer() + durationMs
end

local function clearShot(vehicle)
    local target = vehicle or activeShot.vehicle
    stopNitrousOverride(target)
    activeShot.vehicle = nil
    activeShot.activeUntil = 0
end

-- Per-frame loop: disables the nitrous control input and auto-clears when the shot expires.
CreateThread(function()
    while true do
        if activeShot.vehicle ~= nil then
            local now = GetGameTimer()
            local v = activeShot.vehicle
            if not DoesEntityExist(v) or now >= activeShot.activeUntil then
                clearShot(v)
            else
                DisableControlAction(0, 73, true)
                DisableControlAction(1, 73, true)
                DisableControlAction(2, 73, true)
                Wait(0)
            end
        else
            Wait(100)
        end
    end
end)

function Nitrous.clearShot(vehicle)
    clearShot(vehicle)
end

local function dispatchShot(vehicle, instructions)
    executeShot(vehicle, instructions)
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
    if not PerformanceTuning.VehicleManager.isVehicleEntityValid(vehicle) then
        return
    end

    -- Stationary refill model: nitrous becomes fully available only when essentially stopped.
    if GetEntitySpeed(vehicle) > 0.5 then
        return
    end

    local nitrousState = bindings.ensureTuningState and bindings.ensureTuningState(vehicle) or nil
    if not nitrousState or (nitrousState.nitrousLevel or 'stock') == 'stock' then
        return
    end

    if nitrousState.nitrousActiveUntil > now then
        return
    end

    local hadFullCharge = (tonumber(nitrousState.nitrousAvailableCharge) or 0.0) >= 1.0
    nitrousState.nitrousAvailableCharge = 1.0

    if not hadFullCharge and not nitrousState.nitrousAvailableNotified then
        nitrousState.nitrousAvailableNotified = true
        if bindings.notify then
            bindings.notify('Nitrous is available.')
        end
    end
end

-- Rev limiter: disables throttle input at redline. Moved here from customphysics/power.lua
-- to remove the dependency on that resource for this performancetuning-owned feature.
local accelDisabledAt = 0

local function updateRevLimiter(vehicle, now)
    local bucket = PerformanceTuning.VehicleManager.ensureTuningState(vehicle)
    if not bucket or bucket.revLimiterEnabled ~= true then
        accelDisabledAt = 0
        return
    end

    local currentGear = GetVehicleCurrentGear(vehicle)
    local highGear = math.max(GetVehicleHighGear(vehicle) or 0, 0)
    local currentRpm = GetVehicleCurrentRpm(vehicle)
    local moving = GetEntitySpeed(vehicle) * 2.2369362921 > 1.0
    local validGear = currentGear >= 1 and (highGear <= 1 or currentGear < highGear)

    if moving and validGear and currentRpm >= 1.0 then
        accelDisabledAt = now + 10
    end

    if now < accelDisabledAt then
        DisableControlAction(0, 71, true)
        DisableControlAction(2, 71, true)
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
            updateRevLimiter(vehicle, GetGameTimer())
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
