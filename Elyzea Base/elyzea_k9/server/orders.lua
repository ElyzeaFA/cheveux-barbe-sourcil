-- =====================================================================
--  ELYZEA K9 - SERVEUR : ordres, détection, intervention, pistage
--  Le hasard est tiré ICI (obéissance, détection, réussite) avec les
--  compétences du chien : un client modifié ne peut pas forcer un résultat.
-- =====================================================================
local Notify, TooFast, Access = K9S.Notify, K9S.TooFast, K9S.Access
local inv = exports.elyzea_inventory
local Orders = {}      -- [dogId] = ordre en cours { id, target, t, attempts, ... }
K9S.Orders = Orders
local Recent = {}      -- anti-farm : [dogId:kind:clé] = horodatage

local function int(v, d) v = tonumber(v) if not v or v ~= v then return d end return math.floor(v) end
local function Dist(a, b) return (a and b) and #(a - b) or 1e9 end
local function Ped(src) local p = GetPlayerPed(src) return (p and p ~= 0) and p or nil end
local function roll(p) return math.random() < p end

-- XP d'intervention, une fois par cible et par délai (sameTargetMinutes)
local function MissionXp(src, d, kind, key, amount, label)
    local k = ('%d:%s:%s'):format(d.id, kind, tostring(key))
    local t = os.time()
    if Recent[k] and t - Recent[k] < Config.MissionXp.sameTargetMinutes * 60 then return 0 end
    Recent[k] = t
    d.stats.missions[kind] = (d.stats.missions[kind] or 0) + 1
    return K9S.AddXp(src, d, amount, 'mission', label)
end

-- Joueur ciblable : connecté, vivant, pas le maître ; distance au maître
local function ValidTarget(src, target, maxDist)
    target = tonumber(target)
    if not target or target == src or not GetPlayerName(target) then return nil, 'Personne introuvable.' end
    local tp = Ped(target)
    if not tp then return nil, 'Personne introuvable.' end
    if GetEntityHealth(tp) <= 100 then return nil, 'Cette personne est déjà à terre.' end
    if Dist(GetEntityCoords(tp), K9S.Coords(src)) > (maxDist or Config.Target.maxDistance) + 6.0 then return nil, 'Cette personne est trop loin.' end
    return target, tp
end

local function IsCopOnDuty(target)
    if GetResourceState('elyzea_police') ~= 'started' then return false end
    local ok, on = pcall(function() return exports.elyzea_police:IsOnDuty(target) end)
    return ok and on == true
end

-- ---------------------------------------------------------------------
--  Ordre donné par le maître → { ok, obey, hesitate, ... }
-- ---------------------------------------------------------------------
Ely.callback.register('elyzea_k9:order', function(src, side, orderId, target)
    if TooFast(src, 'order', Config.Orders.cooldownMs) then return { ok = false, error = 'Laisse à ton chien le temps de réagir.' } end
    local ok, err = Access(src, side, true)
    if not ok then return { ok = false, error = err } end
    local o = K9.Order(orderId)
    if not o or (o.police and side ~= 'police') then return { ok = false, error = 'Ordre inconnu.' } end
    local d, a = K9S.ActiveDog(src, side)
    if not d then return { ok = false, error = a } end
    if K9S.Busy[src] then return { ok = false, error = 'Termine ton exercice d\'abord.' } end
    local e = K9.Effects(d)
    local out = { ok = true, order = o.id, hesitate = e.hesitateMs }

    -- cible
    local tsrc
    if o.target == 'player' then
        local maxD = o.id == 'track' and Config.Target.maxDistance or Config.Target.maxDistance
        local t, tp = ValidTarget(src, target, maxD)
        if not t then return { ok = false, error = tp } end
        tsrc = t
        if (o.id == 'attack' or o.id == 'takedown') then
            if GetVehiclePedIsIn(tp, false) ~= 0 then return { ok = false, error = 'La personne est dans un véhicule.' } end
            if side == 'police' and Config.Police.protectOnDutyPolice and IsCopOnDuty(t) then return { ok = false, error = 'Ton chien n\'attaque pas un collègue en service.' } end
        end
        out.target = t
    elseif o.target == 'vehicle' then
        local veh = NetworkGetEntityFromNetworkId(int(target, 0))
        if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return { ok = false, error = 'Véhicule introuvable.' } end
        if Dist(GetEntityCoords(veh), K9S.Coords(src)) > Config.Target.vehicleDistance + 4.0 then return { ok = false, error = 'Véhicule trop loin.' } end
        out.target = int(target, 0)
    end

    -- obéissance (tirée ici) ; un chien peu dressé a peur d'une cible armée
    local chance = e.obeyChance
    if (o.id == 'attack' or o.id == 'takedown') and tsrc then
        local w = GetSelectedPedWeapon(Ped(tsrc))
        if w and w ~= `WEAPON_UNARMED` and w ~= 0 then
            if e.attackRefuseArmed then return { ok = true, order = o.id, obey = false, fear = true, target = tsrc } end
            chance = chance - 0.08
        end
    end
    if o.target == 'none' and (o.id == 'follow' or o.id == 'come') then chance = math.max(chance, 0.9) end   -- le rappel est la base
    out.obey = roll(chance)
    if not out.obey then return out end

    a.mode = o.id
    Orders[d.id] = { id = o.id, target = out.target, t = GetGameTimer(), attempts = 0 }
    if o.id == 'attack' or o.id == 'takedown' then out.chase = Config.Attack.chaseSeconds end
    if o.id == 'track' then out.refresh = e.trackRefresh end
    if o.id == 'intim' or o.id == 'bark' then out.seconds = o.id == 'bark' and 6 or e.intimSeconds end
    if o.id == 'search' then out.sniffMs = e.sniffMs end
    if o.id == 'sniffp' or o.id == 'sniffv' then out.sniffMs = e.sniffMs end
    return out
end)

-- ---------------------------------------------------------------------
--  Détection de stupéfiants
-- ---------------------------------------------------------------------
local function CountDrugs(items)
    local n = 0
    for _, it in pairs(items or {}) do if type(it) == 'table' and K9.IsDrug(it.name) then n = n + (tonumber(it.count) or 1) end end
    return n
end
local function TrunkItems(plate)
    local id = 'trunk:' .. plate
    local ok, items = pcall(function() return inv:GetStashItems(id) end)
    if ok and type(items) == 'table' and next(items) then return items end
    local row = MySQL.single.await('SELECT `items` FROM `elyzea_stashes` WHERE `id` = ?', { id })
    local ok2, list = pcall(json.decode, row and row.items or '[]')
    return ok2 and type(list) == 'table' and list or {}
end
local function Plate(veh) return ((GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', '')) end

-- Renifler une personne : appelé quand le chien est contre elle
Ely.callback.register('elyzea_k9:sniffPerson', function(src, side, target)
    local d, a, dog = K9S.ActiveDog(src, side)
    if not d then return { ok = false, error = a } end
    local o = Orders[d.id]
    target = tonumber(target)
    if not o or o.id ~= 'sniffp' or o.target ~= target then return { ok = false, error = 'Aucune fouille en cours.' } end
    Orders[d.id] = nil
    local tp = Ped(target)
    if not tp or Dist(GetEntityCoords(tp), GetEntityCoords(dog)) > 4.0 then return { ok = false, error = 'Le chien n\'a pas pu approcher la personne.' } end
    local e = K9.Effects(d)
    local ok2, items = pcall(function() return inv:GetInventoryItems(target) end)
    local n = ok2 and CountDrugs(items) or 0
    local found = n > 0 and roll(math.min(0.99, e.sniffChance + math.min(0.15, n * 0.01)))
    local falsePos = n == 0 and roll(e.falsePositive)
    local r = { ok = true, marked = found or falsePos }
    if found then
        r.xp = MissionXp(src, d, 'sniff', 'p' .. target, Config.MissionXp.sniffFound, 'Stupéfiants détectés sur une personne')
    else
        MissionXp(src, d, 'sniffclear', 'p' .. target, Config.MissionXp.sniffClear, 'Fouille d\'une personne')
    end
    return r
end)

-- Renifler un véhicule (coffre + cachettes ; habitacle = occupants)
Ely.callback.register('elyzea_k9:sniffVehicle', function(src, side, netId)
    local d, a, dog = K9S.ActiveDog(src, side)
    if not d then return { ok = false, error = a } end
    local o = Orders[d.id]
    if not o or o.id ~= 'sniffv' or o.target ~= int(netId, 0) then return { ok = false, error = 'Aucune fouille en cours.' } end
    Orders[d.id] = nil
    local veh = NetworkGetEntityFromNetworkId(int(netId, 0))
    if not veh or veh == 0 or not DoesEntityExist(veh) then return { ok = false, error = 'Véhicule introuvable.' } end
    if Dist(GetEntityCoords(veh), GetEntityCoords(dog)) > 7.0 then return { ok = false, error = 'Le chien n\'a pas pu approcher du véhicule.' } end
    local e = K9.Effects(d)
    local plate = Plate(veh)
    local spots = {}   -- où le chien marque : trunk | cabin | hidden
    if plate ~= '' and CountDrugs(TrunkItems(plate)) > 0 and roll(e.sniffChance) then spots[#spots + 1] = 'trunk' end
    -- habitacle : occupants porteurs de stupéfiants
    for seat = -1, 6 do
        local p = GetPedInVehicleSeat(veh, seat)
        if p and p ~= 0 and IsPedAPlayer(p) then
            local s = NetworkGetEntityOwner(p)
            local ok2, items = pcall(function() return inv:GetInventoryItems(s) end)
            if ok2 and CountDrugs(items) > 0 and roll(e.sniffChance) then spots[#spots + 1] = 'cabin' break end
        end
    end
    -- cachettes (elyzea_cachettes) : bien mieux repérées à partir du niveau 3 de reniflage
    if plate ~= '' and GetResourceState('elyzea_cachettes') == 'started' then
        local ok3, hidden = pcall(function() return exports.elyzea_cachettes:GetVehicleHiddenItems(plate) end)
        if ok3 and type(hidden) == 'table' then
            for _, h in ipairs(hidden) do
                if CountDrugs(h.items) > 0 and roll(e.sniffHidden and e.sniffChance or e.sniffChance * 0.35) then spots[#spots + 1] = 'hidden' break end
            end
        end
    end
    local falsePos = #spots == 0 and roll(e.falsePositive)
    if falsePos then spots[1] = 'trunk' end
    local r = { ok = true, spots = spots, marked = #spots > 0 }
    if #spots > 0 and not falsePos then
        r.xp = MissionXp(src, d, 'sniff', 'v' .. plate, Config.MissionXp.sniffFound, ('Stupéfiants détectés dans un véhicule (%s)'):format(plate))
    else
        MissionXp(src, d, 'sniffclear', 'v' .. plate, Config.MissionXp.sniffClear, 'Fouille d\'un véhicule')
    end
    return r
end)

-- Fouiller la zone : personnes cachées (pistage) et stupéfiants (reniflage) autour du chien
Ely.callback.register('elyzea_k9:searchZone', function(src, side)
    local d, a, dog = K9S.ActiveDog(src, side)
    if not d then return { ok = false, error = a } end
    local o = Orders[d.id]
    if not o or o.id ~= 'search' then return { ok = false, error = 'Aucune fouille en cours.' } end
    Orders[d.id] = nil
    local e = K9.Effects(d)
    local center = GetEntityCoords(dog)
    local spots = {}
    -- personnes (hors maître, hors policiers en service) dans le rayon de recherche
    for _, sid in ipairs(GetPlayers()) do
        local t = tonumber(sid)
        local tp = t ~= src and Ped(t)
        if tp and GetEntityHealth(tp) > 100 and GetVehiclePedIsIn(tp, false) == 0 then
            local c = GetEntityCoords(tp)
            if Dist(c, center) <= e.personRadius and not IsCopOnDuty(t) and roll(e.trackChance) then
                spots[#spots + 1] = { kind = 'person', x = c.x, y = c.y, z = c.z, sid = t }
                local ok2, items = pcall(function() return inv:GetInventoryItems(t) end)
                if ok2 and CountDrugs(items) > 0 and roll(e.sniffChance) then spots[#spots].drugs = true end
            end
        end
    end
    -- stupéfiants au sol (sacs, colis) dans le rayon de reniflage
    local ok3, drops = pcall(function() return inv:GetDropsInRadius(center, e.drugRadius) end)
    if ok3 and type(drops) == 'table' then
        local seen = {}
        for _, dr in ipairs(drops) do
            if K9.IsDrug(dr.name) and not seen[dr.drop] and roll(e.sniffChance) then
                seen[dr.drop] = true
                spots[#spots + 1] = { kind = 'drugs', x = dr.coords.x, y = dr.coords.y, z = dr.coords.z }
            end
        end
    end
    -- véhicules garés à portée : coffre chargé
    for _, veh in ipairs(GetAllVehicles()) do
        local c = GetEntityCoords(veh)
        if Dist(c, center) <= e.drugRadius then
            local plate = Plate(veh)
            if plate ~= '' and CountDrugs(TrunkItems(plate)) > 0 and roll(e.sniffChance * 0.8) then
                spots[#spots + 1] = { kind = 'vehicle', x = c.x, y = c.y, z = c.z, net = NetworkGetNetworkIdFromEntity(veh) }
            end
        end
    end
    table.sort(spots, function(x, y) return Dist(vector3(x.x, x.y, x.z), center) < Dist(vector3(y.x, y.y, y.z), center) end)
    while #spots > 6 do table.remove(spots) end
    local xp = 0
    for _, s in ipairs(spots) do
        if s.kind == 'person' then xp = xp + MissionXp(src, d, 'found', 'z' .. s.sid, Config.MissionXp.trackFound, 'Personne retrouvée en fouille de zone') end
        if s.kind ~= 'person' or s.drugs then xp = xp + MissionXp(src, d, 'sniff', ('z%d:%d'):format(math.floor(s.x), math.floor(s.y)), Config.MissionXp.sniffFound, 'Stupéfiants trouvés en fouille de zone') end
    end
    return { ok = true, spots = spots, radius = math.max(e.personRadius, e.drugRadius), xp = xp }
end)

-- ---------------------------------------------------------------------
--  Intervention : contact chien-cible → mise au sol (côté victime)
-- ---------------------------------------------------------------------
Ely.callback.register('elyzea_k9:contact', function(src, side, target)
    local d, a, dog = K9S.ActiveDog(src, side)
    if not d then return { ok = false, error = a } end
    local o = Orders[d.id]
    target = tonumber(target)
    if not o or (o.id ~= 'attack' and o.id ~= 'takedown' and o.id ~= 'defend') or o.target ~= target then return { ok = false } end
    if GetGameTimer() - o.t > (Config.Attack.chaseSeconds + 5) * 1000 then Orders[d.id] = nil return { ok = false, error = 'Poursuite abandonnée.' } end
    if TooFast(src, 'contact', 700) then return { ok = false } end
    local tp = Ped(target)
    if not tp then Orders[d.id] = nil return { ok = false } end
    if Dist(GetEntityCoords(tp), GetEntityCoords(dog)) > Config.Attack.contactDistance + 1.2 then return { ok = false, far = true } end
    if GetVehiclePedIsIn(tp, false) ~= 0 then Orders[d.id] = nil return { ok = false, error = 'La cible est montée dans un véhicule.' } end
    o.attempts = o.attempts + 1
    local e = K9.Effects(d)
    local chance = e.attackChance + (o.id == 'defend' and 0.05 or 0)
    if not roll(chance) then
        if o.attempts >= 3 then Orders[d.id] = nil return { ok = true, success = false, gaveUp = true } end
        return { ok = true, success = false }
    end
    Orders[d.id] = nil
    local hold = o.id == 'takedown' and 0 or e.holdSeconds
    TriggerClientEvent('elyzea_k9:client:takedown', target, { dog = K9S.Active[d.id].netId, hold = hold, damage = Config.Attack.bitesDamage, floor = Config.Attack.healthFloor })
    local xp = MissionXp(src, d, 'takedown', 't' .. target, o.id == 'defend' and Config.MissionXp.defend or Config.MissionXp.takedown,
        o.id == 'defend' and 'Protection de son maître' or 'Cible mise au sol')
    return { ok = true, success = true, hold = hold, xp = xp }
end)

-- Défense automatique : quelqu'un s'en prend au maître
Ely.callback.register('elyzea_k9:defendTrigger', function(src, side, aggressor)
    local d, a = K9S.ActiveDog(src, side)
    if not d then return { ok = false } end
    if a.mode ~= 'defend' then return { ok = false } end
    if TooFast(src, 'defend', 4000) then return { ok = false } end
    local e = K9.Effects(d)
    local t, tp = ValidTarget(src, aggressor, e.defendRadius + 4.0)
    if not t then return { ok = false } end
    if side == 'police' and Config.Police.protectOnDutyPolice and IsCopOnDuty(t) then return { ok = false } end
    if GetVehiclePedIsIn(tp, false) ~= 0 then return { ok = false } end
    if not roll(e.defendChance) then return { ok = true, go = false } end
    Orders[d.id] = { id = 'defend', target = t, t = GetGameTimer(), attempts = 0 }
    return { ok = true, go = true, target = t, reaction = e.defendReactionMs }
end)

-- Intimidation / aboiements : la cible ressent la pression (côté victime)
Ely.callback.register('elyzea_k9:intimidate', function(src, side, target)
    local d, a, dog = K9S.ActiveDog(src, side)
    if not d then return { ok = false } end
    local o = Orders[d.id]
    target = tonumber(target)
    if not o or (o.id ~= 'intim' and o.id ~= 'bark') or o.target ~= target then return { ok = false } end
    Orders[d.id] = nil
    local tp = Ped(target)
    if not tp or Dist(GetEntityCoords(tp), GetEntityCoords(dog)) > 7.0 then return { ok = false, error = 'Le chien est trop loin de la personne.' } end
    local e = K9.Effects(d)
    local level = o.id == 'bark' and 1 or e.intimLevel
    local secs = o.id == 'bark' and 6 or e.intimSeconds
    TriggerClientEvent('elyzea_k9:client:intimidated', target, { dog = K9S.Active[d.id].netId, level = level, seconds = secs })
    local xp = 0
    if o.id == 'intim' then xp = MissionXp(src, d, 'intim', 'i' .. target, Config.MissionXp.intimidate, 'Intimidation') end
    return { ok = true, level = level, seconds = secs, xp = xp }
end)

-- ---------------------------------------------------------------------
--  Pistage : position (bruitée selon le niveau) de la personne pistée
-- ---------------------------------------------------------------------
Ely.callback.register('elyzea_k9:trackPoint', function(src, side)
    local d, a, dog = K9S.ActiveDog(src, side)
    if not d then return { ok = false, error = a } end
    local o = Orders[d.id]
    if not o or o.id ~= 'track' then return { ok = false, error = 'Aucune piste en cours.' } end
    local e = K9.Effects(d)
    if TooFast(src, 'track', math.max(800, e.trackRefresh - 600)) then return { ok = true, wait = true } end
    if GetGameTimer() - o.t > Config.Track.seconds * 1000 then Orders[d.id] = nil return { ok = true, lost = true, reason = 'time' } end
    local tp = Ped(o.target)
    if not tp then Orders[d.id] = nil return { ok = true, lost = true, reason = 'gone' } end
    local c, dc = GetEntityCoords(tp), GetEntityCoords(dog)
    local dist = Dist(c, dc)
    if dist > Config.Track.maxDistance then Orders[d.id] = nil return { ok = true, lost = true, reason = 'far' } end
    if dist <= Config.Track.foundDistance then
        Orders[d.id] = nil
        local xp = MissionXp(src, d, 'found', 'k' .. o.target, Config.MissionXp.trackFound, 'Personne retrouvée par pistage')
        return { ok = true, found = true, x = c.x, y = c.y, z = c.z, target = o.target, xp = xp }
    end
    -- en véhicule rapide, la piste se perd vite ; sinon petite chance de perdre la piste selon le niveau
    local veh = GetVehiclePedIsIn(tp, false)
    if veh ~= 0 and GetEntitySpeed(veh) > 12.0 and roll(0.5) then Orders[d.id] = nil return { ok = true, lost = true, reason = 'vehicle' } end
    if roll((1 - e.trackChance) * 0.12) then Orders[d.id] = nil return { ok = true, lost = true, reason = 'scent' } end
    local err = e.trackError
    local ang = math.random() * math.pi * 2
    local r = math.random() * err
    return { ok = true, x = c.x + math.cos(ang) * r, y = c.y + math.sin(ang) * r, z = c.z, refresh = e.trackRefresh }
end)

-- Ordre interrompu par le maître (nouvel ordre, annulation)
RegisterNetEvent('elyzea_k9:server:cancel', function(side)
    local src = source
    local d = K9S.Load(K9S.Cid(src), side)
    if d and K9S.Active[d.id] and K9S.Active[d.id].src == src then
        Orders[d.id] = nil
        K9S.Active[d.id].mode = 'follow'
    end
end)
RegisterNetEvent('elyzea_k9:server:mode', function(side, mode)
    local src = source
    local d = K9S.Load(K9S.Cid(src), side)
    if d and K9S.Active[d.id] and K9S.Active[d.id].src == src and (mode == 'follow' or mode == 'defend' or mode == 'stay') then K9S.Active[d.id].mode = mode end
end)

-- Nettoyage régulier de l'anti-farm
CreateThread(function()
    while true do
        Wait(10 * 60 * 1000)
        local t = os.time()
        for k, v in pairs(Recent) do if t - v > Config.MissionXp.sameTargetMinutes * 60 then Recent[k] = nil end end
    end
end)
