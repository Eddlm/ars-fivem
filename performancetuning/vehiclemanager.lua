-- Manages per-vehicle tuning buckets, tracking, caching, and statebag sync.
PerformanceTuning = PerformanceTuning or {}
PerformanceTuning.VehicleManager = PerformanceTuning.VehicleManager or {}

local VehicleManager = PerformanceTuning.VehicleManager

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

VehicleManager.roundToThreeDecimals = roundToThreeDecimals

function VehicleManager.getVehicleCacheKey(vehicle)
    if not vehicle or vehicle == 0 then
        return nil
    end

    if NetworkGetEntityIsNetworked(vehicle) then
        return ('net:%s'):format(NetworkGetNetworkIdFromEntity(vehicle))
    end

    return ('ent:%s'):format(vehicle)
end

function VehicleManager.isVehicleEntityValid(vehicle)
    return vehicle ~= nil and vehicle ~= 0 and DoesEntityExist(vehicle)
end

function VehicleManager.isPedDrivingVehicle(ped, vehicle)
    return DoesEntityExist(ped)
        and VehicleManager.isVehicleEntityValid(vehicle)
        and GetPedInVehicleSeat(vehicle, -1) == ped
end

function VehicleManager.getVehicleBucket(vehicle, createIfMissing)
    local key = VehicleManager.getVehicleCacheKey(vehicle)
    if not key then
        return nil
    end

    local state = PerformanceTuning._state
    local bucket = state.originalHandlingByVehicle[key]
    if not bucket and createIfMissing then
        bucket = {}
        state.originalHandlingByVehicle[key] = bucket
    end

    return bucket
end

function VehicleManager.getTuningBucket(vehicle, createIfMissing)
    local key = VehicleManager.getVehicleCacheKey(vehicle)
    if not key then
        return nil
    end

    local state = PerformanceTuning._state
    if key:sub(1, 4) == 'net:' then
        local entityKey = ('ent:%s'):format(vehicle)
        if state.tuningStateByVehicle[entityKey] and not state.tuningStateByVehicle[key] then
            state.tuningStateByVehicle[key] = state.tuningStateByVehicle[entityKey]
            state.tuningStateByVehicle[entityKey] = nil
        end
    end

    local bucket = state.tuningStateByVehicle[key]
    if not bucket and createIfMissing then
        local nitrousConfig = PerformanceTuning._internals.NitrousConfig
        bucket = {
            enginePack = 'stock',
            transmissionPack = 'stock',
            suspensionPack = 'stock',
            tireCompoundPack = 'stock',
            tireCompoundCategory = 'stock',
            tireCompoundQuality = 'mid_end',
            nitrousLevel = 'stock',
            steeringLockMode = 'stock',
            nitrousAvailableCharge = 1.0,
            nitrousActiveUntil = 0,
            nitrousDurationMs = nitrousConfig.baseDurationMs,
            nitrousShotStrength = 1.0,
            nitrousAvailableNotified = true,
            revLimiterEnabled = false,
        }
        state.tuningStateByVehicle[key] = bucket
    end

    return bucket
end

function VehicleManager.trackVehicle(vehicle)
    local key = VehicleManager.getVehicleCacheKey(vehicle)
    if not key then
        return nil
    end

    local state = PerformanceTuning._state
    local tracked = state.trackedVehiclesByKey
    if tracked[key] then
        return key
    end

    tracked[key] = true
    local trackedKeys = state.trackedVehicleKeys
    trackedKeys[#trackedKeys + 1] = key
    return key
end

function VehicleManager.untrackVehicleByKey(key)
    if type(key) ~= 'string' or key == '' then
        return
    end

    local state = PerformanceTuning._state
    if not state.trackedVehiclesByKey[key] then
        return
    end

    state.trackedVehiclesByKey[key] = nil

    local trackedKeys = state.trackedVehicleKeys
    for index = #trackedKeys, 1, -1 do
        if trackedKeys[index] == key then
            table.remove(trackedKeys, index)
            break
        end
    end

    local trackedVehicleIndex = tonumber(state.trackedVehicleIndex) or 0
    if trackedVehicleIndex > #trackedKeys then
        state.trackedVehicleIndex = #trackedKeys
    end
end

function VehicleManager.resolveTrackedVehicleEntity(key)
    if type(key) ~= 'string' or key == '' then
        return 0
    end

    local id = tonumber(key:match(':(%d+)$'))
    if not id then
        return 0
    end

    if key:sub(1, 4) == 'net:' then
        return NetworkGetEntityFromNetworkId(id)
    end

    return id
end

function VehicleManager.serializeTuneState(bucket)
    local internals = PerformanceTuning._internals
    local antirollField = internals.ANTIROLL_FORCE_FIELD
    local antirollBiasField = internals.ANTIROLL_BIAS_FRONT_FIELD
    local brakeBiasField = internals.BRAKE_BIAS_FRONT_FIELD
    local suspensionBiasField = internals.SUSPENSION_BIAS_FRONT_FIELD
    local tireBiasField = internals.TIRE_BIAS_FRONT_FIELD
    local normalizeSteeringLockMode = internals.normalizeSteeringLockMode
    return {
        enginePack = bucket.enginePack or 'stock',
        transmissionPack = bucket.transmissionPack or 'stock',
        suspensionPack = (bucket.suspensionPack == 'street' and 'sport') or (bucket.suspensionPack or 'stock'),
        tireCompoundPack = bucket.tireCompoundPack or 'stock',
        tireCompoundCategory = bucket.tireCompoundCategory or 'stock',
        tireCompoundQuality = bucket.tireCompoundQuality or 'mid_end',
        brakePack = bucket.brakePack or 'stock',
        nitrousLevel = bucket.nitrousLevel or 'stock',
        steeringLockMode = normalizeSteeringLockMode(bucket.steeringLockMode),
        revLimiterEnabled = bucket.revLimiterEnabled == true,
        nitrousShotStrength = roundToThreeDecimals(bucket.nitrousShotStrength, 1.0) or 1.0,
        antirollForce = roundToThreeDecimals(internals.clampAntirollForceValue(bucket.antirollForce or bucket.baseAntiroll[antirollField] or 0.0), 0.0) or 0.0,
        brakeBiasFront = roundToThreeDecimals(internals.clampBrakeBiasFrontValue(bucket.brakeBiasFront or bucket.baseBrakes[brakeBiasField] or 0.5), 0.5) or 0.5,
        gripBiasFront = roundToThreeDecimals(internals.clampGripBiasFrontValue(bucket.gripBiasFront or bucket.baseTires[tireBiasField] or 0.5), 0.5) or 0.5,
        antirollBiasFront = roundToThreeDecimals(internals.clampAntirollBiasFrontValue(bucket.antirollBiasFront or bucket.baseAntiroll[antirollBiasField] or 0.5), 0.5) or 0.5,
        suspensionRaise = roundToThreeDecimals(internals.clampSuspensionRaiseValue(bucket.suspensionRaise or bucket.baseSuspension.fSuspensionRaise or 0.0), 0.0) or 0.0,
        suspensionBiasFront = roundToThreeDecimals(internals.clampSuspensionBiasFrontValue(bucket.suspensionBiasFront or bucket.baseSuspension[suspensionBiasField] or 0.5), 0.5) or 0.5,
    }
end

function VehicleManager.getLastAppliedTuneState(vehicle)
    local key = VehicleManager.getVehicleCacheKey(vehicle)
    return key and PerformanceTuning._state.lastAppliedTuneStateByVehicle[key] or nil
end

function VehicleManager.setLastAppliedTuneState(vehicle, state)
    local key = VehicleManager.getVehicleCacheKey(vehicle)
    if not key then
        return
    end

    PerformanceTuning._state.lastAppliedTuneStateByVehicle[key] = state
end

function VehicleManager.getLastAppliedPiState(vehicle)
    local key = VehicleManager.getVehicleCacheKey(vehicle)
    return key and PerformanceTuning._state.lastAppliedPiStateByVehicle[key] or nil
end

function VehicleManager.setLastAppliedPiState(vehicle, state)
    local key = VehicleManager.getVehicleCacheKey(vehicle)
    if not key then
        return
    end

    PerformanceTuning._state.lastAppliedPiStateByVehicle[key] = state
end

function VehicleManager.getLastPiStateUpdatedAt(vehicle)
    local key = VehicleManager.getVehicleCacheKey(vehicle)
    return key and PerformanceTuning._state.lastPiStateUpdatedAtByVehicle[key] or nil
end

function VehicleManager.setLastPiStateUpdatedAt(vehicle, timestampMs)
    local key = VehicleManager.getVehicleCacheKey(vehicle)
    if not key then
        return
    end

    PerformanceTuning._state.lastPiStateUpdatedAtByVehicle[key] = math.floor(tonumber(timestampMs) or 0)
end

function VehicleManager.piStatesEqual(a, b)
    if type(a) ~= 'table' or type(b) ~= 'table' then
        return false
    end

    local keys = { 'total', 'power', 'speed', 'topSpeed', 'grip', 'brake', 'class' }
    for _, key in ipairs(keys) do
        if a[key] ~= b[key] then
            return false
        end
    end

    return true
end

function VehicleManager.buildPiState(vehicle)
    if not VehicleManager.isVehicleEntityValid(vehicle) then
        return nil
    end

    local performancePanel = PerformanceTuning.PerformancePanel or {}
    local metrics = type(performancePanel.buildMetrics) == 'function' and performancePanel.buildMetrics(vehicle) or nil
    if type(metrics) ~= 'table' then
        return nil
    end

    local values = type(metrics.values) == 'table' and metrics.values or {}
    return {
        total = math.floor(tonumber(metrics.total) or 0),
        power = math.floor(tonumber(values[1]) or 0),
        speed = math.floor(tonumber(values[2]) or 0),
        topSpeed = math.floor(tonumber(values[2]) or 0),
        grip = math.floor(tonumber(values[3]) or 0),
        brake = math.floor(tonumber(values[4]) or 0),
    }
end

function VehicleManager.syncVehiclePiState(vehicle, ensureNetworked, forceUpdate)
    if not VehicleManager.isVehicleEntityValid(vehicle) then
        return false
    end

    local now = GetGameTimer()
    local updateIntervalMs = 500
    if forceUpdate ~= true then
        local lastUpdatedAt = tonumber(VehicleManager.getLastPiStateUpdatedAt(vehicle)) or 0
        if (now - lastUpdatedAt) < updateIntervalMs then
            return false
        end
    end

    if ensureNetworked == true then
        if not VehicleManager.ensureVehicleNetworked(vehicle, 500) then
            return false
        end
    elseif not NetworkGetEntityIsNetworked(vehicle) then
        return false
    end

    local piState = VehicleManager.buildPiState(vehicle)
    if not piState then
        return false
    end

    VehicleManager.setLastPiStateUpdatedAt(vehicle, now)

    local previousState = VehicleManager.getLastAppliedPiState(vehicle)
    if previousState and VehicleManager.piStatesEqual(previousState, piState) then
        return false
    end

    local piStateKey = PerformanceTuning._internals.StateBagKeys.pi
    if type(piStateKey) ~= 'string' or piStateKey == '' then
        return false
    end

    Entity(vehicle).state:set(piStateKey, piState, true)
    VehicleManager.setLastAppliedPiState(vehicle, piState)
    return true
end

function VehicleManager.tuneStatesEqual(a, b)
    if type(a) ~= 'table' or type(b) ~= 'table' then
        return false
    end

    local function sameNumber(left, right, fallback, tolerance)
        local lhs = left
        if lhs == nil then
            lhs = fallback
        end

        local rhs = right
        if rhs == nil then
            rhs = fallback
        end

        return math.abs(lhs - rhs) <= tolerance
    end

    if a.enginePack ~= b.enginePack
        or a.transmissionPack ~= b.transmissionPack
        or a.suspensionPack ~= b.suspensionPack
        or a.tireCompoundPack ~= b.tireCompoundPack
        or (a.tireCompoundCategory or 'stock') ~= (b.tireCompoundCategory or 'stock')
        or (a.tireCompoundQuality or 'mid_end') ~= (b.tireCompoundQuality or 'mid_end')
        or a.brakePack ~= b.brakePack
        or a.nitrousLevel ~= b.nitrousLevel
        or (a.steeringLockMode or 'stock') ~= (b.steeringLockMode or 'stock')
        or (a.revLimiterEnabled == true) ~= (b.revLimiterEnabled == true)
    then
        return false
    end

    return sameNumber(a.nitrousShotStrength, b.nitrousShotStrength, 1.0, 0.0001)
        and sameNumber(a.antirollForce, b.antirollForce, 0.0, 0.0001)
        and sameNumber(a.brakeBiasFront, b.brakeBiasFront, 0.5, 0.0001)
        and sameNumber(a.gripBiasFront, b.gripBiasFront, 0.5, 0.0001)
        and sameNumber(a.antirollBiasFront, b.antirollBiasFront, 0.5, 0.0001)
        and sameNumber(a.suspensionRaise, b.suspensionRaise, 0.0, 0.0001)
        and sameNumber(a.suspensionBiasFront, b.suspensionBiasFront, 0.5, 0.0001)
end

function VehicleManager.getCurrentVehicle()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then
        return nil, 'Player ped does not exist.'
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then
        return nil, 'You are not inside a vehicle.'
    end

    if not VehicleManager.isPedDrivingVehicle(ped, vehicle) then
        return nil, 'You must be in the driver seat to tune this vehicle.'
    end

    return vehicle
end

function VehicleManager.ensureVehicleNetworked(vehicle, timeoutMs)
    if not VehicleManager.isVehicleEntityValid(vehicle) then
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

function VehicleManager.serializeFieldTable(fieldNames, source)
    local serialized = {}

    for _, fieldName in ipairs(fieldNames or {}) do
        local value = type(source) == 'table' and source[fieldName] or nil
        if value ~= nil then
            serialized[fieldName] = value
        end
    end

    return serialized
end

function VehicleManager.readFieldTable(vehicle, fieldNames, fieldTypeResolver)
    local values = {}
    local readHandlingValue = PerformanceTuning.HandlingManager.readHandlingValue

    for _, fieldName in ipairs(fieldNames or {}) do
        local fieldType = type(fieldTypeResolver) == 'function' and fieldTypeResolver(fieldName) or fieldTypeResolver
        values[fieldName] = readHandlingValue(vehicle, fieldType, fieldName)
    end

    return values
end

function VehicleManager.buildPersistedHandlingState(vehicle, bucket)
    local internals = PerformanceTuning._internals
    if not VehicleManager.isVehicleEntityValid(vehicle) or type(bucket) ~= 'table' then
        return nil
    end

    return {
        version = 1,
        original = {
            engine = VehicleManager.serializeFieldTable(internals.ENGINE_FIELDS, bucket.baseEngine),
            transmission = VehicleManager.serializeFieldTable(internals.TRANSMISSION_FIELDS, bucket.baseTransmission),
            suspension = VehicleManager.serializeFieldTable(internals.SUSPENSION_FIELDS, bucket.baseSuspension),
            tires = VehicleManager.serializeFieldTable(internals.TIRE_FIELDS, bucket.baseTires),
            brakes = VehicleManager.serializeFieldTable(internals.BRAKE_FIELDS, bucket.baseBrakes),
            antiroll = VehicleManager.serializeFieldTable(internals.ANTIROLL_FIELDS, bucket.baseAntiroll),
        },
        tuned = {
            engine = VehicleManager.readFieldTable(vehicle, internals.ENGINE_FIELDS, 'float'),
            transmission = VehicleManager.readFieldTable(vehicle, internals.TRANSMISSION_FIELDS, function(fieldName)
                return fieldName == internals.GEAR_FIELD and 'int' or 'float'
            end),
            suspension = VehicleManager.readFieldTable(vehicle, internals.SUSPENSION_FIELDS, 'float'),
            tires = VehicleManager.readFieldTable(vehicle, internals.TIRE_FIELDS, 'float'),
            brakes = VehicleManager.readFieldTable(vehicle, internals.BRAKE_FIELDS, 'float'),
            antiroll = VehicleManager.readFieldTable(vehicle, internals.ANTIROLL_FIELDS, 'float'),
        }
    }
end

function VehicleManager.syncVehicleHandlingState(vehicle)
    if not VehicleManager.isVehicleEntityValid(vehicle) then
        return
    end

    if not VehicleManager.ensureVehicleNetworked(vehicle, 1500) then
        return
    end

    local bucket = VehicleManager.ensureTuningState(vehicle)
    local state = VehicleManager.buildPersistedHandlingState(vehicle, bucket)
    if not state then
        return
    end

    Entity(vehicle).state:set(PerformanceTuning._internals.StateBagKeys.handling, state, true)
    VehicleManager.syncVehiclePiState(vehicle, false)
end

function VehicleManager.applyPersistedHandlingBaseState(vehicle, tuningBucket)
    local internals = PerformanceTuning._internals
    if not VehicleManager.isVehicleEntityValid(vehicle) or type(tuningBucket) ~= 'table' then
        return false
    end

    if not NetworkGetEntityIsNetworked(vehicle) then
        return false
    end

    local persistedState = Entity(vehicle).state[internals.StateBagKeys.handling]
    local originalState = type(persistedState) == 'table' and persistedState.original or nil
    if type(originalState) ~= 'table' then
        return false
    end

    if type(originalState.engine) == 'table' and tuningBucket.baseEngine == nil then
        tuningBucket.baseEngine = VehicleManager.serializeFieldTable(internals.ENGINE_FIELDS, originalState.engine)
        tuningBucket.basePower = tuningBucket.baseEngine[internals.POWER_FIELD]
        tuningBucket.baseTopSpeed = tuningBucket.baseEngine[internals.TOP_SPEED_FIELD]
    end

    if type(originalState.transmission) == 'table' and tuningBucket.baseTransmission == nil then
        tuningBucket.baseTransmission = VehicleManager.serializeFieldTable(internals.TRANSMISSION_FIELDS, originalState.transmission)
    end

    if type(originalState.suspension) == 'table' and tuningBucket.baseSuspension == nil then
        tuningBucket.baseSuspension = VehicleManager.serializeFieldTable(internals.SUSPENSION_FIELDS, originalState.suspension)
    end

    if type(originalState.tires) == 'table' and tuningBucket.baseTires == nil then
        tuningBucket.baseTires = VehicleManager.serializeFieldTable(internals.TIRE_FIELDS, originalState.tires)
    end

    if type(originalState.brakes) == 'table' and tuningBucket.baseBrakes == nil then
        tuningBucket.baseBrakes = VehicleManager.serializeFieldTable(internals.BRAKE_FIELDS, originalState.brakes)
    end

    if type(originalState.antiroll) == 'table' and tuningBucket.baseAntiroll == nil then
        tuningBucket.baseAntiroll = VehicleManager.serializeFieldTable(internals.ANTIROLL_FIELDS, originalState.antiroll)
    end

    return true
end

function VehicleManager.ensureTuningState(vehicle)
    local internals = PerformanceTuning._internals
    local bucket = VehicleManager.getTuningBucket(vehicle, true)
    VehicleManager.trackVehicle(vehicle)
    VehicleManager.applyPersistedHandlingBaseState(vehicle, bucket)

    if bucket.basePower == nil then
        local readHandlingValue = PerformanceTuning.HandlingManager.readHandlingValue
        bucket.basePower = readHandlingValue(vehicle, 'float', internals.POWER_FIELD)
        bucket.baseTopSpeed = readHandlingValue(vehicle, 'float', internals.TOP_SPEED_FIELD)
        if (internals.STEERING_LOCK_FIELD or '') ~= '' then
            bucket.baseSteeringLock = readHandlingValue(vehicle, 'float', internals.STEERING_LOCK_FIELD)
        end
        if internals.DRAG_FIELD then
            bucket.baseDrag = readHandlingValue(vehicle, 'float', internals.DRAG_FIELD)
        end
    end

    if bucket.steeringLockMode == nil then
        bucket.steeringLockMode = 'stock'
    end
    if bucket.tireCompoundCategory == nil then
        bucket.tireCompoundCategory = 'stock'
    end
    if bucket.tireCompoundQuality == nil then
        bucket.tireCompoundQuality = 'mid_end'
    end

    if (internals.STEERING_LOCK_FIELD or '') ~= '' and bucket.baseSteeringLock == nil then
        bucket.baseSteeringLock = PerformanceTuning.HandlingManager.readHandlingValue(vehicle, 'float', internals.STEERING_LOCK_FIELD)
    end

    if internals.DRAG_FIELD and bucket.baseDrag == nil then
        bucket.baseDrag = PerformanceTuning.HandlingManager.readHandlingValue(vehicle, 'float', internals.DRAG_FIELD)
    end

    if bucket.baseSuspension == nil then
        bucket.baseSuspension = {}
        for _, fieldName in ipairs(internals.SUSPENSION_FIELDS) do
            bucket.baseSuspension[fieldName] = PerformanceTuning.HandlingManager.readHandlingValue(vehicle, 'float', fieldName)
        end
    end

    if bucket.baseTransmission == nil then
        bucket.baseTransmission = {}
        for _, fieldName in ipairs(internals.TRANSMISSION_FIELDS) do
            local fieldType = fieldName == internals.GEAR_FIELD and 'int' or 'float'
            bucket.baseTransmission[fieldName] = PerformanceTuning.HandlingManager.readHandlingValue(vehicle, fieldType, fieldName)
        end
    end

    if bucket.baseEngine == nil then
        bucket.baseEngine = {}
        for _, fieldName in ipairs(internals.ENGINE_FIELDS) do
            bucket.baseEngine[fieldName] = PerformanceTuning.HandlingManager.readHandlingValue(vehicle, 'float', fieldName)
        end

        if internals.DRAG_FIELD then
            bucket.baseEngine[internals.DRAG_FIELD] = PerformanceTuning.HandlingManager.readHandlingValue(vehicle, 'float', internals.DRAG_FIELD)
            if bucket.baseDrag == nil then
                bucket.baseDrag = bucket.baseEngine[internals.DRAG_FIELD]
            end
        end
    end

    if bucket.baseTires == nil then
        bucket.baseTires = {}
        for _, fieldName in ipairs(internals.TIRE_FIELDS) do
            bucket.baseTires[fieldName] = PerformanceTuning.HandlingManager.readHandlingValue(vehicle, 'float', fieldName)
        end
    end

    if bucket.baseBrakes == nil then
        bucket.baseBrakes = {}
        for _, fieldName in ipairs(internals.BRAKE_FIELDS) do
            bucket.baseBrakes[fieldName] = PerformanceTuning.HandlingManager.readHandlingValue(vehicle, 'float', fieldName)
        end
    end

    if bucket.baseAntiroll == nil then
        bucket.baseAntiroll = {}
        for _, fieldName in ipairs(internals.ANTIROLL_FIELDS) do
            bucket.baseAntiroll[fieldName] = PerformanceTuning.HandlingManager.readHandlingValue(vehicle, 'float', fieldName)
        end
    end

    return bucket
end

function VehicleManager.syncVehicleTuneState(vehicle)
    if not VehicleManager.isVehicleEntityValid(vehicle) then
        return
    end

    local bucket = VehicleManager.ensureTuningState(vehicle)
    VehicleManager.trackVehicle(vehicle)
    local state = VehicleManager.serializeTuneState(bucket)
    VehicleManager.setLastAppliedTuneState(vehicle, state)

    if VehicleManager.ensureVehicleNetworked(vehicle, 1500) then
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        if netId and netId ~= 0 then
            local runtimeState = PerformanceTuning.RuntimeState or {}
            runtimeState.localTuneAuthoredUntilByNetId = runtimeState.localTuneAuthoredUntilByNetId or {}
            runtimeState.localTuneAuthoredUntilByNetId[netId] = GetGameTimer() + 2000
        end

        Entity(vehicle).state:set(PerformanceTuning._internals.StateBagKeys.tune, state, true)
        if netId and netId ~= 0 then
            TriggerServerEvent('performancetuning:registerTunedVehicle', netId)
        end
    end

    VehicleManager.syncVehicleHandlingState(vehicle)
    VehicleManager.syncVehiclePiState(vehicle, false)
end
