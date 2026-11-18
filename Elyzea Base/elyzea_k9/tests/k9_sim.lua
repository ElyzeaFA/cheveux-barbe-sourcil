-- =====================================================================
--  ELYZEA K9 : vrais fichiers serveur (config, shared, server/*) sur une vraie base MariaDB
--  PHASE 1 : police + gang + civils. PHASE 2 : redémarrage (même base).
-- =====================================================================
--@@MOCKS@@
local function permissive(env)
    return setmetatable(env, { __index = function(_, k)
        local v = rawget(_G, k)
        if v ~= nil then return v end
        if type(k) == 'string' and k:match('^%u') then return function() end end
    end })
end
MySQL.ready = function(fn) fn() end
function CreateThread(fn) local co = coroutine.create(fn) local ok, err = coroutine.resume(co) if not ok then error(err) end end
Citizen = { CreateThread = CreateThread, Wait = function() end }
function Wait() if coroutine.isyieldable() then coroutine.yield() end end
MySQL.update.await = function(s, a) return py_update(s, a) end
Clock = 1000000
NOW = 1800000000
-- monde : joueurs (src -> ped = src), entités
POS = { [1] = vector3(0, 0, 30), [2] = vector3(50, 50, 30), [3] = vector3(5, 0, 30), [4] = vector3(2, 2, 30), [5] = vector3(8, 1, 30) }
HP = { [1] = 200, [2] = 200, [3] = 200, [4] = 200, [5] = 200 }
WEAPON = {}
INVEH = {}
ENTS = {}          -- [ent] = { pos, model, owner, type, plate, speed }
NETS = {}          -- [netId] = ent
CIDS = { [1] = 'COP1', [2] = 'GANG1', [3] = 'CIV1', [4] = 'COP2', [5] = 'CIV2' }
PERM = { [1] = true, [4] = false }
DUTY = { [1] = true, [4] = true }
GROUP = { [2] = { name = 'ballas', label = 'Ballas', type = 'gang', color = '#a0f' } }
GPERM = { [2] = true }
INV = { [3] = { { name = 'cokebaggy', count = 3 } }, [5] = { { name = 'water', count = 1 } } }
TRUNK = {}         -- [plate] = items
HIDDEN = {}        -- [plate] = { { slot, label, items } }
DROPS = {}
CLIENTEV = {}
RNGV = 0.0
local env = permissive({})
env.math = setmetatable({ random = function(a, b) if a then return a end return RNGV end }, { __index = math })
env.os = setmetatable({ time = function(t) if t then return os.time(t) end return NOW end, date = function(f) return os.date(f, NOW) end }, { __index = os })
env.GetGameTimer = function() return Clock end
env.GetPlayerName = function(s) return CIDS[tonumber(s)] and ('J' .. s) or nil end
env.GetPlayers = function() local t = {} for s in pairs(CIDS) do t[#t + 1] = tostring(s) end return t end
env.GetPlayerPed = function(s) s = tonumber(s) return CIDS[s] and s or 0 end
env.GetEntityCoords = function(e) if ENTS[e] then return ENTS[e].pos end return POS[e] or vector3(0, 0, 0) end
env.GetEntityHealth = function(p) return HP[p] or 200 end
env.GetSelectedPedWeapon = function(p) return WEAPON[p] or joaat('WEAPON_UNARMED') end
env.GetVehiclePedIsIn = function(p) return INVEH[p] or 0 end
env.NetworkGetEntityFromNetworkId = function(n) return NETS[tonumber(n)] or 0 end
env.NetworkGetNetworkIdFromEntity = function(e) for n, x in pairs(NETS) do if x == e then return n end end return 0 end
env.DoesEntityExist = function(e) return ENTS[e] ~= nil end
env.DeleteEntity = function(e) ENTS[e] = nil for n, x in pairs(NETS) do if x == e then NETS[n] = nil end end end
env.GetEntityModel = function(e) return ENTS[e] and ENTS[e].model or 0 end
env.NetworkGetEntityOwner = function(e) if ENTS[e] then return ENTS[e].owner end return e end
env.GetEntityType = function(e) return ENTS[e] and ENTS[e].type or 1 end
env.GetVehicleNumberPlateText = function(e) return ENTS[e] and ENTS[e].plate or '' end
env.GetPedInVehicleSeat = function(veh, seat) for p, v in pairs(INVEH) do if v == veh and seat == -1 then return p end end return 0 end
env.IsPedAPlayer = function(p) return CIDS[p] ~= nil end
env.GetAllVehicles = function() local t = {} for e, x in pairs(ENTS) do if x.type == 2 then t[#t + 1] = e end end return t end
env.GetEntitySpeed = function(e) return ENTS[e] and ENTS[e].speed or 0 end
env.Entity = function(e) return { state = { set = function(_, k, v) ENTS[e].state = v end } } end
env.TriggerClientEvent = function(n, s, ...) CLIENTEV[#CLIENTEV + 1] = { n = n, s = s, a = { ... } } end
env.GetResourceState = function() return 'started' end
env.GetCurrentResourceName = function() return 'elyzea_k9' end
CB, NET, HANDLERS = {}, {}, {}
env.Ely = { callback = { register = function(n, fn) CB[n] = fn end } }
env.RegisterNetEvent = function(n, fn) if fn then NET[n] = fn end end
env.AddEventHandler = function(n, fn) HANDLERS[n] = HANDLERS[n] or {} table.insert(HANDLERS[n], fn) end
EXPORTS = {}
env.exports = setmetatable({}, { __call = function(_, n, fn) EXPORTS[n] = fn end, __index = function(_, res)
    local R = {
        elyzea_core = { GetCitizenId = function(_, s) return CIDS[tonumber(s)] end },
        elyzea_police = { HasPermission = function(_, s, p) return p == 'k9' and PERM[tonumber(s)] == true end, IsOnDuty = function(_, s) return DUTY[tonumber(s)] == true end },
        elyzea_illegal = { GetPlayerGroup = function(_, s) return GROUP[tonumber(s)] end, HasGroupPermission = function(_, s, p) return p == 'k9' and GPERM[tonumber(s)] == true end },
        elyzea_inventory = { GetInventoryItems = function(_, s) return INV[tonumber(s)] or {} end,
            GetStashItems = function(_, id) local plate = id:match('^trunk:(.+)$') return plate and TRUNK[plate] or {} end,
            GetDropsInRadius = function(_, c, r) local out = {} for _, d in ipairs(DROPS) do if #(d.coords - c) <= r then out[#out + 1] = d end end return out end },
        elyzea_cachettes = { GetVehicleHiddenItems = function(_, plate) return HIDDEN[plate] or {} end },
    }
    return R[res] or setmetatable({}, { __index = function() return function() end end })
end })
for _, f in ipairs({ 'elyzea_k9/config.lua', 'elyzea_k9/shared/k9.lua', 'elyzea_k9/server/main.lua', 'elyzea_k9/server/orders.lua', 'elyzea_k9/server/training.lua' }) do
    -- hachages FiveM `NOM` → joaat('NOM')
    assert(load((py_read(f):gsub('`(%u[%u%d_]+)`', 'joaat("%1")')), '@' .. f, 't', env))()
end
local function cb(name, src, ...) Clock = Clock + 5000 return CB[name](src, ...) end
local function net(name, src, ...) env.source = src source = src return NET[name](...) end
local function fire2(name, src) env.source = src source = src for _, fn in ipairs(HANDLERS[name] or {}) do fn(src) end end
local function count(sql, a) return tonumber(py_scalar(sql, a)) or 0 end
local function sent(name, to) for i = #CLIENTEV, 1, -1 do local e = CLIENTEV[i] if e.n == name and (not to or e.s == to) then return e end end end
local K9S = env.K9S
local DOGNET = 900
local function spawnDog(src, side, model)
    local ok, r = cb('elyzea_k9:requestSpawn', src, side)
    if not ok then return false, r end
    DOGNET = DOGNET + 1
    local ent = 5000 + DOGNET
    ENTS[ent] = { pos = vector3(POS[src].x + 1, POS[src].y, POS[src].z), model = joaat(model or r.model), owner = src, type = 1 }
    NETS[DOGNET] = ent
    net('elyzea_k9:server:spawned', src, r.token, DOGNET)
    return true, r, ent
end

if PHASE == 1 then
    print('— Base de données')
    check(count("SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME LIKE 'elyzea_k9_%'") == 2, '2 tables K9 créées')
    local total = 0
    for l = 1, env.Config.Progress.maxLevel - 1 do total = total + env.K9.XpFor(l) end
    check(total > 8000 and total < 20000, ('progression équilibrée : %d XP du niveau 1 au niveau %d'):format(total, env.Config.Progress.maxLevel))

    print('— Accès')
    check(not cb('elyzea_k9:open', 3).ok, 'civil : aucun accès')
    check(not cb('elyzea_k9:open', 4).ok, 'policier sans la permission K9 : aucun accès')
    local o1 = cb('elyzea_k9:open', 1)
    check(o1.ok and #o1.sides == 1 and o1.sides[1].side == 'police' and o1.sides[1].dog == nil and o1.sides[1].duty, 'policier K9 en service : menu de la police, pas encore de chien')
    local o2 = cb('elyzea_k9:open', 2)
    check(o2.ok and o2.sides[1].side == 'gang' and o2.sides[1].info.groupLabel == 'Ballas', 'membre de gang autorisé : menu du groupe')
    GROUP[2].type = 'societe'
    check(not cb('elyzea_k9:open', 2).ok, 'type de groupe non autorisé : refusé')
    GROUP[2].type = 'gang'

    print('— Création')
    check(select(2, cb('elyzea_k9:create', 1, 'police', 'chop', 'detection', 'Rex')):find('indisponible'), 'race réservée aux gangs refusée pour la police')
    check(select(2, cb('elyzea_k9:create', 1, 'police', 'shepherd', nil, 'Rex')):find('spécialité'), 'spécialité obligatoire (police)')
    check(select(2, cb('elyzea_k9:create', 1, 'police', 'shepherd', 'detection', 'R')):find('Nom'), 'nom trop court refusé')
    local ok, d1 = cb('elyzea_k9:create', 1, 'police', 'labrador', 'detection', ' Rex <b> ')
    check(ok and d1.name == 'Rex b' and d1.specialty == 'detection' and d1.level == 1, 'chien de police créé (nom nettoyé)')
    local sk = {} for _, s in ipairs(d1.skills) do sk[s.id] = s end
    check(sk.sniff.level == 2 and sk.sniff.cap == 5 and sk.attack.cap == 2 and sk.track.cap == 3, 'détection : reniflage niveau 2, plafonds selon la spécialité')
    check(select(2, cb('elyzea_k9:create', 1, 'police', 'shepherd', 'attack', 'Max')):find('déjà'), 'un seul chien par côté')
    local okg, dg = cb('elyzea_k9:create', 2, 'gang', 'chop', 'detection', 'Brutus')
    local gk = {} for _, s in ipairs(dg.skills) do gk[s.id] = s end
    check(okg and dg.specialty == nil and gk.attack and gk.defense and gk.intim and not gk.sniff, 'chien de gang : attaque, défense, intimidation (pas de spécialité)')

    print('— Progression')
    local D = K9S.Dogs[d1.id]
    check(not cb('elyzea_k9:upgrade', 1, 'police', 'obey'), 'pas de point : amélioration refusée')
    local got = K9S.AddXp(1, D, 500, 'train', 'test')
    check(got == 500 and D.level >= 3 and D.points == D.level - 1, ('500 XP : niveau %d, %d points'):format(D.level, D.points))
    check(sent('elyzea_k9:client:levelUp', 1) ~= nil, 'passage de niveau annoncé')
    check(K9S.AddXp(1, D, 500, 'train', 'test') == 200, 'plafond journalier d\'entraînement (700 XP)')
    check(K9S.AddXp(1, D, 50, 'train', 'test') == 0, 'au-delà du plafond : plus rien')
    local okU, du = cb('elyzea_k9:upgrade', 1, 'police', 'attack')
    check(okU and D.skills.attack == 2, 'attaque 1 → 2 (1 point)')
    check(select(2, cb('elyzea_k9:upgrade', 1, 'police', 'attack')):find('maximal'), 'attaque plafonnée à 2 pour un chien de détection')
    local before = D.points
    cb('elyzea_k9:upgrade', 1, 'police', 'sniff')
    check(D.skills.sniff == 3 and D.points == before - 2, 'reniflage 2 → 3 coûte 2 points')
    check(count('SELECT COUNT(*) FROM elyzea_k9_history WHERE dog_id = ?', { d1.id }) >= 4, 'historique enregistré')

    print('— Sortir le chien')
    DUTY[1] = false
    check(select(2, cb('elyzea_k9:requestSpawn', 1, 'police')):find('service'), 'hors service : refusé')
    DUTY[1] = true
    INVEH[1] = 77
    check(select(2, cb('elyzea_k9:requestSpawn', 1, 'police')):find('véhicule'), 'en véhicule : refusé')
    INVEH[1] = nil
    local okS = spawnDog(1, 'police', 'a_c_pug')
    check(okS and K9S.Active[d1.id] == nil, 'modèle différent de la race : entité supprimée')
    local okS2, r2, dogEnt = spawnDog(1, 'police')
    check(okS2 and K9S.Active[d1.id] and K9S.Active[d1.id].src == 1 and ENTS[dogEnt].state.name == 'Rex b', 'chien sorti, enregistré au nom du maître')
    local okS3, _, dogEnt2 = spawnDog(1, 'police')
    check(ENTS[dogEnt] == nil and ENTS[dogEnt2] ~= nil, 'ressortir : l\'ancien chien est supprimé (jamais de doublon)')
    dogEnt = dogEnt2

    print('— Ordres')
    RNGV = 0.99
    local r = cb('elyzea_k9:order', 1, 'police', 'sit')
    check(r.ok and r.obey == false and r.hesitate > 0, 'mauvais tirage : le chien n\'obéit pas (et hésite)')
    RNGV = 0.0
    r = cb('elyzea_k9:order', 1, 'police', 'attack', 4)
    check(not r.ok and r.error:find('collègue'), 'pas d\'attaque sur un policier en service')
    INVEH[3] = 55
    check(cb('elyzea_k9:order', 1, 'police', 'attack', 3).error:find('véhicule'), 'cible en véhicule : pas d\'attaque')
    INVEH[3] = nil
    WEAPON[3] = joaat('WEAPON_PISTOL')
    D.skills.attack = 1
    r = cb('elyzea_k9:order', 1, 'police', 'attack', 3)
    check(r.ok and r.obey == false and r.fear, 'chien peu dressé face à une cible armée : il a peur')
    D.skills.attack = 2
    WEAPON[3] = nil
    check(cb('elyzea_k9:order', 1, 'police', 'attack', 2).error:find('loin'), 'cible trop loin refusée')
    ENTS[dogEnt].pos = vector3(200, 0, 30)
    check(cb('elyzea_k9:order', 1, 'police', 'sit').error:find('loin'), 'chien trop loin du maître : ordre refusé')
    ENTS[dogEnt].pos = vector3(1, 0, 30)

    print('— Intervention')
    r = cb('elyzea_k9:order', 1, 'police', 'takedown', 3)
    check(r.ok and r.obey and r.chase, 'mise au sol ordonnée')
    check(cb('elyzea_k9:contact', 1, 'police', 3).far, 'contact refusé tant que le chien n\'est pas au contact (vérifié par le serveur)')
    ENTS[dogEnt].pos = vector3(4.5, 0, 30)
    CLIENTEV = {}
    local c = cb('elyzea_k9:contact', 1, 'police', 3)
    local ev = sent('elyzea_k9:client:takedown', 3)
    check(c.ok and c.success and c.hold == 0 and ev and ev.a[1].floor == 120 and ev.a[1].damage > 0, 'cible mise au sol (côté victime, dégâts contrôlés, plancher de santé)')
    check(c.xp == 70 and D.stats.missions.takedown == 1, '+70 XP d\'intervention')
    r = cb('elyzea_k9:order', 1, 'police', 'attack', 3)
    c = cb('elyzea_k9:contact', 1, 'police', 3)
    check(c.success and c.hold >= 4 and c.xp == 0, 'attaque : maintien au sol ; même cible juste après : pas d\'XP (anti-farm)')
    check(not cb('elyzea_k9:contact', 1, 'police', 3).ok, 'contact sans ordre en cours : refusé')

    print('— Détection')
    r = cb('elyzea_k9:order', 1, 'police', 'sniffp', 3)
    local sp = cb('elyzea_k9:sniffPerson', 1, 'police', 3)
    check(sp.ok and sp.marked and sp.xp == 60, 'personne avec cocaïne : le chien marque (+60 XP)')
    RNGV = 0.5
    cb('elyzea_k9:order', 1, 'police', 'sniffp', 5)
    POS[5] = vector3(2, 0, 30)
    sp = cb('elyzea_k9:sniffPerson', 1, 'police', 5)
    check(sp.ok and not sp.marked, 'personne sans stupéfiant : pas de marquage')
    RNGV = 0.0
    local veh = 7001
    ENTS[veh] = { pos = vector3(4, 4, 30), type = 2, plate = 'AB123CD' }
    NETS[3001] = veh
    TRUNK.AB123CD = { { name = 'weed_pouch', count = 2 } }
    HIDDEN.AB123CD = { { slot = 'door_fl', type = 'door', label = 'Portière avant gauche', items = { { name = 'meth', count = 4 } } }, { slot = 'door_rr', type = 'door', label = 'Portière arrière droite', items = { { name = 'meth', count = 1 } } }, { slot = 'seat_p', type = 'seat', label = 'Siège passager avant', items = { { name = 'meth', count = 2 } } } }
    cb('elyzea_k9:order', 1, 'police', 'sniffv', 3001)
    local sv = cb('elyzea_k9:sniffVehicle', 1, 'police', 3001)
    check(sv.ok and sv.marked and #sv.spots == 3 and sv.spots[1] == 'trunk' and sv.spots[2] == 'hidden_door' and sv.spots[3] == 'hidden_seat', 'véhicule : coffre + portière + siège (sans dire lesquels)')
    TRUNK.AB123CD = nil
    py_query("CREATE TABLE IF NOT EXISTS elyzea_stashes (id VARCHAR(120) PRIMARY KEY, items LONGTEXT)")
    py_update("REPLACE INTO elyzea_stashes VALUES ('trunk:AB123CD', '[{\"name\":\"cokebaggy\",\"count\":1,\"slot\":1}]')")
    HIDDEN.AB123CD = nil
    NOW = NOW + 3600
    cb('elyzea_k9:order', 1, 'police', 'sniffv', 3001)
    sv = cb('elyzea_k9:sniffVehicle', 1, 'police', 3001)
    check(sv.marked and sv.spots[1] == 'trunk', 'coffre jamais ouvert depuis le redémarrage : lu en base')

    print('— Fouille de zone et pistage')
    DROPS = { { drop = 1, coords = vector3(6, 6, 30), name = 'crack_baggy', count = 1 }, { drop = 2, coords = vector3(3, 3, 30), name = 'water', count = 1 } }
    cb('elyzea_k9:order', 1, 'police', 'search')
    local sz = cb('elyzea_k9:searchZone', 1, 'police')
    local kinds = {}
    for _, s in ipairs(sz.spots) do kinds[s.kind] = (kinds[s.kind] or 0) + 1 end
    check(sz.ok and kinds.person == 2 and kinds.drugs == 1 and kinds.vehicle == 1, 'zone : 2 personnes (pas le policier en service), sac de drogue, véhicule chargé')
    POS[3] = vector3(30, 0, 30)
    RNGV = 0.5   -- le chien ne perd pas la piste (tirage moyen)
    cb('elyzea_k9:order', 1, 'police', 'track', 3)
    Clock = Clock + 10000
    local tp = cb('elyzea_k9:trackPoint', 1, 'police')
    check(tp.ok and tp.x and math.abs(tp.x - 30) <= 30 and not tp.found, 'pistage : position bruitée selon le niveau')
    POS[3] = vector3(5, 0, 30)
    Clock = Clock + 10000
    tp = cb('elyzea_k9:trackPoint', 1, 'police')
    check(tp.found and tp.target == 3, 'personne retrouvée')
    POS[3] = vector3(5000, 0, 30)
    POS[5] = vector3(10, 0, 30)
    cb('elyzea_k9:order', 1, 'police', 'track', 5)
    POS[5] = vector3(3000, 0, 30)
    Clock = Clock + 10000
    tp = cb('elyzea_k9:trackPoint', 1, 'police')
    check(tp.lost and tp.reason == 'far', 'piste perdue (trop loin)')
    POS[3] = vector3(5, 0, 30)
    RNGV = 0.0

    print('— Intimidation, défense')
    cb('elyzea_k9:order', 1, 'police', 'intim', 3)
    CLIENTEV = {}
    local it = cb('elyzea_k9:intimidate', 1, 'police', 3)
    check(it.ok and sent('elyzea_k9:client:intimidated', 3) and it.seconds >= 6, 'intimidation ressentie par la cible')
    check(not cb('elyzea_k9:defendTrigger', 1, 'police', 3).ok, 'pas en mode défense : pas d\'intervention automatique')
    cb('elyzea_k9:order', 1, 'police', 'defend')
    local df = cb('elyzea_k9:defendTrigger', 1, 'police', 3)
    check(df.ok and df.go and df.target == 3, 'mode défense : intervient contre l\'agresseur')

    print('— Entraînement')
    D.stats.trainXp = 0
    local okE = cb('elyzea_k9:exStart', 1, 'police', 'defense')
    check(not okE, 'exercice réservé aux gangs refusé')
    okE = cb('elyzea_k9:exStart', 1, 'police', 'obey')
    check(okE, 'exercice d\'obéissance commencé')
    check(not cb('elyzea_k9:order', 1, 'police', 'sit').ok, 'pas d\'ordre pendant un exercice')
    Clock = Clock + 5000
    check(not cb('elyzea_k9:exFinish', 1, 'police', 'obey', 1.0), 'exercice trop court : refusé')
    cb('elyzea_k9:exStart', 1, 'police', 'obey')
    NOW = NOW + 10
    Clock = Clock + 40000
    local okF, fr = cb('elyzea_k9:exFinish', 1, 'police', 'obey', 0.8)
    check(okF and fr.xp == 44 and D.stats.trained.obey == 1, 'exercice réussi à 80 % : +44 XP')
    check(select(2, cb('elyzea_k9:exStart', 1, 'police', 'obey')):find('reposer'), 'même exercice tout de suite : repos obligatoire')
    NOW = NOW + 7 * 60
    cb('elyzea_k9:exStart', 1, 'police', 'obey')
    Clock = Clock + 40000
    okF, fr = cb('elyzea_k9:exFinish', 1, 'police', 'obey', 0.8)
    check(fr.xp == 26, 'répété dans l\'heure : expérience réduite (×0,6)')

    print('— Gang')
    local okGs, _, gEnt = spawnDog(2, 'gang')
    check(okGs, 'chien de gang sorti (sans notion de service)')
    POS[3] = vector3(52, 50, 30)
    check(cb('elyzea_k9:order', 2, 'gang', 'sniffp', 3).error:find('inconnu'), 'gang : pas de détection de stupéfiants')
    POS[2] = vector3(3, 3, 30)
    ENTS[gEnt].pos = vector3(4, 3, 30)
    local rg = cb('elyzea_k9:order', 2, 'gang', 'attack', 1)
    check(rg.ok, 'gang : peut attaquer (même un policier)')
    GPERM[2] = false
    check(not cb('elyzea_k9:order', 2, 'gang', 'sit').ok, 'permission retirée : plus d\'ordre')
    GPERM[2] = true

    print('— Déconnexion')
    fire2('playerDropped', 2)
    check(K9S.Active[dg.id] == nil and ENTS[gEnt] == nil, 'déconnexion : chien rangé, entité supprimée')
    net('elyzea_k9:server:health', 1, 'police', 0, true)
    check(K9S.Active[d1.id] == nil and D.injured_until > NOW, 'chien blessé : rangé et indisponible')
    check(select(2, cb('elyzea_k9:requestSpawn', 1, 'police')):find('blessé'), 'blessé : ne peut pas ressortir')
    py_query("CREATE TABLE IF NOT EXISTS sim_state (k VARCHAR(10) PRIMARY KEY, v INT)")
    py_update('REPLACE INTO sim_state VALUES (?, ?), (?, ?), (?, ?)', { 'lvl', D.level, 'pts', D.points, 'now', NOW })
else
    print('— Après redémarrage du serveur')
    NOW = tonumber(py_scalar("SELECT v FROM sim_state WHERE k = 'now'")) + 3600
    local o = cb('elyzea_k9:open', 1)
    local d = o.sides[1].dog
    check(d and d.level == tonumber(py_scalar("SELECT v FROM sim_state WHERE k = 'lvl'")) and d.points == tonumber(py_scalar("SELECT v FROM sim_state WHERE k = 'pts'")), 'niveau et points conservés')
    local sk = {} for _, s in ipairs(d.skills) do sk[s.id] = s.level end
    check(sk.sniff == 3 and sk.attack == 2 and d.missions.takedown == 1 and d.missions.sniff >= 2, 'compétences et interventions conservées')
    check(d.injured == 0 and #d.history > 5, 'blessure guérie après le délai ; historique conservé')
    check(cb('elyzea_k9:open', 2).sides[1].dog.name == 'Brutus', 'chien de gang conservé')
end
