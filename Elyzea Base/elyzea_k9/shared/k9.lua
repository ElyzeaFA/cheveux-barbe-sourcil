-- =====================================================================
--  ELYZEA K9 - fonctions partagées (client et serveur)
--  Calculs de progression et effets RÉELS des compétences sur le comportement.
-- =====================================================================
K9 = {}

function K9.Breed(id) for _, b in ipairs(Config.Breeds) do if b.id == id then return b end end end
function K9.Specialty(id) for _, s in ipairs(Config.Specialties) do if s.id == id then return s end end end
function K9.Exercise(id) for _, e in ipairs(Config.Training.exercises) do if e.id == id then return e end end end
function K9.SkillList(side) return Config.Skills[side] or {} end

-- Expérience pour passer du niveau n au suivant
function K9.XpFor(level)
    local P = Config.Progress
    if level >= P.maxLevel then return 0 end
    return math.floor(P.xpBase + P.xpStep * ((level - 1) ^ P.xpPower))
end

-- Plafonds des compétences (selon la spécialité pour la police)
function K9.Caps(dog)
    if dog.side == 'gang' then return Config.GangCaps end
    local s = K9.Specialty(dog.specialty)
    return s and s.caps or { sniff = 3, obey = 5, track = 3, attack = 3 }
end
function K9.UpgradeCost(toLevel) return math.max(1, toLevel - 1) end

local function lerp(a, b, k) return a + (b - a) * k end
local function clamp(v, a, b) return v < a and a or (v > b and b or v) end
K9.clamp = clamp

-- Niveau (1-5) d'une compétence ; pour un chien de gang, l'obéissance découle du niveau général
function K9.Skill(dog, id)
    if id == 'obey' and dog.side == 'gang' then return clamp(1 + math.floor((dog.level or 1) / 7), 1, 5) end
    return clamp(tonumber((dog.skills or {})[id]) or 1, 1, 5)
end

-- Bonus de race (points de %) et de spécialité
local function breedMod(dog, key) local b = K9.Breed(dog.breed) return b and b.mods and b.mods[key] or 0 end
local function specBonus(dog, key)
    if dog.side ~= 'police' then return 0 end
    local s = K9.Specialty(dog.specialty)
    return (s and s.main == key) and 10 or 0
end

-- Effets (valeurs utilisées par le serveur pour décider, et par le client pour jouer le comportement)
function K9.Effects(dog)
    local obey = K9.Skill(dog, 'obey')
    local sniff = K9.Skill(dog, 'sniff')
    local track = K9.Skill(dog, 'track')
    local attack = K9.Skill(dog, 'attack')
    local defense = dog.side == 'gang' and K9.Skill(dog, 'defense') or obey
    local intim = dog.side == 'gang' and K9.Skill(dog, 'intim') or math.max(attack, 2)
    local k = function(lvl) return (lvl - 1) / 4 end
    local e = {}
    -- obéissance : chance d'exécuter un ordre, hésitation avant d'agir
    e.obeyChance = clamp(0.58 + 0.105 * (obey - 1) + (dog.level or 1) * 0.002, 0.5, 0.99)
    e.hesitateMs = math.floor(lerp(2200, 150, k(obey)))
    -- reniflage
    e.sniffChance = clamp(0.40 + 0.12 * (sniff - 1) + (breedMod(dog, 'sniff') + specBonus(dog, 'sniff')) / 100, 0.2, 0.98)
    e.sniffMs = math.floor(lerp(9000, 3500, k(sniff)))
    e.sniffHidden = sniff >= 3                           -- repère les cachettes de véhicule
    e.falsePositive = sniff <= 1 and 0.08 or (sniff == 2 and 0.04 or 0)
    e.drugRadius = lerp(Config.Search.drugRadius[1], Config.Search.drugRadius[2], k(sniff))
    -- pistage
    e.trackChance = clamp(0.45 + 0.11 * (track - 1) + (breedMod(dog, 'track') + specBonus(dog, 'track')) / 100, 0.25, 0.98)
    e.trackError = lerp(28.0, 4.0, k(track))             -- imprécision de la piste (mètres)
    e.trackRefresh = math.floor(lerp(7000, 2000, k(track)))
    e.personRadius = lerp(Config.Search.personRadius[1], Config.Search.personRadius[2], k(track))
    -- attaque
    e.attackChance = clamp(0.42 + 0.12 * (attack - 1) + (breedMod(dog, 'attack') + specBonus(dog, 'attack')) / 100, 0.2, 0.97)
    e.attackRefuseArmed = attack <= 1 and obey <= 2       -- un chien peu dressé a peur d'une cible armée
    e.holdSeconds = math.floor(lerp(Config.Attack.holdSeconds[1], Config.Attack.holdSeconds[2], k(attack)))
    -- défense
    e.defendRadius = lerp(Config.Defend.radius[1], Config.Defend.radius[2], k(defense)) * (1 + breedMod(dog, 'defense') / 100)
    e.defendReactionMs = math.floor(lerp(Config.Defend.reactionMs[1], Config.Defend.reactionMs[2], k(defense)))
    e.defendChance = clamp(0.5 + 0.12 * (defense - 1) + breedMod(dog, 'defense') / 100, 0.3, 0.98)
    -- intimidation
    e.intimLevel = clamp(intim + (breedMod(dog, 'intim') >= 6 and 1 or 0), 1, 5)
    e.intimSeconds = math.floor(lerp(6, 14, k(intim)))
    -- vitesse de la race
    local b = K9.Breed(dog.breed)
    e.speed = b and b.mods and b.mods.speed or 1.0
    e.healthMul = b and b.mods and b.mods.health or 1.0
    return e
end

-- Ordres : id, libellé, cible (none | player | vehicle), côtés, compétence utile
K9.Orders = {
    { id = 'follow',   label = 'Au pied (suivre)',     target = 'none' },
    { id = 'stay',     label = 'Reste',                target = 'none' },
    { id = 'sit',      label = 'Assis',                target = 'none' },
    { id = 'lie',      label = 'Couché',               target = 'none' },
    { id = 'come',     label = 'Viens (rappel)',       target = 'none' },
    { id = 'search',   label = 'Fouiller la zone',     target = 'none', police = true },
    { id = 'defend',   label = 'Défends-moi',          target = 'none' },
    { id = 'sniffp',   label = 'Renifler la personne', target = 'player', police = true },
    { id = 'sniffv',   label = 'Renifler le véhicule', target = 'vehicle', police = true },
    { id = 'bark',     label = 'Aboyer',               target = 'player' },
    { id = 'intim',    label = 'Intimider',            target = 'player' },
    { id = 'attack',   label = 'Attaquer',             target = 'player' },
    { id = 'takedown', label = 'Faire tomber',         target = 'player' },
    { id = 'track',    label = 'Pister',               target = 'player', police = true },
}
function K9.Order(id) for _, o in ipairs(K9.Orders) do if o.id == id then return o end end end
function K9.OrdersFor(side)
    local out = {}
    for _, o in ipairs(K9.Orders) do if side == 'police' or not o.police then out[#out + 1] = o end end
    return out
end

-- Objet = stupéfiant ?
function K9.IsDrug(name)
    if type(name) ~= 'string' then return false end
    local D = Config.Drugs
    for _, x in ipairs(D.exclude or {}) do if x == name then return false end end
    for _, x in ipairs(D.extra or {}) do if x == name then return true end end
    for _, p in ipairs(D.prefixes or {}) do if name:sub(1, #p) == p then return true end end
    return false
end
