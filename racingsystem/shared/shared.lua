RacingSystem = RacingSystem or {}

RacingSystem.States = {
    idle = 'idle',
    staging = 'staging',
    running = 'running',
    finished = 'finished',
}

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

function RacingSystem.Trim(value)
    return (tostring(value or ''):match('^%s*(.-)%s*$'))
end

function RacingSystem.NormalizeRaceName(name)
    local trimmed = RacingSystem.Trim(name)
    if trimmed == '' then
        return nil
    end

    return trimmed:lower()
end
