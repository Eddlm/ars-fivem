RacingSystem = RacingSystem or {}
RacingSystem.Server = RacingSystem.Server or {}
RacingSystem.Server.State = RacingSystem.Server.State or {}

local advancedServerConfig = (((RacingSystem or {}).Config or {}).advanced or {}).server or {}

local function normalizeInt(value, minimum)
    local numeric = math.floor(tonumber(value) or 0)
    if minimum ~= nil and numeric < minimum then
        return minimum
    end
    if numeric < 0 then
        return 0
    end
    return numeric
end

local function normalizeString(value, fallback)
    local resolved = tostring(value or fallback or '')
    if resolved == '' then
        return tostring(fallback or '')
    end
    return resolved
end

local function normalizeTable(value, fallback)
    if type(value) == 'table' then
        return value
    end
    if type(fallback) == 'table' then
        return fallback
    end
    return {}
end

RacingSystem.Server.State.resourceName = normalizeString(RacingSystem.Server.State.resourceName, 'racingsystem')
RacingSystem.Server.State.indexFile = normalizeString(RacingSystem.Server.State.indexFile, 'race_index.json')
RacingSystem.Server.State.indexExamplesFile = normalizeString(RacingSystem.Server.State.indexExamplesFile, 'race_index_examples.json')
RacingSystem.Server.State.customRaceFolder = normalizeString(RacingSystem.Server.State.customRaceFolder, 'CustomRaces')
RacingSystem.Server.State.onlineRaceFolder = normalizeString(RacingSystem.Server.State.onlineRaceFolder, 'OnlineRaces')

RacingSystem.Server.State.advancedConfig = normalizeTable(RacingSystem.Server.State.advancedConfig, advancedServerConfig)
RacingSystem.Server.State.config = RacingSystem.Server.State.config or {}
RacingSystem.Server.State.config.ugcFetchRetryCooldownMs = math.max(
    0,
    normalizeInt(
        RacingSystem.Server.State.config.ugcFetchRetryCooldownMs ~= nil and RacingSystem.Server.State.config.ugcFetchRetryCooldownMs
            or tonumber(advancedServerConfig.ugcFetchRetryCooldownMs) or 700
    )
)
RacingSystem.Server.State.config.gtaoCheckpointRadiusScale = tonumber(
    RacingSystem.Server.State.config.gtaoCheckpointRadiusScale ~= nil and RacingSystem.Server.State.config.gtaoCheckpointRadiusScale
        or tonumber(advancedServerConfig.gtaoCheckpointRadiusScale) or 1.0
) or 1.0
RacingSystem.Server.State.config.pointToPointAutodetectDistanceMeters = tonumber(
    RacingSystem.Server.State.config.pointToPointAutodetectDistanceMeters ~= nil and RacingSystem.Server.State.config.pointToPointAutodetectDistanceMeters
        or tonumber(advancedServerConfig.pointToPointAutodetectDistanceMeters) or 500.0
) or 500.0
RacingSystem.Server.State.config.extraPrintLevel = math.max(
    0,
    math.min(
        2,
        normalizeInt(
            RacingSystem.Server.State.config.extraPrintLevel ~= nil and RacingSystem.Server.State.config.extraPrintLevel
                or tonumber(advancedServerConfig.extraPrintLevel) or 0
        )
    )
)
RacingSystem.Server.State.config.snapshotFullCycleTargetMs = math.max(
    250,
    normalizeInt(RacingSystem.Server.State.config.snapshotFullCycleTargetMs ~= nil and RacingSystem.Server.State.config.snapshotFullCycleTargetMs or 4000, 250)
)
RacingSystem.Server.State.config.snapshotMinTickMs = math.max(
    1,
    normalizeInt(RacingSystem.Server.State.config.snapshotMinTickMs ~= nil and RacingSystem.Server.State.config.snapshotMinTickMs or 50, 1)
)

RacingSystem.Server.State.raceInstancesById = normalizeTable(RacingSystem.Server.State.raceInstancesById)
RacingSystem.Server.State.raceInstanceIdsByName = normalizeTable(RacingSystem.Server.State.raceInstanceIdsByName)
RacingSystem.Server.State.knownRaceDefinitionsByName = normalizeTable(RacingSystem.Server.State.knownRaceDefinitionsByName)
RacingSystem.Server.State.immutableExampleLookupNames = normalizeTable(RacingSystem.Server.State.immutableExampleLookupNames)
RacingSystem.Server.State.checkpointAnomalyLogByKey = normalizeTable(RacingSystem.Server.State.checkpointAnomalyLogByKey)
RacingSystem.Server.State.lifecycleAnomalyLogByKey = normalizeTable(RacingSystem.Server.State.lifecycleAnomalyLogByKey)

RacingSystem.Server.State.nextRaceInstanceId = math.max(1, normalizeInt(RacingSystem.Server.State.nextRaceInstanceId ~= nil and RacingSystem.Server.State.nextRaceInstanceId or 1, 1))
RacingSystem.Server.State.nextEntrantIdToken = math.max(1, normalizeInt(RacingSystem.Server.State.nextEntrantIdToken ~= nil and RacingSystem.Server.State.nextEntrantIdToken or 1, 1))
RacingSystem.Server.State.nextSnapshotVersion = normalizeInt(RacingSystem.Server.State.nextSnapshotVersion ~= nil and RacingSystem.Server.State.nextSnapshotVersion or 0)
RacingSystem.Server.State.nextAllowedUGCFetchAt = normalizeInt(RacingSystem.Server.State.nextAllowedUGCFetchAt ~= nil and RacingSystem.Server.State.nextAllowedUGCFetchAt or 0)

RacingSystem.Server.State.reliabilityCounters = normalizeTable(RacingSystem.Server.State.reliabilityCounters)
RacingSystem.Server.State.reliabilityCounters.rejectedJoinRunning = math.max(0, normalizeInt(RacingSystem.Server.State.reliabilityCounters.rejectedJoinRunning))
RacingSystem.Server.State.reliabilityCounters.emptyInstanceAutoDestroyed = math.max(0, normalizeInt(RacingSystem.Server.State.reliabilityCounters.emptyInstanceAutoDestroyed))
RacingSystem.Server.State.reliabilityCounters.illegalLifecycleRequests = math.max(0, normalizeInt(RacingSystem.Server.State.reliabilityCounters.illegalLifecycleRequests))


