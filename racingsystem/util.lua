RacingSystemUtil = RacingSystemUtil or {}

local raceLeaderboardVisualState = {
    rows = {},
    entriesByKey = {},
}

function RacingSystemUtil.NotifyPlayer(message, isError)
    local colorPrefix = isError and '~o~' or '~g~'
    local text = ('%s%s~s~'):format(colorPrefix, tostring(message or ''))
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostTicker(false, false)
end

function RacingSystemUtil.ShowWarningSubtitle(message, durationMs, colorTag)
    BeginTextCommandPrint('STRING')
    local colorPrefix = tostring(colorTag or '~y~')
    AddTextComponentSubstringPlayerName(('%s%s~s~'):format(colorPrefix, tostring(message or '')))
    EndTextCommandPrint(math.max(0, math.floor(tonumber(durationMs) or 1000)), true)
end

function RacingSystemUtil.ShowRaceEventVisual(title, subtitle, durationMs)
    -- UI is disabled.
end

function RacingSystemUtil.DrawRaceEventVisual()
    -- UI is disabled.
end

function RacingSystemUtil.UpdateCountdownVisual(instanceId, remainingMs)
    -- UI is disabled.
end

function RacingSystemUtil.ClearCountdownVisual()
    -- UI is disabled.
end

local function clearRaceLeaderboardVisualState()
    raceLeaderboardVisualState.rows = {}
    raceLeaderboardVisualState.entriesByKey = {}
end

function RacingSystemUtil.UpdateRaceLeaderboardVisual(title, rows)
    local rowList = type(rows) == 'table' and rows or {}
    if #rowList == 0 then
        clearRaceLeaderboardVisualState()
        return
    end

    local resolvedRows = {}
    for index = 1, math.min(8, #rowList) do
        local row = rowList[index]
        local text
        local key

        if type(row) == 'table' then
            text = tostring(row.text or '')
            key = tostring(row.key or text)
        else
            text = tostring(row or '')
            key = text
        end

        if text ~= '' then
            local existingEntry = raceLeaderboardVisualState.entriesByKey[key]
            resolvedRows[#resolvedRows + 1] = {
                key = key,
                text = text,
                currentY = existingEntry and tonumber(existingEntry.currentY) or nil,
            }
        end
    end

    if #resolvedRows == 0 then
        clearRaceLeaderboardVisualState()
        return
    end

    local nextEntriesByKey = {}
    for _, row in ipairs(resolvedRows) do
        nextEntriesByKey[row.key] = row
    end

    raceLeaderboardVisualState.entriesByKey = nextEntriesByKey
    raceLeaderboardVisualState.rows = resolvedRows
end

function RacingSystemUtil.DrawRaceLeaderboardVisual()
    local rows = raceLeaderboardVisualState.rows
    if type(rows) ~= 'table' or #rows == 0 then
        return
    end

    local baseX = 0.085
    local baseY = 0.33
    local rowWidth = 0.14
    local rowHeight = 0.03
    local rowGap = 0.006
    local textOffsetX = 0.006
    local textOffsetY = 0.0115
    local smoothingFactor = math.max(0.0, math.min(1.0, (tonumber(GetFrameTime()) or 0.0) * 10.0))

    for index, row in ipairs(rows) do
        local targetY = baseY + ((index - 1) * (rowHeight + rowGap))
        local currentY = tonumber(row.currentY)
        if currentY == nil then
            currentY = targetY
        else
            currentY = currentY + ((targetY - currentY) * smoothingFactor)
        end

        row.currentY = currentY
        raceLeaderboardVisualState.entriesByKey[row.key] = row

        DrawRect(baseX, currentY, rowWidth, rowHeight, 0, 0, 0, 185)

        SetTextFont(4)
        SetTextScale(0.33, 0.33)
        SetTextColour(255, 255, 255, 245)
        SetTextWrap(0.0, 1.0)
        SetTextJustification(1)
        SetTextCentre(false)
        BeginTextCommandDisplayText('STRING')
        AddTextComponentSubstringPlayerName(row.text)
        EndTextCommandDisplayText((baseX - (rowWidth * 0.5)) + textOffsetX, currentY - textOffsetY)
    end
end

function RacingSystemUtil.ClearRaceLeaderboardVisual()
    clearRaceLeaderboardVisualState()
end
