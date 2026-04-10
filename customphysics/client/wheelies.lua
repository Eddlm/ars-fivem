CustomPhysicsWheelies = CustomPhysicsWheelies or {}
local WheelieConfig = (((CustomPhysics or {}).Config or {}).advanced or {}).wheelies or {}

local WheelieStage = {
    off = 0,
    prepared = 1,
    active = 2,
}

local nativeWheelieControlActive = false
local prevAcceleration = false
local prevBrake = false
local prevHandbrake = false
local wheelieStage = WheelieStage.off
local wheelieForce = 0.0
local CUSTOM_WHEELIE_ARM_SPEED_THRESHOLD_METERS_PER_SECOND = tonumber(WheelieConfig.armSpeedThresholdMetersPerSecond) or 1.0
local CUSTOM_WHEELIE_FORCE_MULTIPLIER = tonumber(WheelieConfig.forceMultiplier) or 0.4
local CUSTOM_WHEELIE_FRONT_OFFSET_LENGTH_MULTIPLIER = tonumber(WheelieConfig.frontOffsetLengthMultiplier) or 2.0

-- State helpers

-- Clears the transient wheelie state machine values.
local function resetWheelieState()
    wheelieStage = WheelieStage.off
    wheelieForce = 0.0
end

-- Caches the current frame's launch-related input states.
local function storeWheelieInputs(accelerationActive, brakeActive, handbrakeActive)
    prevAcceleration = accelerationActive
    prevBrake = brakeActive
    prevHandbrake = handbrakeActive
end

-- Input helpers

-- Checks whether acceleration input is currently being held.
local function isAccelerationActive()
    return IsControlPressed(0, 71) or IsDisabledControlPressed(0, 71) or IsControlPressed(2, 71) or IsDisabledControlPressed(2, 71)
end

-- Checks whether the brake input is currently being held.
local function isBrakeHeld()
    return IsControlPressed(0, 72) or IsDisabledControlPressed(0, 72) or IsControlPressed(2, 72) or IsDisabledControlPressed(2, 72)
end

-- Checks whether the handbrake input is currently being held.
local function isHandbrakeHeld()
    return IsControlPressed(0, 76) or IsDisabledControlPressed(0, 76) or IsControlPressed(2, 76) or IsDisabledControlPressed(2, 76)
end

-- Returns whether the current vehicle is allowed to use the custom wheelie system.
local function isWheelieVehicleAllowed(vehicle)
    if CustomPhysics.Config.wheeliesMuscleOnly ~= true then
        return true
    end

    return GetVehicleClass(vehicle) == 4
end

-- Native wheelie suppression

-- Applies native wheelie suppression during launch conditions when configured.
local function applyNativeWheelieSuppression(vehicle)
    if CustomPhysics.Config.nativeWheeliesDisabled == false then
        nativeWheelieControlActive = false
        return
    end

    local handbrakeActive = isHandbrakeHeld()
    local currentRpm = GetVehicleCurrentRpm(vehicle)
    local accelerationActive = isAccelerationActive()
    local vehicleSpeed = GetEntitySpeed(vehicle)

    if handbrakeActive and currentRpm > 0.9 and accelerationActive then
        nativeWheelieControlActive = true
    elseif nativeWheelieControlActive and vehicleSpeed > 0.5 then
        nativeWheelieControlActive = false
    end

    if not nativeWheelieControlActive then
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

    local sampleOffset = math.max(vehicleLength * 0.35, 0.75)
    local rayStartHeight = 1.5
    local rayDepth = 6.0

    local frontStart = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, sampleOffset, rayStartHeight)
    local frontEndZ = frontStart.z - rayDepth
    local rearStart = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -sampleOffset, rayStartHeight)
    local rearEndZ = rearStart.z - rayDepth

    local frontRay = StartShapeTestRay(frontStart.x, frontStart.y, frontStart.z, frontStart.x, frontStart.y, frontEndZ, 1, vehicle, 0)
    local _, frontHit, frontCoords = GetShapeTestResult(frontRay)
    local rearRay = StartShapeTestRay(rearStart.x, rearStart.y, rearStart.z, rearStart.x, rearStart.y, rearEndZ, 1, vehicle, 0)
    local _, rearHit, rearCoords = GetShapeTestResult(rearRay)

    if frontHit ~= 1 or rearHit ~= 1 then
        return GetEntityPitch(vehicle)
    end

    local groundDx = frontCoords.x - rearCoords.x
    local groundDy = frontCoords.y - rearCoords.y
    local groundDz = frontCoords.z - rearCoords.z
    local groundFlatLen = math.sqrt((groundDx * groundDx) + (groundDy * groundDy))
    if groundFlatLen <= 0.0001 then
        return GetEntityPitch(vehicle)
    end

    local groundPitchDeg = math.deg(math.atan2(groundDz, groundFlatLen))
    local vehiclePitchDeg = GetEntityPitch(vehicle)
    return vehiclePitchDeg - groundPitchDeg
end

-- Returns whether at least one driven wheel is in contact with a valid surface.
local function hasGroundedDrivenWheel(wheelSnapshot, vehicle)
    local wheelPowers = wheelSnapshot and wheelSnapshot.wheelPowers or {}
    local wheelCount = wheelSnapshot and wheelSnapshot.wheelCount or 0

    for wheelIndex = 0, wheelCount - 1 do
        local wheelPower = wheelPowers[wheelIndex] or 0.0
        if wheelPower > 0.0001 then
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
    local wheelPower = wheelSnapshot and wheelSnapshot.drivenWheelPower or 0.0
    return CustomPhysicsUtil.clamp(wheelPower, 0.0, 1.0)
end

-- Public subsystem API

-- Resets the wheelie subsystem when the vehicle context changes or stops.
function CustomPhysicsWheelies.reset()
    nativeWheelieControlActive = false
    prevAcceleration = false
    prevBrake = false
    prevHandbrake = false
    resetWheelieState()
end

-- Updates native suppression, arming, and force application for the wheelie controller.
function CustomPhysicsWheelies.update(vehicle)
    applyNativeWheelieSuppression(vehicle)

    local accelerationActive = isAccelerationActive()
    local brakeActive = isBrakeHeld()
    local handbrakeActive = isHandbrakeHeld()

    if CustomPhysics.Config.customWheelieEnabled == false then
        storeWheelieInputs(accelerationActive, brakeActive, handbrakeActive)
        resetWheelieState()
        return
    end

    if not isWheelieVehicleAllowed(vehicle) then
        storeWheelieInputs(accelerationActive, brakeActive, handbrakeActive)
        resetWheelieState()
        return
    end

    if not accelerationActive or IsEntityInAir(vehicle) or (GetVehicleCurrentGear(vehicle) > 1 and IsVehicleOnAllWheels(vehicle)) then
        resetWheelieState()
    end

    if wheelieStage == WheelieStage.off
        and prevAcceleration
        and prevBrake
        and accelerationActive
        and handbrakeActive
        and not brakeActive
    then
        wheelieStage = WheelieStage.prepared
    end

    if wheelieStage == WheelieStage.prepared then
        if not accelerationActive then
            resetWheelieState()
        elseif prevHandbrake
            and not handbrakeActive
            and GetVehicleCurrentRpm(vehicle) > 0.9
            and GetEntitySpeed(vehicle) <= CUSTOM_WHEELIE_ARM_SPEED_THRESHOLD_METERS_PER_SECOND
        then
            wheelieStage = WheelieStage.active
            local baseForce = CUSTOM_WHEELIE_FORCE_MULTIPLIER
            wheelieForce = math.max(wheelieForce, baseForce)
        end
    end

    storeWheelieInputs(accelerationActive, brakeActive, handbrakeActive)

    if wheelieStage ~= WheelieStage.active then
        wheelieForce = 0.0
        return
    end

    local vehicleLength = getVehicleLength(vehicle)
    local frontOffset = CUSTOM_WHEELIE_FRONT_OFFSET_LENGTH_MULTIPLIER * vehicleLength
    local frameTime = CustomPhysicsUtil.getDeltaSeconds()

    local wheelSnapshot = CustomPhysicsUtil.buildWheelPowerSnapshot(vehicle)
    if not hasGroundedDrivenWheel(wheelSnapshot, vehicle) then
        wheelieForce = 0.0
        return
    end

    local pitchDeg = getSlopeRelativePitchDegrees(vehicle, vehicleLength)
    local pitchRate = -math.deg(GetEntityRotationVelocity(vehicle).y)
    local wheelPower = getClampedDrivenWheelPower(wheelSnapshot)
    local wheelPowerNorm = CustomPhysicsUtil.clamp(wheelPower / 0.9, 0.0, 1.0)
    local driveBiasFront = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fDriveBiasFront')
    local rearBiasMultiplier = CustomPhysicsUtil.clamp(1.0 - driveBiasFront, 0.0, 1.0)
    local targetPitchDeg = wheelPowerNorm * 40.0
    local proportionalGain = 0.5
    local forceRampRate = 1.0
    local pitchErr = targetPitchDeg - pitchDeg
    local targetRateDeg = pitchErr * proportionalGain
    local pitchRateErr = targetRateDeg - pitchRate
    local controlOut = pitchRateErr
    local targetForce = math.max(0.0, controlOut)

    if wheelieForce < targetForce then
        wheelieForce = math.min(targetForce, wheelieForce + (forceRampRate * frameTime))
    else
        wheelieForce = math.max(targetForce, wheelieForce - (forceRampRate * frameTime))
    end

    local wheelForce = wheelieForce * rearBiasMultiplier * frameTime
    local rearForce = wheelForce * 0.5

    -- Old wheelie force experiment kept here for later comparison.
    -- ApplyForceToEntity(vehicle, 1, 0.0, 0.0, wheelForce, 0.0, frontOffset, 0.0, 0, true, true, true, false, true)
    -- ApplyForceToEntity(vehicle, 1, 0.0, 0.0, -rearForce, 0.0, -frontOffset, 0.0, 0, true, true, true, false, true)

    ApplyForceToEntity(vehicle, 1, 0.0, -wheelForce, 0.0, 0.0, 0.0, frontOffset, 0, true, true, true, false, true)
    ApplyForceToEntity(vehicle, 1, 0.0, 0.0, wheelForce, 0.0, frontOffset, 0.0, 0, true, true, true, false, true)
end
