fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_entreprises'
author 'Elyzea FA'
description 'Entreprises créées par les joueurs depuis le téléphone (Elyzea Aura › Entreprises) : vitrine (logo, spécialité, description), métier et compte par entreprise, grades et permissions, recrutement, service et paie, dépôts / retraits, téléphone de service et tablette, appels et messages des clients, modération staff'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'shared/perms.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
    'server/service.lua',
    'server/finance.lua',
    'server/direction.lua',
    'server/company.lua',
    'server/admin.lua',
    'server/phone.lua',
    'server/api.lua',
}

client_scripts {
    'client/main.lua',
    'client/tablet.lua',
    'client/phone.lua',
}

ui_page 'html/index.html'

files {
    'html/brand.css',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/tablet.js',
    'html/admin.js',
}

dependencies { 'elyzea_core' }
