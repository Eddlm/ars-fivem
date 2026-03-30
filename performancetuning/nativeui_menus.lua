-- Builds and runs the full NativeUI tuning menu hierarchy and keybind entrypoint.
PerformanceTuning = PerformanceTuning or {}
PerformanceTuning.NativeUI = PerformanceTuning.NativeUI or {}

local function getNativeUIState()
    local nativeUI = PerformanceTuning.NativeUI
    nativeUI.state = nativeUI.state or {}
    nativeUI.state.menus = nativeUI.state.menus or {}
    nativeUI.state.items = nativeUI.state.items or {}
    nativeUI.state.options = nativeUI.state.options or {}
    nativeUI.state.sliderValues = nativeUI.state.sliderValues or {}
    nativeUI.state.dynamicSliderProfiles = nativeUI.state.dynamicSliderProfiles or {}
    nativeUI.state.piDisplayModeIndex = math.max(1, math.min(3, math.floor(tonumber(nativeUI.state.piDisplayModeIndex) or 1)))
    nativeUI.state.menuOpen = nativeUI.state.menuOpen == true
    nativeUI.state.menuInitialized = nativeUI.state.menuInitialized == true
    return nativeUI.state
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
    local definitions = PerformanceTuning.Definitions or {}
    local uiText = definitions.uiText or {}
    local descriptions = uiText.menuDescriptions or {}
    return descriptions[key] or ''
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

local getSteeringLockModeIdFromIndex
local getSteeringLockModeIndex
local handleSteeringLockModeSelection

local function getIndexedListOption(listKey, index)
    local state = getNativeUIState()
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
    if not listItem then
        return
    end

    listItem:Description(getListOptionDescription(listKey, option, currentValue))
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
    menu:CurrentSelection(clampedGetterIndex - 1)
end

local function updateMainMenuListContext(context)
    local nativeUI = PerformanceTuning.NativeUI
    local state = getNativeUIState()
    local listState = nativeUI.buildListState(context)
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

    if state.menus.main then
        state.menus.main.ReDraw = true
    end
end

local function setAntirollSliderState(value)
    local nativeUI = PerformanceTuning.NativeUI
    local state = getNativeUIState()
    local item = state.items.antirollSlider
    if item == nil then
        return
    end

    local resolvedValue = nativeUI.clampAntirollForceValue(value)
    item:Description(('Current: %s'):format(nativeUI.getAntirollForceLabel(resolvedValue)))
    item:Index(nativeUI.getAntirollSliderIndex(resolvedValue))
    if state.menus.main then
        state.menus.main.ReDraw = true
    end
end

local function setNitrousShotSliderState(value)
    local nativeUI = PerformanceTuning.NativeUI
    local state = getNativeUIState()
    local item = state.items.nitrousShotSlider
    if item == nil then
        return
    end

    local resolvedValue = nativeUI.clampNitroShotStrength(value)
    item:Description(('Current: %s'):format(nativeUI.getNitroShotStrengthLabel(resolvedValue)))
    item:Index(nativeUI.getNitroShotSliderIndex(resolvedValue))
    if state.menus.tweaks and state.menus.tweaks.SubMenu then
        state.menus.tweaks.SubMenu.ReDraw = true
    end
end

local function setBrakeBiasSliderState(value)
    local nativeUI = PerformanceTuning.NativeUI
    local state = getNativeUIState()
    local item = state.items.brakeBiasSlider
    if item == nil then
        return
    end

    local resolvedValue = nativeUI.clampBrakeBiasFrontValue(value)
    item:Description(('Current: %s'):format(nativeUI.getBrakeBiasFrontLabel(resolvedValue)))
    item:Index(nativeUI.getBrakeBiasSliderIndex(resolvedValue))
    if state.menus.tweaks and state.menus.tweaks.SubMenu then
        state.menus.tweaks.SubMenu.ReDraw = true
    end
end

local function setGripBiasSliderState(value)
    local nativeUI = PerformanceTuning.NativeUI
    local state = getNativeUIState()
    local item = state.items.gripBiasSlider
    if item == nil then
        return
    end

    local resolvedValue = nativeUI.clampGripBiasFrontValue(value)
    item:Description(('Current: %s'):format(nativeUI.getGripBiasFrontLabel(resolvedValue)))
    item:Index(nativeUI.getGripBiasSliderIndex(resolvedValue))
    if state.menus.tweaks and state.menus.tweaks.SubMenu then
        state.menus.tweaks.SubMenu.ReDraw = true
    end
end

local function setAntirollBiasSliderState(value)
    local nativeUI = PerformanceTuning.NativeUI
    local state = getNativeUIState()
    local item = state.items.antirollBiasSlider
    if item == nil then
        return
    end

    local resolvedValue = nativeUI.clampAntirollBiasFrontValue(value)
    item:Description(('Current: %s'):format(nativeUI.getAntirollBiasFrontLabel(resolvedValue)))
    item:Index(nativeUI.getAntirollBiasSliderIndex(resolvedValue))
    if state.menus.tweaks and state.menus.tweaks.SubMenu then
        state.menus.tweaks.SubMenu.ReDraw = true
    end
end

local function setSuspensionRaiseSliderState(value)
    local nativeUI = PerformanceTuning.NativeUI
    local state = getNativeUIState()
    local item = state.items.suspensionRaiseSlider
    if item == nil then
        return
    end

    local vehicle = nativeUI.getCurrentVehicle()
    local bucket = vehicle and nativeUI.ensureTuningState(vehicle) or nil
    local baseUpperLimit = bucket and bucket.baseSuspension and tonumber(bucket.baseSuspension.fSuspensionUpperLimit) or 0.0
    local liveUpperLimit = vehicle and PerformanceTuning.HandlingManager.readHandlingValue(vehicle, 'float', 'fSuspensionUpperLimit') or nil
    local displayedUpperLimit = tonumber(liveUpperLimit) or baseUpperLimit
    local profile = state.dynamicSliderProfiles.suspensionRaise or {}
    local resolvedValue = tonumber(value) or 0.0
    item:Description(('Upper: %.4f | Raise: %.4f | Gap: %.4f'):format(displayedUpperLimit, resolvedValue, displayedUpperLimit - resolvedValue))
    item:Index(getNearestSuspensionProfileIndex(profile, resolvedValue))
    if state.menus.tweaks and state.menus.tweaks.SubMenu then
        state.menus.tweaks.SubMenu.ReDraw = true
    end
end

local function refreshSuspensionRaiseSliderRange(vehicle)
    local nativeUI = PerformanceTuning.NativeUI
    local state = getNativeUIState()
    local item = state.items.suspensionRaiseSlider
    if item == nil then
        return
    end

    local bucket = vehicle and nativeUI.ensureTuningState(vehicle) or nil
    local baseUpperLimit = bucket and bucket.baseSuspension and tonumber(bucket.baseSuspension.fSuspensionUpperLimit) or 0.0
    local baseLowerLimit = bucket and bucket.baseSuspension and tonumber(bucket.baseSuspension.fSuspensionLowerLimit) or -0.05
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

    state.dynamicSliderProfiles.suspensionRaise = {
        raiseValues = raiseValues,
        labels = labels,
        baseUpperLimit = baseUpperLimit,
        baseLowerLimit = baseLowerLimit,
        baseRaise = baseRaise,
        leftRaise = leftRaise,
        rightRaise = rightRaise,
    }

    state.sliderValues.suspensionRaise = labels
    item.Items = labels
end

local function setSuspensionBiasSliderState(value)
    local nativeUI = PerformanceTuning.NativeUI
    local state = getNativeUIState()
    local item = state.items.suspensionBiasSlider
    if item == nil then
        return
    end

    local resolvedValue = nativeUI.clampSuspensionBiasFrontValue(value)
    item:Description(('Current: %s'):format(nativeUI.getSuspensionBiasFrontLabel(resolvedValue)))
    item:Index(nativeUI.getSuspensionBiasSliderIndex(resolvedValue))
    if state.menus.tweaks and state.menus.tweaks.SubMenu then
        state.menus.tweaks.SubMenu.ReDraw = true
    end
end

local function setMenuItemsEnabled(enabled, disabledDescription)
    local state = getNativeUIState()
    local resolvedEnabled = enabled == true
    local disabledText = tostring(disabledDescription or 'Enter the driver seat to enable tuning controls.')
    local itemOrder = {
        'engine',
        'transmission',
        'suspension',
        'tireCompoundCategory',
        'tireCompoundQuality',
        'brakes',
        'antirollSlider',
        'nitrous',
        'nitrousShotSlider',
        'revLimiter',
        'steeringLockMode',
        'brakeBiasSlider',
        'gripBiasSlider',
        'antirollBiasSlider',
        'suspensionRaiseSlider',
        'suspensionBiasSlider',
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

    if state.menus.tweaks and state.menus.tweaks.Item and type(state.menus.tweaks.Item.Enabled) == 'function' then
        state.menus.tweaks.Item:Enabled(resolvedEnabled)
    end
end

function PerformanceTuning.NativeUI.closeMenu()
    local nativeUI = PerformanceTuning.NativeUI
    local state = getNativeUIState()
    if not state.menuOpen or not state.menuPool then
        return
    end

    state.menuOpen = false
    state.lastVehicleValidity = nil
    nativeUI.resetPerformanceIndexDisplayState()
    state.menuPool:CloseAllMenus()
end

function PerformanceTuning.NativeUI.refreshMenu()
    local nativeUI = PerformanceTuning.NativeUI
    local state = getNativeUIState()
    if not state.menuInitialized then
        return false
    end

    local selectedMenuIndex = state.menus.main and state.menus.main:CurrentSelection() or 1
    local vehicle, vehicleError = nativeUI.getCurrentVehicle()
    if not vehicle then
        state.menus.main.Title:Text('~r~NO VALID CAR')
        setMenuItemsEnabled(false, vehicleError or 'Enter the driver seat to enable tuning controls.')
        state.menus.main.ReDraw = true
        restoreMenuSelection(state.menus.main, selectedMenuIndex)
        return true
    end

    setMenuItemsEnabled(true)
    local engineState, engineError = nativeUI.buildListState('engine')
    if not engineState then
        state.menus.main.Title:Text('~r~NO VALID CAR')
        setMenuItemsEnabled(false, engineError or 'Enter the driver seat to enable tuning controls.')
        state.menus.main.ReDraw = true
        restoreMenuSelection(state.menus.main, selectedMenuIndex)
        return true
    end

    local transmissionState = nativeUI.buildListState('transmission')
    local suspensionState = nativeUI.buildListState('suspension')
    local tireCompoundCategoryState = nativeUI.buildListState('tireCompoundCategory')
    local tireCompoundQualityState = nativeUI.buildListState('tireCompoundQuality')
    local brakesState = nativeUI.buildListState('brakes')
    local nitrousState = nativeUI.buildListState('nitrous')
    local bucket = nativeUI.ensureTuningState(engineState.vehicle)
    refreshSuspensionRaiseSliderRange(engineState.vehicle)
    state.options.engine = engineState.context.options or {}
    state.options.transmission = transmissionState.context.options or {}
    state.options.suspension = suspensionState.context.options or {}
    state.options.tireCompoundCategory = tireCompoundCategoryState.context.options or {}
    state.options.tireCompoundQuality = tireCompoundQualityState.context.options or {}
    state.options.brakes = brakesState.context.options or {}
    state.options.nitrous = nitrousState.context.options or {}
    state.menus.main.Title:Text(engineState.displayName)

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
    if state.items.revLimiter then
        local revLimiterIndex = bucket.revLimiterEnabled == true and 2 or 1
        local revLimiterDescriptions = (((PerformanceTuning.Definitions or {}).uiText or {}).listOptionDescriptions or {}).revLimiter or {}
        state.items.revLimiter:Index(revLimiterIndex)
        state.items.revLimiter:Description(revLimiterDescriptions[revLimiterIndex] or getMenuDescription('revLimiter'))
    end
    if state.items.steeringLockMode then
        local steeringModeIndex = getSteeringLockModeIndex(bucket.steeringLockMode)
        local steeringModeDescriptions = (((PerformanceTuning.Definitions or {}).uiText or {}).listOptionDescriptions or {}).steeringLockMode or {}
        state.items.steeringLockMode:Index(steeringModeIndex)
        state.items.steeringLockMode:Description(steeringModeDescriptions[steeringModeIndex] or getMenuDescription('steeringLockMode'))
    end
    if state.items.piDisplayMode then
        local piDisplayModeIndex = math.max(1, math.min(3, math.floor(tonumber(state.piDisplayModeIndex) or 1)))
        local piDisplayModeDescriptions = (((PerformanceTuning.Definitions or {}).uiText or {}).listOptionDescriptions or {}).piDisplayMode or {}
        state.items.piDisplayMode:Index(piDisplayModeIndex)
        state.items.piDisplayMode:Description(piDisplayModeDescriptions[piDisplayModeIndex] or getMenuDescription('piDisplayMode'))
    end
    setAntirollSliderState(bucket.antirollForce)
        setNitrousShotSliderState(bucket.nitrousShotStrength)
    setBrakeBiasSliderState(bucket.brakeBiasFront)
    setGripBiasSliderState(bucket.gripBiasFront or bucket.baseTires[nativeUI.tireBiasFrontField] or 0.5)
    setAntirollBiasSliderState(bucket.antirollBiasFront)
    local currentSuspensionRaise = PerformanceTuning.HandlingManager.readHandlingValue(engineState.vehicle, 'float', 'fSuspensionRaise')
    if currentSuspensionRaise == nil then
        currentSuspensionRaise = bucket.suspensionRaise
    end
    setSuspensionRaiseSliderState(currentSuspensionRaise)
    setSuspensionBiasSliderState(bucket.suspensionBiasFront)

    state.menus.main.ReDraw = true
    restoreMenuSelection(state.menus.main, selectedMenuIndex)
    return true
end

local function handleRevLimiterSelection(index)
    local nativeUI = PerformanceTuning.NativeUI
    local vehicle = nativeUI.getCurrentVehicle()
    if not vehicle then
        return
    end

    local bucket = nativeUI.ensureTuningState(vehicle)
    bucket.revLimiterEnabled = index == 2
    nativeUI.syncVehicleTuneState(vehicle)
    nativeUI.refreshMenu()
end

getSteeringLockModeIdFromIndex = function(index)
    if index == 2 then
        return 'balanced'
    end
    if index == 3 then
        return 'aggressive'
    end
    if index == 4 then
        return 'very_aggressive'
    end
    if index == 5 then
        return 'very_smooth'
    end
    if index == 6 then
        return 'smooth'
    end
    return 'stock'
end

getSteeringLockModeIndex = function(modeId)
    local normalized = tostring(modeId or 'stock'):lower()
    if normalized == 'balanced' or normalized == 'balance' then
        return 2
    end
    if normalized == 'aggro' or normalized == 'aggressive' then
        return 3
    end
    if normalized == 'very_aggro' or normalized == 'very_aggressive' or normalized == 'extreme_aggressive' then
        return 4
    end
    if normalized == 'very_smooth' or normalized == 'extreme_smooth' then
        return 5
    end
    if normalized == 'sooth' or normalized == 'smooth' then
        return 6
    end
    return 1
end

handleSteeringLockModeSelection = function(index)
    local nativeUI = PerformanceTuning.NativeUI
    local vehicle = nativeUI.getCurrentVehicle()
    if not vehicle then
        return
    end

    local selectedMode = getSteeringLockModeIdFromIndex(index)
    if nativeUI.applySteeringLockModeTweak then
        nativeUI.applySteeringLockModeTweak(vehicle, selectedMode)
    else
        local bucket = nativeUI.ensureTuningState(vehicle)
        bucket.steeringLockMode = selectedMode
        nativeUI.syncVehicleTuneState(vehicle)
    end
    nativeUI.refreshMenu()
end

local function previewMainMenuSelection(context, index)
    local nativeUI = PerformanceTuning.NativeUI
    local state = getNativeUIState()
    local item = getMainMenuItemByContext(state, context)
    if item then
        local listState = nativeUI.buildListState(context) or {}
        setListItemDescription(item, context, getIndexedListOption(context, index), (listState.context or {}).currentValue)
    end
end

local function handleMainMenuSelection(context, index)
    previewMainMenuSelection(context, index)
    PerformanceTuning.NativeUI.applyMenuSelection(context, index)
    updateMainMenuListContext(context)
end

local function handleMainSliderChange(index)
    local nativeUI = PerformanceTuning.NativeUI
    local vehicle = nativeUI.getCurrentVehicle()
    if not vehicle then
        return
    end

    local value = nativeUI.getSliderValueForIndex(index, nativeUI.sliderRanges.antirollBars)
    setAntirollSliderState(value)
    nativeUI.applyAntirollForceTweak(vehicle, value)
end

local function handleTweakSliderChange(item, index)
    local nativeUI = PerformanceTuning.NativeUI
    local state = getNativeUIState()
    local vehicle = nativeUI.getCurrentVehicle()
    if not vehicle then
        return
    end

    if item == state.items.nitrousShotSlider then
        local value = nativeUI.getSliderValueForIndex(index, nativeUI.sliderRanges.nitrousShotStrength)
        setNitrousShotSliderState(value)
        nativeUI.applyNitroShotStrengthTweak(vehicle, value)
    elseif item == state.items.brakeBiasSlider then
        local value = nativeUI.getSliderValueForIndex(index, nativeUI.sliderRanges.brakeBiasFront)
        setBrakeBiasSliderState(value)
        nativeUI.applyBrakeBiasFrontTweak(vehicle, value)
    elseif item == state.items.gripBiasSlider then
        local value = nativeUI.getSliderValueForIndex(index, nativeUI.sliderRanges.gripBiasFront)
        setGripBiasSliderState(value)
        nativeUI.applyGripBiasFrontTweak(vehicle, value)
    elseif item == state.items.antirollBiasSlider then
        local value = nativeUI.getSliderValueForIndex(index, nativeUI.sliderRanges.antirollBiasFront)
        setAntirollBiasSliderState(value)
        nativeUI.applyAntirollBiasFrontTweak(vehicle, value)
    elseif item == state.items.suspensionRaiseSlider then
        local profile = state.dynamicSliderProfiles.suspensionRaise or {}
        local value = ((profile.raiseValues or {})[index]) or 0.0
        setSuspensionRaiseSliderState(value)
        nativeUI.applySuspensionRaiseTweak(vehicle, value)
    elseif item == state.items.suspensionBiasSlider then
        local value = nativeUI.getSliderValueForIndex(index, nativeUI.sliderRanges.suspensionBiasFront)
        setSuspensionBiasSliderState(value)
        nativeUI.applySuspensionBiasFrontTweak(vehicle, value)
    end
end

function PerformanceTuning.NativeUI.initializeMenu()
    local nativeUI = PerformanceTuning.NativeUI
    local state = getNativeUIState()
    if state.menuInitialized or type(NativeUI) ~= 'table' or type(NativeUI.CreatePool) ~= 'function' then
        return state.menuInitialized
    end

    state.menuPool = NativeUI.CreatePool()
    state.sliderValues.antirollBars = nativeUI.buildNormalizedSliderValues(nativeUI.sliderRanges.antirollBars)
    state.sliderValues.brakeBiasFront = nativeUI.buildNormalizedSliderValues(nativeUI.sliderRanges.brakeBiasFront)
    state.sliderValues.gripBiasFront = nativeUI.buildNormalizedSliderValues(nativeUI.sliderRanges.gripBiasFront)
    state.sliderValues.antirollBiasFront = nativeUI.buildNormalizedSliderValues(nativeUI.sliderRanges.antirollBiasFront)
    state.sliderValues.suspensionRaise = nativeUI.buildNormalizedSliderValues(nativeUI.sliderRanges.suspensionRaise)
    state.sliderValues.suspensionBiasFront = nativeUI.buildNormalizedSliderValues(nativeUI.sliderRanges.suspensionBiasFront)
    state.sliderValues.nitrousShotStrength = nativeUI.buildNitroShotSliderValues()

    state.menus.main = NativeUI.CreateMenu('Performance Tuning', '~b~CURRENT CAR', 1420, 0, nil, nil, nil, 255, 255, 255, 210)
    state.menuPool:Add(state.menus.main)
    state.menus.tweaks = state.menuPool:AddSubMenu(state.menus.main, 'Tweaks', 'Fine tuning adjustments for handling balance and special behavior.', true, true)

    state.items.engine = NativeUI.CreateListItem('Engine', { 'Stock' }, 1, getMenuDescription('engine'))
    state.items.transmission = NativeUI.CreateListItem('Transmission', { 'Stock' }, 1, getMenuDescription('transmission'))
    state.items.suspension = NativeUI.CreateListItem('Suspension', { 'Stock' }, 1, getMenuDescription('suspension'))
    state.items.tireCompoundCategory = NativeUI.CreateListItem('Compound', { 'Stock', 'Road', 'Rally', 'Offroad' }, 1, getMenuDescription('tireCompoundCategory'))
    state.items.tireCompoundQuality = NativeUI.CreateListItem('Quality', { 'Low-End', 'Mid-End', 'High-End', 'Top-End' }, 2, getMenuDescription('tireCompoundQuality'))
    state.items.brakes = NativeUI.CreateListItem('Brakes', { 'Stock' }, 1, getMenuDescription('brakes'))
    state.items.nitrous = NativeUI.CreateListItem('Nitrous', { 'Stock' }, 1, getMenuDescription('nitrous'))
    state.items.revLimiter = NativeUI.CreateListItem('Rev Limiter', { 'Off', 'On' }, 1, getMenuDescription('revLimiter'))
    state.items.steeringLockMode = NativeUI.CreateListItem('Steering Lock Mode', { 'Stock', 'Balanced', 'Aggro', 'Very Aggro', 'Very Smooth', 'Smooth' }, 1, getMenuDescription('steeringLockMode'))
    state.items.piDisplayMode = NativeUI.CreateListItem('PI Display', { 'mine', 'nearby tuned', 'nearby cars' }, state.piDisplayModeIndex, getMenuDescription('piDisplayMode'))
    state.items.antirollSlider = NativeUI.CreateSliderItem('Anti-Roll Bars', state.sliderValues.antirollBars, nativeUI.getAntirollSliderIndex(0.0), getMenuDescription('antirollBars'))
    state.items.nitrousShotSlider = NativeUI.CreateSliderItem('Shot Strength', state.sliderValues.nitrousShotStrength, nativeUI.getNitroShotSliderIndex(1.0), getMenuDescription('nitrousShotStrength'))
    state.items.brakeBiasSlider = NativeUI.CreateSliderItem('Brake Bias Front', state.sliderValues.brakeBiasFront, nativeUI.getBrakeBiasSliderIndex(0.5), getMenuDescription('brakeBiasFront'))
    state.items.gripBiasSlider = NativeUI.CreateSliderItem('Grip Bias Front', state.sliderValues.gripBiasFront, nativeUI.getGripBiasSliderIndex(0.5), getMenuDescription('gripBiasFront'))
    state.items.antirollBiasSlider = NativeUI.CreateSliderItem('Anti-Roll Bias Front', state.sliderValues.antirollBiasFront, nativeUI.getAntirollBiasSliderIndex(0.5), getMenuDescription('antirollBiasFront'))
    state.items.suspensionRaiseSlider = NativeUI.CreateSliderItem('Clearance', state.sliderValues.suspensionRaise, nativeUI.getSuspensionRaiseSliderIndex(0.0), getMenuDescription('suspensionRaise'))
    state.items.suspensionBiasSlider = NativeUI.CreateSliderItem('Suspension Bias Front', state.sliderValues.suspensionBiasFront, nativeUI.getSuspensionBiasSliderIndex(0.5), getMenuDescription('suspensionBiasFront'))

    state.menus.main:AddItem(state.items.engine)
    state.menus.main:AddItem(state.items.transmission)
    state.menus.main:AddItem(state.items.suspension)
    state.menus.main:AddItem(state.items.tireCompoundCategory)
    state.menus.main:AddItem(state.items.tireCompoundQuality)
    state.menus.main:AddItem(state.items.brakes)
    state.menus.main:AddItem(state.items.antirollSlider)
    state.menus.main:AddItem(state.items.nitrous)
    state.menus.main:AddItem(state.items.piDisplayMode)
    state.menus.tweaks.SubMenu:AddItem(state.items.nitrousShotSlider)
    state.menus.tweaks.SubMenu:AddItem(state.items.revLimiter)
    state.menus.tweaks.SubMenu:AddItem(state.items.steeringLockMode)
    state.menus.tweaks.SubMenu:AddItem(state.items.brakeBiasSlider)
    state.menus.tweaks.SubMenu:AddItem(state.items.gripBiasSlider)
    state.menus.tweaks.SubMenu:AddItem(state.items.antirollBiasSlider)
    state.menus.tweaks.SubMenu:AddItem(state.items.suspensionRaiseSlider)
    state.menus.tweaks.SubMenu:AddItem(state.items.suspensionBiasSlider)

    state.menus.main.OnMenuClosed = function()
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 and DoesEntityExist(vehicle) then
            nativeUI.updateSavedVehicleTuningFile(vehicle)
            if PerformanceTuning._internals.requestDragRebalance then
                PerformanceTuning._internals.requestDragRebalance(vehicle, 10000)
            end
        end
        state.menuOpen = false
        state.lastVehicleValidity = nil
        nativeUI.resetPerformanceIndexDisplayState()
        TriggerEvent('performancetuning:menuClosed')
    end

    state.menus.tweaks.SubMenu.OnMenuChanged = function()
        nativeUI.refreshMenu()
    end

    state.menus.tweaks.SubMenu.OnListChange = function(_, item, index)
        if item == state.items.revLimiter then
            handleRevLimiterSelection(index)
        elseif item == state.items.steeringLockMode then
            handleSteeringLockModeSelection(index)
        end
    end

    state.menus.tweaks.SubMenu.OnListSelect = function(_, item, index)
    end

    state.menus.main.OnListChange = function(_, item, index)
        if item == state.items.piDisplayMode then
            state.piDisplayModeIndex = math.max(1, math.min(3, math.floor(tonumber(index) or 1)))
            local piDisplayModeDescriptions = (((PerformanceTuning.Definitions or {}).uiText or {}).listOptionDescriptions or {}).piDisplayMode or {}
            item:Description(piDisplayModeDescriptions[state.piDisplayModeIndex] or getMenuDescription('piDisplayMode'))
            return
        end

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

    state.menus.main.OnListSelect = function(_, item, index)
    end

    state.menus.main.OnSliderChange = function(_, item, index)
        if item == state.items.antirollSlider then
            handleMainSliderChange(index)
        end
    end

    state.menus.main.OnSliderSelect = function(_, item, index)
    end

    state.menus.tweaks.SubMenu.OnSliderChange = function(_, item, index)
        handleTweakSliderChange(item, index)
    end

    state.menus.tweaks.SubMenu.OnSliderSelect = function(_, item, index)
    end

    state.menuInitialized = true
    state.menuPool:RefreshIndex()
    return true
end

function PerformanceTuning.NativeUI.openMainMenu()
    local nativeUI = PerformanceTuning.NativeUI
    local state = getNativeUIState()
    if not nativeUI.initializeMenu() then
        nativeUI.notify('NativeUI is not available.')
        return false
    end

    nativeUI.applyCurrentVehicleStateBagTuningForMenu()

    local ok, errorMessage = nativeUI.refreshMenu()
    if not ok then
        if errorMessage then
            nativeUI.notify(errorMessage)
        end
        return false
    end

    state.menuOpen = true
    state.menus.main:Visible(true)
    return true
end

function PerformanceTuning.NativeUI.processFrame()
    local nativeUI = PerformanceTuning.NativeUI
    local state = getNativeUIState()

    if state.menuInitialized and state.menuPool then
        state.menuPool:ProcessMenus()
    end

    if not state.menuOpen then
        return false
    end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    local hasValidVehicle = PerformanceTuning.VehicleManager.isPedDrivingVehicle(ped, vehicle)
    if state.lastVehicleValidity ~= hasValidVehicle then
        state.lastVehicleValidity = hasValidVehicle
        nativeUI.refreshMenu()
    end

    if hasValidVehicle then
        nativeUI.drawPerformanceIndexPanel(vehicle)
    else
        nativeUI.drawPerformanceIndexPanel(nil, { drawNearbyOnly = true })
    end
    return true
end
