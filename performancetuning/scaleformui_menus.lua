-- Builds and runs the full ScaleformUI tuning menu hierarchy.
PerformanceTuning = PerformanceTuning or {}
PerformanceTuning.ScaleformUI = PerformanceTuning.ScaleformUI or {}
local MENU_DESCRIPTIONS = {
    engine = 'Engine power and top speed.',
    transmission = 'Shift speed and gearing.',
    suspension = 'Body control and weight transfer.',
    tireCompoundCategory = 'Tire compound family.',
    tireCompoundQuality = 'Tire quality tier.',
    brakes = 'Stopping force.',
    nitrous = 'On-demand power boost.',
    antirollBars = 'Roll stiffness.',
    nitrousShotStrength = 'Burst strength versus duration.',
    brakeBiasFront = 'Front-to-rear brake balance.',
    gripBiasFront = 'Front-to-rear grip balance.',
    antirollBiasFront = 'Front-to-rear roll stiffness.',
    suspensionRaise = 'Ride height gap.',
    suspensionBiasFront = 'Front-to-rear suspension balance.',
    steeringLockMode = 'Speed-based steering lock scaling.',
    tweaks = 'Fine adjustments.',
}
local LIST_OPTION_DESCRIPTIONS = {
    steeringLockMode = {
        [1] = 'Stock steering lock.',
        [2] = '2.0x lateral grip scaling.',
        [3] = '2.5x lateral grip scaling.',
        [4] = '3.0x lateral grip scaling.',
        [5] = '1.0x lateral grip scaling.',
        [6] = '1.5x lateral grip scaling.',
    },
}

local function getScaleformUIState()
    local scaleformUI = PerformanceTuning.ScaleformUI
    scaleformUI.state = scaleformUI.state or {}
    scaleformUI.state.menus = scaleformUI.state.menus or {}
    scaleformUI.state.items = scaleformUI.state.items or {}
    scaleformUI.state.options = scaleformUI.state.options or {}
    scaleformUI.state.sliderValues = scaleformUI.state.sliderValues or {}
    scaleformUI.state.dynamicSliderProfiles = scaleformUI.state.dynamicSliderProfiles or {}
    scaleformUI.state.panels = scaleformUI.state.panels or {}
    scaleformUI.state.piDisplayModeIndex = math.max(1, math.min(3, math.floor(tonumber(scaleformUI.state.piDisplayModeIndex) or 1)))
    scaleformUI.state.menuOpen = scaleformUI.state.menuOpen == true
    scaleformUI.state.menuInitialized = scaleformUI.state.menuInitialized == true
    scaleformUI.state.switchingToTweaks = scaleformUI.state.switchingToTweaks == true
    return scaleformUI.state
end

local function getNearestSuspensionProfileIndex(profile, value)
    local resolvedValue = tonumber(value) or 0.0
    local nearestIndex = 1
    local nearestDistance = math.huge
    for index, raiseValue in ipairs((profile or {}).raiseValues or {}) do
        local distance = math.abs((tonumber(raiseValue) or 0.0) - resolvedValue)
        if distance < nearestDistance then
            nearestDistance = distance
            nearestIndex = index
        end
    end
    return nearestIndex
end

local function getMenuDescription(key)
    return MENU_DESCRIPTIONS[key] or ''
end

local function getListOptionDescription(listKey, option, currentValue)
    local label = type(option) == 'table' and option.label or nil
    local description = type(option) == 'table' and option.description or nil
    local unavailableSuffix = type(option) == 'table' and option.enabled == false and ' Unavailable on this vehicle.' or ''

    if type(label) ~= 'string' or label == '' then
        return tostring(currentValue or '')
    end
    if type(description) ~= 'string' or description == '' then
        description = getMenuDescription(listKey)
    end
    return ('%s%s'):format(description or '', unavailableSuffix)
end

local function getIndexedListOption(listKey, index)
    local state = getScaleformUIState()
    local options = (state.options or {})[listKey]
    return type(options) == 'table' and options[index] or nil
end

local function getMainMenuItemByContext(state, context)
    return ({
        engine = state.items.engine,
        transmission = state.items.transmission,
        suspension = state.items.suspension,
        tireCompoundCategory = state.items.tireCompoundCategory,
        tireCompoundQuality = state.items.tireCompoundQuality,
        brakes = state.items.brakes,
        nitrous = state.items.nitrous,
    })[context]
end

local function setListItemDescription(listItem, listKey, option, currentValue)
    if listItem and type(listItem.Description) == 'function' then
        listItem:Description(getListOptionDescription(listKey, option, currentValue))
    end
end

local function setListItemOptions(listItem, options, currentStep)
    local items = {}
    local selectedIndex = 1
    for index, option in ipairs(options or {}) do
        local suffix = option.enabled == false and ' (Unavailable)' or ''
        items[index] = ('%s%s'):format(option.label, suffix)
        if option.id == currentStep then
            selectedIndex = index
        end
    end
    if #items == 0 then
        items[1] = 'No options'
    end
    listItem.Items = items
    listItem:Index(selectedIndex)
end

local function restoreMenuSelection(menu, getterIndex)
    if not menu then
        return
    end
    local itemCount = #(menu.Items or {})
    if itemCount <= 0 then
        return
    end
    local clampedGetterIndex = math.max(1, math.min(itemCount, math.floor(tonumber(getterIndex) or 1)))
    menu:CurrentSelection(clampedGetterIndex)
end

local function setMenuItemsEnabled(enabled, disabledDescription)
    local state = getScaleformUIState()
    local resolvedEnabled = enabled == true
    local disabledText = tostring(disabledDescription or 'Enter the driver seat to enable tuning controls.')
    local itemOrder = {
        'engine', 'transmission', 'suspension', 'tireCompoundCategory', 'tireCompoundQuality',
        'brakes', 'antirollSlider', 'nitrous', 'openTweaks',
        'nitrousShotSlider', 'steeringLockMode', 'brakeBiasSlider',
        'gripBiasSlider', 'antirollBiasSlider', 'suspensionRaiseSlider', 'suspensionBiasSlider',
    }

    for _, itemKey in ipairs(itemOrder) do
        local item = state.items[itemKey]
        if item ~= nil then
            if type(item.Enabled) == 'function' then
                item:Enabled(resolvedEnabled)
            end
            if not resolvedEnabled and type(item.Description) == 'function' then
                item:Description(disabledText)
            end
        end
    end
end

local function createPiStatisticsPanel()
    return UIMenuStatisticsPanel.New({
        { name = 'Speed', value = 0 },
        { name = 'Power', value = 0 },
        { name = 'Grip', value = 0 },
        { name = 'Brake', value = 0 },
    })
end

local function attachPiStatisticsPanel(item)
    if not item or type(item.AddPanel) ~= 'function' then
        return
    end

    local state = getScaleformUIState()
    state.panels.piStats = state.panels.piStats or {}

    local panel = createPiStatisticsPanel()
    item:AddPanel(panel)
    state.panels.piStats[#state.panels.piStats + 1] = panel
end

local function refreshVisibleMenuPanels()
    local state = getScaleformUIState()
    local menus = { state.menus.main, state.menus.tweaks }

    for index = 1, #menus do
        local menu = menus[index]
        if menu and menu:Visible() and type(menu.CurrentSelection) == 'function' and type(menu.SendPanelsToItemScaleform) == 'function' then
            local currentSelection = math.floor(tonumber(menu:CurrentSelection()) or 1)
            if currentSelection >= 1 and currentSelection <= #(menu.Items or {}) then
                menu:SendPanelsToItemScaleform(currentSelection, false)
            end
        end
    end
end

local function updatePiStatisticsPanels(vehicle)
    local state = getScaleformUIState()
    local panels = (state.panels or {}).piStats or {}
    if #panels <= 0 then
        return
    end

    local metrics = vehicle and PerformanceTuning.PerformancePanel and PerformanceTuning.PerformancePanel.buildMetrics and PerformanceTuning.PerformancePanel.buildMetrics(vehicle) or nil
    local fills = type(metrics) == 'table' and type(metrics.fills) == 'table' and metrics.fills or {}
    local values = {
        math.floor(((tonumber(fills[2]) or 0.0) * 100.0) + 0.5),
        math.floor(((tonumber(fills[1]) or 0.0) * 100.0) + 0.5),
        math.floor(((tonumber(fills[3]) or 0.0) * 100.0) + 0.5),
        math.floor(((tonumber(fills[4]) or 0.0) * 100.0) + 0.5),
    }

    for index = 1, #panels do
        local panel = panels[index]
        if panel then
            for statIndex = 1, 4 do
                panel:UpdateStatistic(statIndex, values[statIndex] or 0)
            end
        end
    end

    refreshVisibleMenuPanels()
end

local function refreshSuspensionRaiseSliderRange(vehicle)
    local scaleformUI = PerformanceTuning.ScaleformUI
    local state = getScaleformUIState()
    local item = state.items.suspensionRaiseSlider
    if item == nil then
        return
    end

    local bucket = vehicle and scaleformUI.ensureTuningState(vehicle) or nil
    local baseUpperLimit = bucket and bucket.baseSuspension and tonumber(bucket.baseSuspension.fSuspensionUpperLimit) or 0.0
    local baseRaise = bucket and bucket.baseSuspension and tonumber(bucket.baseSuspension.fSuspensionRaise) or 0.0
    local leftRaise = baseRaise - (baseUpperLimit * 0.5)
    local rightRaise = math.min(baseRaise + 0.2, 0.3)
    local raiseValues = {}
    local labels = {}
    local sliderSteps = 9
    local centerIndex = 5
    local sideStepCount = centerIndex - 1

    for index = 1, sliderSteps do
        local raiseValue
        if index <= centerIndex then
            local progress = (index - 1) / sideStepCount
            raiseValue = leftRaise + ((baseRaise - leftRaise) * progress)
        else
            local progress = (index - centerIndex) / sideStepCount
            raiseValue = baseRaise + ((rightRaise - baseRaise) * progress)
        end
        raiseValues[index] = raiseValue
        labels[index] = ('%.3f'):format(raiseValue)
    end

    state.dynamicSliderProfiles.suspensionRaise = { raiseValues = raiseValues, labels = labels }
    state.sliderValues.suspensionRaise = labels
    item._Max = math.max(0, #labels - 1)
end

local function setAntirollSliderState(value)
    local scaleformUI = PerformanceTuning.ScaleformUI
    local item = getScaleformUIState().items.antirollSlider
    if item == nil then
        return
    end
    local resolvedValue = scaleformUI.clampAntirollForceValue(value)
    item:Description(('Current: %s'):format(scaleformUI.getAntirollForceLabel(resolvedValue)))
    item:Index(scaleformUI.getAntirollSliderIndex(resolvedValue) - 1)
end

local function setNitrousShotSliderState(value)
    local scaleformUI = PerformanceTuning.ScaleformUI
    local item = getScaleformUIState().items.nitrousShotSlider
    if item == nil then
        return
    end
    local resolvedValue = scaleformUI.clampNitroShotStrength(value)
    item:Description(('Current: %s'):format(scaleformUI.getNitroShotStrengthLabel(resolvedValue)))
    item:Index(scaleformUI.getNitroShotSliderIndex(resolvedValue) - 1)
end

local function setBrakeBiasSliderState(value)
    local scaleformUI = PerformanceTuning.ScaleformUI
    local item = getScaleformUIState().items.brakeBiasSlider
    if item == nil then
        return
    end
    local resolvedValue = scaleformUI.clampBrakeBiasFrontValue(value)
    item:Description(('Current: %s'):format(scaleformUI.getBrakeBiasFrontLabel(resolvedValue)))
    item:Index(scaleformUI.getBrakeBiasSliderIndex(resolvedValue) - 1)
end

local function setGripBiasSliderState(value)
    local scaleformUI = PerformanceTuning.ScaleformUI
    local item = getScaleformUIState().items.gripBiasSlider
    if item == nil then
        return
    end
    local resolvedValue = scaleformUI.clampGripBiasFrontValue(value)
    item:Description(('Current: %s'):format(scaleformUI.getGripBiasFrontLabel(resolvedValue)))
    item:Index(scaleformUI.getGripBiasSliderIndex(resolvedValue) - 1)
end

local function setAntirollBiasSliderState(value)
    local scaleformUI = PerformanceTuning.ScaleformUI
    local item = getScaleformUIState().items.antirollBiasSlider
    if item == nil then
        return
    end
    local resolvedValue = scaleformUI.clampAntirollBiasFrontValue(value)
    item:Description(('Current: %s'):format(scaleformUI.getAntirollBiasFrontLabel(resolvedValue)))
    item:Index(scaleformUI.getAntirollBiasSliderIndex(resolvedValue) - 1)
end

local function setSuspensionRaiseSliderState(value)
    local scaleformUI = PerformanceTuning.ScaleformUI
    local state = getScaleformUIState()
    local item = state.items.suspensionRaiseSlider
    if item == nil then
        return
    end

    local vehicle = scaleformUI.getCurrentVehicle()
    local bucket = vehicle and scaleformUI.ensureTuningState(vehicle) or nil
    local baseUpperLimit = bucket and bucket.baseSuspension and tonumber(bucket.baseSuspension.fSuspensionUpperLimit) or 0.0
    local liveUpperLimit = vehicle and PerformanceTuning.HandlingManager.readHandlingValue(vehicle, 'float', 'fSuspensionUpperLimit') or nil
    local displayedUpperLimit = tonumber(liveUpperLimit) or baseUpperLimit
    local profile = state.dynamicSliderProfiles.suspensionRaise or {}
    local resolvedValue = tonumber(value) or 0.0
    item:Description(('Upper: %.4f | Raise: %.4f | Gap: %.4f'):format(displayedUpperLimit, resolvedValue, displayedUpperLimit - resolvedValue))
    item:Index(getNearestSuspensionProfileIndex(profile, resolvedValue) - 1)
end

local function setSuspensionBiasSliderState(value)
    local scaleformUI = PerformanceTuning.ScaleformUI
    local item = getScaleformUIState().items.suspensionBiasSlider
    if item == nil then
        return
    end
    local resolvedValue = scaleformUI.clampSuspensionBiasFrontValue(value)
    item:Description(('Current: %s'):format(scaleformUI.getSuspensionBiasFrontLabel(resolvedValue)))
    item:Index(scaleformUI.getSuspensionBiasSliderIndex(resolvedValue) - 1)
end

local function getSteeringLockModeIdFromIndex(index)
    if index == 2 then return 'balanced' end
    if index == 3 then return 'aggressive' end
    if index == 4 then return 'very_aggressive' end
    if index == 5 then return 'very_smooth' end
    if index == 6 then return 'smooth' end
    return 'stock'
end

local function getSteeringLockModeIndex(modeId)
    local normalized = tostring(modeId or 'stock'):lower()
    if normalized == 'balanced' or normalized == 'balance' then return 2 end
    if normalized == 'aggro' or normalized == 'aggressive' then return 3 end
    if normalized == 'very_aggro' or normalized == 'very_aggressive' or normalized == 'extreme_aggressive' then return 4 end
    if normalized == 'very_smooth' or normalized == 'extreme_smooth' then return 5 end
    if normalized == 'sooth' or normalized == 'smooth' then return 6 end
    return 1
end

local function handleSteeringLockModeSelection(index)
    local scaleformUI = PerformanceTuning.ScaleformUI
    local vehicle = scaleformUI.getCurrentVehicle()
    if not vehicle then
        return
    end
    local selectedMode = getSteeringLockModeIdFromIndex(index)
    if scaleformUI.applySteeringLockModeTweak then
        scaleformUI.applySteeringLockModeTweak(vehicle, selectedMode)
    else
        local bucket = scaleformUI.ensureTuningState(vehicle)
        bucket.steeringLockMode = selectedMode
        scaleformUI.syncVehicleTuneState(vehicle)
    end
    scaleformUI.refreshMenu()
end

local function previewMainMenuSelection(context, index)
    local scaleformUI = PerformanceTuning.ScaleformUI
    local state = getScaleformUIState()
    local item = getMainMenuItemByContext(state, context)
    if item then
        local listState = scaleformUI.buildListState(context) or {}
        setListItemDescription(item, context, getIndexedListOption(context, index), (listState.context or {}).currentValue)
    end
end

local function updateMainMenuListContext(context)
    local scaleformUI = PerformanceTuning.ScaleformUI
    local state = getScaleformUIState()
    local listState = scaleformUI.buildListState(context)
    if not listState then
        return
    end
    local currentValue = ((listState or {}).context or {}).currentValue
    local currentStep = ((listState or {}).context or {}).currentStep
    local options = ((listState or {}).context or {}).options or {}
    state.options[context] = options
    local item = getMainMenuItemByContext(state, context)
    if item then
        setListItemOptions(item, options, currentStep)
        setListItemDescription(item, context, getIndexedListOption(context, item:Index()), currentValue)
    end
end

local function handleMainMenuSelection(context, index)
    previewMainMenuSelection(context, index)
    PerformanceTuning.ScaleformUI.applyMenuSelection(context, index)
    updateMainMenuListContext(context)
    updatePiStatisticsPanels(PerformanceTuning.ScaleformUI.getCurrentVehicle())
end

local function handleMainSliderChange(index)
    local scaleformUI = PerformanceTuning.ScaleformUI
    local vehicle = scaleformUI.getCurrentVehicle()
    if not vehicle then
        return
    end
    local value = scaleformUI.getSliderValueForIndex(index + 1, scaleformUI.sliderRanges.antirollBars)
    setAntirollSliderState(value)
    scaleformUI.applyAntirollForceTweak(vehicle, value)
    updatePiStatisticsPanels(vehicle)
end

local function handleTweakSliderChange(item, index)
    local scaleformUI = PerformanceTuning.ScaleformUI
    local state = getScaleformUIState()
    local vehicle = scaleformUI.getCurrentVehicle()
    if not vehicle then
        return
    end

    if item == state.items.nitrousShotSlider then
        local value = scaleformUI.getSliderValueForIndex(index + 1, scaleformUI.sliderRanges.nitrousShotStrength)
        setNitrousShotSliderState(value)
        scaleformUI.applyNitroShotStrengthTweak(vehicle, value)
    elseif item == state.items.brakeBiasSlider then
        local value = scaleformUI.getSliderValueForIndex(index + 1, scaleformUI.sliderRanges.brakeBiasFront)
        setBrakeBiasSliderState(value)
        scaleformUI.applyBrakeBiasFrontTweak(vehicle, value)
    elseif item == state.items.gripBiasSlider then
        local value = scaleformUI.getSliderValueForIndex(index + 1, scaleformUI.sliderRanges.gripBiasFront)
        setGripBiasSliderState(value)
        scaleformUI.applyGripBiasFrontTweak(vehicle, value)
    elseif item == state.items.antirollBiasSlider then
        local value = scaleformUI.getSliderValueForIndex(index + 1, scaleformUI.sliderRanges.antirollBiasFront)
        setAntirollBiasSliderState(value)
        scaleformUI.applyAntirollBiasFrontTweak(vehicle, value)
    elseif item == state.items.suspensionRaiseSlider then
        local profile = state.dynamicSliderProfiles.suspensionRaise or {}
        local value = ((profile.raiseValues or {})[index + 1]) or 0.0
        setSuspensionRaiseSliderState(value)
        scaleformUI.applySuspensionRaiseTweak(vehicle, value)
    elseif item == state.items.suspensionBiasSlider then
        local value = scaleformUI.getSliderValueForIndex(index + 1, scaleformUI.sliderRanges.suspensionBiasFront)
        setSuspensionBiasSliderState(value)
        scaleformUI.applySuspensionBiasFrontTweak(vehicle, value)
    end

    updatePiStatisticsPanels(vehicle)
end

function PerformanceTuning.ScaleformUI.closeMenu()
    local scaleformUI = PerformanceTuning.ScaleformUI
    local state = getScaleformUIState()
    state.menuOpen = false
    state.lastVehicleValidity = nil
    scaleformUI.resetPerformanceIndexDisplayState()
    if state.menus.tweaks then
        state.menus.tweaks:Visible(false)
    end
    if state.menus.main then
        state.menus.main:Visible(false)
    end
end

function PerformanceTuning.ScaleformUI.getPiDisplayModeIndex()
    local state = getScaleformUIState()
    return math.max(1, math.min(3, math.floor(tonumber(state.piDisplayModeIndex) or 1)))
end

function PerformanceTuning.ScaleformUI.setPiDisplayModeIndex(index)
    local state = getScaleformUIState()
    state.piDisplayModeIndex = math.max(1, math.min(3, math.floor(tonumber(index) or 1)))
    if state.menuInitialized then
        PerformanceTuning.ScaleformUI.refreshMenu()
    end
    return state.piDisplayModeIndex
end

function PerformanceTuning.ScaleformUI.getCurrentVehicleRevLimiterEnabled()
    local scaleformUI = PerformanceTuning.ScaleformUI
    local vehicle = scaleformUI.getCurrentVehicle()
    if not vehicle then
        return nil
    end

    local bucket = scaleformUI.ensureTuningState(vehicle)
    return bucket.revLimiterEnabled == true
end

function PerformanceTuning.ScaleformUI.setCurrentVehicleRevLimiterEnabled(enabled)
    local scaleformUI = PerformanceTuning.ScaleformUI
    local vehicle = scaleformUI.getCurrentVehicle()
    if not vehicle then
        return false
    end

    local bucket = scaleformUI.ensureTuningState(vehicle)
    bucket.revLimiterEnabled = enabled == true
    scaleformUI.syncVehicleTuneState(vehicle)
    scaleformUI.refreshMenu()
    return true
end

function PerformanceTuning.ScaleformUI.getCurrentVehicleSteeringLockMode()
    local scaleformUI = PerformanceTuning.ScaleformUI
    local vehicle = scaleformUI.getCurrentVehicle()
    if not vehicle then
        return nil
    end

    local bucket = scaleformUI.ensureTuningState(vehicle)
    return tostring(bucket.steeringLockMode or 'stock')
end

function PerformanceTuning.ScaleformUI.setCurrentVehicleSteeringLockMode(mode)
    local scaleformUI = PerformanceTuning.ScaleformUI
    local vehicle = scaleformUI.getCurrentVehicle()
    if not vehicle then
        return false, nil
    end

    local selectedMode = tostring(mode or 'stock')
    if scaleformUI.applySteeringLockModeTweak then
        local ok, normalizedMode = scaleformUI.applySteeringLockModeTweak(vehicle, selectedMode)
        scaleformUI.refreshMenu()
        return ok == true, normalizedMode
    end

    local bucket = scaleformUI.ensureTuningState(vehicle)
    bucket.steeringLockMode = selectedMode
    scaleformUI.syncVehicleTuneState(vehicle)
    scaleformUI.refreshMenu()
    return true, selectedMode
end

function PerformanceTuning.ScaleformUI.refreshMenu()
    local scaleformUI = PerformanceTuning.ScaleformUI
    local state = getScaleformUIState()
    if not state.menuInitialized then
        return false
    end

    local selectedMenuIndex = state.menus.main and state.menus.main:CurrentSelection() or 1
    local vehicle, vehicleError = scaleformUI.getCurrentVehicle()
    if not vehicle then
        state.menus.main:Subtitle('~r~NO VALID CAR')
        setMenuItemsEnabled(false, vehicleError or 'Enter the driver seat to enable tuning controls.')
        restoreMenuSelection(state.menus.main, selectedMenuIndex)
        return true
    end

    setMenuItemsEnabled(true)
    local engineState, engineError = scaleformUI.buildListState('engine')
    if not engineState then
        state.menus.main:Subtitle('~r~NO VALID CAR')
        setMenuItemsEnabled(false, engineError or 'Enter the driver seat to enable tuning controls.')
        restoreMenuSelection(state.menus.main, selectedMenuIndex)
        return true
    end

    local transmissionState = scaleformUI.buildListState('transmission')
    local suspensionState = scaleformUI.buildListState('suspension')
    local tireCompoundCategoryState = scaleformUI.buildListState('tireCompoundCategory')
    local tireCompoundQualityState = scaleformUI.buildListState('tireCompoundQuality')
    local brakesState = scaleformUI.buildListState('brakes')
    local nitrousState = scaleformUI.buildListState('nitrous')
    local bucket = scaleformUI.ensureTuningState(engineState.vehicle)
    refreshSuspensionRaiseSliderRange(engineState.vehicle)

    state.options.engine = engineState.context.options or {}
    state.options.transmission = transmissionState.context.options or {}
    state.options.suspension = suspensionState.context.options or {}
    state.options.tireCompoundCategory = tireCompoundCategoryState.context.options or {}
    state.options.tireCompoundQuality = tireCompoundQualityState.context.options or {}
    state.options.brakes = brakesState.context.options or {}
    state.options.nitrous = nitrousState.context.options or {}
    state.menus.main:Subtitle(engineState.displayName)

    setListItemOptions(state.items.engine, state.options.engine, engineState.context.currentStep)
    setListItemOptions(state.items.transmission, state.options.transmission, transmissionState.context.currentStep)
    setListItemOptions(state.items.suspension, state.options.suspension, suspensionState.context.currentStep)
    setListItemOptions(state.items.tireCompoundCategory, state.options.tireCompoundCategory, tireCompoundCategoryState.context.currentStep)
    setListItemOptions(state.items.tireCompoundQuality, state.options.tireCompoundQuality, tireCompoundQualityState.context.currentStep)
    setListItemOptions(state.items.brakes, state.options.brakes, brakesState.context.currentStep)
    setListItemOptions(state.items.nitrous, state.options.nitrous, nitrousState.context.currentStep)
    setListItemDescription(state.items.engine, 'engine', getIndexedListOption('engine', state.items.engine:Index()), engineState.context.currentValue)
    setListItemDescription(state.items.transmission, 'transmission', getIndexedListOption('transmission', state.items.transmission:Index()), transmissionState.context.currentValue)
    setListItemDescription(state.items.suspension, 'suspension', getIndexedListOption('suspension', state.items.suspension:Index()), suspensionState.context.currentValue)
    setListItemDescription(state.items.tireCompoundCategory, 'tireCompoundCategory', getIndexedListOption('tireCompoundCategory', state.items.tireCompoundCategory:Index()), tireCompoundCategoryState.context.currentValue)
    setListItemDescription(state.items.tireCompoundQuality, 'tireCompoundQuality', getIndexedListOption('tireCompoundQuality', state.items.tireCompoundQuality:Index()), tireCompoundQualityState.context.currentValue)
    setListItemDescription(state.items.brakes, 'brakes', getIndexedListOption('brakes', state.items.brakes:Index()), brakesState.context.currentValue)
    setListItemDescription(state.items.nitrous, 'nitrous', getIndexedListOption('nitrous', state.items.nitrous:Index()), nitrousState.context.currentValue)

    if state.items.steeringLockMode then
        local steeringModeIndex = getSteeringLockModeIndex(bucket.steeringLockMode)
        local steeringModeDescriptions = LIST_OPTION_DESCRIPTIONS.steeringLockMode or {}
        state.items.steeringLockMode:Index(steeringModeIndex)
        state.items.steeringLockMode:Description(steeringModeDescriptions[steeringModeIndex] or getMenuDescription('steeringLockMode'))
    end

    setAntirollSliderState(bucket.antirollForce)
    setNitrousShotSliderState(bucket.nitrousShotStrength)
    setBrakeBiasSliderState(bucket.brakeBiasFront)
    setGripBiasSliderState(bucket.gripBiasFront or bucket.baseTires[scaleformUI.tireBiasFrontField] or 0.5)
    setAntirollBiasSliderState(bucket.antirollBiasFront)
    local currentSuspensionRaise = PerformanceTuning.HandlingManager.readHandlingValue(engineState.vehicle, 'float', 'fSuspensionRaise')
    if currentSuspensionRaise == nil then
        currentSuspensionRaise = bucket.suspensionRaise
    end
    setSuspensionRaiseSliderState(currentSuspensionRaise)
    setSuspensionBiasSliderState(bucket.suspensionBiasFront)
    updatePiStatisticsPanels(engineState.vehicle)
    restoreMenuSelection(state.menus.main, selectedMenuIndex)
    return true
end

function PerformanceTuning.ScaleformUI.initializeMenu()
    local scaleformUI = PerformanceTuning.ScaleformUI
    local state = getScaleformUIState()
    if state.menuInitialized then
        return true
    end
    if type(UIMenu) ~= 'table' or type(UIMenu.New) ~= 'function' then
        return false
    end

    state.sliderValues.antirollBars = scaleformUI.buildNormalizedSliderValues(scaleformUI.sliderRanges.antirollBars)
    state.sliderValues.brakeBiasFront = scaleformUI.buildNormalizedSliderValues(scaleformUI.sliderRanges.brakeBiasFront)
    state.sliderValues.gripBiasFront = scaleformUI.buildNormalizedSliderValues(scaleformUI.sliderRanges.gripBiasFront)
    state.sliderValues.antirollBiasFront = scaleformUI.buildNormalizedSliderValues(scaleformUI.sliderRanges.antirollBiasFront)
    state.sliderValues.suspensionRaise = scaleformUI.buildNormalizedSliderValues(scaleformUI.sliderRanges.suspensionRaise)
    state.sliderValues.suspensionBiasFront = scaleformUI.buildNormalizedSliderValues(scaleformUI.sliderRanges.suspensionBiasFront)
    state.sliderValues.nitrousShotStrength = scaleformUI.buildNitroShotSliderValues()

    state.menus.main = UIMenu.New('Performance Tuning', '~b~CURRENT CAR', 20, 20, true)
    state.menus.main:MenuAlignment(MenuAlignment.LEFT)
    state.menus.tweaks = UIMenu.New('Performance Tuning', 'Fine adjustments', 20, 20, true)
    state.menus.tweaks:MenuAlignment(MenuAlignment.LEFT)

    state.items.engine = UIMenuListItem.New('Engine', { 'Stock' }, 1)
    state.items.transmission = UIMenuListItem.New('Transmission', { 'Stock' }, 1)
    state.items.suspension = UIMenuListItem.New('Suspension', { 'Stock' }, 1)
    state.items.tireCompoundCategory = UIMenuListItem.New('Compound', { 'Stock', 'Road', 'Rally', 'Offroad' }, 1)
    state.items.tireCompoundQuality = UIMenuListItem.New('Quality', { 'Low-End', 'Mid-End', 'High-End', 'Top-End' }, 2)
    state.items.brakes = UIMenuListItem.New('Brakes', { 'Stock' }, 1)
    state.items.nitrous = UIMenuListItem.New('Nitrous', { 'Stock' }, 1)
    state.items.antirollSlider = UIMenuSliderItem.New('Anti-Roll Bars', #state.sliderValues.antirollBars - 1, 1, scaleformUI.getAntirollSliderIndex(0.0) - 1, false)
    state.items.openTweaks = UIMenuItem.New('Tweaks', getMenuDescription('tweaks'))

    state.items.nitrousShotSlider = UIMenuSliderItem.New('Shot Strength', #state.sliderValues.nitrousShotStrength - 1, 1, scaleformUI.getNitroShotSliderIndex(1.0) - 1, false)
    state.items.steeringLockMode = UIMenuListItem.New('Steering Lock Mode', { 'Stock', 'Balanced', 'Aggro', 'Very Aggro', 'Very Smooth', 'Smooth' }, 1)
    state.items.brakeBiasSlider = UIMenuSliderItem.New('Brake Bias Front', #state.sliderValues.brakeBiasFront - 1, 1, scaleformUI.getBrakeBiasSliderIndex(0.5) - 1, false)
    state.items.gripBiasSlider = UIMenuSliderItem.New('Grip Bias Front', #state.sliderValues.gripBiasFront - 1, 1, scaleformUI.getGripBiasSliderIndex(0.5) - 1, false)
    state.items.antirollBiasSlider = UIMenuSliderItem.New('Anti-Roll Bias Front', #state.sliderValues.antirollBiasFront - 1, 1, scaleformUI.getAntirollBiasSliderIndex(0.5) - 1, false)
    state.items.suspensionRaiseSlider = UIMenuSliderItem.New('Clearance', 8, 1, 4, false)
    state.items.suspensionBiasSlider = UIMenuSliderItem.New('Suspension Bias Front', #state.sliderValues.suspensionBiasFront - 1, 1, scaleformUI.getSuspensionBiasSliderIndex(0.5) - 1, false)

    state.menus.main:AddItem(state.items.engine)
    state.menus.main:AddItem(state.items.transmission)
    state.menus.main:AddItem(state.items.suspension)
    state.menus.main:AddItem(state.items.tireCompoundCategory)
    state.menus.main:AddItem(state.items.tireCompoundQuality)
    state.menus.main:AddItem(state.items.brakes)
    state.menus.main:AddItem(state.items.antirollSlider)
    state.menus.main:AddItem(state.items.nitrous)
    state.menus.main:AddItem(state.items.openTweaks)

    state.menus.tweaks:AddItem(state.items.nitrousShotSlider)
    state.menus.tweaks:AddItem(state.items.steeringLockMode)
    state.menus.tweaks:AddItem(state.items.brakeBiasSlider)
    state.menus.tweaks:AddItem(state.items.gripBiasSlider)
    state.menus.tweaks:AddItem(state.items.antirollBiasSlider)
    state.menus.tweaks:AddItem(state.items.suspensionRaiseSlider)
    state.menus.tweaks:AddItem(state.items.suspensionBiasSlider)

    attachPiStatisticsPanel(state.items.engine)
    attachPiStatisticsPanel(state.items.transmission)
    attachPiStatisticsPanel(state.items.suspension)
    attachPiStatisticsPanel(state.items.tireCompoundCategory)
    attachPiStatisticsPanel(state.items.tireCompoundQuality)
    attachPiStatisticsPanel(state.items.brakes)
    attachPiStatisticsPanel(state.items.antirollSlider)
    attachPiStatisticsPanel(state.items.nitrous)
    attachPiStatisticsPanel(state.items.openTweaks)
    attachPiStatisticsPanel(state.items.nitrousShotSlider)
    attachPiStatisticsPanel(state.items.steeringLockMode)
    attachPiStatisticsPanel(state.items.brakeBiasSlider)
    attachPiStatisticsPanel(state.items.gripBiasSlider)
    attachPiStatisticsPanel(state.items.antirollBiasSlider)
    attachPiStatisticsPanel(state.items.suspensionRaiseSlider)
    attachPiStatisticsPanel(state.items.suspensionBiasSlider)

    state.items.openTweaks.Activated = function(menu)
        state.switchingToTweaks = true
        menu:SwitchTo(state.menus.tweaks, 1, true)
    end

    state.menus.main.OnMenuClose = function()
        if state.switchingToTweaks then
            state.switchingToTweaks = false
            return
        end

        local vehicle = scaleformUI.getCurrentVehicle()
        if vehicle and PerformanceTuning._internals.requestDragRebalance then
            PerformanceTuning._internals.requestDragRebalance(vehicle, 10000)
        end
        state.menuOpen = false
        state.lastVehicleValidity = nil
        scaleformUI.resetPerformanceIndexDisplayState()
        TriggerEvent('performancetuning:menuClosed')
    end

    state.menus.main.OnListChange = function(_, item, index)
        local contexts = {
            [state.items.engine] = 'engine',
            [state.items.transmission] = 'transmission',
            [state.items.suspension] = 'suspension',
            [state.items.tireCompoundCategory] = 'tireCompoundCategory',
            [state.items.tireCompoundQuality] = 'tireCompoundQuality',
            [state.items.brakes] = 'brakes',
            [state.items.nitrous] = 'nitrous',
        }
        local context = contexts[item]
        if context then
            handleMainMenuSelection(context, index)
        end
    end

    state.menus.main.OnSliderChange = function(_, item, index)
        if item == state.items.antirollSlider then
            handleMainSliderChange(index)
        end
    end

    state.menus.tweaks.OnListChange = function(_, item, index)
        if item == state.items.steeringLockMode then
            handleSteeringLockModeSelection(index)
        end
    end

    state.menus.tweaks.OnSliderChange = function(_, item, index)
        handleTweakSliderChange(item, index)
    end

    state.menuInitialized = true
    return true
end

function PerformanceTuning.ScaleformUI.openMainMenu()
    local scaleformUI = PerformanceTuning.ScaleformUI
    local state = getScaleformUIState()
    if not scaleformUI.initializeMenu() then
        scaleformUI.notify('ScaleformUI is not available.')
        return false
    end
    scaleformUI.applyCurrentVehicleStateBagTuningForMenu()
    local ok, errorMessage = scaleformUI.refreshMenu()
    if not ok then
        if errorMessage then
            scaleformUI.notify(errorMessage)
        end
        return false
    end
    state.menuOpen = true
    state.menus.main:Visible(true)
    return true
end

function PerformanceTuning.ScaleformUI.processFrame()
    local scaleformUI = PerformanceTuning.ScaleformUI
    local state = getScaleformUIState()
    local mainVisible = state.menus.main and state.menus.main:Visible() or false
    local tweaksVisible = state.menus.tweaks and state.menus.tweaks:Visible() or false
    state.menuOpen = mainVisible or tweaksVisible

    if not state.menuOpen then
        return false
    end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    local hasValidVehicle = PerformanceTuning.VehicleManager.isPedDrivingVehicle(ped, vehicle)
    if state.lastVehicleValidity ~= hasValidVehicle then
        state.lastVehicleValidity = hasValidVehicle
        scaleformUI.refreshMenu()
    end

    if hasValidVehicle then
        -- Custom left PI panel disabled for now; keep draw code available for later iteration.
        -- scaleformUI.drawPerformanceIndexPanel(vehicle)
    else
        -- Custom left PI panel disabled for now; keep draw code available for later iteration.
        -- scaleformUI.drawPerformanceIndexPanel(nil, { drawNearbyOnly = true })
    end
    return true
end
