fx_version 'cerulean'
game 'gta5'

author 'Eddlm'
description 'Forces ambient traffic and population density to configured values.'
version '1.0.0'

shared_script 'Config.lua'

client_scripts {
    'client.lua',
    'traffic_task.lua',
}

server_scripts {
    'server.lua',
}
