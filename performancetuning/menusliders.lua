-- Builds, clamps, and labels NativeUI slider values for tuning controls.
PerformanceTuning = PerformanceTuning or {}
PerformanceTuning.MenuSliders = PerformanceTuning.MenuSliders or {}

local MenuSliders = PerformanceTuning.MenuSliders

function MenuSliders.clampSliderRangeValue(value, rangeConfig, fallback)
    local numericValue = tonumber(value) or fallback
    if numericValue < rangeConfig.min then
        return rangeConfig.min
    end
    if numericValue > rangeConfig.max then
        return rangeConfig.max
    end
    return numericValue
end

function MenuSliders.buildSliderValues(rangeConfig, formatter)
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

function MenuSliders.getSliderIndex(value, rangeConfig, sliderValues, fallback)
    local normalized = MenuSliders.clampSliderRangeValue(value, rangeConfig, fallback)
    local steps = math.floor(((normalized - rangeConfig.min) / rangeConfig.step) + 0.5)
    local index = steps + 1
    return math.max(1, math.min(#sliderValues, index))
end

function MenuSliders.getSliderValueForIndex(index, rangeConfig)
    return rangeConfig.min + ((index - 1) * rangeConfig.step)
end

function MenuSliders.buildNormalizedSliderValues(rangeConfig)
    return MenuSliders.buildSliderValues(rangeConfig, function(value)
        return ('%.3f'):format(value)
    end)
end

function MenuSliders.buildNitroShotSliderValues()
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return MenuSliders.buildSliderValues((runtimeConfig.sliderRanges or {}).nitrousShotStrength, function(value)
        return ('%.1fx'):format(value)
    end)
end

function MenuSliders.buildSuspensionClearanceSliderValues(baseUpperLimit)
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
    return MenuSliders.buildSliderValues(dynamicRange, function(value)
        return ('%.3f'):format(value)
    end)
end

function MenuSliders.getNativeUISliderValues(key)
    local nativeUI = PerformanceTuning and PerformanceTuning.NativeUI or nil
    local state = nativeUI and nativeUI.state or nil
    local sliderValues = state and state.sliderValues or nil
    return sliderValues and sliderValues[key] or {}
end

function MenuSliders.clampAntirollForceValue(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return MenuSliders.clampSliderRangeValue(value, (runtimeConfig.sliderRanges or {}).antirollBars, 0.0)
end

function MenuSliders.getAntirollSliderIndex(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return MenuSliders.getSliderIndex(value, (runtimeConfig.sliderRanges or {}).antirollBars, MenuSliders.getNativeUISliderValues('antirollBars'), 0.0)
end

function MenuSliders.getAntirollForceLabel(value)
    return ('%.3f'):format(MenuSliders.clampAntirollForceValue(value))
end

function MenuSliders.clampBrakeBiasFrontValue(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return MenuSliders.clampSliderRangeValue(value, (runtimeConfig.sliderRanges or {}).brakeBiasFront, 0.5)
end

function MenuSliders.getBrakeBiasSliderIndex(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return MenuSliders.getSliderIndex(value, (runtimeConfig.sliderRanges or {}).brakeBiasFront, MenuSliders.getNativeUISliderValues('brakeBiasFront'), 0.5)
end

function MenuSliders.getBrakeBiasFrontLabel(value)
    return ('%.3f'):format(MenuSliders.clampBrakeBiasFrontValue(value))
end

function MenuSliders.clampGripBiasFrontValue(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return MenuSliders.clampSliderRangeValue(value, (runtimeConfig.sliderRanges or {}).gripBiasFront, 0.5)
end

function MenuSliders.getGripBiasSliderIndex(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return MenuSliders.getSliderIndex(value, (runtimeConfig.sliderRanges or {}).gripBiasFront, MenuSliders.getNativeUISliderValues('gripBiasFront'), 0.5)
end

function MenuSliders.getGripBiasFrontLabel(value)
    return ('%.3f'):format(MenuSliders.clampGripBiasFrontValue(value))
end

function MenuSliders.clampAntirollBiasFrontValue(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return MenuSliders.clampSliderRangeValue(value, (runtimeConfig.sliderRanges or {}).antirollBiasFront, 0.5)
end

function MenuSliders.getAntirollBiasSliderIndex(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return MenuSliders.getSliderIndex(value, (runtimeConfig.sliderRanges or {}).antirollBiasFront, MenuSliders.getNativeUISliderValues('antirollBiasFront'), 0.5)
end

function MenuSliders.getAntirollBiasFrontLabel(value)
    return ('%.3f'):format(MenuSliders.clampAntirollBiasFrontValue(value))
end

function MenuSliders.clampSuspensionRaiseValue(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return MenuSliders.clampSliderRangeValue(value, (runtimeConfig.sliderRanges or {}).suspensionRaise, 0.0)
end

function MenuSliders.getSuspensionRaiseSliderIndex(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return MenuSliders.getSliderIndex(value, (runtimeConfig.sliderRanges or {}).suspensionRaise, MenuSliders.getNativeUISliderValues('suspensionRaise'), 0.0)
end

function MenuSliders.getSuspensionRaiseLabel(value)
    return ('%.3f'):format(MenuSliders.clampSuspensionRaiseValue(value))
end

function MenuSliders.clampSuspensionClearanceValue(value)
    return MenuSliders.clampSuspensionRaiseValue(value)
end

function MenuSliders.getSuspensionClearanceSliderIndex(value)
    return MenuSliders.getSuspensionRaiseSliderIndex(value)
end

function MenuSliders.getSuspensionClearanceLabel(value)
    local resolvedValue = MenuSliders.clampSuspensionClearanceValue(value)
    if resolvedValue > 0.0001 then
        return ('+%.3f'):format(resolvedValue)
    end
    return ('%.3f'):format(resolvedValue)
end

function MenuSliders.clampSuspensionBiasFrontValue(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return MenuSliders.clampSliderRangeValue(value, (runtimeConfig.sliderRanges or {}).suspensionBiasFront, 0.5)
end

function MenuSliders.getSuspensionBiasSliderIndex(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return MenuSliders.getSliderIndex(value, (runtimeConfig.sliderRanges or {}).suspensionBiasFront, MenuSliders.getNativeUISliderValues('suspensionBiasFront'), 0.5)
end

function MenuSliders.getSuspensionBiasFrontLabel(value)
    return ('%.3f'):format(MenuSliders.clampSuspensionBiasFrontValue(value))
end

function MenuSliders.clampNitroShotStrength(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return MenuSliders.clampSliderRangeValue(value, (runtimeConfig.sliderRanges or {}).nitrousShotStrength, 1.0)
end

function MenuSliders.getNitroShotSliderIndex(value)
    local runtimeConfig = PerformanceTuning.RuntimeConfig or {}
    return MenuSliders.getSliderIndex(value, (runtimeConfig.sliderRanges or {}).nitrousShotStrength, MenuSliders.getNativeUISliderValues('nitrousShotStrength'), 1.0)
end

function MenuSliders.getNitroShotStrengthLabel(value)
    return ('%.1fx'):format(MenuSliders.clampNitroShotStrength(value))
end
