fx_version 'cerulean'
game 'gta5'

author 'Eddlm'
description 'Forces ambient traffic and population density to configured values.'
version '0.0.0'

shared_script 'shared/Config.lua'

client_scripts {
    'client/traffic_task.lua',
}

server_scripts {
    'server/UpdateNotifier.lua',
    'server/server.lua',
}
