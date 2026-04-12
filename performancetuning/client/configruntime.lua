-- Normalizes shared/user config into the runtime config used by client modules.
PerformanceTuning = PerformanceTuning or {}

local definitions = PerformanceTuning.Definitions or {}
local runtimeConfig = definitions.runtimeConfig or {}
local config = PerformanceTuning.Config or {}
local INTERNAL_SLIDER_RANGES = {
    antirollBars = { min = 0.0, max = 2.0, step = 0.1 },
    brakeBiasFront = { min = 0.3, max = 0.7, step = 0.05 },
     gripBiasFront = { min = 0.4, max = 0.6, step = 0.005 },
    antirollBiasFront = { min = 0.0, max = 1.0, step = 0.025 },
    suspensionBiasFront = { min = 0.3, max = 0.7, step = 0.01 },
    cgOffset = { min = -0.20, max = 0.20, step = 0.05 },
}
local INTERNAL_PERFORMANCE_BAR_FILL_TARGETS = {
    power = 0.60,
    topSpeedMph = 220.0,
    grip = 2.50,
    brake = 2.50,
    barSegmentCount = 20,
}
local INTERNAL_PI_DISTRIBUTION = {
    power = 20.0,
    topSpeed = 40.0,
    grip = 20.0,
    brake = 20.0,
}
local INTERNAL_PERFORMANCE_BARS = {
    displayMode = 'absolute_benchmark',
    power = {
        target = INTERNAL_PERFORMANCE_BAR_FILL_TARGETS.power,
        transmission = { powerBonusPerUpgrade = 0.01 },
        nitrous = {
            powerBarFillPerNitroLevel = 5.0,
        },
    },
    topSpeed = {
        target = 0.60,
    },
    grip = {
        target = 0.0,
        qualityLadder = {
            low_end = 0.60,
            mid_end = 0.7333333333,
            high_end = 0.8666666667,
            top_end = 1.0,
        },
        compoundRoadOffset = {
            road = 0.0,
            rally = -0.15,
            offroad = -0.30,
        },
    },
    brake = {
        target = 0.60,
    },
    handbrake = {
        target = 0.60,
    },
}

local function getConfiguredSliderRange(key)
    local configuredRanges = config.sliderRanges or {}
    local configured = configuredRanges[key] or {}
    local fallback = INTERNAL_SLIDER_RANGES[key] or { min = 0.0, max = 1.0, step = 0.1 }
    local minValue = tonumber(configured.min)
    local maxValue = tonumber(configured.max)
    local stepValue = tonumber(configured.step)

    minValue = minValue or fallback.min
    maxValue = maxValue or fallback.max
    stepValue = stepValue or fallback.step

    if stepValue <= 0.0 or maxValue < minValue then
        return {
            min = fallback.min,
            max = fallback.max,
            step = fallback.step,
        }
    end

    return {
        min = minValue,
        max = maxValue,
        step = stepValue,
    }
end

local function getConfiguredNitrousValue(key)
    local configuredNitrous = config.nitrous or {}
    local configuredValue = tonumber(configuredNitrous[key])
    local fallbackValue = key == 'baseDurationMs' and 4000 or 0.5

    if configuredValue == nil then
        return fallbackValue
    end

    if key == 'baseDurationMs' then
        return math.max(250, math.floor(configuredValue))
    end

    if key == 'nativePowerMultiplier' then
        return math.max(0.0, configuredValue)
    end

    return configuredValue
end

local function getConfiguredPerformanceBarFillTargets()
    local configuredTargets = config.performanceBarFillTargets or {}
    local defaults = INTERNAL_PERFORMANCE_BAR_FILL_TARGETS
    local targets = {
        power = tonumber(configuredTargets.power) or defaults.power,
        topSpeedMph = tonumber(configuredTargets.topSpeedMph) or defaults.topSpeedMph,
        grip = tonumber(configuredTargets.grip) or defaults.grip,
        brake = tonumber(configuredTargets.brake) or defaults.brake,
        barSegmentCount = defaults.barSegmentCount,
    }

    if targets.power <= 0.0 then
        targets.power = defaults.power
    end
    if targets.topSpeedMph <= 0.0 then
        targets.topSpeedMph = defaults.topSpeedMph
    end
    if targets.grip <= 0.0 then
        targets.grip = defaults.grip
    end
    if targets.brake <= 0.0 then
        targets.brake = defaults.brake
    end
    return targets
end

local function getConfiguredPerformanceBars()
    local configuredBars = config.performanceModel or config.performanceBars or {}
    local configuredPower = configuredBars.power or {}
    local configuredPowerTransmission = configuredPower.transmission or {}
    local configuredPowerNitrous = configuredPower.nitrous or {}
    local configuredTopSpeed = configuredBars.topSpeed or {}
    local configuredGrip = configuredBars.grip or {}
    local configuredGripQuality = configuredGrip.qualityLadder or {}
    local configuredGripCompound = configuredGrip.compoundRoadOffset or {}
    local configuredBrake = configuredBars.brake or {}
    local configuredHandbrake = configuredBars.handbrake or {}

    local bars = {
        displayMode = tostring(configuredBars.displayMode or INTERNAL_PERFORMANCE_BARS.displayMode):lower(),
        power = {
            target = tonumber(configuredPower.target)
                or tonumber((config.performanceBarFillTargets or {}).power)
                or INTERNAL_PERFORMANCE_BARS.power.target,
            transmission = {
                powerBonusPerUpgrade = tonumber(configuredPowerTransmission.powerBonusPerUpgrade)
                    or INTERNAL_PERFORMANCE_BARS.power.transmission.powerBonusPerUpgrade,
            },
            nitrous = {
                powerBarFillPerNitroLevel = tonumber(configuredPowerNitrous.powerBarFillPerNitroLevel)
                    or INTERNAL_PERFORMANCE_BARS.power.nitrous.powerBarFillPerNitroLevel,
            },
        },
        topSpeed = {
            target = tonumber(configuredTopSpeed.target)
                or INTERNAL_PERFORMANCE_BARS.topSpeed.target,
        },
        grip = {
            target = tonumber(configuredGrip.target) or INTERNAL_PERFORMANCE_BARS.grip.target,
            qualityLadder = {
                low_end = tonumber(configuredGripQuality.low_end) or INTERNAL_PERFORMANCE_BARS.grip.qualityLadder.low_end,
                mid_end = tonumber(configuredGripQuality.mid_end) or INTERNAL_PERFORMANCE_BARS.grip.qualityLadder.mid_end,
                high_end = tonumber(configuredGripQuality.high_end) or INTERNAL_PERFORMANCE_BARS.grip.qualityLadder.high_end,
                top_end = tonumber(configuredGripQuality.top_end) or INTERNAL_PERFORMANCE_BARS.grip.qualityLadder.top_end,
            },
            compoundRoadOffset = {
                road = tonumber(configuredGripCompound.road) or INTERNAL_PERFORMANCE_BARS.grip.compoundRoadOffset.road,
                rally = tonumber(configuredGripCompound.rally) or INTERNAL_PERFORMANCE_BARS.grip.compoundRoadOffset.rally,
                offroad = tonumber(configuredGripCompound.offroad) or INTERNAL_PERFORMANCE_BARS.grip.compoundRoadOffset.offroad,
            },
        },
        brake = {
            target = tonumber(configuredBrake.target)
                or INTERNAL_PERFORMANCE_BARS.brake.target,
        },
        handbrake = {
            target = tonumber(configuredHandbrake.target)
                or INTERNAL_PERFORMANCE_BARS.handbrake.target,
        },
    }

    if bars.power.target <= 0.0 then
        bars.power.target = INTERNAL_PERFORMANCE_BARS.power.target
    end
    if bars.displayMode ~= 'vehicle_relative' then
        bars.displayMode = 'absolute_benchmark'
    end
    if bars.topSpeed.target < 0.0 then
        bars.topSpeed.target = INTERNAL_PERFORMANCE_BARS.topSpeed.target
    end
    if bars.grip.target < 0.0 then
        bars.grip.target = INTERNAL_PERFORMANCE_BARS.grip.target
    end
    if bars.brake.target < 0.0 then
        bars.brake.target = INTERNAL_PERFORMANCE_BARS.brake.target
    end
    if bars.handbrake.target < 0.0 then
        bars.handbrake.target = INTERNAL_PERFORMANCE_BARS.handbrake.target
    end
    if bars.power.transmission.powerBonusPerUpgrade < 0.0 then
        bars.power.transmission.powerBonusPerUpgrade = INTERNAL_PERFORMANCE_BARS.power.transmission.powerBonusPerUpgrade
    end
    if bars.power.nitrous.powerBarFillPerNitroLevel < 0.0 then
        bars.power.nitrous.powerBarFillPerNitroLevel = INTERNAL_PERFORMANCE_BARS.power.nitrous.powerBarFillPerNitroLevel
    end
    return bars
end

local function getConfiguredPiDistribution()
    local configuredDistribution = config.performancePiDistribution or {}
    local legacyMultipliers = config.performancePiMultipliers or {}
    local raw = {
        power = tonumber(configuredDistribution.power),
        topSpeed = tonumber(configuredDistribution.topSpeed),
        grip = tonumber(configuredDistribution.grip),
        brake = tonumber(configuredDistribution.brake),
    }

    if raw.power == nil then raw.power = tonumber(legacyMultipliers.power) end
    if raw.topSpeed == nil then raw.topSpeed = tonumber(legacyMultipliers.topSpeed) end
    if raw.grip == nil then raw.grip = tonumber(legacyMultipliers.grip) end
    if raw.brake == nil then raw.brake = tonumber(legacyMultipliers.brake) end

    local resolved = {
        power = (raw.power and raw.power > 0.0) and raw.power or INTERNAL_PI_DISTRIBUTION.power,
        topSpeed = (raw.topSpeed and raw.topSpeed > 0.0) and raw.topSpeed or INTERNAL_PI_DISTRIBUTION.topSpeed,
        grip = (raw.grip and raw.grip > 0.0) and raw.grip or INTERNAL_PI_DISTRIBUTION.grip,
        brake = (raw.brake and raw.brake > 0.0) and raw.brake or INTERNAL_PI_DISTRIBUTION.brake,
    }
    return resolved
end

runtimeConfig.sliderRanges.antirollBars = getConfiguredSliderRange('antirollBars')
runtimeConfig.sliderRanges.nitrousShotStrength = getConfiguredSliderRange('nitrousShotStrength')
runtimeConfig.sliderRanges.brakeBiasFront = getConfiguredSliderRange('brakeBiasFront')
runtimeConfig.sliderRanges.gripBiasFront = getConfiguredSliderRange('gripBiasFront')
runtimeConfig.sliderRanges.antirollBiasFront = getConfiguredSliderRange('antirollBiasFront')
runtimeConfig.sliderRanges.suspensionRaise = getConfiguredSliderRange('suspensionRaise')
runtimeConfig.sliderRanges.suspensionBiasFront = getConfiguredSliderRange('suspensionBiasFront')
runtimeConfig.sliderRanges.cgOffset = getConfiguredSliderRange('cgOffset')
runtimeConfig.nitrous.baseDurationMs = getConfiguredNitrousValue('baseDurationMs')
runtimeConfig.nitrous.nativePowerMultiplier = getConfiguredNitrousValue('nativePowerMultiplier')
runtimeConfig.performancePiDistribution = getConfiguredPiDistribution()
runtimeConfig.performancePiMultipliers = runtimeConfig.performancePiDistribution
runtimeConfig.performanceModel = getConfiguredPerformanceBars()
runtimeConfig.performanceBars = runtimeConfig.performanceModel
runtimeConfig.performanceBarFillTargets = getConfiguredPerformanceBarFillTargets()
runtimeConfig.performanceNearbyPanels = config.performanceNearbyPanels or {}

PerformanceTuning.RuntimeConfig = runtimeConfig
