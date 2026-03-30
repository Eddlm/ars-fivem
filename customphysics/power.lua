CustomPhysicsPower = CustomPhysicsPower or {}

local Handling = {
    class = 'CHandlingData',
    tractionCurveLateralField = 'fTractionCurveLateral',
    initialDriveMaxFlatVelocityField = 'fInitialDriveMaxFlatVel',
}

local StateBagKeys = {
    handling = 'performancetuning:handlingState',
    tune = 'performancetuning:tuneState',
}

local Units = {
    flatVelToMph = 145.0 / 176.0,
    metersPerSecondToMph = 2.2369362921,
    metersPerSecondSquaredPerG = 9.81,
}

local EngineSmoke = {
    ptfxAsset = 'core',
    ptfxName = 'veh_plane_damage',
    bones = { 'engine', 'engine_l', 'engine_r', 'bonnet' },
}

local Offroad = {
    updateIntervalMs = 100,
    shiftBlockDurationMs = 350,
    targetAccelerationToPowerFactor = 0.5,
    accelerationToPowerFactorCap = 2.0,
    minimumAccelerationToPowerFactor = 0.01,
}

local Suspension = {
    penaltyRecoveryPerSecond = 4.0,
}

local RevLimiter = {
    accelDisableDurationMs = 10,
}

local Overspeed = {
    minimumPowerMultiplier = 0.5,
    fallRatePerSecond = 0.2,
    recoveryRatePerSecond = 0.1,
    activationSpeedBufferMph = 10.0,
}

-- Alternative effect kept for later testing: 'ent_amb_smoke_general'

local state = {
    accelDisabledAt = 0,
    offroadPowerMultiplier = 1.0,
    overspeedPowerMultiplier = 1.0,
    offroadTargetMultiplier = 1.0,
    antiBoostMultiplier = 1.0,
    lastRpm = 0.0,
    lastPlanarSpeed = 0.0,
    offroadUpdateAt = 0,
    lastDrivenWheelPower = 0.0,
    lastOffroadGear = 0,
    offroadShiftBlockedUntil = 0,
    lastAccelerationToPowerFactor = 0.0,
    engineSmokeFx = nil,
    engineSmokeBone = -1,
}

-- Snapshot helpers

-- Returns planar acceleration in Gs using the last cached planar speed.
local function getPlanarAcceleration(vehicle)
    local currentPlanarSpeed = CustomPhysicsUtil.getVehiclePlanarSpeed(vehicle)
    local deltaSeconds = math.max(CustomPhysicsUtil.getDeltaSeconds(), 0.000001)
    local planarAcceleration = (currentPlanarSpeed - state.lastPlanarSpeed) / deltaSeconds
    state.lastPlanarSpeed = currentPlanarSpeed
    return planarAcceleration / Units.metersPerSecondSquaredPerG
end

-- Collects the shared per-update vehicle inputs used across power subsystems.
local function buildVehicleUpdateSnapshot(vehicle)
    local wheelSnapshot = CustomPhysicsUtil.buildWheelPowerSnapshot(vehicle)

    return {
        vehicle = vehicle,
        currentRpm = GetVehicleCurrentRpm(vehicle),
        planarAcceleration = getPlanarAcceleration(vehicle),
        currentGear = GetVehicleCurrentGear(vehicle),
        highGear = math.max(GetVehicleHighGear(vehicle) or 0, 0),
        clutch = GetVehicleClutch(vehicle),
        wheelSnapshot = wheelSnapshot,
    }
end

-- General power-stack helpers

-- Computes the slide multiplier from slip angle relative to the handling traction baseline.
local function calculateSlideMultiplier(vehicle)
    local forward = GetEntityForwardVector(vehicle)
    local velocity = GetEntityVelocity(vehicle)
    local slipAngle, planarSpeed = CustomPhysicsUtil.getPlanarAngleDegrees(forward, velocity)

    if planarSpeed < (CustomPhysics.Config.slideSpeedThreshold or 3.0) then
        return 1.0, slipAngle
    end

    local latTraction = GetVehicleHandlingFloat(vehicle, Handling.class, Handling.tractionCurveLateralField)
    local slideThreshold = latTraction * 0.1
    local overAngle = slipAngle - slideThreshold
    if overAngle <= 0.0 then
        return 1.0, slipAngle
    end

    local angleStep = tonumber(CustomPhysics.Config.slideAngleStepDegrees) or 10.0
    if angleStep <= 0.0 then
        angleStep = 10.0
    end

    local slideMultiplier = 1.0 + (overAngle / angleStep)
    local slideMaxMult = tonumber(CustomPhysics.Config.slideMaxMultiplier) or 10.0
    return CustomPhysicsUtil.clamp(slideMultiplier, 1.0, slideMaxMult), slipAngle
end

-- Reads the current handling top speed value from the live vehicle.
local function getFlatVelocity(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil
    end

    local flatVel = GetVehicleHandlingFloat(vehicle, Handling.class, Handling.initialDriveMaxFlatVelocityField)
    return flatVel > 0.0 and flatVel or nil
end

-- Reads the original handling top speed from performancetuning state when available.
local function getOriginalFlatVelocity(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil
    end

    if NetworkGetEntityIsNetworked(vehicle) then
        local handlingState = Entity(vehicle).state[StateBagKeys.handling]
        local original = type(handlingState) == 'table' and handlingState.original or nil
        local engineState = type(original) == 'table' and original.engine or nil
        local flatVel = type(engineState) == 'table' and tonumber(engineState[Handling.initialDriveMaxFlatVelocityField]) or nil
        if flatVel and flatVel > 0.0 then
            return flatVel
        end
    end

    return nil
end

-- Overspeed limiter helpers

-- Stops the overspeed smoke effect and clears its cached handle.
local function stopEngineSmokeEffect()
    if state.engineSmokeFx then
        StopParticleFxLooped(state.engineSmokeFx, false)
        state.engineSmokeFx = nil
    end
    state.engineSmokeBone = -1
end

-- Finds and caches a valid engine-area bone for the overspeed smoke effect.
local function getEngineSmokeBoneIndex(vehicle)
    if state.engineSmokeBone and state.engineSmokeBone >= 0 then
        return state.engineSmokeBone
    end

    for index = 1, #EngineSmoke.bones do
        local boneIndex = GetEntityBoneIndexByName(vehicle, EngineSmoke.bones[index])
        if boneIndex and boneIndex ~= -1 then
            state.engineSmokeBone = boneIndex
            return boneIndex
        end
    end

    state.engineSmokeBone = -1
    return -1
end

-- Starts the overspeed smoke effect if it is not already running.
local function ensureEngineSmokeEffect(vehicle)
    local boneIndex = getEngineSmokeBoneIndex(vehicle)
    if boneIndex == -1 then
        stopEngineSmokeEffect()
        return
    end

    if state.engineSmokeFx then
        return
    end

    if not HasNamedPtfxAssetLoaded(EngineSmoke.ptfxAsset) then
        RequestNamedPtfxAsset(EngineSmoke.ptfxAsset)
        if not HasNamedPtfxAssetLoaded(EngineSmoke.ptfxAsset) then
            return
        end
    end

    UseParticleFxAssetNextCall(EngineSmoke.ptfxAsset)
    state.engineSmokeFx = StartParticleFxLoopedOnEntityBone(
        EngineSmoke.ptfxName,
        vehicle,
        0.0, 0.0, -0.2,
        0.0, 0.0, 0.0,
        boneIndex,
        1.3,
        false, false, false
    )
end

-- Updates the overspeed limiter multiplier and its smoke feedback.
local function updateOverspeedPower(vehicle, currentRpm)
    local currentSpeedMph = CustomPhysicsUtil.getVehiclePlanarSpeed(vehicle) * Units.metersPerSecondToMph
    local topSpeedFlatVel = getFlatVelocity(vehicle) or getOriginalFlatVelocity(vehicle) or 0.0
    local topSpeedMph = topSpeedFlatVel * Units.flatVelToMph
    local activationBufferMph = tonumber(Overspeed.activationSpeedBufferMph) or 10.0
    local overspeedThresholdMph = topSpeedMph + math.max(0.0, activationBufferMph)
    local overspeedActive = topSpeedMph > 0.0 and currentSpeedMph >= overspeedThresholdMph and currentRpm >= 1.0
    local deltaSeconds = CustomPhysicsUtil.getDeltaSeconds()

    if overspeedActive then
        state.overspeedPowerMultiplier = math.max(
            Overspeed.minimumPowerMultiplier,
            state.overspeedPowerMultiplier - (Overspeed.fallRatePerSecond * deltaSeconds)
        )
    else
        state.overspeedPowerMultiplier = math.min(1.0, state.overspeedPowerMultiplier + (Overspeed.recoveryRatePerSecond * deltaSeconds))
    end

    if state.overspeedPowerMultiplier < 1.0 then
        ensureEngineSmokeEffect(vehicle)
    else
        stopEngineSmokeEffect()
    end
end

-- Offroad helpers

-- Counts how many wheels are on materials configured to add tire drag.
local function getOffroadSurfaceWheelCount(vehicle, wheelCount)
    local offroadWheelCount = 0
    local dragTable = CustomPhysics.Config.materialTyreDragByIndex or {}

    for wheelIndex = 0, wheelCount - 1 do
        local material = GetVehicleWheelSurfaceMaterial(vehicle, wheelIndex)
        local drag = tonumber(dragTable[material])
        if drag == nil then
            drag = 0.0
        end
        if drag > 0.0 then
            offroadWheelCount = offroadWheelCount + 1
        end
    end

    return offroadWheelCount
end

-- Starts a short offroad recalculation block when the transmission changes gear.
local function updateOffroadShiftBlock(currentGear, now)
    if currentGear ~= state.lastOffroadGear then
        state.lastOffroadGear = currentGear
        state.offroadShiftBlockedUntil = now + Offroad.shiftBlockDurationMs
    end
end

-- Reuses the last nonzero driven wheel power during brief zero-power moments.
local function getUsableDrivenWheelPower(rawDrivenWheelPower)
    if rawDrivenWheelPower > 0.000001 then
        state.lastDrivenWheelPower = rawDrivenWheelPower
        return rawDrivenWheelPower
    end

    return state.lastDrivenWheelPower
end

-- Calculates the offroad target multiplier from wheel drag state and acceleration mismatch.
local function calculateOffroadTargetMultiplier(snapshot, now, offroadMaxMultiplier)
    local wheelCount = snapshot.wheelSnapshot and snapshot.wheelSnapshot.wheelCount or 0
    local rawDrivenWheelPower = snapshot.wheelSnapshot and snapshot.wheelSnapshot.drivenWheelPower or 0.0
    local drivenWheelPower = getUsableDrivenWheelPower(rawDrivenWheelPower)
    local currentGear = snapshot.currentGear or 0
    local clutch = snapshot.clutch or 1.0
    local offroadWheelCount = getOffroadSurfaceWheelCount(snapshot.vehicle, wheelCount)

    updateOffroadShiftBlock(currentGear, now)

    if wheelCount <= 0 or offroadWheelCount ~= wheelCount or currentGear <= 0 then
        return 1.0
    end

    local offroadShiftBlocked = clutch < 0.95 or now < state.offroadShiftBlockedUntil
    if rawDrivenWheelPower <= 0.000001 or offroadShiftBlocked then
        return state.offroadPowerMultiplier
    end

    if drivenWheelPower <= 0.000001 then
        return 1.0
    end

    local accelerationToPowerFactor = CustomPhysicsUtil.clamp(
        math.max(0.0, snapshot.planarAcceleration) / drivenWheelPower,
        0.0,
        Offroad.accelerationToPowerFactorCap
    )

    if accelerationToPowerFactor >= Offroad.targetAccelerationToPowerFactor then
        return 1.0
    end

    local safeAccelerationToPowerFactor = math.max(accelerationToPowerFactor, Offroad.minimumAccelerationToPowerFactor)
    local rawTargetMultiplier = Offroad.targetAccelerationToPowerFactor / safeAccelerationToPowerFactor
    return CustomPhysicsUtil.clamp(rawTargetMultiplier, 1.0, offroadMaxMultiplier)
end

-- Moves the live offroad multiplier toward its current target at configured rise and fall rates.
local function advanceOffroadMultiplier(updateDeltaSeconds, offroadMaxMultiplier)
    if state.offroadPowerMultiplier < state.offroadTargetMultiplier then
        local maxRisePerSecond = math.max(tonumber(CustomPhysics.Config.offroadRampStep) or 0.5, 0.0)
        local maxRiseStep = maxRisePerSecond * updateDeltaSeconds
        state.offroadPowerMultiplier = math.min(
            state.offroadPowerMultiplier + maxRiseStep,
            state.offroadTargetMultiplier
        )
    elseif state.offroadPowerMultiplier > state.offroadTargetMultiplier then
        local maxFallPerSecond = math.max(tonumber(CustomPhysics.Config.offroadFallStep) or 100.0, 0.0)
        local maxFallStep = maxFallPerSecond * updateDeltaSeconds
        state.offroadPowerMultiplier = math.max(
            state.offroadPowerMultiplier - maxFallStep,
            state.offroadTargetMultiplier
        )
    else
        state.offroadPowerMultiplier = state.offroadTargetMultiplier
    end

    state.offroadPowerMultiplier = CustomPhysicsUtil.clamp(state.offroadPowerMultiplier, 1.0, offroadMaxMultiplier)
    return state.offroadPowerMultiplier
end

-- Updates the offroad multiplier on its own interval and returns the current live value.
local function getOffroadMultiplier(snapshot, now)
    if CustomPhysics.Config.offroadBoostEnabled == false then
        state.offroadPowerMultiplier = 1.0
        state.offroadTargetMultiplier = 1.0
        return 1.0
    end

    local intervalMs = Offroad.updateIntervalMs
    if intervalMs < 0 then
        intervalMs = 250
    end

    if state.offroadUpdateAt > now then
        return state.offroadPowerMultiplier
    end

    state.offroadUpdateAt = now + intervalMs
    local updateDeltaSeconds = intervalMs / 1000.0
    state.offroadTargetMultiplier = 1.0
    local offroadMaxMultiplier = tonumber(CustomPhysics.Config.offroadMaxMultiplier) or 4.0
    state.offroadTargetMultiplier = calculateOffroadTargetMultiplier(snapshot, now, offroadMaxMultiplier)
    return advanceOffroadMultiplier(updateDeltaSeconds, offroadMaxMultiplier)
end

-- Suspension penalty helpers

-- Applies the acceleration-vs-wheel-power penalty portion of the suspension system.
local function applyAccelerationFactorPenalty(planarAcceleration, drivenWheelPower)
    if drivenWheelPower > 0.000001 then
        state.lastAccelerationToPowerFactor = math.max(0.0, planarAcceleration) / drivenWheelPower
    else
        state.lastAccelerationToPowerFactor = 0.0
    end

    local factorPenalty = CustomPhysicsUtil.mapValue(state.lastAccelerationToPowerFactor, 1.5, 2.0, 0.0, 1.0, true)
    state.antiBoostMultiplier = state.antiBoostMultiplier - factorPenalty
end

-- Gradually restores the suspension penalty multiplier back toward normal.
local function recoverSuspensionPenalty()
    if state.antiBoostMultiplier < 1.0 then
        state.antiBoostMultiplier = state.antiBoostMultiplier + (Suspension.penaltyRecoveryPerSecond * CustomPhysicsUtil.getDeltaSeconds())
    end

    state.antiBoostMultiplier = CustomPhysicsUtil.clamp(state.antiBoostMultiplier, 0.1, 1.0)
end

-- Computes the current suspension penalty multiplier and its recovery behavior.
local function getSuspensionPenalty(vehicle, snapshot, slideAngle)
    local penaltyStrength = tonumber(CustomPhysics.Config.suspensionBoostPenaltyStrength) or 0
    if penaltyStrength <= 0 then
        state.lastRpm = snapshot.currentRpm
        state.antiBoostMultiplier = 1.0
        state.lastAccelerationToPowerFactor = 0.0
        return 1.0
    end

    local drivenWheelPower = snapshot.wheelSnapshot and snapshot.wheelSnapshot.drivenWheelPower or 0.0
    applyAccelerationFactorPenalty(snapshot.planarAcceleration, drivenWheelPower)

    state.lastRpm = snapshot.currentRpm
    recoverSuspensionPenalty()
    if math.abs(slideAngle or 0.0) < 10.0 then
        return state.antiBoostMultiplier
    end

    return 1.0
end

-- Rev limiter helpers

-- Disables throttle input briefly when the rev limiter conditions are active.
local function updateRpmLimiter(vehicle, now)
    local limiterEnabled = CustomPhysics.Config.fallbackRevLimiterEnabled == true
    if NetworkGetEntityIsNetworked(vehicle) then
        local tuneState = Entity(vehicle).state[StateBagKeys.tune]
        if type(tuneState) == 'table' then
            limiterEnabled = tuneState.revLimiterEnabled == true
        end
    end

    if limiterEnabled ~= true then
        state.accelDisabledAt = 0
        return
    end

    local currentGear = GetVehicleCurrentGear(vehicle)
    local highGear = math.max(GetVehicleHighGear(vehicle) or 0, 0)
    local currentRpm = GetVehicleCurrentRpm(vehicle)
    local planarSpeed = CustomPhysicsUtil.getVehiclePlanarSpeed(vehicle)
    local moving = (planarSpeed * Units.metersPerSecondToMph) > 1.0
    local validGear = currentGear >= 1 and (highGear <= 1 or currentGear < highGear)

    if moving and validGear and currentRpm >= 1.0 then
        state.accelDisabledAt = now + RevLimiter.accelDisableDurationMs
    end

    if now < state.accelDisabledAt then
        DisableControlAction(0, 71, true)
        DisableControlAction(2, 71, true)
    end
end

-- Public subsystem API

-- Builds the full cheat-power multiplier stack for the current update.
local function updatePowerMultiplierStack(vehicle, now)
    local snapshot = buildVehicleUpdateSnapshot(vehicle)
    local slideMultiplier, slideAngle = calculateSlideMultiplier(vehicle)
    local offroadMultiplier = getOffroadMultiplier(snapshot, now)
    local suspensionPenalty = getSuspensionPenalty(vehicle, snapshot, slideAngle or 0.0)

    SetVehicleCheatPowerIncrease(vehicle, slideMultiplier * offroadMultiplier * suspensionPenalty * state.overspeedPowerMultiplier)
end

-- Runs all power-related subsystems for the current vehicle update.
function CustomPhysicsPower.update(vehicle, now)
    updateRpmLimiter(vehicle, now)
    updateOverspeedPower(vehicle, GetVehicleCurrentRpm(vehicle))
    updatePowerMultiplierStack(vehicle, now)
end

-- Clears all cached power state and restores default vehicle power when possible.
function CustomPhysicsPower.reset(vehicle)
    stopEngineSmokeEffect()

    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        SetVehicleCheatPowerIncrease(vehicle, 1.0)
    end

    state.accelDisabledAt = 0
    state.offroadPowerMultiplier = 1.0
    state.overspeedPowerMultiplier = 1.0
    state.offroadTargetMultiplier = 1.0
    state.antiBoostMultiplier = 1.0
    state.lastRpm = 0.0
    state.lastPlanarSpeed = 0.0
    state.offroadUpdateAt = 0
    state.lastDrivenWheelPower = 0.0
    state.lastOffroadGear = 0
    state.offroadShiftBlockedUntil = 0
    state.lastAccelerationToPowerFactor = 0.0
end
