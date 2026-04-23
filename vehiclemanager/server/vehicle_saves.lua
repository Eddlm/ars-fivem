local saveDirectory = "savedvehicles"
local licenseIdentifierPrefix = "license:"
local function logVm(action, sourceId, message)
    return
end
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

local function isValidSavePayload(vehicleData)
    if type(vehicleData) ~= "table" then
        return false, "payload_not_table"
    end
    if type(vehicleData.saveId) ~= "string" or vehicleData.saveId == "" then
        return false, "missing_save_id"
    end
    if type(vehicleData.vehicle) ~= "table" then
        return false, "missing_vehicle_block"
    end
    return true, nil
end

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

local function sanitizeFilePart(value, fallback)
    local text = tostring(value or ""):gsub("[^%w%-_]+", "_"):gsub("_+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if text == "" then
        return fallback
    end
    return text
end

local function notifyMissingLicenseIdentifier(playerSource)
    if not playerSource or playerSource <= 0 then
        return
    end

    TriggerClientEvent("chat:addMessage", playerSource, {
        color = { 255, 165, 0 },
        args = { "vehiclemanager", "Could not find your license identifier (license:)." },
    })
end

local function getPlayerOwnerIdentifier(playerSource)
    local identifiers = GetPlayerIdentifiers(playerSource)
    for i = 1, #identifiers do
        local identifier = identifiers[i]
        if string.sub(identifier, 1, #licenseIdentifierPrefix) == licenseIdentifierPrefix then
            return identifier
        end
    end
    return nil
end

local function getOwnerDirectory(playerSource)
    local ownerIdentifier = getPlayerOwnerIdentifier(playerSource)
    if not ownerIdentifier then
        return nil, nil
    end
    local ownerKey = sanitizeFilePart(ownerIdentifier, "unknown_owner")
    return ownerKey, ownerIdentifier
end

local function getIndexFileName(ownerKey)
    return ("%s/%s_%s.json"):format(saveDirectory, "index", ownerKey)
end

local function buildSaveFileName(ownerKey, vehicleData)
    local saveId = sanitizeFilePart(vehicleData.saveId, "vehicle")
    return ("%s/%s_%s.json"):format(saveDirectory, ownerKey, saveId)
end

local function buildSaveFileNameFromId(ownerKey, saveId)
    local sanitizedSaveId = sanitizeFilePart(saveId, "vehicle")
    return ("%s/%s_%s.json"):format(saveDirectory, ownerKey, sanitizedSaveId)
end

local function normalizeTuningSelections(source)
    local canonical = normalizeSelectionMap(source)
    if type(canonical) ~= "table" then
        return nil
    end

    local normalized = {}
    for index = 1, #VehicleManager.Config.constants.TUNING_SELECTION_SCHEMA do
        local entry = VehicleManager.Config.constants.TUNING_SELECTION_SCHEMA[index]
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

local function normalizeTuningEnvelope(tuning)
    if type(tuning) ~= "table" then
        return nil
    end

    local selections = nil
    if type(tuning.selections) == "table" then
        selections = normalizeTuningSelections(tuning.selections)
    elseif type(tuning.tuneState) == "table" then
        selections = normalizeTuningSelections(tuning.tuneState)
    else
        selections = normalizeTuningSelections(tuning)
    end

    if type(selections) ~= "table" then
        return nil
    end

    return {
        version = 1,
        selections = selections,
    }
end

local function loadVehicleIndex(ownerKey)
    local indexFileName = getIndexFileName(ownerKey)
    local rawIndex = LoadResourceFile(GetCurrentResourceName(), indexFileName)
    if not rawIndex or rawIndex == "" then
        return {}
    end

    local decoded = json.decode(rawIndex)
    if type(decoded) ~= "table" then
        return {}
    end
    return decoded
end

local function saveVehicleIndex(ownerKey, index)
    local indexFileName = getIndexFileName(ownerKey)
    local encoded = json.encode(index, { indent = true })
    if not encoded then
        return false
    end
    return SaveResourceFile(GetCurrentResourceName(), indexFileName, encoded, -1)
end

local function sortIndexNewestFirst(index)
    table.sort(index, function(a, b)
        local aSavedAt = a and a.savedAt or ""
        local bSavedAt = b and b.savedAt or ""
        return aSavedAt > bSavedAt
    end)
end

local function buildIndexEntry(fileName, vehicleData)
    local identity = vehicleData.identity or {}
    local owner = vehicleData.owner or {}
    return {
        file = fileName,
        savedAt = vehicleData.savedAt,
        saveId = vehicleData.saveId,
        displayName = identity.displayName or "vehicle",
        localizedName = identity.localizedName or identity.displayName or "vehicle",
        plate = identity.plate or "",
        pi = tonumber(identity.performancePi) or nil,
        primaryColorLabel = identity.primaryColorLabel or "",
        model = identity.model,
        class = identity.class,
        ownerLicense = owner.license,
    }
end

local function upsertIndexEntry(ownerKey, entry)
    local index = loadVehicleIndex(ownerKey)
    local replaced = false

    for i = 1, #index do
        if index[i].file == entry.file then
            index[i] = entry
            replaced = true
            break
        end
    end

    if not replaced then
        index[#index + 1] = entry
    end

    sortIndexNewestFirst(index)
    return saveVehicleIndex(ownerKey, index)
end

local function removeIndexEntryByFile(ownerKey, fileName)
    if type(fileName) ~= "string" or fileName == "" then
        return false
    end

    local index = loadVehicleIndex(ownerKey)
    local removed = false
    for i = #index, 1, -1 do
        if tostring(index[i] and index[i].file or "") == fileName then
            table.remove(index, i)
            removed = true
        end
    end

    if not removed then
        return false
    end

    sortIndexNewestFirst(index)
    return saveVehicleIndex(ownerKey, index)
end

RegisterNetEvent("vehiclemanager:saveVehicle", function(vehicleData)
    local src = source
    local validPayload, payloadError = isValidSavePayload(vehicleData)
    if not validPayload then
        logVm("saveVehicle.reject", src, payloadError)
        return
    end

    local ownerKey, ownerIdentifier = getOwnerDirectory(src)
    if not ownerKey or not ownerIdentifier then
        notifyMissingLicenseIdentifier(src)
        logVm("saveVehicle.reject", src, "missing_owner_identifier")
        return
    end

    vehicleData.owner = {
        license = ownerIdentifier,
        key = ownerKey,
    }
    vehicleData.savedAt = os.date("!%Y-%m-%dT%H:%M:%SZ")
    vehicleData.server = {
        resource = GetCurrentResourceName(),
        savedBy = src,
        receivedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    vehicleData.tuning = normalizeTuningEnvelope(vehicleData.tuning)

    local encoded = json.encode(vehicleData, { indent = true })
    if not encoded then
        return
    end

    local fileName = buildSaveFileName(ownerKey, vehicleData)
    local ok = SaveResourceFile(GetCurrentResourceName(), fileName, encoded, -1)
    if not ok then
        logVm("saveVehicle.reject", src, ("write_failed file=%s"):format(fileName))
        return
    end

    if not upsertIndexEntry(ownerKey, buildIndexEntry(fileName, vehicleData)) then
        logVm("saveVehicle.reject", src, ("index_upsert_failed file=%s"):format(fileName))
        return
    end

    logVm("saveVehicle.ok", src, ("saveId=%s file=%s"):format(tostring(vehicleData.saveId), tostring(fileName)))
    TriggerClientEvent("vehiclemanager:vehicleSaved", src, vehicleData.saveId)
end)

RegisterNetEvent("vehiclemanager:requestSavedVehicleIndex", function()
    local src = source
    local ownerKey = getOwnerDirectory(src)
    if not ownerKey then
        notifyMissingLicenseIdentifier(src)
        TriggerClientEvent("vehiclemanager:receiveSavedVehicleIndex", src, {})
        return
    end

    TriggerClientEvent("vehiclemanager:receiveSavedVehicleIndex", src, loadVehicleIndex(ownerKey))
end)

RegisterNetEvent("vehiclemanager:requestSavedVehiclePayload", function(fileName)
    local src = source
    if type(fileName) ~= "string" or fileName == "" then
        TriggerClientEvent("vehiclemanager:receiveSavedVehiclePayload", src, nil)
        return
    end

    local ownerKey, ownerIdentifier = getOwnerDirectory(src)
    if not ownerKey or not ownerIdentifier then
        notifyMissingLicenseIdentifier(src)
        TriggerClientEvent("vehiclemanager:receiveSavedVehiclePayload", src, nil)
        return
    end

    local allowedPrefix = ("%s/%s_"):format(saveDirectory, ownerKey)
    if string.sub(fileName, 1, #allowedPrefix) ~= allowedPrefix then
        logVm("requestSavedVehiclePayload.reject", src, ("prefix_mismatch file=%s"):format(tostring(fileName)))
        TriggerClientEvent("vehiclemanager:receiveSavedVehiclePayload", src, nil)
        return
    end

    local rawPayload = LoadResourceFile(GetCurrentResourceName(), fileName)
    if not rawPayload or rawPayload == "" then
        TriggerClientEvent("vehiclemanager:receiveSavedVehiclePayload", src, nil)
        return
    end

    local payload = json.decode(rawPayload)
    if type(payload) ~= "table" then
        TriggerClientEvent("vehiclemanager:receiveSavedVehiclePayload", src, nil)
        return
    end

    local owner = payload.owner or {}
    if owner.license ~= ownerIdentifier then
        logVm("requestSavedVehiclePayload.reject", src, ("owner_mismatch file=%s"):format(tostring(fileName)))
        TriggerClientEvent("vehiclemanager:receiveSavedVehiclePayload", src, nil)
        return
    end

    logVm("requestSavedVehiclePayload.ok", src, ("file=%s saveId=%s"):format(tostring(fileName), tostring(payload.saveId or "")))
    TriggerClientEvent("vehiclemanager:receiveSavedVehiclePayload", src, payload)
end)

RegisterNetEvent("vehiclemanager:forgetSavedVehicle", function(fileName)
    local src = source
    if type(fileName) ~= "string" or fileName == "" then
        return
    end

    local ownerKey = getOwnerDirectory(src)
    if not ownerKey then
        notifyMissingLicenseIdentifier(src)
        return
    end

    local allowedPrefix = ("%s/%s_"):format(saveDirectory, ownerKey)
    if string.sub(fileName, 1, #allowedPrefix) ~= allowedPrefix then
        return
    end

    removeIndexEntryByFile(ownerKey, fileName)
    TriggerClientEvent("vehiclemanager:receiveSavedVehicleIndex", src, loadVehicleIndex(ownerKey))
end)

RegisterNetEvent("vehiclemanager:updateSavedVehicleSnapshot", function(saveId, vehicleData)
    local src = source
    if type(saveId) ~= "string" or saveId == "" or type(vehicleData) ~= "table" then
        return
    end

    local ownerKey, ownerIdentifier = getOwnerDirectory(src)
    if not ownerKey or not ownerIdentifier then
        notifyMissingLicenseIdentifier(src)
        logVm("updateSavedVehicleSnapshot.reject", src, "missing_owner_identifier")
        return
    end

    local fileName = buildSaveFileNameFromId(ownerKey, saveId)
    local rawPayload = LoadResourceFile(GetCurrentResourceName(), fileName)
    if not rawPayload or rawPayload == "" then
        logVm("updateSavedVehicleSnapshot.reject", src, ("missing_payload file=%s"):format(tostring(fileName)))
        return
    end

    local payload = json.decode(rawPayload)
    if type(payload) ~= "table" then
        return
    end

    local owner = payload.owner or {}
    if owner.license ~= ownerIdentifier then
        logVm("updateSavedVehicleSnapshot.reject", src, ("owner_mismatch file=%s"):format(tostring(fileName)))
        return
    end

    local incomingVehicle = type(vehicleData.vehicle) == "table" and vehicleData.vehicle or {}
    local incomingIdentity = type(vehicleData.identity) == "table" and vehicleData.identity or {}
    local incomingTuning = normalizeTuningEnvelope(vehicleData.tuning)

    payload.identity = payload.identity or {}
    payload.identity.displayName = incomingIdentity.displayName or payload.identity.displayName
    payload.identity.localizedName = incomingIdentity.localizedName or payload.identity.localizedName
    payload.identity.model = incomingIdentity.model or payload.identity.model
    payload.identity.class = incomingIdentity.class or payload.identity.class
    payload.identity.plate = incomingIdentity.plate or payload.identity.plate
    payload.identity.plateIndex = incomingIdentity.plateIndex or payload.identity.plateIndex
    payload.identity.performancePi = incomingIdentity.performancePi or payload.identity.performancePi
    payload.identity.primaryColorLabel = incomingIdentity.primaryColorLabel or payload.identity.primaryColorLabel

    payload.vehicle = payload.vehicle or {}
    payload.vehicle.modelHash = incomingVehicle.modelHash or payload.vehicle.modelHash
    if type(incomingVehicle.vehicleProperties) == "table" then
        payload.vehicle.vehicleProperties = incomingVehicle.vehicleProperties
    end

    if type(incomingTuning) == "table" then
        payload.tuning = incomingTuning
    end

    payload.updatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ")

    local encoded = json.encode(payload, { indent = true })
    if not encoded then
        return
    end

    local ok = SaveResourceFile(GetCurrentResourceName(), fileName, encoded, -1)
    if not ok then
        logVm("updateSavedVehicleSnapshot.reject", src, ("write_failed file=%s"):format(tostring(fileName)))
        return
    end

    upsertIndexEntry(ownerKey, buildIndexEntry(fileName, payload))
    logVm("updateSavedVehicleSnapshot.ok", src, ("saveId=%s file=%s"):format(tostring(saveId), tostring(fileName)))
    TriggerClientEvent("vehiclemanager:vehicleSnapshotUpdated", src, saveId)
end)

RegisterCommand("vm_save_inspect", function(src, args)
    if not src or src <= 0 then
        return
    end
    local saveId = tostring((args or {})[1] or "")
    if saveId == "" then
        TriggerClientEvent("chat:addMessage", src, { args = { "^1vehiclemanager", "Usage: /vm_save_inspect <saveId>" } })
        return
    end
    local ownerKey = getOwnerDirectory(src)
    if not ownerKey then
        notifyMissingLicenseIdentifier(src)
        return
    end
    local fileName = buildSaveFileNameFromId(ownerKey, saveId)
    local rawPayload = LoadResourceFile(GetCurrentResourceName(), fileName)
    if not rawPayload or rawPayload == "" then
        TriggerClientEvent("chat:addMessage", src, { args = { "^1vehiclemanager", ("Save not found: %s"):format(saveId) } })
        return
    end
    local payload = json.decode(rawPayload) or {}
    local identity = type(payload.identity) == "table" and payload.identity or {}
    local plate = tostring(identity.plate or "")
    local model = tostring(identity.displayName or identity.model or "unknown")
    local savedAt = tostring(payload.savedAt or "unknown")
    TriggerClientEvent("chat:addMessage", src, { args = { "^2vehiclemanager", ("saveId=%s model=%s plate=%s savedAt=%s"):format(saveId, model, plate, savedAt) } })
end, false)

RegisterCommand("vm_save_delete", function(src, args)
    if not src or src <= 0 then
        return
    end
    local saveId = tostring((args or {})[1] or "")
    if saveId == "" then
        TriggerClientEvent("chat:addMessage", src, { args = { "^1vehiclemanager", "Usage: /vm_save_delete <saveId>" } })
        return
    end
    local ownerKey = getOwnerDirectory(src)
    if not ownerKey then
        notifyMissingLicenseIdentifier(src)
        return
    end
    local fileName = buildSaveFileNameFromId(ownerKey, saveId)
    local removed = removeIndexEntryByFile(ownerKey, fileName)
    if not removed then
        TriggerClientEvent("chat:addMessage", src, { args = { "^1vehiclemanager", ("Save not found in index: %s"):format(saveId) } })
        return
    end
    SaveResourceFile(GetCurrentResourceName(), fileName, "", -1)
    logVm("vm_save_delete.ok", src, ("saveId=%s file=%s"):format(tostring(saveId), tostring(fileName)))
    TriggerClientEvent("vehiclemanager:receiveSavedVehicleIndex", src, loadVehicleIndex(ownerKey))
    TriggerClientEvent("chat:addMessage", src, { args = { "^2vehiclemanager", ("Deleted save: %s"):format(saveId) } })
end, false)

