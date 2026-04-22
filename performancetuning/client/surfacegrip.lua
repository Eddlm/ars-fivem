PerformanceTuning = PerformanceTuning or {}
PerformanceTuning.SurfaceGrip = PerformanceTuning.SurfaceGrip or {}

function PerformanceTuning.SurfaceGrip.getMaterialTyreGripByIndex(materialIndex)
    local numericIndex = tonumber(materialIndex)
    if numericIndex == nil or type(MaterialTyreGripByIndex) ~= 'table' then
        return nil
    end

    return MaterialTyreGripByIndex[numericIndex]
end

