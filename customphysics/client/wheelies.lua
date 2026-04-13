CustomPhysicsWheelies = CustomPhysicsWheelies or {}
local WheelieConfig = (((CustomPhysics or {}).Config or {}).advanced or {}).wheelies or {}

local WheelieStage = {
    off      = 0,
    prepared = 1,
    active   = 2,
}

local Params = {
    armSpeedThreshold     = WheelieConfig.armSpeedThresholdMetersPerSecond or 1.0,
    forceMultiplier       = WheelieConfig.forceMultiplier or 0.4,
    frontOffsetMultiplier = WheelieConfig.frontOffsetLengthMultiplier or 2.0,
    -- Suppression
    suppressionRpmThreshold   = 0.9,
    suppressionSpeedThreshold = 0.5,
    -- Force controller
    rpmLaunchThreshold  = 0.9,
    targetPitchFactor   = 40.0,
    proportionalGain    = 0.5,
    forceRampRate       = 1.0,
    wheelPowerNormClamp = 0.9,
    -- Drive bias remapping: fDriveBiasFront range that maps to full rear bias
    driveBiasInMin  = 0.2,
    driveBiasInMax  = 0.0,
}

local defaultState = {
    nativeWheelieControlActive = false,
    prevAcceleration           = false,
    prevBrake                  = false,
    prevHandbrake              = false,
    stage                      = WheelieStage.off,
    force                      = 0.0,
}

local state = {}
for k, v in pairs(defaultState) do state[k] = v end

-- State helpers

local function resetWheelieState()
    state.stage = WheelieStage.off
    state.force = 0.0
end

local function storeWheelieInputs(accelerationActive, brakeActive, handbrakeActive)
    state.prevAcceleration = accelerationActive
    state.prevBrake        = brakeActive
    state.prevHandbrake    = handbrakeActive
end

-- Input helpers

local function isAccelerationActive()
    return IsControlPressed(0, 71) or IsDisabledControlPressed(0, 71) or IsControlPressed(2, 71) or IsDisabledControlPressed(2, 71)
end

local function isBrakeHeld()
    return IsControlPressed(0, 72) or IsDisabledControlPressed(0, 72) or IsControlPressed(2, 72) or IsDisabledControlPressed(2, 72)
end

local function isHandbrakeHeld()
    return IsControlPressed(0, 76) or IsDisabledControlPressed(0, 76) or IsControlPressed(2, 76) or IsDisabledControlPressed(2, 76)
end

-- Native wheelie suppression

-- Applies native wheelie suppression during launch conditions when configured.
local function applyNativeWheelieSuppression(vehicle)
    if CustomPhysics.Config.nativeWheeliesDisabled == false then
        state.nativeWheelieControlActive = false
        return
    end

    local handbrakeActive  = isHandbrakeHeld()
    local currentRpm       = GetVehicleCurrentRpm(vehicle)
    local accelerationActive = isAccelerationActive()
    local vehicleSpeed     = GetEntitySpeed(vehicle)

    if handbrakeActive and currentRpm > Params.suppressionRpmThreshold and accelerationActive then
        state.nativeWheelieControlActive = true
    elseif state.nativeWheelieControlActive and vehicleSpeed > Params.suppressionSpeedThreshold then
        state.nativeWheelieControlActive = false
    end

    if not state.nativeWheelieControlActive then
        return
    end

    if GetVehicleWheelieState(vehicle) ~= 1 then
        SetVehicleWheelieState(vehicle, 1)
    end
end

-- Geometry and force helpers

-- Returns the model length used to scale wheelie offsets and slope sampling.
local function getVehicleLength(vehicle)
    local modelMin, modelMax = GetModelDimensions(GetEntityModel(vehicle))
    return math.abs(modelMax.y - modelMin.y)
end

-- Measures vehicle pitch relative to the ground slope instead of world pitch alone.
local function getSlopeRelativePitchDegrees(vehicle, vehicleLength)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return 0.0
    end

    local sampleOffset  = math.max(vehicleLength * 0.35, 0.75)
    local rayStartHeight = 1.5
    local rayDepth      = 6.0

    local frontStart = GetOffsetFromEntityInWorldCoords(vehicle, 0.0,  sampleOffset, rayStartHeight)
    local rearStart  = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -sampleOffset, rayStartHeight)

    local frontRay = StartShapeTestRay(frontStart.x, frontStart.y, frontStart.z, frontStart.x, frontStart.y, frontStart.z - rayDepth, 1, vehicle, 0)
    local _, frontHit, frontCoords = GetShapeTestResult(frontRay)
    local rearRay  = StartShapeTestRay(rearStart.x,  rearStart.y,  rearStart.z,  rearStart.x,  rearStart.y,  rearStart.z  - rayDepth, 1, vehicle, 0)
    local _, rearHit,  rearCoords  = GetShapeTestResult(rearRay)

    if frontHit ~= 1 or rearHit ~= 1 then
        return GetEntityPitch(vehicle)
    end

    local groundDx      = frontCoords.x - rearCoords.x
    local groundDy      = frontCoords.y - rearCoords.y
    local groundDz      = frontCoords.z - rearCoords.z
    local groundFlatLen = math.sqrt((groundDx * groundDx) + (groundDy * groundDy))
    if groundFlatLen <= 0.0001 then
        return GetEntityPitch(vehicle)
    end

    return GetEntityPitch(vehicle) - math.deg(math.atan2(groundDz, groundFlatLen))
end

-- Returns whether at least one driven wheel is in contact with a valid surface.
local function hasGroundedDrivenWheel(wheelSnapshot, vehicle)
    local wheelPowers = wheelSnapshot and wheelSnapshot.wheelPowers or {}
    local wheelCount  = wheelSnapshot and wheelSnapshot.wheelCount  or 0

    for wheelIndex = 0, wheelCount - 1 do
        if (wheelPowers[wheelIndex] or 0.0) > 0.0001 then
            local material = GetVehicleWheelSurfaceMaterial(vehicle, wheelIndex)
            if material and material > 0 then
                return true
            end
        end
    end

    return false
end

-- Returns driven wheel power after clamping it into the wheelie controller's expected range.
local function getClampedDrivenWheelPower(wheelSnapshot)
    return CustomPhysicsUtil.clamp(wheelSnapshot and wheelSnapshot.drivenWheelPower or 0.0, 0.0, 1.0)
end

-- Public subsystem API

-- Resets the wheelie subsystem when the vehicle context changes or stops.
function CustomPhysicsWheelies.reset()
    state = {}
    for k, v in pairs(defaultState) do state[k] = v end
end

-- Updates native suppression, arming, and force application for the wheelie controller.
function CustomPhysicsWheelies.update(vehicle)
    applyNativeWheelieSuppression(vehicle)

    local accelerationActive = isAccelerationActive()
    local brakeActive        = isBrakeHeld()
    local handbrakeActive    = isHandbrakeHeld()

    -- Wheelies off, early exit
    if not GetConvarBool('cp_wheelies_enabled', true) then
        storeWheelieInputs(accelerationActive, brakeActive, handbrakeActive)
        resetWheelieState()
        return
    end

    if GetConvarBool('cp_wheelies_muscle_only', true) and not GetVehicleClass(vehicle) == 4 then
        storeWheelieInputs(accelerationActive, brakeActive, handbrakeActive)
        resetWheelieState()
        return
    end

    if not accelerationActive or IsEntityInAir(vehicle) or (GetVehicleCurrentGear(vehicle) > 1 and IsVehicleOnAllWheels(vehicle)) then
        resetWheelieState()
    end

    if state.stage == WheelieStage.off
        and state.prevAcceleration
        and state.prevBrake
        and accelerationActive
        and handbrakeActive
        and not brakeActive
    then
        state.stage = WheelieStage.prepared
    end

    if state.stage == WheelieStage.prepared then
        if not accelerationActive then
            resetWheelieState()
        elseif state.prevHandbrake
            and not handbrakeActive
            and GetVehicleCurrentRpm(vehicle) > Params.rpmLaunchThreshold
            and GetEntitySpeed(vehicle) <= Params.armSpeedThreshold
        then
            state.stage = WheelieStage.active
            state.force = math.max(state.force, Params.forceMultiplier)
        end
    end

    storeWheelieInputs(accelerationActive, brakeActive, handbrakeActive)

    if state.stage ~= WheelieStage.active then
        state.force = 0.0
        return
    end

    local vehicleLength = getVehicleLength(vehicle)
    local frontOffset   = Params.frontOffsetMultiplier * vehicleLength
    local frameTime     = CustomPhysicsUtil.getDeltaSeconds()

    local wheelSnapshot = CustomPhysicsUtil.buildWheelPowerSnapshot(vehicle)
    if not hasGroundedDrivenWheel(wheelSnapshot, vehicle) then
        state.force = 0.0
        return
    end

    local pitchDeg        = getSlopeRelativePitchDegrees(vehicle, vehicleLength)
    local pitchRate       = -math.deg(GetEntityRotationVelocity(vehicle).y)
    local wheelPower      = getClampedDrivenWheelPower(wheelSnapshot)
    local wheelPowerNorm  = CustomPhysicsUtil.clamp(wheelPower / Params.wheelPowerNormClamp, 0.0, 1.0)
    local driveBiasFront  = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fDriveBiasFront')
    local rearBiasMultiplier = CustomPhysicsUtil.mapValue(driveBiasFront, Params.driveBiasInMin, Params.driveBiasInMax, 0.0, 1.0, true)
    local targetPitchDeg  = wheelPowerNorm * Params.targetPitchFactor
    local pitchErr        = targetPitchDeg - pitchDeg
    local targetRateDeg   = pitchErr * Params.proportionalGain
    local controlOut      = targetRateDeg - pitchRate
    local targetForce     = math.max(0.0, controlOut)

    if state.force < targetForce then
        state.force = math.min(targetForce, state.force + (Params.forceRampRate * frameTime))
    else
        state.force = math.max(targetForce, state.force - (Params.forceRampRate * frameTime))
    end

    local wheelForce = state.force * rearBiasMultiplier * frameTime

    ApplyForceToEntity(vehicle, 1, 0.0, -wheelForce, 0.0, 0.0, 0.0, frontOffset, 0, true, true, true, false, true)
    ApplyForceToEntity(vehicle, 1, 0.0,  0.0, wheelForce, 0.0, frontOffset, 0.0, 0, true, true, true, false, true)
end
