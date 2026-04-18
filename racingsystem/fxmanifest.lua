fx_version 'cerulean'
game 'gta5'

author 'Eddlm'
description 'Client-server Lua system for a racing system resource'
version '0.0.0'

lua54 'yes'

dependency 'ScaleformUI_Assets'
dependency 'ScaleformUI_Lua'

ui_page 'ui/index.html'

shared_scripts {
    'shared/Config.lua',
    'shared/shared.lua'
}

files {
    'ui/index.html',
    'ui/app.js',
    'ui/style.css',
    'race_index.json',
    'CustomRaces/*.json',
    'OnlineRaces/*.json',
}

client_scripts {
    '@ScaleformUI_Lua/ScaleformUI.lua',
    'client/util.lua',
    'client/menu.lua',
    'client/client.lua',
    'client/InRace.lua'
}

server_scripts {
    'server/UpdateNotifier.lua',
    'server/server.lua'
}
