-- Shared generic helpers for performancetuning client modules.
PerformanceTuning = PerformanceTuning or {}
PerformanceTuning.Utils = PerformanceTuning.Utils or {}

function PerformanceTuning.Utils.isFiniteNumber(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end
