-- Reads, writes, formats, and parses handling fields for tuned vehicles.
PerformanceTuning = PerformanceTuning or {}
PerformanceTuning.HandlingManager = PerformanceTuning.HandlingManager or {}

local HandlingManager = PerformanceTuning.HandlingManager

function HandlingManager.normalizeFieldName(fieldName)
    local trim = PerformanceTuning._internals.trim
    local normalized = trim(fieldName)
    if normalized == '' then
        return nil, 'Handling field name is required.'
    end

    return normalized
end

function HandlingManager.normalizeFieldType(fieldType, fieldName)
    local internals = PerformanceTuning._internals
    local trim = internals.trim
    local startsWith = internals.startsWith
    local aliases = internals.FIELD_TYPE_ALIASES
    local knownFieldTypes = internals.KNOWN_FIELD_TYPES
    local normalizedFieldName = trim(fieldName or '')
    local normalizedType = trim(fieldType or ''):lower()

    if normalizedType ~= '' then
        normalizedType = aliases[normalizedType] or normalizedType
        if normalizedType == 'float' or normalizedType == 'int' or normalizedType == 'vector' then
            return normalizedType
        end

        return nil, ('Unsupported field type "%s". Use float, int, or vector.'):format(fieldType)
    end

    if knownFieldTypes[normalizedFieldName] then
        return knownFieldTypes[normalizedFieldName]
    end

    if startsWith(normalizedFieldName, 'vec') then
        return 'vector'
    end

    if startsWith(normalizedFieldName, 'n') or startsWith(normalizedFieldName, 'str') or normalizedFieldName == 'AIHandling' then
        return 'int'
    end

    return 'float'
end

function HandlingManager.readHandlingValue(vehicle, fieldType, fieldName)
    local handlingClass = PerformanceTuning._internals.HANDLING_CLASS
    if fieldType == 'float' then
        return GetVehicleHandlingFloat(vehicle, handlingClass, fieldName)
    end

    if fieldType == 'int' then
        return GetVehicleHandlingInt(vehicle, handlingClass, fieldName)
    end

    if fieldType == 'vector' then
        return GetVehicleHandlingVector(vehicle, handlingClass, fieldName)
    end

    return nil
end

function HandlingManager.writeHandlingValue(vehicle, fieldType, fieldName, value)
    local handlingClass = PerformanceTuning._internals.HANDLING_CLASS
    if fieldType == 'float' then
        SetVehicleHandlingFloat(vehicle, handlingClass, fieldName, value)
        return true
    end

    if fieldType == 'int' then
        SetVehicleHandlingInt(vehicle, handlingClass, fieldName, value)
        return true
    end

    if fieldType == 'vector' then
        SetVehicleHandlingVector(vehicle, handlingClass, fieldName, value)
        return true
    end

    return false
end

function HandlingManager.parseScalarNumber(rawValue, integerOnly)
    local parsed = tonumber(rawValue)
    if not PerformanceTuning._internals.isFiniteNumber(parsed) then
        return nil
    end

    if integerOnly then
        return math.floor(parsed >= 0 and parsed + 0.5 or parsed - 0.5)
    end

    return parsed
end

function HandlingManager.parseVectorValue(rawValues)
    local joined = table.concat(rawValues, ' ')
    local components = {}

    for part in joined:gmatch('[^,%s]+') do
        components[#components + 1] = tonumber(part)
    end

    if #components ~= 3 then
        return nil, 'Vector values must be three numbers, e.g. 0.0 0.1 -0.2'
    end

    for index = 1, 3 do
        if not PerformanceTuning._internals.isFiniteNumber(components[index]) then
            return nil, 'Vector values must be valid numbers.'
        end
    end

    return vector3(components[1], components[2], components[3])
end

function HandlingManager.parseValueForType(fieldType, rawValues)
    if fieldType == 'vector' then
        return HandlingManager.parseVectorValue(rawValues)
    end

    local rawValue = rawValues[1]
    if rawValue == nil then
        return nil, 'A value is required.'
    end

    local numericValue = HandlingManager.parseScalarNumber(rawValue, fieldType == 'int')
    if numericValue == nil then
        return nil, ('"%s" is not a valid %s value.'):format(tostring(rawValue), fieldType)
    end

    return numericValue
end

function HandlingManager.formatHandlingValue(value, fieldType)
    if fieldType == 'vector' and type(value) == 'vector3' then
        return ('vector3(%.4f, %.4f, %.4f)'):format(value.x, value.y, value.z)
    end

    if type(value) == 'number' then
        return ('%.6f'):format(value)
    end

    return tostring(value)
end

function HandlingManager.rememberOriginalValue(vehicle, fieldName, fieldType)
    local vehicleManager = PerformanceTuning.VehicleManager
    local bucket = vehicleManager.getVehicleBucket(vehicle, true)
    if bucket[fieldName] ~= nil then
        return
    end

    bucket[fieldName] = {
        fieldType = fieldType,
        value = HandlingManager.readHandlingValue(vehicle, fieldType, fieldName)
    }
end

function HandlingManager.getHandlingField(fieldName, fieldType, vehicle)
    local resolvedFieldName, fieldNameError = HandlingManager.normalizeFieldName(fieldName)
    if not resolvedFieldName then
        return nil, fieldNameError
    end

    local resolvedType, typeError = HandlingManager.normalizeFieldType(fieldType, resolvedFieldName)
    if not resolvedType then
        return nil, typeError
    end

    local resolvedVehicle = vehicle
    if not resolvedVehicle then
        local vehicleResult, vehicleError = PerformanceTuning.VehicleManager.getCurrentVehicle()
        if not vehicleResult then
            return nil, vehicleError
        end

        resolvedVehicle = vehicleResult
    end

    if not DoesEntityExist(resolvedVehicle) then
        return nil, 'Vehicle does not exist.'
    end

    return HandlingManager.readHandlingValue(resolvedVehicle, resolvedType, resolvedFieldName), nil, resolvedType
end

function HandlingManager.setHandlingField(fieldName, value, fieldType, vehicle)
    local internals = PerformanceTuning._internals
    local resolvedFieldName, fieldNameError = HandlingManager.normalizeFieldName(fieldName)
    if not resolvedFieldName then
        return false, fieldNameError
    end

    local resolvedType, typeError = HandlingManager.normalizeFieldType(fieldType, resolvedFieldName)
    if not resolvedType then
        return false, typeError
    end

    local resolvedVehicle = vehicle
    if not resolvedVehicle then
        local vehicleResult, vehicleError = PerformanceTuning.VehicleManager.getCurrentVehicle()
        if not vehicleResult then
            return false, vehicleError
        end

        resolvedVehicle = vehicleResult
    end

    if not DoesEntityExist(resolvedVehicle) then
        return false, 'Vehicle does not exist.'
    end

    if resolvedType == 'float' and not internals.isFiniteNumber(value) then
        return false, 'Float handling values must be valid numbers.'
    end

    if resolvedType == 'int' and type(value) ~= 'number' then
        return false, 'Int handling values must be numbers.'
    end

    if resolvedType == 'int' then
        value = math.floor(value >= 0 and value + 0.5 or value - 0.5)
    end

    if resolvedType == 'vector' and type(value) ~= 'vector3' then
        return false, 'Vector handling values must be a vector3.'
    end

    HandlingManager.rememberOriginalValue(resolvedVehicle, resolvedFieldName, resolvedType)
    HandlingManager.writeHandlingValue(resolvedVehicle, resolvedType, resolvedFieldName, value)

    internals.refreshVehicleAfterHandlingChange(resolvedVehicle)
    PerformanceTuning.VehicleManager.syncVehicleHandlingState(resolvedVehicle)

    local updatedValue = HandlingManager.readHandlingValue(resolvedVehicle, resolvedType, resolvedFieldName)
    return true, updatedValue, resolvedType
end

function HandlingManager.resetHandlingField(fieldName, vehicle)
    local internals = PerformanceTuning._internals
    local resolvedFieldName, fieldNameError = HandlingManager.normalizeFieldName(fieldName)
    if not resolvedFieldName then
        return false, fieldNameError
    end

    local resolvedVehicle = vehicle
    if not resolvedVehicle then
        local vehicleResult, vehicleError = PerformanceTuning.VehicleManager.getCurrentVehicle()
        if not vehicleResult then
            return false, vehicleError
        end

        resolvedVehicle = vehicleResult
    end

    local vehicleManager = PerformanceTuning.VehicleManager
    local bucket = vehicleManager.getVehicleBucket(resolvedVehicle, false)
    if not bucket or not bucket[resolvedFieldName] then
        return false, ('No cached original value exists for %s on this vehicle.'):format(resolvedFieldName)
    end

    local originalEntry = bucket[resolvedFieldName]
    HandlingManager.writeHandlingValue(resolvedVehicle, originalEntry.fieldType, resolvedFieldName, originalEntry.value)

    if resolvedFieldName == 'fSuspensionRaise' and bucket.fSuspensionUpperLimit then
        local pairedUpperEntry = bucket.fSuspensionUpperLimit
        HandlingManager.writeHandlingValue(resolvedVehicle, pairedUpperEntry.fieldType, 'fSuspensionUpperLimit', pairedUpperEntry.value)
        bucket.fSuspensionUpperLimit = nil
    end

    if resolvedFieldName == 'fSuspensionRaise' and bucket.fSuspensionLowerLimit then
        local pairedLowerEntry = bucket.fSuspensionLowerLimit
        HandlingManager.writeHandlingValue(resolvedVehicle, pairedLowerEntry.fieldType, 'fSuspensionLowerLimit', pairedLowerEntry.value)
        bucket.fSuspensionLowerLimit = nil
    end

    PerformanceTuning._internals.refreshVehicleAfterHandlingChange(resolvedVehicle)
    bucket[resolvedFieldName] = nil

    if next(bucket) == nil then
        PerformanceTuning._state.originalHandlingByVehicle[vehicleManager.getVehicleCacheKey(resolvedVehicle)] = nil
    end

    vehicleManager.syncVehicleHandlingState(resolvedVehicle)
    return true, originalEntry.value, originalEntry.fieldType
end

function HandlingManager.resetAllHandling(vehicle)
    local internals = PerformanceTuning._internals
    local resolvedVehicle = vehicle
    if not resolvedVehicle then
        local vehicleResult, vehicleError = PerformanceTuning.VehicleManager.getCurrentVehicle()
        if not vehicleResult then
            return false, vehicleError
        end

        resolvedVehicle = vehicleResult
    end

    local vehicleManager = PerformanceTuning.VehicleManager
    local key = vehicleManager.getVehicleCacheKey(resolvedVehicle)
    local bucket = key and PerformanceTuning._state.originalHandlingByVehicle[key] or nil
    if not bucket then
        return false, 'No cached original handling values exist for this vehicle.'
    end

    local count = 0
    for trackedFieldName, entry in pairs(bucket) do
        HandlingManager.writeHandlingValue(resolvedVehicle, entry.fieldType, trackedFieldName, entry.value)
        count = count + 1
    end

    PerformanceTuning._internals.refreshVehicleAfterHandlingChange(resolvedVehicle)
    PerformanceTuning._state.originalHandlingByVehicle[key] = nil
    vehicleManager.syncVehicleHandlingState(resolvedVehicle)
    return true, count
end
