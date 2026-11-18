-- =====================================================================
--  ELYZEA ENTREPRISES - configuration
--  Les entreprises sont créées PAR LES JOUEURS depuis le téléphone
--  (Elyzea Aura › appli « Entreprises » › « Lancer mon Business ») et gardées en base.
--  Ici : le prix, les limites, les spécialités et les valeurs de départ.
-- =====================================================================
Config = {}

Config.Keys = {
    menu = 'F6',     -- sort le téléphone de service (elyzea_jobphone) ; sans lui : la tablette
}

-- Création d'une entreprise
Config.Create = {
    price = 25000,              -- payé depuis le compte en BANQUE du joueur
    startBalance = 0,           -- argent mis sur le compte de l'entreprise à sa création (0 = rien, le patron dépose ensuite)
    nameMin = 3, nameMax = 40,
    descriptionMax = 600,
    maxPerOwner = 1,            -- entreprises actives qu'un même personnage peut posséder
    cooldownMinutes = 30,       -- délai avant de pouvoir recréer une entreprise après en avoir dissous une
    -- Mots refusés dans le nom (en plus des noms déjà pris et des métiers officiels)
    forbiddenNames = { 'police', 'lspd', 'bcso', 'sheriff', 'fbi', 'ems', 'sams', 'hopital', 'hôpital', 'gouvernement', 'mairie', 'staff', 'admin' },
}

-- Spécialités proposées (le joueur en choisit une ; affichée sur la vitrine et sert au filtre)
Config.Specialties = {
    { id = 'commerce',     label = 'Commerce',            icon = '🛍️' },
    { id = 'restauration', label = 'Restauration',        icon = '🍽️' },
    { id = 'transport',    label = 'Transport et livraison', icon = '🚚' },
    { id = 'automobile',   label = 'Automobile',          icon = '🚗' },
    { id = 'securite',     label = 'Sécurité privée',     icon = '🛡️' },
    { id = 'immobilier',   label = 'Immobilier',          icon = '🏠' },
    { id = 'btp',          label = 'BTP et artisanat',    icon = '🔨' },
    { id = 'mode',         label = 'Mode et beauté',      icon = '👗' },
    { id = 'evenementiel', label = 'Événementiel',        icon = '🎉' },
    { id = 'medias',       label = 'Médias et communication', icon = '📣' },
    { id = 'juridique',    label = 'Juridique et conseil', icon = '⚖️' },
    { id = 'sante',        label = 'Santé et bien-être',  icon = '💆' },
    { id = 'loisirs',      label = 'Loisirs et sport',    icon = '🎳' },
    { id = 'technologie',  label = 'Technologie',         icon = '💻' },
    { id = 'services',     label = 'Services à la personne', icon = '🤝' },
    { id = 'autre',        label = 'Autre',               icon = '🏢' },
}

-- Couleurs proposées pour la vitrine (couleur libre aussi acceptée : #rrggbb)
Config.Colors = { '#7c6cff', '#3b82f6', '#06b6d4', '#10b981', '#84cc16', '#eab308', '#f97316', '#ef4444', '#ec4899', '#a855f7', '#64748b' }

-- Logo : image hébergée en https (galerie du téléphone, lien, ou import depuis l'ordinateur)
Config.Logo = {
    -- Sites autorisés pour un logo collé en lien (vide = tout lien https). Les logos importés
    -- depuis l'ordinateur passent par l'hébergeur de l'appareil photo d'Elyzea Aura (Fivemanage).
    allowedHosts = {},
    -- Import depuis l'ordinateur : page web servie par CE serveur (http://IP:PORT/elyzea_entreprises/logo)
    import = {
        enabled = true,
        codeMinutes = 15,
        maxMb = 5,
        -- Adresse publique du serveur (ex. 'http://123.45.67.89:30120'). Vide = la même que l'import
        -- de musique d'ElyFy (Config.ElyFy.Import.Url, ou l'adresse trouvée au démarrage).
        url = '',
    },
}

Config.Recruit = { distance = 5.0, timeout = 30, cooldown = 8 }
Config.Pay = { maxRate = 100000 }
Config.Money = { maxDeposit = 10000000 }

Config.Statuses = {
    { id = 'available', label = 'Disponible',     color = '#22c55e' },
    { id = 'busy',      label = 'Occupé',         color = '#f59e0b' },
    { id = 'meeting',   label = 'En rendez-vous', color = '#3b82f6' },
    { id = 'road',      label = 'En déplacement', color = '#a855f7' },
    { id = 'break',     label = 'En pause',       color = '#94a3b8' },
}

-- Grades créés pour chaque nouvelle entreprise (modifiables ensuite dans la tablette :
-- noms, niveaux, salaires et permissions). Le créateur reçoit le grade le plus haut.
Config.DefaultGrades = {
    { name = 'Employé',     level = 1, salary = 0, default = true, perms = { 'duty', 'tablet' } },
    { name = 'Responsable', level = 2, salary = 0, perms = { 'duty', 'tablet', 'open', 'recruit', 'employees_view', 'history_view', 'direction' } },
    { name = 'Directeur',   level = 3, salary = 0, perms = { 'duty', 'tablet', 'open', 'profile', 'direction', 'recruit', 'employees_view', 'employees_edit',
        'promote', 'demote', 'fire', 'history_view', 'finance', 'deposit', 'payroll' } },
    { name = 'Patron',      level = 4, salary = 0, perms = 'all' },
}
