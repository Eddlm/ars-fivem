-- Wires shared runtime state, internals, and ScaleformUI services across modules.
PerformanceTuning = PerformanceTuning or {}
PerformanceTuning._state = PerformanceTuning._state or {}
PerformanceTuning._internals = PerformanceTuning._internals or {}
PerformanceTuning.ScaleformUI = PerformanceTuning.ScaleformUI or {}

local state = PerformanceTuning._state
local internals = PerformanceTuning._internals
local scaleformUI = PerformanceTuning.ScaleformUI
local runtimeState = PerformanceTuning.RuntimeState or {}
local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
local bindings = PerformanceTuning.ClientBindings or {}
local definitions = PerformanceTuning.Definitions or {}
local menuSliders = PerformanceTuning.MenuSliders or {}
local tuningPackManager = PerformanceTuning.TuningPackManager or {}
local config = PerformanceTuning.Config or {}
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

local function resolvePerformanceFromRuntimeConfig()
    local configured = runtimeConfig.performanceBarFillTargets or {}
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
local handlingFields = definitions.handlingFields or {}
local engineFields = definitions.engineFields or {}
local transmissionFields = definitions.transmissionFields or {}
local suspensionFields = definitions.suspensionFields or {}
local tireFields = definitions.tireFields or {}
local brakeFields = definitions.brakeFields or {}
local antirollFields = definitions.antirollFields or {}
local fieldTypeAliases = definitions.fieldTypeAliases or {}
local knownFieldTypes = definitions.knownFieldTypes or {}
local packDefinitions = config.packDefinitions or {}
local handlingManager = PerformanceTuning.HandlingManager or {}
local vehicleManager = PerformanceTuning.VehicleManager or {}

state.originalHandlingByVehicle = runtimeState.originalHandlingByVehicle
state.tuningStateByVehicle = runtimeState.tuningStateByVehicle
state.lastAppliedTuneStateByVehicle = runtimeState.lastAppliedTuneStateByVehicle
state.lastAppliedPiStateByVehicle = runtimeState.lastAppliedPiStateByVehicle
state.lastPiStateUpdatedAtByVehicle = runtimeState.lastPiStateUpdatedAtByVehicle
state.cachedEngineSwapValuesByModel = runtimeState.cachedEngineSwapValuesByModel
state.trackedVehiclesByKey = runtimeState.trackedVehiclesByKey
state.trackedVehicleKeys = runtimeState.trackedVehicleKeys

internals.HANDLING_CLASS = definitions.handlingClass
internals.StateBagKeys = definitions.stateBagKeys
internals.ENGINE_FIELDS = engineFields
internals.TRANSMISSION_FIELDS = transmissionFields
internals.SUSPENSION_FIELDS = suspensionFields
internals.TIRE_FIELDS = tireFields
internals.BRAKE_FIELDS = brakeFields
internals.ANTIROLL_FIELDS = antirollFields
internals.POWER_FIELD = handlingFields.engine and handlingFields.engine.power or nil
internals.TOP_SPEED_FIELD = handlingFields.engine and handlingFields.engine.topSpeed or nil
internals.DRAG_FIELD = handlingFields.engine and handlingFields.engine.drag or nil
internals.STEERING_LOCK_FIELD = handlingFields.steering and handlingFields.steering.lock or nil
internals.GEAR_FIELD = handlingFields.transmission and handlingFields.transmission.gear or nil
internals.CLUTCH_UPSHIFT_FIELD = handlingFields.transmission and handlingFields.transmission.clutchUpshift or nil
internals.BRAKE_FORCE_FIELD = handlingFields.brakes and handlingFields.brakes.force or nil
internals.HANDBRAKE_FORCE_FIELD = handlingFields.brakes and handlingFields.brakes.handbrakeForce or nil
internals.TIRE_BIAS_FRONT_FIELD = handlingFields.tires and handlingFields.tires.biasFront or nil
internals.TIRE_MAX_FIELD = handlingFields.tires and handlingFields.tires.max or nil
internals.SUSPENSION_BIAS_FRONT_FIELD = handlingFields.suspension and handlingFields.suspension.biasFront or nil
internals.ANTIROLL_FORCE_FIELD = handlingFields.antiroll and handlingFields.antiroll.force or nil
internals.ANTIROLL_BIAS_FRONT_FIELD = handlingFields.antiroll and handlingFields.antiroll.biasFront or nil
internals.BRAKE_BIAS_FRONT_FIELD = handlingFields.brakes and handlingFields.brakes.biasFront or nil
internals.ENGINE_SWAP_MODEL_NAME = definitions.engineSwapModelName
local resolvedPerformanceConfig = resolvePerformanceFromRuntimeConfig()
internals.BRAKE_SCALING = resolvedPerformanceConfig.brakeScaling
internals.FIELD_TYPE_ALIASES = fieldTypeAliases
internals.KNOWN_FIELD_TYPES = knownFieldTypes
internals.SUSPENSION_PACKS = packDefinitions.suspension
internals.TRANSMISSION_PACKS = packDefinitions.transmission
internals.ENGINE_PACKS = packDefinitions.engine
internals.ENGINE_SWAPS = config.engineSwaps or {}
internals.TIRE_COMPOUND_PACKS = packDefinitions.tires
internals.BRAKE_PACKS = packDefinitions.brakes
internals.HANDBRAKE_PACKS = packDefinitions.handbrakes or packDefinitions.brakes or {}
internals.NITROUS_PACKS = packDefinitions.nitrous
internals.NitrousConfig = runtimeConfig.nitrous
internals.Performance = resolvedPerformanceConfig.performance
internals.trim = bindings.trim
internals.startsWith = bindings.startsWith
internals.isFiniteNumber = bindings.isFiniteNumber
internals.clampAntirollForceValue = menuSliders.clampAntirollForceValue
internals.clampBrakeBiasFrontValue = menuSliders.clampBrakeBiasFrontValue
internals.clampGripBiasFrontValue = menuSliders.clampGripBiasFrontValue
internals.clampAntirollBiasFrontValue = menuSliders.clampAntirollBiasFrontValue
internals.clampSuspensionRaiseValue = menuSliders.clampSuspensionRaiseValue
internals.clampSuspensionBiasFrontValue = menuSliders.clampSuspensionBiasFrontValue
internals.readHandlingValue = bindings.readHandlingValue
internals.writeHandlingValue = bindings.writeHandlingValue
internals.refreshVehicleAfterHandlingChange = bindings.refreshVehicleAfterHandlingChange
internals.applySuspensionRaiseLimitAdjustments = tuningPackManager.applySuspensionRaiseLimitAdjustments
internals.parseValueForType = handlingManager.parseValueForType
internals.formatHandlingValue = handlingManager.formatHandlingValue
internals.computeBrakeBarProgressForVehicle = bindings.computeBrakeBarProgressForVehicle
internals.getVehicleModelAudioName = bindings.getVehicleModelAudioName
internals.logInfo = bindings.logInfo
internals.normalizeSuspensionPackId = tuningPackManager.normalizeSuspensionPackId
internals.normalizeSteeringLockMode = tuningPackManager.normalizeSteeringLockMode
internals.clampNitroShotStrength = menuSliders.clampNitroShotStrength
internals.clampCgOffsetValue = menuSliders.clampCgOffsetValue
internals.clearCustomPhysicsNitrousShot = bindings.clearCustomPhysicsNitrousShot
internals.requestDragRebalance = bindings.requestDragRebalance

scaleformUI.state = scaleformUI.state or {}
scaleformUI.notify = bindings.notify
scaleformUI.buildNormalizedSliderValues = menuSliders.buildNormalizedSliderValues
scaleformUI.buildNitroShotSliderValues = menuSliders.buildNitroShotSliderValues
scaleformUI.buildSuspensionClearanceSliderValues = menuSliders.buildSuspensionClearanceSliderValues
scaleformUI.buildListState = bindings.buildListState
scaleformUI.applyCurrentVehicleStateBagTuningForMenu = bindings.applyCurrentVehicleStateBagTuningForMenu
scaleformUI.applyMenuSelection = bindings.applyMenuSelection
scaleformUI.getCurrentVehicle = vehicleManager.getCurrentVehicle
scaleformUI.ensureTuningState = bindings.ensureTuningState
scaleformUI.syncVehicleTuneState = vehicleManager.syncVehicleTuneState
scaleformUI.applyAntirollForceTweak = tuningPackManager.applyAntirollForceTweak
scaleformUI.applyNitroShotStrengthTweak = tuningPackManager.applyNitroShotStrengthTweak
scaleformUI.applyBrakeBiasFrontTweak = tuningPackManager.applyBrakeBiasFrontTweak
scaleformUI.applyGripBiasFrontTweak = tuningPackManager.applyGripBiasFrontTweak
scaleformUI.applyAntirollBiasFrontTweak = tuningPackManager.applyAntirollBiasFrontTweak
scaleformUI.applySuspensionRaiseTweak = tuningPackManager.applySuspensionRaiseTweak
scaleformUI.applySuspensionBiasFrontTweak = tuningPackManager.applySuspensionBiasFrontTweak
scaleformUI.applySteeringLockModeTweak = tuningPackManager.applySteeringLockModeTweak
scaleformUI.resetPerformanceIndexDisplayState = bindings.resetPerformanceIndexDisplayState
scaleformUI.drawPerformanceIndexPanel = bindings.drawPerformanceIndexPanel
scaleformUI.getSliderValueForIndex = menuSliders.getSliderValueForIndex
scaleformUI.getAntirollSliderIndex = menuSliders.getAntirollSliderIndex
scaleformUI.getBrakeBiasSliderIndex = menuSliders.getBrakeBiasSliderIndex
scaleformUI.getGripBiasSliderIndex = menuSliders.getGripBiasSliderIndex
scaleformUI.getAntirollBiasSliderIndex = menuSliders.getAntirollBiasSliderIndex
scaleformUI.getSuspensionRaiseSliderIndex = menuSliders.getSuspensionRaiseSliderIndex
scaleformUI.getSuspensionBiasSliderIndex = menuSliders.getSuspensionBiasSliderIndex
scaleformUI.getNitroShotSliderIndex = menuSliders.getNitroShotSliderIndex
scaleformUI.getAntirollForceLabel = menuSliders.getAntirollForceLabel
scaleformUI.getBrakeBiasFrontLabel = menuSliders.getBrakeBiasFrontLabel
scaleformUI.getGripBiasFrontLabel = menuSliders.getGripBiasFrontLabel
scaleformUI.getAntirollBiasFrontLabel = menuSliders.getAntirollBiasFrontLabel
scaleformUI.getSuspensionRaiseLabel = menuSliders.getSuspensionRaiseLabel
scaleformUI.getSuspensionBiasFrontLabel = menuSliders.getSuspensionBiasFrontLabel
scaleformUI.getNitroShotStrengthLabel = menuSliders.getNitroShotStrengthLabel
scaleformUI.getNitrousPackLabel = tuningPackManager.getNitrousPackLabel
scaleformUI.clampAntirollForceValue = menuSliders.clampAntirollForceValue
scaleformUI.clampBrakeBiasFrontValue = menuSliders.clampBrakeBiasFrontValue
scaleformUI.clampGripBiasFrontValue = menuSliders.clampGripBiasFrontValue
scaleformUI.clampAntirollBiasFrontValue = menuSliders.clampAntirollBiasFrontValue
scaleformUI.clampSuspensionRaiseValue = menuSliders.clampSuspensionRaiseValue
scaleformUI.clampSuspensionBiasFrontValue = menuSliders.clampSuspensionBiasFrontValue
scaleformUI.clampNitroShotStrength = menuSliders.clampNitroShotStrength
scaleformUI.applyCgOffsetTweak = tuningPackManager.applyCgOffsetTweak
scaleformUI.clampCgOffsetValue = menuSliders.clampCgOffsetValue
scaleformUI.getCgOffsetSliderIndex = menuSliders.getCgOffsetSliderIndex
scaleformUI.getCgOffsetLabel = menuSliders.getCgOffsetLabel
scaleformUI.sliderRanges = runtimeConfig.sliderRanges
scaleformUI.tireBiasFrontField = handlingFields.tires and handlingFields.tires.biasFront or nil
