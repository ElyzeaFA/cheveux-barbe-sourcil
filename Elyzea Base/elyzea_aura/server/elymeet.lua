-- =========================================================
--  ELYMEET : rencontres (comme happn), remplace Étincelle
--  · Croisements : le serveur relève régulièrement les positions ; deux profils compatibles qui passent
--    à moins de CrossRadius mètres se « croisent » (nombre de fois, dernier lieu ARRONDI, jamais la position exacte)
--  · Fil des personnes croisées, carte des lieux de croisement, profils complets (photos, centres d'intérêt…)
--  · J'aime / Passer / Coup de foudre (limité par jour) ; j'aime réciproque = Crush → messagerie privée
--  Sécurité : les profils sont désignés par un numéro, jamais par l'identifiant du joueur ; un profil n'est
--  visible que si on l'a croisé (ou qu'on a un crush avec lui) ; les photos viennent de SA galerie.
-- =========================================================
local A = AuraCore
local Register, Notify, Players, trim, HasApp = A.Register, A.Notify, A.Players, A.trim, A.HasApp
local CFG = Config.ElyMeet or {}
local APP = 'elymeet'

local function opt(k, d) local v = CFG[k] if v == nil then return d end return v end
local function int(v, d) v = tonumber(v) if not v or v ~= v then return d end return math.floor(v) end
local MIN_AGE = int(opt('MinAge', (Config.Dating or {}).MinAge or 18), 18)
local MAX_PHOTOS = math.max(1, math.min(9, int(opt('MaxPhotos', 6), 6)))
local MIN_INT, MAX_INT = int(opt('MinInterests', 3), 3), int(opt('MaxInterests', 10), 10)
local BIO_LEN = math.min(500, int(opt('BioLength', 300), 300))
local MSG_LEN = math.min(500, int(opt('MessageLength', 500), 500))
local BLUR = math.max(25, tonumber(opt('CrossBlur', 120)) or 120)
local GENDERS = { man = true, woman = true, other = true }
local SEEKS = { men = true, women = true, all = true }
local LOOKING = {}
for _, l in ipairs(CFG.Looking or {}) do LOOKING[l.id] = true end
local INTERESTS = {}
for _, c in ipairs(CFG.Interests or {}) do for _, it in ipairs(c.items or {}) do INTERESTS[it] = true end end

-- ---------------------------------------------------------
--  Base de données
-- ---------------------------------------------------------
local Ready = false
local Cache = {}   -- [identifier] = { id, name, gender, seek, age, age_min, age_max, visible } (profils, pour les croisements)
local function CacheRow(r)
    if not r then return end
    Cache[r.identifier] = { id = int(r.id, 0), name = r.name, gender = r.gender, seek = r.seek, age = int(r.age, 18),
        age_min = int(r.age_min, MIN_AGE), age_max = int(r.age_max, 99), visible = r.visible == 1 or r.visible == true }
end
CreateThread(function()
    local t = GetGameTimer()
    while not A.IsSchemaReady() and GetGameTimer() - t < 30000 do Wait(100) end
    local sql = LoadResourceFile(GetCurrentResourceName(), 'sql/elymeet.sql') or ''
    for statement in sql:gmatch('[^;]+') do
        local q = statement:gsub('%-%-[^\n]*', ''):gsub('^%s+', ''):gsub('%s+$', '')
        if q ~= '' then
            local ok, err = pcall(MySQL.query.await, q)
            if not ok then print('^1[elyzea_aura] ElyMeet : table non créée : ' .. tostring(err) .. '^0') end
        end
    end
    pcall(function() exports.elyzea_core:AlignCollations() end)
    for _, r in ipairs(MySQL.query.await('SELECT id, identifier, name, gender, seek, age, age_min, age_max, visible FROM elyzea_em_profiles') or {}) do CacheRow(r) end
    Ready = true
    print('^2[elyzea_aura] ElyMeet prêt (croisements, carte, crushs, messages).^0')
end)

-- ---------------------------------------------------------
--  Outils
-- ---------------------------------------------------------
local Throttle = {}
local function TooFast(src, key, ms)
    local k, now = src .. ':' .. key, GetGameTimer()
    if Throttle[k] and now - Throttle[k] < ms then return true end
    Throttle[k] = now
    return false
end
local function bool(v) return v == 1 or v == true or v == '1' end
local function SourceOf(identifier) for s, d in pairs(Players) do if d.identifier == identifier then return s end end end
local function Push(src, data) TriggerClientEvent('elyzea_aura:client:elymeet', src, data) end
local function placeholders(n) return ('?'):rep(n, ', ') end
local function decodeList(s) local ok, v = pcall(json.decode, s or '[]') return ok and type(v) == 'table' and v or {} end
local function Pair(x, y) if x < y then return x, y end return y, x end
local function Wants(seek, gender) return seek == 'all' or (seek == 'men' and gender == 'man') or (seek == 'women' and gender == 'woman') end
-- les deux se correspondent (genre recherché et tranche d'âge, dans les deux sens)
local function Compatible(p, q)
    return Wants(p.seek, q.gender) and Wants(q.seek, p.gender)
        and q.age >= p.age_min and q.age <= p.age_max and p.age >= q.age_min and p.age <= q.age_max
end
local function Mine(identifier) return MySQL.single.await('SELECT * FROM elyzea_em_profiles WHERE identifier = ?', { identifier }) end
local function ById(id) return MySQL.single.await('SELECT * FROM elyzea_em_profiles WHERE id = ?', { int(id, 0) }) end
local function Public(r)
    if not r then return nil end
    return { id = int(r.id, 0), name = r.name, age = int(r.age, 18), gender = r.gender, looking = r.looking,
        photos = decodeList(r.photos), interests = decodeList(r.interests), bio = r.bio or '', job = r.job or '' }
end
local function Common(a, b)
    local set, out = {}, {}
    for _, x in ipairs(a or {}) do set[x] = true end
    for _, x in ipairs(b or {}) do if set[x] then out[#out + 1] = x end end
    return out
end
local function Badges(myId)
    if not myId then return { messages = 0 } end
    local n = MySQL.scalar.await([[SELECT COUNT(*) FROM elyzea_em_messages m JOIN elyzea_em_matches x ON x.id = m.match_id
        WHERE (x.a = ? OR x.b = ?) AND m.sender <> ? AND m.seen = 0]], { myId, myId, myId }) or 0
    return { messages = int(n, 0) }
end
local function BoltsLeft(myId)
    local used = MySQL.scalar.await("SELECT COUNT(*) FROM elyzea_em_likes WHERE who = ? AND kind = 'bolt' AND created_at >= CURDATE()", { myId }) or 0
    return math.max(0, int(opt('BoltsPerDay', 1), 1) - int(used, 0))
end

local function EM_(name, needProfile, fn)
    Register(name, function(src, me, args)
        if not HasApp(me, APP) then return { ok = false, error = 'Application non installée' } end
        local t = GetGameTimer()
        while not Ready and GetGameTimer() - t < 7000 do Wait(100) end
        if not Ready then return { ok = false, error = 'ElyMeet démarre, réessaie' } end
        local mine
        if needProfile then
            mine = Mine(me.identifier)
            if not mine then return { ok = false, error = 'Crée d\'abord ton profil', noProfile = true } end
        end
        return fn(src, me, type(args) == 'table' and args or {}, mine)
    end)
end

-- ---------------------------------------------------------
--  Inscription et profil
-- ---------------------------------------------------------
local function GalleryPhotos(identifier, urls)
    local list = {}
    for _, u in ipairs(urls) do if type(u) == 'string' and #u <= 500 and #list < MAX_PHOTOS then list[#list + 1] = u end end
    if #list == 0 then return {} end
    local args = { identifier }
    for _, u in ipairs(list) do args[#args + 1] = u end
    local ok = {}
    for _, r in ipairs(MySQL.query.await(("SELECT url FROM elyzea_gallery WHERE owner = ? AND type = 'photo' AND url IN (%s)"):format(placeholders(#list)), args) or {}) do ok[r.url] = true end
    local out = {}
    for _, u in ipairs(list) do if ok[u] then out[#out + 1] = u ok[u] = nil end end
    return out
end

EM_('emInit', false, function(src, me)
    local mine = Mine(me.identifier)
    local prefill
    if not mine then
        -- pré-remplissage : ancien profil Étincelle (s'il existe) puis prénom du personnage
        local old = MySQL.single.await('SELECT name, age, gender, interest, bio, photos FROM elyzea_dating_profiles WHERE identifier = ?', { me.identifier })
        local first = (A.GetCharName(src) or ''):match('^(%S+)') or ''
        prefill = { name = old and old.name or first, age = old and int(old.age, nil) or nil, gender = old and GENDERS[old.gender] and old.gender or nil,
            seek = old and SEEKS[old.interest] and old.interest or nil, bio = old and old.bio or '',
            photos = old and GalleryPhotos(me.identifier, decodeList(old.photos)) or {} }
    end
    local p = mine and Public(mine)
    if p then
        p.seek = mine.seek p.ageMin = int(mine.age_min, MIN_AGE) p.ageMax = int(mine.age_max, 99) p.visible = bool(mine.visible)
    end
    return { ok = true, profile = p, prefill = prefill, badges = Badges(mine and mine.id),
        bolts = mine and BoltsLeft(mine.id) or int(opt('BoltsPerDay', 1), 1),
        options = { minAge = MIN_AGE, maxPhotos = MAX_PHOTOS, minInterests = MIN_INT, maxInterests = MAX_INT, bio = BIO_LEN, message = MSG_LEN,
            interests = CFG.Interests or {}, looking = CFG.Looking or {}, radius = int(opt('CrossRadius', 60), 60), feedDays = int(opt('FeedDays', 14), 14) } }
end)

EM_('emSaveProfile', false, function(src, me, args)
    if TooFast(src, 'save', 1500) then return { ok = false, error = 'Patiente un instant' } end
    local name = trim(args.name, 30)
    local age = int(args.age, 0)
    if #name < 2 then return { ok = false, error = 'Indique ton prénom' } end
    if age < MIN_AGE or age > 99 then return { ok = false, error = ('Âge : %d ans minimum'):format(MIN_AGE) } end
    if not GENDERS[args.gender] then return { ok = false, error = 'Indique ton genre' } end
    if not SEEKS[args.seek] then return { ok = false, error = 'Indique qui tu veux rencontrer' } end
    local looking = LOOKING[args.looking] and args.looking or 'unsure'
    local photos = GalleryPhotos(me.identifier, type(args.photos) == 'table' and args.photos or {})
    if #photos == 0 then return { ok = false, error = 'Ajoute au moins une photo de ta galerie' } end
    local interests, seen = {}, {}
    for _, it in ipairs(type(args.interests) == 'table' and args.interests or {}) do
        if INTERESTS[it] and not seen[it] and #interests < MAX_INT then seen[it] = true interests[#interests + 1] = it end
    end
    if #interests < MIN_INT then return { ok = false, error = ('Choisis au moins %d centres d\'intérêt'):format(MIN_INT) } end
    local bio = trim((tostring(args.bio or ''):gsub('\r', '')), BIO_LEN)
    local job = trim(args.job, 40)
    local mine = Mine(me.identifier)
    if mine then
        MySQL.update.await([[UPDATE elyzea_em_profiles SET name = ?, age = ?, gender = ?, seek = ?, looking = ?, photos = ?, interests = ?, bio = ?, job = ? WHERE id = ?]],
            { name, age, args.gender, args.seek, looking, json.encode(photos), json.encode(interests), bio, job, mine.id })
    else
        local amin = math.max(MIN_AGE, age - 8)
        MySQL.insert.await([[INSERT INTO elyzea_em_profiles (identifier, name, age, gender, seek, looking, photos, interests, bio, job, age_min, age_max)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], { me.identifier, name, age, args.gender, args.seek, looking, json.encode(photos), json.encode(interests), bio, job, amin, math.min(99, age + 12) })
    end
    mine = Mine(me.identifier)
    CacheRow(mine)
    local p = Public(mine)
    p.seek = mine.seek p.ageMin = int(mine.age_min, MIN_AGE) p.ageMax = int(mine.age_max, 99) p.visible = bool(mine.visible)
    return { ok = true, profile = p }
end)

EM_('emSettings', true, function(src, me, args, mine)
    local amin = math.max(MIN_AGE, math.min(99, int(args.ageMin, int(mine.age_min, MIN_AGE))))
    local amax = math.max(amin, math.min(99, int(args.ageMax, int(mine.age_max, 99))))
    local seek = SEEKS[args.seek] and args.seek or mine.seek
    local visible = args.visible == nil and bool(mine.visible) or args.visible == true
    MySQL.update.await('UPDATE elyzea_em_profiles SET age_min = ?, age_max = ?, seek = ?, visible = ? WHERE id = ?', { amin, amax, seek, visible and 1 or 0, mine.id })
    CacheRow(Mine(me.identifier))
    return { ok = true, ageMin = amin, ageMax = amax, seek = seek, visible = visible }
end)

-- ---------------------------------------------------------
--  Fil : personnes croisées
-- ---------------------------------------------------------
local function Relations(myId, ids)
    local liked, likedMe, matches = {}, {}, {}
    if #ids == 0 then return liked, likedMe, matches end
    local a1 = { myId } for _, i in ipairs(ids) do a1[#a1 + 1] = i end
    for _, r in ipairs(MySQL.query.await(('SELECT target, kind FROM elyzea_em_likes WHERE who = ? AND target IN (%s)'):format(placeholders(#ids)), a1) or {}) do liked[int(r.target, 0)] = r.kind end
    for _, r in ipairs(MySQL.query.await(('SELECT who, kind FROM elyzea_em_likes WHERE target = ? AND who IN (%s)'):format(placeholders(#ids)), a1) or {}) do likedMe[int(r.who, 0)] = r.kind end
    for _, r in ipairs(MySQL.query.await('SELECT id, a, b FROM elyzea_em_matches WHERE a = ? OR b = ?', { myId, myId }) or {}) do
        matches[int(r.a, 0) == myId and int(r.b, 0) or int(r.a, 0)] = int(r.id, 0)
    end
    return liked, likedMe, matches
end
local function MyPrefs(mine)
    return { gender = mine.gender, seek = mine.seek, age = int(mine.age, 18), age_min = int(mine.age_min, MIN_AGE), age_max = int(mine.age_max, 99) }
end
local function Crossed(mine, sinceDays)
    local since = os.time() - int(sinceDays, 14) * 86400
    return MySQL.query.await([[SELECT c.count, c.last_ts, c.x, c.y, p.* FROM elyzea_em_crossings c
        JOIN elyzea_em_profiles p ON p.id = IF(c.a = ?, c.b, c.a)
        WHERE (c.a = ? OR c.b = ?) AND c.last_ts > ? AND p.visible = 1 ORDER BY c.last_ts DESC LIMIT 80]], { mine.id, mine.id, mine.id, since }) or {}
end

EM_('emFeed', true, function(src, me, args, mine)
    local rows = Crossed(mine, opt('FeedDays', 14))
    local my = MyPrefs(mine)
    local ids = {}
    for _, r in ipairs(rows) do ids[#ids + 1] = int(r.id, 0) end
    local liked, likedMe, matches = Relations(mine.id, ids)
    local myInterests = decodeList(mine.interests)
    local out = {}
    for _, r in ipairs(rows) do
        local id = int(r.id, 0)
        local them = { gender = r.gender, seek = r.seek, age = int(r.age, 18), age_min = int(r.age_min, MIN_AGE), age_max = int(r.age_max, 99) }
        if liked[id] ~= 'pass' and Compatible(my, them) then
            local p = Public(r)
            p.count, p.ts, p.x, p.y = int(r.count, 1), int(r.last_ts, 0), r.x, r.y
            p.common = Common(myInterests, p.interests)
            p.liked = liked[id]
            p.bolt = likedMe[id] == 'bolt'
            p.match = matches[id]
            out[#out + 1] = p
        end
    end
    -- un coup de foudre reçu passe devant
    table.sort(out, function(x, y)
        if x.bolt ~= y.bolt then return x.bolt end
        return x.ts > y.ts
    end)
    return { ok = true, people = out, bolts = BoltsLeft(mine.id), badges = Badges(mine.id), now = os.time() }
end)

local function CanSee(mine, otherId)
    if MySQL.scalar.await('SELECT 1 FROM elyzea_em_crossings WHERE a = ? AND b = ?', { Pair(mine.id, otherId) }) then return true end
    return MySQL.scalar.await('SELECT 1 FROM elyzea_em_matches WHERE a = ? AND b = ?', { Pair(mine.id, otherId) }) ~= nil
end

EM_('emProfile', true, function(src, me, args, mine)
    local r = ById(args.id)
    if not r or int(r.id, 0) == int(mine.id, 0) or not CanSee(mine, int(r.id, 0)) then return { ok = false, error = 'Profil introuvable' } end
    local p = Public(r)
    local c = MySQL.single.await('SELECT count, last_ts, x, y FROM elyzea_em_crossings WHERE a = ? AND b = ?', { Pair(mine.id, p.id) })
    if c then p.count, p.ts, p.x, p.y = int(c.count, 1), int(c.last_ts, 0), c.x, c.y end
    local liked, likedMe, matches = Relations(mine.id, { p.id })
    p.common = Common(decodeList(mine.interests), p.interests)
    p.liked, p.bolt, p.match = liked[p.id], likedMe[p.id] == 'bolt', matches[p.id]
    return { ok = true, profile = p, now = os.time() }
end)

EM_('emAct', true, function(src, me, args, mine)
    if TooFast(src, 'act', 350) then return { ok = false, error = 'Doucement' } end
    local kind = (args.kind == 'like' or args.kind == 'pass' or args.kind == 'bolt') and args.kind or nil
    local r = ById(args.id)
    if not kind or not r or int(r.id, 0) == int(mine.id, 0) then return { ok = false } end
    local otherId = int(r.id, 0)
    if not MySQL.scalar.await('SELECT 1 FROM elyzea_em_crossings WHERE a = ? AND b = ?', { Pair(mine.id, otherId) }) then
        return { ok = false, error = 'Vous ne vous êtes pas encore croisés' }
    end
    if kind == 'bolt' and BoltsLeft(mine.id) < 1 then return { ok = false, error = 'Plus de coup de foudre aujourd\'hui' } end
    MySQL.update.await('INSERT INTO elyzea_em_likes (who, target, kind) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE kind = VALUES(kind), created_at = IF(VALUES(kind) = \'bolt\', NOW(), created_at)',
        { mine.id, otherId, kind })
    if kind == 'pass' then return { ok = true } end
    local tsrc = SourceOf(r.identifier)
    local theirs = MySQL.scalar.await("SELECT kind FROM elyzea_em_likes WHERE who = ? AND target = ? AND kind IN ('like', 'bolt')", { otherId, mine.id })
    if theirs then
        local a, b = Pair(mine.id, otherId)
        MySQL.insert.await('INSERT IGNORE INTO elyzea_em_matches (a, b) VALUES (?, ?)', { a, b })
        local mid = int(MySQL.scalar.await('SELECT id FROM elyzea_em_matches WHERE a = ? AND b = ?', { a, b }), 0)
        if tsrc then
            Notify(tsrc, { app = APP, key = 'emMatch', params = { name = mine.name } })
            Push(tsrc, { type = 'match', id = mid })
        end
        return { ok = true, match = { id = mid, profile = Public(r), me = Public(mine) }, bolts = BoltsLeft(mine.id) }
    end
    if kind == 'bolt' and tsrc then
        Notify(tsrc, { app = APP, key = 'emBolt', params = { name = mine.name } })
        Push(tsrc, { type = 'bolt' })
    end
    return { ok = true, bolts = BoltsLeft(mine.id) }
end)

-- ---------------------------------------------------------
--  Carte des croisements (lieux arrondis, regroupés)
-- ---------------------------------------------------------
EM_('emMap', true, function(src, me, args, mine)
    local rows = Crossed(mine, opt('FeedDays', 14))
    local my = MyPrefs(mine)
    local ids = {}
    for _, r in ipairs(rows) do ids[#ids + 1] = int(r.id, 0) end
    local liked = Relations(mine.id, ids)
    local spots, order = {}, {}
    for _, r in ipairs(rows) do
        local id = int(r.id, 0)
        local them = { gender = r.gender, seek = r.seek, age = int(r.age, 18), age_min = int(r.age_min, MIN_AGE), age_max = int(r.age_max, 99) }
        if liked[id] ~= 'pass' and Compatible(my, them) then
            local key = ('%d:%d'):format(math.floor(r.x + 0.5), math.floor(r.y + 0.5))
            if not spots[key] then spots[key] = { x = r.x, y = r.y, people = {} } order[#order + 1] = key end
            local photos = decodeList(r.photos)
            table.insert(spots[key].people, { id = id, name = r.name, age = int(r.age, 18), photo = photos[1], count = int(r.count, 1), ts = int(r.last_ts, 0) })
        end
    end
    local out = {}
    for _, k in ipairs(order) do out[#out + 1] = spots[k] end
    local me_ = nil
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 then local c = GetEntityCoords(ped) me_ = { x = c.x, y = c.y } end
    return { ok = true, spots = out, me = me_, now = os.time() }
end)

-- ---------------------------------------------------------
--  Crushs et messages
-- ---------------------------------------------------------
local function MatchOf(mine, matchId)
    local m = MySQL.single.await('SELECT * FROM elyzea_em_matches WHERE id = ?', { int(matchId, 0) })
    if not m or (int(m.a, 0) ~= int(mine.id, 0) and int(m.b, 0) ~= int(mine.id, 0)) then return nil end
    return m, (int(m.a, 0) == int(mine.id, 0) and int(m.b, 0) or int(m.a, 0))
end

EM_('emMatches', true, function(src, me, args, mine)
    local rows = MySQL.query.await([[SELECT x.id AS match_id, UNIX_TIMESTAMP(x.created_at) AS mts, p.id, p.name, p.age, p.photos,
        (SELECT m.body FROM elyzea_em_messages m WHERE m.match_id = x.id ORDER BY m.id DESC LIMIT 1) AS last,
        (SELECT m.sender FROM elyzea_em_messages m WHERE m.match_id = x.id ORDER BY m.id DESC LIMIT 1) AS last_sender,
        (SELECT UNIX_TIMESTAMP(m.created_at) FROM elyzea_em_messages m WHERE m.match_id = x.id ORDER BY m.id DESC LIMIT 1) AS lts,
        (SELECT COUNT(*) FROM elyzea_em_messages m WHERE m.match_id = x.id AND m.sender <> ? AND m.seen = 0) AS unread
        FROM elyzea_em_matches x JOIN elyzea_em_profiles p ON p.id = IF(x.a = ?, x.b, x.a)
        WHERE x.a = ? OR x.b = ?]], { mine.id, mine.id, mine.id, mine.id }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = { match = int(r.match_id, 0), id = int(r.id, 0), name = r.name, age = int(r.age, 18), photo = decodeList(r.photos)[1],
            last = r.last, mine = r.last_sender and int(r.last_sender, 0) == int(mine.id, 0) or false, ts = int(r.lts or r.mts, 0), unread = int(r.unread, 0), fresh = r.last == nil }
    end
    table.sort(out, function(x, y) return x.ts > y.ts end)
    return { ok = true, matches = out, badges = Badges(mine.id) }
end)

EM_('emMessages', true, function(src, me, args, mine)
    local m, otherId = MatchOf(mine, args.match)
    if not m then return { ok = false, error = 'Conversation introuvable' } end
    MySQL.update.await('UPDATE elyzea_em_messages SET seen = 1 WHERE match_id = ? AND sender <> ? AND seen = 0', { m.id, mine.id })
    local rows = MySQL.query.await('SELECT id, sender, body, UNIX_TIMESTAMP(created_at) AS ts FROM elyzea_em_messages WHERE match_id = ? ORDER BY id DESC LIMIT 150', { m.id }) or {}
    local items = {}
    for i = #rows, 1, -1 do local r = rows[i] items[#items + 1] = { id = int(r.id, 0), mine = int(r.sender, 0) == int(mine.id, 0), body = r.body, ts = int(r.ts, 0) } end
    local other = Public(ById(otherId))
    if other then other.common = Common(decodeList(mine.interests), other.interests) end
    return { ok = true, profile = other, items = items, badges = Badges(mine.id) }
end)

EM_('emSend', true, function(src, me, args, mine)
    if TooFast(src, 'msg', 400) then return { ok = false, error = 'Doucement' } end
    local m, otherId = MatchOf(mine, args.match)
    if not m then return { ok = false, error = 'Conversation introuvable' } end
    local body = trim((tostring(args.body or ''):gsub('\r', '')), MSG_LEN)
    if body == '' then return { ok = false } end
    local id = MySQL.insert.await('INSERT INTO elyzea_em_messages (match_id, sender, body) VALUES (?, ?, ?)', { m.id, mine.id, body })
    local other = ById(otherId)
    local tsrc = other and SourceOf(other.identifier)
    if tsrc then
        Notify(tsrc, { app = APP, key = 'emMessage', params = { name = mine.name }, text = body })
        Push(tsrc, { type = 'message', match = int(m.id, 0), item = { id = id, mine = false, body = body, ts = os.time() } })
    end
    return { ok = true, item = { id = id, mine = true, body = body, ts = os.time() } }
end)

EM_('emUnmatch', true, function(src, me, args, mine)
    local m, otherId = MatchOf(mine, args.match)
    if not m then return { ok = false } end
    MySQL.update.await('DELETE FROM elyzea_em_messages WHERE match_id = ?', { m.id })
    MySQL.update.await('DELETE FROM elyzea_em_matches WHERE id = ?', { m.id })
    MySQL.update.await("INSERT INTO elyzea_em_likes (who, target, kind) VALUES (?, ?, 'pass') ON DUPLICATE KEY UPDATE kind = 'pass'", { mine.id, otherId })
    return { ok = true }
end)

-- ---------------------------------------------------------
--  Moteur de croisements
-- ---------------------------------------------------------
local CrossMem, Notified, AppOk = {}, {}, {}
local function CanUse(src, p)
    local now = GetGameTimer()
    local c = AppOk[src]
    if c and now - c.t < 60000 then return c.ok end
    local ok = HasApp(p, APP) and true or false
    AppOk[src] = { t = now, ok = ok }
    return ok
end
local function Blur(v) return math.floor(v / BLUR + 0.5) * BLUR end

local function CrossTick()
    if not Ready then return 0 end
    local now = os.time()
    local radius = tonumber(opt('CrossRadius', 60.0)) or 60.0
    local r2 = radius * radius
    local cooldown = int(opt('CrossCooldown', 10), 10) * 60
    local list = {}
    for s, p in pairs(Players) do
        local c = p.identifier and Cache[p.identifier]
        if c and c.visible and CanUse(s, p) then
            local ped = GetPlayerPed(s)
            if ped and ped ~= 0 then
                local pos = GetEntityCoords(ped)
                if pos and not (pos.x == 0.0 and pos.y == 0.0) then list[#list + 1] = { s = s, c = c, x = pos.x, y = pos.y, z = pos.z } end
            end
        end
    end
    local made = 0
    for i = 1, #list - 1 do
        local p = list[i]
        for j = i + 1, #list do
            local q = list[j]
            local dx, dy = p.x - q.x, p.y - q.y
            if dx * dx + dy * dy <= r2 and math.abs(p.z - q.z) < 20.0 and Compatible(p.c, q.c) then
                local a, b = Pair(p.c.id, q.c.id)
                local key = a .. ':' .. b
                if not CrossMem[key] or now - CrossMem[key] >= cooldown then
                    CrossMem[key] = now
                    local x, y = Blur((p.x + q.x) / 2), Blur((p.y + q.y) / 2)
                    local limit = now - cooldown
                    MySQL.update.await([[INSERT INTO elyzea_em_crossings (a, b, count, last_ts, x, y) VALUES (?, ?, 1, ?, ?, ?)
                        ON DUPLICATE KEY UPDATE count = IF(last_ts < ?, count + 1, count), x = IF(last_ts < ?, VALUES(x), x),
                        y = IF(last_ts < ?, VALUES(y), y), last_ts = IF(last_ts < ?, VALUES(last_ts), last_ts)]], { a, b, now, x, y, limit, limit, limit, limit })
                    made = made + 1
                    -- notification (au plus une toutes les NotifyEvery minutes par joueur)
                    for _, pair in ipairs({ { p, q }, { q, p } }) do
                        local who, other = pair[1], pair[2]
                        local last = Notified[who.s]
                        if not last or now - last >= int(opt('NotifyEvery', 20), 20) * 60 then
                            Notified[who.s] = now
                            Notify(who.s, { app = APP, key = 'emCrossed', params = { name = other.c.name } })
                        end
                        Push(who.s, { type = 'crossed' })
                    end
                end
            end
        end
    end
    return made
end
ElyMeetCrossTick = CrossTick   -- pour les tests hors jeu
CreateThread(function()
    while not Ready do Wait(1000) end
    while true do
        Wait(math.max(5, int(opt('CrossEvery', 15), 15)) * 1000)
        local ok, err = pcall(CrossTick)
        if not ok then print('^1[elyzea_aura] ElyMeet : croisements : ' .. tostring(err) .. '^0') end
    end
end)
AddEventHandler('playerDropped', function()
    local src = source
    AppOk[src], Notified[src] = nil, nil
    local s = tostring(src) .. ':'
    for k in pairs(Throttle) do if k:sub(1, #s) == s then Throttle[k] = nil end end
end)
