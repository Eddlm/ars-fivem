CustomPhysicsUtil = CustomPhysicsUtil or {}

-- Basic math helpers

-- Restricts a value to the given minimum and maximum bounds.
function CustomPhysicsUtil.clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
end

-- Remaps a value from one range into another with optional output clamping.
function CustomPhysicsUtil.mapValue(x, inMin, inMax, outMin, outMax, doClamp)
    local denominator = inMax - inMin
    if math.abs(denominator) <= 0.000001 then
        return doClamp and CustomPhysicsUtil.clamp(outMin, math.min(outMin, outMax), math.max(outMin, outMax)) or outMin
    end

    local value = (((x - inMin) * (outMax - outMin)) / denominator) + outMin
    if doClamp then
        local minimum = math.min(outMin, outMax)
        local maximum = math.max(outMin, outMax)
        value = CustomPhysicsUtil.clamp(value, minimum, maximum)
    end

    return value
end

-- Frame timing helpers

-- Returns the current frame time in seconds with a safe fallback.
function CustomPhysicsUtil.getDeltaSeconds()
    local frameTime = GetFrameTime()
    if frameTime <= 0.000001 then
        return 1.0 / 60.0
    end

    return frameTime
end

-- Displays a short subtitle/debug message using the standard text command pipeline.
function CustomPhysicsUtil.showSubtitle(text, durationMs)
    BeginTextCommandPrint("STRING")
    AddTextComponentSubstringPlayerName(tostring(text or ""))
    EndTextCommandPrint(math.max(0, math.floor(tonumber(durationMs) or 2000)), true)
end

-- Vehicle motion helpers

-- Returns the planar angle between forward direction and velocity plus planar speed magnitude.
function CustomPhysicsUtil.getPlanarAngleDegrees(forward, velocity)
    local forwardX = forward.x
    local forwardY = forward.y
    local velocityX = velocity.x
    local velocityY = velocity.y

    local forwardLength = math.sqrt((forwardX * forwardX) + (forwardY * forwardY))
    local velocityLength = math.sqrt((velocityX * velocityX) + (velocityY * velocityY))
    if forwardLength <= 0.0001 or velocityLength <= 0.0001 then
        return 0.0, velocityLength
    end

    forwardX = forwardX / forwardLength
    forwardY = forwardY / forwardLength
    velocityX = velocityX / velocityLength
    velocityY = velocityY / velocityLength

    local dot = CustomPhysicsUtil.clamp((forwardX * velocityX) + (forwardY * velocityY), -1.0, 1.0)
    local angle = math.deg(math.acos(dot))
    return angle, velocityLength
end

-- Returns the vehicle's horizontal speed without vertical motion.
function CustomPhysicsUtil.getVehiclePlanarSpeed(vehicle)
    local velocity = GetEntityVelocity(vehicle)
    local velocityX = velocity.x
    local velocityY = velocity.y
    return math.sqrt((velocityX * velocityX) + (velocityY * velocityY))
end

-- Vehicle snapshot helpers

-- Returns the full 3D speed of an entity as a scalar.
function CustomPhysicsUtil.getEntitySpeed3D(vehicle)
    return GetEntitySpeed(vehicle)
end

-- Collects the common per-frame vehicle reads used across power, wheelies, and rollover subsystems.
function CustomPhysicsUtil.buildVehicleSnapshot(vehicle)
    local forward  = GetEntityForwardVector(vehicle)
    local velocity = GetEntityVelocity(vehicle)
    local vx, vy  = velocity.x, velocity.y
    local planarSpeed = math.sqrt((vx * vx) + (vy * vy))

    return {
        forward  = forward,
        velocity = velocity,
        speed    = planarSpeed,
        speed3D  = GetEntitySpeed(vehicle),
        gear     = GetVehicleCurrentGear(vehicle),
        rpm      = GetVehicleCurrentRpm(vehicle),
        inAir    = IsEntityInAir(vehicle),
        onWheels = IsVehicleOnAllWheels(vehicle),
        wheels   = CustomPhysicsUtil.buildWheelPowerSnapshot(vehicle),
    }
end

-- Wheel power helpers

-- Collects wheel count, per-wheel power, and total driven wheel power for one vehicle snapshot.
function CustomPhysicsUtil.buildWheelPowerSnapshot(vehicle)
    local wheelCount = GetVehicleNumberOfWheels(vehicle)
    local drivenWheelPower = 0.0
    local wheelPowers = {}

    for wheelIndex = 0, wheelCount  do
        local wheelPower = GetVehicleWheelPower(vehicle, wheelIndex)
        wheelPowers[wheelIndex] = wheelPower
        drivenWheelPower = drivenWheelPower + wheelPower
    end

    return {
        wheelCount = wheelCount,
        wheelPowers = wheelPowers,
        drivenWheelPower = drivenWheelPower,
    }
end

