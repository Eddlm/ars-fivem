TrafficControl = TrafficControl or {}
local ServerConfig = (((TrafficControl or {}).Config) or {}).server or {}
local SERVER_REQUEST_PREFIX = tostring(ServerConfig.requestPrefix or 'server:')
local CLIENT_REQUEST_PREFIX = 'client:'
local PRINT_REQUESTS_CONVAR = 'tControlPrintRequests'
local REQUEST_EVENT = 'traffic_control:requestDensity'

local function shouldPrintRequests()
    return GetConvarBool(PRINT_REQUESTS_CONVAR, false)
end

local function printRequestEvent(requestKey, density, reason, sourceLabel)
    if not shouldPrintRequests() then
        return
    end

    local densityText = density == nil and 'nil' or tostring(density)
    local reasonText = tostring(reason or '')
    if reasonText == '' then
        reasonText = 'no reason'
    end

    print(('[traffic_control] %s requested density of %s (%s)'):format(
        tostring(sourceLabel or 'unknown'),
        densityText,
        reasonText
    ))
end

local function emitDensityRequest(target, density, reason, requestKey, sourceLabel)
    local numericDensity = nil
    if density ~= nil then
        numericDensity = tonumber(density)
        if numericDensity == nil then
            printRequestEvent(requestKey, density, reason, sourceLabel)
            return false
        end
    end

    TriggerClientEvent('traffic_control:setMode', target, numericDensity, reason or 'traffic_request', requestKey)
    printRequestEvent(requestKey, numericDensity, reason or 'traffic_request', sourceLabel)
    return true
end

local function buildServerRequestKey(requestName)
    return SERVER_REQUEST_PREFIX .. tostring(requestName or 'script')
end

local function buildClientRequestKey(playerSource, requestName)
    return CLIENT_REQUEST_PREFIX .. tostring(playerSource) .. ':' .. tostring(requestName or 'script')
end

RegisterNetEvent(REQUEST_EVENT, function(density, reason, requestName)
    local playerSource = tonumber(source) or 0
    if playerSource > 0 then
        local requestKey = buildClientRequestKey(playerSource, requestName)
        emitDensityRequest(
            playerSource,
            density,
            reason or 'client_event_request',
            requestKey,
            REQUEST_EVENT .. ' client:' .. tostring(playerSource)
        )
        return
    end

    local requestKey = buildServerRequestKey(requestName)
    emitDensityRequest(-1, density, reason or 'server_event_request', requestKey, REQUEST_EVENT .. ' server')
end)
