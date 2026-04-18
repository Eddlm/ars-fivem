-- Builds, clamps, and labels ScaleformUI slider values for tuning controls.
PerformanceTuning = PerformanceTuning or {}
PerformanceTuning.MenuSliders = PerformanceTuning.MenuSliders or {}
function PerformanceTuning.MenuSliders.clampSliderRangeValue(value, rangeConfig, fallback)
    local numericValue = tonumber(value) or fallback
    if numericValue < rangeConfig.min then
        return rangeConfig.min
    end
    if numericValue > rangeConfig.max then
        return rangeConfig.max
    end
    return numericValue
end

function PerformanceTuning.MenuSliders.buildSliderValues(rangeConfig, formatter)
    local values = {}
    local index = 1
    local value = rangeConfig.min

    while value <= (rangeConfig.max + 0.0001) do
        values[index] = formatter(value)
        index = index + 1
        value = value + rangeConfig.step
    end

    return values
end

function PerformanceTuning.MenuSliders.getSliderIndex(value, rangeConfig, sliderValues, fallback)
    local normalized = PerformanceTuning.MenuSliders.clampSliderRangeValue(value, rangeConfig, fallback)
    local steps = math.floor(((normalized - rangeConfig.min) / rangeConfig.step) + 0.5)
    local index = steps + 1
    return math.max(1, math.min(#sliderValues, index))
end

function PerformanceTuning.MenuSliders.getSliderValueForIndex(index, rangeConfig)
    return rangeConfig.min + ((index - 1) * rangeConfig.step)
end

function PerformanceTuning.MenuSliders.buildNormalizedSliderValues(rangeConfig)
    return PerformanceTuning.MenuSliders.buildSliderValues(rangeConfig, function(value)
        return ('%.3f'):format(value)
    end)
end

function PerformanceTuning.MenuSliders.buildNitroShotSliderValues()
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return PerformanceTuning.MenuSliders.buildSliderValues((runtimeConfig.sliderRanges or {}).nitrousShotStrength, function(value)
        return ('%.1fx'):format(value)
    end)
end

function PerformanceTuning.MenuSliders.buildSuspensionClearanceSliderValues(baseUpperLimit)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    local rangeConfig = (runtimeConfig.sliderRanges or {}).suspensionRaise
    local resolvedUpperLimit = math.max(0.0, tonumber(baseUpperLimit) or 0.0)
    local minValue = 0.0
    local maxValue = resolvedUpperLimit * 2.0
    local stepValue = tonumber(rangeConfig and rangeConfig.step) or 0.01
    local dynamicRange = {
        min = minValue,
        max = maxValue,
        step = stepValue,
    }
    return PerformanceTuning.MenuSliders.buildSliderValues(dynamicRange, function(value)
        return ('%.3f'):format(value)
    end)
end

function PerformanceTuning.MenuSliders.getUISliderValues(key)
    local scaleformUI = PerformanceTuning and PerformanceTuning.ScaleformUI or nil
    local state = scaleformUI and scaleformUI.state or nil
    local sliderValues = state and state.sliderValues or nil
    return sliderValues and sliderValues[key] or {}
end

function PerformanceTuning.MenuSliders.clampAntirollForceValue(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return PerformanceTuning.MenuSliders.clampSliderRangeValue(value, (runtimeConfig.sliderRanges or {}).antirollBars, 0.0)
end

function PerformanceTuning.MenuSliders.getAntirollSliderIndex(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return PerformanceTuning.MenuSliders.getSliderIndex(value, (runtimeConfig.sliderRanges or {}).antirollBars, PerformanceTuning.MenuSliders.getUISliderValues('antirollBars'), 0.0)
end

function PerformanceTuning.MenuSliders.getAntirollForceLabel(value)
    return ('%.3f'):format(PerformanceTuning.MenuSliders.clampAntirollForceValue(value))
end

function PerformanceTuning.MenuSliders.clampBrakeBiasFrontValue(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return PerformanceTuning.MenuSliders.clampSliderRangeValue(value, (runtimeConfig.sliderRanges or {}).brakeBiasFront, 0.5)
end

function PerformanceTuning.MenuSliders.getBrakeBiasSliderIndex(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return PerformanceTuning.MenuSliders.getSliderIndex(value, (runtimeConfig.sliderRanges or {}).brakeBiasFront, PerformanceTuning.MenuSliders.getUISliderValues('brakeBiasFront'), 0.5)
end

function PerformanceTuning.MenuSliders.getBrakeBiasFrontLabel(value)
    return ('%.3f'):format(PerformanceTuning.MenuSliders.clampBrakeBiasFrontValue(value))
end

function PerformanceTuning.MenuSliders.clampGripBiasFrontValue(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return PerformanceTuning.MenuSliders.clampSliderRangeValue(value, (runtimeConfig.sliderRanges or {}).gripBiasFront, 0.5)
end

function PerformanceTuning.MenuSliders.getGripBiasSliderIndex(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return PerformanceTuning.MenuSliders.getSliderIndex(value, (runtimeConfig.sliderRanges or {}).gripBiasFront, PerformanceTuning.MenuSliders.getUISliderValues('gripBiasFront'), 0.5)
end

function PerformanceTuning.MenuSliders.getGripBiasFrontLabel(value)
    return ('%.3f'):format(PerformanceTuning.MenuSliders.clampGripBiasFrontValue(value))
end

function PerformanceTuning.MenuSliders.clampAntirollBiasFrontValue(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return PerformanceTuning.MenuSliders.clampSliderRangeValue(value, (runtimeConfig.sliderRanges or {}).antirollBiasFront, 0.5)
end

function PerformanceTuning.MenuSliders.getAntirollBiasSliderIndex(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return PerformanceTuning.MenuSliders.getSliderIndex(value, (runtimeConfig.sliderRanges or {}).antirollBiasFront, PerformanceTuning.MenuSliders.getUISliderValues('antirollBiasFront'), 0.5)
end

function PerformanceTuning.MenuSliders.getAntirollBiasFrontLabel(value)
    return ('%.3f'):format(PerformanceTuning.MenuSliders.clampAntirollBiasFrontValue(value))
end

function PerformanceTuning.MenuSliders.clampSuspensionRaiseValue(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return PerformanceTuning.MenuSliders.clampSliderRangeValue(value, (runtimeConfig.sliderRanges or {}).suspensionRaise, 0.0)
end

function PerformanceTuning.MenuSliders.getSuspensionRaiseSliderIndex(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return PerformanceTuning.MenuSliders.getSliderIndex(value, (runtimeConfig.sliderRanges or {}).suspensionRaise, PerformanceTuning.MenuSliders.getUISliderValues('suspensionRaise'), 0.0)
end

function PerformanceTuning.MenuSliders.getSuspensionRaiseLabel(value)
    return ('%.3f'):format(PerformanceTuning.MenuSliders.clampSuspensionRaiseValue(value))
end

function PerformanceTuning.MenuSliders.clampSuspensionClearanceValue(value)
    return PerformanceTuning.MenuSliders.clampSuspensionRaiseValue(value)
end

function PerformanceTuning.MenuSliders.getSuspensionClearanceSliderIndex(value)
    return PerformanceTuning.MenuSliders.getSuspensionRaiseSliderIndex(value)
end

function PerformanceTuning.MenuSliders.getSuspensionClearanceLabel(value)
    local resolvedValue = PerformanceTuning.MenuSliders.clampSuspensionClearanceValue(value)
    if resolvedValue > 0.0001 then
        return ('+%.3f'):format(resolvedValue)
    end
    return ('%.3f'):format(resolvedValue)
end

function PerformanceTuning.MenuSliders.clampSuspensionBiasFrontValue(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return PerformanceTuning.MenuSliders.clampSliderRangeValue(value, (runtimeConfig.sliderRanges or {}).suspensionBiasFront, 0.5)
end

function PerformanceTuning.MenuSliders.getSuspensionBiasSliderIndex(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return PerformanceTuning.MenuSliders.getSliderIndex(value, (runtimeConfig.sliderRanges or {}).suspensionBiasFront, PerformanceTuning.MenuSliders.getUISliderValues('suspensionBiasFront'), 0.5)
end

function PerformanceTuning.MenuSliders.getSuspensionBiasFrontLabel(value)
    return ('%.3f'):format(PerformanceTuning.MenuSliders.clampSuspensionBiasFrontValue(value))
end

function PerformanceTuning.MenuSliders.clampCgOffsetValue(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return PerformanceTuning.MenuSliders.clampSliderRangeValue(value, (runtimeConfig.sliderRanges or {}).cgOffset, 0.0)
end

function PerformanceTuning.MenuSliders.getCgOffsetSliderIndex(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return PerformanceTuning.MenuSliders.getSliderIndex(value, (runtimeConfig.sliderRanges or {}).cgOffset, PerformanceTuning.MenuSliders.getUISliderValues('cgOffset'), 0.0)
end

function PerformanceTuning.MenuSliders.getCgOffsetLabel(value)
    local clamped = PerformanceTuning.MenuSliders.clampCgOffsetValue(value)
    if clamped > 0.0001 then
        return ('+%.2f'):format(clamped)
    end
    return ('%.2f'):format(clamped)
end

function PerformanceTuning.MenuSliders.clampNitroShotStrength(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return PerformanceTuning.MenuSliders.clampSliderRangeValue(value, (runtimeConfig.sliderRanges or {}).nitrousShotStrength, 1.0)
end

function PerformanceTuning.MenuSliders.getNitroShotSliderIndex(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return PerformanceTuning.MenuSliders.getSliderIndex(value, (runtimeConfig.sliderRanges or {}).nitrousShotStrength, PerformanceTuning.MenuSliders.getUISliderValues('nitrousShotStrength'), 1.0)
end

function PerformanceTuning.MenuSliders.getNitroShotStrengthLabel(value)
    return ('%.1fx'):format(PerformanceTuning.MenuSliders.clampNitroShotStrength(value))
end

