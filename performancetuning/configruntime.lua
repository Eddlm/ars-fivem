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

runtimeConfig.sliderRanges.antirollBars = getConfiguredSliderRange('antirollBars')
runtimeConfig.sliderRanges.nitrousShotStrength = getConfiguredSliderRange('nitrousShotStrength')
runtimeConfig.sliderRanges.brakeBiasFront = getConfiguredSliderRange('brakeBiasFront')
runtimeConfig.sliderRanges.gripBiasFront = getConfiguredSliderRange('gripBiasFront')
runtimeConfig.sliderRanges.antirollBiasFront = getConfiguredSliderRange('antirollBiasFront')
runtimeConfig.sliderRanges.suspensionRaise = getConfiguredSliderRange('suspensionRaise')
runtimeConfig.sliderRanges.suspensionBiasFront = getConfiguredSliderRange('suspensionBiasFront')
runtimeConfig.nitrous.baseDurationMs = getConfiguredNitrousValue('baseDurationMs')
runtimeConfig.nitrous.nativePowerMultiplier = getConfiguredNitrousValue('nativePowerMultiplier')
runtimeConfig.performancePiMultipliers = config.performancePiMultipliers or {}
runtimeConfig.performanceNearbyPanels = config.performanceNearbyPanels or {}
runtimeConfig.performancePiClasses = config.performancePiClasses or {}
runtimeConfig.nitrousRefill = config.nitrousRefill or {}

PerformanceTuning.RuntimeConfig = runtimeConfig
