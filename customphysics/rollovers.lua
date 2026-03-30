CustomPhysicsRollovers = CustomPhysicsRollovers or {}

local ROLLOVER_ANGULAR_XY_THRESHOLD_DEGREES = 180.0
local ROLLOVER_ANGULAR_Z_THRESHOLD_DEGREES = 180.0
local ROLLOVER_CHECK_INTERVAL_MS = 300
local ROLLOVER_FORCE_HEIGHT_OFFSET = 4.0
local ROLLOVER_FORCE_MAGNITUDE = 1.4
local ROLLOVER_SETTLE_DURATION_MS = 500
local ROLLOVER_INITIAL_FORCE_MULTIPLIER = 3.0

local forceActive = false
local forceStartedAt = 0
local cache = {
    nextCheckAt = 0,
    speed = 0.0,
    forwardSpeedRatio = 1.0,
    inAir = false,
    onAllWheels = false,
    unstableTriggerActive = false,
    angularTriggerActive = false,
    lastHitMaterial = 0,
}

-- Physics helpers

-- Returns full 3D speed along with the original velocity components.
local function getVelocityMagnitude(velocity)
    local velocityX = velocity.x
    local velocityY = velocity.y
    local velocityZ = velocity.z
    return math.sqrt((velocityX * velocityX) + (velocityY * velocityY) + (velocityZ * velocityZ)), velocityX, velocityY, velocityZ
end

-- Cached rollover checks

-- Refreshes cached rollover trigger data on a slower interval to save per-frame work.
local function refreshRolloverChecks(vehicle, now)
    cache.nextCheckAt = now + ROLLOVER_CHECK_INTERVAL_MS

    local velocity = GetEntityVelocity(vehicle)
    cache.speed = getVelocityMagnitude(velocity)

    cache.inAir = IsEntityInAir(vehicle)
    cache.onAllWheels = IsVehicleOnAllWheels(vehicle)

    cache.forwardSpeedRatio = cache.speed > 0.0001 and (math.abs(GetEntitySpeedVector(vehicle, true).y) / cache.speed) or 0.0

    local rotationVelocity = GetEntityRotationVelocity(vehicle)
    local rollRateDeg = math.abs(math.deg(rotationVelocity.x))
    local pitchRateDeg = math.abs(math.deg(rotationVelocity.y))
    local yawRateDeg = math.abs(math.deg(rotationVelocity.z))

    cache.unstableTriggerActive = not cache.inAir and not cache.onAllWheels and cache.forwardSpeedRatio <= 0.5
    cache.angularTriggerActive = rollRateDeg > ROLLOVER_ANGULAR_XY_THRESHOLD_DEGREES
        or pitchRateDeg > ROLLOVER_ANGULAR_XY_THRESHOLD_DEGREES
        or yawRateDeg > ROLLOVER_ANGULAR_Z_THRESHOLD_DEGREES
    cache.lastHitMaterial = GetLastMaterialHitByEntity(vehicle)
end

-- Public subsystem API

-- Resets rollover force state and the cached trigger snapshot.
function CustomPhysicsRollovers.reset()
    forceActive = false
    forceStartedAt = 0
    cache = {
        nextCheckAt = 0,
        speed = 0.0,
        forwardSpeedRatio = 1.0,
        inAir = false,
        onAllWheels = false,
        unstableTriggerActive = false,
        angularTriggerActive = false,
        lastHitMaterial = 0,
    }
end

-- Applies rollover recovery force when the cached trigger conditions say the vehicle is unstable.
function CustomPhysicsRollovers.update(vehicle)
    if CustomPhysics.Config.rolloversEnabled ~= true then
        CustomPhysicsRollovers.reset()
        return
    end

    local now = GetGameTimer()
    if cache.nextCheckAt <= 0 or now >= cache.nextCheckAt then
        refreshRolloverChecks(vehicle, now)
    end

    if cache.speed < 4.0 then
        forceActive = false
        forceStartedAt = 0
        return
    end

    if not forceActive and not cache.inAir and (cache.unstableTriggerActive or (cache.forwardSpeedRatio <= 0.5 and cache.angularTriggerActive)) then
        forceActive = true
        forceStartedAt = now
    end

    if not forceActive then
        return
    end

    local elapsedMs = math.max(0, now - forceStartedAt)
    local velocity = GetEntityVelocity(vehicle)
    local speed, velocityX, velocityY, velocityZ = getVelocityMagnitude(velocity)
    if speed <= 0.0001 then
        return
    end

    local frameTime = GetFrameTime()
    if frameTime <= 0.000001 then
        frameTime = 1.0 / 60.0
    end

    local settleProgress = CustomPhysicsUtil.clamp(elapsedMs / ROLLOVER_SETTLE_DURATION_MS, 0.0, 1.0)
    local forceMultiplier = ROLLOVER_INITIAL_FORCE_MULTIPLIER - ((ROLLOVER_INITIAL_FORCE_MULTIPLIER - 1.0) * settleProgress)
    local hitBoostActive = elapsedMs >= ROLLOVER_SETTLE_DURATION_MS and cache.lastHitMaterial > 0
    if hitBoostActive then
        forceMultiplier = forceMultiplier * 2.0
    end

    local forceMagnitude = ROLLOVER_FORCE_MAGNITUDE * forceMultiplier
    local forceScale = forceMagnitude * frameTime
    local forceX = (velocityX / speed) * forceScale
    local forceY = (velocityY / speed) * forceScale
    local forceZ = (velocityZ / speed) * forceScale

    if cache.onAllWheels then
        ApplyForceToEntity(vehicle, 1, forceX, forceY, forceZ, 0.0, 0.0, 0.0, 0, false, false, true, false, true)
    else
        ApplyForceToEntity(vehicle, 1, forceX, forceY, forceZ, 0.0, 0.0, ROLLOVER_FORCE_HEIGHT_OFFSET, 0, false, false, true, false, true)
    end
end
