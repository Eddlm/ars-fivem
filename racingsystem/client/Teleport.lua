RacingSystem = RacingSystem or {}
RacingSystem.Client = RacingSystem.Client or {}

local isTeleportInProgress = false
local MAX_LOOP_ITERATIONS = 5
local SAFE_SPOT_SAMPLE_COUNT = 5
local FADE_POLL_ATTEMPTS = 5
local ENTITY_SCAN_LIMIT = 5

local function sampleGroundZWithSpherecast(x, y, zHint, ignoreEntity)
    local startZ = (tonumber(zHint) or 0.0) + 4.0
    local endZ = (tonumber(zHint) or 0.0) - 35.0
    local shape = StartShapeTestSweptSphere(
        x,
        y,
        startZ,
        x,
        y,
        endZ,
        0.75,
        1,
        tonumber(ignoreEntity) or 0,
        4
    )
    local _, didHit, hitCoords = GetShapeTestResult(shape)
    if not didHit or type(hitCoords) ~= 'vector3' then
        return nil, nil
    end
    return tonumber(hitCoords.z), math.abs((tonumber(hitCoords.z) or 0.0) - startZ)
end

local function isSpotOccupiedByVehicleOrPlayer(x, y, z, radius, ignoreVehicle, ignorePed)
    local checkRadius = math.max(1.5, tonumber(radius) or 2.5)
    local checkRadiusSq = checkRadius * checkRadius
    local vehicles = GetGamePool('CVehicle')
    local vehicleChecks = 0
    for _, vehicle in ipairs(vehicles) do
        if vehicleChecks >= ENTITY_SCAN_LIMIT then
            break
        end
        vehicleChecks = vehicleChecks + 1
        if vehicle ~= 0 and DoesEntityExist(vehicle) and vehicle ~= ignoreVehicle then
            local coords = GetEntityCoords(vehicle)
            local dx = (tonumber(coords.x) or 0.0) - x
            local dy = (tonumber(coords.y) or 0.0) - y
            local dz = (tonumber(coords.z) or 0.0) - z
            if ((dx * dx) + (dy * dy) + (dz * dz)) <= checkRadiusSq then
                return true
            end
        end
    end

    for playerOffset = 0, ENTITY_SCAN_LIMIT - 1 do
        local playerIndex = playerOffset
        if NetworkIsPlayerActive(playerIndex) then
            local ped = GetPlayerPed(playerIndex)
            if ped ~= 0 and DoesEntityExist(ped) and IsPedAPlayer(ped) and ped ~= ignorePed then
                local coords = GetEntityCoords(ped)
                local dx = (tonumber(coords.x) or 0.0) - x
                local dy = (tonumber(coords.y) or 0.0) - y
                local dz = (tonumber(coords.z) or 0.0) - z
                if ((dx * dx) + (dy * dy) + (dz * dz)) <= checkRadiusSq then
                    return true
                end
            end
        end
    end

    return false
end

local function findNearestSafeGroundSpot(originX, originY, zHint, ignoreVehicle, ignorePed, timeoutMs)
    local maxGroundZDelta = 8.0
    local sampleRadius = 2.0
    local candidates = {
        { x = 0.0, y = 0.0 },
        { x = sampleRadius, y = 0.0 },
        { x = -sampleRadius, y = 0.0 },
        { x = 0.0, y = sampleRadius },
        { x = 0.0, y = -sampleRadius },
    }

    for index = 1, SAFE_SPOT_SAMPLE_COUNT do
        local candidate = candidates[index]
        if type(candidate) ~= 'table' then
            break
        end
        local candidateX = originX + (tonumber(candidate.x) or 0.0)
        local candidateY = originY + (tonumber(candidate.y) or 0.0)
        local groundZ = sampleGroundZWithSpherecast(candidateX, candidateY, zHint, ignoreVehicle ~= 0 and ignoreVehicle or ignorePed)
        if groundZ ~= nil and math.abs((tonumber(groundZ) or 0.0) - (tonumber(zHint) or 0.0)) <= maxGroundZDelta then
            local occupied = isSpotOccupiedByVehicleOrPlayer(
                candidateX,
                candidateY,
                groundZ + 1.0,
                2.5,
                ignoreVehicle,
                ignorePed
            )
            if not occupied then
                return candidateX, candidateY, groundZ + 1.0
            end
        end
        if index < SAFE_SPOT_SAMPLE_COUNT then
            Wait(75)
        end
    end

    return nil
end

local function getWorldGroundBelowEntity(entity, maxDropMeters)
    if entity == 0 or not DoesEntityExist(entity) then
        return nil
    end
    local coords = GetEntityCoords(entity)
    local startZ = (tonumber(coords.z) or 0.0) + 1.0
    local endZ = startZ - math.max(10.0, tonumber(maxDropMeters) or 120.0)
    local ray = StartShapeTestLosProbe(
        tonumber(coords.x) or 0.0,
        tonumber(coords.y) or 0.0,
        startZ,
        tonumber(coords.x) or 0.0,
        tonumber(coords.y) or 0.0,
        endZ,
        1,
        entity,
        4
    )
    local _, didHit, hitCoords = GetShapeTestResult(ray)
    if not didHit or type(hitCoords) ~= 'vector3' then
        return nil
    end
    return tonumber(hitCoords.z)
end

local function waitForFadeState(targetFadedOut, timeoutMs, pollIntervalMs)
    local maxWaitMs = math.max(0, math.floor(tonumber(timeoutMs) or 2500))
    local configuredPollMs = math.max(1, math.floor(tonumber(pollIntervalMs) or 75))
    local budgetPollMs = math.max(1, math.floor(maxWaitMs / FADE_POLL_ATTEMPTS))
    local pollMs = math.min(configuredPollMs, budgetPollMs)
    for attempt = 1, FADE_POLL_ATTEMPTS do
        local ready = targetFadedOut and IsScreenFadedOut() or IsScreenFadedIn()
        if ready then
            return true
        end
        if attempt < FADE_POLL_ATTEMPTS and maxWaitMs > 0 then
            Wait(pollMs)
        end
    end
    return false
end

local function resolveTeleportHeading(payload)
    local heading = tonumber(payload and payload.heading)
    if heading ~= nil then
        return heading
    end

    local joinedInstance = type(RacingSystem.Client.getJoinedRaceInstance) == 'function' and RacingSystem.Client.getJoinedRaceInstance() or nil
    local checkpoints = type(joinedInstance) == 'table' and type(joinedInstance.checkpoints) == 'table' and joinedInstance.checkpoints or {}
    local checkpointCount = #checkpoints
    local checkpointIndex = math.max(1, math.min(checkpointCount, math.floor(tonumber(payload and payload.checkpointIndex) or 1)))
    if checkpointCount <= 0 then
        return 0.0
    end

    local targetVariant = type(RacingSystem.Client.getCheckpointVariantEntry) == 'function' and RacingSystem.Client.getCheckpointVariantEntry(joinedInstance, checkpointIndex) or nil
    local targetCheckpoint = targetVariant and targetVariant.primary or checkpoints[checkpointIndex]
    local previousIndex = checkpointIndex - 1
    if previousIndex < 1 then
        previousIndex = checkpointCount
    end
    local previousVariant = type(RacingSystem.Client.getCheckpointVariantEntry) == 'function' and RacingSystem.Client.getCheckpointVariantEntry(joinedInstance, previousIndex) or nil
    local previousCheckpoint = previousVariant and previousVariant.primary or checkpoints[previousIndex]
    if type(previousCheckpoint) == 'table' and type(targetCheckpoint) == 'table' then
        return (type(RacingSystem.Client.getVehicleHeadingToNextCheckpoint) == 'function' and RacingSystem.Client.getVehicleHeadingToNextCheckpoint(previousCheckpoint, targetCheckpoint)) or 0.0
    end

    return 0.0
end

local function normalizeHeading(value)
    local heading = tonumber(value) or 0.0
    heading = heading % 360.0
    if heading < 0.0 then
        heading = heading + 360.0
    end
    return heading
end

local function getHeadingOffsetForSourceType(sourceType)
    local normalizedSourceType = tostring(sourceType or ''):lower()
    if normalizedSourceType == 'custom' then
        return 180.0
    end
    if normalizedSourceType == 'online' then
        return -90.0
    end
    return 0.0
end

local function resolveJoinTeleportDestination(payload, destinationX, destinationY)
    local joinedInstance = type(RacingSystem.Client.getJoinedRaceInstance) == 'function' and RacingSystem.Client.getJoinedRaceInstance() or nil
    local entrants = type(joinedInstance) == 'table' and type(joinedInstance.entrants) == 'table' and joinedInstance.entrants or {}
    local checkpoints = type(joinedInstance) == 'table' and type(joinedInstance.checkpoints) == 'table' and joinedInstance.checkpoints or {}
    local checkpointCount = #checkpoints
    local localSource = tonumber(GetPlayerServerId(PlayerId())) or 0
    local slot = math.max(1, #entrants)
    local localEntrant = type(RacingSystem.Client.getLocalEntrant) == 'function' and RacingSystem.Client.getLocalEntrant(joinedInstance) or nil
    local checkpointIndex = math.max(1, math.min(checkpointCount, math.floor(tonumber(payload and payload.checkpointIndex) or 1)))

    if type(localEntrant) == 'table' then
        local positionSlot = math.floor(tonumber(localEntrant.position) or 0)
        if positionSlot > 0 then
            slot = positionSlot
        else
            local entrantChecks = 0
            for index, entrant in ipairs(entrants) do
                if entrantChecks >= MAX_LOOP_ITERATIONS then
                    break
                end
                entrantChecks = entrantChecks + 1
                if tonumber(entrant and entrant.source) == localSource then
                    slot = index
                    break
                end
            end
        end
    end

    if checkpointCount <= 0 then
        return destinationX, destinationY
    end

    local currentVariant = type(RacingSystem.Client.getCheckpointVariantEntry) == 'function' and RacingSystem.Client.getCheckpointVariantEntry(joinedInstance, checkpointIndex) or nil
    local currentCheckpoint = currentVariant and currentVariant.primary or checkpoints[checkpointIndex]
    local previousIndex = checkpointIndex - 1
    if previousIndex < 1 then
        previousIndex = checkpointCount
    end
    local previousVariant = type(RacingSystem.Client.getCheckpointVariantEntry) == 'function' and RacingSystem.Client.getCheckpointVariantEntry(joinedInstance, previousIndex) or nil
    local previousCheckpoint = previousVariant and previousVariant.primary or checkpoints[previousIndex]
    local currentX = tonumber(currentCheckpoint and currentCheckpoint.x) or destinationX
    local currentY = tonumber(currentCheckpoint and currentCheckpoint.y) or destinationY
    local prevX = tonumber(previousCheckpoint and previousCheckpoint.x) or currentX
    local prevY = tonumber(previousCheckpoint and previousCheckpoint.y) or currentY
    local forwardX = currentX - prevX
    local forwardY = currentY - prevY
    local forwardLength = math.sqrt((forwardX * forwardX) + (forwardY * forwardY))
    if forwardLength <= 0.001 then
        return destinationX, destinationY
    end

    forwardX = forwardX / forwardLength
    forwardY = forwardY / forwardLength
    local rightX = forwardY
    local rightY = -forwardX
    local sideMeters = math.max(2.0, ((tonumber(previousCheckpoint and previousCheckpoint.radius) or 8.0) * 0.5) - 2.0)
    local behindMeters = 5.0 * slot
    local sideSign = (slot % 2 == 0) and 1.0 or -1.0
    return currentX - (forwardX * behindMeters) + (rightX * sideMeters * sideSign), currentY - (forwardY * behindMeters) + (rightY * sideMeters * sideSign)
end

local function getTeleportPedContext()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then
        return nil
    end
    local vehicle = GetVehiclePedIsIn(ped, false)
    local isDriverVehicle = vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped
    return ped, vehicle, isDriverVehicle
end

local function applyVehicleTeleport(vehicle, ped, destinationX, destinationY, destinationZ, heading, headingOffset, teleportType, checkpointSpeedMps, getFadeInRemainingMs, waitWithinFadeInDeadline)
    local targetZ = destinationZ
    SetEntityCoordsNoOffset(vehicle, destinationX, destinationY, targetZ, false, false, false)
    SetEntityHeading(vehicle, heading)
    SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)
    FreezeEntityPosition(vehicle, true)
    waitWithinFadeInDeadline(1500)
    local safeX, safeY, safeZ = findNearestSafeGroundSpot(
        destinationX,
        destinationY,
        targetZ,
        vehicle,
        ped,
        math.min(4000, getFadeInRemainingMs())
    )
    if safeX ~= nil and safeY ~= nil and safeZ ~= nil then
        SetEntityCoordsNoOffset(vehicle, safeX, safeY, safeZ, false, false, false)
        SetVehicleOnGroundProperly(vehicle)
    end
    SetEntityHeading(vehicle, normalizeHeading(heading - headingOffset))
    FreezeEntityPosition(vehicle, false)
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
end

local function applyPedTeleport(ped, destinationX, destinationY, destinationZ, heading, headingOffset)
    SetEntityCoordsNoOffset(ped, destinationX, destinationY, destinationZ, false, false, false)
    SetEntityHeading(ped, normalizeHeading(heading - headingOffset))
    SetEntityVelocity(ped, 0.0, 0.0, 0.0)
    ClearPedTasks(ped)
    SetPlayerControl(PlayerId(), true, 0)
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
    local teleportStartedAt = GetGameTimer()
    local fadeInDeadlineAt = teleportStartedAt + 4000
    local destinationX = tonumber(payload.x) or 0.0
    local destinationY = tonumber(payload.y) or 0.0
    local destinationZ = tonumber(payload.z) or 0.0
    local sourceType = tostring(payload.sourceType or '')
    local heading = resolveTeleportHeading(payload)
    local teleportType = tostring(payload.teleportType or 'join')
    local headingOffset = getHeadingOffsetForSourceType(sourceType)
    if teleportType == 'checkpoint' then
        headingOffset = headingOffset + 180.0
    end
    local checkpointSpeedMph = math.max(0.0, tonumber(payload.speedMph) or 15.0)
    local checkpointSpeedMps = checkpointSpeedMph * 0.44704
    local fadeOutMs = 650
    local fadeInMs = 650
    local fadeTimeoutMs = 2500
    local pollIntervalMs = 75
    local function getFadeInRemainingMs()
        return math.max(0, fadeInDeadlineAt - GetGameTimer())
    end
    local function waitWithinFadeInDeadline(waitMs)
        local clampedWaitMs = math.max(0, math.floor(tonumber(waitMs) or 0))
        local remainingMs = getFadeInRemainingMs()
        if remainingMs <= 0 or clampedWaitMs <= 0 then
            return
        end
        Wait(math.min(clampedWaitMs, remainingMs))
    end

    local ok, _ = pcall(function()
        if teleportType == 'join' then
            destinationX, destinationY = resolveJoinTeleportDestination(payload, destinationX, destinationY)
        end

        local ped, vehicle, isDriverVehicle = getTeleportPedContext()
        if ped == nil then
            return
        end

        if not IsScreenFadedOut() then
            DoScreenFadeOut(fadeOutMs)
            waitForFadeState(true, math.min(fadeTimeoutMs, getFadeInRemainingMs()), pollIntervalMs)
        end
        didFadeOut = true
        if isDriverVehicle and DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == ped then
            applyVehicleTeleport(
                vehicle,
                ped,
                destinationX,
                destinationY,
                destinationZ,
                heading,
                headingOffset,
                teleportType,
                checkpointSpeedMps,
                getFadeInRemainingMs,
                waitWithinFadeInDeadline
            )
        else
            applyPedTeleport(ped, destinationX, destinationY, destinationZ, heading, headingOffset)
        end
    end)

    if didFadeOut then
        if not IsScreenFadedIn() then
            DoScreenFadeIn(fadeInMs)
            waitForFadeState(false, math.min(fadeTimeoutMs, getFadeInRemainingMs()), pollIntervalMs)
        end
    end
    if not ok then
    end
    isTeleportInProgress = false
end

local function buildCheckpointTeleportPayload(checkpoint, nextCheckpoint)
    if type(checkpoint) ~= 'table' then
        return nil
    end

    local joinedInstance = type(RacingSystem.Client.getJoinedRaceInstance) == 'function' and RacingSystem.Client.getJoinedRaceInstance() or nil
    local checkpointIndex = math.max(1, math.floor(tonumber(checkpoint.index) or 1))
    local payload = {
        checkpointIndex = checkpointIndex,
        x = tonumber(checkpoint.x) or 0.0,
        y = tonumber(checkpoint.y) or 0.0,
        z = (tonumber(checkpoint.z) or 0.0) + 1.0,
        teleportType = 'checkpoint',
        speedMph = 15.0,
        sourceType = tostring(type(joinedInstance) == 'table' and joinedInstance.sourceType or ''),
    }
    return payload
end

local function runSmartCheckpointTeleport(checkpoint, nextCheckpoint)
    local payload = buildCheckpointTeleportPayload(checkpoint, nextCheckpoint)
    if type(payload) ~= 'table' then
        return
    end
    runSmartJoinTeleport(payload)
end
RacingSystem.Client.runSmartCheckpointTeleport = runSmartCheckpointTeleport

local function runSmartTeleportToPoint(x, y, z, heading)
    local joinedInstance = type(RacingSystem.Client.getJoinedRaceInstance) == 'function' and RacingSystem.Client.getJoinedRaceInstance() or nil
    runSmartJoinTeleport({
        x = tonumber(x) or 0.0,
        y = tonumber(y) or 0.0,
        z = tonumber(z) or 0.0,
        heading = tonumber(heading) or 0.0,
        teleportType = 'safety',
        sourceType = tostring(type(joinedInstance) == 'table' and joinedInstance.sourceType or ''),
    })
end
RacingSystem.Client.runSmartTeleportToPoint = runSmartTeleportToPoint

local function runSafetyExitTeleportIfNeeded()
    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then
        return false
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    local isDriverVehicle = vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped
    local anchor = isDriverVehicle and vehicle or ped
    local coords = GetEntityCoords(anchor)
    local groundZ = getWorldGroundBelowEntity(anchor, 160.0)
    if groundZ == nil then
        return false
    end

    local heightAboveGround = tonumber(GetEntityHeightAboveGround(anchor)) or 0.0
    if heightAboveGround <= 6.0 then
        return false
    end

    local safeX, safeY, safeZ = findNearestSafeGroundSpot(
        tonumber(coords.x) or 0.0,
        tonumber(coords.y) or 0.0,
        groundZ + 1.0,
        isDriverVehicle and vehicle or 0,
        ped,
        1000
    )
    if safeX == nil or safeY == nil or safeZ == nil then
        return false
    end

    local heading = tonumber(GetEntityHeading(anchor)) or 0.0
    runSmartTeleportToPoint(safeX, safeY, safeZ + 3.0, heading)
    return true
end
RacingSystem.Client.runSafetyExitTeleportIfNeeded = runSafetyExitTeleportIfNeeded

RegisterNetEvent('racingsystem:race:teleportCheckpoint', function(payload)
    Citizen.CreateThread(function()
        runSmartJoinTeleport(payload)
    end)
end)

AddEventHandler('racingsystem:smartCheckpointTeleport', function(payload)
    Citizen.CreateThread(function()
        local checkpoint = type(payload) == 'table' and payload.checkpoint or nil
        local nextCheckpoint = type(payload) == 'table' and payload.nextCheckpoint or nil
        runSmartCheckpointTeleport(checkpoint, nextCheckpoint)
    end)
end)

