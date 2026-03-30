CustomPhysicsNitrous = CustomPhysicsNitrous or {}

local Nitrous = {
    ptfxAsset = 'veh_xs_vehicle_mods',
    defaultOverrideLevel = 1.0,
    defaultHudFill = 100.0,
    controlId = 73,
}

local activeNitrousShot = {
    vehicle = nil,
    activeUntil = 0,
}

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
end

RegisterNetEvent('customphysics:nitrous:executeShot', function(vehicle, instructions)
    CustomPhysicsNitrous.executeShot(vehicle, instructions)
end)

RegisterNetEvent('customphysics:nitrous:clear', function(vehicle)
    CustomPhysicsNitrous.reset(vehicle)
end)
