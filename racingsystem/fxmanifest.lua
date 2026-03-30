fx_version 'cerulean'
game 'gta5'
-- Startup order hint:
-- ensure ScaleformUI_Assets
-- ensure ScaleformUI_Lua
-- ensure racingsystem

author 'Eddlm'
description 'Client-server Lua scaffolding for a racing system resource'
version '0.1.0'

lua54 'yes'

dependency 'ScaleformUI_Assets'
dependency 'ScaleformUI_Lua'

shared_scripts {
    'shared.lua'
}

files {
    'race_index.json',
    'CustomRaces/*.json',
    'OnlineRaces/*.json'
}

client_scripts {
    '@ScaleformUI_Lua/ScaleformUI.lua',
    'client.lua'
}

server_scripts {
    'server.lua'
}
