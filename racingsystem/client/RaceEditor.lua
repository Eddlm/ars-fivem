RacingSystem = RacingSystem or {}
RacingSystem.Client = RacingSystem.Client or {}
RacingSystem.Menu = RacingSystem.Menu or {}

local editorState = {
    active = false,
    name = '',
    selectedName = '',
    checkpoints = {},
    grabbedCheckpointIndex = nil,
    finishLineCheckpointIndex = nil,
    defaultCheckpointRadius = 8.0,
    mouseGrabActive = false,
}
RacingSystem.Client.editorState = editorState

local ClientAdvancedConfig = (((RacingSystem or {}).Config or {}).advanced or {}).client or {}
local CHECKPOINT_RADIUS_STEP_METERS = tonumber(ClientAdvancedConfig.checkpointRadiusStepMeters) or 1.0
local EDITOR_PITCH_UP_CONTROL_ID = math.floor(tonumber(ClientAdvancedConfig.editorPitchUpControlId) or 111)
local EDITOR_PITCH_DOWN_CONTROL_ID = math.floor(tonumber(ClientAdvancedConfig.editorPitchDownControlId) or 112)
local EDITOR_MOUSE_GRAB_CONTROL_ID = 24
local EDITOR_MOUSE_SCROLL_UP_CONTROL_ID = 241
local EDITOR_MOUSE_SCROLL_DOWN_CONTROL_ID = 242
local MARKER_TAXONOMY = ClientAdvancedConfig.markerTaxonomy or {}
local EDITOR_TARGET_RAYCAST_RANGE_METERS = 300.0

local editorTargetState = {
    hit = nil,
    camera = nil,
}

local function setEditorCursorHidden(hidden)
    if type(SetMouseCursorVisibleInMenus) == 'function' then
        SetMouseCursorVisibleInMenus(hidden ~= true)
    end
end

local function cloneCheckpoints(checkpoints)
    local cloned = {}
    for index, checkpoint in ipairs(type(checkpoints) == 'table' and checkpoints or {}) do
        cloned[index] = {
            index = tonumber(checkpoint.index) or index,
            x = tonumber(checkpoint.x) or 0.0,
            y = tonumber(checkpoint.y) or 0.0,
            z = tonumber(checkpoint.z) or 0.0,
            radius = tonumber(checkpoint.radius) or 8.0,
            markerZ = tonumber(checkpoint.markerZ),
            rotX = tonumber(checkpoint.rotX),
            rotY = tonumber(checkpoint.rotY),
            rotZ = tonumber(checkpoint.rotZ),
            sampledX = tonumber(checkpoint.sampledX),
            sampledY = tonumber(checkpoint.sampledY),
            sampledZ = tonumber(checkpoint.sampledZ),
        }
    end
    return cloned
end

local function normalizeCheckpointIndexes()
    for index, checkpoint in ipairs(editorState.checkpoints) do
        checkpoint.index = index
    end
    if editorState.grabbedCheckpointIndex and editorState.grabbedCheckpointIndex > #editorState.checkpoints then
        editorState.grabbedCheckpointIndex = nil
        editorState.mouseGrabActive = false
    end
    if editorState.finishLineCheckpointIndex and editorState.finishLineCheckpointIndex > #editorState.checkpoints then
        editorState.finishLineCheckpointIndex = nil
    end
end

local function removeCheckpointAtIndex(indexToRemove)
    local checkpointIndex = math.floor(tonumber(indexToRemove) or 0)
    if checkpointIndex < 1 or checkpointIndex > #editorState.checkpoints then
        return
    end

    table.remove(editorState.checkpoints, checkpointIndex)

    local finishIndex = tonumber(editorState.finishLineCheckpointIndex)
    if finishIndex then
        if finishIndex == checkpointIndex then
            editorState.finishLineCheckpointIndex = nil
        elseif finishIndex > checkpointIndex then
            editorState.finishLineCheckpointIndex = finishIndex - 1
        end
    end

    editorState.grabbedCheckpointIndex = nil
    editorState.mouseGrabActive = false
    normalizeCheckpointIndexes()
end

local function getSpectatorPose()
    local spectator = ((RacingSystem or {}).Client or {}).Spectator
    if type(spectator) ~= 'table' or type(spectator.getPose) ~= 'function' then
        return nil
    end
    return spectator.getPose()
end

local function getEditorCameraCoords()
    local camera = editorTargetState.camera
    if type(camera) ~= 'vector3' then
        return nil
    end
    return camera
end
RacingSystem.Client.getEditorCameraCoords = getEditorCameraCoords

local function directionFromRotation(pitchDegrees, yawDegrees)
    local pitchRadians = math.rad(tonumber(pitchDegrees) or 0.0)
    local yawRadians = math.rad(tonumber(yawDegrees) or 0.0)
    local cosPitch = math.cos(pitchRadians)
    return vector3(
        -math.sin(yawRadians) * cosPitch,
        math.cos(yawRadians) * cosPitch,
        math.sin(pitchRadians)
    )
end

local function getEditorRaycastHit()
    local pose = getSpectatorPose()
    if type(pose) ~= 'table' then
        return nil
    end

    local origin = vector3(
        tonumber(pose.x) or 0.0,
        tonumber(pose.y) or 0.0,
        tonumber(pose.z) or 0.0
    )
    local forward = directionFromRotation(pose.pitch, pose.yaw)
    local destination = vector3(
        origin.x + (forward.x * EDITOR_TARGET_RAYCAST_RANGE_METERS),
        origin.y + (forward.y * EDITOR_TARGET_RAYCAST_RANGE_METERS),
        origin.z + (forward.z * EDITOR_TARGET_RAYCAST_RANGE_METERS)
    )

    local rayHandle = StartExpensiveSynchronousShapeTestLosProbe(
        origin.x,
        origin.y,
        origin.z,
        destination.x,
        destination.y,
        destination.z,
        17,
        0,
        4
    )
    local hitState, didHit, endCoords, _, _, entityHit = GetShapeTestResultIncludingMaterial(rayHandle)
    local validHit = (didHit == 1) or (didHit == true)
    if hitState ~= 2 or not validHit or type(endCoords) ~= 'vector3' then
        return nil
    end
    if entityHit and entityHit ~= 0 and (IsEntityAPed(entityHit) or IsEntityAVehicle(entityHit)) then
        return nil
    end
    return vector3(
        tonumber(endCoords.x) or 0.0,
        tonumber(endCoords.y) or 0.0,
        tonumber(endCoords.z) or 0.0
    )
end

local function refreshEditorTargetState()
    local pose = getSpectatorPose()
    if type(pose) == 'table' then
        editorTargetState.camera = vector3(
            tonumber(pose.x) or 0.0,
            tonumber(pose.y) or 0.0,
            tonumber(pose.z) or 0.0
        )
    else
        editorTargetState.camera = nil
    end
    editorTargetState.hit = getEditorRaycastHit()
end

local function getEditorTargetCoords()
    local hit = editorTargetState.hit
    if type(hit) ~= 'vector3' then
        return nil
    end
    return hit
end
RacingSystem.Client.getEditorTargetCoords = getEditorTargetCoords

local function getCheckpointRaycastIgnoredEntity()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then
        return 0
    end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        return vehicle
    end
    return ped
end

local function sampleCheckpointSurface(x, y, z, topOffset, bottomOffset)
    local ignoredEntity = getCheckpointRaycastIgnoredEntity()
    local rayHandle = StartExpensiveSynchronousShapeTestLosProbe(
        x,
        y,
        z + (tonumber(topOffset) or 2.0),
        x,
        y,
        z - (tonumber(bottomOffset) or 20.0),
        511,
        ignoredEntity,
        4
    )
    local hitState, didHit, endCoords, surfaceNormal = GetShapeTestResultIncludingMaterial(rayHandle)
    if hitState ~= 2 or not didHit or not endCoords or not surfaceNormal then
        return nil
    end
    return {
        z = tonumber(endCoords.z) or z,
        nx = tonumber(surfaceNormal.x) or 0.0,
        ny = tonumber(surfaceNormal.y) or 0.0,
        nz = tonumber(surfaceNormal.z) or 1.0,
    }
end

local function refreshCheckpointMarkerAlignment(checkpoint)
    if type(checkpoint) ~= 'table' then
        return
    end
    local x = tonumber(checkpoint.x) or 0.0
    local y = tonumber(checkpoint.y) or 0.0
    local z = tonumber(checkpoint.z) or 0.0
    local sampleOffset = 1.25
    local samplePositions = {
        { x = x - sampleOffset, y = y },
        { x = x + sampleOffset, y = y },
        { x = x, y = y + sampleOffset },
    }
    local function collectSampleHits(topOffset, bottomOffset)
        local totalZ = 0.0
        local sampleHits = {}
        for _, samplePosition in ipairs(samplePositions) do
            local sample = sampleCheckpointSurface(samplePosition.x, samplePosition.y, z, topOffset, bottomOffset)
            if sample then
                totalZ = totalZ + sample.z
                sampleHits[#sampleHits + 1] = {
                    x = samplePosition.x,
                    y = samplePosition.y,
                    z = sample.z,
                }
            end
        end
        return totalZ, sampleHits
    end
    local totalZ, sampleHits = collectSampleHits(2.0, 20.0)
    if #sampleHits >= 3 then
        local averageZ = totalZ / #sampleHits
        if (averageZ - 6.0) < (z - 20.0) then
            totalZ, sampleHits = collectSampleHits(40.0, 80.0)
        end
    elseif z ~= nil then
        totalZ, sampleHits = collectSampleHits(40.0, 80.0)
    end
    if #sampleHits >= 3 then
        local averageZ = totalZ / #sampleHits
        local pointA = sampleHits[1]
        local pointB = sampleHits[2]
        local pointC = sampleHits[3]
        local abX = pointB.x - pointA.x
        local abY = pointB.y - pointA.y
        local abZ = pointB.z - pointA.z
        local acX = pointC.x - pointA.x
        local acY = pointC.y - pointA.y
        local acZ = pointC.z - pointA.z
        local normalX = (abY * acZ) - (abZ * acY)
        local normalY = (abZ * acX) - (abX * acZ)
        local normalZ = (abX * acY) - (abY * acX)
        local normalLength = math.sqrt((normalX * normalX) + (normalY * normalY) + (normalZ * normalZ))
        if normalLength > 0.0001 then
            normalX = normalX / normalLength
            normalY = normalY / normalLength
            normalZ = normalZ / normalLength
        else
            normalX = 0.0
            normalY = 0.0
            normalZ = 1.0
        end
        if normalZ < 0.0 then
            normalX = -normalX
            normalY = -normalY
            normalZ = -normalZ
        end
        checkpoint.markerZ = averageZ - 3.0
        checkpoint.rotX = -math.deg(math.atan2(normalY, normalZ))
        checkpoint.rotY = -math.deg(math.atan2(normalX, normalZ))
        checkpoint.rotZ = 0.0
    else
        checkpoint.markerZ = z - 2.5
        checkpoint.rotX = 0.0
        checkpoint.rotY = 0.0
        checkpoint.rotZ = 0.0
    end
    checkpoint.sampledX = x
    checkpoint.sampledY = y
    checkpoint.sampledZ = z
end

local function ensureCheckpointMarkerAlignment(checkpoint)
    if type(checkpoint) ~= 'table' then
        return
    end
    local x = tonumber(checkpoint.x) or 0.0
    local y = tonumber(checkpoint.y) or 0.0
    local z = tonumber(checkpoint.z) or 0.0
    local sampledX = tonumber(checkpoint.sampledX)
    local sampledY = tonumber(checkpoint.sampledY)
    local sampledZ = tonumber(checkpoint.sampledZ)
    local needsRefresh = checkpoint.markerZ == nil
        or checkpoint.rotX == nil
        or checkpoint.rotY == nil
        or checkpoint.rotZ == nil
        or sampledX == nil
        or sampledY == nil
        or sampledZ == nil
        or math.abs(x - sampledX) > 0.75
        or math.abs(y - sampledY) > 0.75
        or math.abs(z - sampledZ) > 0.75
    if needsRefresh then
        refreshCheckpointMarkerAlignment(checkpoint)
    end
end

local function getClosestCheckpointIndex()
    local coords = getEditorTargetCoords()
    if not coords then
        return nil, nil
    end
    local closestIndex
    local closestDistance
    for index, checkpoint in ipairs(editorState.checkpoints) do
        local dx = coords.x - checkpoint.x
        local dy = coords.y - checkpoint.y
        local dz = coords.z - checkpoint.z
        local distance = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
        if not closestDistance or distance < closestDistance then
            closestIndex = index
            closestDistance = distance
        end
    end
    return closestIndex, closestDistance
end

local function getClosestCheckpointIndexToCoords(coords)
    if type(coords) ~= 'vector3' then
        return nil, nil
    end
    local closestIndex = nil
    local closestDistance = nil
    for index, checkpoint in ipairs(editorState.checkpoints) do
        local dx = coords.x - (tonumber(checkpoint.x) or 0.0)
        local dy = coords.y - (tonumber(checkpoint.y) or 0.0)
        local dz = coords.z - (tonumber(checkpoint.z) or 0.0)
        local distance = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
        if not closestDistance or distance < closestDistance then
            closestIndex = index
            closestDistance = distance
        end
    end
    return closestIndex, closestDistance
end

function RacingSystem.Client.getEditorClosestCheckpoint()
    if type(editorState.checkpoints) ~= 'table' or #editorState.checkpoints == 0 then
        return nil
    end
    local closestIndex, closestDistance = getClosestCheckpointIndex()
    if not closestIndex then
        return nil
    end
    return {
        index = closestIndex,
        distance = closestDistance,
        checkpoint = editorState.checkpoints[closestIndex],
    }
end

local function getHeadingToNextCheckpoint(currentCheckpoint, nextCheckpoint)
    local currentX = tonumber(currentCheckpoint and currentCheckpoint.x) or 0.0
    local currentY = tonumber(currentCheckpoint and currentCheckpoint.y) or 0.0
    local nextX = tonumber(nextCheckpoint and nextCheckpoint.x) or currentX
    local nextY = tonumber(nextCheckpoint and nextCheckpoint.y) or currentY
    local dx = nextX - currentX
    local dy = nextY - currentY
    if math.abs(dx) <= 0.0001 and math.abs(dy) <= 0.0001 then
        return 0.0
    end
    return math.deg(math.atan2(dy, dx)) - 90.0
end

local function isEditorActive()
    return editorState.active == true
end

local function beginEditorSession(raceName, checkpoints)
    local spectator = ((RacingSystem or {}).Client or {}).Spectator
    if type(spectator) == 'table' and type(spectator.enableForEditor) == 'function' then
        spectator.enableForEditor()
    end

    editorState.active = true
    editorState.name = raceName or 'Untitled Race'
    editorState.selectedName = editorState.name
    editorState.checkpoints = cloneCheckpoints(checkpoints)
    editorState.mouseGrabActive = false
    normalizeCheckpointIndexes()
    if #editorState.checkpoints > 0 then
        editorState.finishLineCheckpointIndex = #editorState.checkpoints
    else
        editorState.finishLineCheckpointIndex = nil
    end
    for _, checkpoint in ipairs(editorState.checkpoints) do
        ensureCheckpointMarkerAlignment(checkpoint)
    end
    setEditorCursorHidden(true)
    refreshEditorTargetState()
    RacingSystem.Menu.beginEditorSessionUI()
end

local function endEditorSession()
    local spectator = ((RacingSystem or {}).Client or {}).Spectator
    if type(spectator) == 'table' and type(spectator.disableForEditorIfOwned) == 'function' then
        spectator.disableForEditorIfOwned()
    end

    RacingSystem.Menu.endEditorSessionUI()
    editorState.active = false
    editorState.name = ''
    editorState.checkpoints = {}
    editorState.grabbedCheckpointIndex = nil
    editorState.finishLineCheckpointIndex = nil
    editorState.mouseGrabActive = false
    editorTargetState.hit = nil
    editorTargetState.camera = nil
    setEditorCursorHidden(false)
end
RacingSystem.Client.endEditorSession = endEditorSession

local function addCheckpointAtPlayer()
    if not isEditorActive() then
        return
    end
    local coords = getEditorTargetCoords()
    if not coords then
        return
    end
    local checkpointToInsert = {
        index = #editorState.checkpoints + 1,
        x = coords.x,
        y = coords.y,
        z = coords.z,
        radius = tonumber(editorState.defaultCheckpointRadius) or 8.0,
    }

    if #editorState.checkpoints <= 0 then
        editorState.checkpoints[#editorState.checkpoints + 1] = checkpointToInsert
    else
        local closestIndex = getClosestCheckpointIndexToCoords(coords)
        if not closestIndex or closestIndex >= #editorState.checkpoints then
            editorState.checkpoints[#editorState.checkpoints + 1] = checkpointToInsert
        else
            local insertIndex = closestIndex + 1
            table.insert(editorState.checkpoints, insertIndex, checkpointToInsert)
            local finishIndex = tonumber(editorState.finishLineCheckpointIndex)
            if finishIndex and finishIndex >= insertIndex then
                editorState.finishLineCheckpointIndex = finishIndex + 1
            end
        end
    end

    normalizeCheckpointIndexes()
    local insertedCheckpoint = editorState.checkpoints[checkpointToInsert.index]
    if insertedCheckpoint then
        refreshCheckpointMarkerAlignment(insertedCheckpoint)
    end
end
RacingSystem.Client.addCheckpointAtPlayer = addCheckpointAtPlayer

local function setClosestCheckpointType(typeName)
    if not isEditorActive() then
        return
    end
    local closestIndex = getClosestCheckpointIndex()
    if not closestIndex then
        return
    end
    if tostring(typeName) == 'Finish Line' then
        editorState.finishLineCheckpointIndex = closestIndex
        return
    end
    if editorState.finishLineCheckpointIndex == closestIndex then
        editorState.finishLineCheckpointIndex = nil
    end
end
RacingSystem.Client.setClosestCheckpointType = setClosestCheckpointType

local function getClosestCheckpointType()
    if not isEditorActive() then
        return 'Checkpoint'
    end
    local closestIndex = getClosestCheckpointIndex()
    if not closestIndex then
        return nil
    end
    if editorState.finishLineCheckpointIndex == closestIndex then
        return 'Finish Line'
    end
    return 'Checkpoint'
end
RacingSystem.Client.getClosestCheckpointType = getClosestCheckpointType

local function ensureFinishBeforeSave()
    if #editorState.checkpoints == 0 then
        editorState.finishLineCheckpointIndex = nil
        return
    end
    local finishIndex = tonumber(editorState.finishLineCheckpointIndex)
    if not finishIndex or finishIndex < 1 or finishIndex > #editorState.checkpoints then
        editorState.finishLineCheckpointIndex = 1
    end
end

local function rotateCheckpointsSoFinishIsLast()
    local checkpointCount = #editorState.checkpoints
    if checkpointCount <= 1 then
        editorState.finishLineCheckpointIndex = checkpointCount == 1 and 1 or nil
        return
    end
    local finishIndex = tonumber(editorState.finishLineCheckpointIndex)
    if not finishIndex or finishIndex == checkpointCount then
        return
    end
    local rotated = {}
    local nextIndex = finishIndex + 1
    if nextIndex > checkpointCount then
        nextIndex = 1
    end
    for offset = 0, checkpointCount - 1 do
        local sourceIndex = nextIndex + offset
        if sourceIndex > checkpointCount then
            sourceIndex = sourceIndex - checkpointCount
        end
        rotated[#rotated + 1] = editorState.checkpoints[sourceIndex]
    end
    editorState.checkpoints = rotated
    editorState.finishLineCheckpointIndex = checkpointCount
end

local function prepareEditorCheckpointsForSave()
    if not isEditorActive() then
        return {}
    end
    ensureFinishBeforeSave()
    rotateCheckpointsSoFinishIsLast()
    normalizeCheckpointIndexes()
    for _, checkpoint in ipairs(editorState.checkpoints) do
        ensureCheckpointMarkerAlignment(checkpoint)
    end
    return cloneCheckpoints(editorState.checkpoints)
end
RacingSystem.Client.prepareEditorCheckpointsForSave = prepareEditorCheckpointsForSave

local function adjustClosestCheckpointRadius(direction)
    if not isEditorActive() then
        return
    end
    local targetIndex = editorState.grabbedCheckpointIndex
    if not targetIndex then
        targetIndex = getClosestCheckpointIndex()
    end
    if not targetIndex then
        return
    end
    local checkpoint = editorState.checkpoints[targetIndex]
    local step = CHECKPOINT_RADIUS_STEP_METERS
    local minimum = RacingSystem.Config.checkpointRadiusMinMeters or 2.0
    local maximum = RacingSystem.Config.checkpointRadiusMaxMeters or 40.0
    local updatedRadius = checkpoint.radius + (step * direction)
    checkpoint.radius = math.max(minimum, math.min(maximum, updatedRadius))
end

local function toggleGrabClosestCheckpoint()
    if not isEditorActive() then
        return
    end
    if editorState.grabbedCheckpointIndex then
        local grabbedCheckpoint = editorState.checkpoints[editorState.grabbedCheckpointIndex]
        editorState.grabbedCheckpointIndex = nil
        editorState.mouseGrabActive = false
        if grabbedCheckpoint then
            ensureCheckpointMarkerAlignment(grabbedCheckpoint)
        end
        return
    end
    local closestIndex = getClosestCheckpointIndex()
    if not closestIndex then
        return
    end
    editorState.grabbedCheckpointIndex = closestIndex
end
RacingSystem.Client.toggleGrabClosestCheckpoint = toggleGrabClosestCheckpoint

local function releaseMouseGrab()
    local grabbedIndex = tonumber(editorState.grabbedCheckpointIndex)
    if not grabbedIndex then
        editorState.mouseGrabActive = false
        return
    end

    local grabbedCheckpoint = editorState.checkpoints[grabbedIndex]
    local shouldDeleteGrabbed = false

    if type(grabbedCheckpoint) == 'table' then
        local grabbedX = tonumber(grabbedCheckpoint.x) or 0.0
        local grabbedY = tonumber(grabbedCheckpoint.y) or 0.0
        local grabbedZ = tonumber(grabbedCheckpoint.z) or 0.0

        for index, checkpoint in ipairs(editorState.checkpoints) do
            if index ~= grabbedIndex and type(checkpoint) == 'table' then
                local dx = grabbedX - (tonumber(checkpoint.x) or 0.0)
                local dy = grabbedY - (tonumber(checkpoint.y) or 0.0)
                local dz = grabbedZ - (tonumber(checkpoint.z) or 0.0)
                local distance = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
                local targetRadius = math.max(0.1, tonumber(checkpoint.radius) or 8.0)

                if distance <= targetRadius then
                    shouldDeleteGrabbed = true
                    break
                end
            end
        end
    end

    if shouldDeleteGrabbed then
        removeCheckpointAtIndex(grabbedIndex)
    elseif grabbedCheckpoint then
        ensureCheckpointMarkerAlignment(grabbedCheckpoint)
    end

    editorState.grabbedCheckpointIndex = nil
    editorState.mouseGrabActive = false
end

local function isEditorControlPressed(controlId)
    return IsControlPressed(0, controlId)
        or IsControlPressed(2, controlId)
        or IsDisabledControlPressed(0, controlId)
        or IsDisabledControlPressed(2, controlId)
end

local function wasEditorControlJustPressed(controlId)
    return IsControlJustPressed(0, controlId)
        or IsControlJustPressed(2, controlId)
        or IsDisabledControlJustPressed(0, controlId)
        or IsDisabledControlJustPressed(2, controlId)
end

local function wasEditorControlJustReleased(controlId)
    return IsControlJustReleased(0, controlId)
        or IsControlJustReleased(2, controlId)
        or IsDisabledControlJustReleased(0, controlId)
        or IsDisabledControlJustReleased(2, controlId)
end

local function getPreviewCheckpointMarker(checkpoint)
    ensureCheckpointMarkerAlignment(checkpoint)
    local x = tonumber(checkpoint and checkpoint.x) or 0.0
    local y = tonumber(checkpoint and checkpoint.y) or 0.0
    local markerZ = tonumber(checkpoint and checkpoint.markerZ) or ((tonumber(checkpoint and checkpoint.z) or 0.0) - 2.5)
    local rotX = tonumber(checkpoint and checkpoint.rotX) or 0.0
    local rotY = tonumber(checkpoint and checkpoint.rotY) or 0.0
    local rotZ = tonumber(checkpoint and checkpoint.rotZ) or 0.0
    return {
        x = x,
        y = y,
        z = markerZ,
        dirX = 0.0,
        dirY = 0.0,
        dirZ = 0.0,
        rotX = rotX,
        rotY = rotY,
        rotZ = rotZ,
    }
end

local function drawCheckpointIndexLabel(checkpointIndex, x, y, z, distanceMeters)
    local distance = math.max(0.0, tonumber(distanceMeters) or 0.0)
    local fadeDistance = math.max(20.0, tonumber(RacingSystem.Config.checkpointDrawDistanceMeters) or 250.0)
    local alphaRatio = math.max(0.2, 1.0 - (distance / fadeDistance))
    local alpha = math.floor(255.0 * alphaRatio)

    SetDrawOrigin(x, y, z + 3.5, 0)
    SetTextScale(0.0, 0.62)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextCentre(true)
    SetTextColour(255, 255, 255, alpha)
    SetTextDropshadow(0, 0, 0, 0, alpha)
    SetTextEdge(2, 0, 0, 0, alpha)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(('#%d'):format(math.max(1, math.floor(tonumber(checkpointIndex) or 1))))
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

RegisterNetEvent('racingsystem:editor:loaded', function(payload)
    if type(payload) ~= 'table' or payload.ok ~= true then
        return
    end
    local data = type(payload.data) == 'table' and payload.data or {}
    local requestedName = RacingSystem.Trim(data.requestedName)
    local race = type(data.race) == 'table' and data.race or nil
    local raceName = race and race.name or (requestedName ~= '' and requestedName or 'Untitled Race')
    local checkpoints = race and race.checkpoints or {}
    editorState.selectedName = raceName
    beginEditorSession(raceName, checkpoints)
    RacingSystem.Menu.refreshEditorMenu(RacingSystem.Menu.buildMenuState())
end)

RegisterNetEvent('racingsystem:editor:saved', function(payload)
    if type(payload) ~= 'table' or payload.ok ~= true then
        return
    end
    local data = type(payload.data) == 'table' and payload.data or {}
    local race = data.race or {}
    editorState.name = race.name or editorState.name
    editorState.selectedName = editorState.name
    editorState.checkpoints = cloneCheckpoints(race.checkpoints or editorState.checkpoints)
    normalizeCheckpointIndexes()
    if #editorState.checkpoints > 0 then
        editorState.finishLineCheckpointIndex = #editorState.checkpoints
    else
        editorState.finishLineCheckpointIndex = nil
    end
    for _, checkpoint in ipairs(editorState.checkpoints) do
        ensureCheckpointMarkerAlignment(checkpoint)
    end
    RacingSystem.Menu.refreshEditorMenu(RacingSystem.Menu.buildMenuState())
end)

RegisterNetEvent('racingsystem:def:registered', function(payload)
    if type(payload) ~= 'table' or payload.ok ~= true then
        return
    end
    local data = type(payload.data) == 'table' and payload.data or {}
    local definition = type(data.definition) == 'table' and data.definition or {}
    RacingSystem.Menu.pendingSelectRaceName = definition.name or RacingSystem.Menu.pendingSelectRaceName
    RacingSystem.Menu.pendingEditorRaceName = definition.name or RacingSystem.Menu.pendingEditorRaceName
end)

RegisterNetEvent('racingsystem:def:deleted', function(payload)
    RacingSystem.Menu.deleteConfirmRaceName = nil
    if type(payload) ~= 'table' or payload.ok ~= true then
        RacingSystem.Menu.refreshEditorMenu(RacingSystem.Menu.buildMenuState())
        return
    end
    local data = type(payload.data) == 'table' and payload.data or {}
    local definition = type(data.definition) == 'table' and data.definition or {}
    local deletedName = tostring(definition.name or 'unknown')
    if RacingSystem.NormalizeRaceName(editorState.selectedName) == RacingSystem.NormalizeRaceName(deletedName) then
        editorState.selectedName = ''
    end
end)

CreateThread(function()
    while true do
        if not editorState.active then
            Wait(1000)
        else
            setEditorCursorHidden(true)
            refreshEditorTargetState()
            local origin = getEditorCameraCoords() or getEditorTargetCoords()
            if origin then
                local closestIndex = getClosestCheckpointIndex()
                local grabbedIndex = editorState.grabbedCheckpointIndex
                if grabbedIndex and editorState.checkpoints[grabbedIndex] then
                    local anchorCoords = getEditorTargetCoords()
                    if anchorCoords then
                        local grabbedCheckpoint = editorState.checkpoints[grabbedIndex]
                        grabbedCheckpoint.x = anchorCoords.x
                        grabbedCheckpoint.y = anchorCoords.y
                        grabbedCheckpoint.z = anchorCoords.z
                    end
                end

                if wasEditorControlJustPressed(EDITOR_PITCH_UP_CONTROL_ID) then
                    adjustClosestCheckpointRadius(1)
                elseif wasEditorControlJustPressed(EDITOR_PITCH_DOWN_CONTROL_ID) then
                    adjustClosestCheckpointRadius(-1)
                end
                if wasEditorControlJustPressed(EDITOR_MOUSE_SCROLL_UP_CONTROL_ID) then
                    adjustClosestCheckpointRadius(1)
                elseif wasEditorControlJustPressed(EDITOR_MOUSE_SCROLL_DOWN_CONTROL_ID) then
                    adjustClosestCheckpointRadius(-1)
                end

                local mouseGrabJustPressed = wasEditorControlJustPressed(EDITOR_MOUSE_GRAB_CONTROL_ID)
                if mouseGrabJustPressed then
                    local closestForMouseGrab, closestDistanceForMouseGrab = getClosestCheckpointIndex()
                    local closestCheckpoint = closestForMouseGrab and editorState.checkpoints[closestForMouseGrab] or nil
                    local grabThreshold = math.max(6.0, tonumber(closestCheckpoint and closestCheckpoint.radius) or 8.0)
                    if closestForMouseGrab and tonumber(closestDistanceForMouseGrab) and closestDistanceForMouseGrab <= grabThreshold then
                        editorState.grabbedCheckpointIndex = closestForMouseGrab
                        editorState.mouseGrabActive = true
                    else
                        addCheckpointAtPlayer()
                    end
                end
                if editorState.mouseGrabActive and wasEditorControlJustReleased(EDITOR_MOUSE_GRAB_CONTROL_ID) then
                    releaseMouseGrab()
                elseif editorState.mouseGrabActive and not isEditorControlPressed(EDITOR_MOUSE_GRAB_CONTROL_ID) then
                    releaseMouseGrab()
                end

                for index, checkpoint in ipairs(editorState.checkpoints) do
                    local distance = #(origin - vector3(checkpoint.x, checkpoint.y, checkpoint.z))
                    if distance <= RacingSystem.Config.checkpointDrawDistanceMeters then
                        local isClosest = index == closestIndex
                        local isGrabbed = index == grabbedIndex
                        local isFinishLine = index == editorState.finishLineCheckpointIndex
                        local red = isGrabbed and 255 or (isClosest and 255 or (index == 1 and 80 or 240))
                        local green = isGrabbed and 120 or (isClosest and 220 or (index == 1 and 220 or 180))
                        local blue = isGrabbed and 255 or (isClosest and 80 or (index == #editorState.checkpoints and 80 or 255))
                        local markerDraw = getPreviewCheckpointMarker(checkpoint)
                        if isFinishLine then
                            local nextCheckpoint = editorState.checkpoints[index + 1] or editorState.checkpoints[1]
                            local flagHeading = getHeadingToNextCheckpoint(checkpoint, nextCheckpoint)
                            local flagScale = math.max(1.2, math.min(2.6, (tonumber(checkpoint.radius) or 8.0) * 0.2))
                            DrawMarker(
                                tonumber(MARKER_TAXONOMY.startLineIdleTypeId) or 4,
                                markerDraw.x,
                                markerDraw.y,
                                tonumber(checkpoint.z) or markerDraw.z,
                                0.0,
                                0.0,
                                0.0,
                                0.0,
                                0.0,
                                flagHeading,
                                flagScale,
                                flagScale,
                                flagScale,
                                tonumber((MARKER_TAXONOMY.startLineIdleColor or {}).r) or 255,
                                tonumber((MARKER_TAXONOMY.startLineIdleColor or {}).g) or 255,
                                tonumber((MARKER_TAXONOMY.startLineIdleColor or {}).b) or 255,
                                230,
                                true,
                                false,
                                2,
                                true,
                                nil,
                                nil,
                                false
                            )
                        else
                            local visualRadius = (type(RacingSystem.Client.getVisualCheckpointRadius) == 'function' and RacingSystem.Client.getVisualCheckpointRadius(checkpoint)) or (tonumber(checkpoint.radius) or 8.0)
                            DrawMarker(
                                (type(RacingSystem.Client.getRouteCheckpointMarkerTypeId) == 'function' and RacingSystem.Client.getRouteCheckpointMarkerTypeId()) or 1,
                                markerDraw.x,
                                markerDraw.y,
                                markerDraw.z,
                                markerDraw.dirX,
                                markerDraw.dirY,
                                markerDraw.dirZ,
                                markerDraw.rotX,
                                markerDraw.rotY,
                                markerDraw.rotZ,
                                visualRadius,
                                visualRadius,
                                10.0,
                                red,
                                green,
                                blue,
                                160,
                                false,
                                false,
                                2,
                                false,
                                nil,
                                nil,
                                false
                            )
                        end
                        if editorState.checkpoints[index + 1] then
                            DrawLine(
                                checkpoint.x,
                                checkpoint.y,
                                checkpoint.z + 0.2,
                                editorState.checkpoints[index + 1].x,
                                editorState.checkpoints[index + 1].y,
                                editorState.checkpoints[index + 1].z + 0.2,
                                80,
                                200,
                                255,
                                180
                            )
                        end
                        drawCheckpointIndexLabel(index, checkpoint.x, checkpoint.y, checkpoint.z, distance)
                    end
                end
            end
            Wait(0)
        end
    end
end)
