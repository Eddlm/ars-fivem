VehicleManager = VehicleManager or {}
VehicleManager.Client = VehicleManager.Client or {}
-- Config constants, defines runtime/static values --
local MenuConfig = (VehicleManager.Config or {}).menu or {}
local AppearanceConfig = (VehicleManager.Config or {}).appearance or {}
local CategoryConfig = (VehicleManager.Config or {}).categories or {}
local ConstantConfig = (VehicleManager.Config or {}).constants or {}
local UIConfig = (VehicleManager.Config or {}).ui or {}
local MENU_X_POSITION = tonumber(UIConfig.menuXPosition) or 20
local MENU_TITLE = tostring(UIConfig.menuTitle or "Vehicle Manager")
local MENU_SUBTITLE = tostring(UIConfig.menuSubtitle or "Fix, customize and save your vehicle")
local MENU_KEYBIND_RELEASE_COMMAND = tostring(UIConfig.menuKeybindReleaseCommand or "-vehiclemanager_menu")
local MENU_KEYBIND_DESCRIPTION = tostring(UIConfig.menuKeybindDescription or "Open the vehicle manager menu")
local MENU_AVAILABILITY_REFRESH_MS = math.max(0, math.floor(tonumber(UIConfig.menuAvailabilityRefreshMs) or 200))
local VEHICLE_TUNING_AUTOSAVE_DELAY_MS = 6000
local rawPiOptionLabels = UIConfig.performanceSettingsPiOptions or { "No", "Yes" }
local rawRevLimiterOptionLabels = UIConfig.performanceSettingsRevLimiterOptions or { "Off", "On" }

local function buildOptionLabels(options)
    local labels = {}
    for index = 1, #options do
        labels[index] = options[index].label
    end
    return labels
end






-- VM UI helpers, builds menu primitives --
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





-- Menu state, defines items and local caches --
local vehicleMenuPool = VMUI.CreatePool()
local vehicleMainMenu = VMUI.CreateMenu(MENU_TITLE, MENU_SUBTITLE, MENU_X_POSITION, 0, nil, nil, nil, 255, 255, 255, 210)

local helpOptions = {
    { name = "fixVehicle", label = "Fix Vehicle" },
    { name = "teleportNearestRoad", label = "Teleport To Nearest Road" },
    { name = "deleteVehicle", label = "Delete Vehicle" },
}
local helpOptionLabels = buildOptionLabels(helpOptions)
local performancePiOptions = {
    { name = "no", label = tostring(rawPiOptionLabels[1] or "No"), modeIndex = 1 },
    { name = "yes", label = tostring(rawPiOptionLabels[2] or "Yes"), modeIndex = 2 },
}
local performanceRevLimiterOptions = {
    { name = "off", label = tostring(rawRevLimiterOptionLabels[1] or "Off"), enabled = false },
    { name = "on", label = tostring(rawRevLimiterOptionLabels[2] or "On"), enabled = true },
}
local helpListItem = VMUI.CreateListItem("Util", helpOptionLabels, 1, nil)
local saveVehicleItem = VMUI.CreateItem("Save Vehicle", "")
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
local paintCategoryListItem = VMUI.CreateListItem("Paint Category", { "Classic" }, 1, "Choose the paint finish for your body colors.")
local primaryPaintColorListItem = VMUI.CreateListItem("Primary", { "Black" }, 1, "Set the main paint color.")
local secondaryPaintColorListItem = VMUI.CreateListItem("Secondary", { "Black" }, 1, "Set the secondary paint color.")
local pearlescentColorListItem = VMUI.CreateListItem("Pearlescent", { "Black" }, 1, "Add a pearl finish over the paint.")
local interiorColorListItem = VMUI.CreateListItem("Interior", { "Black" }, 1, "Change the interior color.")
local dashboardColorListItem = VMUI.CreateListItem("Dashboard", { "Black" }, 1, "Change the dashboard color.")
local xenonColorListItem = VMUI.CreateListItem("Xenon", { "Default" }, 1, "Set the xenon headlight color.")
local liveryListItem = VMUI.CreateListItem("Livery", { "No liveries available" }, 1, "Apply a livery if this vehicle supports one.")
local wheelCategoryListItem = VMUI.CreateListItem("Wheel Category", { "Sport" }, 1, "Choose a wheel family to browse.")
local wheelListItem = VMUI.CreateListItem("Wheel", { "Stock" }, 1, "Pick a wheel style from this category.")
local wheelColorListItem = VMUI.CreateListItem("Wheel Color", { "Black" }, 1, "Change the wheel color.")
local customTyresItem = UIMenuCheckboxItem.New("Custom Tyres", false, 1, "Toggle custom tyres for this wheel setup.")
customTyresItem.Activated = customTyresItem.Activated or function() end
local performancePiDisplayListItem = VMUI.CreateListItem("Compare with Nearby", buildOptionLabels(performancePiOptions), 1, "Show or hide nearby PI comparison panels.")
local performanceRevLimiterListItem = VMUI.CreateListItem("Rev Limiter", buildOptionLabels(performanceRevLimiterOptions), 1, "Turn the current vehicle's rev limiter behavior on or off.")

local cache = {
    currentPrimaryColorOptions = {},
    currentSecondaryColorOptions = {},
    currentLiveryOptions = {},
    currentWheelOptions = {},
    partsModItems = {},
    partsModEntries = {},
    statsModItems = {},
    statsModEntries = {},
    savedVehicleEntries = {},
    savedVehicleItems = {},
    deleteVehicleEntries = {},
    deleteVehicleItems = {},
    vehicleRequiredItems = {},
    driverRequiredItems = {},
}

local flow = {
    returnToCustomizeAfterPerformanceTuningClose = false,
    pendingVehicleTuningAutosaveId = 0,
    saveActionInFlight = false,
    pendingUtilityDeleteByVehicle = {},
    pendingOverwriteSaveId = nil,
}

local availabilityState = {
    hasVehicle = nil,
    hasDriverVehicle = nil,
}
-- State bag watchers, reacts to tuning/handling state changes --
local stateBagKeys = {
    tuneState = tostring(UIConfig.tuneStateBagKey or "performancetuning:tuneState"),
    handlingState = tostring(UIConfig.handlingStateBagKey or "performancetuning:handlingState"),
    saveId = tostring(UIConfig.saveIdStateBagKey or "vehiclemanager:saveId"),
}





AddStateBagChangeHandler(stateBagKeys.tuneState, nil, function(bagName, key, value)
    if type(VehicleManager.Client.getCurrentVehicle) ~= 'function' then
        return
    end

    local vehicle = VehicleManager.Client.getCurrentVehicle(false)
    if not vehicle then return end
    if GetEntityFromStateBagName(bagName) ~= vehicle then return end
    if type(VehicleManager.Client.scheduleVehicleTuningAutosave) == 'function' then
        VehicleManager.Client.scheduleVehicleTuningAutosave()
    end
end)

AddStateBagChangeHandler(stateBagKeys.handlingState, nil, function(bagName, key, value)
    if type(VehicleManager.Client.getCurrentVehicle) ~= 'function' then
        return
    end

    local vehicle = VehicleManager.Client.getCurrentVehicle(false)
    if not vehicle then return end
    if GetEntityFromStateBagName(bagName) ~= vehicle then return end
    if type(VehicleManager.Client.scheduleVehicleTuningAutosave) == 'function' then
        VehicleManager.Client.scheduleVehicleTuningAutosave()
    end
end)






-- Appearance bootstrap, builds paint/color option datasets --
local customization = nil
local modmenus = nil
local persistence = nil
local getColorLabelById = nil
local rebuildPaintColorList = nil
local rebuildLiveryList = nil
local rebuildWheelList = nil
local refreshWheelControls = nil
local applyWheelSelection = nil
local refreshVehicleCustomizationLists = nil
local applyPaintColor = nil
local applyPearlescentColor = nil
local applyInteriorColor = nil
local applyDashboardColor = nil
local applyXenonColor = nil
local applyWheelColor = nil
local applySelectedLivery = nil

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






-- Menu logic, handles vehicle state and customization flows --
local partsVehicleModCategories = CategoryConfig.partsVehicleModCategories or {}
local statsVehicleModCategories = CategoryConfig.statsVehicleModCategories or {}

function VehicleManager.Client.getCurrentVehicle(requireDriver)
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

if type((VehicleManager.Customization or {}).create) ~= "function" then
    error("vehiclemanager customization module is not available")
end

customization = VehicleManager.Customization.create({
    appearanceConfig = AppearanceConfig,
    categoryConfig = CategoryConfig,
    cache = cache,
    items = {
        paintCategoryListItem = paintCategoryListItem,
        primaryPaintColorListItem = primaryPaintColorListItem,
        secondaryPaintColorListItem = secondaryPaintColorListItem,
        pearlescentColorListItem = pearlescentColorListItem,
        interiorColorListItem = interiorColorListItem,
        dashboardColorListItem = dashboardColorListItem,
        xenonColorListItem = xenonColorListItem,
        liveryListItem = liveryListItem,
        wheelCategoryListItem = wheelCategoryListItem,
        wheelListItem = wheelListItem,
        wheelColorListItem = wheelColorListItem,
        customTyresItem = customTyresItem,
    },
    getDisplayLabel = getDisplayLabel,
    getCurrentVehicle = function(requireDriver)
        return VehicleManager.Client.getCurrentVehicle(requireDriver)
    end,
    scheduleAutosave = function()
        if type(VehicleManager.Client.scheduleVehicleTuningAutosave) == "function" then
            VehicleManager.Client.scheduleVehicleTuningAutosave()
        end
    end,
})

getColorLabelById = customization.getColorLabelById
rebuildPaintColorList = customization.rebuildPaintColorList
rebuildLiveryList = customization.rebuildLiveryList
rebuildWheelList = customization.rebuildWheelList
refreshWheelControls = customization.refreshWheelControls
applyWheelSelection = customization.applyWheelSelection
refreshVehicleCustomizationLists = customization.refreshVehicleCustomizationLists
applyPaintColor = customization.applyPaintColor
applyPearlescentColor = customization.applyPearlescentColor
applyInteriorColor = customization.applyInteriorColor
applyDashboardColor = customization.applyDashboardColor
applyXenonColor = customization.applyXenonColor
applyWheelColor = customization.applyWheelColor
applySelectedLivery = customization.applySelectedLivery

if type((VehicleManager.ModMenus or {}).create) ~= "function" then
    error("vehiclemanager modmenus module is not available")
end

modmenus = VehicleManager.ModMenus.create({
    vmui = VMUI,
    vehicleMenuPool = vehicleMenuPool,
    getCurrentVehicle = function(requireDriver)
        return VehicleManager.Client.getCurrentVehicle(requireDriver)
    end,
    getDisplayLabel = getDisplayLabel,
    scheduleAutosave = function()
        if type(VehicleManager.Client.scheduleVehicleTuningAutosave) == "function" then
            VehicleManager.Client.scheduleVehicleTuningAutosave()
        end
    end,
})

local function registerVehicleRequiredItem(item)
    if item then
        cache.vehicleRequiredItems[#cache.vehicleRequiredItems + 1] = item
    end
end

local function registerDriverRequiredItem(item)
    if item then
        cache.driverRequiredItems[#cache.driverRequiredItems + 1] = item
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

-- ModMenus extraction point:
-- 1) buildModCategoryDescription
-- 2) rebuildModMenu
-- 3) applyModSelection
-- Wrappers kept local: rebuildPartsMenu, rebuildStatsMenu.
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

    return math.max(1, math.min(#performancePiOptions, math.floor(tonumber(value) or 1)))
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

local function getPerformanceRevLimiterOptionIndex(enabled)
    for index = 1, #performanceRevLimiterOptions do
        if performanceRevLimiterOptions[index].enabled == enabled then
            return index
        end
    end

    return 1
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
        local description = "Get into a vehicle and take the driver seat to use this option."
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
    performanceRevLimiterListItem:Index(getPerformanceRevLimiterOptionIndex(revLimiterEnabled))
    if hasRevLimiterVehicle then
        clearItemDescription(performanceRevLimiterListItem)
    else
        setItemDescriptionRaw(performanceRevLimiterListItem, "Get into a vehicle and take the driver seat to use this option.")
        performanceRevLimiterListItem:Enabled(false)
    end

    syncMenuCurrentDescription(performanceSettingsMenu)
end

local function rebuildPartsMenu()
    cache.partsModItems, cache.partsModEntries = modmenus.rebuildModMenu(
        partsSubMenu,
        partsVehicleModCategories,
        "No parts available",
        "This vehicle doesn't have any customizable parts here.",
        false
    )
end

local function rebuildStatsMenu()
    cache.statsModItems, cache.statsModEntries = modmenus.rebuildModMenu(
        statsLocalMenu,
        statsVehicleModCategories,
        "No stats upgrades",
        "This vehicle doesn't have any upgrade options here.",
        true
    )
end

local function updateVehicleAvailabilityState(forceRefresh)
    local hasVehicle = VehicleManager.Client.getCurrentVehicle(false) ~= nil
    local hasDriverVehicle = VehicleManager.Client.getCurrentVehicle(true) ~= nil
    local stateChanged = hasVehicle ~= availabilityState.hasVehicle or hasDriverVehicle ~= availabilityState.hasDriverVehicle
    if not forceRefresh and not stateChanged then
        return
    end

    availabilityState.hasVehicle = hasVehicle
    availabilityState.hasDriverVehicle = hasDriverVehicle

    setItemsEnabled(cache.vehicleRequiredItems, hasVehicle)
    setItemsEnabled(cache.driverRequiredItems, hasDriverVehicle)

    refreshVehicleCustomizationLists()
    refreshWheelControls()
    rebuildPartsMenu()
    rebuildStatsMenu()
    refreshPerformanceSettingsMenu()

    vehicleMenuPool:RefreshIndex()
end

local function fixCurrentVehicle()
    local vehicle = VehicleManager.Client.getCurrentVehicle(true)
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
    local vehicle = VehicleManager.Client.getCurrentVehicle(true)
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
    local vehicle = VehicleManager.Client.getCurrentVehicle(true)
    if not vehicle or not DoesEntityExist(vehicle) or not DoesEntityExist(ped) then
        return
    end

    local vehicleKey = tostring(NetworkGetNetworkIdFromEntity(vehicle) or vehicle)
    if flow.pendingUtilityDeleteByVehicle[vehicleKey] then
        return
    end
    flow.pendingUtilityDeleteByVehicle[vehicleKey] = true

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

        flow.pendingUtilityDeleteByVehicle[vehicleKey] = nil
        updateVehicleAvailabilityState(true)
    end)
end






if type((VehicleManager.Persistence or {}).create) ~= "function" then
    error("vehiclemanager persistence module is not available")
end

persistence = VehicleManager.Persistence.create({
    cache = cache,
    flow = flow,
    stateBagKeys = stateBagKeys,
    constants = ConstantConfig,
    vmui = VMUI,
    vehicleMenuPool = vehicleMenuPool,
    getDisplayLabel = getDisplayLabel,
    getCurrentVehicle = function(requireDriver)
        return VehicleManager.Client.getCurrentVehicle(requireDriver)
    end,
    getVehiclePerformancePi = getVehiclePerformancePi,
    getColorLabelById = function(colorId)
        return getColorLabelById(colorId)
    end,
    notify = notify,
    notifyPersistentVehicleUpdated = notifyPersistentVehicleUpdated,
    requestSavedVehicleIndex = function()
        TriggerServerEvent("vehiclemanager:requestSavedVehicleIndex")
    end,
    scheduleAutosave = function()
        if type(VehicleManager.Client.scheduleVehicleTuningAutosave) == "function" then
            VehicleManager.Client.scheduleVehicleTuningAutosave()
        end
    end,
    triggerServerEvent = TriggerServerEvent,
})

-- Save/load pipeline, serializes and restores vehicle snapshots --
-- Persistence extraction boundary:
-- buildVehicleSavePayload / spawnSavedVehicle / rebuildSavedVehicleMenu
-- saveCurrentVehicle / autosaveManagedVehicleToExistingSave
-- setVehicleSaveIdState / getVehicleSaveIdState / getVehicleTuningState / applyVehicleTuningState

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

local function rebuildSavedVehicleMenu()
    persistence.rebuildSavedVehicleMenu(saveLoadSubMenu, deleteVehiclesSubMenu, saveVehicleItem)
end

local function requestSavedVehicleIndex()
    TriggerServerEvent("vehiclemanager:requestSavedVehicleIndex")
end

local function saveCurrentVehicle()
    persistence.saveCurrentVehicle(promptForSaveId)
end

local function triggerSaveVehicleAction()
    if flow.saveActionInFlight then
        return
    end

    flow.saveActionInFlight = true
    saveCurrentVehicle()
    flow.saveActionInFlight = false
end

saveVehicleItem.Activated = function()
    triggerSaveVehicleAction()
end

local function autosaveManagedVehicleToExistingSave()
    persistence.autosaveManagedVehicleToExistingSave()
end

function VehicleManager.Client.scheduleVehicleTuningAutosave()
    flow.pendingVehicleTuningAutosaveId = flow.pendingVehicleTuningAutosaveId + 1
    local saveRequestId = flow.pendingVehicleTuningAutosaveId

    CreateThread(function()
        Wait(VEHICLE_TUNING_AUTOSAVE_DELAY_MS)

        if saveRequestId ~= flow.pendingVehicleTuningAutosaveId then
            return
        end

        autosaveManagedVehicleToExistingSave()
    end)
end

-- Menu assembly, wires UI structure and callbacks --
vehicleMainMenu:AddItem(helpListItem)
customizeSubMenu = vehicleMenuPool:AddSubMenu(vehicleMainMenu, "Customize Vehicle", "Customization", true, true)
saveLoadSubMenu = vehicleMenuPool:AddSubMenu(vehicleMainMenu, "Save / Load", "These vehicles persist across sessions.", true, true)
deleteVehiclesSubMenu = vehicleMenuPool:AddSubMenu(saveLoadSubMenu.SubMenu, "Delete Vehicle", "~r~This action is permanent.", true, true)
performanceSettingsSubMenu = vehicleMenuPool:AddSubMenu(customizeSubMenu.SubMenu, "Performance Settings", "Tune assist settings.", true, true)
statsLocalSubMenu = vehicleMenuPool:AddSubMenu(customizeSubMenu.SubMenu, "Stats", "Performance upgrades.", true, true)
colorSubMenu = vehicleMenuPool:AddSubMenu(customizeSubMenu.SubMenu, "Color", "Paint and finish options.", true, true)
partsSubMenu = vehicleMenuPool:AddSubMenu(customizeSubMenu.SubMenu, "Parts", "Body and interior parts.", true, true)
wheelsSubMenu = vehicleMenuPool:AddSubMenu(customizeSubMenu.SubMenu, "Wheels", "Wheel style and setup.", true, true)
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
        flow.returnToCustomizeAfterPerformanceTuningClose = true
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

    local selectedOption = helpOptions[index]
    if not selectedOption then
        return
    end

    if selectedOption.name == "fixVehicle" then
        fixCurrentVehicle()
    elseif selectedOption.name == "teleportNearestRoad" then
        teleportVehicleToNearestRoad()
    elseif selectedOption.name == "deleteVehicle" then
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
    modmenus.applyModSelection(item, index, cache.partsModEntries)
end

partsSubMenu.SubMenu.OnListSelect = function(_, item, index)
    modmenus.applyModSelection(item, index, cache.partsModEntries)
end

partsSubMenu.SubMenu.OnMenuChanged = function(_, _, _)
    rebuildPartsMenu()
end

performanceSettingsMenu.OnListChange = function(_, item, index)
    if item == performancePiDisplayListItem then
        local option = performancePiOptions[index]
        if option then
            setPerformanceTuningPiDisplayModeIndex(option.modeIndex or index)
        end
    elseif item == performanceRevLimiterListItem then
        local option = performanceRevLimiterOptions[index]
        if option and setPerformanceTuningRevLimiterEnabled(option.enabled == true) then
            VehicleManager.Client.scheduleVehicleTuningAutosave()
        end
    end
    syncMenuCurrentDescription(performanceSettingsMenu)
end

performanceSettingsMenu.OnListSelect = function(_, item, index)
    if item == performancePiDisplayListItem then
        local option = performancePiOptions[index]
        if option then
            setPerformanceTuningPiDisplayModeIndex(option.modeIndex or index)
        end
    elseif item == performanceRevLimiterListItem then
        local option = performanceRevLimiterOptions[index]
        if option and setPerformanceTuningRevLimiterEnabled(option.enabled == true) then
            VehicleManager.Client.scheduleVehicleTuningAutosave()
        end
    end
    syncMenuCurrentDescription(performanceSettingsMenu)
end

statsLocalMenu.OnListChange = function(_, item, index)
    modmenus.applyModSelection(item, index, cache.statsModEntries)
end

statsLocalMenu.OnListSelect = function(_, item, index)
    modmenus.applyModSelection(item, index, cache.statsModEntries)
end

-- Runtime bindings, handles events, commands, and polling --
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
    VehicleManager.Client.scheduleVehicleTuningAutosave()

    if not flow.returnToCustomizeAfterPerformanceTuningClose then
        return
    end

    flow.returnToCustomizeAfterPerformanceTuningClose = false

    if not customizeSubMenu or not customizeSubMenu.SubMenu then
        return
    end

    customizeSubMenu.SubMenu:Visible(true)
end)

RegisterNetEvent("vehiclemanager:receiveSavedVehicleIndex", function(entries)
    if type(entries) == "table" then
        cache.savedVehicleEntries = entries
    else
        cache.savedVehicleEntries = {}
    end

    rebuildSavedVehicleMenu()
end)

RegisterNetEvent("vehiclemanager:receiveSavedVehiclePayload", function(savedData)
    if not persistence.onReceiveSavedVehiclePayload(savedData) then
        return
    end
    rebuildPartsMenu()
    rebuildStatsMenu()
end)

RegisterNetEvent("vehiclemanager:vehicleSnapshotUpdated", function(saveId)
    persistence.onVehicleSnapshotUpdated(saveId)
end)

RegisterNetEvent("vehiclemanager:vehicleSaved", function(saveId)
    persistence.onVehicleSaved(saveId)
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

