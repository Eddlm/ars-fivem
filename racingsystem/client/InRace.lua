RacingSystem = RacingSystem or {}
RacingSystem.Client = RacingSystem.Client or {}
RacingSystem.Client.InRace = RacingSystem.Client.InRace or {}

-- ============================================================
-- Shared state (exposed on namespace so client.lua can reach it)
-- ============================================================

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
    chevronEdgeCache = nil,
    penaltyPreviewText = nil,
    penaltyPreviewShownAt = 0,
    cornerConesByKey = {},
}
RacingSystem.Client.InRace.raceRuntimeState = raceRuntimeState

local countdownEndTimeByInstanceId = {}
RacingSystem.Client.InRace.countdownEndTimeByInstanceId = countdownEndTimeByInstanceId

local countdownZeroReportedByInstanceId = {}
RacingSystem.Client.InRace.countdownZeroReportedByInstanceId = countdownZeroReportedByInstanceId

local raceStartCueShownByInstanceId = {}
RacingSystem.Client.InRace.raceStartCueShownByInstanceId = raceStartCueShownByInstanceId

local finishCueShownByInstanceId = {}
RacingSystem.Client.InRace.finishCueShownByInstanceId = finishCueShownByInstanceId

local raceTimingState = {
    instanceId = nil,
    raceStartedAt = nil,
    lapStartedAt = nil,
}
RacingSystem.Client.InRace.raceTimingState = raceTimingState

local localEntrantIdentity = {
    entrantId = nil,
}
RacingSystem.Client.InRace.localEntrantIdentity = localEntrantIdentity

-- ============================================================
-- Constants (derived from ClientAdvancedConfig in client.lua)
-- These are read lazily at runtime via the shared Config table.
-- ============================================================

local function getClientAdvancedConfig()
    return (((RacingSystem or {}).Config or {}).advanced or {}).client or {}
end

local CHECKPOINT_PASS_ARM_DISTANCE
local CHECKPOINT_PASS_RELEASE_THRESHOLD
local CHECKPOINT_RECOVERY_PASS_MAX_MPH
local CHECKPOINT_RECOVERY_FORWARD_VELOCITY_RATIO_MAX
local METERS_PER_SECOND_TO_MILES_PER_HOUR = 2.236936
local CHECKPOINT_SOFT_POWER_PENALTY_MULTIPLIER
local LEADERBOARD_CLIENT_TIEBREAK_ENABLED

local function ensureConstants()
    if CHECKPOINT_PASS_ARM_DISTANCE then
        return
    end
    local cfg = getClientAdvancedConfig()
    CHECKPOINT_PASS_ARM_DISTANCE = tonumber(cfg.checkpointPassArmDistance) or 30.0
    CHECKPOINT_PASS_RELEASE_THRESHOLD = tonumber(cfg.checkpointPassReleaseThreshold) or 0.75
    CHECKPOINT_RECOVERY_PASS_MAX_MPH = tonumber(cfg.checkpointRecoveryPassMaxMph) or 5.0
    CHECKPOINT_RECOVERY_FORWARD_VELOCITY_RATIO_MAX = tonumber(cfg.checkpointRecoveryForwardVelocityRatioMax) or 0.66
    CHECKPOINT_SOFT_POWER_PENALTY_MULTIPLIER = tonumber(cfg.checkpointSoftPowerPenaltyMultiplier) or 0.05
    LEADERBOARD_CLIENT_TIEBREAK_ENABLED = cfg.leaderboardClientTiebreakEnabled == true
end

-- ============================================================
-- Lap time / duration formatting
-- ============================================================

local function formatLapTime(ms)
    ms = math.max(0, math.floor(tonumber(ms) or 0))
    local mins = math.floor(ms / 60000)
    local secs = math.floor((ms % 60000) / 1000)
    local cents = math.floor((ms % 1000) / 10)
    if mins > 0 then
        return ('%d:%02d.%02d'):format(mins, secs, cents)
    end
    return ('%d.%02d'):format(secs, cents)
end
RacingSystem.Client.InRace.formatLapTime = formatLapTime

local function formatDurationMs(totalMs)
    local durationMs = math.max(0, math.floor(tonumber(totalMs) or 0))
    local minutes = math.floor(durationMs / 60000)
    local seconds = math.floor((durationMs % 60000) / 1000)
    local milliseconds = durationMs % 1000
    return ('%02d:%02d.%03d'):format(minutes, seconds, milliseconds)
end
RacingSystem.Client.InRace.formatDurationMs = formatDurationMs

-- ============================================================
-- Race timing
-- ============================================================

local function clearPredictedRaceProgress(instanceId)
    local predicted = raceRuntimeState.predictedProgress
    if not predicted then
        return
    end
    if instanceId == nil or tonumber(predicted.instanceId) == tonumber(instanceId) then
        raceRuntimeState.predictedProgress = nil
    end
end
RacingSystem.Client.InRace.clearPredictedRaceProgress = clearPredictedRaceProgress

local function resetLocalRaceTiming()
    raceTimingState.instanceId = nil
    raceTimingState.raceStartedAt = nil
    raceTimingState.lapStartedAt = nil
    clearPredictedRaceProgress()
end
RacingSystem.Client.InRace.resetLocalRaceTiming = resetLocalRaceTiming

local function ensureLocalRaceTiming(instanceId)
    local numericInstanceId = tonumber(instanceId)
    if raceTimingState.instanceId ~= numericInstanceId then
        resetLocalRaceTiming()
        raceTimingState.instanceId = numericInstanceId
    end
end
RacingSystem.Client.InRace.ensureLocalRaceTiming = ensureLocalRaceTiming

-- ============================================================
-- Penalty enforcement
-- ============================================================

local function clearPowerPenaltyVehicleOverride()
    local penaltyVehicle = raceRuntimeState.powerPenaltyVehicle
    if penaltyVehicle and DoesEntityExist(penaltyVehicle) then
        SetVehicleEnginePowerMultiplier(penaltyVehicle, 0.0)
    end
    raceRuntimeState.powerPenaltyVehicle = nil
    raceRuntimeState.powerPenaltyUntil = 0
end
RacingSystem.Client.InRace.clearPowerPenaltyVehicleOverride = clearPowerPenaltyVehicleOverride

local function applySoftPowerPenalty(vehicle, durationMs)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return
    end
    local penaltyDurationMs = math.max(0, math.floor(tonumber(durationMs) or 0))
    if penaltyDurationMs <= 0 then
        return
    end
    ensureConstants()
    raceRuntimeState.powerPenaltyVehicle = vehicle
    raceRuntimeState.powerPenaltyUntil = GetGameTimer() + penaltyDurationMs
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

-- ============================================================
-- Prop speed modification (used by checkpoint pass context)
-- ============================================================

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

local function GetPropSpeedModificationParameters(model, prpsba)
    if prpsba == -1 then
        return false
    end

    local speedTarget, durationTarget = -1, -1

    if speedUpObjects[model] then
        if prpsba == 1 then
            speedTarget, durationTarget = 15, 0.3
        elseif prpsba == 2 then
            speedTarget, durationTarget = 25, 0.3
        elseif prpsba == 3 then
            speedTarget, durationTarget = 35, 0.5
        elseif prpsba == 4 then
            speedTarget, durationTarget = 45, 0.5
        elseif prpsba == 5 then
            speedTarget, durationTarget = 100, 0.5
        else
            speedTarget, durationTarget = 25, 0.4
        end
    elseif slowDownObjects[model] then
        durationTarget = -1
        if prpsba == 1 then
            speedTarget = 44
        elseif prpsba == 2 then
            speedTarget = 30
        elseif prpsba == 3 then
            speedTarget = 16
        else
            speedTarget = 30
        end
    else
        return false
    end

    return true, speedTarget, durationTarget
end
RacingSystem.Client.InRace.GetPropSpeedModificationParameters = GetPropSpeedModificationParameters

-- ============================================================
-- Checkpoint pass helpers
-- ============================================================

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
    if currentCheckpoint < 1 then currentCheckpoint = 1 end
    if currentCheckpoint > totalCheckpoints then currentCheckpoint = 1 end

    local lastCheckpointIndex = currentCheckpoint - 1
    if lastCheckpointIndex < 1 then lastCheckpointIndex = totalCheckpoints end

    local lastVariantEntry = RacingSystem.Client.getCheckpointVariantEntry(instance, lastCheckpointIndex)
    local currentVariantEntry = RacingSystem.Client.getCheckpointVariantEntry(instance, currentCheckpoint)
    local lastCheckpoint = (lastVariantEntry and lastVariantEntry.primary) or checkpoints[lastCheckpointIndex]
    local nextCheckpoint = (currentVariantEntry and currentVariantEntry.primary) or checkpoints[currentCheckpoint]
    if type(lastCheckpoint) ~= 'table' then
        return nil, nil
    end

    return cloneRuntimeCheckpoint(lastCheckpoint), cloneRuntimeCheckpoint(nextCheckpoint)
end
RacingSystem.Client.InRace.resolveLastPassedCheckpointTarget = resolveLastPassedCheckpointTarget

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
RacingSystem.Client.InRace.getEffectiveEntrantProgress = getEffectiveEntrantProgress

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

local function predictCheckpointPass(instance, entrantProgress, totalCheckpoints, targetIndex)
    local instanceId = tonumber(instance and instance.id)
    if not instanceId then
        return
    end

    local currentLap = math.max(1, tonumber(entrantProgress and entrantProgress.currentLap) or 1)
    local totalLaps = math.max(1, tonumber(instance and instance.laps) or 1)
    local lapTriggerCheckpoint = RacingSystem.Client.getClientLapTriggerCheckpoint(totalCheckpoints)
    local postFinishNextCheckpoint = (instance and instance.pointToPoint == true)
        and math.max(1, totalCheckpoints)
        or 1

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
                currentCheckpoint = postFinishNextCheckpoint,
                currentLap = currentLap + 1,
                finished = false,
            }
        end
    else
        local nextCheckpoint = targetIndex + 1
        if nextCheckpoint > totalCheckpoints then nextCheckpoint = 1 end
        raceRuntimeState.predictedProgress = {
            instanceId = instanceId,
            currentCheckpoint = nextCheckpoint,
            currentLap = currentLap,
            finished = false,
        }
    end
end

-- ============================================================
-- Main loop: checkpoint detection, penalty enforcement, timing
-- ============================================================

CreateThread(function()
    ensureConstants()
    while true do
        local joinedInstance = RacingSystem.Client.getJoinedRaceInstance()

        if not joinedInstance then
            raceRuntimeState.penaltyPreviewText = nil
            raceRuntimeState.penaltyPreviewShownAt = 0
            localEntrantIdentity.entrantId = nil
            finishCueShownByInstanceId = {}
            RacingSystem.Client.InRace.finishCueShownByInstanceId = finishCueShownByInstanceId

            raceRuntimeState.pendingCheckpointPass = nil
            raceRuntimeState.previousPosition = nil
            raceRuntimeState.checkpointPassArm = nil
            raceRuntimeState.lastPassedCheckpoint = nil
            raceRuntimeState.startLineCheckpoint = nil
            raceRuntimeState.joinHintInstanceId = nil
            RacingSystem.Client.clearCheckpointChevronEdgeCache()
            raceRuntimeState.accelerationPenaltyUntil = 0
            clearPowerPenaltyVehicleOverride()
            RacingSystem.Client.clearFutureCheckpointBlips()
            RacingSystem.Client.clearStartLineBlip()
            RacingSystem.Client.clearCornerCones()
            resetLocalRaceTiming()
            RacingSystem.Client.Util.ClearCountdownVisual()
            RacingSystem.Client.Util.ClearRaceLeaderboardVisual()
            if RacingSystem.Client.activeInstanceAssets.instanceId then
                RacingSystem.Client.unloadActiveInstanceAssets()
            end
            Wait(1000)
        else
            local joinedInstanceId = tonumber(joinedInstance.id)
            if joinedInstanceId and raceRuntimeState.joinHintInstanceId ~= joinedInstanceId then
                raceRuntimeState.joinHintInstanceId = joinedInstanceId
                RacingSystem.Client.showJoinHintNotifications()

                local joinCheckpoints = type(joinedInstance.checkpoints) == 'table' and joinedInstance.checkpoints or {}
                local joinCheckpointCount = #joinCheckpoints
                if joinCheckpointCount > 0 then
                    local joinEntrant = RacingSystem.Client.getLocalEntrant(joinedInstance)
                    local joinTargetIndex = tonumber(joinEntrant and joinEntrant.currentCheckpoint) or 1
                    local joinCurrentLap = math.max(1, tonumber(joinEntrant and joinEntrant.currentLap) or 1)
                    local joinTotalLaps = math.max(1, tonumber(joinedInstance.laps) or 1)
                    local allowWrapOnJoin = (joinedInstance.pointToPoint ~= true) and (joinCurrentLap < joinTotalLaps)
                    RacingSystem.Client.updateFutureCheckpointBlips(joinedInstance, joinCheckpointCount, joinTargetIndex, allowWrapOnJoin)
                    raceRuntimeState.futureBlipCheckpointIndex = joinTargetIndex
                    raceRuntimeState.futureBlipInstanceId = joinedInstanceId
                else
                    RacingSystem.Client.clearFutureCheckpointBlips()
                end
            end

            RacingSystem.Client.Util.UpdateRaceLeaderboardVisual(nil, RacingSystem.Client.buildLiveLeaderboardRows(joinedInstance))
            ensureLocalRaceTiming(joinedInstanceId)
            if joinedInstance.sourceType == 'online' then
                if tonumber(RacingSystem.Client.activeInstanceAssets.instanceId) ~= joinedInstanceId then
                    local payload = RacingSystem.Client.instanceAssetCache[joinedInstanceId]
                    if payload then
                        RacingSystem.Client.loadInstanceAssets(payload)
                    end
                end
            elseif RacingSystem.Client.activeInstanceAssets.instanceId then
                RacingSystem.Client.unloadActiveInstanceAssets()
            end

            local ped = PlayerPedId()
            local origin = GetEntityCoords(ped)
            local pedVehicle = GetVehiclePedIsIn(ped, false)
            local entrant = RacingSystem.Client.getLocalEntrant(joinedInstance)
            local entrantProgress = getEffectiveEntrantProgress(joinedInstance, entrant)
            local checkpoints = type(joinedInstance.checkpoints) == 'table' and joinedInstance.checkpoints or {}
            local totalCheckpoints = #checkpoints

            local chevronEdgeCache = RacingSystem.Client.getCheckpointChevronEdgeCache(joinedInstance)
            local targetIndex = 1
            local isPointToPoint = joinedInstance.pointToPoint == true
            local startLineCheckpoint = RacingSystem.Client.resolveStartLineCheckpoint(checkpoints, totalCheckpoints, nil, isPointToPoint)
            RacingSystem.Client.updateStartLineBlip(startLineCheckpoint)

            clearPendingCheckpointIfAdvanced(entrant)
            targetIndex = tonumber(entrantProgress.currentCheckpoint) or targetIndex
            local routeTargetIndex = tonumber(entrant and entrant.currentCheckpoint) or targetIndex
            local routeCurrentLap = math.max(1, tonumber(entrantProgress and entrantProgress.currentLap) or 1)
            local routeTotalLaps = math.max(1, tonumber(joinedInstance.laps) or 1)
            local allowRouteWrap = (joinedInstance.pointToPoint ~= true) and (routeCurrentLap < routeTotalLaps)
            if totalCheckpoints > 0 then
                local routeInstanceId = tonumber(joinedInstance.id)
                if raceRuntimeState.futureBlipInstanceId ~= routeInstanceId
                    or raceRuntimeState.futureBlipCheckpointIndex ~= routeTargetIndex then
                    RacingSystem.Client.updateFutureCheckpointBlips(joinedInstance, totalCheckpoints, routeTargetIndex, allowRouteWrap)
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
                    local joinedInstanceId2 = tonumber(joinedInstance.id)
                    local countdownEndsAt = countdownEndTimeByInstanceId[joinedInstanceId2]
                    local remainingMs = countdownEndsAt and math.max(0, countdownEndsAt - GetGameTimer()) or 0
                    RacingSystem.Client.Util.UpdateCountdownVisual(joinedInstanceId2, remainingMs)

                    if pedVehicle ~= 0 and GetPedInVehicleSeat(pedVehicle, -1) == ped then
                        SetVehicleHandbrake(pedVehicle, true)
                    end

                    if countdownEndsAt and remainingMs <= 0 and not countdownZeroReportedByInstanceId[joinedInstanceId2] then
                        countdownZeroReportedByInstanceId[joinedInstanceId2] = true
                        TriggerServerEvent('racingsystem:countdownReachedZero', joinedInstanceId2, GetGameTimer())
                    end
                elseif joinedInstance.state == RacingSystem.States.running then
                    RacingSystem.Client.Util.ClearCountdownVisual()
                    local joinedInstanceId2 = tonumber(joinedInstance.id)
                    if joinedInstanceId2 and not raceStartCueShownByInstanceId[joinedInstanceId2] then
                        raceStartCueShownByInstanceId[joinedInstanceId2] = true
                        RacingSystem.Client.Util.ShowRaceEventVisual('~g~GO!', '~w~Race is live', 1400)
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
                    RacingSystem.Client.Util.ClearCountdownVisual()
                    if pedVehicle ~= 0 and GetPedInVehicleSeat(pedVehicle, -1) == ped then
                        SetVehicleHandbrake(pedVehicle, false)
                    end
                else
                    RacingSystem.Client.Util.ClearCountdownVisual()
                    if pedVehicle ~= 0 and GetPedInVehicleSeat(pedVehicle, -1) == ped then
                        SetVehicleHandbrake(pedVehicle, false)
                    end
                end
            end

            local targetVariantEntry = RacingSystem.Client.getCheckpointVariantEntry(joinedInstance, targetIndex)
            local targetCheckpoint = targetVariantEntry and targetVariantEntry.primary or checkpoints[targetIndex]
            local secondaryTargetCheckpoint = targetVariantEntry and targetVariantEntry.secondary or nil
            if not targetCheckpoint or totalCheckpoints == 0 then
                raceRuntimeState.checkpointPassArm = nil
                raceRuntimeState.previousPosition = origin
                RacingSystem.Client.clearFutureCheckpointBlips()
                RacingSystem.Client.clearStartLineBlip()
                Wait(1000)
            else
                local checkpointCandidates = {}
                local primaryCoords = vector3(targetCheckpoint.x or 0.0, targetCheckpoint.y or 0.0, targetCheckpoint.z or 0.0)
                local primaryMarkerHeight = RacingSystem.Client.getFuturePreviewMarkerHeight(#(origin - primaryCoords))
                local secondaryCoords = nil
                local secondaryMarkerHeight = nil
                checkpointCandidates[#checkpointCandidates + 1] = {
                    routeVariant = 'primary',
                    checkpoint = targetCheckpoint,
                    distance = RacingSystem.Client.getHorizontalDistance(origin, targetCheckpoint),
                    drawDistance = #(origin - primaryCoords),
                }

                if type(secondaryTargetCheckpoint) == 'table' then
                    secondaryCoords = vector3(secondaryTargetCheckpoint.x or 0.0, secondaryTargetCheckpoint.y or 0.0, secondaryTargetCheckpoint.z or 0.0)
                    secondaryMarkerHeight = RacingSystem.Client.getFuturePreviewMarkerHeight(#(origin - secondaryCoords))
                    checkpointCandidates[#checkpointCandidates + 1] = {
                        routeVariant = 'secondary',
                        checkpoint = secondaryTargetCheckpoint,
                        distance = RacingSystem.Client.getHorizontalDistance(origin, secondaryTargetCheckpoint),
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

                do
                    local totalLaps = math.max(1, tonumber(joinedInstance.laps) or 1)
                    local currentLap = math.max(1, tonumber(entrantProgress and entrantProgress.currentLap) or 1)
                    local lapTriggerCheckpoint = RacingSystem.Client.getClientLapTriggerCheckpoint(totalCheckpoints)
                    local raceStartCheckpoint = RacingSystem.Client.getClientRaceStartCheckpoint(totalCheckpoints, isPointToPoint)
                    local isStart = targetIndex == raceStartCheckpoint
                    local isFinish = targetIndex == lapTriggerCheckpoint
                    local isTerminalFinish = isFinish and currentLap >= totalLaps
                    local prevIndex = targetIndex - 1
                    if prevIndex < 1 then prevIndex = totalCheckpoints end
                    local prevPrimaryCheckpoint = RacingSystem.Client.getCheckpointForVariant(joinedInstance, prevIndex, 'primary')
                        or checkpoints[prevIndex]
                    local nextPrimaryCheckpoint = RacingSystem.Client.getNextCheckpointForVariant(joinedInstance, totalCheckpoints, targetIndex, 'primary')
                    local nextSecondaryCheckpoint = RacingSystem.Client.getNextCheckpointForVariant(joinedInstance, totalCheckpoints, targetIndex, 'secondary')

                    RacingSystem.Client.drawCheckpointTarget(
                        targetCheckpoint,
                        prevPrimaryCheckpoint,
                        nextPrimaryCheckpoint,
                        isStart,
                        isFinish,
                        { r = 255, g = 225, b = 80, a = 180 },
                        { r = 255, g = 235, b = 80, a = 220 },
                        true,
                        90.0,
                        chevronEdgeCache.primary[targetIndex],
                        isTerminalFinish,
                        primaryMarkerHeight,
                        joinedInstance
                    )

                    if type(secondaryTargetCheckpoint) == 'table' then
                        RacingSystem.Client.drawCheckpointTarget(
                            secondaryTargetCheckpoint,
                            prevPrimaryCheckpoint,
                            nextSecondaryCheckpoint,
                            isStart,
                            isFinish,
                            { r = 255, g = 145, b = 35, a = 170 },
                            { r = 255, g = 170, b = 75, a = 220 },
                            true,
                            0.0,
                            chevronEdgeCache.secondary[targetIndex],
                            false,
                            secondaryMarkerHeight or primaryMarkerHeight,
                            joinedInstance
                        )
                    end

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

                    local MAX_FUTURE_PREVIEW_CHECKPOINTS = RacingSystem.Client.getMaxFuturePreviewCheckpoints()
                    local previewSteps = math.min(MAX_FUTURE_PREVIEW_CHECKPOINTS, math.max(0, totalCheckpoints - 1))
                    if joinedInstance.pointToPoint == true or currentLap >= totalLaps then
                        previewSteps = math.min(MAX_FUTURE_PREVIEW_CHECKPOINTS, math.max(0, totalCheckpoints - targetIndex))
                    end

                    for previewStep = 1, previewSteps do
                        previewIndex = previewIndex + 1
                        if previewIndex > totalCheckpoints then
                            if joinedInstance.pointToPoint == true or currentLap >= totalLaps then
                                break
                            end
                            previewIndex = 1
                        end

                        if not previewSeenIndex[previewIndex] then
                            previewSeenIndex[previewIndex] = true
                            local previewVariantEntry = RacingSystem.Client.getCheckpointVariantEntry(joinedInstance, previewIndex)
                            local previewCheckpoint = previewVariantEntry and previewVariantEntry.primary or checkpoints[previewIndex]

                            if type(previewCheckpoint) == 'table' then
                                local previewCoords = vector3(
                                    tonumber(previewCheckpoint.x) or 0.0,
                                    tonumber(previewCheckpoint.y) or 0.0,
                                    tonumber(previewCheckpoint.z) or 0.0
                                )
                                local previewPrevIndex = previewIndex - 1
                                if previewPrevIndex < 1 then previewPrevIndex = totalCheckpoints end
                                local previewPrevPrimaryCheckpoint = RacingSystem.Client.getCheckpointForVariant(joinedInstance, previewPrevIndex, 'primary')
                                    or checkpoints[previewPrevIndex]
                                local previewNextPrimaryCheckpoint = RacingSystem.Client.getNextCheckpointForVariant(joinedInstance, totalCheckpoints, previewIndex, 'primary')
                                local previewDistanceMeters = #(origin - previewCoords)
                                local previewMarkerHeight = RacingSystem.Client.getFuturePreviewMarkerHeight(previewDistanceMeters)
                                RacingSystem.Client.drawCheckpointTarget(
                                    previewCheckpoint,
                                    previewPrevPrimaryCheckpoint,
                                    previewNextPrimaryCheckpoint,
                                    false,
                                    false,
                                    previewMarkerColors[previewStep] or previewMarkerColors[#previewMarkerColors],
                                    previewChevronColors[previewStep] or previewChevronColors[#previewChevronColors],
                                    true,
                                    0.0,
                                    chevronEdgeCache.primary[previewIndex],
                                    false,
                                    previewMarkerHeight,
                                    joinedInstance
                                )
                            end
                        end
                    end
                end

                if joinedInstance.state == RacingSystem.States.idle then
                    local startCheckpoint = RacingSystem.Client.resolveStartLineCheckpoint(checkpoints, totalCheckpoints, targetCheckpoint, isPointToPoint)
                    if startCheckpoint then
                        local startLineIndex = math.max(1, math.floor(tonumber(startCheckpoint.index) or totalCheckpoints or 1))
                        startCheckpoint.nextCheckpoint = RacingSystem.Client.getNextCheckpointForVariant(joinedInstance, totalCheckpoints, startLineIndex, 'primary')
                            or checkpoints[1]
                        RacingSystem.Client.drawIdleStartChevron(startCheckpoint)
                    end
                end

                if joinedInstance.state == RacingSystem.States.running and entrant and tonumber(entrantProgress.finishedAt) == nil then
                    local pending = raceRuntimeState.pendingCheckpointPass
                    local isPendingSameCheckpoint = pending
                        and tonumber(pending.instanceId) == tonumber(joinedInstance.id)
                        and tonumber(pending.checkpointIndex) == tonumber(targetIndex)
                        and GetGameTimer() <= (pending.expiresAt or 0)
                    local withinPassDetectionRange = false
                    local nearestCheckpointDistance = math.huge
                    local nearestCheckpoint = targetCheckpoint
                    for _, candidate in ipairs(checkpointCandidates) do
                        local candidateDistance = tonumber(candidate.distance) or math.huge
                        if candidateDistance < nearestCheckpointDistance then
                            nearestCheckpointDistance = candidateDistance
                            nearestCheckpoint = candidate.checkpoint or targetCheckpoint
                        end
                        if candidateDistance <= CHECKPOINT_PASS_ARM_DISTANCE then
                            withinPassDetectionRange = true
                        end
                    end
                    if nearestCheckpointDistance < math.huge and not withinPassDetectionRange then
                        raceRuntimeState.penaltyPreviewText = nil
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

                                if distance >= (newMinDistance + CHECKPOINT_PASS_RELEASE_THRESHOLD) then
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
                                passedOutsideRadius = outsideLateralDistance > RacingSystem.Client.getCheckpointPenaltyRadius(passedTargetCheckpoint, joinedInstance)
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
                            outsideOffset = math.max(0.0, (tonumber(outsideLateralDistance) or 0.0) - RacingSystem.Client.getCheckpointPenaltyRadius(passedTargetCheckpoint, joinedInstance))
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
                            local lapTimingPayload = nil
                            local totalLaps = math.max(1, tonumber(joinedInstance.laps) or 1)
                            local lapTriggerCheckpoint = RacingSystem.Client.getClientLapTriggerCheckpoint(totalCheckpoints)
                            if targetIndex == lapTriggerCheckpoint then
                                local nowMs = GetGameTimer()
                                local raceStartedAt = tonumber(raceTimingState.raceStartedAt) or nowMs
                                local lapStartedAt = tonumber(raceTimingState.lapStartedAt) or raceStartedAt
                                local currentLapNum = math.max(1, tonumber(entrantProgress.currentLap) or 1)

                                lapTimingPayload = {
                                    lapNumber = currentLapNum,
                                    lapTimeMs = math.max(0, nowMs - lapStartedAt),
                                    totalTimeMs = math.max(0, nowMs - raceStartedAt),
                                    finished = currentLapNum >= totalLaps,
                                }

                                if lapTimingPayload.finished then
                                    raceTimingState.lapStartedAt = nil
                                else
                                    raceTimingState.lapStartedAt = nowMs
                                end

                                RacingSystem.Client.Util.NotifyPlayer('~w~' .. formatLapTime(lapTimingPayload.lapTimeMs))
                            end

                            raceRuntimeState.pendingCheckpointPass = {
                                instanceId = joinedInstance.id,
                                checkpointIndex = targetIndex,
                                expiresAt = GetGameTimer() + 1500,
                            }
                            local nextCheckpointForPassedVariant = RacingSystem.Client.getNextCheckpointForVariant(joinedInstance, totalCheckpoints, targetIndex, passedRouteVariant)
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
                                local lapTriggerCheckpoint2 = RacingSystem.Client.getClientLapTriggerCheckpoint(totalCheckpoints)
                                if targetIndex == lapTriggerCheckpoint2 and not (lapTimingPayload and lapTimingPayload.finished == true) then
                                    postPassCheckpointIndex = 1
                                end

                                local passedCheckpoint = passedTargetCheckpoint or targetCheckpoint
                                local newCurrentCheckpoint = RacingSystem.Client.getNextCheckpointForVariant(joinedInstance, totalCheckpoints, targetIndex, passedRouteVariant) or checkpoints[postPassCheckpointIndex]
                                RacingSystem.Client.runSmartCheckpointTeleport(passedCheckpoint, newCurrentCheckpoint)
                            elseif applyThrottlePenalty then
                                if pedVehicle ~= 0 and DoesEntityExist(pedVehicle) then
                                    local velocity = GetEntityVelocity(pedVehicle)
                                    SetEntityVelocity(
                                        pedVehicle,
                                        (tonumber(velocity.x) or 0.0) * 0.9,
                                        (tonumber(velocity.y) or 0.0) * 0.9,
                                        (tonumber(velocity.z) or 0.0) * 0.9
                                    )
                                end
                            elseif applyPowerPenalty then
                                applySoftPowerPenalty(pedVehicle, powerPenaltyMs)
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
                Wait(0)
            end
        end
    end
end)
