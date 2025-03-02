fx_version 'cerulean'
game 'gta5'
lua54 'yes'
description 'Enhanced Heist System'
author 'Original by Hatsuko, Enhanced Version'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'modules/loader.lua',
    'modules/utils.lua'
}

client_scripts {
    'modules/client/utils.lua',
    
    'client/cl_vangelico.lua',
    'client/cl_car.lua',
    'client/cl_cargo_ship.lua'
}

server_scripts {
    'modules/server/utils.lua',
    
    'server/sv_vangelico.lua',
    'server/sv_car.lua',
    'server/sv_cargo_ship.lua'
}
