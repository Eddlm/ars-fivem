RacingSystem = RacingSystem or {}
RacingSystem.Client = RacingSystem.Client or {}
RacingSystem.Menu = RacingSystem.Menu or {}

RacingSystem.Client.Util = RacingSystem.Client.Util or {}

RacingSystem.Client.Util.NotifyPlayer = function(message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(tostring(message or ''))
    EndTextCommandThefeedPostTicker(false, false)
end

RacingSystem.Client.Util.ShowWarningSubtitle = function(message, durationMs, colorTag)
    BeginTextCommandPrint('STRING')
    local colorPrefix = tostring(colorTag or '~y~')
    AddTextComponentSubstringPlayerName(('%s%s~s~'):format(colorPrefix, tostring(message or '')))
    EndTextCommandPrint(math.max(0, math.floor(tonumber(durationMs) or 1000)), true)
end

RacingSystem.Client.Util.UpdateCountdownVisual = function(instanceId, remainingMs)
    local seconds = math.floor(remainingMs / 1000)
    if seconds >= 0 then
        ScaleformUI.Scaleforms.BigMessageInstance:ShowMpMessageLarge("Race starts in", tostring(seconds), 1000)
    end
end
RacingSystem.Client.Util.ClearCountdownVisual = function()
    ScaleformUI.Scaleforms.BigMessageInstance:Dispose()
end

local raceLeaderboardVisualState = {
    title = 'LEADERBOARD',
    rows = {},
    finalizedByKey = {},
}

local raceEventVisualState = {
    title = '',
    subtitle = '',
    expiresAt = 0,
}

local function drawLeaderboardText(x, y, scale, text, r, g, b, a, centered)
    SetTextFont(0)
    SetTextProportional(1)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, a)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(centered == true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(tostring(text or ''))
    EndTextCommandDisplayText(x, y)
end

RacingSystem.Client.Util.ShowRaceEventVisual = function(title, subtitle, durationMs)
    raceEventVisualState.title = tostring(title or '')
    raceEventVisualState.subtitle = tostring(subtitle or '')
    raceEventVisualState.expiresAt = GetGameTimer() + math.max(0, math.floor(tonumber(durationMs) or 1200))
end

RacingSystem.Client.Util.DrawRaceEventVisual = function()
    local expiresAt = tonumber(raceEventVisualState.expiresAt) or 0
    local now = GetGameTimer()
    if expiresAt <= now then
        raceEventVisualState.title = ''
        raceEventVisualState.subtitle = ''
        return
    end

    local title = raceEventVisualState.title
    local subtitle = raceEventVisualState.subtitle
    if title == '' and subtitle == '' then
        return
    end

    local bodyX = 0.5
    local bodyY = 0.185
    local hasSubtitle = subtitle ~= ''
    local bodyHeight = hasSubtitle and 0.09 or 0.062
    DrawRect(bodyX, bodyY, 0.48, bodyHeight, 10, 14, 24, 150)
    drawLeaderboardText(bodyX, bodyY - (hasSubtitle and 0.024 or 0.012), 0.45, title, 245, 250, 255, 235, true)
    if hasSubtitle then
        drawLeaderboardText(bodyX, bodyY + 0.01, 0.32, subtitle, 210, 225, 255, 220, true)
    end
end

RacingSystem.Client.Util.UpdateRaceLeaderboardVisual = function(title, rows)
    raceLeaderboardVisualState.title = tostring(title or 'LEADERBOARD')
    local previousByKey = {}
    for _, existing in ipairs(type(raceLeaderboardVisualState.rows) == 'table' and raceLeaderboardVisualState.rows or {}) do
        if type(existing) == 'table' then
            previousByKey[tostring(existing.key or '')] = existing
        end
    end

    local finalizedByKey = type(raceLeaderboardVisualState.finalizedByKey) == 'table' and raceLeaderboardVisualState.finalizedByKey or {}
    raceLeaderboardVisualState.finalizedByKey = finalizedByKey
    raceLeaderboardVisualState.rows = {}

    for index, row in ipairs(type(rows) == 'table' and rows or {}) do
        local rowKey = tostring((type(row) == 'table' and row.key) or index)
        local incomingFinalized = type(row) == 'table' and row.finalized == true
        local wasFinalized = finalizedByKey[rowKey] == true
        local shouldFinalize = incomingFinalized or wasFinalized
        local previous = previousByKey[rowKey]

        if shouldFinalize then
            finalizedByKey[rowKey] = true
        end

        local resolvedRank = math.max(1, math.floor(tonumber(type(row) == 'table' and row.rank) or index))
        if shouldFinalize and type(previous) == 'table' and tonumber(previous.rank) then
            resolvedRank = math.max(1, math.floor(tonumber(previous.rank) or resolvedRank))
        end

        local resolvedText = tostring((type(row) == 'table' and row.text) or '')
        if shouldFinalize and type(previous) == 'table' and type(previous.text) == 'string' and previous.text ~= '' then
            resolvedText = previous.text
        end

        raceLeaderboardVisualState.rows[index] = {
            key = rowKey,
            text = resolvedText,
            rank = resolvedRank,
            finalized = shouldFinalize,
        }
    end
end

RacingSystem.Client.Util.DrawRaceLeaderboardVisual = function()
    local rows = type(raceLeaderboardVisualState.rows) == 'table' and raceLeaderboardVisualState.rows or {}
    if #rows <= 0 then
        return
    end

    local bodyLeftX = 0.03
    local bodyY = 0.39
    local rowTextScale = 0.27
    local bodyWidth = 0.22
    local baseX = bodyLeftX + (bodyWidth * 0.5)
    local rowHeight = 0.024
    local bodyHeight = math.max(0.028, math.min(0.30, (#rows * rowHeight) + 0.012))

    DrawRect(baseX, bodyY, bodyWidth, bodyHeight, 12, 16, 26, 140)

    local firstRowY = bodyY - (bodyHeight * 0.5) + (rowHeight * 0.5) + 0.002
    local textLeftX = bodyLeftX + 0.008
    for index, row in ipairs(rows) do
        local y = firstRowY + ((index - 1) * rowHeight)
        if y > 0.95 then
            break
        end

        local rank = math.max(1, math.floor(tonumber((row or {}).rank) or index))
        local isFinalized = type(row) == 'table' and row.finalized == true
        local textR, textG, textB, textA = 235, 240, 255, 225
        if isFinalized then
            if rank == 1 then
                textR, textG, textB, textA = 255, 215, 0, 240
            elseif rank == 2 then
                textR, textG, textB, textA = 192, 192, 192, 240
            elseif rank == 3 then
                textR, textG, textB, textA = 205, 127, 50, 240
            else
                textR, textG, textB, textA = 80, 160, 255, 235
            end
        end

        drawLeaderboardText(textLeftX, y - 0.004, rowTextScale, row.text, textR, textG, textB, textA, false)
    end
end

RacingSystem.Client.Util.ClearRaceLeaderboardVisual = function()
    raceLeaderboardVisualState.rows = {}
    raceLeaderboardVisualState.finalizedByKey = {}
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
RacingSystem.Client.latestSnapshot = latestSnapshot

local editorState = {
    active = false,
    name = '',
    selectedName = '',
    checkpoints = {},
    grabbedCheckpointIndex = nil,
    defaultCheckpointRadius = 8.0,
}
RacingSystem.Client.editorState = editorState

local latestSnapshotVersion = 0
local snapshotAcceptedAt = 0
local snapshotRequestedAt = 0
local latestStandingsVersionByInstanceId = {}
local latestStandingsByInstanceId = {}
local reliabilityCounters = {
    staleSnapshotsIgnored = 0,
}
local currentTrafficDensity = nil
local RACE_TRAFFIC_REQUEST_KEY = GetCurrentResourceName()
local ClientAdvancedConfig = (((RacingSystem or {}).Config or {}).advanced or {}).client or {}
local CHECKPOINT_RADIUS_STEP_METERS = tonumber(ClientAdvancedConfig.checkpointRadiusStepMeters) or 1.0
local EDITOR_PITCH_UP_CONTROL_ID = math.floor(tonumber(ClientAdvancedConfig.editorPitchUpControlId) or 111)
local EDITOR_PITCH_DOWN_CONTROL_ID = math.floor(tonumber(ClientAdvancedConfig.editorPitchDownControlId) or 112)
local LEADERBOARD_CLIENT_TIEBREAK_ENABLED = ClientAdvancedConfig.leaderboardClientTiebreakEnabled == true

local isGTAORacePromptOpen = false

local instanceAssetCache = {}
RacingSystem.Client.instanceAssetCache = instanceAssetCache

local activeInstanceAssets = {
    instanceId = nil,
    objects = {},
    modelHides = {},
}
RacingSystem.Client.activeInstanceAssets = activeInstanceAssets

local MILES_PER_HOUR_TO_METERS_PER_SECOND = 0.44704
local CHECKPOINT_RUNTIME_Z_OFFSET_METERS = tonumber(ClientAdvancedConfig.checkpointRuntimeZOffsetMeters) or -2.0
local MAX_FUTURE_PREVIEW_CHECKPOINTS = math.max(1, math.floor(tonumber(ClientAdvancedConfig.maxFuturePreviewCheckpoints) or 3))
local CORNER_CONE_MODEL_HASH = GetHashKey(tostring(ClientAdvancedConfig.cornerConeModel or 'prop_roadcone01a'))
local CORNER_CONE_SPAWN_HEIGHT_OFFSET = tonumber(ClientAdvancedConfig.cornerConeSpawnHeightOffset) or 4.0
local CORNER_CONE_MIN_LINE_CLEARANCE_METERS = tonumber(ClientAdvancedConfig.cornerConeMinLineClearanceMeters) or 10.0
-- Marker taxonomy (single source of truth for marker/blip semantics).
local MARKER_TAXONOMY = ClientAdvancedConfig.markerTaxonomy or {
    routeCheckpointTypeId = nil, -- falls back to RacingSystem.Config.markerTypeId
    routeChevronTypeId = 20,
    startLineIdleTypeId = 4, -- CheckeredFlagRect
    startLineIdleColor = { r = 255, g = 255, b = 255, a = 0 },
    futureCheckpointBlipSprite = 1,
    startLineBlipSprite = 38,
}
local isTeleportInProgress = false
local CLIENT_EXTRA_PRINT_LEVEL = math.floor(tonumber(ClientAdvancedConfig.extraPrintLevel) or 0)

-- Lazy accessor so client.lua functions can read InRace state without a circular upvalue.
local function getRaceRuntimeState()
    return RacingSystem.Client.InRace.raceRuntimeState
end

local function getRouteCheckpointMarkerTypeId()
    local taxonomyType = tonumber(MARKER_TAXONOMY.routeCheckpointTypeId)
    if taxonomyType then
        return taxonomyType
    end
    return tonumber(RacingSystem.Config.markerTypeId) or 1
end

local function getClientExtraPrintLevel()
    if CLIENT_EXTRA_PRINT_LEVEL == 2 then
        return 2
    end
    return 0
end

local function logClientVerbose(message)
    if getClientExtraPrintLevel() ~= 2 then
        return
    end
    print(('[racingsystem:client] %s'):format(tostring(message or '')))
end

RegisterNetEvent('racingsystem:notify', function(payload)
    local message = ''
    if type(payload) == 'table' then
        message = tostring(payload.message or '')
    else
        message = tostring(payload or '')
    end
    if message == '' then
        return
    end
    RacingSystem.Client.Util.NotifyPlayer(message)
end)

local function requestRaceStateSnapshot()
    snapshotRequestedAt = GetGameTimer()
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

local function isEditorActive()
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

    -- Notify menu UI that editor session has begun
    RacingSystem.Menu.beginEditorSessionUI()
end

local function endEditorSession()
    -- Notify menu UI that editor session has ended
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

local function moveClosestCheckpointToPlayer()
    if not isEditorActive() then
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
    if not isEditorActive() then
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

    local closestIndex, closestDistance = getClosestCheckpointIndex()
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

local function saveEditorRace(optionalName)
    if not isEditorActive() then
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

local function getRuntimeCheckpointMarker(checkpoint)
    local x = tonumber(checkpoint and checkpoint.x) or 0.0
    local y = tonumber(checkpoint and checkpoint.y) or 0.0
    local z = (tonumber(checkpoint and checkpoint.z) or 0.0) + CHECKPOINT_RUNTIME_Z_OFFSET_METERS

    return {
        x = x,
        y = y,
        z = z,
        dirX = 0.0,
        dirY = 0.0,
        dirZ = 0.0,
        rotX = 0.0,
        rotY = 0.0,
        rotZ = 0.0,
    }
end

local function getFuturePreviewMarkerHeight()
    return 3.0
end
RacingSystem.Client.getFuturePreviewMarkerHeight = getFuturePreviewMarkerHeight

local function getMaxFuturePreviewCheckpoints()
    return MAX_FUTURE_PREVIEW_CHECKPOINTS
end
RacingSystem.Client.getMaxFuturePreviewCheckpoints = getMaxFuturePreviewCheckpoints

local function getCheckpointRadiusScaleFactor(instance)
    local sourceType = tostring(type(instance) == 'table' and instance.sourceType or ''):lower()
    return sourceType == 'online' and 2.0 or 1.0
end

local function getVisualCheckpointRadius(checkpoint, instance)
    local baseRadius = tonumber(checkpoint and checkpoint.radius) or 8.0
    local visualScale = tonumber(RacingSystem.Config.visualCheckpointRadiusScale) or 1.0
    return (baseRadius * getCheckpointRadiusScaleFactor(instance) * 0.5) * visualScale
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
RacingSystem.Client.getNextCheckpointForVariant = getNextCheckpointForVariant

local function getCheckpointForVariant(instance, index, routeVariant)
    local variantEntry = getCheckpointVariantEntry(instance, index)
    if not variantEntry then
        return nil
    end

    if routeVariant == 'secondary' and type(variantEntry.secondary) == 'table' then
        return variantEntry.secondary
    end

    return variantEntry.primary
end
RacingSystem.Client.getCheckpointForVariant = getCheckpointForVariant
RacingSystem.Client.getCheckpointVariantEntry = getCheckpointVariantEntry

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

local function getVehicleHeadingToNextCheckpoint(currentCheckpoint, nextCheckpoint)
    local currentX = tonumber(currentCheckpoint and currentCheckpoint.x) or 0.0
    local currentY = tonumber(currentCheckpoint and currentCheckpoint.y) or 0.0
    local nextX = tonumber(nextCheckpoint and nextCheckpoint.x) or currentX
    local nextY = tonumber(nextCheckpoint and nextCheckpoint.y) or currentY
    local dx = nextX - currentX
    local dy = nextY - currentY
    if math.abs(dx) <= 0.0001 and math.abs(dy) <= 0.0001 then
        return 0.0
    end

    local heading = tonumber(GetHeadingFromVector_2d(dx, dy)) or 0.0
    if heading < 0.0 then
        heading = heading + 360.0
    end
    return heading
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
RacingSystem.Client.getHorizontalDistance = getHorizontalDistance

local function getCheckpointPassRadius(checkpoint, instance)
    local baseRadius = tonumber(checkpoint and checkpoint.radius) or 8.0
    return baseRadius * getCheckpointRadiusScaleFactor(instance)
end

local function getCheckpointPenaltyRadius(checkpoint, instance)
    return getCheckpointPassRadius(checkpoint, instance) * 0.5
end
RacingSystem.Client.getCheckpointPenaltyRadius = getCheckpointPenaltyRadius

local function getPenaltyPreviewStateByOutsideOffset(outsideOffset)
    local offset = math.max(0.0, tonumber(outsideOffset) or 0.0)
    if offset > 20.0 then
        return 'PENALTY PREVIEW: INVALID', '~o~'
    end
    if offset > 10.0 then
        return 'PENALTY PREVIEW: TELEPORT', '~o~'
    end
    if offset >= 1.5 then
        return 'PENALTY PREVIEW: CUT', '~r~'
    end
    if offset >= 0.5 then
        return 'PENALTY PREVIEW: WARN', '~y~'
    end
    return 'PENALTY PREVIEW: CLEAR', '~g~'
end

local function computeCheckpointChevronEdge(checkpoint, prevCheckpoint, nextCheckpoint, instance)
    if type(checkpoint) ~= 'table' then
        return nil
    end

    local currentX = tonumber(checkpoint.x) or 0.0
    local currentY = tonumber(checkpoint.y) or 0.0
    local prevX = tonumber(prevCheckpoint and prevCheckpoint.x) or currentX
    local prevY = tonumber(prevCheckpoint and prevCheckpoint.y) or currentY
    local nextX = tonumber(nextCheckpoint and nextCheckpoint.x) or currentX
    local nextY = tonumber(nextCheckpoint and nextCheckpoint.y) or currentY
    local lineX = nextX - prevX
    local lineY = nextY - prevY
    local lineLengthSquared = (lineX * lineX) + (lineY * lineY)
    local radius = getCheckpointPassRadius(checkpoint, instance) * 0.2
    if lineLengthSquared <= 0.001 then
        return {
            x = currentX + radius,
            y = currentY,
        }
    end

    local toCurrentX = currentX - prevX
    local toCurrentY = currentY - prevY
    local t = ((toCurrentX * lineX) + (toCurrentY * lineY)) / lineLengthSquared
    t = math.max(0.0, math.min(1.0, t))

    local closestX = prevX + (lineX * t)
    local closestY = prevY + (lineY * t)
    local dirX = closestX - currentX
    local dirY = closestY - currentY
    local dirLength = math.sqrt((dirX * dirX) + (dirY * dirY))
    if dirLength <= 0.001 then
        dirX = nextX - currentX
        dirY = nextY - currentY
        dirLength = math.sqrt((dirX * dirX) + (dirY * dirY))
    end
    if dirLength <= 0.001 then
        return {
            x = currentX + radius,
            y = currentY,
        }
    end

    return {
        x = currentX + ((dirX / dirLength) * radius),
        y = currentY + ((dirY / dirLength) * radius),
    }
end

local function computeCheckpointCornerPoint(checkpoint, prevCheckpoint, nextCheckpoint, instance)
    if type(checkpoint) ~= 'table' then
        return nil
    end

    local currentX = tonumber(checkpoint.x) or 0.0
    local currentY = tonumber(checkpoint.y) or 0.0
    local prevX = tonumber(prevCheckpoint and prevCheckpoint.x) or currentX
    local prevY = tonumber(prevCheckpoint and prevCheckpoint.y) or currentY
    local nextX = tonumber(nextCheckpoint and nextCheckpoint.x) or currentX
    local nextY = tonumber(nextCheckpoint and nextCheckpoint.y) or currentY

    local lineX = nextX - prevX
    local lineY = nextY - prevY
    local lineLengthSquared = (lineX * lineX) + (lineY * lineY)
    local midpointX = (prevX + nextX) * 0.5
    local midpointY = (prevY + nextY) * 0.5
    local dirX = midpointX - currentX
    local dirY = midpointY - currentY
    local dirLength = math.sqrt((dirX * dirX) + (dirY * dirY))

    if dirLength <= 0.001 then
        dirX = nextX - currentX
        dirY = nextY - currentY
        dirLength = math.sqrt((dirX * dirX) + (dirY * dirY))
    end

    local cornerRadius = getCheckpointPenaltyRadius(checkpoint, instance)
    if dirLength <= 0.001 or cornerRadius <= 0.001 then
        return {
            x = currentX,
            y = currentY,
        }
    end

    -- If the true closest point on the prev->next segment falls inside radius,
    -- skip cone placement for this checkpoint.
    local closestDistance = math.huge
    if lineLengthSquared > 0.001 then
        local toCurrentX = currentX - prevX
        local toCurrentY = currentY - prevY
        local t = ((toCurrentX * lineX) + (toCurrentY * lineY)) / lineLengthSquared
        t = math.max(0.0, math.min(1.0, t))
        local closestX = prevX + (lineX * t)
        local closestY = prevY + (lineY * t)
        local closestDirX = closestX - currentX
        local closestDirY = closestY - currentY
        closestDistance = math.sqrt((closestDirX * closestDirX) + (closestDirY * closestDirY))
    else
        closestDistance = dirLength
    end

    local requiredClearance = cornerRadius + CORNER_CONE_MIN_LINE_CLEARANCE_METERS
    if closestDistance <= requiredClearance then
        return {
            x = currentX,
            y = currentY,
            skipCone = true,
        }
    end

    local clamped = math.min(dirLength, cornerRadius)
    return {
        x = currentX + ((dirX / dirLength) * clamped),
        y = currentY + ((dirY / dirLength) * clamped),
        dirX = dirX / dirLength,
        dirY = dirY / dirLength,
        radius = clamped,
    }
end

local function clearCornerCones()
    local conesByKey = type(getRaceRuntimeState().cornerConesByKey) == 'table' and getRaceRuntimeState().cornerConesByKey or {}
    for _, entry in pairs(conesByKey) do
        local entity = tonumber(type(entry) == 'table' and entry.entity or entry)
        if entity and entity ~= 0 and DoesEntityExist(entity) then
            SetEntityAsNoLongerNeeded(entity)
        end
    end
    getRaceRuntimeState().cornerConesByKey = {}
end
RacingSystem.Client.clearCornerCones = clearCornerCones

local function spawnCornerConeIfMissing(key, x, y, z, heading)
    if key == nil then
        return
    end

    if not IsModelInCdimage(CORNER_CONE_MODEL_HASH) then
        return
    end

    if not HasModelLoaded(CORNER_CONE_MODEL_HASH) then
        RequestModel(CORNER_CONE_MODEL_HASH)
        if not HasModelLoaded(CORNER_CONE_MODEL_HASH) then
            return
        end
    end

    local conesByKey = type(getRaceRuntimeState().cornerConesByKey) == 'table' and getRaceRuntimeState().cornerConesByKey or {}
    local keyString = tostring(key)
    local existing = conesByKey[keyString]
    local entity = tonumber(type(existing) == 'table' and existing.entity or existing) or 0

    if entity ~= 0 then
        return
    end

    local spawnZ = (tonumber(z) or 0.0) + CORNER_CONE_SPAWN_HEIGHT_OFFSET

    entity = CreateObjectNoOffset(CORNER_CONE_MODEL_HASH, x, y, spawnZ, true, true, false)
    if entity == 0 or not DoesEntityExist(entity) then
        return
    end

    FreezeEntityPosition(entity, false)
    PlaceObjectOnGroundProperly(entity)
    SetEntityHeading(entity, tonumber(heading) or 0.0)
    FreezeEntityPosition(entity, false)

    conesByKey[keyString] = {
        entity = entity,
    }
    getRaceRuntimeState().cornerConesByKey = conesByKey
end

local function releaseCornerConeByKey(key)
    if key == nil then
        return
    end

    local conesByKey = type(getRaceRuntimeState().cornerConesByKey) == 'table' and getRaceRuntimeState().cornerConesByKey or {}
    local keyString = tostring(key)
    local existing = conesByKey[keyString]
    local entity = tonumber(type(existing) == 'table' and existing.entity or existing) or 0
    if entity ~= 0 and DoesEntityExist(entity) then
        SetEntityAsNoLongerNeeded(entity)
    end
    conesByKey[keyString] = nil
    getRaceRuntimeState().cornerConesByKey = conesByKey
end

local function clearCheckpointChevronEdgeCache()
    getRaceRuntimeState().chevronEdgeCache = nil
end
RacingSystem.Client.clearCheckpointChevronEdgeCache = clearCheckpointChevronEdgeCache

local function getCheckpointChevronEdgeCache(instance)
    if type(instance) ~= 'table' then
        return { primary = {}, secondary = {} }
    end

    local instanceId = tonumber(instance.id)
    local checkpoints = type(instance.checkpoints) == 'table' and instance.checkpoints or {}
    local totalCheckpoints = #checkpoints
    local existing = getRaceRuntimeState().chevronEdgeCache
    if type(existing) == 'table'
        and tonumber(existing.instanceId) == instanceId
        and tonumber(existing.totalCheckpoints) == totalCheckpoints then
        return existing
    end

    local cache = {
        instanceId = instanceId,
        totalCheckpoints = totalCheckpoints,
        primary = {},
        secondary = {},
    }

    if totalCheckpoints <= 0 then
        getRaceRuntimeState().chevronEdgeCache = cache
        return cache
    end

    for index = 1, totalCheckpoints do
        local prevIndex = index - 1
        if prevIndex < 1 then
            prevIndex = totalCheckpoints
        end
        local nextIndex = index + 1
        if nextIndex > totalCheckpoints then
            nextIndex = 1
        end

        local currentVariant = getCheckpointVariantEntry(instance, index)
        local prevVariant = getCheckpointVariantEntry(instance, prevIndex)
        local nextVariant = getCheckpointVariantEntry(instance, nextIndex)

        local currentPrimary = currentVariant and currentVariant.primary or checkpoints[index]
        local prevPrimary = prevVariant and prevVariant.primary or checkpoints[prevIndex]
        local nextPrimary = nextVariant and nextVariant.primary or checkpoints[nextIndex]
        cache.primary[index] = computeCheckpointChevronEdge(currentPrimary, prevPrimary, nextPrimary, instance)

        local currentSecondary = currentVariant and currentVariant.secondary or nil
        if type(currentSecondary) == 'table' then
            local prevSecondary = prevVariant and prevVariant.secondary or nil
            local nextSecondary = nextVariant and nextVariant.secondary or nil
            cache.secondary[index] = computeCheckpointChevronEdge(
                currentSecondary,
                prevSecondary or prevPrimary,
                nextSecondary or nextPrimary,
                instance
            )
        end
    end

    getRaceRuntimeState().chevronEdgeCache = cache
    return cache
end
RacingSystem.Client.getCheckpointChevronEdgeCache = getCheckpointChevronEdgeCache

local function drawCheckpointConeChevronVariants(checkpoint, prevCheckpoint, nextCheckpoint, currentX, currentY, currentZ, aimX, aimY, nextX, nextY, chevronZ, chevronSize, chevronRotationZ, chevronColor, instance)
    local coneChevronA = nil
    local coneChevronB = nil
    local cornerPoint = computeCheckpointCornerPoint(checkpoint, prevCheckpoint, nextCheckpoint, instance)
    if type(cornerPoint) == 'table' then
        local markerDrawForLine = getRuntimeCheckpointMarker(checkpoint)
        local lineBaseZ = tonumber(markerDrawForLine.z) or (tonumber(checkpoint.z) or 0.0)
        local checkpointKey = ('%.3f|%.3f|%.3f'):format(currentX, currentY, tonumber(checkpoint.z) or 0.0)

        if cornerPoint.skipCone == true then
            releaseCornerConeByKey(checkpointKey .. '|a')
            releaseCornerConeByKey(checkpointKey .. '|b')

            local centerHeading = getHeadingToNextCheckpoint(checkpoint, nextCheckpoint)
            spawnCornerConeIfMissing(checkpointKey .. '|c', currentX, currentY, lineBaseZ, centerHeading)
            coneChevronA = { x = currentX, y = currentY, z = lineBaseZ }
        else
            releaseCornerConeByKey(checkpointKey .. '|c')

            local cornerX = tonumber(cornerPoint.x) or 0.0
            local cornerY = tonumber(cornerPoint.y) or 0.0
            local oppositeX = currentX - (cornerX - currentX)
            local oppositeY = currentY - (cornerY - currentY)
            local outwardHeading = math.deg(math.atan2(cornerY - currentY, cornerX - currentX))

            spawnCornerConeIfMissing(checkpointKey .. '|a', cornerX, cornerY, lineBaseZ, outwardHeading)
            spawnCornerConeIfMissing(checkpointKey .. '|b', oppositeX, oppositeY, lineBaseZ, outwardHeading + 180.0)
            coneChevronA = { x = cornerX, y = cornerY, z = lineBaseZ + 3.0 }
            coneChevronB = { x = oppositeX, y = oppositeY, z = lineBaseZ + 3.0 }
        end
    end

    local function drawConeChevronAt(targetX, targetY, targetZ)
        local toNextX = nextX - targetX
        local toNextY = nextY - targetY
        local toNextLength = math.sqrt((toNextX * toNextX) + (toNextY * toNextY))
        local coneAimX = aimX
        local coneAimY = aimY
        if toNextLength > 0.001 then
            coneAimX = toNextX / toNextLength
            coneAimY = toNextY / toNextLength
        end

        DrawMarker(
            MARKER_TAXONOMY.routeChevronTypeId,
            targetX,
            targetY,
            tonumber(targetZ) or chevronZ,
            coneAimX,
            coneAimY,
            0.0,
            89.0,
            0.0,
            chevronRotationZ,
            chevronSize,
            chevronSize,
            chevronSize,
            chevronColor.r,
            chevronColor.g,
            chevronColor.b,
            chevronColor.a,
            false,
            false,
            2,
            false,
            nil,
            nil,
            false
        )
    end

    if type(coneChevronA) == 'table' then
        drawConeChevronAt(coneChevronA.x, coneChevronA.y, coneChevronA.z)
    end
    if type(coneChevronB) == 'table' then
        drawConeChevronAt(coneChevronB.x, coneChevronB.y, coneChevronB.z)
    end
end

local function drawCheckpointTarget(checkpoint, prevCheckpoint, nextCheckpoint, isStart, isFinish, markerColor, chevronColor, hideChevron, spinDegreesPerSecond, chevronEdge, renderAsCheckeredFlag, markerHeightOverride, instance)
    if type(checkpoint) ~= 'table' then
        return
    end

    local markerDraw = getRuntimeCheckpointMarker(checkpoint)
    if renderAsCheckeredFlag == true then
        local baseRadius = tonumber(checkpoint.radius) or 8.0
        local flagScale = math.max(1.2, math.min(2.6, baseRadius * 0.2))
        local drawZ = tonumber(checkpoint.z) or markerDraw.z
        local flagHeading = getHeadingToNextCheckpoint(checkpoint, nextCheckpoint)
        DrawMarker(
            MARKER_TAXONOMY.startLineIdleTypeId,
            markerDraw.x,
            markerDraw.y,
            drawZ,
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
            tonumber((MARKER_TAXONOMY.startLineIdleColor or {}).a) or 77,
            false,
            true,
            2,
            false,
            nil,
            nil,
            false
        )
        return
    end

    local visualRadius = getVisualCheckpointRadius(checkpoint, instance)
    local markerRed = tonumber((markerColor or {}).r) or 80
    local markerGreen = tonumber((markerColor or {}).g) or 255
    local markerBlue = tonumber((markerColor or {}).b) or 255
    local markerAlpha = 170
    local markerHeight = tonumber(markerHeightOverride) or 4.0
    DrawMarker(
        getRouteCheckpointMarkerTypeId(),
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
        markerHeight,
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
    local dirToLastX = prevX - currentX
    local dirToLastY = prevY - currentY
    local dirToNextX = nextX - currentX
    local dirToNextY = nextY - currentY
    local dirToLastLength = math.sqrt((dirToLastX * dirToLastX) + (dirToLastY * dirToLastY))
    local dirToNextLength = math.sqrt((dirToNextX * dirToNextX) + (dirToNextY * dirToNextY))
    local orientedAngleDegrees = 180.0
    if dirToLastLength > 0.001 and dirToNextLength > 0.001 then
        local dot = ((dirToLastX * dirToNextX) + (dirToLastY * dirToNextY)) / (dirToLastLength * dirToNextLength)
        local crossZ = ((dirToLastX * dirToNextY) - (dirToLastY * dirToNextX)) / (dirToLastLength * dirToNextLength)
        local signedAngle = math.deg(math.atan2(crossZ, dot))
        if signedAngle < 0.0 then
            orientedAngleDegrees = signedAngle + 360.0
        else
            orientedAngleDegrees = signedAngle
        end
    end
    local chevronRotationZ = -90.0
    local toNextX = nextX - currentX
    local toNextY = nextY - currentY
    local toNextLength = math.sqrt((toNextX * toNextX) + (toNextY * toNextY))
    if toNextLength <= 0.001 then
        return
    end
    local aimX = toNextX / toNextLength
    local aimY = toNextY / toNextLength

    local edgeRadius = getCheckpointPassRadius(checkpoint, instance)
    local chevronZ = currentZ + 2.35
    local chevronSize = math.max(1.2, math.min(2.2, edgeRadius * 0.18))
    local chevronColor = { r = 255, g = 140, b = 0, a = 242 }
    local mainChevronAlpha = chevronColor.a
    local edge = type(chevronEdge) == 'table' and chevronEdge or computeCheckpointChevronEdge(checkpoint, prevCheckpoint, nextCheckpoint, instance)
    if type(edge) ~= 'table' then
        return
    end
    local edgeX = tonumber(edge.x) or currentX
    local edgeY = tonumber(edge.y) or currentY
    local function drawRouteChevronAt(targetX, targetY, flipRotationX, drawZOverride)
        local drawAimX = aimX
        local drawAimY = aimY
        local rotationX = (flipRotationX == true) and -89.0 or 89.0
        DrawMarker(
            MARKER_TAXONOMY.routeChevronTypeId,
            targetX,
            targetY,
            tonumber(drawZOverride) or chevronZ,
            drawAimX,
            drawAimY,
            0.0,
            -- Keep X just below 90; exact 90 flattens/resets this marker.
            rotationX,
            0.0,
            chevronRotationZ,
            chevronSize,
            chevronSize,
            chevronSize,
            chevronColor.r,
            chevronColor.g,
            chevronColor.b,
            mainChevronAlpha,
            false,
            false,
            2,
            false,
            nil,
            nil,
            false
        )
    end

    drawRouteChevronAt(currentX, currentY, false)
    -- Legacy cone-based chevrons intentionally disabled for now.
    -- Kept in a separate method for future toggles/tuning.
    -- drawCheckpointConeChevronVariants(checkpoint, prevCheckpoint, nextCheckpoint, currentX, currentY, currentZ, aimX, aimY, nextX, nextY, chevronZ, chevronSize, chevronRotationZ, chevronColor, instance)

    return
end
RacingSystem.Client.drawCheckpointTarget = drawCheckpointTarget

local function drawIdleStartChevron(checkpoint)
    if type(checkpoint) ~= 'table' then
        return
    end

    local markerDraw = getRuntimeCheckpointMarker(checkpoint)
    local baseRadius = tonumber(checkpoint.radius) or 8.0
    local flagScale = math.max(1.2, math.min(2.6, baseRadius * 0.2))
    local drawZ = tonumber(checkpoint.z) or markerDraw.z
    local nextCheckpoint = nil
    if type(checkpoint.nextCheckpoint) == 'table' then
        nextCheckpoint = checkpoint.nextCheckpoint
    end
    local flagHeading = getHeadingToNextCheckpoint(checkpoint, nextCheckpoint)

    DrawMarker(
        MARKER_TAXONOMY.startLineIdleTypeId,
        markerDraw.x,
        markerDraw.y,
        drawZ,
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
        tonumber((MARKER_TAXONOMY.startLineIdleColor or {}).a) or 220,
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
    local blipsByIndex = type(getRaceRuntimeState().futureCheckpointBlips) == 'table' and getRaceRuntimeState().futureCheckpointBlips or {}
    for _, blip in pairs(blipsByIndex) do
        if blip and DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    getRaceRuntimeState().futureCheckpointBlips = {}
    getRaceRuntimeState().futureBlipCheckpointIndex = nil
    getRaceRuntimeState().futureBlipInstanceId = nil
end
RacingSystem.Client.clearFutureCheckpointBlips = clearFutureCheckpointBlips

local function clearStartLineBlip()
    local blip = getRaceRuntimeState().startLineBlip
    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
    getRaceRuntimeState().startLineBlip = nil
end
RacingSystem.Client.clearStartLineBlip = clearStartLineBlip

local function buildFutureCheckpointIndices(totalCheckpoints, targetIndex, countAhead, allowWrap)
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
    local canWrap = allowWrap ~= false
    local indices = {}

    -- Include the current target checkpoint first so passing it removes that blip
    -- (instead of appearing to remove the next checkpoint).
    for step = 0, (maxCount - 1) do
        local futureIndex = currentIndex + step
        if futureIndex > total then
            if not canWrap then
                break
            end
            futureIndex = ((futureIndex - 1) % total) + 1
        end
        indices[#indices + 1] = futureIndex
    end

    return indices
end

local function updateFutureCheckpointBlips(instance, totalCheckpoints, targetIndex, allowWrap)
    local indices = buildFutureCheckpointIndices(totalCheckpoints, targetIndex, 5, allowWrap)
    if #indices == 0 then
        clearFutureCheckpointBlips()
        return
    end

    local desired = {}
    for _, index in ipairs(indices) do
        desired[index] = true
    end

    local blipsByIndex = type(getRaceRuntimeState().futureCheckpointBlips) == 'table' and getRaceRuntimeState().futureCheckpointBlips or {}
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
                SetBlipSprite(blip, MARKER_TAXONOMY.futureCheckpointBlipSprite)
                SetBlipDisplay(blip, 4)
                SetBlipScale(blip, 0.75)
                SetBlipColour(blip, 3)
                SetBlipAsShortRange(blip, false)
                blipsByIndex[index] = blip
            end
        end
    end

    getRaceRuntimeState().futureCheckpointBlips = blipsByIndex
end
RacingSystem.Client.updateFutureCheckpointBlips = updateFutureCheckpointBlips

local function resolveStartLineCheckpoint(checkpoints, totalCheckpoints, fallbackCheckpoint, pointToPoint)
    local list = type(checkpoints) == 'table' and checkpoints or {}
    local checkpointCount = math.max(1, math.floor(tonumber(totalCheckpoints) or #list or 1))
    local startIndex = (pointToPoint == true) and 1 or checkpointCount
    local raw = list[startIndex] or list[#list] or fallbackCheckpoint or getRaceRuntimeState().startLineCheckpoint
    if type(raw) ~= 'table' then
        return nil
    end

    local resolved = {
        index = startIndex,
        x = tonumber(raw.x) or 0.0,
        y = tonumber(raw.y) or 0.0,
        z = tonumber(raw.z) or 0.0,
        radius = tonumber(raw.radius) or 8.0,
    }
    getRaceRuntimeState().startLineCheckpoint = resolved
    logClientVerbose(("[startfinish] startLine resolvedIndex=%s totalCheckpoints=%s xyz=(%.2f,%.2f,%.2f)"):format(
        tostring(resolved.index),
        tostring(totalCheckpoints),
        resolved.x,
        resolved.y,
        resolved.z
    ))
    return resolved
end
RacingSystem.Client.resolveStartLineCheckpoint = resolveStartLineCheckpoint

local function getClientRaceStartCheckpoint(totalCheckpoints, pointToPoint)
    local checkpointCount = math.max(0, math.floor(tonumber(totalCheckpoints) or 0))
    if checkpointCount <= 1 then
        return 1
    end

    if pointToPoint == true then
        return 1
    end

    -- Coherency rule: start line is always the final checkpoint.
    return checkpointCount
end
RacingSystem.Client.getClientRaceStartCheckpoint = getClientRaceStartCheckpoint

local function getClientLapTriggerCheckpoint(totalCheckpoints)
    local checkpointCount = math.max(0, math.floor(tonumber(totalCheckpoints) or 0))
    if checkpointCount <= 1 then
        return 1
    end

    -- Coherency rule: finish/lap trigger is always the final checkpoint.
    return checkpointCount
end
RacingSystem.Client.getClientLapTriggerCheckpoint = getClientLapTriggerCheckpoint

local function updateStartLineBlip(startCheckpoint)
    if type(startCheckpoint) ~= 'table' then
        clearStartLineBlip()
        return
    end

    local x = tonumber(startCheckpoint.x) or 0.0
    local y = tonumber(startCheckpoint.y) or 0.0
    local z = tonumber(startCheckpoint.z) or 0.0
    local blip = getRaceRuntimeState().startLineBlip
    if not blip or not DoesBlipExist(blip) then
        blip = AddBlipForCoord(x, y, z)
        getRaceRuntimeState().startLineBlip = blip
        SetBlipSprite(blip, MARKER_TAXONOMY.startLineBlipSprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.9)
        SetBlipColour(blip, 0)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Race Start')
        EndTextCommandSetBlipName(blip)
    else
        SetBlipCoords(blip, x, y, z)
    end
end
RacingSystem.Client.updateStartLineBlip = updateStartLineBlip

local function showJoinHintNotifications()
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName('Gather near the blue chevron and start the Countdown from the ~b~Race~s~ menu.')
    EndTextCommandThefeedPostTicker(false, false)

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName('I assure you this jank is ~y~temporary~w~.')
    EndTextCommandThefeedPostTicker(false, false)
end
RacingSystem.Client.showJoinHintNotifications = showJoinHintNotifications

local function getCheckpointPassArmKey(instanceId, checkpointIndex, lapNumber)
    return ('%s:%s:%s'):format(tonumber(instanceId) or 0, tonumber(checkpointIndex) or 0, tonumber(lapNumber) or 1)
end
RacingSystem.Client.getCheckpointPassArmKey = getCheckpointPassArmKey

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
RacingSystem.Client.cloneRuntimeCheckpoint = cloneRuntimeCheckpoint

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
    local cached = getRaceRuntimeState().lastPassedCheckpoint
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

local function normalizeEntrantId(value)
    if value == nil then
        return nil
    end

    local text = RacingSystem.Trim(tostring(value))
    if text == '' then
        return nil
    end

    return text
end

local function resolveLocalEntrantEntry(instance)
    if type(instance) ~= 'table' then
        return nil
    end

    local entrants = type(instance.entrants) == 'table' and instance.entrants or {}
    local localServerId = tonumber(GetPlayerServerId(PlayerId())) or 0
    local preferredEntrantId = normalizeEntrantId(RacingSystem.Client.InRace.localEntrantIdentity.entrantId)
    if preferredEntrantId then
        for _, entrant in ipairs(entrants) do
            local entrantId = normalizeEntrantId(entrant.entrantId)
            if entrantId and entrantId == preferredEntrantId then
                return entrant
            end
        end
    end

    for _, entrant in ipairs(entrants) do
        if tonumber(entrant.source) == localServerId then
            local entrantId = normalizeEntrantId(entrant.entrantId)
            if entrantId then
                RacingSystem.Client.InRace.localEntrantIdentity.entrantId = entrantId
            end
            return entrant
        end
    end

    return nil
end

local function getJoinedRaceInstance()
    local instances = type(latestSnapshot.instances) == 'table' and latestSnapshot.instances or {}
    for _, instance in ipairs(instances) do
        local entrant = resolveLocalEntrantEntry(instance)
        if entrant then
            local entrantId = normalizeEntrantId(entrant.entrantId)
            if entrantId then
                RacingSystem.Client.InRace.localEntrantIdentity.entrantId = entrantId
            end
            return instance
        end
    end

    return nil
end
RacingSystem.Client.getJoinedRaceInstance = getJoinedRaceInstance

local function normalizeTrafficDensity(value)
    local density = tonumber(value)
    if not density then
        return 0.0
    end

    if density < 0.0 then
        density = 0.0
    elseif density > 1.0 then
        density = 1.0
    end

    return density
end

local function applyJoinedInstanceTrafficMode()
    local joinedInstance = getJoinedRaceInstance()
    if not joinedInstance then
        if currentTrafficDensity ~= nil then
            currentTrafficDensity = nil
            TriggerServerEvent('traffic_control:requestDensity', nil, 'Traffic control lifted', RACE_TRAFFIC_REQUEST_KEY)
        end
        return
    end

    local targetDensity = normalizeTrafficDensity(joinedInstance and joinedInstance.trafficDensity)
    if currentTrafficDensity and math.abs(currentTrafficDensity - targetDensity) < 0.0001 then
        return
    end

    currentTrafficDensity = targetDensity
    TriggerServerEvent('traffic_control:requestDensity', targetDensity, 'Traffic control for race', RACE_TRAFFIC_REQUEST_KEY)
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
    local entrant = resolveLocalEntrantEntry(instance)
    if type(entrant) == 'table' then
        local entrantId = normalizeEntrantId(entrant.entrantId)
        if entrantId then
            RacingSystem.Client.InRace.localEntrantIdentity.entrantId = entrantId
        end
    end
    return entrant
end
RacingSystem.Client.getLocalEntrant = getLocalEntrant

local function getEffectiveEntrantProgress(instance, entrant)
    local currentCheckpoint = tonumber(entrant and entrant.currentCheckpoint) or 1
    local currentLap = math.max(1, tonumber(entrant and entrant.currentLap) or 1)
    local finishedAt = tonumber(entrant and entrant.finishedAt)
    local predicted = getRaceRuntimeState().predictedProgress
    local instanceId = tonumber(instance and instance.id)

    if predicted and instanceId and tonumber(predicted.instanceId) == instanceId then
        local predictedCheckpoint = tonumber(predicted.currentCheckpoint)
        local predictedLap = math.max(1, tonumber(predicted.currentLap) or currentLap)
        local predictedFinished = predicted.finished == true

        if finishedAt or (predictedFinished and predictedCheckpoint == nil) then
            RacingSystem.Client.InRace.clearPredictedRaceProgress(instanceId)
        elseif predictedCheckpoint and (predictedLap > currentLap or (predictedLap == currentLap and predictedCheckpoint > currentCheckpoint)) then
            currentCheckpoint = predictedCheckpoint
            currentLap = predictedLap
        else
            RacingSystem.Client.InRace.clearPredictedRaceProgress(instanceId)
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
        return
    end

    local entrant = getLocalEntrant(joinedInstance)
    local entrantProgress = RacingSystem.Client.InRace.getEffectiveEntrantProgress(joinedInstance, entrant)
    local lastCheckpoint, nextCheckpoint = RacingSystem.Client.InRace.resolveLastPassedCheckpointTarget(joinedInstance, entrantProgress)
    if type(lastCheckpoint) ~= 'table' then
        return
    end

    TriggerEvent('racingsystem:smartCheckpointTeleport', {
        checkpoint = lastCheckpoint,
        nextCheckpoint = nextCheckpoint,
    })
end

local function predictCheckpointPass(instance, entrantProgress, totalCheckpoints, targetIndex)
    local instanceId = tonumber(instance and instance.id)
    if not instanceId then
        return
    end

    local currentLap = math.max(1, tonumber(entrantProgress and entrantProgress.currentLap) or 1)
    local totalLaps = math.max(1, tonumber(instance and instance.laps) or 1)
    local lapTriggerCheckpoint = getClientLapTriggerCheckpoint(totalCheckpoints)
    local postFinishNextCheckpoint = (instance and instance.pointToPoint == true)
        and math.max(1, totalCheckpoints)
        or 1

    if targetIndex == lapTriggerCheckpoint then
        if currentLap >= totalLaps then
            getRaceRuntimeState().predictedProgress = {
                instanceId = instanceId,
                currentCheckpoint = totalCheckpoints + 1,
                currentLap = currentLap,
                finished = true,
            }
        else
            getRaceRuntimeState().predictedProgress = {
                instanceId = instanceId,
                currentCheckpoint = postFinishNextCheckpoint,
                currentLap = currentLap + 1,
                finished = false,
            }
        end
    else
        local nextCheckpoint = targetIndex + 1
        if nextCheckpoint > totalCheckpoints then
            nextCheckpoint = 1
        end
        getRaceRuntimeState().predictedProgress = {
            instanceId = instanceId,
            currentCheckpoint = nextCheckpoint,
            currentLap = currentLap,
            finished = false,
        }
    end
end
RacingSystem.Client.predictCheckpointPass = predictCheckpointPass

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
    if not forceReset and not isGTAORacePromptOpen then
        return
    end

    isGTAORacePromptOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'racingsystem:toggleGTAORacePrompt',
        open = false,
    })
end

local function openGTAORaceUrlPrompt()
    if isGTAORacePromptOpen then
        return
    end

    isGTAORacePromptOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'racingsystem:toggleGTAORacePrompt',
        open = true,
    })
end

local function cloneEntrantRow(entrant)
    if type(entrant) ~= 'table' then
        return nil
    end

    return {
        entrantId = tostring(entrant.entrantId or ''),
        source = tonumber(entrant.source) or 0,
        name = tostring(entrant.name or ''),
        joinedAt = tonumber(entrant.joinedAt) or 0,
        currentCheckpoint = tonumber(entrant.currentCheckpoint) or 1,
        currentLap = tonumber(entrant.currentLap) or 1,
        checkpointsPassed = tonumber(entrant.checkpointsPassed) or 0,
        lastCheckpointAt = tonumber(entrant.lastCheckpointAt) or 0,
        lapStartedAt = tonumber(entrant.lapStartedAt) or 0,
        lapTimes = type(entrant.lapTimes) == 'table' and entrant.lapTimes or {},
        totalTimeMs = tonumber(entrant.totalTimeMs) or nil,
        finishedAt = tonumber(entrant.finishedAt) or nil,
        position = tonumber(entrant.position) or nil,
    }
end

local function reconcileInstanceEntrantsWithAuthoritativeStandings(instance)
    if type(instance) ~= 'table' then
        return
    end

    local instanceId = tonumber(instance.id)
    if not instanceId then
        return
    end

    local standingsEntrants = latestStandingsByInstanceId[instanceId]
    if type(standingsEntrants) ~= 'table' then
        return
    end

    local updatedEntrants = {}
    for _, entrant in ipairs(standingsEntrants) do
        local cloned = cloneEntrantRow(entrant)
        if cloned then
            updatedEntrants[#updatedEntrants + 1] = cloned
        end
    end

    if #updatedEntrants > 0 then
        instance.entrants = updatedEntrants
    end
end

-- Local-only event bridge used by menu.lua to open the GTAO URL prompt.
AddEventHandler('racingsystem:openGTAORaceUrlPrompt', function()
    openGTAORaceUrlPrompt()
end)

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
RacingSystem.Client.unloadActiveInstanceAssets = unloadActiveInstanceAssets

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
                local hasSpeedAdjust, speedTarget, durationTarget = RacingSystem.Client.InRace.GetPropSpeedModificationParameters(model, speedAdjustment)
                if hasSpeedAdjust then
                    if speedTarget > -1 then
                        SetObjectStuntPropSpeedup(newObject, speedTarget)
                    end

                    if durationTarget > -1 then
                        SetObjectStuntPropDuration(newObject, durationTarget)
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
RacingSystem.Client.loadInstanceAssets = loadInstanceAssets

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
    if not getRaceRuntimeState().pendingCheckpointPass then
        return
    end

    local currentCheckpoint = tonumber(entrant and entrant.currentCheckpoint) or 1
    local pending = getRaceRuntimeState().pendingCheckpointPass
    if pending.instanceId ~= nil and tonumber(currentCheckpoint) ~= tonumber(pending.checkpointIndex) then
        getRaceRuntimeState().pendingCheckpointPass = nil
        return
    end

    if GetGameTimer() > (pending.expiresAt or 0) then
        getRaceRuntimeState().pendingCheckpointPass = nil
    end
end
RacingSystem.Client.clearPendingCheckpointIfAdvanced = clearPendingCheckpointIfAdvanced

RegisterNetEvent('racingsystem:stateSnapshot', function(snapshot)
    if type(snapshot) ~= 'table' then
        return
    end

    local incomingVersion = math.floor(tonumber(snapshot.snapshotVersion) or 0)
    if incomingVersion > 0 and incomingVersion <= latestSnapshotVersion then
        reliabilityCounters.staleSnapshotsIgnored = reliabilityCounters.staleSnapshotsIgnored + 1
        if getClientExtraPrintLevel() == 2 then
            logClientVerbose(("Ignored stale snapshot version=%s latest=%s ignored=%s"):format(
                tostring(incomingVersion),
                tostring(latestSnapshotVersion),
                tostring(reliabilityCounters.staleSnapshotsIgnored)
            ))
        end
        return
    end

    if incomingVersion > 0 then
        latestSnapshotVersion = incomingVersion
    end
    snapshotAcceptedAt = GetGameTimer()
    latestSnapshot = snapshot
    RacingSystem.Client.latestSnapshot = latestSnapshot

    local instances = type(snapshot.instances) == 'table' and snapshot.instances or {}
    for _, instance in ipairs(instances) do
        reconcileInstanceEntrantsWithAuthoritativeStandings(instance)
    end

    -- Refresh menu if it's open (for live state updates)
    if RacingSystem.Menu.isRaceMenuVisible() then
        RacingSystem.Menu.refreshRaceMenu()
    end

    if getClientExtraPrintLevel() == 2 then
        local definitions = type(snapshot.definitions) == 'table' and snapshot.definitions or {}
        local samples = {}
        for _, definition in ipairs(definitions) do
            if tostring(definition.sourceType or '') == 'online' then
                samples[#samples + 1] = ("%s|lookup=%s|id=%s"):format(
                    tostring(definition.name or ''),
                    tostring(definition.lookupName or ''),
                    tostring(definition.raceId or 'nil')
                )
                if #samples >= 5 then
                    break
                end
            end
        end
        logClientVerbose(("Snapshot definitions=%s instances=%s sampleOnline=[%s]"):format(
            tostring(#definitions),
            tostring(#(type(snapshot.instances) == 'table' and snapshot.instances or {})),
            (#samples > 0 and table.concat(samples, '; ') or 'none')
        ))
    end

    local activeCountdowns = {}
    local snapshotInstances = type(snapshot.instances) == 'table' and snapshot.instances or {}
    for _, instance in ipairs(snapshotInstances) do
        local instanceId = tonumber(instance.id)
        if instanceId and instance.state == RacingSystem.States.staging and RacingSystem.Client.InRace.countdownEndTimeByInstanceId[instanceId] then
            activeCountdowns[instanceId] = RacingSystem.Client.InRace.countdownEndTimeByInstanceId[instanceId]
        end
    end

    local cdt = RacingSystem.Client.InRace.countdownEndTimeByInstanceId
    for k in pairs(cdt) do cdt[k] = nil end
    for k, v in pairs(activeCountdowns) do cdt[k] = v end
    if not getJoinedRaceInstance() then
        RacingSystem.Client.InRace.localEntrantIdentity.entrantId = nil
    end

    if RacingSystem.Menu.raceMenuInitialized and RacingSystem.Menu.isRaceMenuVisible() then
        RacingSystem.Menu.refreshRaceMenu()
    end

    applyJoinedInstanceTrafficMode()
end)

RegisterNetEvent('racingsystem:standingsUpdate', function(payload)
    if type(payload) ~= 'table' then
        return
    end

    local instanceId = tonumber(payload.instanceId)
    if not instanceId then
        return
    end

    local incomingVersion = math.max(0, math.floor(tonumber(payload.standingsVersion) or 0))
    local latestVersion = math.max(0, math.floor(tonumber(latestStandingsVersionByInstanceId[instanceId]) or 0))
    if incomingVersion > 0 and incomingVersion <= latestVersion then
        if getClientExtraPrintLevel() == 2 then
            logClientVerbose(("Ignored stale standings instanceId=%s incoming=%s latest=%s"):format(
                tostring(instanceId),
                tostring(incomingVersion),
                tostring(latestVersion)
            ))
        end
        return
    end

    if incomingVersion > 0 then
        latestStandingsVersionByInstanceId[instanceId] = incomingVersion
    end

    local entrants = type(payload.entrants) == 'table' and payload.entrants or {}
    local authoritativeEntrants = {}
    for _, entrant in ipairs(entrants) do
        local cloned = cloneEntrantRow(entrant)
        if cloned then
            authoritativeEntrants[#authoritativeEntrants + 1] = cloned
        end
    end
    latestStandingsByInstanceId[instanceId] = authoritativeEntrants

    local snapshotInstances = type(latestSnapshot.instances) == 'table' and latestSnapshot.instances or {}
    for _, instance in ipairs(snapshotInstances) do
        if tonumber(instance.id) == instanceId then
            instance.entrants = authoritativeEntrants
            break
        end
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

    RacingSystem.Client.InRace.ensureLocalRaceTiming(instanceId)
    RacingSystem.Client.InRace.countdownEndTimeByInstanceId[instanceId] = GetGameTimer() + countdownMs
    RacingSystem.Client.InRace.countdownZeroReportedByInstanceId[instanceId] = nil
    RacingSystem.Client.InRace.raceStartCueShownByInstanceId[instanceId] = nil
    RacingSystem.Client.InRace.finishCueShownByInstanceId[instanceId] = nil
    RacingSystem.Client.InRace.raceTimingState.raceStartedAt = RacingSystem.Client.InRace.countdownEndTimeByInstanceId[instanceId]
    RacingSystem.Client.InRace.raceTimingState.lapStartedAt = RacingSystem.Client.InRace.countdownEndTimeByInstanceId[instanceId]

    -- Refresh menu if visible (state changed from idle to staging)
    if RacingSystem.Menu.isRaceMenuVisible() then
        RacingSystem.Menu.refreshRaceMenu()
    end
end)

RegisterNetEvent('racingsystem:lapCompleted', function(payload)
    if type(payload) ~= 'table' then
        return
    end

    local instance = getJoinedRaceInstance()
    local localEntrant = getLocalEntrant(instance)
    local localEntrantId = normalizeEntrantId(localEntrant and localEntrant.entrantId)
    local payloadEntrantId = normalizeEntrantId(payload.entrantId)

    if localEntrantId and payloadEntrantId then
        if payloadEntrantId ~= localEntrantId then
            return
        end
    else
        local localServerId = tonumber(GetPlayerServerId(PlayerId())) or 0
        local lapOwnerSource = tonumber(payload.playerSource) or 0
        if lapOwnerSource ~= localServerId then
            return
        end
    end

    if payload.finished == true then
        local finishPosition = math.max(1, math.floor(tonumber(localEntrant and localEntrant.position) or 1))
        local finishOrdinal = ('%dº'):format(finishPosition)
        local instanceId = tonumber(instance and instance.id)
        if instanceId then
            if RacingSystem.Client.InRace.finishCueShownByInstanceId[instanceId] then
                return
            end
            RacingSystem.Client.InRace.finishCueShownByInstanceId[instanceId] = true
        end
        ScaleformUI.Scaleforms.BigMessageInstance:ShowMissionPassedMessage(('FINISHED  %s'):format(finishOrdinal), 6000)
    else
        local lapNumber = math.max(1, math.floor(tonumber(payload.lapNumber) or 1))
        local totalLaps = math.max(1, math.floor(tonumber(payload.totalLaps) or tonumber(instance and instance.laps) or 1))
        if totalLaps > 1 and lapNumber == totalLaps - 1 then
            ScaleformUI.Scaleforms.BigMessageInstance:ShowSimpleShard("FINAL LAP", "", 2500)
        else
            RacingSystem.Client.Util.ShowRaceEventVisual(('~b~LAP %d COMPLETED'):format(lapNumber), '', 1400)
        end
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

RegisterNetEvent('racingsystem:lapTimeAnnotation', function(payload)
    if type(payload) ~= 'table' then
        return
    end

    if payload.isInstanceBest then
        RacingSystem.Client.Util.NotifyPlayer('~g~Instance best')
    else
        local deltaMs = tonumber(payload.deltaMs) or 0
        local sign = deltaMs >= 0 and '+' or '-'
        RacingSystem.Client.Util.NotifyPlayer('~r~' .. sign .. RacingSystem.Client.InRace.formatLapTime(math.abs(deltaMs)) .. ' off best')
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

local function resolveTeleportHeading(payload)
    local heading = tonumber(payload and payload.heading)
    if heading ~= nil then
        return heading
    end

    local joinedInstance = getJoinedRaceInstance()
    local checkpoints = type(joinedInstance) == 'table' and type(joinedInstance.checkpoints) == 'table' and joinedInstance.checkpoints or {}
    local checkpointCount = #checkpoints
    local checkpointIndex = math.max(1, math.min(checkpointCount, math.floor(tonumber(payload and payload.checkpointIndex) or 1)))
    if checkpointCount <= 0 then
        return 0.0
    end

    local targetVariant = getCheckpointVariantEntry(joinedInstance, checkpointIndex)
    local targetCheckpoint = targetVariant and targetVariant.primary or checkpoints[checkpointIndex]
    local previousIndex = checkpointIndex - 1
    if previousIndex < 1 then
        -- If previous checkpoint is not in-range, use the last checkpoint in the list.
        previousIndex = checkpointCount
    end
    local previousVariant = getCheckpointVariantEntry(joinedInstance, previousIndex)
    local previousCheckpoint = previousVariant and previousVariant.primary or checkpoints[previousIndex]
    if type(previousCheckpoint) == 'table' and type(targetCheckpoint) == 'table' then
        return getVehicleHeadingToNextCheckpoint(previousCheckpoint, targetCheckpoint)
    end

    return 0.0
end

local function runSmartJoinTeleport(payload)
    if type(payload) ~= 'table' then
        return
    end

    if isTeleportInProgress then
        return
    end
    isTeleportInProgress = true

    local didFadeOut = false
    local destinationX = tonumber(payload.x) or 0.0
    local destinationY = tonumber(payload.y) or 0.0
    local destinationZ = tonumber(payload.z) or 0.0
    local heading = resolveTeleportHeading(payload)
    local teleportType = tostring(payload.teleportType or 'join')
    local checkpointSpeedMph = math.max(0.0, tonumber(payload.speedMph) or 15.0)
    local checkpointSpeedMps = checkpointSpeedMph * 0.44704
    local fadeOutMs = 650
    local fadeInMs = 650
    local fadeTimeoutMs = 2500
    local pollIntervalMs = 75

    local ok, _ = pcall(function()
        if teleportType == 'join' then
            local joinedInstance = getJoinedRaceInstance()
            local entrants = type(joinedInstance) == 'table' and type(joinedInstance.entrants) == 'table' and joinedInstance.entrants or {}
            local checkpoints = type(joinedInstance) == 'table' and type(joinedInstance.checkpoints) == 'table' and joinedInstance.checkpoints or {}
            local checkpointCount = #checkpoints
            local localSource = tonumber(GetPlayerServerId(PlayerId())) or 0
            local slot = math.max(1, #entrants)
            local localEntrant = getLocalEntrant(joinedInstance)
            local checkpointIndex = math.max(1, math.min(checkpointCount, math.floor(tonumber(payload and payload.checkpointIndex) or 1)))

            if type(localEntrant) == 'table' then
                local positionSlot = math.floor(tonumber(localEntrant.position) or 0)
                if positionSlot > 0 then
                    slot = positionSlot
                else
                    for index, entrant in ipairs(entrants) do
                        if tonumber(entrant and entrant.source) == localSource then
                            slot = index
                            break
                        end
                    end
                end
            end

            if checkpointCount > 0 then
                local currentVariant = getCheckpointVariantEntry(joinedInstance, checkpointIndex)
                local currentCheckpoint = currentVariant and currentVariant.primary or checkpoints[checkpointIndex]
                local previousIndex = checkpointIndex - 1
                if previousIndex < 1 then previousIndex = checkpointCount end
                local previousVariant = getCheckpointVariantEntry(joinedInstance, previousIndex)
                local previousCheckpoint = previousVariant and previousVariant.primary or checkpoints[previousIndex]
                local currentX = tonumber(currentCheckpoint and currentCheckpoint.x) or destinationX
                local currentY = tonumber(currentCheckpoint and currentCheckpoint.y) or destinationY
                local prevX = tonumber(previousCheckpoint and previousCheckpoint.x) or currentX
                local prevY = tonumber(previousCheckpoint and previousCheckpoint.y) or currentY
                local forwardX = currentX - prevX
                local forwardY = currentY - prevY
                local forwardLength = math.sqrt((forwardX * forwardX) + (forwardY * forwardY))

                if forwardLength > 0.001 then
                    forwardX = forwardX / forwardLength
                    forwardY = forwardY / forwardLength
                    local rightX = forwardY
                    local rightY = -forwardX
                    local sideMeters = math.max(2.0, ((tonumber(previousCheckpoint and previousCheckpoint.radius) or 8.0) * 0.5) - 2.0)
                    local behindMeters = 5.0 * slot
                    local sideSign = (slot % 2 == 0) and 1.0 or -1.0

                    destinationX = currentX - (forwardX * behindMeters) + (rightX * sideMeters * sideSign)
                    destinationY = currentY - (forwardY * behindMeters) + (rightY * sideMeters * sideSign)
                end
            end
        end

        local ped = PlayerPedId()
        if not DoesEntityExist(ped) then
            return
        end

        local vehicle = GetVehiclePedIsIn(ped, false)
        local isDriverVehicle = vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped

        if not IsScreenFadedOut() then
            DoScreenFadeOut(fadeOutMs)
            waitForFadeState(true, fadeTimeoutMs, pollIntervalMs)
        end
        didFadeOut = true

        local targetZ = destinationZ

        if isDriverVehicle and DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == ped then
            SetEntityCoordsNoOffset(vehicle, destinationX, destinationY, targetZ, false, false, false)
            SetEntityHeading(vehicle, heading)
            SetVehicleOnGroundProperly(vehicle)
            SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)
            if teleportType == 'checkpoint' then
                SetVehicleForwardSpeed(vehicle, checkpointSpeedMps)
            else
                SetVehicleForwardSpeed(vehicle, 0.0)
            end
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

    if didFadeOut then
        if not IsScreenFadedIn() then
            DoScreenFadeIn(fadeInMs)
            waitForFadeState(false, fadeTimeoutMs, pollIntervalMs)
        end
    end

    if not ok then
    end

    isTeleportInProgress = false
end

local function runSmartJoinTeleportLerp(payload)
    if type(payload) ~= 'table' then
        return
    end

    if isTeleportInProgress then
        return
    end
    isTeleportInProgress = true

    local controlledEntity = 0
    local pedToUnfreeze = 0

    local ok, _ = pcall(function()
        local destinationX = tonumber(payload.x) or 0.0
        local destinationY = tonumber(payload.y) or 0.0
        local destinationZ = tonumber(payload.z) or 0.0
        local heading = resolveTeleportHeading(payload)
        local teleportType = tostring(payload.teleportType or 'join')
        local checkpointSpeedMph = math.max(0.0, tonumber(payload.speedMph) or 15.0)
        local checkpointSpeedMps = checkpointSpeedMph * 0.44704
        local closeEnoughMeters = math.max(0.1, tonumber(payload.closeEnoughMeters) or 3.0)
        local lerpFactorPerSecond = math.max(0.01, tonumber(payload.lerpFactorPerSecond) or 0.25)

        local ped = PlayerPedId()
        if not DoesEntityExist(ped) then
            return
        end

        local vehicle = GetVehiclePedIsIn(ped, false)
        local isDriverVehicle = vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped
        local entity = (isDriverVehicle and DoesEntityExist(vehicle)) and vehicle or ped
        if not DoesEntityExist(entity) then
            return
        end

        controlledEntity = entity
        if entity ~= ped and DoesEntityExist(ped) then
            pedToUnfreeze = ped
        end

        FreezeEntityPosition(entity, true)
        if pedToUnfreeze ~= 0 then
            FreezeEntityPosition(pedToUnfreeze, true)
        end

        SetEntityVelocity(entity, 0.0, 0.0, 0.0)
        if isDriverVehicle then
            SetVehicleForwardSpeed(vehicle, 0.0)
        end

        while true do
            local current = GetEntityCoords(entity)
            local dx = destinationX - (tonumber(current.x) or 0.0)
            local dy = destinationY - (tonumber(current.y) or 0.0)
            local distance = math.sqrt((dx * dx) + (dy * dy))
            if distance <= closeEnoughMeters then
                break
            end

            local alpha = lerpFactorPerSecond * math.max(0.0, tonumber(GetFrameTime()) or 0.0)
            if alpha < 0.001 then
                alpha = 0.001
            elseif alpha > 1.0 then
                alpha = 1.0
            end

            local stepX = (tonumber(current.x) or 0.0) + (dx * alpha)
            local stepY = (tonumber(current.y) or 0.0) + (dy * alpha)
            local stepZ = destinationZ
            local currentHeading = tonumber(GetEntityHeading(entity)) or 0.0
            local headingDelta = ((heading - currentHeading + 540.0) % 360.0) - 180.0
            local stepHeading = currentHeading + (headingDelta * alpha)
            if stepHeading < 0.0 then
                stepHeading = stepHeading + 360.0
            elseif stepHeading >= 360.0 then
                stepHeading = stepHeading - 360.0
            end

            SetEntityCoordsNoOffset(entity, stepX, stepY, stepZ, false, false, false)
            SetEntityHeading(entity, stepHeading)
            Wait(0)
        end

        SetEntityCoordsNoOffset(entity, destinationX, destinationY, destinationZ, false, false, false)
        SetEntityHeading(entity, heading)
        SetEntityVelocity(entity, 0.0, 0.0, 0.0)

        if isDriverVehicle then
            if teleportType == 'checkpoint' then
                SetVehicleForwardSpeed(vehicle, checkpointSpeedMps)
            else
                SetVehicleForwardSpeed(vehicle, 0.0)
            end
            SetVehicleHandbrake(vehicle, false)
            SetVehicleUndriveable(vehicle, false)
            SetVehicleEngineOn(vehicle, true, true, false)
            SetVehicleBrakeLights(vehicle, false)
        else
            ClearPedTasks(ped)
        end
    end)

    if controlledEntity ~= 0 and DoesEntityExist(controlledEntity) then
        FreezeEntityPosition(controlledEntity, false)
    end
    if pedToUnfreeze ~= 0 and DoesEntityExist(pedToUnfreeze) then
        FreezeEntityPosition(pedToUnfreeze, false)
    end
    SetPlayerControl(PlayerId(), true, 0)

    if not ok then
    end

    isTeleportInProgress = false
end

local function buildCheckpointTeleportPayload(checkpoint, nextCheckpoint)
    if type(checkpoint) ~= 'table' then
        return nil
    end

    local checkpointIndex = math.max(1, math.floor(tonumber(checkpoint.index) or 1))

    local payload = {
        checkpointIndex = checkpointIndex,
        x = tonumber(checkpoint.x) or 0.0,
        y = tonumber(checkpoint.y) or 0.0,
        z = (tonumber(checkpoint.z) or 0.0) + 1.0,
        teleportType = 'checkpoint',
        speedMph = 15.0,
    }

    return payload
end

local function getEntrantTargetDistanceToCheckpoint(instance, entrant, checkpointIndex)
    if type(instance) ~= 'table' or type(entrant) ~= 'table' then
        return math.huge
    end

    local checkpoints = type(instance.checkpoints) == 'table' and instance.checkpoints or {}
    local totalCheckpoints = #checkpoints
    if totalCheckpoints <= 0 then
        return math.huge
    end

    local targetIndex = math.max(1, math.min(totalCheckpoints, math.floor(tonumber(checkpointIndex) or 1)))
    local variantEntry = getCheckpointVariantEntry(instance, targetIndex)
    local checkpoint = variantEntry and variantEntry.primary or checkpoints[targetIndex]
    if type(checkpoint) ~= 'table' then
        return math.huge
    end

    local source = tonumber(entrant.source) or 0
    if source <= 0 then
        return math.huge
    end

    local localSource = tonumber(GetPlayerServerId(PlayerId())) or 0
    local ped = nil
    if source == localSource then
        ped = PlayerPedId()
    else
        local player = GetPlayerFromServerId(source)
        if player and player ~= -1 then
            ped = GetPlayerPed(player)
        end
    end

    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return math.huge
    end

    local coords = GetEntityCoords(ped)
    local dx = (tonumber(coords.x) or 0.0) - (tonumber(checkpoint.x) or 0.0)
    local dy = (tonumber(coords.y) or 0.0) - (tonumber(checkpoint.y) or 0.0)
    local dz = (tonumber(coords.z) or 0.0) - (tonumber(checkpoint.z) or 0.0)
    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

local function buildLiveLeaderboardRows(instance)
    local entrants = type(instance) == 'table' and type(instance.entrants) == 'table' and instance.entrants or {}
    if #entrants == 0 then
        return {}
    end

    local localEntrant = getLocalEntrant(instance)
    local localEntrantId = normalizeEntrantId(localEntrant and localEntrant.entrantId)
    local localServerId = tonumber(GetPlayerServerId(PlayerId())) or 0
    local entries = {}
    local rows = {}

    for index, entrant in ipairs(entrants) do
        local entrantSource = tonumber(entrant.source) or 0
        local entrantId = normalizeEntrantId(entrant.entrantId)
        local position = math.max(1, math.floor(tonumber(entrant.position) or index))
        local entrantName = tostring(entrant.name or ('Player %s'):format(entrantSource > 0 and entrantSource or position))
        local label = entrantName

        local isLocalEntrant = false
        if localEntrantId and entrantId then
            isLocalEntrant = entrantId == localEntrantId
        else
            isLocalEntrant = entrantSource == localServerId
        end

        if isLocalEntrant then
            label = ('%s (You)'):format(entrantName)
        end

        local checkpointIndex = math.max(1, math.floor(tonumber(entrant.currentCheckpoint) or 1))
        local lap = math.max(1, math.floor(tonumber(entrant.currentLap) or 1))
        entries[#entries + 1] = {
            key = tostring(entrantId or (entrantSource > 0 and entrantSource or position)),
            label = label,
            basePosition = position,
            sourceOrder = index,
            checkpointIndex = checkpointIndex,
            lap = lap,
            tieBreakDistance = getEntrantTargetDistanceToCheckpoint(instance, entrant, checkpointIndex),
            finishedAt = tonumber(entrant.finishedAt),
        }
    end

    if LEADERBOARD_CLIENT_TIEBREAK_ENABLED then
        table.sort(entries, function(a, b)
            if a.basePosition ~= b.basePosition then
                return a.basePosition < b.basePosition
            end

            local sameProgress = a.checkpointIndex == b.checkpointIndex and a.lap == b.lap
            if sameProgress then
                local aDistance = tonumber(a.tieBreakDistance) or math.huge
                local bDistance = tonumber(b.tieBreakDistance) or math.huge
                if aDistance ~= bDistance then
                    return aDistance < bDistance
                end
            end

            return a.sourceOrder < b.sourceOrder
        end)
    end

    for index, entry in ipairs(entries) do
        local displayPosition = LEADERBOARD_CLIENT_TIEBREAK_ENABLED and index or entry.basePosition
        rows[#rows + 1] = {
            key = entry.key,
            text = ('%dº %s'):format(displayPosition, entry.label),
            rank = displayPosition,
            finalized = entry.finishedAt ~= nil,
        }
    end

    return rows
end
RacingSystem.Client.buildLiveLeaderboardRows = buildLiveLeaderboardRows

local function runSmartCheckpointTeleport(checkpoint, nextCheckpoint)
    local payload = buildCheckpointTeleportPayload(checkpoint, nextCheckpoint)
    if type(payload) ~= 'table' then
        return
    end

    runSmartJoinTeleport(payload)
end
RacingSystem.Client.runSmartCheckpointTeleport = runSmartCheckpointTeleport

RegisterNetEvent('racingsystem:teleportToCheckpoint', function(payload)
    Citizen.CreateThread(function()
        runSmartJoinTeleport(payload)
    end)
end)

-- Local-only event: triggered by menu via TriggerEvent, never sent from server.
AddEventHandler('racingsystem:resetToLastCheckpoint', function()
    local joinedInstance = getJoinedRaceInstance()
    if not joinedInstance or joinedInstance.state ~= RacingSystem.States.running then
        return
    end

    local entrant = getLocalEntrant(joinedInstance)
    if not entrant then
        return
    end

    local entrantProgress = RacingSystem.Client.InRace.getEffectiveEntrantProgress(joinedInstance, entrant)
    local lastCheckpoint, nextCheckpoint = RacingSystem.Client.InRace.resolveLastPassedCheckpointTarget(joinedInstance, entrantProgress)
    if type(lastCheckpoint) ~= 'table' then
        return
    end

    TriggerEvent('racingsystem:smartCheckpointTeleport', {
        checkpoint = lastCheckpoint,
        nextCheckpoint = nextCheckpoint,
        preserveVelocity = false
    })
end)

-- Local-only event: triggered by menu via TriggerEvent. Pre-validates locally for UX, then forwards to server.
AddEventHandler('racingsystem:startRace', function()
    local joinedInstance = getJoinedRaceInstance()
    if not joinedInstance then
        return
    end

    if joinedInstance.state == RacingSystem.States.staging then
        return
    end

    if joinedInstance.state ~= RacingSystem.States.idle then
        return
    end

    local entrant = getLocalEntrant(joinedInstance)
    if not entrant then
        return
    end

    if joinedInstance.owner ~= GetPlayerServerId(PlayerId()) then
        return
    end

    if #(joinedInstance.entrants or {}) == 0 then
        return
    end

    TriggerServerEvent('racingsystem:startRace')
end)

-- Local-only event: triggered by menu via TriggerEvent. Cleans up client state immediately, then notifies server.
AddEventHandler('racingsystem:leaveRace', function()
    local joinedInstance = getJoinedRaceInstance()
    if not joinedInstance then
        return
    end

    -- Immediate client side cleanup
    RacingSystem.Client.InRace.localEntrantIdentity.entrantId = nil
    getRaceRuntimeState().pendingCheckpointPass = nil
    getRaceRuntimeState().checkpointPassArm = nil
    do local t = RacingSystem.Client.InRace.finishCueShownByInstanceId; for k in pairs(t) do t[k] = nil end end

    RacingSystem.Client.InRace.clearPredictedRaceProgress()
    RacingSystem.Client.InRace.resetLocalRaceTiming()
    clearFutureCheckpointBlips()
    clearStartLineBlip()
    clearCornerCones()
    RacingSystem.Client.Util.ClearCountdownVisual()
    RacingSystem.Client.Util.ClearRaceLeaderboardVisual()
    currentTrafficDensity = nil
    TriggerServerEvent('traffic_control:requestDensity', nil, 'racingsystem_clear', RACE_TRAFFIC_REQUEST_KEY)

    -- Async notify server
    TriggerServerEvent('racingsystem:leaveRace')

    MenuHandler:CloseAndClearHistory()
end)

-- Local-only event: pure client teleport, triggered via TriggerEvent, never sent from server.
AddEventHandler('racingsystem:smartCheckpointTeleport', function(payload)
    Citizen.CreateThread(function()
        local checkpoint = type(payload) == 'table' and payload.checkpoint or nil
        local nextCheckpoint = type(payload) == 'table' and payload.nextCheckpoint or nil
        runSmartCheckpointTeleport(checkpoint, nextCheckpoint)
    end)
end)

RegisterNUICallback('racingsystem:gtAoRaceUrlSubmit', function(data, cb)
    closeGTAORaceUrlPrompt()
    cb({})

    local typedValue = type(data) == 'table' and data.value or ''
    local ugcId = extractGTAOUGCIdFromInput(typedValue)
    if not ugcId then
        RacingSystem.Client.Util.ShowWarningSubtitle('Could not parse a GTAO race ID from that URL.', 2500, '~o~')
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
        RacingSystem.Client.Util.ShowWarningSubtitle(message, 2500, '~o~')
        return
    end

    local raceName = tostring(payload.raceName or payload.ugcId or '')
    local checkpointCount = tostring(math.max(0, math.floor(tonumber(payload.checkpointCount) or 0)))
    if raceName ~= '' then
        RacingSystem.Menu.pendingSelectRaceName = raceName
    end
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
    RacingSystem.Menu.refreshEditorMenu(RacingSystem.Menu.buildMenuState())
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
    RacingSystem.Menu.refreshEditorMenu(RacingSystem.Menu.buildMenuState())
end)

RegisterNetEvent('racingsystem:raceDefinitionRegistered', function(payload)
    if type(payload) ~= 'table' or payload.ok ~= true then
        return
    end

    local definition = type(payload.definition) == 'table' and payload.definition or {}
    RacingSystem.Menu.pendingSelectRaceName = definition.name or RacingSystem.Menu.pendingSelectRaceName
    RacingSystem.Menu.pendingEditorRaceName = definition.name or RacingSystem.Menu.pendingEditorRaceName
end)

RegisterNetEvent('racingsystem:raceDefinitionDeleted', function(payload)
    RacingSystem.Menu.deleteConfirmRaceName = nil

    if type(payload) ~= 'table' or payload.ok ~= true then
        RacingSystem.Menu.refreshEditorMenu(RacingSystem.Menu.buildMenuState())
        return
    end

    local definition = type(payload.definition) == 'table' and payload.definition or {}
    local deletedName = tostring(definition.name or 'unknown')

    if RacingSystem.NormalizeRaceName(editorState.selectedName) == RacingSystem.NormalizeRaceName(deletedName) then
        editorState.selectedName = ''
    end
end)

CreateThread(function()
    Wait(1500)
    requestRaceStateSnapshot()
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
                    local visualRadius = getVisualCheckpointRadius(checkpoint)

                    DrawMarker(
                        getRouteCheckpointMarkerTypeId(),
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
    local staleThresholdMs = 5000
    local requestCooldownMs = 1500
    while true do
        local joinedInstance = getJoinedRaceInstance()
        local hasActiveCountdown = next(RacingSystem.Client.InRace.countdownEndTimeByInstanceId) ~= nil
        local shouldReconcile = joinedInstance ~= nil or hasActiveCountdown or (RacingSystem.Menu.raceMenuInitialized and RacingSystem.Menu.isRaceMenuVisible())
        if shouldReconcile then
            local now = GetGameTimer()
            local lastAcceptedAt = tonumber(snapshotAcceptedAt) or 0
            local lastRequestedAt = tonumber(snapshotRequestedAt) or 0
            if (now - lastAcceptedAt) >= staleThresholdMs and (now - lastRequestedAt) >= requestCooldownMs then
                logClientVerbose(("Requesting snapshot reconciliation (latestVersion=%s ignoredStale=%s)"):format(
                    tostring(latestSnapshotVersion),
                    tostring(reliabilityCounters.staleSnapshotsIgnored)
                ))
                requestRaceStateSnapshot()
            end
            Wait(1000)
        else
            Wait(1500)
        end
    end
end)

CreateThread(function()
    while true do
        RacingSystem.Client.Util.DrawRaceEventVisual()
        RacingSystem.Client.Util.DrawRaceLeaderboardVisual()
        Wait(0)
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    closeGTAORaceUrlPrompt(true)
    RacingSystem.Client.InRace.localEntrantIdentity.entrantId = nil
    do local t = RacingSystem.Client.InRace.finishCueShownByInstanceId; for k in pairs(t) do t[k] = nil end end

    currentTrafficDensity = nil
    TriggerServerEvent('traffic_control:requestDensity', nil, 'racingsystem_clear', RACE_TRAFFIC_REQUEST_KEY)
    RacingSystem.Client.InRace.clearPowerPenaltyVehicleOverride()
    clearFutureCheckpointBlips()
    clearStartLineBlip()
    clearCornerCones()
    RacingSystem.Client.Util.ClearRaceLeaderboardVisual()
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






RacingSystem.Client.drawIdleStartChevron = drawIdleStartChevron
