-- =====================================================================
--  ELYZEA ENTREPRISES - serveur : création, vitrine, tableau de bord, dissolution
--  · « Lancer mon Business » (téléphone) : nom, spécialité, logo, description,
--    paiement depuis la banque → l'entreprise, son métier, son compte et ses
--    grades sont créés, le joueur en devient le patron.
--  · Vitrine : logo (galerie, lien, ou import depuis l'ordinateur), spécialité,
--    description, couleur. Visible de tous dans l'appli « Entreprises ».
-- =====================================================================
local P = Ent
local core = exports.elyzea_core
local C = Config.Create

local SPEC = {}
for _, s in ipairs(Config.Specialties) do SPEC[s.id] = s end
function P.Specialty(id) return SPEC[id] end

-- Configuration publique
P.Pub.init = { fn = function()
    return { perms = ENTPerms, statuses = Config.Statuses, keys = Config.Keys, specialties = Config.Specialties, colors = Config.Colors,
        price = C.price, nameMin = C.nameMin, nameMax = C.nameMax, descriptionMax = C.descriptionMax }
end }

-- ---------------------------------------------------------------------
-- Validation
-- ---------------------------------------------------------------------
-- Comparaison de noms : minuscules, sans accents (UTF-8), sans espaces ni ponctuation
local FOLD = {}
for from, to in pairs({ a = 'àáâãäåÀÁÂÃÄÅ', e = 'èéêëÈÉÊË', i = 'ìíîïÌÍÎÏ', o = 'òóôõöÒÓÔÕÖ', u = 'ùúûüÙÚÛÜ', c = 'çÇ', n = 'ñÑ', y = 'ýÿÝ', oe = 'œŒ', ae = 'æÆ' }) do
    for _, cp in utf8.codes(to) do FOLD[cp] = from end
end
local function squash(s)
    s = tostring(s or '')
    if not utf8.len(s) then return (s:lower():gsub('[^%w]', '')) end
    local out = {}
    for _, cp in utf8.codes(s) do
        local f = FOLD[cp]
        if f then out[#out + 1] = f
        elseif cp < 128 then local ch = string.char(cp):lower() if ch:match('%w') then out[#out + 1] = ch end end
    end
    return table.concat(out)
end

function P.ValidName(name, exceptId)
    name = P.Clean(name, C.nameMax)
    if utf8.len(name) < C.nameMin then return nil, ('Nom trop court (%d caractères au moins).'):format(C.nameMin) end
    if not name:find('%w') then return nil, 'Le nom doit contenir des lettres ou des chiffres.' end
    local sq = squash(name)
    for _, w in ipairs(C.forbiddenNames or {}) do
        local f = squash(w)
        if f ~= '' and sq:find(f, 1, true) then return nil, ('Ce nom n\'est pas autorisé (« %s »).'):format(w) end
    end
    for _, D in pairs(P.shops) do
        if not D.deleted and D.id ~= exceptId and squash(D.name) == sq then return nil, 'Une entreprise porte déjà ce nom.' end
    end
    -- Métiers officiels du serveur (police, EMS, restaurants…)
    local ok, jobs = pcall(function() return core:GetJobs() end)
    if ok and type(jobs) == 'table' then
        for jname, j in pairs(jobs) do
            if not tostring(jname):match('^ent_') and type(j) == 'table' and squash(j.label) == sq then return nil, 'Ce nom est celui d\'un métier du serveur.' end
        end
    end
    return name
end

function P.ValidColor(c)
    c = tostring(c or ''):lower()
    if c:match('^#%x%x%x%x%x%x$') then return c end
    return nil
end

local function HostOk(url, hosts)
    if #hosts == 0 then return true end
    local host = (url:match('^https://([^/:?#]+)') or ''):lower()
    for _, h in ipairs(hosts) do
        h = tostring(h):lower()
        if host == h or host:sub(-(#h + 1)) == '.' .. h then return true end
    end
    return false
end
-- Logo : lien https sans caractère dangereux (affiché dans une balise image, jamais exécuté)
function P.ValidLogo(url)
    url = tostring(url or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if url == '' then return '' end
    if #url > 500 or not url:match('^https://[%w%.%-]+[/:]') or url:find('[%s"\'<>`\\%(%)]') then return nil, 'Logo : lien d\'image https invalide.' end
    -- Logo importé depuis l'ordinateur (hébergeur de l'appareil photo) : toujours accepté
    if P.UploadHostOk and P.UploadHostOk(url) then return url end
    if not HostOk(url, Config.Logo.allowedHosts or {}) then return nil, 'Logo : ce site d\'images n\'est pas autorisé sur le serveur.' end
    return url
end

-- ---------------------------------------------------------------------
-- Création (« Lancer mon Business »)
-- ---------------------------------------------------------------------
local creating = {}

local function OwnedCount(cid)
    local n = 0
    for _, D in pairs(P.shops) do if D.ownerCid == cid and not D.deleted then n = n + 1 end end
    return n
end

-- Vérifications avant paiement (aussi utilisées par l'appli pour prévenir le joueur)
function P.CreateCheck(src)
    local p = P.GetPlayer(src)
    if not p then return nil, 'Personnage non chargé.' end
    local cid = p.PlayerData.citizenid
    if OwnedCount(cid) >= (C.maxPerOwner or 1) then return nil, 'Vous possédez déjà une entreprise.' end
    local cur = P.employees[cid]
    if cur then
        local D = P.shops[cur.shop_id]
        return nil, ('Vous travaillez déjà chez « %s » : quittez-la d\'abord (tablette › Tableau de bord).'):format(D and D.name or '?')
    end
    if (C.cooldownMinutes or 0) > 0 then
        local recent = MySQL.scalar.await([[SELECT COUNT(*) FROM `ent_companies` WHERE `owner_cid` = ? AND `deleted` = 1
            AND `updated_at` > DATE_SUB(NOW(), INTERVAL ? MINUTE)]], { cid, C.cooldownMinutes })
        if (tonumber(recent) or 0) > 0 then return nil, ('Vous venez de dissoudre une entreprise : attendez %d minutes avant d\'en créer une autre.'):format(C.cooldownMinutes) end
    end
    local job = p.PlayerData.job or {}
    local current = (job.name and job.name ~= 'unemployed') and (job.label or job.name) or nil
    return { cid = cid, current = current, bank = tonumber(p.Functions.GetMoney('bank')) or 0 }
end

function P.CreateCompany(src, d)
    local info, why = P.CreateCheck(src)
    if not info then return { error = why } end
    local cid = info.cid
    if creating[cid] then return { error = 'Création déjà en cours.' } end
    local name, e1 = P.ValidName(d.name)
    if not name then return { error = e1 } end
    local spec = SPEC[tostring(d.specialty or '')]
    if not spec then return { error = 'Choisissez une spécialité.' } end
    local logo, e2 = P.ValidLogo(d.logo)
    if not logo then return { error = e2 } end
    if logo == '' then return { error = 'Choisissez un logo.' } end
    local desc = P.CleanText(d.description, C.descriptionMax)
    if utf8.len(desc) < 10 then return { error = 'Décrivez votre entreprise (10 caractères au moins).' } end
    local color = P.ValidColor(d.color) or Config.Colors[1]
    if info.current and d.leaveJob ~= true then
        return { error = ('Vous quitterez votre métier actuel (%s) en devenant patron : confirmez.'):format(info.current), needLeave = info.current }
    end
    if info.bank < C.price then return { error = ('Il faut %d $ en banque (vous avez %d $).'):format(C.price, info.bank) } end

    creating[cid] = true
    local ok, res = pcall(function()
        local p = P.GetPlayer(src)
        if not p then return { error = 'Personnage non chargé.' } end
        local paid = C.price <= 0 or (p.Functions.RemoveMoney('bank', C.price, ('Création de l\'entreprise %s'):format(name)) == true)
        if not paid then return { error = 'Paiement refusé par la banque.' } end
        local ownerName = P.Name(src)
        local id = MySQL.insert.await([[INSERT INTO `ent_companies` (`name`, `specialty`, `logo`, `description`, `color`, `owner_cid`, `owner_name`, `price_paid`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)]], { name, spec.id, logo, desc, color, cid, ownerName, C.price })
        if not id then
            if C.price > 0 then p.Functions.AddMoney('bank', C.price, 'Remboursement : création d\'entreprise impossible') end
            return { error = 'Création impossible (base de données) : vous avez été remboursé.' }
        end
        local job, society = ('ent_%d'):format(id), ('ent_%d'):format(id)
        MySQL.update.await('UPDATE `ent_companies` SET `job` = ?, `society` = ? WHERE `id` = ?', { job, society, id })
        local D = { id = id, name = name, specialty = spec.id, logo = logo, description = desc, color = color, ownerCid = cid, ownerName = ownerName,
            job = job, jobLabel = name, society = society, matPrefix = 'EN-', enabled = true, deleted = false, createdAt = os.date('%d/%m/%Y'), options = {} }
        P.shops[id] = D
        P.SeedGrades(id)
        P.SyncCoreJob(D)
        pcall(function() core:GetSocietyMoney(society) end)   -- le compte de société existe dès maintenant
        if (C.startBalance or 0) > 0 then P.SocietyAdd(D, C.startBalance, 'Capital de départ') end
        local top = P.TopGrade(id)
        local hired, mat = P.Hire(D, cid, ownerName, top)
        if not hired then print(('^1[ENTREPRISES] Patron non embauché (%s) : %s^0'):format(name, tostring(mat))) end
        P.AddLog(id, src, cid, ownerName, 'Création', nil, top and top.name, ('Entreprise créée (%d $)'):format(C.price))
        P.Log(src, 'Création d\'entreprise', ('%s · %s · %d $'):format(name, spec.label, C.price))
        P.Touch()
        return { ok = true, id = id, message = ('« %s » est créée : vous en êtes le patron. Votre téléphone et votre tablette d\'entreprise sont prêts (F6).'):format(name) }
    end)
    creating[cid] = nil
    if not ok then
        print(('^1[ENTREPRISES] Création : %s^0'):format(tostring(res)))
        return { error = 'Erreur pendant la création.' }
    end
    return res
end

-- ---------------------------------------------------------------------
-- Vitrine (version publique : appli « Entreprises » du téléphone)
-- ---------------------------------------------------------------------
P.version = 0
function P.Touch() P.version = P.version + 1 end

local function Numbers()
    local out = {}
    if GetResourceState('elyzea_jobphone') ~= 'started' then return out end
    local ok, list = pcall(function() return exports.elyzea_jobphone:GetBusinesses() end)
    for _, b in ipairs(ok and type(list) == 'table' and list or {}) do
        local id = tostring(b.unit or ''):match('^' .. GetCurrentResourceName() .. ':(%d+)$')
        if id then out[tonumber(id)] = b end
    end
    return out
end

function P.PublicView(D, b)
    local s = SPEC[D.specialty] or { label = D.specialty, icon = '🏢' }
    return { id = D.id, name = D.name, specialty = D.specialty, specialtyLabel = s.label, specialtyIcon = s.icon, logo = D.logo, description = D.description,
        color = D.color, owner = D.ownerName, created = D.createdAt, employees = P.CountEmployees(D.id),
        number = b and b.number or nil, open = b ~= nil and b.open == true, onDuty = b and b.onDuty or 0 }
end

function P.PublicList()
    local nums = Numbers()
    local list = {}
    for _, D in pairs(P.shops) do
        if P.ShopOpen(D) then list[#list + 1] = P.PublicView(D, nums[D.id]) end
    end
    table.sort(list, function(a, b)
        if (a.onDuty > 0) ~= (b.onDuty > 0) then return a.onDuty > 0 end
        return a.name:lower() < b.name:lower()
    end)
    return list
end

-- Ce que le téléphone montre au joueur dans « Lancer mon Business » / « Mon business »
function P.MineView(src)
    local cid = P.Cid(src)
    if not cid then return { state = 'none' } end
    local D = P.ShopOf(src)
    if D then
        local g = P.Grade(src)
        local nums = Numbers()
        return { state = 'member', company = P.PublicView(D, nums[D.id]), grade = g and g.name or '?', canProfile = P.Can(src, 'profile'),
            owner = D.ownerCid == cid, suspended = not D.enabled }
    end
    -- Patron fondateur qui a pris un autre métier : il peut reprendre sa place
    local owned = P.ShopByOwner(cid)
    if owned then return { state = 'away', company = P.PublicView(owned, nil) } end
    local info, why = P.CreateCheck(src)
    return { state = 'none', canCreate = info ~= nil, reason = why, current = info and info.current, bank = info and info.bank, price = C.price }
end

-- Reprendre sa place de patron (fondateur parti dans un autre métier)
P.Pub.reclaim = { fn = function(src, d)
    local cid = P.Cid(src)
    local D = cid and P.ShopByOwner(cid)
    if not D then return { error = 'Vous ne possédez aucune entreprise.' } end
    if P.employees[cid] then return { error = 'Vous êtes déjà employé d\'une entreprise.' } end
    local p = P.GetPlayer(src)
    local job = p and p.PlayerData.job or {}
    if job.name and job.name ~= 'unemployed' and d.leaveJob ~= true then
        return { error = ('Vous quitterez votre métier actuel (%s) : confirmez.'):format(job.label or job.name), needLeave = job.label or job.name }
    end
    local ok, mat = P.Hire(D, cid, P.Name(src), P.TopGrade(D.id))
    if not ok then return { error = mat } end
    P.AddLog(D.id, src, cid, P.Name(src), 'Retour du patron', nil, P.TopGrade(D.id).name, nil)
    return { ok = true, message = ('Vous avez repris votre place de patron de « %s ».'):format(D.name) }
end }

-- ---------------------------------------------------------------------
-- Modifier la vitrine (permission « profile »)
-- ---------------------------------------------------------------------
P.Actions.profileSave = { perm = 'profile', fn = function(src, d, D)
    local changes = {}
    if d.specialty ~= nil then
        local s = SPEC[tostring(d.specialty)]
        if not s then return { error = 'Spécialité inconnue.' } end
        if s.id ~= D.specialty then D.specialty = s.id changes[#changes + 1] = 'spécialité' end
    end
    if d.description ~= nil then
        local desc = P.CleanText(d.description, C.descriptionMax)
        if utf8.len(desc) < 10 then return { error = 'Description trop courte (10 caractères au moins).' } end
        if desc ~= D.description then D.description = desc changes[#changes + 1] = 'description' end
    end
    if d.color ~= nil then
        local c = P.ValidColor(d.color)
        if not c then return { error = 'Couleur invalide.' } end
        if c ~= D.color then D.color = c changes[#changes + 1] = 'couleur' end
    end
    if d.logo ~= nil then
        local logo, why = P.ValidLogo(d.logo)
        if not logo then return { error = why } end
        if logo == '' then return { error = 'Le logo ne peut pas être vide.' } end
        if logo ~= D.logo then D.logo = logo changes[#changes + 1] = 'logo' end
    end
    if #changes == 0 then return { ok = true, message = 'Aucun changement.' } end
    P.SaveShop(D)
    P.Touch()
    P.PushShop(D.id)
    P.AddLog(D.id, src, nil, nil, 'Vitrine modifiée', nil, nil, table.concat(changes, ', '))
    return { ok = true, message = 'Vitrine mise à jour : ' .. table.concat(changes, ', ') .. '.' }
end }

-- ---------------------------------------------------------------------
-- Tableau de bord et fiche
-- ---------------------------------------------------------------------
P.Actions.dashboard = { perm = 'tablet', fn = function(src, _, D)
    local crew = {}
    for _, s in ipairs(P.CrewOnDuty(D.id)) do crew[#crew + 1] = P.CrewInfo(s) end
    table.sort(crew, P.SortCrew)
    local e, g = P.Employee(src), P.Grade(src)
    local nums = Numbers()
    local b = nums[D.id]
    local week = MySQL.query.await([[SELECT `type`, SUM(`amount`) AS total FROM `ent_transactions` WHERE `shop_id` = ? AND `created_at` >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        GROUP BY `type`]], { D.id }) or {}
    local flow = { ['in'] = 0, out = 0 }
    for _, r in ipairs(week) do flow[r.type] = tonumber(r.total) or 0 end
    return { company = P.PublicView(D, b), employees = P.CountEmployees(D.id), crew = crew, flow = flow, suspended = not D.enabled, reason = D.disabledReason,
        balance = P.Can(src, 'finance') and P.Balance(D) or nil, isOwner = e and e.citizenid == D.ownerCid,
        me = { grade = g and g.name or '?', matricule = e and e.matricule or '', duty = P.OnDuty(src), status = P.status[src] or 'available', times = P.MyTimes(src) } }
end }

P.Actions.profile = { perm = 'tablet', fn = function(src, _, D)
    return { company = P.PublicView(D, Numbers()[D.id]), canEdit = P.Can(src, 'profile'), specialties = Config.Specialties, colors = Config.Colors,
        descriptionMax = C.descriptionMax, job = D.job, society = D.society }
end }

-- ---------------------------------------------------------------------
-- Dissolution (le patron fondateur seulement)
-- ---------------------------------------------------------------------
function P.Dissolve(D, actorSrc, why)
    P.FlushShop(D.id)
    for cid in pairs(P.ShopEmployees(D.id)) do
        local s = core:GetSourceByCitizenId(cid)
        P.Remove(cid)
        if s then P.Notify(s, ('L\'entreprise « %s » a été dissoute%s.'):format(D.name, why and (' : ' .. why) or ''), 'error') end
    end
    D.deleted, D.enabled = true, false
    P.SaveShop(D)
    pcall(function() core:RemoveJob(D.job) end)
    P.Touch()
end

P.Actions.dissolve = { perm = nil, open = false, fn = function(src, d, D)
    local cid = P.Cid(src)
    if cid ~= D.ownerCid then return { error = 'Seul le fondateur peut dissoudre l\'entreprise.' } end
    if P.Clean(d.confirm, 60):lower() ~= D.name:lower() then return { error = 'Tapez exactement le nom de l\'entreprise pour confirmer.' } end
    P.FlushShop(D.id)
    local due = 0
    for _, e in pairs(P.ShopEmployees(D.id)) do due = due + math.floor(e.unpaid_amount) end
    if due > 0 and d.dropUnpaid ~= true then
        return { error = ('%d $ de salaires ne sont pas payés : payez-les dans Finance, ou confirmez l\'abandon.'):format(due), unpaid = due }
    end
    local balance = P.Balance(D)
    local refunded = 0
    if balance > 0 then
        if P.SocietyRemove(D, balance, 'Dissolution : solde versé au fondateur') then
            local ok = P.PayBank(cid, balance, ('Dissolution de %s'):format(D.name))
            if ok then
                refunded = balance
                P.Tx(D, { type = 'out', category = 'dissolve', amount = balance, reason = 'Solde versé au fondateur', actorCid = cid, actorName = P.Name(src), targetCid = cid, targetName = P.Name(src) })
            else
                P.SocietyAdd(D, balance, 'Annulation : versement au fondateur impossible')
                return { error = 'Versement du solde impossible : rien n\'a été fait.' }
            end
        end
    end
    P.AddLog(D.id, src, nil, nil, 'Dissolution', nil, nil, due > 0 and ('%d $ de salaires abandonnés'):format(due) or nil)
    P.Log(src, 'Dissolution d\'entreprise', ('%s · solde %d $'):format(D.name, refunded))
    P.Dissolve(D, src, nil)
    return { ok = true, message = ('« %s » est dissoute.%s'):format(D.name, refunded > 0 and (' %d $ versés sur votre compte.'):format(refunded) or '') }
end }

-- ---------------------------------------------------------------------
-- Logo importé depuis l'ordinateur
--  1. le téléphone demande un code (15 min) → lien de la page servie par CE serveur ;
--  2. la page (navigateur de l'ordinateur) envoie l'image directement à l'hébergeur
--     de l'appareil photo d'Elyzea Aura (lien d'envoi à usage unique) ;
--  3. le lien de l'image revient ici et attend dans le téléphone du joueur.
--  Aucun fichier ne transite par le serveur FiveM, la clé de l'hébergeur reste secrète.
-- ---------------------------------------------------------------------
local IMP = Config.Logo.import or {}
local Codes, Pending, Fails = {}, {}, {}
local CODE_CHARS = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'
local function Aura() return GetResourceState('elyzea_aura') == 'started' and exports.elyzea_aura or nil end
function P.UploadHostOk(url)
    local a = Aura()
    if not a then return false end
    local ok, res = pcall(function() return a:UploadHostAllowed(url) end)
    return ok and res == true
end
local function BaseUrl()
    local u = tostring(IMP.url or ''):gsub('^%s+', ''):gsub('%s+$', ''):gsub('/+$', '')
    if u ~= '' then return u:match('^https?://') and u or ('http://' .. u) end
    local a = Aura()
    local ok, b = pcall(function() return a and a:ImportBase() end)
    return ok and type(b) == 'string' and b ~= '' and b or nil
end
local function CleanCodes()
    local now = os.time()
    for c, v in pairs(Codes) do if v.exp < now then Codes[c] = nil end end
end

function P.LogoCode(src)
    if IMP.enabled == false then return { error = 'L\'import depuis l\'ordinateur est désactivé sur ce serveur.' } end
    local cid = P.Cid(src)
    if not cid then return { error = 'Personnage non chargé.' } end
    local base = BaseUrl()
    if not base then return { error = 'Adresse du serveur introuvable : le staff doit renseigner Config.Logo.import.url (elyzea_entreprises).' } end
    CleanCodes()
    for c, v in pairs(Codes) do if v.cid == cid then Codes[c] = nil end end
    local code
    repeat
        code = ''
        for _ = 1, 6 do local i = math.random(1, #CODE_CHARS) code = code .. CODE_CHARS:sub(i, i) end
    until not Codes[code]
    local minutes = math.max(2, tonumber(IMP.codeMinutes) or 15)
    Codes[code] = { cid = cid, exp = os.time() + minutes * 60, uses = 0 }
    Pending[cid] = nil
    return { ok = true, code = code, url = ('%s/%s/logo?code=%s'):format(base, GetCurrentResourceName(), code), minutes = minutes, maxMb = tonumber(IMP.maxMb) or 5 }
end
-- Logo arrivé depuis l'ordinateur (le téléphone le demande tant que la fenêtre d'import est ouverte)
function P.LogoPending(src)
    local cid = P.Cid(src)
    local url = cid and Pending[cid]
    return { ok = true, url = url }
end
function P.LogoTake(src)
    local cid = P.Cid(src)
    if cid then Pending[cid] = nil end
end

local GlobalFails = { n = 0, t = 0 }
function P.LogoRequest(path, ip, body)
    ip = tostring(ip or ''):gsub(':%d+$', '')
    local now = os.time()
    local f = Fails[ip]
    if f and f.n >= 8 and now - f.t < 600 then return 429, { ok = false, error = 'Trop d\'essais. Réessayez dans quelques minutes.' } end
    if now - GlobalFails.t >= 600 then GlobalFails = { n = 0, t = now } end
    if GlobalFails.n >= 300 then return 429, { ok = false, error = 'Trop d\'essais. Réessayez dans quelques minutes.' } end
    local ok, d = pcall(json.decode, body or '')
    if not ok or type(d) ~= 'table' then return 400, { ok = false, error = 'Requête invalide.' } end
    CleanCodes()
    local code = tostring(d.code or ''):upper():gsub('[^%w]', '')
    local c = Codes[code]
    if not c then
        Fails[ip] = { n = (f and now - f.t < 600 and f.n or 0) + 1, t = now }
        GlobalFails.n = GlobalFails.n + 1
        return 403, { ok = false, error = 'Code invalide ou expiré : demandez un nouveau code dans l\'appli Entreprises du téléphone.' }
    end
    local maxBytes = (tonumber(IMP.maxMb) or 5) * 1024 * 1024
    if path == '/logo/check' then return 200, { ok = true, maxMb = tonumber(IMP.maxMb) or 5 } end
    if path == '/logo/start' then
        local size = tonumber(d.size) or 0
        if size <= 0 or size > maxBytes then return 400, { ok = false, error = ('Image trop lourde (%d Mo maximum).'):format(tonumber(IMP.maxMb) or 5) } end
        if not tostring(d.type or ''):match('^image/') then return 400, { ok = false, error = 'Ce fichier n\'est pas une image (PNG, JPG, WEBP…).' } end
        local a = Aura()
        if not a then return 503, { ok = false, error = 'Hébergeur d\'images indisponible (elyzea_aura arrêté).' } end
        local okU, url, err = pcall(function() return a:UploadUrl('image') end)
        if not okU or type(url) ~= 'string' then
            print(('^1[ENTREPRISES] Logo : pas de lien d\'envoi (%s).^0'):format(tostring(okU and err or url)))
            return 502, { ok = false, error = 'L\'hébergeur d\'images a refusé l\'envoi. Prévenez le staff du serveur.' }
        end
        return 200, { ok = true, uploadUrl = url }
    end
    if path == '/logo/finish' then
        local url = tostring(d.url or '')
        if not P.UploadHostOk(url) then return 400, { ok = false, error = 'Lien de l\'image refusé.' } end
        c.uses = c.uses + 1
        if c.uses >= 5 then Codes[code] = nil end
        Pending[c.cid] = url
        Fails[ip] = nil
        local s = core:GetSourceByCitizenId(c.cid)
        if s then P.Notify(s, 'Logo reçu sur votre téléphone (appli Entreprises).', 'success') end
        return 200, { ok = true }
    end
    return 404, { ok = false }
end

local function ClientIp(req)
    local h = req.headers or {}
    local xff = h['X-Forwarded-For'] or h['x-forwarded-for']
    return (type(xff) == 'string' and xff:match('^%s*([^,%s]+)')) or req.address
end
SetHttpHandler(function(req, res)
    local path = tostring(req.path or '/'):gsub('%?.*$', ''):gsub('/+$', '')
    if path == '' then path = '/' end
    if req.method == 'GET' and (path == '/logo' or path == '/') then
        res.writeHead(200, { ['Content-Type'] = 'text/html; charset=utf-8', ['Cache-Control'] = 'no-store' })
        res.send(LoadResourceFile(GetCurrentResourceName(), 'web/logo.html') or 'Page introuvable')
        return
    end
    if req.method == 'GET' and path == '/logo/ping' then
        res.writeHead(200, { ['Content-Type'] = 'text/plain' })
        res.send('entreprises-ok')
        return
    end
    if req.method == 'POST' and (path == '/logo/check' or path == '/logo/start' or path == '/logo/finish') then
        req.setDataHandler(function(body)
            CreateThread(function()
                local ok, code, out = pcall(P.LogoRequest, path, ClientIp(req), body)
                if not ok then print('^1[ENTREPRISES] Logo : ' .. tostring(code) .. '^0') code, out = 500, { ok = false, error = 'Erreur du serveur.' } end
                res.writeHead(code, { ['Content-Type'] = 'application/json; charset=utf-8', ['Cache-Control'] = 'no-store' })
                res.send(json.encode(out))
            end)
        end)
        return
    end
    res.writeHead(404, { ['Content-Type'] = 'text/plain' })
    res.send('')
end)
