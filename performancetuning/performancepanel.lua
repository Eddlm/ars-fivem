-- Computes and draws the live performance index panel and its frame loop.
PerformanceTuning = PerformanceTuning or {}
PerformanceTuning.PerformancePanel = PerformanceTuning.PerformancePanel or {}

local PerformancePanel = PerformanceTuning.PerformancePanel
local INTERNAL_PERFORMANCE_DEFAULTS = {
    barSegmentCount = 20,
    power = 0.60,
    topSpeedMph = 220.0,
    grip = 2.50,
    brake = 2.50,
    flatVelToMphFactor = 145.0 / 176.0,
}
local SHARED_PANEL_HEIGHT_UNITS = 0.15
local SHARED_PANEL_BASE_SCALE = 0.95
local SHARED_PANEL_MIN_SCALE = 0.72
local SHARED_PANEL_ALPHA = 168
local SHARED_PANEL_FILL_ALPHA = 204
local SHARED_PANEL_HEADER_HEIGHT_RATIO = 0.15
local SHARED_PANEL_TEXT_BASE_HEIGHT_UNITS = 0.20
local SHARED_PANEL_WIDTH_UNITS = 0.1875
local DEFAULT_PANEL_HEIGHT_UNITS = 0.0874
local PRIMARY_PANEL_LEFT_MARGIN = 0.014
local MENU_PANEL_GAP_X = 0.018
local STACKED_PANEL_GAP_Y = 0.016
local DEFAULT_MENU_LEFT_PX = 20.0
local DEFAULT_MENU_WIDTH_PX = 431.0

local function getNitrousPowerBonusPoints(bucket)
    local packs = ((PerformanceTuning.Config or {}).packDefinitions or {}).nitrous or {}
    local selectedLevel = type(bucket) == 'table' and bucket.nitrousLevel or 'stock'

    for _, pack in ipairs(packs) do
        if pack.id == selectedLevel then
            return math.max(0.0, tonumber(pack.powerMultiplier) or 0.0) * 25.0
        end
    end

    return 0.0
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
    PerformancePanel.state = state
    return state
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
    state.nearbyVehicleCache = {
        sourceVehicle = nil,
        lastUpdatedAt = 0,
        entries = {},
    }
    state.externalKeepAliveUntil = 0
end

function PerformancePanel.computeBrakeBarProgressForVehicle(vehicle, brakeForce)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    local barFillTargets = (runtimeConfig or {}).performanceBarFillTargets or {}
    local brakeTopValueUnits = tonumber(barFillTargets.brake) or INTERNAL_PERFORMANCE_DEFAULTS.brake
    if brakeTopValueUnits <= 0.0 then
        brakeTopValueUnits = INTERNAL_PERFORMANCE_DEFAULTS.brake
    end
    local wheelCount = math.max(1, GetVehicleNumberOfWheels(vehicle) or 1)
    local computedBrakeValue = (tonumber(brakeForce) or 0.0) * wheelCount
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
        maxPanels = math.max(0, math.floor(tonumber(config.maxPanels) or 5)),
    }
end

local function getPiDisplayModeIndex()
    local scaleformUIState = (((PerformanceTuning or {}).ScaleformUI or {}).state or {})
    local index = math.floor(tonumber(scaleformUIState.piDisplayModeIndex) or 1)
    return math.max(1, math.min(3, index))
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
        return vehicleHasPanelStateBag(candidate)
    end
    if displayMode == 3 then
        return true
    end
    return false
end

local function getNearbyPanelVehiclesCached(displayState, primaryVehicle, nearbyConfig, displayMode)
    local maxDistanceMeters = tonumber(nearbyConfig.maxDistanceMeters) or 50.0
    local maxPanels = math.max(0, math.floor(tonumber(nearbyConfig.maxPanels) or 5))
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

local function getPrimaryPanelPlacement(panelWidth, panelHeight, safeInset, displayState)
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

        local screenWidth = tonumber(select(1, GetActiveScreenResolution())) or 0.0
        if screenWidth > 0.0 then
            local menuLeftPx = tonumber(visibleMenu and visibleMenu.X) or DEFAULT_MENU_LEFT_PX
            local widthOffsetPx = tonumber(visibleMenu and visibleMenu.WidthOffset) or 0.0
            local menuWidthPx = DEFAULT_MENU_WIDTH_PX + widthOffsetPx
            local menuRightX = (menuLeftPx + menuWidthPx) / screenWidth
            preferredLeftX = math.max(preferredLeftX, menuRightX + MENU_PANEL_GAP_X)
        end
    end

    local preferredCenterY = safeInset + (panelHeight * 0.5) + 0.02
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
    local panelMetrics = PerformancePanel.buildMetrics(vehicle)
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
        local rowTrackLeftX = trackLeftX - (panelW * 0.055) - 0.001
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

        drawPiLeftText(labelX, rowY - (trackH * 0.8) - 0.005, headerNameScale, orderedLabels[index])

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

function PerformancePanel.buildPerformanceIndex(vehicle, bucket)
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

    local nitrousPowerBonusPoints = getNitrousPowerBonusPoints(bucket or (bindings.ensureTuningState and bindings.ensureTuningState(vehicle) or nil))
    local piScales = getPiScales(runtimeConfig)
    local nitrousPowerBonusValue = nitrousPowerBonusPoints / (100.0 * piScales.power)
    local currentPower = (readHandlingValue and readHandlingValue(vehicle, 'float', engineFields.power) or 0.0) + shiftBenefit + nitrousPowerBonusValue
    local currentTopSpeed = getFlatVelTopSpeedMph(vehicle)
    local currentGrip = readHandlingValue and readHandlingValue(vehicle, 'float', tireFields.max) or 0.0
    local currentTractionLoss = readHandlingValue and readHandlingValue(vehicle, 'float', tireFields.tractionLoss) or 0.0
    local brakeForce = GetVehicleHandlingFloat(vehicle, definitions.handlingClass, brakeFields.force) or 0.0
    local currentBrakeProgress = PerformancePanel.computeBrakeBarProgressForVehicle(vehicle, brakeForce)
    local powerLevel = scaleMetricLevel(currentPower, performance.powerBarScaleFactor, performance.barSegmentCount)
    local topSpeedLevel = scaleMetricLevel(currentTopSpeed, performance.topSpeedBarScaleFactor, performance.barSegmentCount)
    local powerProgress = scaleMetricProgress(currentPower, performance.powerBarScaleFactor, performance.barSegmentCount)
    local topSpeedProgress = scaleMetricProgress(currentTopSpeed, performance.topSpeedBarScaleFactor, performance.barSegmentCount)
    local gripProgressFromMax = scaleMetricProgress(currentGrip, performance.gripBarScaleFactor, performance.barSegmentCount)
    local normalizedTractionLoss = clampUnit((tonumber(currentTractionLoss) or 0.0) / 3.0)
    local tractionLossProgress = 1.0 - normalizedTractionLoss
    local gripProgress = clampUnit((gripProgressFromMax * 0.75) + (tractionLossProgress * 0.25))
    local gripLevel = math.floor((gripProgress * (tonumber(performance.barSegmentCount) or 10)) + 0.5)
    local powerPi = scaleMetricPi(currentPower, performance.powerBarScaleFactor, piScales.power, performance.barSegmentCount)
    local topSpeedPi = scaleMetricPi(currentTopSpeed, performance.topSpeedBarScaleFactor, piScales.topSpeed, performance.barSegmentCount)
    local gripPi = math.floor((gripProgress * 100.0 * piScales.grip) + 0.5)
    local brakePi = math.floor((currentBrakeProgress * 100.0 * piScales.brake) + 0.5)

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
                valueLabel = ('Max %s | Loss %s'):format(
                    formatHandlingValue(currentGrip, 'float'),
                    formatHandlingValue(currentTractionLoss, 'float')
                ),
            }
        }
    }
end

function PerformancePanel.buildMetrics(vehicle)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    local definitions = PerformanceTuning.Definitions or {}
    local brakeFields = (definitions.handlingFields or {}).brakes or {}
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil
    end

    local performanceIndex = PerformancePanel.buildPerformanceIndex(vehicle)
    local categories = performanceIndex and performanceIndex.categories or {}
    local powerFill = (categories[1] or {}).progress or 0.0
    local speedFill = (categories[2] or {}).progress or 0.0
    local gripFill = (categories[3] or {}).progress or 0.0
    local brakeFill = PerformancePanel.computeBrakeBarProgressForVehicle(vehicle, GetVehicleHandlingFloat(vehicle, definitions.handlingClass, brakeFields.force) or 0.0)
    local piScales = getPiScales(runtimeConfig)

    return {
        total = performanceIndex and performanceIndex.total or 0,
        fills = { powerFill, speedFill, gripFill, brakeFill },
        labels = { 'PWR', 'SPD', 'GRP', 'BRK' },
        values = {
            math.floor((powerFill * 100.0 * piScales.power) + 0.5),
            math.floor((speedFill * 100.0 * piScales.topSpeed) + 0.5),
            math.floor((gripFill * 100.0 * piScales.grip) + 0.5),
            math.floor((brakeFill * 100.0 * piScales.brake) + 0.5),
        }
    }
end

function PerformancePanel.drawPanelInstance(vehicle, options)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end

    local state = getDisplayState()
    local scaleformUIState = (((PerformanceTuning or {}).ScaleformUI or {}).state or {})
    if isAnyMenuOpen(scaleformUIState) then
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
    if isAnyMenuOpen(scaleformUIState) then
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
        local maxDrawnPanels = math.max(0, math.floor(tonumber(nearbyConfig.maxPanels) or 5))
        local nearbyVehicles = getNearbyPanelVehiclesCached(state, primaryVehicle, nearbyConfig, displayMode)
        local titlePrefix = displayMode == 2 and 'Tuned' or 'Nearby'
        local keptNearbyRects = {}
        local drawnNearbyCount = 0
        local nearbyPanelHeight = SHARED_PANEL_HEIGHT_UNITS

        for _, entry in ipairs(nearbyVehicles) do
            if drawnNearbyCount >= maxDrawnPanels then
                break
            end
            local candidateVehicle = entry.vehicle
            local distanceMeters = math.sqrt(tonumber(entry.distanceSquared) or 0.0)
            local nearbyScale = getDistanceScaledPanelScale(distanceMeters, 0.0, 0.0, SHARED_PANEL_BASE_SCALE, SHARED_PANEL_BASE_SCALE)
            if not isPanelScaleVisible(nearbyScale) then
                goto continue_nearby_vehicle
            end
            local nearbyPanelWidth = getSharedPanelWidth() * nearbyScale
            local nearbyPanelHeightScaled = nearbyPanelHeight * nearbyScale
            local panelLeftX, panelY = nil, nil
            if shouldUseScreenAnchor and primaryPanelLeftX and primaryPanelY then
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
                local intersectsCloserPanel = false

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

        local persistentNearbyModeActive = getPiDisplayModeIndex() ~= 1
        if not nativeMenuOpen and persistentNearbyModeActive then
            PerformancePanel.drawPanel(nil, { drawNearbyOnly = true })
        end

        local externalPanelActive = (tonumber(state.externalKeepAliveUntil) or 0) > GetGameTimer()
        if not nativeMenuOpen and not externalPanelActive and not persistentNearbyModeActive and state.visible then
            state.visible = false
        end

        Wait(0)
    end
end)
