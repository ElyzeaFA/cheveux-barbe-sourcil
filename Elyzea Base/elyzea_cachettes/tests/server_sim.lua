-- =====================================================================
--  Simulation serveur hors jeu : VRAI elyzea_inventory + elyzea_cachettes, base MySQL simulée.
--  Lancer : python3 tests/run_server_sim.py   (pip install lupa)
--  Couvre : installation, essais et suspicion, capacités indépendantes, transferts, objets interdits,
--  verrous (deux joueurs), anti-duplication, police (inspection, fouille, saisie), redémarrage,
--  vente / changement de plaque, motos, menu admin.
-- =====================================================================
local BASE = BASE   -- dossier « Elyzea Base » (fourni par le lanceur)
local fails, passes = 0, 0
local function check(c, l) if c then passes = passes + 1 print('  ok   ' .. l) else fails = fails + 1 print('  ÉCHEC ' .. l) end end
local function section(t) print('\n[' .. t .. ']') end

-- ---------------------------------------------------------------- JSON minimal
json = {}
do
    local function enc(v, out)
        local t = type(v)
        if t == 'nil' then out[#out + 1] = 'null'
        elseif t == 'boolean' then out[#out + 1] = tostring(v)
        elseif t == 'number' then out[#out + 1] = (math.type(v) == 'integer' or v ~= math.floor(v)) and tostring(v) or string.format('%d', v)
        elseif t == 'string' then out[#out + 1] = '"' .. v:gsub('[%c"\\]', function(c) return string.format('\\u%04x', c:byte()) end) .. '"'
        elseif t == 'table' then
            local n = #v
            local isArr = n > 0 or next(v) == nil
            if isArr then for k in pairs(v) do if type(k) ~= 'number' then isArr = false break end end end
            if isArr then
                out[#out + 1] = '['
                for i = 1, n do if i > 1 then out[#out + 1] = ',' end enc(v[i], out) end
                out[#out + 1] = ']'
            else
                out[#out + 1] = '{'
                local first = true
                for k, x in pairs(v) do
                    if not first then out[#out + 1] = ',' end first = false
                    enc(tostring(k), out) out[#out + 1] = ':' enc(x, out)
                end
                out[#out + 1] = '}'
            end
        else out[#out + 1] = 'null' end
    end
    function json.encode(v) local o = {} enc(v, o) return table.concat(o) end
    function json.decode(s)
        if type(s) ~= 'string' then error('json') end
        local i = 1
        local function ws() i = s:find('[^ \t\r\n]', i) or #s + 1 end
        local val
        local function str()
            i = i + 1 local o = {}
            while true do
                local c = s:sub(i, i)
                if c == '"' then i = i + 1 break end
                if c == '\\' then
                    local n = s:sub(i + 1, i + 1)
                    if n == 'u' then o[#o + 1] = utf8.char(tonumber(s:sub(i + 2, i + 5), 16)) i = i + 6
                    else o[#o + 1] = ({ n = '\n', t = '\t', r = '\r', b = '\b', f = '\f' })[n] or n i = i + 2 end
                elseif c == '' then error('json') else o[#o + 1] = c i = i + 1 end
            end
            return table.concat(o)
        end
        function val()
            ws()
            local c = s:sub(i, i)
            if c == '{' then
                i = i + 1 local t = {} ws()
                if s:sub(i, i) == '}' then i = i + 1 return t end
                while true do ws() local k = str() ws() i = i + 1 t[k] = val() ws() local d = s:sub(i, i) i = i + 1 if d == '}' then break end end
                return t
            elseif c == '[' then
                i = i + 1 local t = {} ws()
                if s:sub(i, i) == ']' then i = i + 1 return t end
                while true do t[#t + 1] = val() ws() local d = s:sub(i, i) i = i + 1 if d == ']' then break end end
                return t
            elseif c == '"' then return str()
            elseif s:sub(i, i + 3) == 'true' then i = i + 4 return true
            elseif s:sub(i, i + 4) == 'false' then i = i + 5 return false
            elseif s:sub(i, i + 3) == 'null' then i = i + 4 return nil
            else local num = s:match('^-?%d+%.?%d*[eE]?[-+]?%d*', i) if not num or num == '' then error('json') end i = i + #num return math.tointeger(tonumber(num)) or tonumber(num) end
        end
        return val()
    end
end

-- ---------------------------------------------------------------- vecteurs
local V = {} V.__index = V
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end
vec3 = vector3
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
V.__len = function(a) return math.sqrt(a.x ^ 2 + a.y ^ 2 + a.z ^ 2) end

-- ---------------------------------------------------------------- monde simulé
NOW = 100000
function GetGameTimer() return NOW end
local function advance(ms) NOW = NOW + ms end
local PLAYERS = {
    [1] = { cid = 'CRIM', pos = vector3(0, 1, 0) },
    [2] = { cid = 'COP', pos = vector3(0, -1, 0), cop = true },
    [3] = { cid = 'THIEF', pos = vector3(1, 1, 0) },
    [4] = { cid = 'BUYER', pos = vector3(-1, 1, 0) },
}
local VEH = {   -- [netId = entité]
    [501] = { plate = 'ELY 42', pos = vector3(0, 0, 0), lock = 1, vtype = 'automobile', model = 'baller', seats = {} },
    [502] = { plate = 'MOTO 1', pos = vector3(3, 0, 0), lock = 1, vtype = 'bike', model = 'faggio', seats = {} },
    [503] = { plate = 'PNJ 77', pos = vector3(-3, 0, 0), lock = 1, vtype = 'automobile', model = 'blista', seats = {} },
    [504] = { plate = 'POL 01', pos = vector3(0, 3, 0), lock = 1, vtype = 'automobile', model = 'police', seats = {} },
}
function GetPlayers() local o = {} for s in pairs(PLAYERS) do o[#o + 1] = tostring(s) end return o end
function GetPlayerName(s) return PLAYERS[tonumber(s)] and ('Joueur' .. s) or nil end
function GetPlayerPed(s) return PLAYERS[tonumber(s)] and -tonumber(s) or 0 end
function GetEntityCoords(e) if e < 0 then return PLAYERS[-e].pos end return VEH[e].pos end
function NetworkGetEntityFromNetworkId(n) return VEH[n] and n or 0 end
function DoesEntityExist(e) return VEH[e] ~= nil end
function GetEntityType(e) return VEH[e] and 2 or 1 end
function GetVehicleNumberPlateText(e) return VEH[e].plate end
function GetVehicleDoorLockStatus(e) return VEH[e].lock end
function GetVehicleType(e) return VEH[e].vtype end
function GetHashKey(n) local h = 0 for i = 1, #n do h = (h * 31 + n:lower():byte(i)) % 4294967296 end return h end
function GetEntityModel(e) return GetHashKey(VEH[e].model) end
function GetPedInVehicleSeat(e, seat) return VEH[e].seats[seat] or 0 end
local STATE = {}
function Player(s) STATE[s] = STATE[s] or { state = {} } return STATE[s] end
GlobalState = {}
local KVP = {}
function GetResourceKvpString(k) return KVP[k] end
function GetResourceKvpInt(k) return tonumber(KVP[k]) or 0 end
function SetResourceKvp(k, v) KVP[k] = v end
function DeleteResourceKvp(k) KVP[k] = nil end
function IsDuplicityVersion() return true end
function GetNumResources() return 0 end
function GetResourceByFindIndex() return nil end
function RegisterCommand() end
function SetTimeout(_, fn) end
function GetCurrentResourceName() return CURRENT_RES or 'test' end
function LoadResourceFile(res, path)
    local f = io.open(BASE .. '/' .. res .. '/' .. path) if not f then return nil end
    local s = f:read('a') f:close()
    return hashTicks(s)
end
-- Les hachages FiveM `nom` (hors des chaînes de texte) deviennent des nombres ; les `colonnes` SQL restent intactes
function hashTicks(src)
    local out, i, n = {}, 1, #src
    while i <= n do
        local c = src:sub(i, i)
        local two = src:sub(i, i + 1)
        if two == '--' then
            local lvl = src:match('^%-%-%[(=*)%[', i)
            local j = lvl and select(2, src:find('%]' .. lvl .. '%]', i)) or (src:find('\n', i) or n)
            out[#out + 1] = src:sub(i, j) i = j + 1
        elseif c == '[' and src:match('^%[=*%[', i) then
            local lvl = src:match('^%[(=*)%[', i)
            local _, j = src:find('%]' .. lvl .. '%]', i)
            out[#out + 1] = src:sub(i, j) i = j + 1
        elseif c == '"' or c == "'" then
            local j = i + 1
            while j <= n do local d = src:sub(j, j) if d == '\\' then j = j + 2 elseif d == c then break else j = j + 1 end end
            out[#out + 1] = src:sub(i, j) i = j + 1
        elseif c == '`' then
            local j = src:find('`', i + 1, true)
            out[#out + 1] = tostring(GetHashKey(src:sub(i + 1, j - 1))) i = j + 1
        else out[#out + 1] = c i = i + 1 end
    end
    return table.concat(out)
end
local STARTED = { elyzea_core = true, elyzea_inventory = true, elyzea_police = true, elyzea_cachettes = true }
function GetResourceState(r) return STARTED[r] and 'started' or 'missing' end
-- Ordonnanceur : chaque fil s'exécute jusqu'à son Wait ; tick() fait avancer tous les fils d'un pas
local THREADS = {}
function Wait() coroutine.yield() end
function CreateThread(fn) local co = coroutine.create(fn) local ok, e = coroutine.resume(co) if not ok then error(e) end if coroutine.status(co) ~= 'dead' then THREADS[#THREADS + 1] = co end end
local function tick()
    local list = THREADS THREADS = {}
    for _, co in ipairs(list) do
        local ok, e = coroutine.resume(co)
        if not ok then error(e) end
        if coroutine.status(co) ~= 'dead' then THREADS[#THREADS + 1] = co end
    end
end
Citizen = { CreateThread = CreateThread, Wait = Wait }

-- ---------------------------------------------------------------- évènements, exports
local HANDLERS, SENT, NOTES = {}, {}, {}
function AddEventHandler(n, fn) HANDLERS[n] = HANDLERS[n] or {} table.insert(HANDLERS[n], fn) end
function RegisterNetEvent(n, fn) if fn then AddEventHandler(n, fn) end end
function TriggerEvent(n, ...) for _, fn in ipairs(HANDLERS[n] or {}) do fn(...) end end
function TriggerClientEvent(n, s, ...) SENT[#SENT + 1] = { n = n, s = s, args = { ... } } end
local function fire(n, src, ...) source = src for _, fn in ipairs(HANDLERS[n] or {}) do fn(...) end end
local REG = {}
local KEYS = {}
local function hasKeysDb(src, veh)
    local plate = VEH[veh] and VEH[veh].plate
    if KEYS[src] and KEYS[src][plate] then return true end
    for _, r in ipairs(DB.player_vehicles) do if r.plate == plate and r.citizenid == PLAYERS[src].cid then return true end end
    return false
end
REG.elyzea_core = {
    GetCitizenId = function(s) return PLAYERS[s] and PLAYERS[s].cid end,
    Notify = function(s, text, kind, dur, title) NOTES[#NOTES + 1] = { s = s, text = text, kind = kind, title = title } end,
    HasKeys = function(s, veh) return hasKeysDb(s, veh) end,
    GetPlayerData = function(s) return { job = { name = 'x', grade = { level = 0 } } } end,
    GetMoney = function() return 0 end,
}
local COP_PERMS = { veh_inspect = true, veh_cachettes = true }
REG.elyzea_police = {
    IsOnDuty = function(s) return PLAYERS[s] and PLAYERS[s].cop == true end,
    HasPermission = function(s, p) return PLAYERS[s] and PLAYERS[s].cop == true and COP_PERMS[p] == true end,
}
local function makeExports(res)
    REG[res] = REG[res] or {}
    return setmetatable({}, {
        __call = function(_, name, fn) REG[res][name] = fn end,
        __index = function(_, other)
            return setmetatable({}, { __index = function(_, fname)
                return function(self, ...)
                    local f = REG[other] and REG[other][fname]
                    if not f then error(('No such export %s in resource %s'):format(fname, other), 2) end
                    return f(...)
                end
            end })
        end,
    })
end

-- ---------------------------------------------------------------- base MySQL simulée
DB = { players = {}, player_vehicles = {}, elyzea_stashes = {}, cach = {}, log = {} }
DB.player_vehicles = {
    { id = 7, plate = 'ELY 42', citizenid = 'CRIM', vehicle = 'baller' },
    { id = 8, plate = 'MOTO 1', citizenid = 'CRIM', vehicle = 'faggio' },
    { id = 9, plate = 'POL 01', citizenid = 'CRIM', vehicle = 'police' },
}
local function vehByPlate(p) for _, r in ipairs(DB.player_vehicles) do if r.plate == p or r.plate == ' ' .. p then return r end end end
local function cachKey(v, s) return v .. '|' .. s end
local function q(sql, p, mode)
    p = p or {}
    sql = sql:gsub('%s+', ' ')
    if sql:find('CREATE TABLE') then return {} end
    if sql:find('information_schema') then return 0 end
    if sql:find('FROM `players`') then return DB.players[p[1]] end
    if sql:find('UPDATE `players`') then DB.players[p[2]] = p[1] return 1 end
    if sql:find('SELECT `items` FROM `elyzea_stashes`') then local v = DB.elyzea_stashes[p[1]] return v and { items = v } or nil end
    if sql:find('INSERT INTO `elyzea_stashes`') then DB.elyzea_stashes[p[1]] = p[2] return 1 end
    if sql:find('SELECT COUNT%(%*%) FROM `elyzea_stashes`') then return DB.elyzea_stashes[p[1]] and 1 or 0 end
    if sql:find('UPDATE `elyzea_stashes` SET `id`') then DB.elyzea_stashes[p[1]] = DB.elyzea_stashes[p[2]] DB.elyzea_stashes[p[2]] = nil return 1 end
    if sql:find('SELECT `id` FROM `player_vehicles`') then local r = vehByPlate(p[1]) return r and r.id end
    if sql:find('SELECT `id`, `citizenid`, `vehicle` FROM `player_vehicles`') then return vehByPlate(p[1]) end
    if sql:find('SELECT %* FROM `elyzea_cachettes`') then
        local out = {} for _, r in pairs(DB.cach) do if r.vehicle_id == p[1] then out[#out + 1] = r end end return out
    end
    if sql:find('INSERT INTO `elyzea_cachettes`') then
        local k = cachKey(p[1], p[2]) local old = DB.cach[k] or {}
        DB.cach[k] = { vehicle_id = p[1], slot = p[2], state = p[3], attempts = p[4], suspicion = p[5], capacity = p[6], category = p[7],
            installed_by = p[8] or old.installed_by, installed_at = p[9] or old.installed_at, discovered = old.discovered or 0 }
        return 1
    end
    if sql:find('SET `discovered` = 1') then local r = DB.cach[cachKey(p[1], p[2])] if r then r.discovered = 1 end return 1 end
    if sql:find('SET `opened_at`') then return 1 end
    if sql:find('UPDATE `elyzea_cachettes` SET `vehicle_id`') then
        local moved = {} for k, r in pairs(DB.cach) do if r.vehicle_id == p[2] then moved[#moved + 1] = k end end
        for _, k in ipairs(moved) do local r = DB.cach[k] DB.cach[k] = nil r.vehicle_id = p[1] DB.cach[cachKey(p[1], r.slot)] = r end return 1
    end
    if sql:find('DELETE FROM `elyzea_cachettes`') then DB.cach[cachKey(p[1], p[2])] = nil return 1 end
    if sql:find('COUNT%(%*%) FROM `elyzea_cachettes`') then local n = 0 for _, r in pairs(DB.cach) do if r.state == 1 then n = n + 1 end end return n end
    if sql:find('INSERT INTO `elyzea_cachettes_log`') then DB.log[#DB.log + 1] = { veh = p[1], slot = p[2], action = p[3], cid = p[4], detail = p[5] } return #DB.log end
    error('SQL non simulé : ' .. sql)
end
local function api(mode) return setmetatable({ await = function(sql, p) return q(sql, p, mode) end }, { __call = function(_, sql, p, cb) local r = q(sql, p, mode) if type(cb) == 'function' then cb(r) end return r end }) end
MySQL = { query = api('query'), scalar = api('scalar'), single = api('single'), update = api('update'), insert = api('insert') }

-- ---------------------------------------------------------------- Ely (callbacks)
local CB = {}
Ely = { callback = { register = function(name, fn) CB[name] = fn end } }
local function call(name, src, ...) return CB[name](src, ...) end

-- ---------------------------------------------------------------- démarrage du « serveur »
local function runFile(res, path, env)
    local f = assert(io.open(BASE .. '/' .. res .. '/' .. path), path)
    local src = f:read('a') f:close()
    src = hashTicks(src)
    CURRENT_RES = res
    assert(load(src, '@' .. res .. '/' .. path, 't', env))()
end
local INV, CACH
local function boot()
    HANDLERS, CB, SENT, THREADS = {}, {}, {}, {}
    REG.elyzea_inventory, REG.elyzea_cachettes = {}, {}
    INV = setmetatable({ exports = makeExports('elyzea_inventory') }, { __index = _G })
    INV._G = INV
    for _, f in ipairs({ 'config.lua', 'shared/items.lua', 'shared/utils.lua', 'shared/import.lua', 'shared/catalog.lua', 'server/main.lua' }) do runFile('elyzea_inventory', f, INV) end
    CACH = setmetatable({ exports = makeExports('elyzea_cachettes') }, { __index = _G })
    CACH._G = CACH
    for _, f in ipairs({ 'config.lua', 'shared/slots.lua', 'server/settings.lua', 'server/main.lua', 'server/admin.lua' }) do runFile('elyzea_cachettes', f, CACH) end
    tick()
    for s in pairs(PLAYERS) do fire('elyzea_inv:ready', s) end
end
local function stopAll()
    CURRENT_RES = 'elyzea_cachettes' TriggerEvent('onResourceStop', 'elyzea_cachettes')
    CURRENT_RES = 'elyzea_inventory' TriggerEvent('onResourceStop', 'elyzea_inventory')
end

local inv = setmetatable({}, { __index = function(_, k) return function(...) return REG.elyzea_inventory[k](...) end end })
local function count(src, name) return inv.GetItemCount(src, name) or 0 end
local function slotOf(src, name) local r = inv.Search(src, 'slots', name) return r and r[1] and r[1].slot end
local function stashCount(id, name)
    local veh, slot = id:match('^cach:(%d+):(.+)$')
    local n = 0 for _, it in ipairs(CACH.Cach.StashItems(tonumber(veh), slot)) do if it.name == name then n = n + it.count end end return n
end
local function action(src, name, data) fire('elyzea_inv:action', src, name, data) end
local function lastToast(src)
    for i = #SENT, 1, -1 do local e = SENT[i] if e.s == src and e.n == 'elyzea_inv:sync' and e.args[2] then return e.args[2].text end end
end
local CAR_SLOTS = { 'door_fl', 'door_fr', 'door_rl', 'door_rr', 'trunk', 'wheel_fl', 'wheel_fr', 'wheel_rl', 'wheel_rr', 'seat_d', 'seat_p', 'seat_rl', 'seat_rr', 'saddle' }
local function menu(src, net, role, class, slots) return call('cach:menu', src, net, role, { class = class, slots = slots or CAR_SLOTS }) end
local function find(list, id) for _, e in ipairs(list or {}) do if e.id == id then return e end end end
-- une opération complète : menu → début → (durée) → fin
local function op(src, net, role, class, slot, result, ms)
    local m = menu(src, net, role, class)
    if m.error then return m end
    local st = call('cach:start', src, slot)
    if st.error then return st, st end
    if result.errors and result.errors > 0 then fire('elyzea_cachettes:progress', src, st.token, result.errors) end
    advance(ms or 70000)
    return call('cach:finish', src, st.token, result), st
end
local function close(src) fire('elyzea_inv:close', src) CACH.Cach.Tick() end

-- =====================================================================
boot()
for s in pairs(PLAYERS) do inv.ClearInventory(s) end   -- kit de départ retiré : poids connus
section('Démarrage')
check(REG.elyzea_inventory.RegisterStashGuard ~= nil and REG.elyzea_inventory.GetViewing ~= nil, 'inventaire : exports RegisterStashGuard et GetViewing présents')
check(CACH.Cach.dbReady == true and GlobalState.cachettes and GlobalState.cachettes.tool == 'tournevis', 'cachettes : tables créées, réglages publiés aux clients')
check(INV.Items.tournevis and INV.Items.tournevis.image == 'screwdriverset.png', 'objet « tournevis » déclaré dans l\'inventaire (avec image)')

section('Tournevis et accès')
local m = menu(1, 501, 'crime', 2)
check(m.error and m.error:find('tournevis'), 'sans tournevis : refusé')
inv.AddItem(1, 'tournevis', 1)
inv.AddItem(3, 'tournevis', 1)
m = menu(3, 501, 'crime', 2)
check(m.error and m.error:find('clés'), 'avec tournevis mais sans les clés du véhicule : refusé')
m = menu(1, 501, 'crime', 2)
check(not m.error and #m.slots == 13, 'SUV : 13 emplacements (4 portières, coffre, 4 roues, 4 sièges) ; pas de selle')
check(find(m.slots, 'door_fl').capacity == 15 and find(m.slots, 'trunk').capacity == 30 and find(m.slots, 'wheel_rr').capacity == 15 and find(m.slots, 'seat_rl').capacity == 15,
    'SUV : 15 kg par portière / roue / siège, 30 kg pour le coffre')
m = menu(1, 501, 'crime', 2, { 'door_fl', 'trunk', 'seat_d', 'seat_p' })
check(#m.slots == 4, 'seuls les emplacements réellement présents sur le modèle sont proposés')
VEH[501].seats[0] = 99
m = menu(1, 501, 'crime', 2)
check(find(m.slots, 'seat_p').disabled == true, 'siège passager occupé : emplacement indisponible')
VEH[501].seats[0] = nil
check(count(1, 'tournevis') == 1, 'le tournevis n\'est pas consommé')

section('Installation : essais et suspicion')
local r = op(1, 501, 'crime', 2, 'door_fr', { success = false, errors = 5 })
check(r.failed and DB.cach['7|door_fr'] and DB.cach['7|door_fr'].attempts == 1 and DB.cach['7|door_fr'].state == 0, 'échec : essai compté et enregistré en base (cachette non installée)')
check(not CACH.Locks['7:door_fr'] and not CACH.Sessions[1], 'échec : verrou et opération libérés')
r = op(1, 501, 'crime', 2, 'door_fr', { success = true }, 10000)
check(r.error and DB.cach['7|door_fr'].state == 0, 'réussite trop rapide (10 s) : refusée par le serveur')
r = op(1, 501, 'crime', 2, 'door_fr', { success = true })
check(r.opened and r.installed and DB.cach['7|door_fr'].state == 1 and DB.cach['7|door_fr'].suspicion == 1, 'réussite au 2e essai : installée, suspicion LÉGÈRE')
local v = inv.GetViewing(1)
check(v and v.id == 'cach:7:door_fr', 'inventaire de la cachette ouvert à côté de celui du joueur')
check(CACH.Locks['7:door_fr'] == 1, 'emplacement verrouillé tant que la cachette est ouverte')

section('Capacité individuelle et transferts')
inv.AddItem(1, 'bank_drill', 5)
for i = 1, 4 do action(1, 'store', { from = slotOf(1, 'bank_drill'), count = 1 }) end
check(stashCount('cach:7:door_fr', 'bank_drill') == 4, '4 perceuses (14 kg) rangées dans la portière')
action(1, 'store', { from = slotOf(1, 'bank_drill'), count = 1 })
check(stashCount('cach:7:door_fr', 'bank_drill') == 4 and count(1, 'bank_drill') == 1, '5e perceuse (17,5 kg > 15 kg) : refusée, rien de perdu')
CACH.Cach.S.blacklist.burger = true
inv.AddItem(1, 'burger', 2)
action(1, 'store', { from = slotOf(1, 'burger'), count = 1 })
check(stashCount('cach:7:door_fr', 'burger') == 0 and lastToast(1) == 'Cet objet ne peut pas être caché ici.', 'objet interdit (réglage) : refusé avec un message')
CACH.Cach.S.blacklist.burger = nil
action(1, 'store', { from = slotOf(1, 'burger'), count = 1 })
check(stashCount('cach:7:door_fr', 'burger') == 1, 'objet autorisé de nouveau : rangé (14,22 kg)')
local items = inv.GetStashItems('cach:7:door_fr')
action(1, 'take', { from = items[1].slot, count = 1 })
check(stashCount('cach:7:door_fr', 'bank_drill') + stashCount('cach:7:door_fr', 'burger') == 4 and count(1, 'bank_drill') + count(1, 'burger') == 3, 'récupération d\'un objet : le total joueur + cachette ne change pas')

section('Deux joueurs sur le même emplacement')
KEYS[4] = { ['ELY 42'] = true }
inv.AddItem(4, 'tournevis', 1)
m = menu(4, 501, 'crime', 2)
check(find(m.slots, 'door_fr').disabled and find(m.slots, 'door_fr').desc:find('travaille'), 'second joueur : emplacement occupé affiché indisponible')
local st = call('cach:start', 4, 'door_fr')
check(st.error, 'second joueur : début refusé')
CACH.Cach.S.access.policeNeedsTool = false
m = menu(2, 501, 'police', 2)
CACH.Cach.S.access.policeNeedsTool = true
check(find(m.slots, 'door_fr').disabled, 'police : emplacement occupé aussi indisponible')

section('Fermeture, verrou libéré, cachette refermée')
close(1)
check(not CACH.Locks['7:door_fr'] and not CACH.Sessions[1], 'inventaire fermé : opération et verrou libérés')
check(DB.elyzea_stashes['cach:7:door_fr'] and DB.elyzea_stashes['cach:7:door_fr']:find('bank_drill'), 'contenu sauvegardé en base à la fermeture')
local before = count(1, 'bank_drill')
INV.Viewing[1] = { kind = 'stash', id = 'cach:7:door_fr' }   -- client tricheur : l'inventaire n'a jamais été refermé
items = inv.GetStashItems('cach:7:door_fr')
action(1, 'take', { from = items[1].slot, count = 1 })
check(count(1, 'bank_drill') == before and stashCount('cach:7:door_fr', 'bank_drill') == 3, 'cachette refermée : plus aucun retrait possible (anti-duplication)')
fire('elyzea_inv:openContainer', 1, 'stash', 'cach:7:door_fr')
check(INV.Viewing[1] == nil or INV.Viewing[1].id ~= 'cach:7:door_fr' or lastToast(1) == INV.Config.Messages.no_access, 'ouverture directe par le client (sans mini-jeu) : refusée')
INV.Viewing[1] = nil

section('Autres emplacements : indépendants')
r = op(1, 501, 'crime', 2, 'trunk', { success = true })
check(r.installed and DB.cach['7|trunk'].suspicion == 0, 'coffre réussi au 1er essai : AUCUNE suspicion')
local doorBurgers = stashCount('cach:7:door_fr', 'burger')
if count(1, 'burger') == 0 then inv.AddItem(1, 'burger', 1) end
action(1, 'store', { from = slotOf(1, 'burger'), count = 1 })
check(stashCount('cach:7:trunk', 'burger') == 1 and stashCount('cach:7:door_fr', 'burger') == doorBurgers, 'chaque cachette a son propre inventaire (rien ne passe d\'une portière au coffre)')
close(1)
r = menu(1, 501, 'crime', 2)
check(find(r.slots, 'door_fr').status == 'installed' and find(r.slots, 'trunk').status == 'installed' and find(r.slots, 'door_fl').status == 'free', 'menu : cachettes installées affichées « Ouvrir », pas de seconde installation')
for i = 1, 3 do op(1, 501, 'crime', 2, 'wheel_rl', { success = false, errors = 5 }) end
r = op(1, 501, 'crime', 2, 'wheel_rl', { success = true })
close(1)
check(r.installed and DB.cach['7|wheel_rl'].suspicion == 2 and DB.cach['7|wheel_rl'].attempts == 3, 'roue réussie au 4e essai : suspicion ÉLEVÉE')
check(DB.cach['7|door_fr'].suspicion == 1 and DB.cach['7|trunk'].suspicion == 0, 'les échecs de la roue ne changent pas la suspicion des autres emplacements')
r = op(1, 501, 'crime', 2, 'door_fr', { success = false, errors = 5 })
check(DB.cach['7|door_fr'].suspicion == 1 and DB.cach['7|door_fr'].attempts == 1, 'échecs à l\'OUVERTURE : la suspicion reste celle de l\'installation')
r = op(1, 501, 'crime', 2, 'door_fr', { success = true })
check(r.opened and not r.installed and stashCount('cach:7:door_fr', 'bank_drill') == 3, 'réouverture : même contenu')
close(1)

section('Annulation et déconnexion')
r = op(1, 501, 'crime', 2, 'seat_d', { cancelled = true, errors = 0 })
check(r.cancelled and not r.counted and DB.cach['7|seat_d'] == nil, 'annulation sans erreur : aucun essai compté')
r = op(1, 501, 'crime', 2, 'seat_d', { cancelled = true, errors = 2 })
check(r.counted and DB.cach['7|seat_d'].attempts == 1, 'annulation après des erreurs : essai raté compté')
m = menu(1, 501, 'crime', 2) st = call('cach:start', 1, 'seat_d')
fire('elyzea_cachettes:progress', 1, st.token, 1)
fire('playerDropped', 1)
check(DB.cach['7|seat_d'].attempts == 2 and not CACH.Locks['7:seat_d'], 'déconnexion en plein mini-jeu après une erreur : essai compté, verrou libéré')
fire('elyzea_inv:ready', 1)

section('Inspection policière')
NOTES = {}
r = call('cach:inspectStart', 1, 501)
check(r.error, 'joueur non policier : inspection refusée')
r = call('cach:inspectStart', 2, 501)
check(r.token and r.duration == 12000, 'policier en service : inspection commencée')
advance(3000)
local f = call('cach:inspectFinish', 2, r.token)
check(f.error and #NOTES == 0, 'inspection écourtée : aucun résultat')
r = call('cach:inspectStart', 2, 501) advance(12500)
f = call('cach:inspectFinish', 2, r.token)
local texts = {} for _, n in ipairs(NOTES) do texts[#texts + 1] = n.text end
check(f.count == 2, 'deux anomalies (portière légère, roue élevée) ; le coffre propre n\'est pas signalé')
check(texts[1] == 'Une petite anomalie semble présente au niveau de la portière avant droite.', 'suspicion légère : « ' .. tostring(texts[1]) .. ' »')
check(texts[2] == 'Il semblerait qu\'une intervention ait été effectuée au niveau du passage de roue arrière gauche.', 'suspicion élevée : « ' .. tostring(texts[2]) .. ' »')
local leak = false for _, t in ipairs(texts) do if t:find('perceuse') or t:find('Perceuse') or t:find('burger') or t:find('Burger') then leak = true end end
check(not leak, 'les notifications ne révèlent jamais le contenu')
NOTES = {}
r = call('cach:inspectStart', 2, 504) advance(12500) f = call('cach:inspectFinish', 2, r.token)
check(f.count == 0 and NOTES[1].text == 'L\'inspection n\'a révélé aucun élément suspect.', 'véhicule sans cachette : « aucun élément suspect »')
NOTES = {}
r = call('cach:inspectStart', 2, 503) advance(12500) f = call('cach:inspectFinish', 2, r.token)
check(f.count == 0 and NOTES[1].text:find('aucun'), 'véhicule non immatriculé : inspection possible, rien de suspect')

section('Fouille policière : même mini-jeu')
m = menu(2, 501, 'police', 2)
check(m.error and m.error:find('tournevis'), 'police sans tournevis (réglage par défaut) : refusé')
inv.AddItem(2, 'tournevis', 1)
m = menu(2, 501, 'police', 2)
local hasStatus = false for _, e in ipairs(m.slots) do if e.status or e.capacity or e.attempts then hasStatus = true end end
check(#m.slots == 13 and not hasStatus, 'police : tous les emplacements proposés, sans révéler où sont les cachettes')
r = op(2, 501, 'police', 2, 'door_fl', { success = true })
check(r.empty and not CACH.Locks['7:door_fl'], 'emplacement sans cachette : « rien n\'est dissimulé », verrou libéré')
r = op(2, 501, 'police', 2, 'trunk', { success = false, errors = 5 })
check(r.failed and DB.cach['7|trunk'].attempts == 0 and DB.cach['7|trunk'].suspicion == 0, 'échec de la police : rien ne change (ni essais, ni suspicion)')
r = op(2, 501, 'police', 2, 'trunk', { success = true }, 20000)
check(r.error, 'police aussi : réussite trop rapide refusée (aucun raccourci)')
r = op(2, 501, 'police', 2, 'trunk', { success = true })
check(r.opened and r.found and DB.cach['7|trunk'].discovered == 1, 'coffre démonté : cachette découverte, inventaire ouvert')
check(DB.cach['7|door_fr'].discovered == 0 and DB.cach['7|wheel_rl'].discovered == 0, 'la découverte du coffre ne révèle pas les autres cachettes')
items = inv.GetStashItems('cach:7:trunk')
action(2, 'take', { from = items[1].slot, count = 1 })
check(count(2, 'burger') == 1 and stashCount('cach:7:trunk', 'burger') == 0, 'saisie : l\'objet passe dans l\'inventaire du policier')
local seized = false for _, l in ipairs(DB.log) do if l.action == 'seize' and l.cid == 'COP' then seized = true end end
check(seized, 'saisie inscrite au journal (elyzea_cachettes_log)')
close(2)
r = op(2, 503, 'police', 0, 'door_fl', { success = true })
check(r.empty, 'véhicule non immatriculé : la police peut démonter, rien n\'est trouvé')

section('Motos et scooters')
m = menu(1, 502, 'crime', 8, { 'saddle', 'door_fl', 'trunk' })
check(#m.slots == 1 and m.slots[1].id == 'saddle' and m.slots[1].capacity == 5, 'moto : seulement le compartiment sous la selle, 5 kg')
r = op(1, 502, 'crime', 8, 'saddle', { success = true })
check(r.installed and DB.cach['8|saddle'].capacity == 5000, 'selle : cachette installée (5 kg)')
inv.AddItem(1, 'bank_drill', 1)
action(1, 'store', { from = slotOf(1, 'bank_drill'), count = 1 })
action(1, 'store', { from = slotOf(1, 'bank_drill'), count = 1 })
check(stashCount('cach:8:saddle', 'bank_drill') == 1, 'selle : 3,5 kg accepté, 7 kg refusé')
close(1)
m = menu(1, 504, 'crime', 18)
check(m.error and m.error:find('ne permet pas'), 'véhicule d\'urgence (catégorie « aucune ») : pas de cachette')
KEYS[1] = { ['PNJ 77'] = true }   -- véhicule volé, clés trouvées
m = menu(1, 503, 'crime', 0)
check(m.error and m.error:find('immatriculé'), 'véhicule non immatriculé : pas d\'installation possible')

section('Redémarrage du serveur')
fire('elyzea_inv:close', 1)
stopAll()
local drillsBefore = stashCount('cach:7:door_fr', 'bank_drill')
boot()
check(stashCount('cach:7:door_fr', 'bank_drill') == drillsBefore and drillsBefore == 3, 'après redémarrage : contenu de la portière identique (3 perceuses)')
check(count(1, 'tournevis') == 1, 'après redémarrage : inventaire du joueur rechargé')
NOTES = {}
inv.AddItem(2, 'tournevis', 0)
r = call('cach:inspectStart', 2, 501) advance(12500) f = call('cach:inspectFinish', 2, r.token)
check(f.count == 2 and NOTES[1].text:find('portière avant droite'), 'après redémarrage : suspicion conservée par emplacement')
m = menu(1, 501, 'crime', 2)
check(find(m.slots, 'door_fr').status == 'installed' and find(m.slots, 'seat_d').attempts == 2, 'après redémarrage : cachettes et essais ratés conservés')

section('Vente et changement de plaque')
for _, row in ipairs(DB.player_vehicles) do if row.id == 7 then row.citizenid = 'BUYER' row.plate = 'NEW 1' end end
VEH[501].plate = 'NEW 1'
KEYS[4] = nil
advance(31000)   -- cache plaque → véhicule (30 s)
m = menu(1, 501, 'crime', 2)
check(m.error and m.error:find('clés'), 'ancien propriétaire : n\'a plus accès')
m = menu(4, 501, 'crime', 2)
check(not m.error and find(m.slots, 'door_fr').status == 'installed', 'nouveau propriétaire, nouvelle plaque : les cachettes suivent le véhicule')
r = op(4, 501, 'crime', 2, 'door_fr', { success = true })
check(r.opened and stashCount('cach:7:door_fr', 'bank_drill') == 3, 'nouveau propriétaire : même contenu')
close(4)

section('Menu admin')
local ad = REG.elyzea_cachettes.AdminData()
check(ad.available and #ad.categories == 4 and #ad.classes == 23 and #ad.games == 5 and ad.installed >= 4, 'AdminData : catégories, classes, mini-jeux, nombre de cachettes')
ad.categories[1].caps.door = 7
ad.games[1].difficulty = 5
ad.models = { { model = 'blista', category = 'large' } }
local ok, msg = REG.elyzea_cachettes.AdminAction(0, 'save', ad)
check(ok and CACH.Cach.S.caps.small.door == 7 and CACH.Cach.S.minigames.door.difficulty == 5 and CACH.Cach.S.modelCategory.blista == 'large', 'enregistrement : capacité, difficulté et exception de modèle appliquées')
check(KVP['elyzea_cachettes:settings'] and KVP['elyzea_cachettes:settings']:find('blista'), 'réglages gardés par la ressource (KVP)')
ad.games[1].difficulty = 99 ad.categories[1].caps.door = -5 ad.inspect.light = 'Sans emplacement'
REG.elyzea_cachettes.AdminAction(0, 'save', ad)
check(CACH.Cach.S.minigames.door.difficulty == 5 and CACH.Cach.S.caps.small.door == 0 and CACH.Cach.S.inspect.light == CACH.Config.Inspect.light, 'valeurs hors limites bornées ; message sans « %s » refusé')
local ok2, _, look = REG.elyzea_cachettes.AdminAction(0, 'lookup', { plate = 'new 1' })
check(ok2 and look.vehicleId == 7 and #look.list >= 4, 'recherche par plaque : cachettes du véhicule listées')
local okd, md = REG.elyzea_cachettes.AdminAction(0, 'delete', { vehicleId = 7, slot = 'door_fr' })
check(not okd and md:find('vidée'), 'suppression d\'une cachette pleine : refusée')
okd = REG.elyzea_cachettes.AdminAction(0, 'delete', { vehicleId = 7, slot = 'trunk' })
check(okd and DB.cach['7|trunk'] == nil, 'suppression d\'une cachette vide : faite')
REG.elyzea_cachettes.AdminAction(0, 'reset', {})
check(CACH.Cach.S.caps.small.door == 5 and KVP['elyzea_cachettes:settings'] == nil, 'valeurs par défaut remises')

section('Transfert d\'identifiant (export)')
local okt = REG.elyzea_cachettes.TransferCachettes(7, 70)
check(okt and DB.cach['70|door_fr'] and stashCount('cach:70:door_fr', 'bank_drill') == 3 and DB.elyzea_stashes['cach:7:door_fr'] == nil, 'TransferCachettes : lignes et contenu déplacés vers le nouvel identifiant')

print(('\n%d ok, %d échec(s)'):format(passes, fails))
return fails
