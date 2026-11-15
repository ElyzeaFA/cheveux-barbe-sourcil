-- Imitation de FiveM pour run_server_sim.py : natives serveur, événements, exports entre ressources,
-- KVP par ressource, base MySQL réelle (passerelle Python), threads (coroutines).
-- Chaque ressource est chargée dans son propre environnement (_ENV), comme dans FiveM.

-- ---------- Vecteurs ----------
local V = {}
V.__index = V
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end
vec3 = vector3
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
V.__len = function(a) return math.sqrt(a.x ^ 2 + a.y ^ 2 + a.z ^ 2) end

-- ---------- Monde ----------
NOW = 100000
PLAYERS = {}          -- [src] = { cid, name, pos }
SENT, NOTES = {}, {}
PERMS = {}            -- [src] = { perm = true }
function GetGameTimer() return NOW end
function GetPlayerPed(s) return PLAYERS[s] and s or 0 end
function GetEntityCoords(ped) return PLAYERS[ped] and PLAYERS[ped].pos or vector3(0, 0, 0) end
function GetPlayerName(s) return PLAYERS[s] and PLAYERS[s].name or nil end
function Player(s) return { state = {} } end
function GetPlayers() local t = {} for s in pairs(PLAYERS) do t[#t + 1] = tostring(s) end return t end
function GetHashKey(n) local h = 0 for i = 1, #n do h = (h * 31 + n:byte(i)) % 4294967296 end return h end
function IsDuplicityVersion() return true end
function GetNumResources() return 0 end
function GetResourceByFindIndex() return nil end
function RegisterCommand() end
local TIMERS = {}
function SetTimeout(ms, fn) TIMERS[#TIMERS + 1] = fn end
function GetResourceState(res)
    if res == 'elyzea_inventory' or res == 'elyzea_core' or res == 'elyzea_lettres' or res == 'admin_menu' then return 'started' end
    return 'missing'
end
function CreateThread(fn) local co = coroutine.create(fn) local ok, err = coroutine.resume(co) if not ok then error(err) end end
Citizen = { CreateThread = CreateThread }
function Wait() if coroutine.isyieldable() then coroutine.yield() end end
function TriggerClientEvent(n, s, ...) SENT[#SENT + 1] = { n = n, s = s, args = { ... } } end

json = { encode = function(t) return py_json_encode(t) end, decode = function(s) if type(s) ~= 'string' or s == '' then return nil end return py_json_decode(s) end }

-- ---------- Base de données (vraie MariaDB) ----------
local function m(fn, await)
    return setmetatable({ await = await or fn }, { __call = function(_, sql, params, cb)
        if type(params) == 'function' then cb, params = params, nil end
        local r = fn(sql, params)
        if cb then cb(r) end
        return r
    end })
end
local function q(sql, p) return py_query(sql, p) end
MySQL = {
    query = m(function(sql, p) local r = q(sql, p) return r end),
    single = m(function(sql, p) return py_single(sql, p) end),
    scalar = m(function(sql, p) return py_scalar(sql, p) end),
    insert = m(function(sql, p) return py_insert(sql, p) end),
    update = m(function(sql, p) return py_update(sql, p) end),
}
-- les requêtes sans résultat (CREATE, UPDATE) passent aussi par query
MySQL.query = m(function(sql, p)
    local s = sql:match('^%s*(%a+)'):upper()
    if s == 'SELECT' or s == 'SHOW' then return q(sql, p) end
    return py_update(sql, p)
end)

-- ---------- Événements et exports ----------
HANDLERS = {}
EXPORTS = {}
local function on(n, fn) HANDLERS[n] = HANDLERS[n] or {} table.insert(HANDLERS[n], fn) end
function FIRE(n, src, ...)
    local prev = source
    source = src
    for _, fn in ipairs(HANDLERS[n] or {}) do fn(...) end
    source = prev
end

local core = {
    GetCitizenId = function(s) return PLAYERS[s] and PLAYERS[s].cid end,
    GetCharName = function(s) return PLAYERS[s] and PLAYERS[s].name end,
    Notify = function(s, text, kind) NOTES[#NOTES + 1] = { s = s, text = text, kind = kind } end,
    GetMoney = function() return 0 end,
    GetPlayerData = function() return { job = { name = 'unemployed', grade = { level = 0 } } } end,
}
local admin = { HasPermission = function(s, p) return PERMS[s] and PERMS[s][p] == true end, AddLog = function() end }

local function proxy(res)
    return setmetatable({}, { __index = function(_, k)
        return function(self, ...)
            local t = res == 'elyzea_core' and core or res == 'admin_menu' and admin or EXPORTS[res]
            local fn = t and t[k]
            if not fn then error(('export %s.%s absent'):format(res, k), 2) end
            return fn(...)
        end
    end })
end

local function env(res)
    local e = setmetatable({}, { __index = _G })
    e.exports = setmetatable({}, {
        __call = function(_, name, fn) EXPORTS[res] = EXPORTS[res] or {} EXPORTS[res][name] = fn end,
        __index = function(_, r) return proxy(r) end,
    })
    e.GetCurrentResourceName = function() return res end
    e.RegisterNetEvent = function(n, fn) if fn then on(n, fn) end end
    e.AddEventHandler = on
    e.TriggerEvent = function(n, ...) for _, fn in ipairs(HANDLERS[n] or {}) do fn(...) end end
    e.GetResourceKvpString = function(k) return py_kvp_get(res, k) end
    e.GetResourceKvpInt = function(k) return tonumber(py_kvp_get(res, k)) or 0 end
    e.SetResourceKvp = function(k, v) py_kvp_set(res, k, v) end
    e.DeleteResourceKvp = function(k) py_kvp_del(res, k) end
    e.LoadResourceFile = function(r, path)
        local s = py_read(r, path)
        return s and hashes(s) or nil
    end
    return e
end

-- `nom` (hash FiveM) → nombre, sauf dans les lignes SQL où les accents graves entourent des noms de colonnes
local SQLWORDS = { 'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'CREATE', 'NULL', 'KEY', 'ENGINE', 'DEFAULT', 'varchar', 'VARCHAR',
    'TEXT', 'longtext', 'timestamp', 'DATETIME', 'TINYINT', 'FROM', 'WHERE', 'COUNT', 'SUM(' }
function hashes(src)   -- globale : utilisée aussi par LoadResourceFile (plus haut)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        local sql = false
        for _, w in ipairs(SQLWORDS) do if line:find(w, 1, true) then sql = true break end end
        out[#out + 1] = sql and line or line:gsub('`([%w_]+)`', function(n) return tostring(GetHashKey(n)) end)
    end
    return table.concat(out, '\n')
end
HASHES = hashes

local function run(e, res, path)
    local src = assert(py_read(res, path), res .. '/' .. path)
    assert(load(hashes(src), '@' .. res .. '/' .. path, 't', e))()
end

-- (Re)démarrage : environnements neufs, gestionnaires et exports vidés (la base et les KVP restent)
function BOOT()
    HANDLERS, EXPORTS = {}, {}
    INV = env('elyzea_inventory')
    for _, f in ipairs({ 'config.lua', 'shared/items.lua', 'shared/utils.lua', 'shared/import.lua', 'shared/catalog.lua', 'server/main.lua' }) do run(INV, 'elyzea_inventory', f) end
    LET = env('elyzea_lettres')
    for _, f in ipairs({ 'config.lua', 'shared/text.lua', 'server/main.lua', 'server/admin.lua' }) do run(LET, 'elyzea_lettres', f) end
end

function RUN_SCENARIO(src)
    local fn = assert(load(src, '@tests/server_sim.lua'))
    return fn()
end
