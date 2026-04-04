fx_version 'cerulean'
game 'gta5'
-- Startup order hint:
-- ensure ScaleformUI_Assets
-- ensure ScaleformUI_Lua
-- ensure racingsystem

author 'Eddlm'
description 'Client-server Lua system for a racing system resource'
version '0.0.1'

lua54 'yes'

dependency 'ScaleformUI_Assets'
dependency 'ScaleformUI_Lua'

shared_scripts {
    'shared.lua'
}

ui_page 'ui/gtao_race_prompt.html'

files {
    'race_index.json',
    'CustomRaces/*.json',
    'OnlineRaces/*.json',
    'ui/gtao_race_prompt.html',
    'ui/gtao_race_prompt.css',
    'ui/gtao_race_prompt.js'
}

client_scripts {
    '@ScaleformUI_Lua/ScaleformUI.lua',
    'util.lua',
    'client.lua'
}

server_scripts {
    'UpdateNotifier.lua',
    'server.lua'
}
