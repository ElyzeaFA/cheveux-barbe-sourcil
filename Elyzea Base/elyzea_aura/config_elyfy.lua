-- =========================================================
--  ELYFY : streaming musical du téléphone (+ import de musique depuis l'ordinateur)
--  Fichier séparé de config.lua : ton config.lua (clé d'hébergeur…) n'est pas touché.
-- =========================================================
Config.ElyFy = {
    -- ---------- Catalogue ----------
    -- Audius : musique libre et légale (titres complets), aucune clé nécessaire.
    Audius = { Enabled = true, Host = 'https://api.audius.co', AppName = 'ElyzeaFA' },
    -- YouTube : recherche de n'importe quel titre (lecture par le lecteur YouTube officiel).
    -- Clé API YouTube Data v3 (gratuite, console.cloud.google.com). Vide = celle d'Itoune (Config.Itoune.YouTubeApiKey).
    YouTubeApiKey = '',
    -- Titres du serveur (fichiers audio en https : Fivemanage, etc.), visibles par tous
    Catalog = {
        -- { title = 'Hymne de Los Santos', artist = 'Elyzea FA', url = 'https://r2.fivemanage.com/xxx/hymne.mp3', thumb = '', genre = 'pop' },
    },
    -- Artistes de la ville : un joueur peut publier son propre titre (lien audio de ces hébergeurs)
    UploadHosts = { 'fivemanage.com', 'r2.dev', 'cdn.discordapp.com', 'media.discordapp.net' },

    -- ---------- Téléchargements (à partir de l'ElyAura 4) ----------
    -- Les titres téléchargés sont enregistrés DANS le téléphone : onglet Téléchargements, toujours disponibles.
    Downloads = { MinTier = 4, Max = { [4] = 100, [5] = 300, [6] = 1000 } },

    -- ---------- Bibliothèque ----------
    PlaylistsMax = 50,
    PlaylistItemsMax = 300,

    -- ---------- Import depuis l'ordinateur (onglet « Mes titres ») ----------
    -- Le téléphone donne un code et l'adresse d'une page web servie par ce serveur ; le joueur y envoie son fichier audio
    -- depuis le navigateur de son ordinateur. Le fichier part sur l'hébergeur de l'appareil photo (Fivemanage, Config.Camera).
    Import = {
        Enabled = true,
        -- Adresse publique du serveur, sans / à la fin. Vide = automatique : au démarrage, le serveur essaie son adresse cfx.re
        -- puis http://IP_PUBLIQUE:PORT et garde celle qui répond (voir la console ; commande console : elyfy_import).
        -- Exemples : 'https://monserveur-abc123.users.cfx.re'  ou  'http://123.45.67.89:30120'
        Url = '',
        -- Page d'import hébergée ailleurs (ex. GitHub Pages : 'https://pseudo.github.io/elyfy/'). Vide = page servie par ce serveur.
        -- Dans le index.html de cette page, mets SERVER = l'adresse https de ton serveur (https://xxxx.users.cfx.re).
        Page = 'https://connexionsky9.github.io/Sky9New/',
        MaxMB = 15,          -- taille maximale d'un fichier
        CodeMinutes = 15,    -- durée de validité d'un code
    },
}
