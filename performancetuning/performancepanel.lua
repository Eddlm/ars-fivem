-- Computes and draws the live performance index panel and its frame loop.
PerformanceTuning = PerformanceTuning or {}
PerformanceTuning.PerformancePanel = PerformanceTuning.PerformancePanel or {}

local PerformancePanel = PerformanceTuning.PerformancePanel

local function getNitrousPowerBonusPoints(bucket)
    local packs = ((PerformanceTuning.Definitions or {}).packDefinitions or {}).nitrous or {}
    local selectedLevel = type(bucket) == 'table' and bucket.nitrousLevel or 'stock'

    for _, pack in ipairs(packs) do
        if pack.id == selectedLevel then
            return math.max(0.0, tonumber(pack.multiplier) or 0.0) * 25.0
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

local function getUiAspectWidth(heightUnits)
    local resX, resY = GetActiveScreenResolution()
    if not resX or not resY or resX <= 0 or resY <= 0 then
        return heightUnits
    end

    return heightUnits * (resY / resX)
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
    local brakeScaling = runtimeConfig.brakeScaling or {}
    local wheelCount = math.max(1, GetVehicleNumberOfWheels(vehicle) or 1)
    local computedBrakeValue = (tonumber(brakeForce) or 0.0) * wheelCount
    return math.max(0.0, math.min(1.0, computedBrakeValue / (tonumber(brakeScaling.barTopValue) or 1.0)))
end

local function scaleMetricProgress(currentValue, factor)
    local isFiniteNumber = PerformanceTuning.ClientBindings and PerformanceTuning.ClientBindings.isFiniteNumber or nil
    local performance = (PerformanceTuning.Definitions or {}).performance or {}
    if not isFiniteNumber or not isFiniteNumber(currentValue) then
        return 0.0
    end

    if not isFiniteNumber(factor) or factor <= 0.0 then
        factor = 1.0
    end

    return math.max(0.0, (currentValue * factor) / (tonumber(performance.barSegments) or 1.0))
end

local function scaleMetricLevel(currentValue, factor)
    local performance = (PerformanceTuning.Definitions or {}).performance or {}
    local progress = scaleMetricProgress(currentValue, factor)
    return math.floor((progress * (tonumber(performance.barSegments) or 10)) + 0.5)
end

local function scaleMetricPi(currentValue, factor, piMultiplier)
    local progress = scaleMetricProgress(currentValue, factor)
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
    local configured = (runtimeConfig or {}).performancePiMultipliers or {}
    return {
        power = (tonumber(configured.power) or 10.0) * 0.1,
        topSpeed = (tonumber(configured.topSpeed) or 10.0) * 0.1,
        grip = (tonumber(configured.grip) or 10.0) * 0.1,
        brake = (tonumber(configured.brake) or 10.0) * 0.1,
    }
end

local function resolvePiClassLabel(runtimeConfig, piTotal)
    local classes = (runtimeConfig or {}).performancePiClasses
    if type(classes) == 'table' then
        for _, classDef in ipairs(classes) do
            local minimum = tonumber(type(classDef) == 'table' and classDef.minimum or nil) or 0
            local label = type(classDef) == 'table' and tostring(classDef.label or '') or ''
            if label ~= '' and piTotal >= minimum then
                return label
            end
        end
    end

    return 'N/A'
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
    local nativeUIState = (((PerformanceTuning or {}).NativeUI or {}).state or {})
    local index = math.floor(tonumber(nativeUIState.piDisplayModeIndex) or 1)
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
        return (left.distanceSquared or math.huge) < (right.distanceSquared or math.huge)
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

local function getWorldAnchoredPanelPosition(vehicle, panelScale, safeInset)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil
    end

    local model = GetEntityModel(vehicle)
    local minBounds, maxBounds = GetModelDimensions(model)
    local roofHeight = (maxBounds and tonumber(maxBounds.z)) or nil
    if type(roofHeight) ~= 'number' then
        roofHeight = 1.0
    end
    local roofClearance = 0.02
    local anchor = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, 0.0, roofHeight + roofClearance)

    local anchorX = anchor.x
    local anchorY = anchor.y
    local anchorZ = anchor.z
    local visible, screenX = GetScreenCoordFromWorldCoord(anchorX, anchorY, anchorZ)
    if not visible then
        return nil
    end

    local panelHeight = 0.19 * panelScale
    local panelWidth = getUiAspectWidth(panelHeight)
    local panelLeftX = screenX - (panelWidth * 0.5)
    local panelY = 0.18 + safeInset
    return clampPanelToSafeZone(panelLeftX, panelY, panelWidth, panelHeight, safeInset)
end

local function doRectsOverlap(leftA, rightA, topA, bottomA, leftB, rightB, topB, bottomB)
    return leftA < rightB
        and rightA > leftB
        and topA < bottomB
        and bottomA > topB
end

local function drawPanelInstanceInternal(vehicle, displayState, stateKey, options, runtimeConfig)
    local panelMetrics = PerformancePanel.buildMetrics(vehicle)
    if not panelMetrics then
        return false
    end

    local safeZone = GetSafeZoneSize()
    local safeInset = (1.0 - safeZone) * 0.5
    local panelScale = math.max(0.1, tonumber((options or {}).panelScale) or 1.3)
    local panelH = 0.19 * panelScale
    local panelW = getUiAspectWidth(panelH)
    local panelLeftX = tonumber((options or {}).panelLeftX)
    if panelLeftX == nil then
        panelLeftX = 0.014 + safeInset
    end
    local panelX = panelLeftX + (panelW * 0.5)
    local panelY = tonumber((options or {}).panelY)
    if panelY == nil then
        panelY = 0.18 + safeInset
    end
    local panelAlpha = math.max(0, math.min(255, math.floor(tonumber((options or {}).panelAlpha) or 84)))
    local fillAlpha = math.max(0, math.min(255, math.floor(tonumber((options or {}).fillAlpha) or 168)))
    local barBaseY = panelY + (0.0152088 * panelScale)
    local barH = 0.108 * panelScale
    local barW = getUiAspectWidth(0.03086208 * panelScale)
    local barGap = getUiAspectWidth(0.0403767 * panelScale)
    local firstBarX = panelX - (barGap * 1.5)
    local dt = GetFrameTime()
    local lerpAlpha = math.min(1.0, math.max(0.0, dt * 6.0))
    local piScales = getPiScales(runtimeConfig)
    local animationState = getPanelAnimationState(displayState, stateKey)
    local title = tostring((options or {}).title or '')

    for index = 1, #panelMetrics.fills do
        local currentFill = animationState.fills[index] or 0.0
        local targetFill = panelMetrics.fills[index]
        animationState.fills[index] = currentFill + ((targetFill - currentFill) * lerpAlpha)
    end

    local displayedValues = {
        math.floor(((animationState.fills[1] or 0.0) * 100.0 * piScales.power) + 0.5),
        math.floor(((animationState.fills[2] or 0.0) * 100.0 * piScales.topSpeed) + 0.5),
        math.floor(((animationState.fills[3] or 0.0) * 100.0 * piScales.grip) + 0.5),
        math.floor(((animationState.fills[4] or 0.0) * 100.0 * piScales.brake) + 0.5),
    }
    local displayedTotal = displayedValues[1] + displayedValues[2] + displayedValues[3] + displayedValues[4]

    DrawRect(panelX, panelY, panelW, panelH, 0, 0, 0, panelAlpha)
    if title ~= '' then
        drawPiCenteredText(panelX, panelY - (0.102 * panelScale), 0.16 * panelScale, title)
    end
    drawPiCenteredText(panelX, panelY - (0.082 * panelScale), 0.28 * panelScale, ('PI: %d'):format(displayedTotal))

    for index = 1, #animationState.fills do
        local barX = firstBarX + ((index - 1) * barGap)
        local fill = animationState.fills[index]
        DrawRect(barX, barBaseY, barW, barH, 0, 0, 0, panelAlpha)
        DrawRect(barX, barBaseY + ((barH * (1.0 - fill)) * 0.5), barW, barH * fill, 40, 110, 255, fillAlpha)
        drawPiCenteredText(barX, barBaseY - (barH * 0.72), 0.18 * panelScale, ('%d'):format(displayedValues[index] or 0))
        drawPiCenteredText(barX, barBaseY + (barH * 0.5104), 0.22 * panelScale, panelMetrics.labels[index])
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

    return flatVel * ((PerformanceTuning.Definitions or {}).performance or {}).flatVelToMph
end

function PerformancePanel.buildPerformanceIndex(vehicle, bucket)
    local bindings = PerformanceTuning.ClientBindings or {}
    local definitions = PerformanceTuning.Definitions or {}
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    local performance = definitions.performance or {}
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
    local powerLevel = scaleMetricLevel(currentPower, performance.powerFactor)
    local topSpeedLevel = scaleMetricLevel(currentTopSpeed, performance.topSpeedFactor)
    local powerProgress = scaleMetricProgress(currentPower, performance.powerFactor)
    local topSpeedProgress = scaleMetricProgress(currentTopSpeed, performance.topSpeedFactor)
    local gripProgressFromMax = scaleMetricProgress(currentGrip, performance.gripFactor)
    local normalizedTractionLoss = clampUnit((tonumber(currentTractionLoss) or 0.0) / 3.0)
    local tractionLossProgress = 1.0 - normalizedTractionLoss
    local gripProgress = clampUnit((gripProgressFromMax * 0.75) + (tractionLossProgress * 0.25))
    local gripLevel = math.floor((gripProgress * (tonumber(performance.barSegments) or 10)) + 0.5)
    local powerPi = scaleMetricPi(currentPower, performance.powerFactor, piScales.power)
    local topSpeedPi = scaleMetricPi(currentTopSpeed, performance.topSpeedFactor, piScales.topSpeed)
    local gripPi = math.floor((gripProgress * 100.0 * piScales.grip) + 0.5)
    local brakePi = math.floor((currentBrakeProgress * 100.0 * piScales.brake) + 0.5)

    local totalPi = powerPi + topSpeedPi + gripPi + brakePi
    return {
        total = totalPi,
        class = resolvePiClassLabel(runtimeConfig, totalPi),
        categories = {
            {
                key = 'power',
                label = 'POWER',
                level = powerLevel,
                maxLevel = performance.barSegments,
                progress = powerProgress,
                pi = powerPi,
                value = currentPower,
                valueLabel = formatHandlingValue(currentPower, 'float'),
            },
            {
                key = 'top_speed',
                label = 'TOP SPEED',
                level = topSpeedLevel,
                maxLevel = performance.barSegments,
                progress = topSpeedProgress,
                pi = topSpeedPi,
                value = currentTopSpeed,
                valueLabel = ('%d mph'):format(math.floor(currentTopSpeed + 0.5)),
            },
            {
                key = 'grip',
                label = 'GRIP',
                level = gripLevel,
                maxLevel = performance.barSegments,
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
        class = performanceIndex and performanceIndex.class or 'N/A',
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
    local drawOptions = options or {}
    local validPrimaryVehicle = vehicle and vehicle ~= 0 and DoesEntityExist(vehicle)
    local drawNearbyOnly = drawOptions.drawNearbyOnly == true
    local didDrawAny = false

    if validPrimaryVehicle and not drawNearbyOnly then
        local primaryDrawn = drawPanelInstanceInternal(vehicle, state, 'primary', {
            panelScale = 1.3,
        }, runtimeConfig)
        if primaryDrawn then
            didDrawAny = true
        end
    end

    local displayMode = getPiDisplayModeIndex()
    local nearbyConfig = getNearbyPanelConfig(runtimeConfig)
    if displayMode ~= 1 and nearbyConfig.enabled then
        local safeZone = GetSafeZoneSize()
        local safeInset = (1.0 - safeZone) * 0.5
        local primaryScale = 1.3
        local maxDrawnPanels = math.max(0, math.floor(tonumber(nearbyConfig.maxPanels) or 5))
        local nearbyVehicles = getNearbyPanelVehiclesCached(state, vehicle, nearbyConfig, displayMode)
        local titlePrefix = displayMode == 2 and 'Tuned' or 'Nearby'
        local keptNearbyRects = {}
        local drawnNearbyCount = 0

        for _, entry in ipairs(nearbyVehicles) do
            if drawnNearbyCount >= maxDrawnPanels then
                break
            end
            local candidateVehicle = entry.vehicle
            local distanceMeters = math.sqrt(tonumber(entry.distanceSquared) or 0.0)
            local scaleMultiplier = 1.0
            local nearbyScale = primaryScale * scaleMultiplier
            local nearbyPanelHeight = 0.19 * nearbyScale
            local nearbyPanelWidth = getUiAspectWidth(nearbyPanelHeight)
            local panelLeftX, panelY = getWorldAnchoredPanelPosition(candidateVehicle, nearbyScale, safeInset)
            if panelLeftX and panelY then
                local panelRightX = panelLeftX + nearbyPanelWidth
                local panelTopY = panelY - (nearbyPanelHeight * 0.5)
                local panelBottomY = panelY + (nearbyPanelHeight * 0.5)
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
                    local didDrawNearby = drawPanelInstanceInternal(candidateVehicle, state, ('nearby:%s'):format(tostring(candidateVehicle)), {
                        panelScale = nearbyScale,
                        panelY = panelY,
                        panelLeftX = panelLeftX,
                        panelAlpha = 72,
                        fillAlpha = 140,
                        title = ('%s %.0fm'):format(titlePrefix, distanceMeters),
                    }, runtimeConfig)
                    didDrawAny = didDrawAny or didDrawNearby == true
                    if didDrawNearby then
                        drawnNearbyCount = drawnNearbyCount + 1
                    end

                    keptNearbyRects[#keptNearbyRects + 1] = {
                        left = panelLeftX,
                        right = panelRightX,
                        top = panelTopY,
                        bottom = panelBottomY,
                    }
                end
            end
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
        if PerformanceTuning.NativeUI and PerformanceTuning.NativeUI.processFrame then
            nativeMenuOpen = PerformanceTuning.NativeUI.processFrame() == true
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
