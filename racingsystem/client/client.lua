RacingSystem = RacingSystem or {}
RacingSystem.Client = RacingSystem.Client or {}
RacingSystem.Menu = RacingSystem.Menu or {}
RacingSystem.Client.Util = RacingSystem.Client.Util or {}
local raceInfoById = {}
local currentTrafficDensity = nil
local RACE_TRAFFIC_REQUEST_KEY = GetCurrentResourceName()
local ClientAdvancedConfig = (((RacingSystem or {}).Config or {}).advanced or {}).client or {}
local LEADERBOARD_CLIENT_TIEBREAK_ENABLED = ClientAdvancedConfig.leaderboardClientTiebreakEnabled == true
local isGTAORacePromptOpen = false
local instanceAssetCache = {}
RacingSystem.Client.instanceAssetCache = instanceAssetCache
local localMembershipInstanceId = nil
local raceStandings = nil
local raceLeaderboardScoreboard = nil
local activeInstanceAssets = {
    instanceId = nil,
    objects = {},
    modelHides = {},
}
RacingSystem.Client.activeInstanceAssets = activeInstanceAssets
local CHECKPOINT_RUNTIME_Z_OFFSET_METERS = tonumber(ClientAdvancedConfig.checkpointRuntimeZOffsetMeters) or -2.0
local MAX_FUTURE_PREVIEW_CHECKPOINTS = math.max(1, math.floor(tonumber(ClientAdvancedConfig.maxFuturePreviewCheckpoints) or 3))
local MARKER_TAXONOMY = ClientAdvancedConfig.markerTaxonomy or {
    routeCheckpointTypeId = nil,
    routeChevronTypeId = 20,
    startLineIdleTypeId = 4,
    startLineIdleColor = { r = 255, g = 255, b = 255, a = 0 },
    startLineBlipSprite = 38,
}
local CLIENT_EXTRA_PRINT_LEVEL = math.floor(tonumber(ClientAdvancedConfig.extraPrintLevel) or 0)
local ASSET_MODEL_LOAD_TIMEOUT_MS = 5000

local function showStartupVersionNotice()
    local resourceName = GetCurrentResourceName()
    local version = tostring(GetResourceMetadata(resourceName, 'version', 0) or 'unknown')
    local latestChange = tostring(GetResourceMetadata(resourceName, 'latest_change', 0) or '')
    latestChange = (latestChange:match('^%s*(.-)%s*$') or '')

    local message
    if latestChange ~= '' then
        message = ('RacingSystem v%s started. Latest change: %s'):format(version, latestChange)
    else
        message = ('RacingSystem v%s started.'):format(version)
    end

    RacingSystem.Client.Util.NotifyPlayer(message)
end

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
RacingSystem.Client.getRouteCheckpointMarkerTypeId = getRouteCheckpointMarkerTypeId
local function getClientExtraPrintLevel()
    if CLIENT_EXTRA_PRINT_LEVEL == 2 then
        return 2
    end
    return 0
end

local function logClientVerbose(message)
    if getClientExtraPrintLevel() ~= 2 then return end
    print(('[racingsystem:client] %s'):format(tostring(message or '')))
end

RegisterNetEvent('racingsystem:ui:notify', function(payload)
    local message = ''
    if type(payload) == 'table' then
        message = tostring(payload.message or '')
    else
        message = tostring(payload or '')
    end
    if message == '' then return end
    RacingSystem.Client.Util.NotifyPlayer(message)
end)

local function getRuntimeCheckpointMarker(checkpoint)
    local x = tonumber(checkpoint and checkpoint.x) or 0.0
    local y = tonumber(checkpoint and checkpoint.y) or 0.0
    local z = (tonumber(checkpoint and checkpoint.z) or 0.0) + CHECKPOINT_RUNTIME_Z_OFFSET_METERS
    return { x = x, y = y, z = z, dirX = 0.0, dirY = 0.0, dirZ = 0.0, rotX = 0.0, rotY = 0.0, rotZ = 0.0 }
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
RacingSystem.Client.getVisualCheckpointRadius = getVisualCheckpointRadius
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
    local minimumRadius = tonumber(RacingSystem.Config.checkpointRadiusMinMeters) or 2.0
    local maximumRadius = math.max(minimumRadius, tonumber(RacingSystem.Config.checkpointRadiusMaxMeters) or 40.0)
    local radius = tonumber(primaryCheckpoint.radius) or 8.0
    local secondarySizes = metadata and type(metadata.sndsz) == 'table' and metadata.sndsz or nil
    if secondarySizes then
        local size = tonumber(secondarySizes[targetIndex])
        if size and size == size and size > -math.huge and size < math.huge then
            radius = 8.0 * size
        end
    end
    radius = math.max(minimumRadius, math.min(maximumRadius, radius))
    return { index = tonumber(primaryCheckpoint.index) or targetIndex, x = x, y = y, z = z, radius = radius }
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
    return { index = targetIndex, primary = primary, secondary = secondary }
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
RacingSystem.Client.getVehicleHeadingToNextCheckpoint = getVehicleHeadingToNextCheckpoint
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
local function computeCheckpointChevronEdge(checkpoint, prevCheckpoint, nextCheckpoint, instance)
    if type(checkpoint) ~= 'table' then
        return nil
    end
    local currentX = tonumber(checkpoint.x) or 0.0
    local currentY = tonumber(checkpoint.y) or 0.0
    local prevX = tonumber(prevCheckpoint and prevCheckpoint.x) or currentX
    local prevY = tonumber(prevCheckpoint and prevCheckpoint.y) or currentY
    local dirX = currentX - prevX
    local dirY = currentY - prevY
    local dirLength = math.sqrt((dirX * dirX) + (dirY * dirY))
    local radius = getCheckpointPassRadius(checkpoint, instance) * 0.4
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
local function drawCheckpointTarget(checkpoint, prevCheckpoint, nextCheckpoint, isStart, isFinish, markerColor, chevronColor, chevronEdge, renderAsCheckeredFlag, markerHeightOverride, instance)
    if type(checkpoint) ~= 'table' then return end
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
    if type(nextCheckpoint) ~= 'table' then return end
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
    if toNextLength <= 0.001 then return end
    local aimX = toNextX / toNextLength
    local aimY = toNextY / toNextLength
    local edgeRadius = getCheckpointPassRadius(checkpoint, instance)
    local chevronZ = currentZ + 2.35
    local chevronSize = math.max(1.2, math.min(2.2, edgeRadius * 0.18))
    local resolvedChevronColor = type(chevronColor) == 'table'
        and chevronColor
        or { r = 255, g = 140, b = 0, a = 242 }
    local mainChevronAlpha = tonumber(resolvedChevronColor.a) or 242
    local edge = type(chevronEdge) == 'table' and chevronEdge or computeCheckpointChevronEdge(checkpoint, prevCheckpoint, nextCheckpoint, instance)
    if type(edge) ~= 'table' then return end
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
            rotationX,
            0.0,
            chevronRotationZ,
            chevronSize,
            chevronSize,
            chevronSize,
            tonumber(resolvedChevronColor.r) or 255,
            tonumber(resolvedChevronColor.g) or 140,
            tonumber(resolvedChevronColor.b) or 0,
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
    drawRouteChevronAt(edgeX, edgeY, false)
    return
end
RacingSystem.Client.drawCheckpointTarget = drawCheckpointTarget
local function drawIdleStartChevron(checkpoint)
    if type(checkpoint) ~= 'table' then return end
    local markerDraw = getRuntimeCheckpointMarker(checkpoint)
    local baseRadius = tonumber(checkpoint.radius) or 8.0
    local flagScale = math.max(1.2, math.min(2.6, baseRadius * 0.2)) * 3.0
    local drawZ = (tonumber(checkpoint.z) or markerDraw.z) + 5.0
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
        230,
        false,
        false,
        2,
        false,
        nil,
        nil,
        false
    )
end

local function clearStartLineBlip()
    local blip = getRaceRuntimeState().startLineBlip
    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
    getRaceRuntimeState().startLineBlip = nil
end
RacingSystem.Client.clearStartLineBlip = clearStartLineBlip
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
    return checkpointCount
end
RacingSystem.Client.getClientRaceStartCheckpoint = getClientRaceStartCheckpoint
local function getClientLapTriggerCheckpoint(totalCheckpoints)
    local checkpointCount = math.max(0, math.floor(tonumber(totalCheckpoints) or 0))
    if checkpointCount <= 1 then
        return 1
    end
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

local checkpointBlipsByInstanceId = {}
local activeCheckpointBlipsInstanceId = nil

local function clearCheckpointBlips(instanceId)
    local numericId = tonumber(instanceId) or activeCheckpointBlipsInstanceId
    if not numericId then return end
    local blips = checkpointBlipsByInstanceId[numericId]
    if type(blips) ~= 'table' then
        checkpointBlipsByInstanceId[numericId] = nil
        if numericId == activeCheckpointBlipsInstanceId then
            activeCheckpointBlipsInstanceId = nil
        end
        return
    end
    for _, blip in ipairs(blips) do
        if blip and DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    checkpointBlipsByInstanceId[numericId] = nil
    if numericId == activeCheckpointBlipsInstanceId then
        activeCheckpointBlipsInstanceId = nil
    end
end
RacingSystem.Client.clearCheckpointBlips = clearCheckpointBlips

local function updateCheckpointBlips(instance, currentCheckpoint, totalLaps, currentLap)
    if type(instance) ~= 'table' then
        clearCheckpointBlips(instance and instance.id)
        return
    end
    local instanceId = tonumber(instance.id)
    if not instanceId then return end
    local checkpoints = type(instance.checkpoints) == 'table' and instance.checkpoints or {}
    local totalCheckpoints = #checkpoints
    if totalCheckpoints <= 0 then
        clearCheckpointBlips(instanceId)
        return
    end
    local targetIndex = math.max(1, math.floor(tonumber(currentCheckpoint) or 1))
    local lapNumber = math.max(1, math.floor(tonumber(currentLap) or 1))
    local maxLaps = math.max(1, math.floor(tonumber(totalLaps) or 1))
    local isFinalLap = lapNumber >= maxLaps
    local isPointToPoint = instance.pointToPoint == true
    local blips = checkpointBlipsByInstanceId[instanceId]
    if type(blips) ~= 'table' or #blips ~= totalCheckpoints then
        clearCheckpointBlips(instanceId)
        blips = {}
        checkpointBlipsByInstanceId[instanceId] = blips
        activeCheckpointBlipsInstanceId = instanceId
        for i = 1, totalCheckpoints do
            local cp = checkpoints[i]
            if type(cp) == 'table' then
                local x = tonumber(cp.x) or 0.0
                local y = tonumber(cp.y) or 0.0
                local z = tonumber(cp.z) or 0.0
                local blip = AddBlipForCoord(x, y, z)
                blips[i] = blip
                SetBlipDisplay(blip, 4)
                SetBlipScale(blip, 0.65)
                SetBlipAsShortRange(blip, true)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(('CP %s'):format(tostring(i)))
                EndTextCommandSetBlipName(blip)
            else
                blips[i] = nil
            end
        end
    end
    local nextIndex = targetIndex + 1
    if nextIndex > totalCheckpoints then nextIndex = 1 end
    if isPointToPoint and targetIndex >= totalCheckpoints then nextIndex = targetIndex end
    for i = 1, totalCheckpoints do
        local blip = blips[i]
        if blip and DoesBlipExist(blip) then
            local isCurrentOrNext = (i == targetIndex or i == nextIndex)
            SetBlipAsShortRange(blip, not isCurrentOrNext)
            local isFinishCp = isPointToPoint and i == totalCheckpoints
            if i < targetIndex then
                SetBlipSprite(blip, 1)
                SetBlipColour(blip, 4)
                SetBlipAlpha(blip, 120)
            elseif i == targetIndex then
                if isFinishCp and isFinalLap then
                    SetBlipSprite(blip, 38)
                    SetBlipColour(blip, 0)
                else
                    SetBlipSprite(blip, 1)
                    SetBlipColour(blip, 0)
                end
                SetBlipAlpha(blip, 255)
            else
                if isFinishCp and isFinalLap then
                    SetBlipSprite(blip, 38)
                    SetBlipColour(blip, 0)
                else
                    SetBlipSprite(blip, 1)
                    SetBlipColour(blip, 3)
                end
                SetBlipAlpha(blip, 180)
            end
        end
    end
end
RacingSystem.Client.updateCheckpointBlips = updateCheckpointBlips
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

local function getLocalRaceMembershipFromStateBag()
    if type(LocalPlayer) ~= 'table' or type(LocalPlayer.state) ~= 'table' then
        return nil, nil
    end
    local state = LocalPlayer.state
    local instanceId = tonumber(state['rs:instanceId'])
    if not instanceId or instanceId <= 0 then
        return nil, nil
    end
    return instanceId, normalizeEntrantId(state['rs:entrantId'])
end
local getJoinedRaceInstance
local function parsePlayerSourceFromStateBagName(bagName)
    if type(bagName) ~= 'string' or bagName:sub(1, 7) ~= 'player:' then
        return nil
    end
    local numericSource = tonumber(bagName:sub(8))
    if not numericSource or numericSource <= 0 then
        return nil
    end
    return numericSource
end

local function getPlayerStateBagValueBySource(source, key)
    local numericSource = tonumber(source) or 0
    if numericSource <= 0 then
        return nil
    end
    local player = Player(numericSource)
    if not player or not player.state then
        return nil
    end
    return player.state[key]
end

local function resolveEntrantNameBySource(source)
    local numericSource = tonumber(source) or 0
    local playerId = GetPlayerFromServerId(numericSource)
    if playerId and playerId ~= -1 then
        return GetPlayerName(playerId) or ('Player %s'):format(tostring(numericSource))
    end
    return ('Player %s'):format(tostring(numericSource))
end

local function removeEntrantFromAllRaceInfoBySource(source)
    local numericSource = tonumber(source) or 0
    if numericSource <= 0 then return end
    for _, raceInfo in pairs(raceInfoById) do
        local participants = type(raceInfo) == 'table' and type(raceInfo.Participants) == 'table' and raceInfo.Participants or nil
        local entrants = participants and type(participants.entrants) == 'table' and participants.entrants or nil
        if entrants then
            for index = #entrants, 1, -1 do
                if tonumber(entrants[index] and entrants[index].source) == numericSource then
                    table.remove(entrants, index)
                end
            end
        end
    end
end

local function ensureRaceInfoEntrantBySource(instanceId, source)
    local numericInstanceId = tonumber(instanceId) or 0
    local numericSource = tonumber(source) or 0
    if numericInstanceId <= 0 or numericSource <= 0 then
        return nil
    end
    local raceInfo = type(raceInfoById[numericInstanceId]) == 'table' and raceInfoById[numericInstanceId] or nil
    if not raceInfo then
        return nil
    end
    local participants = type(raceInfo.Participants) == 'table' and raceInfo.Participants or {}
    raceInfo.Participants = participants
    local entrants = type(participants.entrants) == 'table' and participants.entrants or {}
    participants.entrants = entrants
    for _, entrant in ipairs(entrants) do
        if tonumber(entrant and entrant.source) == numericSource then
            return entrant
        end
    end
    local entrant = {
        source = numericSource,
        name = resolveEntrantNameBySource(numericSource),
        entrantId = tostring(getPlayerStateBagValueBySource(numericSource, 'rs:entrantId') or ''),
        position = tonumber(getPlayerStateBagValueBySource(numericSource, 'rs:position')) or nil,
        currentLap = tonumber(getPlayerStateBagValueBySource(numericSource, 'rs:currentLap')) or 1,
        currentCheckpoint = tonumber(getPlayerStateBagValueBySource(numericSource, 'rs:currentCheckpoint')) or 1,
        finishedAt = tonumber(getPlayerStateBagValueBySource(numericSource, 'rs:finishedAt')) or nil,
    }
    entrants[#entrants + 1] = entrant
    return entrant
end

local function applyEntrantStateBagField(source, key, value)
    local numericSource = tonumber(source) or 0
    if numericSource <= 0 then return end
    local instanceId = tonumber(getPlayerStateBagValueBySource(numericSource, 'rs:instanceId')) or 0
    if instanceId <= 0 then return end
    local entrant = ensureRaceInfoEntrantBySource(instanceId, numericSource)
    if not entrant then return end
    if key == 'rs:entrantId' then
        entrant.entrantId = tostring(value or '')
    elseif key == 'rs:position' then
        entrant.position = tonumber(value) or nil
    elseif key == 'rs:currentLap' then
        entrant.currentLap = tonumber(value) or 1
    elseif key == 'rs:currentCheckpoint' then
        entrant.currentCheckpoint = tonumber(value) or 1
    elseif key == 'rs:finishedAt' then
        entrant.finishedAt = tonumber(value) or nil
    end
end

local function getCurrentMenuPlayerState()
    if type(RacingSystem.Client.editorState) == 'table' and RacingSystem.Client.editorState.active then
        return 'editing'
    end
    local instance = getJoinedRaceInstance()
    if not instance then
        return 'neutral'
    end
    if instance.state == RacingSystem.States.idle then
        return 'staging'
    elseif instance.state == RacingSystem.States.staging then
        return 'countdown'
    elseif instance.state == RacingSystem.States.running then
        return 'racing'
    elseif instance.state == RacingSystem.States.finished then
        return 'finished'
    end
    return 'neutral'
end

local function applyRaceMenuStageFromCurrentState()
    if type(RacingSystem.Menu) ~= 'table' or type(RacingSystem.Menu.applyRaceStageMenu) ~= 'function' then return end
    RacingSystem.Menu.applyRaceStageMenu(getCurrentMenuPlayerState())
end

local function refreshRaceMenuFromCurrentState(forceRefresh)
    if type(RacingSystem.Menu) ~= 'table'
        or type(RacingSystem.Menu.refreshRaceMenu) ~= 'function'
        or type(RacingSystem.Menu.isRaceMenuVisible) ~= 'function' then
        return
    end
    if not forceRefresh and not RacingSystem.Menu.isRaceMenuVisible() then
        return
    end
    local refreshInstance = getJoinedRaceInstance()
    local refreshInstanceId = tonumber(refreshInstance and refreshInstance.id)
    local refreshPlayerState = getCurrentMenuPlayerState()
    local refreshIsHost = false
    local refreshIsIdleState = false
    local refreshHasEntrants = false
    if type(refreshInstance) == 'table' then
        local refreshOwnerSource = tonumber(refreshInstance.owner)
        local refreshLocalSource = tonumber(GetPlayerServerId(PlayerId())) or 0
        refreshIsHost = refreshOwnerSource ~= nil and refreshOwnerSource > 0 and refreshOwnerSource == refreshLocalSource
        refreshIsIdleState = refreshInstance.state == RacingSystem.States.idle
        refreshHasEntrants = #(refreshInstance.entrants or {}) > 0
        if not refreshHasEntrants and type(RacingSystem.Client.getLocalEntrant) == 'function' then
            refreshHasEntrants = RacingSystem.Client.getLocalEntrant(refreshInstance) ~= nil
        end
    end
    if refreshInstanceId and refreshIsIdleState then
        RacingSystem.Menu.countdownAcceptedByInstanceId[refreshInstanceId] = nil
        if type(RacingSystem.Menu.clearCountdownAccepted) == 'function' then
            RacingSystem.Menu.clearCountdownAccepted(refreshInstanceId)
        end
    end
    local refreshCountdownAccepted = refreshInstanceId and RacingSystem.Menu.countdownAcceptedByInstanceId[refreshInstanceId] == true
    local refreshIsAdmin = type(LocalPlayer) == 'table'
        and type(LocalPlayer.state) == 'table'
        and LocalPlayer.state['rs:isAdmin'] == true
    local catalogViewer = type(RacingSystem.Client.getCatalogViewer) == 'function'
        and RacingSystem.Client.getCatalogViewer()
        or nil
    local ownerKillEnabled = type(catalogViewer) == 'table' and catalogViewer.canKillOwnedInstances == true
    RacingSystem.Menu.refreshRaceMenu({
        canStartCountdown = refreshPlayerState == 'staging' and refreshIsHost and refreshIsIdleState and not refreshCountdownAccepted and refreshHasEntrants,
        canRestart = (refreshPlayerState == 'staging' or refreshPlayerState == 'countdown' or refreshPlayerState == 'finished') and refreshIsHost and refreshHasEntrants,
        canKill = refreshIsAdmin or (ownerKillEnabled and refreshIsHost),
        countdownAccepted = refreshCountdownAccepted == true,
        instanceId = refreshInstanceId,
    })
end
RacingSystem.Menu.refreshRaceMenuFromCurrentState = refreshRaceMenuFromCurrentState
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
    if currentTrafficDensity and math.abs(currentTrafficDensity - targetDensity) < 0.0001 then return end
    currentTrafficDensity = targetDensity
    TriggerServerEvent('traffic_control:requestDensity', targetDensity, 'Traffic control for race', RACE_TRAFFIC_REQUEST_KEY)
end

AddStateBagChangeHandler('rs:instanceId', nil, function(bagName, key, value, _, _)
    local source = parsePlayerSourceFromStateBagName(bagName)
    if not source then return end
    removeEntrantFromAllRaceInfoBySource(source)
    local instanceId = tonumber(value) or 0
    TriggerEvent('racingsystem:membership:changed', source, instanceId)
    if instanceId <= 0 then return end
    ensureRaceInfoEntrantBySource(instanceId, source)
    applyEntrantStateBagField(source, 'rs:entrantId', getPlayerStateBagValueBySource(source, 'rs:entrantId'))
    applyEntrantStateBagField(source, 'rs:position', getPlayerStateBagValueBySource(source, 'rs:position'))
    applyEntrantStateBagField(source, 'rs:currentLap', getPlayerStateBagValueBySource(source, 'rs:currentLap'))
    applyEntrantStateBagField(source, 'rs:currentCheckpoint', getPlayerStateBagValueBySource(source, 'rs:currentCheckpoint'))
    applyEntrantStateBagField(source, 'rs:finishedAt', getPlayerStateBagValueBySource(source, 'rs:finishedAt'))
    applyRaceMenuStageFromCurrentState()
    refreshRaceMenuFromCurrentState()
    applyJoinedInstanceTrafficMode()
end)
AddStateBagChangeHandler('rs:entrantId', nil, function(bagName, key, value, _, _)
    local source = parsePlayerSourceFromStateBagName(bagName)
    if not source then return end
    applyEntrantStateBagField(source, key, value)
end)
AddStateBagChangeHandler('rs:position', nil, function(bagName, key, value, _, _)
    local source = parsePlayerSourceFromStateBagName(bagName)
    if not source then return end
    applyEntrantStateBagField(source, key, value)
end)
AddStateBagChangeHandler('rs:currentLap', nil, function(bagName, key, value, _, _)
    local source = parsePlayerSourceFromStateBagName(bagName)
    if not source then return end
    applyEntrantStateBagField(source, key, value)
end)
AddStateBagChangeHandler('rs:currentCheckpoint', nil, function(bagName, key, value, _, _)
    local source = parsePlayerSourceFromStateBagName(bagName)
    if not source then return end
    applyEntrantStateBagField(source, key, value)
end)
AddStateBagChangeHandler('rs:finishedAt', nil, function(bagName, key, value, _, _)
    local source = parsePlayerSourceFromStateBagName(bagName)
    if not source then return end
    applyEntrantStateBagField(source, key, value)
end)
AddStateBagChangeHandler(nil, 'global', function(_, key, _, _, _)
    if type(key) ~= 'string' or key:sub(1, 13) ~= 'rs:raceState:' then return end
    local changedInstanceId = tonumber(key:sub(14))
    local joinedInstanceId = select(1, getLocalRaceMembershipFromStateBag())
    if not changedInstanceId or not joinedInstanceId or changedInstanceId ~= joinedInstanceId then return end
    applyRaceMenuStageFromCurrentState()
    refreshRaceMenuFromCurrentState()
    applyJoinedInstanceTrafficMode()
end)

local function resolveLocalEntrantEntry(instance)
    if type(instance) ~= 'table' then
        return nil
    end
    local entrants = type(instance.entrants) == 'table' and instance.entrants or {}
    local localServerId = tonumber(GetPlayerServerId(PlayerId())) or 0
    local preferredEntrantId = normalizeEntrantId(RacingSystem.Client.InRace.localEntrantIdentity.entrantId)
    local stateBagInstanceId, stateBagEntrantId = getLocalRaceMembershipFromStateBag()
    if stateBagEntrantId then
        preferredEntrantId = stateBagEntrantId
    end
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
    local instanceId = tonumber(instance.id)
    if stateBagInstanceId and instanceId and stateBagInstanceId == instanceId then
        return {
            entrantId = stateBagEntrantId,
            source = localServerId,
        }
    end
    return nil
end
function getJoinedRaceInstance()
    local stateBagInstanceId, stateBagEntrantId = getLocalRaceMembershipFromStateBag()
    if stateBagInstanceId then
        local localServerId = tonumber(GetPlayerServerId(PlayerId())) or 0
        local raceStateKey = ('rs:raceState:%s'):format(tostring(stateBagInstanceId))
        local raceState = tostring(GlobalState[raceStateKey] or RacingSystem.States.idle)
        local raceInfo = type(raceInfoById[stateBagInstanceId]) == 'table' and raceInfoById[stateBagInstanceId] or {}
        local identity = type(raceInfo.Identity) == 'table' and raceInfo.Identity or {}
        local config = type(raceInfo.Config) == 'table' and raceInfo.Config or {}
        local route = type(raceInfo.Route) == 'table' and raceInfo.Route or {}
        local runtime = type(raceInfo.Runtime) == 'table' and raceInfo.Runtime or {}
        local participants = type(raceInfo.Participants) == 'table' and raceInfo.Participants or {}
        local fallbackEntrant = {
            entrantId = stateBagEntrantId,
            source = localServerId,
        }
        if stateBagEntrantId then
            RacingSystem.Client.InRace.localEntrantIdentity.entrantId = stateBagEntrantId
        end
        return {
            id = stateBagInstanceId,
            name = tostring(identity.name or ''),
            sourceType = identity.sourceType,
            sourceName = identity.sourceName,
            state = raceState,
            owner = tonumber(identity.owner) or localServerId,
            laps = tonumber(config.laps) or 1,
            trafficDensity = tonumber(config.trafficDensity) or 0.0,
            pointToPoint = config.pointToPoint == true,
            checkpoints = type(route.checkpoints) == 'table' and route.checkpoints or {},
            checkpointVariants = type(route.checkpointVariants) == 'table' and route.checkpointVariants or {},
            raceMetadata = type(route.raceMetadata) == 'table' and route.raceMetadata or {},
            entrants = type(participants.entrants) == 'table' and participants.entrants or { fallbackEntrant },
            createdAt = runtime.createdAt,
            invokedAt = runtime.invokedAt,
            startAt = runtime.startAt,
            startedAt = runtime.startedAt,
            finishedAt = runtime.finishedAt,
            bestLapTimeMs = runtime.bestLapTimeMs,
        }
    end
    return nil
end
RacingSystem.Client.getJoinedRaceInstance = getJoinedRaceInstance
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
    if not forceReset and not isGTAORacePromptOpen then return end
    isGTAORacePromptOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'racingsystem:toggleGTAORacePrompt',
        open = false,
    })
end

local function openGTAORaceUrlPrompt()
    if isGTAORacePromptOpen then return end
    isGTAORacePromptOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'racingsystem:toggleGTAORacePrompt',
        open = true,
    })
end

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
local function requestInstanceAssetModel(model, instanceId)
    RequestModel(model)
    local deadline = GetGameTimer() + ASSET_MODEL_LOAD_TIMEOUT_MS
    while not HasModelLoaded(model) do
        if tonumber(localMembershipInstanceId) ~= tonumber(instanceId) then
            return false, 'membership changed'
        end
        if GetGameTimer() >= deadline then
            return false, 'model load timed out'
        end
        Wait(0)
    end
    return true, nil
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
        if model and model ~= 0 and IsModelInCdimage(model) then
            local modelLoaded, loadError = requestInstanceAssetModel(model, activeInstanceAssets.instanceId)
            if not modelLoaded then
                SetModelAsNoLongerNeeded(model)
                logClientVerbose(('Skipped instance asset model %s: %s.'):format(tostring(model), tostring(loadError)))
                if loadError == 'membership changed' then
                    unloadActiveInstanceAssets()
                    return false
                end
                goto continue_prop
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
        ::continue_prop::
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

local function syncJoinedInstanceAssets(instanceId)
    local numericInstanceId = tonumber(instanceId) or 0
    if numericInstanceId <= 0 then
        local previousInstanceId = localMembershipInstanceId
        localMembershipInstanceId = nil
        unloadActiveInstanceAssets()
        if previousInstanceId then
            instanceAssetCache[previousInstanceId] = nil
            raceInfoById[previousInstanceId] = nil
        end
        return
    end

    localMembershipInstanceId = numericInstanceId
    if tonumber(activeInstanceAssets.instanceId) == numericInstanceId then
        return
    end

    local payload = instanceAssetCache[numericInstanceId]
    if type(payload) == 'table' then
        loadInstanceAssets(payload)
    end
end

AddEventHandler('racingsystem:membership:changed', function(source, instanceId)
    local localSource = tonumber(GetPlayerServerId(PlayerId())) or 0
    if tonumber(source) ~= localSource then
        return
    end

    syncJoinedInstanceAssets(instanceId)
    if (tonumber(instanceId) or 0) <= 0 then
        applyRaceMenuStageFromCurrentState()
        refreshRaceMenuFromCurrentState()
        applyJoinedInstanceTrafficMode()
    end
end)

RegisterNetEvent('racingsystem:race:lapCompleted', function(payload)
    if type(payload) ~= 'table' then return end
    local instance = getJoinedRaceInstance()
    local localEntrant = getLocalEntrant(instance)
    local localEntrantId = normalizeEntrantId(localEntrant and localEntrant.entrantId)
    local payloadEntrantId = normalizeEntrantId(payload.entrantId)
    if localEntrantId and payloadEntrantId then
        if payloadEntrantId ~= localEntrantId then return end
    else
        local localServerId = tonumber(GetPlayerServerId(PlayerId())) or 0
        local lapOwnerSource = tonumber(payload.playerSource) or 0
        if lapOwnerSource ~= localServerId then return end
    end

    local lapNumber = math.max(1, math.floor(tonumber(payload.lapNumber) or 1))
    local lapTimeMs = tonumber(payload.lapTimeMs)
    if lapTimeMs then
        RacingSystem.Client.InRace.raceTimingState.lapTimes[lapNumber] = lapTimeMs
    end

    if payload.finished == true then
        if lapTimeMs then
            RacingSystem.Client.Util.NotifyPlayer('~w~' .. RacingSystem.Client.InRace.formatLapTime(lapTimeMs))
        end
        RacingSystem.Client.InRace.raceTimingState.lapStartedAt = nil
        local instanceId = tonumber(instance and instance.id)
        if instanceId then
            if RacingSystem.Client.InRace.finishCueShownByInstanceId[instanceId] then return end
            RacingSystem.Client.InRace.finishCueShownByInstanceId[instanceId] = true
        end
        local finishPosition = math.max(1, math.floor(tonumber(payload.position) or tonumber(localEntrant and localEntrant.position) or 1))
        ScaleformUI.Scaleforms.BigMessageInstance:ShowSimpleShard(
            'FINISHED',
            ('%dº'):format(finishPosition),
            2000,
            false
        )

        -- Show all lap times as notifications
        local lapTimes = RacingSystem.Client.InRace.raceTimingState.lapTimes
        if lapTimes then
            local totalLaps = math.max(1, math.floor(tonumber(payload.totalLaps) or tonumber(instance and instance.laps) or 1))
            for i = 1, totalLaps do
                local t = lapTimes[i]
                if t then
                    RacingSystem.Client.Util.NotifyPlayer(('~w~Lap %d/%d: %s'):format(i, totalLaps, RacingSystem.Client.InRace.formatLapTime(t)))
                end
            end
        end
    else
        if lapTimeMs then
            RacingSystem.Client.Util.NotifyPlayer('~w~' .. RacingSystem.Client.InRace.formatLapTime(lapTimeMs))
        end
        RacingSystem.Client.InRace.raceTimingState.lapStartedAt = GetGameTimer()
        local totalLaps = math.max(1, math.floor(tonumber(payload.totalLaps) or tonumber(instance and instance.laps) or 1))
        if totalLaps > 1 and lapNumber == totalLaps - 1 then
            RacingSystem.Client.Util.ShowRaceEventVisual('~y~FINAL LAP', '', 3000)
        else
            RacingSystem.Client.Util.ShowRaceEventVisual(('~b~LAP %d COMPLETED'):format(lapNumber), '', 3000)
        end
    end
end)

RegisterNetEvent('racingsystem:race:lapAnnotation', function(payload)
    if type(payload) ~= 'table' then return end
    if payload.isInstanceBest then
        RacingSystem.Client.Util.NotifyPlayer('~g~Instance best')
    else
        local deltaMs = tonumber(payload.deltaMs) or 0
        local sign = deltaMs >= 0 and '+' or '-'
        RacingSystem.Client.Util.NotifyPlayer('~r~' .. sign .. RacingSystem.Client.InRace.formatLapTime(math.abs(deltaMs)) .. ' off best')
    end
end)

RegisterNetEvent('racingsystem:race:standingsUpdate', function(payload)
    if type(payload) ~= 'table' then return end
    raceStandings = payload
end)

RegisterNetEvent('racingsystem:race:instanceAssets', function(payload)
    if type(payload) ~= 'table' or tonumber(payload.instanceId) == nil then return end
    local instanceId = tonumber(payload.instanceId)
    instanceAssetCache[instanceId] = payload
    local joinedInstanceId = select(1, getLocalRaceMembershipFromStateBag())
    if joinedInstanceId == instanceId then
        syncJoinedInstanceAssets(instanceId)
    end
end)

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
RegisterNetEvent('racingsystem:race:getRaceInfo', function(payload)
    if type(payload) ~= 'table' then return end
    local instanceId = tonumber(payload.id)
    if not instanceId or instanceId <= 0 then return end
    raceInfoById[instanceId] = {
        Identity = {
            id = instanceId,
            name = tostring(payload.name or ''),
            definitionId = payload.definitionId,
            definitionName = payload.definitionName,
            sourceType = payload.sourceType,
            sourceName = payload.sourceName,
            owner = tonumber(payload.owner) or 0,
        },
        Config = {
            laps = tonumber(payload.laps) or 1,
            trafficDensity = tonumber(payload.trafficDensity) or 0.0,
            pointToPoint = payload.pointToPoint == true,
        },
        Route = {
            checkpoints = type(payload.checkpoints) == 'table' and payload.checkpoints or {},
            checkpointVariants = type(payload.checkpointVariants) == 'table' and payload.checkpointVariants or {},
            raceMetadata = type(payload.raceMetadata) == 'table' and payload.raceMetadata or {},
        },
        Runtime = {
            state = payload.state,
            createdAt = payload.createdAt,
            invokedAt = payload.invokedAt,
            startAt = payload.startAt,
            startedAt = payload.startedAt,
            finishedAt = payload.finishedAt,
            bestLapTimeMs = tonumber(payload.bestLapTimeMs) or nil,
        },
        Participants = {
            entrants = type(payload.entrants) == 'table' and payload.entrants or {},
        },
    }

    applyJoinedInstanceTrafficMode()
end)

AddEventHandler('racingsystem:resetToLastCheckpoint', function()
    local joinedInstance = getJoinedRaceInstance()
    if not joinedInstance or joinedInstance.state ~= RacingSystem.States.running then return end
    local entrant = getLocalEntrant(joinedInstance)
    if not entrant then return end
    local entrantProgress = RacingSystem.Client.InRace.getEffectiveEntrantProgress(joinedInstance, entrant)
    local lastCheckpoint, nextCheckpoint = RacingSystem.Client.InRace.resolveLastPassedCheckpointTarget(joinedInstance, entrantProgress)
    if type(lastCheckpoint) ~= 'table' then return end
    TriggerEvent('racingsystem:smartCheckpointTeleport', {
        checkpoint = lastCheckpoint,
        nextCheckpoint = nextCheckpoint,
        preserveVelocity = false
    })
end)

AddEventHandler('racingsystem:race:start', function()
    local joinedInstance = getJoinedRaceInstance()
    if not joinedInstance then return end
    if joinedInstance.state ~= RacingSystem.States.idle and joinedInstance.state ~= RacingSystem.States.finished then return end
    local entrant = getLocalEntrant(joinedInstance)
    if not entrant then return end
    local ownerSource = tonumber(joinedInstance.owner)
    local localSource = tonumber(GetPlayerServerId(PlayerId())) or 0
    if ownerSource == nil or ownerSource <= 0 then
        local entrants = type(joinedInstance.entrants) == 'table' and joinedInstance.entrants or {}
        local firstEntrantSource = tonumber(type(entrants[1]) == 'table' and entrants[1].source)
        if firstEntrantSource ~= localSource then return end
    elseif ownerSource ~= localSource then
        return
    end
    if #(joinedInstance.entrants or {}) == 0 then return end
    TriggerServerEvent('racingsystem:race:start')
end)

AddEventHandler('racingsystem:race:restart', function()
    local joinedInstance = getJoinedRaceInstance()
    if not joinedInstance then return end
    local entrant = getLocalEntrant(joinedInstance)
    if not entrant then return end
    local ownerSource = tonumber(joinedInstance.owner)
    local localSource = tonumber(GetPlayerServerId(PlayerId())) or 0
    if ownerSource == nil or ownerSource <= 0 then
        local entrants = type(joinedInstance.entrants) == 'table' and joinedInstance.entrants or {}
        local firstEntrantSource = tonumber(type(entrants[1]) == 'table' and entrants[1].source)
        if firstEntrantSource ~= localSource then return end
    elseif ownerSource ~= localSource then
        return
    end
    if #(joinedInstance.entrants or {}) == 0 then return end
    TriggerServerEvent('racingsystem:race:restart')
end)

AddEventHandler('racingsystem:race:leave', function()
    local joinedInstance = getJoinedRaceInstance()
    if not joinedInstance then return end
    RacingSystem.Client.InRace.localEntrantIdentity.entrantId = nil
    getRaceRuntimeState().pendingCheckpointPass = nil
    getRaceRuntimeState().checkpointPassArm = nil
    do local t = RacingSystem.Client.InRace.finishCueShownByInstanceId; for k in pairs(t) do t[k] = nil end end
    RacingSystem.Client.InRace.clearPredictedRaceProgress()
    RacingSystem.Client.InRace.resetLocalRaceTiming()
    clearStartLineBlip()
    RacingSystem.Client.clearCheckpointBlips(joinedInstance and joinedInstance.id)
    if type(RacingSystem.Menu.clearCountdownAccepted) == 'function' then
        RacingSystem.Menu.clearCountdownAccepted(joinedInstance and joinedInstance.id)
    end
    RacingSystem.Client.Util.ClearRaceLeaderboardVisual()
    currentTrafficDensity = nil
    TriggerServerEvent('traffic_control:requestDensity', nil, 'racingsystem_clear', RACE_TRAFFIC_REQUEST_KEY)
    TriggerServerEvent('racingsystem:race:leave')
    MenuHandler:CloseAndClearHistory()
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
    TriggerServerEvent('racingsystem:ugc:importById', ugcId)
end)

RegisterNUICallback('racingsystem:gtAoRaceUrlCancel', function(_, cb)
    closeGTAORaceUrlPrompt()
    cb({})
end)

RegisterNetEvent('racingsystem:ugc:importResult', function(payload)
    if type(payload) ~= 'table' then return end
    local data = type(payload.data) == 'table' and payload.data or {}
    if payload.ok ~= true then
        local message = type(payload.error) == 'string' and payload.error or 'Could not validate GTAO race URL.'
        RacingSystem.Client.Util.ShowWarningSubtitle(message, 2500, '~o~')
        return
    end
    local raceName = tostring(data.raceName or data.ugcId or '')
    local checkpointCount = math.max(0, math.floor(tonumber(data.checkpointCount) or 0))
    if raceName ~= '' then
        RacingSystem.Menu.pendingSelectRaceName = raceName
    end
    RacingSystem.Client.Util.ShowWarningSubtitle(
        ('Imported %s (%d checkpoints).'):format(raceName ~= '' and raceName or 'GTAO race', checkpointCount),
        3000,
        '~g~'
    )
end)

RegisterNetEvent('racingsystem:race:restarted', function(payload)
    if type(payload) ~= 'table' then return end
    local instanceId = tonumber(payload.instanceId)
    if not instanceId then return end
    if type(RacingSystem.Menu.clearCountdownAccepted) == 'function' then
        RacingSystem.Menu.clearCountdownAccepted(instanceId)
    end
    RacingSystem.Client.InRace.countdownEndTimeByInstanceId[instanceId] = nil
    RacingSystem.Client.InRace.raceStartCueShownByInstanceId[instanceId] = nil
    RacingSystem.Client.InRace.finishCueShownByInstanceId[instanceId] = nil
    local joinedInstance = getJoinedRaceInstance()
    if joinedInstance and tonumber(joinedInstance.id) == instanceId then
        RacingSystem.Client.InRace.resetLocalRaceTiming()
        getRaceRuntimeState().pendingCheckpointPass = nil
        getRaceRuntimeState().checkpointPassArm = nil
        getRaceRuntimeState().lastPassedCheckpoint = nil
        RacingSystem.Client.clearCheckpointBlips(instanceId)
    end
    applyRaceMenuStageFromCurrentState()
    refreshRaceMenuFromCurrentState()
end)

CreateThread(function()
    while true do
        RacingSystem.Client.Util.DrawRaceEventVisual()
        Wait(0)
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    closeGTAORaceUrlPrompt(true)
    RacingSystem.Client.InRace.localEntrantIdentity.entrantId = nil
    do local t = RacingSystem.Client.InRace.finishCueShownByInstanceId; for k in pairs(t) do t[k] = nil end end
    currentTrafficDensity = nil
    TriggerServerEvent('traffic_control:requestDensity', nil, 'racingsystem_clear', RACE_TRAFFIC_REQUEST_KEY)
    RacingSystem.Client.InRace.clearPowerPenaltyVehicleOverride()
    clearStartLineBlip()
    RacingSystem.Client.Util.ClearRaceLeaderboardVisual()
    unloadActiveInstanceAssets()
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    closeGTAORaceUrlPrompt(true)

    SetTimeout(250, function()
        closeGTAORaceUrlPrompt(true)
    end)

    SetTimeout(1200, function()
        showStartupVersionNotice()
    end)

    SetTimeout(500, function()
        TriggerServerEvent('racingsystem:state:request')
    end)
end)
RacingSystem.Client.drawIdleStartChevron = drawIdleStartChevron

-- Live leaderboard on TAB hold
CreateThread(function()
    while true do
        if raceStandings and raceStandings.entrants and #raceStandings.entrants > 0 then
            local tabHeld = IsControlPressed(0, 249) -- INPUT_REPLAY_SHOWHOTKEY (TAB)
            if tabHeld then
                if not raceLeaderboardScoreboard then
                    PlayerListScoreboard:Load()
                    PlayerListScoreboard:SetTitle(
                        tostring(raceStandings.instanceName or 'Race'),
                        ('Laps: %d'):format(tonumber(raceStandings.totalLaps) or 1),
                        0
                    )
                    PlayerListScoreboard._start = 0
                    PlayerListScoreboard.Enabled = true
                    raceLeaderboardScoreboard = true
                end
                -- Rebuild rows from current standings
                for i = #PlayerListScoreboard.PlayerRows, 1, -1 do
                    PlayerListScoreboard:RemoveRow(i)
                end
                for _, entrant in ipairs(raceStandings.entrants) do
                    local label = entrant.name
                    local rightText
                    if entrant.finishedAt then
                        rightText = RacingSystem.Client.InRace.formatDurationMs(entrant.totalTimeMs or 0)
                    else
                        rightText = ('Lap %d/%d'):format(entrant.currentLap, entrant.totalLaps)
                    end
                    local row = SCPlayerItem.New(label, 0, 0, rightText, '', '', '', 0, '', entrant.source, '')
                    PlayerListScoreboard:AddRow(row)
                end
                PlayerListScoreboard:CurrentPage(1)
                PlayerListScoreboard:BuildMenu()
                PlayerListScoreboard:Update()
            else
                if raceLeaderboardScoreboard then
                    PlayerListScoreboard:Dispose()
                    raceLeaderboardScoreboard = nil
                end
            end
        else
            if raceLeaderboardScoreboard then
                PlayerListScoreboard:Dispose()
                raceLeaderboardScoreboard = nil
            end
        end
        Wait(0)
    end
end)


