RacingSystem = RacingSystem or {}

RacingSystem.States = {
    idle = 'idle',
    staging = 'staging',
    running = 'running',
    finished = 'finished',
}

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

function RacingSystem.DecodeJson(rawValue, contextLabel)
    if type(rawValue) ~= 'string' or rawValue == '' then
        return nil, ('No %s content was provided.'):format(tostring(contextLabel or 'JSON'))
    end
    if type(json) ~= 'table' or type(json.decode) ~= 'function' then
        return nil, 'The JSON decoder is unavailable.'
    end

    local ok, decoded = pcall(json.decode, rawValue)
    if not ok then
        return nil, ('Invalid %s: %s'):format(tostring(contextLabel or 'JSON'), tostring(decoded or 'decode failed'))
    end
    if type(decoded) ~= 'table' then
        return nil, ('The %s root must be an object or array.'):format(tostring(contextLabel or 'JSON'))
    end
    return decoded, nil
end

function RacingSystem.EncodeJson(value, contextLabel)
    if type(json) ~= 'table' or type(json.encode) ~= 'function' then
        return nil, 'The JSON encoder is unavailable.'
    end

    local ok, encoded = pcall(json.encode, value)
    if not ok or type(encoded) ~= 'string' or encoded == '' then
        return nil, ('Could not encode %s: %s'):format(
            tostring(contextLabel or 'JSON'),
            tostring(ok and 'empty result' or encoded or 'encode failed')
        )
    end
    return encoded, nil
end
