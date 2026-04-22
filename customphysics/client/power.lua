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

local function metersPerSecondSquaredToGs(value)
    return value / Units.metersPerSecondSquaredPerG
end

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
    rampStepPerSecond = 2.0,
    fallStepPerSecond = 100.0,
}

local Suspension = {
    stabilitySampleIntervalMs = 50,
}

local Overspeed = {
    minimumPowerMultiplier = 0.5,
    fallRatePerSecond = 0.2,
    recoveryRatePerSecond = 0.1,
    activationSpeedBufferMph = 10.0,
}

-- Alternative effect kept for later testing: 'ent_amb_smoke_general'

-- Requests the ptfx asset on startup and retries every 500 ms until it is confirmed loaded.
CreateThread(function()
    while not HasNamedPtfxAssetLoaded(EngineSmoke.ptfxAsset) do
        RequestNamedPtfxAsset(EngineSmoke.ptfxAsset)
        Wait(500)
    end
end)

local state = {
    offroadPowerMultiplier = 1.0,
    overspeedPowerMultiplier = 1.0,
    offroadTargetMultiplier = 1.0,
    antiBoostMultiplier = 1.0,
    antiBoostGearGuardUntil = 0,
    antiBoostLastGear = 0,
    lastPlanarSpeed = 0.0,
    lastStabilityVelocity = nil,
    lastStabilityForward = nil,
    lastStabilitySampleAt = 0,
    offroadUpdateAt = 0,
    lastDrivenWheelPower = 0.0,
    lastOffroadGear = 0,
    offroadShiftBlockedUntil = 0,
    lastDisparityGs = 0.0,
    lastAccelerationExcessGs = 0.0,
    lastMeasuredAccelerationGs = 0.0,
    lastDrivenWheelPowerSampleGs = 0.0,
    engineSmokeFx = nil,
    engineSmokeBone = -1,
}

CustomPhysicsPower.STABILITY_SAMPLE_INTERVAL_MS = Suspension.stabilitySampleIntervalMs

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
local function calculateSlideMultiplier(vehicle, forward, velocity)
    local slipAngle, planarSpeed = CustomPhysicsUtil.getPlanarAngleDegrees(forward, velocity)

    if planarSpeed < (CustomPhysics.Config.slideSpeedThresholdMetersPerSecond or 3.0) then
        return 1.0, slipAngle
    end

    local latTraction = GetVehicleHandlingFloat(vehicle, Handling.class, Handling.tractionCurveLateralField)
    local slideThreshold = latTraction * 0.1
    local overAngle = slipAngle - slideThreshold
    if overAngle <= 0.0 then
        return 1.0, slipAngle
    end

    local angleStep = CustomPhysics.Config.slideAngleStepDegrees or 10.0
    if angleStep <= 0.0 then
        angleStep = 10.0
    end

    local slideMultiplier = 1.0 + (overAngle / angleStep)
    local slideMaxMult = CustomPhysics.Config.slideMaxMultiplier or 10.0
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
        return
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
    local activationBufferMph = Overspeed.activationSpeedBufferMph or 10.0
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
        local drag = dragTable[material]
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
        local maxRisePerSecond = math.max(Offroad.rampStepPerSecond, 0.0)
        local maxRiseStep = maxRisePerSecond * updateDeltaSeconds
        state.offroadPowerMultiplier = math.min(
            state.offroadPowerMultiplier + maxRiseStep,
            state.offroadTargetMultiplier
        )
    elseif state.offroadPowerMultiplier > state.offroadTargetMultiplier then
        local maxFallPerSecond = math.max(Offroad.fallStepPerSecond, 0.0)
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
    if not GetConvarBool('cp_offroad_boost_enabled', true) then
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
    local offroadMaxMultiplier = tonumber(GetConvar('cp_offroad_max_multiplier', '5.0')) or 5.0
    offroadMaxMultiplier = math.max(1.0, offroadMaxMultiplier)
    state.offroadTargetMultiplier = calculateOffroadTargetMultiplier(snapshot, now, offroadMaxMultiplier)
    return advanceOffroadMultiplier(updateDeltaSeconds, offroadMaxMultiplier)
end

-- Returns true when at least one driven wheel is on a drag-enabled material.
local function hasDrivenWheelOnDragSurface(vehicle, wheelSnapshot)
    local wheelCount = wheelSnapshot and wheelSnapshot.wheelCount or 0
    if wheelCount <= 0 then
        return false
    end

    local wheelPowers = wheelSnapshot.wheelPowers or {}
    local dragTable = CustomPhysics.Config.materialTyreDragByIndex or {}

    for wheelIndex = 0, wheelCount - 1 do
        local wheelPower = wheelPowers[wheelIndex] or 0.0
        if wheelPower > 0.0001 then
            local material = GetVehicleWheelSurfaceMaterial(vehicle, wheelIndex)
            local drag = dragTable[material] or 0.0
            if drag > 0.0 then
                return true
            end
        end
    end

    return false
end

-- Stability monitor
-- Samples forward acceleration and wheel power every tick, shows both and their disparity as a subtitle.

local AntiBoost = {
    disparityThreshold = 0.33,
    slideAngleGuardDegrees = 10.0,
    gearGuardMs = 500,
    -- ceiling = (1 + disparityThreshold) - (disparityGs * gsCalibration)
    gsCalibration = 9.81 * 2,
    ceilingMin = -0.1,
    dragSurfaceCeilingMin = 0.8,
}

-- Returns true when the anti-boost ceiling should be applied given the current conditions.
local function shouldApplyAntiBoost(disparityGs, slideAngle, gear, now)
    return disparityGs > AntiBoost.disparityThreshold
        and gear > 1
        and now >= state.antiBoostGearGuardUntil
        and slideAngle <= AntiBoost.slideAngleGuardDegrees
end

function CustomPhysicsPower.sampleStability(vehicle, now)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return
    end

    local currentVelocity = GetEntityVelocity(vehicle)
    local currentForward  = GetEntityForwardVector(vehicle)

    if state.lastStabilitySampleAt <= 0 then
        state.lastStabilityVelocity = currentVelocity
        state.lastStabilityForward  = currentForward
        state.lastStabilitySampleAt = now
        return
    end

    local deltaSeconds = math.max((now - state.lastStabilitySampleAt) / 1000.0, 0.000001)
    local lastVelocity = state.lastStabilityVelocity or currentVelocity
    -- Use the forward vector cached at the start of the interval so the projection
    -- reflects the car's heading when the velocity delta began, not where it ended up.
    local lastForward  = state.lastStabilityForward or currentForward
    local rawAccel = (
        ((currentVelocity.x - lastVelocity.x) * lastForward.x) +
        ((currentVelocity.y - lastVelocity.y) * lastForward.y) +
        ((currentVelocity.z - lastVelocity.z) * lastForward.z)
    ) / deltaSeconds

    local wheelSnapshot          = CustomPhysicsUtil.buildWheelPowerSnapshot(vehicle)
    local measuredGs             = metersPerSecondSquaredToGs(rawAccel)
    local wheelPowerGs           = wheelSnapshot.drivenWheelPower or 0.0
    local disparityGs            = measuredGs - wheelPowerGs
    local drivenWheelOnDragSurface = hasDrivenWheelOnDragSurface(vehicle, wheelSnapshot)

    state.lastMeasuredAccelerationGs   = measuredGs
    state.lastDrivenWheelPowerSampleGs = wheelPowerGs
    state.lastAccelerationExcessGs     = disparityGs

    local currentGear = GetVehicleCurrentGear(vehicle)
    if currentGear ~= state.antiBoostLastGear then
        state.antiBoostLastGear       = currentGear
        state.antiBoostGearGuardUntil = now + AntiBoost.gearGuardMs
    end

    -- Reuse the forward/velocity already read above for the slide angle check.
    local slideAngle = select(1, CustomPhysicsUtil.getPlanarAngleDegrees(currentForward, currentVelocity))

    if shouldApplyAntiBoost(disparityGs, slideAngle, currentGear, now) then
        local ceiling = math.max(
            (1 + AntiBoost.disparityThreshold) - (disparityGs * AntiBoost.gsCalibration),
            AntiBoost.ceilingMin
        )
        if drivenWheelOnDragSurface then
            ceiling = math.max(ceiling, AntiBoost.dragSurfaceCeilingMin)
        end
        state.antiBoostMultiplier = ceiling
    end

    state.lastDisparityGs       = disparityGs
    state.lastStabilityVelocity = currentVelocity
    state.lastStabilityForward  = currentForward
    state.lastStabilitySampleAt = now
end

-- Advances the anti-boost multiplier toward 1.0 at 1.0 per second.
function CustomPhysicsPower.recoverAntiBoost(deltaSeconds)
    state.antiBoostMultiplier = math.min(1.0, state.antiBoostMultiplier + (deltaSeconds*3))
end

-- Public subsystem API

-- Builds the full cheat-power multiplier stack for the current update.
local function updatePowerMultiplierStack(vehicle, now)
    local snapshot = buildVehicleUpdateSnapshot(vehicle)
    local forward  = GetEntityForwardVector(vehicle)
    local velocity = GetEntityVelocity(vehicle)
    local slideMultiplier, _ = calculateSlideMultiplier(vehicle, forward, velocity)
    local offroadMultiplier = getOffroadMultiplier(snapshot, now)
    SetVehicleCheatPowerIncrease(vehicle, slideMultiplier * offroadMultiplier * state.overspeedPowerMultiplier * state.antiBoostMultiplier)

    if GetConvarInt('cPhysicsPrintLevel', 0) == 2 then
        local atFull = state.antiBoostMultiplier >= 1.0
        local r, g, b = 255, atFull and 255 or 0, atFull and 255 or 0
        SetTextFont(0)
        SetTextScale(1.2, 1.2)
        SetTextColour(r, g, b, 255)
        SetTextCentre(true)
        SetTextDropshadow(50, 0, 0, 0, 255)
        BeginTextCommandDisplayText('STRING')
        AddTextComponentString(('%.1f'):format(state.antiBoostMultiplier))
        EndTextCommandDisplayText(0.5, 0.333)
    end
end

-- Runs all power-related subsystems for the current vehicle update.
function CustomPhysicsPower.update(vehicle, now)
    updateOverspeedPower(vehicle, GetVehicleCurrentRpm(vehicle))
    updatePowerMultiplierStack(vehicle, now)
end

function CustomPhysicsPower.getDebugSnapshot()
    return {
        measuredAccelerationGs  = state.lastMeasuredAccelerationGs or 0.0,
        drivenWheelPowerGs      = state.lastDrivenWheelPowerSampleGs or 0.0,
        accelerationExcessGs    = state.lastAccelerationExcessGs or 0.0,
        offroadPowerMultiplier  = state.offroadPowerMultiplier or 1.0,
        overspeedPowerMultiplier = state.overspeedPowerMultiplier or 1.0,
        antiBoostMultiplier     = state.antiBoostMultiplier or 1.0,
    }
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
    state.lastPlanarSpeed = 0.0
    state.lastStabilityVelocity = nil
    state.lastStabilitySampleAt = 0
    state.offroadUpdateAt = 0
    state.lastDrivenWheelPower = 0.0
    state.lastOffroadGear = 0
    state.offroadShiftBlockedUntil = 0
    state.lastAccelerationExcessGs = 0.0
    state.lastMeasuredAccelerationGs = 0.0
    state.lastDrivenWheelPowerSampleGs = 0.0
end
