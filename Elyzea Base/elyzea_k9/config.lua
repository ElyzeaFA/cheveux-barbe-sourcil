-- =====================================================================
--  ELYZEA K9 - réglages
--  Chiens de la police (unité cynophile) et chiens des gangs (elyzea_illegal).
--  Tout ce qui touche à la sécurité (permissions, distances, réussite des ordres,
--  détection, expérience) est décidé par le SERVEUR avec ces valeurs.
-- =====================================================================
Config = {}
Config.Debug = false

-- Touches (modifiables par chaque joueur : Paramètres > Raccourcis clavier > FiveM)
Config.Keys = {
    menu = 'O',          -- menu du chien
    target = 'I',        -- mode ciblage (molette = changer de personne, E = confirmer, Échap = annuler)
}

-- ---------------------------------------------------------------------
--  Accès
-- ---------------------------------------------------------------------
Config.Police = {
    enabled = true,
    permission = 'k9',          -- permission des grades de la police (elyzea_police › Direction › Grades)
    requireDuty = true,         -- sortir le chien et donner des ordres : en service uniquement
    protectOnDutyPolice = true, -- un chien de la police n'attaque pas un agent en service
}
Config.Gang = {
    enabled = true,
    permission = 'k9',          -- permission des grades des groupes illégaux (elyzea_illegal › Grades)
    -- types de groupes autorisés (elyzea_illegal : gang, organisation, cartel)
    groupTypes = { gang = true, organisation = true, cartel = true },
}

-- ---------------------------------------------------------------------
--  Races : uniquement des MODÈLES différents (pas de simple changement de couleur).
--  GTA V contient ces grands chiens : berger allemand, rottweiler, husky, labrador (retriever) et Chop.
--  Malinois, dobermann, berger hollandais… n'existent PAS dans GTA V : ils apparaissent ici
--  seulement si un modèle « addon » portant ce nom est installé sur le serveur (addon = true) ;
--  sinon le menu les montre grisés (« modèle non installé »).
--  Modificateurs (bonus réels) :
--    speed  : vitesse de course (×)          health : santé (×)
--    sniff / track / attack / defense / intim : bonus de réussite (en points de %, ajoutés aux compétences)
-- ---------------------------------------------------------------------
Config.Breeds = {
    { id = 'shepherd', label = 'Berger allemand', model = 'a_c_shepherd', sides = { police = true, gang = true },
      desc = 'Polyvalent, endurant et très attentif. La référence des unités cynophiles.',
      traits = { flair = 4, vitesse = 4, puissance = 4, endurance = 5 },
      mods = { speed = 1.05, health = 1.10, sniff = 4, track = 6, attack = 4, defense = 4, intim = 3 } },
    { id = 'rottweiler', label = 'Rottweiler', model = 'a_c_rottweiler', sides = { police = true, gang = true },
      desc = 'Massif et impressionnant. Excellent en intervention et en protection.',
      traits = { flair = 3, vitesse = 3, puissance = 5, endurance = 4 },
      mods = { speed = 0.97, health = 1.25, sniff = 0, track = 0, attack = 8, defense = 8, intim = 8 } },
    { id = 'chop', label = 'Rottweiler « lignée de rue »', model = 'a_c_chop', sides = { gang = true },
      desc = 'Rottweiler au gabarit de rue, nerveux et rapide. Modèle propre à GTA (Chop).',
      traits = { flair = 3, vitesse = 4, puissance = 4, endurance = 4 },
      mods = { speed = 1.04, health = 1.15, sniff = 0, track = 2, attack = 6, defense = 6, intim = 6 } },
    { id = 'husky', label = 'Husky', model = 'a_c_husky', sides = { police = true, gang = true },
      desc = 'Infatigable, excellent pisteur sur de longues distances.',
      traits = { flair = 4, vitesse = 5, puissance = 3, endurance = 5 },
      mods = { speed = 1.08, health = 1.05, sniff = 2, track = 8, attack = 0, defense = 2, intim = 2 } },
    { id = 'labrador', label = 'Labrador', model = 'a_c_retriever', sides = { police = true },
      desc = 'Flair exceptionnel et caractère calme : le spécialiste de la détection.',
      traits = { flair = 5, vitesse = 4, puissance = 2, endurance = 4 },
      mods = { speed = 1.00, health = 1.00, sniff = 10, track = 4, attack = -6, defense = 0, intim = -4 } },
    -- Modèles « addon » (à installer : dossier stream d'une ressource de modèles). Exemples de noms courants.
    { id = 'malinois', label = 'Berger malinois', model = 'a_c_malinois', addon = true, sides = { police = true, gang = true },
      desc = 'Vif, précis et explosif. Chien d\'intervention par excellence.',
      traits = { flair = 4, vitesse = 5, puissance = 4, endurance = 5 },
      mods = { speed = 1.10, health = 1.05, sniff = 4, track = 5, attack = 9, defense = 6, intim = 5 } },
    { id = 'doberman', label = 'Dobermann', model = 'a_c_doberman', addon = true, sides = { police = true, gang = true },
      desc = 'Rapide et dissuasif, très réactif à la menace.',
      traits = { flair = 3, vitesse = 5, puissance = 4, endurance = 4 },
      mods = { speed = 1.09, health = 1.00, sniff = 0, track = 2, attack = 6, defense = 8, intim = 9 } },
    { id = 'dutch', label = 'Berger hollandais', model = 'a_c_dutchshepherd', addon = true, sides = { police = true },
      desc = 'Robuste et équilibré, apprécié en recherche comme en intervention.',
      traits = { flair = 4, vitesse = 4, puissance = 4, endurance = 5 },
      mods = { speed = 1.04, health = 1.10, sniff = 5, track = 7, attack = 5, defense = 4, intim = 3 } },
}

-- ---------------------------------------------------------------------
--  Spécialités (police) : compétence principale et plafonds des compétences
-- ---------------------------------------------------------------------
Config.Specialties = {
    { id = 'detection', label = 'Détection de stupéfiants', icon = '👃', main = 'sniff',
      desc = 'Personnes, véhicules (coffre, habitacle, cachettes) et zones.',
      start = { sniff = 2, obey = 1, track = 1, attack = 1 }, caps = { sniff = 5, obey = 5, track = 3, attack = 2 } },
    { id = 'attack', label = 'Attaque et intervention', icon = '⚡', main = 'attack',
      desc = 'Intimidation, attaque sur ordre, mise au sol et maintien.',
      start = { sniff = 1, obey = 1, track = 1, attack = 2 }, caps = { sniff = 2, obey = 5, track = 3, attack = 5 } },
    { id = 'tracking', label = 'Recherche et pistage', icon = '🧭', main = 'track',
      desc = 'Pistage d\'une personne, recherche de zone, personnes cachées.',
      start = { sniff = 1, obey = 1, track = 2, attack = 1 }, caps = { sniff = 3, obey = 5, track = 5, attack = 2 } },
}

-- Compétences (descriptions par niveau, affichées dans le menu)
Config.Skills = {
    police = {
        { id = 'sniff', label = 'Reniflage', levels = { 'Détection basique, portée et précision faibles.', 'Meilleure détection.', 'Meilleure précision, repère les cachettes.', 'Détection plus rapide et plus efficace.', 'Capacité de détection maximale.' } },
        { id = 'obey', label = 'Obéissance', levels = { 'Peut hésiter, désobéir ou avoir peur.', 'Meilleure réponse aux commandes.', 'Meilleure maîtrise du chien.', 'Exécution rapide, peu d\'hésitation.', 'Obéissance excellente.' } },
        { id = 'attack', label = 'Attaque', levels = { 'Attaque hésitante, faible efficacité.', 'Meilleure réactivité.', 'Meilleure maîtrise de la cible.', 'Attaque plus efficace.', 'Intervention très performante.' } },
        { id = 'track', label = 'Pistage', levels = { 'Piste difficile à suivre.', 'Meilleure détection de la piste.', 'Meilleure précision.', 'Pistage plus rapide.', 'Pistage très performant.' } },
    },
    gang = {
        { id = 'attack', label = 'Attaque', levels = { 'Attaque hésitante.', 'Plus réactif.', 'Fait tomber plus souvent.', 'Attaque efficace.', 'Redoutable.' } },
        { id = 'defense', label = 'Défense', levels = { 'Réagit tard aux menaces proches.', 'Réagit plus vite.', 'Protège sur une plus grande distance.', 'Intervient presque toujours.', 'Garde du corps redoutable.' } },
        { id = 'intim', label = 'Intimidation', levels = { 'Aboie sans conviction.', 'Grogne et aboie.', 'Comportement menaçant, la cible ralentit.', 'La cible n\'ose plus courir.', 'Tétanise la cible.' } },
    },
}
Config.GangStart = { attack = 1, defense = 1, intim = 1 }
Config.GangCaps = { attack = 5, defense = 5, intim = 5 }

-- ---------------------------------------------------------------------
--  Progression
-- ---------------------------------------------------------------------
Config.Progress = {
    maxLevel = 30,
    -- expérience pour passer du niveau n au niveau n+1 : base + step × (n-1)^power (≈ 12 000 XP au total : plusieurs semaines de jeu normal)
    xpBase = 120, xpStep = 12, xpPower = 1.2,
    pointsPerLevel = 1,             -- point de compétence par niveau gagné
    bonusPoints = { [10] = 1, [20] = 1, [30] = 1 },   -- points en plus à ces niveaux
    -- coût d'une amélioration vers le niveau L : L - 1 points (2 → 1 pt, 3 → 2 pts, 4 → 3 pts, 5 → 4 pts)
    historyKeep = 60,               -- lignes d'historique gardées par chien
}

-- Expérience gagnée en intervention (réelle, sur de vrais joueurs) ; limites anti-farm
Config.MissionXp = {
    sniffFound = 60,       -- drogue trouvée (personne / véhicule / zone)
    sniffClear = 10,       -- fouille sans rien trouver
    takedown = 70,         -- cible mise au sol
    intimidate = 15,
    trackFound = 90,       -- personne retrouvée par pistage / recherche
    defend = 50,           -- protection réussie
    sameTargetMinutes = 30,    -- pas d'XP deux fois pour la même personne / le même véhicule pendant ce délai
    dailyCap = 900,            -- XP d'intervention max par jour et par chien
}

-- ---------------------------------------------------------------------
--  Entraînement (exercices réels en jeu, anti-farm)
-- ---------------------------------------------------------------------
Config.Training = {
    dailyCap = 700,             -- XP d'entraînement max par jour et par chien
    repeatPenalty = 0.6,        -- même exercice refait dans l'heure : XP × 0,6 à chaque répétition
    cooldownMinutes = 6,        -- délai minimum avant de refaire le MÊME exercice
    exercises = {
        { id = 'obey', label = 'Obéissance', skill = 'obey', sides = { police = true, gang = true }, xp = 55, seconds = 60, minSeconds = 25,
          desc = 'Enchaîne les ordres affichés (assis, couché, reste, au pied). Récompense ton chien quand il réussit.' },
        { id = 'sniff', label = 'Reniflage', skill = 'sniff', sides = { police = true }, xp = 65, seconds = 120, minSeconds = 30,
          desc = 'Trois leurres odorants sont cachés autour de toi. Lance la recherche et récompense le chien quand il marque.' },
        { id = 'track', label = 'Pistage', skill = 'track', sides = { police = true }, xp = 70, seconds = 150, minSeconds = 40,
          desc = 'Une piste est tracée. Suis ton chien jusqu\'au bout de la piste.' },
        { id = 'attack', label = 'Attaque contrôlée', skill = 'attack', sides = { police = true, gang = true }, xp = 65, seconds = 90, minSeconds = 20,
          desc = 'Un homme d\'attaque protégé arrive. Envoie ton chien puis ordonne-lui de lâcher.' },
        { id = 'defense', label = 'Défense', skill = 'defense', sides = { gang = true }, xp = 65, seconds = 90, minSeconds = 15,
          desc = 'Un individu menaçant fonce sur toi. Ton chien doit l\'intercepter avant qu\'il ne t\'atteigne.' },
        { id = 'intim', label = 'Intimidation', skill = 'intim', sides = { police = true, gang = true }, xp = 50, seconds = 60, minSeconds = 15,
          desc = 'Maintiens la pression : ton chien grogne et aboie jusqu\'à ce que l\'individu lève les mains.' },
    },
}

-- ---------------------------------------------------------------------
--  Ordres et distances
-- ---------------------------------------------------------------------
Config.Target = {
    maxDistance = 35.0,         -- mètres : personnes proposées en mode ciblage
    vehicleDistance = 12.0,     -- mètres : véhicules proposés (renifler un véhicule)
    refreshMs = 500,
}
Config.Orders = {
    cooldownMs = 1500,          -- anti-spam entre deux ordres
    dogLeash = 60.0,            -- le chien doit être à moins de ça de son maître pour recevoir un ordre
}
Config.Attack = {
    contactDistance = 2.6,      -- le serveur vérifie la distance chien-cible avant la mise au sol
    chaseSeconds = 25,          -- abandon de la poursuite au-delà
    holdSeconds = { 4, 10 },    -- maintien au sol : du niveau 1 au niveau 5
    bitesDamage = 6,            -- dégâts par morsure (contrôlés : les dégâts natifs des chiens sont coupés)
    healthFloor = 120,          -- santé minimale laissée par un chien (sur 200 ; GTA : mort à 100) → un chien ne tue jamais
}
Config.Track = {
    maxDistance = 600.0,        -- une piste se perd au-delà
    foundDistance = 9.0,
    seconds = 180,
}
Config.Search = {
    personRadius = { 15.0, 45.0 },   -- recherche de personnes cachées : rayon du niveau 1 au niveau 5 (pistage)
    drugRadius = { 8.0, 24.0 },      -- recherche de stupéfiants au sol (sacs, colis) : niveau 1 à 5 (reniflage)
}
Config.Defend = {
    radius = { 6.0, 18.0 },     -- portée de protection du niveau 1 au niveau 5 (défense ; obéissance pour la police)
    reactionMs = { 2600, 600 }, -- délai de réaction
    growlArmed = true,          -- grogne quand une personne armée s'approche
}

-- ---------------------------------------------------------------------
--  Stupéfiants : objets d'elyzea_inventory que le chien sait détecter
-- ---------------------------------------------------------------------
Config.Drugs = {
    prefixes = { 'weed', 'joint', 'coke', 'cocaine', 'coca_', 'crack', 'meth', 'xtc', 'opi_', 'oxy', 'ketamine', 'mushroom', 'heroin', 'lsd', 'drg_opium' },
    exclude = { 'meth_chemicals', 'baking_soda', 'drg_dye_pink', 'drg_dye_blue', 'drg_dye_yellow', 'drg_syringe_empty', 'drg_safrole' },
    extra = { 'dried_mushroom', 'magic_mushroom' },
}

-- ---------------------------------------------------------------------
--  Santé, blessures
-- ---------------------------------------------------------------------
Config.Health = {
    invincible = false,
    injuredMinutes = 20,        -- chien gravement blessé : indisponible pendant ce délai (soigné au chenil)
}
