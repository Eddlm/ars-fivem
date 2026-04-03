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
