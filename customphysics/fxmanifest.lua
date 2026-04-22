fx_version 'cerulean'
game 'gta5'

author 'Eddlm'
description 'Client-side drivetrain and slide physics helpers'
version '0.0.0'

lua54 'yes'

shared_scripts {
    'shared/Config.lua'
}

client_scripts {
    'client/util.lua',
    'client/wheelies.lua',
    'client/rollovers.lua',
    'client/power.lua',
    'client/client.lua'
}

server_script 'server/UpdateNotifier.lua'

convar_policy {
    read = {
        'cp_rollover_start_speed',
        'cp_rollover_keep_speed',
        'cp_rollover_start_rot',
        'cp_rollover_keep_rot',
    }
}
