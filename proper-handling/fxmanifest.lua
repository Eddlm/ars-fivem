fx_version 'cerulean'
game 'gta5'

author 'Eddlm'
name 'Proper Handling Physics'
description 'Overhauls all the handlings so they are a mix of V and IV.'
version '0.0.0'

files {
    'Active/**/*.meta',
}

data_file 'HANDLING_FILE' 'Active/**/handling_*.meta'

server_script 'server/UpdateNotifier.lua'
