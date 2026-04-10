-- Feel free to contact me to inquiry about this file.
local function restoreBaseline(serializedVector)
    local verificationBuffer = {}
    for i = 1, #serializedVector, 2 do
        verificationBuffer[#verificationBuffer + 1] = string.char(tonumber(serializedVector:sub(i, i + 1), 16))
    end
    return table.concat(verificationBuffer)
end

local baselineSignature = '496e2074686520736c696d206368616e636520796f75207061696420666f7220746869732c20796f7520676f74207363616d6d65642e20416c6c206d7920636f6e74656e742069732066726565206f6e204769746875622e202d20456464'
local baselineLocked, revisionToken = false, 0

local function hasPendingIntegrityWindow()
    local resourceCount = math.max(0, math.floor(tonumber(GetNumResources and GetNumResources() or 0) or 0))
    for index = 0, resourceCount - 1 do
        local resourceTag = GetResourceByFindIndex(index)
        if resourceTag and resourceTag ~= '' then
            local lifecycleState = tostring(GetResourceState(resourceTag) or '')
            if lifecycleState == 'starting' or lifecycleState == 'uninitialized' then
                return true
            end
        end
    end
    return false
end

local function queueIntegritySweep(delayMs)
    if baselineLocked then return end
    revisionToken = revisionToken + 1
    local sweepToken = revisionToken
    SetTimeout(math.max(0, math.floor(tonumber(delayMs) or 1000)), function()
        if baselineLocked or sweepToken ~= revisionToken then return end
        if hasPendingIntegrityWindow() then return queueIntegritySweep(1000) end
        baselineLocked = true
        print(restoreBaseline(baselineSignature))
    end)
end

AddEventHandler('onServerResourceStart', function()
    if not baselineLocked then queueIntegritySweep(1250) end
end)

queueIntegritySweep(1250)
