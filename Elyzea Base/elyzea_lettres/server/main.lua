-- =====================================================================
--  ELYZEA LETTRES · SERVEUR
--  Une lettre = une ligne de la table elyzea_letters (texte, destinataire, signature, police,
--  papier, date, auteur, pages) + un objet « lettre » dont la métadonnée « letter » est l'identifiant.
--  L'objet n'est qu'une clé : il se donne, se range dans un coffre, se pose au sol comme n'importe
--  quel objet d'elyzea_inventory, et le texte ne voyage jamais dans l'inventaire.
--  Le contenu d'une lettre terminée n'est JAMAIS réécrit : aucune requête UPDATE sur le texte.
--  Tout est vérifié ici : session de rédaction (jeton à usage unique), feuille et stylo réellement
--  sur le joueur, longueurs, pages, police, consommation de la feuille, présence de l'objet.
-- =====================================================================
Letters = {}

local I = Config.Items
local INV = 'elyzea_inventory'
local core = exports.elyzea_core
local function inv() return exports[INV] end

local Sessions = {}   -- [src] = { token, expires }                    rédaction en cours
local Reading  = {}   -- [src] = { letter, envelope = bool }            lettre / enveloppe affichée
local Busy     = {}   -- [src] = true pendant une opération sur l'inventaire
local Rate     = {}   -- [src] = prochain moment autorisé (ms)
local Settings        -- réglages en cours (voir loadSettings)
local cache    = {}   -- [id] = ligne de la lettre (contenu immuable : le cache ne devient jamais faux)

-- ---------------------------------------------------------------------
-- Outils
-- ---------------------------------------------------------------------
local function notify(src, text, kind) pcall(function() core:Notify(src, text, kind or 'error') end) end
local function cidOf(src)
    local ok, cid = pcall(function() return core:GetCitizenId(src) end)
    return ok and cid and tostring(cid) or nil
end
local function nameOf(src)
    local ok, n = pcall(function() return core:GetCharName(src) end)
    if ok and type(n) == 'string' and n ~= '' then return n end
    return GetPlayerName(src) or ('Joueur ' .. tostring(src))
end
local function count(holder, item, md)
    local ok, n = pcall(function() return inv():Search(holder, 'count', item, md) end)
    return ok and tonumber(n) or 0
end
local function rate(src, ms)
    local now = GetGameTimer()
    if (Rate[src] or 0) > now then return false end
    Rate[src] = now + (ms or 300)
    return true
end
local function newToken() return ('%08x%08x'):format(math.random(0, 0x7FFFFFFF), math.random(0, 0x7FFFFFFF)) end

local MONTHS = { 'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre' }
-- « 2026-11-15 14:03:00 » → « 15 novembre 2026 » (le 1er du mois : « 1er novembre »)
function Letters.frenchDate(sqlDate)
    local y, m, d = tostring(sqlDate or ''):match('^(%d+)-(%d+)-(%d+)')
    if not y then return '' end
    d = tonumber(d)
    return ('%s %s %s'):format(d == 1 and '1er' or tostring(d), MONTHS[tonumber(m)] or '', y)
end
local function dateLine(sqlDate)
    local d = Letters.frenchDate(sqlDate)
    if Config.City and Config.City ~= '' then return ('%s, le %s'):format(Config.City, d) end
    return 'Le ' .. d
end

-- ---------------------------------------------------------------------
-- Réglages (modifiés par le menu admin, gardés en KVP)
-- ---------------------------------------------------------------------
local function clampInt(v, lim, def)
    v = math.tointeger(tonumber(v) and math.floor(tonumber(v)))
    if not v then return def end
    return math.max(lim[1], math.min(lim[2], v))
end

function Letters.validSettings(s)
    local D = Config.Defaults
    s = type(s) == 'table' and s or {}
    local out = {
        maxChars = clampInt(s.maxChars, Config.Limits.maxChars, D.maxChars),
        maxPages = clampInt(s.maxPages, Config.Limits.maxPages, D.maxPages),
        consume = (s.consume == 'letter' or s.consume == 'page' or s.consume == 'none') and s.consume or D.consume,
        envelopes = s.envelopes == nil and D.envelopes or s.envelopes == true,
        animation = s.animation == nil and D.animation or s.animation == true,
        fonts = {}, papers = {},
    }
    local anyFont, anyPaper = false, false
    for _, f in ipairs(Config.Fonts) do
        local v = nil
        if type(s.fonts) == 'table' then v = s.fonts[f.id] end
        if v == nil then v = D.fonts[f.id] ~= false end   -- non réglé : valeur de config.lua
        out.fonts[f.id] = v == true
        anyFont = anyFont or out.fonts[f.id]
    end
    for _, p in ipairs(Config.Papers) do
        local v = nil
        if type(s.papers) == 'table' then v = s.papers[p.id] end
        if v == nil then v = D.papers[p.id] ~= false end   -- non réglé : valeur de config.lua
        out.papers[p.id] = v == true
        anyPaper = anyPaper or out.papers[p.id]
    end
    if not anyFont then out.fonts[Config.Fonts[1].id] = true end      -- toujours au moins un style
    if not anyPaper then out.papers[Config.Papers[1].id] = true end
    out.defaultFont = out.fonts[s.defaultFont] and s.defaultFont or nil
    if not out.defaultFont then
        out.defaultFont = out.fonts[D.defaultFont] and D.defaultFont or nil
        if not out.defaultFont then for _, f in ipairs(Config.Fonts) do if out.fonts[f.id] then out.defaultFont = f.id break end end end
    end
    return out
end

local function loadSettings()
    local raw = GetResourceKvpString('settings')
    local ok, data = pcall(json.decode, raw or '')
    Settings = Letters.validSettings(ok and data or nil)
end
loadSettings()

function Letters.getSettings() return Settings end
function Letters.setSettings(s)
    Settings = Letters.validSettings(s)
    SetResourceKvp('settings', json.encode(Settings))
    return Settings
end

-- ---------------------------------------------------------------------
-- Base de données
-- ---------------------------------------------------------------------
local ready = false
CreateThread(function()
    local ok, err = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `elyzea_letters` (
                `id` VARCHAR(16) NOT NULL,
                `author_cid` VARCHAR(64) NULL,
                `author_name` VARCHAR(100) NULL,
                `recipient` VARCHAR(255) NOT NULL DEFAULT '',
                `body` MEDIUMTEXT NOT NULL,
                `signature` VARCHAR(255) NOT NULL DEFAULT '',
                `font` VARCHAR(20) NOT NULL,
                `paper` VARCHAR(20) NOT NULL,
                `pages` TINYINT UNSIGNED NOT NULL DEFAULT 1,
                `layout` VARCHAR(20) NOT NULL DEFAULT 'lettre-v1',
                `created` DATETIME NOT NULL,
                PRIMARY KEY (`id`), KEY `author_cid` (`author_cid`), KEY `created` (`created`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]])
    end)
    if not ok then print('^1[elyzea_lettres] table elyzea_letters : ' .. tostring(err) .. '^0') end
    ready = ok
end)

local function load(id)
    if type(id) ~= 'string' or #id > 16 or not id:match('^[%w]+$') then return nil end
    if cache[id] then return cache[id] end
    -- date relue en texte (le pilote pourrait sinon renvoyer un horodatage en millisecondes)
    local row = MySQL.single.await("SELECT `id`, `author_cid`, `author_name`, `recipient`, `body`, `signature`, `font`, `paper`, `pages`, `layout`, DATE_FORMAT(`created`, '%Y-%m-%d %H:%i:%s') AS `created` FROM `elyzea_letters` WHERE `id` = ?", { id })
    if not row then return nil end
    row.created = tostring(row.created)
    row.pages = math.tointeger(tonumber(row.pages)) or 1
    cache[id] = row
    return row
end
Letters.load = load

local function newId()
    for _ = 1, 20 do
        local id = ('L%06X%05X'):format(os.time() % 0xFFFFFF, math.random(0, 0xFFFFF))
        if not cache[id] and not MySQL.scalar.await('SELECT 1 FROM `elyzea_letters` WHERE `id` = ?', { id }) then return id end
    end
end

-- ---------------------------------------------------------------------
-- Métadonnées des objets (le texte n'y est jamais : seulement l'identifiant et ce qui s'affiche)
-- ---------------------------------------------------------------------
local function short(s, n)
    if (utf8.len(s) or 0) <= n then return s end
    return s:sub(1, (utf8.offset(s, n) or (n + 1)) - 1) .. '…'
end
local function pagesTxt(n) return ('%d page%s'):format(n, n > 1 and 's' or '') end

function Letters.letterMeta(row)
    local to = row.recipient ~= '' and row.recipient or nil
    return {
        letter = row.id,
        label = to and ('Lettre · ' .. short(to, 24)) or 'Lettre',
        description = ('%s · %s · écrite le %s'):format(to and ('Pour : ' .. to) or 'Sans destinataire', pagesTxt(row.pages), Letters.frenchDate(row.created)),
    }
end
function Letters.sealedMeta(row, opened)
    local to = row.recipient ~= '' and row.recipient or nil
    return {
        letter = row.id, opened = opened == true or nil,
        label = to and ('Enveloppe · ' .. short(to, 22)) or 'Enveloppe',
        description = ('%s · %s. Utiliser pour l\'ouvrir et lire la lettre.'):format(to and ('Pour : ' .. to) or 'Sans destinataire',
            opened and 'Ouverte' or 'Cachetée'),
    }
end

-- Ce que l'interface affiche (identique pour l'auteur et pour tous ceux qui la reçoivent)
local function letterView(row)
    return { id = row.id, recipient = row.recipient, body = row.body, signature = row.signature, font = row.font,
        paper = row.paper, date = dateLine(row.created), pages = row.pages, layout = row.layout }
end

-- ---------------------------------------------------------------------
-- Brouillon (un par personnage, gardé côté serveur tant que la lettre n'est pas terminée)
-- ---------------------------------------------------------------------
local function draftKey(cid) return 'draft:' .. cid end
local function cleanDraft(d)
    d = type(d) == 'table' and d or {}
    local out = {}
    out.recipient = LetterText.clean(d.recipient, { max = Config.MaxRecipient }) or ''
    out.signature = LetterText.clean(d.signature, { max = Config.MaxSignature }) or ''
    -- le brouillon garde le texte tel quel (espaces de fin compris), seulement borné et nettoyé des caractères de contrôle
    local body = type(d.body) == 'string' and d.body or ''
    if not utf8.len(body) then body = '' end
    body = body:gsub('\r', ''):gsub('[%z\1-\9\11-\31\127]', '')
    if utf8.len(body) > Settings.maxChars then body = body:sub(1, (utf8.offset(body, Settings.maxChars + 1) or (#body + 1)) - 1) end
    out.body = body
    out.font = Settings.fonts[d.font] and d.font or Settings.defaultFont
    local paperOk = false
    for _, p in ipairs(Config.Papers) do if p.id == d.paper and Settings.papers[p.id] then paperOk = true end end
    if not paperOk then for _, p in ipairs(Config.Papers) do if Settings.papers[p.id] then out.paper = p.id break end end else out.paper = d.paper end
    return out
end
function Letters.getDraft(cid)
    local raw = cid and GetResourceKvpString(draftKey(cid))
    local ok, d = pcall(json.decode, raw or '')
    return ok and type(d) == 'table' and d or nil
end
local function saveDraft(cid, d)
    if not cid then return end
    local empty = d.recipient == '' and d.signature == '' and (d.body or ''):gsub('%s', '') == ''
    if empty then DeleteResourceKvp(draftKey(cid)) else SetResourceKvp(draftKey(cid), json.encode(d)) end
end
local function deleteDraft(cid) if cid then DeleteResourceKvp(draftKey(cid)) end end

-- ---------------------------------------------------------------------
-- Ouvrir la rédaction (feuille ou stylo utilisé depuis l'inventaire)
-- ---------------------------------------------------------------------
local function sheetsNeeded(pages)
    if Settings.consume == 'none' then return 0 end
    if Settings.consume == 'page' then return math.max(1, pages) end
    return 1
end

function Letters.openWriter(src)
    if not ready then return notify(src, 'Le papier à lettres n\'est pas encore prêt, réessaie dans un instant.') end
    if Busy[src] then return end
    if count(src, I.pen) < 1 then return notify(src, 'Il vous faut un stylo à bille pour écrire une lettre.') end
    if count(src, I.paper) < 1 then return notify(src, 'Il vous faut une feuille de papier pour écrire une lettre.') end
    local cid = cidOf(src)
    if not cid then return end
    local token = newToken()
    Sessions[src] = { token = token, expires = os.time() + 3 * 3600 }
    Reading[src] = nil
    local fonts, papers = {}, {}
    for _, f in ipairs(Config.Fonts) do if Settings.fonts[f.id] then fonts[#fonts + 1] = { id = f.id, label = f.label } end end
    for _, p in ipairs(Config.Papers) do if Settings.papers[p.id] then papers[#papers + 1] = { id = p.id, label = p.label } end end
    local draft = Letters.getDraft(cid)
    TriggerClientEvent('elyzea_lettres:openWriter', src, {
        token = token,
        draft = draft and cleanDraft(draft) or nil,
        date = dateLine(os.date('%Y-%m-%d %H:%M:%S')),
        author = nameOf(src),
        limits = { maxChars = Settings.maxChars, maxPages = Settings.maxPages, recipient = Config.MaxRecipient, signature = Config.MaxSignature },
        fonts = fonts, papers = papers, defaultFont = Settings.defaultFont,
        consume = Settings.consume, sheets = count(src, I.paper),
        autosave = Config.DraftAutosave, animation = Settings.animation,
    })
end

local function session(src, token)
    local s = Sessions[src]
    if not s or type(token) ~= 'string' or s.token ~= token then return nil end
    if os.time() > s.expires then Sessions[src] = nil return nil end
    return s
end

RegisterNetEvent('elyzea_lettres:saveDraft', function(token, data)
    local src = source
    if not session(src, token) or not rate(src, 800) then return end
    saveDraft(cidOf(src), cleanDraft(data))
end)

-- Fermer sans terminer : la feuille n'est jamais consommée. keep = garder le brouillon
RegisterNetEvent('elyzea_lettres:cancel', function(token, keep, data)
    local src = source
    if not session(src, token) then return end
    Sessions[src] = nil
    local cid = cidOf(src)
    if keep == true then
        if type(data) == 'table' then saveDraft(cid, cleanDraft(data)) end
        notify(src, 'Lettre mise de côté : vous la retrouverez en reprenant une feuille.', 'inform')
    else
        deleteDraft(cid)
    end
end)

-- ---------------------------------------------------------------------
-- Terminer la lettre
-- ---------------------------------------------------------------------
local function finishReply(src, ok, msg) TriggerClientEvent('elyzea_lettres:finished', src, ok, msg) end

-- Valide le contenu envoyé. Renvoie la lettre propre ou (nil, message)
function Letters.validate(data)
    if type(data) ~= 'table' then return nil, 'Lettre illisible.' end
    local recipient, e1 = LetterText.clean(data.recipient, { max = Config.MaxRecipient })
    if not recipient then return nil, e1 == 'too_long' and ('Destinataire trop long (%d caractères maximum).'):format(Config.MaxRecipient) or 'Destinataire illisible.' end
    local signature, e2 = LetterText.clean(data.signature, { max = Config.MaxSignature })
    if not signature then return nil, e2 == 'too_long' and ('Signature trop longue (%d caractères maximum).'):format(Config.MaxSignature) or 'Signature illisible.' end
    local body, e3 = LetterText.clean(data.body, { max = Settings.maxChars, multiline = true })
    if not body then return nil, e3 == 'too_long' and ('Lettre trop longue (%d caractères maximum).'):format(Settings.maxChars) or 'Texte illisible.' end
    if body:gsub('%s', '') == '' then return nil, 'La lettre est vide : écrivez quelques mots avant de la terminer.' end
    if not Settings.fonts[data.font] then return nil, 'Ce style d\'écriture n\'est pas disponible.' end
    local paperOk = false
    for _, p in ipairs(Config.Papers) do if p.id == data.paper and Settings.papers[p.id] then paperOk = true end end
    if not paperOk then return nil, 'Ce papier n\'est pas disponible.' end
    local minPages = LetterText.minPages(body, Config.Layout.linesPerPage, Config.Layout.charsPerLine)
    local pages = math.tointeger(tonumber(data.pages)) or minPages
    pages = math.max(pages, minPages)
    if pages < 1 or pages > Settings.maxPages then return nil, ('Lettre trop longue : %d pages au maximum.'):format(Settings.maxPages) end
    return { recipient = recipient, signature = signature, body = body, font = data.font, paper = data.paper, pages = pages }
end

RegisterNetEvent('elyzea_lettres:finish', function(token, data)
    local src = source
    if not session(src, token) then return finishReply(src, false, 'Cette feuille n\'est plus ouverte. Reprenez une feuille.') end
    if Busy[src] or not rate(src, 600) then return end
    Busy[src] = true
    local ok, err = pcall(function()
        local L, why = Letters.validate(data)
        if not L then return finishReply(src, false, why) end
        local need = sheetsNeeded(L.pages)
        if count(src, I.pen) < 1 then return finishReply(src, false, 'Vous n\'avez plus de stylo à bille.') end
        local have = count(src, I.paper)
        if have < math.max(1, need) then
            return finishReply(src, false, need > 1 and ('Il vous faut %d feuilles pour %d pages (vous en avez %d).'):format(need, L.pages, have)
                or 'Vous n\'avez plus de feuille de papier.')
        end
        local cid = cidOf(src)
        local id = newId()
        if not id then return finishReply(src, false, 'Erreur, réessayez.') end
        local created = os.date('%Y-%m-%d %H:%M:%S')
        local row = { id = id, author_cid = cid, author_name = nameOf(src), recipient = L.recipient, body = L.body, signature = L.signature,
            font = L.font, paper = L.paper, pages = L.pages, layout = 'lettre-v1', created = created }
        -- 1. le texte est enregistré
        MySQL.insert.await('INSERT INTO `elyzea_letters` (`id`, `author_cid`, `author_name`, `recipient`, `body`, `signature`, `font`, `paper`, `pages`, `layout`, `created`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            { row.id, row.author_cid, row.author_name, row.recipient, row.body, row.signature, row.font, row.paper, row.pages, row.layout, row.created })
        if not MySQL.scalar.await('SELECT 1 FROM `elyzea_letters` WHERE `id` = ?', { id }) then return finishReply(src, false, 'Erreur d\'enregistrement, réessayez.') end
        -- 2. la lettre arrive dans l'inventaire, PUIS la (ou les) feuille(s) sont consommées, une seule fois.
        --    Dans cet ordre, un échec ne fait jamais perdre de feuille : la lettre ajoutée est simplement reprise.
        local meta = Letters.letterMeta(row)
        local function addLetter() local okA, r = pcall(function() return inv():AddItem(src, I.letter, 1, meta) end) return okA and r == true end
        local function takeSheets() if need == 0 then return true end local okR, r = pcall(function() return inv():RemoveItem(src, I.paper, need) end) return okR and r == true end
        local function abort(text)
            MySQL.query.await('DELETE FROM `elyzea_letters` WHERE `id` = ?', { id })
            return finishReply(src, false, text)
        end
        local FULL = 'Votre inventaire est plein : faites de la place pour garder la lettre (rien n\'a été consommé).'
        if addLetter() then
            if not takeSheets() then
                pcall(function() inv():RemoveItem(src, I.letter, 1, { letter = id }) end)
                return abort('Vous n\'avez plus assez de feuilles.')
            end
        else
            -- plus de case libre : la lettre prend la place de la (dernière) feuille utilisée
            if need == 0 or count(src, I.paper) ~= need or not takeSheets() then return abort(FULL) end
            if not addLetter() then
                inv():AddItem(src, I.paper, need)   -- la case vient d'être libérée : les feuilles y retournent
                return abort(FULL)
            end
        end
        Sessions[src] = nil                -- jeton utilisé : impossible de terminer deux fois
        cache[id] = row
        deleteDraft(cid)
        finishReply(src, true, 'Lettre terminée : elle est dans votre inventaire.')
        print(('[elyzea_lettres] lettre %s écrite par %s [%d] (%s) : %d page(s), %d caractère(s)'):format(id, GetPlayerName(src) or '?', src, tostring(cid), row.pages, utf8.len(row.body)))
    end)
    Busy[src] = nil
    if not ok then print('^1[elyzea_lettres] terminer : ' .. tostring(err) .. '^0') finishReply(src, false, 'Erreur, réessayez.') end
end)

-- ---------------------------------------------------------------------
-- Lire une lettre, une enveloppe
-- ---------------------------------------------------------------------
local function canEnvelope(src)
    return Settings.envelopes and count(src, I.envelope) > 0
end

function Letters.read(src, id)
    local row = load(id)
    if not row then return notify(src, 'Cette lettre est illisible : l\'encre a disparu.') end
    Sessions[src] = nil
    Reading[src] = { letter = row.id, envelope = false }
    TriggerClientEvent('elyzea_lettres:read', src, letterView(row), { canEnvelope = canEnvelope(src), animation = Settings.animation })
end

function Letters.viewEnvelope(src, id, opened)
    local row = load(id)
    if not row then return notify(src, 'Cette enveloppe est vide.') end
    Sessions[src] = nil
    Reading[src] = { letter = row.id, envelope = true }
    TriggerClientEvent('elyzea_lettres:envelope', src, { recipient = row.recipient, font = row.font, opened = opened == true },
        { animation = Settings.animation })
end

-- La lettre / l'enveloppe affichée est-elle toujours sur le joueur ?
local function held(src, kind)
    local r = Reading[src]
    if not r then return nil end
    local item = kind == 'sealed' and I.sealed or I.letter
    local ok, list = pcall(function() return inv():Search(src, 'slots', item, { letter = r.letter }) end)
    if ok and type(list) == 'table' and list[1] then return r, list[1] end
end

-- Ouvrir l'enveloppe affichée : elle passe « ouverte » et la lettre s'affiche
RegisterNetEvent('elyzea_lettres:openEnvelope', function()
    local src = source
    if not rate(src) then return end
    local r, slot = held(src, 'sealed')
    if not r or not r.envelope then return notify(src, 'Cette enveloppe n\'est plus sur vous.') end
    local row = load(r.letter)
    if not row then return notify(src, 'Cette enveloppe est vide.') end
    if not (slot.metadata and slot.metadata.opened) then
        pcall(function() inv():SetMetadata(src, slot.slot, Letters.sealedMeta(row, true)) end)
    end
    Reading[src] = { letter = row.id, envelope = true }
    TriggerClientEvent('elyzea_lettres:read', src, letterView(row), { fromEnvelope = true, animation = Settings.animation })
end)

-- Mettre la lettre affichée sous enveloppe (consomme une enveloppe vide)
RegisterNetEvent('elyzea_lettres:putInEnvelope', function()
    local src = source
    if not rate(src, 600) or Busy[src] then return end
    if not Settings.envelopes then return notify(src, 'Les enveloppes ne sont pas disponibles.') end
    Busy[src] = true
    local ok, err = pcall(function()
        local r = held(src, 'letter')
        if not r or r.envelope then return notify(src, 'Cette lettre n\'est plus sur vous.') end
        if count(src, I.envelope) < 1 then return notify(src, 'Il vous faut une enveloppe vide.') end
        local row = load(r.letter)
        if not row then return end
        if not inv():RemoveItem(src, I.letter, 1, { letter = row.id }) then return notify(src, 'Cette lettre n\'est plus sur vous.') end
        if not inv():RemoveItem(src, I.envelope, 1) then
            inv():AddItem(src, I.letter, 1, Letters.letterMeta(row))
            return notify(src, 'Il vous faut une enveloppe vide.')
        end
        local okAdd, added = pcall(function() return inv():AddItem(src, I.sealed, 1, Letters.sealedMeta(row, false)) end)
        if not okAdd or added ~= true then
            inv():AddItem(src, I.letter, 1, Letters.letterMeta(row))
            inv():AddItem(src, I.envelope, 1)
            return notify(src, 'Votre inventaire est plein.')
        end
        Reading[src] = nil
        TriggerClientEvent('elyzea_lettres:closeUi', src, 'sealed')
        notify(src, 'Lettre glissée dans l\'enveloppe et cachetée.', 'success')
    end)
    Busy[src] = nil
    if not ok then print('^1[elyzea_lettres] enveloppe : ' .. tostring(err) .. '^0') end
end)

-- Sortir la lettre de l'enveloppe ouverte (l'enveloppe déchirée est jetée)
RegisterNetEvent('elyzea_lettres:takeOut', function()
    local src = source
    if not rate(src, 600) or Busy[src] then return end
    Busy[src] = true
    local ok, err = pcall(function()
        local r = held(src, 'sealed')
        if not r or not r.envelope then return notify(src, 'Cette enveloppe n\'est plus sur vous.') end
        local row = load(r.letter)
        if not row then return end
        if not inv():RemoveItem(src, I.sealed, 1, { letter = row.id }) then return notify(src, 'Cette enveloppe n\'est plus sur vous.') end
        local okAdd, added = pcall(function() return inv():AddItem(src, I.letter, 1, Letters.letterMeta(row)) end)
        if not okAdd or added ~= true then
            inv():AddItem(src, I.sealed, 1, Letters.sealedMeta(row, true))
            return notify(src, 'Votre inventaire est plein.')
        end
        Reading[src] = { letter = row.id, envelope = false }
        TriggerClientEvent('elyzea_lettres:read', src, letterView(row), { canEnvelope = canEnvelope(src), animation = Settings.animation, tookOut = true })
        notify(src, 'Vous sortez la lettre de l\'enveloppe.', 'inform')
    end)
    Busy[src] = nil
    if not ok then print('^1[elyzea_lettres] enveloppe : ' .. tostring(err) .. '^0') end
end)

RegisterNetEvent('elyzea_lettres:closed', function()
    Reading[source] = nil
end)

-- ---------------------------------------------------------------------
-- Objets utilisables
-- ---------------------------------------------------------------------
CreateThread(function()
    while GetResourceState(INV) ~= 'started' do Wait(500) end
    local function reg(name, fn) pcall(function() inv():RegisterUsableItem(name, fn) end) end
    reg(I.paper, function(src) Letters.openWriter(src) return false end)
    reg(I.pen, function(src)
        if count(src, I.paper) < 1 then notify(src, 'Il vous faut une feuille de papier pour écrire une lettre.', 'inform') return false end
        Letters.openWriter(src)
        return false
    end)
    reg(I.letter, function(src, it)
        local id = it and it.metadata and it.metadata.letter
        if type(id) ~= 'string' then notify(src, 'Cette lettre est vierge.') return false end
        Letters.read(src, id)
        return false
    end)
    reg(I.sealed, function(src, it)
        local id = it and it.metadata and it.metadata.letter
        if type(id) ~= 'string' then notify(src, 'Cette enveloppe est vide.') return false end
        Letters.viewEnvelope(src, id, it.metadata.opened == true)
        return false
    end)
    reg(I.envelope, function(src)
        notify(src, 'Ouvrez une lettre terminée puis choisissez « Mettre sous enveloppe ».', 'inform')
        return false
    end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    Sessions[src], Reading[src], Busy[src], Rate[src] = nil, nil, nil, nil
end)

-- Personnage changé (elyzea_multichar) : la rédaction en cours est fermée
AddEventHandler('elyzea:server:playerUnloaded', function(src)
    src = tonumber(src)
    if not src then return end
    Sessions[src], Reading[src] = nil, nil
    TriggerClientEvent('elyzea_lettres:closeUi', src)
end)

-- API pour d'autres ressources (lecture seule : le contenu d'une lettre ne se modifie pas)
exports('GetLetter', function(id) local r = load(id) return r and letterView(r) or nil end)
exports('OpenWriter', function(src) Letters.openWriter(tonumber(src)) end)
