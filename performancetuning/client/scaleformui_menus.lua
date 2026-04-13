-- Builds and runs the full ScaleformUI tuning menu hierarchy.
PerformanceTuning = PerformanceTuning or {}
PerformanceTuning.ScaleformUI = PerformanceTuning.ScaleformUI or {}
local DEFAULT_MENU_DESCRIPTION = 'Description pending.'
local MENU_DESCRIPTIONS = {
    power = 'Engine power and top speed.',

    tires = 'Tire compound and grip tuning.',
    brakes = 'Stopping force and brake balance.',
    handbrakes = 'Handbrake force tuning.',
    suspension = 'Body control, ride height and weight transfer.',
    antiRoll = 'Roll stiffness and front-to-rear distribution.',
    nitro = 'On-demand power boost.',
    piPanelDisplayMode = DEFAULT_MENU_DESCRIPTION,
    engine = 'Engine power and top speed.',
    transmission = DEFAULT_MENU_DESCRIPTION,
    tireCompoundCategory = 'Tire compound family.',
    tireCompoundQuality = 'Tire quality tier.',
    nitrous = DEFAULT_MENU_DESCRIPTION,
    antirollBars = 'Roll stiffness.',
    nitrousShotStrength = 'Higher throughput at the cost of on-time.',
    brakeBiasFront = 'Front-to-rear brake balance.',
    gripBiasFront = 'Front-to-rear grip balance.',
    antirollBiasFront = 'Front-to-rear roll stiffness.',
    suspensionRaise = 'Ride height gap.',
    suspensionBiasFront = 'Front-to-rear suspension balance.',
    steeringLockMode = "Alters the underlying logic so your steering is more or less aggressive.",
    cgOffset = 'Vertical center of gravity offset relative to stock.',
}
local LIST_OPTION_DESCRIPTIONS = {
    tireCompoundCategory = {
        [1] = 'Factory. Quality has no effect.',
        [2] = "Tarmac focused, don't go off the road.",
        [3] = 'Compromise between tarmac grip and offroad grip loss.',
        [4] = 'Least griploss offroad, not much grip on tarmac.',
    },
}
local LIST_OPTION_DESCRIPTIONS_BY_ID = {
    tireCompoundCategory = {
        stock = 'Factory. Quality has no effect.',
        road = "Tarmac focused, don't go off the road.",
        rally = 'Compromise between tarmac grip and offroad grip loss.',
        offroad = 'Least griploss offroad, not much grip on tarmac.',
    },
}

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
    return MENU_DESCRIPTIONS[key] or DEFAULT_MENU_DESCRIPTION
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

local function getScaleformUIState()
    local scaleformUI = PerformanceTuning.ScaleformUI
    scaleformUI.state = scaleformUI.state or {}
    scaleformUI.state.menus = scaleformUI.state.menus or {}
    scaleformUI.state.items = scaleformUI.state.items or {}
    scaleformUI.state.options = scaleformUI.state.options or {}
    scaleformUI.state.sliderValues = scaleformUI.state.sliderValues or {}
    scaleformUI.state.dynamicSliderProfiles = scaleformUI.state.dynamicSliderProfiles or {}
    scaleformUI.state.piDisplayModeIndex = math.max(1, math.min(2, math.floor(tonumber(scaleformUI.state.piDisplayModeIndex) or 1)))
    scaleformUI.state.piPanelDisplayModeIndex = math.max(1, math.min(2, math.floor(tonumber(scaleformUI.state.piPanelDisplayModeIndex) or 2)))
    if scaleformUI.state.performanceBarsDisplayMode == nil then
        local runtimeModel = (((PerformanceTuning or {}).RuntimeConfig or {}).performanceModel or ((PerformanceTuning or {}).RuntimeConfig or {}).performanceBars or {})
        local runtimeMode = normalizePerformanceBarsDisplayMode((runtimeModel or {}).displayMode)
        scaleformUI.state.performanceBarsDisplayMode = runtimeMode or 'absolute_benchmark'
    else
        scaleformUI.state.performanceBarsDisplayMode = normalizePerformanceBarsDisplayMode(scaleformUI.state.performanceBarsDisplayMode) or 'absolute_benchmark'
    end
    scaleformUI.state.menuOpen = scaleformUI.state.menuOpen == true
    scaleformUI.state.menuInitialized = scaleformUI.state.menuInitialized == true
    scaleformUI.state.switchingToPower = scaleformUI.state.switchingToPower == true

    scaleformUI.state.switchingToTires = scaleformUI.state.switchingToTires == true
    scaleformUI.state.switchingToBrakes = scaleformUI.state.switchingToBrakes == true
    scaleformUI.state.switchingToSuspension = scaleformUI.state.switchingToSuspension == true
    scaleformUI.state.switchingToAntiRoll = scaleformUI.state.switchingToAntiRoll == true
    scaleformUI.state.switchingToNitro = scaleformUI.state.switchingToNitro == true
    return scaleformUI.state
end

local function getListOptionDescription(listKey, option, currentValue)
    local label = type(option) == 'table' and option.label or nil
    local description = type(option) == 'table' and option.description or nil
    local fallbackDescriptions = LIST_OPTION_DESCRIPTIONS[listKey]
    local fallbackDescriptionsById = LIST_OPTION_DESCRIPTIONS_BY_ID[listKey]
    local unavailableSuffix = type(option) == 'table' and option.enabled == false and ' Unavailable on this vehicle.' or ''

    if type(label) ~= 'string' or label == '' then
        return tostring(currentValue or '')
    end
    if (type(description) ~= 'string' or description == '') and type(fallbackDescriptionsById) == 'table' then
        local optionId = tostring(type(option) == 'table' and option.id or ''):lower()
        local fallbackDescription = fallbackDescriptionsById[optionId]
        if type(fallbackDescription) == 'string' and fallbackDescription ~= '' then
            description = fallbackDescription
        end
    end

    if (type(description) ~= 'string' or description == '') and type(fallbackDescriptions) == 'table' then
        local optionIndex = type(option) == 'table' and tonumber(option.index) or nil
        local fallbackDescription = optionIndex and fallbackDescriptions[optionIndex] or nil
        if type(fallbackDescription) == 'string' and fallbackDescription ~= '' then
            description = fallbackDescription
        end
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
        handbrakes = state.items.handbrakes,
        nitrous = state.items.nitrous,
    })[context]
end

local function setListItemDescription(listItem, listKey, option, currentValue)
    if listItem and type(listItem.Description) == 'function' then
        listItem:Description(getListOptionDescription(listKey, option, currentValue))
    end
end

local function shouldUseDynamicListDescription(context)
    return context == 'tireCompoundCategory' or context == 'tireCompoundQuality'
end

local function applyDefaultListItemDescriptions()
    local state = getScaleformUIState()
    local listItems = {
        { item = state.items.piPanelDisplayMode, key = 'piPanelDisplayMode' },
        { item = state.items.engine, key = 'engine' },
        { item = state.items.transmission, key = 'transmission' },
        { item = state.items.suspension, key = 'suspension' },
        { item = state.items.tireCompoundCategory, key = 'tireCompoundCategory' },
        { item = state.items.tireCompoundQuality, key = 'tireCompoundQuality' },
        { item = state.items.brakes, key = 'brakes' },
        { item = state.items.handbrakes, key = 'handbrakes' },
        { item = state.items.nitrous, key = 'nitrous' },
        { item = state.items.steeringLockMode, key = 'steeringLockMode' },
    }

    for _, listItem in ipairs(listItems) do
        if listItem.item and type(listItem.item.Description) == 'function' then
            listItem.item:Description(getMenuDescription(listItem.key))
        end
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

local function setTireCompoundQualityAvailability(bucket)
    local state = getScaleformUIState()
    local qualityItem = state.items.tireCompoundQuality
    if qualityItem == nil then
        return
    end

    local category = tostring(type(bucket) == 'table' and bucket.tireCompoundCategory or 'stock'):lower()
    local qualityEnabled = category ~= 'stock'
    if type(qualityItem.Enabled) == 'function' then
        qualityItem:Enabled(qualityEnabled)
    end
    if not qualityEnabled and type(qualityItem.Description) == 'function' then
        qualityItem:Description('Disabled while Compound is Stock.')
    end
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
        'openPower', 'openTires', 'openBrakes', 'openSuspension', 'openAntiRoll', 'openNitro', 'piPanelDisplayMode',
        'engine', 'transmission', 'tireCompoundCategory', 'tireCompoundQuality', 'brakes', 'handbrakes', 'suspension',
        'nitrous', 'nitrousShotSlider', 'steeringLockMode',
        'brakeBiasSlider', 'gripBiasSlider', 'antirollSlider', 'antirollBiasSlider', 'suspensionRaiseSlider', 'suspensionBiasSlider', 'cgOffsetSlider',
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

local function setBrakeBiasSliderState(value)
    local scaleformUI = PerformanceTuning.ScaleformUI
    local item = getScaleformUIState().items.brakeBiasSlider
    if item == nil then
        return
    end
     local resolvedValue = scaleformUI.clampBrakeBiasFrontValue(value)
     item:Description(('Bias %.1f/%.1f'):format(resolvedValue * 100, (1.0 - resolvedValue) * 100))
    item:Index(scaleformUI.getBrakeBiasSliderIndex(resolvedValue) - 1)
end

local function setGripBiasSliderState(value)
    local scaleformUI = PerformanceTuning.ScaleformUI
    local item = getScaleformUIState().items.gripBiasSlider
    if item == nil then
        return
    end
     local resolvedValue = scaleformUI.clampGripBiasFrontValue(value)
     item:Description(('Bias %.1f/%.1f'):format(resolvedValue * 100, (1.0 - resolvedValue) * 100))
    item:Index(scaleformUI.getGripBiasSliderIndex(resolvedValue) - 1)
end

local function setAntirollBiasSliderState(value)
    local scaleformUI = PerformanceTuning.ScaleformUI
    local item = getScaleformUIState().items.antirollBiasSlider
    if item == nil then
        return
    end
     local resolvedValue = scaleformUI.clampAntirollBiasFrontValue(value)
     item:Description(('Bias %.1f/%.1f'):format(resolvedValue * 100, (1.0 - resolvedValue) * 100))
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
     item:Description(('Bias %.1f/%.1f'):format(resolvedValue * 100, (1.0 - resolvedValue) * 100))
    item:Index(scaleformUI.getSuspensionBiasSliderIndex(resolvedValue) - 1)
end

local function setCgOffsetSliderState(value)
    local scaleformUI = PerformanceTuning.ScaleformUI
    local item = getScaleformUIState().items.cgOffsetSlider
    if item == nil then
        return
    end
    local resolvedValue = scaleformUI.clampCgOffsetValue(value)
    item:Description(('Current: %s'):format(scaleformUI.getCgOffsetLabel(resolvedValue)))
    item:Index(scaleformUI.getCgOffsetSliderIndex(resolvedValue) - 1)
end

-- None=stock, Balanced=1.0, Aggressive=1.2, Very Aggressive=1.4, Soft=0.8, Very Soft=0.6
local STEERING_LOCK_MODE_INDEX_TO_ID = { 'stock', '1.0', '1.1', '1.2', '0.8', '0.9' }
local STEERING_LOCK_MODE_ID_TO_INDEX = { stock=1, ['1.0']=2, ['1.1']=3, ['1.2']=4, ['0.8']=5, ['0.9']=6 }

local function getSteeringLockModeIdFromIndex(index)
    local idx = math.max(1, math.min(#STEERING_LOCK_MODE_INDEX_TO_ID, math.floor(tonumber(index) or 1)))
    return STEERING_LOCK_MODE_INDEX_TO_ID[idx] or 'stock'
end

local function isAnyNativeMenuOpen()
    local menuHandler = rawget(_G, 'MenuHandler')
    if type(menuHandler) ~= 'table' then
        return false
    end

    if type(menuHandler.IsAnyMenuOpen) == 'function' and menuHandler:IsAnyMenuOpen() == true then
        return true
    end

    local currentMenu = menuHandler.CurrentMenu
    if currentMenu ~= nil then
        if type(currentMenu.Visible) == 'function' then
            return currentMenu:Visible() == true
        end
        return true
    end

    return false
end

local function getSteeringLockModeIndex(modeId)
    return STEERING_LOCK_MODE_ID_TO_INDEX[tostring(modeId or 'stock'):lower()] or 1
end

local function buildSteeringLockModeLabels()
    return { 'None', 'Balanced', 'Aggressive', 'Very Aggressive', 'Very Soft', 'Soft' }
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
    if item and shouldUseDynamicListDescription(context) then
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
        if shouldUseDynamicListDescription(context) then
            setListItemDescription(item, context, getIndexedListOption(context, item:Index()), currentValue)
        end
    end
end

local function handleMainMenuSelection(context, index)
    previewMainMenuSelection(context, index)
    PerformanceTuning.ScaleformUI.applyMenuSelection(context, index)
    updateMainMenuListContext(context)
    if context == 'tireCompoundCategory' then
        updateMainMenuListContext('tireCompoundQuality')
        local scaleformUI = PerformanceTuning.ScaleformUI
        local vehicle = scaleformUI.getCurrentVehicle()
        if vehicle then
            setTireCompoundQualityAvailability(scaleformUI.ensureTuningState(vehicle))
        end
    end
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
end

function PerformanceTuning.ScaleformUI.closeMenu()
    local scaleformUI = PerformanceTuning.ScaleformUI
    local state = getScaleformUIState()
    state.menuOpen = false
    state.lastVehicleValidity = nil
    scaleformUI.resetPerformanceIndexDisplayState()
    local submenusToHide = { state.menus.power, state.menus.tires, state.menus.brakes, state.menus.suspension, state.menus.antiRoll, state.menus.nitro }
    for _, submenu in ipairs(submenusToHide) do
        if submenu then submenu:Visible(false) end
    end
    if state.menus.main then
        state.menus.main:Visible(false)
    end
end

function PerformanceTuning.ScaleformUI.getPiDisplayModeIndex()
    local state = getScaleformUIState()
    return math.max(1, math.min(2, math.floor(tonumber(state.piDisplayModeIndex) or 1)))
end

function PerformanceTuning.ScaleformUI.setPiDisplayModeIndex(index)
    local state = getScaleformUIState()
    state.piDisplayModeIndex = math.max(1, math.min(2, math.floor(tonumber(index) or 1)))
    -- Keep bar scaling mode in sync with "Compare with Nearby" mode.
    -- 1 = personal view (relative bars), 2 = compare with nearby (absolute bars).
    if state.piDisplayModeIndex == 2 then
        state.performanceBarsDisplayMode = 'absolute_benchmark'
    else
        state.performanceBarsDisplayMode = 'vehicle_relative'
    end
    if state.menuInitialized then
        PerformanceTuning.ScaleformUI.refreshMenu()
    end
    return state.piDisplayModeIndex
end

function PerformanceTuning.ScaleformUI.getPerformanceBarsDisplayMode()
    local state = getScaleformUIState()
    if math.floor(tonumber(state.piDisplayModeIndex) or 1) == 2 then
        return 'absolute_benchmark'
    end
    return 'vehicle_relative'
end

function PerformanceTuning.ScaleformUI.setPerformanceBarsDisplayMode(mode)
    local state = getScaleformUIState()
    local normalizedMode = normalizePerformanceBarsDisplayMode(mode) or 'absolute_benchmark'
    -- Bars mode is derived from Compare-with-Nearby mode.
    state.piDisplayModeIndex = (normalizedMode == 'absolute_benchmark') and 2 or 1
    state.performanceBarsDisplayMode = normalizedMode
    if state.menuInitialized then
        PerformanceTuning.ScaleformUI.refreshMenu()
    end
    return state.performanceBarsDisplayMode
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
    applyDefaultListItemDescriptions()
    if state.items.nitrousShotSlider and type(state.items.nitrousShotSlider.Description) == 'function' then
        state.items.nitrousShotSlider:Description('Higher throughput at the cost of on-time')
    end
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
    local handbrakesState = scaleformUI.buildListState('handbrakes')
    local nitrousState = scaleformUI.buildListState('nitrous')
    local bucket = scaleformUI.ensureTuningState(engineState.vehicle)
    refreshSuspensionRaiseSliderRange(engineState.vehicle)

    state.options.engine = engineState.context.options or {}
    state.options.transmission = transmissionState.context.options or {}
    state.options.suspension = suspensionState.context.options or {}
    state.options.tireCompoundCategory = tireCompoundCategoryState.context.options or {}
    state.options.tireCompoundQuality = tireCompoundQualityState.context.options or {}
    state.options.brakes = brakesState.context.options or {}
    state.options.handbrakes = handbrakesState.context.options or {}
    state.options.nitrous = nitrousState.context.options or {}
    do
        local steeringLabels = buildSteeringLockModeLabels()
        local steeringOptions = {}
        for i, label in ipairs(steeringLabels) do
            steeringOptions[i] = { label = label, index = i }
        end
        state.options.steeringLockMode = steeringOptions
    end
    state.menus.main:Subtitle(engineState.displayName)
    local submenus = { state.menus.power, state.menus.tires, state.menus.brakes, state.menus.suspension, state.menus.antiRoll, state.menus.nitro }
    for _, submenu in ipairs(submenus) do
        if submenu then submenu:Subtitle(engineState.displayName) end
    end

    setListItemOptions(state.items.engine, state.options.engine, engineState.context.currentStep)
    setListItemOptions(state.items.transmission, state.options.transmission, transmissionState.context.currentStep)
    setListItemOptions(state.items.suspension, state.options.suspension, suspensionState.context.currentStep)
    setListItemOptions(state.items.tireCompoundCategory, state.options.tireCompoundCategory, tireCompoundCategoryState.context.currentStep)
    setListItemOptions(state.items.tireCompoundQuality, state.options.tireCompoundQuality, tireCompoundQualityState.context.currentStep)
    setListItemOptions(state.items.brakes, state.options.brakes, brakesState.context.currentStep)
    setListItemOptions(state.items.handbrakes, state.options.handbrakes, handbrakesState.context.currentStep)
    setListItemOptions(state.items.nitrous, state.options.nitrous, nitrousState.context.currentStep)
    setListItemDescription(state.items.tireCompoundCategory, 'tireCompoundCategory', getIndexedListOption('tireCompoundCategory', state.items.tireCompoundCategory:Index()), tireCompoundCategoryState.context.currentValue)
    setListItemDescription(state.items.tireCompoundQuality, 'tireCompoundQuality', getIndexedListOption('tireCompoundQuality', state.items.tireCompoundQuality:Index()), tireCompoundQualityState.context.currentValue)
    setTireCompoundQualityAvailability(bucket)

    if state.items.steeringLockMode then
        local steeringModeIndex = getSteeringLockModeIndex(bucket.steeringLockMode)
        state.items.steeringLockMode:Index(steeringModeIndex)
    end

    setAntirollSliderState(bucket.antirollForce)
    state.items.nitrousShotSlider:Index(scaleformUI.getNitroShotSliderIndex(bucket.nitrousShotStrength) - 1)
    setBrakeBiasSliderState(bucket.brakeBiasFront)
    setGripBiasSliderState(bucket.gripBiasFront or bucket.baseTires[scaleformUI.tireBiasFrontField] or 0.5)
    setAntirollBiasSliderState(bucket.antirollBiasFront)
    local currentSuspensionRaise = PerformanceTuning.HandlingManager.readHandlingValue(engineState.vehicle, 'float', 'fSuspensionRaise')
    if currentSuspensionRaise == nil then
        currentSuspensionRaise = bucket.suspensionRaise
    end
    setSuspensionRaiseSliderState(currentSuspensionRaise)
    setSuspensionBiasSliderState(bucket.suspensionBiasFront)
    setCgOffsetSliderState(bucket.cgOffsetTweak or 0.0)
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
    state.sliderValues.cgOffset = scaleformUI.buildNormalizedSliderValues(scaleformUI.sliderRanges.cgOffset)

    state.menus.main = UIMenu.New('Performance Tuning', '~b~CURRENT CAR', 20, 20, true)
    state.menus.main:MenuAlignment(MenuAlignment.LEFT)
    state.menus.main:SetBannerColor(SColor.LightBlue)
    state.menus.power = UIMenu.New('Performance Tuning', 'Power', 20, 20, true)
    state.menus.power:MenuAlignment(MenuAlignment.LEFT)
    state.menus.power:SetBannerColor(SColor.LightBlue)

    state.menus.tires = UIMenu.New('Performance Tuning', 'Tires', 20, 20, true)
    state.menus.tires:MenuAlignment(MenuAlignment.LEFT)
    state.menus.tires:SetBannerColor(SColor.LightBlue)
    state.menus.brakes = UIMenu.New('Performance Tuning', 'Brakes', 20, 20, true)
    state.menus.brakes:MenuAlignment(MenuAlignment.LEFT)
    state.menus.brakes:SetBannerColor(SColor.LightBlue)
    state.menus.suspension = UIMenu.New('Performance Tuning', 'Suspension', 20, 20, true)
    state.menus.suspension:MenuAlignment(MenuAlignment.LEFT)
    state.menus.suspension:SetBannerColor(SColor.LightBlue)
    state.menus.antiRoll = UIMenu.New('Performance Tuning', 'Anti-Roll', 20, 20, true)
    state.menus.antiRoll:MenuAlignment(MenuAlignment.LEFT)
    state.menus.antiRoll:SetBannerColor(SColor.LightBlue)
    state.menus.nitro = UIMenu.New('Performance Tuning', 'Nitro', 20, 20, true)
    state.menus.nitro:MenuAlignment(MenuAlignment.LEFT)
    state.menus.nitro:SetBannerColor(SColor.LightBlue)
    state.items.openPower = UIMenuItem.New('Power', getMenuDescription('power'))

    state.items.openTires = UIMenuItem.New('Tires', getMenuDescription('tires'))
    state.items.openBrakes = UIMenuItem.New('Brakes', getMenuDescription('brakes'))
    state.items.openSuspension = UIMenuItem.New('Suspension', getMenuDescription('suspension'))
    state.items.openAntiRoll = UIMenuItem.New('Anti-Roll', getMenuDescription('antiRoll'))
    state.items.openNitro = UIMenuItem.New('Nitro', getMenuDescription('nitro'))
    state.items.piPanelDisplayMode = UIMenuListItem.New('PI panel displays:', { 'PI', 'Raw numbers' }, state.piPanelDisplayModeIndex, getMenuDescription('piPanelDisplayMode'))
    state.items.engine = UIMenuListItem.New('Engine', { 'Stock' }, 1, getMenuDescription('engine'))
    state.items.transmission = UIMenuListItem.New('Transmission', { 'Stock' }, 1, getMenuDescription('transmission'))
    state.items.suspension = UIMenuListItem.New('Suspension', { 'Stock' }, 1, getMenuDescription('suspension'))
    state.items.tireCompoundCategory = UIMenuListItem.New('Compound', { 'Stock', 'Road', 'Mixed', 'Offroad' }, 1, getMenuDescription('tireCompoundCategory'))
    state.items.tireCompoundQuality = UIMenuListItem.New('Quality', { 'Low-End', 'Mid-End', 'High-End', 'Top-End' }, 2, getMenuDescription('tireCompoundQuality'))
    state.items.brakes = UIMenuListItem.New('Brakes', { 'Stock' }, 1, getMenuDescription('brakes'))
    state.items.handbrakes = UIMenuListItem.New('Handbrakes', { 'Stock' }, 1, getMenuDescription('handbrakes'))
    state.items.nitrous = UIMenuListItem.New('Nitrous', { 'Stock' }, 1, getMenuDescription('nitrous'))
    state.items.antirollSlider = UIMenuSliderItem.New('Anti-Roll Bars', #state.sliderValues.antirollBars - 1, 1, scaleformUI.getAntirollSliderIndex(0.0) - 1, false)
    state.items.nitrousShotSlider = UIMenuSliderItem.New('Shot Strength', #state.sliderValues.nitrousShotStrength - 1, 1, scaleformUI.getNitroShotSliderIndex(1.0) - 1, false)
    state.items.nitrousShotSlider:Description('Higher throughput at the cost of on-time')
    state.items.steeringLockMode = UIMenuListItem.New('Steering Balance', buildSteeringLockModeLabels(), 1, getMenuDescription('steeringLockMode'))
    state.items.brakeBiasSlider = UIMenuSliderItem.New('Brake Bias Front', #state.sliderValues.brakeBiasFront - 1, 1, scaleformUI.getBrakeBiasSliderIndex(0.5) - 1, false)
    state.items.gripBiasSlider = UIMenuSliderItem.New('Grip Bias Front', #state.sliderValues.gripBiasFront - 1, 1, scaleformUI.getGripBiasSliderIndex(0.5) - 1, false)
    state.items.antirollBiasSlider = UIMenuSliderItem.New('Anti-Roll Bias Front', #state.sliderValues.antirollBiasFront - 1, 1, scaleformUI.getAntirollBiasSliderIndex(0.5) - 1, false)
    state.items.suspensionRaiseSlider = UIMenuSliderItem.New('Clearance', 8, 1, 4, false)
    state.items.suspensionBiasSlider = UIMenuSliderItem.New('Suspension Bias Front', #state.sliderValues.suspensionBiasFront - 1, 1, scaleformUI.getSuspensionBiasSliderIndex(0.5) - 1, false)
    state.items.cgOffsetSlider = UIMenuSliderItem.New('CG Offset', #state.sliderValues.cgOffset - 1, 1, scaleformUI.getCgOffsetSliderIndex(0.0) - 1, false)

    state.menus.main:AddItem(state.items.openPower)
    state.menus.main:AddItem(state.items.openTires)
    state.menus.main:AddItem(state.items.openBrakes)
    state.menus.main:AddItem(state.items.openSuspension)
    state.menus.main:AddItem(state.items.openAntiRoll)
    state.menus.main:AddItem(state.items.openNitro)
    state.menus.main:AddItem(state.items.piPanelDisplayMode)

    state.menus.power:AddItem(state.items.engine)
    state.menus.power:AddItem(state.items.transmission)

    state.menus.tires:AddItem(state.items.tireCompoundCategory)
    state.menus.tires:AddItem(state.items.tireCompoundQuality)
    state.menus.tires:AddItem(state.items.gripBiasSlider)

    state.menus.brakes:AddItem(state.items.brakes)
    state.menus.brakes:AddItem(state.items.handbrakes)
    state.menus.brakes:AddItem(state.items.brakeBiasSlider)

    state.menus.suspension:AddItem(state.items.steeringLockMode)
    state.menus.suspension:AddItem(state.items.suspension)
    state.menus.suspension:AddItem(state.items.suspensionRaiseSlider)
    state.menus.suspension:AddItem(state.items.suspensionBiasSlider)
    state.menus.suspension:AddItem(state.items.cgOffsetSlider)

    state.menus.antiRoll:AddItem(state.items.antirollSlider)
    state.menus.antiRoll:AddItem(state.items.antirollBiasSlider)

    state.menus.nitro:AddItem(state.items.nitrous)
    state.menus.nitro:AddItem(state.items.nitrousShotSlider)

    state.items.openPower.Activated = function(menu)
        state.switchingToPower = true
        menu:SwitchTo(state.menus.power, 1, true)
    end

    state.items.openTires.Activated = function(menu)
        state.switchingToTires = true
        menu:SwitchTo(state.menus.tires, 1, true)
    end
    state.items.openBrakes.Activated = function(menu)
        state.switchingToBrakes = true
        menu:SwitchTo(state.menus.brakes, 1, true)
    end
    state.items.openSuspension.Activated = function(menu)
        state.switchingToSuspension = true
        menu:SwitchTo(state.menus.suspension, 1, true)
    end
    state.items.openAntiRoll.Activated = function(menu)
        state.switchingToAntiRoll = true
        menu:SwitchTo(state.menus.antiRoll, 1, true)
    end
    state.items.openNitro.Activated = function(menu)
        state.switchingToNitro = true
        menu:SwitchTo(state.menus.nitro, 1, true)
    end

    state.menus.main.OnMenuClose = function()
        if state.switchingToPower then
            state.switchingToPower = false
            return
        end

        if state.switchingToTires then
            state.switchingToTires = false
            return
        end
        if state.switchingToBrakes then
            state.switchingToBrakes = false
            return
        end
        if state.switchingToSuspension then
            state.switchingToSuspension = false
            return
        end
        if state.switchingToAntiRoll then
            state.switchingToAntiRoll = false
            return
        end
        if state.switchingToNitro then
            state.switchingToNitro = false
            return
        end
        local vehicle = scaleformUI.getCurrentVehicle()
        if vehicle and PerformanceTuning._internals.requestDragRebalance then
            PerformanceTuning._internals.requestDragRebalance(vehicle)
        end
        state.menuOpen = false
        state.lastVehicleValidity = nil
        scaleformUI.resetPerformanceIndexDisplayState()
        TriggerEvent('performancetuning:menuClosed')
    end

    state.menus.main.OnListChange = function(_, item, index)
        if item == state.items.piPanelDisplayMode then
            state.piPanelDisplayModeIndex = math.max(1, math.min(2, math.floor(tonumber(index) or 1)))
            state.items.piPanelDisplayMode:Index(state.piPanelDisplayModeIndex)
        end
    end

    state.menus.power.OnListChange = function(_, item, index)
        if item == state.items.engine then
            handleMainMenuSelection('engine', index)
        elseif item == state.items.transmission then
            handleMainMenuSelection('transmission', index)
        end
    end


    state.menus.tires.OnListChange = function(_, item, index)
        local contexts = {
            [state.items.tireCompoundCategory] = 'tireCompoundCategory',
            [state.items.tireCompoundQuality] = 'tireCompoundQuality',
        }
        local context = contexts[item]
        if context then
            handleMainMenuSelection(context, index)
        end
    end

    state.menus.tires.OnSliderChange = function(_, item, index)
        if item == state.items.gripBiasSlider then
            handleTweakSliderChange(item, index)
        end
    end

    state.menus.brakes.OnListChange = function(_, item, index)
        if item == state.items.brakes then
            handleMainMenuSelection('brakes', index)
        elseif item == state.items.handbrakes then
            handleMainMenuSelection('handbrakes', index)
        end
    end

    state.menus.brakes.OnSliderChange = function(_, item, index)
        if item == state.items.brakeBiasSlider then
            handleTweakSliderChange(item, index)
        end
    end

    state.menus.suspension.OnListChange = function(_, item, index)
        if item == state.items.suspension then
            handleMainMenuSelection('suspension', index)
            return
        end
        if item == state.items.steeringLockMode then
            handleSteeringLockModeSelection(index)
        end
    end

    state.menus.suspension.OnSliderChange = function(_, item, index)
        if item == state.items.suspensionRaiseSlider or item == state.items.suspensionBiasSlider then
            handleTweakSliderChange(item, index)
        elseif item == state.items.cgOffsetSlider then
            local vehicle = scaleformUI.getCurrentVehicle()
            if not vehicle then return end
            local value = scaleformUI.getSliderValueForIndex(index + 1, scaleformUI.sliderRanges.cgOffset)
            setCgOffsetSliderState(value)
            scaleformUI.applyCgOffsetTweak(vehicle, value)
        end
    end

    state.menus.antiRoll.OnSliderChange = function(_, item, index)
        if item == state.items.antirollSlider then
            handleMainSliderChange(index)
        elseif item == state.items.antirollBiasSlider then
            handleTweakSliderChange(item, index)
        end
    end

    state.menus.nitro.OnListChange = function(_, item, index)
        if item == state.items.nitrous then
            handleMainMenuSelection('nitrous', index)
        end
    end

    state.menus.nitro.OnSliderChange = function(_, item, index)
        if item == state.items.nitrousShotSlider then
            handleTweakSliderChange(item, index)
        end
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


RegisterCommand('+ptmenu', function()
    PerformanceTuning.ScaleformUI.openMainMenu()
end, false)
local ptmenuDefaultKey = GetResourceState('vehiclemanager') == 'started' and '' or 'F5'
if ptmenuDefaultKey == '' then
    print('[performancetuning] Vehicle Manager found, +ptmenu will not be bound to a key.')
else
    print('[performancetuning] Vehicle Manager not found, binding +ptmenu to F5 by default.')
end
RegisterKeyMapping('+ptmenu', 'Open Performance Tuning menu', 'keyboard', ptmenuDefaultKey)

function PerformanceTuning.ScaleformUI.processFrame()
    local scaleformUI = PerformanceTuning.ScaleformUI
    local state = getScaleformUIState()
    local mainVisible = state.menus.main and state.menus.main:Visible() or false
    local anySubmenuVisible = (state.menus.power and state.menus.power:Visible())

        or (state.menus.tires and state.menus.tires:Visible())
        or (state.menus.brakes and state.menus.brakes:Visible())
        or (state.menus.suspension and state.menus.suspension:Visible())
        or (state.menus.antiRoll and state.menus.antiRoll:Visible())
        or (state.menus.nitro and state.menus.nitro:Visible())
        or false
    local managerMenuOpen = mainVisible or anySubmenuVisible
    local anyNativeMenuVisible = isAnyNativeMenuOpen()
    state.managerMenuOpen = managerMenuOpen
    state.menuOpen = managerMenuOpen or anyNativeMenuVisible

    if not state.menuOpen then
        return false
    end

    local ped = PlayerPedId()
    local pedVehicle = GetVehiclePedIsIn(ped, false)
    local hasValidDrivingVehicle = PerformanceTuning.VehicleManager.isPedDrivingVehicle(ped, pedVehicle)
    if state.lastVehicleValidity ~= hasValidDrivingVehicle then
        state.lastVehicleValidity = hasValidDrivingVehicle
        scaleformUI.refreshMenu()
    end

    return true
end
