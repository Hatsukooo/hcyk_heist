fx_version 'cerulean'
game 'gta5'
lua54 'yes'
description 'Enhanced Heist System'
author 'Original by Hatsuko, Enhanced Version'
version '2.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'modules/init.lua',
    'config.lua'       
}

client_scripts {
    'client/cl_vangelico.lua',
    'client/cl_car.lua',
    'client/cl_cargo_ship.lua',
    'client/cl_trailers.lua'
}

server_scripts {
    'server/sv_vangelico.lua',
    'server/sv_car.lua',
    'server/sv_cargo_ship.lua',
    'server/sv_trailers.lua'
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_target',
    'ox_inventory'
}

files {
    -- Module files
    'modules/config.lua',
    'modules/error_handler.lua',
    'modules/utils.lua',
    'modules/client/utils.lua',
    'modules/client/performance.lua',
    'modules/client/feedback.lua',
    'modules/server/utils.lua',
    'modules/server/security.lua'
}