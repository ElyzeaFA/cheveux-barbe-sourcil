-- =====================================================================
--  ElyChat + ElyMeet : vrais fichiers serveur (elyzea_aura/server/main.lua + elychat.lua + elymeet.lua)
--  PHASE 1 : trois joueurs utilisent les applis. PHASE 2 : redémarrage (même base).
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
function SetTimeout() end
function LoadResourceFile(res, path) local ok, s = pcall(py_read, res .. '/' .. path) return ok and s or nil end
MySQL.prepare = MySQL.query
MySQL.update.await = function(s, a) return py_update(s, a) end
function GetPlayerIdentifiers() return {} end
function RegisterCommand() end
Clock = 1000000
function GetGameTimer() return Clock end
NOW = 1800000000
local PLAYERS = {
    [1] = { cid = 'CID_A', ci = { firstname = 'Léna', lastname = 'Duval' } },
    [2] = { cid = 'CID_B', ci = { firstname = 'Malik', lastname = 'Benali' } },
    [3] = { cid = 'CID_C', ci = { firstname = 'Hugo', lastname = 'Morel' } },
}
function GetPlayerName(s) return 'J' .. s end
function GetPlayers() return { '1', '2', '3' } end
local function pobj(s)
    local p = PLAYERS[tonumber(s)]; if not p then return nil end
    return { PlayerData = { source = s, citizenid = p.cid, charinfo = p.ci, metadata = {}, job = { name = 'unemployed' } }, Functions = { GetMoney = function() return 0 end } }
end
Registry.elyzea_core = { GetPlayer = pobj, GetPlayerByCitizenId = function(cid) for s, p in pairs(PLAYERS) do if p.cid == cid then return pobj(s) end end end }
Registry.elyzea_inventory = { Search = function() return 1 end }
Registry.elyzea_aura = {}
Started = { elyzea_core = true, elyzea_inventory = true }

POS = { [1] = { x = 100.0, y = 200.0, z = 30.0 }, [2] = { x = 120.0, y = 215.0, z = 31.0 }, [3] = { x = 110.0, y = 190.0, z = 30.0 } }
local env = permissive({})
local e = loadResource('elyzea_aura', {})
env.exports = e.exports
env.GetCurrentResourceName = function() return 'elyzea_aura' end
env.Devices = false
env.GetPlayerPed = function(s) return POS[tonumber(s)] and tonumber(s) or 0 end
env.GetEntityCoords = function(ped) local p = POS[ped] return p and vector3(p.x, p.y, p.z) or vector3(0.0, 0.0, 0.0) end
env.os = setmetatable({ time = function(t) if t then return os.time(t) end return NOW end }, { __index = os })
for _, f in ipairs({ 'elyzea_aura/config.lua', 'elyzea_aura/config_elychat.lua', 'elyzea_aura/config_elymeet.lua', 'elyzea_aura/server/main.lua', 'elyzea_aura/server/elychat.lua', 'elyzea_aura/server/elymeet.lua' }) do
    assert(load(py_read(f), '@' .. f, 't', env))()
end
local AU = env
local function call(name, src, args, noClock)
    if not noClock then Clock = Clock + 20000 end
    local reply
    TriggerClientEvent = function(n, s, ...) local a = { ... } Sent[#Sent + 1] = { name = n, src = s, args = a } if n == 'elyzea_aura:client:cb' then reply = a[2] end end
    fire('elyzea_aura:server:cb', src, name, 1, args or {})
    return reply
end
local function install(src, list)
    call('getProfile', src)
    AU.AuraCore.Players[src].settings.installed = list
    AU.AuraCore.Players[src].settings.notifications = true
end
local function count(sql, a) return tonumber(py_scalar(sql, a)) or 0 end
local function notified(src, key) for i = #Sent, 1, -1 do local s = Sent[i] if s.src == src and s.name == 'elyzea_aura:client:notify' and s.args[1].key == key then return s.args[1] end end end
local function find(list, k, v) for _, x in ipairs(list or {}) do if x[k] == v then return x end end end
local PHOTO = 'https://r2.fivemanage.com/abc/photo_%d.jpg'

install(1, { 'elychat', 'elymeet' }) install(2, { 'elychat', 'elymeet' }) install(3, { 'elymeet' })

if PHASE == 1 then
    for i = 1, 3 do py_insert("INSERT INTO elyzea_gallery (owner, url, type) VALUES ('CID_A', ?, 'photo')", { PHOTO:format(i) }) end
    py_insert("INSERT INTO elyzea_gallery (owner, url, type) VALUES ('CID_B', ?, 'photo')", { PHOTO:format(10) })
    py_insert("INSERT INTO elyzea_gallery (owner, url, type) VALUES ('CID_C', ?, 'photo')", { PHOTO:format(20) })

    print('— Base de données')
    check(count("SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME LIKE 'elyzea_ec_%'") == 4, '4 tables ElyChat créées')
    check(count("SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME LIKE 'elyzea_em_%'") == 5, '5 tables ElyMeet créées')

    print('— ElyChat : comptes et amis')
    check(call('ecInit', 1).ok and call('ecInit', 1).account == nil, 'premier lancement : pas encore de compte')
    check(call('ecInit', 3).error == 'Application non installée', 'appli non installée : refusée')
    check(not call('ecCreateAccount', 1, { username = 'L!' }).ok, 'nom d\'utilisateur invalide refusé')
    local a1 = call('ecCreateAccount', 1, { username = 'lena.duval', display = 'Léna', color = '#3DDC97' })
    check(a1.ok and a1.account.u == 'lena.duval' and a1.account.color == '#3DDC97', 'compte créé (nom, couleur)')
    check(call('ecCreateAccount', 2, { username = 'lena.duval' }).error:find('déjà pris'), 'nom déjà pris')
    check(call('ecCreateAccount', 2, { username = 'malik', display = 'Malik', color = '#000000' }).account.color == '#FFD60A', 'couleur hors liste remplacée par la couleur par défaut')
    check(#call('ecSearch', 1, { q = 'mal' }).users == 1 and call('ecSearch', 1, { q = 'mal' }).users[1].rel == 'none', 'recherche d\'un utilisateur')
    check(call('ecAddFriend', 1, { u = 'malik' }).rel == 'sent', 'demande d\'ami envoyée')
    check(notified(2, 'ecFriendReq') ~= nil and call('ecInit', 2).badges.requests == 1, 'le destinataire est prévenu (pastille)')
    check(not call('ecSendSnap', 1, { url = PHOTO:format(1), to = { 'malik' } }).ok, 'pas encore amis : snap refusé')
    check(call('ecRespond', 2, { u = 'lena.duval', accept = true }).ok and notified(1, 'ecFriendOk') ~= nil, 'demande acceptée, l\'autre est prévenu')
    check(#call('ecFriends', 1).friends == 1, 'amis des deux côtés')

    print('— ElyChat : snaps, ElyScore, flammes')
    check(call('ecSendSnap', 1, { url = 'https://evil.test/x.jpg', to = { 'malik' } }).error:find('galerie'), 'snap : photo hors de sa galerie refusée')
    check(call('ecSendSnap', 1, { url = PHOTO:format(10), to = { 'malik' } }).error:find('galerie'), 'snap : photo de la galerie d\'un autre refusée')
    local sn = call('ecSendSnap', 1, { url = PHOTO:format(1), caption = 'Coucou\nla ville', duration = 10, to = { 'malik', 'personne' } })
    check(sn.ok and sn.sent == 1 and sn.score == 1, 'snap envoyé (destinataire inconnu ignoré), +1 ElyScore')
    check(notified(2, 'ecSnap') ~= nil, 'notification « nouveau snap »')
    local ch2 = call('ecChats', 2)
    local row = find(ch2.chats, 'u', 'lena.duval')
    check(row and row.newSnaps == 1 and row.status.kind == 'snap' and row.status.state == 'new' and ch2.badges.snaps == 1, 'liste : « Nouveau snap » + pastille')
    local op = call('ecOpenSnap', 2, { u = 'lena.duval' })
    check(op.ok and op.snap.url == PHOTO:format(1) and op.snap.duration == 10 and op.snap.caption == 'Coucou la ville', 'snap ouvert (photo, durée, légende sur une ligne)')
    check(not call('ecOpenSnap', 2, { u = 'lena.duval' }).ok, 'un snap ne se voit qu\'une fois')
    check(count('SELECT COUNT(*) FROM elyzea_ec_snaps WHERE url IS NOT NULL AND opened = 1') == 0, 'le lien du snap ouvert est effacé')
    check(count("SELECT score FROM elyzea_ec_profiles WHERE identifier = 'CID_B'") == 1, 'ouvrir un snap : +1 ElyScore')
    local st1 = find(call('ecChats', 1).chats, 'u', 'malik').status
    check(st1.dir == 'out' and st1.state == 'opened', 'l\'expéditeur voit « Ouvert »')
    check(call('ecSendSnap', 2, { url = PHOTO:format(10), to = { 'lena.duval' } }).ok, 'snap en retour')
    check(find(call('ecChats', 1).chats, 'u', 'malik').streak == 1, 'snaps échangés dans les deux sens aujourd\'hui : 1 flamme')
    local day = math.floor(NOW / 86400)
    py_update("UPDATE elyzea_ec_friends SET streak = 4, streak_day = ?, a_day = ?, b_day = ?", { day - 1, day - 1, day - 1 })
    call('ecSendSnap', 1, { url = PHOTO:format(2), to = { 'malik' } })
    check(find(call('ecChats', 1).chats, 'u', 'malik').streak == 4, 'flamme d\'hier encore visible tant que l\'autre n\'a pas répondu')
    call('ecOpenSnap', 2, { u = 'lena.duval' })
    call('ecSendSnap', 2, { url = PHOTO:format(10), to = { 'lena.duval' } })
    check(find(call('ecChats', 1).chats, 'u', 'malik').streak == 5, 'nouveau jour d\'échange : 5 flammes')
    py_update("UPDATE elyzea_ec_friends SET streak_day = ?", { day - 3 })
    check(find(call('ecChats', 1).chats, 'u', 'malik').streak == 0, 'plus d\'échange depuis 2 jours : flamme éteinte')
    py_update("UPDATE elyzea_ec_friends SET streak_day = ?", { day })

    print('— ElyChat : chat éphémère')
    local m1 = call('ecSend', 1, { u = 'malik', body = 'On se voit ce soir ?' })
    check(m1.ok and notified(2, 'ecChat') ~= nil, 'message envoyé et notifié')
    local st2 = find(call('ecChats', 2).chats, 'u', 'lena.duval')
    check(st2.newChats == 1 and st2.status.kind == 'chat' and st2.status.state == 'new', 'liste : « Nouveau chat »')
    local th = call('ecChat', 2, { u = 'lena.duval' })
    check(th.ok and #th.items >= 3 and find(th.items, 'body', 'On se voit ce soir ?') and find(th.items, 'kind', 'snap') and th.user.u == 'lena.duval', 'conversation : snaps et messages')
    check(count('SELECT seen FROM elyzea_ec_messages WHERE id = ?', { m1.item.id }) == 1, 'message marqué comme vu')
    local m2 = call('ecSend', 2, { u = 'lena.duval', body = 'Oui, 21h !' })
    call('ecChat', 1, { u = 'malik' })
    check(call('ecSave', 2, { id = m2.item.id }).saved == true, 'message enregistré')
    check(not call('ecSave', 3, { id = m2.item.id }).ok, 'un autre ne peut pas toucher au message')
    py_update('UPDATE elyzea_ec_messages SET seen_at = ?', { NOW - 25 * 3600 })
    AU.ElyChatCleanup()
    check(count('SELECT COUNT(*) FROM elyzea_ec_messages WHERE id = ?', { m1.item.id }) == 0, 'message vu depuis plus de 24 h : effacé')
    check(count('SELECT COUNT(*) FROM elyzea_ec_messages WHERE id = ?', { m2.item.id }) == 1, 'message enregistré : gardé')

    print('— ElyChat : carte et partage de position')
    check(#call('ecMap', 2).friends == 0, 'mode fantôme par défaut : personne ne voit Léna')
    check(call('ecSetShare', 1, { mode = 'all' }).share == 'all', 'partage avec tous ses amis')
    local mp = call('ecMap', 2)
    check(#mp.friends == 1 and mp.friends[1].live and math.abs(mp.friends[1].x - 100) < 0.1 and mp.me ~= nil, 'Malik voit Léna en direct sur la carte')
    call('ecSetShare', 1, { mode = 'some', list = {} })
    check(#call('ecMap', 2).friends == 0, 'partage « seulement » sans Malik : il ne la voit plus')
    call('ecSetShare', 1, { mode = 'some', list = { 'malik', 'inconnu' } })
    check(#call('ecMap', 2).friends == 1, 'partage « seulement » avec Malik : il la voit')
    local p1 = POS[1]
    POS[1] = { x = 150.0, y = 260.0, z = 30.0 }
    AU.AuraCore.Players[1].identifier = AU.AuraCore.Players[1].identifier
    py_update("UPDATE elyzea_ec_profiles SET last_x = 150, last_y = 260, last_ts = ? WHERE identifier = 'CID_A'", { NOW - 600 })
    local saved = AU.AuraCore.Players[1]
    AU.AuraCore.Players[1] = nil
    local off = call('ecMap', 2).friends[1]
    check(off and not off.live and off.x == 150 and off.ts == NOW - 600, 'hors ligne : dernière position connue, avec l\'heure')
    AU.AuraCore.Players[1] = saved
    POS[1] = p1
    call('ecSetShare', 1, { mode = 'off' })
    check(#call('ecMap', 2).friends == 0 and count("SELECT COUNT(*) FROM elyzea_ec_profiles WHERE identifier = 'CID_A' AND last_x IS NULL") == 1, 'mode fantôme : invisible et dernière position effacée')

    print('— ElyMeet : inscription')
    py_insert([[INSERT INTO elyzea_dating_profiles (identifier, name, age, gender, interest, bio, photos, tags) VALUES ('CID_A', 'Léna', 26, 'woman', 'men', 'Ancienne bio', ?, '[]')]],
        { '["' .. PHOTO:format(1) .. '","https://autre.site/x.jpg"]' })
    local i1 = call('emInit', 1)
    check(i1.ok and i1.profile == nil and i1.prefill.name == 'Léna' and i1.prefill.age == 26 and i1.prefill.seek == 'men' and #i1.prefill.photos == 1, 'ancien profil Étincelle : inscription pré-remplie (photos de la galerie seulement)')
    check(#i1.options.interests >= 5 and i1.options.minAge == 18, 'centres d\'intérêt proposés')
    local base = { name = 'Léna', age = 26, gender = 'woman', seek = 'men', looking = 'serious', photos = { PHOTO:format(1), PHOTO:format(2) }, interests = { 'Cuisine', 'Voyages', 'Musique', 'Inconnu' }, bio = 'Bonjour', job = 'Photographe' }
    local function with(t, k, v) local c = {} for kk, vv in pairs(t) do c[kk] = vv end c[k] = v return c end
    check(call('emSaveProfile', 1, with(base, 'age', 16)).error:find('18'), 'moins de 18 ans : refusé')
    check(call('emSaveProfile', 1, with(base, 'photos', { PHOTO:format(10) })).error:find('photo'), 'photo d\'un autre joueur : refusée')
    check(call('emSaveProfile', 1, with(base, 'interests', { 'Cuisine', 'Inconnu' })).error:find('centres'), 'moins de 3 centres d\'intérêt : refusé')
    local s1 = call('emSaveProfile', 1, base)
    check(s1.ok and #s1.profile.interests == 3 and s1.profile.ageMin == 18 and s1.profile.ageMax == 38, 'profil créé (intérêt inconnu ignoré, tranche d\'âge par défaut)')
    check(call('emSaveProfile', 2, { name = 'Malik', age = 28, gender = 'man', seek = 'women', looking = 'dating', photos = { PHOTO:format(10) }, interests = { 'Cuisine', 'Boxe', 'Voyages' } }).ok, 'profil de Malik')
    check(call('emSaveProfile', 3, { name = 'Hugo', age = 30, gender = 'man', seek = 'men', looking = 'dating', photos = { PHOTO:format(20) }, interests = { 'Golf', 'Boxe', 'Bars' } }).ok, 'profil de Hugo')

    print('— ElyMeet : croisements')
    check(AU.ElyMeetCrossTick() == 1, 'Léna et Malik se croisent (Hugo ne correspond à personne)')
    local cr = py_single('SELECT * FROM elyzea_em_crossings')
    check(cr.count == 1 and cr.x % 120 == 0 and cr.y % 120 == 0, 'croisement enregistré, lieu arrondi (jamais la position exacte)')
    check(notified(1, 'emCrossed') ~= nil and notified(1, 'emCrossed').params.name == 'Malik', 'notification « vous venez de croiser Malik »')
    AU.ElyMeetCrossTick()
    check(count('SELECT count FROM elyzea_em_crossings') == 1, 'toujours ensemble : pas compté deux fois')
    NOW = NOW + 11 * 60
    AU.ElyMeetCrossTick()
    check(count('SELECT count FROM elyzea_em_crossings') == 2, 'recroisés plus tard : 2 fois')
    POS[2] = { x = 900.0, y = 900.0, z = 30.0 }
    NOW = NOW + 11 * 60
    check(AU.ElyMeetCrossTick() == 0, 'trop loin : pas de croisement')
    local f1 = call('emFeed', 1)
    local mk = find(f1.people, 'name', 'Malik')
    check(mk and mk.count == 2 and #mk.common == 2 and mk.x ~= nil and #f1.people == 1, 'fil : Malik, croisé 2 fois, 2 intérêts en commun')
    check(#call('emFeed', 3).people == 0, 'Hugo ne voit personne')
    local hugoId = count("SELECT id FROM elyzea_em_profiles WHERE identifier = 'CID_C'")
    local malikId, lenaId = mk.id, count("SELECT id FROM elyzea_em_profiles WHERE identifier = 'CID_A'")
    check(not call('emProfile', 1, { id = hugoId }).ok, 'profil de quelqu\'un jamais croisé : refusé')
    check(call('emProfile', 1, { id = malikId }).profile.bio ~= nil, 'profil complet de quelqu\'un de croisé')
    check(call('emAct', 1, { id = hugoId, kind = 'like' }).error:find('croisés'), 'aimer quelqu\'un jamais croisé : refusé')

    print('— ElyMeet : j\'aime, coup de foudre, crush')
    local l1 = call('emAct', 1, { id = malikId, kind = 'like' })
    check(l1.ok and not l1.match, 'Léna aime Malik (pas encore réciproque)')
    local b2 = call('emAct', 2, { id = lenaId, kind = 'bolt' })
    check(b2.ok and b2.match and b2.match.profile.name == 'Léna' and notified(1, 'emMatch') ~= nil, 'coup de foudre réciproque : Crush, Léna est prévenue')
    check(call('emAct', 2, { id = lenaId, kind = 'bolt' }).error:find('foudre'), '1 coup de foudre par jour')
    local mt = call('emMatches', 1).matches[1]
    check(mt and mt.name == 'Malik' and mt.fresh, 'nouveau crush dans la liste')
    local se = call('emSend', 2, { match = mt.match, body = 'Salut Léna !' })
    check(se.ok and notified(1, 'emMessage') ~= nil, 'message envoyé et notifié')
    check(call('emMatches', 1).matches[1].unread == 1 and call('emInit', 1).badges.messages == 1, 'message non lu (pastille)')
    local ms = call('emMessages', 1, { match = mt.match })
    check(#ms.items == 1 and ms.profile.name == 'Malik' and #ms.profile.common == 2 and call('emInit', 1).badges.messages == 0, 'conversation lue')
    check(not call('emMessages', 3, { match = mt.match }).ok, 'conversation d\'un autre : refusée')
    local sp = call('emMap', 1).spots
    check(#sp == 1 and sp[1].people[1].name == 'Malik', 'carte : lieu du croisement avec Malik')

    print('— ElyMeet : préférences')
    check(call('emSettings', 1, { ageMin = 18, ageMax = 25 }).ageMax == 25, 'tranche d\'âge 18-25')
    check(#call('emFeed', 1).people == 0, 'Malik (28 ans) n\'apparaît plus')
    call('emSettings', 1, { ageMin = 20, ageMax = 40 })
    check(call('emSettings', 2, { visible = false }).visible == false and #call('emFeed', 1).people == 0, 'mode invisible : Malik disparaît du fil')
    POS[2] = { x = 101.0, y = 201.0, z = 30.0 }
    NOW = NOW + 11 * 60
    check(AU.ElyMeetCrossTick() == 0, 'mode invisible : plus de croisement')
    call('emSettings', 2, { visible = true })
    check(call('emUnmatch', 1, { match = mt.match }).ok and #call('emMatches', 2).matches == 0 and #call('emFeed', 1).people == 0, 'crush retiré : conversation supprimée, il ne réapparaît plus')
    py_query("CREATE TABLE IF NOT EXISTS sim_state (k VARCHAR(10) PRIMARY KEY, v INT)")
    py_update('REPLACE INTO sim_state VALUES (?, ?)', { 'now', NOW })
else
    print('— Après redémarrage du serveur')
    NOW = tonumber(py_scalar("SELECT v FROM sim_state WHERE k = 'now'")) + 3600
    check(call('ecInit', 1).account.score == 2, 'ElyScore conservé (2 snaps envoyés)')
    check(#call('ecFriends', 2).friends == 1, 'amis conservés')
    check(call('emInit', 1).profile.name == 'Léna', 'profil ElyMeet conservé')
    POS[1] = { x = 500.0, y = 500.0, z = 30.0 } POS[3] = { x = 505.0, y = 505.0, z = 30.0 }
    POS[2] = { x = 510.0, y = 495.0, z = 30.0 }
    call('emSaveProfile', 3, { name = 'Hugo', age = 30, gender = 'man', seek = 'women', looking = 'dating', photos = { PHOTO:format(20) }, interests = { 'Golf', 'Boxe', 'Bars' } })
    check(AU.ElyMeetCrossTick() == 2, 'croisements actifs dès le démarrage (profils chargés) : Léna croise Hugo et Malik')
    check(find(call('emFeed', 1).people, 'name', 'Hugo') ~= nil, 'Hugo dans le fil de Léna')
end
