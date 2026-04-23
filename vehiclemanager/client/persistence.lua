VehicleManager = VehicleManager or {}
VehicleManager.Persistence = VehicleManager.Persistence or {}

function VehicleManager.Persistence.create(deps)
    local cache = (deps or {}).cache
    local flow = (deps or {}).flow
    local stateBagKeys = (deps or {}).stateBagKeys
    local constants = (deps or {}).constants
    local vmui = (deps or {}).vmui
    local vehicleMenuPool = (deps or {}).vehicleMenuPool
    local getDisplayLabel = (deps or {}).getDisplayLabel
    local getCurrentVehicle = (deps or {}).getCurrentVehicle
    local getVehiclePerformancePi = (deps or {}).getVehiclePerformancePi
    local getColorLabelById = (deps or {}).getColorLabelById
    local notify = (deps or {}).notify
    local notifyPersistentVehicleUpdated = (deps or {}).notifyPersistentVehicleUpdated
    local requestSavedVehicleIndex = (deps or {}).requestSavedVehicleIndex
    local scheduleAutosave = (deps or {}).scheduleAutosave
    local triggerServerEvent = (deps or {}).triggerServerEvent

    if type(cache) ~= "table" then
        error("VehicleManager.Persistence.create requires deps.cache")
    end
    if type(flow) ~= "table" then
        error("VehicleManager.Persistence.create requires deps.flow")
    end
    if type(stateBagKeys) ~= "table" then
        error("VehicleManager.Persistence.create requires deps.stateBagKeys")
    end
    if type(constants) ~= "table" then
        error("VehicleManager.Persistence.create requires deps.constants")
    end
    if type(vmui) ~= "table" or type(vmui.CreateItem) ~= "function" then
        error("VehicleManager.Persistence.create requires deps.vmui with CreateItem")
    end
    if type(vehicleMenuPool) ~= "table" or type(vehicleMenuPool.RefreshIndex) ~= "function" then
        error("VehicleManager.Persistence.create requires deps.vehicleMenuPool with RefreshIndex")
    end
    if type(getCurrentVehicle) ~= "function" then
        error("VehicleManager.Persistence.create requires deps.getCurrentVehicle")
    end
    if type(getDisplayLabel) ~= "function" then
        error("VehicleManager.Persistence.create requires deps.getDisplayLabel")
    end
    if type(getVehiclePerformancePi) ~= "function" then
        error("VehicleManager.Persistence.create requires deps.getVehiclePerformancePi")
    end
    if type(getColorLabelById) ~= "function" then
        error("VehicleManager.Persistence.create requires deps.getColorLabelById")
    end
    if type(notify) ~= "function" then
        error("VehicleManager.Persistence.create requires deps.notify")
    end
    if type(notifyPersistentVehicleUpdated) ~= "function" then
        error("VehicleManager.Persistence.create requires deps.notifyPersistentVehicleUpdated")
    end
    if type(requestSavedVehicleIndex) ~= "function" then
        error("VehicleManager.Persistence.create requires deps.requestSavedVehicleIndex")
    end
    if type(scheduleAutosave) ~= "function" then
        error("VehicleManager.Persistence.create requires deps.scheduleAutosave")
    end
    if type(triggerServerEvent) ~= "function" then
        error("VehicleManager.Persistence.create requires deps.triggerServerEvent")
    end

    local doorMapping = constants.DOOR_MAPPING or {}
    local tyreMapping = constants.TYRE_MAPPING or {}
    local tuningSelectionSchema = constants.TUNING_SELECTION_SCHEMA or {}





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

    local function getVehicleDoorState(vehicle)
        return {
            open = iterateVehicleState(vehicle, doorMapping, function(v, i) return GetVehicleDoorAngleRatio(v, i) > 0.01 end),
            broken = iterateVehicleState(vehicle, doorMapping, function(v, i) return IsVehicleDoorDamaged(v, i) end),
        }
    end

    local function getVehicleTyreState(vehicle)
        return iterateVehicleState(vehicle, tyreMapping, function(v, i) return IsVehicleTyreBurst(v, i, false) end)
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
        for index = 1, #tuningSelectionSchema do
            local entry = tuningSelectionSchema[index]
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

    local function serializeTuningSelections(tuneState)
        local normalizedSelections = normalizeTuningSelectionMap(tuneState)
        if type(normalizedSelections) ~= "table" then
            return nil
        end
        return {
            version = 1,
            selections = normalizedSelections,
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
        local tuneState = entityState[stateBagKeys.tuneState]
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
            entityState[stateBagKeys.tuneState] = normalizedTuneState
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
        entityState[stateBagKeys.saveId] = saveId
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
        local saveId = entityState[stateBagKeys.saveId]
        if type(saveId) ~= "string" or saveId == "" then
            return nil
        end
        return saveId
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
            SetEntityProofs(vehicle, vehicleData.proofs.bulletProof == true, vehicleData.proofs.fireProof == true, vehicleData.proofs.explosionProof == true, vehicleData.proofs.collisionProof == true, vehicleData.proofs.meleeProof == true, vehicleData.proofs.steamProof == true, vehicleData.proofs.unknownProof7 == true, vehicleData.proofs.drownProof == true)
        end
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
        if identity.plate ~= nil then
            SetVehicleNumberPlateText(spawnedVehicle, tostring(identity.plate))
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

    local function getVehicleDisplayName(model)
        local displayName = GetDisplayNameFromVehicleModel(model)
        if not displayName or displayName == "" then
            return tostring(model)
        end
        return displayName
    end





    local function buildSavedVehicleLabel(entry)
        local piValue = tonumber(entry and entry.pi)
        local piLabel = piValue and tostring(math.max(0, math.floor(piValue + 0.5))) or "--"
        local colorLabel = tostring((entry and (entry.primaryColorLabel or entry.colorLabel)) or "Unknown")
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
        for index = 1, #cache.savedVehicleEntries do
            local entrySaveId = tostring(cache.savedVehicleEntries[index] and cache.savedVehicleEntries[index].saveId or ""):lower()
            if entrySaveId == normalized then
                return true
            end
        end
        return false
    end

    local function rebuildSavedVehicleMenu(saveLoadSubMenu, deleteVehiclesSubMenu, saveVehicleItem)
        saveLoadSubMenu.SubMenu:Clear()
        cache.savedVehicleItems = {}
        cache.deleteVehicleEntries = {}
        cache.deleteVehicleItems = {}
        saveLoadSubMenu.SubMenu:AddItem(saveVehicleItem)
        if deleteVehiclesSubMenu and deleteVehiclesSubMenu.Item then
            saveLoadSubMenu.SubMenu:AddItem(deleteVehiclesSubMenu.Item)
            if deleteVehiclesSubMenu.SubMenu then
                deleteVehiclesSubMenu.SubMenu:Clear()
                local emptyDeleteItem = vmui.CreateItem("No Saved Vehicles", "")
                emptyDeleteItem:Enabled(false)
                deleteVehiclesSubMenu.SubMenu:AddItem(emptyDeleteItem)
            end
        end

        if #cache.savedVehicleEntries <= 0 then
            if deleteVehiclesSubMenu and deleteVehiclesSubMenu.Item then
                deleteVehiclesSubMenu.Item:Enabled(false)
            end
            local emptyItem = vmui.CreateItem("No Saved Vehicles", "")
            emptyItem:Enabled(false)
            saveLoadSubMenu.SubMenu:AddItem(emptyItem)
            vehicleMenuPool:RefreshIndex()
            return
        end

        for i = 1, #cache.savedVehicleEntries do
            local entry = cache.savedVehicleEntries[i]
            local item = vmui.CreateItem(buildSavedVehicleLabel(entry), "")
            item.Activated = function()
                triggerServerEvent("vehiclemanager:requestSavedVehiclePayload", entry.file)
            end
            saveLoadSubMenu.SubMenu:AddItem(item)
            cache.savedVehicleItems[i] = item
            cache.deleteVehicleEntries[#cache.deleteVehicleEntries + 1] = entry
        end

        if deleteVehiclesSubMenu and deleteVehiclesSubMenu.SubMenu then
            deleteVehiclesSubMenu.Item:Enabled(#cache.deleteVehicleEntries > 0)
            deleteVehiclesSubMenu.SubMenu:Clear()
            if #cache.deleteVehicleEntries <= 0 then
                local emptyDeleteItem = vmui.CreateItem("No Saved Vehicles", "")
                emptyDeleteItem:Enabled(false)
                deleteVehiclesSubMenu.SubMenu:AddItem(emptyDeleteItem)
            else
                for i = 1, #cache.deleteVehicleEntries do
                    local entry = cache.deleteVehicleEntries[i]
                    local deleteItem = vmui.CreateColouredItem(buildSavedVehicleLabel(entry), "")
                    deleteItem.Activated = function()
                        triggerServerEvent("vehiclemanager:forgetSavedVehicle", entry.file)
                    end
                    deleteVehiclesSubMenu.SubMenu:AddItem(deleteItem)
                    cache.deleteVehicleItems[i] = deleteItem
                end
            end
        end

        vehicleMenuPool:RefreshIndex()
    end





    local function buildVehicleSavePayload(vehicle)
        local model = GetEntityModel(vehicle)
        local primaryColor, secondaryColor = GetVehicleColours(vehicle)
        local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
        local modColor1Type, modColor1Color, modColor1Pearlescent = GetVehicleModColor_1(vehicle)
        local modColor2Type, modColor2Color = GetVehicleModColor_2(vehicle)
        local plateText = GetVehicleNumberPlateText(vehicle)
        local displayName = getVehicleDisplayName(model)
        local localizedName = getDisplayLabel(displayName, displayName)
        local performancePi = getVehiclePerformancePi(vehicle)
        local primaryColorLabel = getColorLabelById(primaryColor)
        local tyreSmokeR, tyreSmokeG, tyreSmokeB = GetVehicleTyreSmokeColor(vehicle)
        local isPrimaryCustom = GetIsVehiclePrimaryColourCustom(vehicle)
        local isSecondaryCustom = GetIsVehicleSecondaryColourCustom(vehicle)
        local customPrimaryColor = getCustomColor(function() return GetVehicleCustomPrimaryColour(vehicle) end, isPrimaryCustom)
        local customSecondaryColor = getCustomColor(function() return GetVehicleCustomSecondaryColour(vehicle) end, isSecondaryCustom)
        local tuningState = getVehicleTuningState(vehicle)
        local livery = GetVehicleLivery(vehicle)
        local roofLivery = GetVehicleRoofLivery(vehicle)

        return {
            source = "VehicleManager",
            schemaVersion = 1,
            format = { name = "VehicleManagerSavedVehicle", variant = "menyoo-inspired-json" },
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
                        modColor1 = { paintType = modColor1Type, color = modColor1Color, pearlescent = modColor1Pearlescent },
                        modColor2 = { paintType = modColor2Type, color = modColor2Color },
                        isPrimaryColourCustom = isPrimaryCustom,
                        customPrimary = customPrimaryColor,
                        isSecondaryColourCustom = isSecondaryCustom,
                        customSecondary = customSecondaryColor,
                        tyreSmoke = { r = tyreSmokeR, g = tyreSmokeG, b = tyreSmokeB },
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





    local function saveCurrentVehicle(promptForSaveId)
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

        if hasExistingSaveId(saveId) and flow.pendingOverwriteSaveId ~= saveId then
            flow.pendingOverwriteSaveId = saveId
            notify(("Save '%s' already exists. Press Save again to confirm overwrite."):format(saveId))
            return
        end
        flow.pendingOverwriteSaveId = nil

        local payload = buildVehicleSavePayload(vehicle)
        payload.saveId = saveId
        setVehicleSaveIdState(vehicle, saveId)
        notify(("Saving vehicle as '%s'..."):format(saveId))
        triggerServerEvent("vehiclemanager:saveVehicle", payload)
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
        triggerServerEvent("vehiclemanager:updateSavedVehicleSnapshot", saveId, payload)
    end

    local function onReceiveSavedVehiclePayload(savedData)
        if type(savedData) ~= "table" then
            notify("Could not load saved vehicle payload.")
            return false
        end

        spawnSavedVehicle(savedData)
        notify(("Loaded saved vehicle: %s"):format(tostring(savedData.saveId or "unknown")))
        return true
    end

    local function onVehicleSnapshotUpdated(saveId)
        local _ = saveId
        notifyPersistentVehicleUpdated(getCurrentVehicle(false))
    end

    local function onVehicleSaved(saveId)
        flow.pendingOverwriteSaveId = nil
        if type(saveId) ~= "string" or saveId == "" then
            notify("Vehicle saved.")
        else
            notify(("Vehicle saved: %s"):format(saveId))
        end
        requestSavedVehicleIndex()
    end

    local function requestSavedVehiclePayload(file)
        triggerServerEvent("vehiclemanager:requestSavedVehiclePayload", file)
    end

    local function forgetSavedVehicle(file)
        triggerServerEvent("vehiclemanager:forgetSavedVehicle", file)
    end





    return {
        iterateVehicleState = iterateVehicleState,
        getCustomColor = getCustomColor,
        getNeonState = getNeonState,
        getVehicleExtras = getVehicleExtras,
        getVehicleMods = getVehicleMods,
        getVehicleDoorState = getVehicleDoorState,
        getVehicleTyreState = getVehicleTyreState,
        getVehicleProofs = getVehicleProofs,
        waitForVehicleOwnership = waitForVehicleOwnership,
        ensureVehicleNetworked = ensureVehicleNetworked,
        waitForVehicleNetworkState = waitForVehicleNetworkState,
        cleanModSelectionMap = cleanModSelectionMap,
        normalizeTuningSelectionMap = normalizeTuningSelectionMap,
        serializeTuningSelections = serializeTuningSelections,
        deserializeTuningSelections = deserializeTuningSelections,
        getVehicleTuningState = getVehicleTuningState,
        applyVehicleTuningState = applyVehicleTuningState,
        setVehicleSaveIdState = setVehicleSaveIdState,
        getVehicleSaveIdState = getVehicleSaveIdState,
        setVehicleModEntry = setVehicleModEntry,
        applySavedVehicleColours = applySavedVehicleColours,
        applySavedVehicleNeons = applySavedVehicleNeons,
        applySavedVehicleExtras = applySavedVehicleExtras,
        applySavedVehicleMods = applySavedVehicleMods,
        applySavedVehicleDoorState = applySavedVehicleDoorState,
        applySavedVehicleTyres = applySavedVehicleTyres,
        applySavedVehicleEntityState = applySavedVehicleEntityState,
        requestModel = requestModel,
        spawnSavedVehicle = spawnSavedVehicle,
        buildSavedVehicleLabel = buildSavedVehicleLabel,
        hasExistingSaveId = hasExistingSaveId,
        rebuildSavedVehicleMenu = rebuildSavedVehicleMenu,
        buildVehicleSavePayload = buildVehicleSavePayload,
        saveCurrentVehicle = saveCurrentVehicle,
        autosaveManagedVehicleToExistingSave = autosaveManagedVehicleToExistingSave,
        onReceiveSavedVehiclePayload = onReceiveSavedVehiclePayload,
        onVehicleSnapshotUpdated = onVehicleSnapshotUpdated,
        onVehicleSaved = onVehicleSaved,
        requestSavedVehiclePayload = requestSavedVehiclePayload,
        forgetSavedVehicle = forgetSavedVehicle,
    }
end
