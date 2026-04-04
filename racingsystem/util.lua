RacingSystemUtil = RacingSystemUtil or {}

local raceCountdownVisualState = {
    instanceId = nil,
    scaleform = nil,
    lastLabel = nil,
    goVisibleUntil = 0,
}

local raceEventVisualState = {
    scaleform = nil,
    title = nil,
    subtitle = nil,
    expiresAt = 0,
}

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

local function clearCountdownScaleform()
    if raceCountdownVisualState.scaleform and raceCountdownVisualState.scaleform ~= 0 then
        SetScaleformMovieAsNoLongerNeeded(raceCountdownVisualState.scaleform)
    end
    raceCountdownVisualState.scaleform = nil
    raceCountdownVisualState.lastLabel = nil
    raceCountdownVisualState.instanceId = nil
    raceCountdownVisualState.goVisibleUntil = 0
end

local function ensureCountdownScaleform()
    if raceCountdownVisualState.scaleform and raceCountdownVisualState.scaleform ~= 0 then
        return raceCountdownVisualState.scaleform
    end

    local handle = RequestScaleformMovie('MP_BIG_MESSAGE_FREEMODE')
    if not handle or handle == 0 then
        return nil
    end

    raceCountdownVisualState.scaleform = handle
    return handle
end

local function clearRaceEventScaleform()
    if raceEventVisualState.scaleform and raceEventVisualState.scaleform ~= 0 then
        SetScaleformMovieAsNoLongerNeeded(raceEventVisualState.scaleform)
    end
    raceEventVisualState.scaleform = nil
    raceEventVisualState.title = nil
    raceEventVisualState.subtitle = nil
    raceEventVisualState.expiresAt = 0
end

local function clearRaceLeaderboardVisualState()
    raceLeaderboardVisualState.rows = {}
    raceLeaderboardVisualState.entriesByKey = {}
end

local function ensureRaceEventScaleform()
    if raceEventVisualState.scaleform and raceEventVisualState.scaleform ~= 0 then
        return raceEventVisualState.scaleform
    end

    local handle = RequestScaleformMovie('MP_BIG_MESSAGE_FREEMODE')
    if not handle or handle == 0 then
        return nil
    end

    raceEventVisualState.scaleform = handle
    return handle
end

function RacingSystemUtil.ShowRaceEventVisual(title, subtitle, durationMs)
    raceEventVisualState.title = tostring(title or '')
    raceEventVisualState.subtitle = tostring(subtitle or '')
    raceEventVisualState.expiresAt = GetGameTimer() + math.max(250, math.floor(tonumber(durationMs) or 1500))
end

function RacingSystemUtil.DrawRaceEventVisual()
    local now = GetGameTimer()
    if (tonumber(raceEventVisualState.expiresAt) or 0) <= now then
        if raceEventVisualState.scaleform then
            clearRaceEventScaleform()
        end
        return
    end

    local scaleform = ensureRaceEventScaleform()
    if not scaleform or scaleform == 0 or not HasScaleformMovieLoaded(scaleform) then
        return
    end

    BeginScaleformMovieMethod(scaleform, 'SHOW_SHARD_CENTERED_MP_MESSAGE')
    PushScaleformMovieMethodParameterString(raceEventVisualState.title or '')
    PushScaleformMovieMethodParameterString(raceEventVisualState.subtitle or '')
    EndScaleformMovieMethod()
    DrawScaleformMovie(scaleform, 0.5, 0.34, 1.0, 1.0, 255, 255, 255, 255, 0)
end

function RacingSystemUtil.UpdateCountdownVisual(instanceId, remainingMs)
    local resolvedInstanceId = tonumber(instanceId)
    if not resolvedInstanceId then
        clearCountdownScaleform()
        return
    end

    if raceCountdownVisualState.instanceId ~= resolvedInstanceId then
        raceCountdownVisualState.instanceId = resolvedInstanceId
        raceCountdownVisualState.lastLabel = nil
        raceCountdownVisualState.goVisibleUntil = 0
    end

    local now = GetGameTimer()
    local label = nil
    local ms = math.max(0, tonumber(remainingMs) or 0)
    if ms <= 0 then
        label = 'GO'
        if raceCountdownVisualState.goVisibleUntil <= 0 then
            raceCountdownVisualState.goVisibleUntil = now + 1000
        end
        if now > raceCountdownVisualState.goVisibleUntil then
            clearCountdownScaleform()
            return
        end
    elseif ms <= 1000 then
        label = '1'
    elseif ms <= 2000 then
        label = '2'
    elseif ms <= 3000 then
        label = '3'
    else
        raceCountdownVisualState.lastLabel = nil
        return
    end

    local scaleform = ensureCountdownScaleform()
    if not scaleform or scaleform == 0 or not HasScaleformMovieLoaded(scaleform) then
        return
    end

    if raceCountdownVisualState.lastLabel ~= label then
        raceCountdownVisualState.lastLabel = label
        local styledLabel = (label == 'GO') and '~g~GO' or ('~y~%s'):format(label)
        BeginScaleformMovieMethod(scaleform, 'SHOW_SHARD_CENTERED_MP_MESSAGE')
        PushScaleformMovieMethodParameterString(styledLabel)
        PushScaleformMovieMethodParameterString('')
        EndScaleformMovieMethod()
    end

    DrawScaleformMovie(scaleform, 0.5, 0.3, 1.0, 1.0, 255, 255, 255, 255, 0)
end

function RacingSystemUtil.ClearCountdownVisual()
    clearCountdownScaleform()
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
