-- Race Control menu — ScaleformUI implementation
-- Loaded after util.lua and before client.lua via fxmanifest.

local MENU_TITLE    = 'Race Control'
local MENU_SUBTITLE = '~b~RACINGSYSTEM'
local MENU_X        = 20

-- ─── Debug logging ────────────────────────────────────────────────────────────

local function getClientExtraPrintLevel()
    local rawLevel = 0
    if type(GetConvarInt) == 'function' then
        rawLevel = math.floor(tonumber(GetConvarInt('rSystemExtraPrints', 0)) or 0)
    else
        local raw = type(GetConvar) == 'function' and GetConvar('rSystemExtraPrints', '0') or '0'
        rawLevel = math.floor(tonumber(raw) or 0)
    end
    return rawLevel == 2 and 2 or 0
end

local function logMenuVerbose(message)
    if getClientExtraPrintLevel() == 2 then
        print(('[racingsystem:menu] %s'):format(tostring(message or '')))
    end
end

-- ─── Menu state (read by client.lua) ────────────────────────────────────────

raceMenuInitialized       = false
raceMenuPendingSelectName = nil
raceMenuPendingEditorName = nil
raceMenuDeleteConfirmName = nil
raceMenuDynamicItemsActive = {} -- Track which dynamic items are currently added

-- ─── Helper: determine player's current race state ─────────────────────────────

local function getMenuPlayerState()
    -- Returns: 'neutral', 'staging', 'countdown', 'racing', 'finished', or 'editing'
    if editorSessionActive then
        return 'editing'
    end

    local instance = type(getJoinedRaceInstance) == 'function' and getJoinedRaceInstance() or nil
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

-- ─── Menu objects ────────────────────────────────────────────────────────────

local raceMainMenu = UIMenu.New(MENU_TITLE, MENU_SUBTITLE, MENU_X, 0, true)
raceMainMenu:MenuAlignment(MenuAlignment.LEFT)
raceMainMenu:SetBannerColor(SColor.LightBlue)

-- Reset to Checkpoint (not in menu, kept for future use)
local resetCheckpointMenuItem = UIMenuItem.New(
    'Reset to Checkpoint',
    'Teleport back to your last passed checkpoint.'
)
resetCheckpointMenuItem.Activated = function(menu)
    logMenuVerbose('Reset to Checkpoint activated')
    TriggerServerEvent('racingsystem:resetToCheckpoint')
end

-- Start Countdown (not in menu, kept for future use)
local startCountdownMenuItem = UIMenuItem.New(
    'Start Countdown',
    'Start countdown for the race you are currently joined to.'
)
startCountdownMenuItem.Activated = function(menu)
    logMenuVerbose('Start Countdown activated')
    TriggerServerEvent('racingsystem:startRace')
end

-- Leave Race (not in menu, kept for future use)
local leaveRaceMenuItem = UIMenuItem.New(
    'Leave Race',
    'Leave your current race instance.'
)
leaveRaceMenuItem.Activated = function(menu)
    logMenuVerbose('Leave Race activated')
    TriggerServerEvent('racingsystem:leaveRace')
    -- Menu will refresh via snapshot update when server processes the leave
end

-- ─── Host submenu ────────────────────────────────────────────────────────────

local hostItem = UIMenuItem.New(
    'Host',
    'Host a race from saved definitions.'
)
raceMainMenu:AddItem(hostItem)

-- Active Races
local activeRacesItem = UIMenuItem.New(
    'Active Races',
    'Join a race that is currently running.'
)
raceMainMenu:AddItem(activeRacesItem)

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
    local instances = type(latestSnapshot) == 'table' and type(latestSnapshot.instances) == 'table'
        and latestSnapshot.instances or {}

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
    local instances = type(latestSnapshot) == 'table' and type(latestSnapshot.instances) == 'table'
        and latestSnapshot.instances or {}
    local selectedIndex = tonumber(activeRaceListItem:Index()) or 1

    logMenuVerbose(('Join activated: selectedIndex=%d, totalInstances=%d'):format(selectedIndex, #instances))

    local selectedInstance = instances[selectedIndex]

    if not selectedInstance then
        logMenuVerbose('Selected instance is nil')
        RacingSystemUtil.NotifyPlayer('No active race selected.', true)
        return
    end

    logMenuVerbose(('Joining race: id=%d name=%s'):format(
        selectedInstance.id,
        tostring(selectedInstance.name)
    ))

    TriggerServerEvent('racingsystem:joinRaceInstanceById', selectedInstance.id)
    closeRaceMenu()
end

local hostSubmenu = UIMenu.New('Host', 'Choose a saved race and host it.', MENU_X, 0, true)
hostSubmenu:MenuAlignment(MenuAlignment.LEFT)
hostSubmenu:SetBannerColor(SColor.LightBlue)

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

hostItem.Activated = function(menu)
    -- Refresh the race list from latestSnapshot.definitions before opening submenu
    logMenuVerbose(('Host submenu activated, latestSnapshot type: %s'):format(type(latestSnapshot)))

    local definitions = type(latestSnapshot) == 'table' and type(latestSnapshot.definitions) == 'table'
        and latestSnapshot.definitions or {}

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
    raceListItem:Index(1)

    menu:SwitchTo(hostSubmenu, 1, true)
end

acceptItem.Activated = function(menu)
    local definitions = type(latestSnapshot) == 'table' and type(latestSnapshot.definitions) == 'table'
        and latestSnapshot.definitions or {}
    local selectedIndex = tonumber(raceListItem:Index()) or 1

    logMenuVerbose(('Accept activated: selectedIndex=%d, totalDefinitions=%d'):format(selectedIndex, #definitions))

    local selectedDefinition = definitions[selectedIndex]

    if not selectedDefinition then
        logMenuVerbose('Selected definition is nil')
        RacingSystemUtil.NotifyPlayer('No race selected.', true)
        return
    end

    -- Get selected options
    local selectedLapCount = tonumber(lapListItem:Index()) or 2
    local actualLapCount = tonumber(lapOptions[selectedLapCount]) or 2

    local trafficIndex = tonumber(trafficListItem:Index()) or 1
    local trafficNames = { none = 'none', low = 'low', high = 'high', full = 'full' }
    local trafficValue = 'none'
    if trafficIndex == 2 then trafficValue = 'low'
    elseif trafficIndex == 3 then trafficValue = 'high'
    elseif trafficIndex == 4 then trafficValue = 'full'
    end

    local lateJoinIndex = tonumber(lateJoinListItem:Index()) or 3
    local lateJoinPercents = { 0, 25, 50, 75, 100 }
    local lateJoinPercent = lateJoinPercents[lateJoinIndex] or 50

    logMenuVerbose(('Invoking race: name=%s lookup=%s sourceType=%s laps=%d traffic=%s lateJoin=%d%%'):format(
        tostring(selectedDefinition.name),
        tostring(selectedDefinition.lookupName),
        tostring(selectedDefinition.sourceType),
        actualLapCount,
        trafficValue,
        lateJoinPercent
    ))

    local payload = {
        name = selectedDefinition.name,
        lookupName = selectedDefinition.lookupName,
        sourceType = selectedDefinition.sourceType,
        raceId = selectedDefinition.raceId,
        trafficMode = trafficValue,
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
    2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0,
    13.0, 14.0, 15.0, 16.0, 18.0, 20.0, 24.0, 28.0, 32.0, 40.0
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
    local definitions = type(latestSnapshot) == 'table' and type(latestSnapshot.definitions) == 'table'
        and latestSnapshot.definitions or {}

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
    if editorSessionActive and type(addCheckpointAtPlayer) == 'function' then
        addCheckpointAtPlayer()
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

    if not editorSessionActive or not editorState or not editorState.name or #editorState.checkpoints == 0 then
        logMenuVerbose('Save cancelled: session not active or no checkpoints')
        return
    end

    logMenuVerbose(('Saving race "%s" with %d checkpoints'):format(editorState.name, #editorState.checkpoints))

    -- Fire the save event to the server
    TriggerServerEvent('racingsystem:saveEditorRace', {
        name = editorState.name,
        checkpoints = editorState.checkpoints,
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

    local raceName = editorState and editorState.name or ''
    if raceName == '' then
        return
    end

    -- Check if armed for deletion
    if raceMenuDeleteConfirmName == RacingSystem.NormalizeRaceName(raceName) then
        -- SECOND CLICK - Execute delete
        logMenuVerbose(('Confirmed delete: %s'):format(raceName))
        TriggerServerEvent('racingsystem:deleteRaceDefinition', raceName)
        raceMenuDeleteConfirmName = nil
        deleteRaceMenuItem:Label('Delete Selected Race')
        deleteRaceMenuItem:Description('Delete this race definition from disk.')
    else
        -- FIRST CLICK - Arm for deletion
        logMenuVerbose(('Armed delete confirmation for: %s'):format(raceName))
        raceMenuDeleteConfirmName = RacingSystem.NormalizeRaceName(raceName)
        deleteRaceMenuItem:Label('Delete Selected Race (Confirm)')
        deleteRaceMenuItem:Description(('Press again to permanently delete "%s".'):format(raceName))
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
    if editorSessionActive and type(endEditorSession) == 'function' then
        endEditorSession()
    end
end
raceEditorMenu:AddItem(exitEditorMenuItem)

-- Slider change handler
raceEditorMenu.OnSliderChange = function(menu, item, index)
    if item == checkpointWidthSlider then
        local newRadius = CHECKPOINT_WIDTH_OPTIONS[index + 1]
        if newRadius and editorState then
            logMenuVerbose(('Checkpoint width changed to: %.1f'):format(newRadius))
            editorState.defaultCheckpointRadius = newRadius

            -- If grabbing a checkpoint, update its radius too
            if editorState.grabbedCheckpointIndex and editorState.checkpoints[editorState.grabbedCheckpointIndex] then
                editorState.checkpoints[editorState.grabbedCheckpointIndex].radius = newRadius
                logMenuVerbose(('Updated grabbed checkpoint radius to: %.1f'):format(newRadius))
            end
        end
    end
end

-- Checkbox change handler
-- ─── Grab checkpoint implementation ───────────────────────────────────────

local grabbedCheckpointIndex = nil

local function getClosestCheckpoint()
    if not editorState or not editorState.checkpoints or #editorState.checkpoints == 0 then
        return nil
    end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    local closest = nil
    local closestDistance = math.huge

    for i, checkpoint in ipairs(editorState.checkpoints) do
        local checkpointCoords = vector3(checkpoint.x, checkpoint.y, checkpoint.z)
        local distance = #(playerCoords - checkpointCoords)

        if distance < closestDistance then
            closest = { index = i, distance = distance, checkpoint = checkpoint }
            closestDistance = distance
        end
    end

    return closest
end

local function toggleGrabCheckpoint()
    if not editorSessionActive then
        return
    end

    if grabbedCheckpointIndex then
        -- Release the grabbed checkpoint
        grabbedCheckpointIndex = nil
        logMenuVerbose('Checkpoint released')
    else
        -- Grab the closest checkpoint
        local closest = getClosestCheckpoint()
        if closest then
            grabbedCheckpointIndex = closest.index
            logMenuVerbose(('Grabbed checkpoint %d'):format(grabbedCheckpointIndex))
        else
            logMenuVerbose('No checkpoints available')
        end
    end
end

-- Editor thread: move grabbed checkpoint and draw line to closest
CreateThread(function()
    local debugPrinted = false
    while true do
        Wait(10)

        if editorSessionActive then
            if not debugPrinted then
                print(('[racingsystem:menu] DEBUG: editorSessionActive=true, editorState type=%s'):format(type(editorState)))
                if type(editorState) == 'table' then
                    print(('[racingsystem:menu] DEBUG: editorState.checkpoints type=%s, count=%s'):format(type(editorState.checkpoints), editorState.checkpoints and #editorState.checkpoints or 'nil'))
                end
                debugPrinted = true
            end
        end

        if editorSessionActive and editorState and editorState.checkpoints and #editorState.checkpoints > 0 then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)

            -- Handle grabbed checkpoint movement
            if grabbedCheckpointIndex and editorState.checkpoints[grabbedCheckpointIndex] then
                local grabbedCheckpoint = editorState.checkpoints[grabbedCheckpointIndex]
                grabbedCheckpoint.x = playerCoords.x
                grabbedCheckpoint.y = playerCoords.y
                grabbedCheckpoint.z = playerCoords.z
            end

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
        -- Sync checkbox with actual grab state
        grabCheckpointCheckbox:Checked(grabbedCheckpointIndex ~= nil)
    end
end


-- Add Race Editor item to main menu
local raceEditorMenuItem = UIMenuItem.New(
    'Race Editor',
    'Create and edit race checkpoint layouts.'
)
raceMainMenu:AddItem(raceEditorMenuItem)

raceEditorMenuItem.Activated = function(menu)
    logMenuVerbose('Race Editor submenu activated')
    menu:SwitchTo(raceEditorMenu, 1, true)
end

raceMenuInitialized = true

print('[racingsystem:menu] Menu system loaded. raceMenuInitialized = true')

-- ─── Public interface (called by client.lua) ─────────────────────────────────

function isRaceMenuVisible()
    return raceMainMenu:Visible()
end

function openRaceMenu()
    if MenuHandler:IsAnyMenuOpen() then
        MenuHandler:CloseAndClearHistory()
    else
        refreshRaceMenu()
        raceMainMenu:Visible(true)
    end
end

function refreshRaceMenu()
    -- Called whenever menu opens or snapshot updates; dynamically show/hide items based on race state
    local playerState = getMenuPlayerState()
    local instance = type(getJoinedRaceInstance) == 'function' and getJoinedRaceInstance() or nil
    local isHost = instance and instance.owner == GetPlayerServerId(PlayerId())
    local inRace = playerState == 'staging' or playerState == 'countdown' or playerState == 'racing' or playerState == 'finished'

    logMenuVerbose(('refreshRaceMenu: playerState=%s, inRace=%s, isHost=%s'):format(playerState, inRace, isHost))

    -- Static items: enable/disable based on state
    hostItem:Enabled(not inRace)
    raceEditorMenuItem:Enabled(not inRace)

    -- Track what should be active
    local shouldHaveStartCountdown = playerState == 'staging' and isHost
    local shouldHaveLeaveRace = inRace
    local shouldHaveResetCheckpoint = playerState == 'racing'

    -- Helper: find item index in menu
    local function findItemIndex(item)
        for i, menuItem in ipairs(raceMainMenu.Items) do
            if menuItem == item then
                return i
            end
        end
        return nil
    end

    -- Remove items that should no longer be present
    if not shouldHaveStartCountdown and raceMenuDynamicItemsActive.startCountdown then
        local idx = findItemIndex(startCountdownMenuItem)
        if idx then
            raceMainMenu:RemoveItemAt(idx)
            logMenuVerbose('Removed Start Countdown')
        end
        raceMenuDynamicItemsActive.startCountdown = false
    end

    if not shouldHaveLeaveRace and raceMenuDynamicItemsActive.leaveRace then
        local idx = findItemIndex(leaveRaceMenuItem)
        if idx then
            raceMainMenu:RemoveItemAt(idx)
            logMenuVerbose('Removed Leave Race')
        end
        raceMenuDynamicItemsActive.leaveRace = false
    end

    if not shouldHaveResetCheckpoint and raceMenuDynamicItemsActive.resetCheckpoint then
        local idx = findItemIndex(resetCheckpointMenuItem)
        if idx then
            raceMainMenu:RemoveItemAt(idx)
            logMenuVerbose('Removed Reset to Checkpoint')
        end
        raceMenuDynamicItemsActive.resetCheckpoint = false
    end

    -- Add items that should be present
    if shouldHaveStartCountdown and not raceMenuDynamicItemsActive.startCountdown then
        raceMainMenu:AddItem(startCountdownMenuItem)
        raceMenuDynamicItemsActive.startCountdown = true
        logMenuVerbose('Added Start Countdown (host in staging)')
    end

    if shouldHaveLeaveRace and not raceMenuDynamicItemsActive.leaveRace then
        raceMainMenu:AddItem(leaveRaceMenuItem)
        raceMenuDynamicItemsActive.leaveRace = true
        logMenuVerbose('Added Leave Race (in race)')
    end

    if shouldHaveResetCheckpoint and not raceMenuDynamicItemsActive.resetCheckpoint then
        raceMainMenu:AddItem(resetCheckpointMenuItem)
        raceMenuDynamicItemsActive.resetCheckpoint = true
        logMenuVerbose('Added Reset to Checkpoint (racing)')
    end
end

function refreshEditorMenu(state)
    -- Called when editor session changes (loaded, saved, deleted)
    logMenuVerbose('refreshEditorMenu called')
    refreshEditExistingRaces()
end

function buildMenuState()
    return {
        editorSessionActive = editorSessionActive,
    }
end

function beginEditorSessionUI()
    -- Called when editor session is activated
    logMenuVerbose('beginEditorSessionUI: editor session started')
    editorSessionActive = true

    -- Enable all editing controls
    addCheckpointMenuItem:Enabled(true)
    checkpointWidthSlider:Enabled(true)
    grabCheckpointCheckbox:Enabled(true)
    saveRaceMenuItem:Enabled(true)
    exitEditorMenuItem:Enabled(true)

    -- Check delete permission
    local canDelete = type(latestSnapshot) == 'table' and type(latestSnapshot.viewer) == 'table'
        and (latestSnapshot.viewer.canDeleteRaceDefinitions or latestSnapshot.viewer.isAdmin)
    deleteRaceMenuItem:Enabled(canDelete)
    if not canDelete then
        deleteRaceMenuItem:Description('Admin permission is required to delete race definitions.')
    end

    -- Reset checkbox state
    grabCheckpointCheckbox:Checked(false)

    -- Clear any pending delete confirmation
    raceMenuDeleteConfirmName = nil
    deleteRaceMenuItem:Label('Delete Selected Race')
    deleteRaceMenuItem:Description('Delete this race definition from disk.')

    logMenuVerbose('beginEditorSessionUI: editor controls now enabled')
end

function endEditorSessionUI()
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
    raceMenuDeleteConfirmName = nil
    deleteRaceMenuItem:Label('Delete Selected Race')
    deleteRaceMenuItem:Description('Delete this race definition from disk.')

    -- Return to neutral editor menu state
    if raceEditorMenu:Visible() then
        raceEditorMenu:GoBack()
    end
end

-- ─── Keybind ─────────────────────────────────────────────────────────────────

RegisterCommand('+racemenu', function()
    openRaceMenu()
end, false)

RegisterCommand('-racemenu', function()
end, false)

RegisterKeyMapping('+racemenu', 'Open race control menu', 'keyboard', 'F7')
