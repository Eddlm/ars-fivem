RacingSystem = RacingSystem or {}

RacingSystem.States = {
    idle = 'idle',
    staging = 'staging',
    running = 'running',
    finished = 'finished',
}

-- Returns a lightweight race payload for network/UI usage while preserving core metadata and current entrants/checkpoints.
function RacingSystem.BuildRaceSnapshot(race)
    if type(race) ~= 'table' then
        return nil
    end

    return {
        id = race.id,
        name = race.name,
        owner = race.owner,
        state = race.state,
        createdAt = race.createdAt,
        checkpoints = race.checkpoints or {},
        entrants = race.entrants or {},
    }
end

-- Normalizes arbitrary input to a trimmed string so name/id validation can be done consistently across client/server.
function RacingSystem.Trim(value)
    return (tostring(value or ''):match('^%s*(.-)%s*$'))
end

-- Produces a canonical lowercase race-name key (or nil when empty) to support case-insensitive lookups and indexing.
function RacingSystem.NormalizeRaceName(name)
    local trimmed = RacingSystem.Trim(name)
    if trimmed == '' then
        return nil
    end

    return trimmed:lower()
end
