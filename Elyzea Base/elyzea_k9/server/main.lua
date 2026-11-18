-- =====================================================================
--  ELYZEA K9 - SERVEUR
--  Données des chiens, permissions, progression, ordres (tout est validé ici).
--  Le client ne fait que jouer le comportement que le serveur autorise.
-- =====================================================================
local core = exports.elyzea_core
K9S = { Dogs = {}, Active = {}, Busy = {}, Ready = false }
local Dogs, Active = K9S.Dogs, K9S.Active

-- ---------------------------------------------------------------------
--  Base de données
-- ---------------------------------------------------------------------
local SQL = {
    [[CREATE TABLE IF NOT EXISTS `elyzea_k9_dogs` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `owner` VARCHAR(64) NOT NULL,
        `side` VARCHAR(8) NOT NULL,
        `group_name` VARCHAR(64) NULL,
        `name` VARCHAR(24) NOT NULL,
        `breed` VARCHAR(24) NOT NULL,
        `specialty` VARCHAR(16) NULL,
        `level` INT NOT NULL DEFAULT 1,
        `xp` INT NOT NULL DEFAULT 0,
        `points` INT NOT NULL DEFAULT 0,
        `skills` TEXT NOT NULL,
        `health` INT NOT NULL DEFAULT 100,
        `injured_until` INT NOT NULL DEFAULT 0,
        `stats` TEXT NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        UNIQUE KEY `owner_side` (`owner`, `side`)
    )]],
    [[CREATE TABLE IF NOT EXISTS `elyzea_k9_history` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `dog_id` INT NOT NULL,
        `kind` VARCHAR(12) NOT NULL,
        `label` VARCHAR(120) NOT NULL,
        `xp` INT NOT NULL DEFAULT 0,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `dog` (`dog_id`, `id`)
    )]],
}
CreateThread(function()
    for _, q in ipairs(SQL) do
        local ok, err = pcall(MySQL.query.await, q)
        if not ok then print('^1[elyzea_k9] table non créée : ' .. tostring(err) .. '^0') end
    end
    K9S.Ready = true
    print('^2[elyzea_k9] prêt : chiens de la police et des gangs.^0')
end)

-- ---------------------------------------------------------------------
--  Outils
-- ---------------------------------------------------------------------
local function int(v, d) v = tonumber(v) if not v or v ~= v then return d end return math.floor(v) end
local function now() return os.time() end
local function today() return os.date('%Y-%m-%d') end
local function decode(s, d) local ok, v = pcall(json.decode, s or '') return ok and type(v) == 'table' and v or d end
function K9S.Cid(src) local ok, cid = pcall(function() return core:GetCitizenId(src) end) return ok and cid or nil end
function K9S.Notify(src, text, kind) TriggerClientEvent('elyzea_k9:client:notify', src, text, kind or 'inform') end
local Notify = K9S.Notify

-- Anti-spam : une action par clé et par joueur toutes les ms millisecondes
local Last = {}
function K9S.TooFast(src, key, ms)
    local k, t = src .. ':' .. key, GetGameTimer()
    if Last[k] and t - Last[k] < ms then return true end
    Last[k] = t
    return false
end
local TooFast = K9S.TooFast

local function Ped(src) local p = GetPlayerPed(src) return (p and p ~= 0) and p or nil end
function K9S.Coords(src) local p = Ped(src) return p and GetEntityCoords(p) or nil end
local function Dist(a, b) return (a and b) and #(a - b) or 1e9 end

-- ---------------------------------------------------------------------
--  Permissions
-- ---------------------------------------------------------------------
local function res(name) return GetResourceState(name) == 'started' end

-- side = 'police' | 'gang' ; duty : exiger le service (police)
-- → true, info  |  false, raison
function K9S.Access(src, side, duty)
    if side == 'police' then
        if not Config.Police.enabled then return false, 'Unité cynophile désactivée.' end
        if not res('elyzea_police') then return false, 'Police indisponible.' end
        local ok, has = pcall(function() return exports.elyzea_police:HasPermission(src, Config.Police.permission) end)
        if not ok or not has then return false, 'Ton grade n\'a pas accès à l\'unité cynophile.' end
        if duty and Config.Police.requireDuty then
            local ok2, on = pcall(function() return exports.elyzea_police:IsOnDuty(src) end)
            if not ok2 or not on then return false, 'Prends ton service d\'abord.' end
        end
        return true, { group = 'police' }
    elseif side == 'gang' then
        if not Config.Gang.enabled then return false, 'Chiens de gang désactivés.' end
        if not res('elyzea_illegal') then return false, 'Groupes indisponibles.' end
        local ok, g = pcall(function() return exports.elyzea_illegal:GetPlayerGroup(src) end)
        if not ok or type(g) ~= 'table' then return false, 'Tu ne fais partie d\'aucun groupe.' end
        if not (Config.Gang.groupTypes or {})[g.type] then return false, 'Ton groupe ne peut pas avoir de chiens.' end
        local ok2, has = pcall(function() return exports.elyzea_illegal:HasGroupPermission(src, Config.Gang.permission) end)
        if not ok2 or not has then return false, 'Ton grade n\'a pas accès aux chiens du groupe.' end
        return true, { group = g.name, groupLabel = g.label, color = g.color }
    end
    return false, 'Accès refusé.'
end
local Access = K9S.Access

-- ---------------------------------------------------------------------
--  Chiens (cache + base)
-- ---------------------------------------------------------------------
local function Row2Dog(r)
    if not r then return nil end
    local d = { id = int(r.id, 0), owner = r.owner, side = r.side, group = r.group_name, name = r.name, breed = r.breed, specialty = r.specialty,
        level = int(r.level, 1), xp = int(r.xp, 0), points = int(r.points, 0), skills = decode(r.skills, {}), health = int(r.health, 100),
        injured_until = int(r.injured_until, 0), stats = decode(r.stats, {}) }
    d.stats.trained = d.stats.trained or {}
    d.stats.missions = d.stats.missions or {}
    d.stats.ex = d.stats.ex or {}
    return d
end
function K9S.Load(cid, side)
    if not cid then return nil end
    for _, d in pairs(Dogs) do if d.owner == cid and d.side == side then return d end end
    local d = Row2Dog(MySQL.single.await('SELECT * FROM `elyzea_k9_dogs` WHERE `owner` = ? AND `side` = ?', { cid, side }))
    if d then Dogs[d.id] = d end
    return d
end
function K9S.Save(d)
    MySQL.update.await([[UPDATE `elyzea_k9_dogs` SET `name` = ?, `level` = ?, `xp` = ?, `points` = ?, `skills` = ?, `health` = ?,
        `injured_until` = ?, `stats` = ?, `group_name` = ? WHERE `id` = ?]],
        { d.name, d.level, d.xp, d.points, json.encode(d.skills), d.health, d.injured_until, json.encode(d.stats), d.group, d.id })
end
function K9S.History(d, kind, label, xp)
    MySQL.insert.await('INSERT INTO `elyzea_k9_history` (`dog_id`, `kind`, `label`, `xp`) VALUES (?, ?, ?, ?)', { d.id, kind, label:sub(1, 120), int(xp, 0) })
    MySQL.update.await([[DELETE FROM `elyzea_k9_history` WHERE `dog_id` = ? AND `id` NOT IN
        (SELECT `id` FROM (SELECT `id` FROM `elyzea_k9_history` WHERE `dog_id` = ? ORDER BY `id` DESC LIMIT ?) x)]], { d.id, d.id, Config.Progress.historyKeep })
end

-- Compteurs du jour (anti-farm)
local function Day(d)
    if d.stats.day ~= today() then d.stats.day, d.stats.trainXp, d.stats.missionXp = today(), 0, 0 end
end

-- Ajoute de l'expérience (kind = 'train' | 'mission') ; renvoie l'XP réellement gagnée
function K9S.AddXp(src, d, amount, kind, label)
    Day(d)
    amount = math.max(0, int(amount, 0))
    local cap = kind == 'train' and Config.Training.dailyCap or Config.MissionXp.dailyCap
    local field = kind == 'train' and 'trainXp' or 'missionXp'
    amount = math.min(amount, math.max(0, cap - (d.stats[field] or 0)))
    local maxL = Config.Progress.maxLevel
    if amount <= 0 or d.level >= maxL then
        if amount <= 0 and src then Notify(src, ('%s a assez travaillé aujourd\'hui : plus d\'expérience pour ce type d\'activité.'):format(d.name), 'inform') end
        K9S.Save(d)
        return 0
    end
    d.stats[field] = (d.stats[field] or 0) + amount
    d.xp = d.xp + amount
    local ups = 0
    while d.level < maxL and d.xp >= K9.XpFor(d.level) do
        d.xp = d.xp - K9.XpFor(d.level)
        d.level = d.level + 1
        d.points = d.points + Config.Progress.pointsPerLevel + (Config.Progress.bonusPoints[d.level] or 0)
        ups = ups + 1
    end
    if d.level >= maxL then d.xp = 0 end
    K9S.History(d, kind, label, amount)
    if ups > 0 then
        K9S.History(d, 'level', ('Niveau %d atteint'):format(d.level), 0)
        if src then
            Notify(src, ('%s passe au niveau %d ! Point(s) de compétence disponible(s) : %d.'):format(d.name, d.level, d.points), 'success')
            TriggerClientEvent('elyzea_k9:client:levelUp', src, d.side, d.level)
        end
    end
    K9S.Save(d)
    if src then TriggerClientEvent('elyzea_k9:client:dogUpdate', src, K9S.Public(d)) end
    return amount
end

-- Données envoyées au joueur (rien de secret)
function K9S.Public(d)
    if not d then return nil end
    Day(d)
    local skills = {}
    local caps = K9.Caps(d)
    for _, s in ipairs(K9.SkillList(d.side)) do
        local lvl = K9.Skill(d, s.id)
        skills[#skills + 1] = { id = s.id, label = s.label, level = lvl, cap = caps[s.id] or 5, levels = s.levels,
            cost = lvl < (caps[s.id] or 5) and K9.UpgradeCost(lvl + 1) or nil, trained = d.stats.trained[s.id] or 0 }
    end
    local ex = {}
    local t = now()
    for _, e in ipairs(Config.Training.exercises) do
        if e.sides[d.side] then
            local last = d.stats.ex[e.id]
            local wait = last and math.max(0, (last.t + Config.Training.cooldownMinutes * 60) - t) or 0
            local rep = (last and t - last.t < 3600) and (last.n or 1) or 0
            ex[#ex + 1] = { id = e.id, label = e.label, skill = e.skill, desc = e.desc, seconds = e.seconds,
                xp = math.floor(e.xp * (Config.Training.repeatPenalty ^ rep)), wait = wait }
        end
    end
    local hist = MySQL.query.await('SELECT `kind`, `label`, `xp`, UNIX_TIMESTAMP(`created_at`) AS `ts` FROM `elyzea_k9_history` WHERE `dog_id` = ? ORDER BY `id` DESC LIMIT 20', { d.id }) or {}
    return { id = d.id, side = d.side, name = d.name, breed = d.breed, specialty = d.specialty, level = d.level, xp = d.xp,
        xpNext = K9.XpFor(d.level), maxLevel = Config.Progress.maxLevel, points = d.points, skills = skills, health = d.health,
        injured = d.injured_until > t and (d.injured_until - t) or 0, active = Active[d.id] ~= nil, exercises = ex, history = hist,
        missions = d.stats.missions, trainXp = d.stats.trainXp or 0, missionXp = d.stats.missionXp or 0,
        trainCap = Config.Training.dailyCap, missionCap = Config.MissionXp.dailyCap, effects = K9.Effects(d) }
end

-- ---------------------------------------------------------------------
--  Menu : ce que le joueur peut voir / faire
-- ---------------------------------------------------------------------
Ely.callback.register('elyzea_k9:open', function(src)
    local cid = K9S.Cid(src)
    if not cid then return { ok = false, error = 'Personnage non chargé.' } end
    local out = { ok = true, sides = {} }
    for _, side in ipairs({ 'police', 'gang' }) do
        local ok, info = Access(src, side, false)
        if ok then
            local d = K9S.Load(cid, side)
            local dutyOk, dutyErr = Access(src, side, true)
            out.sides[#out.sides + 1] = { side = side, info = info, duty = dutyOk, dutyError = not dutyOk and dutyErr or nil, dog = K9S.Public(d) }
        end
    end
    if #out.sides == 0 then return { ok = false, error = 'Tu n\'as accès à aucun chien (unité cynophile de la police ou groupe autorisé).' } end
    local breeds = {}
    for _, b in ipairs(Config.Breeds) do
        breeds[#breeds + 1] = { id = b.id, label = b.label, model = b.model, addon = b.addon == true, desc = b.desc, traits = b.traits, sides = b.sides }
    end
    out.breeds, out.specialties, out.skills, out.orders = breeds, Config.Specialties, Config.Skills, K9.Orders
    out.gangStart = Config.GangStart
    return out
end)

local function ValidName(n)
    n = tostring(n or ''):gsub('[%c<>"\\]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #n < 2 or #n > 18 then return nil end
    return n
end

Ely.callback.register('elyzea_k9:create', function(src, side, breedId, specialty, name)
    if TooFast(src, 'create', 2000) then return false, 'Patiente un instant.' end
    local ok, info = Access(src, side, false)
    if not ok then return false, info end
    local cid = K9S.Cid(src)
    if K9S.Load(cid, side) then return false, 'Tu as déjà un chien.' end
    local b = K9.Breed(breedId)
    if not b or not b.sides[side] then return false, 'Race indisponible.' end
    name = ValidName(name)
    if not name then return false, 'Nom : 2 à 18 caractères.' end
    local skills
    if side == 'police' then
        local s = K9.Specialty(specialty)
        if not s then return false, 'Choisis une spécialité.' end
        skills = {}
        for k, v in pairs(s.start) do skills[k] = v end
    else
        specialty = nil
        skills = {}
        for k, v in pairs(Config.GangStart) do skills[k] = v end
    end
    local id = MySQL.insert.await([[INSERT INTO `elyzea_k9_dogs` (`owner`, `side`, `group_name`, `name`, `breed`, `specialty`, `skills`, `stats`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)]], { cid, side, info.group, name, b.id, specialty, json.encode(skills), json.encode({ trained = {}, missions = {}, ex = {} }) })
    if not id then return false, 'Création impossible.' end
    local d = K9S.Load(cid, side)
    K9S.History(d, 'info', ('%s rejoint %s (%s)'):format(name, side == 'police' and 'l\'unité cynophile' or (info.groupLabel or 'le groupe'), b.label), 0)
    return true, K9S.Public(d)
end)

Ely.callback.register('elyzea_k9:rename', function(src, side, name)
    if TooFast(src, 'rename', 1500) then return false, 'Patiente un instant.' end
    local ok, err = Access(src, side, false)
    if not ok then return false, err end
    local d = K9S.Load(K9S.Cid(src), side)
    if not d then return false, 'Aucun chien.' end
    name = ValidName(name)
    if not name then return false, 'Nom : 2 à 18 caractères.' end
    d.name = name
    K9S.Save(d)
    if Active[d.id] then TriggerClientEvent('elyzea_k9:client:renamed', src, side, name) end
    return true, K9S.Public(d)
end)

-- Améliorer une compétence avec les points du chien
Ely.callback.register('elyzea_k9:upgrade', function(src, side, skill)
    if TooFast(src, 'upgrade', 600) then return false, 'Patiente un instant.' end
    local ok, err = Access(src, side, false)
    if not ok then return false, err end
    local d = K9S.Load(K9S.Cid(src), side)
    if not d then return false, 'Aucun chien.' end
    local valid = false
    for _, s in ipairs(K9.SkillList(side)) do if s.id == skill then valid = true end end
    if not valid then return false, 'Compétence inconnue.' end
    local lvl = K9.Skill(d, skill)
    local cap = K9.Caps(d)[skill] or 5
    if lvl >= cap then return false, side == 'police' and 'Niveau maximal pour cette spécialité.' or 'Niveau maximal.' end
    local cost = K9.UpgradeCost(lvl + 1)
    if d.points < cost then return false, ('Il faut %d point(s).'):format(cost) end
    d.points = d.points - cost
    d.skills[skill] = lvl + 1
    local label
    for _, s in ipairs(K9.SkillList(side)) do if s.id == skill then label = s.label end end
    K9S.History(d, 'skill', ('%s : niveau %d'):format(label, lvl + 1), 0)
    K9S.Save(d)
    if Active[d.id] then TriggerClientEvent('elyzea_k9:client:effects', src, side, K9.Effects(d)) end
    return true, K9S.Public(d)
end)

-- ---------------------------------------------------------------------
--  Sortir / renvoyer le chien (une seule entité par chien, jamais de doublon)
-- ---------------------------------------------------------------------
local Tokens = {}
local function DeleteDogEntity(netId)
    local ent = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if ent and ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
end
function K9S.Despawn(dogId, save)
    local a = Active[dogId]
    if not a then return end
    Active[dogId] = nil
    if a.netId then DeleteDogEntity(a.netId) end
    local d = Dogs[dogId]
    if d and save ~= false then K9S.Save(d) end
    if GetPlayerName(a.src) then TriggerClientEvent('elyzea_k9:client:despawned', a.src, a.side) end
end

Ely.callback.register('elyzea_k9:requestSpawn', function(src, side)
    if TooFast(src, 'spawn', 3000) then return false, 'Patiente un instant.' end
    local ok, err = Access(src, side, true)
    if not ok then return false, err end
    local d = K9S.Load(K9S.Cid(src), side)
    if not d then return false, 'Aucun chien.' end
    if d.injured_until > now() then return false, ('%s est blessé : encore %d min de repos.'):format(d.name, math.ceil((d.injured_until - now()) / 60)) end
    local ped = Ped(src)
    if not ped or GetVehiclePedIsIn(ped, false) ~= 0 then return false, 'Descends du véhicule pour sortir ton chien.' end
    -- un seul chien sorti par joueur (l'autre côté est rangé) et jamais deux fois le même
    for id, a in pairs(Active) do if a.src == src and id ~= d.id then K9S.Despawn(id) end end
    if Active[d.id] then K9S.Despawn(d.id) end
    local b = K9.Breed(d.breed)
    local token = ('%d-%d-%d'):format(src, d.id, math.random(100000, 999999))
    Tokens[src] = { token = token, dog = d.id, t = GetGameTimer(), model = b and b.model or 'a_c_shepherd' }
    return true, { token = token, model = Tokens[src].model, dog = K9S.Public(d), effects = K9.Effects(d), healthFloor = Config.Attack.healthFloor }
end)

RegisterNetEvent('elyzea_k9:server:spawned', function(token, netId)
    local src = source
    local t = Tokens[src]
    Tokens[src] = nil
    if not t or t.token ~= token or GetGameTimer() - t.t > 20000 then return DeleteDogEntity(netId) end
    local ent = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not ent or ent == 0 or not DoesEntityExist(ent) or GetEntityModel(ent) ~= joaat(t.model) then
        DeleteDogEntity(netId)
        return Notify(src, 'Le chien n\'a pas pu sortir (modèle refusé).', 'error')
    end
    if NetworkGetEntityOwner(ent) ~= src then DeleteDogEntity(netId) return end
    local d = Dogs[t.dog]
    if not d then DeleteDogEntity(netId) return end
    if Active[d.id] then K9S.Despawn(d.id) end
    Active[d.id] = { src = src, side = d.side, netId = tonumber(netId), t = now(), mode = 'follow' }
    Entity(ent).state:set('k9', { id = d.id, side = d.side, owner = src, name = d.name }, true)
end)

Ely.callback.register('elyzea_k9:store', function(src, side)
    local d = K9S.Load(K9S.Cid(src), side)
    if not d or not Active[d.id] or Active[d.id].src ~= src then return false end
    K9S.Despawn(d.id)
    return true
end)

-- Santé envoyée par le client du maître ; dead = chien mis hors de combat
RegisterNetEvent('elyzea_k9:server:health', function(side, pct, dead)
    local src = source
    if TooFast(src, 'health', 1500) and not dead then return end
    local d = K9S.Load(K9S.Cid(src), side)
    if not d or not Active[d.id] or Active[d.id].src ~= src then return end
    d.health = math.max(0, math.min(100, int(pct, d.health)))
    if dead then
        d.health = 100
        d.injured_until = now() + Config.Health.injuredMinutes * 60
        K9S.History(d, 'info', 'Blessé en intervention', 0)
        Notify(src, ('%s est blessé : il est ramené au chenil (%d min de soins).'):format(d.name, Config.Health.injuredMinutes), 'error')
        K9S.Despawn(d.id)
    end
end)

-- Le chien a disparu côté client (entité supprimée par le jeu) : on libère
RegisterNetEvent('elyzea_k9:server:lost', function(side)
    local src = source
    local d = K9S.Load(K9S.Cid(src), side)
    if d and Active[d.id] and Active[d.id].src == src then K9S.Despawn(d.id) end
end)

-- Déconnexion, changement de personnage, arrêt : le chien est rangé (progression sauvegardée)
local function onLeave(src)
    for id, a in pairs(Active) do if a.src == src then K9S.Despawn(id) end end
    Tokens[src] = nil
    K9S.Busy[src] = nil
    local s = tostring(src) .. ':'
    for k in pairs(Last) do if k:sub(1, #s) == s then Last[k] = nil end end
    -- cache libéré (les données restent en base)
    local cid = K9S.Cid(src)
    for id, d in pairs(Dogs) do if not Active[id] and (d.owner == cid) then Dogs[id] = nil end end
end
AddEventHandler('playerDropped', function() onLeave(source) end)
AddEventHandler('elyzea:server:playerUnloaded', function(src) if tonumber(src) then onLeave(tonumber(src)) end end)
AddEventHandler('onResourceStop', function(r)
    if r ~= GetCurrentResourceName() then return end
    for id in pairs(Active) do K9S.Despawn(id) end
end)

-- Chien actif d'un joueur (ordres) : vérifie la propriété, l'entité et la distance au maître
function K9S.ActiveDog(src, side)
    local d = K9S.Load(K9S.Cid(src), side)
    if not d then return nil, 'Aucun chien.' end
    local a = Active[d.id]
    if not a or a.src ~= src then return nil, ('%s n\'est pas sorti.'):format(d.name) end
    local ent = NetworkGetEntityFromNetworkId(a.netId or 0)
    if not ent or ent == 0 or not DoesEntityExist(ent) then K9S.Despawn(d.id) return nil, 'Ton chien a disparu.' end
    local owner = K9S.Coords(src)
    if Dist(GetEntityCoords(ent), owner) > Config.Orders.dogLeash then return nil, ('%s est trop loin de toi.'):format(d.name) end
    return d, a, ent
end

-- Export pour les autres ressources (lecture seule)
exports('GetActiveDog', function(src)
    for id, a in pairs(Active) do if a.src == tonumber(src) then local d = Dogs[id] return d and { id = d.id, side = d.side, name = d.name, netId = a.netId } end end
end)
