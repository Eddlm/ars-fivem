RacingSystem = RacingSystem or {}
RacingSystem.Client = RacingSystem.Client or {}
RacingSystem.Menu = RacingSystem.Menu or {}
RacingSystem.Client.Util = RacingSystem.Client.Util or {}

local raceLeaderboardVisualState = {
    title = 'LEADERBOARD',
    rows = {},
    finalizedByKey = {},
}

local raceEventVisualState = {
    title = '',
    subtitle = '',
    expiresAt = 0,
}

local function drawLeaderboardText(x, y, scale, text, r, g, b, a, centered)
    SetTextFont(0)
    SetTextProportional(1)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, a)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(centered == true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(tostring(text or ''))
    EndTextCommandDisplayText(x, y)
end

function RacingSystem.Client.Util.NotifyPlayer(message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(tostring(message or ''))
    EndTextCommandThefeedPostTicker(false, false)
end

function RacingSystem.Client.Util.ShowWarningSubtitle(message, durationMs, colorTag)
    BeginTextCommandPrint('STRING')
    local colorPrefix = tostring(colorTag or '~y~')
    AddTextComponentSubstringPlayerName(('%s%s~s~'):format(colorPrefix, tostring(message or '')))
    EndTextCommandPrint(math.max(0, math.floor(tonumber(durationMs) or 1000)), true)
end

function RacingSystem.Client.Util.UpdateCountdownVisual(_, remainingMs)
    local seconds = math.floor((tonumber(remainingMs) or 0) / 1000)
    if seconds >= 0 then
        RacingSystem.Client.Util.ShowWarningSubtitle(('Race starts in %s'):format(tostring(seconds)), 1000, '~b~')
    end
end

function RacingSystem.Client.Util.ClearCountdownVisual()
end

function RacingSystem.Client.Util.ShowRaceEventVisual(title, subtitle, durationMs)
    raceEventVisualState.title = tostring(title or '')
    raceEventVisualState.subtitle = tostring(subtitle or '')
    raceEventVisualState.expiresAt = GetGameTimer() + math.max(0, math.floor(tonumber(durationMs) or 1200))
end

function RacingSystem.Client.Util.DrawRaceEventVisual()
    local expiresAt = tonumber(raceEventVisualState.expiresAt) or 0
    local now = GetGameTimer()
    if expiresAt <= now then
        raceEventVisualState.title = ''
        raceEventVisualState.subtitle = ''
        return
    end

    local title = raceEventVisualState.title
    local subtitle = raceEventVisualState.subtitle
    if title == '' and subtitle == '' then
        return
    end

    local bodyX = 0.5
    local bodyY = 0.185
    local hasSubtitle = subtitle ~= ''
    local bodyHeight = hasSubtitle and 0.09 or 0.062
    DrawRect(bodyX, bodyY, 0.48, bodyHeight, 10, 14, 24, 150)
    drawLeaderboardText(bodyX, bodyY - (hasSubtitle and 0.024 or 0.012), 0.45, title, 245, 250, 255, 235, true)
    if hasSubtitle then
        drawLeaderboardText(bodyX, bodyY + 0.01, 0.32, subtitle, 210, 225, 255, 220, true)
    end
end

function RacingSystem.Client.Util.UpdateRaceLeaderboardVisual(title, rows)
    raceLeaderboardVisualState.title = tostring(title or 'LEADERBOARD')
    local previousByKey = {}
    for _, existing in ipairs(type(raceLeaderboardVisualState.rows) == 'table' and raceLeaderboardVisualState.rows or {}) do
        if type(existing) == 'table' then
            previousByKey[tostring(existing.key or '')] = existing
        end
    end

    local finalizedByKey = type(raceLeaderboardVisualState.finalizedByKey) == 'table' and raceLeaderboardVisualState.finalizedByKey or {}
    raceLeaderboardVisualState.finalizedByKey = finalizedByKey
    raceLeaderboardVisualState.rows = {}

    for index, row in ipairs(type(rows) == 'table' and rows or {}) do
        local rowKey = tostring((type(row) == 'table' and row.key) or index)
        local incomingFinalized = type(row) == 'table' and row.finalized == true
        local wasFinalized = finalizedByKey[rowKey] == true
        local shouldFinalize = incomingFinalized or wasFinalized
        local previous = previousByKey[rowKey]

        if shouldFinalize then
            finalizedByKey[rowKey] = true
        end

        local resolvedRank = math.max(1, math.floor(tonumber(type(row) == 'table' and row.rank) or index))
        if shouldFinalize and type(previous) == 'table' and tonumber(previous.rank) then
            resolvedRank = math.max(1, math.floor(tonumber(previous.rank) or resolvedRank))
        end

        local resolvedText = tostring((type(row) == 'table' and row.text) or '')
        if shouldFinalize and type(previous) == 'table' and type(previous.text) == 'string' and previous.text ~= '' then
            resolvedText = previous.text
        end

        raceLeaderboardVisualState.rows[index] = {
            key = rowKey,
            text = resolvedText,
            rank = resolvedRank,
            finalized = shouldFinalize,
        }
    end
end

function RacingSystem.Client.Util.ClearRaceLeaderboardVisual()
    raceLeaderboardVisualState.rows = {}
    raceLeaderboardVisualState.finalizedByKey = {}
end