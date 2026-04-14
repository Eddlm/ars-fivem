-- Exposes the remaining client-side orchestration glue after module extraction.
local Definitions = PerformanceTuning.Definitions or {}
local HandlingFields = Definitions.handlingFields
local RuntimeConfig = PerformanceTuning.RuntimeConfig or Definitions.runtimeConfig

local RuntimeState = {
    originalHandlingByVehicle = {},
    tuningStateByVehicle = {},
    lastAppliedTuneStateByVehicle = {},
    lastAppliedPiStateByVehicle = {},
    lastPiStateUpdatedAtByVehicle = {},
    liveSurfaceLateralByVehicle = {},
    cachedEngineSwapValuesByModel = {},
    trackedVehiclesByKey = {},
    trackedVehicleKeys = {},
    trackedVehicleIndex = 0,
    pendingVehicleResyncByNetId = {},
    pendingVehicleResyncNetIds = {},
    pendingVehicleResyncIndex = 0,
    localTuneAuthoredUntilByNetId = {},
    steeringLockOverrideAppliedByVehicleKey = {},
}
local ensureTuningState, syncVehicleHandlingState, buildPerformanceIndex

local function trim(value)
    return (tostring(value or ''):match('^%s*(.-)%s*$'))
end

local function startsWith(value, prefix)
    return value:sub(1, #prefix) == prefix
end

local function isFiniteNumber(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function resetPerformanceIndexDisplayState()
    return PerformanceTuning.PerformancePanel.resetDisplayState()
end

local function computeBrakeBarProgressForVehicle(vehicle, brakeForce)
    return PerformanceTuning.PerformancePanel.computeBrakeBarProgressForVehicle(vehicle, brakeForce)
end

local function buildPerformancePanelMetrics(vehicle)
    return PerformanceTuning.PerformancePanel.buildMetrics(vehicle)
end

local function drawPerformanceIndexPanel(vehicle, options)
    return PerformanceTuning.PerformancePanel.drawPanel(vehicle, options)
end

local function drawPerformanceIndexPanelInstance(vehicle, options)
    return PerformanceTuning.PerformancePanel.drawPanelInstance(vehicle, options)
end

local function setKeepPersonalPiPanelActive(source, active)
    if PerformanceTuning.PerformancePanel and PerformanceTuning.PerformancePanel.setKeepPersonalPiPanelActive then
        PerformanceTuning.PerformancePanel.setKeepPersonalPiPanelActive(source, active)
        return true
    end
    return false
end

local function setPanelDrawRequest(source, requestKey, vehicle, options, settings)
    if PerformanceTuning.PerformancePanel and PerformanceTuning.PerformancePanel.setPanelDrawRequest then
        return PerformanceTuning.PerformancePanel.setPanelDrawRequest(source, requestKey, vehicle, options, settings)
    end
    return false
end

local function clearPanelDrawRequest(source, requestKey)
    if PerformanceTuning.PerformancePanel and PerformanceTuning.PerformancePanel.clearPanelDrawRequest then
        return PerformanceTuning.PerformancePanel.clearPanelDrawRequest(source, requestKey)
    end
    return false
end

local function notify(message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(tostring(message))
    EndTextCommandThefeedPostTicker(false, false)
end

local function clearCustomPhysicsNitrousShot(vehicle)
    return PerformanceTuning.Nitrous.clearShot(vehicle)
end

local function readHandlingValue(vehicle, fieldType, fieldName)
    return PerformanceTuning.HandlingManager.readHandlingValue(vehicle, fieldType, fieldName)
end

local function writeHandlingValue(vehicle, fieldType, fieldName, value)
    return PerformanceTuning.HandlingManager.writeHandlingValue(vehicle, fieldType, fieldName, value)
end

local function refreshVehicleAfterHandlingChange(vehicle)
    if not PerformanceTuning.VehicleManager.isVehicleEntityValid(vehicle) then
        return
    end

    -- Force vanilla performance internals to re-evaluate from a known baseline.
    SetVehicleModKit(vehicle, 0)
    SetVehicleMod(vehicle, 11, -1, false) -- Engine: stock
    SetVehicleMod(vehicle, 13, -1, false) -- Transmission: stock
    ModifyVehicleTopSpeed(vehicle, 1.2)
end

local function flatVelToEstimatedMaxSpeedMs(flatVel)
    local resolvedFlatVel = tonumber(flatVel) or 0.0
    return (resolvedFlatVel * 0.6213712 / 0.75) * 0.44704
end

local function calculateTargetDragCoeff(topSpeedFlatVel, powerValue)
    local resolvedTopSpeedFlatVel = tonumber(topSpeedFlatVel) or 0.0
    local resolvedPowerValue = tonumber(powerValue) or 0.0
    local estimatedTopSpeedMs = flatVelToEstimatedMaxSpeedMs(resolvedTopSpeedFlatVel)
    local refSpeedDrag = ((((estimatedTopSpeedMs / 0.75) / 5.0) ^ 2.0) / 2500.0)
    if refSpeedDrag <= 0.0 then
        return nil
    end

    return (resolvedPowerValue / refSpeedDrag) * 2.0
end

syncVehicleHandlingState = function(vehicle)
    return PerformanceTuning.VehicleManager.syncVehicleHandlingState(vehicle)
end

local function notifyDragRebalanceFinished()
end

local function requestDragRebalance(vehicle, options)
    if not PerformanceTuning.VehicleManager.isVehicleEntityValid(vehicle) then
        return false
    end

    options = type(options) == 'table' and options or {}
    local dragField = HandlingFields.engine and HandlingFields.engine.drag or 'fInitialDragCoeff'
    local powerField = HandlingFields.engine and HandlingFields.engine.power or 'fInitialDriveForce'
    local topSpeedField = HandlingFields.engine and HandlingFields.engine.topSpeed or 'fInitialDriveMaxFlatVel'
    local currentPower = readHandlingValue(vehicle, 'float', powerField)
    local currentTopSpeedFlatVel = readHandlingValue(vehicle, 'float', topSpeedField)
    if not isFiniteNumber(currentPower) or not isFiniteNumber(currentTopSpeedFlatVel) then
        return false
    end

    local targetDragCoeff = calculateTargetDragCoeff(currentTopSpeedFlatVel, currentPower)
    if not isFiniteNumber(targetDragCoeff) then
        return false
    end

    PerformanceTuning.HandlingManager.rememberOriginalValue(vehicle, dragField, 'float')
    writeHandlingValue(vehicle, 'float', dragField, targetDragCoeff)
    if options.skipSync ~= true then
        syncVehicleHandlingState(vehicle)
    end
    if options.skipRefresh ~= true then
        refreshVehicleAfterHandlingChange(vehicle)
    end
    notifyDragRebalanceFinished()
    return true
end


local steeringLockTargetByVehicleKey = {}
local steeringLockActiveByVehicleKey = {}

CreateThread(function()
    local steeringLockField = (HandlingFields.steering or {}).lock or 'fSteeringLock'
    local tractionLateralField = (HandlingFields.tires or {}).lateral or 'fTractionCurveLateral'
    local appliedOverrides = RuntimeState.steeringLockOverrideAppliedByVehicleKey or {}
    RuntimeState.steeringLockOverrideAppliedByVehicleKey = appliedOverrides
    local minRefreshSpeedMph = 1.0
    local maxRefreshSpeedMph = 15.0
    local minRefreshIntervalMs = 50
    local maxRefreshIntervalMs = 250

    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        local speedMph = GetEntitySpeed(vehicle) * 2.2369362920544
        local waitMs = maxRefreshIntervalMs
        if speedMph <= minRefreshSpeedMph then
            waitMs = maxRefreshIntervalMs
        elseif speedMph >= maxRefreshSpeedMph then
            waitMs = minRefreshIntervalMs
        else
            local progress = (speedMph - minRefreshSpeedMph) / (maxRefreshSpeedMph - minRefreshSpeedMph)
            waitMs = math.floor(maxRefreshIntervalMs + ((minRefreshIntervalMs - maxRefreshIntervalMs) * progress) + 0.5)
        end
        Wait(waitMs)

        if not PerformanceTuning.VehicleManager.isPedDrivingVehicle(ped, vehicle) then
            goto continue
        end

        local bucket = ensureTuningState and ensureTuningState(vehicle) or nil
        if type(bucket) ~= 'table' then
            goto continue
        end

        local vehicleKey = PerformanceTuning.VehicleManager.getVehicleCacheKey(vehicle)
        local mode = bucket.steeringLockMode or 'stock'
        local factor = PerformanceTuning.TuningPackManager.getSteeringLockModeFactor(mode)

        if type(factor) == 'number' then
            local lateral = readHandlingValue(vehicle, 'float', tractionLateralField)
            if not isFiniteNumber(lateral) then
                goto continue
            end



            local baseSteeringLock = tonumber(bucket.baseSteeringLock)
            if not isFiniteNumber(baseSteeringLock) then
                -- Prefer the pre-override original value stored by rememberOriginalValue,
                -- so we never seed baseSteeringLock from an already-overridden live field.
                local origBucket = PerformanceTuning.VehicleManager.getVehicleBucket(vehicle, false)
                local origEntry = origBucket and origBucket[steeringLockField]
                if origEntry and isFiniteNumber(origEntry.value) then
                    baseSteeringLock = origEntry.value
                else
                    baseSteeringLock = readHandlingValue(vehicle, 'float', steeringLockField)
                end
                if isFiniteNumber(baseSteeringLock) then
                    bucket.baseSteeringLock = baseSteeringLock
                end
            end
            local targetSteeringLock = lateral * ( baseSteeringLock/lateral) * factor
            if not isFiniteNumber(targetSteeringLock) then
                goto continue
            end
            -- If steering input and lateral slide are opposite, the driver is countersteering —
            -- restore original lock. Same direction means sliding with steering, apply factor.
            local localVel = GetEntitySpeedVector(vehicle, true)
            local lateralSlide = localVel.x  -- positive = sliding right in vehicle space
            local steeringInput = GetVehicleSteeringAngle(vehicle)  -- positive = turning right
            local threshold = lateral / 3.0
            local oppositeSide = (lateralSlide > threshold and steeringInput < -threshold) or (lateralSlide < -threshold and steeringInput > threshold)
            if oppositeSide and isFiniteNumber(baseSteeringLock) then
                targetSteeringLock = baseSteeringLock
            else
                if isFiniteNumber(baseSteeringLock) then
                    local minBlendSpeedMph = 5.0
                    local maxBlendSpeedMph = 30.0
                    if speedMph <= minBlendSpeedMph then
                        targetSteeringLock = baseSteeringLock
                    elseif speedMph < maxBlendSpeedMph then
                        local blend = (speedMph - minBlendSpeedMph) / (maxBlendSpeedMph - minBlendSpeedMph)
                        targetSteeringLock = baseSteeringLock + ((targetSteeringLock - baseSteeringLock) * blend)
                    end
                end
            end
        
            if type(vehicleKey) == 'string' and vehicleKey ~= '' then
                steeringLockTargetByVehicleKey[vehicleKey] = targetSteeringLock
                appliedOverrides[vehicleKey] = true
            end
            PerformanceTuning.HandlingManager.rememberOriginalValue(vehicle, steeringLockField, 'float')
        else
            local shouldRestore = type(vehicleKey) == 'string' and vehicleKey ~= '' and appliedOverrides[vehicleKey] == true
            if shouldRestore then
                local baseSteeringLock = tonumber(bucket.baseSteeringLock)
                if not isFiniteNumber(baseSteeringLock) then
                    baseSteeringLock = readHandlingValue(vehicle, 'float', steeringLockField)
                    bucket.baseSteeringLock = baseSteeringLock
                end
                if type(vehicleKey) == 'string' and vehicleKey ~= '' then
                    steeringLockTargetByVehicleKey[vehicleKey] = baseSteeringLock
                end
                appliedOverrides[vehicleKey] = nil
                steeringLockActiveByVehicleKey[vehicleKey] = nil
            end
        end

        ::continue::
    end
end)

CreateThread(function()
    local steeringLockField = (HandlingFields.steering or {}).lock or 'fSteeringLock'
    while true do
                Wait(0)

        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if not PerformanceTuning.VehicleManager.isPedDrivingVehicle(ped, vehicle) then
            goto continueFrame
        end
        local vehicleKey = PerformanceTuning.VehicleManager.getVehicleCacheKey(vehicle)
        if type(vehicleKey) ~= 'string' or vehicleKey == '' then
            goto continueFrame
        end
        local target = steeringLockTargetByVehicleKey[vehicleKey]
        if not isFiniteNumber(target) then
            goto continueFrame
        end
        local current = steeringLockActiveByVehicleKey[vehicleKey] or target

        local applied = current + (target - current) * 0.5
        steeringLockActiveByVehicleKey[vehicleKey] = applied
        writeHandlingValue(vehicle, 'float', steeringLockField, applied)

        ::continueFrame::
    end
end)

CreateThread(function()
    while true do
        Wait(500)

        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if PerformanceTuning.VehicleManager.isPedDrivingVehicle(ped, vehicle) then
            PerformanceTuning.VehicleManager.syncVehiclePiState(vehicle, true, false)
        end
    end
end)

local function logInfo(message)
    return message
end

ensureTuningState = function(vehicle)
    return PerformanceTuning.VehicleManager.ensureTuningState(vehicle)
end

buildPerformanceIndex = function(vehicle, bucket)
    return PerformanceTuning.PerformancePanel.buildPerformanceIndex(vehicle, bucket)
end

local function getVehicleDisplayName(vehicle)
    local displayCode = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)) or ''
    local displayName = displayCode

    if displayCode ~= '' and displayCode ~= 'CARNOTFOUND' then
        local label = GetLabelText(displayCode)
        if label and label ~= '' and label ~= 'NULL' then
            displayName = label
        end
    end

    if displayName == '' or displayName == 'CARNOTFOUND' then
        displayName = 'CURRENT CAR'
    end

    return displayName
end

local function getVehicleModelAudioName(vehicle)
    if not PerformanceTuning.VehicleManager.isVehicleEntityValid(vehicle) then
        return nil
    end

    local modelName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    if modelName == nil or modelName == '' or modelName == 'CARNOTFOUND' then
        return nil
    end

    return tostring(modelName)
end


local function buildNativeListState(context)
    local vehicle, vehicleError = PerformanceTuning.VehicleManager.getCurrentVehicle()
    if not vehicle then
        return nil, vehicleError
    end

    local bucket = ensureTuningState(vehicle)
    local function isUnavailableTirePack(pack, baseTireMax)
        local barFillTargets = (PerformanceTuning.RuntimeConfig or {}).performanceBarFillTargets or {}
        local performance = ((PerformanceTuning or {})._internals or {}).Performance or {}
        local barSegmentCount = math.max(1, math.floor(tonumber(performance.barSegmentCount) or tonumber(barFillTargets.barSegmentCount) or 20))
        local gripTarget = tonumber(barFillTargets.grip) or 2.5
        if gripTarget <= 0.0 then
            gripTarget = 2.5
        end
        local gripBarScaleFactor = tonumber(performance.gripBarScaleFactor) or (barSegmentCount / gripTarget)
        if type(pack) ~= 'table' or pack.enabled == false then
            return true
        end

        if pack.id == 'stock' or pack.id == 'rally' or not isFiniteNumber(baseTireMax) or pack.gripBarProgressRatio == nil then
            return false
        end

        local targetGripValue = (math.max(0.0, math.min(1.0, tonumber(pack.gripBarProgressRatio) or 0.0)) * barSegmentCount) / gripBarScaleFactor
        return targetGripValue < baseTireMax
    end

    if context == 'tires' and bucket and bucket.tireCompoundPack and bucket.tireCompoundPack ~= 'stock' then
        local tireCompoundPacks = ((((PerformanceTuning.Config or {}).packDefinitions) or {}).tires) or {}
        for _, pack in ipairs(tireCompoundPacks) do
            if pack.id == bucket.tireCompoundPack then
                local baseTireMax = bucket.baseTires and bucket.baseTires[HandlingFields.tires.max]
                if isUnavailableTirePack(pack, baseTireMax) then
                    PerformanceTuning.TuningPackManager.applyTireCompoundPack(vehicle, 'stock', { skipLog = true })
                    PerformanceTuning.VehicleManager.syncVehicleTuneState(vehicle)
                end
                break
            end
        end
    end

    bucket = ensureTuningState(vehicle)
    local contextDetails = PerformanceTuning.TuningPackManager.getContextDetails(bucket, context)
    return {
        vehicle = vehicle,
        displayName = getVehicleDisplayName(vehicle),
        summary = {
            engine = PerformanceTuning.TuningPackManager.getEnginePackLabel(bucket.enginePack),
            engineSwap = PerformanceTuning.TuningPackManager.getEngineSwapPackLabel(bucket.engineSwapPack),
            transmission = PerformanceTuning.TuningPackManager.getTransmissionPackLabel(bucket.transmissionPack),
            suspension = PerformanceTuning.TuningPackManager.getSuspensionPackLabel(bucket.suspensionPack),
            tires = ('%s / %s'):format(
                PerformanceTuning.TuningPackManager.getTireCompoundCategoryLabel(bucket.tireCompoundCategory),
                PerformanceTuning.TuningPackManager.getTireCompoundQualityLabel(bucket.tireCompoundQuality)
            ),
            nitrous = PerformanceTuning.TuningPackManager.getNitrousPackLabel(bucket.nitrousLevel),
        },
        performanceIndex = buildPerformanceIndex(vehicle, bucket),
        context = contextDetails,
    }
end

local function applyCurrentVehicleStateBagTuningForMenu()
    local vehicle = PerformanceTuning.VehicleManager.getCurrentVehicle()
    if not vehicle then
        return false
    end

    if not PerformanceTuning.VehicleManager.ensureVehicleNetworked(vehicle, 1500) then
        return false
    end

    local state = Entity(vehicle).state[(Definitions.stateBagKeys or {}).tune]
    if type(state) ~= 'table' then
        return true
    end

    if PerformanceTuning.VehicleManager.tuneStatesEqual(PerformanceTuning.VehicleManager.getLastAppliedTuneState(vehicle), state) then
        return true
    end

    PerformanceTuning.TuningPackManager.applySynchronizedTuneState(vehicle, state, {
        skipLog = true,
    })

    return true
end

local function applyNativeMenuSelection(context, index)
    local vehicle, vehicleError = PerformanceTuning.VehicleManager.getCurrentVehicle()
    if not vehicle then
        if PerformanceTuning.ScaleformUI and PerformanceTuning.ScaleformUI.closeMenu then
            PerformanceTuning.ScaleformUI.closeMenu()
        end
        return false, vehicleError
    end

    local scaleformUIState = PerformanceTuning.ScaleformUI and PerformanceTuning.ScaleformUI.state or nil
    local optionsByContext = scaleformUIState and scaleformUIState.options or nil
    local options = optionsByContext and optionsByContext[context] or nil
    local option = type(options) == 'table' and options[index] or nil
    local bucket = PerformanceTuning.VehicleManager.ensureTuningState(vehicle)
    local selectionByContext = {
        engine = bucket.enginePack,
        engineSwap = bucket.engineSwapPack,
        transmission = bucket.transmissionPack,
        suspension = bucket.suspensionPack,
        tires = bucket.tireCompoundPack,
        tireCompoundCategory = bucket.tireCompoundCategory,
        tireCompoundQuality = bucket.tireCompoundQuality,
        brakes = bucket.brakePack,
        handbrakes = bucket.handbrakePack,
        nitrous = bucket.nitrousLevel,
        nitro = bucket.nitrousLevel,
    }
    local currentSelectionId = selectionByContext[context]

    if (context == 'tires' or context == 'tireCompoundQuality') and option and option.enabled == false then
        local ok, resultOrError = PerformanceTuning.TuningPackManager.applyTunePackForContext(vehicle, context, 'stock')
        if not ok then
            return false, resultOrError
        end

        PerformanceTuning.VehicleManager.syncVehicleTuneState(vehicle)
        return true, resultOrError
    end

    if not option or option.enabled == false then
        return false, 'Selected tuning pack is unavailable.'
    end

    if currentSelectionId == option.id then
        return true, option.label
    end

    local ok, resultOrError = PerformanceTuning.TuningPackManager.applyTunePackForContext(vehicle, context, option.id)
    if not ok then
        return false, resultOrError
    end

    PerformanceTuning.VehicleManager.syncVehicleTuneState(vehicle)
    return true, resultOrError
end

exports('GetCurrentVehicle', function()
    return PerformanceTuning.VehicleManager.getCurrentVehicle()
end)

exports('GetMaterialTyreGrip', function(materialIndex)
    return PerformanceTuning.SurfaceGrip.getMaterialTyreGripByIndex(materialIndex)
end)

exports('InferHandlingFieldType', function(fieldName)
    local resolvedFieldName = PerformanceTuning.HandlingManager.normalizeFieldName(fieldName)
    if not resolvedFieldName then
        return nil
    end

    return PerformanceTuning.HandlingManager.normalizeFieldType(nil, resolvedFieldName)
end)

exports('GetHandlingField', function(fieldName, fieldType, vehicle)
    return PerformanceTuning.HandlingManager.getHandlingField(fieldName, fieldType, vehicle)
end)

exports('SetHandlingField', function(fieldName, value, fieldType, vehicle)
    return PerformanceTuning.HandlingManager.setHandlingField(fieldName, value, fieldType, vehicle)
end)

exports('ResetHandlingField', function(fieldName, vehicle)
    return PerformanceTuning.HandlingManager.resetHandlingField(fieldName, vehicle)
end)

exports('ResetAllHandling', function(vehicle)
    return PerformanceTuning.HandlingManager.resetAllHandling(vehicle)
end)

exports('GetPerformancePanelMetrics', function(vehicle)
    return buildPerformancePanelMetrics(vehicle)
end)

exports('DrawPerformanceIndexPanel', function(vehicle)
    if not PerformanceTuning.VehicleManager.isVehicleEntityValid(vehicle) then
        resetPerformanceIndexDisplayState()
        return false
    end

    PerformanceTuning.PerformancePanel.state = PerformanceTuning.PerformancePanel.state or {}
    PerformanceTuning.PerformancePanel.state.externalKeepAliveUntil = GetGameTimer() + 100
    drawPerformanceIndexPanel(vehicle)
    return true
end)

exports('DrawPerformanceIndexPanelInstance', function(vehicle, options)
    if not PerformanceTuning.VehicleManager.isVehicleEntityValid(vehicle) then
        return false
    end

    PerformanceTuning.PerformancePanel.state = PerformanceTuning.PerformancePanel.state or {}
    PerformanceTuning.PerformancePanel.state.externalKeepAliveUntil = GetGameTimer() + 100
    return drawPerformanceIndexPanelInstance(vehicle, options)
end)

exports('SetKeepPersonalPiPanelActive', function(source, active)
    return setKeepPersonalPiPanelActive(source, active)
end)

exports('SetPanelDrawRequest', function(source, requestKey, vehicle, options, settings)
    return setPanelDrawRequest(source, requestKey, vehicle, options, settings)
end)

exports('ClearPanelDrawRequest', function(source, requestKey)
    return clearPanelDrawRequest(source, requestKey)
end)

exports('OpenPerformanceTuningMenu', function()
    if PerformanceTuning.ScaleformUI and PerformanceTuning.ScaleformUI.openMainMenu then
        return PerformanceTuning.ScaleformUI.openMainMenu() == true
    end

    return false
end)

exports('GetPiDisplayModeIndex', function()
    if PerformanceTuning.ScaleformUI and PerformanceTuning.ScaleformUI.getPiDisplayModeIndex then
        return PerformanceTuning.ScaleformUI.getPiDisplayModeIndex()
    end

    return 1
end)

exports('SetPiDisplayModeIndex', function(index)
    if PerformanceTuning.ScaleformUI and PerformanceTuning.ScaleformUI.setPiDisplayModeIndex then
        return PerformanceTuning.ScaleformUI.setPiDisplayModeIndex(index)
    end

    return 1
end)

exports('GetPerformanceBarsDisplayMode', function()
    if PerformanceTuning.ScaleformUI and PerformanceTuning.ScaleformUI.getPerformanceBarsDisplayMode then
        return PerformanceTuning.ScaleformUI.getPerformanceBarsDisplayMode()
    end

    return 'absolute_benchmark'
end)

local function applyPerformanceBarsModeRequest(requestedMode)
    local scaleformUI = PerformanceTuning.ScaleformUI
    if not scaleformUI or type(scaleformUI.setPerformanceBarsDisplayMode) ~= 'function' or type(scaleformUI.getPerformanceBarsDisplayMode) ~= 'function' then
        return 'absolute_benchmark'
    end

    local targetMode = tostring(requestedMode or ''):lower()
    if targetMode == '' or targetMode == 'toggle' then
        local currentMode = tostring(scaleformUI.getPerformanceBarsDisplayMode() or 'absolute_benchmark')
        targetMode = (currentMode == 'vehicle_relative') and 'absolute' or 'relative'
    end

    return scaleformUI.setPerformanceBarsDisplayMode(targetMode)
end

exports('SetPerformanceBarsDisplayMode', function(mode)
    return applyPerformanceBarsModeRequest(mode)
end)

exports('GetCurrentVehicleRevLimiterEnabled', function()
    if PerformanceTuning.ScaleformUI and PerformanceTuning.ScaleformUI.getCurrentVehicleRevLimiterEnabled then
        return PerformanceTuning.ScaleformUI.getCurrentVehicleRevLimiterEnabled()
    end

    return nil
end)

exports('SetCurrentVehicleRevLimiterEnabled', function(enabled)
    if PerformanceTuning.ScaleformUI and PerformanceTuning.ScaleformUI.setCurrentVehicleRevLimiterEnabled then
        return PerformanceTuning.ScaleformUI.setCurrentVehicleRevLimiterEnabled(enabled)
    end

    return false
end)

exports('GetCurrentVehicleSteeringLockMode', function()
    if PerformanceTuning.ScaleformUI and PerformanceTuning.ScaleformUI.getCurrentVehicleSteeringLockMode then
        return PerformanceTuning.ScaleformUI.getCurrentVehicleSteeringLockMode()
    end

    return nil
end)

exports('SetCurrentVehicleSteeringLockMode', function(mode)
    if PerformanceTuning.ScaleformUI and PerformanceTuning.ScaleformUI.setCurrentVehicleSteeringLockMode then
        return PerformanceTuning.ScaleformUI.setCurrentVehicleSteeringLockMode(mode)
    end

    return false, nil
end)

PerformanceTuning.RuntimeState = RuntimeState
PerformanceTuning.RuntimeConfig = RuntimeConfig
PerformanceTuning.ClientBindings = {
    trim = trim,
    startsWith = startsWith,
    isFiniteNumber = isFiniteNumber,
    readHandlingValue = readHandlingValue,
    writeHandlingValue = writeHandlingValue,
    refreshVehicleAfterHandlingChange = refreshVehicleAfterHandlingChange,
    computeBrakeBarProgressForVehicle = computeBrakeBarProgressForVehicle,
    getVehicleModelAudioName = getVehicleModelAudioName,
    logInfo = logInfo,
    clearCustomPhysicsNitrousShot = clearCustomPhysicsNitrousShot,
    requestDragRebalance = requestDragRebalance,
    notify = notify,
    buildListState = buildNativeListState,
    applyCurrentVehicleStateBagTuningForMenu = applyCurrentVehicleStateBagTuningForMenu,
    applyMenuSelection = applyNativeMenuSelection,
    ensureTuningState = ensureTuningState,
    resetPerformanceIndexDisplayState = resetPerformanceIndexDisplayState,
    drawPerformanceIndexPanel = drawPerformanceIndexPanel,
    drawPerformanceIndexPanelInstance = drawPerformanceIndexPanelInstance,
    applyPerformanceBarsModeRequest = applyPerformanceBarsModeRequest,
}


RegisterNetEvent('racingsystem:stableLapTime', function(payload)
    TriggerEvent('performancetuning:stableLapTime', payload)
end)

AddEventHandler('performancetuning:stableLapTime', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if not PerformanceTuning.VehicleManager.isPedDrivingVehicle(ped, vehicle) then
        return
    end

    local modelHash = GetEntityModel(vehicle)
    local modelName = GetDisplayNameFromVehicleModel(modelHash)
    local metrics = buildPerformancePanelMetrics(vehicle) or {}
    local piValues = type(metrics.values) == 'table' and metrics.values or {}

    TriggerServerEvent('performancetuning:storeStableLapSample', {
        model = (type(modelName) == 'string' and modelName ~= '' and modelName) or tostring(modelHash),
        pi = {
            total = math.max(0, math.floor(tonumber(metrics.total) or 0)),
            power = math.max(0, math.floor(tonumber(piValues[1]) or 0)),
            speed = math.max(0, math.floor(tonumber(piValues[2]) or 0)),
            grip = math.max(0, math.floor(tonumber(piValues[3]) or 0)),
            brake = math.max(0, math.floor(tonumber(piValues[4]) or 0)),
        },
    })
end)

RegisterNetEvent('performancetuning:stableLapStored', function(payload)
    if type(payload) ~= 'table' then
        return
    end

    local model = tostring(payload.model or 'vehicle')
    if payload.status == 'comparison' then
        local currentPi = type(payload.currentPi) == 'table' and payload.currentPi or {}
        local existingPi = type(payload.existingPi) == 'table' and payload.existingPi or {}
        local deltaPi = type(payload.deltaPi) == 'table' and payload.deltaPi or {}
        notify(('%s PI already saved | Current %d vs Saved %d (%+d) | PWR %d/%d (%+d) SPD %d/%d (%+d) GRP %d/%d (%+d) BRK %d/%d (%+d)'):format(
            model,
            tonumber(currentPi.total) or 0,
            tonumber(existingPi.total) or 0,
            tonumber(deltaPi.total) or 0,
            tonumber(currentPi.power) or 0,
            tonumber(existingPi.power) or 0,
            tonumber(deltaPi.power) or 0,
            tonumber(currentPi.speed) or 0,
            tonumber(existingPi.speed) or 0,
            tonumber(deltaPi.speed) or 0,
            tonumber(currentPi.grip) or 0,
            tonumber(existingPi.grip) or 0,
            tonumber(deltaPi.grip) or 0,
            tonumber(currentPi.brake) or 0,
            tonumber(existingPi.brake) or 0,
            tonumber(deltaPi.brake) or 0
        ))
        return
    end

    local pi = type(payload.pi) == 'table' and payload.pi or {}
    notify(('Saved PI for %s | TOTAL %d | PWR %d SPD %d GRP %d BRK %d'):format(
        model,
        tonumber(pi.total) or 0,
        tonumber(pi.power) or 0,
        tonumber(pi.speed) or 0,
        tonumber(pi.grip) or 0,
        tonumber(pi.brake) or 0
    ))
end)
