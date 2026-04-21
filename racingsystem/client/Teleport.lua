RacingSystem = RacingSystem or {}
RacingSystem.Client = RacingSystem.Client or {}

local isTeleportInProgress = false

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
                    for index, entrant in ipairs(entrants) do
                        if tonumber(entrant and entrant.source) == localSource then
                            slot = index
                            break
                        end
                    end
                end
            end

            if checkpointCount > 0 then
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

local function runSmartCheckpointTeleport(checkpoint, nextCheckpoint)
    local payload = buildCheckpointTeleportPayload(checkpoint, nextCheckpoint)
    if type(payload) ~= 'table' then
        return
    end
    runSmartJoinTeleport(payload)
end
RacingSystem.Client.runSmartCheckpointTeleport = runSmartCheckpointTeleport

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

