-- =====================================================================
--  ELYZEA CACHETTES - réglages (serveur)
--  Valeurs de config.lua, remplacées par celles enregistrées en jeu (menu admin, KVP).
--  Chaque valeur reçue du menu est revalidée ici (bornes, types).
-- =====================================================================
Cach = Cach or {}
local KVP = 'elyzea_cachettes:settings'

local function copy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = copy(v) end
    return o
end
local function num(v, min, max, def)
    v = tonumber(v)
    if not v or v ~= v then return def end
    if v < min then v = min elseif v > max then v = max end
    return v
end
local function str(v, maxLen, def)
    if type(v) ~= 'string' then return def end
    v = v:gsub('[%c]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if v == '' then return def end
    return v:sub(1, maxLen)
end

local CAT_SET = { none = true }
for _, k in ipairs(Config.CategoryOrder) do CAT_SET[k] = true end
local TYPES = { 'door', 'trunk', 'wheel', 'seat', 'saddle' }

function Cach.Defaults()
    local d = {
        access = copy(Config.Access),
        caps = {},
        classCategory = {},
        modelCategory = {},
        slotTypes = copy(Config.SlotTypes),
        minigames = copy(Config.Minigames),
        minSeconds = Config.MinSeconds,
        inspect = copy(Config.Inspect),
        blacklist = {},
    }
    for k, c in pairs(Config.Categories) do d.caps[k] = copy(c.caps) end
    for class, cat in pairs(Config.ClassCategory) do d.classCategory[class] = cat end
    for model, cat in pairs(Config.ModelCategory) do d.modelCategory[tostring(model):lower()] = cat end
    for _, name in ipairs(Config.Blacklist) do d.blacklist[name] = true end
    return d
end

-- Nettoie et borne un jeu de réglages complet (venant du KVP ou du menu)
function Cach.Sanitize(raw)
    local d = Cach.Defaults()
    if type(raw) ~= 'table' then return d end
    if type(raw.access) == 'table' then
        local a = raw.access
        for _, k in ipairs({ 'requireKeys', 'policeNeedsTool' }) do
            if a[k] ~= nil then d.access[k] = a[k] == true end
        end
        d.access.policeInspectPerm = str(a.policeInspectPerm, 40, d.access.policeInspectPerm)
        d.access.policeOpenPerm = str(a.policeOpenPerm, 40, d.access.policeOpenPerm)
    end
    if type(raw.caps) == 'table' then
        for cat, caps in pairs(d.caps) do
            local r = raw.caps[cat]
            if type(r) == 'table' then
                for t in pairs(caps) do caps[t] = math.floor(num(r[t], 0, 500, caps[t]) * 10 + 0.5) / 10 end
            end
        end
    end
    if type(raw.classCategory) == 'table' then
        for k, v in pairs(raw.classCategory) do
            local class = tonumber(k)
            if class and d.classCategory[class] ~= nil and CAT_SET[v] then d.classCategory[class] = v end
        end
    end
    if type(raw.modelCategory) == 'table' then
        d.modelCategory = {}
        local n = 0
        for k, v in pairs(raw.modelCategory) do
            local name = str(k, 40, nil)
            if name and CAT_SET[v] and n < 300 then
                name = name:lower():gsub('[^%w_%-]', '')
                if name ~= '' then d.modelCategory[name] = v n = n + 1 end
            end
        end
    end
    if type(raw.slotTypes) == 'table' then
        for _, t in ipairs(TYPES) do if raw.slotTypes[t] ~= nil then d.slotTypes[t] = raw.slotTypes[t] == true end end
    end
    if type(raw.minigames) == 'table' then
        for _, t in ipairs(TYPES) do
            local r, m = raw.minigames[t], d.minigames[t]
            if type(r) == 'table' and m then
                m.difficulty = math.floor(num(r.difficulty, 1, 5, m.difficulty))
                m.length = math.floor(num(r.length, 0.6, 1.6, m.length) * 10 + 0.5) / 10
                m.maxErrors = math.floor(num(r.maxErrors, 1, 10, m.maxErrors))
                m.timeLimit = math.floor(num(r.timeLimit, 90, 600, m.timeLimit))
            end
        end
    end
    d.minSeconds = math.floor(num(raw.minSeconds, 0, 120, d.minSeconds))
    if type(raw.inspect) == 'table' then
        d.inspect.duration = math.floor(num(raw.inspect.duration, 3000, 60000, d.inspect.duration))
        for _, k in ipairs({ 'light', 'high', 'none' }) do d.inspect[k] = str(raw.inspect[k], 200, d.inspect[k]) end
        -- un message de suspicion doit garder la place de l'emplacement (%s), une seule fois
        for _, k in ipairs({ 'light', 'high' }) do
            local _, n = d.inspect[k]:gsub('%%s', '')
            local _, other = d.inspect[k]:gsub('%%[^s]', '')
            if n ~= 1 or other > 0 then d.inspect[k] = Config.Inspect[k] end
        end
    end
    if type(raw.blacklist) == 'table' then
        d.blacklist = {}
        local n = 0
        for k, v in pairs(raw.blacklist) do
            local name = type(k) == 'number' and v or (v == true and k or nil)
            name = str(name, 60, nil)
            if name and n < 200 then d.blacklist[name] = true n = n + 1 end
        end
    end
    return d
end

function Cach.LoadSettings()
    local raw = GetResourceKvpString(KVP)
    local ok, data = pcall(json.decode, raw or '')
    Cach.S = Cach.Sanitize(ok and data or nil)
end

-- JSON : les clés numériques (classes) deviennent du texte, relues par Sanitize
-- Ce que le client doit savoir pour afficher (ou non) les actions ALT ; le serveur revérifie tout
function Cach.Publish()
    local S = Cach.S
    local classes, models = {}, {}
    for class, cat in pairs(S.classCategory) do classes[tostring(class)] = cat end
    for name, cat in pairs(S.modelCategory) do models[tostring(GetHashKey(name) % 4294967296)] = cat end
    GlobalState.cachettes = {
        classes = classes, models = models, slotTypes = S.slotTypes,
        inspectPerm = S.access.policeInspectPerm, openPerm = S.access.policeOpenPerm,
        policeNeedsTool = S.access.policeNeedsTool, requireKeys = S.access.requireKeys, tool = Config.ToolItem,
    }
end

function Cach.SaveSettings()
    local out = {}
    for k, v in pairs(Cach.S) do out[k] = v end
    local cc = {}
    for class, cat in pairs(Cach.S.classCategory) do cc[tostring(class)] = cat end
    out.classCategory = cc
    SetResourceKvp(KVP, json.encode(out))
    Cach.Publish()
end

function Cach.ResetSettings()
    DeleteResourceKvp(KVP)
    Cach.S = Cach.Defaults()
    Cach.Publish()
end

Cach.LoadSettings()
Cach.Publish()
