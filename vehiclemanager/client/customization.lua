VehicleManager = VehicleManager or {}
VehicleManager.Customization = VehicleManager.Customization or {}

function VehicleManager.Customization.create(deps)
    local appearanceConfig = (deps or {}).appearanceConfig or {}
    local categoryConfig = (deps or {}).categoryConfig or {}
    local cache = (deps or {}).cache or {}
    local items = (deps or {}).items or {}
    local getDisplayLabel = (deps or {}).getDisplayLabel
    local getCurrentVehicle = (deps or {}).getCurrentVehicle
    local scheduleAutosave = (deps or {}).scheduleAutosave

    cache.currentPrimaryColorOptions = cache.currentPrimaryColorOptions or {}
    cache.currentSecondaryColorOptions = cache.currentSecondaryColorOptions or {}
    cache.currentLiveryOptions = cache.currentLiveryOptions or {}
    cache.currentWheelOptions = cache.currentWheelOptions or {}

    local function scheduleAutosaveIfAvailable()
        if type(scheduleAutosave) == "function" then
            scheduleAutosave()
        end
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

    local function buildPaintColorOptionList(options)
        local labels = {}
        for index = 1, #options do
            labels[index] = options[index].label
        end
        return labels
    end

    local paintCategories = {}
    for index = 1, #(appearanceConfig.paintCategories or {}) do
        local category = (appearanceConfig.paintCategories or {})[index]
        local resolvedColors = appearanceConfig[category.colorSet or ""] or appearanceConfig.baseGlossColorOptions
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

    local extraColorOptions = buildMergedColorOptions(
        appearanceConfig.baseGlossColorOptions,
        appearanceConfig.matteColorOptions,
        appearanceConfig.utilColorOptions,
        appearanceConfig.wornColorOptions,
        appearanceConfig.metalColorOptions,
        appearanceConfig.chromeColorOptions
    )
    local xenonColorOptions = appearanceConfig.xenonColorOptions or {}
    local wheelCategories = categoryConfig.wheelCategories or {}

    if items.paintCategoryListItem then
        items.paintCategoryListItem.Items = paintCategoryLabels
    end
    if items.pearlescentColorListItem then
        items.pearlescentColorListItem.Items = buildPaintColorOptionList(extraColorOptions)
    end
    if items.interiorColorListItem then
        items.interiorColorListItem.Items = buildPaintColorOptionList(extraColorOptions)
    end
    if items.dashboardColorListItem then
        items.dashboardColorListItem.Items = buildPaintColorOptionList(extraColorOptions)
    end
    if items.xenonColorListItem then
        items.xenonColorListItem.Items = buildPaintColorOptionList(xenonColorOptions)
    end
    if items.wheelColorListItem then
        items.wheelColorListItem.Items = buildPaintColorOptionList(extraColorOptions)
    end
    if items.wheelCategoryListItem then
        items.wheelCategoryListItem.Items = buildPaintColorOptionList(wheelCategories)
    end

    local function buildColorIdLookup(colorOptions)
        local lookup = {}
        for index = 1, #colorOptions do
            lookup[colorOptions[index].colorId] = true
        end
        return lookup
    end

    local utilColorLookup = buildColorIdLookup(appearanceConfig.utilColorOptions or {})
    local wornColorLookup = buildColorIdLookup(appearanceConfig.wornColorOptions or {})
    local fullColorLabelById = {}
    for _, colorSet in ipairs({
        appearanceConfig.baseGlossColorOptions or {},
        appearanceConfig.matteColorOptions or {},
        appearanceConfig.utilColorOptions or {},
        appearanceConfig.wornColorOptions or {},
        appearanceConfig.metalColorOptions or {},
        appearanceConfig.chromeColorOptions or {},
    }) do
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

    local function findColorIndex(options, colorId)
        for index = 1, #options do
            if options[index].colorId == colorId then
                return index
            end
        end

        return 1
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
            cache.currentPrimaryColorOptions = options
        else
            cache.currentSecondaryColorOptions = options
        end
    end

    local function rebuildLiveryList(vehicle)
        cache.currentLiveryOptions = {}
        items.liveryListItem.Items = {}

        if not vehicle then
            cache.currentLiveryOptions[1] = { label = "No vehicle", available = false }
            items.liveryListItem.Items[1] = "No vehicle"
            items.liveryListItem:Index(1)
            return
        end

        SetVehicleModKit(vehicle, 0)

        local liveryCount = GetVehicleLiveryCount(vehicle)
        if liveryCount and liveryCount > 0 then
            for liveryIndex = 0, liveryCount - 1 do
                local listIndex = #cache.currentLiveryOptions + 1
                cache.currentLiveryOptions[listIndex] = {
                    label = getDisplayLabel(GetLiveryName(vehicle, liveryIndex), ("Livery %d"):format(liveryIndex + 1)),
                    available = true,
                    mode = "native",
                    value = liveryIndex,
                }
                items.liveryListItem.Items[listIndex] = cache.currentLiveryOptions[listIndex].label
            end

            items.liveryListItem:Index(1)
            return
        end

        local modCount = GetNumVehicleMods(vehicle, 48)
        if modCount and modCount > 0 then
            cache.currentLiveryOptions[1] = {
                label = "Stock",
                available = true,
                mode = "mod",
                value = -1,
            }
            items.liveryListItem.Items[1] = "Stock"

            for modIndex = 0, modCount - 1 do
                local listIndex = #cache.currentLiveryOptions + 1
                cache.currentLiveryOptions[listIndex] = {
                    label = getDisplayLabel(GetModTextLabel(vehicle, 48, modIndex), ("Livery %d"):format(modIndex + 1)),
                    available = true,
                    mode = "mod",
                    value = modIndex,
                }
                items.liveryListItem.Items[listIndex] = cache.currentLiveryOptions[listIndex].label
            end

            items.liveryListItem:Index(1)
            return
        end

        cache.currentLiveryOptions[1] = { label = "No liveries available", available = false }
        items.liveryListItem.Items[1] = "No liveries available"
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
        cache.currentWheelOptions = {}
        items.wheelListItem.Items = {}

        local vehicle = getCurrentVehicle(false)
        if not vehicle then
            items.wheelListItem.Items[1] = "No vehicle"
            items.wheelListItem:Index(1)
            items.customTyresItem:Checked(false)
            return
        end

        SetVehicleModKit(vehicle, 0)
        local wheelState = captureWheelState(vehicle)
        local wheelCategory = getWheelCategory(categoryIndex)
        local wheelModType = getPrimaryWheelModType(vehicle)

        SetVehicleWheelType(vehicle, wheelCategory.wheelType)

        local modCount = GetNumVehicleMods(vehicle, wheelModType)
        cache.currentWheelOptions[1] = { label = "Stock", value = -1 }
        items.wheelListItem.Items[1] = "Stock"

        if modCount and modCount > 0 then
            for modIndex = 0, modCount - 1 do
                local listIndex = #cache.currentWheelOptions + 1
                local label = getDisplayLabel(GetModTextLabel(vehicle, wheelModType, modIndex), ("Wheel %d"):format(modIndex + 1))
                cache.currentWheelOptions[listIndex] = {
                    label = label,
                    value = modIndex,
                }
                items.wheelListItem.Items[listIndex] = label
            end
        end

        local currentWheelIndex = 1
        local currentModValue = wheelModType == 24 and wheelState.rearIndex or wheelState.frontIndex
        for optionIndex = 1, #cache.currentWheelOptions do
            if cache.currentWheelOptions[optionIndex].value == currentModValue then
                currentWheelIndex = optionIndex
                break
            end
        end

        items.wheelListItem:Index(currentWheelIndex)
        items.customTyresItem:Checked((wheelModType == 24 and wheelState.rearCustom or wheelState.frontCustom) == true)
        restoreWheelState(vehicle, wheelState)
    end

    local function applyWheelSelection(categoryIndex, wheelIndex, useCustomTyres)
        local vehicle = getCurrentVehicle(false)
        local option = cache.currentWheelOptions[wheelIndex]
        if not vehicle or not option then
            return
        end

        SetVehicleModKit(vehicle, 0)
        SetVehicleWheelType(vehicle, getWheelCategory(categoryIndex).wheelType)

        local wheelModType = getPrimaryWheelModType(vehicle)
        SetVehicleMod(vehicle, wheelModType, option.value, useCustomTyres == true)
        scheduleAutosaveIfAvailable()
    end

    local function findLiveryIndex(vehicle)
        if not vehicle or #cache.currentLiveryOptions <= 0 then
            return 1
        end

        local currentNativeLivery = GetVehicleLivery(vehicle)
        for index = 1, #cache.currentLiveryOptions do
            local option = cache.currentLiveryOptions[index]
            if option.mode == "native" and option.value == currentNativeLivery then
                return index
            end
        end

        local currentModLivery = GetVehicleMod(vehicle, 48)
        for index = 1, #cache.currentLiveryOptions do
            local option = cache.currentLiveryOptions[index]
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
        items.paintCategoryListItem:Index(categoryIndex)

        rebuildPaintColorList(items.primaryPaintColorListItem, categoryIndex, "primary")
        rebuildPaintColorList(items.secondaryPaintColorListItem, categoryIndex, "secondary")

        items.primaryPaintColorListItem:Index(findColorIndex(cache.currentPrimaryColorOptions, primaryColor))
        items.secondaryPaintColorListItem:Index(findColorIndex(cache.currentSecondaryColorOptions, secondaryColor))
        items.pearlescentColorListItem:Index(findColorIndex(extraColorOptions, pearlescentColor))
        items.interiorColorListItem:Index(findColorIndex(extraColorOptions, interiorColor))
        items.dashboardColorListItem:Index(findColorIndex(extraColorOptions, dashboardColor))
        items.xenonColorListItem:Index(findColorIndex(xenonColorOptions, xenonColor))
        rebuildLiveryList(vehicle)
        items.liveryListItem:Index(findLiveryIndex(vehicle))
    end

    local function refreshWheelControls()
        local vehicle = getCurrentVehicle(false)
        if not vehicle then
            items.wheelCategoryListItem:Index(1)
            rebuildWheelList(1)
            items.wheelColorListItem:Index(1)
            return
        end

        local _, wheelColor = GetVehicleExtraColours(vehicle)
        local wheelCategoryIndex = getWheelCategoryIndexByType(GetVehicleWheelType(vehicle))
        items.wheelCategoryListItem:Index(wheelCategoryIndex)
        rebuildWheelList(wheelCategoryIndex)
        items.wheelColorListItem:Index(findColorIndex(extraColorOptions, wheelColor))
    end

    local function applyPaintColor(target, categoryIndex, colorIndex)
        local vehicle = getCurrentVehicle(false)
        local category = getPaintCategory(categoryIndex)
        local options = target == "primary" and cache.currentPrimaryColorOptions or cache.currentSecondaryColorOptions
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
        scheduleAutosaveIfAvailable()
    end

    local function applyPearlescentColor(index)
        local vehicle = getCurrentVehicle(false)
        local option = extraColorOptions[index]
        if not vehicle or not option then
            return
        end

        local _, wheelColor = GetVehicleExtraColours(vehicle)
        SetVehicleExtraColours(vehicle, option.colorId, wheelColor)
        scheduleAutosaveIfAvailable()
    end

    local function applyInteriorColor(index)
        local vehicle = getCurrentVehicle(false)
        local option = extraColorOptions[index]
        if not vehicle or not option then
            return
        end

        SetVehicleInteriorColor(vehicle, option.colorId)
        scheduleAutosaveIfAvailable()
    end

    local function applyDashboardColor(index)
        local vehicle = getCurrentVehicle(false)
        local option = extraColorOptions[index]
        if not vehicle or not option then
            return
        end

        SetVehicleDashboardColor(vehicle, option.colorId)
        scheduleAutosaveIfAvailable()
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
        scheduleAutosaveIfAvailable()
    end

    local function applyWheelColor(index)
        local vehicle = getCurrentVehicle(false)
        local option = extraColorOptions[index]
        if not vehicle or not option then
            return
        end

        local pearlescentColor, _ = GetVehicleExtraColours(vehicle)
        SetVehicleExtraColours(vehicle, pearlescentColor, option.colorId)
        scheduleAutosaveIfAvailable()
    end

    local function applySelectedLivery(index)
        local vehicle = getCurrentVehicle(false)
        local option = cache.currentLiveryOptions[index]
        if not vehicle or not option or not option.available then
            return
        end

        SetVehicleModKit(vehicle, 0)
        if option.mode == "native" then
            SetVehicleLivery(vehicle, option.value)
        elseif option.mode == "mod" then
            SetVehicleMod(vehicle, 48, option.value, false)
        end
        scheduleAutosaveIfAvailable()
    end

    return {
        getColorLabelById = getColorLabelById,
        rebuildPaintColorList = rebuildPaintColorList,
        rebuildLiveryList = rebuildLiveryList,
        rebuildWheelList = rebuildWheelList,
        refreshWheelControls = refreshWheelControls,
        applyWheelSelection = applyWheelSelection,
        refreshVehicleCustomizationLists = refreshVehicleCustomizationLists,
        applyPaintColor = applyPaintColor,
        applyPearlescentColor = applyPearlescentColor,
        applyInteriorColor = applyInteriorColor,
        applyDashboardColor = applyDashboardColor,
        applyXenonColor = applyXenonColor,
        applyWheelColor = applyWheelColor,
        applySelectedLivery = applySelectedLivery,
    }
end
