RacingSystem = RacingSystem or {}
RacingSystem.Server = RacingSystem.Server or {}
RacingSystem.Server.Logging = RacingSystem.Server.Logging or {}

local function getExtraPrintLevel()
    return math.max(0, math.min(2, tonumber((RacingSystem.Server.State or {}).config and RacingSystem.Server.State.config.extraPrintLevel) or 0))
end

local function logError(message)
    print(tostring(message or 'Unknown server error.'))
end

local function logLevelOne(message)
    if getExtraPrintLevel() < 1 then
        return
    end
    print(tostring(message or ''))
end

local function logVerbose(message)
    if getExtraPrintLevel() < 2 then
        return
    end
    print(tostring(message or ''))
end

local function shouldLogCheckpointAnomaly(source, instanceId)
    local key = ('%s:%s'):format(tonumber(source) or 0, tonumber(instanceId) or -1)
    local now = GetGameTimer()
    local map = (RacingSystem.Server.State or {}).checkpointAnomalyLogByKey or {}
    local lastLoggedAt = tonumber(map[key]) or -100000
    if now - lastLoggedAt < 2000 then
        return false
    end

    map[key] = now
    return true
end

local function shouldLogLifecycleAnomaly(eventName, source, instanceId)
    local key = ('%s:%s:%s'):format(tostring(eventName or 'unknown'), tonumber(source) or 0, tonumber(instanceId) or -1)
    local now = GetGameTimer()
    local map = (RacingSystem.Server.State or {}).lifecycleAnomalyLogByKey or {}
    local lastLoggedAt = tonumber(map[key]) or -100000
    if now - lastLoggedAt < 2000 then
        return false
    end

    map[key] = now
    return true
end

local function logLifecycleEvent(eventName, instance, entrant, source, oldState, newState, reason)
    logLevelOne(("[lifecycle] event=%s instanceId=%s entrantId=%s source=%s from=%s to=%s reason=%s"):format(
        tostring(eventName or 'unknown'),
        tostring(type(instance) == 'table' and instance.id or 'nil'),
        tostring(type(entrant) == 'table' and entrant.entrantId or 'nil'),
        tostring(tonumber(source) or 0),
        tostring(oldState or 'nil'),
        tostring(newState or 'nil'),
        tostring(reason or 'none')
    ))
end

local function buildEntrantId(source)
    local token = tonumber((RacingSystem.Server.State or {}).nextEntrantIdToken) or 1
    RacingSystem.Server.State.nextEntrantIdToken = token + 1
    return ('%s-%s-%s'):format(
        tostring(tonumber(source) or 0),
        tostring(math.floor(tonumber(os.time()) or 0)),
        tostring(token)
    )
end

local function isLifecycleTransitionAllowed(fromState, toState)
    if fromState == toState then
        return true
    end

    local stateRules = {
        [RacingSystem.States.idle] = {
            [RacingSystem.States.staging] = true,
            terminated = true,
        },
        [RacingSystem.States.staging] = {
            [RacingSystem.States.running] = true,
            [RacingSystem.States.idle] = true,
            terminated = true,
        },
        [RacingSystem.States.running] = {
            [RacingSystem.States.finished] = true,
            [RacingSystem.States.idle] = true,
            terminated = true,
        },
        [RacingSystem.States.finished] = {
            [RacingSystem.States.staging] = true,
            [RacingSystem.States.idle] = true,
            terminated = true,
        },
    }

    local allowedTargets = stateRules[fromState]
    if type(allowedTargets) ~= 'table' then
        return false
    end

    return allowedTargets[toState] == true
end

local function setRaceInstanceState(instance, nextState, eventName, source, entrant, reason)
    if type(instance) ~= 'table' then
        return false, 'Missing race instance.'
    end

    local currentState = tostring(instance.state or RacingSystem.States.idle)
    local targetState = tostring(nextState or currentState)
    if currentState == targetState then
        return true
    end

    if not isLifecycleTransitionAllowed(currentState, targetState) then
        RacingSystem.Server.State.reliabilityCounters.illegalLifecycleRequests = (tonumber(RacingSystem.Server.State.reliabilityCounters.illegalLifecycleRequests) or 0) + 1
        if shouldLogLifecycleAnomaly(eventName, source, instance.id) then
            logLifecycleEvent(eventName, instance, entrant, source, currentState, targetState, reason or 'illegal_transition')
        end
        return false, ('Illegal lifecycle transition (%s -> %s).'):format(currentState, targetState)
    end

    instance.state = targetState
    if type(GlobalState) == 'table' then
        GlobalState[('rs:raceState:%s'):format(tostring(tonumber(instance.id) or -1))] = targetState
    end
    logLifecycleEvent(eventName, instance, entrant, source, currentState, targetState, reason or 'state_transition')
    return true
end

local function setRaceStateBag(instance)
    if type(instance) ~= 'table' or type(GlobalState) ~= 'table' then
        return
    end
    GlobalState[('rs:raceState:%s'):format(tostring(tonumber(instance.id) or -1))] = tostring(instance.state or RacingSystem.States.idle)
end

local function clearRaceStateBagByInstanceId(instanceId)
    if type(GlobalState) ~= 'table' then
        return
    end
    GlobalState[('rs:raceState:%s'):format(tostring(tonumber(instanceId) or -1))] = nil
end

local function resolvePlayerLogLabel(sourceId)
    local numericSource = tonumber(sourceId) or 0
    local playerName = (numericSource == 0 and 'console') or (GetPlayerName(numericSource) or ('player:%s'):format(tostring(numericSource)))
    return ('%s (%s)'):format(playerName, tostring(numericSource))
end

local function resolveReadablePlayerName(playerSource, entrant)
    local liveName = type(GetPlayerName) == 'function' and GetPlayerName(playerSource) or nil
    if type(liveName) == 'string' then
        local trimmed = liveName:match('^%s*(.-)%s*$')
        if trimmed and trimmed ~= '' then
            return trimmed
        end
    end

    local entrantName = tostring((entrant or {}).name or '')
    local trimmedEntrantName = entrantName:match('^%s*(.-)%s*$') or ''
    if trimmedEntrantName ~= '' and not trimmedEntrantName:match('^[Pp]layer%s+%d+$') then
        return trimmedEntrantName
    end

    return ('player:%s'):format(tostring(playerSource))
end

local function logCheckpointPassContext(instance, entrant, reportedCheckpoint, totalCheckpoints, lapNumber, totalLaps, passContext)
    local printLevel = getExtraPrintLevel()
    if printLevel == 0 then
        return
    end

    local context = type(passContext) == 'table' and passContext or {}
    local playerSource = tonumber((entrant or {}).source) or 0
    local playerName = resolveReadablePlayerName(playerSource, entrant)
    local raceName = tostring((instance or {}).name or 'unknown')
    local contextKind = tostring(context.kind or 'unknown')
    local penalty = tostring(context.penalty or 'none')
    local routeVariant = tostring(context.routeVariant or 'primary')
    local outsideOffset = tonumber(context.outsideOffset) or 0.0
    local throttlePenaltyMs = math.max(0, math.floor(tonumber(context.throttlePenaltyMs) or 0))
    local powerPenaltyMs = math.max(0, math.floor(tonumber(context.powerPenaltyMs) or 0))
    local assumedCrashPenaltyVoided = context.assumedCrashPenaltyVoided == true and 'yes' or 'no'

    local checkpointNumber = math.max(0, math.floor(tonumber(reportedCheckpoint) or 0))
    local checkpointTotal = math.max(0, math.floor(tonumber(totalCheckpoints) or 0))
    local currentLap = math.max(1, math.floor(tonumber(lapNumber) or 1))
    local lapTotal = math.max(1, math.floor(tonumber(totalLaps) or 1))

    local hasPenalty = (
        penalty ~= 'none'
        or throttlePenaltyMs > 0
        or powerPenaltyMs > 0
        or outsideOffset > 0.01
        or contextKind ~= 'clean_pass'
        or assumedCrashPenaltyVoided == 'yes'
    )
    if printLevel == 1 and not hasPenalty then
        return
    end

    local details = {}
    if contextKind ~= 'clean_pass' then
        table.insert(details, ('context: %s'):format(contextKind:gsub('_', ' ')))
    end
    if penalty ~= 'none' then
        table.insert(details, ('penalty: %s'):format(penalty:gsub('_', ' ')))
    end
    if outsideOffset > 0.01 then
        table.insert(details, ('outside by %.2fm'):format(outsideOffset))
    end
    if throttlePenaltyMs > 0 then
        table.insert(details, ('throttle penalty: %dms'):format(throttlePenaltyMs))
    end
    if powerPenaltyMs > 0 then
        table.insert(details, ('power penalty: %dms'):format(powerPenaltyMs))
    end
    if assumedCrashPenaltyVoided == 'yes' then
        table.insert(details, 'crash penalty voided')
    end
    if routeVariant ~= 'primary' then
        table.insert(details, ('route: %s'):format(routeVariant))
    end

    logLevelOne(("[checkpoint] player=%s source=%s race='%s' checkpoint=%s/%s lap=%s/%s details=%s"):format(
        tostring(playerName),
        tostring(playerSource),
        tostring(raceName),
        tostring(checkpointNumber),
        tostring(checkpointTotal),
        tostring(currentLap),
        tostring(lapTotal),
        (#details > 0 and table.concat(details, ', ') or 'clean pass')
    ))
end

local function hasAdminAccess(sourceId)
    local ace = tostring(((RacingSystem.Config or {}).adminAce) or "racingsystem.admin")
    if sourceId == 0 then
        return true
    end
    return IsPlayerAceAllowed(sourceId, ace)
end

local function auditLog(action, sourceId, details)
    local actor = resolvePlayerLogLabel(sourceId)
    local detailText = tostring(details or '')
    if detailText == '' then
        detailText = tostring(action or 'Performed a race action')
    end
    logLevelOne(("%s %s."):format(tostring(actor), detailText))
end

local function notifyPlayer(target, message, isError)
    local targetId = tonumber(target)
    local text = tostring(message or '')

    if targetId == nil or targetId <= 0 then
        return
    end

    TriggerClientEvent('racingsystem:ui:notify', targetId, {
        message = text,
        isError = isError == true,
    })
end

RacingSystem.Server.Logging.getExtraPrintLevel = getExtraPrintLevel
RacingSystem.Server.Logging.logError = logError
RacingSystem.Server.Logging.logLevelOne = logLevelOne
RacingSystem.Server.Logging.logVerbose = logVerbose
RacingSystem.Server.Logging.shouldLogCheckpointAnomaly = shouldLogCheckpointAnomaly
RacingSystem.Server.Logging.shouldLogLifecycleAnomaly = shouldLogLifecycleAnomaly
RacingSystem.Server.Logging.logLifecycleEvent = logLifecycleEvent
RacingSystem.Server.Logging.buildEntrantId = buildEntrantId
RacingSystem.Server.Logging.isLifecycleTransitionAllowed = isLifecycleTransitionAllowed
RacingSystem.Server.Logging.setRaceInstanceState = setRaceInstanceState
RacingSystem.Server.Logging.setRaceStateBag = setRaceStateBag
RacingSystem.Server.Logging.clearRaceStateBagByInstanceId = clearRaceStateBagByInstanceId
RacingSystem.Server.Logging.resolvePlayerLogLabel = resolvePlayerLogLabel
RacingSystem.Server.Logging.resolveReadablePlayerName = resolveReadablePlayerName
RacingSystem.Server.Logging.logCheckpointPassContext = logCheckpointPassContext
RacingSystem.Server.Logging.hasAdminAccess = hasAdminAccess
RacingSystem.Server.Logging.auditLog = auditLog
RacingSystem.Server.Logging.notifyPlayer = notifyPlayer


