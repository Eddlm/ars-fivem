CustomPhysicsRollovers = CustomPhysicsRollovers or {}
local RolloverConfig = (((CustomPhysics or {}).Config or {}).advanced or {}).rollovers or {}

local ROLLOVER_START_SPEED = tonumber(GetConvar('cp_rollover_start_speed', tostring(RolloverConfig.startSpeedMs  or 8.94)))
local ROLLOVER_KEEP_SPEED  = tonumber(GetConvar('cp_rollover_keep_speed',  tostring(RolloverConfig.keepSpeedMs   or 6.71)))
local ROLLOVER_START_ROT   = tonumber(GetConvar('cp_rollover_start_rot',   tostring(RolloverConfig.angularStartDegrees or 180.0)))
local ROLLOVER_KEEP_ROT    = tonumber(GetConvar('cp_rollover_keep_rot',    tostring(RolloverConfig.angularKeepDegrees  or 90.0)))
local ROLLOVER_CHECK_INTERVAL_MS = math.max(0, math.floor(RolloverConfig.checkIntervalMs or 300))

local ROLLOVER_STATE_INACTIVE = 0
local ROLLOVER_STATE_ACTIVE   = 1
local ROLLOVER_FORCE_HEIGHT_OFFSET = RolloverConfig.forceHeightOffset or 4.0
local ROLLOVER_FORCE_MAGNITUDE = RolloverConfig.forceMagnitude or 1.4
local ROLLOVER_SETTLE_DURATION_MS = math.max(0, math.floor(RolloverConfig.settleDurationMs or 500))
local ROLLOVER_INITIAL_FORCE_MULTIPLIER = RolloverConfig.initialForceMultiplier or 3.0

local defaultState = {
    rolloverState         = ROLLOVER_STATE_INACTIVE,
    forceStartedAt        = 0,
    nextCheckAt           = 0,
    speed                 = 0.0,
    forwardSpeedRatio     = 1.0,
    inAir                 = false,
    onAllWheels           = false,
    unstableTriggerActive = false,
    angularTriggerActive  = false,
    lastHitMaterial       = 0,
    rollRateDeg           = 0.0,
    pitchRateDeg          = 0.0,
    yawRateDeg            = 0.0,
}

local state = {}
for k, v in pairs(defaultState) do state[k] = v end

-- Cached rollover checks

-- Refreshes cached rollover trigger data on a slower interval to save per-frame work.
local function refreshRolloverChecks(vehicle, now)
    state.nextCheckAt = now + ROLLOVER_CHECK_INTERVAL_MS
    state.speed       = CustomPhysicsUtil.getEntitySpeed3D(vehicle)
    state.inAir       = IsEntityInAir(vehicle)
    state.onAllWheels = IsVehicleOnAllWheels(vehicle)

    state.forwardSpeedRatio = state.speed > 0.0001
        and (math.abs(GetEntitySpeedVector(vehicle, true).y) / state.speed)
        or 0.0

    local rotationVelocity = GetEntityRotationVelocity(vehicle)
    local rollRateDeg  = math.abs(math.deg(rotationVelocity.x))
    local pitchRateDeg = math.abs(math.deg(rotationVelocity.y))
    local yawRateDeg   = math.abs(math.deg(rotationVelocity.z))

    state.unstableTriggerActive = not state.inAir and not state.onAllWheels and state.forwardSpeedRatio <= 0.5
    state.angularTriggerActive  = rollRateDeg  > ROLLOVER_START_ROT
        or pitchRateDeg > ROLLOVER_START_ROT
        or yawRateDeg   > ROLLOVER_START_ROT
    state.rollRateDeg  = rollRateDeg
    state.pitchRateDeg = pitchRateDeg
    state.yawRateDeg   = yawRateDeg
    state.lastHitMaterial = GetLastMaterialHitByEntity(vehicle)
end

-- Public subsystem API

-- Resets rollover force state and the cached trigger snapshot.
function CustomPhysicsRollovers.reset()
    state = {}
    for k, v in pairs(defaultState) do state[k] = v end
end

-- Applies rollover recovery force when the cached trigger conditions say the vehicle is unstable.
function CustomPhysicsRollovers.update(vehicle)
    if CustomPhysics.Config.rolloversEnabled ~= true then
        CustomPhysicsRollovers.reset()
        return
    end

    local now = GetGameTimer()
    if state.nextCheckAt <= 0 or now >= state.nextCheckAt then
        refreshRolloverChecks(vehicle, now)
    end

    -- INACTIVE → ACTIVE: speed must be over 20 mph (8.94 m/s)
    if state.rolloverState == ROLLOVER_STATE_INACTIVE then
        if state.speed < ROLLOVER_START_SPEED then return end
        if not state.inAir
            and (state.unstableTriggerActive or (state.forwardSpeedRatio <= 0.5 and state.angularTriggerActive))
        then
            state.rolloverState  = ROLLOVER_STATE_ACTIVE
            state.forceStartedAt = now
        end
        if state.rolloverState == ROLLOVER_STATE_INACTIVE then return end
    end

    -- ACTIVE → INACTIVE: speed below 15 mph or rotation below 90°/s
    local rotVel       = GetEntityRotationVelocity(vehicle)
    local maxRotDeg    = math.max(
        math.abs(math.deg(rotVel.x)),
        math.abs(math.deg(rotVel.y)),
        math.abs(math.deg(rotVel.z))
    )
    local speed        = CustomPhysicsUtil.getEntitySpeed3D(vehicle)
    if speed < ROLLOVER_KEEP_SPEED
        or maxRotDeg < ROLLOVER_KEEP_ROT
    then
        state.rolloverState  = ROLLOVER_STATE_INACTIVE
        state.forceStartedAt = 0
        return
    end

    local elapsedMs = math.max(0, now - state.forceStartedAt)
    local velocity  = GetEntityVelocity(vehicle)
    if speed <= 0.0001 then
        return
    end

    local frameTime      = CustomPhysicsUtil.getDeltaSeconds()
    local settleProgress = CustomPhysicsUtil.clamp(elapsedMs / ROLLOVER_SETTLE_DURATION_MS, 0.0, 1.0)
    local forceMultiplier = ROLLOVER_INITIAL_FORCE_MULTIPLIER - ((ROLLOVER_INITIAL_FORCE_MULTIPLIER - 1.0) * settleProgress)

    if elapsedMs >= ROLLOVER_SETTLE_DURATION_MS and state.lastHitMaterial > 0 then
        forceMultiplier = forceMultiplier * 2.0
    end

    local forceMagnitude = ROLLOVER_FORCE_MAGNITUDE * forceMultiplier
    local forceScale     = forceMagnitude * frameTime
    local forceX = (velocity.x / speed) * forceScale
    local forceY = (velocity.y / speed) * forceScale
    local forceZ = (velocity.z / speed) * forceScale

    if state.onAllWheels then
        ApplyForceToEntity(vehicle, 1, forceX, forceY, forceZ, 0.0, 0.0, 0.0, 0, false, false, true, false, true)
    else
        ApplyForceToEntity(vehicle, 1, forceX, forceY, forceZ, 0.0, 0.0, ROLLOVER_FORCE_HEIGHT_OFFSET, 0, false, false, true, false, true)
    end
end

-- Debug panel

local function drawDebugLine(text, x, y, r, g, b)
    SetTextFont(0)
    SetTextScale(0.0, 0.28)
    SetTextColour(r or 255, g or 255, b or 255, 255)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

local function drawDebugStatus(label, r, g, b, x, y, w, lineH)
    DrawRect(x + w * 0.5, y + lineH * 0.5, w, lineH, r, g, b, 220)
    SetTextFont(0)
    SetTextScale(0.0, 0.28)
    SetTextColour(255, 255, 255, 255)
    SetTextJustification(0) -- centered
    SetTextEntry("STRING")
    AddTextComponentString(label)
    DrawText(x + w * 0.5, y + lineH * 0.15)
    SetTextJustification(1) -- reset to left
end

local GREEN = { 80, 220, 80 }
local RED   = { 220, 80, 80 }
local WHITE = { 255, 255, 255 }

local function bool2str(v) return v and "true" or "false" end
local function col(condition) return condition and GREEN or RED end

function CustomPhysicsRollovers.drawDebugPanel()
    local lineH  = 0.022
    local x      = 0.02
    local y      = 0.04
    local rectW  = 0.2
    local lx     = x + 0.004
    local active = state.rolloverState == ROLLOVER_STATE_ACTIVE

    local rotVel    = GetEntityRotationVelocity(GetVehiclePedIsIn(PlayerPedId(), false))
    local maxRotDeg = math.max(
        math.abs(math.deg(rotVel.x)),
        math.abs(math.deg(rotVel.y)),
        math.abs(math.deg(rotVel.z))
    )
    local elapsedMs = active and math.max(0, GetGameTimer() - state.forceStartedAt) or 0

    local statusLabel, sr, sg, sb
    if active then
        statusLabel, sr, sg, sb = "ACTIVE", 180, 40, 40
    else
        statusLabel, sr, sg, sb = "INACTIVE", 40, 40, 40
    end

    -- speed threshold depends on state
    local speedOk   = active and (state.speed >= ROLLOVER_KEEP_SPEED) or (not active and state.speed >= ROLLOVER_START_SPEED)
    local rotToStart = state.angularTriggerActive  -- cached: any axis >= 360
    local rotToKeep  = maxRotDeg >= ROLLOVER_KEEP_ROT  -- live: max axis >= 90

    local lines = {
        { string.format("enoughSpeed:    %s", bool2str(speedOk)),                       col(speedOk) },
        { string.format("isUnstable:     %s", bool2str(state.unstableTriggerActive)),     col(state.unstableTriggerActive) },
        { string.format("enoughRotToStart:%s", bool2str(rotToStart)),                    col(rotToStart) },
        { string.format("enoughRotToKeep:%s", bool2str(rotToKeep)),                      col(rotToKeep) },
        { string.format("forceElapsed:   %d ms", elapsedMs),                             WHITE },
    }

    local lineCount = #lines + 1 -- +1 for status bar
    DrawRect(x + rectW * 0.5, y + (lineH * (lineCount + 1)) * 0.5, rectW, lineH * (lineCount + 1), 0, 0, 0, 180)
    drawDebugStatus(statusLabel, sr, sg, sb, x, y, rectW, lineH)

    for i, entry in ipairs(lines) do
        local c = entry[2]
        drawDebugLine(entry[1], lx, y + lineH * (i + 0.5), c[1], c[2], c[3])
    end
end

CreateThread(function()
    while true do
        if CustomPhysics.Config.rolloversEnabled == true and GetConvarInt('cPhysicsExtraPrints', 0) >= 1 then
            CustomPhysicsRollovers.drawDebugPanel()
        end
        Wait(0)
    end
end)
