-- Race Control menu — ScaleformUI implementation
-- Static per-state menu architecture
-- No dynamic item mutation, no runtime adding/removing items

RacingSystem = RacingSystem or {}
RacingSystem.Menu = RacingSystem.Menu or {}
RacingSystem.Client = RacingSystem.Client or {}

RacingSystem.Client.latestSnapshot = RacingSystem.Client.latestSnapshot or {
    definitions = {},
    instances = {},
    viewer = {},
}
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

-- ─── Debug logging ────────────────────────────────────────────────────────────

local function getClientExtraPrintLevel()
    return CLIENT_EXTRA_PRINT_LEVEL == 2 and 2 or 0
end

local function logMenuVerbose(message)
    local _ = message
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

-- ─── RacingSystem.Menu state (read by client.lua) ────────────────────────────────────────

RacingSystem.Menu.raceMenuInitialized    = false
RacingSystem.Menu.pendingSelectRaceName  = nil
RacingSystem.Menu.pendingEditorRaceName  = nil
RacingSystem.Menu.deleteConfirmRaceName  = nil

-- ─── Helper: determine player's current race state ─────────────────────────────

local function getMenuPlayerState()
    -- Returns: 'neutral', 'staging', 'countdown', 'racing', 'finished', or 'editing'
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

-- ─── Shared RacingSystem.Menu Items ────────────────────────────────────────────────────────────

-- Reset to Checkpoint
local resetCheckpointMenuItem = UIMenuItem.New(
    'Reset to Checkpoint',
    'Teleport back to your last passed checkpoint.'
)
resetCheckpointMenuItem.Activated = function(menu)
    logMenuVerbose('Reset to Checkpoint activated')
    TriggerEvent('racingsystem:resetToLastCheckpoint')
end

-- Start Countdown
local startCountdownMenuItem = UIMenuItem.New(
    'Start Countdown',
    'Start countdown for the race you are currently joined to.'
)
startCountdownMenuItem.Activated = function(menu)
    logMenuVerbose('Start Countdown activated')
    TriggerEvent('racingsystem:startRace')
end

-- Leave Race
local leaveRaceMenuItem = UIMenuItem.New(
    'Leave Race',
    'Leave your current race instance.'
)
leaveRaceMenuItem.Activated = function(menu)
    logMenuVerbose('Leave Race activated')
    TriggerEvent('racingsystem:leaveRace')
    menu:Visible(false)
end

-- Kill Race Instance
local killRaceMenuItem = UIMenuItem.New(
    'Kill Race Instance',
    'Forcibly terminate this race instance for all players.'
)
killRaceMenuItem.Activated = function(menu)
    logMenuVerbose('Kill Race Instance activated')
    local instance = RacingSystem.Client.getJoinedRaceInstance()
    if instance then
        TriggerServerEvent('racingsystem:killRace', instance.name)
    end
    menu:Visible(false)
end

-- ─── 1. NEUTRAL MENU ────────────────────────────────────────────────────────────
-- State: Not in any race

local neutralMenu = UIMenu.New(MENU_TITLE, MENU_SUBTITLE, MENU_X, 0, true)
neutralMenu:MenuAlignment(MenuAlignment.LEFT)
neutralMenu:SetBannerColor(SColor.LightBlue)

-- Host submenu
local hostItem = UIMenuItem.New(
    'Host',
    'Host a race from saved definitions.'
)
neutralMenu:AddItem(hostItem)

-- Active Races
local activeRacesItem = UIMenuItem.New(
    'Active Races',
    'Join a race that is currently running.'
)
neutralMenu:AddItem(activeRacesItem)

-- Race Editor
local raceEditorMenuItem = UIMenuItem.New(
    'Race Editor',
    'Create and edit race checkpoint layouts.'
)
neutralMenu:AddItem(raceEditorMenuItem)

-- ─── 2. STAGING MENU ────────────────────────────────────────────────────────────
-- State: Staging, Countdown, Finished

local stagingMenu = UIMenu.New(MENU_TITLE, MENU_SUBTITLE, MENU_X, 0, true)
stagingMenu:MenuAlignment(MenuAlignment.LEFT)
stagingMenu:SetBannerColor(SColor.Orange)

-- Start Countdown (will be enabled dynamically only for host)
stagingMenu:AddItem(startCountdownMenuItem)

-- Leave Race
stagingMenu:AddItem(leaveRaceMenuItem)

-- Kill Race Instance (enabled dynamically for owner/admin only)
stagingMenu:AddItem(killRaceMenuItem)

-- ─── 3. RACING MENU ────────────────────────────────────────────────────────────
-- State: Actively racing

local racingMenu = UIMenu.New(MENU_TITLE, MENU_SUBTITLE, MENU_X, 0, true)
racingMenu:MenuAlignment(MenuAlignment.LEFT)
racingMenu:SetBannerColor(SColor.Green)

-- Reset to Checkpoint
racingMenu:AddItem(resetCheckpointMenuItem)

-- Leave Race
racingMenu:AddItem(leaveRaceMenuItem)

-- Kill Race Instance (enabled dynamically for owner/admin only)
racingMenu:AddItem(killRaceMenuItem)

-- ─── Host submenu ────────────────────────────────────────────────────────────

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
    local instances = type(RacingSystem.Client.latestSnapshot) == 'table' and type(RacingSystem.Client.latestSnapshot.instances) == 'table'
        and RacingSystem.Client.latestSnapshot.instances or {}

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
    local instances = type(RacingSystem.Client.latestSnapshot) == 'table' and type(RacingSystem.Client.latestSnapshot.instances) == 'table'
        and RacingSystem.Client.latestSnapshot.instances or {}
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

    TriggerServerEvent('racingsystem:joinRaceInstanceById', selectedInstance.id)
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

-- Build lap count options (config: minLapCount=1, maxLapCount=10)
local lapOptions = {}
for lapCount = RacingSystem.Config.minLapCount, RacingSystem.Config.maxLapCount do
    lapOptions[#lapOptions + 1] = tostring(lapCount)
end

local lapListItem = UIMenuListItem.New('Laps', lapOptions, 2, 'Number of laps for this race.')
hostSubmenu:AddItem(lapListItem)

-- Traffic options
local trafficOptions = { 'None', 'Low', 'High', 'Full' }
local trafficListItem = UIMenuListItem.New('Traffic', trafficOptions, 1, 'Traffic density for the hosted race instance.')
hostSubmenu:AddItem(trafficListItem)

-- Maximum PI (disabled/preview only)
local piListItem = UIMenuListItem.New('Maximum PI', { '400', '800', '1200' }, 1, 'Maximum PI limit (preview only, not enforced yet).')
piListItem:Enabled(false)
hostSubmenu:AddItem(piListItem)

-- Late Join %
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
    -- Refresh the race list from RacingSystem.Client.latestSnapshot.definitions before opening submenu
    logMenuVerbose(('Host submenu activated, RacingSystem.Client.latestSnapshot type: %s'):format(type(RacingSystem.Client.latestSnapshot)))

    local definitions = type(RacingSystem.Client.latestSnapshot) == 'table' and type(RacingSystem.Client.latestSnapshot.definitions) == 'table'
        and RacingSystem.Client.latestSnapshot.definitions or {}

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
        logMenuVerbose('No races available — snapshot may not be loaded yet')
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
    local definitions = type(RacingSystem.Client.latestSnapshot) == 'table' and type(RacingSystem.Client.latestSnapshot.definitions) == 'table'
        and RacingSystem.Client.latestSnapshot.definitions or {}
    local selectedIndex = tonumber(raceListItem:Index()) or 1

    logMenuVerbose(('Accept activated: selectedIndex=%d, totalDefinitions=%d'):format(selectedIndex, #definitions))

    local selectedDefinition = definitions[selectedIndex]

    if not selectedDefinition then
        logMenuVerbose('Selected definition is nil')
        RacingSystem.Client.Util.NotifyPlayer('No race selected.', true)
        return
    end

    -- Get selected options
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

    TriggerServerEvent('racingsystem:invokeRace', payload, actualLapCount)
    MenuHandler:CloseAndClearHistory()
end

-- ─── Race Editor ─────────────────────────────────────────────────────────────

-- Editor state tracking (read/written by client.lua event handlers)
local editorSessionActive = false

-- New Race keyboard input
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

-- Checkpoint width slider options
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
    return 7  -- default 8.0m at index 7
end

-- Main editor menu: Race Editor (submenu)
local raceEditorMenu = UIMenu.New('Race Editor', 'Create and edit race checkpoint layouts.', MENU_X, 0, true)
raceEditorMenu:MenuAlignment(MenuAlignment.LEFT)
raceEditorMenu:SetBannerColor(SColor.LightBlue)
raceEditorMenu:AddItem(importGTAOUrlItem)

-- New Race menu item
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
        TriggerServerEvent('racingsystem:requestEditorRace', raceName)
    else
        logMenuVerbose('New Race: raceName was nil, not firing event')
    end
end
raceEditorMenu:AddItem(newRaceMenuItem)

-- Edit Existing submenu: displays indexed races
local editExistingSubmenu = UIMenu.New('Edit Existing', 'Select a race to edit.', MENU_X, 0, true)
editExistingSubmenu:MenuAlignment(MenuAlignment.LEFT)
editExistingSubmenu:SetBannerColor(SColor.LightBlue)

-- Stored race items for updating
local editExistingRaceItems = {}

-- Populate Edit Existing submenu with indexed races
local function refreshEditExistingRaces()
    local definitions = type(RacingSystem.Client.latestSnapshot) == 'table' and type(RacingSystem.Client.latestSnapshot.definitions) == 'table'
        and RacingSystem.Client.latestSnapshot.definitions or {}

    -- Recreate submenu to clear old items
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

            -- Capture definition in closure
            raceMenuItem.Activated = function(itemMenu)
                logMenuVerbose(('Loading race for editing: %s'):format(definition.name))
                TriggerServerEvent('racingsystem:requestEditorRace', definition.name)
                -- Switch back to Race Editor menu
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

    local definitions = type(RacingSystem.Client.latestSnapshot) == 'table' and type(RacingSystem.Client.latestSnapshot.definitions) == 'table'
        and RacingSystem.Client.latestSnapshot.definitions or {}

    for _, definition in ipairs(definitions) do
        local normalizedLookupName = RacingSystem.NormalizeRaceName(definition.lookupName)
        local normalizedDefinitionName = RacingSystem.NormalizeRaceName(definition.name)
        if normalizedRaceName == normalizedLookupName or normalizedRaceName == normalizedDefinitionName then
            return definition
        end
    end

    return nil
end

-- Initial population
refreshEditExistingRaces()

-- Edit Existing menu item
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

-- Add Checkpoint menu item (always present, disabled until session active)
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

-- Checkpoint Width slider (disabled until session active)
local checkpointWidthSlider = UIMenuSliderItem.New(
    'Checkpoint Width',
    #CHECKPOINT_WIDTH_OPTIONS - 1,
    1,
    getWidthIndex(8.0) - 1,
    false
)
checkpointWidthSlider:Enabled(false)
raceEditorMenu:AddItem(checkpointWidthSlider)

-- Grab Checkpoint checkbox (disabled until session active)
local grabCheckpointCheckbox = UIMenuCheckboxItem.New(
    'Grab Checkpoint',
    false,
    1,
    'Grab the nearest checkpoint and drag it as you move.'
)
grabCheckpointCheckbox:Enabled(false)
raceEditorMenu:AddItem(grabCheckpointCheckbox)

-- Save Race item (disabled until session active)
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

    logMenuVerbose(('Saving race "%s" with %d checkpoints'):format(RacingSystem.Client.editorState.name, #RacingSystem.Client.editorState.checkpoints))

    -- Fire the save event to the server
    TriggerServerEvent('racingsystem:saveEditorRace', {
        name = RacingSystem.Client.editorState.name,
        checkpoints = RacingSystem.Client.editorState.checkpoints,
    })
end
raceEditorMenu:AddItem(saveRaceMenuItem)

-- Delete Race item (disabled until session active, two-click confirmation)
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

    -- Check if armed for deletion
    if RacingSystem.Menu.deleteConfirmRaceName == RacingSystem.NormalizeRaceName(raceName) then
        -- SECOND CLICK - Execute delete
        logMenuVerbose(('Confirmed delete: %s'):format(raceName))
        local selectedDefinition = findDefinitionByEditorRaceName(raceName)
        TriggerServerEvent('racingsystem:deleteRaceDefinition', {
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
        -- FIRST CLICK - Arm for deletion
        logMenuVerbose(('Armed delete confirmation for: %s'):format(raceName))
        RacingSystem.Menu.deleteConfirmRaceName = RacingSystem.NormalizeRaceName(raceName)
        deleteRaceMenuItem:Label('Delete Selected Race (Confirm)')
        setItemDescriptionRaw(deleteRaceMenuItem, ('Press again to permanently delete "%s".'):format(raceName))
        syncMenuCurrentDescription(raceEditorMenu)
    end
end
raceEditorMenu:AddItem(deleteRaceMenuItem)

-- Exit Editor item (disabled until session active)
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

-- Slider change handler
local function getClosestCheckpoint()
    if not RacingSystem.Client.editorState or not RacingSystem.Client.editorState.checkpoints or #RacingSystem.Client.editorState.checkpoints == 0 then
        return nil
    end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    local closest = nil
    local closestDistance = math.huge

    for i, checkpoint in ipairs(RacingSystem.Client.editorState.checkpoints) do
        local checkpointCoords = vector3(checkpoint.x, checkpoint.y, checkpoint.z)
        local distance = #(playerCoords - checkpointCoords)

        if distance < closestDistance then
            closest = { index = i, distance = distance, checkpoint = checkpoint }
            closestDistance = distance
        end
    end

    return closest
end

raceEditorMenu.OnSliderChange = function(menu, item, index)
    if item == checkpointWidthSlider then
        local newRadius = CHECKPOINT_WIDTH_OPTIONS[index + 1]
        if newRadius and RacingSystem.Client.editorState then
            logMenuVerbose(('Checkpoint width changed to: %.1f'):format(newRadius))
            RacingSystem.Client.editorState.defaultCheckpointRadius = newRadius

            -- Apply live width to selected checkpoint (single source of truth)
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

-- Checkbox change handler
-- ─── Grab checkpoint implementation ───────────────────────────────────────

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

-- Editor thread: draw helper line to nearest checkpoint
CreateThread(function()
    while true do
        Wait(10)

        if editorSessionActive and RacingSystem.Client.editorState and RacingSystem.Client.editorState.checkpoints and #RacingSystem.Client.editorState.checkpoints > 0 then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)

            -- Draw line to closest checkpoint
            local closest = getClosestCheckpoint()
            if closest then
                local checkpointCoords = vector3(closest.checkpoint.x, closest.checkpoint.y, closest.checkpoint.z)
                DrawLine(
                    playerCoords.x, playerCoords.y, playerCoords.z,
                    checkpointCoords.x, checkpointCoords.y, checkpointCoords.z,
                    255, 255, 255, 255  -- White line
                )
            end
        end
    end
end)

raceEditorMenu.OnCheckboxChange = function(menu, item, checked)
    if item == grabCheckpointCheckbox then
        logMenuVerbose(('Grab Checkpoint toggled: %s'):format(checked and 'on' or 'off'))
        toggleGrabCheckpoint()
        -- Sync checkbox with actual shared selection state
        local isGrabbed = RacingSystem.Client.editorState and RacingSystem.Client.editorState.grabbedCheckpointIndex ~= nil
        grabCheckpointCheckbox:Checked(isGrabbed)
    end
end


raceEditorMenuItem.Activated = function(menu)
    logMenuVerbose('Race Editor submenu activated')
    menu:SwitchTo(raceEditorMenu, 1, true)
end

RacingSystem.Menu.raceMenuInitialized = true

-- ─── Public interface (called by client.lua) ─────────────────────────────────

function RacingSystem.Menu.isRaceMenuVisible()
    return neutralMenu:Visible() or stagingMenu:Visible() or racingMenu:Visible()
end

local function setVisibleStateMenu(playerState)
    -- Editing state intentionally routes to neutral so Race Editor stays reachable.
    if playerState == 'neutral' or playerState == 'editing' then
        neutralMenu:Visible(true)
    elseif playerState == 'racing' then
        racingMenu:Visible(true)
    else
        stagingMenu:Visible(true)
    end
end

function RacingSystem.Menu.refreshRaceMenu()
    local playerState = getMenuPlayerState()
    local instance = type(RacingSystem.Client.getJoinedRaceInstance) == 'function' and RacingSystem.Client.getJoinedRaceInstance() or nil
    local isHost = instance and instance.owner == GetPlayerServerId(PlayerId())

    startCountdownMenuItem:Enabled(playerState == 'staging' and isHost)

    local viewerIsAdmin = type(RacingSystem.Client.latestSnapshot.viewer) == 'table'
        and RacingSystem.Client.latestSnapshot.viewer.isAdmin == true
    killRaceMenuItem:Enabled(isHost or viewerIsAdmin)

    if RacingSystem.Menu.isRaceMenuVisible() then
        setVisibleStateMenu(playerState)
    end
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
    -- Called when editor session changes (loaded, saved, deleted)
    logMenuVerbose('refreshEditorMenu called')
    refreshEditExistingRaces()

    local isGrabbed = RacingSystem.Client.editorState and RacingSystem.Client.editorState.grabbedCheckpointIndex ~= nil
    grabCheckpointCheckbox:Checked(isGrabbed)
end

function RacingSystem.Menu.buildMenuState()
    return {
        editorSessionActive = editorSessionActive,
    }
end

function RacingSystem.Menu.beginEditorSessionUI()
    -- Called when editor session is activated
    logMenuVerbose('beginEditorSessionUI: editor session started')
    editorSessionActive = true

    -- Enable all editing controls
    addCheckpointMenuItem:Enabled(true)
    checkpointWidthSlider:Enabled(true)
    grabCheckpointCheckbox:Enabled(true)
    saveRaceMenuItem:Enabled(true)
    exitEditorMenuItem:Enabled(true)

    -- Keep delete control available in editor; server still enforces permissions.
    deleteRaceMenuItem:Enabled(true)

    -- Sync checkbox state from shared selection state
    local isGrabbed = RacingSystem.Client.editorState and RacingSystem.Client.editorState.grabbedCheckpointIndex ~= nil
    grabCheckpointCheckbox:Checked(isGrabbed)

    -- Clear any pending delete confirmation
    RacingSystem.Menu.deleteConfirmRaceName = nil
    deleteRaceMenuItem:Label('Delete Selected Race')
    setItemDescriptionRaw(deleteRaceMenuItem, 'Delete this race definition from disk.')
    syncMenuCurrentDescription(raceEditorMenu)

    logMenuVerbose('beginEditorSessionUI: editor controls now enabled')
end

function RacingSystem.Menu.endEditorSessionUI()
    -- Called when editor session is ended
    logMenuVerbose('endEditorSessionUI: editor session ended')
    editorSessionActive = false

    -- Disable all editing controls
    addCheckpointMenuItem:Enabled(false)
    checkpointWidthSlider:Enabled(false)
    grabCheckpointCheckbox:Enabled(false)
    grabCheckpointCheckbox:Checked(false)
    saveRaceMenuItem:Enabled(false)
    deleteRaceMenuItem:Enabled(false)
    exitEditorMenuItem:Enabled(false)

    -- Clear any pending delete confirmation
    RacingSystem.Menu.deleteConfirmRaceName = nil
    deleteRaceMenuItem:Label('Delete Selected Race')
    setItemDescriptionRaw(deleteRaceMenuItem, 'Delete this race definition from disk.')
    syncMenuCurrentDescription(raceEditorMenu)

    -- Return to neutral editor menu state
    if raceEditorMenu:Visible() then
        raceEditorMenu:GoBack()
    end
end

-- ─── Keybind ─────────────────────────────────────────────────────────────────

RegisterCommand('+racemenu', function()
    RacingSystem.Menu.openRaceMenu()
end, false)

RegisterCommand('-racemenu', function() end, false)

RegisterKeyMapping('+racemenu', 'Open race control menu', 'keyboard', 'F7')


