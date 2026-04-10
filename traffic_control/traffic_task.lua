local trafficState = {
    mode = nil,
    profile = nil,
    reason = 'init',
}

-- Dictionary of resourceName -> { mode, reason } for tracking requests from multiple resources
local trafficRequests = {}
local requestSequence = 0
local defaultTrafficMode = nil
local defaultTrafficProfile = nil
local DEFAULT_TRAFFIC_CONVAR = 'tControlDefault'
local DEFAULT_TRAFFIC_DENSITY_FALLBACK = '1.0'
local function getConfig()
    return ((TrafficControl or {}).Config) or (TrafficControlConfig or {}) or {}
end

local function normalizeMultiplier(value)
    if value == nil then
        return nil
    end
    local numeric = tonumber(value)
    if not numeric then
        return nil
    end
    if numeric < 0.0 then
        numeric = 0.0
    elseif numeric > 1.0 then
        numeric = 1.0
    end
    return numeric
end

local function normalizeMode(value)
    local mode = tostring(value or ''):lower()
    if mode == '' then
        return nil
    end

    local config = getConfig()
    local profiles = type(config.profiles) == 'table' and config.profiles or {}
    local legacy = type(config.legacyModeDensity) == 'table' and config.legacyModeDensity or {}

    if type(profiles[mode]) == 'table' then
        return mode
    end

    if legacy[mode] ~= nil then
        return mode
    end

    return nil
end

local function getDefaultMode()
    local config = getConfig()
    local configured = normalizeMode(config.defaultMode)
    return configured or 'normal'
end

local function clampDensity(value)
    local numeric = tonumber(value)
    if not numeric then
        return nil
    end
    if numeric < 0.0 then
        numeric = 0.0
    elseif numeric > 2.0 then
        numeric = 2.0
    end
    return numeric
end

local function getConfiguredDensityForMode(mode)
    local config = getConfig()
    local modes = type(config.legacyModeDensity) == 'table' and config.legacyModeDensity or {}
    return clampDensity(modes[mode])
end

local function boolOrDefault(value, defaultValue)
    if value == nil then
        return defaultValue and true or false
    end
    return value and true or false
end

local function buildProfileForMode(mode)
    local config = getConfig()
    local profiles = type(config.profiles) == 'table' and config.profiles or {}
    local profile = type(profiles[mode]) == 'table' and profiles[mode] or nil

    if not profile then
        local fallbackDensity = getConfiguredDensityForMode(mode) or 0.0
        profile = {
            vehicleDensity = fallbackDensity,
            randomVehicleDensity = fallbackDensity,
            parkedVehicleDensity = fallbackDensity,
            pedDensity = fallbackDensity,
            scenarioPedDensity = fallbackDensity,
            randomBoats = false,
            garbageTrucks = false,
            randomCops = false,
            randomCopsNotOnScenarios = false,
            randomCopsOnScenarios = false,
            parkedVehicleCount = 0,
            blockPopulationPeds = false,
        }
    end

    return {
        vehicleDensity = clampDensity(profile.vehicleDensity) or 0.0,
        randomVehicleDensity = clampDensity(profile.randomVehicleDensity) or 0.0,
        parkedVehicleDensity = clampDensity(profile.parkedVehicleDensity) or 0.0,
        pedDensity = clampDensity(profile.pedDensity) or 0.0,
        scenarioPedDensity = clampDensity(profile.scenarioPedDensity) or 0.0,
        randomBoats = boolOrDefault(profile.randomBoats, false),
        garbageTrucks = boolOrDefault(profile.garbageTrucks, false),
        randomCops = boolOrDefault(profile.randomCops, false),
        randomCopsNotOnScenarios = boolOrDefault(profile.randomCopsNotOnScenarios, false),
        randomCopsOnScenarios = boolOrDefault(profile.randomCopsOnScenarios, false),
        parkedVehicleCount = math.max(0, math.floor(tonumber(profile.parkedVehicleCount) or 0)),
        blockPopulationPeds = boolOrDefault(profile.blockPopulationPeds, false),
    }
end

local function applyPersistentControls(profile)
    SetRandomBoats(profile.randomBoats)
    SetGarbageTrucks(profile.garbageTrucks)
    SetCreateRandomCops(profile.randomCops)
    SetCreateRandomCopsNotOnScenarios(profile.randomCopsNotOnScenarios)
    SetCreateRandomCopsOnScenarios(profile.randomCopsOnScenarios)
    if type(SetNumberOfParkedVehicles) == 'function' then
        SetNumberOfParkedVehicles(profile.parkedVehicleCount)
    end
end

local function getActiveRequest()
    -- Prefer the newest explicit request.
    local selectedRequest = nil
    local selectedResourceName = nil
    local selectedSequence = -1

    for resourceName, request in pairs(trafficRequests) do
        if request and (request.mode or request.multiplier) then
            local sequence = math.floor(tonumber(request.sequence) or 0)
            if sequence > selectedSequence then
                selectedSequence = sequence
                selectedRequest = request
                selectedResourceName = resourceName
            end
        end
    end

    return selectedRequest, selectedResourceName
end

local function refreshDefaultTraffic()
    defaultTrafficMode = getDefaultMode()
    defaultTrafficProfile = buildProfileForMode(defaultTrafficMode)

    local configuredDefaultDensity = clampDensity(GetConvar(DEFAULT_TRAFFIC_CONVAR, DEFAULT_TRAFFIC_DENSITY_FALLBACK))
    if configuredDefaultDensity ~= nil and defaultTrafficProfile ~= nil then
        defaultTrafficProfile.vehicleDensity = configuredDefaultDensity
        defaultTrafficProfile.randomVehicleDensity = configuredDefaultDensity
        defaultTrafficProfile.parkedVehicleDensity = configuredDefaultDensity
        defaultTrafficProfile.pedDensity = configuredDefaultDensity
        defaultTrafficProfile.scenarioPedDensity = configuredDefaultDensity
    end
end

local function updateActiveState()
    local request, resourceName = getActiveRequest()

    if not request then
        if not defaultTrafficProfile then
            refreshDefaultTraffic()
        end

        trafficState.mode = defaultTrafficMode or getDefaultMode()
        trafficState.profile = defaultTrafficProfile or buildProfileForMode(trafficState.mode)
        trafficState.reason = 'default_dormant'
        applyPersistentControls(trafficState.profile)
        return
    end

    if request.mode then
        trafficState.mode = request.mode
        trafficState.profile = buildProfileForMode(request.mode)
    else
        local multiplier = request.multiplier
        trafficState.mode = 'custom'
        trafficState.profile = {
            vehicleDensity = multiplier,
            randomVehicleDensity = multiplier,
            parkedVehicleDensity = multiplier,
            pedDensity = multiplier,
            scenarioPedDensity = multiplier,
            randomBoats = false,
            garbageTrucks = false,
            randomCops = false,
            randomCopsNotOnScenarios = false,
            randomCopsOnScenarios = false,
            parkedVehicleCount = 0,
            blockPopulationPeds = false,
        }
    end

    trafficState.reason = tostring(request.reason or ('from_' .. tostring(resourceName)))
    applyPersistentControls(trafficState.profile)
end

local function setMultiplier(multiplier, reason, resourceName)
    resourceName = tostring(resourceName or 'unknown')
    local normalizedMultiplier = normalizeMultiplier(multiplier)

    if normalizedMultiplier == nil then
        trafficRequests[resourceName] = nil
    else
        requestSequence = requestSequence + 1
        trafficRequests[resourceName] = {
            multiplier = normalizedMultiplier,
            reason = tostring(reason or 'multiplier_update'),
            sequence = requestSequence,
        }
    end

    updateActiveState()
end

local function applyMode(mode, reason, resourceName)
    resourceName = tostring(resourceName or 'unknown')
    local normalizedMode = normalizeMode(mode)

    if normalizedMode == nil then
        trafficRequests[resourceName] = nil
    else
        requestSequence = requestSequence + 1
        trafficRequests[resourceName] = {
            mode = normalizedMode,
            reason = tostring(reason or 'mode_update'),
            sequence = requestSequence,
        }
    end

    updateActiveState()
end

local function applyDensity(density, reason)
    local normalizedDensity = normalizeMultiplier(density)
    if not normalizedDensity then
        return false
    end

    local resourceName = tostring(GetInvokingResource() or GetCurrentResourceName())
    setMultiplier(normalizedDensity, tostring(reason or 'density_update'), resourceName)
    return true
end

RegisterNetEvent('traffic_control:setMode', function(multiplier, reason, requestKey)
    local resourceName = requestKey or GetInvokingResource()
    setMultiplier(multiplier, reason, resourceName)
end)

exports('SetTrafficMode', function(mode, reason)
    local resourceName = GetInvokingResource()
    local normalizedDensity = normalizeMultiplier(mode)
    if normalizedDensity == nil then
        setMultiplier(nil, reason, resourceName)
        return false
    end

    setMultiplier(normalizedDensity, reason, resourceName)
    return true
end)

exports('SetTrafficDensity', function(density, reason)
    return applyDensity(density, reason)
end)

exports('GetTrafficState', function()
    local profile = trafficState.profile
    if not profile then
        if not defaultTrafficProfile then
            refreshDefaultTraffic()
        end
        profile = defaultTrafficProfile or buildProfileForMode(getDefaultMode())
    end

    return {
        mode = trafficState.mode,
        profile = profile,
        reason = trafficState.reason,
    }
end)

AddEventHandler('populationPedCreating', function()
    local profile = trafficState.profile
    if profile and profile.blockPopulationPeds then
        CancelEvent()
    end
end)

CreateThread(function()
    refreshDefaultTraffic()
    updateActiveState()

    while true do
        if trafficState.profile then
            SetVehicleDensityMultiplierThisFrame(trafficState.profile.vehicleDensity)
            SetRandomVehicleDensityMultiplierThisFrame(trafficState.profile.randomVehicleDensity)
            SetParkedVehicleDensityMultiplierThisFrame(trafficState.profile.parkedVehicleDensity)
            SetPedDensityMultiplierThisFrame(trafficState.profile.pedDensity)
            SetScenarioPedDensityMultiplierThisFrame(trafficState.profile.scenarioPedDensity, trafficState.profile.scenarioPedDensity)
        end
        Wait(0)
    end
end)

CreateThread(function()
    while true do
        local profile = trafficState.profile
        if not profile then
            if not defaultTrafficProfile then
                refreshDefaultTraffic()
            end
            profile = defaultTrafficProfile or buildProfileForMode(getDefaultMode())
        end
        applyPersistentControls(profile)
        Wait(1000)
    end
end)
