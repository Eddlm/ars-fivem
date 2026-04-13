-- Computes and draws the live performance index panel and its frame loop.
PerformanceTuning = PerformanceTuning or {}
PerformanceTuning.PerformancePanel = PerformanceTuning.PerformancePanel or {}

local PerformancePanel = PerformanceTuning.PerformancePanel
local PanelConfig = ((((PerformanceTuning or {}).Config or {}).advanced or {}).panel or {})
local INTERNAL_PERFORMANCE_DEFAULTS = {
    barSegmentCount = 20,
    power = 0.60,
    topSpeedMph = 220.0,
    grip = 2.50,
    brake = 2.50,
    flatVelToMphFactor = 145.0 / 176.0,
}
local SHARED_PANEL_HEIGHT_UNITS = PanelConfig.sharedPanelHeightUnits or 0.15
local SHARED_PANEL_BASE_SCALE = PanelConfig.sharedPanelBaseScale or 0.95
local SHARED_PANEL_MIN_SCALE = PanelConfig.sharedPanelMinScale or 0.72
local SHARED_PANEL_ALPHA = math.floor(PanelConfig.sharedPanelAlpha or 168)
local SHARED_PANEL_FILL_ALPHA = math.floor(PanelConfig.sharedPanelFillAlpha or 204)
local SHARED_PANEL_HEADER_HEIGHT_RATIO = PanelConfig.sharedPanelHeaderHeightRatio or 0.15
local SHARED_PANEL_TEXT_BASE_HEIGHT_UNITS = PanelConfig.sharedPanelTextBaseHeightUnits or 0.20
local SHARED_PANEL_WIDTH_UNITS = PanelConfig.sharedPanelWidthUnits or 0.1875
local DEFAULT_PANEL_HEIGHT_UNITS = PanelConfig.defaultPanelHeightUnits or 0.0874
local PRIMARY_PANEL_LEFT_MARGIN = PanelConfig.primaryPanelLeftMargin or 0.014
local MENU_PANEL_GAP_X = PanelConfig.menuPanelGapX or 0.018
local STACKED_PANEL_GAP_Y = PanelConfig.stackedPanelGapY or 0.0032
local DEFAULT_MENU_LEFT_PX = PanelConfig.defaultMenuLeftPx or 20.0
local DEFAULT_MENU_WIDTH_PX = PanelConfig.defaultMenuWidthPx or 431.0
local PANEL_DRAW_REQUEST_STALE_MS = math.max(0, math.floor(PanelConfig.panelDrawRequestStaleMs or 1000))
local MAIN_PANEL_Y_OFFSET = PanelConfig.mainPanelYOffset or -0.01
local getPrimaryPanelPlacement

local function getNitrousUpgradeLevel(bucket)
    local packs = ((PerformanceTuning.Config or {}).packDefinitions or {}).nitrous or {}
    local selectedLevel = type(bucket) == 'table' and bucket.nitrousLevel or 'stock'
    local level = 0

    for index, pack in ipairs(packs) do
        if type(pack) == 'table' and pack.enabled ~= false then
            if index > 1 then
                level = level + 1
            end
            if pack.id == selectedLevel then
                return math.max(0, level)
            end
        end
    end

    return 0
end

local function getNitrousPowerBonusValue(bucket, runtimeConfig, performance)
    local performanceModel = (runtimeConfig or {}).performanceModel or (runtimeConfig or {}).performanceBars or {}
    local nitrousConfig = ((performanceModel.power or {}).nitrous or {})
    local powerBarScaleFactor = tonumber((performance or {}).powerBarScaleFactor) or 0.0
    local barSegmentCount = math.max(1, math.floor(tonumber((performance or {}).barSegmentCount) or INTERNAL_PERFORMANCE_DEFAULTS.barSegmentCount))
    if powerBarScaleFactor <= 0.0 then
        powerBarScaleFactor = barSegmentCount / INTERNAL_PERFORMANCE_DEFAULTS.power
    end
    local powerFillTargetValue = barSegmentCount / powerBarScaleFactor

    local fillPerLevelPercent = tonumber(nitrousConfig.powerBarFillPerNitroLevel) or 0.0
    if fillPerLevelPercent < 0.0 then
        fillPerLevelPercent = 0.0
    end
    local bonusFill = getNitrousUpgradeLevel(bucket) * (fillPerLevelPercent / 100.0)
    return math.max(0.0, bonusFill * powerFillTargetValue)
end

local function getDisplayState()
    local state = PerformancePanel.state or {}
    if type(state.panelStatesByKey) ~= 'table' then
        state.panelStatesByKey = {}
    end
    if type(state.nearbyVehicleCache) ~= 'table' then
        state.nearbyVehicleCache = {
            sourceVehicle = nil,
            lastUpdatedAt = 0,
            entries = {},
        }
    end
    if type(state.nearbyScanner) ~= 'table' then
        state.nearbyScanner = {
            carsPerSecond = 500.0,
            carBudgetAccumulator = 0.0,
            vehicles = {},
            cursor = 1,
            resultsByVehicle = {},
            request = { active = false },
            lastRequestSignature = '',
        }
    end
    state.visible = state.visible == true
    state.externalKeepAliveUntil = tonumber(state.externalKeepAliveUntil) or 0
    state.lastPrimaryVehicle = tonumber(state.lastPrimaryVehicle) or 0
    state.lastDrivenVehicle = tonumber(state.lastDrivenVehicle) or 0
    if type(state.panelController) ~= 'table' then
        state.panelController = {
            nextRefreshAt = 0,
            refreshIntervalMs = 300,
        }
    end
    if type(state.panelDrawRequests) ~= 'table' then
        state.panelDrawRequests = {}
    end
    if type(state.keepPersonalPiPanelSources) ~= 'table' then
        state.keepPersonalPiPanelSources = {}
    end
    PerformancePanel.state = state
    return state
end

function PerformancePanel.setPanelDrawRequest(source, requestKey, vehicle, options, settings)
    local sourceId = tostring(source or 'unknown')
    local key = tostring(requestKey or 'default')
    local state = getDisplayState()
    state.panelDrawRequests[sourceId] = state.panelDrawRequests[sourceId] or {}

    if not PerformanceTuning.VehicleManager.isVehicleEntityValid(vehicle) then
        state.panelDrawRequests[sourceId][key] = nil
        return false
    end

    local requestOptions = {}
    if type(options) == 'table' then
        for optionKey, optionValue in pairs(options) do
            requestOptions[optionKey] = optionValue
        end
    end
    local requestSettings = {}
    if type(settings) == 'table' then
        for settingKey, settingValue in pairs(settings) do
            requestSettings[settingKey] = settingValue
        end
    end

    state.panelDrawRequests[sourceId][key] = {
        vehicle = vehicle,
        options = requestOptions,
        settings = requestSettings,
        updatedAt = GetGameTimer(),
    }
    return true
end

function PerformancePanel.clearPanelDrawRequest(source, requestKey)
    local sourceId = tostring(source or 'unknown')
    local key = tostring(requestKey or 'default')
    local state = getDisplayState()
    local sourceRequests = state.panelDrawRequests[sourceId]
    if type(sourceRequests) ~= 'table' then
        return false
    end

    sourceRequests[key] = nil
    return true
end

local function collectActivePanelDrawRequests(now)
    local state = getDisplayState()
    local requests = {}
    local requestsBySource = state.panelDrawRequests or {}
    for sourceId, sourceRequests in pairs(requestsBySource) do
        if type(sourceRequests) == 'table' then
            for key, entry in pairs(sourceRequests) do
                local isStale = (now - (tonumber(type(entry) == 'table' and entry.updatedAt or 0) or 0)) > PANEL_DRAW_REQUEST_STALE_MS
                local vehicle = type(entry) == 'table' and entry.vehicle or nil
                if isStale or not PerformanceTuning.VehicleManager.isVehicleEntityValid(vehicle) then
                    sourceRequests[key] = nil
                else
                    requests[#requests + 1] = {
                        source = sourceId,
                        key = key,
                        vehicle = vehicle,
                        options = type(entry.options) == 'table' and entry.options or {},
                        settings = type(entry.settings) == 'table' and entry.settings or {},
                    }
                end
            end
        end
    end

    table.sort(requests, function(a, b)
        local aId = ('%s:%s'):format(tostring(a.source), tostring(a.key))
        local bId = ('%s:%s'):format(tostring(b.source), tostring(b.key))
        return aId < bId
    end)

    return requests
end

local function applyTopRightPlacementToDrawOptions(drawOptions)
    local panelScale = tonumber(drawOptions.panelScale) or 0.95
    local panelHeightUnits = tonumber(drawOptions.panelHeightUnits) or (0.15 * panelScale)
    local safeZone = GetSafeZoneSize()
    local safeInset = (1.0 - safeZone) * 0.5
    local panelWidth = 0.1875 * panelScale
    drawOptions.panelScale = panelScale
    drawOptions.panelHeightUnits = panelHeightUnits
    drawOptions.panelLeftX = drawOptions.panelLeftX or ((1.0 - safeInset) - panelWidth - 0.01)
    drawOptions.panelY = drawOptions.panelY or (safeInset + (panelHeightUnits * 0.5) + MAIN_PANEL_Y_OFFSET)
end

local function getTopRightDockPlacement(panelScale, panelHeightUnits)
    local resolvedScale = tonumber(panelScale) or 0.95
    local resolvedHeight = tonumber(panelHeightUnits) or (0.15 * resolvedScale)
    local safeZone = GetSafeZoneSize()
    local safeInset = (1.0 - safeZone) * 0.5
    local panelWidth = 0.1875 * resolvedScale
    return {
        panelLeftX = (1.0 - safeInset) - panelWidth - 0.01,
        panelY = safeInset + (resolvedHeight * 0.5) + MAIN_PANEL_Y_OFFSET,
    }
end

local function drawPanelDrawRequests(now)
    local requests = collectActivePanelDrawRequests(now)
    local drawnCount = 0
    for _, request in ipairs(requests) do
        local drawOptions = {}
        for optionKey, optionValue in pairs(request.options or {}) do
            drawOptions[optionKey] = optionValue
        end
        local settings = request.settings or {}
        local stackMode = tostring(settings.stackMode or 'top_right')
        if drawOptions.panelLeftX == nil and drawOptions.panelY == nil and stackMode == 'top_right' then
            applyTopRightPlacementToDrawOptions(drawOptions)
        end
        if settings.barsMode ~= nil and drawOptions.barMode == nil then
            drawOptions.barMode = settings.barsMode
        end
        local onFootMode = tostring(settings.onFootMode or 'hide')
        if onFootMode == 'hide' and GetVehiclePedIsIn(PlayerPedId(), false) == 0 then
            goto continue_request
        end
        drawOptions.forceWhileMenuOpen = true
        if drawOptions.stateKey == nil then
            drawOptions.stateKey = ('request:%s:%s'):format(tostring(request.source), tostring(request.key))
        end

        if PerformancePanel.drawPanelInstance(request.vehicle, drawOptions) then
            drawnCount = drawnCount + 1
        end

        ::continue_request::
    end

    return drawnCount
end

function PerformancePanel.setKeepPersonalPiPanelActive(source, isActive)
    local state = getDisplayState()
    local sourceKey = tostring(source or 'unknown')
    state.keepPersonalPiPanelSources[sourceKey] = isActive == true
end

function PerformancePanel.isKeepPersonalPiPanelActive()
    local sources = (getDisplayState() or {}).keepPersonalPiPanelSources or {}
    for _, value in pairs(sources) do
        if value == true then
            return true
        end
    end
    return false
end

local function getPanelAnimationState(displayState, stateKey)
    local key = tostring(stateKey or 'default')
    local panelStates = displayState.panelStatesByKey
    local panelState = panelStates[key]
    if type(panelState) ~= 'table' then
        panelState = {
            fills = { 0.0, 0.0, 0.0, 0.0 },
            lastSeenAt = 0,
        }
        panelStates[key] = panelState
    end

    if type(panelState.fills) ~= 'table' then
        panelState.fills = { 0.0, 0.0, 0.0, 0.0 }
    end
    for index = 1, 4 do
        panelState.fills[index] = tonumber(panelState.fills[index]) or 0.0
    end

    panelState.lastSeenAt = GetGameTimer()
    return panelState
end

local function pruneInactivePanelStates(displayState, now)
    local panelStates = displayState.panelStatesByKey or {}
    for key, panelState in pairs(panelStates) do
        local staleFor = now - (tonumber(type(panelState) == 'table' and panelState.lastSeenAt or 0) or 0)
        if staleFor > 2000 then
            panelStates[key] = nil
        end
    end
end

local function drawPiCenteredText(x, y, scale, text)
    SetTextFont(0)
    SetTextProportional(false)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 220)
    SetTextDropShadow()
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextOutline()
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(x, y)
end

local function drawPiLeftText(x, y, scale, text)
    SetTextFont(0)
    SetTextProportional(false)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 220)
    SetTextDropShadow()
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextOutline()
    SetTextCentre(false)
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(x, y)
end

local function drawPiRightText(x, y, scale, text)
    SetTextFont(0)
    SetTextProportional(false)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 220)
    SetTextDropShadow()
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextOutline()
    SetTextRightJustify(true)
    SetTextWrap(0.0, x)
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(x, y)
end

local function getPanelVehicleDisplayName(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return 'CURRENT CAR'
    end

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

    return string.upper(tostring(displayName))
end

local function getUiAspectWidth(heightUnits)
    local resX, resY = GetActiveScreenResolution()
    if not resX or not resY or resX <= 0 or resY <= 0 then
        return heightUnits
    end

    return heightUnits * (resY / resX)
end

local function getSharedPanelWidth()
    return SHARED_PANEL_WIDTH_UNITS
end

function PerformancePanel.resetDisplayState()
    local state = getDisplayState()
    state.visible = false
    state.panelStatesByKey = {}
    state.panelDrawRequests = {}
    state.panelController = {
        nextRefreshAt = 0,
        refreshIntervalMs = 300,
    }
    state.nearbyVehicleCache = {
        sourceVehicle = nil,
        lastUpdatedAt = 0,
        entries = {},
    }
    state.externalKeepAliveUntil = 0
    state.keepPersonalPiPanelSources = {}
end

local function getBrakeValueForPi(vehicle, brakeForce)
    local wheelCount = math.max(1, GetVehicleNumberOfWheels(vehicle) or 1)
    return (tonumber(brakeForce) or 0.0) * wheelCount
end

function PerformancePanel.computeBrakeBarProgressForVehicle(vehicle, brakeForce)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    local barFillTargets = (runtimeConfig or {}).performanceBarFillTargets or {}
    local brakeTopValueUnits = tonumber(barFillTargets.brake) or INTERNAL_PERFORMANCE_DEFAULTS.brake
    if brakeTopValueUnits <= 0.0 then
        brakeTopValueUnits = INTERNAL_PERFORMANCE_DEFAULTS.brake
    end
    local computedBrakeValue = getBrakeValueForPi(vehicle, brakeForce)
    return math.max(0.0, math.min(1.0, computedBrakeValue / brakeTopValueUnits))
end

local function resolvePerformanceCalibration(runtimeConfig)
    local configured = (runtimeConfig or {}).performanceBarFillTargets or {}
    local barSegmentCount = math.max(1, math.floor(tonumber(configured.barSegmentCount) or INTERNAL_PERFORMANCE_DEFAULTS.barSegmentCount))
    local powerTarget = tonumber(configured.power) or INTERNAL_PERFORMANCE_DEFAULTS.power
    local topSpeedTarget = tonumber(configured.topSpeedMph) or INTERNAL_PERFORMANCE_DEFAULTS.topSpeedMph
    local gripTarget = tonumber(configured.grip) or INTERNAL_PERFORMANCE_DEFAULTS.grip

    if powerTarget <= 0.0 then powerTarget = INTERNAL_PERFORMANCE_DEFAULTS.power end
    if topSpeedTarget <= 0.0 then topSpeedTarget = INTERNAL_PERFORMANCE_DEFAULTS.topSpeedMph end
    if gripTarget <= 0.0 then gripTarget = INTERNAL_PERFORMANCE_DEFAULTS.grip end

    return {
        barSegmentCount = barSegmentCount,
        powerBarScaleFactor = barSegmentCount / powerTarget,
        topSpeedBarScaleFactor = barSegmentCount / topSpeedTarget,
        gripBarScaleFactor = barSegmentCount / gripTarget,
        flatVelToMphFactor = INTERNAL_PERFORMANCE_DEFAULTS.flatVelToMphFactor,
    }
end

local function scaleMetricProgress(currentValue, factor, barSegmentCount)
    local isFiniteNumber = PerformanceTuning.ClientBindings and PerformanceTuning.ClientBindings.isFiniteNumber or nil
    if not isFiniteNumber or not isFiniteNumber(currentValue) then
        return 0.0
    end

    if not isFiniteNumber(factor) or factor <= 0.0 then
        factor = 1.0
    end

    local resolvedSegmentCount = math.max(1, math.floor(tonumber(barSegmentCount) or INTERNAL_PERFORMANCE_DEFAULTS.barSegmentCount))
    return math.max(0.0, (currentValue * factor) / resolvedSegmentCount)
end

local function scaleMetricLevel(currentValue, factor, barSegmentCount)
    local resolvedSegmentCount = math.max(1, math.floor(tonumber(barSegmentCount) or INTERNAL_PERFORMANCE_DEFAULTS.barSegmentCount))
    local progress = scaleMetricProgress(currentValue, factor, resolvedSegmentCount)
    return math.floor((progress * resolvedSegmentCount) + 0.5)
end

local function scaleMetricPi(currentValue, factor, piMultiplier, barSegmentCount)
    local progress = scaleMetricProgress(currentValue, factor, barSegmentCount)
    if type(piMultiplier) ~= 'number' or piMultiplier <= 0.0 then
        piMultiplier = 1.0
    end

    return math.floor((progress * 100.0 * piMultiplier) + 0.5)
end

local function clampUnit(value)
    local resolved = tonumber(value) or 0.0
    if resolved < 0.0 then
        return 0.0
    end
    if resolved > 1.0 then
        return 1.0
    end
    return resolved
end

local function coerceNumber(value, fallback)
    if type(value) == 'number' then
        return value
    end
    if type(value) == 'string' then
        local parsed = tonumber(value)
        if parsed ~= nil then
            return parsed
        end
    end
    return fallback
end

local function normalizePerformanceBarsDisplayMode(mode)
    local normalized = tostring(mode or ''):lower()
    if normalized == 'vehicle_relative' or normalized == 'relative' then
        return 'vehicle_relative'
    end
    if normalized == 'absolute_benchmark' or normalized == 'absolute' then
        return 'absolute_benchmark'
    end
    return nil
end

local function getPerformanceBarsDisplayMode(runtimeConfig, requestedMode)
    local overrideMode = normalizePerformanceBarsDisplayMode(requestedMode)
    if overrideMode ~= nil then
        return overrideMode
    end

    local stateMode = normalizePerformanceBarsDisplayMode(((((PerformanceTuning or {}).ScaleformUI or {}).state or {}).performanceBarsDisplayMode)
    )
    if stateMode ~= nil then
        return stateMode
    end

    local configuredModel = (runtimeConfig or {}).performanceModel or (runtimeConfig or {}).performanceBars or {}
    local configuredMode = normalizePerformanceBarsDisplayMode((configuredModel or {}).displayMode)
    if configuredMode ~= nil then
        return configuredMode
    end
    return 'absolute_benchmark'
end

local function countEnabledUpgradePacks(packs)
    local count = 0
    for index, pack in ipairs(packs or {}) do
        if index > 1 and type(pack) == 'table' and pack.enabled ~= false then
            count = count + 1
        end
    end
    return count
end

local function getVehicleRelativePerformanceTargets(vehicle, bucket, runtimeConfig)
    local b = bucket or {}
    local definitions = PerformanceTuning.Definitions or {}
    local handlingFields = definitions.handlingFields or {}
    local engineFields = handlingFields.engine or {}
    local tiresFields = handlingFields.tires or {}
    local brakesFields = handlingFields.brakes or {}
    local baseEngine = type(b.baseEngine) == 'table' and b.baseEngine or {}
    local baseTires = type(b.baseTires) == 'table' and b.baseTires or {}
    local baseBrakes = type(b.baseBrakes) == 'table' and b.baseBrakes or {}
    local bars = (runtimeConfig or {}).performanceModel or (runtimeConfig or {}).performanceBars or {}
    local powerCfg = bars.power or {}
    local topSpeedCfg = bars.topSpeed or {}
    local gripCfg = bars.grip or {}
    local nitrousCfg = powerCfg.nitrous or {}
    local qualityOffsets = gripCfg.qualityLadder or {}
    local compoundOffsets = gripCfg.compoundRoadOffset or {}

    local basePower = tonumber(baseEngine[engineFields.power]) or 0.0
    local baseTopSpeed = tonumber(baseEngine[engineFields.topSpeed]) or 0.0
    local baseGrip = tonumber(baseTires[tiresFields.max]) or 0.0
    local baseBrakeForce = tonumber(baseBrakes[brakesFields.force]) or 0.0

    local powerOffset = math.max(0.0, tonumber(powerCfg.target) or 0.0)
    local topSpeedOffset = math.max(0.0, tonumber(topSpeedCfg.target) or 0.0)
    local brakeOffset = math.max(0.0, tonumber(((bars or {}).brake or {}).target) or 0.0)
    local topQualityOffset = tonumber(qualityOffsets.top_end) or 0.0
    local roadOffset = tonumber(compoundOffsets.road) or 0.0

    local transBonusPerUpgrade = math.max(0.0, tonumber((powerCfg.transmission or {}).powerBonusPerUpgrade) or 0.0)
    local maxTransmissionBonus = countEnabledUpgradePacks((((PerformanceTuning.Config or {}).packDefinitions or {}).transmission)) * transBonusPerUpgrade

    local maxNitroLevel = countEnabledUpgradePacks((((PerformanceTuning.Config or {}).packDefinitions or {}).nitrous))
    local fillPerLevelPercent = math.max(0.0, tonumber(nitrousCfg.powerBarFillPerNitroLevel) or 0.0)
    local powerFillTargetValue = math.max(0.0001, (tonumber((runtimeConfig or {}).performanceBarFillTargets and (runtimeConfig or {}).performanceBarFillTargets.power) or INTERNAL_PERFORMANCE_DEFAULTS.power))
    local maxNitrousBonusValue = (maxNitroLevel * (fillPerLevelPercent / 100.0)) * powerFillTargetValue

    return {
        power = math.max(0.0001, basePower + powerOffset + maxTransmissionBonus + maxNitrousBonusValue),
        topSpeedMph = math.max(0.0001, (baseTopSpeed * INTERNAL_PERFORMANCE_DEFAULTS.flatVelToMphFactor) + topSpeedOffset),
        grip = math.max(0.1, baseGrip + topQualityOffset + roadOffset),
        brakeForce = math.max(0.0001, baseBrakeForce + brakeOffset),
    }
end

local function getPiScales(runtimeConfig)
    local configured = (runtimeConfig or {}).performancePiDistribution or (runtimeConfig or {}).performancePiMultipliers or {}
    return {
        power = (tonumber(configured.power) or 10.0) * 0.1,
        topSpeed = (tonumber(configured.topSpeed) or 10.0) * 0.1,
        grip = (tonumber(configured.grip) or 10.0) * 0.1,
        brake = (tonumber(configured.brake) or 10.0) * 0.1,
    }
end

local function getNearbyPanelConfig(runtimeConfig)
    local config = (runtimeConfig or {}).performanceNearbyPanels or {}
    return {
        enabled = config.enabled ~= false,
        maxDistanceMeters = math.max(0.0, tonumber(config.maxDistanceMeters) or 50.0),
        maxPanels = math.max(0, math.floor(tonumber(config.maxPanels) or 6)),
    }
end

local function getPiDisplayModeIndex()
    local scaleformUIState = (((PerformanceTuning or {}).ScaleformUI or {}).state or {})
    local index = math.floor(tonumber(scaleformUIState.piDisplayModeIndex) or 1)
    return math.max(1, math.min(2, index))
end

local function getPiPanelDisplayModeIndex()
    local scaleformUIState = (((PerformanceTuning or {}).ScaleformUI or {}).state or {})
    local index = math.floor(tonumber(scaleformUIState.piPanelDisplayModeIndex) or 1)
    return math.max(1, math.min(2, index))
end

local function getPersonalPanelVehicle()
    local vehicle = PerformanceTuning.VehicleManager.getCurrentVehicle()
    if PerformanceTuning.VehicleManager.isVehicleEntityValid(vehicle) then
        return vehicle
    end

    local ped = PlayerPedId()
    local pedVehicle = GetVehiclePedIsIn(ped, false)
    if PerformanceTuning.VehicleManager.isVehicleEntityValid(pedVehicle) then
        return pedVehicle
    end

    local state = getDisplayState()
    local lastPrimaryVehicle = tonumber(state.lastPrimaryVehicle) or 0
    if PerformanceTuning.VehicleManager.isVehicleEntityValid(lastPrimaryVehicle) then
        return lastPrimaryVehicle
    end

    return nil
end

local function vehicleHasPanelStateBag(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end

    local stateBagKeys = (PerformanceTuning.Definitions or {}).stateBagKeys or {}
    local entityState = Entity(vehicle).state
    if type(stateBagKeys.tune) == 'string' and stateBagKeys.tune ~= '' then
        local tuneState = entityState[stateBagKeys.tune]
        if type(tuneState) == 'table' then
            return true
        end
    end

    if type(stateBagKeys.handling) == 'string' and stateBagKeys.handling ~= '' then
        local handlingState = entityState[stateBagKeys.handling]
        return type(handlingState) == 'table'
    end

    return false
end

local function shouldIncludeCandidateForDisplayMode(candidate, displayMode)
    if displayMode == 2 then
        return true
    end
    return false
end

local function getNearbyPanelVehiclesCached(displayState, primaryVehicle, nearbyConfig, displayMode)
    local maxDistanceMeters = tonumber(nearbyConfig.maxDistanceMeters) or 50.0
    local maxPanels = math.max(0, math.floor(tonumber(nearbyConfig.maxPanels) or 6))
    local scanner = displayState.nearbyScanner or {}
    displayState.nearbyScanner = scanner

    local ped = PlayerPedId()
    if maxPanels <= 0 or maxDistanceMeters <= 0.0 or displayMode == 1 or not DoesEntityExist(ped) then
        scanner.request = { active = false }
        scanner.resultsByVehicle = {}
        return {}
    end

    local origin = GetEntityCoords(ped)
    local maxDistanceSquared = maxDistanceMeters * maxDistanceMeters
    local signature = ('%s|%d|%.3f|%d'):format(tostring(primaryVehicle), displayMode, maxDistanceMeters, maxPanels)
    scanner.request = {
        active = true,
        signature = signature,
        primaryVehicle = primaryVehicle,
        displayMode = displayMode,
        maxDistanceSquared = maxDistanceSquared,
        origin = origin,
    }

    local nearby = {}
    local resultsByVehicle = scanner.resultsByVehicle or {}
    scanner.resultsByVehicle = resultsByVehicle
    for key, entry in pairs(resultsByVehicle) do
        local candidate = type(entry) == 'table' and entry.vehicle or nil
        if candidate and candidate ~= primaryVehicle and DoesEntityExist(candidate) and shouldIncludeCandidateForDisplayMode(candidate, displayMode) then
            local candidateCoords = GetEntityCoords(candidate)
            local deltaX = candidateCoords.x - origin.x
            local deltaY = candidateCoords.y - origin.y
            local deltaZ = candidateCoords.z - origin.z
            local distanceSquared = (deltaX * deltaX) + (deltaY * deltaY) + (deltaZ * deltaZ)
            if distanceSquared <= maxDistanceSquared then
                nearby[#nearby + 1] = {
                    vehicle = candidate,
                    distanceSquared = distanceSquared,
                }
            else
                resultsByVehicle[key] = nil
            end
        else
            resultsByVehicle[key] = nil
        end
    end

    table.sort(nearby, function(left, right)
        return (left.distanceSquared or -math.huge) > (right.distanceSquared or -math.huge)
    end)

    return nearby
end

local function clampPanelToSafeZone(panelLeftX, panelY, panelWidth, panelHeight, safeInset)
    local minLeftX = 0.014 + safeInset
    local maxLeftX = (1.0 - safeInset) - panelWidth
    local clampedLeftX = math.max(minLeftX, math.min(maxLeftX, panelLeftX))
    local halfHeight = panelHeight * 0.5
    local minCenterY = safeInset + halfHeight
    local maxCenterY = (1.0 - safeInset) - halfHeight
    local clampedY = math.max(minCenterY, math.min(maxCenterY, panelY))
    return clampedLeftX, clampedY
end

local function getWorldAnchoredPanelPosition(vehicle, panelScale, safeInset, panelHeightUnits)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil
    end

    local model = GetEntityModel(vehicle)
    local minBounds, maxBounds = GetModelDimensions(model)
    local roofHeight = (maxBounds and tonumber(maxBounds.z)) or 1.0
    local panelHeight = tonumber(panelHeightUnits) or (DEFAULT_PANEL_HEIGHT_UNITS * panelScale)
    local roofClearance = 1.05 + (panelHeight * 0.75)
    local anchor = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, 0.0, roofHeight + roofClearance)
    local anchorX = anchor.x
    local anchorY = anchor.y
    local anchorZ = anchor.z
    local visible, screenX, screenY = GetScreenCoordFromWorldCoord(anchorX, anchorY, anchorZ)
    if not visible then
        return nil
    end

    local resolvedPanelHeightUnits = panelHeight
    local resolvedScale = math.max(0.1, tonumber(panelScale) or SHARED_PANEL_BASE_SCALE)
    local panelWidth = getSharedPanelWidth() * resolvedScale
    local panelLeftX = screenX - (panelWidth * 0.5)
    local panelY = screenY
    return clampPanelToSafeZone(panelLeftX, panelY, panelWidth, resolvedPanelHeightUnits, safeInset)
end

local function getDistanceScaledPanelScale(distanceMeters, nearDistance, farDistance, nearScale, farScale)
    local resolvedDistance = math.max(0.0, tonumber(distanceMeters) or 0.0)
    local baseScale = tonumber(nearScale) or SHARED_PANEL_BASE_SCALE
    local fullScaleDistance = 20.0
    if resolvedDistance <= fullScaleDistance then
        return baseScale
    end

    local scaled = baseScale * (1.0 - (0.05 * (resolvedDistance - fullScaleDistance)))
    return math.max(0.1, scaled)
end

local function isPanelScaleVisible(panelScale)
    return (tonumber(panelScale) or 0.0) >= 0.5
end

local function isDisplayVehicleValid(vehicle)
    return vehicle and vehicle ~= 0 and DoesEntityExist(vehicle)
end

local function resolvePrimaryDisplayVehicle(displayState, requestedVehicle)
    local ped = PlayerPedId()
    local vehicleManager = PerformanceTuning.VehicleManager or {}
    local currentVehicle = GetVehiclePedIsIn(ped, false)
    if isDisplayVehicleValid(currentVehicle) then
        displayState.lastPrimaryVehicle = currentVehicle
        displayState.lastDrivenVehicle = currentVehicle
        return currentVehicle
    end

    if vehicleManager.isPedDrivingVehicle and vehicleManager.isPedDrivingVehicle(ped, requestedVehicle) then
        displayState.lastDrivenVehicle = requestedVehicle
    end

    local lastDrivenVehicle = tonumber(displayState.lastDrivenVehicle) or 0
    if isDisplayVehicleValid(lastDrivenVehicle) then
        displayState.lastPrimaryVehicle = lastDrivenVehicle
        return lastDrivenVehicle
    end

    if isDisplayVehicleValid(requestedVehicle) then
        displayState.lastPrimaryVehicle = requestedVehicle
        return requestedVehicle
    end

    displayState.lastDrivenVehicle = 0
    displayState.lastPrimaryVehicle = 0
    return nil
end

local function resolveComparisonVehicle(displayState, primaryVehicle, nearbyConfig, displayMode)
    if not isDisplayVehicleValid(primaryVehicle) then
        return nil
    end

    local candidates = getNearbyPanelVehiclesCached(displayState, primaryVehicle, nearbyConfig, displayMode)
    local comparisonVehicle = candidates[1] and candidates[1].vehicle or nil
    if isDisplayVehicleValid(comparisonVehicle) and comparisonVehicle ~= primaryVehicle then
        return comparisonVehicle
    end

    return nil
end

local function isAnyMenuOpen(scaleformUIState)
    local menuHandler = rawget(_G, 'MenuHandler')
    if type(menuHandler) == 'table' then
        if type(menuHandler.IsAnyMenuOpen) == 'function' and menuHandler:IsAnyMenuOpen() == true then
            return true
        end

        local currentMenu = menuHandler.CurrentMenu
        if currentMenu ~= nil then
            if type(currentMenu.Visible) == 'function' then
                if currentMenu:Visible() == true then
                    return true
                end
            else
                return true
            end
        end
    end

    if scaleformUIState.menuOpen == true then
        return true
    end

    local menus = scaleformUIState.menus or {}
    if menus.tweaks and type(menus.tweaks.Visible) == 'function' and menus.tweaks:Visible() then
        return true
    end
    if menus.main and type(menus.main.Visible) == 'function' and menus.main:Visible() then
        return true
    end

    return false
end

local function buildPersonalPanelRequestSettings()
    local barsDisplayMode = getPerformanceBarsDisplayMode(PerformanceTuning.RuntimeConfig or {}, nil)
    return {
        stackMode = 'top_right',
        onFootMode = 'hide',
        barsMode = barsDisplayMode,
    }
end

local function refreshManagedPanelDrawRequests(now)
    local state = getDisplayState()
    local controller = state.panelController or {}
    state.panelController = controller
    local refreshIntervalMs = math.max(1, math.floor(tonumber(controller.refreshIntervalMs) or 300))
    if now < (tonumber(controller.nextRefreshAt) or 0) then
        return
    end
    controller.nextRefreshAt = now + refreshIntervalMs

    local scaleformUIState = (((PerformanceTuning or {}).ScaleformUI or {}).state or {})
    local anyMenuOpen = isAnyMenuOpen(scaleformUIState)
    local compareNearbyEnabled = getPiDisplayModeIndex() == 2
    local currentVehicle = getPersonalPanelVehicle()
    if anyMenuOpen and not compareNearbyEnabled and PerformanceTuning.VehicleManager.isVehicleEntityValid(currentVehicle) then
        local panelScale = SHARED_PANEL_BASE_SCALE
        local panelHeightUnits = SHARED_PANEL_HEIGHT_UNITS * panelScale
        local safeZone = GetSafeZoneSize()
        local safeInset = (1.0 - safeZone) * 0.5
        local placementLeftX, placementY = getPrimaryPanelPlacement(
            getSharedPanelWidth(),
            SHARED_PANEL_HEIGHT_UNITS,
            safeInset,
            state
        )
        PerformancePanel.setPanelDrawRequest(
            'main_loop',
            'personal',
            currentVehicle,
            {
                stateKey = 'menu:current',
                panelScale = panelScale,
                panelHeightUnits = panelHeightUnits,
                panelLeftX = placementLeftX,
                panelY = placementY,
            },
            buildPersonalPanelRequestSettings()
        )
    else
        PerformancePanel.clearPanelDrawRequest('main_loop', 'personal')
    end
end

getPrimaryPanelPlacement = function(panelWidth, panelHeight, safeInset, displayState)
    local scaleformUIState = (((PerformanceTuning or {}).ScaleformUI or {}).state or {})
    local menuOpen = isAnyMenuOpen(scaleformUIState)
    local rightDockLeftX = (1.0 - safeInset) - panelWidth - 0.01
    -- Temporary: keep PI panels right-aligned at all times for stable non-overlapping behavior.
    local preferredLeftX = rightDockLeftX

    if menuOpen then
        local visibleMenu = nil
        local menus = scaleformUIState.menus or {}
        if menus.tweaks and type(menus.tweaks.Visible) == 'function' and menus.tweaks:Visible() then
            visibleMenu = menus.tweaks
        elseif menus.main and type(menus.main.Visible) == 'function' and menus.main:Visible() then
            visibleMenu = menus.main
        end

        local screenWidth = coerceNumber(select(1, GetActiveScreenResolution()), 0.0)
        if screenWidth > 0.0 then
            local menuLeftPx = coerceNumber(visibleMenu and visibleMenu.X, DEFAULT_MENU_LEFT_PX)
            local widthOffsetPx = coerceNumber(visibleMenu and visibleMenu.WidthOffset, 0.0)
            local menuWidthPx = DEFAULT_MENU_WIDTH_PX + widthOffsetPx
            local menuRightX = (menuLeftPx + menuWidthPx) / screenWidth
            preferredLeftX = math.max(preferredLeftX, menuRightX + MENU_PANEL_GAP_X)
        end
    end

    local preferredCenterY = safeInset + (panelHeight * 0.5) + MAIN_PANEL_Y_OFFSET
    return clampPanelToSafeZone(preferredLeftX, preferredCenterY, panelWidth, panelHeight, safeInset)
end

local function buildSharedPanelDrawOptions(panelLeftX, panelY, panelScale)
    local resolvedScale = tonumber(panelScale) or SHARED_PANEL_BASE_SCALE
    return {
        panelScale = resolvedScale,
        panelHeightUnits = SHARED_PANEL_HEIGHT_UNITS * resolvedScale,
        panelLeftX = panelLeftX,
        panelY = panelY,
        panelAlpha = SHARED_PANEL_ALPHA,
        fillAlpha = SHARED_PANEL_FILL_ALPHA,
    }
end

local function getStackedPanelPlacement(stackLeftX, stackTopCenterY, stackIndex, panelWidth, panelHeight, safeInset)
    local stackedCenterY = stackTopCenterY + ((panelHeight + STACKED_PANEL_GAP_Y) * math.max(0, stackIndex))
    return clampPanelToSafeZone(stackLeftX, stackedCenterY, panelWidth, panelHeight, safeInset)
end

local function getStackedNearbyPanelLimit(primaryPanelY, primaryPanelHeight, safeInset, nearbyPanelHeight)
    local firstCenterY = primaryPanelY + primaryPanelHeight + STACKED_PANEL_GAP_Y
    local maxCenterY = (1.0 - safeInset) - (nearbyPanelHeight * 0.5)
    if firstCenterY > maxCenterY then
        return 0
    end

    local stepY = nearbyPanelHeight + STACKED_PANEL_GAP_Y
    if stepY <= 0.0 then
        return 0
    end

    return math.max(0, math.floor(((maxCenterY - firstCenterY) / stepY) + 1.0))
end

local function doRectsOverlap(leftA, rightA, topA, bottomA, leftB, rightB, topB, bottomB)
    return leftA < rightB
        and rightA > leftB
        and topA < bottomB
        and bottomA > topB
end

local function expandRect(leftX, rightX, topY, bottomY, paddingX, paddingY)
    return {
        left = leftX - paddingX,
        right = rightX + paddingX,
        top = topY - paddingY,
        bottom = bottomY + paddingY,
    }
end

local function drawPanelInstanceInternal(vehicle, displayState, stateKey, options, runtimeConfig)
    local panelMetrics = PerformancePanel.buildMetrics(vehicle, options)
    if not panelMetrics then
        return false
    end
    local safeZone = GetSafeZoneSize()
    local safeInset = (1.0 - safeZone) * 0.5
    local panelScale = math.max(0.1, tonumber((options or {}).panelScale) or 1.3)
    local panelHeightUnits = tonumber((options or {}).panelHeightUnits)
        or (DEFAULT_PANEL_HEIGHT_UNITS * panelScale)
    local panelH = panelHeightUnits
    local panelW = getSharedPanelWidth() * panelScale
    local panelLeftX = tonumber((options or {}).panelLeftX)
    if panelLeftX == nil then
        panelLeftX = 0.014 + safeInset
    end
    local panelX = panelLeftX + (panelW * 0.5)
    local panelY = tonumber((options or {}).panelY)
    if panelY == nil then
        panelY = 0.18 + safeInset
    end
    local panelAlpha = math.max(0, math.min(255, math.floor(tonumber((options or {}).panelAlpha) or 168)))
    local fillAlpha = math.max(0, math.min(255, math.floor(tonumber((options or {}).fillAlpha) or 255)))
    local leftX = panelX - (panelW * 0.5)
    local labelX = leftX + (panelW * 0.035)
    local trackLeftX = leftX + (panelW * 0.49)
    local trackW = panelW * 0.42
    local trackH = panelH * 0.062
    local headerY = panelY - (panelH * 0.45)
    local panelTextScale = panelH / math.max(0.0001, SHARED_PANEL_TEXT_BASE_HEIGHT_UNITS)
    local segmentGap = trackW * 0.016
    local segmentCount = 5
    local segmentW = (trackW - (segmentGap * (segmentCount - 1))) / segmentCount
    local dt = GetFrameTime()
    local lerpAlpha = math.min(1.0, math.max(0.0, dt * 6.0))
    local animationState = getPanelAnimationState(displayState, stateKey)

    for index = 1, #panelMetrics.fills do
        local currentFill = animationState.fills[index] or 0.0
        local targetFill = panelMetrics.fills[index]
        animationState.fills[index] = currentFill + ((targetFill - currentFill) * lerpAlpha)
    end

    DrawRect(panelX, panelY, panelW, panelH, 0, 0, 0, panelAlpha)
    local headerHeight = panelH * SHARED_PANEL_HEADER_HEIGHT_RATIO
    local headerCenterY = panelY - (panelH * 0.5) + (headerHeight * 0.5)
    local headerTextY = headerCenterY - (headerHeight * 0.46)
    local headerLeftX = leftX + (panelW * 0.035)
    local headerRightX = leftX + panelW - (panelW * 0.035)
    local headerNameScale = math.max(0.18, math.min(0.7, 0.36 * panelTextScale))
    DrawRect(panelX, headerCenterY, panelW, headerHeight, 60, 140, 255, math.min(255, panelAlpha + 20))
    drawPiLeftText(headerLeftX, headerTextY, headerNameScale, getPanelVehicleDisplayName(vehicle))
    drawPiRightText(headerRightX, headerTextY, headerNameScale, ('PI %d'):format(math.max(0, math.floor((tonumber(panelMetrics.total) or 0) + 0.5))))

    local orderedLabels = { 'Speed', 'Power', 'Grip', 'Brake' }
    local metricValues = type(panelMetrics.metricValues) == 'table' and panelMetrics.metricValues or {}
    local piValues = type(panelMetrics.values) == 'table' and panelMetrics.values or {}
    local orderedPiMarkers = {
        ('%d PI'):format(math.max(0, math.floor((tonumber(piValues[2]) or 0) + 0.5))),
        ('%d PI'):format(math.max(0, math.floor((tonumber(piValues[1]) or 0) + 0.5))),
        ('%d PI'):format(math.max(0, math.floor((tonumber(piValues[3]) or 0) + 0.5))),
        ('%d PI'):format(math.max(0, math.floor((tonumber(piValues[4]) or 0) + 0.5))),
    }
    local orderedMetricMarkers = {
        ('%d mph'):format(math.max(0, math.floor((tonumber(metricValues.speed) or 0.0) + 0.5))),
        ('%.3f G'):format(math.max(0.0, tonumber(metricValues.power) or 0.0)),
        ('%.3f G'):format(math.max(0.0, tonumber(metricValues.grip) or 0.0)),
        ('%.3f G'):format(math.max(0.0, tonumber(metricValues.brake) or 0.0)),
    }
    local showingRawMetrics = getPiPanelDisplayModeIndex() == 2
    local orderedLeftMarkers = showingRawMetrics and orderedMetricMarkers or orderedPiMarkers
    local orderedFills = {
        animationState.fills[2] or 0.0,
        animationState.fills[1] or 0.0,
        animationState.fills[3] or 0.0,
        animationState.fills[4] or 0.0,
    }
    local comparisonMetrics = type((options or {}).comparisonMetrics) == 'table' and (options or {}).comparisonMetrics or nil
    local comparisonFills = nil
    if type(comparisonMetrics) == 'table' and type(comparisonMetrics.fills) == 'table' then
        comparisonFills = {
            comparisonMetrics.fills[2] or 0.0,
            comparisonMetrics.fills[1] or 0.0,
            comparisonMetrics.fills[3] or 0.0,
            comparisonMetrics.fills[4] or 0.0,
        }
    end
    local bottomRowMargin = math.max(trackH * 1.6, panelH * 0.04)
    local speedRowY = panelY + (panelH * 0.5) - bottomRowMargin
    local rowStepY = panelH * 0.17

    for index = 1, #orderedFills do
        local fill = orderedFills[index]
        local reverseIndex = #orderedFills - index
        local rowY = (speedRowY - (reverseIndex * rowStepY)) - 0.005
        local rowTextY = rowY - (trackH * 0.8) - 0.005
        local rowTrackLeftX = trackLeftX - (panelW * 0.055) - 0.001
        local markerX = rowTrackLeftX - (panelW * 0.14) - 0.01
        local rowTrackW = trackW * 1.3
        local rowSegmentGap = rowTrackW * 0.016
        local rowSegmentW = (rowTrackW - (rowSegmentGap * (segmentCount - 1))) / segmentCount
        local scaledSegments = math.max(0.0, math.min(segmentCount, fill * segmentCount))
        local fullSegments = math.floor(scaledSegments)
        local partialSegmentFill = scaledSegments - fullSegments
        local comparisonFill = comparisonFills and tonumber(comparisonFills[index]) or nil
        local comparisonDelta = comparisonFill and (comparisonFill - fill) or nil
        local comparisonStartUnits = fill * segmentCount
        local comparisonEndUnits = comparisonFill and (comparisonFill * segmentCount) or nil

        drawPiLeftText(markerX, rowTextY, headerNameScale, orderedLeftMarkers[index] or '')
        drawPiLeftText(labelX, rowTextY, headerNameScale, orderedLabels[index])

        for segmentIndex = 1, segmentCount do
            local segmentCenterX = rowTrackLeftX + (rowSegmentW * 0.5) + ((segmentIndex - 1) * (rowSegmentW + rowSegmentGap))
            local segmentLeftX = segmentCenterX - (rowSegmentW * 0.5)
            local emptyAlpha = math.floor(math.max(0, math.min(255, panelAlpha)) * 0.5)
            DrawRect(segmentCenterX, rowY, rowSegmentW, trackH, 0, 0, 0, emptyAlpha)

            if segmentIndex <= fullSegments then
                DrawRect(segmentCenterX, rowY, rowSegmentW, trackH, 255, 255, 255, fillAlpha)
            elseif segmentIndex == (fullSegments + 1) and partialSegmentFill > 0.001 then
                local partialWidth = rowSegmentW * partialSegmentFill
                local partialCenterX = segmentLeftX + (partialWidth * 0.5)
                DrawRect(partialCenterX, rowY, partialWidth, trackH, 255, 255, 255, fillAlpha)
            end

            if comparisonDelta ~= nil and comparisonDelta ~= 0.0 and comparisonEndUnits then
                local comparisonColor = { 255, 40, 40 }
                local comparisonAlpha = 255
                local comparisonY = rowY
                if comparisonDelta < 0.0 then
                    comparisonColor = { 0, 180, 0 }
                    comparisonAlpha = 255
                end
                local deltaStartUnits = math.min(comparisonStartUnits, comparisonEndUnits)
                local deltaEndUnits = math.max(comparisonStartUnits, comparisonEndUnits)
                local segmentStartUnits = segmentIndex - 1
                local segmentEndUnits = segmentIndex
                local overlayStartUnits = math.max(segmentStartUnits, deltaStartUnits)
                local overlayEndUnits = math.min(segmentEndUnits, deltaEndUnits)
                local overlayUnits = overlayEndUnits - overlayStartUnits
                if overlayUnits > 0.001 then
                    local overlayWidth = rowSegmentW * overlayUnits
                    local overlayCenterX = segmentLeftX + (overlayWidth * 0.5) + (rowSegmentW * math.max(0.0, overlayStartUnits - segmentStartUnits))
                    DrawRect(overlayCenterX, comparisonY, overlayWidth, trackH, comparisonColor[1], comparisonColor[2], comparisonColor[3], comparisonAlpha)
                end
            end
        end
    end

    return true
end

local function getFlatVelTopSpeedMph(vehicle)
    local bindings = PerformanceTuning.ClientBindings or {}
    local handlingFields = (PerformanceTuning.Definitions or {}).handlingFields or {}
    local engineFields = handlingFields.engine or {}
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return 0.0
    end

    local flatVel = bindings.readHandlingValue and bindings.readHandlingValue(vehicle, 'float', engineFields.topSpeed) or nil
    local isFiniteNumber = bindings.isFiniteNumber
    if not isFiniteNumber or not isFiniteNumber(flatVel) or flatVel <= 0.0 then
        return 0.0
    end

    local mphFactor = (((PerformanceTuning or {})._internals or {}).Performance or {}).flatVelToMphFactor
        or INTERNAL_PERFORMANCE_DEFAULTS.flatVelToMphFactor
        or (145.0 / 176.0)
    return flatVel * mphFactor
end

function PerformancePanel.buildPerformanceIndex(vehicle, bucket, options)
    local bindings = PerformanceTuning.ClientBindings or {}
    local definitions = PerformanceTuning.Definitions or {}
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    local performance = resolvePerformanceCalibration(runtimeConfig)
    local handlingFields = definitions.handlingFields or {}
    local transmissionFields = handlingFields.transmission or {}
    local engineFields = handlingFields.engine or {}
    local tireFields = handlingFields.tires or {}
    local brakeFields = handlingFields.brakes or {}
    local readHandlingValue = bindings.readHandlingValue
    local formatHandlingValue = PerformanceTuning.HandlingManager and PerformanceTuning.HandlingManager.formatHandlingValue or tostring
    local shiftBenefit = 0.0
    local upshiftRate = tonumber(readHandlingValue and readHandlingValue(vehicle, 'float', transmissionFields.clutchUpshift) or 0.0) or 0.0
    if upshiftRate > 0.0 then
        shiftBenefit = (1.0 - (1.0 / upshiftRate)) * 0.1
    end

    local resolvedBucket = bucket or (bindings.ensureTuningState and bindings.ensureTuningState(vehicle) or nil) or {}
    local nitrousPowerBonusValue = getNitrousPowerBonusValue(resolvedBucket, runtimeConfig, performance)
    local piScales = getPiScales(runtimeConfig)
    local currentPower = (readHandlingValue and readHandlingValue(vehicle, 'float', engineFields.power) or 0.0) + shiftBenefit + nitrousPowerBonusValue
    local currentTopSpeed = getFlatVelTopSpeedMph(vehicle)
    local currentGrip = readHandlingValue and readHandlingValue(vehicle, 'float', tireFields.max) or 0.0
    local brakeForce = GetVehicleHandlingFloat(vehicle, definitions.handlingClass, brakeFields.force) or 0.0
    local brakeValueForPi = getBrakeValueForPi(vehicle, brakeForce)
    local displayMode = getPerformanceBarsDisplayMode(runtimeConfig, (options or {}).barMode)
    local powerProgress = 0.0
    local topSpeedProgress = 0.0
    local gripProgress = 0.0
    local currentBrakeProgress = 0.0
    local powerProgressForPi = 0.0
    local topSpeedProgressForPi = 0.0
    local gripProgressForPi = 0.0
    local brakeProgressForPi = 0.0
    if displayMode == 'vehicle_relative' then
        local targets = getVehicleRelativePerformanceTargets(vehicle, resolvedBucket, runtimeConfig)
        powerProgressForPi = currentPower / math.max(0.0001, tonumber(targets.power) or 0.0001)
        topSpeedProgressForPi = currentTopSpeed / math.max(0.0001, tonumber(targets.topSpeedMph) or 0.0001)
        gripProgressForPi = currentGrip / math.max(0.1, tonumber(targets.grip) or 0.1)
        brakeProgressForPi = brakeValueForPi / math.max(0.0001, tonumber(targets.brakeForce) or 0.0001)
        powerProgress = clampUnit(powerProgressForPi)
        topSpeedProgress = clampUnit(topSpeedProgressForPi)
        gripProgress = clampUnit(gripProgressForPi)
        currentBrakeProgress = clampUnit(brakeProgressForPi)
    else
        currentBrakeProgress = PerformancePanel.computeBrakeBarProgressForVehicle(vehicle, brakeForce)
        powerProgress = scaleMetricProgress(currentPower, performance.powerBarScaleFactor, performance.barSegmentCount)
        topSpeedProgress = scaleMetricProgress(currentTopSpeed, performance.topSpeedBarScaleFactor, performance.barSegmentCount)
        local gripProgressFromMax = scaleMetricProgress(currentGrip, performance.gripBarScaleFactor, performance.barSegmentCount)
        gripProgress = clampUnit(gripProgressFromMax)
        powerProgressForPi = powerProgress
        topSpeedProgressForPi = topSpeedProgress
        gripProgressForPi = gripProgressFromMax
        brakeProgressForPi = currentBrakeProgress
    end

    local powerLevel = math.floor((powerProgress * performance.barSegmentCount) + 0.5)
    local topSpeedLevel = math.floor((topSpeedProgress * performance.barSegmentCount) + 0.5)
    local gripLevel = math.floor((gripProgress * (tonumber(performance.barSegmentCount) or 10)) + 0.5)
    local powerPi = math.floor((math.max(0.0, tonumber(currentPower) or 0.0) * piScales.power) + 0.5)
    local topSpeedPi = math.floor((math.max(0.0, tonumber(currentTopSpeed) or 0.0) * piScales.topSpeed) + 0.5)
    local gripPi = math.floor((math.max(0.0, tonumber(currentGrip) or 0.0) * piScales.grip) + 0.5)
    local brakePi = math.floor((math.max(0.0, tonumber(brakeValueForPi) or 0.0) * piScales.brake) + 0.5)

    local totalPi = powerPi + topSpeedPi + gripPi + brakePi
    return {
        total = totalPi,
        categories = {
            {
                key = 'power',
                label = 'POWER',
                level = powerLevel,
                maxLevel = performance.barSegmentCount,
                progress = powerProgress,
                pi = powerPi,
                value = currentPower,
                valueLabel = formatHandlingValue(currentPower, 'float'),
            },
            {
                key = 'top_speed',
                label = 'TOP SPEED',
                level = topSpeedLevel,
                maxLevel = performance.barSegmentCount,
                progress = topSpeedProgress,
                pi = topSpeedPi,
                value = currentTopSpeed,
                valueLabel = ('%d mph'):format(math.floor(currentTopSpeed + 0.5)),
            },
            {
                key = 'grip',
                label = 'GRIP',
                level = gripLevel,
                maxLevel = performance.barSegmentCount,
                progress = gripProgress,
                pi = gripPi,
                value = currentGrip,
                valueLabel = ('Max %s'):format(formatHandlingValue(currentGrip, 'float')),
            }
        }
    }
end

function PerformancePanel.buildMetrics(vehicle, options)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    local definitions = PerformanceTuning.Definitions or {}
    local bindings = PerformanceTuning.ClientBindings or {}
    local readHandlingValue = bindings.readHandlingValue
    local handlingFields = definitions.handlingFields or {}
    local engineFields = handlingFields.engine or {}
    local tireFields = handlingFields.tires or {}
    local brakeFields = (definitions.handlingFields or {}).brakes or {}
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil
    end

    local performanceIndex = PerformancePanel.buildPerformanceIndex(vehicle, nil, options)
    local categories = performanceIndex and performanceIndex.categories or {}
    local powerFill = (categories[1] or {}).progress or 0.0
    local speedFill = (categories[2] or {}).progress or 0.0
    local gripFill = (categories[3] or {}).progress or 0.0
    local brakeForce = GetVehicleHandlingFloat(vehicle, definitions.handlingClass, brakeFields.force) or 0.0
    local brakeValueForPi = getBrakeValueForPi(vehicle, brakeForce)
    local brakeFill = PerformancePanel.computeBrakeBarProgressForVehicle(vehicle, brakeForce)
    local piScales = getPiScales(runtimeConfig)
    local powerValue = readHandlingValue and readHandlingValue(vehicle, 'float', engineFields.power) or 0.0
    local speedValue = getFlatVelTopSpeedMph(vehicle)
    local gripValue = readHandlingValue and readHandlingValue(vehicle, 'float', tireFields.max) or 0.0
    local powerPiValue = math.floor((math.max(0.0, tonumber(powerValue) or 0.0) * piScales.power) + 0.5)
    local speedPiValue = math.floor((math.max(0.0, tonumber(speedValue) or 0.0) * piScales.topSpeed) + 0.5)
    local gripPiValue = math.floor((math.max(0.0, tonumber(gripValue) or 0.0) * piScales.grip) + 0.5)
    local brakePiValue = math.floor((math.max(0.0, tonumber(brakeValueForPi) or 0.0) * piScales.brake) + 0.5)

    return {
        total = performanceIndex and performanceIndex.total or 0,
        fills = { powerFill, speedFill, gripFill, brakeFill },
        labels = { 'PWR', 'SPD', 'GRP', 'BRK' },
        metricValues = {
            speed = tonumber(speedValue) or 0.0,
            power = tonumber(powerValue) or 0.0,
            grip = tonumber(gripValue) or 0.0,
            brake = tonumber(brakeValueForPi) or 0.0,
        },
        values = {
            powerPiValue,
            speedPiValue,
            gripPiValue,
            brakePiValue,
        }
    }
end

function PerformancePanel.drawPanelInstance(vehicle, options)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end

    local state = getDisplayState()
    local scaleformUIState = (((PerformanceTuning or {}).ScaleformUI or {}).state or {})
    if isAnyMenuOpen(scaleformUIState) and not ((options or {}).forceWhileMenuOpen == true) then
        state.visible = false
        return false
    end

    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    local stateKey = (options or {}).stateKey or ('vehicle:%s'):format(tostring(vehicle))
    local didDraw = drawPanelInstanceInternal(vehicle, state, stateKey, options, runtimeConfig)
    if didDraw then
        state.visible = true
    end
    return didDraw
end

function PerformancePanel.drawPanel(vehicle, options)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    local state = getDisplayState()
    local scaleformUIState = (((PerformanceTuning or {}).ScaleformUI or {}).state or {})
    if isAnyMenuOpen(scaleformUIState) and not ((options or {}).forceWhileMenuOpen == true) then
        state.visible = false
        return false
    end

    local drawOptions = options or {}
    local drawNearbyOnly = drawOptions.drawNearbyOnly == true
    local displayMode = getPiDisplayModeIndex()
    local nearbyConfig = getNearbyPanelConfig(runtimeConfig)
    local ped = PlayerPedId()
    local currentVehicle = GetVehiclePedIsIn(ped, false)
    local playerIsInVehicle = isDisplayVehicleValid(currentVehicle) and PerformanceTuning.VehicleManager.isPedDrivingVehicle(ped, currentVehicle)
    local shouldUseScreenAnchor = playerIsInVehicle
    local primaryVehicle = resolvePrimaryDisplayVehicle(state, vehicle)
    local validPrimaryVehicle = isDisplayVehicleValid(primaryVehicle)
    local didDrawAny = false
    local primaryPanelLeftX = nil
    local primaryPanelY = nil
    local primaryPanelHeight = SHARED_PANEL_HEIGHT_UNITS
    local primaryPanelWidth = nil
    local primaryMetrics = nil
    local comparisonVehicle = nil
    if validPrimaryVehicle then
        primaryMetrics = PerformancePanel.buildMetrics(primaryVehicle)
    end

    if validPrimaryVehicle and (not drawNearbyOnly or drawOptions.allowLastDrivenPrimary ~= false) then
        local safeZone = GetSafeZoneSize()
        local safeInset = (1.0 - safeZone) * 0.5
        primaryPanelWidth = getSharedPanelWidth()
        comparisonVehicle = resolveComparisonVehicle(state, primaryVehicle, nearbyConfig, displayMode)
        local primaryPanelScale = SHARED_PANEL_BASE_SCALE
        if shouldUseScreenAnchor then
            primaryPanelLeftX, primaryPanelY = getPrimaryPanelPlacement(primaryPanelWidth, primaryPanelHeight, safeInset, state)
        else
            local pedCoords = GetEntityCoords(ped)
            local vehicleCoords = GetEntityCoords(primaryVehicle)
            local dx = vehicleCoords.x - pedCoords.x
            local dy = vehicleCoords.y - pedCoords.y
            local dz = vehicleCoords.z - pedCoords.z
            local distanceMeters = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
            primaryPanelScale = getDistanceScaledPanelScale(distanceMeters, 10.0, 100.0, SHARED_PANEL_BASE_SCALE, SHARED_PANEL_BASE_SCALE * 0.5)
            if not isPanelScaleVisible(primaryPanelScale) then
                goto skip_primary_draw
            end

            primaryPanelLeftX, primaryPanelY = getWorldAnchoredPanelPosition(primaryVehicle, primaryPanelScale, safeInset, primaryPanelHeight * primaryPanelScale)
            if not primaryPanelLeftX or not primaryPanelY then
                goto skip_primary_draw
            end
        end
        local primaryDrawOptions = buildSharedPanelDrawOptions(primaryPanelLeftX, primaryPanelY, primaryPanelScale)
        local primaryDrawn = drawPanelInstanceInternal(primaryVehicle, state, 'primary', primaryDrawOptions, runtimeConfig)
        if primaryDrawn then
            didDrawAny = true
        end
        ::skip_primary_draw::
    end

    if displayMode ~= 1 and nearbyConfig.enabled then
        local safeZone = GetSafeZoneSize()
        local safeInset = (1.0 - safeZone) * 0.5
        local overlapPaddingX = 0.014
        local overlapPaddingY = 0.01
        local nearbyPanelHeight = SHARED_PANEL_HEIGHT_UNITS
        local maxDrawnPanels = math.max(0, math.floor(tonumber(nearbyConfig.maxPanels) or 6))
        if shouldUseScreenAnchor and primaryPanelLeftX and primaryPanelY then
            maxDrawnPanels = math.min(
                maxDrawnPanels,
                getStackedNearbyPanelLimit(primaryPanelY, primaryPanelHeight, safeInset, nearbyPanelHeight * SHARED_PANEL_BASE_SCALE)
            )
        end
        local nearbyVehicles = getNearbyPanelVehiclesCached(state, primaryVehicle, nearbyConfig, displayMode)
        local titlePrefix = 'Nearby'
        local keptNearbyRects = {}
        local drawnNearbyCount = 0

        for _, entry in ipairs(nearbyVehicles) do
            if drawnNearbyCount >= maxDrawnPanels then
                break
            end
            local candidateVehicle = entry.vehicle
            local distanceMeters = math.sqrt(tonumber(entry.distanceSquared) or 0.0)
            local useStackedPlacement = shouldUseScreenAnchor and primaryPanelLeftX and primaryPanelY
            local nearbyScale = SHARED_PANEL_BASE_SCALE
            if not useStackedPlacement then
                nearbyScale = getDistanceScaledPanelScale(distanceMeters, 0.0, 0.0, SHARED_PANEL_BASE_SCALE, SHARED_PANEL_BASE_SCALE)
            end
            if not isPanelScaleVisible(nearbyScale) then
                goto continue_nearby_vehicle
            end
            local nearbyPanelWidth = getSharedPanelWidth() * nearbyScale
            local nearbyPanelHeightScaled = nearbyPanelHeight * nearbyScale
            local panelLeftX, panelY = nil, nil
            if useStackedPlacement then
                panelLeftX, panelY = getStackedPanelPlacement(
                    primaryPanelLeftX,
                    primaryPanelY + primaryPanelHeight + STACKED_PANEL_GAP_Y,
                    drawnNearbyCount,
                    nearbyPanelWidth,
                    nearbyPanelHeightScaled,
                    safeInset
                )
            else
                panelLeftX, panelY = getWorldAnchoredPanelPosition(candidateVehicle, nearbyScale, safeInset, nearbyPanelHeightScaled)
            end
            if panelLeftX and panelY then
                local panelRightX = panelLeftX + nearbyPanelWidth
                local panelTopY = panelY - (nearbyPanelHeightScaled * 0.5)
                local panelBottomY = panelY + (nearbyPanelHeightScaled * 0.5)
                local shouldCheckOverlap = not useStackedPlacement
                local intersectsCloserPanel = false

                if shouldCheckOverlap then
                    for _, keptRect in ipairs(keptNearbyRects) do
                        if doRectsOverlap(
                            panelLeftX,
                            panelRightX,
                            panelTopY,
                            panelBottomY,
                            keptRect.left,
                            keptRect.right,
                            keptRect.top,
                            keptRect.bottom
                        ) then
                            intersectsCloserPanel = true
                            break
                        end
                    end
                end

                if not intersectsCloserPanel then
                    local nearbyDrawOptions = buildSharedPanelDrawOptions(panelLeftX, panelY, nearbyScale)
                    nearbyDrawOptions.title = ('%s %.0fm'):format(titlePrefix, distanceMeters)
                    nearbyDrawOptions.comparisonMetrics = primaryMetrics
                    if comparisonVehicle and candidateVehicle == comparisonVehicle then
                        nearbyDrawOptions.comparisonMetrics = primaryMetrics
                    end
                    local didDrawNearby = drawPanelInstanceInternal(candidateVehicle, state, ('nearby:%s'):format(tostring(candidateVehicle)), nearbyDrawOptions, runtimeConfig)
                    didDrawAny = didDrawAny or didDrawNearby == true
                    if didDrawNearby then
                        drawnNearbyCount = drawnNearbyCount + 1
                    end

                    if shouldCheckOverlap then
                        keptNearbyRects[#keptNearbyRects + 1] = expandRect(
                            panelLeftX,
                            panelRightX,
                            panelTopY,
                            panelBottomY,
                            overlapPaddingX,
                            overlapPaddingY
                        )
                    end
                end
            end
            ::continue_nearby_vehicle::
        end
    end

    if didDrawAny then
        state.visible = true
    end
    pruneInactivePanelStates(state, GetGameTimer())
end

CreateThread(function()
    while true do
        Wait(0)
        local state = getDisplayState()
        local scanner = state.nearbyScanner or {}
        state.nearbyScanner = scanner
        local request = scanner.request

        if type(request) ~= 'table' or request.active ~= true then
            scanner.vehicles = {}
            scanner.cursor = 1
            scanner.resultsByVehicle = {}
            scanner.carBudgetAccumulator = 0.0
            scanner.lastRequestSignature = ''
            goto continue
        end

        local frameTime = math.max(0.0, tonumber(GetFrameTime()) or 0.0)
        local carsPerSecond = math.max(1.0, tonumber(scanner.carsPerSecond) or 500.0)
        scanner.carBudgetAccumulator = (tonumber(scanner.carBudgetAccumulator) or 0.0) + (carsPerSecond * frameTime)
        local carsToProcess = math.floor(scanner.carBudgetAccumulator)
        if carsToProcess <= 0 then
            goto continue
        end
        scanner.carBudgetAccumulator = scanner.carBudgetAccumulator - carsToProcess

        local requestSignature = tostring(request.signature or '')
        if scanner.lastRequestSignature ~= requestSignature then
            scanner.lastRequestSignature = requestSignature
            scanner.vehicles = {}
            scanner.cursor = 1
            scanner.resultsByVehicle = {}
        end

        local vehicles = scanner.vehicles or {}
        local cursor = tonumber(scanner.cursor) or 1
        local resultsByVehicle = scanner.resultsByVehicle or {}
        scanner.resultsByVehicle = resultsByVehicle
        local origin = request.origin
        local primaryVehicle = request.primaryVehicle
        local displayMode = request.displayMode
        local maxDistanceSquared = tonumber(request.maxDistanceSquared) or 0.0

        while carsToProcess > 0 do
            if cursor > #vehicles then
                vehicles = GetGamePool('CVehicle') or {}
                cursor = 1
                if #vehicles == 0 then
                    break
                end
            end

            local candidate = vehicles[cursor]
            cursor = cursor + 1
            carsToProcess = carsToProcess - 1
            local key = tostring(candidate)

            if candidate and candidate ~= primaryVehicle and DoesEntityExist(candidate) and shouldIncludeCandidateForDisplayMode(candidate, displayMode) then
                local candidateCoords = GetEntityCoords(candidate)
                local deltaX = candidateCoords.x - origin.x
                local deltaY = candidateCoords.y - origin.y
                local deltaZ = candidateCoords.z - origin.z
                local distanceSquared = (deltaX * deltaX) + (deltaY * deltaY) + (deltaZ * deltaZ)
                if distanceSquared <= maxDistanceSquared then
                    resultsByVehicle[key] = {
                        vehicle = candidate,
                        distanceSquared = distanceSquared,
                    }
                else
                    resultsByVehicle[key] = nil
                end
            else
                resultsByVehicle[key] = nil
            end
        end

        scanner.vehicles = vehicles
        scanner.cursor = cursor

        ::continue::
    end
end)

CreateThread(function()
    local state = getDisplayState()
    while true do
        local nativeMenuOpen = false
        if PerformanceTuning.ScaleformUI and PerformanceTuning.ScaleformUI.processFrame then
            nativeMenuOpen = PerformanceTuning.ScaleformUI.processFrame() == true
        end
        local scaleformUIState = (((PerformanceTuning or {}).ScaleformUI or {}).state or {})
        local anyMenuOpen = nativeMenuOpen or isAnyMenuOpen(scaleformUIState)

        local now = GetGameTimer()
        refreshManagedPanelDrawRequests(now)
        local requestedPanelsDrawn = drawPanelDrawRequests(now)
        local compareNearbyEnabled = getPiDisplayModeIndex() == 2
        local menuComparisonDrawn = false
        if compareNearbyEnabled and anyMenuOpen then
            local currentVehicle = getPersonalPanelVehicle()
            if PerformanceTuning.VehicleManager.isVehicleEntityValid(currentVehicle) then
                menuComparisonDrawn = PerformancePanel.drawPanel(currentVehicle, {
                    forceWhileMenuOpen = true,
                }) == true
            end
        end

        local persistentNearbyModeActive = compareNearbyEnabled and requestedPanelsDrawn == 0 and not menuComparisonDrawn and not anyMenuOpen
        if persistentNearbyModeActive then
            PerformancePanel.drawPanel(nil, { drawNearbyOnly = true })
        end

        local externalPanelActive = (tonumber(state.externalKeepAliveUntil) or 0) > GetGameTimer()
        if not anyMenuOpen and requestedPanelsDrawn == 0 and not menuComparisonDrawn and not externalPanelActive and not persistentNearbyModeActive and state.visible then
            state.visible = false
        end

        Wait(0)
    end
end)
