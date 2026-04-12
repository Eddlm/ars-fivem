fx_version 'cerulean'
game 'gta5'

name 'vehiclemanager'
author 'eddlm'
description 'Standalone vehicle manager menu built on ScaleformUI_Lua with PerformanceTuning integration.'
version '0.0.0'

lua54 'yes'

dependency 'ScaleformUI_Assets'
dependency 'ScaleformUI_Lua'

shared_script 'Config.lua'

client_scripts {
    '@ScaleformUI_Lua/ScaleformUI.lua',
    'client/vehiclemanager.lua'
}

server_scripts {
    'UpdateNotifier.lua',
    'server/vehicle_saves.lua'
}

files {
    'savedvehicles/.gitkeep',
    'savedvehicles/*.json'
}
