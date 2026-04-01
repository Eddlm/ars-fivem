local Config = (CustomCam or {}).Config or {}
local LOOK_BACK_CONTROL = 79 -- INPUT_VEH_LOOK_BEHIND
local DEFAULT_GAMEPLAY_CAM_FOV = 60.0
local VIRTUAL_MIRROR_HORIZONTAL_FOV_DEGREES = 90.0
local VIRTUAL_MIRROR_VERTICAL_FOV_DEGREES = 15.0
local VIRTUAL_MIRROR_TRACKING_HORIZONTAL_PADDING_DEGREES = 90.0
local VIRTUAL_MIRROR_VEHICLE_POLL_RADIUS_METERS = 200.0
local VIRTUAL_MIRROR_MAX_TRACKED_VEHICLES = 24
local VIRTUAL_MIRROR_FRAME_THICKNESS_NORMALIZED = 0.006
local VIRTUAL_MIRROR_FRAME_COLOR = { r = 20, g = 20, b = 20, a = 230 }
local VIRTUAL_MIRROR_FILL_COLOR = { r = 65, g = 75, b = 90, a = 120 }
local VIRTUAL_MIRROR_DOT_SIZE_NORMALIZED = 0.007
local VIRTUAL_MIRROR_DOT_SIZE_NEAR_MULTIPLIER = 7.5
local VIRTUAL_MIRROR_DOT_SCALE_EXPONENT = 4.0
local VIRTUAL_MIRROR_DOT_SEPARATION_FALLOFF_EXPONENT = 22.0
local VIRTUAL_MIRROR_DOT_WIDTH_SCALE = 0.65
local VIRTUAL_MIRROR_DOT_CLIP_PADDING_PIXELS = 4.0
local VIRTUAL_MIRROR_DOT_TEXTURE_DICT = 'mpinventory'
local VIRTUAL_MIRROR_DOT_TEXTURE_NAME = 'in_world_circle'
local VIRTUAL_MIRROR_DOT_COLOR = { r = 255, g = 220, b = 80, a = 235 }
local VIRTUAL_MIRROR_DOT_REAR_COLOR = { r = 255, g = 70, b = 60, a = 235 }
local FOLLOW_CAM_MINIMUM_BUBBLE_PADDING_METERS = 1.0
local FOLLOW_CAM_MINIMUM_BUBBLE_ESCAPE_SPEED_METERS_PER_SECOND = 6.0
local FOLLOW_CAM_SPEED_MATCH_DISTANCE_METERS = 4.0
local FOLLOW_CAM_ACCELERATION_FACTOR = 10.0
local FOLLOW_CAM_DAMPING_FACTOR = 2.0
local FOLLOW_CAM_CATCHUP_FACTOR = 10.0
local FOLLOW_CAM_ROTATION_ACCELERATION_DEGREES_PER_SECOND_SQUARED = 1800.0
local FOLLOW_CAM_ROTATION_DAMPING_FACTOR = 8.0
local FOLLOW_CAM_ROTATION_SMOOTHING_FACTOR = 30.0
local FOLLOW_CAM_VIEW_MODE_PADDING_METERS = {
    [0] = 0.25,
    [1] = 0.5,
    [2] = 0.75
}
local FOLLOW_CAM_FALLBACK_DISTANCE_PADDING_METERS = 0.1
local FOLLOW_CAM_VELOCITY_LOOK_AHEAD_FACTOR = 0.5
local FOLLOW_CAM_HOOD_VIEW_MODE_ID = 4
local FOLLOW_CAM_FLIP_ANGULAR_VELOCITY_X_RADIANS_PER_SECOND = 1.5
local FOLLOW_CAM_UPRIGHT_THRESHOLD_RATIO = 0.2
local FOLLOW_CAM_UPRIGHT_RECOVERY_THRESHOLD_RATIO = 0.9
local FOLLOW_CAM_FOCUS_HEIGHT_METERS = 0.85
local HOOD_CAM_SCAN_HEIGHT_METERS = 2.5
local HOOD_CAM_SCAN_STEP_METERS = 0.2
local HOOD_CAM_SCAN_MAX_AHEAD_METERS = 3.5
local HOOD_CAM_NORMAL_DOT_THRESHOLD_RATIO = 0.94
local HOOD_CAM_ROTATION_Y_DEGREES = 0.0
local HOOD_CAM_ROTATION_Z_DEGREES = 0.0

local state = {
    active = false,
    cam = nil,
    fov = DEFAULT_GAMEPLAY_CAM_FOV,
    velocity = vector3(0.0, 0.0, 0.0),
    lookAheadEnabled = true,
    hoodAttached = false,
    rotation = nil,
    rotationSpeed = vector3(0.0, 0.0, 0.0),
    position = nil,
    focus = nil,
    lookBackActive = false,
    virtualMirrorVehicles = {},
    virtualMirrorTracker = {},
    mirrorPollQueue = {},
    mirrorPollQueueIndex = 1,
    mirrorPollAccumulator = 0.0
}
local toggleHoldState = {
    heldSince = nil,
    hasTriggered = false
}

-- Shared math helpers keep the camera motion code readable.
local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end

    if value > maxValue then
        return maxValue
    end

    return value
end

local function angleDelta(target, current)
    local delta = (target - current + 180.0) % 360.0 - 180.0
    return delta
end

local function normalizeAngle(angle)
    local wrapped = angle % 360.0
    if wrapped > 180.0 then
        wrapped = wrapped - 360.0
    end
    if wrapped < -180.0 then
        wrapped = wrapped + 360.0
    end
    return wrapped
end

local function addVector(a, b)
    return vector3(a.x + b.x, a.y + b.y, a.z + b.z)
end

local function subtractVector(a, b)
    return vector3(a.x - b.x, a.y - b.y, a.z - b.z)
end

local function scaleVector(vector, scalar)
    return vector3(vector.x * scalar, vector.y * scalar, vector.z * scalar)
end

local function cross(a, b)
    return vector3(
        (a.y * b.z) - (a.z * b.y),
        (a.z * b.x) - (a.x * b.z),
        (a.x * b.y) - (a.y * b.x)
    )
end

local function vectorLength(vector)
    return math.sqrt((vector.x * vector.x) + (vector.y * vector.y) + (vector.z * vector.z))
end

local function normalize(vector)
    local length = vectorLength(vector)
    if length <= 0.0001 then
        return vector3(0.0, 0.0, 0.0)
    end

    return scaleVector(vector, 1.0 / length)
end

local function directionToRotation(direction)
    local normalized = normalize(direction)
    local horizontalLength = math.sqrt((normalized.x * normalized.x) + (normalized.y * normalized.y))
    local pitch = math.deg(math.atan2(normalized.z, horizontalLength))
    local yaw = math.deg(math.atan2(-normalized.x, normalized.y))

    return vector3(pitch, 0.0, yaw)
end

local function dot(a, b)
    return (a.x * b.x) + (a.y * b.y) + (a.z * b.z)
end

local function signedPower(value, exponent)
    if value == 0.0 then
        return 0.0
    end

    return (value > 0.0 and 1.0 or -1.0) * (math.abs(value) ^ exponent)
end

local function getEntityForwardVectorSafe(entity)
    if type(GetEntityForwardVector) == 'function' then
        local forward = GetEntityForwardVector(entity)
        if forward then
            return forward
        end
    end

    local heading = GetEntityHeading(entity)
    local radians = math.rad(heading)
    return vector3(-math.sin(radians), math.cos(radians), 0.0)
end

local function getEntityUpVectorSafe(entity)
    if type(GetEntityUpVector) == 'function' then
        local up = GetEntityUpVector(entity)
        if up then
            return up
        end
    end

    return vector3(0.0, 0.0, 1.0)
end

local function getVehiclePoolSafe()
    if type(GetGamePool) == 'function' then
        local pool = GetGamePool('CVehicle')
        if pool then
            return pool
        end
    end

    return {}
end

local function getVehicleCenterCoordsSafe(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return vector3(0.0, 0.0, 0.0)
    end

    local model = GetEntityModel(vehicle)
    if not model or model == 0 then
        return GetEntityCoords(vehicle)
    end

    local minDim, maxDim = GetModelDimensions(model)
    local localCenterY = ((tonumber(minDim.y) or 0.0) + (tonumber(maxDim.y) or 0.0)) * 0.5
    local localCenterZ = ((tonumber(minDim.z) or 0.0) + (tonumber(maxDim.z) or 0.0)) * 0.5
    return GetOffsetFromEntityInWorldCoords(vehicle, 0.0, localCenterY, localCenterZ)
end

local function getVehicleLightAnchorCoordsSafe(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return getVehicleCenterCoordsSafe(vehicle)
    end
    if type(GetEntityBoneIndexByName) ~= 'function' or type(GetWorldPositionOfEntityBone) ~= 'function' then
        return getVehicleCenterCoordsSafe(vehicle)
    end

    local function resolveLightAnchorByBoneNames(boneNames)
        local positions = {}
        for i = 1, #boneNames do
            local boneName = boneNames[i]
            local boneIndex = GetEntityBoneIndexByName(vehicle, boneName)
            if boneIndex and boneIndex ~= -1 then
                positions[#positions + 1] = GetWorldPositionOfEntityBone(vehicle, boneIndex)
            end
        end

        if #positions == 0 then
            return nil
        end

        local sum = vector3(0.0, 0.0, 0.0)
        for i = 1, #positions do
            sum = addVector(sum, positions[i])
        end

        return scaleVector(sum, 1.0 / #positions)
    end

    local frontLightBoneNames = {
        'headlight_l',
        'headlight_r',
        'headlight_lm',
        'headlight_rm',
        'headlight_lf',
        'headlight_rf'
    }
    local rearLightBoneNames = {
        'taillight_l',
        'taillight_r',
        'tail_light_l',
        'tail_light_r',
        'brakelight_l',
        'brakelight_r'
    }

    local frontAnchor = resolveLightAnchorByBoneNames(frontLightBoneNames)
    if frontAnchor then
        return frontAnchor
    end

    local rearAnchor = resolveLightAnchorByBoneNames(rearLightBoneNames)
    if rearAnchor then
        return rearAnchor
    end

    return getVehicleCenterCoordsSafe(vehicle)
end

-- Hood camera helpers probe the vehicle body so the camera can snap cleanly.
local function raycastVehicleDown(vehicle, localY, minDim, maxDim)
    local startWorld = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, localY, maxDim.z + HOOD_CAM_SCAN_HEIGHT_METERS)
    local endWorld = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, localY, minDim.z - 1.0)
    local rayHandle = StartExpensiveSynchronousShapeTestLosProbe(
        startWorld.x, startWorld.y, startWorld.z,
        endWorld.x, endWorld.y, endWorld.z,
        2,
        PlayerPedId(),
        7
    )
    local _, hit, hitCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)

    if hit ~= 1 or entityHit ~= vehicle then
        return nil, nil
    end

    return hitCoords, surfaceNormal
end

local function findHoodAttachOffset(vehicle)
    local minDim, maxDim = GetModelDimensions(GetEntityModel(vehicle))
    local bestOffset = vector3(0.0, maxDim.y, maxDim.z)
    local localY = 0.0
    local scanEndY = maxDim.y + HOOD_CAM_SCAN_MAX_AHEAD_METERS

    while localY <= scanEndY do
        local hitCoords, surfaceNormal = raycastVehicleDown(vehicle, localY, minDim, maxDim)

        if hitCoords and surfaceNormal then
            local localOffset = GetOffsetFromEntityGivenWorldCoords(vehicle, hitCoords.x, hitCoords.y, hitCoords.z)
            bestOffset = localOffset

            if dot(surfaceNormal, vector3(0.0, 0.0, 1.0)) < HOOD_CAM_NORMAL_DOT_THRESHOLD_RATIO then
                return localOffset
            end
        end

        localY = localY + HOOD_CAM_SCAN_STEP_METERS
    end

    return bestOffset
end

-- Follow camera motion uses a spring-like controller instead of a hard snap.
local function smoothAxis(currentAngle, currentSpeed, targetAngle, dt)
    local delta = angleDelta(targetAngle, currentAngle)
    local angularAccel = delta * FOLLOW_CAM_ROTATION_SMOOTHING_FACTOR
    angularAccel = clamp(angularAccel, -FOLLOW_CAM_ROTATION_ACCELERATION_DEGREES_PER_SECOND_SQUARED, FOLLOW_CAM_ROTATION_ACCELERATION_DEGREES_PER_SECOND_SQUARED)
    angularAccel = angularAccel - (currentSpeed * FOLLOW_CAM_ROTATION_DAMPING_FACTOR)

    currentSpeed = currentSpeed + (angularAccel * dt)
    currentAngle = currentAngle + (currentSpeed * dt)

    if currentAngle > 180.0 then
        currentAngle = currentAngle - 360.0
    elseif currentAngle < -180.0 then
        currentAngle = currentAngle + 360.0
    end

    return currentAngle, currentSpeed
end

local function smoothRotation(currentRotation, currentSpeed, targetRotation, dt)
    local pitch, pitchSpeed = smoothAxis(currentRotation.x, currentSpeed.x, targetRotation.x, dt)
    local yaw, yawSpeed = smoothAxis(currentRotation.z, currentSpeed.z, targetRotation.z, dt)

    return vector3(pitch, 0.0, yaw), vector3(pitchSpeed, 0.0, yawSpeed)
end

-- View mode checks let the hood camera and follow camera share the same entrypoint.
local function isHoodViewMode()
    return GetFollowVehicleCamViewMode() == FOLLOW_CAM_HOOD_VIEW_MODE_ID
end

local function getViewModeFollowPadding()
    local viewMode = GetFollowVehicleCamViewMode()
    local padding = FOLLOW_CAM_VIEW_MODE_PADDING_METERS[viewMode]

    if padding == nil then
        padding = FOLLOW_CAM_FALLBACK_DISTANCE_PADDING_METERS
    end

    return padding
end

local function getViewModeTrailingDistance(vehicleLength)
    local viewMode = GetFollowVehicleCamViewMode()
    local configuredDistance = Config.FollowCam.trailingDistanceByViewModeMeters and Config.FollowCam.trailingDistanceByViewModeMeters[viewMode] or nil
    local baseVehicleDistance = math.max(0.0, tonumber(vehicleLength) or 0.0) * 0.5

    if configuredDistance ~= nil then
        return baseVehicleDistance + (tonumber(configuredDistance) or Config.FollowCam.initialSpawnDistanceMeters)
    end

    return baseVehicleDistance + getViewModeFollowPadding()
end

local function getMinimumBubbleDistance(vehicleLength)
    return math.max(0.0, tonumber(vehicleLength) or 0.0) + FOLLOW_CAM_MINIMUM_BUBBLE_PADDING_METERS
end

local function getViewModeHeightOffset()
    local viewMode = GetFollowVehicleCamViewMode()
    local configuredHeightOffset = Config.FollowCam.heightOffsetByViewModeMeters and Config.FollowCam.heightOffsetByViewModeMeters[viewMode] or nil

    if configuredHeightOffset ~= nil then
        return tonumber(configuredHeightOffset) or 0.5
    end

    return 0.5
end

local function syncCameraFov()
    local gameplayFov = tonumber(GetGameplayCamFov and GetGameplayCamFov() or nil)
    if gameplayFov and gameplayFov > 0.0 then
        state.fov = gameplayFov
    else
        state.fov = DEFAULT_GAMEPLAY_CAM_FOV
    end
end

-- Camera lifecycle helpers keep creation, activation, and teardown in one place.
local function cleanupCamera()
    if state.cam and DoesCamExist(state.cam) then
        SetCamActive(state.cam, false)
        RenderScriptCams(false, true, 200, true, true)
        DestroyCam(state.cam, false)
    end

    ClearFocus()
    SetFocusEntity(PlayerPedId())
    DisplayRadar(true)

    state.active = false
    state.cam = nil
    state.velocity = vector3(0.0, 0.0, 0.0)
    state.lookAheadEnabled = true
    state.hoodAttached = false
    state.rotation = nil
    state.rotationSpeed = vector3(0.0, 0.0, 0.0)
    state.position = nil
    state.focus = nil
    state.lookBackActive = false
    state.virtualMirrorVehicles = {}
    state.virtualMirrorTracker = {}
    state.mirrorPollQueue = {}
    state.mirrorPollQueueIndex = 1
    state.mirrorPollAccumulator = 0.0
end

-- The scripted camera is created lazily so we only allocate it when needed.
local function ensureCamera()
    if state.cam and DoesCamExist(state.cam) then
        return
    end

    state.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
end

-- Activating the camera only needs to happen once per session.
local function activateCamera()
    ensureCamera()
    syncCameraFov()
    SetCamActive(state.cam, true)
    SetCamFov(state.cam, state.fov)
    RenderScriptCams(true, true, 200, true, true)
    state.active = true
end

-- Hood mode hard-attaches the camera to the vehicle and leaves the follow logic idle.
local function attachHoodCam(vehicle, lookBackActive)
    local localOffset = findHoodAttachOffset(vehicle)
    local yaw = HOOD_CAM_ROTATION_Z_DEGREES

    if lookBackActive then
        yaw = yaw + 180.0
    end

    local attachOffset = vector3(
        localOffset.x,
        localOffset.y + Config.HoodCam.forwardOffsetMeters,
        localOffset.z + Config.HoodCam.upOffsetMeters
    )

    DetachCam(state.cam)
    HardAttachCamToEntity(
        state.cam,
        vehicle,
        Config.HoodCam.rotationXDegrees,
        HOOD_CAM_ROTATION_Y_DEGREES,
        yaw,
        attachOffset.x,
        attachOffset.y,
        attachOffset.z,
        true
    )

    state.hoodAttached = true
end

local function isControlPressedAnyPad(controlId)
    return IsControlPressed(0, controlId)
        or IsControlPressed(1, controlId)
        or IsControlPressed(2, controlId)
        or IsDisabledControlPressed(0, controlId)
        or IsDisabledControlPressed(1, controlId)
        or IsDisabledControlPressed(2, controlId)
end

local function isControlJustPressedAnyPad(controlId)
    return IsControlJustPressed(0, controlId)
        or IsControlJustPressed(1, controlId)
        or IsControlJustPressed(2, controlId)
        or IsDisabledControlJustPressed(0, controlId)
        or IsDisabledControlJustPressed(1, controlId)
        or IsDisabledControlJustPressed(2, controlId)
end

local function isControlJustReleasedAnyPad(controlId)
    return IsControlJustReleased(0, controlId)
        or IsControlJustReleased(1, controlId)
        or IsControlJustReleased(2, controlId)
        or IsDisabledControlJustReleased(0, controlId)
        or IsDisabledControlJustReleased(1, controlId)
        or IsDisabledControlJustReleased(2, controlId)
end

local function updateLookBackState()
    local previousLookBackState = state.lookBackActive

    local justPressed = isControlJustPressedAnyPad(LOOK_BACK_CONTROL)
    local justReleased = isControlJustReleasedAnyPad(LOOK_BACK_CONTROL)

    if justPressed then
        state.lookBackActive = true
    elseif justReleased then
        state.lookBackActive = false
    elseif state.lookBackActive then
        -- Keep the state sticky only while the key remains held.
        state.lookBackActive = isControlPressedAnyPad(LOOK_BACK_CONTROL)
    end

    return previousLookBackState ~= state.lookBackActive
end

-- Follow mode computes the desired focus point and trailing camera anchor.
local function getDesiredFollowData()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    local minDim, maxDim = GetModelDimensions(GetEntityModel(vehicle))
    local vehicleCoords = GetEntityCoords(vehicle)
    local forward = getEntityForwardVectorSafe(vehicle)
    local flatForward = normalize(vector3(forward.x, forward.y, 0.0))
    local worldVelocity = GetEntityVelocity(vehicle)
    local forwardSpeed = dot(worldVelocity, forward)
    local lookAheadDirection = flatForward
    local vehicleLength = math.abs(maxDim.y - minDim.y)
    local vehicleHalfLength = vehicleLength * 0.5

    if vectorLength(lookAheadDirection) <= 0.001 then
        lookAheadDirection = vector3(0.0, 1.0, 0.0)
    end

    local lookAheadOffset = vector3(0.0, 0.0, 0.0)

    if state.lookAheadEnabled then
        local rawLookAheadOffset = scaleVector(lookAheadDirection, forwardSpeed * FOLLOW_CAM_VELOCITY_LOOK_AHEAD_FACTOR)
        local rawLookAheadDistance = vectorLength(rawLookAheadOffset)
        lookAheadOffset = rawLookAheadOffset

        if rawLookAheadDistance > vehicleLength then
            lookAheadOffset = scaleVector(normalize(rawLookAheadOffset), vehicleLength)
        end
    end

    local targetFocus = addVector(
        addVector(vehicleCoords, lookAheadOffset),
        vector3(0.0, 0.0, FOLLOW_CAM_FOCUS_HEIGHT_METERS)
    )

    local roofHeight = math.max(0.0, tonumber(maxDim.z) or 0.0)
    local targetHeight = roofHeight + getViewModeHeightOffset()
    local followDistance = getViewModeTrailingDistance(vehicleHalfLength)
    local currentOffsetFromVehicle = subtractVector(state.position, vehicleCoords)
    local rearwardDirection = scaleVector(lookAheadDirection, -1.0)
    local direction = normalize(currentOffsetFromVehicle)

    if vectorLength(rearwardDirection) <= 0.001 then
        rearwardDirection = vector3(0.0, -1.0, 0.0)
    end

    if vectorLength(direction) <= 0.001 then
        direction = rearwardDirection
    end

    direction = normalize(vector3(direction.x, direction.y, 0.0))
    if vectorLength(direction) <= 0.001 then
        direction = rearwardDirection
    end

    local targetPosition = addVector(
        vehicleCoords,
        addVector(
            scaleVector(direction, followDistance),
            vector3(0.0, 0.0, targetHeight)
        )
    )

    return targetPosition, targetFocus
end

-- Starting follow mode seeds the camera state from the current vehicle.
local function getInitialFollowPosition(vehicle)
    local vehicleCoords = GetEntityCoords(vehicle)
    local minDim, maxDim = GetModelDimensions(GetEntityModel(vehicle))
    local vehicleLength = math.abs(maxDim.y - minDim.y) * 0.5
    local roofHeight = math.max(0.0, tonumber(maxDim.z) or 0.0)
    local forward = getEntityForwardVectorSafe(vehicle)
    local flatForward = normalize(vector3(forward.x, forward.y, 0.0))
    local rearwardDirection = scaleVector(flatForward, -1.0)
    local targetHeight = roofHeight + getViewModeHeightOffset()

    if vectorLength(rearwardDirection) <= 0.001 then
        rearwardDirection = vector3(0.0, -1.0, 0.0)
    end

    local initialDistance = math.max(
        tonumber(Config.FollowCam.initialSpawnDistanceMeters) or 7.0,
        getViewModeTrailingDistance(vehicleLength)
    )

    return addVector(
        vehicleCoords,
        addVector(
            scaleVector(rearwardDirection, initialDistance),
            vector3(0.0, 0.0, targetHeight)
        )
    )
end

local function seedFollowState(vehicle)
    state.position = getInitialFollowPosition(vehicle)

    local _, desiredFocus = getDesiredFollowData()
    state.velocity = vector3(0.0, 0.0, 0.0)
    state.focus = desiredFocus
    state.rotation = directionToRotation(subtractVector(state.focus, state.position))
    state.rotationSpeed = vector3(0.0, 0.0, 0.0)
    syncCameraFov()

    SetCamCoord(state.cam, state.position.x, state.position.y, state.position.z)
    SetCamRot(state.cam, state.rotation.x, state.rotation.y, state.rotation.z, 2)
    SetCamFov(state.cam, state.fov)
    SetFocusPosAndVel(state.position.x, state.position.y, state.position.z, 0.0, 0.0, 0.0)
end

-- Follow mode initializes the scripted camera and syncs the first frame.
local function startFollowCam()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        return
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    activateCamera()
    state.lookBackActive = false
    seedFollowState(vehicle)

    if isHoodViewMode() then
        attachHoodCam(vehicle, state.lookBackActive)
        state.position = GetCamCoord(state.cam)
        state.rotation = GetCamRot(state.cam, 2)
        state.focus = nil
        return
    end
end

-- Gameplay controls are only suppressed while the custom camera is active.
local function disableGameplayControls()
    DisablePlayerFiring(PlayerId(), true)
    DisplayRadar(true)
end

local function drawVirtualMirrorOverlay()
    local mirror = Config.VirtualMirror
    if not mirror or mirror.enabled ~= true then
        return
    end

    local centerX = tonumber(mirror.centerXNormalized) or 0.5
    local centerY = tonumber(mirror.centerYNormalized) or 0.08
    local width = tonumber(mirror.widthNormalized) or 0.42
    local height = tonumber(mirror.heightNormalized) or 0.08
    local frameThickness = VIRTUAL_MIRROR_FRAME_THICKNESS_NORMALIZED
    local frameColor = VIRTUAL_MIRROR_FRAME_COLOR
    local fillColor = VIRTUAL_MIRROR_FILL_COLOR
    local horizontalFovDegrees = math.max(VIRTUAL_MIRROR_HORIZONTAL_FOV_DEGREES, 1.0)
    local verticalFovDegrees = math.max(VIRTUAL_MIRROR_VERTICAL_FOV_DEGREES, 1.0)
    local trackingHorizontalPaddingDegrees = math.max(VIRTUAL_MIRROR_TRACKING_HORIZONTAL_PADDING_DEGREES, 0.0)
    local horizontalHalfFov = math.rad(horizontalFovDegrees * 0.5)
    local verticalHalfFov = math.rad(verticalFovDegrees * 0.5)
    local trackingHorizontalHalfFov = horizontalHalfFov + math.rad(trackingHorizontalPaddingDegrees)
    local dotSize = math.max(VIRTUAL_MIRROR_DOT_SIZE_NORMALIZED, 0.001)
    local dotSizeNearMultiplier = math.max(VIRTUAL_MIRROR_DOT_SIZE_NEAR_MULTIPLIER, 1.0)
    local dotScaleExponent = math.max(VIRTUAL_MIRROR_DOT_SCALE_EXPONENT, 0.1)
    local dotSeparationFalloffExponent = math.max(VIRTUAL_MIRROR_DOT_SEPARATION_FALLOFF_EXPONENT, 0.1)
    local dotWidthScale = math.max(VIRTUAL_MIRROR_DOT_WIDTH_SCALE, 0.1)
    local dotClipPaddingPixels = math.max(VIRTUAL_MIRROR_DOT_CLIP_PADDING_PIXELS, 0.0)
    local dotTextureDict = VIRTUAL_MIRROR_DOT_TEXTURE_DICT
    local dotTextureName = VIRTUAL_MIRROR_DOT_TEXTURE_NAME
    local dotColor = VIRTUAL_MIRROR_DOT_COLOR
    local dotRearColor = VIRTUAL_MIRROR_DOT_REAR_COLOR
    local dotScaleDistance = math.max(VIRTUAL_MIRROR_VEHICLE_POLL_RADIUS_METERS, 0.001)
    local canUseDotSprite = false

    if type(HasStreamedTextureDictLoaded) == 'function' and type(RequestStreamedTextureDict) == 'function' then
        if not HasStreamedTextureDictLoaded(dotTextureDict) then
            RequestStreamedTextureDict(dotTextureDict, true)
        end
        canUseDotSprite = HasStreamedTextureDictLoaded(dotTextureDict)
    end

    DrawRect(
        centerX,
        centerY,
        width,
        height,
        tonumber(frameColor.r) or 20,
        tonumber(frameColor.g) or 20,
        tonumber(frameColor.b) or 20,
        tonumber(frameColor.a) or 230
    )

    local innerWidth = math.max(0.0, width - (frameThickness * 2.0))
    local innerHeight = math.max(0.0, height - (frameThickness * 2.0))
    DrawRect(
        centerX,
        centerY,
        innerWidth,
        innerHeight,
        tonumber(fillColor.r) or 65,
        tonumber(fillColor.g) or 75,
        tonumber(fillColor.b) or 90,
        tonumber(fillColor.a) or 120
    )

    local playerPed = PlayerPedId()
    if not IsPedInAnyVehicle(playerPed, false) then
        return
    end

    local playerVehicle = GetVehiclePedIsIn(playerPed, false)
    if playerVehicle == 0 then
        return
    end

    local playerCoords = getVehicleCenterCoordsSafe(playerVehicle)
    local playerForward = getEntityForwardVectorSafe(playerVehicle)
    local worldUp = vector3(0.0, 0.0, 1.0)
    local playerRight = normalize(cross(playerForward, worldUp))
    if vectorLength(playerRight) <= 0.001 then
        playerRight = vector3(1.0, 0.0, 0.0)
    end
    local playerForwardHorizontalLength = math.sqrt((playerForward.x * playerForward.x) + (playerForward.y * playerForward.y))
    local playerForwardPitch = math.atan2(playerForward.z, playerForwardHorizontalLength)
    local mirrorHalfWidth = innerWidth * 0.5
    local mirrorHalfHeight = innerHeight * 0.5
    local screenWidth, screenHeight = GetActiveScreenResolution()
    local clipPaddingX = 0.0
    local clipPaddingY = 0.0
    local occupiedHeadlightPairBounds = {}

    if screenWidth and screenWidth > 0 then
        clipPaddingX = dotClipPaddingPixels / screenWidth
    end

    if screenHeight and screenHeight > 0 then
        clipPaddingY = dotClipPaddingPixels / screenHeight
    end

    local function isPointInsideAnyOccupiedPairBounds(x, y)
        for i = 1, #occupiedHeadlightPairBounds do
            local bounds = occupiedHeadlightPairBounds[i]
            if x >= bounds.minX and x <= bounds.maxX and y >= bounds.minY and y <= bounds.maxY then
                return true
            end
        end

        return false
    end

    for i = 1, #state.virtualMirrorVehicles do
        local vehicle = state.virtualMirrorVehicles[i]

        if vehicle and DoesEntityExist(vehicle) then
            local vehicleCenterCoords = getVehicleCenterCoordsSafe(vehicle)
            local lightAnchorCoords = getVehicleLightAnchorCoordsSafe(vehicle)
            local toVehicle = subtractVector(lightAnchorCoords, playerCoords)
            local toPlayerFromVehicle = subtractVector(playerCoords, vehicleCenterCoords)
            local vehicleForward = getEntityForwardVectorSafe(vehicle)
            local vehicleForwardFlat = normalize(vector3(vehicleForward.x, vehicleForward.y, 0.0))
            local toPlayerFlat = normalize(vector3(toPlayerFromVehicle.x, toPlayerFromVehicle.y, 0.0))
            local showRearLights = false

            if vectorLength(vehicleForwardFlat) > 0.001 and vectorLength(toPlayerFlat) > 0.001 then
                showRearLights = dot(vehicleForwardFlat, toPlayerFlat) < 0.0
            end

            local activeDotColor = showRearLights and dotRearColor or dotColor
            local localRight = dot(toVehicle, playerRight)
            local localForward = dot(toVehicle, playerForward)
            local backwardsDepth = -localForward

            if backwardsDepth > 0.01 then
                local yaw = math.atan2(localRight, backwardsDepth)
                local toVehicleHorizontalLength = math.sqrt((toVehicle.x * toVehicle.x) + (toVehicle.y * toVehicle.y))
                local toVehiclePitch = math.atan2(toVehicle.z, toVehicleHorizontalLength)
                local pitch = toVehiclePitch - playerForwardPitch

                if math.abs(yaw) <= trackingHorizontalHalfFov and math.abs(pitch) <= verticalHalfFov then
                    local normalizedX = yaw / horizontalHalfFov
                    local normalizedY = pitch / verticalHalfFov
                    local mirrorX = centerX + (normalizedX * mirrorHalfWidth)
                    local mirrorY = centerY + (normalizedY * mirrorHalfHeight)
                    local centerDistance = vectorLength(subtractVector(vehicleCenterCoords, playerCoords))
                    local vehicleDistance = centerDistance
                    local distanceScale = clamp(1.0 - (vehicleDistance / dotScaleDistance), 0.0, 1.0)
                    local dotScaleT = distanceScale ^ dotScaleExponent
                    local scaledDotSize = dotSize * dotScaleT * (1.0 + ((dotSizeNearMultiplier - 1.0) * dotScaleT))
                    local scaledDotWidth = scaledDotSize * dotWidthScale
                    local separationScale = distanceScale ^ dotSeparationFalloffExponent
                    local scaledPairSeparation = innerWidth * clamp(separationScale, 0.0, 1.0)

                    if scaledDotSize > 0.0001 then
                        local leftDotX = mirrorX - (scaledPairSeparation * 0.5)
                        local rightDotX = mirrorX + (scaledPairSeparation * 0.5)
                        local halfDotWidth = scaledDotWidth * 0.5
                        local halfDotHeight = scaledDotSize * 0.5
                        local innerMinX = centerX - mirrorHalfWidth
                        local innerMaxX = centerX + mirrorHalfWidth
                        local innerMinY = centerY - mirrorHalfHeight
                        local innerMaxY = centerY + mirrorHalfHeight

                        local leftInBounds = (leftDotX - halfDotWidth) >= (innerMinX - clipPaddingX) and (leftDotX + halfDotWidth) <= (innerMaxX + clipPaddingX)
                        local rightInBounds = (rightDotX - halfDotWidth) >= (innerMinX - clipPaddingX) and (rightDotX + halfDotWidth) <= (innerMaxX + clipPaddingX)
                        local verticalInBounds = (mirrorY - halfDotHeight) >= (innerMinY - clipPaddingY) and (mirrorY + halfDotHeight) <= (innerMaxY + clipPaddingY)
                        local leftOccluded = isPointInsideAnyOccupiedPairBounds(leftDotX, mirrorY)
                        local rightOccluded = isPointInsideAnyOccupiedPairBounds(rightDotX, mirrorY)
                        local drewAnyDotForPair = false

                        if verticalInBounds and leftInBounds and not leftOccluded then
                            if canUseDotSprite then
                                DrawSprite(
                                    dotTextureDict,
                                    dotTextureName,
                                    leftDotX,
                                    mirrorY,
                                    scaledDotWidth,
                                    scaledDotSize,
                                    0.0,
                                    tonumber(activeDotColor.r) or 255,
                                    tonumber(activeDotColor.g) or 190,
                                    tonumber(activeDotColor.b) or 190,
                                    tonumber(activeDotColor.a) or 235
                                )
                            else
                                DrawRect(
                                    leftDotX,
                                    mirrorY,
                                    scaledDotWidth,
                                    scaledDotSize,
                                    tonumber(activeDotColor.r) or 255,
                                    tonumber(activeDotColor.g) or 190,
                                    tonumber(activeDotColor.b) or 190,
                                    tonumber(activeDotColor.a) or 235
                                )
                            end

                            drewAnyDotForPair = true
                        end

                        if verticalInBounds and rightInBounds and not rightOccluded then
                            if canUseDotSprite then
                                DrawSprite(
                                    dotTextureDict,
                                    dotTextureName,
                                    rightDotX,
                                    mirrorY,
                                    scaledDotWidth,
                                    scaledDotSize,
                                    0.0,
                                    tonumber(activeDotColor.r) or 255,
                                    tonumber(activeDotColor.g) or 190,
                                    tonumber(activeDotColor.b) or 190,
                                    tonumber(activeDotColor.a) or 235
                                )
                            else
                                DrawRect(
                                    rightDotX,
                                    mirrorY,
                                    scaledDotWidth,
                                    scaledDotSize,
                                    tonumber(activeDotColor.r) or 255,
                                    tonumber(activeDotColor.g) or 190,
                                    tonumber(activeDotColor.b) or 190,
                                    tonumber(activeDotColor.a) or 235
                                )
                            end

                            drewAnyDotForPair = true
                        end

                        if drewAnyDotForPair then
                            occupiedHeadlightPairBounds[#occupiedHeadlightPairBounds + 1] = {
                                minX = math.min(leftDotX - halfDotWidth, rightDotX - halfDotWidth),
                                maxX = math.max(leftDotX + halfDotWidth, rightDotX + halfDotWidth),
                                minY = mirrorY - halfDotHeight,
                                maxY = mirrorY + halfDotHeight
                            }
                        end
                    end
                end
            end
        end
    end
end

local function gatherVirtualMirrorPollQueue(playerVehicle)
    local queue = {}
    local vehicles = getVehiclePoolSafe()

    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        if vehicle and vehicle ~= playerVehicle and DoesEntityExist(vehicle) then
            queue[#queue + 1] = vehicle
        end
    end

    state.mirrorPollQueue = queue
    state.mirrorPollQueueIndex = 1
end

local function rebuildVirtualMirrorTrackedVehicles(playerVehicle, playerCoords, searchRadiusSquared, maxTrackedVehicles)
    local tracker = state.virtualMirrorTracker or {}
    local trackedVehicles = {}

    for vehicle, _ in pairs(tracker) do
        if vehicle and vehicle ~= playerVehicle and DoesEntityExist(vehicle) then
            local vehicleCoords = getVehicleCenterCoordsSafe(vehicle)
            local toVehicle = subtractVector(vehicleCoords, playerCoords)
            local toVehicleFlat = vector3(toVehicle.x, toVehicle.y, 0.0)
            local distanceSquared = dot(toVehicleFlat, toVehicleFlat)

            if distanceSquared <= searchRadiusSquared and distanceSquared > 0.01 then
                trackedVehicles[#trackedVehicles + 1] = {
                    vehicle = vehicle,
                    distanceSquared = distanceSquared
                }
            else
                tracker[vehicle] = nil
            end
        else
            tracker[vehicle] = nil
        end
    end

    table.sort(trackedVehicles, function(a, b)
        return a.distanceSquared < b.distanceSquared
    end)

    while #trackedVehicles > maxTrackedVehicles do
        trackedVehicles[#trackedVehicles] = nil
    end

    local trackedVehicleHandles = {}
    for i = 1, #trackedVehicles do
        trackedVehicleHandles[i] = trackedVehicles[i].vehicle
    end

    state.virtualMirrorTracker = tracker
    state.virtualMirrorVehicles = trackedVehicleHandles
end

local function updateVirtualMirrorVehiclePollRoundRobin(playerVehicle)
    local mirror = Config.VirtualMirror
    if not mirror or mirror.enabled ~= true then
        state.virtualMirrorVehicles = {}
        state.virtualMirrorTracker = {}
        state.mirrorPollQueue = {}
        state.mirrorPollQueueIndex = 1
        state.mirrorPollAccumulator = 0.0
        return
    end

    local searchRadius = math.max(VIRTUAL_MIRROR_VEHICLE_POLL_RADIUS_METERS, 0.0)
    local searchRadiusSquared = searchRadius * searchRadius
    local checksPerSecond = math.max(tonumber(mirror.roundRobinChecksPerSecond) or 100.0, 1.0)
    local maxTrackedVehicles = math.max(math.floor(VIRTUAL_MIRROR_MAX_TRACKED_VEHICLES), 1)
    local playerCoords = getVehicleCenterCoordsSafe(playerVehicle)
    local playerForward = getEntityForwardVectorSafe(playerVehicle)
    local playerForwardFlat = normalize(vector3(playerForward.x, playerForward.y, 0.0))

    if vectorLength(playerForwardFlat) <= 0.001 then
        playerForwardFlat = vector3(0.0, 1.0, 0.0)
    end

    if #state.mirrorPollQueue <= 0 then
        gatherVirtualMirrorPollQueue(playerVehicle)
    end

    local tracker = state.virtualMirrorTracker or {}
    state.mirrorPollAccumulator = (state.mirrorPollAccumulator or 0.0) + (GetFrameTime() * checksPerSecond)
    local checksThisFrame = math.floor(state.mirrorPollAccumulator)
    if checksThisFrame > 0 then
        state.mirrorPollAccumulator = state.mirrorPollAccumulator - checksThisFrame
    end

    for _ = 1, checksThisFrame do
        local queue = state.mirrorPollQueue or {}
        if #queue <= 0 then
            gatherVirtualMirrorPollQueue(playerVehicle)
            queue = state.mirrorPollQueue or {}
            if #queue <= 0 then
                break
            end
        end

        local queueIndex = math.floor(tonumber(state.mirrorPollQueueIndex) or 1)
        if queueIndex < 1 then
            queueIndex = 1
        end
        if queueIndex > #queue then
            state.mirrorPollQueue = {}
            state.mirrorPollQueueIndex = 1
            gatherVirtualMirrorPollQueue(playerVehicle)
            queue = state.mirrorPollQueue or {}
            queueIndex = 1
            if #queue <= 0 then
                break
            end
        end

        local vehicle = queue[queueIndex]
        queueIndex = queueIndex + 1
        if queueIndex > #queue then
            state.mirrorPollQueue = {}
            state.mirrorPollQueueIndex = 1
        else
            state.mirrorPollQueueIndex = queueIndex
        end

        if vehicle and vehicle ~= playerVehicle and DoesEntityExist(vehicle) then
            local vehicleCoords = getVehicleCenterCoordsSafe(vehicle)
            local toVehicle = subtractVector(vehicleCoords, playerCoords)
            local toVehicleFlat = vector3(toVehicle.x, toVehicle.y, 0.0)
            local distanceSquared = dot(toVehicleFlat, toVehicleFlat)
            local isTracked = false

            if distanceSquared <= searchRadiusSquared and distanceSquared > 0.01 then
                local longitudinalDistance = dot(toVehicleFlat, playerForwardFlat)
                isTracked = longitudinalDistance < 0.0
            end

            if isTracked then
                tracker[vehicle] = true
            else
                tracker[vehicle] = nil
            end
        else
            tracker[vehicle] = nil
        end
    end

    state.virtualMirrorTracker = tracker
    rebuildVirtualMirrorTrackedVehicles(playerVehicle, playerCoords, searchRadiusSquared, maxTrackedVehicles)
end

-- Hood mode only needs to keep the attach and focus state alive.
local function updateHoodCam(vehicle)
    local previousLookBackState = state.lookBackActive
    updateLookBackState()
    if not state.hoodAttached or previousLookBackState ~= state.lookBackActive then
        attachHoodCam(vehicle, state.lookBackActive)
    end

    state.position = GetCamCoord(state.cam)
    syncCameraFov()
    SetCamFov(state.cam, state.fov)
    SetFocusPosAndVel(state.position.x, state.position.y, state.position.z, 0.0, 0.0, 0.0)
end

-- The follow loop advances the camera toward the vehicle and keeps it stable.
local function updateFollowCam()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        cleanupCamera()
        return
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if isHoodViewMode() then
        updateHoodCam(vehicle)
        return
    end

    updateLookBackState()

    if state.hoodAttached then
        DetachCam(state.cam)
        state.hoodAttached = false
        seedFollowState(vehicle)
    end

    if not state.position or not state.focus or not state.rotation then
        seedFollowState(vehicle)
    end

    if not state.position or not state.focus or not state.rotation then
        cleanupCamera()
        return
    end

    local rotationVelocity = GetEntityRotationVelocity(vehicle)
    local uprightValue = GetEntityUprightValue(vehicle)
    local upsideDown = uprightValue <= FOLLOW_CAM_UPRIGHT_THRESHOLD_RATIO
    local onAllWheels = IsVehicleOnAllWheels(vehicle)

    if state.lookAheadEnabled then
        if upsideDown or math.abs(rotationVelocity.x) >= FOLLOW_CAM_FLIP_ANGULAR_VELOCITY_X_RADIANS_PER_SECOND then
            state.lookAheadEnabled = false
        end
    elseif onAllWheels and uprightValue >= FOLLOW_CAM_UPRIGHT_RECOVERY_THRESHOLD_RATIO then
        state.lookAheadEnabled = true
    end

    local desiredPosition, desiredFocus = getDesiredFollowData()
    local dt = GetFrameTime()
    local toTarget = subtractVector(desiredPosition, state.position)
    local distance = vectorLength(toTarget)
    local minDim, maxDim = GetModelDimensions(GetEntityModel(vehicle))
    local vehicleLength = math.abs(maxDim.y - minDim.y) * 0.5
    local vehicleCoords = GetEntityCoords(vehicle)
    local currentOffsetFromVehicle = subtractVector(state.position, vehicleCoords)
    local currentVehicleDistance = vectorLength(currentOffsetFromVehicle)
    local minBubbleDistance = getMinimumBubbleDistance(vehicleLength)
    local vehicleSpeed = GetEntitySpeed(vehicle)
    local distanceOffset = distance - FOLLOW_CAM_SPEED_MATCH_DISTANCE_METERS
    local signedDistanceGain = signedPower(distanceOffset, 1.35) * FOLLOW_CAM_CATCHUP_FACTOR
    local desiredScalarSpeed = vehicleSpeed + signedDistanceGain
    local bubbleEscapeSpeed = FOLLOW_CAM_MINIMUM_BUBBLE_ESCAPE_SPEED_METERS_PER_SECOND

    if currentVehicleDistance < minBubbleDistance then
        desiredScalarSpeed = math.max(desiredScalarSpeed, bubbleEscapeSpeed)
    end

    local desiredVelocity = scaleVector(
        normalize(toTarget),
        desiredScalarSpeed
    )
    local velocityError = subtractVector(desiredVelocity, state.velocity)
    local acceleration = subtractVector(
        scaleVector(velocityError, FOLLOW_CAM_ACCELERATION_FACTOR),
        scaleVector(state.velocity, FOLLOW_CAM_DAMPING_FACTOR)
    )

    state.velocity = addVector(state.velocity, scaleVector(acceleration, dt))
    state.position = addVector(state.position, scaleVector(state.velocity, dt))
    state.focus = desiredFocus

    local targetRotation = directionToRotation(subtractVector(state.focus, state.position))
    state.rotation, state.rotationSpeed = smoothRotation(state.rotation, state.rotationSpeed, targetRotation, dt)
    local appliedPosition = state.position
    local appliedRotation = state.rotation

    if state.lookBackActive then
        local renderVehicleCoords = GetEntityCoords(vehicle)
        local relativeOffset = subtractVector(state.position, renderVehicleCoords)
        appliedPosition = addVector(
            renderVehicleCoords,
            vector3(-relativeOffset.x, -relativeOffset.y, relativeOffset.z)
        )
        appliedRotation = vector3(
            appliedRotation.x,
            appliedRotation.y,
            normalizeAngle(appliedRotation.z + 180.0)
        )
    end

    syncCameraFov()
    SetCamCoord(state.cam, appliedPosition.x, appliedPosition.y, appliedPosition.z)
    SetCamRot(state.cam, appliedRotation.x, appliedRotation.y, appliedRotation.z, 2)
    SetCamFov(state.cam, state.fov)
    SetFocusPosAndVel(appliedPosition.x, appliedPosition.y, appliedPosition.z, 0.0, 0.0, 0.0)
end

-- Holding the camera control for long enough toggles the custom camera state.
local function isToggleCameraHeld()
    return IsControlPressed(0, 0)
end

-- The hold-toggle state machine prevents accidental camera flicker.
local function updateToggleHoldState()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        toggleHoldState.heldSince = nil
        toggleHoldState.hasTriggered = false
        return false
    end

    if not isToggleCameraHeld() then
        toggleHoldState.heldSince = nil
        toggleHoldState.hasTriggered = false
        return false
    end

    if not toggleHoldState.heldSince then
        toggleHoldState.heldSince = GetGameTimer()
        toggleHoldState.hasTriggered = false
        return false
    end

    if toggleHoldState.hasTriggered then
        return true
    end

    if (GetGameTimer() - toggleHoldState.heldSince) < (Config.toggleHoldMs or 1000) then
        return true
    end

    toggleHoldState.hasTriggered = true

    if state.active then
        cleanupCamera()
    else
        startFollowCam()
    end

    return true
end

CreateThread(function()
    while true do
        local mirror = Config.VirtualMirror

        if state.active and mirror and mirror.enabled == true then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                local vehicle = GetVehiclePedIsIn(ped, false)
                if vehicle and vehicle ~= 0 then
                    updateVirtualMirrorVehiclePollRoundRobin(vehicle)
                    Wait(0)
                else
                    state.virtualMirrorVehicles = {}
                    state.virtualMirrorTracker = {}
                    state.mirrorPollQueue = {}
                    state.mirrorPollQueueIndex = 1
                    state.mirrorPollAccumulator = 0.0
                    Wait(100)
                end
            else
                state.virtualMirrorVehicles = {}
                state.virtualMirrorTracker = {}
                state.mirrorPollQueue = {}
                state.mirrorPollQueueIndex = 1
                state.mirrorPollAccumulator = 0.0
                Wait(100)
            end
        else
            state.virtualMirrorVehicles = {}
            state.virtualMirrorTracker = {}
            state.mirrorPollQueue = {}
            state.mirrorPollQueueIndex = 1
            state.mirrorPollAccumulator = 0.0
            Wait(250)
        end
    end
end)

-- The main loop keeps the camera responsive without burning cycles when idle.
CreateThread(function()
    while true do
        local handledToggle = updateToggleHoldState()

        if state.active then
            Wait(0)
            disableGameplayControls()
            drawVirtualMirrorOverlay()
            updateFollowCam()
        else
            Wait(handledToggle and 0 or 250)
        end
    end
end)

-- Resource shutdown always cleans up the active scripted camera.
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    cleanupCamera()
end)
