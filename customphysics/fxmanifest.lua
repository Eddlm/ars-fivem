fx_version 'cerulean'
game 'gta5'
-- Startup order hint:
-- customphysics is designed as a silent gameplay enhancer.
-- It can run independently; start after performancetuning if you want
-- optional handling-state baseline reads to be available sooner.

author 'Eddlm'
description 'Client-side drivetrain and slide physics helpers'
version '0.0.2'

lua54 'yes'

shared_scripts {
    'shared.lua'
}

client_scripts {
    'util.lua',
    'wheelies.lua',
    'rollovers.lua',
    'power.lua',
    'nitrous.lua',
    'client.lua'
}

server_script 'UpdateNotifier.lua'
