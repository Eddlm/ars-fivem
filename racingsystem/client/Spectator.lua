RacingSystem = RacingSystem or {}
RacingSystem.Client = RacingSystem.Client or {}
RacingSystem.Client.Spectator = RacingSystem.Client.Spectator or {}

local spectatorConfig = {
    cameraName = 'DEFAULT_SCRIPTED_CAMERA',
    updateIntervalMs = 0,
    defaultFov = 55.0,
    minFov = 25.0,
    maxFov = 85.0,
    defaultHeightMeters = 4.0,
    minHeightMeters = 10.0,
    maxHeightMeters = 160.0,
    minPitchDegrees = -80.0,
    maxPitchDegrees = 80.0,
    defaultPitchDegrees = -55.0,
    defaultYawDegrees = 0.0,
    moveSpeedMetersPerSecond = 42.0,
    verticalSpeedMetersPerSecond = 24.0,
    sprintMultiplier = 2.0,
    edgeScrollThresholdNormalized = 0.025,
    zoomStepFovDegrees = 2.5,
    zoomStepHeightMeters = 2.0,
    yawStepDegrees = 1.5,
    pitchStepDegrees = 1.0,
    smoothing = {
        position = 10.0,
        rotation = 14.0,
        zoom = 16.0,
    },
    controls = {
        moveForward = 32,
        moveBackward = 33,
        moveLeft = 34,
        moveRight = 35,
        moveUp = 21,
        moveDown = 36,
        sprint = 21,
        rotateLeft = 174,
        rotateRight = 175,
        rotateUp = 172,
        rotateDown = 173,
        zoomIn = 241,
        zoomOut = 242,
        dragPan = 25,
    },
}
RacingSystem.Client.Spectator.config = spectatorConfig

local spectatorRuntime = {
    enabled = false,
    editorOwned = false,
    mode = 'rts',
    targetEntity = nil,
    targetCoords = nil,
    camera = {
        handle = nil,
        active = false,
        initialized = false,
        fov = spectatorConfig.defaultFov,
        height = spectatorConfig.defaultHeightMeters,
        pitch = spectatorConfig.defaultPitchDegrees,
        yaw = spectatorConfig.defaultYawDegrees,
        roll = 0.0,
        coords = nil,
        lookAt = nil,
    },
    motion = {
        moveVector = vector3(0.0, 0.0, 0.0),
        worldVelocity = vector3(0.0, 0.0, 0.0),
        edgeScrollVector = vector3(0.0, 0.0, 0.0),
        dragPanVector = vector3(0.0, 0.0, 0.0),
        zoomVelocity = 0.0,
        yawVelocity = 0.0,
        pitchVelocity = 0.0,
    },
    input = {
        hasKeyboardInput = false,
        hasMouseInput = false,
        hasGamepadInput = false,
        mouseScreenX = 0.5,
        mouseScreenY = 0.5,
        mouseDeltaX = 0.0,
        mouseDeltaY = 0.0,
        wheelDelta = 0.0,
        lastInputAt = 0,
    },
    bounds = {
        center = nil,
        radius = nil,
        minZ = nil,
        maxZ = nil,
    },
    debug = {
        drawAnchor = false,
        drawBounds = false,
        printInput = false,
    },
}
RacingSystem.Client.Spectator.runtime = spectatorRuntime

function RacingSystem.Client.Spectator.isActive()
    return spectatorRuntime.enabled == true
end

function RacingSystem.Client.Spectator.getPose()
    local camera = spectatorRuntime.camera
    if spectatorRuntime.enabled ~= true or not camera or not camera.handle or not camera.coords then
        return nil
    end
    return {
        x = tonumber(camera.coords.x) or 0.0,
        y = tonumber(camera.coords.y) or 0.0,
        z = tonumber(camera.coords.z) or 0.0,
        pitch = tonumber(camera.pitch) or 0.0,
        yaw = tonumber(camera.yaw) or 0.0,
        roll = tonumber(camera.roll) or 0.0,
    }
end

local function getCameraGroundAnchor()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local x = tonumber(coords.x) or 0.0
    local y = tonumber(coords.y) or 0.0
    local z = tonumber(coords.z) or 0.0
    local _, groundZ = GetGroundZFor_3dCoord(x, y, z + 100.0, false)
    return vector3(x, y, (tonumber(groundZ) or z) + 4.0)
end

local function setCameraToAnchor()
    local camera = spectatorRuntime.camera
    if not camera.handle then
        return
    end

    local anchor = getCameraGroundAnchor()
    camera.coords = anchor
    SetCamCoord(camera.handle, anchor.x, anchor.y, anchor.z)
end

local function isControlPressedAnyPad(controlId)
    return IsControlPressed(0, controlId)
        or IsControlPressed(1, controlId)
        or IsControlPressed(2, controlId)
        or IsDisabledControlPressed(0, controlId)
        or IsDisabledControlPressed(1, controlId)
        or IsDisabledControlPressed(2, controlId)
end

local function getMoveInput()
    local controls = spectatorConfig.controls or {}
    local forward = 0.0
    local strafe = 0.0
    local vertical = 0.0

    if isControlPressedAnyPad(tonumber(controls.moveForward) or 32) then
        forward = forward + 1.0
    end
    if isControlPressedAnyPad(tonumber(controls.moveBackward) or 33) then
        forward = forward - 1.0
    end
    if isControlPressedAnyPad(tonumber(controls.moveRight) or 35) then
        strafe = strafe + 1.0
    end
    if isControlPressedAnyPad(tonumber(controls.moveLeft) or 34) then
        strafe = strafe - 1.0
    end
    if isControlPressedAnyPad(tonumber(controls.moveUp) or 21) then
        vertical = vertical + 1.0
    end
    if isControlPressedAnyPad(tonumber(controls.moveDown) or 36) then
        vertical = vertical - 1.0
    end

    local length = math.sqrt((forward * forward) + (strafe * strafe))
    if length > 0.001 then
        return forward / length, strafe / length, vertical
    end

    return 0.0, 0.0, vertical
end

local function updateCameraMovement(dt)
    local camera = spectatorRuntime.camera
    if not camera.handle or not camera.coords then
        return
    end

    local forwardInput, strafeInput, verticalInput = getMoveInput()
    if math.abs(forwardInput) <= 0.001 and math.abs(strafeInput) <= 0.001 and math.abs(verticalInput) <= 0.001 then
        return
    end

    local yawRadians = math.rad(tonumber(camera.yaw) or 0.0)
    local forwardX = -math.sin(yawRadians)
    local forwardY = math.cos(yawRadians)
    local rightX = math.cos(yawRadians)
    local rightY = math.sin(yawRadians)

    local moveX = (forwardX * forwardInput) + (rightX * strafeInput)
    local moveY = (forwardY * forwardInput) + (rightY * strafeInput)
    local moveLength = math.sqrt((moveX * moveX) + (moveY * moveY))
    if moveLength > 0.001 then
        moveX = moveX / moveLength
        moveY = moveY / moveLength
    else
        moveX = 0.0
        moveY = 0.0
    end

    local speed = tonumber(spectatorConfig.moveSpeedMetersPerSecond) or 42.0
    local verticalSpeed = tonumber(spectatorConfig.verticalSpeedMetersPerSecond) or speed

    local currentCoords = camera.coords
    local deltaTime = tonumber(dt) or 0.0
    local nextX = currentCoords.x + (moveX * speed * deltaTime)
    local nextY = currentCoords.y + (moveY * speed * deltaTime)
    local nextZ = currentCoords.z + (verticalInput * verticalSpeed * deltaTime)

    camera.coords = vector3(nextX, nextY, nextZ)
    SetCamCoord(camera.handle, camera.coords.x, camera.coords.y, camera.coords.z)
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

local function getLookInput()
    local lookX = 0.0
    local lookY = 0.0
    local lookControlX = 1
    local lookControlY = 2

    lookX = lookX + (tonumber(GetDisabledControlNormal(0, lookControlX)) or 0.0)
    lookY = lookY + (tonumber(GetDisabledControlNormal(0, lookControlY)) or 0.0)
    lookX = lookX + (tonumber(GetDisabledControlNormal(1, lookControlX)) or 0.0)
    lookY = lookY + (tonumber(GetDisabledControlNormal(1, lookControlY)) or 0.0)
    lookX = lookX + (tonumber(GetDisabledControlNormal(2, lookControlX)) or 0.0)
    lookY = lookY + (tonumber(GetDisabledControlNormal(2, lookControlY)) or 0.0)

    if math.abs(lookX) <= 0.0001 then
        lookX = lookX + (tonumber(GetControlNormal(0, lookControlX)) or 0.0)
    end
    if math.abs(lookY) <= 0.0001 then
        lookY = lookY + (tonumber(GetControlNormal(0, lookControlY)) or 0.0)
    end

    return lookX, lookY
end

local function updateCameraAimRotation(dt)
    local camera = spectatorRuntime.camera
    if not camera.handle then
        return
    end

    local lookX, lookY = getLookInput()
    local deltaTime = tonumber(dt) or 0.0
    local yawRate = 220.0
    local pitchRate = 180.0
    camera.yaw = normalizeAngle(camera.yaw - (lookX * yawRate * deltaTime))
    camera.pitch = camera.pitch - (lookY * pitchRate * deltaTime)
    camera.pitch = math.max(tonumber(spectatorConfig.minPitchDegrees) or -80.0, math.min(tonumber(spectatorConfig.maxPitchDegrees) or -20.0, camera.pitch))
    camera.roll = 0.0
    SetCamRot(camera.handle, camera.pitch, 0.0, camera.yaw, 2)
end

local function updateGameFocusFromCamera()
    local camera = spectatorRuntime.camera
    if not camera or not camera.handle then
        return
    end

    local focusCoords = nil
    if type(GetCamCoord) == 'function' then
        local liveCamCoords = GetCamCoord(camera.handle)
        if type(liveCamCoords) == 'vector3' then
            focusCoords = liveCamCoords
        end
    end
    if not focusCoords then
        focusCoords = camera.coords
    end
    if type(focusCoords) ~= 'vector3' then
        return
    end

    SetFocusPosAndVel(
        focusCoords.x,
        focusCoords.y,
        focusCoords.z,
        0.0,
        0.0,
        0.0
    )
end

local function disableSpectatorCombatControls()
    DisableControlAction(0, 37, true)
    DisableControlAction(1, 37, true)
    DisableControlAction(2, 37, true)
end

local function stopSpectatorMode()
    local camera = spectatorRuntime.camera
    local ped = PlayerPedId()

    spectatorRuntime.enabled = false
    spectatorRuntime.editorOwned = false
    camera.active = false
    camera.initialized = false
    camera.coords = nil
    camera.lookAt = nil

    if camera.handle then
        RenderScriptCams(false, true, 350, true, true)
        DestroyCam(camera.handle, false)
        camera.handle = nil
    end
    ClearFocus()

    FreezeEntityPosition(ped, false)
    if RacingSystem.Client.Util and type(RacingSystem.Client.Util.NotifyPlayer) == 'function' then
        RacingSystem.Client.Util.NotifyPlayer('Spectator mode disabled.')
    end
end

local function startSpectatorMode()
    local camera = spectatorRuntime.camera
    local ped = PlayerPedId()

    if camera.handle then
        DestroyCam(camera.handle, false)
        camera.handle = nil
    end

    camera.handle = CreateCam(spectatorConfig.cameraName, true)
    camera.fov = spectatorConfig.defaultFov
    camera.active = true
    camera.initialized = true
    camera.pitch = spectatorConfig.defaultPitchDegrees
    camera.yaw = spectatorConfig.defaultYawDegrees
    camera.roll = 0.0
    spectatorRuntime.motion.pitchVelocity = 0.0
    spectatorRuntime.motion.yawVelocity = 0.0

    setCameraToAnchor()
    SetCamFov(camera.handle, camera.fov)
    SetCamRot(camera.handle, camera.pitch, 0.0, camera.yaw, 2)

    FreezeEntityPosition(ped, true)
    SetCamActive(camera.handle, true)
    RenderScriptCams(true, true, 350, true, true)
    updateGameFocusFromCamera()
    spectatorRuntime.enabled = true

    if RacingSystem.Client.Util and type(RacingSystem.Client.Util.NotifyPlayer) == 'function' then
        RacingSystem.Client.Util.NotifyPlayer('Spectator mode enabled.')
    end
end

function RacingSystem.Client.Spectator.enableForEditor()
    if spectatorRuntime.enabled then
        spectatorRuntime.editorOwned = false
        return true
    end
    startSpectatorMode()
    spectatorRuntime.editorOwned = spectatorRuntime.enabled == true
    return spectatorRuntime.enabled == true
end

function RacingSystem.Client.Spectator.disableForEditorIfOwned()
    if spectatorRuntime.editorOwned ~= true then
        return
    end
    stopSpectatorMode()
end

local function toggleSpectatorMode()
    if spectatorRuntime.enabled then
        stopSpectatorMode()
        return
    end
    startSpectatorMode()
end

RegisterCommand('spec', function()
    toggleSpectatorMode()
end, false)

CreateThread(function()
    while true do
        if spectatorRuntime.enabled then
            local ped = PlayerPedId()
            FreezeEntityPosition(ped, true)
            disableSpectatorCombatControls()
            updateCameraMovement(GetFrameTime())
            updateCameraAimRotation(GetFrameTime())
            updateGameFocusFromCamera()
            Wait(math.max(0, math.floor(tonumber(spectatorConfig.updateIntervalMs) or 0)))
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    stopSpectatorMode()
end)
