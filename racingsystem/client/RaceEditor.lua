RacingSystem = RacingSystem or {}
RacingSystem.Client = RacingSystem.Client or {}
RacingSystem.Menu = RacingSystem.Menu or {}

local editorState = {
    active = false,
    name = '',
    selectedName = '',
    checkpoints = {},
    grabbedCheckpointIndex = nil,
    defaultCheckpointRadius = 8.0,
}
RacingSystem.Client.editorState = editorState

local ClientAdvancedConfig = (((RacingSystem or {}).Config or {}).advanced or {}).client or {}
local CHECKPOINT_RADIUS_STEP_METERS = tonumber(ClientAdvancedConfig.checkpointRadiusStepMeters) or 1.0
local EDITOR_PITCH_UP_CONTROL_ID = math.floor(tonumber(ClientAdvancedConfig.editorPitchUpControlId) or 111)
local EDITOR_PITCH_DOWN_CONTROL_ID = math.floor(tonumber(ClientAdvancedConfig.editorPitchDownControlId) or 112)

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
    end
end

local function getPlayerCoords()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then
        return nil
    end
    return GetEntityCoords(ped)
end

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

local function getEditorAnchorCoords()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then
        return nil
    end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        return GetEntityCoords(vehicle)
    end
    return GetEntityCoords(ped)
end

local function getClosestCheckpointIndex()
    local coords = getPlayerCoords()
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

local function isEditorActive()
    return editorState.active == true
end

local function beginEditorSession(raceName, checkpoints)
    editorState.active = true
    editorState.name = raceName or 'Untitled Race'
    editorState.selectedName = editorState.name
    editorState.checkpoints = cloneCheckpoints(checkpoints)
    normalizeCheckpointIndexes()
    for _, checkpoint in ipairs(editorState.checkpoints) do
        ensureCheckpointMarkerAlignment(checkpoint)
    end
    RacingSystem.Menu.beginEditorSessionUI()
end

local function endEditorSession()
    RacingSystem.Menu.endEditorSessionUI()
    editorState.active = false
    editorState.name = ''
    editorState.checkpoints = {}
    editorState.grabbedCheckpointIndex = nil
end
RacingSystem.Client.endEditorSession = endEditorSession

local function addCheckpointAtPlayer()
    if not isEditorActive() then
        return
    end
    local coords = getPlayerCoords()
    if not coords then
        return
    end
    editorState.checkpoints[#editorState.checkpoints + 1] = {
        index = #editorState.checkpoints + 1,
        x = coords.x,
        y = coords.y,
        z = coords.z,
        radius = tonumber(editorState.defaultCheckpointRadius) or 8.0,
    }
    refreshCheckpointMarkerAlignment(editorState.checkpoints[#editorState.checkpoints])
end
RacingSystem.Client.addCheckpointAtPlayer = addCheckpointAtPlayer

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

local function wasEditorControlJustPressed(controlId)
    return IsControlJustPressed(0, controlId)
        or IsControlJustPressed(2, controlId)
        or IsDisabledControlJustPressed(0, controlId)
        or IsDisabledControlJustPressed(2, controlId)
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
            local ped = PlayerPedId()
            local origin = GetEntityCoords(ped)
            local closestIndex = getClosestCheckpointIndex()
            local grabbedIndex = editorState.grabbedCheckpointIndex
            if grabbedIndex and editorState.checkpoints[grabbedIndex] then
                local anchorCoords = getEditorAnchorCoords()
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

            for index, checkpoint in ipairs(editorState.checkpoints) do
                local distance = #(origin - vector3(checkpoint.x, checkpoint.y, checkpoint.z))
                if distance <= RacingSystem.Config.checkpointDrawDistanceMeters then
                    local isClosest = index == closestIndex
                    local isGrabbed = index == grabbedIndex
                    local red = isGrabbed and 255 or (isClosest and 255 or (index == 1 and 80 or 240))
                    local green = isGrabbed and 120 or (isClosest and 220 or (index == 1 and 220 or 180))
                    local blue = isGrabbed and 255 or (isClosest and 80 or (index == #editorState.checkpoints and 80 or 255))
                    local markerDraw = getPreviewCheckpointMarker(checkpoint)
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
                end
            end
            Wait(0)
        end
    end
end)

