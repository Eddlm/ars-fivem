VehicleManager = VehicleManager or {}
VehicleManager.ModMenus = VehicleManager.ModMenus or {}

function VehicleManager.ModMenus.create(deps)
    local vmui = (deps or {}).vmui
    local vehicleMenuPool = (deps or {}).vehicleMenuPool
    local getCurrentVehicle = (deps or {}).getCurrentVehicle
    local getDisplayLabel = (deps or {}).getDisplayLabel
    local scheduleAutosave = (deps or {}).scheduleAutosave

    if type(vmui) ~= "table" or type(vmui.CreateItem) ~= "function" or type(vmui.CreateListItem) ~= "function" then
        error("VehicleManager.ModMenus.create requires deps.vmui with CreateItem/CreateListItem")
    end
    if type(vehicleMenuPool) ~= "table" or type(vehicleMenuPool.RefreshIndex) ~= "function" then
        error("VehicleManager.ModMenus.create requires deps.vehicleMenuPool with RefreshIndex")
    end
    if type(getCurrentVehicle) ~= "function" then
        error("VehicleManager.ModMenus.create requires deps.getCurrentVehicle")
    end
    if type(getDisplayLabel) ~= "function" then
        error("VehicleManager.ModMenus.create requires deps.getDisplayLabel")
    end
    if type(scheduleAutosave) ~= "function" then
        error("VehicleManager.ModMenus.create requires deps.scheduleAutosave")
    end

    local api = {}

    function api.buildModCategoryDescription(label, isStatsMenu)
        local resolvedLabel = tostring(label or "option")
        if isStatsMenu then
            return ("Select the installed %s upgrade level."):format(resolvedLabel)
        end
        return ("Choose a %s option for this vehicle."):format(resolvedLabel)
    end

    function api.rebuildModMenu(subMenu, categories, emptyTitle, emptyDescription, isStatsMenu)
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
            local emptyItem = vmui.CreateItem("No vehicle", "Get into a vehicle and take the driver seat to use this option.")
            emptyItem:Enabled(false)
            targetMenu:AddItem(emptyItem)
            vehicleMenuPool:RefreshIndex()
            return {}, {}
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

                local item = vmui.CreateListItem(category.label, optionLabels, currentIndex, api.buildModCategoryDescription(category.label, isStatsMenu))
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
            local emptyItem = vmui.CreateItem(emptyTitle, emptyDescription)
            emptyItem:Enabled(false)
            targetMenu:AddItem(emptyItem)
        end

        vehicleMenuPool:RefreshIndex()
        return modItems, modEntries
    end

    function api.applyModSelection(item, index, entries)
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
        scheduleAutosave()
    end

    return api
end
