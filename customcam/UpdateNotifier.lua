local RESOURCE_NAME = GetCurrentResourceName()
local Config = (((CustomCam or {}).Config) or {}).UpdateCheck or (((CustomCam or {}).Config) or {}).updateCheck or {}

-- Trims whitespace from the beginning and end of a string
local function trim(value)
    local text = tostring(value or '')
    return (text:match('^%s*(.-)%s*$') or '')
end

-- Reads a convar value with a fallback, trimming whitespace
local function getCheckerConfig()
    return {
        repo = tostring(Config.repo or 'Eddlm/ars-fivem'),
        branch = tostring(Config.branch or 'main'),
        path = tostring(Config.path or 'customcam'),
        token = trim(Config.token or ''),
        timeoutMs = math.max(1000, math.floor(tonumber(Config.timeoutMs) or 12000)),
    }
end


-- Builds HTTP headers for GitHub API requests, including auth if token is present
local function buildHttpHeaders(config)
    local headers = {
        ['User-Agent'] = 'customcam-update-notifier',
        ['Accept'] = 'application/vnd.github+json',
    }
    if config.token ~= '' then
        headers['Authorization'] = ('Bearer %s'):format(config.token)
    end
    return headers
end

-- Performs an HTTP GET request with timeout handling
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

-- Extracts version string from fxmanifest.lua content (looks for version = 'x.y.z' or version = "x.y.z")
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

-- Gets the local version from resource metadata or fxmanifest.lua
local function getLocalVersion()
    local localMetadataVersion = trim(GetResourceMetadata(RESOURCE_NAME, 'version', 0) or '')
    if localMetadataVersion ~= '' then
        return localMetadataVersion
    end
    local manifest = LoadResourceFile(RESOURCE_NAME, 'fxmanifest.lua')
    return parseVersionFromManifestText(manifest)
end

-- Fetches the remote version from GitHub raw fxmanifest.lua
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

-- Parses a version string into numeric segments (e.g., '1.2.3' -> {1, 2, 3})
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

-- Compares two version strings to determine if remote is newer than local
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

-- Performs the actual update check: gets local and remote versions, logs if debug enabled, prints update available message
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

-- Registers the /ccamupdatecheck command to manually trigger an update check
RegisterCommand('ccamupdatecheck', function(source)
    local numericSource = tonumber(source) or 0
    if numericSource == 0 then
        performUpdateCheck()
    end
end, false)

local checkDeadline = nil

-- Resets the update check countdown whenever any resource starts, so the check
-- fires 20-40s after the last resource finishes loading rather than immediately.
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
