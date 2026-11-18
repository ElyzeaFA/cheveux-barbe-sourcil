-- =====================================================================
--  Simulation hors jeu d'ELYZEA ENTREPRISES : vrais scripts serveur
--    · elyzea_entreprises : config, shared/perms, server/*
--    · elyzea_jobphone    : config, server/main, server/business (téléphone de service)
--    · elyzea_aura        : config, server/main, server/entreprises (téléphone perso, appli « Entreprises »)
--  chargés ensemble, reliés par leurs exports, sur une vraie base MariaDB.
--  Imités : natives FiveM, elyzea_core (joueurs, métiers, comptes de société), hébergeur d'images.
--  PHASE 2 : « redémarrage » d'elyzea_entreprises sur la même base.
-- =====================================================================
local ROOT, MySQL = ...
local ROOT, MySQL = ...
local passes, fails = 0, 0
local function P(...) print(...) end
local function check(ok, label)
    if ok then passes = passes + 1 P('  ok   ' .. label) else fails = fails + 1 P('  ÉCHEC ' .. label) end
end

-- JSON minimal
local json = {}
do
    local function esc(s) return s:gsub('[%c"\\]', function(c) local m = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n' } return m[c] or ('\\u%04x'):format(c:byte()) end) end
    local function isArray(t) local n = 0 for k in pairs(t) do if type(k) ~= 'number' then return false end n = n + 1 end return n == #t end
    function json.encode(v)
        local t = type(v)
        if t == 'nil' then return 'null' elseif t == 'boolean' then return tostring(v)
        elseif t == 'number' then return (math.type(v) == 'integer' or v ~= math.floor(v)) and tostring(v) or ('%d'):format(v)
        elseif t == 'string' then return '"' .. esc(v) .. '"'
        elseif t == 'table' then
            local out = {}
            if next(v) == nil then return '[]' end
            if isArray(v) then for _, x in ipairs(v) do out[#out + 1] = json.encode(x) end return '[' .. table.concat(out, ',') .. ']' end
            for k, x in pairs(v) do out[#out + 1] = json.encode(tostring(k)) .. ':' .. json.encode(x) end
            return '{' .. table.concat(out, ',') .. '}'
        end
        return 'null'
    end
    function json.decode(s)
        local i = 1
        local function ws() i = s:find('%S', i) or #s + 1 end
        local val
        local function str()
            local out = {} i = i + 1
            while true do
                local c = s:sub(i, i)
                if c == '"' then i = i + 1 break end
                if c == '\\' then local n = s:sub(i + 1, i + 1) out[#out + 1] = ({ n = '\n', ['"'] = '"', ['\\'] = '\\', ['/'] = '/' })[n] or n i = i + 2
                else out[#out + 1] = c i = i + 1 end
            end
            return table.concat(out)
        end
        function val()
            ws()
            local c = s:sub(i, i)
            if c == '{' then local t = {} i = i + 1 ws() if s:sub(i, i) == '}' then i = i + 1 return t end
                while true do ws() local k = str() ws() i = i + 1 t[k] = val() ws() local d = s:sub(i, i) i = i + 1 if d == '}' then break end end return t
            elseif c == '[' then local t = {} i = i + 1 ws() if s:sub(i, i) == ']' then i = i + 1 return t end
                while true do t[#t + 1] = val() ws() local d = s:sub(i, i) i = i + 1 if d == ']' then break end end return t
            elseif c == '"' then return str()
            elseif s:sub(i, i + 3) == 'true' then i = i + 4 return true
            elseif s:sub(i, i + 4) == 'false' then i = i + 5 return false
            elseif s:sub(i, i + 3) == 'null' then i = i + 4 return nil
            else local num = s:match('^-?%d+%.?%d*[eE]?[-+]?%d*', i) i = i + #num return tonumber(num) end
        end
        if type(s) ~= 'string' or s == '' then return nil end
        return val()
    end
end

-- Horloge et fils
local GT = 0
local threads, errors = {}, {}
local function CreateThread(fn) threads[#threads + 1] = { co = coroutine.create(fn), at = GT } end
local function Wait(ms) coroutine.yield(ms or 0) end
local function run(ms)
    local stop = GT + (ms or 0)
    repeat
        local moved = true
        while moved do
            moved = false
            for i = #threads, 1, -1 do
                local t = threads[i]
                if t and coroutine.status(t.co) ~= 'dead' and t.at <= GT then
                    local ok, w = coroutine.resume(t.co)
                    if not ok then errors[#errors + 1] = tostring(w) P('  erreur Lua : ' .. tostring(w)) end
                    if coroutine.status(t.co) == 'dead' then table.remove(threads, i) else t.at = GT + math.max(1, w or 0) moved = true end
                end
            end
        end
        if GT >= stop then break end
        local nextAt = stop
        for _, t in ipairs(threads) do if t.at > GT and t.at < nextAt then nextAt = t.at end end
        GT = nextAt
    until false
end
-- Appel « dans un fil » (les scripts attendent la base avec .await)
local function call(fn, ...)
    local args, res, done = table.pack(...), nil, false
    CreateThread(function() res = table.pack(fn(table.unpack(args, 1, args.n))) done = true end)
    run(10)
    if not done then run(20000) end
    return table.unpack(res or {}, 1, res and res.n or 0)
end

-- ---------------------------------------------------------------------
-- Monde : joueurs, métiers, comptes de société
-- ---------------------------------------------------------------------
local players, notes, client = {}, {}, {}
local JOBS, SOC, SOCLOG = {}, {}, {}
local entHandlers = {}   -- événements serveur d'elyzea_entreprises (onJobUpdate…)
local function fireEnt(name, ...) for _, fn in ipairs(entHandlers[name] or {}) do fn(...) end end
local function makePlayer(src, cid, first, last, bank, job, pos)
    players[src] = { src = src, cid = cid, first = first, last = last, money = { bank = bank or 0, cash = 0 },
        job = job or { name = 'unemployed', label = 'Sans emploi', grade = { level = 0 }, onduty = false }, pos = pos or { x = 500.0 + src * 50, y = 0.0, z = 0.0 }, state = {} }
    notes[src] = {}
end
local function srcOf(cid) for s, p in pairs(players) do if p.cid == cid then return s end end end
local function playerObj(src)
    local p = players[tonumber(src) or -1]
    if not p then return nil end
    return {
        PlayerData = { citizenid = p.cid, source = src, charinfo = { firstname = p.first, lastname = p.last }, job = p.job, metadata = {} },
        Functions = {
            GetMoney = function(k) return p.money[k] or 0 end,
            RemoveMoney = function(k, n) if (p.money[k] or 0) < n then return false end p.money[k] = p.money[k] - n return true end,
            AddMoney = function(k, n) p.money[k] = (p.money[k] or 0) + n return true end,
            SetJobDuty = function(on) p.job.onduty = on == true end,
            GetItemByName = function() return nil end,
        },
    }
end
local function setJob(cid, name, level)
    local s = srcOf(cid)
    local p = s and players[s]
    if not p then return false end
    local old = p.job
    local j = JOBS[name]
    p.job = { name = name, label = j and j.label or name, grade = { level = level or 0 }, onduty = false }
    fireEnt('elyzea:server:onJobUpdate', s, p.job, old)
    return true
end
local core = {
    Notify = function(_, src, msg) if notes[src] then table.insert(notes[src], msg) end end,
    GetPlayer = function(_, src) return playerObj(src) end,
    GetPlayers = function() local t = {} for s in pairs(players) do t[s] = playerObj(s) end return t end,
    GetPlayerByCitizenId = function(_, cid) local s = srcOf(cid) return s and playerObj(s) end,
    GetSourceByCitizenId = function(_, cid) return srcOf(cid) end,
    GetOfflinePlayer = function() return nil end,
    SaveOffline = function() return false end,
    CreateJob = function(_, name, data) JOBS[name] = data return true end,
    RemoveJob = function(_, name) JOBS[name] = nil return true end,
    GetJobs = function() return { police = { label = 'LSPD' }, ambulance = { label = 'SAMS' } } end,
    AddPlayerToJob = function(_, cid, name, level) return setJob(cid, name, level) end,
    RemovePlayerFromJob = function(_, cid, name) local s = srcOf(cid) if s and players[s].job.name == name then return setJob(cid, 'unemployed', 0) end return true end,
    GetSocietyMoney = function(_, n) SOC[n] = SOC[n] or 0 return SOC[n] end,
    AddSocietyMoney = function(_, n, a, r) SOC[n] = (SOC[n] or 0) + a table.insert(SOCLOG, { society = n, amount = a, reason = r }) return true end,
    RemoveSocietyMoney = function(_, n, a, r) if (SOC[n] or 0) < a then return false end SOC[n] = SOC[n] - a table.insert(SOCLOG, { society = n, amount = -a, reason = r }) return true end,
    GetSocietyLogs = function(_, n) local out = {} for i = #SOCLOG, 1, -1 do if SOCLOG[i].society == n then out[#out + 1] = SOCLOG[i] end end return out end,
    ToUtf8mb4 = function() return 0 end,
    GiveKeys = function() return true end,
}

-- Hébergeur d'images de l'appareil photo (exports d'elyzea_aura › elyfy.lua, imités)
local auraUpload = {
    UploadUrl = function() return 'https://api.fivemanage.com/api/upload?token=UNIQUE' end,
    UploadHostAllowed = function(url) return type(url) == 'string' and url:match('^https://[%w%.%-]*fivemanage%.com/') ~= nil end,
    ImportBase = function() return 'http://203.0.113.7:30120' end,
}

-- ---------------------------------------------------------------------
-- Ressources : chacune son environnement et ses exports
-- ---------------------------------------------------------------------
local resExports, callbacks, handlers, http = {}, {}, {}, {}
local function proxy(res)
    return setmetatable({}, { __index = function(_, k)
        return function(_, ...)
            local f = resExports[res] and resExports[res][k]
            if not f then error(('export %s:%s absent'):format(res, k)) end
            return f(...)
        end
    end })
end
local STARTED = { elyzea_jobphone = true, elyzea_aura = true, elyzea_core = true, elyzea_entreprises = true, ['pma-voice'] = true }
local ACE = { [6] = true }
local function makeEnv(res)
    local env = {}
    local VM = {}
    VM.__sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, VM) end
    VM.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
    env.json, env.vector3 = json, function(x, y, z) return setmetatable({ x = x, y = y, z = z }, VM) end
    env.CreateThread, env.Wait = CreateThread, Wait
    env.SetTimeout = function(ms, fn) CreateThread(function() Wait(ms) fn() end) end
    env.GetGameTimer = function() return GT end
    env.os = setmetatable({ time = function(t) if t then return os.time(t) end return 1800000000 + GT // 1000 end }, { __index = os })
    env.MySQL = MySQL
    env.print = function(...)
        local s = table.concat({ ... }, ' ')
        if s:find('Appareil photo', 1, true) or s:find('Fivemanage', 1, true) then return end
        if s:find('%^1') then errors[#errors + 1] = s P('  ' .. s) end
    end
    env.exports = setmetatable({ elyzea_core = core, elyzea_jobphone = proxy('elyzea_jobphone'), elyzea_entreprises = proxy('elyzea_entreprises'),
        elyzea_aura = setmetatable({}, { __index = function(_, k)
            if auraUpload[k] then return function(_, ...) return auraUpload[k](...) end end
            return proxy('elyzea_aura')[k]
        end }) }, {
        __call = function(_, name, fn) resExports[res] = resExports[res] or {} resExports[res][name] = fn end,
        __index = function() return setmetatable({}, { __index = function() return function() return nil end end }) end,
    })
    env.GetResourceState = function(r) return STARTED[r] and 'started' or 'missing' end
    env.GetCurrentResourceName = function() return res end
    env.LoadResourceFile = function(r, f) local h = io.open(ROOT .. '/../' .. r .. '/' .. f, 'r') if not h then return nil end local s = h:read('a') h:close() return s end
    env.Ely = { callback = { register = function(n, fn) callbacks[n] = fn end } }
    env.RegisterNetEvent = function(name, fn) if fn then handlers[res .. '|' .. name] = handlers[res .. '|' .. name] or {} table.insert(handlers[res .. '|' .. name], fn) end end
    env.AddEventHandler = function(name, fn)
        handlers[res .. '|' .. name] = handlers[res .. '|' .. name] or {} table.insert(handlers[res .. '|' .. name], fn)
        if res == 'elyzea_entreprises' then entHandlers[name] = entHandlers[name] or {} table.insert(entHandlers[name], fn) end
    end
    env.TriggerEvent = function(name, ...) for _, fn in ipairs(handlers['elyzea_jobphone|' .. name] or {}) do fn(...) end end
    env.TriggerClientEvent = function(name, src, ...) client[#client + 1] = { src = src, name = name, args = table.pack(...) } end
    env.TriggerLatentClientEvent = env.TriggerClientEvent
    env.GetPlayerName = function(src) local p = players[tonumber(src) or -1] return p and (p.first .. ' ' .. p.last) or nil end
    env.GetPlayers = function() local t = {} for s in pairs(players) do t[#t + 1] = tostring(s) end return t end
    env.GetPlayerIdentifiers = function() return {} end
    env.GetPlayerPed = function(src) return players[tonumber(src) or -1] and tonumber(src) or 0 end
    env.GetEntityCoords = function(ped) local p = players[ped] local c = p and p.pos or { x = 0, y = 0, z = 0 } return env.vector3(c.x, c.y, c.z) end
    env.GetEntityHealth = function() return 200 end
    env.GetEntityMaxHealth = function() return 200 end
    env.IsPlayerAceAllowed = function(src) return ACE[tonumber(src)] == true end
    env.RegisterCommand = function() end
    env.SetHttpHandler = function(fn) http[res] = fn end
    env.GlobalState, env.source = {}, 0
    env.Player = function(src)
        local p = players[tonumber(src) or -1]
        local st = p and p.state or {}
        return { state = setmetatable({ set = function(_, k, v) st[k] = v end }, { __index = st }) }
    end
    env.utf8 = utf8
    setmetatable(env, { __index = function(_, k) local v = _G[k] if v ~= nil then return v end return function() return nil end end })
    return env
end
local function loadInto(env, root, path)
    local f = assert(io.open(root .. '/' .. path, 'r'))
    local s = f:read('a') f:close()
    assert(load(s, '@' .. path, 't', env))()
end
local ENTFILES = { 'config.lua', 'shared/perms.lua', 'server/main.lua', 'server/service.lua', 'server/finance.lua', 'server/direction.lua',
    'server/company.lua', 'server/admin.lua', 'server/phone.lua', 'server/api.lua' }
local E = makeEnv('elyzea_entreprises')
for _, f in ipairs(ENTFILES) do loadInto(E, ROOT, f) end
local J, A = makeEnv('elyzea_jobphone'), makeEnv('elyzea_aura')
for _, f in ipairs({ 'config.lua', 'server/main.lua', 'server/business.lua' }) do loadInto(J, ROOT .. '/../elyzea_jobphone', f) end
loadInto(A, ROOT .. '/../elyzea_aura', 'config.lua')
A.Config.Framework = 'elyzea'
loadInto(A, ROOT .. '/../elyzea_aura', 'server/main.lua')
loadInto(A, ROOT .. '/../elyzea_aura', 'server/entreprises.lua')

-- Joueurs
makePlayer(1, 'ALICE', 'Alice', 'Martin', 30000, nil, { x = 0.0, y = 0.0, z = 0.0 })
makePlayer(2, 'BOB', 'Bob', 'Reed', 100000, { name = 'police', label = 'LSPD', grade = { level = 3 }, onduty = false })
makePlayer(3, 'CARL', 'Carl', 'Petit', 1000)
makePlayer(4, 'DINA', 'Dina', 'Lopez', 200, nil, { x = 2.0, y = 0.0, z = 0.0 })
makePlayer(5, 'EVE', 'Eve', 'Cliente', 500)
makePlayer(6, 'STAFF', 'Sam', 'Staff', 0)
run(3000)

local function req(src, action, data) GT = GT + 1500 return call(callbacks['ent:req'], src, action, data or {}) end
local function adm(src, action, data) GT = GT + 1500 return call(callbacks['ent:admin'], src, action, data or {}) end
local function jp(src, action, data) GT = GT + 1500 return call(callbacks['jobphone:req'], src, action, data or {}) end
local function aura(src, name, args)
    GT = GT + 1500
    local before = #client
    call(function() A.source = src for _, fn in ipairs(handlers['elyzea_aura|elyzea_aura:server:cb'] or {}) do fn(name, 99, args or {}) end end)
    for i = #client, before + 1, -1 do local e = client[i] if e.src == src and e.name == 'elyzea_aura:client:cb' then return e.args[2] end end
end
local function net(res, name, src, ...) local args = table.pack(...) return call(function() E.source = src for _, fn in ipairs(handlers[res .. '|' .. name] or {}) do fn(table.unpack(args, 1, args.n)) end end) end
local function ev(src, name) local out = {} for _, e in ipairs(client) do if e.src == src and e.name == name then out[#out + 1] = e.args end end return out end
local function lastEv(src, name) local l = ev(src, name) return l[#l] end
local function clearEv() client = {} end
local function noteHas(src, pat) for _, n in ipairs(notes[src] or {}) do if tostring(n):find(pat, 1, true) then return true end end return false end
local function httpPost(path, body)
    local out = {}
    local reqObj = { method = 'POST', path = '/' .. path, address = '198.51.100.9:5555', headers = {}, setDataHandler = function(fn) out.feed = fn end }
    local resObj = { writeHead = function(code) out.code = code end, send = function(s) out.body = s end }
    call(function() http.elyzea_entreprises(reqObj, resObj) out.feed(json.encode(body)) end)
    run(50)
    return out.code, out.body and json.decode(out.body) or nil
end
local function httpGet(path)
    local out = {}
    call(function() http.elyzea_entreprises({ method = 'GET', path = path, headers = {} }, { writeHead = function(code) out.code = code end, send = function(s) out.body = s end }) end)
    return out.code, out.body
end
local Ent = E.Ent
local LOGO = 'https://r2.fivemanage.com/abc/logo.png'
local DESC = 'Mariages, anniversaires, soirées privées : on organise tout.\nDevis gratuit par message.'

P('\n[Démarrage]')
check(Ent.ready and J.JP.ready and J.JP.Biz.ready, 'entreprises et téléphone de service prêts')
check(tonumber(MySQL.scalar.await("SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME LIKE 'ent\\_%'")) == 7, '7 tables ent_* créées')

P('\n[Lancer mon Business : vérifications]')
local m = aura(1, 'entMine')
check(m and m.ok and m.state == 'none' and m.canCreate and m.price == 25000 and #m.specialties >= 10, 'Alice (sans emploi) : peut créer, prix 25 000 $, spécialités')
local base = { name = 'Vinewood Événements', specialty = 'evenementiel', logo = LOGO, description = DESC, color = '#ec4899' }
local function with(t) local c = {} for k, v in pairs(base) do c[k] = v end for k, v in pairs(t) do c[k] = v end return c end
local r = aura(1, 'entCreate', with({ logo = '' }))
check(r and not r.ok and r.error:find('logo'), 'sans logo : refusé')
r = aura(1, 'entCreate', with({ logo = 'javascript:alert(1)' }))
check(r and not r.ok and r.error:find('Logo'), 'logo « javascript: » : refusé')
r = aura(1, 'entCreate', with({ logo = "https://x.com/a.png' onerror='x" }))
check(r and not r.ok, 'logo avec guillemets : refusé')
r = aura(1, 'entCreate', with({ name = 'LSPD Bis' }))
check(r and not r.ok and r.error:find('autorisé'), 'nom contenant « lspd » : refusé')
r = aura(1, 'entCreate', with({ name = 'Ab' }))
check(r and not r.ok and r.error:find('court'), 'nom trop court : refusé')
r = aura(1, 'entCreate', with({ description = 'court' }))
check(r and not r.ok and r.error:find('10'), 'description trop courte : refusée')
r = aura(1, 'entCreate', with({ specialty = 'banque_suisse' }))
check(r and not r.ok and r.error:find('spécialité'), 'spécialité inconnue : refusée')
check(players[1].money.bank == 30000, 'rien n\'a été payé pendant les refus')

P('\n[Création]')
r = aura(1, 'entCreate', with({ name = '  Vinewood <b>Événements</b> ' }))
check(r and r.ok and r.id == 1, 'Alice crée « Vinewood Événements » · ' .. tostring(r and (r.message or r.error)))
local D1 = Ent.shops[1]
check(D1 and D1.name == 'Vinewood Événements', 'nom nettoyé (balises retirées, espaces) : ' .. tostring(D1 and D1.name))
check(players[1].money.bank == 5000, 'payé 25 000 $ depuis la banque (reste 5 000 $)')
check(players[1].job.name == 'ent_1' and players[1].job.grade.level == 4, 'Alice : métier ent_1, grade le plus haut (Patron)')
check(JOBS.ent_1 and JOBS.ent_1.grades[4].name == 'Patron' and JOBS.ent_1.grades[1].name == 'Employé' and JOBS.ent_1.type == 'business', 'métier ent_1 déclaré dans le core (4 grades)')
check(SOC.ent_1 == 0, 'compte de société ent_1 créé')
local st = players[1].state.ent
check(st and st.shop == 1 and st.grade == 'Patron' and st.owner and st.perms.recruit and st.perms.payroll and st.logo == LOGO, 'état publié (statebag « ent ») : patron, permissions, logo')
local row = MySQL.single.await('SELECT * FROM `ent_companies` WHERE `id` = 1')
check(row and row.owner_cid == 'ALICE' and row.specialty == 'evenementiel' and row.logo == LOGO and row.price_paid == 25000 and row.job == 'ent_1', 'entreprise enregistrée en base')
check(tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `ent_grades` WHERE `shop_id` = 1')) == 4, '4 grades en base')
m = aura(1, 'entMine')
check(m.state == 'member' and m.canProfile and m.owner and m.company.name == D1.name, 'onglet « Lancer mon Business » → « Mon business » (vitrine modifiable)')
r = aura(1, 'entCreate', with({ name = 'Autre Boîte' }))
check(r and not r.ok and r.error:find('déjà'), 'une seule entreprise par personnage')

r = aura(2, 'entCreate', with({ name = 'Blackwood Sécurité', specialty = 'securite', description = 'Agents de sécurité pour vos événements, 24 h/24.' }))
check(r and not r.ok and r.needLeave == 'LSPD', 'Bob (policier) : doit confirmer qu\'il quitte la police')
check(players[2].money.bank == 100000, 'pas payé avant confirmation')
r = aura(2, 'entCreate', with({ name = 'Blackwood Sécurité', specialty = 'securite', description = 'Agents de sécurité pour vos événements, 24 h/24.', leaveJob = true }))
check(r and r.ok and players[2].job.name == 'ent_2', 'Bob confirme : entreprise créée, il quitte la police')
r = aura(3, 'entCreate', with({ name = 'Petit Commerce', specialty = 'commerce' }))
check(r and not r.ok and r.error:find('25000') and players[3].money.bank == 1000, 'Carl (1 000 $) : fonds insuffisants, rien de retiré')
r = aura(3, 'entCreate', with({ name = 'VINEWOOD evenements' }))
check(r and not r.ok and r.error:find('déjà'), 'nom déjà pris (casse et accents ignorés) : refusé')

P('\n[Annuaire : appli « Entreprises » + téléphone de service]')
local L = aura(5, 'entList')
check(L and L.ok and #L.list == 2, 'Eve voit les 2 entreprises')
local v1 for _, c in ipairs(L.list) do if c.id == 1 then v1 = c end end
check(v1 and v1.logo == LOGO and v1.specialtyLabel == 'Événementiel' and v1.description == DESC and v1.owner == 'Alice Martin', 'vitrine : logo, spécialité, description (retours à la ligne gardés), fondateur')
check(v1 and v1.number and v1.number:match('^919%-%d%d%d%d$') and v1.open == true and v1.onDuty == 0, 'numéro public 919-XXXX, joignable par défaut, personne en service : ' .. tostring(v1 and v1.number))
local sv = aura(5, 'servicesList')
local inSvc = false for _, b in ipairs(sv.list or {}) do if b.number == v1.number and b.jobLabel == 'Entreprise' then inSvc = true end end
check(inSvc, 'aussi dans l\'appli « Services » (rangée « Entreprise »)')

P('\n[Recrutement]')
r = req(4, 'dashboard')
check(r.error and r.error:find('employés'), 'Dina (pas employée) : tablette refusée')
r = req(1, 'recruitPreview')
check(r.target and r.target.id == 4 and #r.grades == 3, 'Alice : personne la plus proche = Dina, 3 grades proposables (inférieurs au sien)')
r = req(1, 'recruitSend', { target = 4, gradeId = r.defaultGrade })
check(r.ok, 'proposition envoyée')
local offer = lastEv(4, 'ent:client:recruitOffer')
check(offer and offer[1].job == D1.name and offer[1].grade == 'Employé', 'Dina reçoit la proposition (Employé)')
net('elyzea_entreprises', 'ent:server:recruitAnswer', 4, offer[1].id, true)
check(players[4].job.name == 'ent_1' and players[4].job.grade.level == 1 and Ent.employees.DINA, 'Dina accepte : employée de Vinewood (grade 1)')
check(players[4].state.ent and players[4].state.ent.perms.duty and not players[4].state.ent.perms.profile, 'Dina : service oui, vitrine non')
r = aura(4, 'entProfile', { description = 'Je change tout ce texte !' })
check(r and not r.ok and r.error:find('grade'), 'Dina ne peut pas modifier la vitrine')

P('\n[Vitrine]')
r = aura(1, 'entProfile', { description = 'Nouvelle description : mariages et soirées.', color = '#10b981', logo = 'https://i.imgur.com/AbC123.png' })
check(r and r.ok and D1.color == '#10b981' and D1.logo == 'https://i.imgur.com/AbC123.png', 'Alice modifie description, couleur, logo (lien)')
r = aura(1, 'entProfile', { color = 'red' })
check(r and not r.ok, 'couleur invalide : refusée')
check(players[4].state.ent.logo == 'https://i.imgur.com/AbC123.png', 'employés : état mis à jour (nouveau logo)')

P('\n[Logo depuis l\'ordinateur]')
r = aura(1, 'entLogoCode')
check(r and r.ok and #r.code == 6 and r.url == ('http://203.0.113.7:30120/elyzea_entreprises/logo?code=' .. r.code), 'code + lien de la page servie par le serveur : ' .. tostring(r and r.url))
local code = r.code
local hc, hb = httpGet('/logo?code=' .. code)
check(hc == 200 and hb and hb:find('Logo de mon entreprise', 1, true), 'page d\'import servie (GET /logo)')
hc, hb = httpPost('logo/check', { code = 'ZZZZZZ' })
check(hc == 403 and hb and not hb.ok, 'mauvais code : refusé (403)')
hc, hb = httpPost('logo/check', { code = code:lower() })
check(hc == 200 and hb.ok and hb.maxMb == 5, 'bon code (minuscules acceptées)')
hc, hb = httpPost('logo/start', { code = code, size = 9 * 1024 * 1024, type = 'image/png' })
check(hc == 400 and hb.error:find('lourde'), 'image de 9 Mo : refusée')
hc, hb = httpPost('logo/start', { code = code, size = 1000, type = 'application/x-msdownload' })
check(hc == 400 and hb.error:find('image'), 'fichier qui n\'est pas une image : refusé')
hc, hb = httpPost('logo/start', { code = code, size = 120000, type = 'image/png' })
check(hc == 200 and hb.uploadUrl:find('fivemanage', 1, true), 'lien d\'envoi à usage unique donné par l\'hébergeur de l\'appareil photo')
hc, hb = httpPost('logo/finish', { code = code, url = 'https://evil.example.com/x.png' })
check(hc == 400, 'lien d\'un autre site : refusé')
check(aura(1, 'entLogoPending').url == nil, 'rien en attente sur le téléphone')
hc, hb = httpPost('logo/finish', { code = code, url = 'https://r2.fivemanage.com/u/logo_pc.png' })
check(hc == 200 and hb.ok, 'image envoyée : lien accepté')
check(aura(1, 'entLogoPending').url == 'https://r2.fivemanage.com/u/logo_pc.png', 'le téléphone d\'Alice reçoit le logo')
check(noteHas(1, 'Logo reçu'), 'notification « Logo reçu »')
check(aura(4, 'entLogoPending').url == nil, 'pas chez les autres joueurs')
r = aura(1, 'entProfile', { logo = 'https://r2.fivemanage.com/u/logo_pc.png' })
check(r and r.ok and D1.logo == 'https://r2.fivemanage.com/u/logo_pc.png' and aura(1, 'entLogoPending').url == nil, 'logo enregistré sur la vitrine (attente vidée)')
for i = 1, 9 do httpPost('logo/check', { code = 'BAD00' .. i }) end
hc = httpPost('logo/check', { code = code })
check(hc == 429, 'trop de mauvais codes depuis la même adresse : bloqué (429)')

P('\n[Service, téléphone de service, appels et messages des clients]')
r = req(4, 'duty', { on = true })
check(r.ok and Ent.OnDuty(4) and players[4].job.onduty, 'Dina prend son service')
local me = call(function() return J.JP.Me(4) end)
check(me and me.res == 'elyzea_entreprises' and me.unit == 'elyzea_entreprises:1' and me.unitLabel == D1.name and me.tablet, 'téléphone de service de Dina : entreprise Vinewood, tablette autorisée')
L = aura(5, 'entList')
for _, c in ipairs(L.list) do if c.id == 1 then v1 = c end end
check(v1.onDuty == 1 and L.list[1].id == 1, 'appli Entreprises : 1 en service, entreprise en service affichée en premier')
clearEv()
r = aura(5, 'startCall', { number = v1.number })
check(r and r.ok, 'Eve appelle Vinewood depuis l\'appli')
local ring4, ring1 = lastEv(4, 'elyzea_jobphone:client:call'), lastEv(1, 'elyzea_jobphone:client:call')
check(ring4 and ring4[1].state == 'incoming' and ring4[1].business == D1.name, 'ça sonne sur le téléphone de service de Dina (en service)')
check(ring1 == nil, 'Alice (hors service) : ne sonne pas')
r = req(1, 'duty', { on = true })
r = aura(5, 'endCall', { id = r and r.id })
clearEv()
r = aura(5, 'startCall', { number = v1.number })
local auraId = r.id
ring4, ring1 = lastEv(4, 'elyzea_jobphone:client:call'), lastEv(1, 'elyzea_jobphone:client:call')
check(ring4 and ring1 and ring4[1].state == 'incoming' and ring1[1].state == 'incoming', 'Alice aussi en service : ça sonne chez les deux')
r = jp(1, 'answer', { id = ring1[1].id })
check(r.ok, 'Alice décroche la première')
local endD = lastEv(4, 'elyzea_jobphone:client:call')
check(endD and endD[1].state == 'ended', 'la sonnerie s\'arrête chez Dina (« décroché par un collègue »)')
check(jp(4, 'answer', { id = ring4[1].id }).error ~= nil, 'Dina ne peut plus décrocher')
aura(5, 'endCall', { id = auraId })
clearEv()
r = aura(5, 'sendMessage', { number = v1.number, message = 'Bonjour, dispo samedi pour un mariage ?' })
check(r and r.ok, 'Eve envoie un message à Vinewood')
check(#ev(4, 'elyzea_jobphone:client:bizMessage') == 1 and #ev(1, 'elyzea_jobphone:client:bizMessage') == 1, 'message reçu sur le téléphone de service des employés en service')
local v2 for _, c in ipairs(aura(5, 'entList').list) do if c.id == 2 then v2 = c end end
r = aura(5, 'startCall', { number = v2.number })
check(r and not r.ok and (r.error or ''):find('Personne'), 'Blackwood (personne en service) : « laissez-lui un message »')

P('\n[Finances : dépôt, retrait, salaires]')
r = req(4, 'deposit', { amount = 100 })
check(r.error and r.error:find('grade'), 'Dina (Employé) : dépôt refusé (permission)')
r = req(1, 'deposit', { amount = 3000, reason = 'Capital' })
check(r.ok and SOC.ent_1 == 3000 and players[1].money.bank == 2000, 'Alice dépose 3 000 $ (banque 5 000 → 2 000)')
r = req(1, 'deposit', { amount = 999999 })
check(r.error and SOC.ent_1 == 3000, 'dépôt plus grand que la banque : refusé')
local emp = Ent.SortedGrades(1)[1]
r = req(1, 'financeRate', { id = emp.id, rate = 600 })
check(r.ok and emp.salary == 600, 'taux de l\'Employé : 600 $/h')
run(3600 * 1000)
r = req(1, 'finance')
local due = 0 for _, e in ipairs(r.employees or {}) do if e.cid == 'DINA' then due = e.due end end
check(due >= 590 and due <= 610, ('1 h de service de Dina : %d $ dus'):format(due))
r = req(1, 'financePay', { cid = 'DINA' })
check(r.ok and players[4].money.bank >= 200 + 590 and SOC.ent_1 <= 3000 - 590, 'salaire payé depuis le compte de l\'entreprise vers la banque de Dina')
r = req(1, 'withdraw', { amount = 500 })
check(r.ok and players[1].money.bank == 2500, 'Alice retire 500 $ vers sa banque')
r = req(1, 'transactions')
local cats = {} for _, x in ipairs(r.list or {}) do cats[x.category] = true end
check(cats.deposit and cats.withdraw and cats.salary, 'journal : dépôt, retrait, salaire')
r = req(1, 'dashboard')
check(r.company and r.company.name == D1.name and r.employees == 2 and r.balance == SOC.ent_1 and r.isOwner, 'tableau de bord : vitrine, 2 employés, solde, fondateur')

P('\n[Modération staff]')
check((adm(5, 'list').error or ''):find('staff'), 'joueur normal : refusé')
r = adm(6, 'list')
check(r.list and #r.list == 2, 'staff : 2 entreprises')
check((adm(6, 'toggle', { id = 2, enabled = false }).error or ''):find('motif'), 'suspension sans motif : refusée')
r = adm(6, 'toggle', { id = 2, enabled = false, reason = 'Nom à revoir' })
check(r.ok and not Ent.shops[2].enabled, 'Blackwood suspendue')
check(#aura(5, 'entList').list == 1, 'entreprise suspendue : retirée de l\'appli Entreprises')
check((req(2, 'dashboard').error or ''):find('suspendue'), 'patron : tablette indique la suspension')
check(noteHas(2, 'Nom à revoir'), 'patron prévenu du motif')
r = adm(6, 'clear', { id = 1, logo = true })
check(r.ok and D1.logo == '', 'staff retire le logo de Vinewood')
adm(6, 'toggle', { id = 2, enabled = true })
check(#aura(5, 'entList').list == 2, 'réactivée : de retour dans l\'appli')

P('\n[Démission, dissolution]')
r = req(1, 'dissolve', { confirm = 'mauvais nom' })
check(r.error and r.error:find('nom'), 'dissolution : nom à retaper exactement')
check((req(4, 'dissolve', { confirm = D1.name }).error or ''):find('fondateur'), 'Dina (pas fondatrice) : dissolution refusée')
local bal = SOC.ent_1
local bankBefore = players[1].money.bank
r = req(1, 'dissolve', { confirm = D1.name:lower() })
check(r.error and r.unpaid and r.unpaid > 0, ('salaire en cours non payé (%s $) : il faut confirmer l\'abandon'):format(tostring(r.unpaid)))
bal = SOC.ent_1
r = req(1, 'dissolve', { confirm = D1.name:lower(), dropUnpaid = true })
check(r.ok, 'Alice confirme et dissout Vinewood · ' .. tostring(r.message or r.error))
check(players[1].money.bank == bankBefore + bal and SOC.ent_1 == 0, ('solde %d $ versé sur la banque d\'Alice'):format(bal))
check(players[4].job.name == 'unemployed' and players[1].job.name == 'unemployed' and not Ent.employees.DINA, 'Alice et Dina perdent le métier')
check(JOBS.ent_1 == nil and Ent.shops[1].deleted, 'métier ent_1 retiré du core, entreprise marquée dissoute')
check(#aura(5, 'entList').list == 1, 'disparue de l\'appli Entreprises')
m = aura(1, 'entMine')
check(m.state == 'none' and not m.canCreate and (m.reason or ''):find('attendez'), 'recréer tout de suite : délai de 30 min')

P('\n[Erreurs Lua]')
check(#errors == 0, ('aucune erreur Lua (%d)'):format(#errors))

-- Redémarrage : nouvel état d'elyzea_entreprises, même base
P('\n[Redémarrage]')
local E2 = makeEnv('elyzea_entreprises')
for _, f in ipairs(ENTFILES) do loadInto(E2, ROOT, f) end
run(3000)
local D2 = E2.Ent.shops[2]
check(E2.Ent.ready and D2 and D2.name == 'Blackwood Sécurité' and D2.enabled and E2.Ent.employees.BOB and E2.Ent.shops[1].deleted, 'après redémarrage : Blackwood et son patron rechargés, Vinewood reste dissoute')
check(JOBS.ent_2 and JOBS.ent_2.grades[4], 'métier ent_2 redéclaré au démarrage')
check(#errors == 0, 'aucune erreur Lua après redémarrage')
return fails
