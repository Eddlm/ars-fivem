local RESOURCE_NAME = GetCurrentResourceName()

local function trim(value)
    local text = tostring(value or '')
    return (text:match('^%s*(.-)%s*$') or '')
end

local function readConvar(name, fallback)
    local value = trim(GetConvar(name, tostring(fallback or '')))
    if value == '' then
        return tostring(fallback or '')
    end
    return value
end

local function getCheckerConfig()
    return {
        repo = readConvar('racingsystem_update_repo', 'Eddlm/ars-fivem'),
        branch = readConvar('racingsystem_update_branch', 'main'),
        path = readConvar('racingsystem_update_path', 'racingsystem'),
        token = trim(GetConvar('racingsystem_update_token', '')),
        timeoutMs = 12000,
    }
end

local function getDebugPrintLevel()
    if type(GetConvarInt) == 'function' then
        return math.floor(tonumber(GetConvarInt('rSystemExtraPrints', 0)) or 0)
    end

    local raw = type(GetConvar) == 'function' and GetConvar('rSystemExtraPrints', '0') or '0'
    return math.floor(tonumber(raw) or 0)
end

local function shouldLogUpdateCheck()
    return getDebugPrintLevel() == 2
end

local function buildHttpHeaders(config)
    local headers = {
        ['User-Agent'] = 'racingsystem-update-notifier',
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
        responseHeaders = nil,
    }

    local ok, err = pcall(function()
        PerformHttpRequest(url, function(statusCode, body, responseHeaders)
            response.status = tonumber(statusCode)
            response.body = type(body) == 'string' and body or ''
            response.responseHeaders = type(responseHeaders) == 'table' and responseHeaders or {}
            response.done = true
        end, 'GET', '', headers or {})
    end)

    if not ok then
        return nil, ('HTTP request setup failed: %s'):format(tostring(err or 'unknown error'))
    end

    local deadline = GetGameTimer() + math.max(1000, math.floor(tonumber(timeoutMs) or 12000))
    while not response.done and GetGameTimer() < deadline do
        Wait(50)
    end

    if not response.done then
        return nil, ('HTTP request timed out after %dms'):format(math.max(1000, math.floor(tonumber(timeoutMs) or 12000)))
    end

    return response, nil
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
        return localMetadataVersion, 'metadata'
    end

    local manifest = LoadResourceFile(RESOURCE_NAME, 'fxmanifest.lua')
    local parsed = parseVersionFromManifestText(manifest)
    if parsed then
        return parsed, 'manifest'
    end

    return nil, 'missing'
end

local function getRemoteVersion(config, headers)
    local rawUrl = ('https://raw.githubusercontent.com/%s/%s/%s/fxmanifest.lua'):format(
        config.repo,
        config.branch,
        config.path
    )

    local response, requestError = httpRequest(rawUrl, headers, config.timeoutMs)
    if not response then
        return nil, nil, requestError
    end

    if response.status ~= 200 then
        return nil, rawUrl, ('Remote manifest fetch failed with status %s'):format(tostring(response.status))
    end

    local parsed = parseVersionFromManifestText(response.body)
    if not parsed then
        return nil, rawUrl, 'Remote fxmanifest.lua has no parseable version field.'
    end

    return parsed, nil
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

    if shouldLogUpdateCheck() then
        print(('Update check local=%s remote=%s'):format(localVersion, remoteVersion))
    end

    if isRemoteVersionNewer(localVersion, remoteVersion) then
        print(('Update available %s -> %s | Git pull or download manually https://github.com/Eddlm/ars-fivem'):format(localVersion, remoteVersion))
    end

    return true
end

RegisterCommand('rsupdatecheck', function(source)
    local numericSource = tonumber(source) or 0
    if numericSource == 0 then
        performUpdateCheck()
    end
end, false)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE_NAME then
        return
    end

    CreateThread(function()
        local delayMs = math.random(3 * 60 * 1000, 6 * 60 * 1000)
        Wait(delayMs)
        performUpdateCheck()
    end)
end)
