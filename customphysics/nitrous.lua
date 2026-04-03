CustomPhysicsNitrous = CustomPhysicsNitrous or {}
local Config = (CustomPhysics or {}).Config or {}
local NitrousConfig = type(Config.nitrous) == "table" and Config.nitrous or {}

local Nitrous = {
    ptfxAsset = 'veh_xs_vehicle_mods',
    defaultOverrideLevel = tonumber(NitrousConfig.defaultOverrideLevel) or 1.0,
    defaultHudFill = tonumber(NitrousConfig.defaultHudFill) or 100.0,
    controlId = math.max(0, math.floor(tonumber(NitrousConfig.controlId) or 73)),
}

local activeNitrousShot = {
    vehicle = nil,
    activeUntil = 0,
    lastStatusNotifyAt = 0,
}

local function notify(message)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(tostring(message or ""))
    EndTextCommandThefeedPostTicker(false, false)
end

local function requestNitrousPtfxAsset()
    if HasNamedPtfxAssetLoaded(Nitrous.ptfxAsset) then
        return true
    end

    RequestNamedPtfxAsset(Nitrous.ptfxAsset)
    return HasNamedPtfxAssetLoaded(Nitrous.ptfxAsset)
end

local function stopNitrousOverride(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return
    end

    SetOverrideNitrousLevel(vehicle, false, 10.0, 0.0, Nitrous.defaultHudFill, true)
    SetVehicleHudSpecialAbilityBarActive(vehicle, false)
end

function CustomPhysicsNitrous.reset(vehicle)
    local targetVehicle = vehicle or activeNitrousShot.vehicle
    stopNitrousOverride(targetVehicle)
    activeNitrousShot.vehicle = nil
    activeNitrousShot.activeUntil = 0
    activeNitrousShot.lastStatusNotifyAt = 0
end

function CustomPhysicsNitrous.executeShot(vehicle, instructions)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or type(instructions) ~= 'table' then
        return false
    end

    local durationMs = math.max(250, math.floor(tonumber(instructions.durationMs) or 0))
    local power = math.max(0.0, tonumber(instructions.power) or 0.0)
    if durationMs <= 0 or power <= 0.0 then
        return false
    end

    requestNitrousPtfxAsset()
    FullyChargeNitrous(vehicle)
    Citizen.InvokeNative(
        0xC8E9B6B71B8E660D,
        vehicle,
        true,
        tonumber(instructions.overrideLevel) or Nitrous.defaultOverrideLevel,
        power,
        tonumber(instructions.hudFill) or Nitrous.defaultHudFill,
        instructions.disableSound == true
    )
    SetVehicleHudSpecialAbilityBarActive(vehicle, false)
    activeNitrousShot.vehicle = vehicle
    activeNitrousShot.activeUntil = GetGameTimer() + durationMs
    activeNitrousShot.lastStatusNotifyAt = 0
    return true
end

function CustomPhysicsNitrous.update(vehicle, now)
    if activeNitrousShot.vehicle == nil then
        return
    end

    if activeNitrousShot.vehicle ~= vehicle or not DoesEntityExist(activeNitrousShot.vehicle) then
        CustomPhysicsNitrous.reset(activeNitrousShot.vehicle)
        return
    end

    if now >= activeNitrousShot.activeUntil then
        CustomPhysicsNitrous.reset(activeNitrousShot.vehicle)
        return
    end

    DisableControlAction(0, Nitrous.controlId, true)
    DisableControlAction(1, Nitrous.controlId, true)
    DisableControlAction(2, Nitrous.controlId, true)

    local intervalMs = math.max(250, math.floor(tonumber(NitrousConfig.debugStatusIntervalMs) or 1000))
    if (now - (activeNitrousShot.lastStatusNotifyAt or 0)) >= intervalMs then
        activeNitrousShot.lastStatusNotifyAt = now
    end
end

function CustomPhysicsNitrous.getDebugSnapshot()
    local now = GetGameTimer()
    local activeVehicle = activeNitrousShot.vehicle
    local active = activeVehicle ~= nil and now < (activeNitrousShot.activeUntil or 0)
    local remainingMs = active and math.max(0, (activeNitrousShot.activeUntil or 0) - now) or 0
    return {
        active = active,
        remainingMs = remainingMs,
        controlId = Nitrous.controlId,
        defaultOverrideLevel = Nitrous.defaultOverrideLevel,
        defaultHudFill = Nitrous.defaultHudFill,
    }
end

RegisterNetEvent('customphysics:nitrous:executeShot', function(vehicle, instructions)
    CustomPhysicsNitrous.executeShot(vehicle, instructions)
end)

RegisterNetEvent('customphysics:nitrous:clear', function(vehicle)
    CustomPhysicsNitrous.reset(vehicle)
end)
