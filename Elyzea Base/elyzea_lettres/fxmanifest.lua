fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_lettres'
author 'ELYZEA FA'
description 'Correspondance RP : écrire des lettres manuscrites (feuille + stylo), les lire, les donner, les ranger, les mettre sous enveloppe'
version '1.0.0'

dependencies { 'elyzea_core', 'elyzea_inventory' }

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
    'shared/text.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
    'server/admin.lua',
}

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/layout.js',
    'html/js/app.js',
    'html/fonts/*.woff2',
}
