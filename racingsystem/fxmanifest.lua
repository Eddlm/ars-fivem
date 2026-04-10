fx_version 'cerulean'
game 'gta5'
-- Startup order hint:
-- ensure ScaleformUI_Assets
-- ensure ScaleformUI_Lua
-- ensure racingsystem

author 'Eddlm'
description 'Client-server Lua system for a racing system resource'
version '0.0.8'

lua54 'yes'

dependency 'ScaleformUI_Assets'
dependency 'ScaleformUI_Lua'

ui_page 'ui/index.html'

shared_scripts {
    'Config.lua',
    'shared.lua'
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
    'util.lua',
    'menu.lua',
    'client.lua'
}

server_scripts {
    'UpdateNotifier.lua',
    'server.lua'
}
