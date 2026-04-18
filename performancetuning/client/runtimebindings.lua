-- Wires shared runtime PerformanceTuning._state, PerformanceTuning._internals, and ScaleformUI services across modules.
PerformanceTuning = PerformanceTuning or {}
PerformanceTuning._state = PerformanceTuning._state or {}
PerformanceTuning._internals = PerformanceTuning._internals or {}
PerformanceTuning.ScaleformUI = PerformanceTuning.ScaleformUI or {}
local INTERNAL_PERFORMANCE_CONSTANTS = {
    flatVelToMphFactor = 145.0 / 176.0,
}
local INTERNAL_BAR_FILL_TARGETS = {
    power = 0.60,
    topSpeedMph = 220.0,
    grip = 2.50,
    brake = 2.50,
    barSegmentCount = 20,
}
local INTERNAL_BRAKE_SCALING = { barTopValueUnits = INTERNAL_BAR_FILL_TARGETS.brake }

local function trimRuntimeValue(value)
    return (tostring(value or ''):match('^%s*(.-)%s*$'))
end

local function resolveSwapModelLabel(modelHash, fallbackModelCode)
    local displayCode = GetDisplayNameFromVehicleModel(modelHash)
    if type(displayCode) ~= 'string' or displayCode == '' or displayCode == 'CARNOTFOUND' then
        displayCode = tostring(fallbackModelCode or '')
    end

    if displayCode ~= '' and displayCode ~= 'CARNOTFOUND' then
        local label = GetLabelText(displayCode)
        if type(label) == 'string' and label ~= '' and label ~= 'NULL' then
            return label
        end
        return displayCode
    end

    return tostring(fallbackModelCode or 'UNKNOWN')
end

local function getConfiguredEngineSwaps()
    local swaps = {}
    local seenIds = {}
    local rawCsv = GetConvar('pt_engine_swaps', '')

    for token in tostring(rawCsv or ''):gmatch('([^,]+)') do
        local trimmedToken = trimRuntimeValue(token)
        if trimmedToken ~= '' then
            local normalizedModelCode = trimmedToken:upper()
            if not seenIds[normalizedModelCode] then
                local modelHash = GetHashKey(normalizedModelCode)
                local isValidVehicleModel = modelHash ~= 0 and IsModelInCdimage(modelHash) and IsModelAVehicle(modelHash)
                if isValidVehicleModel then
                    local resolvedName = resolveSwapModelLabel(modelHash, normalizedModelCode)
                    swaps[#swaps + 1] = {
                        id = normalizedModelCode,
                        swapModel = normalizedModelCode,
                        enabled = true,
                        label = ('%s Swap'):format(resolvedName),
                        description = ('Uses %s engine values and audio for a full swap.'):format(resolvedName),
                    }
                    seenIds[normalizedModelCode] = true
                end
            end
        end
    end

    return swaps
end

local function resolvePerformanceFromRuntimeConfig()
    local configured = (PerformanceTuning.RuntimeConfig or {}).performanceBarFillTargets or {}
    local barSegmentCount = math.max(1, math.floor(tonumber(configured.barSegmentCount) or INTERNAL_BAR_FILL_TARGETS.barSegmentCount))
    local powerTarget = tonumber(configured.power) or INTERNAL_BAR_FILL_TARGETS.power
    local topSpeedTarget = tonumber(configured.topSpeedMph) or INTERNAL_BAR_FILL_TARGETS.topSpeedMph
    local gripTarget = tonumber(configured.grip) or INTERNAL_BAR_FILL_TARGETS.grip
    local brakeTarget = tonumber(configured.brake) or INTERNAL_BAR_FILL_TARGETS.brake

    if powerTarget <= 0.0 then powerTarget = INTERNAL_BAR_FILL_TARGETS.power end
    if topSpeedTarget <= 0.0 then topSpeedTarget = INTERNAL_BAR_FILL_TARGETS.topSpeedMph end
    if gripTarget <= 0.0 then gripTarget = INTERNAL_BAR_FILL_TARGETS.grip end
    if brakeTarget <= 0.0 then brakeTarget = INTERNAL_BAR_FILL_TARGETS.brake end

    return {
        performance = {
            barSegmentCount = barSegmentCount,
            powerBarScaleFactor = barSegmentCount / powerTarget,
            topSpeedBarScaleFactor = barSegmentCount / topSpeedTarget,
            gripBarScaleFactor = barSegmentCount / gripTarget,
            flatVelToMphFactor = INTERNAL_PERFORMANCE_CONSTANTS.flatVelToMphFactor,
        },
        brakeScaling = {
            barTopValueUnits = brakeTarget,
        },
    }
end
local handlingFields = (PerformanceTuning.Definitions or {}).handlingFields or {}
local engineFields = (PerformanceTuning.Definitions or {}).engineFields or {}
local transmissionFields = (PerformanceTuning.Definitions or {}).transmissionFields or {}
local suspensionFields = (PerformanceTuning.Definitions or {}).suspensionFields or {}
local tireFields = (PerformanceTuning.Definitions or {}).tireFields or {}
local brakeFields = (PerformanceTuning.Definitions or {}).brakeFields or {}
local antirollFields = (PerformanceTuning.Definitions or {}).antirollFields or {}
local fieldTypeAliases = (PerformanceTuning.Definitions or {}).fieldTypeAliases or {}
local knownFieldTypes = (PerformanceTuning.Definitions or {}).knownFieldTypes or {}
local packDefinitions = (PerformanceTuning.Config or {}).packDefinitions or {}
PerformanceTuning._state.originalHandlingByVehicle = (PerformanceTuning.RuntimeState or {}).originalHandlingByVehicle
PerformanceTuning._state.tuningStateByVehicle = (PerformanceTuning.RuntimeState or {}).tuningStateByVehicle
PerformanceTuning._state.lastAppliedTuneStateByVehicle = (PerformanceTuning.RuntimeState or {}).lastAppliedTuneStateByVehicle
PerformanceTuning._state.lastAppliedPiStateByVehicle = (PerformanceTuning.RuntimeState or {}).lastAppliedPiStateByVehicle
PerformanceTuning._state.lastPiStateUpdatedAtByVehicle = (PerformanceTuning.RuntimeState or {}).lastPiStateUpdatedAtByVehicle
PerformanceTuning._state.cachedEngineSwapValuesByModel = (PerformanceTuning.RuntimeState or {}).cachedEngineSwapValuesByModel
PerformanceTuning._state.trackedVehiclesByKey = (PerformanceTuning.RuntimeState or {}).trackedVehiclesByKey
PerformanceTuning._state.trackedVehicleKeys = (PerformanceTuning.RuntimeState or {}).trackedVehicleKeys

PerformanceTuning._internals.HANDLING_CLASS = (PerformanceTuning.Definitions or {}).handlingClass
PerformanceTuning._internals.StateBagKeys = (PerformanceTuning.Definitions or {}).stateBagKeys
PerformanceTuning._internals.ENGINE_FIELDS = engineFields
PerformanceTuning._internals.TRANSMISSION_FIELDS = transmissionFields
PerformanceTuning._internals.SUSPENSION_FIELDS = suspensionFields
PerformanceTuning._internals.TIRE_FIELDS = tireFields
PerformanceTuning._internals.BRAKE_FIELDS = brakeFields
PerformanceTuning._internals.ANTIROLL_FIELDS = antirollFields
PerformanceTuning._internals.POWER_FIELD = handlingFields.engine and handlingFields.engine.power or nil
PerformanceTuning._internals.TOP_SPEED_FIELD = handlingFields.engine and handlingFields.engine.topSpeed or nil
PerformanceTuning._internals.DRAG_FIELD = handlingFields.engine and handlingFields.engine.drag or nil
PerformanceTuning._internals.STEERING_LOCK_FIELD = handlingFields.steering and handlingFields.steering.lock or nil
PerformanceTuning._internals.GEAR_FIELD = handlingFields.transmission and handlingFields.transmission.gear or nil
PerformanceTuning._internals.CLUTCH_UPSHIFT_FIELD = handlingFields.transmission and handlingFields.transmission.clutchUpshift or nil
PerformanceTuning._internals.BRAKE_FORCE_FIELD = handlingFields.brakes and handlingFields.brakes.force or nil
PerformanceTuning._internals.HANDBRAKE_FORCE_FIELD = handlingFields.brakes and handlingFields.brakes.handbrakeForce or nil
PerformanceTuning._internals.TIRE_BIAS_FRONT_FIELD = handlingFields.tires and handlingFields.tires.biasFront or nil
PerformanceTuning._internals.TIRE_MAX_FIELD = handlingFields.tires and handlingFields.tires.max or nil
PerformanceTuning._internals.SUSPENSION_BIAS_FRONT_FIELD = handlingFields.suspension and handlingFields.suspension.biasFront or nil
PerformanceTuning._internals.ANTIROLL_FORCE_FIELD = handlingFields.antiroll and handlingFields.antiroll.force or nil
PerformanceTuning._internals.ANTIROLL_BIAS_FRONT_FIELD = handlingFields.antiroll and handlingFields.antiroll.biasFront or nil
PerformanceTuning._internals.BRAKE_BIAS_FRONT_FIELD = handlingFields.brakes and handlingFields.brakes.biasFront or nil
PerformanceTuning._internals.ENGINE_SWAP_MODEL_NAME = (PerformanceTuning.Definitions or {}).engineSwapModelName
local resolvedPerformanceConfig = resolvePerformanceFromRuntimeConfig()
PerformanceTuning._internals.BRAKE_SCALING = resolvedPerformanceConfig.brakeScaling
PerformanceTuning._internals.FIELD_TYPE_ALIASES = fieldTypeAliases
PerformanceTuning._internals.KNOWN_FIELD_TYPES = knownFieldTypes
PerformanceTuning._internals.SUSPENSION_PACKS = packDefinitions.suspension
PerformanceTuning._internals.TRANSMISSION_PACKS = packDefinitions.transmission
PerformanceTuning._internals.ENGINE_PACKS = packDefinitions.engine
PerformanceTuning._internals.getConfiguredEngineSwaps = getConfiguredEngineSwaps
PerformanceTuning._internals.ENGINE_SWAPS = getConfiguredEngineSwaps()
PerformanceTuning._internals.TIRE_COMPOUND_PACKS = packDefinitions.tires
PerformanceTuning._internals.BRAKE_PACKS = packDefinitions.brakes
PerformanceTuning._internals.HANDBRAKE_PACKS = packDefinitions.handbrakes or packDefinitions.brakes or {}
PerformanceTuning._internals.NITROUS_PACKS = packDefinitions.nitrous
PerformanceTuning._internals.NitrousConfig = (PerformanceTuning.RuntimeConfig or {}).nitrous
PerformanceTuning._internals.Performance = resolvedPerformanceConfig.performance
PerformanceTuning._internals.trim = (PerformanceTuning.ClientBindings or {}).trim
PerformanceTuning._internals.startsWith = (PerformanceTuning.ClientBindings or {}).startsWith
PerformanceTuning._internals.isFiniteNumber = (PerformanceTuning.ClientBindings or {}).isFiniteNumber
PerformanceTuning._internals.clampAntirollForceValue = (PerformanceTuning.MenuSliders or {}).clampAntirollForceValue
PerformanceTuning._internals.clampBrakeBiasFrontValue = (PerformanceTuning.MenuSliders or {}).clampBrakeBiasFrontValue
PerformanceTuning._internals.clampGripBiasFrontValue = (PerformanceTuning.MenuSliders or {}).clampGripBiasFrontValue
PerformanceTuning._internals.clampAntirollBiasFrontValue = (PerformanceTuning.MenuSliders or {}).clampAntirollBiasFrontValue
PerformanceTuning._internals.clampSuspensionRaiseValue = (PerformanceTuning.MenuSliders or {}).clampSuspensionRaiseValue
PerformanceTuning._internals.clampSuspensionBiasFrontValue = (PerformanceTuning.MenuSliders or {}).clampSuspensionBiasFrontValue
PerformanceTuning._internals.readHandlingValue = (PerformanceTuning.ClientBindings or {}).readHandlingValue
PerformanceTuning._internals.writeHandlingValue = (PerformanceTuning.ClientBindings or {}).writeHandlingValue
PerformanceTuning._internals.refreshVehicleAfterHandlingChange = (PerformanceTuning.ClientBindings or {}).refreshVehicleAfterHandlingChange
PerformanceTuning._internals.applySuspensionRaiseLimitAdjustments = (PerformanceTuning.TuningPackManager or {}).applySuspensionRaiseLimitAdjustments
PerformanceTuning._internals.parseValueForType = (PerformanceTuning.HandlingManager or {}).parseValueForType
PerformanceTuning._internals.formatHandlingValue = (PerformanceTuning.HandlingManager or {}).formatHandlingValue
PerformanceTuning._internals.computeBrakeBarProgressForVehicle = (PerformanceTuning.ClientBindings or {}).computeBrakeBarProgressForVehicle
PerformanceTuning._internals.getVehicleModelAudioName = (PerformanceTuning.ClientBindings or {}).getVehicleModelAudioName
PerformanceTuning._internals.logInfo = (PerformanceTuning.ClientBindings or {}).logInfo
PerformanceTuning._internals.normalizeSuspensionPackId = (PerformanceTuning.TuningPackManager or {}).normalizeSuspensionPackId
PerformanceTuning._internals.normalizeSteeringLockMode = (PerformanceTuning.TuningPackManager or {}).normalizeSteeringLockMode
PerformanceTuning._internals.clampNitroShotStrength = (PerformanceTuning.MenuSliders or {}).clampNitroShotStrength
PerformanceTuning._internals.clampCgOffsetValue = (PerformanceTuning.MenuSliders or {}).clampCgOffsetValue
PerformanceTuning._internals.clearCustomPhysicsNitrousShot = (PerformanceTuning.ClientBindings or {}).clearCustomPhysicsNitrousShot
PerformanceTuning._internals.requestDragRebalance = (PerformanceTuning.ClientBindings or {}).requestDragRebalance

PerformanceTuning.ScaleformUI.state = PerformanceTuning.ScaleformUI.state or {}
PerformanceTuning.ScaleformUI.notify = (PerformanceTuning.ClientBindings or {}).notify
PerformanceTuning.ScaleformUI.buildNormalizedSliderValues = (PerformanceTuning.MenuSliders or {}).buildNormalizedSliderValues
PerformanceTuning.ScaleformUI.buildNitroShotSliderValues = (PerformanceTuning.MenuSliders or {}).buildNitroShotSliderValues
PerformanceTuning.ScaleformUI.buildSuspensionClearanceSliderValues = (PerformanceTuning.MenuSliders or {}).buildSuspensionClearanceSliderValues
PerformanceTuning.ScaleformUI.buildListState = (PerformanceTuning.ClientBindings or {}).buildListState
PerformanceTuning.ScaleformUI.applyCurrentVehicleStateBagTuningForMenu = (PerformanceTuning.ClientBindings or {}).applyCurrentVehicleStateBagTuningForMenu
PerformanceTuning.ScaleformUI.applyMenuSelection = (PerformanceTuning.ClientBindings or {}).applyMenuSelection
PerformanceTuning.ScaleformUI.getCurrentVehicle = (PerformanceTuning.VehicleManager or {}).getCurrentVehicle
PerformanceTuning.ScaleformUI.ensureTuningState = (PerformanceTuning.ClientBindings or {}).ensureTuningState
PerformanceTuning.ScaleformUI.syncVehicleTuneState = (PerformanceTuning.VehicleManager or {}).syncVehicleTuneState
PerformanceTuning.ScaleformUI.applyAntirollForceTweak = (PerformanceTuning.TuningPackManager or {}).applyAntirollForceTweak
PerformanceTuning.ScaleformUI.applyNitroShotStrengthTweak = (PerformanceTuning.TuningPackManager or {}).applyNitroShotStrengthTweak
PerformanceTuning.ScaleformUI.applyBrakeBiasFrontTweak = (PerformanceTuning.TuningPackManager or {}).applyBrakeBiasFrontTweak
PerformanceTuning.ScaleformUI.applyGripBiasFrontTweak = (PerformanceTuning.TuningPackManager or {}).applyGripBiasFrontTweak
PerformanceTuning.ScaleformUI.applyAntirollBiasFrontTweak = (PerformanceTuning.TuningPackManager or {}).applyAntirollBiasFrontTweak
PerformanceTuning.ScaleformUI.applySuspensionRaiseTweak = (PerformanceTuning.TuningPackManager or {}).applySuspensionRaiseTweak
PerformanceTuning.ScaleformUI.applySuspensionBiasFrontTweak = (PerformanceTuning.TuningPackManager or {}).applySuspensionBiasFrontTweak
PerformanceTuning.ScaleformUI.applySteeringLockModeTweak = (PerformanceTuning.TuningPackManager or {}).applySteeringLockModeTweak
PerformanceTuning.ScaleformUI.resetPerformanceIndexDisplayState = (PerformanceTuning.ClientBindings or {}).resetPerformanceIndexDisplayState
PerformanceTuning.ScaleformUI.drawPerformanceIndexPanel = (PerformanceTuning.ClientBindings or {}).drawPerformanceIndexPanel
PerformanceTuning.ScaleformUI.getSliderValueForIndex = (PerformanceTuning.MenuSliders or {}).getSliderValueForIndex
PerformanceTuning.ScaleformUI.getAntirollSliderIndex = (PerformanceTuning.MenuSliders or {}).getAntirollSliderIndex
PerformanceTuning.ScaleformUI.getBrakeBiasSliderIndex = (PerformanceTuning.MenuSliders or {}).getBrakeBiasSliderIndex
PerformanceTuning.ScaleformUI.getGripBiasSliderIndex = (PerformanceTuning.MenuSliders or {}).getGripBiasSliderIndex
PerformanceTuning.ScaleformUI.getAntirollBiasSliderIndex = (PerformanceTuning.MenuSliders or {}).getAntirollBiasSliderIndex
PerformanceTuning.ScaleformUI.getSuspensionRaiseSliderIndex = (PerformanceTuning.MenuSliders or {}).getSuspensionRaiseSliderIndex
PerformanceTuning.ScaleformUI.getSuspensionBiasSliderIndex = (PerformanceTuning.MenuSliders or {}).getSuspensionBiasSliderIndex
PerformanceTuning.ScaleformUI.getNitroShotSliderIndex = (PerformanceTuning.MenuSliders or {}).getNitroShotSliderIndex
PerformanceTuning.ScaleformUI.getAntirollForceLabel = (PerformanceTuning.MenuSliders or {}).getAntirollForceLabel
PerformanceTuning.ScaleformUI.getBrakeBiasFrontLabel = (PerformanceTuning.MenuSliders or {}).getBrakeBiasFrontLabel
PerformanceTuning.ScaleformUI.getGripBiasFrontLabel = (PerformanceTuning.MenuSliders or {}).getGripBiasFrontLabel
PerformanceTuning.ScaleformUI.getAntirollBiasFrontLabel = (PerformanceTuning.MenuSliders or {}).getAntirollBiasFrontLabel
PerformanceTuning.ScaleformUI.getSuspensionRaiseLabel = (PerformanceTuning.MenuSliders or {}).getSuspensionRaiseLabel
PerformanceTuning.ScaleformUI.getSuspensionBiasFrontLabel = (PerformanceTuning.MenuSliders or {}).getSuspensionBiasFrontLabel
PerformanceTuning.ScaleformUI.getNitroShotStrengthLabel = (PerformanceTuning.MenuSliders or {}).getNitroShotStrengthLabel
PerformanceTuning.ScaleformUI.getNitrousPackLabel = (PerformanceTuning.TuningPackManager or {}).getNitrousPackLabel
PerformanceTuning.ScaleformUI.clampAntirollForceValue = (PerformanceTuning.MenuSliders or {}).clampAntirollForceValue
PerformanceTuning.ScaleformUI.clampBrakeBiasFrontValue = (PerformanceTuning.MenuSliders or {}).clampBrakeBiasFrontValue
PerformanceTuning.ScaleformUI.clampGripBiasFrontValue = (PerformanceTuning.MenuSliders or {}).clampGripBiasFrontValue
PerformanceTuning.ScaleformUI.clampAntirollBiasFrontValue = (PerformanceTuning.MenuSliders or {}).clampAntirollBiasFrontValue
PerformanceTuning.ScaleformUI.clampSuspensionRaiseValue = (PerformanceTuning.MenuSliders or {}).clampSuspensionRaiseValue
PerformanceTuning.ScaleformUI.clampSuspensionBiasFrontValue = (PerformanceTuning.MenuSliders or {}).clampSuspensionBiasFrontValue
PerformanceTuning.ScaleformUI.clampNitroShotStrength = (PerformanceTuning.MenuSliders or {}).clampNitroShotStrength
PerformanceTuning.ScaleformUI.applyCgOffsetTweak = (PerformanceTuning.TuningPackManager or {}).applyCgOffsetTweak
PerformanceTuning.ScaleformUI.clampCgOffsetValue = (PerformanceTuning.MenuSliders or {}).clampCgOffsetValue
PerformanceTuning.ScaleformUI.getCgOffsetSliderIndex = (PerformanceTuning.MenuSliders or {}).getCgOffsetSliderIndex
PerformanceTuning.ScaleformUI.getCgOffsetLabel = (PerformanceTuning.MenuSliders or {}).getCgOffsetLabel
PerformanceTuning.ScaleformUI.sliderRanges = (PerformanceTuning.RuntimeConfig or {}).sliderRanges
PerformanceTuning.ScaleformUI.tireBiasFrontField = handlingFields.tires and handlingFields.tires.biasFront or nil













