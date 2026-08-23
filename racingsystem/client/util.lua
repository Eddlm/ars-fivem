RacingSystem = RacingSystem or {}
RacingSystem.Client = RacingSystem.Client or {}
RacingSystem.Menu = RacingSystem.Menu or {}
RacingSystem.Client.Util = RacingSystem.Client.Util or {}

local raceLeaderboardVisualState = {
    title = 'LEADERBOARD',
    rows = {},
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
    raceLeaderboardVisualState.rows = {}
    for index, row in ipairs(type(rows) == 'table' and rows or {}) do
        raceLeaderboardVisualState.rows[index] = {
            key = tostring((type(row) == 'table' and row.key) or index),
            position = tostring((type(row) == 'table' and row.position) or '-'),
            name = tostring((type(row) == 'table' and row.name) or ''),
            lap = tostring((type(row) == 'table' and row.lap) or '-'),
            laptime = tostring((type(row) == 'table' and row.laptime) or '-'),
        }
    end
end

function RacingSystem.Client.Util.DrawRaceLeaderboardVisual()
    local rows = type(raceLeaderboardVisualState.rows) == 'table' and raceLeaderboardVisualState.rows or {}
    if #rows == 0 then
        return
    end

    local panelX = 0.74
    local panelY = 0.12
    local panelW = 0.24
    local lineH = 0.026
    local headerH = 0.03
    local bodyH = lineH * #rows
    local totalH = headerH + bodyH + 0.006

    DrawRect(panelX + panelW * 0.5, panelY + totalH * 0.5, panelW, totalH, 10, 14, 24, 170)

    local headerY = panelY + headerH * 0.5
    DrawRect(panelX + panelW * 0.5, headerY, panelW, headerH, 60, 140, 255, 200)
    local colX = {
        panelX + 0.02,
        panelX + 0.08,
        panelX + 0.16,
        panelX + 0.20,
    }
    drawLeaderboardText(colX[1], headerY - 0.006, 0.28, 'POS', 255, 255, 255, 255, false)
    drawLeaderboardText(colX[2], headerY - 0.006, 0.28, 'PLAYER', 255, 255, 255, 255, false)
    drawLeaderboardText(colX[3], headerY - 0.006, 0.28, 'LAP', 255, 255, 255, 255, false)
    drawLeaderboardText(colX[4], headerY - 0.006, 0.28, 'LAPTIME', 255, 255, 255, 255, false)

    for i, row in ipairs(rows) do
        local rowY = panelY + headerH + lineH * (i - 0.5)
        drawLeaderboardText(colX[1], rowY - 0.006, 0.26, row.position, 255, 255, 255, 255, false)
        drawLeaderboardText(colX[2], rowY - 0.006, 0.26, row.name, 255, 255, 255, 255, false)
        drawLeaderboardText(colX[3], rowY - 0.006, 0.26, row.lap, 255, 255, 255, 255, false)
        drawLeaderboardText(colX[4], rowY - 0.006, 0.26, row.laptime, 255, 255, 255, 255, false)
    end
end

function RacingSystem.Client.Util.ClearRaceLeaderboardVisual()
    raceLeaderboardVisualState.rows = {}
end