-- =====================================================================
--  ELYZEA CACHETTES - serveur
--  · Une cachette = un véhicule immatriculé (player_vehicles.id) + un emplacement.
--    L'identifiant ne change ni avec la plaque, ni avec le propriétaire : la cachette suit le véhicule.
--  · Contenu : coffre elyzea_inventory « cach:<id véhicule>:<emplacement> » (table elyzea_stashes),
--    capacité propre à chaque emplacement, aucune capacité commune.
--  · Suspicion : fixée UNE fois, à l'installation, par le nombre d'essais (1er = 0, 2e = 1, 3e et + = 2).
--  · Un seul joueur à la fois par emplacement (verrou du début du mini-jeu à la fermeture de l'inventaire).
--  · Tout est vérifié ici : outil, permissions, distance, durée réelle du mini-jeu.
-- =====================================================================
Cach = Cach or {}
local S = function() return Cach.S end
local core = exports.elyzea_core
local inv = exports.elyzea_inventory
local PREFIX = 'cach:'

Rows = {}         -- [vehId] = { [slot] = ligne }  (cache des lignes de la table)
Locks = {}        -- [vehId:slot] = src
Sessions = {}     -- [src] = { token, vehId, slot, mode, role, netId, game, started, minMs, errors, state, stashId }
local Menus = {}  -- [src] = { netId, vehId, allowed = { [slot] = true }, role, at, category }
local Inspects = {} -- [src] = { token, netId, started, duration }
local ModelClass = {} -- [modèle] = classe (première déclaration gardée)
local seq = 0

local function now() return GetGameTimer() end
local function cleanPlate(p) return (tostring(p or ''):gsub('^%s+', ''):gsub('%s+$', '')):upper() end
local function lockKey(vehId, slot) return ('%d:%s'):format(vehId, slot) end
function Cach.StashId(vehId, slot) return ('%s%d:%s'):format(PREFIX, vehId, slot) end

local function Notify(src, text, kind, title, duration)
    pcall(function() core:Notify(src, text, kind or 'inform', duration, title) end)
end
local function Cid(src)
    local ok, cid = pcall(function() return core:GetCitizenId(src) end)
    return ok and cid or nil
end

-- ---------------------------------------------------------------------
-- Base de données
-- ---------------------------------------------------------------------
CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `elyzea_cachettes` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `vehicle_id` int(11) NOT NULL,
        `slot` varchar(16) NOT NULL,
        `state` tinyint(1) NOT NULL DEFAULT 0,
        `attempts` int(11) NOT NULL DEFAULT 0,
        `suspicion` tinyint(1) NOT NULL DEFAULT 0,
        `capacity` int(11) NOT NULL DEFAULT 0,
        `category` varchar(16) DEFAULT NULL,
        `installed_by` varchar(50) DEFAULT NULL,
        `installed_at` timestamp NULL DEFAULT NULL,
        `opened_at` timestamp NULL DEFAULT NULL,
        `discovered` tinyint(1) NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        UNIQUE KEY `vehicle_slot` (`vehicle_id`, `slot`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `elyzea_cachettes_log` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `vehicle_id` int(11) NOT NULL,
        `slot` varchar(16) NOT NULL,
        `action` varchar(24) NOT NULL,
        `citizenid` varchar(50) DEFAULT NULL,
        `detail` varchar(255) DEFAULT NULL,
        `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `vehicle_id` (`vehicle_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    Cach.dbReady = true
end)

function Cach.Log(vehId, slot, action, src, detail)
    MySQL.insert('INSERT INTO `elyzea_cachettes_log` (`vehicle_id`, `slot`, `action`, `citizenid`, `detail`) VALUES (?, ?, ?, ?, ?)',
        { vehId, slot, action, src and Cid(src) or nil, detail and tostring(detail):sub(1, 255) or nil })
end

function Cach.LoadRows(vehId)
    if Rows[vehId] then return Rows[vehId] end
    local list = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `elyzea_cachettes` WHERE `vehicle_id` = ?', { vehId }) or {}) do
        if Slots[r.slot] then
            list[r.slot] = { state = tonumber(r.state) or 0, attempts = tonumber(r.attempts) or 0, suspicion = tonumber(r.suspicion) or 0,
                capacity = tonumber(r.capacity) or 0, category = r.category, discovered = tonumber(r.discovered) == 1 }
        end
    end
    Rows[vehId] = list
    return list
end

local function SaveRow(vehId, slot, row, extra)
    MySQL.query.await([[INSERT INTO `elyzea_cachettes` (`vehicle_id`, `slot`, `state`, `attempts`, `suspicion`, `capacity`, `category`, `installed_by`, `installed_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE `state` = VALUES(`state`), `attempts` = VALUES(`attempts`), `suspicion` = VALUES(`suspicion`),
            `capacity` = VALUES(`capacity`), `category` = VALUES(`category`),
            `installed_by` = COALESCE(VALUES(`installed_by`), `installed_by`), `installed_at` = COALESCE(VALUES(`installed_at`), `installed_at`)]],
        { vehId, slot, row.state, row.attempts, row.suspicion, row.capacity, row.category, extra and extra.by or nil, extra and extra.at or nil })
end

-- Identifiant fiable du véhicule : player_vehicles.id (ne change ni avec la plaque, ni avec le propriétaire)
local PlateCache = {}
function Cach.VehicleId(plate)
    plate = cleanPlate(plate)
    if plate == '' then return nil end
    local c = PlateCache[plate]
    if c and now() - c.t < 30000 then return c.id end
    local id = MySQL.scalar.await('SELECT `id` FROM `player_vehicles` WHERE `plate` = ? OR `plate` = ? LIMIT 1', { plate, ' ' .. plate })
    id = tonumber(id)
    PlateCache[plate] = { id = id, t = now() }
    return id
end

-- ---------------------------------------------------------------------
-- Vérifications
-- ---------------------------------------------------------------------
local function HasTool(src)
    local ok, n = pcall(function() return inv:Search(src, 'count', Config.ToolItem) end)
    return ok and (tonumber(n) or 0) > 0
end

local function PolicePerm(src, perm)
    if GetResourceState('elyzea_police') ~= 'started' then return false end
    local ok, res = pcall(function() return exports.elyzea_police:IsOnDuty(src) and exports.elyzea_police:HasPermission(src, perm) end)
    return ok and res == true
end
Cach.PolicePerm = PolicePerm

local function Vehicle(netId)
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return nil end
    return veh
end

local function Near(src, veh, extra)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - GetEntityCoords(veh)) <= Config.Distance + (extra or 0)
end

local function IsBike(veh)
    local ok, t = pcall(GetVehicleType, veh)
    return ok and (t == 'bike' or t == 'quadbike')
end

-- Catégorie du véhicule : exception du modèle, sinon catégorie de sa classe
function Cach.Category(veh, class)
    local model = GetEntityModel(veh) % 4294967296
    for name, cat in pairs(S().modelCategory) do
        if GetHashKey(name) % 4294967296 == model then return cat end
    end
    class = tonumber(class)
    if class then
        if ModelClass[model] == nil then ModelClass[model] = class end
        class = ModelClass[model]
    else
        class = ModelClass[model]
    end
    return S().classCategory[class or -1] or 'none'
end

-- Capacité (grammes) d'un emplacement pour une catégorie ; 0 = pas de cachette possible
function Cach.Capacity(category, slot)
    local s = Slots[slot]
    local caps = s and S().caps[category]
    local kg = caps and caps[s.type] or 0
    return math.floor((tonumber(kg) or 0) * 1000)
end

local function SlotUsable(category, slot, bike)
    local s = Slots[slot]
    if not s or not S().slotTypes[s.type] then return false end
    if not SlotAllowedForKind(slot, bike) then return false end
    if bike and category ~= 'moto' then return false end
    if not bike and category == 'moto' then return false end
    return Cach.Capacity(category, slot) > 0
end

local function SeatTaken(veh, slot)
    local s = Slots[slot]
    if not s or s.seat == nil then return false end
    local ok, ped = pcall(GetPedInVehicleSeat, veh, s.seat)
    return ok and ped and ped ~= 0
end

local function NeedsOpenDoor(slot)
    local t = Slots[slot] and Slots[slot].type
    return t == 'door' or t == 'seat' or t == 'trunk'
end

-- Accès d'un joueur à un véhicule selon son rôle ; renvoie nil ou un message d'erreur
local function CheckAccess(src, veh, role)
    local a = S().access
    if role == 'police' then
        if not PolicePerm(src, a.policeOpenPerm) then return 'Vous n\'avez pas l\'autorisation de démonter un véhicule.' end
        if a.policeNeedsTool and not HasTool(src) then return 'Il vous faut un tournevis.' end
        return nil
    end
    if not HasTool(src) then return 'Il vous faut un tournevis.' end
    if a.requireKeys then
        local ok, k = pcall(function() return core:HasKeys(src, veh) end)
        if not (ok and k == true) then return 'Vous n\'avez pas les clés de ce véhicule.' end
    end
    return nil
end

-- ---------------------------------------------------------------------
-- Menu des emplacements
-- ---------------------------------------------------------------------
-- info = { class, model, slots = { ids détectés sur le modèle par le client } }
Ely.callback.register('cach:menu', function(src, netId, role, info)
    if not Cach.dbReady then return { error = 'Le système démarre, réessayez dans un instant.' } end
    if Sessions[src] then return { error = 'Une opération est déjà en cours.' } end
    role = role == 'police' and 'police' or 'crime'
    info = type(info) == 'table' and info or {}
    local veh = Vehicle(netId)
    if not veh then return { error = 'Véhicule introuvable.' } end
    if not Near(src, veh) then return { error = 'Vous êtes trop loin du véhicule.' } end
    local err = CheckAccess(src, veh, role)
    if err then return { error = err } end
    local bike = IsBike(veh)
    local category = Cach.Category(veh, info.class)
    if category == 'none' then return { error = 'Ce véhicule ne permet pas d\'aménager de cachette.' } end
    local vehId = Cach.VehicleId(GetVehicleNumberPlateText(veh))
    if not vehId then
        if role ~= 'police' then return { error = 'Ce véhicule n\'est immatriculé au nom de personne : impossible d\'y aménager une cachette.' } end
        -- véhicule non immatriculé : aucune cachette ne peut exister, mais on ne le dit pas à la police : même liste, même mini-jeu
        vehId = -1
    end
    local rows = vehId > 0 and Cach.LoadRows(vehId) or {}
    local list, allowed = {}, {}
    local detected = {}
    for _, id in ipairs(type(info.slots) == 'table' and info.slots or {}) do detected[tostring(id)] = true end
    local locked = (GetVehicleDoorLockStatus(veh) or 0) >= 2
    for _, slot in ipairs(SlotOrder) do
        if detected[slot] and SlotUsable(category, slot, bike) then
            local s, row = Slots[slot], rows[slot]
            local e = { id = slot, label = s.label, type = s.type, game = GameLabels[s.type] }
            local busy = vehId > 0 and Locks[lockKey(vehId, slot)] ~= nil
            if busy then e.disabled, e.desc = true, 'Quelqu\'un travaille déjà ici' end
            if SeatTaken(veh, slot) then e.disabled, e.desc = true, 'Siège occupé' end
            if role == 'crime' then
                if row and row.state == 1 then
                    e.status, e.capacity = 'installed', row.capacity / 1000
                else
                    e.status, e.capacity = 'free', Cach.Capacity(category, slot) / 1000
                    if row and row.attempts > 0 then e.attempts = row.attempts end
                end
                if locked and NeedsOpenDoor(slot) and not e.disabled then e.disabled, e.desc = true, 'Déverrouillez d\'abord le véhicule' end
            end
            list[#list + 1] = e
            allowed[slot] = true
        end
    end
    if #list == 0 then return { error = 'Aucun emplacement compatible sur ce véhicule.' } end
    Menus[src] = { netId = tonumber(netId), vehId = vehId, allowed = allowed, role = role, at = now(), category = category }
    local plate = cleanPlate(GetVehicleNumberPlateText(veh))
    return { slots = list, role = role, category = (Config.Categories[category] or {}).label, plate = plate }
end)

-- ---------------------------------------------------------------------
-- Début d'une opération : verrou + paramètres du mini-jeu
-- ---------------------------------------------------------------------
local function Release(src, reason)
    local s = Sessions[src]
    if not s then return end
    Sessions[src] = nil
    if s.vehId and s.vehId > 0 and Locks[lockKey(s.vehId, s.slot)] == src then Locks[lockKey(s.vehId, s.slot)] = nil end
    if s.vehId and s.vehId < 0 then Locks[('-%d:%s'):format(s.netId, s.slot)] = nil end
    if reason then TriggerClientEvent('elyzea_cachettes:ended', src, reason) end
end
Cach.Release = Release

local function Token()
    seq = seq + 1
    return ('%d-%d-%d'):format(seq, math.random(100000, 999999), now())
end

Ely.callback.register('cach:start', function(src, slot)
    local m = Menus[src]
    Menus[src] = nil
    if Sessions[src] then return { error = 'Une opération est déjà en cours.' } end
    if not m or now() - m.at > Config.MenuTimeout * 1000 then return { error = 'Choix expiré, recommencez.' } end
    slot = tostring(slot or '')
    if not m.allowed[slot] then return { error = 'Emplacement indisponible.' } end
    local veh = Vehicle(m.netId)
    if not veh then return { error = 'Véhicule introuvable.' } end
    if not Near(src, veh) then return { error = 'Vous êtes trop loin du véhicule.' } end
    local err = CheckAccess(src, veh, m.role)
    if err then return { error = err } end
    if SeatTaken(veh, slot) then return { error = 'Ce siège est occupé.' } end
    if m.role == 'crime' and NeedsOpenDoor(slot) and (GetVehicleDoorLockStatus(veh) or 0) >= 2 then return { error = 'Déverrouillez d\'abord le véhicule.' } end
    local key = m.vehId > 0 and lockKey(m.vehId, slot) or ('-%d:%s'):format(m.netId, slot)
    if Locks[key] and Locks[key] ~= src then return { error = 'Quelqu\'un travaille déjà sur cet emplacement.' } end
    local mode
    if m.role == 'police' then
        mode = 'search'
    else
        local row = Cach.LoadRows(m.vehId)[slot]
        mode = (row and row.state == 1) and 'open' or 'install'
    end
    local t = Slots[slot].type
    local g = S().minigames[t]
    Locks[key] = src
    local token = Token()
    Sessions[src] = { token = token, vehId = m.vehId, slot = slot, mode = mode, role = m.role, netId = m.netId, category = m.category,
        game = t, started = now(), minMs = math.floor(S().minSeconds * g.length * 1000), limitMs = g.timeLimit * 1000, errors = 0, state = 'game' }
    return { token = token, game = t, mode = mode, label = Slots[slot].label, slot = slot,
        params = { difficulty = g.difficulty, length = g.length, maxErrors = g.maxErrors, timeLimit = g.timeLimit, seed = math.random(1, 2147483646) } }
end)

-- Erreurs en cours de mini-jeu (une déconnexion après une erreur compte comme un essai raté)
RegisterNetEvent('elyzea_cachettes:progress', function(token, errors)
    local s = Sessions[source]
    if s and s.token == token and s.state == 'game' then
        local e = math.floor(tonumber(errors) or 0)
        if e > s.errors then s.errors = math.min(e, 50) end
    end
end)

-- Essai raté d'installation : compté et enregistré (sert à la suspicion de l'installation)
local function FailedAttempt(s, src)
    if s.mode ~= 'install' or s.vehId <= 0 then return end
    local rows = Cach.LoadRows(s.vehId)
    local row = rows[s.slot] or { state = 0, attempts = 0, suspicion = 0, capacity = 0, category = s.category }
    if row.state == 1 then return end
    row.attempts = row.attempts + 1
    rows[s.slot] = row
    SaveRow(s.vehId, s.slot, row)
    Cach.Log(s.vehId, s.slot, 'install_fail', src, ('essai %d'):format(row.attempts))
end

-- Déclare le coffre de la cachette à l'inventaire (nécessaire avant d'en lire ou d'en ouvrir le contenu)
function Cach.EnsureStash(vehId, slot, capacity)
    local id = Cach.StashId(vehId, slot)
    if not capacity then
        local row = Cach.LoadRows(vehId)[slot]
        capacity = row and row.capacity or 0
    end
    inv:RegisterStash(id, ('Cachette · %s'):format(Slots[slot].label), Config.SlotsPerStash, math.max(1, capacity))
    return id
end
function Cach.StashItems(vehId, slot)
    local ok, items = pcall(function() return inv:GetStashItems(Cach.EnsureStash(vehId, slot)) end)
    return ok and items or {}
end

-- Ouvre l'inventaire de la cachette (le verrou reste tenu tant que l'inventaire est ouvert)
local function OpenStash(src, s, row)
    local id = Cach.EnsureStash(s.vehId, s.slot, row.capacity)
    s.stashId, s.state, s.openedAt = id, 'viewing', now()
    if not inv:OpenInventory(src, 'stash', id) then
        Release(src, 'error')
        return false
    end
    MySQL.update('UPDATE `elyzea_cachettes` SET `opened_at` = CURRENT_TIMESTAMP WHERE `vehicle_id` = ? AND `slot` = ?', { s.vehId, s.slot })
    return true
end

-- Fin du mini-jeu : result = { success, cancelled, errors }
Ely.callback.register('cach:finish', function(src, token, result)
    local s = Sessions[src]
    if not s or s.token ~= token or s.state ~= 'game' then return { error = 'Opération inconnue.' } end
    result = type(result) == 'table' and result or {}
    local errors = math.max(s.errors, math.floor(tonumber(result.errors) or 0))
    local elapsed = now() - s.started
    if result.cancelled then
        if errors > 0 then FailedAttempt(s, src) end
        Release(src)
        return { cancelled = true, counted = errors > 0 and s.mode == 'install' }
    end
    if result.success ~= true then
        FailedAttempt(s, src)
        Release(src)
        return { failed = true }
    end
    if elapsed < s.minMs then
        print(('^3[elyzea_cachettes] Réussite refusée (trop rapide : %.1f s < %.1f s) pour le joueur %d^0'):format(elapsed / 1000, s.minMs / 1000, src))
        Release(src)
        return { error = 'Le démontage n\'a pas été fait correctement.' }
    end
    local veh = Vehicle(s.netId)
    if not veh or not Near(src, veh, 2.0) then Release(src) return { error = 'Vous vous êtes éloigné du véhicule.' } end
    local err = CheckAccess(src, veh, s.role)
    if err then Release(src) return { error = err } end

    if s.mode == 'install' then
        local rows = Cach.LoadRows(s.vehId)
        local row = rows[s.slot] or { state = 0, attempts = 0 }
        if row.state == 1 then Release(src) return { error = 'Une cachette existe déjà à cet emplacement.' } end
        row.state = 1
        row.suspicion = math.min(2, row.attempts)       -- 1er essai : 0 · 2e : 1 · 3e et plus : 2
        row.capacity = Cach.Capacity(s.category, s.slot)
        row.category = s.category
        row.discovered = false
        rows[s.slot] = row
        SaveRow(s.vehId, s.slot, row, { by = Cid(src), at = os.date('%Y-%m-%d %H:%M:%S') })
        Cach.Log(s.vehId, s.slot, 'install', src, ('essais %d, suspicion %d, %d g'):format(row.attempts + 1, row.suspicion, row.capacity))
        if not OpenStash(src, s, row) then return { error = 'Inventaire indisponible.' } end
        return { opened = true, installed = true, capacity = row.capacity / 1000 }
    elseif s.mode == 'open' then
        local row = Cach.LoadRows(s.vehId)[s.slot]
        if not row or row.state ~= 1 then Release(src) return { error = 'Aucune cachette ici.' } end
        Cach.Log(s.vehId, s.slot, 'open', src)
        if not OpenStash(src, s, row) then return { error = 'Inventaire indisponible.' } end
        return { opened = true, capacity = row.capacity / 1000 }
    else -- police
        local row = s.vehId > 0 and Cach.LoadRows(s.vehId)[s.slot] or nil
        if not row or row.state ~= 1 then
            if s.vehId > 0 then Cach.Log(s.vehId, s.slot, 'police_empty', src) end
            Release(src)
            return { empty = true }
        end
        if not row.discovered then
            row.discovered = true
            MySQL.update('UPDATE `elyzea_cachettes` SET `discovered` = 1 WHERE `vehicle_id` = ? AND `slot` = ?', { s.vehId, s.slot })
        end
        Cach.Log(s.vehId, s.slot, 'police_found', src)
        if not OpenStash(src, s, row) then return { error = 'Inventaire indisponible.' } end
        return { opened = true, found = true, capacity = row.capacity / 1000 }
    end
end)

-- ---------------------------------------------------------------------
-- Surveillance : inventaire fermé, joueur éloigné, véhicule disparu, mini-jeu abandonné
-- ---------------------------------------------------------------------
local function Viewing(src)
    local ok, v = pcall(function() return inv:GetViewing(src) end)
    return ok and v or nil
end

function Cach.Tick()
    local t = now()
    for src, s in pairs(Sessions) do
        if s.state == 'viewing' then
            local v = Viewing(src)
            local veh = Vehicle(s.netId)
            if not v or v.id ~= s.stashId then
                Release(src, 'closed')
            elseif not veh or not Near(src, veh, 2.5) then
                pcall(function() inv:CloseInventory(src) end)
                Release(src, 'far')
            end
        elseif s.state == 'game' and t - s.started > s.limitMs + 30000 then
            if s.errors > 0 then FailedAttempt(s, src) end
            Release(src, 'timeout')
        end
    end
end
CreateThread(function()
    while true do
        Wait(1000)
        Cach.Tick()
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local s = Sessions[src]
    if s and s.state == 'game' and s.errors > 0 then FailedAttempt(s, src) end
    Release(src)
    Menus[src], Inspects[src] = nil, nil
end)

-- Le client a dû interrompre (mort, menotté, véhicule parti…) : même règle que l'annulation
RegisterNetEvent('elyzea_cachettes:abort', function(token)
    local src = source
    local s = Sessions[src]
    if not s or s.token ~= token then return end
    if s.state == 'game' and s.errors > 0 then FailedAttempt(s, src) end
    if s.state == 'viewing' then pcall(function() inv:CloseInventory(src) end) end
    Release(src)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src, s in pairs(Sessions) do
        if s.state == 'viewing' then pcall(function() inv:CloseInventory(src) end) end
    end
end)

-- ---------------------------------------------------------------------
-- Inventaire : accès réservé à l'opération en cours, objets interdits, journal
-- ---------------------------------------------------------------------
local function Hook()
    if GetResourceState('elyzea_inventory') ~= 'started' then return end
    pcall(function()
        inv:RegisterStashAccess(PREFIX, function(src, stashId)
            local s = Sessions[tonumber(src) or -1]
            return s ~= nil and s.state == 'viewing' and s.stashId == stashId
        end)
    end)
    pcall(function()
        inv:RegisterStashGuard(PREFIX, function(src, stashId, action, name)
            local s = Sessions[tonumber(src) or -1]
            if not s or s.state ~= 'viewing' or s.stashId ~= stashId then return false, 'Cette cachette n\'est plus ouverte.' end
            if action == 'store' and S().blacklist[name] then return false, 'Cet objet ne peut pas être caché ici.' end
            return true
        end)
    end)
end
CreateThread(function() Wait(0) Hook() end)
AddEventHandler('elyzea_inventory:ready', Hook)
AddEventHandler('onServerResourceStart', function(res) if res == 'elyzea_inventory' then SetTimeout(500, Hook) end end)

AddEventHandler('elyzea_inventory:itemMoved', function(src, action, name, count, kind, id)
    if kind ~= 'stash' or type(id) ~= 'string' or id:sub(1, #PREFIX) ~= PREFIX then return end
    local s = Sessions[tonumber(src) or -1]
    local vehId, slot = id:match('^cach:(%d+):(.+)$')
    if not vehId then return end
    local act = action == 'take' and ((s and s.role == 'police') and 'seize' or 'take') or 'store'
    Cach.Log(tonumber(vehId), slot, act, src, ('%dx %s'):format(tonumber(count) or 0, tostring(name)))
end)

-- ---------------------------------------------------------------------
-- Inspection policière
-- ---------------------------------------------------------------------
Ely.callback.register('cach:inspectStart', function(src, netId)
    if not PolicePerm(src, S().access.policeInspectPerm) then return { error = 'Vous n\'avez pas l\'autorisation d\'inspecter un véhicule.' } end
    if Sessions[src] then return { error = 'Une opération est déjà en cours.' } end
    local veh = Vehicle(netId)
    if not veh then return { error = 'Véhicule introuvable.' } end
    if not Near(src, veh) then return { error = 'Vous êtes trop loin du véhicule.' } end
    local token = Token()
    Inspects[src] = { token = token, netId = tonumber(netId), started = now(), duration = S().inspect.duration }
    return { token = token, duration = S().inspect.duration }
end)

-- Liste des anomalies d'un véhicule (cachettes installées avec suspicion), dans l'ordre des emplacements
function Cach.Anomalies(vehId)
    local out = {}
    if not vehId or vehId <= 0 then return out end
    local rows = Cach.LoadRows(vehId)
    for _, slot in ipairs(SlotOrder) do
        local r = rows[slot]
        if r and r.state == 1 and r.suspicion > 0 then out[#out + 1] = { slot = slot, level = r.suspicion } end
    end
    return out
end

Ely.callback.register('cach:inspectFinish', function(src, token, cancelled)
    local i = Inspects[src]
    Inspects[src] = nil
    if not i or i.token ~= token then return { error = 'Inspection inconnue.' } end
    if cancelled then return { cancelled = true } end
    if now() - i.started < i.duration - 1500 then return { error = 'Inspection interrompue.' } end
    local veh = Vehicle(i.netId)
    if not veh or not Near(src, veh, 2.0) then return { error = 'Vous vous êtes éloigné du véhicule.' } end
    local vehId = Cach.VehicleId(GetVehicleNumberPlateText(veh))
    local list = Cach.Anomalies(vehId)
    local msg = S().inspect
    for _, a in ipairs(list) do
        local text = (a.level >= 2 and msg.high or msg.light):format(Slots[a.slot].where)
        Notify(src, text, a.level >= 2 and 'error' or 'warning', 'Inspection du véhicule', 10000)
    end
    if #list == 0 then Notify(src, msg.none, 'success', 'Inspection du véhicule', 8000) end
    if vehId then Cach.Log(vehId, '-', 'inspect', src, ('%d anomalie(s)'):format(#list)) end
    return { count = #list }
end)

-- ---------------------------------------------------------------------
-- Exports pour les autres ressources
-- ---------------------------------------------------------------------
-- Véhicule recréé avec un nouvel identifiant (ex. reprise par un autre système) : les cachettes suivent
exports('TransferCachettes', function(oldId, newId)
    oldId, newId = tonumber(oldId), tonumber(newId)
    if not oldId or not newId or oldId == newId then return false end
    for _, s in pairs(Sessions) do if s.vehId == oldId or s.vehId == newId then return false end end
    local rows = Cach.LoadRows(oldId)
    for slot in pairs(rows) do
        Cach.EnsureStash(oldId, slot)
        local ok = pcall(function() return inv:RenameStash(Cach.StashId(oldId, slot), Cach.StashId(newId, slot)) end)
        if not ok then return false end
    end
    MySQL.update.await('UPDATE `elyzea_cachettes` SET `vehicle_id` = ? WHERE `vehicle_id` = ?', { newId, oldId })
    Rows[oldId], Rows[newId] = nil, nil
    return true
end)
-- Contenu des cachettes actives d'un véhicule, par plaque (lecture seule ; ex. chien de détection K9, elyzea_k9)
-- → { { slot, label, items = { { name, count }, … } }, … }
exports('GetVehicleHiddenItems', function(plate)
    local vehId = Cach.VehicleId(plate)
    local out = {}
    if not vehId then return out end
    for slot, r in pairs(Cach.LoadRows(vehId)) do
        if r.state == 1 and Slots[slot] then
            Cach.EnsureStash(vehId, slot)
            local ok, items = pcall(function() return inv:GetStashItems(Cach.StashId(vehId, slot)) end)
            out[#out + 1] = { slot = slot, label = Slots[slot].label, items = ok and type(items) == 'table' and items or {} }
        end
    end
    return out
end)
exports('GetVehicleCachettes', function(vehId)
    local out = {}
    for slot, r in pairs(Cach.LoadRows(tonumber(vehId) or -1)) do
        if r.state == 1 then out[#out + 1] = { slot = slot, label = Slots[slot].label, suspicion = r.suspicion, capacity = r.capacity, discovered = r.discovered } end
    end
    return out
end)
