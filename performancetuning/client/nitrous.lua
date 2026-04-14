-- Handles performancetuning nitrous availability, refill, and shot dispatch.
-- Shot execution (native calls) lives here directly; customphysics is not required for nitrous.
PerformanceTuning = PerformanceTuning or {}
PerformanceTuning.Nitrous = PerformanceTuning.Nitrous or {}

local Nitrous = PerformanceTuning.Nitrous

local NitrousVisuals = {
    ptfxAsset = 'veh_xs_vehicle_mods',
}

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

local function requestNitrousPtfxAsset()
    if HasNamedPtfxAssetLoaded(NitrousVisuals.ptfxAsset) then
        return
    end

    RequestNamedPtfxAsset(NitrousVisuals.ptfxAsset)
end

local function showSubtitle(text, durationMs)
    BeginTextCommandPrint('STRING')
    AddTextComponentSubstringPlayerName(tostring(text or ''))
    EndTextCommandPrint(math.max(0, math.floor(tonumber(durationMs) or 1000)), true)
end

local function getMaxNitrousShots(nitrousConfig)
    return math.max(1, math.floor(tonumber((nitrousConfig or {}).shotsPerRefill) or 3))
end

local function getNitrousShotCooldownMs(nitrousConfig)
    return math.max(0, math.floor(tonumber((nitrousConfig or {}).shotCooldownMs) or 40000))
end

local function getAvailableShots(nitrousState, maxShots)
    return math.max(0, math.min(maxShots, math.floor(tonumber((nitrousState or {}).nitrousAvailableCharge) or maxShots)))
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
        and (tonumber(nitrousState.nitrousActiveUntil) or 0) <= now
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

    local nitrousConfig = runtimeConfig.nitrous or {}
    local maxShots = getMaxNitrousShots(nitrousConfig)
    local availableShots = getAvailableShots(nitrousState, maxShots)
    if availableShots <= 0 then
        showSubtitle(('~o~No nitro shots remaining.'), 2000)
        return
    end

    local cooldownUntil = math.max(0, math.floor(tonumber(nitrousState.nitrousCooldownUntil) or 0))
    if now < cooldownUntil then
        local remainingSeconds = math.max(1, math.ceil((cooldownUntil - now) / 1000.0))
        showSubtitle(('~o~Engine is too hot.\n ~w~Wait %ss.'):format(remainingSeconds), 2000)
        return
    end

    local sliderRange = (runtimeConfig.sliderRanges or {}).nitrousShotStrength or {}
    local nitrousShotStrength = math.max(tonumber(sliderRange.min) or 1.0, tonumber(nitrousState.nitrousShotStrength) or 1.0)
    local shotCooldownMs = getNitrousShotCooldownMs(nitrousConfig)
    local nitrousPower = nitrousLevelMultiplier * nitrousShotStrength * (tonumber(nitrousConfig.nativePowerMultiplier) or 0.0)
    local nitrousDurationMs = math.max(250, math.floor((tonumber(nitrousConfig.baseDurationMs) or 4000) / (nitrousShotStrength*1.33)))

    dispatchShot(vehicle, {
        power = nitrousPower,
        durationMs = nitrousDurationMs,
        overrideLevel = 1.0,
        hudFill = 100.0,
        disableSound = false,
    })
    nitrousState.nitrousAvailableCharge = math.max(0, availableShots - 1)
    nitrousState.nitrousDurationMs = nitrousDurationMs
    nitrousState.nitrousActiveUntil = now + nitrousDurationMs
    nitrousState.nitrousCooldownUntil = now + shotCooldownMs
    nitrousState.nitrousAvailableNotified = false
    showSubtitle(('~b~%s~w~ shots remaining.'):format(nitrousState.nitrousAvailableCharge), 2000)
end

function Nitrous.refillAvailability(vehicle, now)
    local bindings = PerformanceTuning.ClientBindings or {}
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
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

    if (tonumber(nitrousState.nitrousActiveUntil) or 0) > now then
        return
    end

    local maxShots = getMaxNitrousShots((runtimeConfig or {}).nitrous or {})
    local hadFullCharge = getAvailableShots(nitrousState, maxShots) >= maxShots
    nitrousState.nitrousAvailableCharge = maxShots

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
                requestNitrousPtfxAsset()
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
