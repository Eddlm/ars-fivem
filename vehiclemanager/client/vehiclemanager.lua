local Config = VehicleManager.Config or {}
local MenuConfig = Config.menu or {}
local AppearanceConfig = Config.appearance or {}
local CategoryConfig = Config.categories or {}
local ConstantConfig = Config.constants or {}
local UIConfig = Config.ui or {}
local TextConfig = {
    helpLabel = "Util",
    helpOptions = { "Fix Vehicle", "Teleport To Nearest Road", "Delete Vehicle" },
    helpDescription = "Handy tools for getting your vehicle back in shape.",
    customizeVehicleLabel = "Customize Vehicle",
    customizeVehicleDescription = "Customization",
    saveLoadLabel = "Save / Load",
    saveLoadDescription = "These vehicles persist across sessions.",
    deleteVehicleLabel = "Delete Vehicle",
    deleteVehicleDescription = "~r~This action is permanent.",
    performanceSettingsLabel = "Performance Settings",
    performanceSettingsDescription = "Tune assist settings.",
    statsLabel = "Stats",
    statsDescription = "Performance upgrades.",
    colorLabel = "Color",
    colorDescription = "Paint and finish options.",
    partsLabel = "Parts",
    partsDescription = "Body and interior parts.",
    wheelsMenuLabel = "Wheels",
    wheelsMenuDescription = "Wheel style and setup.",
    saveVehicleLabel = "Save Vehicle",
    saveVehicleDescription = "Save your current vehicle and setup for later.",
    paintCategoryLabel = "Paint Category",
    paintCategoryDescription = "Choose the paint finish for your body colors.",
    primaryPaintLabel = "Primary",
    primaryPaintDescription = "Set the main paint color.",
    secondaryPaintLabel = "Secondary",
    secondaryPaintDescription = "Set the secondary paint color.",
    pearlescentLabel = "Pearlescent",
    pearlescentDescription = "Add a pearl finish over the paint.",
    interiorLabel = "Interior",
    interiorDescription = "Change the interior color.",
    dashboardLabel = "Dashboard",
    dashboardDescription = "Change the dashboard color.",
    xenonLabel = "Xenon",
    xenonDescription = "Set the xenon headlight color.",
    liveryLabel = "Livery",
    liveryDescription = "Apply a livery if this vehicle supports one.",
    wheelCategoryLabel = "Wheel Category",
    wheelCategoryDescription = "Choose a wheel family to browse.",
    wheelLabel = "Wheel",
    wheelDescription = "Pick a wheel style from this category.",
    wheelColorLabel = "Wheel Color",
    wheelColorDescription = "Change the wheel color.",
    customTyresLabel = "Custom Tyres",
    customTyresDescription = "Toggle custom tyres for this wheel setup.",
    performancePiDisplayLabel = "Compare with Nearby",
    performancePiDisplayDescription = "Show or hide nearby PI comparison panels.",
    performanceRevLimiterLabel = "Rev Limiter",
    performanceRevLimiterDescription = "Turn the current vehicle's rev limiter behavior on or off.",
    noVehicleLabel = "No vehicle",
    noVehicleDescription = "Get into a vehicle and take the driver seat to use this option.",
    noLiveriesLabel = "No liveries available",
    partsEmptyTitle = "No parts available",
    partsEmptyDescription = "This vehicle doesn't have any customizable parts here.",
    statsEmptyTitle = "No stats upgrades",
    statsEmptyDescription = "This vehicle doesn't have any upgrade options here.",
    stockLabel = "Stock",
    unknownColorLabel = "Unknown",
}
local MENU_X_POSITION = tonumber(UIConfig.menuXPosition) or 20
local MENU_TITLE = tostring(UIConfig.menuTitle or "Vehicle Manager")
local MENU_SUBTITLE = tostring(UIConfig.menuSubtitle or "Fix, customize and save your vehicle")
local MENU_KEYBIND_RELEASE_COMMAND = tostring(UIConfig.menuKeybindReleaseCommand or "-vehiclemanager_menu")
local MENU_KEYBIND_DESCRIPTION = tostring(UIConfig.menuKeybindDescription or "Open the vehicle manager menu")
local MENU_AVAILABILITY_REFRESH_MS = math.max(0, math.floor(tonumber(UIConfig.menuAvailabilityRefreshMs) or 200))
local VEHICLE_TUNING_AUTOSAVE_DELAY_MS = 6000
local PERFORMANCE_SETTINGS_PI_OPTIONS = UIConfig.performanceSettingsPiOptions or { "No", "Yes" }
local PERFORMANCE_SETTINGS_REV_LIMITER_OPTIONS = UIConfig.performanceSettingsRevLimiterOptions or { "Off", "On" }

local VMUI = {}

function VMUI.CreatePool()
    local pool = {
        rootMenu = nil,
    }

    function pool:Add(menu)
        self.rootMenu = menu
        return menu
    end

    function pool:AddSubMenu(parentMenu, title, description)
        local resolvedDescription = description
        if resolvedDescription == nil then
            resolvedDescription = ""
        end

        local item = VMUI.CreateItem(title, resolvedDescription)
        parentMenu:AddItem(item)
        local submenu = VMUI.CreateMenu(title, resolvedDescription, MENU_X_POSITION, 0, nil, nil, nil, 255, 255, 255, 210)
        submenu:MenuAlignment(MenuAlignment.LEFT)
        item.Activated = function(menu)
            menu:SwitchTo(submenu, 1, true)
        end
        return {
            Item = item,
            SubMenu = submenu,
        }
    end

    function pool:CloseAllMenus()
        MenuHandler:CloseAndClearHistory()
    end

    function pool:RefreshIndex()
    end

    return pool
end

function VMUI.CreateMenu(title, subtitle, x, y, _, _, _, _, _, _, _)
    local menu = UIMenu.New(title, subtitle, x or 0, y or 0, true)
    menu:MenuAlignment(MenuAlignment.LEFT)
    menu:SetBannerColor(SColor.LightBlue)
    return menu
end

function VMUI.CreateItem(text, description)
    local item
    if description == nil then
        item = UIMenuItem.New(text)
    else
        item = UIMenuItem.New(text, description)
    end
    item.Activated = item.Activated or function() end
    return item
end

function VMUI.CreateListItem(text, items, index, description)
    local item
    if description == nil then
        item = UIMenuListItem.New(text, items, index)
    else
        item = UIMenuListItem.New(text, items, index, description)
    end
    item.Activated = item.Activated or function() end
    return item
end

function VMUI.CreateColouredItem(text, description)
    local item
    if description == nil then
        item = UIMenuItem.New(text)
    else
        item = UIMenuItem.New(text, description)
    end
    item.Activated = item.Activated or function() end
    return item
end
local vehicleMenuPool = VMUI.CreatePool()
local vehicleMainMenu = VMUI.CreateMenu(MENU_TITLE, MENU_SUBTITLE, MENU_X_POSITION, 0, nil, nil, nil, 255, 255, 255, 210)

local helpListItem = VMUI.CreateListItem(TextConfig.helpLabel or "Util", TextConfig.helpOptions or { "Fix Vehicle", "Teleport To Nearest Road", "Delete Vehicle" }, 1, nil)
local saveVehicleItem = VMUI.CreateItem(TextConfig.saveVehicleLabel or "Save Vehicle", "")
local saveLoadSubMenu = nil
local deleteVehiclesSubMenu = nil
local customizeSubMenu = nil
local colorSubMenu = nil
local wheelsSubMenu = nil
local partsSubMenu = nil
local performanceSettingsSubMenu = nil
local performanceSettingsGatewayItem = nil
local performanceSettingsMenu = nil
local statsGatewayItem = nil
local statsLocalMenu = nil
local statsLocalSubMenu = nil
local returnToCustomizeAfterPerformanceTuningClose = false
local pendingVehicleTuningAutosaveId = 0
local paintCategoryListItem = VMUI.CreateListItem(TextConfig.paintCategoryLabel or "Paint Category", { "Classic" }, 1, TextConfig.paintCategoryDescription or "Choose the paint finish for your body colors.")
local primaryPaintColorListItem = VMUI.CreateListItem(TextConfig.primaryPaintLabel or "Primary", { "Black" }, 1, TextConfig.primaryPaintDescription or "Set the main paint color.")
local secondaryPaintColorListItem = VMUI.CreateListItem(TextConfig.secondaryPaintLabel or "Secondary", { "Black" }, 1, TextConfig.secondaryPaintDescription or "Set the secondary paint color.")
local pearlescentColorListItem = VMUI.CreateListItem(TextConfig.pearlescentLabel or "Pearlescent", { "Black" }, 1, TextConfig.pearlescentDescription or "Add a pearl finish over the paint.")
local interiorColorListItem = VMUI.CreateListItem(TextConfig.interiorLabel or "Interior", { "Black" }, 1, TextConfig.interiorDescription or "Change the interior color.")
local dashboardColorListItem = VMUI.CreateListItem(TextConfig.dashboardLabel or "Dashboard", { "Black" }, 1, TextConfig.dashboardDescription or "Change the dashboard color.")
local xenonColorListItem = VMUI.CreateListItem(TextConfig.xenonLabel or "Xenon", { "Default" }, 1, TextConfig.xenonDescription or "Set the xenon headlight color.")
local liveryListItem = VMUI.CreateListItem(TextConfig.liveryLabel or "Livery", { TextConfig.noLiveriesLabel or "No liveries available" }, 1, TextConfig.liveryDescription or "Apply a livery if this vehicle supports one.")
local wheelCategoryListItem = VMUI.CreateListItem(TextConfig.wheelCategoryLabel or "Wheel Category", { "Sport" }, 1, TextConfig.wheelCategoryDescription or "Choose a wheel family to browse.")
local wheelListItem = VMUI.CreateListItem(TextConfig.wheelLabel or "Wheel", { TextConfig.stockLabel or "Stock" }, 1, TextConfig.wheelDescription or "Pick a wheel style from this category.")
local wheelColorListItem = VMUI.CreateListItem(TextConfig.wheelColorLabel or "Wheel Color", { "Black" }, 1, TextConfig.wheelColorDescription or "Change the wheel color.")
local customTyresItem = UIMenuCheckboxItem.New(TextConfig.customTyresLabel or "Custom Tyres", false, 1, TextConfig.customTyresDescription or "Toggle custom tyres for this wheel setup.")
customTyresItem.Activated = customTyresItem.Activated or function() end
local performancePiDisplayListItem = VMUI.CreateListItem(TextConfig.performancePiDisplayLabel or "PI Display", PERFORMANCE_SETTINGS_PI_OPTIONS, 1, TextConfig.performancePiDisplayDescription or "Choose which performance index values are shown in the tuning UI.")
local performanceRevLimiterListItem = VMUI.CreateListItem(TextConfig.performanceRevLimiterLabel or "Rev Limiter", PERFORMANCE_SETTINGS_REV_LIMITER_OPTIONS, 1, TextConfig.performanceRevLimiterDescription or "Turn the current vehicle's rev limiter behavior on or off.")

local currentPrimaryColorOptions = {}
local currentSecondaryColorOptions = {}
local currentLiveryOptions = {}
local currentWheelOptions = {}
local partsModItems = {}
local partsModEntries = {}
local statsModItems = {}
local statsModEntries = {}
local savedVehicleEntries = {}
local savedVehicleItems = {}
local deleteVehicleEntries = {}
local deleteVehicleItems = {}
local vehicleRequiredItems = {}
local driverRequiredItems = {}
local saveActionInFlight = false
local pendingUtilityDeleteByVehicle = {}
local availabilityState = {
    hasVehicle = nil,
    hasDriverVehicle = nil,
}
local pendingOverwriteSaveId = nil
local TUNE_STATE_BAG_KEY = tostring(UIConfig.tuneStateBagKey or "performancetuning:tuneState")
local HANDLING_STATE_BAG_KEY = tostring(UIConfig.handlingStateBagKey or "performancetuning:handlingState")
local SAVE_ID_STATE_BAG_KEY = tostring(UIConfig.saveIdStateBagKey or "vehiclemanager:saveId")
local getCurrentVehicle
local scheduleVehicleTuningAutosave

AddStateBagChangeHandler(TUNE_STATE_BAG_KEY, nil, function(bagName, key, value)
    local vehicle = getCurrentVehicle(false)
    if not vehicle then return end
    if GetEntityFromStateBagName(bagName) ~= vehicle then return end
    if scheduleVehicleTuningAutosave then
        scheduleVehicleTuningAutosave()
    end
end)

AddStateBagChangeHandler(HANDLING_STATE_BAG_KEY, nil, function(bagName, key, value)
    local vehicle = getCurrentVehicle(false)
    if not vehicle then return end
    if GetEntityFromStateBagName(bagName) ~= vehicle then return end
    if scheduleVehicleTuningAutosave then
        scheduleVehicleTuningAutosave()
    end
end)

local paintCategories = {}
for index = 1, #(AppearanceConfig.paintCategories or {}) do
    local category = (AppearanceConfig.paintCategories or {})[index]
    local resolvedColors = AppearanceConfig[category.colorSet or ""] or AppearanceConfig.baseGlossColorOptions
    paintCategories[index] = {
        key = category.key,
        label = category.label,
        paintType = category.paintType,
        colors = resolvedColors,
    }
end

local paintCategoryLabels = {}
for index = 1, #paintCategories do
    paintCategoryLabels[index] = paintCategories[index].label
end

local function buildMergedColorOptions(...)
    local mergedOptions = {}
    local seenColorIds = {}
    local sources = { ... }

    for sourceIndex = 1, #sources do
        local source = sources[sourceIndex]
        for optionIndex = 1, #source do
            local option = source[optionIndex]
            if not seenColorIds[option.colorId] then
                seenColorIds[option.colorId] = true
                mergedOptions[#mergedOptions + 1] = {
                    label = option.label,
                    colorId = option.colorId,
                }
            end
        end
    end

    return mergedOptions
end

local extraColorOptions = buildMergedColorOptions(
    AppearanceConfig.baseGlossColorOptions,
    AppearanceConfig.matteColorOptions,
    AppearanceConfig.utilColorOptions,
    AppearanceConfig.wornColorOptions,
    AppearanceConfig.metalColorOptions,
    AppearanceConfig.chromeColorOptions
)
local xenonColorOptions = AppearanceConfig.xenonColorOptions

local function buildPaintColorOptionList(options)
    local labels = {}
    for index = 1, #options do
        labels[index] = options[index].label
    end
    return labels
end

local buildColorLabels = buildPaintColorOptionList

paintCategoryListItem.Items = paintCategoryLabels
pearlescentColorListItem.Items = buildPaintColorOptionList(extraColorOptions)
interiorColorListItem.Items = buildPaintColorOptionList(extraColorOptions)
dashboardColorListItem.Items = buildPaintColorOptionList(extraColorOptions)
xenonColorListItem.Items = buildPaintColorOptionList(AppearanceConfig.xenonColorOptions)
wheelColorListItem.Items = buildPaintColorOptionList(extraColorOptions)

local function buildColorIdLookup(colorOptions)
    local lookup = {}
    for index = 1, #colorOptions do
        lookup[colorOptions[index].colorId] = true
    end
    return lookup
end

local utilColorLookup = buildColorIdLookup(AppearanceConfig.utilColorOptions)
local wornColorLookup = buildColorIdLookup(AppearanceConfig.wornColorOptions)
local fullColorLabelById = {}
for _, colorSet in ipairs({ AppearanceConfig.baseGlossColorOptions, AppearanceConfig.matteColorOptions, AppearanceConfig.utilColorOptions, AppearanceConfig.wornColorOptions, AppearanceConfig.metalColorOptions, AppearanceConfig.chromeColorOptions }) do
    for index = 1, #colorSet do
        local option = colorSet[index]
        fullColorLabelById[option.colorId] = fullColorLabelById[option.colorId] or option.label
    end
end

local function getPaintCategory(index)
    return paintCategories[index] or paintCategories[1]
end

local function getPaintCategoryIndexByState(paintType, colorId)
    if paintType == 1 then
        return 2
    elseif paintType == 3 then
        return 3
    elseif paintType == 4 then
        return 6
    elseif paintType == 5 then
        return 7
    elseif utilColorLookup[colorId] then
        return 4
    elseif wornColorLookup[colorId] then
        return 5
    end

    return 1
end

local function getColorLabelById(colorId)
    local resolvedColorId = tonumber(colorId)
    if resolvedColorId == nil then
        return TextConfig.unknownColorLabel or "Unknown"
    end

    return fullColorLabelById[resolvedColorId] or ("Color %s"):format(resolvedColorId)
end

local function getVehiclePerformancePi(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil
    end

    local ok, metrics = pcall(function()
        return exports["performancetuning"]:GetPerformancePanelMetrics(vehicle)
    end)
    if not ok or type(metrics) ~= "table" then
        return nil
    end

    local total = tonumber(metrics.total)
    if total == nil then
        return nil
    end

    return math.max(0, math.floor(total + 0.5))
end

local partsVehicleModCategories = CategoryConfig.partsVehicleModCategories or {}
local statsVehicleModCategories = CategoryConfig.statsVehicleModCategories or {}
local wheelCategories = CategoryConfig.wheelCategories or {}

local wheelCategoryLabels = {}
for index = 1, #wheelCategories do
    wheelCategoryLabels[index] = wheelCategories[index].label
end

wheelCategoryListItem.Items = wheelCategoryLabels

getCurrentVehicle = function(requireDriver)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then
        return nil
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil
    end

    if requireDriver and GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return nil
    end

    return vehicle
end

local function getLocalizedModName(labelKey, fallback)
    if not labelKey or labelKey == "" then
        return fallback
    end

    local label = GetLabelText(labelKey)
    if not label or label == "NULL" or label == "" then
        return fallback
    end

    return label
end

local getDisplayLabel = getLocalizedModName
local getLabelOrFallback = getLocalizedModName
local getSafeDisplayLabel = getLocalizedModName



local function registerVehicleRequiredItem(item)
    if item then
        vehicleRequiredItems[#vehicleRequiredItems + 1] = item
    end
end

local function registerDriverRequiredItem(item)
    if item then
        driverRequiredItems[#driverRequiredItems + 1] = item
    end
end

local function setItemsEnabled(items, enabled)
    for index = 1, #items do
        items[index]:Enabled(enabled)
    end
end

local function setItemDescriptionRaw(item, text)
    if item == nil then
        return
    end
    item._Description = tostring(text or "")
end

local function syncMenuCurrentDescription(menu)
    if not menu or type(menu.Visible) ~= "function" or not menu:Visible() then
        return
    end

    local currentItem = type(menu.CurrentItem) == "function" and menu:CurrentItem() or nil
    if currentItem == nil or type(currentItem.Description) ~= "function" then
        return
    end

    AddTextEntry("UIMenu_Current_Description", tostring(currentItem:Description() or ""))
    if type(menu.UpdateDescription) == "function" then
        menu:UpdateDescription()
    end
end

local function clearItemDescription(item)
    setItemDescriptionRaw(item, "")
end

local function notify(message)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(tostring(message or ""))
    EndTextCommandThefeedPostTicker(false, false)
end

local function buildModCategoryDescription(label, isStatsMenu)
    local resolvedLabel = tostring(label or "option")
    if isStatsMenu then
        return ("Select the installed %s upgrade level."):format(resolvedLabel)
    end

    return ("Choose a %s option for this vehicle."):format(resolvedLabel)
end

local function notifyPersistentVehicleUpdated(vehicle)
    local vehicleName = "vehicle"

    if vehicle and DoesEntityExist(vehicle) then
        local model = GetEntityModel(vehicle)
        local displayName = GetDisplayNameFromVehicleModel(model)
        if not displayName or displayName == "" then
            displayName = tostring(model)
        end

        local localizedName = GetLabelText(displayName)
        if localizedName and localizedName ~= "" and localizedName ~= "NULL" then
            vehicleName = localizedName
        else
            vehicleName = displayName
        end
    end

    local message = ("Persistent ~HUD_COLOUR_FREEMODE~%s~s~ updated."):format(tostring(vehicleName))
    if ScaleformUI and ScaleformUI.Notifications and ScaleformUI.Notifications.ShowNotification then
        ScaleformUI.Notifications:ShowNotification(message, false, false)
        return
    end

    notify(("Persistent %s updated."):format(tostring(vehicleName)))
end

local function tryOpenPerformanceTuningMenu()
    if GetResourceState("performancetuning") ~= "started" then
        return false
    end

    local ok, opened = pcall(function()
        return exports["performancetuning"]:OpenPerformanceTuningMenu()
    end)

    return ok and opened == true
end

local function isPerformanceTuningStarted()
    return GetResourceState("performancetuning") == "started"
end

local function getPerformanceTuningPiDisplayModeIndex()
    if not isPerformanceTuningStarted() then
        return 1
    end

    local ok, value = pcall(function()
        return exports["performancetuning"]:GetPiDisplayModeIndex()
    end)

    if not ok then
        return 1
    end

    return math.max(1, math.min(#PERFORMANCE_SETTINGS_PI_OPTIONS, math.floor(tonumber(value) or 1)))
end

local function setPerformanceTuningPiDisplayModeIndex(index)
    if not isPerformanceTuningStarted() then
        return false
    end

    local ok = pcall(function()
        exports["performancetuning"]:SetPiDisplayModeIndex(index)
    end)

    return ok
end

local function getPerformanceTuningRevLimiterEnabled()
    if not isPerformanceTuningStarted() then
        return false, false
    end

    local ok, enabled = pcall(function()
        return exports["performancetuning"]:GetCurrentVehicleRevLimiterEnabled()
    end)

    if not ok or enabled == nil then
        return false, false
    end

    return true, enabled == true
end

local function setPerformanceTuningRevLimiterEnabled(enabled)
    if not isPerformanceTuningStarted() then
        return false
    end

    local ok, result = pcall(function()
        return exports["performancetuning"]:SetCurrentVehicleRevLimiterEnabled(enabled)
    end)

    return ok and result == true
end


local function refreshPerformanceSettingsMenu()
    local hasVehicle = availabilityState.hasDriverVehicle == true
    local tuningAvailable = isPerformanceTuningStarted()

    performancePiDisplayListItem:Enabled(tuningAvailable and hasVehicle)
    performanceRevLimiterListItem:Enabled(tuningAvailable and hasVehicle)

    if not tuningAvailable then
        local description = "Start performancetuning to adjust these settings."
        setItemDescriptionRaw(performancePiDisplayListItem, description)
        setItemDescriptionRaw(performanceRevLimiterListItem, description)
        performancePiDisplayListItem:Index(1)
        performanceRevLimiterListItem:Index(1)
        syncMenuCurrentDescription(performanceSettingsMenu)
        return
    end

    if not hasVehicle then
        local description = TextConfig.noVehicleDescription or "Get into a vehicle to see options here."
        setItemDescriptionRaw(performancePiDisplayListItem, description)
        setItemDescriptionRaw(performanceRevLimiterListItem, description)
        performancePiDisplayListItem:Index(1)
        performanceRevLimiterListItem:Index(1)
        syncMenuCurrentDescription(performanceSettingsMenu)
        return
    end

    performancePiDisplayListItem:Index(getPerformanceTuningPiDisplayModeIndex())
    clearItemDescription(performancePiDisplayListItem)

    local hasRevLimiterVehicle, revLimiterEnabled = getPerformanceTuningRevLimiterEnabled()
    performanceRevLimiterListItem:Index(revLimiterEnabled and 2 or 1)
    if hasRevLimiterVehicle then
        clearItemDescription(performanceRevLimiterListItem)
    else
        setItemDescriptionRaw(performanceRevLimiterListItem, TextConfig.noVehicleDescription or "Get into a vehicle to see options here.")
        performanceRevLimiterListItem:Enabled(false)
    end

    syncMenuCurrentDescription(performanceSettingsMenu)
end

local function rebuildPaintColorList(listItem, categoryIndex, target)
    local category = getPaintCategory(categoryIndex)
    local options = {}

    listItem.Items = {}

    for index = 1, #category.colors do
        local option = category.colors[index]
        options[index] = option
        listItem.Items[index] = option.label
    end

    if target == "primary" then
        currentPrimaryColorOptions = options
    else
        currentSecondaryColorOptions = options
    end
end

local function rebuildLiveryList(vehicle)
    currentLiveryOptions = {}
    liveryListItem.Items = {}

    if not vehicle then
        currentLiveryOptions[1] = { label = TextConfig.noVehicleLabel or "No vehicle", available = false }
        liveryListItem.Items[1] = TextConfig.noVehicleLabel or "No vehicle"
        liveryListItem:Index(1)
        return
    end

    SetVehicleModKit(vehicle, 0)

    local liveryCount = GetVehicleLiveryCount(vehicle)
    if liveryCount and liveryCount > 0 then
        for liveryIndex = 0, liveryCount - 1 do
            local listIndex = #currentLiveryOptions + 1
            currentLiveryOptions[listIndex] = {
                label = getDisplayLabel(GetLiveryName(vehicle, liveryIndex), ("Livery %d"):format(liveryIndex + 1)),
                available = true,
                mode = "native",
                value = liveryIndex,
            }
            liveryListItem.Items[listIndex] = currentLiveryOptions[listIndex].label
        end

        liveryListItem:Index(1)
        return
    end

    local modCount = GetNumVehicleMods(vehicle, 48)
    if modCount and modCount > 0 then
        currentLiveryOptions[1] = {
            label = TextConfig.stockLabel or "Stock",
            available = true,
            mode = "mod",
            value = -1,
        }
        liveryListItem.Items[1] = TextConfig.stockLabel or "Stock"

        for modIndex = 0, modCount - 1 do
            local listIndex = #currentLiveryOptions + 1
            currentLiveryOptions[listIndex] = {
                label = getDisplayLabel(GetModTextLabel(vehicle, 48, modIndex), ("Livery %d"):format(modIndex + 1)),
                available = true,
                mode = "mod",
                value = modIndex,
            }
            liveryListItem.Items[listIndex] = currentLiveryOptions[listIndex].label
        end

        liveryListItem:Index(1)
        return
    end

    currentLiveryOptions[1] = { label = TextConfig.noLiveriesLabel or "No liveries available", available = false }
    liveryListItem.Items[1] = TextConfig.noLiveriesLabel or "No liveries available"
end

local function rebuildModMenu(subMenu, categories, emptyTitle, emptyDescription, isStatsMenu)
    local targetMenu = subMenu
    if type(subMenu) == "table" and subMenu.SubMenu then
        targetMenu = subMenu.SubMenu
    end
    if not targetMenu then
        return {}, {}
    end

    targetMenu:Clear()
    local vehicle = getCurrentVehicle(false)
    if not vehicle then
        local emptyItem = VMUI.CreateItem(TextConfig.noVehicleLabel or "No vehicle", TextConfig.noVehicleDescription or "Get into a vehicle to see options here.")
        emptyItem:Enabled(false)
        targetMenu:AddItem(emptyItem)
        vehicleMenuPool:RefreshIndex()
        return
    end

    local modItems = {}
    local modEntries = {}

    SetVehicleModKit(vehicle, 0)

    for _, category in ipairs(categories) do
        local modCount = GetNumVehicleMods(vehicle, category.modType)
        if modCount and modCount > 0 then
            local options = {
                { label = TextConfig.stockLabel or "Stock", value = -1 },
            }
            local optionLabels = { TextConfig.stockLabel or "Stock" }

            for modIndex = 0, modCount - 1 do
                local label = getDisplayLabel(GetModTextLabel(vehicle, category.modType, modIndex), ("%s %d"):format(category.label, modIndex + 1))
                options[#options + 1] = {
                    label = label,
                    value = modIndex,
                }
                optionLabels[#optionLabels + 1] = label
            end

            local currentMod = GetVehicleMod(vehicle, category.modType)
            local currentIndex = 1
            for optionIndex = 1, #options do
                if options[optionIndex].value == currentMod then
                    currentIndex = optionIndex
                    break
                end
            end

            local item = VMUI.CreateListItem(category.label, optionLabels, currentIndex, buildModCategoryDescription(category.label, isStatsMenu))
            targetMenu:AddItem(item)
            modItems[#modItems + 1] = item
            modEntries[#modEntries + 1] = {
                modType = category.modType,
                options = options,
                item = item,
            }
        end
    end

    if #modItems <= 0 then
        local emptyItem = VMUI.CreateItem(emptyTitle, emptyDescription)
        emptyItem:Enabled(false)
        targetMenu:AddItem(emptyItem)
    end

    vehicleMenuPool:RefreshIndex()
    return modItems, modEntries
end

local function rebuildPartsMenu()
    partsModItems, partsModEntries = rebuildModMenu(
        partsSubMenu,
        partsVehicleModCategories,
        TextConfig.partsEmptyTitle or "No parts available",
        TextConfig.partsEmptyDescription or "This vehicle doesn't have any customizable parts here.",
        false
    )
end

local function rebuildStatsMenu()
    statsModItems, statsModEntries = rebuildModMenu(
        statsLocalMenu,
        statsVehicleModCategories,
        TextConfig.statsEmptyTitle or "No stats upgrades",
        TextConfig.statsEmptyDescription or "This vehicle doesn't have any upgrade options here.",
        true
    )
end

local function applyModSelection(item, index, entries)
    local vehicle = getCurrentVehicle(false)
    if not vehicle then
        return
    end

    local targetEntry = nil
    for entryIndex = 1, #entries do
        local entry = entries[entryIndex]
        if entry.item == item then
            targetEntry = entry
            break
        end
    end

    if not targetEntry then
        return
    end

    local option = targetEntry.options[index]
    if not option then
        return
    end

    SetVehicleModKit(vehicle, 0)
    SetVehicleMod(vehicle, targetEntry.modType, option.value, false)
    scheduleVehicleTuningAutosave()
end

local function findColorIndex(options, colorId)
    for index = 1, #options do
        if options[index].colorId == colorId then
            return index
        end
    end

    return 1
end

local function getWheelCategory(index)
    return wheelCategories[index] or wheelCategories[1]
end

local function getWheelCategoryIndexByType(wheelType)
    for index = 1, #wheelCategories do
        if wheelCategories[index].wheelType == wheelType then
            return index
        end
    end

    return 1
end

local function getPrimaryWheelModType(vehicle)
    if not vehicle then
        return 23
    end

    local frontCount = GetNumVehicleMods(vehicle, 23)
    if frontCount and frontCount > 0 then
        return 23
    end

    local rearCount = GetNumVehicleMods(vehicle, 24)
    if rearCount and rearCount > 0 then
        return 24
    end

    return 23
end

local function captureWheelState(vehicle)
    return {
        wheelType = GetVehicleWheelType(vehicle),
        frontIndex = GetVehicleMod(vehicle, 23),
        frontCustom = GetVehicleModVariation(vehicle, 23),
        rearIndex = GetVehicleMod(vehicle, 24),
        rearCustom = GetVehicleModVariation(vehicle, 24),
    }
end

local function restoreWheelState(vehicle, state)
    if not vehicle or not state then
        return
    end

    SetVehicleModKit(vehicle, 0)
    SetVehicleWheelType(vehicle, state.wheelType)
    SetVehicleMod(vehicle, 23, state.frontIndex or -1, state.frontCustom == true)
    SetVehicleMod(vehicle, 24, state.rearIndex or -1, state.rearCustom == true)
end

local function rebuildWheelList(categoryIndex)
    currentWheelOptions = {}
    wheelListItem.Items = {}

    local vehicle = getCurrentVehicle(false)
    if not vehicle then
        wheelListItem.Items[1] = TextConfig.noVehicleLabel or "No vehicle"
        wheelListItem:Index(1)
        customTyresItem:Checked(false)
        return
    end

    SetVehicleModKit(vehicle, 0)

    local wheelState = captureWheelState(vehicle)
    local wheelCategory = getWheelCategory(categoryIndex)
    local wheelModType = getPrimaryWheelModType(vehicle)

    SetVehicleWheelType(vehicle, wheelCategory.wheelType)

    local modCount = GetNumVehicleMods(vehicle, wheelModType)
    currentWheelOptions[1] = { label = TextConfig.stockLabel or "Stock", value = -1 }
    wheelListItem.Items[1] = TextConfig.stockLabel or "Stock"

    if modCount and modCount > 0 then
        for modIndex = 0, modCount - 1 do
            local listIndex = #currentWheelOptions + 1
            local label = getDisplayLabel(GetModTextLabel(vehicle, wheelModType, modIndex), ("Wheel %d"):format(modIndex + 1))
            currentWheelOptions[listIndex] = {
                label = label,
                value = modIndex,
            }
            wheelListItem.Items[listIndex] = label
        end
    end

    local currentWheelIndex = 1
    local currentModValue = wheelModType == 24 and wheelState.rearIndex or wheelState.frontIndex
    for optionIndex = 1, #currentWheelOptions do
        if currentWheelOptions[optionIndex].value == currentModValue then
            currentWheelIndex = optionIndex
            break
        end
    end

    wheelListItem:Index(currentWheelIndex)
    customTyresItem:Checked((wheelModType == 24 and wheelState.rearCustom or wheelState.frontCustom) == true)
    restoreWheelState(vehicle, wheelState)
end

local function refreshWheelControls()
    local vehicle = getCurrentVehicle(false)
    if not vehicle then
        wheelCategoryListItem:Index(1)
        rebuildWheelList(1)
        wheelColorListItem:Index(1)
        return
    end

    local _, wheelColor = GetVehicleExtraColours(vehicle)
    local wheelCategoryIndex = getWheelCategoryIndexByType(GetVehicleWheelType(vehicle))
    wheelCategoryListItem:Index(wheelCategoryIndex)
    rebuildWheelList(wheelCategoryIndex)
    wheelColorListItem:Index(findColorIndex(extraColorOptions, wheelColor))
end

local function applyWheelSelection(categoryIndex, wheelIndex, useCustomTyres)
    local vehicle = getCurrentVehicle(false)
    local option = currentWheelOptions[wheelIndex]
    if not vehicle or not option then
        return
    end

    SetVehicleModKit(vehicle, 0)
    SetVehicleWheelType(vehicle, getWheelCategory(categoryIndex).wheelType)

    local wheelModType = getPrimaryWheelModType(vehicle)
    SetVehicleMod(vehicle, wheelModType, option.value, useCustomTyres == true)
    scheduleVehicleTuningAutosave()
end

local function findLiveryIndex(vehicle)
    if not vehicle or #currentLiveryOptions <= 0 then
        return 1
    end

    local currentNativeLivery = GetVehicleLivery(vehicle)
    for index = 1, #currentLiveryOptions do
        local option = currentLiveryOptions[index]
        if option.mode == "native" and option.value == currentNativeLivery then
            return index
        end
    end

    local currentModLivery = GetVehicleMod(vehicle, 48)
    for index = 1, #currentLiveryOptions do
        local option = currentLiveryOptions[index]
        if option.mode == "mod" and option.value == currentModLivery then
            return index
        end
    end

    return 1
end

local function refreshVehicleCustomizationLists()
    local vehicle = getCurrentVehicle(false)
    local primaryColor = 0
    local secondaryColor = 0
    local primaryPaintType = 0
    local pearlescentColor = 0
    local interiorColor = 0
    local dashboardColor = 0
    local xenonColor = 255

    if vehicle then
        primaryColor, secondaryColor = GetVehicleColours(vehicle)
        primaryPaintType = select(1, GetVehicleModColor_1(vehicle)) or 0
        pearlescentColor = select(1, GetVehicleExtraColours(vehicle)) or 0
        interiorColor = GetVehicleInteriorColour(vehicle) or 0
        dashboardColor = GetVehicleDashboardColour(vehicle) or 0
        xenonColor = GetVehicleXenonLightsColour(vehicle)
        if xenonColor == nil or xenonColor < 0 then
            xenonColor = 255
        end
    end

    local categoryIndex = getPaintCategoryIndexByState(primaryPaintType, primaryColor)

    paintCategoryListItem:Index(categoryIndex)

    rebuildPaintColorList(primaryPaintColorListItem, categoryIndex, "primary")
    rebuildPaintColorList(secondaryPaintColorListItem, categoryIndex, "secondary")

    primaryPaintColorListItem:Index(findColorIndex(currentPrimaryColorOptions, primaryColor))
    secondaryPaintColorListItem:Index(findColorIndex(currentSecondaryColorOptions, secondaryColor))
    pearlescentColorListItem:Index(findColorIndex(extraColorOptions, pearlescentColor))
    interiorColorListItem:Index(findColorIndex(extraColorOptions, interiorColor))
    dashboardColorListItem:Index(findColorIndex(extraColorOptions, dashboardColor))
    xenonColorListItem:Index(findColorIndex(xenonColorOptions, xenonColor))
    rebuildLiveryList(vehicle)
    liveryListItem:Index(findLiveryIndex(vehicle))
end

local function updateVehicleAvailabilityState(forceRefresh)
    local hasVehicle = getCurrentVehicle(false) ~= nil
    local hasDriverVehicle = getCurrentVehicle(true) ~= nil
    local stateChanged = hasVehicle ~= availabilityState.hasVehicle or hasDriverVehicle ~= availabilityState.hasDriverVehicle
    if not forceRefresh and not stateChanged then
        return
    end

    availabilityState.hasVehicle = hasVehicle
    availabilityState.hasDriverVehicle = hasDriverVehicle

    setItemsEnabled(vehicleRequiredItems, hasVehicle)
    setItemsEnabled(driverRequiredItems, hasDriverVehicle)

    refreshVehicleCustomizationLists()
    refreshWheelControls()
    rebuildPartsMenu()
    rebuildStatsMenu()
    refreshPerformanceSettingsMenu()

    vehicleMenuPool:RefreshIndex()
end

local function fixCurrentVehicle()
    local vehicle = getCurrentVehicle(true)
    if not vehicle then
        return
    end

    SetVehicleFixed(vehicle)
    SetVehicleDeformationFixed(vehicle)
    SetVehicleUndriveable(vehicle, false)
    SetVehicleEngineHealth(vehicle, 1000.0)
    SetVehicleBodyHealth(vehicle, 1000.0)
    SetVehiclePetrolTankHealth(vehicle, 1000.0)
    SetVehicleDirtLevel(vehicle, 0.0)
    SetVehicleEngineOn(vehicle, true, true, false)
end

local function teleportVehicleToNearestRoad()
    local vehicle = getCurrentVehicle(true)
    if not vehicle then
        return
    end

    local coords = GetEntityCoords(vehicle)
    local found, roadCoords, roadHeading = GetClosestVehicleNodeWithHeading(coords.x, coords.y, coords.z, 1, 3.0, 0)
    if not found or not roadCoords then
        return
    end

    SetEntityCoords(vehicle, roadCoords.x, roadCoords.y, roadCoords.z + 1.0, false, false, false, false)
    SetEntityHeading(vehicle, roadHeading or GetEntityHeading(vehicle))
    SetVehicleOnGroundProperly(vehicle)
end

local function runUtilityDeleteVehicleSequence()
    local ped = PlayerPedId()
    local vehicle = getCurrentVehicle(true)
    if not vehicle or not DoesEntityExist(vehicle) or not DoesEntityExist(ped) then
        return
    end

    local vehicleKey = tostring(NetworkGetNetworkIdFromEntity(vehicle) or vehicle)
    if pendingUtilityDeleteByVehicle[vehicleKey] then
        return
    end
    pendingUtilityDeleteByVehicle[vehicleKey] = true

    local baseCoords = GetEntityCoords(vehicle)
    local baseHeading = GetEntityHeading(vehicle)
    local vehicleModel = GetEntityModel(vehicle)
    local minBounds, maxBounds = GetModelDimensions(vehicleModel)
    local vehicleLength = math.abs((maxBounds.y or 0.0) - (minBounds.y or 0.0))
    local exitDistance = vehicleLength + 2.0
    local exitCoords = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -exitDistance, 0.0)

    TaskLeaveVehicle(ped, vehicle, 16)
    ClearPedTasksImmediately(ped)
    SetEntityCoordsNoOffset(ped, exitCoords.x, exitCoords.y, exitCoords.z, false, false, false)
    SetEntityHeading(ped, baseHeading)

    SetVehicleEngineOn(vehicle, false, true, false)
    SetVehicleHandbrake(vehicle, true)
    SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)
    SetEntityCollision(vehicle, false, false)
    FreezeEntityPosition(vehicle, true)

    CreateThread(function()
        local startTime = GetGameTimer()
        local durationMs = 5000
        local initialLiftSpeed = 3.0
        local liftAcceleration = 6.0

        while DoesEntityExist(vehicle) do
            local elapsed = GetGameTimer() - startTime
            if elapsed >= durationMs then
                break
            end

            local elapsedSeconds = elapsed / 1000.0
            local verticalOffset = (initialLiftSpeed * elapsedSeconds) + (0.5 * liftAcceleration * elapsedSeconds * elapsedSeconds)
            SetEntityCoordsNoOffset(vehicle, baseCoords.x, baseCoords.y, baseCoords.z + verticalOffset, false, false, false)
            Wait(0)
        end

        if DoesEntityExist(vehicle) then
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteVehicle(vehicle)
            if DoesEntityExist(vehicle) then
                DeleteEntity(vehicle)
            end
        end

        pendingUtilityDeleteByVehicle[vehicleKey] = nil
        updateVehicleAvailabilityState(true)
    end)
end

local function getVehicleDisplayName(model)
    local displayName = GetDisplayNameFromVehicleModel(model)
    if not displayName or displayName == "" then
        return tostring(model)
    end

    return displayName
end

local function iterateVehicleState(vehicle, mapping, stateReader)
    local output = {}
    for index, name in pairs(mapping) do
        output[name] = stateReader(vehicle, index)
    end
    return output
end

local function getCustomColor(getter, isCustom)
    if not isCustom then
        return nil
    end

    local r, g, b = getter()
    return {
        r = r,
        g = g,
        b = b,
    }
end

local function getNeonState(vehicle)
    local r, g, b = GetVehicleNeonLightsColour(vehicle)

    return {
        left = IsVehicleNeonLightEnabled(vehicle, 0),
        right = IsVehicleNeonLightEnabled(vehicle, 1),
        front = IsVehicleNeonLightEnabled(vehicle, 2),
        back = IsVehicleNeonLightEnabled(vehicle, 3),
        color = {
            r = r,
            g = g,
            b = b,
        },
    }
end

local function getVehicleExtras(vehicle)
    local extras = {}

    for extraId = 0, 60 do
        if DoesExtraExist(vehicle, extraId) then
            extras[tostring(extraId)] = IsVehicleExtraTurnedOn(vehicle, extraId)
        end
    end

    return extras
end

local function getVehicleMods(vehicle)
    local mods = {}

    for modType = 0, 49 do
        if modType >= 17 and modType <= 22 then
            local enabled = IsToggleModOn(vehicle, modType)
            if enabled then
                mods[tostring(modType)] = {
                    type = "toggle",
                    enabled = true,
                }
            end
        else
            local modIndex = GetVehicleMod(vehicle, modType)
            local variation = GetVehicleModVariation(vehicle, modType)
            if modIndex ~= -1 or variation == true then
                mods[tostring(modType)] = {
                    type = "index",
                    index = modIndex,
                    variation = variation == true,
                }
            end
        end
    end

    return mods
end

local DOOR_MAPPING = ConstantConfig.DOOR_MAPPING
local TYRE_MAPPING = ConstantConfig.TYRE_MAPPING

local function getVehicleDoorState(vehicle)
    local doorState = {
        open = iterateVehicleState(vehicle, DOOR_MAPPING, function(v, i) return GetVehicleDoorAngleRatio(v, i) > 0.01 end),
        broken = iterateVehicleState(vehicle, DOOR_MAPPING, function(v, i) return IsVehicleDoorDamaged(v, i) end)
    }

    return doorState
end

local function getVehicleTyreState(vehicle)
    return iterateVehicleState(vehicle, TYRE_MAPPING, function(v, i) return IsVehicleTyreBurst(v, i, false) end)
end

local function getVehicleProofs(vehicle)
    local bulletProof, fireProof, explosionProof, collisionProof, meleeProof, steamProof, p7, drownProof = GetEntityProofs(vehicle)

    return {
        bulletProof = bulletProof,
        fireProof = fireProof,
        explosionProof = explosionProof,
        collisionProof = collisionProof,
        meleeProof = meleeProof,
        steamProof = steamProof,
        unknownProof7 = p7,
        drownProof = drownProof,
    }
end

local function waitForVehicleOwnership(vehicle, timeoutMs)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end

    if not NetworkGetEntityIsNetworked(vehicle) then
        NetworkRegisterEntityAsNetworked(vehicle)
    end

    local timeoutAt = GetGameTimer() + (timeoutMs or 2000)
    while GetGameTimer() < timeoutAt do
        if NetworkGetEntityIsNetworked(vehicle) then
            local netId = NetworkGetNetworkIdFromEntity(vehicle)
            if netId and netId ~= 0 then
                return true
            end
        end

        Wait(0)
    end

    return NetworkGetEntityIsNetworked(vehicle)
end

local ensureVehicleNetworked = waitForVehicleOwnership
local waitForVehicleNetworkState = waitForVehicleOwnership

local TUNING_SELECTION_SCHEMA = ConstantConfig.TUNING_SELECTION_SCHEMA

local function roundToThreeDecimals(value, fallback)
    local numeric = tonumber(value)
    if numeric == nil then
        return fallback
    end

    if numeric >= 0 then
        return math.floor((numeric * 1000.0) + 0.5) / 1000.0
    end

    return math.ceil((numeric * 1000.0) - 0.5) / 1000.0
end

local function cleanModSelectionMap(source)
    if type(source) ~= "table" then
        return nil
    end

    local normalized = {}
    for key, value in pairs(source) do
        normalized[key] = value
    end

    return normalized
end

local function normalizeTuningSelectionMap(source)
    local canonical = cleanModSelectionMap(source)
    if type(canonical) ~= "table" then
        return nil
    end

    local normalized = {}
    for index = 1, #TUNING_SELECTION_SCHEMA do
        local entry = TUNING_SELECTION_SCHEMA[index]
        normalized[entry.key] = entry.parse(canonical[entry.key])
    end

    normalized.nitrousShotStrength = roundToThreeDecimals(normalized.nitrousShotStrength, 1.0) or 1.0
    normalized.antirollForce = roundToThreeDecimals(normalized.antirollForce, 0.0) or 0.0
    normalized.brakeBiasFront = roundToThreeDecimals(normalized.brakeBiasFront, 0.5) or 0.5
    normalized.gripBiasFront = roundToThreeDecimals(normalized.gripBiasFront, 0.5) or 0.5
    normalized.antirollBiasFront = roundToThreeDecimals(normalized.antirollBiasFront, 0.5) or 0.5
    normalized.suspensionRaise = roundToThreeDecimals(normalized.suspensionRaise, 0.0) or 0.0
    normalized.suspensionBiasFront = roundToThreeDecimals(normalized.suspensionBiasFront, 0.5) or 0.5
    normalized.cgOffsetTweak = roundToThreeDecimals(normalized.cgOffsetTweak, 0.0) or 0.0

    return normalized
end

local normalizeSelectionMap = cleanModSelectionMap

local function serializeTuningSelections(tuneState)
    local normalizedSelections = normalizeTuningSelectionMap(tuneState)
    if type(normalizedSelections) ~= "table" then
        return nil
    end

    return {
        version = 1,
        selections = normalizedSelections
    }
end

local function deserializeTuningSelections(savedTuning)
    local selections = type(savedTuning) == "table" and savedTuning.selections or nil
    return normalizeTuningSelectionMap(selections)
end

local function getVehicleTuningState(vehicle)
    if not ensureVehicleNetworked(vehicle, 1500) then
        return nil
    end

    local entityState = Entity(vehicle).state
    if not entityState then
        return nil
    end

    local tuneState = entityState[TUNE_STATE_BAG_KEY]
    if type(tuneState) ~= "table" then
        return nil
    end

    return serializeTuningSelections(tuneState)
end

local function applyVehicleTuningState(vehicle, tuningState)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or type(tuningState) ~= "table" then
        return
    end

    if not ensureVehicleNetworked(vehicle, 2000) then
        return
    end

    local entityState = Entity(vehicle).state
    if not entityState then
        return
    end

    local normalizedTuneState = nil

    if type(tuningState.tuneState) == "table" then
        normalizedTuneState = normalizeTuningSelectionMap(tuningState.tuneState)
    else
        normalizedTuneState = deserializeTuningSelections(tuningState)
    end

    if type(normalizedTuneState) == "table" then
        entityState:set(TUNE_STATE_BAG_KEY, normalizedTuneState, true)
    end

end

local function setVehicleSaveIdState(vehicle, saveId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or type(saveId) ~= "string" or saveId == "" then
        return
    end

    if not ensureVehicleNetworked(vehicle, 1500) then
        return
    end

    local entityState = Entity(vehicle).state
    if not entityState then
        return
    end

    entityState:set(SAVE_ID_STATE_BAG_KEY, saveId, true)
end

local function getVehicleSaveIdState(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil
    end

    if not ensureVehicleNetworked(vehicle, 1500) then
        return nil
    end

    local entityState = Entity(vehicle).state
    if not entityState then
        return nil
    end

    local saveId = entityState[SAVE_ID_STATE_BAG_KEY]
    if type(saveId) ~= "string" or saveId == "" then
        return nil
    end

    return saveId
end

local function promptForSaveId(defaultValue)
    AddTextEntry("VEHICLEMANAGER_SAVE_ID", "Enter saved vehicle name")
    DisplayOnscreenKeyboard(1, "VEHICLEMANAGER_SAVE_ID", "", defaultValue or "", "", "", "", 40)

    while UpdateOnscreenKeyboard() == 0 do
        Wait(0)
    end

    if UpdateOnscreenKeyboard() ~= 1 then
        return nil
    end

    local result = GetOnscreenKeyboardResult()
    if not result or result == "" then
        return nil
    end

    return result
end

local function requestModel(model)
    if not IsModelInCdimage(model) or not IsModelAVehicle(model) then
        return false
    end

    RequestModel(model)
    local timeoutAt = GetGameTimer() + 10000

    while not HasModelLoaded(model) do
        if GetGameTimer() >= timeoutAt then
            return false
        end

        Wait(0)
    end

    return true
end


local function setVehicleModEntry(vehicle, modType, modData)
    if type(modData) ~= "table" then
        return
    end

    if modData.type == "toggle" then
        ToggleVehicleMod(vehicle, modType, modData.enabled == true)
        return
    end

    SetVehicleMod(vehicle, modType, modData.index or -1, modData.variation == true)
end

local function applySavedVehicleColours(vehicle, colourData)
    if type(colourData) ~= "table" then
        return
    end

    SetVehicleColours(vehicle, colourData.primary or 0, colourData.secondary or 0)
    SetVehicleExtraColours(vehicle, colourData.pearl or 0, colourData.rim or 0)

    if type(colourData.modColor1) == "table" then
        SetVehicleModColor_1(vehicle, colourData.modColor1.paintType or 0, colourData.modColor1.color or 0, colourData.modColor1.pearlescent or 0)
    end

    if type(colourData.modColor2) == "table" then
        SetVehicleModColor_2(vehicle, colourData.modColor2.paintType or 0, colourData.modColor2.color or 0)
    end

    if colourData.isPrimaryColourCustom and type(colourData.customPrimary) == "table" then
        SetVehicleCustomPrimaryColour(vehicle, colourData.customPrimary.r or 0, colourData.customPrimary.g or 0, colourData.customPrimary.b or 0)
    else
        ClearVehicleCustomPrimaryColour(vehicle)
    end

    if colourData.isSecondaryColourCustom and type(colourData.customSecondary) == "table" then
        SetVehicleCustomSecondaryColour(vehicle, colourData.customSecondary.r or 0, colourData.customSecondary.g or 0, colourData.customSecondary.b or 0)
    else
        ClearVehicleCustomSecondaryColour(vehicle)
    end

    if type(colourData.tyreSmoke) == "table" then
        SetVehicleTyreSmokeColor(vehicle, colourData.tyreSmoke.r or 255, colourData.tyreSmoke.g or 255, colourData.tyreSmoke.b or 255)
    end

    if colourData.interior ~= nil then
        SetVehicleInteriorColour(vehicle, colourData.interior)
    end

    if colourData.dashboard ~= nil then
        SetVehicleDashboardColour(vehicle, colourData.dashboard)
    end

    if colourData.xenonHeadlights ~= nil then
        SetVehicleXenonLightsColor(vehicle, colourData.xenonHeadlights)
    end
end

local function applySavedVehicleNeons(vehicle, neonData)
    if type(neonData) ~= "table" then
        return
    end

    SetVehicleNeonLightEnabled(vehicle, 0, neonData.left == true)
    SetVehicleNeonLightEnabled(vehicle, 1, neonData.right == true)
    SetVehicleNeonLightEnabled(vehicle, 2, neonData.front == true)
    SetVehicleNeonLightEnabled(vehicle, 3, neonData.back == true)

    if type(neonData.color) == "table" then
        SetVehicleNeonLightsColour(vehicle, neonData.color.r or 255, neonData.color.g or 255, neonData.color.b or 255)
    end
end

local function applySavedVehicleExtras(vehicle, extrasData)
    if type(extrasData) ~= "table" then
        return
    end

    for extraId, enabled in pairs(extrasData) do
        local numericExtraId = tonumber(extraId)
        if numericExtraId and DoesExtraExist(vehicle, numericExtraId) then
            SetVehicleExtra(vehicle, numericExtraId, enabled and 0 or 1)
        end
    end
end

local function applySavedVehicleMods(vehicle, modsData)
    if type(modsData) ~= "table" then
        return
    end

    for modType, modData in pairs(modsData) do
        local numericModType = tonumber(modType)
        if numericModType then
            setVehicleModEntry(vehicle, numericModType, modData)
        end
    end
end

local function applySavedVehicleDoorState(vehicle, doorState)
    if type(doorState) ~= "table" then
        return
    end

    local doorNames = {
        frontLeftDoor = 0,
        frontRightDoor = 1,
        backLeftDoor = 2,
        backRightDoor = 3,
        hood = 4,
        trunk = 5,
        trunk2 = 6,
    }

    if type(doorState.open) == "table" then
        for doorName, isOpen in pairs(doorState.open) do
            local doorIndex = doorNames[doorName]
            if doorIndex then
                if isOpen then
                    SetVehicleDoorOpen(vehicle, doorIndex, false, true)
                else
                    SetVehicleDoorShut(vehicle, doorIndex, true)
                end
            end
        end
    end

    if type(doorState.broken) == "table" then
        for doorName, isBroken in pairs(doorState.broken) do
            local doorIndex = doorNames[doorName]
            if doorIndex and isBroken then
                SetVehicleDoorBroken(vehicle, doorIndex, true)
            end
        end
    end
end

local function applySavedVehicleTyres(vehicle, tyreData)
    if type(tyreData) ~= "table" then
        return
    end

    local tyreNames = {
        frontLeft = 0,
        frontRight = 1,
        middleLeft = 2,
        middleRight = 3,
        backLeft = 4,
        backRight = 5,
        extra6 = 6,
        extra7 = 7,
        extra8 = 8,
    }

    for tyreName, isBursted in pairs(tyreData) do
        local tyreIndex = tyreNames[tyreName]
        if tyreIndex and isBursted then
            SetVehicleTyreBurst(vehicle, tyreIndex, false, 1000.0)
        end
    end
end

local function applySavedVehicleEntityState(vehicle, vehicleData)
    if type(vehicleData) ~= "table" then
        return
    end

    if vehicleData.opacityLevel and vehicleData.opacityLevel < 255 then
        SetEntityAlpha(vehicle, vehicleData.opacityLevel, false)
    else
        ResetEntityAlpha(vehicle)
    end

    if vehicleData.lodDistance ~= nil then
        SetEntityLodDist(vehicle, vehicleData.lodDistance)
    end

    if vehicleData.isVisible == false then
        SetEntityVisible(vehicle, false, false)
    else
        SetEntityVisible(vehicle, true, false)
    end

    if vehicleData.maxHealth ~= nil then
        SetEntityMaxHealth(vehicle, vehicleData.maxHealth)
    end

    if vehicleData.health ~= nil then
        SetEntityHealth(vehicle, vehicleData.health)
    end

    if vehicleData.isOnFire then
        StartEntityFire(vehicle)
    end

    if type(vehicleData.proofs) == "table" then
        SetEntityProofs(
            vehicle,
            vehicleData.proofs.bulletProof == true,
            vehicleData.proofs.fireProof == true,
            vehicleData.proofs.explosionProof == true,
            vehicleData.proofs.collisionProof == true,
            vehicleData.proofs.meleeProof == true,
            vehicleData.proofs.steamProof == true,
            vehicleData.proofs.unknownProof7 == true,
            vehicleData.proofs.drownProof == true
        )
    end
end

local function spawnSavedVehicle(savedData)
    if type(savedData) ~= "table" or type(savedData.vehicle) ~= "table" then
        return
    end

    local identity = savedData.identity or {}
    local savedVehicle = savedData.vehicle
    local vehicleProperties = savedVehicle.vehicleProperties or {}
    local model = savedVehicle.modelHash or identity.model
    if not model or not requestModel(model) then
        return
    end

    local ped = PlayerPedId()
    local spawnCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 5.0, 0.0)
    local heading = GetEntityHeading(ped) + 90.0
    local spawnedVehicle = CreateVehicle(model, spawnCoords.x, spawnCoords.y, spawnCoords.z, heading, true, false)

    if spawnedVehicle == 0 or not DoesEntityExist(spawnedVehicle) then
        SetModelAsNoLongerNeeded(model)
        return
    end

    SetEntityVisible(spawnedVehicle, true, false)
    SetEntityAlpha(spawnedVehicle, 0, false)
    SetVehicleOnGroundProperly(spawnedVehicle)
    SetVehicleModKit(spawnedVehicle, 0)

    applySavedVehicleColours(spawnedVehicle, vehicleProperties.colours)

    if vehicleProperties.livery ~= nil then
        SetVehicleLivery(spawnedVehicle, vehicleProperties.livery)
    end

    if vehicleProperties.roofLivery ~= nil then
        SetVehicleRoofLivery(spawnedVehicle, vehicleProperties.roofLivery)
    end

    local resolvedPlateText = identity.plate
    if resolvedPlateText ~= nil then
        SetVehicleNumberPlateText(spawnedVehicle, tostring(resolvedPlateText))
    end

    if vehicleProperties.numberPlateIndex ~= nil then
        SetVehicleNumberPlateTextIndex(spawnedVehicle, vehicleProperties.numberPlateIndex)
    end

    if vehicleProperties.wheelType ~= nil then
        SetVehicleWheelType(spawnedVehicle, vehicleProperties.wheelType)
    end

    if vehicleProperties.windowTint ~= nil then
        SetVehicleWindowTint(spawnedVehicle, vehicleProperties.windowTint)
    end

    if vehicleProperties.bulletProofTyres ~= nil then
        SetVehicleTyresCanBurst(spawnedVehicle, not vehicleProperties.bulletProofTyres)
    end

    if vehicleProperties.sirenActive ~= nil then
        SetVehicleSiren(spawnedVehicle, vehicleProperties.sirenActive == true)
    end

    if vehicleProperties.lockStatus ~= nil then
        SetVehicleDoorsLocked(spawnedVehicle, vehicleProperties.lockStatus)
    end

    applySavedVehicleNeons(spawnedVehicle, vehicleProperties.neons)
    applySavedVehicleExtras(spawnedVehicle, vehicleProperties.modExtras)
    applySavedVehicleMods(spawnedVehicle, vehicleProperties.mods)

    if vehicleProperties.engineOn ~= nil then
        SetVehicleEngineOn(spawnedVehicle, vehicleProperties.engineOn == true, true, false)
    end

    -- Virtual garage behavior: always deliver pristine.
    SetVehicleFixed(spawnedVehicle)
    SetVehicleDeformationFixed(spawnedVehicle)
    SetVehicleUndriveable(spawnedVehicle, false)
    SetVehicleEngineHealth(spawnedVehicle, 1000.0)
    SetVehicleBodyHealth(spawnedVehicle, 1000.0)
    SetVehiclePetrolTankHealth(spawnedVehicle, 1000.0)
    SetVehicleDirtLevel(spawnedVehicle, 0.0)

    CreateThread(function()
        if not waitForVehicleNetworkState(spawnedVehicle, 4000) then
            return
        end

        for _ = 1, 8 do
            if not DoesEntityExist(spawnedVehicle) then
                return
            end

            applyVehicleTuningState(spawnedVehicle, savedData.tuning)
            if type(savedData.saveId) == "string" and savedData.saveId ~= "" then
                setVehicleSaveIdState(spawnedVehicle, savedData.saveId)
            end

            Wait(250)
        end
    end)

    CreateThread(function()
        local fadeDurationMs = 500
        local fadeStartTime = GetGameTimer()

        while DoesEntityExist(spawnedVehicle) do
            local elapsed = GetGameTimer() - fadeStartTime
            if elapsed >= fadeDurationMs then
                break
            end

            local progress = elapsed / fadeDurationMs
            local alpha = math.floor(progress * 255.0 + 0.5)
            SetEntityAlpha(spawnedVehicle, math.max(0, math.min(255, alpha)), false)
            Wait(0)
        end

        if DoesEntityExist(spawnedVehicle) then
            ResetEntityAlpha(spawnedVehicle)
            SetVehicleDoorOpen(spawnedVehicle, 0, false, false)
            Wait(1000)
            if DoesEntityExist(spawnedVehicle) then
                SetVehicleDoorOpen(spawnedVehicle, 0, true, false)
            end
        end
    end)
    SetVehicleOnGroundProperly(spawnedVehicle)
    SetModelAsNoLongerNeeded(model)
end

local function buildSavedVehicleLabel(entry)
    local piValue = tonumber(entry and entry.pi)
    local piLabel = piValue and tostring(math.max(0, math.floor(piValue + 0.5))) or "--"
    local colorLabel = tostring((entry and (entry.primaryColorLabel or entry.colorLabel)) or (TextConfig.unknownColorLabel or "Unknown"))
    local vehicleName = tostring((entry and (entry.localizedName or entry.displayName)) or "Saved Vehicle")
    local plateText = tostring((entry and entry.plate) or "")
    local savedAtText = tostring((entry and entry.savedAt) or "")
    local compactSavedAt = savedAtText ~= "" and savedAtText:gsub("T", " "):gsub("Z", " UTC") or ""
    local platePart = plateText ~= "" and (" | Plate %s"):format(plateText) or ""
    local savedPart = compactSavedAt ~= "" and (" | %s"):format(compactSavedAt) or ""
    return ("%s | %s %s%s%s"):format(piLabel, colorLabel, vehicleName, platePart, savedPart)
end

local function hasExistingSaveId(saveId)
    local normalized = tostring(saveId or ""):lower()
    if normalized == "" then
        return false
    end
    for index = 1, #savedVehicleEntries do
        local entrySaveId = tostring(savedVehicleEntries[index] and savedVehicleEntries[index].saveId or ""):lower()
        if entrySaveId == normalized then
            return true
        end
    end
    return false
end

local function rebuildSavedVehicleMenu()
    saveLoadSubMenu.SubMenu:Clear()
    savedVehicleItems = {}
    deleteVehicleEntries = {}
    deleteVehicleItems = {}
    saveLoadSubMenu.SubMenu:AddItem(saveVehicleItem)
    if deleteVehiclesSubMenu and deleteVehiclesSubMenu.Item then
        saveLoadSubMenu.SubMenu:AddItem(deleteVehiclesSubMenu.Item)
        if deleteVehiclesSubMenu.SubMenu then
            deleteVehiclesSubMenu.SubMenu:Clear()
            local emptyDeleteItem = VMUI.CreateItem("No Saved Vehicles", "")
            emptyDeleteItem:Enabled(false)
            deleteVehiclesSubMenu.SubMenu:AddItem(emptyDeleteItem)
        end
    end

    if #savedVehicleEntries <= 0 then
        if deleteVehiclesSubMenu and deleteVehiclesSubMenu.Item then
            deleteVehiclesSubMenu.Item:Enabled(false)
        end
        local emptyItem = VMUI.CreateItem("No Saved Vehicles", "")
        emptyItem:Enabled(false)
        saveLoadSubMenu.SubMenu:AddItem(emptyItem)
        vehicleMenuPool:RefreshIndex()
        return
    end

    for i = 1, #savedVehicleEntries do
        local entry = savedVehicleEntries[i]
        local item = VMUI.CreateItem(buildSavedVehicleLabel(entry), "")
        item.Activated = function()
            TriggerServerEvent("vehiclemanager:requestSavedVehiclePayload", entry.file)
        end
        saveLoadSubMenu.SubMenu:AddItem(item)
        savedVehicleItems[i] = item
        deleteVehicleEntries[#deleteVehicleEntries + 1] = entry
    end

    if deleteVehiclesSubMenu and deleteVehiclesSubMenu.SubMenu then
        deleteVehiclesSubMenu.Item:Enabled(#deleteVehicleEntries > 0)
        deleteVehiclesSubMenu.SubMenu:Clear()
        if #deleteVehicleEntries <= 0 then
            local emptyDeleteItem = VMUI.CreateItem("No Saved Vehicles", "")
            emptyDeleteItem:Enabled(false)
            deleteVehiclesSubMenu.SubMenu:AddItem(emptyDeleteItem)
        else
            for i = 1, #deleteVehicleEntries do
                local entry = deleteVehicleEntries[i]
                local deleteItem = VMUI.CreateColouredItem(buildSavedVehicleLabel(entry), "")
                deleteItem.Activated = function()
                    TriggerServerEvent("vehiclemanager:forgetSavedVehicle", entry.file)
                end
                deleteVehiclesSubMenu.SubMenu:AddItem(deleteItem)
                deleteVehicleItems[i] = deleteItem
            end
        end
    end

    vehicleMenuPool:RefreshIndex()
end

local function requestSavedVehicleIndex()
    TriggerServerEvent("vehiclemanager:requestSavedVehicleIndex")
end

local function buildVehicleSavePayload(vehicle)
    local model = GetEntityModel(vehicle)
    local primaryColor, secondaryColor = GetVehicleColours(vehicle)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
    local modColor1Type, modColor1Color, modColor1Pearlescent = GetVehicleModColor_1(vehicle)
    local modColor2Type, modColor2Color = GetVehicleModColor_2(vehicle)
    local plateText = GetVehicleNumberPlateText(vehicle)
    local displayName = getVehicleDisplayName(model)
    local localizedName = getLabelOrFallback(displayName, displayName)
    local performancePi = getVehiclePerformancePi(vehicle)
    local primaryColorLabel = getColorLabelById(primaryColor)
    local tyreSmokeR, tyreSmokeG, tyreSmokeB = GetVehicleTyreSmokeColor(vehicle)
    local isPrimaryCustom = GetIsVehiclePrimaryColourCustom(vehicle)
    local isSecondaryCustom = GetIsVehicleSecondaryColourCustom(vehicle)
    local customPrimaryColor = getCustomColor(function()
        return GetVehicleCustomPrimaryColour(vehicle)
    end, isPrimaryCustom)
    local customSecondaryColor = getCustomColor(function()
        return GetVehicleCustomSecondaryColour(vehicle)
    end, isSecondaryCustom)
    local tuningState = getVehicleTuningState(vehicle)
    local livery = GetVehicleLivery(vehicle)
    local roofLivery = GetVehicleRoofLivery(vehicle)
    return {
        source = "VehicleManager",
        schemaVersion = 1,
        format = {
            name = "VehicleManagerSavedVehicle",
            variant = "menyoo-inspired-json",
        },
        identity = {
            model = model,
            displayName = displayName,
            localizedName = localizedName,
            performancePi = performancePi,
            primaryColorLabel = primaryColorLabel,
            plate = plateText,
            plateIndex = GetVehicleNumberPlateTextIndex(vehicle),
            class = GetVehicleClass(vehicle),
        },
        vehicle = {
            modelHash = model,
            vehicleProperties = {
                colours = {
                    primary = primaryColor,
                    secondary = secondaryColor,
                    pearl = pearlescentColor,
                    rim = wheelColor,
                    modColor1 = {
                        paintType = modColor1Type,
                        color = modColor1Color,
                        pearlescent = modColor1Pearlescent,
                    },
                    modColor2 = {
                        paintType = modColor2Type,
                        color = modColor2Color,
                    },
                    isPrimaryColourCustom = isPrimaryCustom,
                    customPrimary = customPrimaryColor,
                    isSecondaryColourCustom = isSecondaryCustom,
                    customSecondary = customSecondaryColor,
                    tyreSmoke = {
                        r = tyreSmokeR,
                        g = tyreSmokeG,
                        b = tyreSmokeB,
                    },
                    interior = GetVehicleInteriorColour(vehicle),
                    dashboard = GetVehicleDashboardColour(vehicle),
                    xenonHeadlights = GetVehicleXenonLightsColour(vehicle),
                },
                livery = livery ~= -1 and livery or nil,
                roofLivery = roofLivery ~= -1 and roofLivery or nil,
                numberPlateIndex = GetVehicleNumberPlateTextIndex(vehicle),
                wheelType = GetVehicleWheelType(vehicle),
                windowTint = GetVehicleWindowTint(vehicle),
                bulletProofTyres = not GetVehicleTyresCanBurst(vehicle),
                sirenActive = IsVehicleSirenOn(vehicle),
                lockStatus = GetVehicleDoorLockStatus(vehicle),
                engineOn = GetIsVehicleEngineRunning(vehicle) == true,
                neons = getNeonState(vehicle),
                modExtras = getVehicleExtras(vehicle),
                mods = getVehicleMods(vehicle),
            },
        },
        tuning = tuningState,
    }
end

local function saveCurrentVehicle()
    local vehicle = getCurrentVehicle(true)
    if not vehicle then
        return
    end

    ensureVehicleNetworked(vehicle, 1500)

    local defaultSaveId = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    local saveId = promptForSaveId(defaultSaveId)
    if not saveId then
        return
    end
    if hasExistingSaveId(saveId) and pendingOverwriteSaveId ~= saveId then
        pendingOverwriteSaveId = saveId
        notify(("Save '%s' already exists. Press Save again to confirm overwrite."):format(saveId))
        return
    end
    pendingOverwriteSaveId = nil

    local payload = buildVehicleSavePayload(vehicle)
    payload.saveId = saveId
    setVehicleSaveIdState(vehicle, saveId)
    notify(("Saving vehicle as '%s'..."):format(saveId))

    TriggerServerEvent("vehiclemanager:saveVehicle", payload)
end

local function triggerSaveVehicleAction()
    if saveActionInFlight then
        return
    end

    saveActionInFlight = true
    saveCurrentVehicle()
    saveActionInFlight = false
end

saveVehicleItem.Activated = function()
    triggerSaveVehicleAction()
end

local function autosaveManagedVehicleToExistingSave()
    local vehicle = getCurrentVehicle(false)
    if not vehicle then
        return
    end

    local saveId = getVehicleSaveIdState(vehicle)
    if not saveId then
        return
    end

    local payload = buildVehicleSavePayload(vehicle)
    payload.saveId = saveId
    TriggerServerEvent("vehiclemanager:updateSavedVehicleSnapshot", saveId, payload)
end

scheduleVehicleTuningAutosave = function()
    pendingVehicleTuningAutosaveId = pendingVehicleTuningAutosaveId + 1
    local saveRequestId = pendingVehicleTuningAutosaveId

    CreateThread(function()
        Wait(VEHICLE_TUNING_AUTOSAVE_DELAY_MS)

        if saveRequestId ~= pendingVehicleTuningAutosaveId then
            return
        end

        autosaveManagedVehicleToExistingSave()
    end)
end

local function applyPaintColor(target, categoryIndex, colorIndex)
    local vehicle = getCurrentVehicle(false)
    local category = getPaintCategory(categoryIndex)
    local options = target == "primary" and currentPrimaryColorOptions or currentSecondaryColorOptions
    local option = options[colorIndex]
    if not vehicle or not option then
        return
    end

    SetVehicleModKit(vehicle, 0)

    local primaryColor, secondaryColor = GetVehicleColours(vehicle)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)

    if target == "primary" then
        SetVehicleColours(vehicle, option.colorId, secondaryColor)
        SetVehicleModColor_1(vehicle, category.paintType, option.colorId, pearlescentColor)
    else
        SetVehicleColours(vehicle, primaryColor, option.colorId)
        SetVehicleModColor_2(vehicle, category.paintType, option.colorId)
    end

    SetVehicleExtraColours(vehicle, pearlescentColor, wheelColor)
    scheduleVehicleTuningAutosave()
end

local function applyPearlescentColor(index)
    local vehicle = getCurrentVehicle(false)
    local option = extraColorOptions[index]
    if not vehicle or not option then
        return
    end

    local _, wheelColor = GetVehicleExtraColours(vehicle)
    SetVehicleExtraColours(vehicle, option.colorId, wheelColor)
    scheduleVehicleTuningAutosave()
end

local function applyInteriorColor(index)
    local vehicle = getCurrentVehicle(false)
    local option = extraColorOptions[index]
    if not vehicle or not option then
        return
    end

    SetVehicleInteriorColor(vehicle, option.colorId)
    scheduleVehicleTuningAutosave()
end

local function applyDashboardColor(index)
    local vehicle = getCurrentVehicle(false)
    local option = extraColorOptions[index]
    if not vehicle or not option then
        return
    end

    SetVehicleDashboardColor(vehicle, option.colorId)
    scheduleVehicleTuningAutosave()
end

local function pulseHeadlightControl(vehicle)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or GetVehiclePedIsIn(ped, false) ~= vehicle then
        return
    end

    CreateThread(function()
        for _ = 1, 3 do
            SetControlNormal(0, 74, 1.0)
            Wait(0)
        end

        SetControlNormal(0, 74, 0.0)
    end)
end

local function applyXenonColor(index)
    local vehicle = getCurrentVehicle(false)
    local option = xenonColorOptions[index]
    if not vehicle or not option then
        return
    end

    if option.colorId == 255 then
        SetVehicleXenonLightsColor(vehicle, 255)
    else
        local lightsOn, highbeamsOn = GetVehicleLightsState(vehicle)
        ToggleVehicleMod(vehicle, 22, true)
        SetVehicleXenonLightsColor(vehicle, option.colorId)
        if not lightsOn and not highbeamsOn then
            pulseHeadlightControl(vehicle)
        end
    end
    scheduleVehicleTuningAutosave()
end

local function applyWheelColor(index)
    local vehicle = getCurrentVehicle(false)
    local option = extraColorOptions[index]
    if not vehicle or not option then
        return
    end

    local pearlescentColor, _ = GetVehicleExtraColours(vehicle)
    SetVehicleExtraColours(vehicle, pearlescentColor, option.colorId)
    scheduleVehicleTuningAutosave()
end

local function applySelectedLivery(index)
    local vehicle = getCurrentVehicle(false)
    local option = currentLiveryOptions[index]
    if not vehicle or not option or not option.available then
        return
    end

    SetVehicleModKit(vehicle, 0)

    if option.mode == "native" then
        SetVehicleLivery(vehicle, option.value)
    elseif option.mode == "mod" then
        SetVehicleMod(vehicle, 48, option.value, false)
    end
    scheduleVehicleTuningAutosave()
end

vehicleMainMenu:AddItem(helpListItem)
customizeSubMenu = vehicleMenuPool:AddSubMenu(vehicleMainMenu, TextConfig.customizeVehicleLabel or "Customize Vehicle", TextConfig.customizeVehicleDescription or "Customization", true, true)
saveLoadSubMenu = vehicleMenuPool:AddSubMenu(vehicleMainMenu, TextConfig.saveLoadLabel or "Save / Load", TextConfig.saveLoadDescription or "These vehicles persist across sessions.", true, true)
deleteVehiclesSubMenu = vehicleMenuPool:AddSubMenu(saveLoadSubMenu.SubMenu, TextConfig.deleteVehicleLabel or "Delete Vehicle", TextConfig.deleteVehicleDescription or "~r~This action is permanent.", true, true)
performanceSettingsSubMenu = vehicleMenuPool:AddSubMenu(customizeSubMenu.SubMenu, TextConfig.performanceSettingsLabel or "Performance Settings", TextConfig.performanceSettingsDescription or "Adjust PI display and rev limiter behavior for your current vehicle.", true, true)
statsLocalSubMenu = vehicleMenuPool:AddSubMenu(customizeSubMenu.SubMenu, TextConfig.statsLabel or "Stats", TextConfig.statsDescription or "Open upgrade categories that affect vehicle performance stats.", true, true)
colorSubMenu = vehicleMenuPool:AddSubMenu(customizeSubMenu.SubMenu, TextConfig.colorLabel or "Color", TextConfig.colorDescription or "Change paint, pearlescent, interior, xenon, and livery options.", true, true)
partsSubMenu = vehicleMenuPool:AddSubMenu(customizeSubMenu.SubMenu, TextConfig.partsLabel or "Parts", TextConfig.partsDescription or "Browse available cosmetic body and interior part categories.", true, true)
wheelsSubMenu = vehicleMenuPool:AddSubMenu(customizeSubMenu.SubMenu, TextConfig.wheelsMenuLabel or "Wheels", TextConfig.wheelsMenuDescription or "Change wheel category, style, color, and custom tyre settings.", true, true)
performanceSettingsGatewayItem = performanceSettingsSubMenu.Item
performanceSettingsMenu = performanceSettingsSubMenu.SubMenu
statsGatewayItem = statsLocalSubMenu.Item
statsLocalMenu = statsLocalSubMenu.SubMenu
performanceSettingsGatewayItem.Activated = function(menu)
    refreshPerformanceSettingsMenu()
    menu:SwitchTo(performanceSettingsMenu, 1, true)
end
statsGatewayItem.Activated = function(menu)
    if GetResourceState("performancetuning") == "started" and tryOpenPerformanceTuningMenu() then
        customizeSubMenu.SubMenu:CurrentSelection(2)
        returnToCustomizeAfterPerformanceTuningClose = true
        vehicleMenuPool:CloseAllMenus()
        return
    end

    rebuildStatsMenu()
    menu:SwitchTo(statsLocalMenu, 1, true)
end
performanceSettingsMenu:AddItem(performancePiDisplayListItem)
performanceSettingsMenu:AddItem(performanceRevLimiterListItem)
saveLoadSubMenu.Item.Activated = function(menu)
    requestSavedVehicleIndex()
    menu:SwitchTo(saveLoadSubMenu.SubMenu, 1, true)
end
colorSubMenu.SubMenu:AddItem(paintCategoryListItem)
colorSubMenu.SubMenu:AddItem(primaryPaintColorListItem)
colorSubMenu.SubMenu:AddItem(secondaryPaintColorListItem)
colorSubMenu.SubMenu:AddItem(pearlescentColorListItem)
colorSubMenu.SubMenu:AddItem(interiorColorListItem)
colorSubMenu.SubMenu:AddItem(dashboardColorListItem)
colorSubMenu.SubMenu:AddItem(xenonColorListItem)
colorSubMenu.SubMenu:AddItem(liveryListItem)
wheelsSubMenu.SubMenu:AddItem(wheelCategoryListItem)
wheelsSubMenu.SubMenu:AddItem(wheelListItem)
wheelsSubMenu.SubMenu:AddItem(wheelColorListItem)
wheelsSubMenu.SubMenu:AddItem(customTyresItem)

registerDriverRequiredItem(helpListItem)
registerDriverRequiredItem(saveVehicleItem)
registerVehicleRequiredItem(customizeSubMenu.Item)
registerVehicleRequiredItem(performanceSettingsGatewayItem)
registerVehicleRequiredItem(colorSubMenu.Item)
registerVehicleRequiredItem(partsSubMenu.Item)
registerVehicleRequiredItem(statsGatewayItem)
registerVehicleRequiredItem(wheelsSubMenu.Item)
registerVehicleRequiredItem(performancePiDisplayListItem)
registerVehicleRequiredItem(performanceRevLimiterListItem)
registerVehicleRequiredItem(paintCategoryListItem)
registerVehicleRequiredItem(primaryPaintColorListItem)
registerVehicleRequiredItem(secondaryPaintColorListItem)
registerVehicleRequiredItem(pearlescentColorListItem)
registerVehicleRequiredItem(interiorColorListItem)
registerVehicleRequiredItem(dashboardColorListItem)
registerVehicleRequiredItem(xenonColorListItem)
registerVehicleRequiredItem(liveryListItem)
registerVehicleRequiredItem(wheelCategoryListItem)
registerVehicleRequiredItem(wheelListItem)
registerVehicleRequiredItem(wheelColorListItem)
registerVehicleRequiredItem(customTyresItem)

refreshWheelControls()
rebuildPartsMenu()
rebuildStatsMenu()
refreshPerformanceSettingsMenu()
rebuildSavedVehicleMenu()
saveLoadSubMenu.Item:RightLabel(">>>")
customizeSubMenu.Item:RightLabel(">>>")
performanceSettingsGatewayItem:RightLabel(">>>")
colorSubMenu.Item:RightLabel(">>>")
wheelsSubMenu.Item:RightLabel(">>>")
partsSubMenu.Item:RightLabel(">>>")
statsGatewayItem:RightLabel(">>>")
vehicleMenuPool:Add(vehicleMainMenu)
vehicleMenuPool:RefreshIndex()
updateVehicleAvailabilityState(true)

vehicleMainMenu.OnListSelect = function(_, item, index)
    if item ~= helpListItem then
        return
    end

    if index == 1 then
        fixCurrentVehicle()
    elseif index == 2 then
        teleportVehicleToNearestRoad()
    elseif index == 3 then
        runUtilityDeleteVehicleSequence()
    end
end

colorSubMenu.SubMenu.OnListChange = function(_, item, index)
    if item == paintCategoryListItem then
        rebuildPaintColorList(primaryPaintColorListItem, index, "primary")
        rebuildPaintColorList(secondaryPaintColorListItem, index, "secondary")
        primaryPaintColorListItem:Index(1)
        secondaryPaintColorListItem:Index(1)
    elseif item == primaryPaintColorListItem then
        applyPaintColor("primary", paintCategoryListItem:Index(), index)
    elseif item == secondaryPaintColorListItem then
        applyPaintColor("secondary", paintCategoryListItem:Index(), index)
    elseif item == pearlescentColorListItem then
        applyPearlescentColor(index)
    elseif item == interiorColorListItem then
        applyInteriorColor(index)
    elseif item == dashboardColorListItem then
        applyDashboardColor(index)
    elseif item == xenonColorListItem then
        applyXenonColor(index)
    elseif item == liveryListItem then
        applySelectedLivery(index)
    end
end

colorSubMenu.SubMenu.OnListSelect = function(_, item, index)
    if item == paintCategoryListItem then
        rebuildPaintColorList(primaryPaintColorListItem, index, "primary")
        rebuildPaintColorList(secondaryPaintColorListItem, index, "secondary")
        primaryPaintColorListItem:Index(1)
        secondaryPaintColorListItem:Index(1)
    elseif item == primaryPaintColorListItem then
        applyPaintColor("primary", paintCategoryListItem:Index(), index)
    elseif item == secondaryPaintColorListItem then
        applyPaintColor("secondary", paintCategoryListItem:Index(), index)
    elseif item == pearlescentColorListItem then
        applyPearlescentColor(index)
    elseif item == interiorColorListItem then
        applyInteriorColor(index)
    elseif item == dashboardColorListItem then
        applyDashboardColor(index)
    elseif item == xenonColorListItem then
        applyXenonColor(index)
    elseif item == liveryListItem then
        applySelectedLivery(index)
    end
end

colorSubMenu.SubMenu.OnMenuChanged = function(_, _, _)
    refreshVehicleCustomizationLists()
end

wheelsSubMenu.SubMenu.OnListChange = function(_, item, index)
    if item == wheelCategoryListItem then
        rebuildWheelList(index)
    elseif item == wheelListItem then
        applyWheelSelection(wheelCategoryListItem:Index(), index, customTyresItem:Checked() == true)
    elseif item == wheelColorListItem then
        applyWheelColor(index)
    end
end

wheelsSubMenu.SubMenu.OnListSelect = function(_, item, index)
    if item == wheelCategoryListItem then
        rebuildWheelList(index)
    elseif item == wheelListItem then
        applyWheelSelection(wheelCategoryListItem:Index(), index, customTyresItem:Checked() == true)
    elseif item == wheelColorListItem then
        applyWheelColor(index)
    end
end

wheelsSubMenu.SubMenu.OnCheckboxChange = function(_, item, checked)
    if item == customTyresItem then
        applyWheelSelection(wheelCategoryListItem:Index(), wheelListItem:Index(), checked)
    end
end

wheelsSubMenu.SubMenu.OnMenuChanged = function(_, _, _)
    refreshWheelControls()
end

partsSubMenu.SubMenu.OnListChange = function(_, item, index)
    applyModSelection(item, index, partsModEntries)
end

partsSubMenu.SubMenu.OnListSelect = function(_, item, index)
    applyModSelection(item, index, partsModEntries)
end

partsSubMenu.SubMenu.OnMenuChanged = function(_, _, _)
    rebuildPartsMenu()
end

performanceSettingsMenu.OnListChange = function(_, item, index)
    if item == performancePiDisplayListItem then
        setPerformanceTuningPiDisplayModeIndex(index)
    elseif item == performanceRevLimiterListItem then
        if setPerformanceTuningRevLimiterEnabled(index == 2) then
            scheduleVehicleTuningAutosave()
        end
    end
    syncMenuCurrentDescription(performanceSettingsMenu)
end

performanceSettingsMenu.OnListSelect = function(_, item, index)
    if item == performancePiDisplayListItem then
        setPerformanceTuningPiDisplayModeIndex(index)
    elseif item == performanceRevLimiterListItem then
        if setPerformanceTuningRevLimiterEnabled(index == 2) then
            scheduleVehicleTuningAutosave()
        end
    end
    syncMenuCurrentDescription(performanceSettingsMenu)
end

statsLocalMenu.OnListChange = function(_, item, index)
    applyModSelection(item, index, statsModEntries)
end

statsLocalMenu.OnListSelect = function(_, item, index)
    applyModSelection(item, index, statsModEntries)
end


vehicleMainMenu.OnMenuChanged = function(_, newmenu, forward)
    if forward and newmenu == saveLoadSubMenu.SubMenu then
        requestSavedVehicleIndex()
    elseif forward and newmenu == performanceSettingsMenu then
        refreshPerformanceSettingsMenu()
    elseif forward and newmenu == wheelsSubMenu.SubMenu then
        refreshWheelControls()
    elseif forward and newmenu == partsSubMenu.SubMenu then
        rebuildPartsMenu()
    elseif forward and newmenu == statsLocalMenu then
        rebuildStatsMenu()
    end
end

AddEventHandler("performancetuning:menuClosed", function()
    scheduleVehicleTuningAutosave()

    if not returnToCustomizeAfterPerformanceTuningClose then
        return
    end

    returnToCustomizeAfterPerformanceTuningClose = false

    if not customizeSubMenu or not customizeSubMenu.SubMenu then
        return
    end

    customizeSubMenu.SubMenu:Visible(true)
end)

RegisterNetEvent("vehiclemanager:receiveSavedVehicleIndex", function(entries)
    if type(entries) == "table" then
        savedVehicleEntries = entries
    else
        savedVehicleEntries = {}
    end

    rebuildSavedVehicleMenu()
end)

RegisterNetEvent("vehiclemanager:receiveSavedVehiclePayload", function(savedData)
    if type(savedData) ~= "table" then
        notify("Could not load saved vehicle payload.")
        return
    end

    spawnSavedVehicle(savedData)
    notify(("Loaded saved vehicle: %s"):format(tostring(savedData.saveId or "unknown")))
    rebuildPartsMenu()
    rebuildStatsMenu()
end)

RegisterNetEvent("vehiclemanager:vehicleSnapshotUpdated", function(saveId)
    local _ = saveId
    notifyPersistentVehicleUpdated(getCurrentVehicle(false))
end)

RegisterNetEvent("vehiclemanager:vehicleSaved", function(saveId)
    pendingOverwriteSaveId = nil
    if type(saveId) ~= "string" or saveId == "" then
        notify("Vehicle saved.")
    else
        notify(("Vehicle saved: %s"):format(saveId))
    end
    requestSavedVehicleIndex()
end)

RegisterCommand(MenuConfig.keybindCommand or "+vehiclemanager_menu", function()
    updateVehicleAvailabilityState(true)
    if not availabilityState.hasVehicle then
        notify("Get into a vehicle to use Vehicle Manager.")
    elseif not availabilityState.hasDriverVehicle then
        notify("Switch to the driver seat to use all Vehicle Manager actions.")
    end
    if MenuHandler:IsAnyMenuOpen() then
        vehicleMenuPool:CloseAllMenus()
    else
        vehicleMainMenu:Visible(true)
    end
end, false)

RegisterCommand(MENU_KEYBIND_RELEASE_COMMAND, function()
end, false)

RegisterKeyMapping(
    MenuConfig.keybindCommand or "+vehiclemanager_menu",
    MENU_KEYBIND_DESCRIPTION,
    "keyboard",
    MenuConfig.defaultKey or "F5"
)

CreateThread(function()
    local nextAvailabilityRefreshAt = 0

    while true do
        Wait(0)

        if GetGameTimer() >= nextAvailabilityRefreshAt then
            updateVehicleAvailabilityState(false)
            nextAvailabilityRefreshAt = GetGameTimer() + MENU_AVAILABILITY_REFRESH_MS
        end
    end
end)
