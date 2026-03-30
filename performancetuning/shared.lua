-- Declares user-facing shared configuration for slider ranges and nitrous values.
PerformanceTuning = PerformanceTuning or {}

PerformanceTuningConfig = PerformanceTuningConfig or {}

-- NativeUI tweak slider ranges.
PerformanceTuningConfig.sliderRanges = {
    antirollBars = {
        min = 0.0,
        max = 1.0,
        step = 0.025,
    },
    nitrousShotStrength = {
        min = 1.0,
        max = 2.0,
        step = 0.2,
    },
    brakeBiasFront = {
        min = 0.3,
        max = 0.7,
        step = 0.01,
    },
    gripBiasFront = {
        min = 0.3,
        max = 0.7,
        step = 0.01,
    },
    antirollBiasFront = {
        min = 0.0,
        max = 1.0,
        step = 0.025,
    },
    suspensionRaise = {
        min = -0.300,
        max = 0.300,
        step = 0.010,
    },
    suspensionBiasFront = {
        min = 0.3,
        max = 0.7,
        step = 0.01,
    },
}

-- Gameplay-side nitrous settings used by the runtime system.
PerformanceTuningConfig.nitrous = {
    baseDurationMs = 4000,
    nativePowerMultiplier = 0.5,
}
