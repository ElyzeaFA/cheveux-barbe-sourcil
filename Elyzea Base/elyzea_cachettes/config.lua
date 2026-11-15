-- =====================================================================
--  ELYZEA CACHETTES - configuration (valeurs PAR DÉFAUT)
--  Tout ce qui est marqué [admin] se modifie en jeu : menu admin (F10) › Illégal › Cachettes véhicules
--  (permission « cachettes_manage »). Les valeurs modifiées en jeu sont gardées par la ressource (KVP)
--  et remplacent celles de ce fichier ; « Valeurs par défaut » dans le menu revient à ce fichier.
-- =====================================================================
Config = {}

Config.ToolItem = 'tournevis'          -- objet nécessaire (jamais consommé)
Config.Distance = 6.0                  -- distance max joueur ↔ centre du véhicule (mètres)
Config.SlotsPerStash = 12              -- nombre de cases de chaque cachette (le poids reste la vraie limite)
Config.MenuTimeout = 90                -- secondes de validité du choix d'un emplacement

-- [admin] Règles d'accès
Config.Access = {
    requireKeys = true,          -- civils : il faut les clés du véhicule (propriétaire, clé donnée) pour installer / ouvrir
    policeNeedsTool = true,      -- police : le tournevis est aussi nécessaire pour ouvrir (équité avec les criminels)
    policeInspectPerm = 'veh_inspect',    -- permission de grade police (elyzea_police) pour « Inspecter le véhicule »
    policeOpenPerm = 'veh_cachettes',     -- permission de grade police pour démonter un emplacement et saisir
}

-- [admin] Catégories de véhicules : capacité (kg) de CHAQUE emplacement, indépendante des autres
-- types : door (chaque portière), trunk (coffre), wheel (chaque passage de roue), seat (chaque siège), saddle (sous la selle)
Config.Categories = {
    small  = { label = 'Petits véhicules',        caps = { door = 5,  trunk = 5,  wheel = 5,  seat = 5 } },
    medium = { label = 'Véhicules moyens',        caps = { door = 10, trunk = 15, wheel = 10, seat = 10 } },
    large  = { label = 'SUV et grands véhicules', caps = { door = 15, trunk = 30, wheel = 15, seat = 15 } },
    moto   = { label = 'Motos et scooters',       caps = { saddle = 5 } },
}
Config.CategoryOrder = { 'small', 'medium', 'large', 'moto' }

-- [admin] Catégorie de chaque classe de véhicule GTA (GetVehicleClass) ; 'none' = aucune cachette
Config.ClassCategory = {
    [0] = 'small',    -- Compactes
    [1] = 'medium',   -- Berlines
    [2] = 'large',    -- SUV
    [3] = 'small',    -- Coupés
    [4] = 'medium',   -- Muscle cars
    [5] = 'small',    -- Sportives classiques
    [6] = 'small',    -- Sportives
    [7] = 'small',    -- Supersportives
    [8] = 'moto',     -- Motos et scooters
    [9] = 'large',    -- Tout-terrain
    [10] = 'none',    -- Industriels
    [11] = 'large',   -- Utilitaires
    [12] = 'large',   -- Fourgons
    [13] = 'none',    -- Vélos
    [14] = 'none',    -- Bateaux
    [15] = 'none',    -- Hélicoptères
    [16] = 'none',    -- Avions
    [17] = 'medium',  -- Services (taxis, bus…)
    [18] = 'none',    -- Urgences
    [19] = 'none',    -- Militaires
    [20] = 'large',   -- Commerciaux
    [21] = 'none',    -- Trains
    [22] = 'none',    -- Monoplaces
}
Config.ClassLabels = {
    [0] = 'Compactes', [1] = 'Berlines', [2] = 'SUV', [3] = 'Coupés', [4] = 'Muscle cars', [5] = 'Sportives classiques',
    [6] = 'Sportives', [7] = 'Supersportives', [8] = 'Motos et scooters', [9] = 'Tout-terrain', [10] = 'Industriels',
    [11] = 'Utilitaires', [12] = 'Fourgons', [13] = 'Vélos', [14] = 'Bateaux', [15] = 'Hélicoptères', [16] = 'Avions',
    [17] = 'Services', [18] = 'Urgences', [19] = 'Militaires', [20] = 'Commerciaux', [21] = 'Trains', [22] = 'Monoplaces',
}

-- [admin] Exceptions par modèle (nom de spawn) : catégorie forcée, 'none' pour interdire
-- ex. ['panto'] = 'small', ['baller'] = 'large', ['police'] = 'none'
Config.ModelCategory = {}

-- [admin] Types d'emplacements autorisés (désactiver un type le retire de tous les véhicules)
Config.SlotTypes = { door = true, trunk = true, wheel = true, seat = true, saddle = true }

-- [admin] Mini-jeux : un par type d'emplacement, identique pour la police et les criminels
--  difficulty : 1 (facile) à 5 (très dur) · length : durée (0.6 à 1.6, nombre de fixations) ·
--  maxErrors : erreurs tolérées avant l'échec · timeLimit : secondes avant l'échec
Config.Minigames = {
    door   = { difficulty = 3, length = 1.0, maxErrors = 4, timeLimit = 180 },
    trunk  = { difficulty = 3, length = 1.0, maxErrors = 4, timeLimit = 180 },
    wheel  = { difficulty = 3, length = 1.0, maxErrors = 4, timeLimit = 180 },
    seat   = { difficulty = 3, length = 1.0, maxErrors = 4, timeLimit = 180 },
    saddle = { difficulty = 3, length = 1.0, maxErrors = 4, timeLimit = 180 },
}
-- Anti-triche : une réussite plus rapide que minSeconds × length est refusée par le serveur
Config.MinSeconds = 40

-- [admin] Inspection policière
Config.Inspect = {
    duration = 12000,     -- ms d'inspection (animation + barre de progression)
    light = 'Une petite anomalie semble présente au niveau %s.',
    high  = 'Il semblerait qu\'une intervention ait été effectuée au niveau %s.',
    none  = 'L\'inspection n\'a révélé aucun élément suspect.',
}

-- [admin] Objets interdits dans les cachettes (noms d'objets de l'inventaire)
Config.Blacklist = {}            -- ex. { 'WEAPON_RPG', 'bank_drill' }

-- Remontage du panneau à la fermeture de l'inventaire (ms, animation seule)
Config.CloseDuration = 3500
