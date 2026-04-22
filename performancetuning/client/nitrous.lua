-- Handles performancetuning nitrous availability, refill, and shot dispatch.
-- Shot execution (native calls) lives here directly; customphysics is not required for nitrous.
PerformanceTuning = PerformanceTuning or {}
PerformanceTuning.Nitrous = PerformanceTuning.Nitrous or {}
local NitrousVisuals = {
    ptfxAsset = 'veh_xs_vehicle_mods',
}

local function getNitrousLevelMultiplier(nitrousLevel)
    for _, pack in ipairs((PerformanceTuning._internals or {}).NITROUS_PACKS or {}) do
        if pack.id == nitrousLevel then
            return tonumber(pack.powerMultiplier) or 0.0
        end
    end

    return 0.0
end

local function wasControlJustPressed()
    return IsControlJustPressed(0, 73)
end

local function requestNitrousPtfxAsset()
    if not HasNamedPtfxAssetLoaded(NitrousVisuals.ptfxAsset) then
        RequestNamedPtfxAsset(NitrousVisuals.ptfxAsset)
    end
end

local function showSubtitle(text, durationMs)
    BeginTextCommandPrint('STRING')
    AddTextComponentSubstringPlayerName(tostring(text or ''))
    durationMs = math.max(0, math.floor(tonumber(durationMs) or 1000))
    EndTextCommandPrint(durationMs, true)
end

local function getMaxNitrousShots(nitrousConfig)
    return math.max(1, math.floor(tonumber((nitrousConfig or {}).shotsPerRefill) or 3))
end

local function getNitrousShotCooldownMs()
    return GetConvarInt('pt_nitrous_shot_cooldown_ms', 0)
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
    if not PerformanceTuning.VehicleManager.isVehicleEntityValid(vehicle) then return end
    SetOverrideNitrousLevel(vehicle, false, 10.0, 0.0, 100.0, true)
    SetVehicleHudSpecialAbilityBarActive(vehicle, false)
end

local function executeShot(vehicle, instructions)
    if not PerformanceTuning.VehicleManager.isVehicleEntityValid(vehicle) or type(instructions) ~= 'table' then return end
    local durationMs = math.max(250, math.floor(tonumber(instructions.durationMs) or 0))
    local power = math.max(0.0, tonumber(instructions.power) or 0.0)
    if power <= 0.0 then return end
    FullyChargeNitrous(vehicle)
    Citizen.InvokeNative(0xC8E9B6B71B8E660D, vehicle, true, tonumber(instructions.overrideLevel) or 1.0, power, tonumber(instructions.hudFill) or 100.0, instructions.disableSound == true)
    SetVehicleHudSpecialAbilityBarActive(vehicle, false)
    activeShot.vehicle = vehicle
    activeShot.activeUntil = GetGameTimer() + durationMs
end

local function clearShot(vehicle)
    stopNitrousOverride(vehicle or activeShot.vehicle)
    activeShot.vehicle = nil
    activeShot.activeUntil = 0
end

function PerformanceTuning.Nitrous.clearShot(vehicle)
    clearShot(vehicle)
end

local function dispatchShot(vehicle, instructions)
    return executeShot(vehicle, instructions)
end

local function canTriggerShot(nitrousState, nitrousLevelMultiplier, now)
    return nitrousState
        and nitrousLevelMultiplier > 0.0
        and (tonumber(nitrousState.nitrousActiveUntil) or 0) <= now
end

local function triggerShotIfAvailable(vehicle)
    if not PerformanceTuning.VehicleManager.isVehicleEntityValid(vehicle) then
        return
    end

    local bindings = PerformanceTuning.ClientBindings or {}
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
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
        showSubtitle('~o~No nitro shots remaining.', 2000)
        return
    end

    local cooldownUntil = math.max(0, math.floor(tonumber(nitrousState.nitrousCooldownUntil) or 0))
    local shotCooldownMs = getNitrousShotCooldownMs(nitrousConfig)
    local cooldownStartedAt = math.max(0, math.floor(tonumber(nitrousState.nitrousCooldownStartedAt) or 0))
    if cooldownUntil <= 0 then
        cooldownStartedAt = 0
        nitrousState.nitrousCooldownStartedAt = 0
    elseif cooldownStartedAt <= 0 then
        cooldownStartedAt = math.max(0, cooldownUntil - shotCooldownMs)
        nitrousState.nitrousCooldownStartedAt = cooldownStartedAt
    end

    local liveCooldownUntil = (cooldownStartedAt > 0) and (cooldownStartedAt + shotCooldownMs) or 0
    nitrousState.nitrousCooldownUntil = liveCooldownUntil
    if now < liveCooldownUntil then
        local remainingSeconds = math.max(1, math.ceil((liveCooldownUntil - now) / 1000.0))
        showSubtitle(('~o~Engine is too hot.\n ~w~Wait %ss.'):format(remainingSeconds), 2000)
        return
    end

    if liveCooldownUntil > 0 then
        nitrousState.nitrousCooldownUntil = 0
        nitrousState.nitrousCooldownStartedAt = 0
    end

    local sliderRange = (runtimeConfig.sliderRanges or {}).nitrousShotStrength or {}
    local nitrousShotStrength = math.max(tonumber(sliderRange.min) or 1.0, tonumber(nitrousState.nitrousShotStrength) or 1.0)
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
    nitrousState.nitrousCooldownStartedAt = now
    nitrousState.nitrousCooldownUntil = now + shotCooldownMs
    nitrousState.nitrousAvailableNotified = false
    showSubtitle(('~b~%d~w~ shots remaining.'):format(nitrousState.nitrousAvailableCharge), 2000)
end

local function refillAvailability(vehicle, now)
    if not PerformanceTuning.VehicleManager.isVehicleEntityValid(vehicle) then
        return
    end

    local bindings = PerformanceTuning.ClientBindings or {}
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}

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
            bindings.notify('PerformanceTuning.Nitrous is available.')
        end
    end
end

local vehicleManager = PerformanceTuning.VehicleManager or {}

CreateThread(function()
    while true do
        local vehicle = vehicleManager.getCurrentVehicle and vehicleManager.getCurrentVehicle() or nil
        if vehicle then
            if wasControlJustPressed() then
                requestNitrousPtfxAsset()
                triggerShotIfAvailable(vehicle)
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

CreateThread(function()
    while true do
        local vehicle = vehicleManager.getCurrentVehicle and vehicleManager.getCurrentVehicle() or nil
        if vehicle then
            refillAvailability(vehicle, GetGameTimer())
        end
        Wait(500)
    end
end)

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
                Wait(0)
            end
        else
            Wait(100)
        end
    end
end)

