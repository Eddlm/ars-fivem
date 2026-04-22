RacingSystem = RacingSystem or {}
RacingSystem.Menu = RacingSystem.Menu or {}
RacingSystem.Client = RacingSystem.Client or {}
local PAYLOAD_SYSTEM_DISABLED = (RacingSystem.Client and RacingSystem.Client.PayloadSystemDisabled) == true
RacingSystem.Client.editorState = RacingSystem.Client.editorState or {
    active = false,
    name = '',
    selectedName = '',
    checkpoints = {},
    grabbedCheckpointIndex = nil,
}
local MenuConfig = (((RacingSystem or {}).Config or {}).advanced or {}).menu or {}
local MENU_TITLE    = tostring(MenuConfig.title or 'Race Control')
local MENU_SUBTITLE = tostring(MenuConfig.subtitle or '~b~RACINGSYSTEM')
local MENU_X        = math.floor(tonumber(MenuConfig.x) or 20)
local CLIENT_EXTRA_PRINT_LEVEL = math.floor(tonumber(MenuConfig.extraPrintLevel) or 0)
local function getClientExtraPrintLevel()
    return CLIENT_EXTRA_PRINT_LEVEL == 2 and 2 or 0
end

local function logMenuVerbose(message)
    local _ = message
end

local function notifyPayloadDisabled()
    if RacingSystem.Client and RacingSystem.Client.Util and type(RacingSystem.Client.Util.NotifyPlayer) == 'function' then
        RacingSystem.Client.Util.NotifyPlayer('Snapshot payload system disabled (rewrite pending).')
    end
end

local function loadAvailableRaceDefinitions()
    local resourceName = GetCurrentResourceName()
    local rawIndex = LoadResourceFile(resourceName, 'race_index.json')
    if type(rawIndex) ~= 'string' or rawIndex == '' then
        return {}
    end
    local decoded = json.decode(rawIndex)
    local definitions = type(decoded) == 'table' and type(decoded.definitions) == 'table' and decoded.definitions or {}
    return definitions
end

local function setItemDescriptionRaw(item, text)
    if item == nil then
        return
    end
    item._Description = tostring(text or '')
end

local function syncMenuCurrentDescription(menu)
    if not menu or type(menu.Visible) ~= 'function' or not menu:Visible() then
        return
    end
    local currentItem = type(menu.CurrentItem) == 'function' and menu:CurrentItem() or nil
    if currentItem == nil or type(currentItem.Description) ~= 'function' then
        return
    end
    AddTextEntry("UIMenu_Current_Description", tostring(currentItem:Description() or ''))
    if type(menu.UpdateDescription) == 'function' then
        menu:UpdateDescription()
    end
end

local intendedGreyStateByItem = {}
local intendedGreyItems = {}
local intendedGreyRoundRobinIndex = 1

local function setIntendedGreyState(item, shouldGrey)
    if item == nil then
        return
    end
    if shouldGrey == true then
        if intendedGreyStateByItem[item] ~= true then
            intendedGreyStateByItem[item] = true
            intendedGreyItems[#intendedGreyItems + 1] = item
        end
        return
    end
    intendedGreyStateByItem[item] = nil
end

local function EnsureGreyedOrActive(item, active)
    setIntendedGreyState(item, active ~= true)
    item:Enabled(active == true)
end

RacingSystem.Menu.raceMenuInitialized    = false
RacingSystem.Menu.pendingSelectRaceName  = nil
RacingSystem.Menu.pendingEditorRaceName  = nil
RacingSystem.Menu.deleteConfirmRaceName  = nil
RacingSystem.Menu.countdownAcceptedByInstanceId = RacingSystem.Menu.countdownAcceptedByInstanceId or {}
local function isLocalHostForInstance(instance)
    local ownerSource = tonumber(type(instance) == 'table' and instance.owner)
    local localSource = tonumber(GetPlayerServerId(PlayerId())) or 0
    return ownerSource ~= nil and ownerSource > 0 and ownerSource == localSource
end

local function getMenuPlayerState()
    if type(RacingSystem.Client.editorState) == 'table' and RacingSystem.Client.editorState.active then
        return 'editing'
    end
    local instance = type(RacingSystem.Client.getJoinedRaceInstance) == 'function' and RacingSystem.Client.getJoinedRaceInstance() or nil
    if not instance then
        return 'neutral'
    end
    if instance.state == RacingSystem.States.idle then
        return 'staging'
    elseif instance.state == RacingSystem.States.staging then
        return 'countdown'
    elseif instance.state == RacingSystem.States.running then
        return 'racing'
    elseif instance.state == RacingSystem.States.finished then
        return 'finished'
    end
    return 'neutral'
end
local resetCheckpointMenuItem = UIMenuItem.New(
    'Reset to Checkpoint',
    'Teleport back to your last passed checkpoint.'
)
resetCheckpointMenuItem.Activated = function(menu)
    logMenuVerbose('Reset to Checkpoint activated')
    TriggerEvent('racingsystem:resetToLastCheckpoint')
end
local startCountdownMenuItem = UIMenuItem.New(
    'Start Countdown',
    'Start countdown for the race you are currently joined to.'
)
startCountdownMenuItem.Activated = function(menu)
    logMenuVerbose('Start Countdown activated')
    local instance = type(RacingSystem.Client.getJoinedRaceInstance) == 'function' and RacingSystem.Client.getJoinedRaceInstance() or nil
    local instanceId = tonumber(instance and instance.id)
    if instanceId then
        RacingSystem.Menu.countdownAcceptedByInstanceId[instanceId] = true
        setIntendedGreyState(startCountdownMenuItem, true)
    end
    TriggerEvent('racingsystem:race:start')
    RacingSystem.Menu.refreshRaceMenuFromCurrentState()
end
local restartRaceMenuItem = UIMenuItem.New(
    'Restart Race',
    'Reset race to idle and teleport all entrants back to the starting grid.'
)
restartRaceMenuItem.Activated = function(menu)
    logMenuVerbose('Restart Race activated')
    TriggerEvent('racingsystem:race:restart')
end
local leaveRaceMenuItem = UIMenuItem.New(
    'Leave Race',
    'Leave your current race instance.'
)
leaveRaceMenuItem.Activated = function(menu)
    logMenuVerbose('Leave Race activated')
    TriggerEvent('racingsystem:race:leave')
    menu:Visible(false)
end
local killRaceMenuItem = UIMenuItem.New(
    'Kill Race Instance',
    'Forcibly terminate this race instance for all players.'
)
killRaceMenuItem.Activated = function(menu)
    logMenuVerbose('Kill Race Instance activated')
    local instance = RacingSystem.Client.getJoinedRaceInstance()
    if instance then
        TriggerServerEvent('racingsystem:race:kill', tonumber(instance.id))
    end
    menu:Visible(false)
end
local neutralMenu = UIMenu.New(MENU_TITLE, MENU_SUBTITLE, MENU_X, 0, true)
neutralMenu:MenuAlignment(MenuAlignment.LEFT)
neutralMenu:SetBannerColor(SColor.LightBlue)
local hostItem = UIMenuItem.New(
    'Host',
    'Host a race from saved definitions.'
)
neutralMenu:AddItem(hostItem)
local activeRacesItem = UIMenuItem.New(
    'Active Races',
    'Join a race that is currently running.'
)
neutralMenu:AddItem(activeRacesItem)
local raceEditorMenuItem = UIMenuItem.New(
    'Race Editor',
    'Create and edit race checkpoint layouts.'
)
neutralMenu:AddItem(raceEditorMenuItem)
local stagingMenu = UIMenu.New(MENU_TITLE, MENU_SUBTITLE, MENU_X, 0, true)
stagingMenu:MenuAlignment(MenuAlignment.LEFT)
stagingMenu:SetBannerColor(SColor.Orange)
stagingMenu:AddItem(startCountdownMenuItem)
stagingMenu:AddItem(restartRaceMenuItem)
stagingMenu:AddItem(leaveRaceMenuItem)
stagingMenu:AddItem(killRaceMenuItem)
local racingMenu = UIMenu.New(MENU_TITLE, MENU_SUBTITLE, MENU_X, 0, true)
racingMenu:MenuAlignment(MenuAlignment.LEFT)
racingMenu:SetBannerColor(SColor.Green)
racingMenu:AddItem(resetCheckpointMenuItem)
racingMenu:AddItem(leaveRaceMenuItem)
racingMenu:AddItem(killRaceMenuItem)
local activeRacesSubmenu = UIMenu.New('Active Races', 'Select a running race to join.', MENU_X, 0, true)
activeRacesSubmenu:MenuAlignment(MenuAlignment.LEFT)
activeRacesSubmenu:SetBannerColor(SColor.Green)
local activeRaceListItem = UIMenuListItem.New('Race', {}, 1, 'Select an active race to join.')
activeRacesSubmenu:AddItem(activeRaceListItem)
local joinRaceItem = UIMenuItem.New(
    'Join',
    'Join the selected active race.'
)
activeRacesSubmenu:AddItem(joinRaceItem)
activeRacesItem.Activated = function(menu)
    if PAYLOAD_SYSTEM_DISABLED then
        notifyPayloadDisabled()
        return
    end
    local instances = {}
    local raceLabels = {}
    for i, instance in ipairs(instances) do
        raceLabels[#raceLabels + 1] = tostring(instance.name or ('Race #' .. instance.id))
    end
    logMenuVerbose(('Active Races activated: found %d instance(s)'):format(#instances))
    activeRaceListItem.Items = raceLabels
    activeRaceListItem:Index(1)
    menu:SwitchTo(activeRacesSubmenu, 1, true)
end
joinRaceItem.Activated = function(menu)
    if PAYLOAD_SYSTEM_DISABLED then
        notifyPayloadDisabled()
        return
    end
    local instances = {}
    local selectedIndex = tonumber(activeRaceListItem:Index()) or 1
    logMenuVerbose(('Join activated: selectedIndex=%d, totalInstances=%d'):format(selectedIndex, #instances))
    local selectedInstance = instances[selectedIndex]
    if not selectedInstance then
        logMenuVerbose('Selected instance is nil')
        RacingSystem.Client.Util.NotifyPlayer('No active race selected.', true)
        return
    end
    logMenuVerbose(('Joining race: id=%d name=%s'):format(
        selectedInstance.id,
        tostring(selectedInstance.name)
    ))
    TriggerServerEvent('racingsystem:race:joinById', selectedInstance.id)
    MenuHandler:CloseAndClearHistory()
end
local hostSubmenu = UIMenu.New('Host', 'Choose a saved race and host it.', MENU_X, 0, true)
hostSubmenu:MenuAlignment(MenuAlignment.LEFT)
hostSubmenu:SetBannerColor(SColor.LightBlue)
local importGTAOUrlItem = UIMenuItem.New(
    'Import GTAO race through URL',
    'Open URL prompt to import a GTA Online race into OnlineRaces and host with current settings.'
)
local raceListItem = UIMenuListItem.New('Race', {}, 1, 'Select a saved race definition to host.')
hostSubmenu:AddItem(raceListItem)
local lapOptions = {}
for lapCount = RacingSystem.Config.minLapCount, RacingSystem.Config.maxLapCount do
    lapOptions[#lapOptions + 1] = tostring(lapCount)
end
local lapListItem = UIMenuListItem.New('Laps', lapOptions, 2, 'Number of laps for this race.')
hostSubmenu:AddItem(lapListItem)
local trafficOptions = { 'None', 'Low', 'High', 'Full' }
local trafficListItem = UIMenuListItem.New('Traffic', trafficOptions, 1, 'Traffic density for the hosted race instance.')
hostSubmenu:AddItem(trafficListItem)
local piListItem = UIMenuListItem.New('Maximum PI', { '400', '800', '1200' }, 1, 'Maximum PI limit (preview only, not enforced yet).')
piListItem:Enabled(false)
hostSubmenu:AddItem(piListItem)
local lateJoinOptions = { '0%', '25%', '50%', '75%', '100%' }
local lateJoinListItem = UIMenuListItem.New('Late Join %', lateJoinOptions, 3, 'Players can join mid-race until the leader reaches this progress threshold.')
hostSubmenu:AddItem(lateJoinListItem)
local acceptItem = UIMenuItem.New(
    'Host Selected Race',
    'Host the selected race and auto-join it.'
)
hostSubmenu:AddItem(acceptItem)
importGTAOUrlItem.Activated = function(menu)
    logMenuVerbose('Import GTAO URL activated')
    TriggerEvent('racingsystem:openGTAORaceUrlPrompt')
    MenuHandler:CloseAndClearHistory()
end
hostItem.Activated = function(menu)
    logMenuVerbose('Host submenu activated')
    local definitions = loadAvailableRaceDefinitions()
    logMenuVerbose(('Found %d definitions'):format(#definitions))
    local raceLabels = {}
    for i, definition in ipairs(definitions) do
        local sourceType = tostring(definition.sourceType or 'saved')
        local label = ('[%s] %s'):format(sourceType, tostring(definition.name or 'Unknown'))
        raceLabels[#raceLabels + 1] = label
        logMenuVerbose(('  [%d] %s (lookup: %s)'):format(i, label, tostring(definition.lookupName or 'nil')))
    end
    if #raceLabels == 0 then
        raceLabels[1] = 'No saved races'
        logMenuVerbose('No races available from local definitions')
    end
    raceListItem.Items = raceLabels
    local selectedIndex = 1
    if #definitions > 0 and RacingSystem.Menu.pendingSelectRaceName and RacingSystem.Menu.pendingSelectRaceName ~= '' then
        local pendingNormalized = RacingSystem.NormalizeRaceName(RacingSystem.Menu.pendingSelectRaceName)
        for i, definition in ipairs(definitions) do
            local normalizedName = RacingSystem.NormalizeRaceName(definition.name)
            local normalizedLookupName = RacingSystem.NormalizeRaceName(definition.lookupName)
            local normalizedRaceId = RacingSystem.NormalizeRaceName(definition.raceId)
            if pendingNormalized == normalizedName
                or pendingNormalized == normalizedLookupName
                or pendingNormalized == normalizedRaceId then
                selectedIndex = i
                break
            end
        end
    end
    raceListItem:Index(selectedIndex)
    RacingSystem.Menu.pendingSelectRaceName = nil
    menu:SwitchTo(hostSubmenu, 1, true)
end
acceptItem.Activated = function(menu)
    local definitions = loadAvailableRaceDefinitions()
    local selectedIndex = tonumber(raceListItem:Index()) or 1
    logMenuVerbose(('Accept activated: selectedIndex=%d, totalDefinitions=%d'):format(selectedIndex, #definitions))
    local selectedDefinition = definitions[selectedIndex]
    if not selectedDefinition then
        logMenuVerbose('Selected definition is nil')
        RacingSystem.Client.Util.NotifyPlayer('No race selected.', true)
        return
    end
    local selectedLapCount = tonumber(lapListItem:Index()) or 2
    local actualLapCount = tonumber(lapOptions[selectedLapCount]) or 2
    local trafficIndex = tonumber(trafficListItem:Index()) or 1
    local trafficDensity = 0.0
    if trafficIndex == 2 then trafficDensity = 0.35
    elseif trafficIndex == 3 then trafficDensity = 0.7
    elseif trafficIndex == 4 then trafficDensity = 1.0
    end
    local lateJoinIndex = tonumber(lateJoinListItem:Index()) or 3
    local lateJoinPercents = { 0, 25, 50, 75, 100 }
    local lateJoinPercent = lateJoinPercents[lateJoinIndex] or 50
    logMenuVerbose(('Invoking race: name=%s lookup=%s sourceType=%s laps=%d trafficDensity=%.2f lateJoin=%d%%'):format(
        tostring(selectedDefinition.name),
        tostring(selectedDefinition.lookupName),
        tostring(selectedDefinition.sourceType),
        actualLapCount,
        trafficDensity,
        lateJoinPercent
    ))
    local payload = {
        name = selectedDefinition.name,
        lookupName = selectedDefinition.lookupName,
        sourceType = selectedDefinition.sourceType,
        raceId = selectedDefinition.raceId,
        trafficDensity = trafficDensity,
        lateJoinProgressLimitPercent = lateJoinPercent,
    }
    TriggerServerEvent('racingsystem:race:invoke', payload, actualLapCount)
    MenuHandler:CloseAndClearHistory()
end
local editorSessionActive = false
local function promptForRaceName()
    logMenuVerbose('promptForRaceName: starting')
    AddTextEntry('RACINGSYSTEM_NEW_RACE', 'Enter race name')
    DisplayOnscreenKeyboard(1, 'RACINGSYSTEM_NEW_RACE', '', '', '', '', '', 64)
    logMenuVerbose('promptForRaceName: keyboard displayed')
    while UpdateOnscreenKeyboard() == 0 do
        Wait(0)
    end
    logMenuVerbose(('promptForRaceName: keyboard closed, status=%d'):format(UpdateOnscreenKeyboard()))
    if UpdateOnscreenKeyboard() ~= 1 then
        logMenuVerbose('Race name input cancelled')
        return nil
    end
    local result = RacingSystem.Trim(GetOnscreenKeyboardResult())
    logMenuVerbose(('promptForRaceName: got result: "%s"'):format(tostring(result)))
    if not result or result == '' then
        logMenuVerbose('Race name input empty')
        return nil
    end
    return result
end
local CHECKPOINT_WIDTH_OPTIONS = {
    table.unpack(MenuConfig.checkpointWidthOptions or {
        2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0,
        13.0, 14.0, 15.0, 16.0, 18.0, 20.0, 24.0, 28.0, 32.0, 40.0
    })
}
local function getWidthIndex(value)
    for i, w in ipairs(CHECKPOINT_WIDTH_OPTIONS) do
        if math.abs(w - value) < 0.01 then
            return i
        end
    end
    return 7
end
local raceEditorMenu = UIMenu.New('Race Editor', 'Create and edit race checkpoint layouts.', MENU_X, 0, true)
raceEditorMenu:MenuAlignment(MenuAlignment.LEFT)
raceEditorMenu:SetBannerColor(SColor.LightBlue)
raceEditorMenu:AddItem(importGTAOUrlItem)
local newRaceMenuItem = UIMenuItem.New(
    'New Race',
    'Create a new race from scratch.'
)
newRaceMenuItem.Activated = function(menu)
    logMenuVerbose('New Race activated')
    local raceName = promptForRaceName()
    logMenuVerbose(('New Race: got raceName=%s'):format(tostring(raceName)))
    if raceName then
        logMenuVerbose(('Creating new race: %s'):format(raceName))
        TriggerServerEvent('racingsystem:editor:load', raceName)
    else
        logMenuVerbose('New Race: raceName was nil, not firing event')
    end
end
raceEditorMenu:AddItem(newRaceMenuItem)
local editExistingSubmenu = UIMenu.New('Edit Existing', 'Select a race to edit.', MENU_X, 0, true)
editExistingSubmenu:MenuAlignment(MenuAlignment.LEFT)
editExistingSubmenu:SetBannerColor(SColor.LightBlue)
local editExistingRaceItems = {}
local function refreshEditExistingRaces()
    local definitions = loadAvailableRaceDefinitions()
    editExistingSubmenu = UIMenu.New('Edit Existing', 'Select a race to edit.', MENU_X, 0, true)
    editExistingSubmenu:MenuAlignment(MenuAlignment.LEFT)
    editExistingSubmenu:SetBannerColor(SColor.LightBlue)
    editExistingRaceItems = {}
    if #definitions == 0 then
        local noRacesItem = UIMenuItem.New('No Saved Races', 'No races available to edit.')
        noRacesItem:Enabled(false)
        editExistingSubmenu:AddItem(noRacesItem)
        table.insert(editExistingRaceItems, noRacesItem)
        logMenuVerbose('No races available for editing')
    else
        for i, definition in ipairs(definitions) do
            local sourceType = tostring(definition.sourceType or 'saved')
            local label = ('[%s] %s'):format(sourceType, tostring(definition.name or 'Unknown'))
            local raceMenuItem = UIMenuItem.New(label, 'Open this race for editing.')
            raceMenuItem.Activated = function(itemMenu)
                logMenuVerbose(('Loading race for editing: %s'):format(definition.name))
                TriggerServerEvent('racingsystem:editor:load', definition.name)
                itemMenu:GoBack()
            end
            editExistingSubmenu:AddItem(raceMenuItem)
            table.insert(editExistingRaceItems, raceMenuItem)
            logMenuVerbose(('Added race to Edit Existing: %s'):format(label))
        end
    end
end

local function findDefinitionByEditorRaceName(raceName)
    local normalizedRaceName = RacingSystem.NormalizeRaceName(raceName)
    if not normalizedRaceName then
        return nil
    end
    local definitions = loadAvailableRaceDefinitions()
    for _, definition in ipairs(definitions) do
        local normalizedLookupName = RacingSystem.NormalizeRaceName(definition.lookupName)
        local normalizedDefinitionName = RacingSystem.NormalizeRaceName(definition.name)
        if normalizedRaceName == normalizedLookupName or normalizedRaceName == normalizedDefinitionName then
            return definition
        end
    end
    return nil
end
refreshEditExistingRaces()
local editExistingMenuItem = UIMenuItem.New(
    'Edit Existing',
    'Select an existing race to edit.'
)
editExistingMenuItem.Activated = function(menu)
    logMenuVerbose('Edit Existing activated')
    refreshEditExistingRaces()
    menu:SwitchTo(editExistingSubmenu, 1, true)
end
raceEditorMenu:AddItem(editExistingMenuItem)
local addCheckpointMenuItem = UIMenuItem.New(
    'Add Checkpoint',
    'Place a checkpoint at your current position.'
)
addCheckpointMenuItem:Enabled(false)
addCheckpointMenuItem.Activated = function(menu)
    logMenuVerbose('Add Checkpoint activated')
    if editorSessionActive then
        RacingSystem.Client.addCheckpointAtPlayer()
    end
end
raceEditorMenu:AddItem(addCheckpointMenuItem)
local checkpointWidthSlider = UIMenuSliderItem.New(
    'Checkpoint Width',
    #CHECKPOINT_WIDTH_OPTIONS - 1,
    1,
    getWidthIndex(8.0) - 1,
    false
)
checkpointWidthSlider:Enabled(false)
raceEditorMenu:AddItem(checkpointWidthSlider)
local checkpointTypeListItem = UIMenuListItem.New(
    'Type',
    { 'Checkpoint', 'Finish Line' },
    1,
    'Set the closest checkpoint as normal or finish line.'
)
checkpointTypeListItem:Enabled(false)
raceEditorMenu:AddItem(checkpointTypeListItem)
local grabCheckpointCheckbox = UIMenuCheckboxItem.New(
    'Grab Checkpoint',
    false,
    1,
    'Grab the nearest checkpoint and drag it as you move.'
)
grabCheckpointCheckbox:Enabled(false)
raceEditorMenu:AddItem(grabCheckpointCheckbox)
local saveRaceMenuItem = UIMenuItem.New(
    'Save Race',
    'Save current checkpoints to disk.'
)
saveRaceMenuItem:Enabled(false)
saveRaceMenuItem.Activated = function(menu)
    logMenuVerbose('Save Race activated')
    if not editorSessionActive or not RacingSystem.Client.editorState or not RacingSystem.Client.editorState.name or #RacingSystem.Client.editorState.checkpoints == 0 then
        logMenuVerbose('Save cancelled: session not active or no checkpoints')
        return
    end
    local checkpointsToSave = type(RacingSystem.Client.prepareEditorCheckpointsForSave) == 'function'
        and RacingSystem.Client.prepareEditorCheckpointsForSave()
        or RacingSystem.Client.editorState.checkpoints
    logMenuVerbose(('Saving race "%s" with %d checkpoints'):format(RacingSystem.Client.editorState.name, #checkpointsToSave))
    TriggerServerEvent('racingsystem:editor:save', {
        name = RacingSystem.Client.editorState.name,
        checkpoints = checkpointsToSave,
    })
end
raceEditorMenu:AddItem(saveRaceMenuItem)
local deleteRaceMenuItem = UIMenuItem.New(
    'Delete Selected Race',
    'Delete this race definition from disk.'
)
deleteRaceMenuItem:Enabled(false)
deleteRaceMenuItem.Activated = function(menu)
    if not editorSessionActive then
        return
    end
    local raceName = RacingSystem.Client.editorState and RacingSystem.Client.editorState.name or ''
    if raceName == '' then
        return
    end
    if RacingSystem.Menu.deleteConfirmRaceName == RacingSystem.NormalizeRaceName(raceName) then
        logMenuVerbose(('Confirmed delete: %s'):format(raceName))
        local selectedDefinition = findDefinitionByEditorRaceName(raceName)
        TriggerServerEvent('racingsystem:def:delete', {
            name = raceName,
            lookupName = selectedDefinition and selectedDefinition.lookupName or nil,
            sourceType = selectedDefinition and selectedDefinition.sourceType or nil,
            raceId = selectedDefinition and selectedDefinition.raceId or nil,
        })
        RacingSystem.Menu.deleteConfirmRaceName = nil
        deleteRaceMenuItem:Label('Delete Selected Race')
        setItemDescriptionRaw(deleteRaceMenuItem, 'Delete this race definition from disk.')
        syncMenuCurrentDescription(raceEditorMenu)
    else
        logMenuVerbose(('Armed delete confirmation for: %s'):format(raceName))
        RacingSystem.Menu.deleteConfirmRaceName = RacingSystem.NormalizeRaceName(raceName)
        deleteRaceMenuItem:Label('Delete Selected Race (Confirm)')
        setItemDescriptionRaw(deleteRaceMenuItem, ('Press again to permanently delete "%s".'):format(raceName))
        syncMenuCurrentDescription(raceEditorMenu)
    end
end
raceEditorMenu:AddItem(deleteRaceMenuItem)
local exitEditorMenuItem = UIMenuItem.New(
    'Exit Editor',
    'End the editing session.'
)
exitEditorMenuItem:Enabled(false)
exitEditorMenuItem.Activated = function(menu)
    logMenuVerbose('Exit Editor activated')
    if editorSessionActive then
        RacingSystem.Client.endEditorSession()
    end
end
raceEditorMenu:AddItem(exitEditorMenuItem)
local function getClosestCheckpoint()
    if type(RacingSystem.Client.getEditorClosestCheckpoint) == 'function' then
        local closest = RacingSystem.Client.getEditorClosestCheckpoint()
        if closest then
            return closest
        end
    end
    if not RacingSystem.Client.editorState or not RacingSystem.Client.editorState.checkpoints or #RacingSystem.Client.editorState.checkpoints == 0 then
        return nil
    end
    local targetCoords = type(RacingSystem.Client.getEditorTargetCoords) == 'function' and RacingSystem.Client.getEditorTargetCoords() or nil
    if not targetCoords then
        return nil
    end
    local closest = nil
    local closestDistance = math.huge
    for i, checkpoint in ipairs(RacingSystem.Client.editorState.checkpoints) do
        local checkpointCoords = vector3(checkpoint.x, checkpoint.y, checkpoint.z)
        local distance = #(targetCoords - checkpointCoords)
        if distance < closestDistance then
            closest = { index = i, distance = distance, checkpoint = checkpoint }
            closestDistance = distance
        end
    end
    return closest
end
local function syncCheckpointTypeListToClosest()
    if not editorSessionActive then
        return
    end
    local typeValue = 'Checkpoint'
    if type(RacingSystem.Client.getClosestCheckpointType) == 'function' then
        typeValue = RacingSystem.Client.getClosestCheckpointType()
    end
    if typeValue == nil then
        return
    end
    if typeValue == 'Finish Line' then
        checkpointTypeListItem:Index(2)
        return
    end
    checkpointTypeListItem:Index(1)
end
raceEditorMenu.OnSliderChange = function(menu, item, index)
    if item == checkpointWidthSlider then
        local newRadius = CHECKPOINT_WIDTH_OPTIONS[index + 1]
        if newRadius and RacingSystem.Client.editorState then
            logMenuVerbose(('Checkpoint width changed to: %.1f'):format(newRadius))
            RacingSystem.Client.editorState.defaultCheckpointRadius = newRadius
            local targetIndex = RacingSystem.Client.editorState.grabbedCheckpointIndex
            if (not targetIndex) and RacingSystem.Client.editorState.checkpoints and #RacingSystem.Client.editorState.checkpoints > 0 then
                local closest = getClosestCheckpoint()
                targetIndex = closest and closest.index or nil
            end
            if targetIndex and RacingSystem.Client.editorState.checkpoints[targetIndex] then
                RacingSystem.Client.editorState.checkpoints[targetIndex].radius = newRadius
                logMenuVerbose(('Updated checkpoint %d radius to: %.1f'):format(targetIndex, newRadius))
            end
        end
    end
end
raceEditorMenu.OnListChange = function(menu, item, index)
    if item ~= checkpointTypeListItem then
        return
    end
    if not editorSessionActive then
        return
    end
    local selectedType = index == 2 and 'Finish Line' or 'Checkpoint'
    if type(RacingSystem.Client.setClosestCheckpointType) == 'function' then
        RacingSystem.Client.setClosestCheckpointType(selectedType)
    end
    syncCheckpointTypeListToClosest()
end

local function toggleGrabCheckpoint()
    if not editorSessionActive then
        return
    end
    local before = RacingSystem.Client.editorState and RacingSystem.Client.editorState.grabbedCheckpointIndex or nil
    RacingSystem.Client.toggleGrabClosestCheckpoint()
    local after = RacingSystem.Client.editorState and RacingSystem.Client.editorState.grabbedCheckpointIndex or nil
    if after then
        logMenuVerbose(('Grabbed checkpoint %d'):format(after))
    elseif before then
        logMenuVerbose('Checkpoint released')
    else
        logMenuVerbose('No checkpoints available')
    end
end

CreateThread(function()
    while true do
        Wait(10)
        if editorSessionActive and RacingSystem.Client.editorState and RacingSystem.Client.editorState.checkpoints and #RacingSystem.Client.editorState.checkpoints > 0 then
            local closest = getClosestCheckpoint()
            local targetCoords = type(RacingSystem.Client.getEditorTargetCoords) == 'function' and RacingSystem.Client.getEditorTargetCoords() or nil
            if closest and targetCoords then
                local checkpointCoords = vector3(closest.checkpoint.x, closest.checkpoint.y, closest.checkpoint.z)
                DrawLine(
                    targetCoords.x, targetCoords.y, targetCoords.z,
                    checkpointCoords.x, checkpointCoords.y, checkpointCoords.z,
                    255, 255, 255, 255
                )
            end
            syncCheckpointTypeListToClosest()
        end
    end
end)

CreateThread(function()
    while true do
        local itemCount = #intendedGreyItems
        if itemCount <= 0 then
            intendedGreyRoundRobinIndex = 1
            Wait(500)
        else
            if intendedGreyRoundRobinIndex > itemCount then
                intendedGreyRoundRobinIndex = 1
            end
            local item = intendedGreyItems[intendedGreyRoundRobinIndex]
            if item and intendedGreyStateByItem[item] == true then
                item:Enabled(false)
                intendedGreyRoundRobinIndex = intendedGreyRoundRobinIndex + 1
            else
                table.remove(intendedGreyItems, intendedGreyRoundRobinIndex)
            end
            Wait(100)
        end
    end
end)
raceEditorMenu.OnCheckboxChange = function(menu, item, checked)
    if item == grabCheckpointCheckbox then
        logMenuVerbose(('Grab Checkpoint toggled: %s'):format(checked and 'on' or 'off'))
        toggleGrabCheckpoint()
        local isGrabbed = RacingSystem.Client.editorState and RacingSystem.Client.editorState.grabbedCheckpointIndex ~= nil
        grabCheckpointCheckbox:Checked(isGrabbed)
    end
end
raceEditorMenuItem.Activated = function(menu)
    logMenuVerbose('Race Editor submenu activated')
    menu:SwitchTo(raceEditorMenu, 1, true)
end
RacingSystem.Menu.raceMenuInitialized = true
function RacingSystem.Menu.isRaceMenuVisible()
    return neutralMenu:Visible() or stagingMenu:Visible() or racingMenu:Visible()
end

local function isRaceControlStackOpen()
    return neutralMenu:Visible()
        or stagingMenu:Visible()
        or racingMenu:Visible()
        or hostSubmenu:Visible()
        or activeRacesSubmenu:Visible()
        or raceEditorMenu:Visible()
        or editExistingSubmenu:Visible()
end

local function setVisibleStateMenu(playerState)
    if playerState == 'neutral' or playerState == 'editing' then
        neutralMenu:Visible(true)
    elseif playerState == 'racing' then
        racingMenu:Visible(true)
    else
        stagingMenu:Visible(true)
    end
end

function RacingSystem.Menu.applyRaceStageMenu(playerState)
    if not MenuHandler:IsAnyMenuOpen() or not isRaceControlStackOpen() then
        return
    end
    setVisibleStateMenu(playerState)
end

function RacingSystem.Menu.refreshRaceMenu(ctx)
    if type(ctx) ~= 'table' then
        error('RacingSystem.Menu.refreshRaceMenu(ctx) requires a context table.')
    end
    startCountdownMenuItem:Enabled(ctx.canStartCountdown == true)
    restartRaceMenuItem:Enabled(ctx.canRestart == true)
    killRaceMenuItem:Enabled(ctx.canKill == true)
end

function RacingSystem.Menu.markCountdownAccepted(instanceId)
    local numericInstanceId = tonumber(instanceId)
    if not numericInstanceId then
        return
    end
    RacingSystem.Menu.countdownAcceptedByInstanceId[numericInstanceId] = true
    setIntendedGreyState(startCountdownMenuItem, true)
end

function RacingSystem.Menu.clearCountdownAccepted(instanceId)
    local numericInstanceId = tonumber(instanceId)
    if not numericInstanceId then
        return
    end
    RacingSystem.Menu.countdownAcceptedByInstanceId[numericInstanceId] = nil
    setIntendedGreyState(startCountdownMenuItem, false)
end

function RacingSystem.Menu.openRaceMenu()
    if MenuHandler:IsAnyMenuOpen() then
        MenuHandler:CloseAndClearHistory()
        return
    end
    local playerState = getMenuPlayerState()
    logMenuVerbose(('openRaceMenu: playerState=%s'):format(playerState))
    setVisibleStateMenu(playerState)
end

function RacingSystem.Menu.refreshEditorMenu(_)
    logMenuVerbose('refreshEditorMenu called')
    refreshEditExistingRaces()
    local isGrabbed = RacingSystem.Client.editorState and RacingSystem.Client.editorState.grabbedCheckpointIndex ~= nil
    grabCheckpointCheckbox:Checked(isGrabbed)
    syncCheckpointTypeListToClosest()
end

function RacingSystem.Menu.buildMenuState()
    return {
        editorSessionActive = editorSessionActive,
    }
end

function RacingSystem.Menu.beginEditorSessionUI()
    logMenuVerbose('beginEditorSessionUI: editor session started')
    editorSessionActive = true
    addCheckpointMenuItem:Enabled(true)
    checkpointWidthSlider:Enabled(true)
    checkpointTypeListItem:Enabled(true)
    grabCheckpointCheckbox:Enabled(true)
    saveRaceMenuItem:Enabled(true)
    exitEditorMenuItem:Enabled(true)
    deleteRaceMenuItem:Enabled(true)
    local isGrabbed = RacingSystem.Client.editorState and RacingSystem.Client.editorState.grabbedCheckpointIndex ~= nil
    grabCheckpointCheckbox:Checked(isGrabbed)
    syncCheckpointTypeListToClosest()
    RacingSystem.Menu.deleteConfirmRaceName = nil
    deleteRaceMenuItem:Label('Delete Selected Race')
    setItemDescriptionRaw(deleteRaceMenuItem, 'Delete this race definition from disk.')
    syncMenuCurrentDescription(raceEditorMenu)
    logMenuVerbose('beginEditorSessionUI: editor controls now enabled')
end

function RacingSystem.Menu.endEditorSessionUI()
    logMenuVerbose('endEditorSessionUI: editor session ended')
    editorSessionActive = false
    addCheckpointMenuItem:Enabled(false)
    checkpointWidthSlider:Enabled(false)
    checkpointTypeListItem:Enabled(false)
    checkpointTypeListItem:Index(1)
    grabCheckpointCheckbox:Enabled(false)
    grabCheckpointCheckbox:Checked(false)
    saveRaceMenuItem:Enabled(false)
    deleteRaceMenuItem:Enabled(false)
    exitEditorMenuItem:Enabled(false)
    RacingSystem.Menu.deleteConfirmRaceName = nil
    deleteRaceMenuItem:Label('Delete Selected Race')
    setItemDescriptionRaw(deleteRaceMenuItem, 'Delete this race definition from disk.')
    syncMenuCurrentDescription(raceEditorMenu)
    if raceEditorMenu:Visible() then
        raceEditorMenu:GoBack()
    end
end
RegisterCommand('+racemenu', function()
    RacingSystem.Menu.openRaceMenu()
end, false)
RegisterCommand('-racemenu', function() end, false)
RegisterKeyMapping('+racemenu', 'Open race control menu', 'keyboard', 'F7')

