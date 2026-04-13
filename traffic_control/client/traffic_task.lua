local DEFAULT_TRAFFIC_CONVAR = 'tControlDefault'

local state = {
    effectiveDensity = nil,
    source = 'idle',
    sourceKey = nil,
    reason = 'idle_no_valid_default_or_requests',
}

local requestsByKey = {}
local requestMetaByKey = {}

local function normalizeDensity(value)
    if value == nil then
        return nil
    end

    return tonumber(value)
end

local function getDefaultDensity()
    return tonumber(GetConvar(DEFAULT_TRAFFIC_CONVAR, ''))
end

local function resolveRequestKey(explicitKey, fallbackKey)
    local key = explicitKey
    if key == nil or key == '' then
        key = fallbackKey
    end
    if key == nil or key == '' then
        key = 'unknown'
    end
    return tostring(key)
end

local function setRequestValue(requestKey, density, reason)
    if density == nil then
        requestsByKey[requestKey] = nil
        requestMetaByKey[requestKey] = nil
        return true
    end

    local numericDensity = normalizeDensity(density)
    if numericDensity == nil then
        return false
    end

    requestsByKey[requestKey] = numericDensity
    requestMetaByKey[requestKey] = tostring(reason or 'request_update')
    return true
end

local function rebuildState()
    local selectedDensity = nil
    local selectedKey = nil

    for key, density in pairs(requestsByKey) do
        if selectedDensity == nil or density < selectedDensity then
            selectedDensity = density
            selectedKey = key
        end
    end

    if selectedDensity ~= nil then
        state.effectiveDensity = selectedDensity
        state.source = 'request'
        state.sourceKey = selectedKey
        state.reason = requestMetaByKey[selectedKey] or 'request_lowest_selected'
        return
    end

    local defaultDensity = getDefaultDensity()
    if defaultDensity ~= nil then
        state.effectiveDensity = defaultDensity
        state.source = 'default'
        state.sourceKey = nil
        state.reason = 'default_convar'
        return
    end

    state.effectiveDensity = nil
    state.source = 'idle'
    state.sourceKey = nil
    state.reason = 'idle_no_valid_default_or_requests'
end

local function applyTrafficRequest(density, reason, requestKey)
    requestKey = resolveRequestKey(requestKey, nil)
    local didApply = setRequestValue(requestKey, density, reason)
    if not didApply then
        return false
    end

    rebuildState()
    return true
end

RegisterNetEvent('traffic_control:setMode', function(density, reason, requestKey)
    applyTrafficRequest(density, reason, requestKey)
end)

CreateThread(function()
    while true do
        rebuildState()

        if state.effectiveDensity ~= nil then
            local density = state.effectiveDensity
            SetVehicleDensityMultiplierThisFrame(density)
            SetRandomVehicleDensityMultiplierThisFrame(density)
            SetParkedVehicleDensityMultiplierThisFrame(density)
            SetPedDensityMultiplierThisFrame(density)
            SetScenarioPedDensityMultiplierThisFrame(density, density)
        end

        Wait(0)
    end
end)
