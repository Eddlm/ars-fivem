local menuX = 1420
local vehicleMenuPool = NativeUI.CreatePool()
local vehicleMainMenu = NativeUI.CreateMenu("Vehicle Manager", "~b~CURRENT VEHICLE", menuX, 0, nil, nil, nil, 255, 255, 255, 210)

local helpListItem = NativeUI.CreateListItem("Help", { "Fix Vehicle", "Teleport To Nearest Road" }, 1, "Quick vehicle helper actions.")
local saveVehicleItem = NativeUI.CreateItem("Save Vehicle", "Scaffold a vehicle save payload and write it to JSON on the resource.")
local saveLoadSubMenu = nil
local deleteVehiclesSubMenu = nil
local customizeSubMenu = nil
local colorSubMenu = nil
local wheelsSubMenu = nil
local partsSubMenu = nil
local statsSubMenu = nil
local statsSubMenuBoundToVehicleManager = true
local returnToCustomizeAfterPerformanceTuningClose = false
local paintCategoryListItem = NativeUI.CreateListItem("Paint Category", { "Classic" }, 1, "Choose the paint family for both vehicle colors.")
local primaryPaintColorListItem = NativeUI.CreateListItem("Primary", { "Black" }, 1, "Apply a primary paint color.")
local secondaryPaintColorListItem = NativeUI.CreateListItem("Secondary", { "Black" }, 1, "Apply a secondary paint color.")
local pearlescentColorListItem = NativeUI.CreateListItem("Pearlescent", { "Black" }, 1, "Apply the pearlescent color.")
local interiorColorListItem = NativeUI.CreateListItem("Interior", { "Black" }, 1, "Apply the interior color.")
local dashboardColorListItem = NativeUI.CreateListItem("Dashboard", { "Black" }, 1, "Apply the dashboard color.")
local xenonColorListItem = NativeUI.CreateListItem("Xenon", { "Default" }, 1, "Apply the xenon headlight color.")
local liveryListItem = NativeUI.CreateListItem("Livery", { "No liveries available" }, 1, "Apply a livery if this vehicle supports one.")
local wheelCategoryListItem = NativeUI.CreateListItem("Wheel Category", { "Sport" }, 1, "Choose the wheel family.")
local wheelListItem = NativeUI.CreateListItem("Wheel", { "Stock" }, 1, "Apply a wheel style for the current wheel category.")
local wheelColorListItem = NativeUI.CreateListItem("Wheel Color", { "Black" }, 1, "Apply the wheel color.")
local customTyresItem = UIMenuCheckboxItem.New("Custom Tyres", false, "Toggle custom tyres for the current wheel setup.")

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
local availabilityState = {
    hasVehicle = nil,
    hasDriverVehicle = nil,
}
local TUNE_STATE_BAG_KEY = "performancetuning:tuneState"
local HANDLING_STATE_BAG_KEY = "performancetuning:handlingState"
local SAVE_ID_STATE_BAG_KEY = "nativeui26:saveId"

local baseGlossColorOptions = {
    { label = "Black", colorId = 0 },
    { label = "Carbon Black", colorId = 147 },
    { label = "Graphite", colorId = 1 },
    { label = "Anthracite Black", colorId = 11 },
    { label = "Silver", colorId = 4 },
    { label = "Blue Silver", colorId = 5 },
    { label = "Rolled Steel", colorId = 6 },
    { label = "Shadow Silver", colorId = 7 },
    { label = "Stone Silver", colorId = 8 },
    { label = "Midnight Silver", colorId = 9 },
    { label = "Cast Iron Silver", colorId = 10 },
    { label = "Red", colorId = 27 },
    { label = "Torino Red", colorId = 28 },
    { label = "Formula Red", colorId = 29 },
    { label = "Lava Red", colorId = 150 },
    { label = "Blaze Red", colorId = 30 },
    { label = "Grace Red", colorId = 31 },
    { label = "Garnet Red", colorId = 32 },
    { label = "Sunset Red", colorId = 33 },
    { label = "Cabernet Red", colorId = 34 },
    { label = "Wine Red", colorId = 143 },
    { label = "Candy Red", colorId = 35 },
    { label = "Sunrise Orange", colorId = 36 },
    { label = "Classic Gold", colorId = 37 },
    { label = "Orange", colorId = 38 },
    { label = "Dark Green", colorId = 49 },
    { label = "Racing Green", colorId = 50 },
    { label = "Sea Green", colorId = 51 },
    { label = "Olive Green", colorId = 52 },
    { label = "Bright Green", colorId = 53 },
    { label = "Gasoline Green", colorId = 54 },
    { label = "Lime Green", colorId = 92 },
    { label = "Midnight Blue", colorId = 141 },
    { label = "Galaxy Blue", colorId = 61 },
    { label = "Dark Blue", colorId = 62 },
    { label = "Saxon Blue", colorId = 63 },
    { label = "Blue", colorId = 64 },
    { label = "Mariner Blue", colorId = 65 },
    { label = "Harbor Blue", colorId = 66 },
    { label = "Diamond Blue", colorId = 67 },
    { label = "Surf Blue", colorId = 68 },
    { label = "Nautical Blue", colorId = 69 },
    { label = "Racing Blue", colorId = 73 },
    { label = "Ultra Blue", colorId = 70 },
    { label = "Light Blue", colorId = 74 },
    { label = "Chocolate Brown", colorId = 96 },
    { label = "Bison Brown", colorId = 101 },
    { label = "Creek Brown", colorId = 95 },
    { label = "Feltzer Brown", colorId = 94 },
    { label = "Maple Brown", colorId = 97 },
    { label = "Beechwood Brown", colorId = 103 },
    { label = "Sienna Brown", colorId = 104 },
    { label = "Saddle Brown", colorId = 98 },
    { label = "Moss Brown", colorId = 100 },
    { label = "Woodbeech Brown", colorId = 102 },
    { label = "Straw Brown", colorId = 99 },
    { label = "Sandy Brown", colorId = 105 },
    { label = "Bleached Brown", colorId = 106 },
    { label = "Schafter Purple", colorId = 71 },
    { label = "Spinnaker Purple", colorId = 72 },
    { label = "Midnight Purple", colorId = 142 },
    { label = "Bright Purple", colorId = 145 },
    { label = "Cream", colorId = 107 },
    { label = "Ice White", colorId = 111 },
    { label = "Frost White", colorId = 112 },
    { label = "Yellow", colorId = 88 },
    { label = "Race Yellow", colorId = 89 },
    { label = "Bronze", colorId = 90 },
    { label = "Dew Yellow", colorId = 91 },
}

local matteColorOptions = {
    { label = "Matte Black", colorId = 12 },
    { label = "Matte Gray", colorId = 13 },
    { label = "Matte Light Gray", colorId = 14 },
    { label = "Matte Ice White", colorId = 131 },
    { label = "Matte Blue", colorId = 83 },
    { label = "Matte Dark Blue", colorId = 82 },
    { label = "Matte Midnight Blue", colorId = 84 },
    { label = "Matte Midnight Purple", colorId = 149 },
    { label = "Matte Schafter Purple", colorId = 148 },
    { label = "Matte Red", colorId = 39 },
    { label = "Matte Dark Red", colorId = 40 },
    { label = "Matte Orange", colorId = 41 },
    { label = "Matte Yellow", colorId = 42 },
    { label = "Matte Lime Green", colorId = 55 },
    { label = "Matte Green", colorId = 128 },
    { label = "Matte Forest Green", colorId = 151 },
    { label = "Matte Foliage Green", colorId = 155 },
    { label = "Matte Olive Drab", colorId = 152 },
    { label = "Matte Dark Earth", colorId = 153 },
    { label = "Matte Desert Tan", colorId = 154 },
}

local utilColorOptions = {
    { label = "Util Black", colorId = 15 },
    { label = "Util Black Poly", colorId = 16 },
    { label = "Util Dark Silver", colorId = 17 },
    { label = "Util Silver", colorId = 18 },
    { label = "Util Gun Metal", colorId = 19 },
    { label = "Util Shadow Silver", colorId = 20 },
    { label = "Util Red", colorId = 43 },
    { label = "Util Bright Red", colorId = 44 },
    { label = "Util Garnet Red", colorId = 45 },
    { label = "Util Dark Green", colorId = 56 },
    { label = "Util Green", colorId = 57 },
    { label = "Util Dark Blue", colorId = 75 },
    { label = "Util Midnight Blue", colorId = 76 },
    { label = "Util Blue", colorId = 77 },
    { label = "Util Sea Foam Blue", colorId = 78 },
    { label = "Util Lightning Blue", colorId = 79 },
    { label = "Util Maui Blue Poly", colorId = 80 },
    { label = "Util Bright Blue", colorId = 81 },
    { label = "Util Brown", colorId = 108 },
    { label = "Util Medium Brown", colorId = 109 },
    { label = "Util Light Brown", colorId = 110 },
}

local wornColorOptions = {
    { label = "Worn Black", colorId = 21 },
    { label = "Worn Graphite", colorId = 22 },
    { label = "Worn Silver Gray", colorId = 23 },
    { label = "Worn Silver", colorId = 24 },
    { label = "Worn Blue Silver", colorId = 25 },
    { label = "Worn Shadow Silver", colorId = 26 },
    { label = "Worn Red", colorId = 46 },
    { label = "Worn Golden Red", colorId = 47 },
    { label = "Worn Dark Red", colorId = 48 },
    { label = "Worn Dark Green", colorId = 58 },
    { label = "Worn Green", colorId = 59 },
    { label = "Worn Sea Wash", colorId = 60 },
    { label = "Worn Dark Blue", colorId = 85 },
    { label = "Worn Blue", colorId = 86 },
    { label = "Worn Light Blue", colorId = 87 },
    { label = "Worn Honey Beige", colorId = 113 },
    { label = "Worn Brown", colorId = 114 },
    { label = "Worn Dark Brown", colorId = 115 },
    { label = "Worn Straw Beige", colorId = 116 },
    { label = "Worn Off White", colorId = 121 },
    { label = "Worn Orange", colorId = 123 },
    { label = "Worn Light Orange", colorId = 124 },
}

local metalColorOptions = {
    { label = "Brushed Steel", colorId = 117 },
    { label = "Brushed Black Steel", colorId = 118 },
    { label = "Brushed Aluminium", colorId = 119 },
    { label = "Pure Gold", colorId = 158 },
    { label = "Brushed Gold", colorId = 159 },
}

local chromeColorOptions = {
    { label = "Chrome", colorId = 120 },
}

local paintCategories = {
    { key = "classic", label = "Classic", paintType = 0, colors = baseGlossColorOptions },
    { key = "metallic", label = "Metallic", paintType = 1, colors = baseGlossColorOptions },
    { key = "matte", label = "Matte", paintType = 3, colors = matteColorOptions },
    { key = "util", label = "Util", paintType = 0, colors = utilColorOptions },
    { key = "worn", label = "Worn", paintType = 0, colors = wornColorOptions },
    { key = "metal", label = "Metal", paintType = 4, colors = metalColorOptions },
    { key = "chrome", label = "Chrome", paintType = 5, colors = chromeColorOptions },
}

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
    baseGlossColorOptions,
    matteColorOptions,
    utilColorOptions,
    wornColorOptions,
    metalColorOptions,
    chromeColorOptions
)

local xenonColorOptions = {
    { label = "Default", colorId = 255 },
    { label = "White", colorId = 0 },
    { label = "Blue", colorId = 1 },
    { label = "Electric Blue", colorId = 2 },
    { label = "Mint Green", colorId = 3 },
    { label = "Lime Green", colorId = 4 },
    { label = "Yellow", colorId = 5 },
    { label = "Golden Shower", colorId = 6 },
    { label = "Orange", colorId = 7 },
    { label = "Red", colorId = 8 },
    { label = "Pony Pink", colorId = 9 },
    { label = "Hot Pink", colorId = 10 },
    { label = "Purple", colorId = 11 },
    { label = "Blacklight", colorId = 12 },
}

local function buildColorLabels(options)
    local labels = {}
    for index = 1, #options do
        labels[index] = options[index].label
    end
    return labels
end

paintCategoryListItem.Items = paintCategoryLabels
pearlescentColorListItem.Items = buildColorLabels(extraColorOptions)
interiorColorListItem.Items = buildColorLabels(extraColorOptions)
dashboardColorListItem.Items = buildColorLabels(extraColorOptions)
xenonColorListItem.Items = buildColorLabels(xenonColorOptions)
wheelColorListItem.Items = buildColorLabels(extraColorOptions)

local function buildColorIdLookup(colorOptions)
    local lookup = {}
    for index = 1, #colorOptions do
        lookup[colorOptions[index].colorId] = true
    end
    return lookup
end

local utilColorLookup = buildColorIdLookup(utilColorOptions)
local wornColorLookup = buildColorIdLookup(wornColorOptions)
local fullColorLabelById = {}
for _, colorSet in ipairs({ baseGlossColorOptions, matteColorOptions, utilColorOptions, wornColorOptions, metalColorOptions, chromeColorOptions }) do
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
        return "Unknown"
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

local partsVehicleModCategories = {
    { modType = 0, label = "Spoilers" },
    { modType = 1, label = "Front Bumper" },
    { modType = 2, label = "Rear Bumper" },
    { modType = 3, label = "Side Skirt" },
    { modType = 4, label = "Exhaust" },
    { modType = 5, label = "Frame" },
    { modType = 6, label = "Grille" },
    { modType = 7, label = "Hood" },
    { modType = 8, label = "Left Fender" },
    { modType = 9, label = "Right Fender" },
    { modType = 10, label = "Roof" },
    { modType = 14, label = "Horns" },
    { modType = 25, label = "Plate Holders" },
    { modType = 26, label = "Vanity Plates" },
    { modType = 27, label = "Trim A" },
    { modType = 28, label = "Ornaments" },
    { modType = 29, label = "Dashboard" },
    { modType = 30, label = "Dial" },
    { modType = 31, label = "Door Speaker" },
    { modType = 32, label = "Seats" },
    { modType = 33, label = "Steering Wheel" },
    { modType = 34, label = "Shifter" },
    { modType = 35, label = "Plaques" },
    { modType = 36, label = "Speakers" },
    { modType = 37, label = "Trunk" },
    { modType = 38, label = "Hydraulics" },
    { modType = 39, label = "Engine Block" },
    { modType = 40, label = "Air Filter" },
    { modType = 41, label = "Struts" },
    { modType = 42, label = "Arch Cover" },
    { modType = 43, label = "Aerials" },
    { modType = 44, label = "Trim B" },
    { modType = 45, label = "Tank" },
    { modType = 46, label = "Windows" },
}

local statsVehicleModCategories = {
    { modType = 11, label = "Engine" },
    { modType = 12, label = "Brakes" },
    { modType = 13, label = "Transmission" },
    { modType = 15, label = "Suspension" },
    { modType = 16, label = "Armor" },
}

local wheelCategories = {
    { wheelType = 0, label = "Sport" },
    { wheelType = 1, label = "Muscle" },
    { wheelType = 2, label = "Lowrider" },
    { wheelType = 3, label = "SUV" },
    { wheelType = 4, label = "Offroad" },
    { wheelType = 5, label = "Tuner" },
    { wheelType = 6, label = "Bike" },
    { wheelType = 7, label = "High End" },
    { wheelType = 8, label = "Benny's Original" },
    { wheelType = 9, label = "Benny's Bespoke" },
    { wheelType = 10, label = "Open Wheel" },
    { wheelType = 11, label = "Street" },
    { wheelType = 12, label = "Track" },
}

local wheelCategoryLabels = {}
for index = 1, #wheelCategories do
    wheelCategoryLabels[index] = wheelCategories[index].label
end

wheelCategoryListItem.Items = wheelCategoryLabels

local function getPlayerVehicle()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then
        return nil
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil
    end

    return vehicle
end

local function getDisplayLabel(labelKey, fallback)
    if not labelKey or labelKey == "" then
        return fallback
    end

    local label = GetLabelText(labelKey)
    if not label or label == "NULL" or label == "" then
        return fallback
    end

    return label
end

local function getDriverVehicle()
    local ped = PlayerPedId()
    local vehicle = getPlayerVehicle()
    if not vehicle then
        return nil
    end

    if GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return nil
    end

    return vehicle
end

local function getManagedVehicle(requireDriver)
    if requireDriver then
        local vehicle = getDriverVehicle()
        if vehicle then
            return vehicle
        end

        return nil
    end

    local vehicle = getPlayerVehicle()
    if vehicle then
        return vehicle
    end

    return nil
end

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

local function notify(message)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(tostring(message or ""))
    EndTextCommandThefeedPostTicker(false, false)
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

local function setStatsSubMenuBinding(shouldBindToVehicleManager)
    if not customizeSubMenu or not customizeSubMenu.SubMenu or not statsSubMenu or not statsSubMenu.Item or not statsSubMenu.SubMenu then
        return
    end

    local parentMenu = customizeSubMenu.SubMenu
    local shouldBind = shouldBindToVehicleManager == true

    if shouldBind and not statsSubMenuBoundToVehicleManager then
        parentMenu:BindMenuToItem(statsSubMenu.SubMenu, statsSubMenu.Item)
        statsSubMenuBoundToVehicleManager = true
    elseif not shouldBind and statsSubMenuBoundToVehicleManager then
        parentMenu:ReleaseMenuFromItem(statsSubMenu.Item)
        statsSubMenuBoundToVehicleManager = false
    end
end

local function refreshStatsTargetBindingFromSelection(menu)
    local targetMenu = menu or (customizeSubMenu and customizeSubMenu.SubMenu) or nil
    if not targetMenu or not statsSubMenu or not statsSubMenu.Item then
        return
    end

    local selectionIndex = targetMenu:CurrentSelection()
    local selectedItem = targetMenu.Items[selectionIndex]
    local shouldRedirectToPerformanceTuning = selectedItem == statsSubMenu.Item and GetResourceState("performancetuning") == "started"
    setStatsSubMenuBinding(not shouldRedirectToPerformanceTuning)
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
        currentLiveryOptions[1] = { label = "No vehicle", available = false }
        liveryListItem.Items[1] = "No vehicle"
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
            label = "Stock",
            available = true,
            mode = "mod",
            value = -1,
        }
        liveryListItem.Items[1] = "Stock"

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

    currentLiveryOptions[1] = { label = "No liveries available", available = false }
    liveryListItem.Items[1] = "No liveries available"
end

local function rebuildModMenu(subMenu, categories, emptyTitle, emptyDescription)
    subMenu.SubMenu:Clear()
    local vehicle = getManagedVehicle(false)
    if not vehicle then
        local emptyItem = NativeUI.CreateItem("No vehicle", "Enter a vehicle to browse available mod categories.")
        emptyItem:Enabled(false)
        subMenu.SubMenu:AddItem(emptyItem)
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
                { label = "Stock", value = -1 },
            }
            local optionLabels = { "Stock" }

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

            local item = NativeUI.CreateListItem(category.label, optionLabels, currentIndex, ("Choose a %s mod for the current vehicle."):format(category.label:lower()))
            subMenu.SubMenu:AddItem(item)
            modItems[#modItems + 1] = item
            modEntries[#modEntries + 1] = {
                modType = category.modType,
                options = options,
                item = item,
            }
        end
    end

    if #modItems <= 0 then
        local emptyItem = NativeUI.CreateItem(emptyTitle, emptyDescription)
        emptyItem:Enabled(false)
        subMenu.SubMenu:AddItem(emptyItem)
    end

    vehicleMenuPool:RefreshIndex()
    return modItems, modEntries
end

local function rebuildPartsMenu()
    partsModItems, partsModEntries = rebuildModMenu(
        partsSubMenu,
        partsVehicleModCategories,
        "No parts available",
        "This vehicle does not expose tunable body mod categories."
    )
end

local function rebuildStatsMenu()
    statsModItems, statsModEntries = rebuildModMenu(
        statsSubMenu,
        statsVehicleModCategories,
        "No stats upgrades",
        "This vehicle does not expose engine, brakes, transmission, suspension, or armor upgrades."
    )
end

local function applyModSelection(item, index, entries)
    local vehicle = getManagedVehicle(false)
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

    local vehicle = getManagedVehicle(false)
    if not vehicle then
        wheelListItem.Items[1] = "No vehicle"
        wheelListItem:Index(1)
        customTyresItem.Checked = false
        return
    end

    SetVehicleModKit(vehicle, 0)

    local wheelState = captureWheelState(vehicle)
    local wheelCategory = getWheelCategory(categoryIndex)
    local wheelModType = getPrimaryWheelModType(vehicle)

    SetVehicleWheelType(vehicle, wheelCategory.wheelType)

    local modCount = GetNumVehicleMods(vehicle, wheelModType)
    currentWheelOptions[1] = { label = "Stock", value = -1 }
    wheelListItem.Items[1] = "Stock"

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
    customTyresItem.Checked = (wheelModType == 24 and wheelState.rearCustom or wheelState.frontCustom) == true
    restoreWheelState(vehicle, wheelState)
end

local function refreshWheelControls()
    local vehicle = getManagedVehicle(false)
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
    local vehicle = getManagedVehicle(false)
    local option = currentWheelOptions[wheelIndex]
    if not vehicle or not option then
        return
    end

    SetVehicleModKit(vehicle, 0)
    SetVehicleWheelType(vehicle, getWheelCategory(categoryIndex).wheelType)

    local wheelModType = getPrimaryWheelModType(vehicle)
    SetVehicleMod(vehicle, wheelModType, option.value, useCustomTyres == true)
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
    local vehicle = getPlayerVehicle()
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
    local hasVehicle = getManagedVehicle(false) ~= nil
    local hasDriverVehicle = getManagedVehicle(true) ~= nil
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

    refreshStatsTargetBindingFromSelection(customizeSubMenu and customizeSubMenu.SubMenu or nil)
    vehicleMenuPool:RefreshIndex()
end

local function fixCurrentVehicle()
    local vehicle = getManagedVehicle(true)
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
    local vehicle = getManagedVehicle(true)
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

local function getVehicleDisplayName(model)
    local displayName = GetDisplayNameFromVehicleModel(model)
    if not displayName or displayName == "" then
        return tostring(model)
    end

    return displayName
end

local function getLabelOrFallback(labelKey, fallback)
    if not labelKey or labelKey == "" then
        return fallback
    end

    local label = GetLabelText(labelKey)
    if not label or label == "" or label == "NULL" then
        return fallback
    end

    return label
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

local function getVehicleDoorState(vehicle)
    local names = {
        [0] = "frontLeftDoor",
        [1] = "frontRightDoor",
        [2] = "backLeftDoor",
        [3] = "backRightDoor",
        [4] = "hood",
        [5] = "trunk",
        [6] = "trunk2",
    }
    local doorState = {
        open = {},
        broken = {},
    }

    for doorIndex, doorName in pairs(names) do
        doorState.open[doorName] = GetVehicleDoorAngleRatio(vehicle, doorIndex) > 0.01
        doorState.broken[doorName] = IsVehicleDoorDamaged(vehicle, doorIndex)
    end

    return doorState
end

local function getVehicleTyreState(vehicle)
    local tyreNames = {
        [0] = "frontLeft",
        [1] = "frontRight",
        [2] = "middleLeft",
        [3] = "middleRight",
        [4] = "backLeft",
        [5] = "backRight",
        [6] = "extra6",
        [7] = "extra7",
        [8] = "extra8",
    }
    local tyreState = {}

    for tyreIndex, tyreName in pairs(tyreNames) do
        tyreState[tyreName] = IsVehicleTyreBurst(vehicle, tyreIndex, false)
    end

    return tyreState
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

local function ensureVehicleNetworked(vehicle, timeoutMs)
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

local TUNING_SELECTION_SCHEMA = {
    { key = "enginePack", default = "stock", parse = function(value) return type(value) == "string" and value or "stock" end },
    { key = "transmissionPack", default = "stock", parse = function(value) return type(value) == "string" and value or "stock" end },
    { key = "suspensionPack", default = "stock", parse = function(value) return type(value) == "string" and value or "stock" end },
    { key = "tireCompoundPack", default = "stock", parse = function(value) return type(value) == "string" and value or "stock" end },
    { key = "tireCompoundCategory", default = "stock", parse = function(value) return type(value) == "string" and value or "stock" end },
    { key = "tireCompoundQuality", default = "mid_end", parse = function(value) return type(value) == "string" and value or "mid_end" end },
    { key = "brakePack", default = "stock", parse = function(value) return type(value) == "string" and value or "stock" end },
    { key = "nitrousLevel", default = "stock", parse = function(value) return type(value) == "string" and value or "stock" end },
    { key = "steeringLockMode", default = "stock", parse = function(value) return type(value) == "string" and value or "stock" end },
    { key = "revLimiterEnabled", default = false, parse = function(value) return value == true end },
    { key = "nitrousShotStrength", default = 1.0, parse = function(value) return tonumber(value) or 1.0 end },
    { key = "antirollForce", default = 0.0, parse = function(value) return tonumber(value) or 0.0 end },
    { key = "brakeBiasFront", default = 0.5, parse = function(value) return tonumber(value) or 0.5 end },
    { key = "gripBiasFront", default = 0.5, parse = function(value) return tonumber(value) or 0.5 end },
    { key = "antirollBiasFront", default = 0.5, parse = function(value) return tonumber(value) or 0.5 end },
    { key = "suspensionRaise", default = 0.0, parse = function(value) return tonumber(value) or 0.0 end },
    { key = "suspensionBiasFront", default = 0.5, parse = function(value) return tonumber(value) or 0.5 end },
}

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

-- Pre-alpha policy: strict canonical schema only (no legacy key aliases).
local function normalizeSelectionMap(source)
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
    local canonical = normalizeSelectionMap(source)
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

    return normalized
end

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
    AddTextEntry("NATIVEUI26_SAVE_ID", "Enter saved vehicle name")
    DisplayOnscreenKeyboard(1, "NATIVEUI26_SAVE_ID", "", defaultValue or "", "", "", "", 40)

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

local function waitForVehicleNetworkState(vehicle, timeoutMs)
    local timeoutAt = GetGameTimer() + (timeoutMs or 3000)

    while DoesEntityExist(vehicle) and GetGameTimer() < timeoutAt do
        if NetworkGetEntityIsNetworked(vehicle) then
            local netId = NetworkGetNetworkIdFromEntity(vehicle)
            if netId and netId ~= 0 then
                return true
            end
        end

        Wait(0)
    end

    return false
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
    local heading = GetEntityHeading(ped)
    local spawnedVehicle = CreateVehicle(model, spawnCoords.x, spawnCoords.y, spawnCoords.z, heading, true, false)

    if spawnedVehicle == 0 or not DoesEntityExist(spawnedVehicle) then
        SetModelAsNoLongerNeeded(model)
        return
    end

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
    SetVehicleOnGroundProperly(spawnedVehicle)
    SetModelAsNoLongerNeeded(model)
end

local function buildSavedVehicleLabel(entry)
    local piValue = tonumber(entry and entry.pi)
    local piLabel = piValue and tostring(math.max(0, math.floor(piValue + 0.5))) or "--"
    local colorLabel = tostring((entry and (entry.primaryColorLabel or entry.colorLabel)) or "Unknown")
    local vehicleName = tostring((entry and (entry.localizedName or entry.displayName)) or "Saved Vehicle")
    return ("%s | %s %s"):format(piLabel, colorLabel, vehicleName)
end

local function buildSavedVehicleDescription(entry)
    local saveId = tostring((entry and entry.saveId) or "")
    if saveId == "" then
        return "ID: (missing)"
    end

    return ("ID: %s"):format(saveId)
end

local function rebuildSavedVehicleMenu()
    saveLoadSubMenu.SubMenu:Clear()
    savedVehicleItems = {}
    deleteVehicleEntries = {}
    deleteVehicleItems = {}
    saveLoadSubMenu.SubMenu:AddItem(saveVehicleItem)
    if deleteVehiclesSubMenu and deleteVehiclesSubMenu.Item then
        saveLoadSubMenu.SubMenu:AddItem(deleteVehiclesSubMenu.Item)
    end

    if #savedVehicleEntries <= 0 then
        local emptyItem = NativeUI.CreateItem("No Saved Vehicles", "Save a vehicle first to populate this list.")
        emptyItem:Enabled(false)
        saveLoadSubMenu.SubMenu:AddItem(emptyItem)
        vehicleMenuPool:RefreshIndex()
        return
    end

    for i = 1, #savedVehicleEntries do
        local entry = savedVehicleEntries[i]
        local item = NativeUI.CreateItem(buildSavedVehicleLabel(entry), buildSavedVehicleDescription(entry))
        saveLoadSubMenu.SubMenu:AddItem(item)
        savedVehicleItems[i] = item
        deleteVehicleEntries[#deleteVehicleEntries + 1] = entry
    end

    if deleteVehiclesSubMenu and deleteVehiclesSubMenu.SubMenu then
        deleteVehiclesSubMenu.SubMenu:Clear()
        if #deleteVehicleEntries <= 0 then
            local emptyDeleteItem = NativeUI.CreateItem("No Saved Vehicles", "Nothing to remove from the index yet.")
            emptyDeleteItem:Enabled(false)
            deleteVehiclesSubMenu.SubMenu:AddItem(emptyDeleteItem)
        else
            for i = 1, #deleteVehicleEntries do
                local entry = deleteVehicleEntries[i]
                local deleteItem = NativeUI.CreateColouredItem(
                    buildSavedVehicleLabel(entry),
                    buildSavedVehicleDescription(entry),
                    Colours.RedDark,
                    Colours.Red
                )
                deleteVehiclesSubMenu.SubMenu:AddItem(deleteItem)
                deleteVehicleItems[i] = deleteItem
            end
        end
    end

    vehicleMenuPool:RefreshIndex()
end

local function requestSavedVehicleIndex()
    TriggerServerEvent("nativeui26:requestSavedVehicleIndex")
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
        source = "NativeUI26.VehicleManager",
        scaffoldVersion = 1,
        format = {
            name = "NativeUI26SavedVehicle",
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
    local vehicle = getManagedVehicle(true)
    if not vehicle then
        return
    end

    ensureVehicleNetworked(vehicle, 1500)

    local defaultSaveId = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    local saveId = promptForSaveId(defaultSaveId)
    if not saveId then
        return
    end

    local payload = buildVehicleSavePayload(vehicle)
    payload.saveId = saveId
    setVehicleSaveIdState(vehicle, saveId)

    TriggerServerEvent("nativeui26:saveVehicle", payload)
end

local function autosaveManagedVehicleToExistingSave()
    local vehicle = getManagedVehicle(false)
    if not vehicle then
        return
    end

    local saveId = getVehicleSaveIdState(vehicle)
    if not saveId then
        return
    end

    local payload = buildVehicleSavePayload(vehicle)
    payload.saveId = saveId
    TriggerServerEvent("nativeui26:updateSavedVehicleSnapshot", saveId, payload)
end

local function applyPaintColor(target, categoryIndex, colorIndex)
    local vehicle = getManagedVehicle(false)
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
end

local function applyPearlescentColor(index)
    local vehicle = getManagedVehicle(false)
    local option = extraColorOptions[index]
    if not vehicle or not option then
        return
    end

    local _, wheelColor = GetVehicleExtraColours(vehicle)
    SetVehicleExtraColours(vehicle, option.colorId, wheelColor)
end

local function applyInteriorColor(index)
    local vehicle = getManagedVehicle(false)
    local option = extraColorOptions[index]
    if not vehicle or not option then
        return
    end

    SetVehicleInteriorColor(vehicle, option.colorId)
end

local function applyDashboardColor(index)
    local vehicle = getManagedVehicle(false)
    local option = extraColorOptions[index]
    if not vehicle or not option then
        return
    end

    SetVehicleDashboardColor(vehicle, option.colorId)
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
    local vehicle = getManagedVehicle(false)
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
end

local function applyWheelColor(index)
    local vehicle = getManagedVehicle(false)
    local option = extraColorOptions[index]
    if not vehicle or not option then
        return
    end

    local pearlescentColor, _ = GetVehicleExtraColours(vehicle)
    SetVehicleExtraColours(vehicle, pearlescentColor, option.colorId)
end

local function applySelectedLivery(index)
    local vehicle = getManagedVehicle(false)
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
end

vehicleMainMenu:AddItem(helpListItem)
customizeSubMenu = vehicleMenuPool:AddSubMenu(vehicleMainMenu, "Customize Vehicle", "Apply paint and livery options to the current vehicle.", true, true)
saveLoadSubMenu = vehicleMenuPool:AddSubMenu(vehicleMainMenu, "Save / Load", "Save the current vehicle or load one of the saved vehicles.", true, true)
deleteVehiclesSubMenu = vehicleMenuPool:AddSubMenu(saveLoadSubMenu.SubMenu, "Delete Vehicle", "Remove a saved vehicle entry from your index.", true, true)
statsSubMenu = vehicleMenuPool:AddSubMenu(customizeSubMenu.SubMenu, "Stats", "Vehicle stats and tune information.", true, true)
colorSubMenu = vehicleMenuPool:AddSubMenu(customizeSubMenu.SubMenu, "Color", "Vehicle paint and livery options.", true, true)
partsSubMenu = vehicleMenuPool:AddSubMenu(customizeSubMenu.SubMenu, "Parts", "Vehicle parts customization.", true, true)
wheelsSubMenu = vehicleMenuPool:AddSubMenu(customizeSubMenu.SubMenu, "Wheels", "Wheel family, style, and custom tyres.", true, true)
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
registerVehicleRequiredItem(colorSubMenu.Item)
registerVehicleRequiredItem(partsSubMenu.Item)
registerVehicleRequiredItem(statsSubMenu.Item)
registerVehicleRequiredItem(wheelsSubMenu.Item)
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
rebuildSavedVehicleMenu()
saveLoadSubMenu.Item:RightLabel(">>>")
customizeSubMenu.Item:RightLabel(">>>")
colorSubMenu.Item:RightLabel(">>>")
wheelsSubMenu.Item:RightLabel(">>>")
partsSubMenu.Item:RightLabel(">>>")
statsSubMenu.Item:RightLabel(">>>")
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
        applyWheelSelection(wheelCategoryListItem:Index(), index, customTyresItem.Checked == true)
    elseif item == wheelColorListItem then
        applyWheelColor(index)
    end
end

wheelsSubMenu.SubMenu.OnListSelect = function(_, item, index)
    if item == wheelCategoryListItem then
        rebuildWheelList(index)
    elseif item == wheelListItem then
        applyWheelSelection(wheelCategoryListItem:Index(), index, customTyresItem.Checked == true)
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

customizeSubMenu.SubMenu.OnIndexChange = function(menu, newindex)
    refreshStatsTargetBindingFromSelection(menu)
end

customizeSubMenu.SubMenu.OnItemSelect = function(_, item, index)
    if item ~= statsSubMenu.Item then
        return
    end

    if tryOpenPerformanceTuningMenu() then
        customizeSubMenu.SubMenu:CurrentSelection(0)
        returnToCustomizeAfterPerformanceTuningClose = true
        vehicleMenuPool:CloseAllMenus()
    end
end

statsSubMenu.SubMenu.OnListChange = function(_, item, index)
    applyModSelection(item, index, statsModEntries)
end

statsSubMenu.SubMenu.OnListSelect = function(_, item, index)
    applyModSelection(item, index, statsModEntries)
end

saveLoadSubMenu.SubMenu.OnItemSelect = function(_, item, index)
    if item == saveVehicleItem then
        saveCurrentVehicle()
        return
    end

    local selectedEntry = nil
    for i = 1, #savedVehicleItems do
        if item == savedVehicleItems[i] then
            selectedEntry = savedVehicleEntries[i]
            break
        end
    end

    if not selectedEntry then
        return
    end

    TriggerServerEvent("nativeui26:requestSavedVehiclePayload", selectedEntry.file)
end

if deleteVehiclesSubMenu and deleteVehiclesSubMenu.SubMenu then
    deleteVehiclesSubMenu.SubMenu.OnItemSelect = function(_, item, index)
        local entry = deleteVehicleEntries[index]
        if not entry or item ~= deleteVehicleItems[index] then
            return
        end

        TriggerServerEvent("nativeui26:forgetSavedVehicle", entry.file)
    end
end

vehicleMainMenu.OnMenuChanged = function(_, newmenu, forward)
    if newmenu == customizeSubMenu.SubMenu then
        refreshStatsTargetBindingFromSelection(newmenu)
    elseif forward and newmenu == saveLoadSubMenu.SubMenu then
        requestSavedVehicleIndex()
    elseif forward and newmenu == wheelsSubMenu.SubMenu then
        refreshWheelControls()
    elseif forward and newmenu == partsSubMenu.SubMenu then
        rebuildPartsMenu()
    elseif forward and newmenu == statsSubMenu.SubMenu then
        rebuildStatsMenu()
    end
end

vehicleMainMenu.OnMenuClosed = function()
    autosaveManagedVehicleToExistingSave()
end

RegisterNetEvent("performancetuning:menuClosed", function()
    if not returnToCustomizeAfterPerformanceTuningClose then
        return
    end

    returnToCustomizeAfterPerformanceTuningClose = false

    if not customizeSubMenu or not customizeSubMenu.SubMenu then
        return
    end

    customizeSubMenu.SubMenu:Visible(true)
    refreshStatsTargetBindingFromSelection(customizeSubMenu.SubMenu)
end)

RegisterNetEvent("nativeui26:receiveSavedVehicleIndex", function(entries)
    if type(entries) == "table" then
        savedVehicleEntries = entries
    else
        savedVehicleEntries = {}
    end

    rebuildSavedVehicleMenu()
end)

RegisterNetEvent("nativeui26:receiveSavedVehiclePayload", function(savedData)
    if type(savedData) ~= "table" then
        return
    end

    spawnSavedVehicle(savedData)
    rebuildPartsMenu()
    rebuildStatsMenu()
end)

RegisterNetEvent("nativeui26:vehicleSnapshotUpdated", function(saveId)
    if type(saveId) ~= "string" or saveId == "" then
        notify("Saved vehicle updated.")
        return
    end

    notify("Saved vehicle updated.")
end)

RegisterCommand("+vehiclemanager_menu", function()
    updateVehicleAvailabilityState(true)
    vehicleMainMenu:Visible(not vehicleMainMenu:Visible())
end, false)

RegisterCommand("-vehiclemanager_menu", function()
end, false)

RegisterKeyMapping("+vehiclemanager_menu", "Open the vehicle manager menu", "keyboard", "F5")

CreateThread(function()
    local nextAvailabilityRefreshAt = 0

    while true do
        Wait(0)
        vehicleMenuPool:ProcessMenus()

        if GetGameTimer() >= nextAvailabilityRefreshAt then
            updateVehicleAvailabilityState(false)
            nextAvailabilityRefreshAt = GetGameTimer() + 200
        end
    end
end)
