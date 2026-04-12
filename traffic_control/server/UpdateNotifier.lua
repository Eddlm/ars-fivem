local RESOURCE_NAME = GetCurrentResourceName()
local Config = (((TrafficControl or {}).Config) or {}).updateCheck or {}

local function trim(value)
    local text = tostring(value or '')
    return (text:match('^%s*(.-)%s*$') or '')
end

local function getCheckerConfig()
    return {
        repo = tostring(Config.repo or 'Eddlm/ars-fivem'),
        branch = tostring(Config.branch or 'main'),
        path = tostring(Config.path or 'traffic_control'),
        token = trim(Config.token or ''),
        timeoutMs = math.max(1000, math.floor(tonumber(Config.timeoutMs) or 12000)),
    }
end


local function buildHttpHeaders(config)
    local headers = {
        ['User-Agent'] = 'traffic_control-update-notifier',
        ['Accept'] = 'application/vnd.github+json',
    }
    if config.token ~= '' then
        headers['Authorization'] = ('Bearer %s'):format(config.token)
    end
    return headers
end

local function httpRequest(url, headers, timeoutMs)
    local response = {
        done = false,
        status = nil,
        body = nil,
    }

    local ok = pcall(function()
        PerformHttpRequest(url, function(statusCode, body)
            response.status = tonumber(statusCode)
            response.body = type(body) == 'string' and body or ''
            response.done = true
        end, 'GET', '', headers or {})
    end)

    if not ok then
        return nil
    end

    local deadline = GetGameTimer() + math.max(1000, math.floor(tonumber(timeoutMs) or 12000))
    while not response.done and GetGameTimer() < deadline do
        Wait(50)
    end

    if not response.done then
        return nil
    end

    return response
end

local function parseVersionFromManifestText(content)
    if type(content) ~= 'string' or content == '' then
        return nil
    end
    local version = content:match("%f[%w_]version%f[^%w_]%s*'([^']+)'")
    if not version then
        version = content:match('%f[%w_]version%f[^%w_]%s*"([^"]+)"')
    end
    version = trim(version)
    if version == '' then
        return nil
    end
    return version
end

local function getLocalVersion()
    local localMetadataVersion = trim(GetResourceMetadata(RESOURCE_NAME, 'version', 0) or '')
    if localMetadataVersion ~= '' then
        return localMetadataVersion
    end
    local manifest = LoadResourceFile(RESOURCE_NAME, 'fxmanifest.lua')
    return parseVersionFromManifestText(manifest)
end

local function getRemoteVersion(config, headers)
    local rawUrl = ('https://raw.githubusercontent.com/%s/%s/%s/fxmanifest.lua'):format(
        config.repo,
        config.branch,
        config.path
    )

    local response = httpRequest(rawUrl, headers, config.timeoutMs)
    if not response or response.status ~= 200 then
        return nil
    end

    return parseVersionFromManifestText(response.body)
end

local function parseVersionSegments(version)
    local cleaned = trim(version)
    if cleaned == '' then
        return nil
    end
    local segments = {}
    for token in cleaned:gmatch('[^%.]+') do
        local numeric = token:match('^(%d+)')
        if not numeric then
            return nil
        end
        segments[#segments + 1] = tonumber(numeric) or 0
    end
    if #segments == 0 then
        return nil
    end
    return segments
end

local function isRemoteVersionNewer(localVersion, remoteVersion)
    local localSegments = parseVersionSegments(localVersion)
    local remoteSegments = parseVersionSegments(remoteVersion)
    if not localSegments or not remoteSegments then
        return false
    end

    local maxLength = math.max(#localSegments, #remoteSegments)
    for index = 1, maxLength do
        local localPart = localSegments[index] or 0
        local remotePart = remoteSegments[index] or 0
        if remotePart > localPart then
            return true
        end
        if remotePart < localPart then
            return false
        end
    end
    return false
end

local function performUpdateCheck()
    local config = getCheckerConfig()
    local headers = buildHttpHeaders(config)

    local localVersion = getLocalVersion()
    if not localVersion then
        return false
    end

    local remoteVersion = getRemoteVersion(config, headers)
    if not remoteVersion then
        return false
    end

    if isRemoteVersionNewer(localVersion, remoteVersion) then
        print(('Checking for updates.... %s > %s available on https://github.com/Eddlm/ars-fivem/releases'):format(localVersion, remoteVersion))
    elseif GetConvar('ars_skip_uptodate_print', '0') ~= '1' then
        print(('Checking for updates.... Up to date (%s)'):format(localVersion))
    end

    return true
end

RegisterCommand('tcupdatecheck', function(source)
    local numericSource = tonumber(source) or 0
    if numericSource == 0 then
        performUpdateCheck()
    end
end, false)

local checkDeadline = nil

AddEventHandler('onResourceStart', function()
    checkDeadline = GetGameTimer() + math.random(20 * 1000, 40 * 1000)
end)

CreateThread(function()
    while true do
        if checkDeadline and GetGameTimer() >= checkDeadline then
            checkDeadline = nil
            performUpdateCheck()
        end
        Wait(1000)
    end
end)
