local latestSnapshot = {
    races = {},
    count = 0,
}

local editorState = {
    active = false,
    name = '',
    selectedName = '',
    checkpoints = {},
    grabbedCheckpointIndex = nil,
    defaultCheckpointRadius = 8.0,
}

local raceRuntimeState = {
    pendingCheckpointPass = nil,
    predictedProgress = nil,
    previousPosition = nil,
    lastOutsideCheckpointCrossKey = nil,
    accelerationPenaltyUntil = 0,
    checkpointPassArm = nil,
}
local raceCountdownLocalEndByInstanceId = {}
local raceCountdownReportedZeroByInstanceId = {}
local raceStartCueShownByInstanceId = {}
local raceCountdownVisualState = {
    instanceId = nil,
    scaleform = nil,
    lastLabel = nil,
    goVisibleUntil = 0,
}
local raceEventVisualState = {
    scaleform = nil,
    title = nil,
    subtitle = nil,
    expiresAt = 0,
}
local raceTimingState = {
    instanceId = nil,
    raceStartedAt = nil,
    lapStartedAt = nil,
}
local CHECKPOINT_RADIUS_STEP_METERS = 1.0
local EDITOR_PITCH_UP_CONTROL_ID = 111
local EDITOR_PITCH_DOWN_CONTROL_ID = 112

local raceMenuInitialized = false
local raceMenuOpen = false
local raceMainMenu
local raceInvokeMenu
local raceJoinMenu
local raceKillMenu
local raceEditorMenu
local raceKillMenuItem
local raceEditorMenuItem
local raceRefreshItem
local raceJoinedStatusItem
local raceOwnedStatusItem
local raceQuickStartItem
local raceQuickLeaveItem
local raceQuickFinishItem
local raceInvokeDefinitionItem
local raceInvokeLapItem
local raceInvokeActionItem
local raceJoinAvailableListItem
local raceJoinActionItem
local raceJoinDetailItemOne
local raceJoinDetailItemTwo
local raceJoinDetailItemThree
local raceEditorSelectedItem
local raceEditorOpenItem
local raceEditorWidthItem
local raceEditorAddCheckpointItem
local raceEditorGrabCheckboxItem
local raceEditorSaveItem
local raceEditorDeleteItem
local raceMenuDefinitionOptions = {}
local raceMenuJoinOptions = {}
local raceMenuEndOptions = {}
local raceMenuLapOptions = {}
local raceMenuEditorOptions = {}
local raceMenuCheckpointWidthValues = {
    '2.0', '3.0', '4.0', '5.0', '6.0', '7.0', '8.0', '9.0', '10.0', '11.0',
    '12.0', '13.0', '14.0', '15.0', '16.0', '18.0', '20.0', '24.0', '28.0', '32.0', '40.0'
}
local raceMenuPendingSelectName = nil
local clearPredictedRaceProgress
local raceMenuPendingEditorName = nil
local raceMenuDeleteConfirmName = nil
local raceMenuKillItems = {}

local function rebuildRaceMenuLapOptions()
    raceMenuLapOptions = {}
    local configuredMin = math.floor(tonumber((RacingSystem.Config or {}).minLapCount) or 1)
    local configuredMax = math.floor(tonumber((RacingSystem.Config or {}).maxLapCount) or 10)
    local minLapCount = math.max(1, configuredMin)
    local maxLapCount = math.max(minLapCount, configuredMax)

    for lap = minLapCount, maxLapCount do
        raceMenuLapOptions[#raceMenuLapOptions + 1] = tostring(lap)
    end
end

rebuildRaceMenuLapOptions()

local instanceAssetCache = {}
local activeInstanceAssets = {
    instanceId = nil,
    objects = {},
    modelHides = {},
}

local CHECKPOINT_PASS_ARM_DISTANCE = 30.0
local CHECKPOINT_PASS_RELEASE_DELTA = 0.75

local GetPropSpeedModificationParameters

do
    local speedUpObjects = {
        [-1006978322] = true,
        [-388593496] = true,
        [-66244843] = true,
        [-1170462683] = true,
        [993442923] = true,
        [737005456] = true,
        [-904856315] = true,
        [-279848256] = true,
        [588352126] = true,
    }

    local slowDownObjects = {
        [346059280] = true,
        [620582592] = true,
        [85342060] = true,
        [483832101] = true,
        [930976262] = true,
        [1677872320] = true,
        [708828172] = true,
        [950795200] = true,
        [-1260656854] = true,
        [-1875404158] = true,
        [-864804458] = true,
        [-1302470386] = true,
        [1518201148] = true,
        [384852939] = true,
        [117169896] = true,
        [-1479958115] = true,
        [-227275508] = true,
        [1431235846] = true,
        [1832852758] = true,
    }

    GetPropSpeedModificationParameters = function(model, prpsba)
        if prpsba == -1 then
            return false
        end

        local var1, var2 = -1, -1

        if speedUpObjects[model] then
            if prpsba == 1 then
                var1, var2 = 15, 0.3
            elseif prpsba == 2 then
                var1, var2 = 25, 0.3
            elseif prpsba == 3 then
                var1, var2 = 35, 0.5
            elseif prpsba == 4 then
                var1, var2 = 45, 0.5
            elseif prpsba == 5 then
                var1, var2 = 100, 0.5
            else
                var1, var2 = 25, 0.4
            end
        elseif slowDownObjects[model] then
            var2 = -1
            if prpsba == 1 then
                var1 = 44
            elseif prpsba == 2 then
                var1 = 30
            elseif prpsba == 3 then
                var1 = 16
            else
                var1 = 30
            end
        else
            return false
        end

        return true, var1, var2
    end
end

-- Sends a lightweight in-game message for the local player.
local function notify(message, isError)
    local text = tostring(message or '')
    if isError then
        text = ('~r~%s~s~'):format(text)
    end

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostTicker(false, false)
end

local function notifyFeed(message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(tostring(message or ''))
    EndTextCommandThefeedPostTicker(false, false)
end

local function clearCountdownScaleform()
    if raceCountdownVisualState.scaleform and raceCountdownVisualState.scaleform ~= 0 then
        SetScaleformMovieAsNoLongerNeeded(raceCountdownVisualState.scaleform)
    end
    raceCountdownVisualState.scaleform = nil
    raceCountdownVisualState.lastLabel = nil
    raceCountdownVisualState.instanceId = nil
    raceCountdownVisualState.goVisibleUntil = 0
end

local function ensureCountdownScaleform()
    if raceCountdownVisualState.scaleform and raceCountdownVisualState.scaleform ~= 0 then
        return raceCountdownVisualState.scaleform
    end

    local handle = RequestScaleformMovie('MP_BIG_MESSAGE_FREEMODE')
    if not handle or handle == 0 then
        return nil
    end

    raceCountdownVisualState.scaleform = handle
    return handle
end

local function clearRaceEventScaleform()
    if raceEventVisualState.scaleform and raceEventVisualState.scaleform ~= 0 then
        SetScaleformMovieAsNoLongerNeeded(raceEventVisualState.scaleform)
    end
    raceEventVisualState.scaleform = nil
    raceEventVisualState.title = nil
    raceEventVisualState.subtitle = nil
    raceEventVisualState.expiresAt = 0
end

local function ensureRaceEventScaleform()
    if raceEventVisualState.scaleform and raceEventVisualState.scaleform ~= 0 then
        return raceEventVisualState.scaleform
    end

    local handle = RequestScaleformMovie('MP_BIG_MESSAGE_FREEMODE')
    if not handle or handle == 0 then
        return nil
    end

    raceEventVisualState.scaleform = handle
    return handle
end

local function showRaceEventVisual(title, subtitle, durationMs)
    raceEventVisualState.title = tostring(title or '')
    raceEventVisualState.subtitle = tostring(subtitle or '')
    raceEventVisualState.expiresAt = GetGameTimer() + math.max(250, math.floor(tonumber(durationMs) or 1500))
end

local function drawRaceEventVisual()
    local now = GetGameTimer()
    if (tonumber(raceEventVisualState.expiresAt) or 0) <= now then
        if raceEventVisualState.scaleform then
            clearRaceEventScaleform()
        end
        return
    end

    local scaleform = ensureRaceEventScaleform()
    if not scaleform or scaleform == 0 or not HasScaleformMovieLoaded(scaleform) then
        return
    end

    BeginScaleformMovieMethod(scaleform, 'SHOW_SHARD_CENTERED_MP_MESSAGE')
    PushScaleformMovieMethodParameterString(raceEventVisualState.title or '')
    PushScaleformMovieMethodParameterString(raceEventVisualState.subtitle or '')
    EndScaleformMovieMethod()
    DrawScaleformMovie(scaleform, 0.5, 0.34, 1.0, 1.0, 255, 255, 255, 255, 0)
end

local function updateCountdownVisual(instanceId, remainingMs)
    local resolvedInstanceId = tonumber(instanceId)
    if not resolvedInstanceId then
        clearCountdownScaleform()
        return
    end

    if raceCountdownVisualState.instanceId ~= resolvedInstanceId then
        raceCountdownVisualState.instanceId = resolvedInstanceId
        raceCountdownVisualState.lastLabel = nil
        raceCountdownVisualState.goVisibleUntil = 0
    end

    local now = GetGameTimer()
    local label = nil
    local ms = math.max(0, tonumber(remainingMs) or 0)
    if ms <= 0 then
        label = 'GO'
        if raceCountdownVisualState.goVisibleUntil <= 0 then
            raceCountdownVisualState.goVisibleUntil = now + 1000
        end
        if now > raceCountdownVisualState.goVisibleUntil then
            clearCountdownScaleform()
            return
        end
    elseif ms <= 1000 then
        label = '1'
    elseif ms <= 2000 then
        label = '2'
    elseif ms <= 3000 then
        label = '3'
    else
        raceCountdownVisualState.lastLabel = nil
        return
    end

    local scaleform = ensureCountdownScaleform()
    if not scaleform or scaleform == 0 or not HasScaleformMovieLoaded(scaleform) then
        return
    end

    if raceCountdownVisualState.lastLabel ~= label then
        raceCountdownVisualState.lastLabel = label
        local styledLabel = (label == 'GO') and '~g~GO' or ('~y~%s'):format(label)
        BeginScaleformMovieMethod(scaleform, 'SHOW_SHARD_CENTERED_MP_MESSAGE')
        PushScaleformMovieMethodParameterString(styledLabel)
        PushScaleformMovieMethodParameterString('')
        EndScaleformMovieMethod()
    end

    DrawScaleformMovie(scaleform, 0.5, 0.3, 1.0, 1.0, 255, 255, 255, 255, 0)
end

RegisterNetEvent('racingsystem:notify', function(payload)
    if type(payload) == 'table' then
        notify(payload.message, payload.isError == true)
        return
    end

    notify(payload)
end)

local function requestRaceStateSnapshot()
    TriggerServerEvent('racingsystem:requestState')
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

local function ensureEditorActive()
    if editorState.active then
        return true
    end

        notify('Race creation mode is not active. Open the race menu (F7) and choose a race to edit first.')
    return false
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
end

local function endEditorSession()
    editorState.active = false
    editorState.name = ''
    editorState.checkpoints = {}
    editorState.grabbedCheckpointIndex = nil
end

local function addCheckpointAtPlayer()
    if not ensureEditorActive() then
        return
    end

    local coords = getPlayerCoords()
    if not coords then
        notify('Could not read your current position.')
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

local function moveClosestCheckpointToPlayer()
    if not ensureEditorActive() then
        return
    end

    local closestIndex, closestDistance = getClosestCheckpointIndex()
    local coords = getPlayerCoords()
    if not closestIndex or not coords then
        notify('There is no checkpoint to move yet.')
        return
    end

    local checkpoint = editorState.checkpoints[closestIndex]
    checkpoint.x = coords.x
    checkpoint.y = coords.y
    checkpoint.z = coords.z
    refreshCheckpointMarkerAlignment(checkpoint)
end

local function deleteClosestCheckpoint()
    if not ensureEditorActive() then
        return
    end

    local closestIndex, closestDistance = getClosestCheckpointIndex()
    if not closestIndex then
        notify('There is no checkpoint to delete yet.')
        return
    end

    table.remove(editorState.checkpoints, closestIndex)
    normalizeCheckpointIndexes()
end

local function adjustClosestCheckpointRadius(direction)
    if not ensureEditorActive() then
        return
    end

    local targetIndex = editorState.grabbedCheckpointIndex
    if not targetIndex then
        targetIndex = getClosestCheckpointIndex()
    end

    if not targetIndex then
        notify('There is no checkpoint to resize yet.')
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
    if not ensureEditorActive() then
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

    local closestIndex, closestDistance = getClosestCheckpointIndex()
    if not closestIndex then
        notify('There is no checkpoint to grab yet.')
        return
    end
    editorState.grabbedCheckpointIndex = closestIndex
end

local function wasEditorControlJustPressed(controlId)
    return IsControlJustPressed(0, controlId)
        or IsControlJustPressed(2, controlId)
        or IsDisabledControlJustPressed(0, controlId)
        or IsDisabledControlJustPressed(2, controlId)
end

local function saveEditorRace(optionalName)
    if not ensureEditorActive() then
        return
    end

    local requestedName = type(optionalName) == 'string' and optionalName or ''
    local raceName = RacingSystem.Trim(requestedName ~= '' and requestedName or editorState.name)
    if raceName == '' then
        notify('A race name is required before saving.')
        return
    end

    TriggerServerEvent('racingsystem:saveEditorRace', {
        name = raceName,
        checkpoints = editorState.checkpoints,
    })
end

local function formatDurationMs(totalMs)
    local durationMs = math.max(0, math.floor(tonumber(totalMs) or 0))
    local minutes = math.floor(durationMs / 60000)
    local seconds = math.floor((durationMs % 60000) / 1000)
    local milliseconds = durationMs % 1000

    return ('%02d:%02d.%03d'):format(minutes, seconds, milliseconds)
end

local function resetLocalRaceTiming()
    raceTimingState.instanceId = nil
    raceTimingState.raceStartedAt = nil
    raceTimingState.lapStartedAt = nil
    clearPredictedRaceProgress()
end

local function ensureLocalRaceTiming(instanceId)
    local numericInstanceId = tonumber(instanceId)
    if raceTimingState.instanceId ~= numericInstanceId then
        resetLocalRaceTiming()
        raceTimingState.instanceId = numericInstanceId
    end
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

local function getVisualCheckpointRadius(checkpoint)
    local baseRadius = tonumber(checkpoint and checkpoint.radius) or 8.0
    local visualScale = tonumber(RacingSystem.Config.visualCheckpointRadiusScale) or 1.0
    return baseRadius * visualScale
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

local function getCheckpointPassArmKey(instanceId, checkpointIndex, lapNumber)
    return ('%s:%s:%s'):format(tonumber(instanceId) or 0, tonumber(checkpointIndex) or 0, tonumber(lapNumber) or 1)
end

local function teleportEntityToCheckpoint(entity, checkpoint, nextCheckpoint)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return
    end

    local x = tonumber(checkpoint and checkpoint.x) or 0.0
    local y = tonumber(checkpoint and checkpoint.y) or 0.0
    local z = (tonumber(checkpoint and checkpoint.z) or 0.0) + 2.0
    local heading = getHeadingToNextCheckpoint(checkpoint, nextCheckpoint) + 90.0
    SetEntityCoordsNoOffset(entity, x, y, z, false, false, false)
    SetEntityHeading(entity, heading)
    SetEntityVelocity(entity, 0.0, 0.0, 0.0)

    if IsEntityAVehicle(entity) then
        SetVehicleForwardSpeed(entity, 0.0)
    end
end

local function getJoinedRaceInstance()
    local serverId = GetPlayerServerId(PlayerId())
    local instances = type(latestSnapshot.instances) == 'table' and latestSnapshot.instances or {}

    for _, instance in ipairs(instances) do
        for _, entrant in ipairs(type(instance.entrants) == 'table' and instance.entrants or {}) do
            if tonumber(entrant.source) == tonumber(serverId) then
                return instance
            end
        end
    end

    return nil
end

local function getOwnedRaceInstance()
    local serverId = GetPlayerServerId(PlayerId())
    local instances = type(latestSnapshot.instances) == 'table' and latestSnapshot.instances or {}

    for _, instance in ipairs(instances) do
        if tonumber(instance.owner) == tonumber(serverId) then
            return instance
        end
    end

    return nil
end

local function getLocalEntrant(instance)
    if type(instance) ~= 'table' then
        return nil
    end

    local localPlayerId = PlayerId()
    local serverId = GetPlayerServerId(localPlayerId)

    for _, entrant in ipairs(type(instance.entrants) == 'table' and instance.entrants or {}) do
        if tonumber(entrant.source) == tonumber(serverId) then
            return entrant
        end
    end

    return nil
end

clearPredictedRaceProgress = function(instanceId)
    local predicted = raceRuntimeState.predictedProgress
    if not predicted then
        return
    end

    if instanceId == nil or tonumber(predicted.instanceId) == tonumber(instanceId) then
        raceRuntimeState.predictedProgress = nil
    end
end

local function getEffectiveEntrantProgress(instance, entrant)
    local currentCheckpoint = tonumber(entrant and entrant.currentCheckpoint) or 1
    local currentLap = math.max(1, tonumber(entrant and entrant.currentLap) or 1)
    local finishedAt = tonumber(entrant and entrant.finishedAt)
    local predicted = raceRuntimeState.predictedProgress
    local instanceId = tonumber(instance and instance.id)

    if predicted and instanceId and tonumber(predicted.instanceId) == instanceId then
        local predictedCheckpoint = tonumber(predicted.currentCheckpoint)
        local predictedLap = math.max(1, tonumber(predicted.currentLap) or currentLap)
        local predictedFinished = predicted.finished == true

        if finishedAt or (predictedFinished and predictedCheckpoint == nil) then
            clearPredictedRaceProgress(instanceId)
        elseif predictedCheckpoint and (predictedLap > currentLap or (predictedLap == currentLap and predictedCheckpoint > currentCheckpoint)) then
            currentCheckpoint = predictedCheckpoint
            currentLap = predictedLap
        else
            clearPredictedRaceProgress(instanceId)
        end
    end

    return {
        currentCheckpoint = currentCheckpoint,
        currentLap = currentLap,
        finishedAt = finishedAt,
    }
end

local function predictCheckpointPass(instance, entrantProgress, totalCheckpoints, targetIndex)
    local instanceId = tonumber(instance and instance.id)
    if not instanceId then
        return
    end

    local currentLap = math.max(1, tonumber(entrantProgress and entrantProgress.currentLap) or 1)
    local totalLaps = math.max(1, tonumber(instance and instance.laps) or 1)
    local lapTriggerCheckpoint = (totalLaps > 1 and totalCheckpoints > 1) and 1 or totalCheckpoints
    local raceStartCheckpoint = (totalLaps > 1 and totalCheckpoints > 1) and 2 or 1

    if targetIndex == lapTriggerCheckpoint then
        if currentLap >= totalLaps then
            raceRuntimeState.predictedProgress = {
                instanceId = instanceId,
                currentCheckpoint = totalCheckpoints + 1,
                currentLap = currentLap,
                finished = true,
            }
        else
            raceRuntimeState.predictedProgress = {
                instanceId = instanceId,
                currentCheckpoint = raceStartCheckpoint,
                currentLap = currentLap + 1,
                finished = false,
            }
        end
    else
        local nextCheckpoint = targetIndex + 1
        if nextCheckpoint > totalCheckpoints then
            nextCheckpoint = 1
        end
        raceRuntimeState.predictedProgress = {
            instanceId = instanceId,
            currentCheckpoint = nextCheckpoint,
            currentLap = currentLap,
            finished = false,
        }
    end
end

local function getDefinitionDisplayName(definition)
    if type(definition) ~= 'table' then
        return 'Unknown'
    end

    local sourceType = tostring(definition.sourceType or 'saved')
    local sourceLabel = sourceType == 'custom' and 'Custom' or (sourceType == 'online' and 'Online' or 'Saved')
    return ('%s [%s]'):format(tostring(definition.name or 'Unnamed'), sourceLabel)
end

local function getInstanceDisplayName(instance)
    if type(instance) ~= 'table' then
        return 'Unknown race'
    end

    local laps = math.max(1, tonumber(instance.laps) or 1)
    return ('%s (%sl)'):format(tostring(instance.name or 'Unnamed'), laps)
end

local function getInstanceStateLabel(instance)
    local state = tostring(instance and instance.state or RacingSystem.States.idle)
    if state == RacingSystem.States.staging then
        return 'Staging'
    elseif state == RacingSystem.States.running then
        return 'Running'
    elseif state == RacingSystem.States.finished then
        return 'Finished'
    end

    return 'Idle'
end

local function getInstanceEntrantCount(instance)
    return #(type(instance and instance.entrants) == 'table' and instance.entrants or {})
end

local function isJoinableRaceInstance(instance)
    if type(instance) ~= 'table' then
        return false
    end

    local state = tostring(instance.state or RacingSystem.States.idle)
    return state ~= RacingSystem.States.finished
end

local function isSameRaceInstance(left, right)
    if type(left) ~= 'table' or type(right) ~= 'table' then
        return false
    end

    local leftId = tonumber(left.id)
    local rightId = tonumber(right.id)
    if leftId and rightId then
        return leftId == rightId
    end

    return tostring(left.name or '') == tostring(right.name or '')
end

local function getSelectedInvokeDefinition()
    local selectedIndex = raceInvokeDefinitionItem and raceInvokeDefinitionItem:Index() or 1
    return raceMenuDefinitionOptions[selectedIndex]
end

local function getSelectedInvokeLapCount()
    local selectedIndex = raceInvokeLapItem and raceInvokeLapItem:Index() or 1
    local lapValue = tonumber(raceMenuLapOptions[selectedIndex]) or 1
    return math.max(1, lapValue)
end

local function rebuildRaceMainMenu(joinedInstance, ownedInstance)
    if not raceMainMenu then
        return
    end

    local hasActiveInstances = #raceMenuEndOptions > 0

    raceMainMenu:Clear()
    raceMainMenu:AddItem(raceJoinedStatusItem)
    raceMainMenu:AddItem(raceOwnedStatusItem)

    if joinedInstance then
        raceMainMenu:AddItem(raceQuickStartItem)
        raceMainMenu:AddItem(raceQuickLeaveItem)
        raceMainMenu:AddItem(raceQuickFinishItem)
    end

    if hasActiveInstances then
        raceMainMenu:AddItem(raceKillMenuItem)
    end

    if not joinedInstance then
        raceMainMenu:AddItem(raceEditorMenuItem)
    end
    raceMainMenu:AddItem(raceRefreshItem)
end

local function promptRaceNameInput(title, defaultText, maxLength)
    AddTextEntry('FMMC_KEY_TIP8', tostring(title or 'Enter race name'))
    DisplayOnscreenKeyboard(1, 'FMMC_KEY_TIP8', '', tostring(defaultText or ''), '', '', '', tonumber(maxLength) or 64)

    while UpdateOnscreenKeyboard() == 0 do
        Wait(0)
    end

    if GetOnscreenKeyboardResult() then
        return RacingSystem.Trim(GetOnscreenKeyboardResult())
    end

    return nil
end

local function getCheckpointWidthIndex(radius)
    local numericRadius = tonumber(radius) or 8.0

    for index, value in ipairs(raceMenuCheckpointWidthValues) do
        if math.abs((tonumber(value) or 0.0) - numericRadius) <= 0.01 then
            return index
        end
    end

    return 7
end

local function getSelectedCheckpointWidth()
    local selectedIndex = (raceEditorWidthItem and raceEditorWidthItem:Index() + 1) or getCheckpointWidthIndex(editorState.defaultCheckpointRadius)
    return tonumber(raceMenuCheckpointWidthValues[selectedIndex]) or 8.0
end

local function getEditorTargetCheckpoint()
    local targetIndex = editorState.grabbedCheckpointIndex
    if not targetIndex then
        targetIndex = getClosestCheckpointIndex()
    end

    if not targetIndex then
        return nil, nil
    end

    return editorState.checkpoints[targetIndex], targetIndex
end

local function setRaceMenuOpenState(isOpen)
    raceMenuOpen = isOpen == true
end

local function isRaceMenuVisible()
    local menus = {
        raceMainMenu,
        raceInvokeMenu,
        raceJoinMenu,
        raceKillMenu,
        raceEditorMenu,
    }

    for _, menu in ipairs(menus) do
        if menu and menu:Visible() then
            return true
        end
    end

    return false
end

local function createRaceMenu(title, subtitle)
    local menu = UIMenu.New(title, subtitle, 20, 20, true)
    menu:MenuAlignment(MenuAlignment.RIGHT)
    menu.Children = menu.Children or {}
    return menu
end

local function rebuildRaceKillMenu(instances)
    if not raceKillMenu then
        return
    end

    raceKillMenu:Clear()
    raceMenuEndOptions = {}
    raceMenuKillItems = {}

    for _, instance in ipairs(instances) do
        raceMenuEndOptions[#raceMenuEndOptions + 1] = instance
        local killItem = UIMenuItem.New(
            getInstanceDisplayName(instance),
            ('Kill this instance for everyone. State: %s | Entrants: %s'):format(
                getInstanceStateLabel(instance),
                getInstanceEntrantCount(instance)
            )
        )
        killItem:RightLabel('Kill')
        raceKillMenu:AddItem(killItem)
        raceMenuKillItems[#raceMenuKillItems + 1] = killItem
    end

    if #raceMenuEndOptions == 0 then
        local emptyKillItem = UIMenuItem.New('No active race instances', 'There is nothing to kill right now.')
        emptyKillItem:Enabled(false)
        raceKillMenu:AddItem(emptyKillItem)
    end
end

local function refreshRaceMenu()
    if not raceMenuInitialized then
        return false
    end

    local definitions = type(latestSnapshot.definitions) == 'table' and latestSnapshot.definitions or {}
    local instances = type(latestSnapshot.instances) == 'table' and latestSnapshot.instances or {}
    local joinedInstance = getJoinedRaceInstance()
    local ownedInstance = getOwnedRaceInstance()
    local selectedDefinitionIndex = raceInvokeDefinitionItem and raceInvokeDefinitionItem:Index() or 1

    raceMenuDefinitionOptions = {}
    local definitionLabels = {}
    for _, definition in ipairs(definitions) do
        raceMenuDefinitionOptions[#raceMenuDefinitionOptions + 1] = definition
        definitionLabels[#definitionLabels + 1] = getDefinitionDisplayName(definition)
    end

    if #definitionLabels == 0 then
        definitionLabels[1] = 'Type a race name...'
    end

    raceInvokeDefinitionItem.Items = definitionLabels
    raceInvokeDefinitionItem:Index(math.min(selectedDefinitionIndex, #definitionLabels))
    raceInvokeDefinitionItem:Enabled(true)
    local canInvokeMoreRaces = RacingSystem.Config.playerCanInvokeMultipleRaces or ownedInstance == nil
    raceInvokeActionItem:Enabled(#raceMenuDefinitionOptions > 0 and canInvokeMoreRaces)
    if canInvokeMoreRaces then
        raceInvokeActionItem:Description("")
    else
        raceInvokeActionItem:Description('You already own an active race instance. Kill it first or enable playerCanInvokeMultipleRaces.')
    end

    if raceMenuPendingSelectName then
        local normalizedPendingName = RacingSystem.NormalizeRaceName(raceMenuPendingSelectName)
        if normalizedPendingName then
            for index, definition in ipairs(raceMenuDefinitionOptions) do
                if RacingSystem.NormalizeRaceName(definition.name) == normalizedPendingName then
                    raceInvokeDefinitionItem:Index(index)
                    raceMenuPendingSelectName = nil
                    break
                end
            end
        else
            raceMenuPendingSelectName = nil
        end
    end

    local editorSelectedIndex = raceEditorSelectedItem and raceEditorSelectedItem:Index() or 1
    local editorLabels = {}
    raceMenuEditorOptions = {}
    for _, definition in ipairs(definitions) do
        raceMenuEditorOptions[#raceMenuEditorOptions + 1] = definition
        editorLabels[#editorLabels + 1] = getDefinitionDisplayName(definition)
    end

    if #editorLabels == 0 then
        editorLabels[1] = 'Type a race name...'
    end

    raceEditorSelectedItem.Items = editorLabels
    raceEditorSelectedItem:Index(math.min(editorSelectedIndex, #editorLabels))
    raceEditorSelectedItem:Enabled(true)

    if raceMenuPendingEditorName then
        local normalizedPendingEditorName = RacingSystem.NormalizeRaceName(raceMenuPendingEditorName)
        if normalizedPendingEditorName then
            for index, definition in ipairs(raceMenuEditorOptions) do
                if RacingSystem.NormalizeRaceName(definition.name) == normalizedPendingEditorName then
                    raceEditorSelectedItem:Index(index)
                    raceMenuPendingEditorName = nil
                    break
                end
            end
        else
            raceMenuPendingEditorName = nil
        end
    end

    local selectedEditorDefinition = raceMenuEditorOptions[raceEditorSelectedItem:Index()]
    local selectedEditorName = editorState.selectedName ~= '' and editorState.selectedName
        or (selectedEditorDefinition and selectedEditorDefinition.name)
        or 'new race'
    raceEditorOpenItem:Description(('Open or create "%s" for editing.'):format(selectedEditorName))
    raceEditorSaveItem:Description(('Save the current editor checkpoints into "%s".'):format(selectedEditorName))
    raceEditorSaveItem:Enabled(editorState.selectedName ~= '' or selectedEditorDefinition ~= nil)
    local normalizedDeleteConfirmName = RacingSystem.NormalizeRaceName(raceMenuDeleteConfirmName)
    local normalizedSelectedEditorName = RacingSystem.NormalizeRaceName(selectedEditorName)
    local deleteIsArmed = normalizedDeleteConfirmName ~= nil and normalizedDeleteConfirmName == normalizedSelectedEditorName
    if deleteIsArmed then
        raceEditorDeleteItem:Label('Delete Selected Race (Confirm)')
        raceEditorDeleteItem:Description(('Press again to permanently delete "%s".'):format(selectedEditorName))
    else
        raceEditorDeleteItem:Label('Delete Selected Race')
        raceEditorDeleteItem:Description(('Delete "%s" from disk and remove it from the race index.'):format(selectedEditorName))
    end
    raceEditorDeleteItem:Enabled(selectedEditorDefinition ~= nil)

    local widthIndex = getCheckpointWidthIndex(editorState.defaultCheckpointRadius)
    raceEditorWidthItem:Index(widthIndex - 1)
    raceEditorWidthItem:Description(('Set width for new or grabbed checkpoints. Current: %.1f'):format(tonumber(editorState.defaultCheckpointRadius) or 8.0))
    raceEditorGrabCheckboxItem:Checked(editorState.grabbedCheckpointIndex ~= nil)

    raceJoinedStatusItem:Description("")

    local ownedLabel = 'None'
    local ownedDescription = 'Host a new race instance from a saved race definition.'
    raceOwnedStatusItem:Label('Host Race')
    if ownedInstance then
        raceOwnedStatusItem:Label('Edit Race')
        ownedLabel = getInstanceStateLabel(ownedInstance)
        ownedDescription = ('Edit your hosted race: %s | State: %s | Entrants: %s'):format(
            tostring(ownedInstance.name or 'Unnamed'),
            getInstanceStateLabel(ownedInstance),
            getInstanceEntrantCount(ownedInstance)
        )
        raceQuickFinishItem:Description(('Finish your active race "%s" for everyone.'):format(tostring(ownedInstance.name or 'Unnamed')))
    else
        raceQuickFinishItem:Description('Finish the race instance you are currently running.')
    end
    raceOwnedStatusItem:RightLabel(ownedLabel)
    raceOwnedStatusItem:Description(ownedDescription)
    raceQuickStartItem:Enabled(joinedInstance ~= nil)
    raceQuickLeaveItem:Enabled(joinedInstance ~= nil)
    raceQuickFinishItem:Enabled(joinedInstance ~= nil)

    raceMenuJoinOptions = {}
    local joinLabels = {}
    for _, instance in ipairs(instances) do
        if isJoinableRaceInstance(instance) then
            raceMenuJoinOptions[#raceMenuJoinOptions + 1] = instance
            joinLabels[#joinLabels + 1] = getInstanceDisplayName(instance)
        end
    end

    if #joinLabels == 0 then
        joinLabels[1] = 'No joinable race instances'
    end

    local selectedJoinIndex = raceJoinAvailableListItem and raceJoinAvailableListItem:Index() or 1
    raceJoinAvailableListItem.Items = joinLabels
    raceJoinAvailableListItem:Index(math.min(selectedJoinIndex, #joinLabels))
    raceJoinAvailableListItem:Enabled(#raceMenuJoinOptions > 0)
    raceJoinAvailableListItem:Description("")

    local selectedJoinInstance = raceMenuJoinOptions[raceJoinAvailableListItem:Index()]
    local alreadyJoinedSelected = selectedJoinInstance ~= nil and isSameRaceInstance(selectedJoinInstance, joinedInstance)
    if selectedJoinInstance then
        raceJoinActionItem:Enabled(not alreadyJoinedSelected)
        if alreadyJoinedSelected then
            raceJoinActionItem:Description('You are already joined to this race.')
        else
            raceJoinActionItem:Description(('Join "%s".'):format(getInstanceDisplayName(selectedJoinInstance)))
        end
        raceJoinDetailItemOne:RightLabel(tostring(math.max(1, tonumber(selectedJoinInstance.laps) or 1)))
        raceJoinDetailItemTwo:RightLabel(tostring(getInstanceEntrantCount(selectedJoinInstance)))
        raceJoinDetailItemThree:RightLabel(tostring(getInstanceStateLabel(selectedJoinInstance)))
    else
        raceJoinActionItem:Enabled(false)
        raceJoinActionItem:Description('Select an available race first.')
        raceJoinDetailItemOne:RightLabel('--')
        raceJoinDetailItemTwo:RightLabel('--')
        raceJoinDetailItemThree:RightLabel('--')
    end
    raceJoinedStatusItem:RightLabel(tostring(#raceMenuJoinOptions))

    rebuildRaceKillMenu(instances)

    rebuildRaceMainMenu(joinedInstance, ownedInstance)
    return true
end

local function initializeRaceMenu()
    if raceMenuInitialized then
        return raceMenuInitialized
    end

    if type(UIMenu) ~= 'table' or type(UIMenu.New) ~= 'function' then
        return false
    end

    raceMainMenu = createRaceMenu('Race Control', '~b~RACINGSYSTEM')
    raceInvokeMenu = createRaceMenu('Create Race', 'Choose a saved race and create a live instance.')
    raceJoinMenu = createRaceMenu('Available Races', 'Browse currently active race instances.')
    raceKillMenu = createRaceMenu('Kill Instance', 'Kill one of the currently active race instances.')
    raceEditorMenu = createRaceMenu('Race Editor', 'Create and edit race checkpoint layouts.')

    raceRefreshItem = UIMenuItem.New('Refresh')
    raceJoinedStatusItem = UIMenuItem.New('Available Races')
    raceOwnedStatusItem = UIMenuItem.New('Host Race')
    raceKillMenuItem = UIMenuItem.New('Kill Instance')
    raceEditorMenuItem = UIMenuItem.New('Race Editor')
    raceQuickStartItem = UIMenuItem.New('Start Countdown')
    raceQuickLeaveItem = UIMenuItem.New('Leave Race')
    raceQuickFinishItem = UIMenuItem.New('Finish Race')
    raceInvokeDefinitionItem = UIMenuListItem.New('Race', { 'Loading...' }, 1)
    raceInvokeLapItem = UIMenuListItem.New('Laps', raceMenuLapOptions, 1)
    raceInvokeActionItem = UIMenuItem.New('Create Selected Race')
    raceJoinAvailableListItem = UIMenuListItem.New('Available Races', { 'Loading...' }, 1)
    raceJoinActionItem = UIMenuItem.New('Join Selected Race')
    raceJoinDetailItemOne = UIMenuItem.New('Laps')
    raceJoinDetailItemTwo = UIMenuItem.New('Entrants')
    raceJoinDetailItemThree = UIMenuItem.New('State')
    raceEditorSelectedItem = UIMenuListItem.New('Selected Race', { 'Type a race name...' }, 1)
    raceEditorOpenItem = UIMenuItem.New('Open/Create Selected')
    raceEditorWidthItem = UIMenuSliderItem.New('Checkpoint Width', #raceMenuCheckpointWidthValues - 1, 1, getCheckpointWidthIndex(editorState.defaultCheckpointRadius) - 1, false)
    raceEditorAddCheckpointItem = UIMenuItem.New('Add Checkpoint')
    raceEditorGrabCheckboxItem = UIMenuCheckboxItem.New('Grab Checkpoint', false, 1)
    raceEditorSaveItem = UIMenuItem.New('Save Selected Race')
    raceEditorDeleteItem = UIMenuItem.New('Delete Selected Race')

    raceInvokeMenu:AddItem(raceInvokeDefinitionItem)
    raceInvokeMenu:AddItem(raceInvokeLapItem)
    raceInvokeMenu:AddItem(raceInvokeActionItem)
    raceJoinMenu:AddItem(raceJoinAvailableListItem)
    raceJoinMenu:AddItem(raceJoinActionItem)
    raceJoinMenu:AddItem(raceJoinDetailItemOne)
    raceJoinMenu:AddItem(raceJoinDetailItemTwo)
    raceJoinMenu:AddItem(raceJoinDetailItemThree)
    raceEditorMenu:AddItem(raceEditorSelectedItem)
    raceEditorMenu:AddItem(raceEditorOpenItem)
    raceEditorMenu:AddItem(raceEditorWidthItem)
    raceEditorMenu:AddItem(raceEditorAddCheckpointItem)
    raceEditorMenu:AddItem(raceEditorGrabCheckboxItem)
    raceEditorMenu:AddItem(raceEditorSaveItem)
    raceEditorMenu:AddItem(raceEditorDeleteItem)

    raceMainMenu:BindMenuToItem(raceInvokeMenu, raceOwnedStatusItem)
    raceMainMenu:BindMenuToItem(raceJoinMenu, raceJoinedStatusItem)
    raceMainMenu:BindMenuToItem(raceKillMenu, raceKillMenuItem)
    raceMainMenu:BindMenuToItem(raceEditorMenu, raceEditorMenuItem)
    raceOwnedStatusItem.Activated = function(menu)
        menu:SwitchTo(raceInvokeMenu, 1, true)
    end
    raceJoinedStatusItem.Activated = function(menu)
        menu:SwitchTo(raceJoinMenu, 1, true)
    end
    raceKillMenuItem.Activated = function(menu)
        menu:SwitchTo(raceKillMenu, 1, true)
    end
    raceEditorMenuItem.Activated = function(menu)
        menu:SwitchTo(raceEditorMenu, 1, true)
    end

    raceMainMenu.OnMenuClose = function()
        setRaceMenuOpenState(isRaceMenuVisible())
    end

    raceInvokeMenu.OnMenuClose = function()
        setRaceMenuOpenState(isRaceMenuVisible())
    end

    raceJoinMenu.OnMenuClose = function()
        setRaceMenuOpenState(isRaceMenuVisible())
    end

    raceKillMenu.OnMenuClose = function()
        setRaceMenuOpenState(isRaceMenuVisible())
    end

    raceEditorMenu.OnMenuClose = function()
        if editorState.active then
            endEditorSession()
            refreshRaceMenu()
        end
        setRaceMenuOpenState(isRaceMenuVisible())
    end

    raceMainMenu.OnItemSelect = function(_, item, index)
        if item == raceRefreshItem then
            requestRaceStateSnapshot()
            refreshRaceMenu()
        elseif item == raceQuickLeaveItem then
            TriggerServerEvent('racingsystem:leaveRace')
        elseif item == raceQuickFinishItem then
            TriggerServerEvent('racingsystem:finishRace')
        elseif item == raceQuickStartItem then
            TriggerServerEvent('racingsystem:startRace')
        end
    end

    raceEditorMenu.OnListChange = function(_, item, index)
        if item ~= raceEditorSelectedItem then
            return
        end

        local selectedDefinition = raceMenuEditorOptions[index]
        if selectedDefinition then
            editorState.selectedName = tostring(selectedDefinition.name or '')
            raceMenuDeleteConfirmName = nil
            refreshRaceMenu()
        end
    end

    raceEditorMenu.OnListSelect = function(_, item, index)
        if item ~= raceEditorSelectedItem then
            return
        end

        local currentDefinition = raceMenuEditorOptions[raceEditorSelectedItem:Index()]
        local typedRaceName = promptRaceNameInput('Edit race name', editorState.selectedName ~= '' and editorState.selectedName or (currentDefinition and currentDefinition.name or ''), 64)
        if not typedRaceName or typedRaceName == '' then
            return
        end

        editorState.selectedName = typedRaceName
        raceMenuDeleteConfirmName = nil
        local normalizedTypedName = RacingSystem.NormalizeRaceName(typedRaceName)
        local foundExistingDefinition = false

        if normalizedTypedName then
            for listIndex, definition in ipairs(raceMenuEditorOptions) do
                if RacingSystem.NormalizeRaceName(definition.name) == normalizedTypedName then
                    raceEditorSelectedItem:Index(listIndex)
                    raceMenuPendingEditorName = nil
                    foundExistingDefinition = true
                    break
                end
            end
        end

        if not foundExistingDefinition then
            raceMenuPendingEditorName = nil
        end

        refreshRaceMenu()
    end

    raceInvokeMenu.OnItemSelect = function(_, item, index)
        if item ~= raceInvokeActionItem then
            return
        end

        local definition = getSelectedInvokeDefinition()
        if not definition then
            notify('There is no saved race available to invoke.')
            return
        end

        TriggerServerEvent('racingsystem:invokeRace', definition.name, getSelectedInvokeLapCount())
        raceInvokeMenu:GoBack()
    end

    raceJoinMenu.OnListChange = function(_, item, index)
        if item ~= raceJoinAvailableListItem then
            return
        end

        local instance = raceMenuJoinOptions[index]
        local alreadyJoined = instance ~= nil and isSameRaceInstance(instance, getJoinedRaceInstance())
        if instance then
            raceJoinActionItem:Enabled(not alreadyJoined)
            if alreadyJoined then
                raceJoinActionItem:Description('You are already joined to this race.')
            else
                raceJoinActionItem:Description(('Join "%s".'):format(getInstanceDisplayName(instance)))
            end
            raceJoinDetailItemOne:RightLabel(tostring(math.max(1, tonumber(instance.laps) or 1)))
            raceJoinDetailItemTwo:RightLabel(tostring(getInstanceEntrantCount(instance)))
            raceJoinDetailItemThree:RightLabel(tostring(getInstanceStateLabel(instance)))
        else
            raceJoinActionItem:Enabled(false)
            raceJoinActionItem:Description('Select an available race first.')
            raceJoinDetailItemOne:RightLabel('--')
            raceJoinDetailItemTwo:RightLabel('--')
            raceJoinDetailItemThree:RightLabel('--')
        end
    end

    raceJoinMenu.OnItemSelect = function(_, item, index)
        if item ~= raceJoinActionItem then
            return
        end

        local selectedIndex = raceJoinAvailableListItem and raceJoinAvailableListItem:Index() or 1
        local instance = raceMenuJoinOptions[selectedIndex]
        if not instance then
            return
        end

        if isSameRaceInstance(instance, getJoinedRaceInstance()) then
            notify('You are already joined to that race.')
            return
        end

        TriggerServerEvent('racingsystem:joinRace', instance.name)
    end

    raceKillMenu.OnItemSelect = function(_, item, index)
        local instance = raceMenuEndOptions[index]
        if instance then
            TriggerServerEvent('racingsystem:killRace', instance.name)
        end
    end

    raceEditorMenu.OnItemSelect = function(_, item, index)
        if item == raceEditorOpenItem then
            local selectedDefinition = raceMenuEditorOptions[raceEditorSelectedItem:Index()]
            local raceName = editorState.selectedName ~= '' and editorState.selectedName or (selectedDefinition and selectedDefinition.name or '')
            local trimmedRaceName = RacingSystem.Trim(raceName)
            if trimmedRaceName == '' then
                notify('Choose or type a race name first.')
                return
            end

            editorState.selectedName = trimmedRaceName
            raceMenuDeleteConfirmName = nil
            TriggerServerEvent('racingsystem:requestEditorRace', trimmedRaceName)
        elseif item == raceEditorAddCheckpointItem then
            addCheckpointAtPlayer()
            refreshRaceMenu()
        elseif item == raceEditorSaveItem then
            local selectedDefinition = raceMenuEditorOptions[raceEditorSelectedItem:Index()]
            local raceName = editorState.selectedName ~= '' and editorState.selectedName or (selectedDefinition and selectedDefinition.name or '')
            local trimmedRaceName = RacingSystem.Trim(raceName)
            if trimmedRaceName == '' then
                notify('Choose or type a race name before saving.')
                return
            end

            editorState.selectedName = trimmedRaceName
            raceMenuDeleteConfirmName = nil
            saveEditorRace(trimmedRaceName)
        elseif item == raceEditorDeleteItem then
            local selectedDefinition = raceMenuEditorOptions[raceEditorSelectedItem:Index()]
            if not selectedDefinition then
                notify('Only indexed races can be deleted from this menu.')
                return
            end

            local selectedRaceName = tostring(selectedDefinition.name or '')
            local normalizedSelectedRaceName = RacingSystem.NormalizeRaceName(selectedRaceName)
            local normalizedDeleteConfirmName = RacingSystem.NormalizeRaceName(raceMenuDeleteConfirmName)

            if normalizedDeleteConfirmName ~= nil and normalizedDeleteConfirmName == normalizedSelectedRaceName then
                raceMenuDeleteConfirmName = nil
                TriggerServerEvent('racingsystem:deleteRaceDefinition', selectedRaceName)
            else
                raceMenuDeleteConfirmName = selectedRaceName
                refreshRaceMenu()
            end
        end
    end

    raceEditorMenu.OnSliderChange = function(_, item, index)
        if item ~= raceEditorWidthItem then
            return
        end

        local selectedWidth = getSelectedCheckpointWidth()
        editorState.defaultCheckpointRadius = selectedWidth
        local checkpoint = getEditorTargetCheckpoint()
        if checkpoint then
            checkpoint.radius = selectedWidth
        end
    end

    raceEditorMenu.OnCheckboxChange = function(_, item, checked)
        if item ~= raceEditorGrabCheckboxItem then
            return
        end

        local currentlyGrabbed = editorState.grabbedCheckpointIndex ~= nil
        if checked ~= currentlyGrabbed then
            toggleGrabClosestCheckpoint()
        end

        raceEditorGrabCheckboxItem:Checked(editorState.grabbedCheckpointIndex ~= nil)
    end

    raceJoinActionItem:Enabled(false)
    raceJoinDetailItemOne:Enabled(false)
    raceJoinDetailItemTwo:Enabled(false)
    raceJoinDetailItemThree:Enabled(false)

    raceMenuInitialized = true
    return true
end

local function openRaceMenu()
    if not initializeRaceMenu() then
        notify('ScaleformUI is not available.')
        return
    end

    requestRaceStateSnapshot()
    refreshRaceMenu()
    setRaceMenuOpenState(true)
    raceMainMenu:Visible(true)
end

local function unloadActiveInstanceAssets()
    for _, objectHandle in ipairs(activeInstanceAssets.objects or {}) do
        if DoesEntityExist(objectHandle) then
            DeleteObject(objectHandle)
        end
    end

    for _, modelHide in ipairs(activeInstanceAssets.modelHides or {}) do
        RemoveModelHide(modelHide.x, modelHide.y, modelHide.z, modelHide.radius, modelHide.model, false)
    end

    activeInstanceAssets.instanceId = nil
    activeInstanceAssets.objects = {}
    activeInstanceAssets.modelHides = {}
end

local function loadInstanceAssets(payload)
    if type(payload) ~= 'table' then
        return false
    end

    unloadActiveInstanceAssets()

    activeInstanceAssets.instanceId = tonumber(payload.instanceId)
    activeInstanceAssets.objects = {}
    activeInstanceAssets.modelHides = {}

    for _, prop in ipairs(type(payload.props) == 'table' and payload.props or {}) do
        local model = tonumber(prop.model)
        if model and IsModelInCdimage(model) then
            RequestModel(model)
            while not HasModelLoaded(model) do
                Wait(0)
            end

            local newObject = CreateObjectNoOffset(
                model,
                tonumber(prop.x) or 0.0,
                tonumber(prop.y) or 0.0,
                tonumber(prop.z) or 0.0,
                false,
                true,
                false
            )

            if DoesEntityExist(newObject) then
                FreezeEntityPosition(newObject, true)
                SetEntityHeading(newObject, tonumber(prop.heading) or 0.0)
                SetEntityRotation(
                    newObject,
                    tonumber(prop.rotX) or 0.0,
                    tonumber(prop.rotY) or 0.0,
                    tonumber(prop.rotZ) or 0.0,
                    2,
                    false
                )

                local textureVariant = tonumber(prop.textureVariant) or -1
                if textureVariant ~= -1 then
                    SetObjectTextureVariant(newObject, textureVariant)
                end

                local lodDistance = tonumber(prop.lodDistance) or -1
                if lodDistance ~= -1 then
                    SetEntityLodDist(newObject, lodDistance)
                end

                local speedAdjustment = tonumber(prop.speedAdjustment) or -1
                local hasSpeedAdjust, speed, duration = GetPropSpeedModificationParameters(model, speedAdjustment)
                if hasSpeedAdjust then
                    if speed > -1 then
                        SetObjectStuntPropSpeedup(newObject, speed)
                    end

                    if duration > -1 then
                        SetObjectStuntPropDuration(newObject, duration)
                    end
                end

                activeInstanceAssets.objects[#activeInstanceAssets.objects + 1] = newObject
            end

            SetModelAsNoLongerNeeded(model)
        end
    end

    for _, modelHide in ipairs(type(payload.modelHides) == 'table' and payload.modelHides or {}) do
        local x = tonumber(modelHide.x) or 0.0
        local y = tonumber(modelHide.y) or 0.0
        local z = tonumber(modelHide.z) or 0.0
        local radius = tonumber(modelHide.radius) or 10.0
        local model = tonumber(modelHide.model) or 0

        CreateModelHide(x, y, z, radius, model, true)
        activeInstanceAssets.modelHides[#activeInstanceAssets.modelHides + 1] = {
            x = x,
            y = y,
            z = z,
            radius = radius,
            model = model,
        }
    end

    return true
end

local function getPlayerPositionText(instance, entrant)
    local position = tonumber(entrant and entrant.position) or 1
    local totalEntrants = #(type(instance.entrants) == 'table' and instance.entrants or {})
    totalEntrants = math.max(totalEntrants, 1)
    return ('POS %s/%s'):format(position, totalEntrants)
end

local function getPlayerLapText(instance, entrant)
    local totalLaps = math.max(1, tonumber(instance and instance.laps) or 1)
    local lap = math.max(1, tonumber(entrant and entrant.currentLap) or 1)
    if tonumber(entrant and entrant.finishedAt) then
        lap = totalLaps
    end

    return ('LAP %s/%s'):format(math.min(lap, totalLaps), totalLaps)
end

local function clearPendingCheckpointIfAdvanced(entrant)
    if not raceRuntimeState.pendingCheckpointPass then
        return
    end

    local currentCheckpoint = tonumber(entrant and entrant.currentCheckpoint) or 1
    local pending = raceRuntimeState.pendingCheckpointPass
    if pending.instanceId ~= nil and tonumber(currentCheckpoint) ~= tonumber(pending.checkpointIndex) then
        raceRuntimeState.pendingCheckpointPass = nil
        return
    end

    if GetGameTimer() > (pending.expiresAt or 0) then
        raceRuntimeState.pendingCheckpointPass = nil
    end
end

RegisterNetEvent('racingsystem:stateSnapshot', function(snapshot)
    if type(snapshot) ~= 'table' then
        return
    end

    latestSnapshot = snapshot

    local activeCountdowns = {}
    local snapshotInstances = type(snapshot.instances) == 'table' and snapshot.instances or {}
    for _, instance in ipairs(snapshotInstances) do
        local instanceId = tonumber(instance.id)
        if instanceId and instance.state == RacingSystem.States.staging and raceCountdownLocalEndByInstanceId[instanceId] then
            activeCountdowns[instanceId] = raceCountdownLocalEndByInstanceId[instanceId]
        end
    end

    raceCountdownLocalEndByInstanceId = activeCountdowns

    if raceMenuInitialized and isRaceMenuVisible() then
        refreshRaceMenu()
    end
end)

RegisterNetEvent('racingsystem:startCountdown', function(payload)
    if type(payload) ~= 'table' then
        return
    end

    local instanceId = tonumber(payload.instanceId)
    local countdownMs = math.max(0, tonumber(payload.countdownMs) or 0)
    if not instanceId then
        return
    end

    ensureLocalRaceTiming(instanceId)
    raceCountdownLocalEndByInstanceId[instanceId] = GetGameTimer() + countdownMs
    raceCountdownReportedZeroByInstanceId[instanceId] = nil
    raceStartCueShownByInstanceId[instanceId] = nil
    raceTimingState.raceStartedAt = raceCountdownLocalEndByInstanceId[instanceId]
    raceTimingState.lapStartedAt = raceCountdownLocalEndByInstanceId[instanceId]
    notifyFeed(("Race starts in %.1fs"):format(countdownMs / 1000.0))
end)

RegisterNetEvent('racingsystem:lapCompleted', function(payload)
    if type(payload) ~= 'table' then
        return
    end

    local localServerId = tonumber(GetPlayerServerId(PlayerId())) or 0
    local lapOwnerSource = tonumber(payload.playerSource) or 0
    if lapOwnerSource ~= localServerId then
        return
    end

    if payload.finished == true then
        local instance = getJoinedRaceInstance()
        local entrant = getLocalEntrant(instance)
        local positionText = getPlayerPositionText(instance, entrant)
        showRaceEventVisual('~g~FINISHED', ('~w~%s'):format(positionText), 2200)
    else
        local lapNumber = math.max(1, math.floor(tonumber(payload.lapNumber) or 1))
        showRaceEventVisual(('~b~LAP %d COMPLETED'):format(lapNumber), '', 1400)
    end

    local bestLapDeltaMs = tonumber(payload.bestLapDeltaMs) or 0
    local comparisonText

    if math.abs(bestLapDeltaMs) <= 0.5 then
        comparisonText = 'BEST LAP MATCHED'
    elseif bestLapDeltaMs > 0 then
        comparisonText = 'OFF BEST LAP'
    else
        comparisonText = 'NEW BEST LAP'
    end

    notifyFeed('Lap completed.')
    notifyFeed(comparisonText)
end)

RegisterNetEvent('racingsystem:stableLapTime', function(payload)
    if type(payload) ~= 'table' then
        return
    end

    notifyFeed('Stable lap recorded.')
end)

RegisterNetEvent('racingsystem:instanceAssets', function(payload)
    if type(payload) ~= 'table' or tonumber(payload.instanceId) == nil then
        return
    end

    instanceAssetCache[tonumber(payload.instanceId)] = payload
end)

RegisterNetEvent('racingsystem:teleportToCheckpoint', function(payload)
    if type(payload) ~= 'table' then
        return
    end

    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then
        return
    end

    local destinationX = tonumber(payload.x) or 0.0
    local destinationY = tonumber(payload.y) or 0.0
    local destinationZ = tonumber(payload.z) or 0.0
    local heading = tonumber(payload.heading) or 0.0

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
        SetEntityCoordsNoOffset(vehicle, destinationX, destinationY, destinationZ, false, false, false)
        SetEntityHeading(vehicle, heading)
        SetVehicleOnGroundProperly(vehicle)
    else
        SetEntityCoordsNoOffset(ped, destinationX, destinationY, destinationZ, false, false, false)
        SetEntityHeading(ped, heading)
    end
end)

RegisterNetEvent('racingsystem:editorRaceLoaded', function(payload)
    if type(payload) ~= 'table' or payload.ok ~= true then
        notify('Could not load race editor data.')
        return
    end

    local requestedName = RacingSystem.Trim(payload.requestedName)
    local race = type(payload.race) == 'table' and payload.race or nil
    local raceName = race and race.name or (requestedName ~= '' and requestedName or 'Untitled Race')
    local checkpoints = race and race.checkpoints or {}

    editorState.selectedName = raceName
    beginEditorSession(raceName, checkpoints)
    refreshRaceMenu()
end)

RegisterNetEvent('racingsystem:editorRaceSaved', function(payload)
    if type(payload) ~= 'table' or payload.ok ~= true then
        notify(type(payload) == 'table' and payload.error or 'Could not save race.')
        return
    end

    local race = payload.race or {}
    editorState.name = race.name or editorState.name
    editorState.selectedName = editorState.name
    editorState.checkpoints = cloneCheckpoints(race.checkpoints or editorState.checkpoints)
    normalizeCheckpointIndexes()

    for _, checkpoint in ipairs(editorState.checkpoints) do
        ensureCheckpointMarkerAlignment(checkpoint)
    end
    requestRaceStateSnapshot()
    refreshRaceMenu()
end)

RegisterNetEvent('racingsystem:raceDefinitionRegistered', function(payload)
    if type(payload) ~= 'table' or payload.ok ~= true then
        notify(type(payload) == 'table' and payload.error or 'Could not register race definition.')
        return
    end

    local definition = type(payload.definition) == 'table' and payload.definition or {}
    raceMenuPendingSelectName = definition.name or raceMenuPendingSelectName
    raceMenuPendingEditorName = definition.name or raceMenuPendingEditorName
    requestRaceStateSnapshot()
end)

RegisterNetEvent('racingsystem:raceDefinitionDeleted', function(payload)
    raceMenuDeleteConfirmName = nil

    if type(payload) ~= 'table' or payload.ok ~= true then
        notify(type(payload) == 'table' and payload.error or 'Could not delete race definition.')
        refreshRaceMenu()
        return
    end

    local definition = type(payload.definition) == 'table' and payload.definition or {}
    local deletedName = tostring(definition.name or 'unknown')

    if RacingSystem.NormalizeRaceName(editorState.selectedName) == RacingSystem.NormalizeRaceName(deletedName) then
        editorState.selectedName = ''
    end

    requestRaceStateSnapshot()
end)

RegisterCommand('+racemenu', function()
    openRaceMenu()
end, false)

RegisterCommand('-racemenu', function()
end, false)

CreateThread(function()
    Wait(1500)
    requestRaceStateSnapshot()
end)

RegisterKeyMapping('+racemenu', 'Open race control menu', 'keyboard', 'F7')

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
                    local visualRadius = getVisualCheckpointRadius(checkpoint)

                    DrawMarker(
                        RacingSystem.Config.markerTypeId,
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

CreateThread(function()
    while true do
        local joinedInstance = getJoinedRaceInstance()

        if not joinedInstance then
            raceRuntimeState.pendingCheckpointPass = nil
            raceRuntimeState.previousPosition = nil
            raceRuntimeState.checkpointPassArm = nil
            raceRuntimeState.lastOutsideCheckpointCrossKey = nil
            raceRuntimeState.accelerationPenaltyUntil = 0
            resetLocalRaceTiming()
            clearCountdownScaleform()
            if activeInstanceAssets.instanceId then
                unloadActiveInstanceAssets()
            end
            Wait(1000)
        else
            local joinedInstanceId = tonumber(joinedInstance.id)
            ensureLocalRaceTiming(joinedInstanceId)
            if joinedInstance.sourceType == 'online' then
                if tonumber(activeInstanceAssets.instanceId) ~= joinedInstanceId then
                    local payload = instanceAssetCache[joinedInstanceId]
                    if payload then
                        loadInstanceAssets(payload)
                    end
                end
            elseif activeInstanceAssets.instanceId then
                unloadActiveInstanceAssets()
            end

            local ped = PlayerPedId()
            local origin = GetEntityCoords(ped)
            local pedVehicle = GetVehiclePedIsIn(ped, false)
            local entrant = getLocalEntrant(joinedInstance)
            local entrantProgress = getEffectiveEntrantProgress(joinedInstance, entrant)
            local checkpoints = type(joinedInstance.checkpoints) == 'table' and joinedInstance.checkpoints or {}
            local totalCheckpoints = #checkpoints
            local targetIndex = 1

            clearPendingCheckpointIfAdvanced(entrant)
            targetIndex = tonumber(entrantProgress.currentCheckpoint) or targetIndex

            for _, otherEntrant in ipairs(type(joinedInstance.entrants) == 'table' and joinedInstance.entrants or {}) do
                local otherSource = tonumber(otherEntrant.source) or 0
                if otherSource > 0 and otherSource ~= GetPlayerServerId(PlayerId()) then
                    local otherPlayer = GetPlayerFromServerId(otherSource)
                    if otherPlayer and otherPlayer ~= -1 then
                        local otherPed = GetPlayerPed(otherPlayer)
                        if otherPed and otherPed ~= 0 and DoesEntityExist(otherPed) then
                            local otherVehicle = GetVehiclePedIsIn(otherPed, false)
                            SetEntityNoCollisionEntity(ped, otherPed, true)
                            SetEntityNoCollisionEntity(otherPed, ped, true)

                            if pedVehicle ~= 0 and DoesEntityExist(pedVehicle) then
                                SetEntityNoCollisionEntity(pedVehicle, otherPed, true)
                                SetEntityNoCollisionEntity(otherPed, pedVehicle, true)
                            end

                            if otherVehicle ~= 0 and DoesEntityExist(otherVehicle) then
                                SetEntityNoCollisionEntity(ped, otherVehicle, true)
                                SetEntityNoCollisionEntity(otherVehicle, ped, true)
                            end

                            if pedVehicle ~= 0 and DoesEntityExist(pedVehicle) and otherVehicle ~= 0 and DoesEntityExist(otherVehicle) then
                                SetEntityNoCollisionEntity(pedVehicle, otherVehicle, true)
                                SetEntityNoCollisionEntity(otherVehicle, pedVehicle, true)
                            end
                        end
                    end
                end
            end

            if entrant then
                if joinedInstance.state == RacingSystem.States.staging and tonumber(joinedInstance.id) then
                    local joinedInstanceId = tonumber(joinedInstance.id)
                    local countdownEndsAt = raceCountdownLocalEndByInstanceId[joinedInstanceId]
                    local remainingMs = countdownEndsAt and math.max(0, countdownEndsAt - GetGameTimer()) or 0
                    updateCountdownVisual(joinedInstanceId, remainingMs)

                    if pedVehicle ~= 0 and GetPedInVehicleSeat(pedVehicle, -1) == ped then
                        SetVehicleHandbrake(pedVehicle, true)
                    end

                    if countdownEndsAt and remainingMs <= 0 and not raceCountdownReportedZeroByInstanceId[joinedInstanceId] then
                        raceCountdownReportedZeroByInstanceId[joinedInstanceId] = true
                        TriggerServerEvent('racingsystem:countdownReachedZero', joinedInstanceId, GetGameTimer())
                    end
                elseif joinedInstance.state == RacingSystem.States.running then
                    clearCountdownScaleform()
                    local joinedInstanceId = tonumber(joinedInstance.id)
                    if joinedInstanceId and not raceStartCueShownByInstanceId[joinedInstanceId] then
                        raceStartCueShownByInstanceId[joinedInstanceId] = true
                        showRaceEventVisual('~g~GO!', '~w~Race is live', 1400)
                        notifyFeed('GO! Race is live.')
                    end
                    if raceTimingState.raceStartedAt == nil then
                        raceTimingState.raceStartedAt = GetGameTimer()
                    end
                    if raceTimingState.lapStartedAt == nil then
                        raceTimingState.lapStartedAt = raceTimingState.raceStartedAt
                    end
                    if pedVehicle ~= 0 and GetPedInVehicleSeat(pedVehicle, -1) == ped then
                        SetVehicleHandbrake(pedVehicle, false)
                    end
                elseif joinedInstance.state == RacingSystem.States.finished and tonumber(entrantProgress.finishedAt) then
                    clearCountdownScaleform()
                    if pedVehicle ~= 0 and GetPedInVehicleSeat(pedVehicle, -1) == ped then
                        SetVehicleHandbrake(pedVehicle, false)
                    end
                else
                    clearCountdownScaleform()
                    if pedVehicle ~= 0 and GetPedInVehicleSeat(pedVehicle, -1) == ped then
                        SetVehicleHandbrake(pedVehicle, false)
                    end
                end
            end

            local targetCheckpoint = checkpoints[targetIndex]
            if not targetCheckpoint or totalCheckpoints == 0 then
                raceRuntimeState.checkpointPassArm = nil
                raceRuntimeState.previousPosition = origin
                Wait(1000)
            else
                local checkpointCoords = vector3(targetCheckpoint.x or 0.0, targetCheckpoint.y or 0.0, targetCheckpoint.z or 0.0)
                local distance = #(origin - checkpointCoords)

                if distance <= RacingSystem.Config.checkpointDrawDistanceMeters then
                    local totalLaps = math.max(1, tonumber(joinedInstance.laps) or 1)
                    local lapTriggerCheckpoint = (totalLaps > 1 and totalCheckpoints > 1) and 1 or totalCheckpoints
                    local isStart = targetIndex == 1
                    local isFinish = targetIndex == lapTriggerCheckpoint
                    local markerDraw = getPreviewCheckpointMarker(targetCheckpoint)
                    local visualRadius = getVisualCheckpointRadius(targetCheckpoint)
                    DrawMarker(
                        RacingSystem.Config.markerTypeId,
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
                        isFinish and 255 or 80,
                        255,
                        isStart and 120 or (isFinish and 80 or 255),
                        160,
                        false,
                        true,
                        2,
                        false,
                        nil,
                        nil,
                        false
                    )

                    if totalCheckpoints > 1 then
                        local nextIndex = targetIndex + 1
                        if nextIndex > totalCheckpoints then
                            nextIndex = 1
                        end
                        local nextCheckpoint = checkpoints[nextIndex]
                        if nextCheckpoint then
                            local chevronHeading = getHeadingToNextCheckpoint(targetCheckpoint, nextCheckpoint)
                            local chevronZ = (tonumber(targetCheckpoint.z) or markerDraw.z) + math.max(0.8, visualRadius * 0.08)
                            DrawMarker(
                                20,
                                markerDraw.x,
                                markerDraw.y,
                                chevronZ,
                                0.0,
                                0.0,
                                0.0,
                                90.0,
                                0.0,
                                chevronHeading,
                                math.max(1.5, visualRadius * 0.25),
                                math.max(1.5, visualRadius * 0.25),
                                1.0,
                                255,
                                235,
                                80,
                                220,
                                false,
                                false,
                                2,
                                false,
                                nil,
                                nil,
                                false
                            )
                        end
                    end
                end

                if joinedInstance.state == RacingSystem.States.running and entrant and tonumber(entrantProgress.finishedAt) == nil then
                    local pending = raceRuntimeState.pendingCheckpointPass
                    local isPendingSameCheckpoint = pending
                        and tonumber(pending.instanceId) == tonumber(joinedInstance.id)
                        and tonumber(pending.checkpointIndex) == tonumber(targetIndex)
                        and GetGameTimer() <= (pending.expiresAt or 0)
                    local withinPassDetectionRange = distance <= CHECKPOINT_PASS_ARM_DISTANCE

                    local checkpointPassed = false
                    local passedOutsideRadius = false
                    local outsideLateralDistance = nil
                    local currentLap = math.max(1, tonumber(entrantProgress.currentLap) or 1)
                    local currentArmKey = getCheckpointPassArmKey(joinedInstance.id, targetIndex, currentLap)
                    local checkpointPassArm = raceRuntimeState.checkpointPassArm

                    if withinPassDetectionRange and not isPendingSameCheckpoint then
                        if checkpointPassArm == nil or checkpointPassArm.key ~= currentArmKey then
                            checkpointPassArm = {
                                key = currentArmKey,
                                minDistance = distance,
                            }
                            raceRuntimeState.checkpointPassArm = checkpointPassArm
                        else
                            checkpointPassArm.minDistance = math.min(tonumber(checkpointPassArm.minDistance) or distance, distance)
                            if distance >= ((tonumber(checkpointPassArm.minDistance) or distance) + CHECKPOINT_PASS_RELEASE_DELTA) then
                                checkpointPassed = true
                                outsideLateralDistance = tonumber(checkpointPassArm.minDistance) or distance
                                passedOutsideRadius = outsideLateralDistance > (tonumber(targetCheckpoint.radius) or 8.0)
                                raceRuntimeState.checkpointPassArm = nil
                            end
                        end
                    elseif checkpointPassArm and checkpointPassArm.key == currentArmKey and distance > (CHECKPOINT_PASS_ARM_DISTANCE + 5.0) then
                        raceRuntimeState.checkpointPassArm = nil
                    end

                    if checkpointPassed then
                        if passedOutsideRadius then
                            local outsideOffset = math.max(0.0, (tonumber(outsideLateralDistance) or 0.0) - (tonumber(targetCheckpoint.radius) or 8.0))
                            local instanceId = tonumber(joinedInstance.id) or 0
                            local lapNumber = math.max(1, tonumber(entrantProgress.currentLap) or 1)
                            local outsideKey = ('%s:%s:%s'):format(instanceId, targetIndex, lapNumber)
                            if raceRuntimeState.lastOutsideCheckpointCrossKey ~= outsideKey then
                                raceRuntimeState.lastOutsideCheckpointCrossKey = outsideKey
                                if outsideOffset > 25.0 then
                                    notifyFeed(('Checkpoint cut (+%.1fm): no correction applied (over 25m cap).'):format(outsideOffset))
                                elseif outsideOffset >= 15.0 then
                                    local correctionEntity = (pedVehicle ~= 0 and DoesEntityExist(pedVehicle)) and pedVehicle or ped
                                    local correctionNextIndex = targetIndex + 1
                                    if correctionNextIndex > totalCheckpoints then
                                        correctionNextIndex = 1
                                    end
                                    teleportEntityToCheckpoint(correctionEntity, targetCheckpoint, checkpoints[correctionNextIndex])
                                    notifyFeed(('Checkpoint cut (+%.1fm): teleport correction applied.'):format(outsideOffset))
                                elseif outsideOffset <= 5.0 then
                                    raceRuntimeState.accelerationPenaltyUntil = GetGameTimer() + 2000
                                    notifyFeed(('Checkpoint cut (+%.1fm): 2s throttle penalty applied.'):format(outsideOffset))
                                else
                                    notifyFeed(('Checkpoint cut (+%.1fm): warning only.'):format(outsideOffset))
                                end
                            end
                        end

                        local lapTimingPayload = nil
                        local totalLaps = math.max(1, tonumber(joinedInstance.laps) or 1)
                        local lapTriggerCheckpoint = (totalLaps > 1 and totalCheckpoints > 1) and 1 or totalCheckpoints
                        if targetIndex == lapTriggerCheckpoint then
                            local nowMs = GetGameTimer()
                            local raceStartedAt = tonumber(raceTimingState.raceStartedAt) or nowMs
                            local lapStartedAt = tonumber(raceTimingState.lapStartedAt) or raceStartedAt
                            local currentLap = math.max(1, tonumber(entrantProgress.currentLap) or 1)

                            lapTimingPayload = {
                                lapNumber = currentLap,
                                lapTimeMs = math.max(0, nowMs - lapStartedAt),
                                totalTimeMs = math.max(0, nowMs - raceStartedAt),
                                finished = currentLap >= totalLaps,
                            }

                            if lapTimingPayload.finished then
                                raceTimingState.lapStartedAt = nil
                            else
                                raceTimingState.lapStartedAt = nowMs
                            end
                        end

                        raceRuntimeState.pendingCheckpointPass = {
                            instanceId = joinedInstance.id,
                            checkpointIndex = targetIndex,
                            expiresAt = GetGameTimer() + 1500,
                        }

                        predictCheckpointPass(joinedInstance, entrantProgress, totalCheckpoints, targetIndex)
                        TriggerServerEvent('racingsystem:checkpointPassed', joinedInstance.id, targetIndex, lapTimingPayload)
                    end
                end

                raceRuntimeState.previousPosition = origin
                local penaltyUntil = tonumber(raceRuntimeState.accelerationPenaltyUntil) or 0
                if penaltyUntil > GetGameTimer() then
                    DisableControlAction(0, 71, true)
                    DisableControlAction(1, 71, true)
                    DisableControlAction(2, 71, true)
                end
                Wait(0)
            end
        end
    end
end)

CreateThread(function()
    while true do
        drawRaceEventVisual()
        Wait(0)
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    unloadActiveInstanceAssets()
end)

print('[racingsystem] Client system loaded.')
