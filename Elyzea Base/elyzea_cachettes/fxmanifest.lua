fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_cachettes'
author 'Elyzea FA'
description 'Contrebande : cachettes dans les véhicules (portières, coffre, passages de roue, sièges, selle), mini-jeux au tournevis, suspicion, inspection et fouille policière'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'shared/slots.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/settings.lua',
    'server/main.lua',
    'server/admin.lua',
}

client_scripts {
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/games.js',
    'html/app.js',
}

dependencies { 'elyzea_core', 'elyzea_inventory' }
