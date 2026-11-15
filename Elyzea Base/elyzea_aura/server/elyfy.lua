-- =========================================================
--  ELYFY : streaming musical du téléphone (comme Spotify, aux couleurs d'Elyzea)
--  · Catalogue : Audius (musique libre, titres complets, sans clé), YouTube (si clé), titres du serveur,
--    titres de la ville (musique importée par les joueurs).
--  · Bibliothèque : titres likés, playlists, écoutés récemment, téléchargements (ElyAura 4 et plus).
--  · Mes titres : musique importée depuis l'ordinateur (page web + code à usage unique) ou par lien.
--  Sécurité : le téléphone n'envoie que des clés de titres ; le serveur retrouve lui-même le titre
--  (jamais un lien libre), vérifie l'appareil et les quotas. La clé de l'hébergeur reste sur le serveur.
-- =========================================================
local A = AuraCore
if A.AddRepair then A.AddRepair('^ef%u', 'sql/elyfy.sql', 'elyzea_ef_', 'ElyFy') end
local Register, Notify, Players, trim, HasApp = A.Register, A.Notify, A.Players, A.trim, A.HasApp
local CFG = Config.ElyFy or {}
local APP = 'elyfy'

-- ---------------------------------------------------------
--  Base de données
-- ---------------------------------------------------------
local Ready = false
CreateThread(function()
    local t = GetGameTimer()
    while not A.IsSchemaReady() and GetGameTimer() - t < 30000 do Wait(100) end
    local sql = LoadResourceFile(GetCurrentResourceName(), 'sql/elyfy.sql') or ''
    for statement in sql:gmatch('[^;]+') do
        local q = statement:gsub('%-%-[^\n]*', ''):gsub('^%s+', ''):gsub('%s+$', '')
        if q ~= '' then
            local ok, err = pcall(MySQL.query.await, q)
            if not ok then print('^1[elyzea_aura] ElyFy : table non créée : ' .. tostring(err) .. '^0') end
        end
    end
    -- même collation que les autres tables (sinon les jointures échouent : « Illegal mix of collations »)
    pcall(function() exports.elyzea_core:AlignCollations() end)
    Ready = true
    print(('^2[elyzea_aura] ElyFy prêt (Audius %s, YouTube %s, import depuis l\'ordinateur %s).^0'):format(
        (CFG.Audius or {}).Enabled ~= false and 'oui' or 'non', (((CFG.YouTubeApiKey or '') ~= '' or ((Config.Itoune or {}).YouTubeApiKey or '') ~= '') and 'oui' or 'non'),
        (CFG.Import or {}).Enabled == false and 'non' or 'oui (adresse vérifiée dans quelques secondes)'))
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
AddEventHandler('playerDropped', function()
    local s = tostring(source) .. ':'
    for k in pairs(Throttle) do if k:sub(1, #s) == s then Throttle[k] = nil end end
end)
local function int(v, d) v = tonumber(v) if not v or v ~= v then return d end return math.floor(v) end
local function bool(v) return v == 1 or v == true or v == '1' end
local function SourceOf(identifier) for s, d in pairs(Players) do if d.identifier == identifier then return s end end end
local function Push(src, data) TriggerClientEvent('elyzea_aura:client:elyfy', src, data) end
local UrlEncode = A.UrlEncode or function(s) return (tostring(s):gsub('[^%w%-%._~]', function(c) return ('%%%02X'):format(c:byte()) end)) end

local function Http(method, url, body, headers)
    local p = promise.new()
    PerformHttpRequest(url, function(code, resp, _, err) p:resolve({ code = code, body = resp or err }) end, method, body or '', headers or {})
    return Citizen.Await(p)
end
local function JsonReq(method, url, body, headers)
    local r = Http(method, url, body, headers)
    local ok, d = pcall(json.decode, r.body or '')
    return r.code, (ok and type(d) == 'table') and d or nil
end
local function Entities(s)
    return (tostring(s or ''):gsub('&#39;', "'"):gsub('&quot;', '"'):gsub('&amp;', '&'):gsub('&lt;', '<'):gsub('&gt;', '>'))
end

-- Résultats mis en cache (moins d'appels aux catalogues)
local Cache = {}
local function Cached(key, ttl, fn)
    local c, now = Cache[key], os.time()
    if c and now - c.t < ttl then return c.v end
    local v = fn()
    Cache[key] = { t = now, v = v }
    return v
end

-- Titres connus du serveur (renvoyés au téléphone) : le téléphone ne renvoie ensuite que leur clé
local Known, KnownCount = {}, 0
local function Track(t)
    if not t or not t.key or not t.url then return nil end
    if not Known[t.key] then KnownCount = KnownCount + 1 end
    if KnownCount > 20000 then Known, KnownCount = {}, 0 end
    Known[t.key] = t
    return t
end
local function Public(t)
    if not t then return nil end
    return { key = t.key, title = t.title, artist = t.artist, url = t.url, thumb = t.thumb, source = t.source, duration = t.duration,
        lyrics = t.lyrics, ai = t.ai, plays = t.plays, likes = t.likes, owner = t.ownerName }
end
local function List(list) local out = {} for _, t in ipairs(list or {}) do out[#out + 1] = Public(t) end return out end

-- Appareil : niveau du téléphone utilisé (téléchargements à partir de l'ElyAura 4)
local function Tier(src, me)
    if not Devices or not Config.Phones then return 6 end
    local n = me.model or Devices.ModelOf(src)
    local m = n and Config.Phones.Models[n]
    return m and m.tier or 0
end

-- ---------------------------------------------------------
--  Sources : Audius, YouTube, serveur, ville
-- ---------------------------------------------------------
local AUD = CFG.Audius or {}
local AUD_APP = UrlEncode(AUD.AppName or 'ElyzeaFA')
local AudiusHost = nil
local function AudiusBase()
    if AUD.Enabled == false then return nil end
    if AudiusHost then return AudiusHost end
    local host = (AUD.Host or 'https://api.audius.co'):gsub('/+$', '')
    local code, d = JsonReq('GET', host .. '/v1/tracks/trending?limit=1&app_name=' .. AUD_APP)
    if code == 200 and d and d.data then AudiusHost = host return host end
    -- ancienne passerelle : elle renvoie la liste des serveurs disponibles
    local c2, nodes = JsonReq('GET', 'https://api.audius.co')
    if c2 == 200 and nodes and type(nodes.data) == 'table' and type(nodes.data[1]) == 'string' then AudiusHost = nodes.data[1]:gsub('/+$', '') return AudiusHost end
    return nil
end
local function AudiusTrack(x)
    if type(x) ~= 'table' or not x.id or x.is_streamable == false or x.is_delete then return nil end
    local host = AudiusBase(); if not host then return nil end
    local art = type(x.artwork) == 'table' and (x.artwork['480x480'] or x.artwork['150x150']) or nil
    return Track({ key = 'audius:' .. tostring(x.id):sub(1, 40), title = trim(x.title or 'Sans titre', 80), artist = trim(type(x.user) == 'table' and x.user.name or 'Artiste', 60),
        url = ('%s/v1/tracks/%s/stream?app_name=%s'):format(host, UrlEncode(x.id), AUD_APP), thumb = art, source = 'audius', duration = int(x.duration, 0), genre = x.genre })
end
local function AudiusList(path)
    local host = AudiusBase(); if not host then return {} end
    local code, d = JsonReq('GET', host .. path .. (path:find('?', 1, true) and '&' or '?') .. 'app_name=' .. AUD_APP)
    if code ~= 200 or not d or type(d.data) ~= 'table' then AudiusHost = nil return {} end
    local out = {}
    for _, x in ipairs(d.data) do local t = AudiusTrack(x) if t then out[#out + 1] = t end end
    return out
end

local function YtKey()
    local k = CFG.YouTubeApiKey or ''
    if k == '' then k = (Config.Itoune or {}).YouTubeApiKey or '' end
    return k
end
local function YouTubeSearch(q)
    local key = YtKey()
    if key == '' then return {} end
    local code, d = JsonReq('GET', ('https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&videoCategoryId=10&maxResults=15&q=%s&key=%s'):format(UrlEncode(q), key))
    if code ~= 200 or not d or type(d.items) ~= 'table' then return {} end
    local out = {}
    for _, it in ipairs(d.items) do
        local id = it.id and it.id.videoId
        local sn = it.snippet or {}
        if id and id:match('^[%w_%-]+$') then
            local th = sn.thumbnails and (sn.thumbnails.high or sn.thumbnails.medium or sn.thumbnails.default) or {}
            out[#out + 1] = Track({ key = 'yt:' .. id, title = trim(Entities(sn.title), 80), artist = trim(Entities(sn.channelTitle or 'YouTube'), 60),
                url = 'https://www.youtube.com/watch?v=' .. id, thumb = th.url, source = 'youtube' })
        end
    end
    return out
end

local function CatalogTrack(i)
    local c = (CFG.Catalog or {})[i]
    if type(c) ~= 'table' or type(c.url) ~= 'string' or not c.url:match('^https://') then return nil end
    return Track({ key = 'cat:' .. i, title = trim(c.title or 'Titre', 80), artist = trim(c.artist or 'Elyzea FA', 60), url = c.url, thumb = (c.thumb or '') ~= '' and c.thumb or nil, source = 'catalog', genre = c.genre })
end
local function Catalog()
    local out = {}
    for i in ipairs(CFG.Catalog or {}) do local t = CatalogTrack(i) if t then out[#out + 1] = t end end
    return out
end

-- Titres de la ville (IA et artistes) : seulement prêts ; publics, ou les miens
local EF_SEL = [[SELECT id, owner, kind, artist, title, url, lyrics, style, plays, likes, public FROM elyzea_ef_tracks WHERE status = 'ready' AND url IS NOT NULL]]
local function CityTrack(r)
    if not r then return nil end
    return Track({ key = 'ef:' .. r.id, title = r.title, artist = r.artist, url = r.url, source = r.kind == 'ai' and 'ai' or 'city', lyrics = r.lyrics,
        ai = r.kind == 'ai', plays = tonumber(r.plays) or 0, likes = tonumber(r.likes) or 0, style = r.style, owner = r.owner })
end
local function CityTracks(where, params, limit)
    local out = {}
    for _, r in ipairs(MySQL.query.await(EF_SEL .. ' AND ' .. where .. (' LIMIT %d'):format(limit or 30), params or {}) or {}) do out[#out + 1] = CityTrack(r) end
    return out
end

-- Retrouve un titre à partir de sa clé (jamais à partir d'un lien envoyé par le téléphone)
local function Resolve(key, me)
    if type(key) ~= 'string' or #key > 80 then return nil end
    local kind, id = key:match('^(%a+):(.+)$')
    if kind == 'ef' then
        local r = MySQL.single.await(EF_SEL .. ' AND id = ? AND (public = 1 OR owner = ?)', { int(id, 0), me and me.identifier or '' })
        return CityTrack(r)
    elseif kind == 'cat' then
        return CatalogTrack(int(id, 0))
    end
    if Known[key] then return Known[key] end
    if kind == 'audius' then
        local host = AudiusBase(); if not host then return nil end
        local code, d = JsonReq('GET', ('%s/v1/tracks/%s?app_name=%s'):format(host, UrlEncode(id), AUD_APP))
        return code == 200 and d and AudiusTrack(d.data) or nil
    elseif kind == 'yt' and id:match('^[%w_%-]+$') and A.ResolveTrack then
        local t = A.ResolveTrack('https://www.youtube.com/watch?v=' .. id)
        if t then return Track({ key = key, title = t.title, artist = t.artist, url = t.url, thumb = t.thumb, source = 'youtube' }) end
    elseif kind == 'url' and me then
        -- lien collé par le joueur : retrouvé dans SA bibliothèque
        local raw = MySQL.scalar.await('SELECT data FROM elyzea_ef_saved WHERE identifier = ? AND track_key = ?', { me.identifier, key })
            or MySQL.scalar.await('SELECT data FROM elyzea_ef_history WHERE identifier = ? AND track_key = ?', { me.identifier, key })
        local ok, t = pcall(json.decode, raw or '')
        if ok and type(t) == 'table' and t.url then t.key = key return t end
    end
    return nil
end
local function Data(t) return json.encode({ key = t.key, title = t.title, artist = t.artist, url = t.url, thumb = t.thumb, source = t.source, duration = t.duration, lyrics = t.lyrics, ai = t.ai }) end
local function Decode(rows)
    local out = {}
    for _, r in ipairs(rows or {}) do
        local ok, t = pcall(json.decode, r.data or '')
        if ok and type(t) == 'table' then
            t.key = r.track_key; t.liked = r.liked and bool(r.liked) or nil; t.downloaded = r.downloaded and bool(r.downloaded) or nil
            out[#out + 1] = t
        end
    end
    return out
end

-- Enregistre un appel ElyFy : application installée, base prête
local function EF_(name, fn)
    Register(name, function(src, me, args)
        if not HasApp(me, APP) then return { ok = false, error = 'Application non installée' } end
        local t = GetGameTimer()
        while not Ready and GetGameTimer() - t < 10000 do Wait(100) end
        if not Ready then return { ok = false, error = 'ElyFy démarre, réessaie' } end
        return fn(src, me, args or {})
    end)
end

-- ---------------------------------------------------------
--  Genres (cartes « Parcourir tout »)
-- ---------------------------------------------------------
local GENRES = {
    { id = 'rap', label = 'Rap', color = '#9B5CFF', audius = 'Hip-Hop/Rap', yt = 'rap français' },
    { id = 'pop', label = 'Pop', color = '#FF6FB5', audius = 'Pop', yt = 'pop hits' },
    { id = 'electro', label = 'Électro', color = '#2EE6F0', audius = 'Electronic', yt = 'electro house' },
    { id = 'rnb', label = 'R&B', color = '#C9A6FF', audius = 'R&B/Soul', yt = 'rnb' },
    { id = 'lofi', label = 'Lo-fi', color = '#6FE7F2', audius = 'Lo-Fi', yt = 'lofi hip hop' },
    { id = 'rock', label = 'Rock', color = '#E8590C', audius = 'Rock', yt = 'rock' },
    { id = 'afro', label = 'Afro', color = '#3EE6B0', audius = 'World', yt = 'afrobeats' },
    { id = 'latin', label = 'Latino', color = '#F59E0B', audius = 'Latin', yt = 'reggaeton' },
    { id = 'house', label = 'House', color = '#FF2D55', audius = 'House', yt = 'house music' },
    { id = 'trap', label = 'Trap', color = '#7B2FF7', audius = 'Trap', yt = 'trap' },
    { id = 'jazz', label = 'Jazz', color = '#FFB547', audius = 'Jazz', yt = 'jazz' },
    { id = 'chill', label = 'Chill', color = '#3B82F6', audius = 'Ambient', yt = 'chill music' },
    { id = 'reggae', label = 'Reggae', color = '#22C55E', audius = 'Reggae', yt = 'reggae' },
    { id = 'metal', label = 'Metal', color = '#64748B', audius = 'Metal', yt = 'metal' },
    { id = 'classique', label = 'Classique', color = '#A99BC9', audius = 'Classical', yt = 'musique classique' },
    { id = 'ville', label = 'Créations de la ville', color = '#FF2D7A' },
}
local function GenreOf(id) for _, g in ipairs(GENRES) do if g.id == id then return g end end end

-- ---------------------------------------------------------
--  Accueil, recherche, genres
-- ---------------------------------------------------------
local function Saved(me, where, order, limit)
    return Decode(MySQL.query.await(('SELECT track_key, data, liked, downloaded FROM elyzea_ef_saved WHERE identifier = ? AND %s ORDER BY %s LIMIT %d'):format(where, order, limit or 300), { me.identifier }))
end
local function Downloads(src, me)
    local tier = Tier(src, me)
    local d = CFG.Downloads or {}
    local max = (d.Max or {})[tier] or 0
    return { allowed = tier >= (d.MinTier or 4), tier = tier, minTier = d.MinTier or 4, max = max,
        count = MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_ef_saved WHERE identifier = ? AND downloaded = 1', { me.identifier }) or 0 }
end

EF_('efInit', function(src, me)
    local artist = MySQL.scalar.await('SELECT artist FROM elyzea_ef_profiles WHERE identifier = ?', { me.identifier }) or A.GetCharName(src)
    local genres = {}
    for _, g in ipairs(GENRES) do genres[#genres + 1] = { id = g.id, label = g.label, color = g.color } end
    return { ok = true, artist = artist, downloads = Downloads(src, me), genres = genres, youtube = YtKey() ~= '',
        import = { enabled = (CFG.Import or {}).Enabled ~= false, maxMb = int((CFG.Import or {}).MaxMB, 15) } }
end)

EF_('efHome', function(src, me)
    local recent = Decode(MySQL.query.await('SELECT track_key, data FROM elyzea_ef_history WHERE identifier = ? ORDER BY played_at DESC LIMIT 12', { me.identifier }))
    local trending = Cached('trend', 900, function() return AudiusList('/v1/tracks/trending?time=week&limit=20') end)
    local city = CityTracks('public = 1 ORDER BY plays DESC, id DESC', {}, 12)
    local fresh = CityTracks('public = 1 ORDER BY id DESC', {}, 12)
    local pls = MySQL.query.await('SELECT id, name, (SELECT COUNT(*) FROM elyzea_ef_playlist_items i WHERE i.playlist_id = p.id) AS n FROM elyzea_ef_playlists p WHERE owner = ? ORDER BY updated_at DESC LIMIT 4', { me.identifier }) or {}
    local mixes = {}
    for _, gid in ipairs({ 'rap', 'pop', 'electro', 'lofi', 'rnb', 'afro' }) do local g = GenreOf(gid) mixes[#mixes + 1] = { id = g.id, label = g.label, color = g.color } end
    return { ok = true, recent = recent, trending = List(trending), city = List(city), fresh = List(fresh), catalog = List(Catalog()), playlists = pls, mixes = mixes,
        liked = MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_ef_saved WHERE identifier = ? AND liked = 1', { me.identifier }) or 0 }
end)

EF_('efGenre', function(src, me, args)
    local g = GenreOf(args.id)
    if not g then return { ok = false, error = 'Genre inconnu' } end
    local tracks
    if g.id == 'ville' then tracks = CityTracks('public = 1 ORDER BY plays DESC, id DESC', {}, 50)
    else
        tracks = Cached('genre:' .. g.id, 900, function() return AudiusList('/v1/tracks/trending?time=month&limit=30&genre=' .. UrlEncode(g.audius)) end)
        if #tracks == 0 and YtKey() ~= '' then tracks = Cached('ytg:' .. g.id, 3600, function() return YouTubeSearch(g.yt) end) end
    end
    return { ok = true, genre = { id = g.id, label = g.label, color = g.color }, tracks = List(tracks) }
end)

EF_('efSearch', function(src, me, args)
    if TooFast(src, 'search', 400) then return { ok = false, error = 'Patiente un instant' } end
    local q = trim(args.q, 60)
    if #q < 2 then return { ok = true, tracks = {}, city = {}, youtube = {} } end
    local lq = q:lower()
    local aud = Cached('s:' .. lq, 600, function() return AudiusList('/v1/tracks/search?limit=20&query=' .. UrlEncode(q)) end)
    local yt = Cached('y:' .. lq, 1800, function() return YouTubeSearch(q) end)
    local like = '%' .. lq:gsub('[\\%%_]', '\\%0') .. '%'
    local city = CityTracks('public = 1 AND (LOWER(title) LIKE ? OR LOWER(artist) LIKE ?) ORDER BY plays DESC', { like, like }, 20)
    local cat = {}
    for _, t in ipairs(Catalog()) do if (t.title .. ' ' .. t.artist):lower():find(lq, 1, true) then cat[#cat + 1] = t end end
    for _, t in ipairs(cat) do table.insert(city, 1, t) end
    return { ok = true, tracks = List(aud), youtube = List(yt), city = List(city) }
end)

-- Lien collé (YouTube, Spotify, audio) : comme Itoune
EF_('efLink', function(src, me, args)
    if TooFast(src, 'link', 1500) then return { ok = false, error = 'Patiente un instant' } end
    if not A.ResolveTrack then return { ok = false, error = 'Lien non reconnu' } end
    local t, err = A.ResolveTrack(trim(args.link, 500))
    if not t then return { ok = false, error = err } end
    local key
    local yt = t.url:match('[?&]v=([%w_%-]+)')
    if yt then key = 'yt:' .. yt else key = 'url:' .. (GetHashKey and tostring(GetHashKey(t.url)) or tostring(#t.url)) end
    local tr = Track({ key = key, title = trim(t.title, 80), artist = trim(t.artist or 'Lien', 60), url = t.url, thumb = t.thumb, source = t.source == 'direct' and 'link' or (t.source or 'youtube') })
    -- garde le lien dans l'historique (retrouvé ensuite par sa clé)
    MySQL.update.await('INSERT INTO elyzea_ef_history (identifier, track_key, data) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data), played_at = CURRENT_TIMESTAMP', { me.identifier, key, Data(tr) })
    return { ok = true, track = Public(tr) }
end)

-- Écouté : historique (+ compteur d'écoutes des titres de la ville, une fois par 10 min et par joueur)
local PlayMark = {}
EF_('efPlayed', function(src, me, args)
    local t = Resolve(args.key, me)
    if not t then return { ok = false } end
    MySQL.update.await('INSERT INTO elyzea_ef_history (identifier, track_key, data) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data), played_at = CURRENT_TIMESTAMP', { me.identifier, t.key, Data(t) })
    local id = t.key:match('^ef:(%d+)$')
    if id then
        local k, now = me.identifier .. ':' .. id, os.time()
        if not PlayMark[k] or now - PlayMark[k] > 600 then PlayMark[k] = now MySQL.update.await('UPDATE elyzea_ef_tracks SET plays = plays + 1 WHERE id = ?', { tonumber(id) }) end
    end
    MySQL.update.await([[DELETE FROM elyzea_ef_history WHERE identifier = ? AND track_key NOT IN
        (SELECT track_key FROM (SELECT track_key FROM elyzea_ef_history WHERE identifier = ? ORDER BY played_at DESC LIMIT 60) keep)]], { me.identifier, me.identifier })
    return { ok = true }
end)

-- ---------------------------------------------------------
--  Bibliothèque : j'aime, téléchargements
-- ---------------------------------------------------------
local function SavedRow(me, t)
    MySQL.update.await('INSERT INTO elyzea_ef_saved (identifier, track_key, data) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)', { me.identifier, t.key, Data(t) })
end
local function Cleanup(me, key)
    MySQL.update.await('DELETE FROM elyzea_ef_saved WHERE identifier = ? AND track_key = ? AND liked = 0 AND downloaded = 0', { me.identifier, key })
end

EF_('efLike', function(src, me, args)
    if TooFast(src, 'like', 250) then return { ok = false } end
    local t = Resolve(args.key, me)
    if not t then return { ok = false, error = 'Titre introuvable' } end
    local cur = MySQL.scalar.await('SELECT liked FROM elyzea_ef_saved WHERE identifier = ? AND track_key = ?', { me.identifier, t.key })
    local want = args.like
    if want == nil then want = not bool(cur) end
    SavedRow(me, t)
    MySQL.update.await('UPDATE elyzea_ef_saved SET liked = ?, liked_at = IF(?, NOW(), liked_at) WHERE identifier = ? AND track_key = ?', { want and 1 or 0, want and 1 or 0, me.identifier, t.key })
    local id = t.key:match('^ef:(%d+)$')
    if id then
        if want then
            if (MySQL.update.await('INSERT IGNORE INTO elyzea_ef_track_likes (track_id, identifier) VALUES (?, ?)', { tonumber(id), me.identifier }) or 0) > 0 then
                MySQL.update.await('UPDATE elyzea_ef_tracks SET likes = likes + 1 WHERE id = ?', { tonumber(id) })
            end
        elseif (MySQL.update.await('DELETE FROM elyzea_ef_track_likes WHERE track_id = ? AND identifier = ?', { tonumber(id), me.identifier }) or 0) > 0 then
            MySQL.update.await('UPDATE elyzea_ef_tracks SET likes = GREATEST(likes - 1, 0) WHERE id = ?', { tonumber(id) })
        end
    end
    if not want then Cleanup(me, t.key) end
    return { ok = true, liked = want }
end)

EF_('efLiked', function(src, me)
    return { ok = true, tracks = Saved(me, 'liked = 1', 'liked_at DESC') }
end)

-- Téléchargement : enregistré DANS le téléphone (ElyAura 4 et plus, place limitée selon le modèle)
EF_('efDownload', function(src, me, args)
    if TooFast(src, 'dl', 300) then return { ok = false, error = 'Patiente un instant' } end
    local d = Downloads(src, me)
    if not d.allowed then return { ok = false, error = ('Téléchargement disponible à partir de l\'ElyAura %d'):format(d.minTier), needTier = d.minTier } end
    local t = Resolve(args.key, me)
    if not t then return { ok = false, error = 'Titre introuvable' } end
    if args.remove then
        MySQL.update.await('UPDATE elyzea_ef_saved SET downloaded = 0 WHERE identifier = ? AND track_key = ?', { me.identifier, t.key })
        Cleanup(me, t.key)
        return { ok = true, downloaded = false, downloads = Downloads(src, me) }
    end
    local already = bool(MySQL.scalar.await('SELECT downloaded FROM elyzea_ef_saved WHERE identifier = ? AND track_key = ?', { me.identifier, t.key }))
    if not already and d.count >= d.max then return { ok = false, error = ('Mémoire pleine : %d titres maximum sur ce téléphone'):format(d.max) } end
    SavedRow(me, t)
    MySQL.update.await('UPDATE elyzea_ef_saved SET downloaded = 1, downloaded_at = NOW() WHERE identifier = ? AND track_key = ?', { me.identifier, t.key })
    return { ok = true, downloaded = true, downloads = Downloads(src, me) }
end)

EF_('efDownloads', function(src, me)
    return { ok = true, tracks = Saved(me, 'downloaded = 1', 'downloaded_at DESC'), downloads = Downloads(src, me) }
end)

-- État « j'aime / téléchargé » d'une liste de titres (pour l'affichage)
EF_('efStates', function(src, me, args)
    local out = {}
    for _, r in ipairs(MySQL.query.await('SELECT track_key, liked, downloaded FROM elyzea_ef_saved WHERE identifier = ?', { me.identifier }) or {}) do
        out[r.track_key] = { liked = bool(r.liked), downloaded = bool(r.downloaded) }
    end
    return { ok = true, states = out }
end)

-- ---------------------------------------------------------
--  Playlists
-- ---------------------------------------------------------
local function MyPlaylist(me, id)
    return MySQL.single.await('SELECT id, name FROM elyzea_ef_playlists WHERE id = ? AND owner = ?', { int(id, 0), me.identifier })
end
EF_('efPlaylists', function(src, me)
    local rows = MySQL.query.await([[SELECT p.id, p.name, (SELECT COUNT(*) FROM elyzea_ef_playlist_items i WHERE i.playlist_id = p.id) AS n,
        (SELECT i.data FROM elyzea_ef_playlist_items i WHERE i.playlist_id = p.id ORDER BY i.id ASC LIMIT 1) AS first
        FROM elyzea_ef_playlists p WHERE p.owner = ? ORDER BY p.updated_at DESC]], { me.identifier }) or {}
    for _, r in ipairs(rows) do
        local ok, f = pcall(json.decode, r.first or '')
        r.thumb = ok and type(f) == 'table' and f.thumb or nil
        r.first = nil
    end
    return { ok = true, playlists = rows,
        liked = MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_ef_saved WHERE identifier = ? AND liked = 1', { me.identifier }) or 0,
        downloads = Downloads(src, me) }
end)
EF_('efPlaylistCreate', function(src, me, args)
    if TooFast(src, 'pl', 800) then return { ok = false, error = 'Patiente un instant' } end
    local name = trim(args.name, 50)
    if name == '' then name = 'Ma playlist' end
    if (MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_ef_playlists WHERE owner = ?', { me.identifier }) or 0) >= int(CFG.PlaylistsMax, 50) then
        return { ok = false, error = 'Nombre maximum de playlists atteint' }
    end
    local id = MySQL.insert.await('INSERT INTO elyzea_ef_playlists (owner, name) VALUES (?, ?)', { me.identifier, name })
    return { ok = true, id = id }
end)
EF_('efPlaylist', function(src, me, args)
    local p = MyPlaylist(me, args.id)
    if not p then return { ok = false, error = 'Playlist introuvable' } end
    p.tracks = Decode(MySQL.query.await('SELECT track_key, data FROM elyzea_ef_playlist_items WHERE playlist_id = ? ORDER BY id ASC', { p.id }))
    return { ok = true, playlist = p }
end)
EF_('efPlaylistAdd', function(src, me, args)
    local p = MyPlaylist(me, args.id)
    if not p then return { ok = false, error = 'Playlist introuvable' } end
    local t = Resolve(args.key, me)
    if not t then return { ok = false, error = 'Titre introuvable' } end
    if (MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_ef_playlist_items WHERE playlist_id = ?', { p.id }) or 0) >= int(CFG.PlaylistItemsMax, 300) then
        return { ok = false, error = 'Playlist pleine' }
    end
    local added = MySQL.update.await('INSERT IGNORE INTO elyzea_ef_playlist_items (playlist_id, track_key, data) VALUES (?, ?, ?)', { p.id, t.key, Data(t) })
    MySQL.update.await('UPDATE elyzea_ef_playlists SET updated_at = NOW() WHERE id = ?', { p.id })
    return { ok = true, added = (added or 0) > 0, name = p.name }
end)
EF_('efPlaylistRemove', function(src, me, args)
    local p = MyPlaylist(me, args.id)
    if not p then return { ok = false, error = 'Playlist introuvable' } end
    MySQL.update.await('DELETE FROM elyzea_ef_playlist_items WHERE playlist_id = ? AND track_key = ?', { p.id, tostring(args.key or '') })
    return { ok = true }
end)
EF_('efPlaylistRename', function(src, me, args)
    local p = MyPlaylist(me, args.id)
    if not p then return { ok = false, error = 'Playlist introuvable' } end
    local name = trim(args.name, 50)
    if name == '' then return { ok = false, error = 'Donne un nom à la playlist' } end
    MySQL.update.await('UPDATE elyzea_ef_playlists SET name = ? WHERE id = ?', { name, p.id })
    return { ok = true }
end)
EF_('efPlaylistDelete', function(src, me, args)
    local p = MyPlaylist(me, args.id)
    if not p then return { ok = false, error = 'Playlist introuvable' } end
    MySQL.update.await('DELETE FROM elyzea_ef_playlist_items WHERE playlist_id = ?', { p.id })
    MySQL.update.await('DELETE FROM elyzea_ef_playlists WHERE id = ?', { p.id })
    return { ok = true }
end)

-- ---------------------------------------------------------
--  Artistes de la ville : publier un titre (lien audio d'un hébergeur autorisé)
-- ---------------------------------------------------------
local function HostAllowed(url, hosts)
    if type(url) ~= 'string' or not url:match('^https://[%w%.%-]+/') or url:find('[%s"\'<>`\\]') then return false end
    local host = (url:match('^https://([^/:?#]+)') or ''):lower()
    for _, h in ipairs(hosts or {}) do
        h = h:lower()
        if host == h or host:sub(-(#h + 1)) == '.' .. h then return true end
    end
    return false
end
EF_('efArtist', function(src, me, args)
    local name = trim(args.name, 40)
    if name == '' then return { ok = false, error = 'Choisis un nom d\'artiste' } end
    MySQL.update.await('INSERT INTO elyzea_ef_profiles (identifier, artist) VALUES (?, ?) ON DUPLICATE KEY UPDATE artist = VALUES(artist)', { me.identifier, name })
    MySQL.update.await('UPDATE elyzea_ef_tracks SET artist = ? WHERE owner = ?', { name, me.identifier })
    return { ok = true, artist = name }
end)
local function ArtistName(src, me)
    return MySQL.scalar.await('SELECT artist FROM elyzea_ef_profiles WHERE identifier = ?', { me.identifier }) or A.GetCharName(src)
end
EF_('efUpload', function(src, me, args)
    if TooFast(src, 'upload', 5000) then return { ok = false, error = 'Attends quelques secondes' } end
    local url = trim(args.url, 500)
    if not HostAllowed(url, CFG.UploadHosts or {}) then return { ok = false, error = 'Lien refusé : utilise un hébergeur autorisé (Fivemanage…)' } end
    local title = trim(args.title, 80)
    if title == '' then return { ok = false, error = 'Donne un titre' } end
    local lyrics = trim((tostring(args.lyrics or ''):gsub('\r', '')), 3000)
    local id = MySQL.insert.await([[INSERT INTO elyzea_ef_tracks (owner, kind, artist, title, url, lyrics, status, public, ready_at)
        VALUES (?, 'upload', ?, ?, ?, ?, 'ready', ?, NOW())]], { me.identifier, ArtistName(src, me), title, url, lyrics ~= '' and lyrics or nil, args.public == true and 1 or 0 })
    return { ok = true, id = id }
end)

-- ---------------------------------------------------------
--  Mes titres : musique importée par les joueurs (depuis l'ordinateur ou par lien)
--  privée par défaut, publiable dans « Créations de la ville »
-- ---------------------------------------------------------
EF_('efCreations', function(src, me)
    local rows = MySQL.query.await([[SELECT id, kind, artist, title, url, lyrics, style, status, public, plays, likes,
        UNIX_TIMESTAMP(created_at) AS ts FROM elyzea_ef_tracks WHERE owner = ? AND status = 'ready' ORDER BY id DESC LIMIT 100]], { me.identifier }) or {}
    for _, r in ipairs(rows) do
        r.public = bool(r.public)
        r.key = 'ef:' .. r.id
        CityTrack({ id = r.id, owner = me.identifier, kind = r.kind, artist = r.artist, title = r.title, url = r.url, lyrics = r.lyrics, style = r.style, plays = r.plays, likes = r.likes })
    end
    return { ok = true, creations = rows }
end)

EF_('efPublish', function(src, me, args)
    local id = int(args.id, 0)
    local n = MySQL.update.await("UPDATE elyzea_ef_tracks SET public = ? WHERE id = ? AND owner = ? AND status = 'ready'", { args.public == false and 0 or 1, id, me.identifier })
    if (n or 0) < 1 then return { ok = false, error = 'Titre introuvable' } end
    return { ok = true, public = args.public ~= false }
end)

EF_('efDeleteCreation', function(src, me, args)
    local id = int(args.id, 0)
    local n = MySQL.update.await("DELETE FROM elyzea_ef_tracks WHERE id = ? AND owner = ?", { id, me.identifier })
    if (n or 0) < 1 then return { ok = false, error = 'Titre introuvable' } end
    MySQL.update.await('DELETE FROM elyzea_ef_track_likes WHERE track_id = ?', { id })
    return { ok = true }
end)

-- ---------------------------------------------------------
--  Import depuis l'ordinateur
--  Le téléphone donne un CODE à usage unique (15 min) et l'adresse d'une page web servie par ce serveur.
--  Sur cette page (navigateur de l'ordinateur), le joueur choisit son fichier : il part directement sur
--  l'hébergeur (Fivemanage, lien d'envoi à usage unique demandé par le serveur, la clé reste secrète),
--  puis le titre est ajouté à SA bibliothèque. Aucun fichier ne transite par le serveur FiveM.
-- ---------------------------------------------------------
local IMP = CFG.Import or {}
local Codes, Fails = {}, {}
local CODE_CHARS = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'
local function MaxBytes() return int(IMP.MaxMB, 15) * 1024 * 1024 end
-- Adresse publique de la page d'import :
--  1. Config.ElyFy.Import.Url si elle est renseignée (toujours prioritaire)
--  2. sinon, trouvée au démarrage : le serveur essaie l'adresse cfx.re (web_baseUrl) puis http://IP_PUBLIQUE:PORT
--     et garde la première qui répond vraiment (page /import/ping)
local Detected = nil
local function Base(u) u = trim(u or '', 200) if u == '' then return nil end if not u:match('^https?://') then u = 'http://' .. u end return (u:gsub('/+$', '')) end
local function PageOf(base) return base .. '/' .. GetCurrentResourceName() .. '/import' end
local function ImportUrl()
    local b = Base(IMP.Url)
    if b then return PageOf(b) end
    return Detected and PageOf(Detected) or nil
end
local function Ping(base)
    local r = Http('GET', PageOf(base) .. '/ping', '', {})
    return r.code == 200 and tostring(r.body or ''):find('elyfy-ok', 1, true) ~= nil
end
local function Candidates()
    local list = {}
    local web = GetConvar('web_baseUrl', '') or ''
    if web ~= '' then list[#list + 1] = { base = web:match('^https?://') and web or ('https://' .. web), why = 'adresse cfx.re' } end
    local port = tostring(GetConvar('endpoint_add_tcp', '') or ''):match(':(%d+)') or tostring(GetConvar('netPort', '30120') or '30120')
    local r = Http('GET', 'https://api.ipify.org', '', {})
    local ip = tostring(r.body or ''):match('^%s*(%d+%.%d+%.%d+%.%d+)%s*$')
    if ip then list[#list + 1] = { base = ('http://%s:%s'):format(ip, port), why = 'IP publique du serveur' } end
    return list
end
local function DetectImportUrl(verbose)
    if IMP.Enabled == false then return end
    local fixed = Base(IMP.Url)
    if fixed then
        local ok = Ping(fixed)
        print((ok and '^2[elyzea_aura] ElyFy : page d\'import joignable : %s^0' or '^3[elyzea_aura] ElyFy : page d\'import (Config.ElyFy.Import.Url) : %s — le serveur n\'a pas pu la joindre lui-même. Vérifie-la dans ton navigateur.^0'):format(PageOf(fixed)))
        return
    end
    local cands = Candidates()
    for _, c in ipairs(cands) do
        if Ping(c.base) then
            Detected = c.base
            print(('^2[elyzea_aura] ElyFy : page d\'import joignable (%s) : %s^0'):format(c.why, PageOf(c.base)))
            return
        end
    end
    -- rien n'a répondu (ex. le serveur ne peut pas se joindre lui-même) : l'IP publique reste le meilleur choix
    local last = cands[#cands]
    Detected = last and last.base or nil
    if Detected then
        print(('^3[elyzea_aura] ElyFy : page d\'import non vérifiée : %s — ouvre-la dans ton navigateur. Si elle ne s\'ouvre pas, mets la bonne adresse dans Config.ElyFy.Import.Url (config_elyfy.lua), ex. \'http://TON_IP:30120\'.^0'):format(PageOf(Detected)))
    else
        print('^1[elyzea_aura] ElyFy : adresse publique introuvable pour la page d\'import. Renseigne Config.ElyFy.Import.Url dans config_elyfy.lua (ex. \'http://TON_IP:30120\').^0')
    end
end
ElyFyDetectImport = DetectImportUrl   -- pour les tests hors jeu
CreateThread(function()
    while not Ready do Wait(500) end
    Wait(5000)   -- le temps que le serveur écoute sur son port
    pcall(DetectImportUrl)
end)
-- Console du serveur : « elyfy_import » affiche l'adresse et la teste à nouveau
RegisterCommand('elyfy_import', function(src)
    if src ~= 0 then return end
    CreateThread(function() pcall(DetectImportUrl, true) end)
end, true)
local function CleanCodes()
    local now = os.time()
    for c, v in pairs(Codes) do if v.exp < now then Codes[c] = nil end end
end

EF_('efImportCode', function(src, me)
    if IMP.Enabled == false then return { ok = false, error = 'L\'import de musique est désactivé sur ce serveur' } end
    local url = ImportUrl()
    if not url then return { ok = false, error = 'Import pas encore prêt : adresse du serveur introuvable (le staff doit renseigner Config.ElyFy.Import.Url)' } end
    CleanCodes()
    for c, v in pairs(Codes) do if v.identifier == me.identifier then Codes[c] = nil end end
    local code
    repeat
        code = ''
        for _ = 1, 6 do local i = math.random(1, #CODE_CHARS) code = code .. CODE_CHARS:sub(i, i) end
    until not Codes[code]
    local minutes = math.max(2, int(IMP.CodeMinutes, 15))
    Codes[code] = { identifier = me.identifier, artist = ArtistName(src, me), exp = os.time() + minutes * 60 }
    return { ok = true, code = code, url = url, minutes = minutes, maxMb = int(IMP.MaxMB, 15) }
end)

-- Traitement des requêtes de la page d'import ; renvoie (code HTTP, réponse)
local function ImportRequest(path, ip, body)
    ip = tostring(ip or ''):gsub(':%d+$', '')
    local now = os.time()
    local f = Fails[ip]
    if f and f.n >= 8 and now - f.t < 600 then return 429, { ok = false, error = 'Trop d\'essais. Réessaie dans quelques minutes.' } end
    local ok, d = pcall(json.decode, body or '')
    if not ok or type(d) ~= 'table' then return 400, { ok = false, error = 'Requête invalide' } end
    CleanCodes()
    local code = tostring(d.code or ''):upper():gsub('[^%w]', '')
    local c = Codes[code]
    if not c then
        Fails[ip] = { n = (f and now - f.t < 600 and f.n or 0) + 1, t = now }
        return 403, { ok = false, error = 'Code invalide ou expiré : demande un nouveau code dans ElyFy (Mes titres > Depuis mon ordinateur).' }
    end
    if path == '/import/check' then return 200, { ok = true, artist = c.artist, maxMb = int(IMP.MaxMB, 15) } end
    if path == '/import/start' then
        local size = tonumber(d.size) or 0
        if size <= 0 or size > MaxBytes() then return 400, { ok = false, error = ('Fichier trop lourd (%d Mo maximum)'):format(int(IMP.MaxMB, 15)) } end
        if not tostring(d.type or ''):match('^audio/') then return 400, { ok = false, error = 'Ce fichier n\'est pas un fichier audio (MP3, M4A, OGG, WAV…)' } end
        local cam = Config.Camera or {}
        local presigned = cam.PresignedUrl or 'https://api.fivemanage.com/api/presigned-url?fileType=%s'
        local r = Http('GET', presigned:format('audio'), '', cam.Headers or {})
        local ok2, j = pcall(json.decode, r.body or '')
        local target = ok2 and type(j) == 'table' and (j.presignedUrl or (j.data and j.data.presignedUrl))
        if not target then
            print(('^1[elyzea_aura] ElyFy (import) : l\'hébergeur n\'a pas donné de lien d\'envoi (code %s). Vérifie la clé Fivemanage (Config.Camera.Headers).^0'):format(tostring(r.code)))
            return 502, { ok = false, error = 'L\'hébergeur de fichiers a refusé l\'envoi. Préviens le staff du serveur.' }
        end
        return 200, { ok = true, uploadUrl = target }
    end
    if path == '/import/finish' then
        local url = trim(d.url, 500)
        if not HostAllowed(url, CFG.UploadHosts or {}) then return 400, { ok = false, error = 'Lien du fichier refusé' } end
        local title = trim(d.title, 80)
        if title == '' then return 400, { ok = false, error = 'Donne un titre' } end
        local public = d.public == true and 1 or 0
        local id = MySQL.insert.await([[INSERT INTO elyzea_ef_tracks (owner, kind, artist, title, url, status, public, ready_at)
            VALUES (?, 'upload', ?, ?, ?, 'ready', ?, NOW())]], { c.identifier, c.artist, title, url, public })
        c.uses = (c.uses or 0) + 1
        if c.uses >= 10 then Codes[code] = nil end   -- un code sert pour 10 titres au plus
        Fails[ip] = nil
        local s = SourceOf(c.identifier)
        if s and Players[s] then
            Notify(s, { app = APP, key = 'efImported', params = { title = title } })
            Push(s, { type = 'imported', id = id, title = title })
        end
        return 200, { ok = true, id = id }
    end
    return 404, { ok = false }
end
ElyFyImportRequest = ImportRequest   -- pour les tests hors jeu

SetHttpHandler(function(req, res)
    local path = tostring(req.path or '/'):gsub('%?.*$', ''):gsub('/+$', '')
    if path == '' then path = '/' end
    if req.method == 'GET' and path == '/import/ping' then
        res.writeHead(200, { ['Content-Type'] = 'text/plain', ['Access-Control-Allow-Origin'] = '*' })
        res.send('elyfy-ok')
        return
    end
    if req.method == 'GET' and (path == '/import' or path == '/') then
        res.writeHead(200, { ['Content-Type'] = 'text/html; charset=utf-8', ['Cache-Control'] = 'no-store' })
        res.send(LoadResourceFile(GetCurrentResourceName(), 'web/elyfy_import.html') or 'ElyFy : page introuvable')
        return
    end
    if req.method == 'POST' and (path == '/import/check' or path == '/import/start' or path == '/import/finish') then
        req.setDataHandler(function(body)
            CreateThread(function()
                local ok, code, out = pcall(ImportRequest, path, req.address, body)
                if not ok then print('^1[elyzea_aura] ElyFy (import) : ' .. tostring(code) .. '^0') code, out = 500, { ok = false, error = 'Erreur du serveur' } end
                res.writeHead(code, { ['Content-Type'] = 'application/json; charset=utf-8', ['Cache-Control'] = 'no-store' })
                res.send(json.encode(out))
            end)
        end)
        return
    end
    res.writeHead(404, { ['Content-Type'] = 'text/plain' })
    res.send('')
end)
