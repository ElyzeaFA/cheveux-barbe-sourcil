-- =====================================================================
--  ELYZEA ENTREPRISES - serveur : base de données, entreprises, grades, employés
--  · Entreprises créées PAR LES JOUEURS depuis le téléphone (Elyzea Aura ›
--    appli « Entreprises » › « Lancer mon Business »).
--  · Chaque entreprise a : son métier elyzea_core (ent_<id>), son compte de
--    société, ses grades et permissions, ses employés, sa vitrine (logo,
--    spécialité, description), son numéro public (téléphone de service).
--  · Pas de point ni de logo sur la carte.
--  · Un employé appartient à UNE entreprise (celle de son métier dans le core).
--  · Chaque requête passe par un point d'entrée qui vérifie : employé,
--    entreprise active, permission du grade, service. Le client ne décide jamais d'un droit.
-- =====================================================================
Ent = {
    shops = {},         -- [id] = entreprise
    grades = {},        -- [id] = { id, shop_id, name, level, salary, perms = {key=true}, isDefault, active }
    employees = {},     -- [citizenid] = { citizenid, shop_id, name, matricule, grade_id, … }
    duty = {},          -- [src] = true
    status = {},        -- [src] = statut
    Actions = {},       -- employés : [nom] = { perm, duty, fn(src, data, D) }
    Pub = {},           -- tout joueur : [nom] = { fn(src, data) }
    Admin = {},         -- staff : [nom] = { fn(src, data) }
    OnReady = {},
    ready = false,
}
local P = Ent
local core = exports.elyzea_core

-- ---------------------------------------------------------------------
-- Utilitaires
-- ---------------------------------------------------------------------
function P.Notify(src, msg, kind) pcall(function() core:Notify(src, msg, kind or 'inform') end) end
function P.GetPlayer(src) return core:GetPlayer(src) end
function P.Cid(src) local p = P.GetPlayer(src) return p and p.PlayerData.citizenid end
function P.Name(src)
    local p = P.GetPlayer(src)
    if not p then return GetPlayerName(src) or ('ID ' .. tostring(src)) end
    local ci = p.PlayerData.charinfo or {}
    return ('%s %s'):format(ci.firstname or '', ci.lastname or '')
end
function P.Coords(src)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and GetEntityCoords(ped) or nil
end
function P.Dist(a, b)
    local ca, cb = P.Coords(a), P.Coords(b)
    if not ca or not cb then return 9999.0 end
    return #(ca - cb)
end
-- Texte propre : pas de balises, pas de caractères de contrôle, espaces en trop retirés
function P.Clean(s, max)
    s = tostring(s or ''):gsub('<[^>]*>', ''):gsub('[<>%c]', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if #s > (max or 100) then
        s = s:sub(1, max or 100)
        -- ne jamais couper un caractère accentué en deux
        while #s > 0 and not utf8.len(s) do s = s:sub(1, -2) end
    end
    return s
end
-- Texte sur plusieurs lignes (description) : retours à la ligne gardés (2 au plus d'affilée)
function P.CleanText(s, max)
    s = tostring(s or ''):gsub('\r', ''):gsub('<[^>]*>', ''):gsub('[<>]', ' '):gsub('[%z\1-\9\11-\31]', ' '):gsub('[ \t]+', ' '):gsub('\n%s*\n[%s\n]*', '\n\n')
    s = s:gsub('^%s+', ''):gsub('%s+$', '')
    if #s > max then
        s = s:sub(1, max)
        while #s > 0 and not utf8.len(s) do s = s:sub(1, -2) end
    end
    return s
end
function P.Int(v, mn, mx, def)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return def end
    v = math.floor(v)
    if mn then v = math.max(mn, v) end
    if mx then v = math.min(mx, v) end
    return v
end
local uidSeq = 0
function P.Uid(prefix)
    uidSeq = (uidSeq + 1) % 1000
    return ('%s-%s-%03d%04d'):format(prefix or 'OP', os.date('%y%m%d%H%M%S'), uidSeq, math.random(0, 9999))
end
function P.Log(src, action, details)
    if GetResourceState('admin_menu') == 'started' then
        if pcall(function() exports.admin_menu:AddLog(src, '[Entreprises] ' .. action, details) end) then return end
    end
    print(('^5[ENTREPRISES]^7 %s | %s | %s'):format(src and P.Name(src) or 'Système', action, details or ''))
end
local function dec(raw, def) local ok, v = pcall(json.decode, raw or '') return ok and type(v) == 'table' and v or def end
P.Decode = dec

-- ---------------------------------------------------------------------
-- Base de données (préfixe ent_)
-- ---------------------------------------------------------------------
P.Tables = {
    ent_companies = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(60) NOT NULL,
        `specialty` VARCHAR(40) NOT NULL,
        `logo` VARCHAR(500) NULL,
        `description` TEXT NULL,
        `color` VARCHAR(9) NOT NULL DEFAULT '#7c6cff',
        `owner_cid` VARCHAR(50) NOT NULL,
        `owner_name` VARCHAR(100) NULL,
        `job` VARCHAR(40) NULL UNIQUE,
        `society` VARCHAR(40) NULL,
        `mat_prefix` VARCHAR(8) NOT NULL DEFAULT 'EN-',
        `price_paid` INT NOT NULL DEFAULT 0,
        `enabled` TINYINT(1) NOT NULL DEFAULT 1,
        `deleted` TINYINT(1) NOT NULL DEFAULT 0,
        `disabled_reason` VARCHAR(160) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX (`owner_cid`) ) ]],
    ent_grades = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `name` VARCHAR(50) NOT NULL,
        `level` INT NOT NULL,
        `salary` INT NOT NULL DEFAULT 0,
        `perms` TEXT NOT NULL,
        `is_default` TINYINT(1) NOT NULL DEFAULT 0,
        `active` TINYINT(1) NOT NULL DEFAULT 1,
        UNIQUE KEY `shop_level` (`shop_id`, `level`), UNIQUE KEY `shop_name` (`shop_id`, `name`) ) ]],
    ent_employees = [[ (
        `citizenid` VARCHAR(50) NOT NULL PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `name` VARCHAR(100) NOT NULL,
        `matricule` VARCHAR(20) NOT NULL,
        `grade_id` INT NOT NULL,
        `recruited_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `promoted_at` DATETIME NULL,
        `note` VARCHAR(255) NULL,
        `total_seconds` INT NOT NULL DEFAULT 0,
        `unpaid_seconds` INT NOT NULL DEFAULT 0,
        `unpaid_amount` DOUBLE NOT NULL DEFAULT 0,
        INDEX (`shop_id`) ) ]],
    ent_admin_log = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `actor_cid` VARCHAR(50) NULL, `actor_name` VARCHAR(100) NULL,
        `target_cid` VARCHAR(50) NULL, `target_name` VARCHAR(100) NULL,
        `action` VARCHAR(40) NOT NULL,
        `old_grade` VARCHAR(50) NULL, `new_grade` VARCHAR(50) NULL,
        `reason` VARCHAR(255) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`shop_id`), INDEX (`target_cid`) ) ]],
    ent_sessions = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL, `name` VARCHAR(100) NULL,
        `grade_name` VARCHAR(50) NULL,
        `started_at` DATETIME NOT NULL, `ended_at` DATETIME NULL,
        `seconds` INT NOT NULL DEFAULT 0,
        `amount` DOUBLE NOT NULL DEFAULT 0,
        `end_reason` VARCHAR(30) NULL,
        INDEX (`citizenid`), INDEX (`shop_id`) ) ]],
    ent_rates = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `grade_id` INT NOT NULL, `grade_name` VARCHAR(50) NULL,
        `rate` INT NOT NULL,
        `actor_name` VARCHAR(100) NULL,
        `effective_from` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`shop_id`) ) ]],
    ent_transactions = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `txid` VARCHAR(40) NOT NULL UNIQUE,
        `type` VARCHAR(10) NOT NULL,
        `category` VARCHAR(20) NOT NULL,
        `amount` INT NOT NULL,
        `reason` VARCHAR(160) NULL,
        `actor_cid` VARCHAR(50) NULL, `actor_name` VARCHAR(100) NULL,
        `target_cid` VARCHAR(50) NULL, `target_name` VARCHAR(100) NULL,
        `seconds` INT NULL,
        `ref` VARCHAR(40) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`shop_id`), INDEX (`category`), INDEX (`created_at`) ) ]],
}
P.TableOrder = { 'ent_companies', 'ent_grades', 'ent_employees', 'ent_admin_log', 'ent_sessions', 'ent_rates', 'ent_transactions' }

local function InitDb()
    for _, name in ipairs(P.TableOrder) do
        local ok, err = pcall(MySQL.query.await, ('CREATE TABLE IF NOT EXISTS `%s` %s DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'):format(name, P.Tables[name]))
        if not ok then print(('^1[ENTREPRISES] Table %s non créée : %s^0'):format(name, tostring(err))) end
    end
    pcall(function() core:ToUtf8mb4(P.TableOrder) end)
end

-- ---------------------------------------------------------------------
-- Entreprises
-- ---------------------------------------------------------------------
local function RowToShop(r)
    return { id = r.id, name = r.name, specialty = r.specialty, logo = r.logo or '', description = r.description or '', color = r.color or '#7c6cff',
        ownerCid = r.owner_cid, ownerName = r.owner_name or '', job = r.job, jobLabel = r.name, society = r.society, matPrefix = r.mat_prefix or 'EN-',
        enabled = r.enabled == 1 or r.enabled == true, deleted = r.deleted == 1 or r.deleted == true, disabledReason = r.disabled_reason,
        createdAt = r.created, options = {} }
end
function P.Opt(D, key, def) local v = D and D.options and D.options[key] if v == nil then return def end return v end

function P.LoadShops()
    P.shops = {}
    for _, r in ipairs(MySQL.query.await("SELECT *, DATE_FORMAT(`created_at`, '%d/%m/%Y') AS created FROM `ent_companies`") or {}) do P.shops[r.id] = RowToShop(r) end
end
function P.ShopByJob(job)
    for _, D in pairs(P.shops) do if D.job == job and not D.deleted then return D end end
end
function P.ShopByOwner(cid)
    for _, D in pairs(P.shops) do if D.ownerCid == cid and not D.deleted then return D end end
end
function P.SaveShop(D)
    MySQL.update.await([[UPDATE `ent_companies` SET `name` = ?, `specialty` = ?, `logo` = ?, `description` = ?, `color` = ?, `owner_cid` = ?, `owner_name` = ?,
        `enabled` = ?, `deleted` = ?, `disabled_reason` = ? WHERE `id` = ?]], { D.name, D.specialty, D.logo ~= '' and D.logo or nil, D.description, D.color,
        D.ownerCid, D.ownerName, D.enabled and 1 or 0, D.deleted and 1 or 0, D.disabledReason, D.id })
end
-- Entreprise en activité : active et non supprimée
function P.ShopOpen(D) return D ~= nil and D.enabled and not D.deleted end

-- ---------------------------------------------------------------------
-- Grades (par entreprise)
-- ---------------------------------------------------------------------
local function DecodePerms(raw)
    local set = {}
    for _, k in ipairs(dec(raw, {})) do if ENTPermSet[k] then set[k] = true end end
    return set
end
function P.EncodePerms(set)
    local list = {}
    for _, p in ipairs(ENTPerms) do if set[p.key] then list[#list + 1] = p.key end end
    return json.encode(list)
end
function P.LoadGrades()
    P.grades = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `ent_grades`') or {}) do
        P.grades[r.id] = { id = r.id, shop_id = r.shop_id, name = r.name, level = r.level, salary = r.salary, perms = DecodePerms(r.perms),
            isDefault = r.is_default == 1 or r.is_default == true, active = not (r.active == 0 or r.active == false) }
    end
end
function P.SortedGrades(shopId)
    local list = {}
    for _, g in pairs(P.grades) do if g.shop_id == shopId then list[#list + 1] = g end end
    table.sort(list, function(a, b) return a.level < b.level end)
    return list
end
function P.DefaultGrade(shopId)
    local sorted = P.SortedGrades(shopId)
    for _, g in ipairs(sorted) do if g.isDefault and g.active then return g end end
    return sorted[1]
end
function P.GradeByLevel(shopId, level)
    for _, g in pairs(P.grades) do if g.shop_id == shopId and g.level == level then return g end end
end
function P.TopLevel(shopId)
    local top = 0
    for _, g in pairs(P.grades) do if g.shop_id == shopId and g.level > top then top = g.level end end
    return top
end
function P.TopGrade(shopId) return P.GradeByLevel(shopId, P.TopLevel(shopId)) end

-- Grades de départ d'une nouvelle entreprise
function P.SeedGrades(shopId)
    for _, g in ipairs(Config.DefaultGrades) do
        local set = {}
        if g.perms == 'all' then for _, p in ipairs(ENTPerms) do set[p.key] = true end
        else for _, k in ipairs(g.perms or {}) do set[k] = true end end
        local id = MySQL.insert.await('INSERT INTO `ent_grades` (`shop_id`, `name`, `level`, `salary`, `perms`, `is_default`) VALUES (?, ?, ?, ?, ?, ?)',
            { shopId, g.name, g.level, g.salary or 0, P.EncodePerms(set), g.default and 1 or 0 })
        if id then
            MySQL.insert.await('INSERT INTO `ent_rates` (`shop_id`, `grade_id`, `grade_name`, `rate`, `actor_name`) VALUES (?, ?, ?, ?, ?)', { shopId, id, g.name, g.salary or 0, 'Création' })
            P.grades[id] = { id = id, shop_id = shopId, name = g.name, level = g.level, salary = g.salary or 0, perms = set, isDefault = g.default == true, active = true }
        end
    end
end

-- Métier elyzea_core de l'entreprise : un grade du core par niveau ; payment = 0
-- (les heures de service sont payées par la direction dans Finance, depuis le compte de l'entreprise)
function P.SyncCoreJob(D)
    if not D or D.deleted or not D.job then return end
    local grades = {}
    local top = P.TopLevel(D.id)
    for _, g in ipairs(P.SortedGrades(D.id)) do
        grades[g.level] = { name = g.name, payment = 0, isboss = g.perms.direction == true or g.level == top }
    end
    if not grades[0] then grades[0] = { name = 'Sans grade', payment = 0 } end
    local ok, err = pcall(function()
        core:CreateJob(D.job, { label = D.name, type = 'business', defaultDuty = false, offDutyPay = false, grades = grades })
    end)
    if not ok then print(('^1[ENTREPRISES] Métier %s non déclaré : %s^0'):format(D.job, tostring(err))) end
end

-- ---------------------------------------------------------------------
-- Employés
-- ---------------------------------------------------------------------
function P.LoadEmployees()
    P.employees = {}
    for _, r in ipairs(MySQL.query.await([[SELECT `citizenid`, `shop_id`, `name`, `matricule`, `grade_id`, `note`, `total_seconds`, `unpaid_seconds`, `unpaid_amount`,
        DATE_FORMAT(`recruited_at`, '%d/%m/%Y') AS recruited, DATE_FORMAT(`promoted_at`, '%d/%m/%Y') AS promoted FROM `ent_employees`]]) or {}) do
        r.total_seconds, r.unpaid_seconds, r.unpaid_amount = tonumber(r.total_seconds) or 0, tonumber(r.unpaid_seconds) or 0, tonumber(r.unpaid_amount) or 0
        P.employees[r.citizenid] = r
    end
end
function P.ShopEmployees(shopId)
    local list = {}
    for cid, e in pairs(P.employees) do if e.shop_id == shopId then list[cid] = e end end
    return list
end
function P.CountEmployees(shopId)
    local n = 0
    for _, e in pairs(P.employees) do if e.shop_id == shopId then n = n + 1 end end
    return n
end
function P.NextMatricule(D)
    local max, prefix = 0, D.matPrefix or 'EN-'
    for _, e in pairs(P.employees) do
        if e.shop_id == D.id then
            local n = tonumber(tostring(e.matricule):sub(#prefix + 1))
            if n and n > max then max = n end
        end
    end
    return ('%s%03d'):format(prefix, max + 1)
end

function P.Employee(src) local cid = P.Cid(src) return cid and P.employees[cid] or nil end
function P.GradeOfCid(cid) local e = P.employees[cid] return e and P.grades[e.grade_id] or nil end
function P.Grade(src) local cid = P.Cid(src) return cid and P.GradeOfCid(cid) or nil end

-- Entreprise du joueur : fiche d'employé + métier du core correspondant
function P.ShopOf(src)
    local p = P.GetPlayer(src)
    if not p then return nil end
    local e = P.employees[p.PlayerData.citizenid]
    local D = e and P.shops[e.shop_id]
    if not D or D.deleted or not (p.PlayerData.job and p.PlayerData.job.name == D.job) then return nil end
    return D
end
function P.IsMember(src) return P.ShopOf(src) ~= nil end
function P.OnDuty(src) return P.duty[tonumber(src) or -1] == true end
function P.Can(src, perm)
    local D = P.ShopOf(src)
    if not D then return false end
    local g = P.Grade(src)
    return g ~= nil and g.perms[perm] == true
end

function P.AddLog(shopId, actorSrc, targetCid, targetName, action, oldGrade, newGrade, reason)
    local aCid, aName
    if type(actorSrc) == 'number' and actorSrc > 0 then aCid, aName = P.Cid(actorSrc), P.Name(actorSrc)
    elseif type(actorSrc) == 'string' then aName = actorSrc end
    MySQL.insert([[INSERT INTO `ent_admin_log` (`shop_id`, `actor_cid`, `actor_name`, `target_cid`, `target_name`, `action`, `old_grade`, `new_grade`, `reason`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], { shopId, aCid, aName, targetCid, targetName, action, oldGrade, newGrade, reason and P.Clean(reason, 255) or nil })
end

P.applying = {}
function P.ApplyGrade(cid, grade)
    local e = P.employees[cid]
    local D = e and P.shops[e.shop_id]
    if not e or not grade or not D or grade.shop_id ~= e.shop_id then return false end
    if P.FlushCid then P.FlushCid(cid) end
    e.grade_id = grade.id
    MySQL.update.await('UPDATE `ent_employees` SET `grade_id` = ?, `promoted_at` = NOW() WHERE `citizenid` = ?', { grade.id, cid })
    P.applying[cid] = true
    pcall(function() core:AddPlayerToJob(cid, D.job, grade.level) end)
    P.applying[cid] = nil
    local src = core:GetSourceByCitizenId(cid)
    if src then
        if P.OnDuty(src) then local p = P.GetPlayer(src) if p then pcall(function() p.Functions.SetJobDuty(true) end) end end
        P.PushState(src)
    end
    return true
end

function P.Hire(D, cid, name, grade)
    local cur = P.employees[cid]
    if cur then
        local other = P.shops[cur.shop_id]
        return false, cur.shop_id == D.id and 'Déjà employé de cette entreprise.' or ('Déjà employé de « %s ».'):format(other and other.name or '?')
    end
    local mat = P.NextMatricule(D)
    MySQL.insert.await('INSERT INTO `ent_employees` (`citizenid`, `shop_id`, `name`, `matricule`, `grade_id`) VALUES (?, ?, ?, ?, ?)', { cid, D.id, name, mat, grade.id })
    P.employees[cid] = { citizenid = cid, shop_id = D.id, name = name, matricule = mat, grade_id = grade.id, recruited = os.date('%d/%m/%Y'),
        total_seconds = 0, unpaid_seconds = 0, unpaid_amount = 0 }
    P.applying[cid] = true
    pcall(function() core:AddPlayerToJob(cid, D.job, grade.level) end)
    P.applying[cid] = nil
    local src = core:GetSourceByCitizenId(cid)
    if src then P.PushState(src) end
    return true, mat
end

function P.Remove(cid)
    local e = P.employees[cid]
    if not e then return false end
    local D = P.shops[e.shop_id]
    local src = core:GetSourceByCitizenId(cid)
    if src and P.OnDuty(src) and P.SetDuty then P.SetDuty(src, false, true) end
    P.employees[cid] = nil
    MySQL.update.await('DELETE FROM `ent_employees` WHERE `citizenid` = ?', { cid })
    if D and D.job then
        P.applying[cid] = true
        pcall(function() core:RemovePlayerFromJob(cid, D.job) end)
        P.applying[cid] = nil
    end
    if src then P.PushState(src) end
    return true
end

-- ---------------------------------------------------------------------
-- État publié au client (affichage seulement : le serveur revérifie tout)
-- ---------------------------------------------------------------------
function P.PushState(src)
    if not GetPlayerName(src) then return end
    local D = P.ShopOf(src)
    if not D then
        if Player(src).state.ent ~= nil then Player(src).state:set('ent', nil, true) end
        return
    end
    local e, g = P.Employee(src), P.Grade(src)
    local perms = {}
    for k in pairs(g and g.perms or {}) do perms[k] = true end
    Player(src).state:set('ent', {
        shop = D.id, shopName = D.name, logo = D.logo, color = D.color, specialty = D.specialty, matricule = e.matricule, name = P.Name(src),
        grade = g and g.name or '?', level = g and g.level or 0, top = g ~= nil and g.level >= P.TopLevel(D.id), owner = e.citizenid == D.ownerCid,
        perms = perms, duty = P.OnDuty(src), status = P.status[src] or 'available', open = P.ShopOpen(D),
    }, true)
end
function P.PushAll() for src in pairs(core:GetPlayers()) do P.PushState(src) end end
function P.PushShop(shopId)
    for src in pairs(core:GetPlayers()) do
        local e = P.Employee(src)
        if e and e.shop_id == shopId then P.PushState(src) end
    end
end

-- ---------------------------------------------------------------------
-- Changements de métier faits ailleurs (menu admin, /setjob, autre métier…)
-- ---------------------------------------------------------------------
AddEventHandler('elyzea:server:onJobUpdate', function(src, job, old)
    local cid = P.Cid(src)
    if not cid or P.applying[cid] or not P.ready then return end
    local D = job and P.ShopByJob(job.name)
    local cur = P.employees[cid]
    if D then
        local level = job.grade and job.grade.level or 0
        local grade = P.GradeByLevel(D.id, level) or P.DefaultGrade(D.id)
        if cur and cur.shop_id ~= D.id then
            if P.OnDuty(src) and P.SetDuty then P.SetDuty(src, false, true) end
            P.employees[cid] = nil
            MySQL.update.await('DELETE FROM `ent_employees` WHERE `citizenid` = ?', { cid })
            P.AddLog(cur.shop_id, 'Système', cid, P.Name(src), 'Départ', nil, nil, 'Métier changé hors de la tablette')
            cur = nil
        end
        if grade and not cur then
            P.Hire(D, cid, P.Name(src), grade)
            P.AddLog(D.id, 'Système', cid, P.Name(src), 'Recrutement', nil, grade.name, 'Métier donné hors de la tablette')
        elseif grade and cur.grade_id ~= grade.id then
            local before = P.grades[cur.grade_id]
            P.ApplyGrade(cid, grade)
            P.AddLog(D.id, 'Système', cid, P.Name(src), 'Changement de grade', before and before.name, grade.name, 'Grade changé hors de la tablette')
        end
    elseif cur and old and P.shops[cur.shop_id] and old.name == P.shops[cur.shop_id].job then
        -- A pris un autre métier : il quitte l'entreprise (le patron fondateur reste propriétaire, voir company.lua)
        if P.OnDuty(src) and P.SetDuty then P.SetDuty(src, false, true) end
        P.employees[cid] = nil
        MySQL.update('DELETE FROM `ent_employees` WHERE `citizenid` = ?', { cid })
        P.AddLog(cur.shop_id, 'Système', cid, P.Name(src), 'Départ', nil, nil, 'Métier changé hors de la tablette')
    end
    P.PushState(src)
end)

AddEventHandler('elyzea:server:playerLoaded', function(src)
    local D = P.ShopOf(src)
    local p = P.GetPlayer(src)
    if D and p and p.PlayerData.job.onduty then pcall(function() p.Functions.SetJobDuty(false) end) end
    P.PushState(src)
end)

-- ---------------------------------------------------------------------
-- Points d'entrée des requêtes
-- ---------------------------------------------------------------------
local rate = {}
function P.Allowed(src, n)
    local now = GetGameTimer()
    local r = rate[src]
    if not r or now - r.t > 1000 then rate[src] = { t = now, n = 1 } return true end
    r.n = r.n + 1
    return r.n <= (n or 12)
end
AddEventHandler('playerDropped', function() rate[source] = nil end)

local function Run(kind, a, action, ...)
    local ok, res = pcall(a.fn, ...)
    if not ok then
        print(('^1[ENTREPRISES] Erreur %s « %s » : %s^0'):format(kind, tostring(action), tostring(res)))
        return { error = 'Erreur serveur.' }
    end
    return res or {}
end
P.Run = Run

-- Employés : l'entreprise est celle du joueur, jamais une valeur envoyée par le client
function P.Request(src, action, data)
    if not P.ready then return { error = 'Les entreprises démarrent, réessayez dans un instant.' } end
    if not P.Allowed(src) then return { error = 'Trop de demandes, patientez une seconde.' } end
    local a = P.Actions[tostring(action)]
    if not a then return { error = 'Action inconnue.' } end
    local D = P.ShopOf(src)
    if a.perm ~= false then
        if not D then return { error = 'Réservé aux employés d\'une entreprise.' } end
        if not D.enabled and a.open ~= false then return { error = ('L\'entreprise « %s » est suspendue par le staff.'):format(D.name) } end
        if a.perm and not P.Can(src, a.perm) then return { error = 'Votre grade ne permet pas cette action.' } end
        if a.duty and not P.OnDuty(src) then return { error = 'Prenez votre service pour faire cela.' } end
    end
    return Run('employé', a, action, src, type(data) == 'table' and data or {}, D)
end
Ely.callback.register('ent:req', function(src, action, data) return P.Request(src, action, data) end)

-- Tout joueur (liste des entreprises, création…)
function P.Public(src, action, data)
    if not P.ready then return { error = 'Les entreprises démarrent, réessayez dans un instant.' } end
    if not P.Allowed(src, 15) then return { error = 'Trop de demandes, patientez une seconde.' } end
    local a = P.Pub[tostring(action)]
    if not a then return { error = 'Action inconnue.' } end
    return Run('public', a, action, src, type(data) == 'table' and data or {})
end
Ely.callback.register('ent:pub', function(src, action, data) return P.Public(src, action, data) end)

-- Staff : permission « entreprises_manage » d'admin_menu, ou ACE « elyzea.entreprises »
function P.IsStaff(src)
    if IsPlayerAceAllowed(tostring(src), 'elyzea.entreprises') then return true end
    if GetResourceState('admin_menu') ~= 'started' then return false end
    local ok, res = pcall(function() return exports.admin_menu:HasPermission(src, 'entreprises_manage') end)
    return ok and res == true
end
Ely.callback.register('ent:admin', function(src, action, data)
    if not P.ready then return { error = 'Les entreprises démarrent, réessayez dans un instant.' } end
    if not P.IsStaff(src) then return { error = 'Réservé au staff (permission « Entreprises des joueurs » du menu admin).' } end
    if not P.Allowed(src, 20) then return { error = 'Trop de demandes, patientez une seconde.' } end
    local a = P.Admin[tostring(action)]
    if not a then return { error = 'Action inconnue.' } end
    return Run('staff', a, action, src, type(data) == 'table' and data or {})
end)

-- ---------------------------------------------------------------------
-- Démarrage
-- ---------------------------------------------------------------------
CreateThread(function()
    InitDb()
    local ok, err = pcall(function()
        P.LoadShops()
        P.LoadGrades()
        P.LoadEmployees()
    end)
    if not ok then print(('^1[ENTREPRISES] Chargement impossible : %s^0'):format(tostring(err))) return end
    for _, D in pairs(P.shops) do P.SyncCoreJob(D) end
    for _, fn in ipairs(P.OnReady) do local okr, e = pcall(fn) if not okr then print(('^1[ENTREPRISES] Démarrage : %s^0'):format(tostring(e))) end end
    P.ready = true
    for src, p in pairs(core:GetPlayers()) do
        local D = P.ShopOf(src)
        if D and p.PlayerData.job.onduty then pcall(function() p.Functions.SetJobDuty(false) end) end
        P.PushState(src)
    end
    local ns, ne = 0, 0
    for _, D in pairs(P.shops) do if not D.deleted then ns = ns + 1 end end
    for _ in pairs(P.employees) do ne = ne + 1 end
    print(('^2[ENTREPRISES] Prêt : %d entreprise(s), %d employé(s).^0'):format(ns, ne))
end)
