RacingSystemUtil = type(RacingSystemUtil) == 'table' and RacingSystemUtil or {}

if type(RacingSystemUtil.NotifyPlayer) ~= 'function' then
    function RacingSystemUtil.NotifyPlayer(message, isError)
        local colorPrefix = isError and '~o~' or '~g~'
        local text = ('%s%s~s~'):format(colorPrefix, tostring(message or ''))
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(text)
        EndTextCommandThefeedPostTicker(false, false)
    end
end

if type(RacingSystemUtil.ShowWarningSubtitle) ~= 'function' then
    function RacingSystemUtil.ShowWarningSubtitle(message, durationMs, colorTag)
        BeginTextCommandPrint('STRING')
        local colorPrefix = tostring(colorTag or '~y~')
        AddTextComponentSubstringPlayerName(('%s%s~s~'):format(colorPrefix, tostring(message or '')))
        EndTextCommandPrint(math.max(0, math.floor(tonumber(durationMs) or 1000)), true)
    end
end

if type(RacingSystemUtil.ShowRaceEventVisual) ~= 'function' then
    function RacingSystemUtil.ShowRaceEventVisual(title, subtitle, durationMs)
        return
    end
end

if type(RacingSystemUtil.DrawRaceEventVisual) ~= 'function' then
    function RacingSystemUtil.DrawRaceEventVisual()
        return
    end
end

if type(RacingSystemUtil.UpdateCountdownVisual) ~= 'function' then
    function RacingSystemUtil.UpdateCountdownVisual(instanceId, remainingMs)
        return
    end
end

if type(RacingSystemUtil.ClearCountdownVisual) ~= 'function' then
    function RacingSystemUtil.ClearCountdownVisual()
        return
    end
end

if type(RacingSystemUtil.UpdateRaceLeaderboardVisual) ~= 'function' then
    function RacingSystemUtil.UpdateRaceLeaderboardVisual(title, rows)
        return
    end
end

if type(RacingSystemUtil.DrawRaceLeaderboardVisual) ~= 'function' then
    function RacingSystemUtil.DrawRaceLeaderboardVisual()
        return
    end
end

if type(RacingSystemUtil.ClearRaceLeaderboardVisual) ~= 'function' then
    function RacingSystemUtil.ClearRaceLeaderboardVisual()
        return
    end
end

local latestSnapshot = {
    races = {},
    count = 0,
    viewer = {
        isAdmin = false,
        canDeleteRaceDefinitions = false,
        canKillOwnedInstances = false,
    },
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
    accelerationPenaltyUntil = 0,
    powerPenaltyUntil = 0,
    powerPenaltyVehicle = nil,
    checkpointPassArm = nil,
    lastPassedCheckpoint = nil,
    startLineCheckpoint = nil,
    joinHintInstanceId = nil,
    startLineBlip = nil,
    futureCheckpointBlips = {},
    futureBlipCheckpointIndex = nil,
    futureBlipInstanceId = nil,
}
local raceCountdownLocalEndByInstanceId = {}
local raceCountdownReportedZeroByInstanceId = {}
local raceStartCueShownByInstanceId = {}
local raceTimingState = {
    instanceId = nil,
    raceStartedAt = nil,
    lapStartedAt = nil,
}
local mockLeaderboardState = {
    localPosition = 2,
    fakeOrder = { 'vega', 'niko', 'luna' },
    swapStep = 1,
}
local CHECKPOINT_RADIUS_STEP_METERS = 1.0
local EDITOR_PITCH_UP_CONTROL_ID = 111
local EDITOR_PITCH_DOWN_CONTROL_ID = 112

local raceMenuInitialized = false
local raceMenuOpen = false
local raceMainMenu
local raceMyRaceMenu
local raceHostRaceMenu
local raceJoinMenu
local raceManageMenu
local raceKillMenu
local raceEditorMenu
local raceMyRaceMenuItem
local raceBrowseMenuItem
local raceManageMenuItem
local raceKillMenuItem
local raceEditorMenuItem
local raceRefreshItem
local raceImportGTAOItem
local raceMyRaceStatusItem
local raceBrowseStatusItem
local raceHostRaceMenuItem
local raceQuickStartItem
local raceQuickLeaveItem
local raceQuickFinishItem
local raceQuickResetItem
local raceInvokeDefinitionItem
local raceInvokeLapItem
local raceInvokePiItem
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
local raceMenuPiOptions = { '400', '800', '1200' }
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
local raceMenuKillItemActions = {}
local gtaoRaceUrlPromptOpen = false

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
local CHECKPOINT_RECOVERY_PASS_MAX_MPH = 5.0
local CHECKPOINT_RECOVERY_FORWARD_VELOCITY_RATIO_MAX = 0.66
local METERS_PER_SECOND_TO_MILES_PER_HOUR = 2.236936
local MILES_PER_HOUR_TO_METERS_PER_SECOND = 0.44704
local CHECKPOINT_SOFT_POWER_PENALTY_MULTIPLIER = 0.05
local joinTeleportInProgress = false

local function clearPowerPenaltyVehicleOverride()
    local penaltyVehicle = raceRuntimeState.powerPenaltyVehicle
    if penaltyVehicle and DoesEntityExist(penaltyVehicle) then
        SetVehicleEnginePowerMultiplier(penaltyVehicle, 0.0)
    end
    raceRuntimeState.powerPenaltyVehicle = nil
    raceRuntimeState.powerPenaltyUntil = 0
end

local function applySoftPowerPenalty(vehicle, durationMs)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return
    end

    local now = GetGameTimer()
    local penaltyDurationMs = math.max(0, math.floor(tonumber(durationMs) or 0))
    if penaltyDurationMs <= 0 then
        return
    end

    raceRuntimeState.powerPenaltyVehicle = vehicle
    raceRuntimeState.powerPenaltyUntil = now + penaltyDurationMs
    SetVehicleEnginePowerMultiplier(vehicle, CHECKPOINT_SOFT_POWER_PENALTY_MULTIPLIER)
end

local function getVehicleForwardVelocityRatio(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return 1.0
    end

    local velocity = GetEntityVelocity(vehicle)
    local speedSquared = (velocity.x * velocity.x) + (velocity.y * velocity.y) + (velocity.z * velocity.z)
    if speedSquared <= 0.0001 then
        return 0.0
    end

    local forward = GetEntityForwardVector(vehicle)
    local forwardSpeed = (velocity.x * forward.x) + (velocity.y * forward.y) + (velocity.z * forward.z)
    return forwardSpeed / math.sqrt(speedSquared)
end

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

RegisterNetEvent('racingsystem:notify', function(payload)
    if type(payload) == 'table' then
        return
    end

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

local function isSecondaryCoordinateValid(x, y, z)
    if not x or not y or not z then
        return false
    end

    if math.abs(x) < 0.001 and math.abs(y) < 0.001 and math.abs(z) < 0.001 then
        return false
    end

    if math.abs(x) > 10000.0 or math.abs(y) > 10000.0 or math.abs(z) > 5000.0 then
        return false
    end

    return true
end

local function buildDerivedSecondaryCheckpoint(instance, targetIndex, primaryCheckpoint)
    if type(primaryCheckpoint) ~= 'table' then
        return nil
    end

    local metadata = type(instance and instance.raceMetadata) == 'table' and instance.raceMetadata or nil
    local secondaryCheckpoints = metadata and type(metadata.sndchk) == 'table' and metadata.sndchk or nil
    if not secondaryCheckpoints then
        return nil
    end

    local rawSecondary = secondaryCheckpoints[targetIndex]
    if type(rawSecondary) ~= 'table' then
        return nil
    end

    local x = tonumber(rawSecondary.x)
    local y = tonumber(rawSecondary.y)
    local z = tonumber(rawSecondary.z)
    if not isSecondaryCoordinateValid(x, y, z) then
        return nil
    end

    local primaryX = tonumber(primaryCheckpoint.x) or 0.0
    local primaryY = tonumber(primaryCheckpoint.y) or 0.0
    local primaryZ = tonumber(primaryCheckpoint.z) or 0.0
    local dx = x - primaryX
    local dy = y - primaryY
    local dz = z - primaryZ
    local distance = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
    if distance < 4.0 or distance > 2500.0 then
        return nil
    end

    local radius = tonumber(primaryCheckpoint.radius) or 8.0
    local secondarySizes = metadata and type(metadata.sndsz) == 'table' and metadata.sndsz or nil
    if secondarySizes then
        local size = tonumber(secondarySizes[targetIndex])
        if size then
            radius = math.max(2.0, 8.0 * size)
        end
    end

    return {
        index = tonumber(primaryCheckpoint.index) or targetIndex,
        x = x,
        y = y,
        z = z,
        radius = radius,
    }
end

local function getCheckpointVariantEntry(instance, targetIndex)
    local checkpoints = type(instance and instance.checkpoints) == 'table' and instance.checkpoints or {}
    local primaryCheckpoint = checkpoints[targetIndex]
    if type(primaryCheckpoint) ~= 'table' then
        return nil
    end

    local variantEntry = type(instance and instance.checkpointVariants) == 'table' and instance.checkpointVariants[targetIndex] or nil
    local primary = primaryCheckpoint
    local secondary = nil

    if type(variantEntry) == 'table' then
        if type(variantEntry.primary) == 'table' then
            primary = variantEntry.primary
        end
        if type(variantEntry.secondary) == 'table' then
            secondary = variantEntry.secondary
        end
    end

    if type(secondary) ~= 'table' then
        secondary = buildDerivedSecondaryCheckpoint(instance, targetIndex, primary)
    end

    return {
        index = targetIndex,
        primary = primary,
        secondary = secondary,
    }
end

local function getNextCheckpointForVariant(instance, totalCheckpoints, targetIndex, routeVariant)
    local total = math.max(0, math.floor(tonumber(totalCheckpoints) or 0))
    if total <= 1 then
        return nil
    end

    local nextIndex = targetIndex + 1
    if nextIndex > total then
        nextIndex = 1
    end

    local nextVariantEntry = getCheckpointVariantEntry(instance, nextIndex)
    if not nextVariantEntry then
        return nil
    end

    if routeVariant == 'secondary' and type(nextVariantEntry.secondary) == 'table' then
        return nextVariantEntry.secondary
    end

    return nextVariantEntry.primary
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

local function getHorizontalDistance(origin, checkpoint)
    local originX = tonumber(origin and origin.x) or 0.0
    local originY = tonumber(origin and origin.y) or 0.0
    local checkpointX = tonumber(checkpoint and checkpoint.x) or 0.0
    local checkpointY = tonumber(checkpoint and checkpoint.y) or 0.0
    local dx = originX - checkpointX
    local dy = originY - checkpointY
    return math.sqrt((dx * dx) + (dy * dy))
end

local function drawCheckpointTarget(checkpoint, prevCheckpoint, nextCheckpoint, isStart, isFinish, markerColor, chevronColor, hideChevron, spinDegreesPerSecond)
    if type(checkpoint) ~= 'table' then
        return
    end

    local markerDraw = getPreviewCheckpointMarker(checkpoint)
    local visualRadius = getVisualCheckpointRadius(checkpoint)
    local markerRed = tonumber((markerColor or {}).r) or 80
    local markerGreen = tonumber((markerColor or {}).g) or 255
    local markerBlue = tonumber((markerColor or {}).b) or 255
    local markerAlpha = 255
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
        isFinish and 255 or markerRed,
        markerGreen,
        isStart and 120 or (isFinish and 80 or markerBlue),
        markerAlpha,
        false,
        true,
        2,
        false,
        nil,
        nil,
        false
    )

    if type(nextCheckpoint) ~= 'table' then
        return
    end

    local currentX = tonumber(checkpoint.x) or 0.0
    local currentY = tonumber(checkpoint.y) or 0.0
    local currentZ = tonumber(checkpoint.z) or 0.0
    local prevX = tonumber(prevCheckpoint and prevCheckpoint.x) or currentX
    local prevY = tonumber(prevCheckpoint and prevCheckpoint.y) or currentY
    local nextX = tonumber(nextCheckpoint.x) or currentX
    local nextY = tonumber(nextCheckpoint.y) or currentY
    local dx = nextX - currentX
    local dy = nextY - currentY
    local magnitude = math.sqrt((dx * dx) + (dy * dy))
    if magnitude <= 0.001 then
        return
    end

    local unitX = dx / magnitude
    local unitY = dy / magnitude
    local inX = currentX - prevX
    local inY = currentY - prevY
    local outX = nextX - currentX
    local outY = nextY - currentY
    local turnCross = (inX * outY) - (inY * outX)
    local turnDot = (inX * outX) + (inY * outY)
    local turnAngleAbsDeg = math.abs(math.deg(math.atan2(turnCross, turnDot)))

    -- Left turn -> outside is left. Right turn -> outside is right.
    local outsideSign = 1.0
    if turnCross < -0.01 then
        outsideSign = -1.0
    elseif turnCross > 0.01 then
        outsideSign = 1.0
    end
    local inMagnitude = math.sqrt((inX * inX) + (inY * inY))
    local inUnitX = inMagnitude > 0.001 and (inX / inMagnitude) or unitX
    local inUnitY = inMagnitude > 0.001 and (inY / inMagnitude) or unitY
    local outUnitX = unitX
    local outUnitY = unitY

    local edgeRadius = tonumber(checkpoint.radius) or 8.0
    local chevronZ = currentZ + 2.35
    local chevronSize = 0.9 * math.max(2.55, math.min(4.05, edgeRadius * 0.33))
    local darkBlue = { r = 20, g = 70, b = 170, a = 0 }
    local spinSpeed = tonumber(spinDegreesPerSecond) or 0.0
    local spinZ = 0.0
    if spinSpeed ~= 0.0 then
        spinZ = (((GetGameTimer() or 0) / 1000.0) * spinSpeed) % 360.0
    end

    local shouldDrawBothEdges = turnAngleAbsDeg < 30.0
    local edgeSigns = shouldDrawBothEdges and { -1.0, 1.0 } or { outsideSign }
    for _, edgeSign in ipairs(edgeSigns) do
        local inNormalX = (-inUnitY) * edgeSign
        local inNormalY = (inUnitX) * edgeSign
        local outNormalX = (-outUnitY) * edgeSign
        local outNormalY = (outUnitX) * edgeSign

        local bisectorX = inNormalX + outNormalX
        local bisectorY = inNormalY + outNormalY
        local bisectorMagnitude = math.sqrt((bisectorX * bisectorX) + (bisectorY * bisectorY))
        if bisectorMagnitude <= 0.001 then
            bisectorX = outNormalX
            bisectorY = outNormalY
            bisectorMagnitude = math.sqrt((bisectorX * bisectorX) + (bisectorY * bisectorY))
        end
        if bisectorMagnitude > 0.001 then
            bisectorX = bisectorX / bisectorMagnitude
            bisectorY = bisectorY / bisectorMagnitude
        end

        local edgeX = currentX + (bisectorX * edgeRadius)
        local edgeY = currentY + (bisectorY * edgeRadius)
        DrawMarker(
            22,
            edgeX,
            edgeY,
            chevronZ,
            unitX,
            unitY,
            0.0,
            90.0,
            90.0,
            spinZ,
            chevronSize,
            chevronSize,
            chevronSize,
            darkBlue.r,
            darkBlue.g,
            darkBlue.b,
            darkBlue.a,
            false,
            false,
            2,
            false,
            nil,
            nil,
            false
        )
    end

    return
end

local function drawIdleStartChevron(checkpoint)
    if type(checkpoint) ~= 'table' then
        return
    end

    local markerDraw = getPreviewCheckpointMarker(checkpoint)
    local baseRadius = tonumber(checkpoint.radius) or 8.0
    local chevronSize = 0.9 * math.max(3.0, math.min(6.6, baseRadius * 0.42))
    local drawZ = (tonumber(checkpoint.z) or markerDraw.z) + 5.4
    local playerCoords = GetEntityCoords(PlayerPedId())
    local dx = (tonumber(playerCoords.x) or markerDraw.x) - markerDraw.x
    local dy = (tonumber(playerCoords.y) or markerDraw.y) - markerDraw.y
    local chevronHeading = 0.0
    if math.abs(dx) > 0.001 or math.abs(dy) > 0.001 then
        chevronHeading = (math.deg(math.atan2(dy, dx)) - 90.0) % 360.0
    end

    DrawMarker(
        20,
        markerDraw.x,
        markerDraw.y,
        drawZ,
        0.0,
        0.0,
        0.0,
        180.0,
        0.0,
        chevronHeading,
        chevronSize,
        chevronSize,
        chevronSize,
        35,
        90,
        220,
        230,
        false,
        true,
        2,
        false,
        nil,
        nil,
        false
    )
end

local function clearFutureCheckpointBlips()
    local blipsByIndex = type(raceRuntimeState.futureCheckpointBlips) == 'table' and raceRuntimeState.futureCheckpointBlips or {}
    for _, blip in pairs(blipsByIndex) do
        if blip and DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    raceRuntimeState.futureCheckpointBlips = {}
    raceRuntimeState.futureBlipCheckpointIndex = nil
    raceRuntimeState.futureBlipInstanceId = nil
end

local function clearStartLineBlip()
    local blip = raceRuntimeState.startLineBlip
    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
    raceRuntimeState.startLineBlip = nil
end

local function buildFutureCheckpointIndices(totalCheckpoints, targetIndex, countAhead)
    local total = math.max(0, math.floor(tonumber(totalCheckpoints) or 0))
    if total <= 0 then
        return {}
    end

    local currentIndex = math.floor(tonumber(targetIndex) or 1)
    if currentIndex < 1 then
        currentIndex = 1
    elseif currentIndex > total then
        currentIndex = 1
    end

    local requestedCount = math.max(1, math.floor(tonumber(countAhead) or 5))
    local maxCount = math.min(requestedCount, total)
    local indices = {}

    for step = 1, maxCount do
        local futureIndex = currentIndex + step
        if futureIndex > total then
            futureIndex = ((futureIndex - 1) % total) + 1
        end
        indices[#indices + 1] = futureIndex
    end

    return indices
end

local function updateFutureCheckpointBlips(instance, totalCheckpoints, targetIndex)
    local indices = buildFutureCheckpointIndices(totalCheckpoints, targetIndex, 5)
    if #indices == 0 then
        clearFutureCheckpointBlips()
        return
    end

    local desired = {}
    for _, index in ipairs(indices) do
        desired[index] = true
    end

    local blipsByIndex = type(raceRuntimeState.futureCheckpointBlips) == 'table' and raceRuntimeState.futureCheckpointBlips or {}
    for index, blip in pairs(blipsByIndex) do
        if not desired[index] or not (blip and DoesBlipExist(blip)) then
            if blip and DoesBlipExist(blip) then
                RemoveBlip(blip)
            end
            blipsByIndex[index] = nil
        end
    end

    for _, index in ipairs(indices) do
        if not blipsByIndex[index] then
            local variantEntry = getCheckpointVariantEntry(instance, index)
            local checkpoint = variantEntry and variantEntry.primary or ((instance or {}).checkpoints or {})[index]
            if type(checkpoint) == 'table' then
                local blip = AddBlipForCoord(
                    tonumber(checkpoint.x) or 0.0,
                    tonumber(checkpoint.y) or 0.0,
                    tonumber(checkpoint.z) or 0.0
                )
                SetBlipSprite(blip, 1)
                SetBlipDisplay(blip, 4)
                SetBlipScale(blip, 0.75)
                SetBlipColour(blip, 11)
                SetBlipAsShortRange(blip, false)
                blipsByIndex[index] = blip
            end
        end
    end

    raceRuntimeState.futureCheckpointBlips = blipsByIndex
end

local function resolveStartLineCheckpoint(checkpoints, totalCheckpoints, fallbackCheckpoint)
    local list = type(checkpoints) == 'table' and checkpoints or {}
    local theoreticalLastIndex = math.max(1, math.floor(tonumber(totalCheckpoints) or #list or 1))
    local raw = list[theoreticalLastIndex] or list[#list] or fallbackCheckpoint or raceRuntimeState.startLineCheckpoint
    if type(raw) ~= 'table' then
        return nil
    end

    local resolved = {
        index = theoreticalLastIndex,
        x = tonumber(raw.x) or 0.0,
        y = tonumber(raw.y) or 0.0,
        z = tonumber(raw.z) or 0.0,
        radius = tonumber(raw.radius) or 8.0,
    }
    raceRuntimeState.startLineCheckpoint = resolved
    return resolved
end

local function updateStartLineBlip(startCheckpoint)
    if type(startCheckpoint) ~= 'table' then
        clearStartLineBlip()
        return
    end

    local x = tonumber(startCheckpoint.x) or 0.0
    local y = tonumber(startCheckpoint.y) or 0.0
    local z = tonumber(startCheckpoint.z) or 0.0
    local blip = raceRuntimeState.startLineBlip
    if not blip or not DoesBlipExist(blip) then
        blip = AddBlipForCoord(x, y, z)
        raceRuntimeState.startLineBlip = blip
        SetBlipSprite(blip, 38)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.9)
        SetBlipColour(blip, 11)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Race Start')
        EndTextCommandSetBlipName(blip)
    else
        SetBlipCoords(blip, x, y, z)
    end
end

local function showJoinHintNotifications()
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName('Gather near the blue chevron and start the Countdown from the ~b~Race~s~ menu.')
    EndTextCommandThefeedPostTicker(false, false)

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName('I assure you this jank is ~y~temporary~w~.')
    EndTextCommandThefeedPostTicker(false, false)
end

local function getCheckpointPassArmKey(instanceId, checkpointIndex, lapNumber)
    return ('%s:%s:%s'):format(tonumber(instanceId) or 0, tonumber(checkpointIndex) or 0, tonumber(lapNumber) or 1)
end

local function cloneRuntimeCheckpoint(checkpoint)
    if type(checkpoint) ~= 'table' then
        return nil
    end

    return {
        index = tonumber(checkpoint.index),
        x = tonumber(checkpoint.x) or 0.0,
        y = tonumber(checkpoint.y) or 0.0,
        z = tonumber(checkpoint.z) or 0.0,
        radius = tonumber(checkpoint.radius) or 8.0,
    }
end

local function resolveLastPassedCheckpointTarget(instance, entrantProgress)
    if type(instance) ~= 'table' then
        return nil, nil
    end

    local checkpoints = type(instance.checkpoints) == 'table' and instance.checkpoints or {}
    local totalCheckpoints = #checkpoints
    if totalCheckpoints <= 0 then
        return nil, nil
    end

    local instanceId = tonumber(instance.id)
    local cached = raceRuntimeState.lastPassedCheckpoint
    if type(cached) == 'table' and tonumber(cached.instanceId) == instanceId and type(cached.checkpoint) == 'table' then
        return cloneRuntimeCheckpoint(cached.checkpoint), cloneRuntimeCheckpoint(cached.nextCheckpoint)
    end

    local currentCheckpoint = math.floor(tonumber((entrantProgress or {}).currentCheckpoint) or 1)
    if currentCheckpoint < 1 then
        currentCheckpoint = 1
    end
    if currentCheckpoint > totalCheckpoints then
        currentCheckpoint = 1
    end

    local lastCheckpointIndex = currentCheckpoint - 1
    if lastCheckpointIndex < 1 then
        lastCheckpointIndex = totalCheckpoints
    end

    local lastVariantEntry = getCheckpointVariantEntry(instance, lastCheckpointIndex)
    local currentVariantEntry = getCheckpointVariantEntry(instance, currentCheckpoint)
    local lastCheckpoint = (lastVariantEntry and lastVariantEntry.primary) or checkpoints[lastCheckpointIndex]
    local nextCheckpoint = (currentVariantEntry and currentVariantEntry.primary) or checkpoints[currentCheckpoint]
    if type(lastCheckpoint) ~= 'table' then
        return nil, nil
    end

    return cloneRuntimeCheckpoint(lastCheckpoint), cloneRuntimeCheckpoint(nextCheckpoint)
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

local function resetLocalPlayerToLastCheckpoint()
    local joinedInstance = getJoinedRaceInstance()
    if type(joinedInstance) ~= 'table' then
        RacingSystemUtil.NotifyPlayer('Join a race first.', true)
        return
    end

    local entrant = getLocalEntrant(joinedInstance)
    local entrantProgress = getEffectiveEntrantProgress(joinedInstance, entrant)
    local lastCheckpoint, nextCheckpoint = resolveLastPassedCheckpointTarget(joinedInstance, entrantProgress)
    if type(lastCheckpoint) ~= 'table' then
        RacingSystemUtil.NotifyPlayer('No checkpoint available for reset yet.', true)
        return
    end

    TriggerEvent('racingsystem:smartCheckpointTeleport', {
        checkpoint = lastCheckpoint,
        nextCheckpoint = nextCheckpoint,
    })
    RacingSystemUtil.NotifyPlayer('Reset to last checkpoint.', false)
end

local function predictCheckpointPass(instance, entrantProgress, totalCheckpoints, targetIndex)
    local instanceId = tonumber(instance and instance.id)
    if not instanceId then
        return
    end

    local currentLap = math.max(1, tonumber(entrantProgress and entrantProgress.currentLap) or 1)
    local totalLaps = math.max(1, tonumber(instance and instance.laps) or 1)
    local lapTriggerCheckpoint = totalCheckpoints
    local raceStartCheckpoint = 1

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

local function getViewerPermissions()
    local viewer = type(latestSnapshot.viewer) == 'table' and latestSnapshot.viewer or {}
    return {
        isAdmin = viewer.isAdmin == true,
        canDeleteRaceDefinitions = viewer.canDeleteRaceDefinitions == true,
        canKillOwnedInstances = viewer.canKillOwnedInstances == true,
    }
end

local function getLocalServerId()
    local playerId = PlayerId()
    if not playerId or playerId == -1 then
        return nil
    end

    local serverId = GetPlayerServerId(playerId)
    if not serverId or serverId <= 0 then
        return nil
    end

    return serverId
end

local function canViewerKillInstance(instance)
    if type(instance) ~= 'table' then
        return false, 'No race instance is selected.'
    end

    local viewer = getViewerPermissions()
    if viewer.isAdmin then
        return true, nil
    end

    local localServerId = getLocalServerId()
    local ownerSource = tonumber(instance.owner)
    if viewer.canKillOwnedInstances and localServerId and ownerSource and localServerId == ownerSource then
        return true, nil
    end

    if viewer.canKillOwnedInstances then
        return false, 'Only the race owner or an admin can kill this instance.'
    end

    return false, 'Admin permission is required to kill race instances.'
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

local function getRaceMenuMode(joinedInstance)
    if editorState.active then
        return 'editing'
    end

    if joinedInstance then
        return 'in_race'
    end

    return 'neutral'
end

local function rebuildRaceMainMenu(menuMode)
    if not raceMainMenu then
        return
    end

    raceMainMenu:Clear()

    if menuMode == 'editing' then
        raceMainMenu:AddItem(raceEditorMenuItem)
        raceMainMenu:AddItem(raceMyRaceMenuItem)
        raceMainMenu:AddItem(raceBrowseMenuItem)
        raceMainMenu:AddItem(raceManageMenuItem)
    elseif menuMode == 'in_race' then
        raceMainMenu:AddItem(raceMyRaceMenuItem)
        raceMainMenu:AddItem(raceBrowseMenuItem)
        raceMainMenu:AddItem(raceManageMenuItem)
    else
        raceMainMenu:AddItem(raceMyRaceMenuItem)
        raceMainMenu:AddItem(raceBrowseMenuItem)
        raceMainMenu:AddItem(raceManageMenuItem)
        raceMainMenu:AddItem(raceEditorMenuItem)
    end

    raceMainMenu:AddItem(raceImportGTAOItem)
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

local function extractGTAOUGCIdFromInput(value)
    local raw = RacingSystem.Trim(value)
    if raw == '' then
        return nil
    end

    local cleaned = raw:gsub('%?.*$', '')
    cleaned = cleaned:gsub('#.*$', '')
    cleaned = cleaned:gsub('/+$', '')

    local tail = cleaned:match('([^/]+)$') or cleaned
    if tail:match('^[%w_-]+$') then
        return tail
    end

    return nil
end

local function closeGTAORaceUrlPrompt(forceReset)
    if not forceReset and not gtaoRaceUrlPromptOpen then
        return
    end

    gtaoRaceUrlPromptOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'racingsystem:toggleGTAORacePrompt',
        open = false,
    })
end

local function openGTAORaceUrlPrompt()
    if gtaoRaceUrlPromptOpen then
        return
    end

    gtaoRaceUrlPromptOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'racingsystem:toggleGTAORacePrompt',
        open = true,
    })
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
        raceMyRaceMenu,
        raceHostRaceMenu,
        raceJoinMenu,
        raceManageMenu,
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
    raceMenuKillItemActions = {}

    for _, instance in ipairs(instances) do
        raceMenuEndOptions[#raceMenuEndOptions + 1] = instance
        local canKill, denyReason = canViewerKillInstance(instance)
        local killItem = UIMenuItem.New(
            getInstanceDisplayName(instance),
            ('State: %s | Entrants: %s'):format(
                getInstanceStateLabel(instance),
                getInstanceEntrantCount(instance)
            )
        )
        if canKill then
            killItem:Description(('Kill this race instance for everyone. State: %s | Entrants: %s'):format(
                getInstanceStateLabel(instance),
                getInstanceEntrantCount(instance)
            ))
            killItem:RightLabel('Kill')
            killItem:Enabled(true)
        else
            killItem:Description(tostring(denyReason or 'You cannot kill this race instance.'))
            killItem:RightLabel('Locked')
            killItem:Enabled(false)
        end
        raceKillMenu:AddItem(killItem)
        raceMenuKillItems[#raceMenuKillItems + 1] = killItem
        raceMenuKillItemActions[#raceMenuKillItemActions + 1] = canKill
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
    local menuMode = getRaceMenuMode(joinedInstance)
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
    local canHostInCurrentMode = menuMode == 'neutral'
    local canHostRace = #raceMenuDefinitionOptions > 0 and canInvokeMoreRaces and canHostInCurrentMode
    raceInvokeActionItem:Enabled(canHostRace)
    if not canHostInCurrentMode then
        if menuMode == 'in_race' then
            raceInvokeActionItem:Description('Leave your current race before hosting another one.')
        else
            raceInvokeActionItem:Description('Exit the race editor before hosting a race.')
        end
    elseif canInvokeMoreRaces then
        raceInvokeActionItem:Description('Host the selected race and auto-join it.')
    else
        raceInvokeActionItem:Description('You already host an active race. Kill it first or enable playerCanInvokeMultipleRaces.')
    end

    if raceInvokePiItem then
        raceInvokePiItem:Enabled(false)
        raceInvokePiItem:Description('Maximum PI limit (preview only, not enforced yet).')
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

    local viewerPermissions = getViewerPermissions()
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
    local canDeleteDefinition = viewerPermissions.canDeleteRaceDefinitions == true
    if not canDeleteDefinition then
        raceEditorDeleteItem:Label('Delete Selected Race')
        raceEditorDeleteItem:Description('Admin permission is required to delete race definitions.')
    end
    raceEditorDeleteItem:Enabled(selectedEditorDefinition ~= nil and canDeleteDefinition)

    local widthIndex = getCheckpointWidthIndex(editorState.defaultCheckpointRadius)
    raceEditorWidthItem:Index(widthIndex - 1)
    raceEditorWidthItem:Description(('Set width for new or grabbed checkpoints. Current: %.1f'):format(tonumber(editorState.defaultCheckpointRadius) or 8.0))
    raceEditorGrabCheckboxItem:Checked(editorState.grabbedCheckpointIndex ~= nil)

    local joinedLabel = joinedInstance and getInstanceDisplayName(joinedInstance) or 'None'
    raceMyRaceStatusItem:RightLabel(joinedLabel)
    if joinedInstance then
        raceMyRaceStatusItem:Description(('You are joined to %s (%s).'):format(
            getInstanceDisplayName(joinedInstance),
            getInstanceStateLabel(joinedInstance)
        ))
    else
        raceMyRaceStatusItem:Description('You are not currently joined to a race.')
    end

    raceHostRaceMenuItem:Enabled(menuMode == 'neutral')
    if menuMode == 'in_race' then
        raceHostRaceMenuItem:Description('You are in a race. Leave it before hosting another race.')
    elseif menuMode == 'editing' then
        raceHostRaceMenuItem:Description('You are editing a race. Exit editor mode before hosting.')
    elseif ownedInstance then
        raceHostRaceMenuItem:Description(('Configure and host a new race. Current hosted race: %s (%s).'):format(
            tostring(ownedInstance.name or 'Unnamed'),
            getInstanceStateLabel(ownedInstance)
        ))
    else
        raceHostRaceMenuItem:Description('Open host setup and create a race from a saved definition.')
    end

    raceQuickStartItem:Enabled(joinedInstance ~= nil)
    raceQuickStartItem:Description(joinedInstance and 'Start countdown for the race you are currently joined to.' or 'Join a race first.')
    raceQuickLeaveItem:Enabled(joinedInstance ~= nil)
    raceQuickLeaveItem:Description(joinedInstance and 'Leave your current race instance.' or 'Join a race first.')
    raceQuickFinishItem:Enabled(joinedInstance ~= nil)
    raceQuickFinishItem:Description(joinedInstance and 'Finish your current race instance.' or 'Join a race first.')
    local resetCheckpointAvailable = false
    if joinedInstance then
        local localEntrant = getLocalEntrant(joinedInstance)
        local entrantProgress = getEffectiveEntrantProgress(joinedInstance, localEntrant)
        local resetCheckpoint = resolveLastPassedCheckpointTarget(joinedInstance, entrantProgress)
        resetCheckpointAvailable = type(resetCheckpoint) == 'table'
    end
    raceQuickResetItem:Enabled(joinedInstance ~= nil and resetCheckpointAvailable)
    raceQuickResetItem:Description((joinedInstance ~= nil and resetCheckpointAvailable) and 'Teleport back to your last passed checkpoint.' or 'Pass at least one checkpoint to enable reset.')

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
    raceBrowseStatusItem:RightLabel(tostring(#raceMenuJoinOptions))
    raceBrowseStatusItem:Description('Browse active races and join one.')
    raceBrowseMenuItem:RightLabel(tostring(#raceMenuJoinOptions))
    raceBrowseMenuItem:Description('Open active race instances.')

    local localServerId = getLocalServerId()
    local manageableCount = 0
    for _, instance in ipairs(instances) do
        local canKill = canViewerKillInstance(instance)
        if canKill then
            manageableCount = manageableCount + 1
        end
    end
    raceKillMenuItem:RightLabel(("%s/%s"):format(tostring(manageableCount), tostring(#instances)))
    raceKillMenuItem:Description('Open active instances. You can only kill races you own (or any race if admin).')
    raceManageMenuItem:RightLabel(tostring(#instances))
    if viewerPermissions.isAdmin then
        raceManageMenuItem:Description('Admin access: manage active race instances.')
    else
        raceManageMenuItem:Description('Manage menu shows what you can or cannot kill.')
    end

    raceMyRaceMenuItem:RightLabel(joinedInstance and getInstanceStateLabel(joinedInstance) or '--')
    raceMyRaceMenuItem:Description('Host a race and control your current race actions.')
    raceMyRaceMenuItem:Enabled(true)

    raceImportGTAOItem:Enabled(true)
    raceImportGTAOItem:RightLabel('URL')
    raceImportGTAOItem:Description('Paste a GTAO race URL to import it via loader and auto-host it as a 1-lap online race.')

    local editorAllowed = menuMode ~= 'in_race'
    raceEditorMenuItem:Enabled(editorAllowed)
    if menuMode == 'in_race' then
        raceEditorMenuItem:Description('Leave your current race to use the race editor.')
    elseif menuMode == 'editing' then
        raceEditorMenuItem:Description('Continue editing checkpoints and race layout.')
    else
        raceEditorMenuItem:Description('Create and edit race checkpoint layouts.')
    end

    rebuildRaceKillMenu(instances)

    rebuildRaceMainMenu(menuMode)
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
    raceMyRaceMenu = createRaceMenu('My Race', 'Host a race and control your current race actions.')
    raceHostRaceMenu = createRaceMenu('Host Race', 'Choose a saved race and host it.')
    raceJoinMenu = createRaceMenu('Browse Races', 'Browse currently active race instances.')
    raceManageMenu = createRaceMenu('Manage', 'Instance management and moderation actions.')
    raceKillMenu = createRaceMenu('Kill Instance', 'Kill one of the currently active race instances.')
    raceEditorMenu = createRaceMenu('Race Editor', 'Create and edit race checkpoint layouts.')

    raceRefreshItem = UIMenuItem.New('Refresh')
    raceMyRaceMenuItem = UIMenuItem.New('My Race')
    raceBrowseMenuItem = UIMenuItem.New('Browse Races')
    raceManageMenuItem = UIMenuItem.New('Manage')
    raceKillMenuItem = UIMenuItem.New('Kill Instance')
    raceEditorMenuItem = UIMenuItem.New('Race Editor')
    raceImportGTAOItem = UIMenuItem.New('Check GTAO Race URL')
    raceMyRaceStatusItem = UIMenuItem.New('Current Race')
    raceBrowseStatusItem = UIMenuItem.New('Active Races')
    raceHostRaceMenuItem = UIMenuItem.New('Host Race')
    raceQuickStartItem = UIMenuItem.New('Start Countdown')
    raceQuickLeaveItem = UIMenuItem.New('Leave Race')
    raceQuickFinishItem = UIMenuItem.New('Finish Race')
    raceQuickResetItem = UIMenuItem.New('Reset to Last Checkpoint')
    raceInvokeDefinitionItem = UIMenuListItem.New('Race', { 'Loading...' }, 1)
    raceInvokeLapItem = UIMenuListItem.New('Laps', raceMenuLapOptions, 1)
    raceInvokePiItem = UIMenuListItem.New('Maximum PI', raceMenuPiOptions, 1)
    raceInvokeActionItem = UIMenuItem.New('Host Selected Race')
    raceJoinAvailableListItem = UIMenuListItem.New('Races', { 'Loading...' }, 1)
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

    raceMyRaceMenu:AddItem(raceMyRaceStatusItem)
    raceMyRaceMenu:AddItem(raceHostRaceMenuItem)
    raceMyRaceMenu:AddItem(raceQuickStartItem)
    raceMyRaceMenu:AddItem(raceQuickLeaveItem)
    raceMyRaceMenu:AddItem(raceQuickFinishItem)
    raceMyRaceMenu:AddItem(raceQuickResetItem)

    raceHostRaceMenu:AddItem(raceInvokeDefinitionItem)
    raceHostRaceMenu:AddItem(raceInvokeLapItem)
    raceHostRaceMenu:AddItem(raceInvokePiItem)
    raceHostRaceMenu:AddItem(raceInvokeActionItem)

    raceJoinMenu:AddItem(raceBrowseStatusItem)
    raceJoinMenu:AddItem(raceJoinAvailableListItem)
    raceJoinMenu:AddItem(raceJoinActionItem)
    raceJoinMenu:AddItem(raceJoinDetailItemOne)
    raceJoinMenu:AddItem(raceJoinDetailItemTwo)
    raceJoinMenu:AddItem(raceJoinDetailItemThree)

    raceManageMenu:AddItem(raceKillMenuItem)

    raceEditorMenu:AddItem(raceEditorSelectedItem)
    raceEditorMenu:AddItem(raceEditorOpenItem)
    raceEditorMenu:AddItem(raceEditorWidthItem)
    raceEditorMenu:AddItem(raceEditorAddCheckpointItem)
    raceEditorMenu:AddItem(raceEditorGrabCheckboxItem)
    raceEditorMenu:AddItem(raceEditorSaveItem)
    raceEditorMenu:AddItem(raceEditorDeleteItem)

    raceMainMenu:BindMenuToItem(raceMyRaceMenu, raceMyRaceMenuItem)
    raceMainMenu:BindMenuToItem(raceJoinMenu, raceBrowseMenuItem)
    raceMainMenu:BindMenuToItem(raceManageMenu, raceManageMenuItem)
    raceMainMenu:BindMenuToItem(raceEditorMenu, raceEditorMenuItem)
    raceMyRaceMenu:BindMenuToItem(raceHostRaceMenu, raceHostRaceMenuItem)
    raceManageMenu:BindMenuToItem(raceKillMenu, raceKillMenuItem)

    raceMyRaceMenuItem.Activated = function(menu)
        menu:SwitchTo(raceMyRaceMenu, 1, true)
    end
    raceBrowseMenuItem.Activated = function(menu)
        menu:SwitchTo(raceJoinMenu, 1, true)
    end
    raceManageMenuItem.Activated = function(menu)
        menu:SwitchTo(raceManageMenu, 1, true)
    end
    raceEditorMenuItem.Activated = function(menu)
        menu:SwitchTo(raceEditorMenu, 1, true)
    end
    raceHostRaceMenuItem.Activated = function(menu)
        menu:SwitchTo(raceHostRaceMenu, 1, true)
    end
    raceKillMenuItem.Activated = function(menu)
        menu:SwitchTo(raceKillMenu, 1, true)
    end

    raceMainMenu.OnMenuClose = function()
        setRaceMenuOpenState(isRaceMenuVisible())
    end

    raceMyRaceMenu.OnMenuClose = function()
        setRaceMenuOpenState(isRaceMenuVisible())
    end

    raceHostRaceMenu.OnMenuClose = function()
        setRaceMenuOpenState(isRaceMenuVisible())
    end

    raceJoinMenu.OnMenuClose = function()
        setRaceMenuOpenState(isRaceMenuVisible())
    end

    raceManageMenu.OnMenuClose = function()
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
        elseif item == raceImportGTAOItem then
            openGTAORaceUrlPrompt()
        end
    end

    raceMyRaceMenu.OnItemSelect = function(_, item, index)
        if item == raceQuickLeaveItem then
            TriggerServerEvent('racingsystem:leaveRace')
        elseif item == raceQuickFinishItem then
            TriggerServerEvent('racingsystem:finishRace')
        elseif item == raceQuickStartItem then
            TriggerServerEvent('racingsystem:startRace')
        elseif item == raceQuickResetItem then
            resetLocalPlayerToLastCheckpoint()
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

    raceHostRaceMenu.OnItemSelect = function(_, item, index)
        if item ~= raceInvokeActionItem then
            return
        end

        local definition = getSelectedInvokeDefinition()
        if not definition then
            return
        end

        TriggerServerEvent('racingsystem:invokeRace', definition.name, getSelectedInvokeLapCount())
        raceHostRaceMenu:GoBack()
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
            return
        end

        TriggerServerEvent('racingsystem:joinRace', instance.name)
    end

    raceKillMenu.OnItemSelect = function(_, item, index)
        local instance = raceMenuEndOptions[index]
        local canKill = raceMenuKillItemActions[index] == true
        if instance and canKill then
            TriggerServerEvent('racingsystem:killRace', instance.name)
        elseif instance and not canKill then
            local _, denyReason = canViewerKillInstance(instance)
        end
    end

    raceEditorMenu.OnItemSelect = function(_, item, index)
        if item == raceEditorOpenItem then
            local selectedDefinition = raceMenuEditorOptions[raceEditorSelectedItem:Index()]
            local raceName = editorState.selectedName ~= '' and editorState.selectedName or (selectedDefinition and selectedDefinition.name or '')
            local trimmedRaceName = RacingSystem.Trim(raceName)
            if trimmedRaceName == '' then
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
                return
            end

            editorState.selectedName = trimmedRaceName
            raceMenuDeleteConfirmName = nil
            saveEditorRace(trimmedRaceName)
        elseif item == raceEditorDeleteItem then
            local viewerPermissions = getViewerPermissions()
            if viewerPermissions.canDeleteRaceDefinitions ~= true then
                return
            end

            local selectedDefinition = raceMenuEditorOptions[raceEditorSelectedItem:Index()]
            if not selectedDefinition then
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
        RacingSystemUtil.ShowRaceEventVisual('~g~FINISHED', ('~w~%s'):format(positionText), 2200)
    else
        local lapNumber = math.max(1, math.floor(tonumber(payload.lapNumber) or 1))
        RacingSystemUtil.ShowRaceEventVisual(('~b~LAP %d COMPLETED'):format(lapNumber), '', 1400)
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

end)

RegisterNetEvent('racingsystem:stableLapTime', function(payload)
    if type(payload) ~= 'table' then
        return
    end

end)

RegisterNetEvent('racingsystem:instanceAssets', function(payload)
    if type(payload) ~= 'table' or tonumber(payload.instanceId) == nil then
        return
    end

    instanceAssetCache[tonumber(payload.instanceId)] = payload
end)

local function waitForFadeState(targetFadedOut, timeoutMs, pollIntervalMs)
    local maxWaitMs = math.max(0, math.floor(tonumber(timeoutMs) or 2500))
    local pollMs = math.max(1, math.floor(tonumber(pollIntervalMs) or 75))
    local deadline = GetGameTimer() + maxWaitMs
    while GetGameTimer() <= deadline do
        local ready = targetFadedOut and IsScreenFadedOut() or IsScreenFadedIn()
        if ready then
            return true
        end
        Wait(pollMs)
    end

    return false
end

local function tryResolveTeleportGroundZ(destinationX, destinationY, destinationZ, timeoutMs, pollIntervalMs, probeOffsets)
    local maxWaitMs = math.max(0, math.floor(tonumber(timeoutMs) or 6000))
    local pollMs = math.max(1, math.floor(tonumber(pollIntervalMs) or 75))
    local offsets = type(probeOffsets) == 'table' and probeOffsets or { 160.0, 100.0, 60.0, 30.0, 10.0 }
    local streamDeadline = GetGameTimer() + maxWaitMs
    while GetGameTimer() <= streamDeadline do
        SetFocusPosAndVel(destinationX, destinationY, destinationZ, 0.0, 0.0, 0.0)
        RequestCollisionAtCoord(destinationX, destinationY, destinationZ)

        for _, probeOffset in ipairs(offsets) do
            local probeZ = destinationZ + (tonumber(probeOffset) or 0.0)
            local foundGround, groundZ = GetGroundZFor_3dCoord(destinationX, destinationY, probeZ, false)
            if foundGround then
                return true, tonumber(groundZ) or destinationZ
            end
        end

        Wait(pollMs)
    end

    return false, destinationZ
end

local function runSmartJoinTeleport(payload)
    if type(payload) ~= 'table' then
        return
    end

    if joinTeleportInProgress then
        return
    end
    joinTeleportInProgress = true

    local shouldNotifyFallback = false
    local didFadeOut = false
    local destinationX = tonumber(payload.x) or 0.0
    local destinationY = tonumber(payload.y) or 0.0
    local destinationZ = tonumber(payload.z) or 0.0
    local heading = tonumber(payload.heading) or 0.0
    local fadeOutMs = 650
    local fadeInMs = 650
    local fadeTimeoutMs = 2500
    local streamTimeoutMs = 6000
    local pollIntervalMs = 75
    local groundProbeOffsets = { 160.0, 100.0, 60.0, 30.0, 10.0 }

    local ok, err = pcall(function()
        local ped = PlayerPedId()
        if not DoesEntityExist(ped) then
            return
        end

        local vehicle = GetVehiclePedIsIn(ped, false)
        local isDriverVehicle = vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped

        -- Stage C: fade out and wait.
        if not IsScreenFadedOut() then
            DoScreenFadeOut(fadeOutMs)
            waitForFadeState(true, fadeTimeoutMs, pollIntervalMs)
        end
        didFadeOut = true

        -- Stage D: focus + stream + ground resolve.
        local foundGround, resolvedGroundZ = tryResolveTeleportGroundZ(
            destinationX,
            destinationY,
            destinationZ,
            streamTimeoutMs,
            pollIntervalMs,
            groundProbeOffsets
        )
        local targetZ = destinationZ
        if foundGround then
            targetZ = resolvedGroundZ + 1.0
            Wait(1000)
        else
            shouldNotifyFallback = true
        end

        -- Stage E: actual teleport.
        if isDriverVehicle and DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == ped then
            SetEntityCoordsNoOffset(vehicle, destinationX, destinationY, targetZ, false, false, false)
            SetEntityHeading(vehicle, heading)
            SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)
            SetVehicleForwardSpeed(vehicle, 0.0)
            SetVehicleOnGroundProperly(vehicle)

            -- Ensure player vehicle control is restored after halt+teleport sequencing.
            ClearPedTasks(ped)
            SetVehicleHandbrake(vehicle, false)
            SetVehicleUndriveable(vehicle, false)
            SetVehicleEngineOn(vehicle, true, true, false)
            SetVehicleBrakeLights(vehicle, false)
            SetPlayerControl(PlayerId(), true, 0)
        else
            SetEntityCoordsNoOffset(ped, destinationX, destinationY, targetZ, false, false, false)
            SetEntityHeading(ped, heading)
            SetEntityVelocity(ped, 0.0, 0.0, 0.0)
            ClearPedTasks(ped)
            SetPlayerControl(PlayerId(), true, 0)
        end
    end)

    -- Stage F/G: always cleanup focus and fade-in, plus fallback warning.
    ClearFocus()

    if didFadeOut then
        if not IsScreenFadedIn() then
            DoScreenFadeIn(fadeInMs)
            waitForFadeState(false, fadeTimeoutMs, pollIntervalMs)
        end
    end

    if shouldNotifyFallback then
    end

    if not ok then
    end

    joinTeleportInProgress = false
end

local function buildCheckpointTeleportPayload(checkpoint, nextCheckpoint)
    if type(checkpoint) ~= 'table' then
        return nil
    end

    local payload = {
        x = tonumber(checkpoint.x) or 0.0,
        y = tonumber(checkpoint.y) or 0.0,
        z = (tonumber(checkpoint.z) or 0.0) + 2.0,
        heading = getHeadingToNextCheckpoint(checkpoint, nextCheckpoint) + 270.0,
    }

    return payload
end

local function getDefaultMockFakeOrder()
    return { 'vega', 'niko', 'luna' }
end

local function buildMockLeaderboardRows()
    local localPlayerName = GetPlayerName(PlayerId()) or 'You'
    local nameByKey = {
        local_player = localPlayerName,
        vega = 'Vega Drift',
        niko = 'Niko Apex',
        luna = 'Luna Circuit',
    }

    local localPosition = math.max(1, math.min(4, math.floor(tonumber(mockLeaderboardState.localPosition) or 2)))
    local fakeOrder = type(mockLeaderboardState.fakeOrder) == 'table' and mockLeaderboardState.fakeOrder or getDefaultMockFakeOrder()
    if #fakeOrder < 3 then
        fakeOrder = getDefaultMockFakeOrder()
        mockLeaderboardState.fakeOrder = fakeOrder
    end

    local rows = {}
    local fakeCursor = 1
    for position = 1, 4 do
        local entryKey
        if position == localPosition then
            entryKey = 'local_player'
        else
            entryKey = fakeOrder[fakeCursor]
            fakeCursor = fakeCursor + 1
        end

        local displayName = tostring(nameByKey[entryKey] or ('Racer %s'):format(tostring(position)))
        rows[#rows + 1] = {
            key = entryKey,
            text = ('%dº %s'):format(position, displayName),
        }
    end

    return rows
end

local function advanceMockLeaderboardFakePositions()
    local fakeOrder = type(mockLeaderboardState.fakeOrder) == 'table' and mockLeaderboardState.fakeOrder or getDefaultMockFakeOrder()
    if #fakeOrder < 3 then
        fakeOrder = getDefaultMockFakeOrder()
    end

    local swapPairs = {
        { 1, 2 },
        { 2, 3 },
        { 1, 3 },
    }
    local step = math.floor(tonumber(mockLeaderboardState.swapStep) or 1)
    if step < 1 or step > #swapPairs then
        step = 1
    end

    local pair = swapPairs[step]
    local a = pair[1]
    local b = pair[2]
    fakeOrder[a], fakeOrder[b] = fakeOrder[b], fakeOrder[a]

    mockLeaderboardState.fakeOrder = fakeOrder
    mockLeaderboardState.swapStep = (step % #swapPairs) + 1
end

local function resetMockLeaderboardState()
    mockLeaderboardState.localPosition = 2
    mockLeaderboardState.fakeOrder = getDefaultMockFakeOrder()
    mockLeaderboardState.swapStep = 1
end

local function runSmartCheckpointTeleport(checkpoint, nextCheckpoint)
    local payload = buildCheckpointTeleportPayload(checkpoint, nextCheckpoint)
    if type(payload) ~= 'table' then
        return
    end

    runSmartJoinTeleport(payload)
end

RegisterNetEvent('racingsystem:teleportToCheckpoint', function(payload)
    runSmartJoinTeleport(payload)
end)

RegisterNetEvent('racingsystem:smartCheckpointTeleport', function(payload)
    local checkpoint = type(payload) == 'table' and payload.checkpoint or nil
    local nextCheckpoint = type(payload) == 'table' and payload.nextCheckpoint or nil
    runSmartCheckpointTeleport(checkpoint, nextCheckpoint)
end)

RegisterNUICallback('racingsystem:gtAoRaceUrlSubmit', function(data, cb)
    closeGTAORaceUrlPrompt()
    cb({})

    local typedValue = type(data) == 'table' and data.value or ''
    local ugcId = extractGTAOUGCIdFromInput(typedValue)
    if not ugcId then
        local failureMessage = 'Could not parse a GTAO race ID from that URL.'
        RacingSystemUtil.NotifyPlayer(failureMessage, true)
        RacingSystemUtil.ShowWarningSubtitle(failureMessage, 2500, '~o~')
        return
    end

    TriggerServerEvent('racingsystem:validateGTAORaceUGCId', ugcId)
end)

RegisterNUICallback('racingsystem:gtAoRaceUrlCancel', function(_, cb)
    closeGTAORaceUrlPrompt()
    cb({})
end)

RegisterNetEvent('racingsystem:gtAoRaceValidationResult', function(payload)
    if type(payload) ~= 'table' then
        return
    end

    if payload.ok ~= true then
        local message = type(payload.error) == 'string' and payload.error or 'Could not validate GTAO race URL.'
        RacingSystemUtil.NotifyPlayer(message, true)
        RacingSystemUtil.ShowWarningSubtitle(message, 2500, '~o~')
        return
    end

    local autoHosted = payload.autoHosted == true
    if autoHosted then
        return
    end

    local raceName = tostring(payload.raceName or payload.ugcId or 'unknown')
    local checkpointCount = tostring(math.max(0, math.floor(tonumber(payload.checkpointCount) or 0)))
    local hostError = tostring(payload.autoHostError or 'Could not auto-host race instance.')
    local errorMessage = ('Imported "%s" (%s checkpoints), but auto-host failed: %s'):format(
        raceName,
        checkpointCount,
        hostError
    )
    RacingSystemUtil.NotifyPlayer(errorMessage, true)
    RacingSystemUtil.ShowWarningSubtitle(errorMessage, 3500, '~o~')
end)

RegisterNetEvent('racingsystem:editorRaceLoaded', function(payload)
    if type(payload) ~= 'table' or payload.ok ~= true then
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
            raceRuntimeState.lastPassedCheckpoint = nil
            raceRuntimeState.startLineCheckpoint = nil
            raceRuntimeState.joinHintInstanceId = nil
            raceRuntimeState.accelerationPenaltyUntil = 0
            clearPowerPenaltyVehicleOverride()
            clearFutureCheckpointBlips()
            clearStartLineBlip()
            resetMockLeaderboardState()
            resetLocalRaceTiming()
            RacingSystemUtil.ClearCountdownVisual()
            RacingSystemUtil.ClearRaceLeaderboardVisual()
            if activeInstanceAssets.instanceId then
                unloadActiveInstanceAssets()
            end
            Wait(1000)
        else
            local joinedInstanceId = tonumber(joinedInstance.id)
            if joinedInstanceId and raceRuntimeState.joinHintInstanceId ~= joinedInstanceId then
                raceRuntimeState.joinHintInstanceId = joinedInstanceId
                showJoinHintNotifications()

                local joinCheckpoints = type(joinedInstance.checkpoints) == 'table' and joinedInstance.checkpoints or {}
                local joinCheckpointCount = #joinCheckpoints
                if joinCheckpointCount > 0 then
                    local joinEntrant = getLocalEntrant(joinedInstance)
                    local joinTargetIndex = tonumber(joinEntrant and joinEntrant.currentCheckpoint) or 1
                    updateFutureCheckpointBlips(joinedInstance, joinCheckpointCount, joinTargetIndex)
                    raceRuntimeState.futureBlipCheckpointIndex = joinTargetIndex
                    raceRuntimeState.futureBlipInstanceId = joinedInstanceId
                else
                    clearFutureCheckpointBlips()
                end
            end

            RacingSystemUtil.UpdateRaceLeaderboardVisual(nil, buildMockLeaderboardRows())
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
            local startLineCheckpoint = resolveStartLineCheckpoint(checkpoints, totalCheckpoints, nil)
            updateStartLineBlip(startLineCheckpoint)

            clearPendingCheckpointIfAdvanced(entrant)
            targetIndex = tonumber(entrantProgress.currentCheckpoint) or targetIndex
            local routeTargetIndex = tonumber(entrant and entrant.currentCheckpoint) or targetIndex
            if totalCheckpoints > 0 then
                local routeInstanceId = tonumber(joinedInstance.id)
                if raceRuntimeState.futureBlipInstanceId ~= routeInstanceId
                    or raceRuntimeState.futureBlipCheckpointIndex ~= routeTargetIndex then
                    updateFutureCheckpointBlips(joinedInstance, totalCheckpoints, routeTargetIndex)
                    raceRuntimeState.futureBlipCheckpointIndex = routeTargetIndex
                    raceRuntimeState.futureBlipInstanceId = routeInstanceId
                end
            end

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
                    RacingSystemUtil.UpdateCountdownVisual(joinedInstanceId, remainingMs)

                    if pedVehicle ~= 0 and GetPedInVehicleSeat(pedVehicle, -1) == ped then
                        SetVehicleHandbrake(pedVehicle, true)
                    end

                    if countdownEndsAt and remainingMs <= 0 and not raceCountdownReportedZeroByInstanceId[joinedInstanceId] then
                        raceCountdownReportedZeroByInstanceId[joinedInstanceId] = true
                        TriggerServerEvent('racingsystem:countdownReachedZero', joinedInstanceId, GetGameTimer())
                    end
                elseif joinedInstance.state == RacingSystem.States.running then
                    RacingSystemUtil.ClearCountdownVisual()
                    local joinedInstanceId = tonumber(joinedInstance.id)
                    if joinedInstanceId and not raceStartCueShownByInstanceId[joinedInstanceId] then
                        raceStartCueShownByInstanceId[joinedInstanceId] = true
                        RacingSystemUtil.ShowRaceEventVisual('~g~GO!', '~w~Race is live', 1400)
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
                    RacingSystemUtil.ClearCountdownVisual()
                    if pedVehicle ~= 0 and GetPedInVehicleSeat(pedVehicle, -1) == ped then
                        SetVehicleHandbrake(pedVehicle, false)
                    end
                else
                    RacingSystemUtil.ClearCountdownVisual()
                    if pedVehicle ~= 0 and GetPedInVehicleSeat(pedVehicle, -1) == ped then
                        SetVehicleHandbrake(pedVehicle, false)
                    end
                end
            end

            local targetVariantEntry = getCheckpointVariantEntry(joinedInstance, targetIndex)
            local targetCheckpoint = targetVariantEntry and targetVariantEntry.primary or checkpoints[targetIndex]
            local secondaryTargetCheckpoint = targetVariantEntry and targetVariantEntry.secondary or nil
            if not targetCheckpoint or totalCheckpoints == 0 then
                raceRuntimeState.checkpointPassArm = nil
                raceRuntimeState.previousPosition = origin
                clearFutureCheckpointBlips()
                clearStartLineBlip()
                Wait(1000)
            else
                local checkpointCandidates = {}
                local primaryCoords = vector3(targetCheckpoint.x or 0.0, targetCheckpoint.y or 0.0, targetCheckpoint.z or 0.0)
                checkpointCandidates[#checkpointCandidates + 1] = {
                    routeVariant = 'primary',
                    checkpoint = targetCheckpoint,
                    distance = getHorizontalDistance(origin, targetCheckpoint),
                    drawDistance = #(origin - primaryCoords),
                }

                if type(secondaryTargetCheckpoint) == 'table' then
                    local secondaryCoords = vector3(secondaryTargetCheckpoint.x or 0.0, secondaryTargetCheckpoint.y or 0.0, secondaryTargetCheckpoint.z or 0.0)
                    checkpointCandidates[#checkpointCandidates + 1] = {
                        routeVariant = 'secondary',
                        checkpoint = secondaryTargetCheckpoint,
                        distance = getHorizontalDistance(origin, secondaryTargetCheckpoint),
                        drawDistance = #(origin - secondaryCoords),
                    }
                end

                local nearestDrawDistance = nil
                for _, candidate in ipairs(checkpointCandidates) do
                    local candidateDrawDistance = tonumber(candidate.drawDistance) or math.huge
                    if nearestDrawDistance == nil or candidateDrawDistance < nearestDrawDistance then
                        nearestDrawDistance = candidateDrawDistance
                    end
                end

                if (nearestDrawDistance or math.huge) <= RacingSystem.Config.checkpointDrawDistanceMeters then
                    local totalLaps = math.max(1, tonumber(joinedInstance.laps) or 1)
                    local lapTriggerCheckpoint = totalCheckpoints
                    local isStart = targetIndex == 1
                    local isFinish = targetIndex == lapTriggerCheckpoint
                    local prevIndex = targetIndex - 1
                    if prevIndex < 1 then
                        prevIndex = totalCheckpoints
                    end
                    local prevPrimaryCheckpoint = getNextCheckpointForVariant(joinedInstance, totalCheckpoints, prevIndex, 'primary')
                        or checkpoints[prevIndex]
                    local nextPrimaryCheckpoint = getNextCheckpointForVariant(joinedInstance, totalCheckpoints, targetIndex, 'primary')
                    local nextSecondaryCheckpoint = getNextCheckpointForVariant(joinedInstance, totalCheckpoints, targetIndex, 'secondary')

                    drawCheckpointTarget(
                        targetCheckpoint,
                        prevPrimaryCheckpoint,
                        nextPrimaryCheckpoint,
                        isStart,
                        isFinish,
                        { r = 255, g = 225, b = 80, a = 180 },
                        { r = 255, g = 235, b = 80, a = 220 },
                        true,
                        90.0
                    )

                    if type(secondaryTargetCheckpoint) == 'table' then
                        drawCheckpointTarget(
                            secondaryTargetCheckpoint,
                            prevPrimaryCheckpoint,
                            nextSecondaryCheckpoint,
                            isStart,
                            isFinish,
                            { r = 255, g = 145, b = 35, a = 170 },
                            { r = 255, g = 170, b = 75, a = 220 },
                            true,
                            0.0
                        )
                    end

                    -- Preview two additional upcoming checkpoints (for a total of 3 visible).
                    local previewSeenIndex = { [targetIndex] = true }
                    local previewIndex = targetIndex
                    local previewMarkerColors = {
                        { r = 90, g = 170, b = 255, a = 120 },
                        { r = 70, g = 135, b = 235, a = 95 },
                    }
                    local previewChevronColors = {
                        { r = 170, g = 170, b = 170, a = 145 },
                        { r = 140, g = 140, b = 140, a = 120 },
                    }

                    for previewStep = 1, 2 do
                        previewIndex = previewIndex + 1
                        if previewIndex > totalCheckpoints then
                            previewIndex = 1
                        end

                        if not previewSeenIndex[previewIndex] then
                            previewSeenIndex[previewIndex] = true
                            local previewVariantEntry = getCheckpointVariantEntry(joinedInstance, previewIndex)
                            local previewCheckpoint = previewVariantEntry and previewVariantEntry.primary or checkpoints[previewIndex]

                            if type(previewCheckpoint) == 'table' then
                                local previewCoords = vector3(
                                    tonumber(previewCheckpoint.x) or 0.0,
                                    tonumber(previewCheckpoint.y) or 0.0,
                                    tonumber(previewCheckpoint.z) or 0.0
                                )
                                if #(origin - previewCoords) <= RacingSystem.Config.checkpointDrawDistanceMeters then
                                    local previewPrevIndex = previewIndex - 1
                                    if previewPrevIndex < 1 then
                                        previewPrevIndex = totalCheckpoints
                                    end
                                    local previewPrevPrimaryCheckpoint = getNextCheckpointForVariant(joinedInstance, totalCheckpoints, previewPrevIndex, 'primary')
                                        or checkpoints[previewPrevIndex]
                                    local previewNextPrimaryCheckpoint = getNextCheckpointForVariant(joinedInstance, totalCheckpoints, previewIndex, 'primary')
                                    drawCheckpointTarget(
                                        previewCheckpoint,
                                        previewPrevPrimaryCheckpoint,
                                        previewNextPrimaryCheckpoint,
                                        false,
                                        false,
                                        previewMarkerColors[previewStep] or previewMarkerColors[#previewMarkerColors],
                                        previewChevronColors[previewStep] or previewChevronColors[#previewChevronColors],
                                        true,
                                        0.0
                                    )
                                end
                            end
                        end
                    end

                end

                if joinedInstance.state == RacingSystem.States.idle then
                    local startCheckpoint = resolveStartLineCheckpoint(checkpoints, totalCheckpoints, targetCheckpoint)
                    if startCheckpoint then
                        drawIdleStartChevron(startCheckpoint)
                    end
                end

                if joinedInstance.state == RacingSystem.States.running and entrant and tonumber(entrantProgress.finishedAt) == nil then
                    local pending = raceRuntimeState.pendingCheckpointPass
                    local isPendingSameCheckpoint = pending
                        and tonumber(pending.instanceId) == tonumber(joinedInstance.id)
                        and tonumber(pending.checkpointIndex) == tonumber(targetIndex)
                        and GetGameTimer() <= (pending.expiresAt or 0)
                    local withinPassDetectionRange = false
                    for _, candidate in ipairs(checkpointCandidates) do
                        if (tonumber(candidate.distance) or math.huge) <= CHECKPOINT_PASS_ARM_DISTANCE then
                            withinPassDetectionRange = true
                            break
                        end
                    end

                    local checkpointPassed = false
                    local passedOutsideRadius = false
                    local outsideLateralDistance = nil
                    local passedTargetCheckpoint = targetCheckpoint
                    local passedRouteVariant = 'primary'
                    local currentLap = math.max(1, tonumber(entrantProgress.currentLap) or 1)
                    local currentArmKey = getCheckpointPassArmKey(joinedInstance.id, targetIndex, currentLap)
                    local checkpointPassArm = raceRuntimeState.checkpointPassArm

                    if withinPassDetectionRange and not isPendingSameCheckpoint then
                        if checkpointPassArm == nil or checkpointPassArm.key ~= currentArmKey then
                            checkpointPassArm = {
                                key = currentArmKey,
                                minDistanceByVariant = {},
                            }
                            for _, candidate in ipairs(checkpointCandidates) do
                                checkpointPassArm.minDistanceByVariant[candidate.routeVariant] = tonumber(candidate.distance) or math.huge
                            end
                            raceRuntimeState.checkpointPassArm = checkpointPassArm
                        else
                            checkpointPassArm.minDistanceByVariant = type(checkpointPassArm.minDistanceByVariant) == 'table' and checkpointPassArm.minDistanceByVariant or {}
                            local bestPassDistance = nil
                            local bestPassCandidate = nil

                            for _, candidate in ipairs(checkpointCandidates) do
                                local routeVariant = tostring(candidate.routeVariant or 'primary')
                                local distance = tonumber(candidate.distance) or math.huge
                                local previousMinDistance = tonumber(checkpointPassArm.minDistanceByVariant[routeVariant]) or distance
                                local newMinDistance = math.min(previousMinDistance, distance)
                                checkpointPassArm.minDistanceByVariant[routeVariant] = newMinDistance

                                if distance >= (newMinDistance + CHECKPOINT_PASS_RELEASE_DELTA) then
                                    if bestPassDistance == nil or newMinDistance < bestPassDistance then
                                        bestPassDistance = newMinDistance
                                        bestPassCandidate = candidate
                                    end
                                end
                            end

                            if bestPassCandidate then
                                checkpointPassed = true
                                outsideLateralDistance = tonumber(bestPassDistance) or 0.0
                                passedTargetCheckpoint = bestPassCandidate.checkpoint or targetCheckpoint
                                passedRouteVariant = tostring(bestPassCandidate.routeVariant or 'primary')
                                passedOutsideRadius = outsideLateralDistance > (tonumber(passedTargetCheckpoint.radius) or 8.0)
                                raceRuntimeState.checkpointPassArm = nil
                            end
                        end
                    elseif checkpointPassArm and checkpointPassArm.key == currentArmKey then
                        local shouldClearArm = true
                        for _, candidate in ipairs(checkpointCandidates) do
                            if (tonumber(candidate.distance) or math.huge) <= (CHECKPOINT_PASS_ARM_DISTANCE + 5.0) then
                                shouldClearArm = false
                                break
                            end
                        end
                        if shouldClearArm then
                            raceRuntimeState.checkpointPassArm = nil
                        end
                    end

                    if checkpointPassed then
                        local checkpointPassIsValid = true
                        local lowSpeedRecoveryPass = false
                        local offWheelsRecoveryPass = false
                        local outsideOffset = 0.0
                        local throttlePenaltyMs = 0
                        local powerPenaltyMs = 0
                        local applyTeleportPenalty = false
                        local applyThrottlePenalty = false
                        local applyPowerPenalty = false
                        if pedVehicle ~= 0 and DoesEntityExist(pedVehicle) then
                            local speedMph = (tonumber(GetEntitySpeed(pedVehicle)) or 0.0) * METERS_PER_SECOND_TO_MILES_PER_HOUR
                            lowSpeedRecoveryPass = speedMph < CHECKPOINT_RECOVERY_PASS_MAX_MPH
                            if not IsVehicleOnAllWheels(pedVehicle) then
                                local forwardVelocityRatio = getVehicleForwardVelocityRatio(pedVehicle)
                                offWheelsRecoveryPass = forwardVelocityRatio < CHECKPOINT_RECOVERY_FORWARD_VELOCITY_RATIO_MAX
                            end
                        end
                        local isRecoveryPenaltyBypass = lowSpeedRecoveryPass or offWheelsRecoveryPass
                        local passContextPayload = {
                            kind = 'clean_pass',
                            penalty = 'none',
                            routeVariant = passedRouteVariant,
                            outsideOffset = 0.0,
                            assumedCrashPenaltyVoided = false,
                            throttlePenaltyMs = 0,
                            powerPenaltyMs = 0,
                        }

                        if passedOutsideRadius then
                            outsideOffset = math.max(0.0, (tonumber(outsideLateralDistance) or 0.0) - (tonumber(passedTargetCheckpoint.radius) or 8.0))
                            passContextPayload.outsideOffset = outsideOffset
                            if isRecoveryPenaltyBypass then
                                if offWheelsRecoveryPass then
                                    passContextPayload.kind = 'assumed_crash_penalty_voided'
                                    passContextPayload.penalty = 'voided_assumed_crash'
                                    passContextPayload.assumedCrashPenaltyVoided = true
                                else
                                    passContextPayload.kind = 'recovery_penalty_voided'
                                    passContextPayload.penalty = 'voided_low_speed'
                                end
                            else
                                if outsideOffset > 20.0 then
                                    checkpointPassIsValid = false
                                    passContextPayload.kind = 'invalid_outside_too_far'
                                    passContextPayload.penalty = 'invalid_no_pass'
                                elseif outsideOffset > 10.0 then
                                    applyTeleportPenalty = true
                                    passContextPayload.kind = 'penalty_teleport'
                                    passContextPayload.penalty = 'teleport_correction'
                                elseif outsideOffset >= 1.5 then
                                    local throttleMinMeters = 1.5
                                    local throttleMaxMeters = 10.0
                                    local throttleMinMs = 1000.0
                                    local throttleMaxMs = 5000.0
                                    local normalized = math.max(0.0, math.min(1.0, (outsideOffset - throttleMinMeters) / (throttleMaxMeters - throttleMinMeters)))
                                    throttlePenaltyMs = math.floor(throttleMinMs + ((throttleMaxMs - throttleMinMs) * normalized))
                                    applyThrottlePenalty = true
                                    passContextPayload.kind = 'penalty_throttle_cut'
                                    passContextPayload.penalty = 'throttle_cut'
                                    passContextPayload.throttlePenaltyMs = throttlePenaltyMs
                                elseif outsideOffset >= 0.5 then
                                    powerPenaltyMs = 1000
                                    applyPowerPenalty = true
                                    passContextPayload.kind = 'penalty_power_multiplier'
                                    passContextPayload.penalty = 'power_multiplier'
                                    passContextPayload.powerPenaltyMs = powerPenaltyMs
                                else
                                    passContextPayload.kind = 'outside_no_penalty'
                                    passContextPayload.penalty = 'none'
                                end
                            end
                        end

                        if checkpointPassIsValid then
                            advanceMockLeaderboardFakePositions()
                            local lapTimingPayload = nil
                            local totalLaps = math.max(1, tonumber(joinedInstance.laps) or 1)
                            local lapTriggerCheckpoint = totalCheckpoints
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
                            local nextCheckpointForPassedVariant = getNextCheckpointForVariant(joinedInstance, totalCheckpoints, targetIndex, passedRouteVariant)
                            raceRuntimeState.lastPassedCheckpoint = {
                                instanceId = tonumber(joinedInstance.id),
                                checkpointIndex = tonumber(targetIndex) or 1,
                                routeVariant = passedRouteVariant,
                                checkpoint = cloneRuntimeCheckpoint(passedTargetCheckpoint or targetCheckpoint),
                                nextCheckpoint = cloneRuntimeCheckpoint(nextCheckpointForPassedVariant),
                                updatedAt = GetGameTimer(),
                            }

                            predictCheckpointPass(joinedInstance, entrantProgress, totalCheckpoints, targetIndex)
                            TriggerServerEvent('racingsystem:checkpointPassed', joinedInstance.id, targetIndex, lapTimingPayload, passContextPayload)

                            if applyTeleportPenalty then
                                local postPassCheckpointIndex = targetIndex + 1
                                if postPassCheckpointIndex > totalCheckpoints then
                                    postPassCheckpointIndex = 1
                                end
                                if targetIndex == lapTriggerCheckpoint and not (lapTimingPayload and lapTimingPayload.finished == true) then
                                    local raceStartCheckpoint = 1
                                    postPassCheckpointIndex = raceStartCheckpoint
                                end

                                local passedCheckpoint = passedTargetCheckpoint or targetCheckpoint
                                local newCurrentCheckpoint = getNextCheckpointForVariant(joinedInstance, totalCheckpoints, targetIndex, passedRouteVariant) or checkpoints[postPassCheckpointIndex]
                                runSmartCheckpointTeleport(passedCheckpoint, newCurrentCheckpoint)
                            elseif applyThrottlePenalty then
                                raceRuntimeState.accelerationPenaltyUntil = GetGameTimer() + throttlePenaltyMs
                                RacingSystemUtil.ShowWarningSubtitle('Keep within the radius', throttlePenaltyMs, '~r~')
                            elseif applyPowerPenalty then
                                applySoftPowerPenalty(pedVehicle, powerPenaltyMs)
                                RacingSystemUtil.ShowWarningSubtitle('Keep within the radius', powerPenaltyMs, '~y~')
                            end
                        else
                            raceRuntimeState.pendingCheckpointPass = {
                                instanceId = joinedInstance.id,
                                checkpointIndex = targetIndex,
                                expiresAt = GetGameTimer() + 1500,
                            }
                        end
                    end
                end

                raceRuntimeState.previousPosition = origin
                local powerPenaltyUntil = tonumber(raceRuntimeState.powerPenaltyUntil) or 0
                if powerPenaltyUntil > GetGameTimer() then
                    local penaltyVehicle = raceRuntimeState.powerPenaltyVehicle
                    if penaltyVehicle and DoesEntityExist(penaltyVehicle) then
                        SetVehicleEnginePowerMultiplier(penaltyVehicle, CHECKPOINT_SOFT_POWER_PENALTY_MULTIPLIER)
                    end
                elseif raceRuntimeState.powerPenaltyVehicle ~= nil then
                    clearPowerPenaltyVehicleOverride()
                end
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
        RacingSystemUtil.DrawRaceEventVisual()
        RacingSystemUtil.DrawRaceLeaderboardVisual()
        Wait(0)
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    closeGTAORaceUrlPrompt(true)
    clearPowerPenaltyVehicleOverride()
    clearFutureCheckpointBlips()
    clearStartLineBlip()
    RacingSystemUtil.ClearRaceLeaderboardVisual()
    unloadActiveInstanceAssets()
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    closeGTAORaceUrlPrompt(true)
    SetTimeout(250, function()
        closeGTAORaceUrlPrompt(true)
    end)
end)

print('[racingsystem] Client system loaded.')

