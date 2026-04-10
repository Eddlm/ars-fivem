TrafficControl = TrafficControl or {}
local ServerConfig = (((TrafficControl or {}).Config) or {}).server or {}
local SERVER_REQUEST_PREFIX = tostring(ServerConfig.requestPrefix or 'server:')

local function emitTrafficRequest(kind, value, reason, requestKey)
    if kind == 'density' then
        TriggerClientEvent('traffic_control:setMode', -1, value, reason or 'server_density_request', requestKey)
        return true
    end

    return false
end

local function clearTrafficRequest(reason, requestKey)
    TriggerClientEvent('traffic_control:setMode', -1, nil, reason or 'server_request_cleared', requestKey)
end

exports('SetServerTrafficMode', function(mode, reason, requestName)
    local numericMode = tonumber(mode)
    if numericMode == nil then
        return false
    end

    local requestKey = SERVER_REQUEST_PREFIX .. tostring(requestName or 'script')
    return emitTrafficRequest('density', numericMode, reason or 'server_export_mode', requestKey)
end)

exports('SetServerTrafficDensity', function(density, reason, requestName)
    local requestKey = SERVER_REQUEST_PREFIX .. tostring(requestName or 'script')
    return emitTrafficRequest('density', density, reason or 'server_export_density', requestKey)
end)

exports('ClearServerTrafficRequest', function(reason, requestName)
    local requestKey = SERVER_REQUEST_PREFIX .. tostring(requestName or 'script')
    clearTrafficRequest(reason or 'server_export_clear', requestKey)
    return true
end)
