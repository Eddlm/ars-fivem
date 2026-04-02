-- Normalizes shared/user config into the runtime config used by client modules.
PerformanceTuning = PerformanceTuning or {}

local definitions = PerformanceTuning.Definitions or {}
local runtimeConfig = definitions.runtimeConfig or {}
local config = PerformanceTuning.Config or {}
local INTERNAL_SLIDER_RANGES = {
    antirollBars = { min = 0.0, max = 1.0, step = 0.025 },
    brakeBiasFront = { min = 0.3, max = 0.7, step = 0.01 },
    gripBiasFront = { min = 0.3, max = 0.7, step = 0.01 },
    antirollBiasFront = { min = 0.0, max = 1.0, step = 0.025 },
    suspensionBiasFront = { min = 0.3, max = 0.7, step = 0.01 },
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
        barSegmentCount = math.floor(tonumber(configuredTargets.barSegmentCount) or defaults.barSegmentCount),
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
    if targets.barSegmentCount < 1 then
        targets.barSegmentCount = defaults.barSegmentCount
    end

    return targets
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
    local sum = resolved.power + resolved.topSpeed + resolved.grip + resolved.brake
    if sum <= 0.0 then
        return {
            power = INTERNAL_PI_DISTRIBUTION.power,
            topSpeed = INTERNAL_PI_DISTRIBUTION.topSpeed,
            grip = INTERNAL_PI_DISTRIBUTION.grip,
            brake = INTERNAL_PI_DISTRIBUTION.brake,
        }
    end

    local normalize = 100.0 / sum
    return {
        power = resolved.power * normalize,
        topSpeed = resolved.topSpeed * normalize,
        grip = resolved.grip * normalize,
        brake = resolved.brake * normalize,
    }
end

runtimeConfig.sliderRanges.antirollBars = getConfiguredSliderRange('antirollBars')
runtimeConfig.sliderRanges.nitrousShotStrength = getConfiguredSliderRange('nitrousShotStrength')
runtimeConfig.sliderRanges.brakeBiasFront = getConfiguredSliderRange('brakeBiasFront')
runtimeConfig.sliderRanges.gripBiasFront = getConfiguredSliderRange('gripBiasFront')
runtimeConfig.sliderRanges.antirollBiasFront = getConfiguredSliderRange('antirollBiasFront')
runtimeConfig.sliderRanges.suspensionRaise = getConfiguredSliderRange('suspensionRaise')
runtimeConfig.sliderRanges.suspensionBiasFront = getConfiguredSliderRange('suspensionBiasFront')
runtimeConfig.nitrous.baseDurationMs = getConfiguredNitrousValue('baseDurationMs')
runtimeConfig.nitrous.nativePowerMultiplier = getConfiguredNitrousValue('nativePowerMultiplier')
runtimeConfig.performancePiDistribution = getConfiguredPiDistribution()
runtimeConfig.performancePiMultipliers = runtimeConfig.performancePiDistribution
runtimeConfig.performanceBarFillTargets = getConfiguredPerformanceBarFillTargets()
runtimeConfig.performanceNearbyPanels = config.performanceNearbyPanels or {}

PerformanceTuning.RuntimeConfig = runtimeConfig
