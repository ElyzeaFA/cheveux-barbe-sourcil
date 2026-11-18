fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_k9'
author 'Elyzea FA'
description 'Elyzea K9 : chiens de la police (détection, intervention, pistage) et des gangs (attaque, défense, intimidation) : races aux modèles réels, dressage et progression sauvegardés, ordres avec ciblage à la molette, exercices en jeu.'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'shared/k9.lua',
}

client_scripts {
    'client/main.lua',
    'client/dog.lua',
    'client/target.lua',
    'client/victim.lua',
    'client/training.lua',
    'client/preview.lua',
    'client/alt.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
    'server/orders.lua',
    'server/training.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/brand.css',
    'html/style.css',
    'html/app.js',
}

dependencies { 'elyzea_core', 'elyzea_inventory' }
