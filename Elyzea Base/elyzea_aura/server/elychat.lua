-- =========================================================
--  ELYCHAT : messagerie photo (comme Snapchat)
--  · Snaps photo (de SA galerie) envoyés à un ou plusieurs amis, vus UNE fois avec un minuteur
--  · Chat éphémère : un message vu disparaît après Config.ElyChat.ChatHours (sauf s'il est enregistré)
--  · Amis : recherche, demandes, acceptation, retrait
--  · ElyScore (snaps envoyés / ouverts) et flammes (un snap échangé chaque jour, dans les deux sens)
--  · Carte : position des amis qui la partagent AVEC MOI (tous mes amis, ou une liste choisie ; mode fantôme)
--  Sécurité : le compte est TOUJOURS celui du personnage ; les amis sont désignés par leur nom
--  d'utilisateur, jamais par leur identifiant ; la position n'est donnée qu'aux amis autorisés.
-- =========================================================
local A = AuraCore
if A.AddRepair then A.AddRepair('^ec%u', 'sql/elychat.sql', 'elyzea_ec_', 'ElyChat') end
local Register, Notify, Players, trim, HasApp = A.Register, A.Notify, A.Players, A.trim, A.HasApp
local CFG = Config.ElyChat or {}
local APP = 'elychat'

local function opt(k, d) local v = CFG[k] if v == nil then return d end return v end
local MSG_LEN = math.min(500, tonumber(opt('MessageLength', 400)) or 400)
local CAP_LEN = math.min(120, tonumber(opt('CaptionLength', 80)) or 80)
local MAX_TO = math.max(1, math.min(50, tonumber(opt('MaxRecipients', 15)) or 15))

-- ---------------------------------------------------------
--  Base de données
-- ---------------------------------------------------------
local Ready = false
CreateThread(function()
    local t = GetGameTimer()
    while not A.IsSchemaReady() and GetGameTimer() - t < 30000 do Wait(100) end
    local sql = LoadResourceFile(GetCurrentResourceName(), 'sql/elychat.sql') or ''
    for statement in sql:gmatch('[^;]+') do
        local q = statement:gsub('%-%-[^\n]*', ''):gsub('^%s+', ''):gsub('%s+$', '')
        if q ~= '' then
            local ok, err = pcall(MySQL.query.await, q)
            if not ok then print('^1[elyzea_aura] ElyChat : table non créée : ' .. tostring(err) .. '^0') end
        end
    end
    pcall(function() exports.elyzea_core:AlignCollations() end)
    Ready = true
    print('^2[elyzea_aura] ElyChat prêt (snaps, chat, amis, carte, ElyScore).^0')
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
local function int(v, d) v = tonumber(v) if not v or v ~= v then return d end return math.floor(v) end
local function bool(v) return v == 1 or v == true or v == '1' end
local function Today() return math.floor(os.time() / 86400) end
local function SourceOf(identifier) for s, d in pairs(Players) do if d.identifier == identifier then return s end end end
local function Push(src, data) TriggerClientEvent('elyzea_aura:client:elychat', src, data) end
local function Pair(x, y) if x < y then return x, y end return y, x end
local function likeEscape(s) return (s:gsub('[\\%%_]', '\\%0')) end
local function placeholders(n) return ('?'):rep(n, ', ') end
local function decodeList(s) local ok, v = pcall(json.decode, s or '[]') return ok and type(v) == 'table' and v or {} end

local function Account(identifier)
    return MySQL.single.await([[SELECT a.identifier, a.username, a.display_name, pr.avatar, IFNULL(pr.color, '#FFD60A') AS color,
        IFNULL(pr.score, 0) AS score, IFNULL(pr.share, 'off') AS share, pr.share_list
        FROM elyzea_accounts a LEFT JOIN elyzea_ec_profiles pr ON pr.identifier = a.identifier
        WHERE a.identifier = ? AND a.app = ?]], { identifier, APP })
end
local function IdOf(username)
    if type(username) ~= 'string' or username == '' then return nil end
    return MySQL.scalar.await('SELECT identifier FROM elyzea_accounts WHERE app = ? AND username = ?', { APP, username:lower():sub(1, 20) })
end
local function Public(r, withScore)
    if not r then return nil end
    return { u = r.username, name = r.display_name, avatar = r.avatar, color = r.color or '#FFD60A', score = withScore and int(r.score, 0) or nil }
end
-- Profils publics de plusieurs identifiants (une seule requête)
local function Users(ids)
    local out, list = {}, {}
    for id in pairs(ids) do list[#list + 1] = id end
    if #list == 0 then return out end
    local args = { APP }
    for _, id in ipairs(list) do args[#args + 1] = id end
    for _, r in ipairs(MySQL.query.await(([[SELECT a.identifier, a.username, a.display_name, pr.avatar, IFNULL(pr.color, '#FFD60A') AS color, IFNULL(pr.score, 0) AS score
        FROM elyzea_accounts a LEFT JOIN elyzea_ec_profiles pr ON pr.identifier = a.identifier
        WHERE a.app = ? AND a.identifier IN (%s)]]):format(placeholders(#list)), args) or {}) do
        out[r.identifier] = Public(r, true)
    end
    return out
end
local function Relation(me, other)
    local a, b = Pair(me, other)
    return MySQL.single.await('SELECT * FROM elyzea_ec_friends WHERE a = ? AND b = ?', { a, b })
end
local function AreFriends(me, other)
    local r = Relation(me, other)
    return r and r.status == 'friends' and r or nil
end
local function StreakOf(r)
    if not r then return 0 end
    local s = int(r.streak, 0)
    if s > 0 and int(r.streak_day, 0) >= Today() - 1 then return s end
    return 0
end

local function Badges(identifier)
    local snaps = MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_ec_snaps WHERE recipient = ? AND opened = 0', { identifier }) or 0
    local chats = MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_ec_messages WHERE (a = ? OR b = ?) AND sender <> ? AND seen = 0', { identifier, identifier, identifier }) or 0
    local reqs = MySQL.scalar.await("SELECT COUNT(*) FROM elyzea_ec_friends WHERE (a = ? OR b = ?) AND status = 'pending' AND requester <> ?", { identifier, identifier, identifier }) or 0
    return { snaps = int(snaps, 0), chats = int(chats, 0), requests = int(reqs, 0) }
end
local function PushBadges(identifier)
    local s = SourceOf(identifier)
    if s then Push(s, { type = 'badges', badges = Badges(identifier) }) end
end

local function EC_(name, needAccount, fn)
    Register(name, function(src, me, args)
        if not HasApp(me, APP) then return { ok = false, error = 'Application non installée' } end
        local t = GetGameTimer()
        while not Ready and GetGameTimer() - t < 7000 do Wait(100) end
        if not Ready then return { ok = false, error = 'ElyChat démarre, réessaie' } end
        local acc
        if needAccount then
            acc = Account(me.identifier)
            if not acc then return { ok = false, error = 'Crée d\'abord ton compte', noAccount = true } end
        end
        return fn(src, me, type(args) == 'table' and args or {}, acc)
    end)
end

local function CheckUsername(u)
    u = trim(u, 20):lower()
    if not u:match('^[a-z0-9_%.]+$') or #u < 3 then return nil, 'Nom d\'utilisateur : 3 à 20 caractères, lettres, chiffres, _ ou .' end
    return u
end
local function CheckColor(c)
    for _, v in ipairs(CFG.Colors or {}) do if v == c then return c end end
    return (CFG.Colors or {})[1] or '#FFD60A'
end

-- ---------------------------------------------------------
--  Compte et profil
-- ---------------------------------------------------------
EC_('ecInit', false, function(src, me)
    local acc = Account(me.identifier)
    local durations = {}
    for _, d in ipairs(CFG.Durations or { 3, 5, 10, 0 }) do durations[#durations + 1] = int(d, 5) end
    return { ok = true, account = acc and Public(acc, true) or nil, share = acc and acc.share or 'off',
        badges = acc and Badges(me.identifier) or { snaps = 0, chats = 0, requests = 0 },
        limits = { message = MSG_LEN, caption = CAP_LEN, recipients = MAX_TO, durations = durations, chatHours = int(opt('ChatHours', 24), 24), mapRefresh = int(opt('MapRefresh', 15), 15) },
        colors = CFG.Colors or {} }
end)

EC_('ecCreateAccount', false, function(src, me, args)
    if TooFast(src, 'acc', 1500) then return { ok = false, error = 'Patiente un instant' } end
    if Account(me.identifier) then return { ok = false, error = 'Compte déjà créé' } end
    local u, err = CheckUsername(args.username)
    if not u then return { ok = false, error = err } end
    local display = trim(args.display, 30)
    if display == '' then display = A.GetCharName(src) end
    if MySQL.scalar.await('SELECT 1 FROM elyzea_accounts WHERE app = ? AND username = ?', { APP, u }) then
        return { ok = false, error = 'Ce nom d\'utilisateur est déjà pris' }
    end
    local ok = pcall(MySQL.insert.await, 'INSERT INTO elyzea_accounts (identifier, app, username, display_name) VALUES (?, ?, ?, ?)', { me.identifier, APP, u, display })
    if not ok then return { ok = false, error = 'Ce nom d\'utilisateur est déjà pris' } end
    MySQL.update.await('INSERT IGNORE INTO elyzea_ec_profiles (identifier, color) VALUES (?, ?)', { me.identifier, CheckColor(args.color) })
    return { ok = true, account = Public(Account(me.identifier), true) }
end)

EC_('ecUpdateProfile', true, function(src, me, args, acc)
    if TooFast(src, 'profile', 1200) then return { ok = false, error = 'Patiente un instant' } end
    local display = trim(args.display, 30)
    if display == '' then display = acc.display_name end
    local avatar = acc.avatar
    if args.avatar ~= nil then
        local url = trim(args.avatar, 500)
        if url == '' then avatar = nil
        elseif MySQL.scalar.await('SELECT 1 FROM elyzea_gallery WHERE owner = ? AND url = ? AND type = ? LIMIT 1', { me.identifier, url, 'photo' }) then avatar = url
        else return { ok = false, error = 'Choisis une photo de ta galerie' } end
    end
    MySQL.update.await('UPDATE elyzea_accounts SET display_name = ? WHERE identifier = ? AND app = ?', { display, me.identifier, APP })
    MySQL.update.await('INSERT INTO elyzea_ec_profiles (identifier, avatar, color) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE avatar = VALUES(avatar), color = VALUES(color)',
        { me.identifier, avatar, args.color and CheckColor(args.color) or acc.color })
    return { ok = true, account = Public(Account(me.identifier), true) }
end)

-- ---------------------------------------------------------
--  Amis
-- ---------------------------------------------------------
local function FriendRows(identifier)
    return MySQL.query.await('SELECT * FROM elyzea_ec_friends WHERE a = ? OR b = ?', { identifier, identifier }) or {}
end

EC_('ecFriends', true, function(src, me)
    local rows = FriendRows(me.identifier)
    local ids = {}
    for _, r in ipairs(rows) do ids[r.a == me.identifier and r.b or r.a] = true end
    local users = Users(ids)
    local friends, incoming, outgoing = {}, {}, {}
    for _, r in ipairs(rows) do
        local other = r.a == me.identifier and r.b or r.a
        local u = users[other]
        if u then
            if r.status == 'friends' then u.streak = StreakOf(r) friends[#friends + 1] = u
            elseif r.requester == me.identifier then outgoing[#outgoing + 1] = u
            else incoming[#incoming + 1] = u end
        end
    end
    table.sort(friends, function(x, y) return (x.name or ''):lower() < (y.name or ''):lower() end)
    local acc = Account(me.identifier)
    local shareWith = {}
    for _, id in ipairs(decodeList(acc and acc.share_list)) do if users[id] then shareWith[#shareWith + 1] = users[id].u end end
    return { ok = true, friends = friends, incoming = incoming, outgoing = outgoing, share = acc and acc.share or 'off', shareWith = shareWith }
end)

EC_('ecSearch', true, function(src, me, args)
    local q = trim(args.q, 30):lower():gsub('^@', '')
    if #q < 2 then return { ok = true, users = {} } end
    local rows = MySQL.query.await([[SELECT a.identifier, a.username, a.display_name, pr.avatar, IFNULL(pr.color, '#FFD60A') AS color, IFNULL(pr.score, 0) AS score
        FROM elyzea_accounts a LEFT JOIN elyzea_ec_profiles pr ON pr.identifier = a.identifier
        WHERE a.app = ? AND a.identifier <> ? AND (a.username LIKE ? OR a.display_name LIKE ?) ORDER BY a.username LIMIT 15]],
        { APP, me.identifier, likeEscape(q) .. '%', '%' .. likeEscape(q) .. '%' }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local u = Public(r, true)
        local rel = Relation(me.identifier, r.identifier)
        u.rel = not rel and 'none' or rel.status == 'friends' and 'friends' or (rel.requester == me.identifier and 'sent' or 'received')
        out[#out + 1] = u
    end
    return { ok = true, users = out }
end)

EC_('ecAddFriend', true, function(src, me, args, acc)
    if TooFast(src, 'add', 700) then return { ok = false, error = 'Patiente un instant' } end
    local other = IdOf(args.u)
    if not other or other == me.identifier then return { ok = false, error = 'Utilisateur introuvable' } end
    local a, b = Pair(me.identifier, other)
    local rel = Relation(me.identifier, other)
    local os_ = SourceOf(other)
    if rel and rel.status == 'friends' then return { ok = true, rel = 'friends' } end
    if rel and rel.requester ~= me.identifier then
        MySQL.update.await("UPDATE elyzea_ec_friends SET status = 'friends' WHERE a = ? AND b = ?", { a, b })
        if os_ then
            Notify(os_, { app = APP, key = 'ecFriendOk', params = { name = acc.display_name } })
            Push(os_, { type = 'friends' })
        end
        PushBadges(me.identifier)
        return { ok = true, rel = 'friends' }
    end
    if not rel then
        MySQL.insert.await('INSERT IGNORE INTO elyzea_ec_friends (a, b, status, requester) VALUES (?, ?, ?, ?)', { a, b, 'pending', me.identifier })
        if os_ then
            Notify(os_, { app = APP, key = 'ecFriendReq', params = { name = acc.display_name } })
            Push(os_, { type = 'friends' })
            PushBadges(other)
        end
    end
    return { ok = true, rel = 'sent' }
end)

EC_('ecRespond', true, function(src, me, args, acc)
    local other = IdOf(args.u)
    if not other then return { ok = false, error = 'Utilisateur introuvable' } end
    local a, b = Pair(me.identifier, other)
    local rel = Relation(me.identifier, other)
    if not rel or rel.status ~= 'pending' or rel.requester == me.identifier then return { ok = false, error = 'Aucune demande' } end
    if args.accept then
        MySQL.update.await("UPDATE elyzea_ec_friends SET status = 'friends' WHERE a = ? AND b = ?", { a, b })
        local os_ = SourceOf(other)
        if os_ then
            Notify(os_, { app = APP, key = 'ecFriendOk', params = { name = acc.display_name } })
            Push(os_, { type = 'friends' })
        end
    else
        MySQL.update.await('DELETE FROM elyzea_ec_friends WHERE a = ? AND b = ?', { a, b })
    end
    PushBadges(me.identifier)
    return { ok = true }
end)

EC_('ecRemoveFriend', true, function(src, me, args)
    local other = IdOf(args.u)
    if not other then return { ok = false, error = 'Utilisateur introuvable' } end
    local a, b = Pair(me.identifier, other)
    MySQL.update.await('DELETE FROM elyzea_ec_friends WHERE a = ? AND b = ?', { a, b })
    -- il ne voit plus ma position (liste de partage) et je ne vois plus la sienne
    for _, who in ipairs({ me.identifier, other }) do
        local p = MySQL.single.await('SELECT share_list FROM elyzea_ec_profiles WHERE identifier = ?', { who })
        if p and p.share_list then
            local keep = {}
            for _, id in ipairs(decodeList(p.share_list)) do if id ~= me.identifier and id ~= other then keep[#keep + 1] = id end end
            MySQL.update.await('UPDATE elyzea_ec_profiles SET share_list = ? WHERE identifier = ?', { json.encode(keep), who })
        end
    end
    local os_ = SourceOf(other)
    if os_ then Push(os_, { type = 'friends' }) end
    return { ok = true }
end)

-- ---------------------------------------------------------
--  Conversations (liste façon Snapchat : nouveau snap, ouvert, nouveau chat, envoyé…)
-- ---------------------------------------------------------
EC_('ecChats', true, function(src, me)
    local id = me.identifier
    local rows = FriendRows(id)
    local friends, ids = {}, {}
    for _, r in ipairs(rows) do
        if r.status == 'friends' then
            local other = r.a == id and r.b or r.a
            friends[other] = r ids[other] = true
        end
    end
    local users = Users(ids)
    local lastSnap, lastMsg, newSnaps, newMsgs = {}, {}, {}, {}
    for _, s in ipairs(MySQL.query.await([[SELECT s.id, s.sender, s.recipient, s.opened, UNIX_TIMESTAMP(s.created_at) AS ts, s.opened_at FROM elyzea_ec_snaps s
        JOIN (SELECT MAX(id) AS id FROM elyzea_ec_snaps WHERE sender = ? OR recipient = ? GROUP BY IF(sender = ?, recipient, sender)) m ON m.id = s.id]], { id, id, id }) or {}) do
        lastSnap[s.sender == id and s.recipient or s.sender] = s
    end
    for _, m in ipairs(MySQL.query.await([[SELECT x.id, x.a, x.b, x.sender, x.seen, UNIX_TIMESTAMP(x.created_at) AS ts FROM elyzea_ec_messages x
        JOIN (SELECT MAX(id) AS id FROM elyzea_ec_messages WHERE a = ? OR b = ? GROUP BY IF(a = ?, b, a)) m ON m.id = x.id]], { id, id, id }) or {}) do
        lastMsg[m.a == id and m.b or m.a] = m
    end
    for _, r in ipairs(MySQL.query.await('SELECT sender, COUNT(*) AS n FROM elyzea_ec_snaps WHERE recipient = ? AND opened = 0 GROUP BY sender', { id }) or {}) do newSnaps[r.sender] = int(r.n, 0) end
    for _, r in ipairs(MySQL.query.await('SELECT sender, COUNT(*) AS n FROM elyzea_ec_messages WHERE (a = ? OR b = ?) AND sender <> ? AND seen = 0 GROUP BY sender', { id, id, id }) or {}) do newMsgs[r.sender] = int(r.n, 0) end
    local out = {}
    for other, rel in pairs(friends) do
        local u = users[other]
        if u then
            local s, m = lastSnap[other], lastMsg[other]
            -- état affiché : le plus récent des deux
            local st
            if s and (not m or s.ts >= m.ts) then
                if s.sender == id then st = { kind = 'snap', dir = 'out', state = bool(s.opened) and 'opened' or 'delivered', ts = bool(s.opened) and int(s.opened_at, s.ts) or s.ts }
                else st = { kind = 'snap', dir = 'in', state = bool(s.opened) and 'opened' or 'new', ts = s.ts } end
            elseif m then
                if m.sender == id then st = { kind = 'chat', dir = 'out', state = bool(m.seen) and 'opened' or 'delivered', ts = m.ts }
                else st = { kind = 'chat', dir = 'in', state = bool(m.seen) and 'opened' or 'new', ts = m.ts } end
            end
            -- non lus d'abord : un snap non ouvert, sinon un chat non lu (comme l'appli d'origine)
            if newMsgs[other] and not newSnaps[other] then st = { kind = 'chat', dir = 'in', state = 'new', ts = (m and m.ts) or (st and st.ts) or 0 } end
            if newSnaps[other] then st = { kind = 'snap', dir = 'in', state = 'new', ts = (s and s.ts) or (st and st.ts) or 0 } end
            u.status = st
            u.newSnaps = newSnaps[other] or 0
            u.newChats = newMsgs[other] or 0
            u.streak = StreakOf(rel)
            out[#out + 1] = u
        end
    end
    table.sort(out, function(x, y)
        local tx, ty = x.status and x.status.ts or 0, y.status and y.status.ts or 0
        if tx ~= ty then return tx > ty end
        return (x.name or '') < (y.name or '')
    end)
    return { ok = true, chats = out, badges = Badges(id) }
end)

-- ---------------------------------------------------------
--  Snaps
-- ---------------------------------------------------------
local function BumpStreak(sender, recipient)
    local a, b = Pair(sender, recipient)
    local r = MySQL.single.await('SELECT * FROM elyzea_ec_friends WHERE a = ? AND b = ?', { a, b })
    if not r then return end
    local day = Today()
    local aDay, bDay = int(r.a_day, 0), int(r.b_day, 0)
    if sender == a then aDay = day else bDay = day end
    local streak, sday = int(r.streak, 0), int(r.streak_day, 0)
    if aDay == day and bDay == day and sday ~= day then
        streak = (sday == day - 1) and streak + 1 or 1
        sday = day
    end
    MySQL.update.await('UPDATE elyzea_ec_friends SET a_day = ?, b_day = ?, streak = ?, streak_day = ? WHERE a = ? AND b = ?', { aDay, bDay, streak, sday, a, b })
end

EC_('ecSendSnap', true, function(src, me, args, acc)
    if TooFast(src, 'snap', 1500) then return { ok = false, error = 'Patiente un instant' } end
    local url = trim(args.url, 500)
    if url == '' or not MySQL.scalar.await('SELECT 1 FROM elyzea_gallery WHERE owner = ? AND url = ? AND type = ? LIMIT 1', { me.identifier, url, 'photo' }) then
        return { ok = false, error = 'Choisis une photo de ta galerie' }
    end
    local duration = 5
    for _, d in ipairs(CFG.Durations or { 3, 5, 10, 0 }) do if int(args.duration, -1) == int(d, 5) then duration = int(d, 5) end end
    local caption = trim((tostring(args.caption or ''):gsub('[\r\n]', ' ')), CAP_LEN)
    local targets, seen = {}, {}
    for _, u in ipairs(type(args.to) == 'table' and args.to or {}) do
        if #targets >= MAX_TO then break end
        local other = IdOf(u)
        if other and not seen[other] and AreFriends(me.identifier, other) then seen[other] = true targets[#targets + 1] = other end
    end
    if #targets == 0 then return { ok = false, error = 'Choisis au moins un ami' } end
    for _, other in ipairs(targets) do
        MySQL.insert.await('INSERT INTO elyzea_ec_snaps (sender, recipient, url, caption, duration) VALUES (?, ?, ?, ?, ?)', { me.identifier, other, url, caption, duration })
        BumpStreak(me.identifier, other)
        local os_ = SourceOf(other)
        if os_ then
            Notify(os_, { app = APP, key = 'ecSnap', params = { name = acc.display_name } })
            Push(os_, { type = 'snap', from = acc.username })
            PushBadges(other)
        end
    end
    local gain = int(opt('ScoreSend', 1), 1) * #targets
    MySQL.update.await('INSERT INTO elyzea_ec_profiles (identifier, score) VALUES (?, ?) ON DUPLICATE KEY UPDATE score = score + VALUES(score)', { me.identifier, gain })
    return { ok = true, sent = #targets, score = int(acc.score, 0) + gain }
end)

-- Ouvrir un snap reçu : vu UNE seule fois (le lien n'est plus jamais redonné)
EC_('ecOpenSnap', true, function(src, me, args, acc)
    local from = IdOf(args.u)
    if not from then return { ok = false, error = 'Utilisateur introuvable' } end
    local s = MySQL.single.await('SELECT id, url, caption, duration, UNIX_TIMESTAMP(created_at) AS ts FROM elyzea_ec_snaps WHERE sender = ? AND recipient = ? AND opened = 0 ORDER BY id ASC LIMIT 1', { from, me.identifier })
    if not s then return { ok = false, error = 'Aucun nouveau snap' } end
    local n = MySQL.update.await('UPDATE elyzea_ec_snaps SET opened = 1, opened_at = ?, url = NULL WHERE id = ? AND opened = 0', { os.time(), s.id })
    if (n or 0) < 1 then return { ok = false, error = 'Snap déjà ouvert' } end
    MySQL.update.await('INSERT INTO elyzea_ec_profiles (identifier, score) VALUES (?, ?) ON DUPLICATE KEY UPDATE score = score + VALUES(score)', { me.identifier, int(opt('ScoreOpen', 1), 1) })
    local left = MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_ec_snaps WHERE sender = ? AND recipient = ? AND opened = 0', { from, me.identifier }) or 0
    local os_ = SourceOf(from)
    if os_ then Push(os_, { type = 'opened', by = acc.username }) end
    return { ok = true, snap = { url = s.url, caption = s.caption, duration = int(s.duration, 5), ts = s.ts }, left = int(left, 0) }
end)

-- ---------------------------------------------------------
--  Chat
-- ---------------------------------------------------------
EC_('ecChat', true, function(src, me, args)
    local other = IdOf(args.u)
    if not other then return { ok = false, error = 'Utilisateur introuvable' } end
    local rel = AreFriends(me.identifier, other)
    if not rel then return { ok = false, error = 'Vous n\'êtes pas amis' } end
    local a, b = Pair(me.identifier, other)
    local now = os.time()
    MySQL.update.await('UPDATE elyzea_ec_messages SET seen = 1, seen_at = ? WHERE a = ? AND b = ? AND sender = ? AND seen = 0', { now, a, b, other })
    local msgs = MySQL.query.await([[SELECT id, sender, body, seen, saved, UNIX_TIMESTAMP(created_at) AS ts FROM elyzea_ec_messages
        WHERE a = ? AND b = ? ORDER BY id DESC LIMIT 120]], { a, b }) or {}
    local snaps = MySQL.query.await([[SELECT id, sender, opened, UNIX_TIMESTAMP(created_at) AS ts FROM elyzea_ec_snaps
        WHERE ((sender = ? AND recipient = ?) OR (sender = ? AND recipient = ?)) AND created_at > (NOW() - INTERVAL 7 DAY) ORDER BY id DESC LIMIT 60]],
        { me.identifier, other, other, me.identifier }) or {}
    local items = {}
    for _, m in ipairs(msgs) do items[#items + 1] = { id = m.id, kind = 'chat', mine = m.sender == me.identifier, body = m.body, seen = bool(m.seen), saved = bool(m.saved), ts = m.ts } end
    for _, s in ipairs(snaps) do items[#items + 1] = { id = s.id, kind = 'snap', mine = s.sender == me.identifier, opened = bool(s.opened), ts = s.ts } end
    table.sort(items, function(x, y) if x.ts ~= y.ts then return x.ts < y.ts end return x.id < y.id end)
    local os_ = SourceOf(other)
    if os_ then Push(os_, { type = 'seen', by = (Account(me.identifier) or {}).username }) end
    PushBadges(me.identifier)
    local u = Users({ [other] = true })[other]
    if u then u.streak = StreakOf(rel) end
    return { ok = true, user = u, items = items }
end)

EC_('ecSend', true, function(src, me, args, acc)
    if TooFast(src, 'msg', 400) then return { ok = false, error = 'Doucement' } end
    local other = IdOf(args.u)
    if not other or not AreFriends(me.identifier, other) then return { ok = false, error = 'Vous n\'êtes pas amis' } end
    local body = trim((tostring(args.body or ''):gsub('\r', '')), MSG_LEN)
    if body == '' then return { ok = false } end
    local a, b = Pair(me.identifier, other)
    local id = MySQL.insert.await('INSERT INTO elyzea_ec_messages (a, b, sender, body) VALUES (?, ?, ?, ?)', { a, b, me.identifier, body })
    local os_ = SourceOf(other)
    if os_ then
        Notify(os_, { app = APP, key = 'ecChat', params = { name = acc.display_name }, text = body })
        Push(os_, { type = 'chat', from = acc.username, item = { id = id, kind = 'chat', mine = false, body = body, seen = false, saved = false, ts = os.time() } })
        PushBadges(other)
    end
    return { ok = true, item = { id = id, kind = 'chat', mine = true, body = body, seen = false, saved = false, ts = os.time() } }
end)

-- Enregistrer / ne plus enregistrer un message (il ne disparaît pas)
EC_('ecSave', true, function(src, me, args)
    local m = MySQL.single.await('SELECT id, a, b, saved FROM elyzea_ec_messages WHERE id = ?', { int(args.id, 0) })
    if not m or (m.a ~= me.identifier and m.b ~= me.identifier) then return { ok = false } end
    local saved = not bool(m.saved)
    MySQL.update.await('UPDATE elyzea_ec_messages SET saved = ? WHERE id = ?', { saved and 1 or 0, m.id })
    return { ok = true, saved = saved }
end)

-- ---------------------------------------------------------
--  Carte : position partagée
-- ---------------------------------------------------------
local function LivePos(identifier)
    local s = SourceOf(identifier)
    if not s then return nil end
    local ped = GetPlayerPed(s)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    if not c or (c.x == 0.0 and c.y == 0.0) then return nil end
    return c
end
-- Est-ce que `owner` partage sa position avec `viewer` ?
local function SharesWith(prof, viewer)
    if not prof or prof.share == 'off' then return false end
    if prof.share == 'all' then return true end
    for _, id in ipairs(decodeList(prof.share_list)) do if id == viewer then return true end end
    return false
end

EC_('ecMap', true, function(src, me)
    local id = me.identifier
    local rows = FriendRows(id)
    local ids = {}
    for _, r in ipairs(rows) do if r.status == 'friends' then ids[r.a == id and r.b or r.a] = true end end
    local list = {}
    for other in pairs(ids) do list[#list + 1] = other end
    local profs = {}
    if #list > 0 then
        for _, p in ipairs(MySQL.query.await(('SELECT identifier, share, share_list, last_x, last_y, last_ts FROM elyzea_ec_profiles WHERE identifier IN (%s)'):format(placeholders(#list)), list) or {}) do
            profs[p.identifier] = p
        end
    end
    local users = Users(ids)
    local out, now = {}, os.time()
    for other in pairs(ids) do
        local p, u = profs[other], users[other]
        if u and SharesWith(p, id) then
            local c = LivePos(other)
            if c then u.x, u.y, u.ts, u.live = c.x, c.y, now, true
            elseif p.last_x and p.last_y then u.x, u.y, u.ts, u.live = p.last_x, p.last_y, int(p.last_ts, 0), false end
            if u.x then out[#out + 1] = u end
        end
    end
    local mine = LivePos(id)
    local acc = Account(id)
    return { ok = true, friends = out, me = mine and { x = mine.x, y = mine.y } or nil, share = acc and acc.share or 'off', now = now }
end)

EC_('ecSetShare', true, function(src, me, args)
    local mode = (args.mode == 'all' or args.mode == 'some') and args.mode or 'off'
    local list = {}
    if mode == 'some' then
        for _, u in ipairs(type(args.list) == 'table' and args.list or {}) do
            local other = IdOf(u)
            if other and AreFriends(me.identifier, other) and #list < 200 then list[#list + 1] = other end
        end
    end
    -- mode fantôme : la dernière position connue est effacée
    if mode == 'off' then
        MySQL.update.await('INSERT INTO elyzea_ec_profiles (identifier, share, share_list, last_x, last_y, last_ts) VALUES (?, ?, ?, NULL, NULL, NULL) ON DUPLICATE KEY UPDATE share = VALUES(share), share_list = VALUES(share_list), last_x = NULL, last_y = NULL, last_ts = NULL',
            { me.identifier, mode, json.encode(list) })
    else
        MySQL.update.await('INSERT INTO elyzea_ec_profiles (identifier, share, share_list) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE share = VALUES(share), share_list = VALUES(share_list)',
            { me.identifier, mode, json.encode(list) })
    end
    return { ok = true, share = mode }
end)

-- Dernière position connue (pour les amis quand on est hors ligne) : enregistrée régulièrement et à la déconnexion
local Sharing = {}   -- [identifier] = true si partage actif (rafraîchi régulièrement)
local function SavePos(identifier, src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local c = GetEntityCoords(ped)
    if not c or (c.x == 0.0 and c.y == 0.0) then return end
    MySQL.update.await("UPDATE elyzea_ec_profiles SET last_x = ?, last_y = ?, last_ts = ? WHERE identifier = ? AND share <> 'off'", { c.x, c.y, os.time(), identifier })
end
CreateThread(function()
    while not Ready do Wait(1000) end
    while true do
        Wait(math.max(15, int(opt('SavePositionEvery', 60), 60)) * 1000)
        local ids, srcs = {}, {}
        for s, p in pairs(Players) do if p.identifier then ids[#ids + 1] = p.identifier srcs[p.identifier] = s end end
        Sharing = {}
        if #ids > 0 then
            for _, r in ipairs(MySQL.query.await(("SELECT identifier FROM elyzea_ec_profiles WHERE share <> 'off' AND identifier IN (%s)"):format(placeholders(#ids)), ids) or {}) do
                Sharing[r.identifier] = true
                SavePos(r.identifier, srcs[r.identifier])
            end
        end
    end
end)
AddEventHandler('playerDropped', function()
    local src = source
    local p = Players[src]
    if p and p.identifier and Sharing[p.identifier] then SavePos(p.identifier, src) end
    local s = tostring(src) .. ':'
    for k in pairs(Throttle) do if k:sub(1, #s) == s then Throttle[k] = nil end end
end)

-- ---------------------------------------------------------
--  Ménage : messages vus (non enregistrés) après ChatHours, snaps jamais ouverts après SnapDays
-- ---------------------------------------------------------
local function Cleanup()
    if not Ready then return end
    MySQL.update.await('DELETE FROM elyzea_ec_messages WHERE seen = 1 AND saved = 0 AND seen_at < ?', { os.time() - int(opt('ChatHours', 24), 24) * 3600 })
    MySQL.update.await('DELETE FROM elyzea_ec_snaps WHERE opened = 0 AND created_at < (NOW() - INTERVAL ? DAY)', { int(opt('SnapDays', 30), 30) })
    MySQL.update.await('DELETE FROM elyzea_ec_snaps WHERE opened = 1 AND created_at < (NOW() - INTERVAL 30 DAY)')
end
ElyChatCleanup = Cleanup   -- pour les tests hors jeu
CreateThread(function()
    while not Ready do Wait(1000) end
    while true do pcall(Cleanup) Wait(10 * 60 * 1000) end
end)
