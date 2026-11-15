-- =========================================================
--  ELYMEET : rencontres (comme happn) : les personnes que vous CROISEZ en ville,
--  une carte des lieux de croisement, j'aime / coup de foudre, crushs et messages.
--  Remplace Étincelle (les anciens profils servent à pré-remplir l'inscription).
--  Fichier séparé de config.lua : ton config.lua (clé d'hébergeur…) n'est pas touché.
-- =========================================================
Config.ElyMeet = {
    MinAge = 18,
    MaxPhotos = 6,
    MinInterests = 3,
    MaxInterests = 10,
    BioLength = 300,
    MessageLength = 500,

    -- Croisements
    CrossRadius = 60.0,         -- mètres : deux joueurs plus proches que ça se « croisent »
    CrossEvery = 15,            -- secondes entre deux relevés des positions
    CrossCooldown = 10,         -- minutes avant de compter un nouveau croisement avec la même personne
    CrossBlur = 120,            -- mètres : le lieu affiché est arrondi (la position exacte n'est jamais montrée)
    FeedDays = 14,              -- jours : croisements montrés dans le fil
    NotifyEvery = 20,           -- minutes : au plus une notification « nouvelle personne croisée » par joueur

    BoltsPerDay = 1,            -- coups de foudre par jour (la personne est prévenue et vous voit en premier)

    Looking = {
        { id = 'serious', label = 'Une relation sérieuse' },
        { id = 'dating',  label = 'Des rencontres' },
        { id = 'friends', label = 'De nouveaux amis' },
        { id = 'unsure',  label = 'Je ne sais pas encore' },
    },

    -- Centres d'intérêt proposés (par catégorie)
    Interests = {
        { cat = 'Sorties', items = { 'Restaurants', 'Bars', 'Clubs', 'Cinéma', 'Concerts', 'Festivals', 'Karaoké', 'Casino' } },
        { cat = 'Sport', items = { 'Salle de sport', 'Running', 'Boxe', 'Basket', 'Football', 'Surf', 'Vélo', 'Golf', 'Yoga', 'Tennis' } },
        { cat = 'Moteurs', items = { 'Voitures', 'Motos', 'Tuning', 'Courses', 'Aviation', 'Bateaux' } },
        { cat = 'Culture', items = { 'Musique', 'Rap', 'Électro', 'Lecture', 'Photographie', 'Art', 'Mode', 'Séries', 'Jeux vidéo', 'Danse' } },
        { cat = 'Style de vie', items = { 'Cuisine', 'Voyages', 'Plage', 'Nature', 'Randonnée', 'Animaux', 'Pêche', 'Chasse', 'Shopping', 'Bien-être' } },
        { cat = 'Valeurs', items = { 'Ambition', 'Humour', 'Famille', 'Fidélité', 'Spontanéité', 'Aventure', 'Calme', 'Fête' } },
    },
}
