RacingSystem = RacingSystem or {}
RacingSystem.Client = RacingSystem.Client or {}
RacingSystem.Menu = RacingSystem.Menu or {}
RacingSystem.Client.Util = RacingSystem.Client.Util or {}

if type(RacingSystem.Client.Util.NotifyPlayer) ~= 'function' then
    RacingSystem.Client.Util.NotifyPlayer = function(message)
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(tostring(message or ''))
        EndTextCommandThefeedPostTicker(false, false)
    end
end

if type(RacingSystem.Client.Util.ShowWarningSubtitle) ~= 'function' then
    RacingSystem.Client.Util.ShowWarningSubtitle = function(message, durationMs, colorTag)
        BeginTextCommandPrint('STRING')
        local colorPrefix = tostring(colorTag or '~y~')
        AddTextComponentSubstringPlayerName(('%s%s~s~'):format(colorPrefix, tostring(message or '')))
        EndTextCommandPrint(math.max(0, math.floor(tonumber(durationMs) or 1000)), true)
    end
end

if type(RacingSystem.Client.Util.UpdateCountdownVisual) ~= 'function' then
    RacingSystem.Client.Util.UpdateCountdownVisual = function(_, remainingMs)
        local seconds = math.floor((tonumber(remainingMs) or 0) / 1000)
        if seconds >= 0 then
            ScaleformUI.Scaleforms.BigMessageInstance:ShowMpMessageLarge('Race starts in', tostring(seconds), 1000)
        end
    end
end

if type(RacingSystem.Client.Util.ClearCountdownVisual) ~= 'function' then
    RacingSystem.Client.Util.ClearCountdownVisual = function()
        ScaleformUI.Scaleforms.BigMessageInstance:Dispose()
    end
end
