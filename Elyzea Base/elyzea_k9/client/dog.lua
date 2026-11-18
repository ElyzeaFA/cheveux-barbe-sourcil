-- =====================================================================
--  ELYZEA K9 - CLIENT : le chien (apparition, suivi, animations, ordres)
--  Le maître crée l'entité réseau (après l'accord du serveur) et en garde
--  le contrôle : les autres joueurs voient le chien normalement.
--  Déplacements : tâches natives (navigation), jamais de téléportation
--  pendant un ordre ; replacement seulement s'il est perdu hors de l'écran.
-- =====================================================================
local REL = joaat('ELY_K9')
CreateThread(function() AddRelationshipGroup('ELY_K9') end)

-- Animations (plusieurs essais : scénarios puis animations ; tous les grands chiens partagent le squelette « rottweiler »)
local ANIM = {
    sit = { scen = { 'WORLD_DOG_SITTING_ROTTWEILER', 'WORLD_DOG_SITTING_SHEPHERD', 'WORLD_DOG_SITTING_RETRIEVER' }, anim = { 'creatures@rottweiler@amb@world_dog_sitting@base', 'base' } },
    lie = { anim = { 'creatures@rottweiler@amb@sleep_in_kennel@', 'sleep_in_kennel' } },
    bark = { anim = { 'creatures@rottweiler@amb@world_dog_barking@idle_a', 'idle_a' }, scen = { 'WORLD_DOG_BARKING_ROTTWEILER', 'WORLD_DOG_BARKING_SHEPHERD', 'WORLD_DOG_BARKING_RETRIEVER' } },
    indicate = { anim = { 'creatures@rottweiler@indication@', 'indicate_high' } },
    sniff = { anim = { 'creatures@rottweiler@indication@', 'indicate_low' } },
    ahead = { anim = { 'creatures@rottweiler@indication@', 'indicate_ahead' } },
    beg = { anim = { 'creatures@rottweiler@tricks@', 'beg_loop' } },
    paw = { anim = { 'creatures@rottweiler@tricks@', 'paw_right_loop' } },
    petDog = { anim = { 'creatures@rottweiler@tricks@', 'petting_chop' } },
    petPlayer = { anim = { 'creatures@rottweiler@tricks@', 'petting_franklin' } },
}
C.ANIM = ANIM

-- Joue une pose (renvoie true si une animation a vraiment démarré). loop = garde la pose.
function C.Pose(ped, name, ms, loop)
    local a = ANIM[name]
    if not a or not DoesEntityExist(ped) then return false end
    if a.anim and C.LoadDict(a.anim[1]) then
        TaskPlayAnim(ped, a.anim[1], a.anim[2], 4.0, -4.0, ms or -1, loop and 1 or 0, 0.0, false, false, false)
        Wait(250)
        if IsEntityPlayingAnim(ped, a.anim[1], a.anim[2], 3) then return true end
    end
    for _, sc in ipairs(a.scen or {}) do
        TaskStartScenarioInPlace(ped, sc, 0, true)
        Wait(500)
        if IsPedUsingScenario(ped, sc) or IsPedUsingAnyScenario(ped) then return true end
    end
    return false
end

-- Sons (vocalisations d'animal ; le scénario d'aboiement en joue aussi)
function C.Vocal(ped, what)
    if PlayAnimalVocalization then PlayAnimalVocalization(ped, 3, what or 'BARK') end
end

-- Aboiements répétés (ms), face à une position
function C.BarkAt(ped, pos, ms)
    if pos then TaskTurnPedToFaceCoord(ped, pos.x, pos.y, pos.z, 700) Wait(600) end
    C.Pose(ped, 'bark', ms or 4000, false)
    local t = GetGameTimer() + (ms or 4000)
    while GetGameTimer() < t and C.dog and C.dog.ped == ped do
        C.Vocal(ped, 'BARK')
        Wait(1100)
    end
end

-- ---------------------------------------------------------------------
--  Sortir / ranger
-- ---------------------------------------------------------------------
local spawning = false
function C.SpawnDog(side)
    if spawning then return end
    if C.dog then
        if C.dog.side == side then return C.Notify(('%s est déjà avec toi.'):format(C.dog.name), 'inform') end
        C.StoreDog()
        Wait(600)
    end
    spawning = true
    local ok, res = Ely.callback.await('elyzea_k9:requestSpawn', false, side)
    if not ok then spawning = false return C.Notify(res or 'Impossible de sortir ton chien.', 'error') end
    local hash = C.LoadModel(res.model)
    if not hash then
        spawning = false
        return C.Notify(('Modèle « %s » introuvable sur ton jeu. Préviens le staff.'):format(res.model), 'error')
    end
    local me = PlayerPedId()
    local p = GetOffsetFromEntityInWorldCoords(me, 0.8, -1.2, 0.0)
    local z = C.Ground(p.x, p.y, p.z) or (GetEntityCoords(me).z - 1.0)
    local ped = CreatePed(28, hash, p.x, p.y, z, GetEntityHeading(me), true, true)
    SetModelAsNoLongerNeeded(hash)
    local t = GetGameTimer() + 3000
    while (not ped or ped == 0 or not NetworkGetEntityIsNetworked(ped)) and GetGameTimer() < t do Wait(0) end
    if not ped or ped == 0 or not DoesEntityExist(ped) then spawning = false return C.Notify('Création du chien impossible.', 'error') end
    local netId = PedToNet(ped)
    SetNetworkIdCanMigrate(netId, false)
    SetNetworkIdExistsOnAllMachines(netId, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)      -- se bat jusqu'au bout quand on le lui ordonne
    SetPedCombatAttributes(ped, 17, false)
    SetPedRelationshipGroupHash(ped, REL)
    SetRelationshipBetweenGroups(0, REL, `PLAYER`)
    SetPedKeepTask(ped, true)
    SetPedCanBeTargetted(ped, true)
    SetPedDiesWhenInjured(ped, false)
    SetEntityInvincible(ped, Config.Health.invincible == true)
    local e = res.effects
    local maxH = math.floor(300 * (e.healthMul or 1.0))
    SetEntityMaxHealth(ped, maxH)
    SetEntityHealth(ped, math.floor(100 + (maxH - 100) * math.max(10, res.dog.health or 100) / 100))
    local blip = AddBlipForEntity(ped)
    SetBlipSprite(blip, 442)
    SetBlipColour(blip, side == 'police' and 38 or 27)
    SetBlipScale(blip, 0.7)
    BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(('K9 · %s'):format(res.dog.name)) EndTextCommandSetBlipName(blip)
    C.dog = { side = side, id = res.dog.id, ped = ped, netId = netId, name = res.dog.name, effects = e, mode = 'follow', task = nil, blip = blip,
        last = GetEntityCoords(ped), lastT = GetGameTimer(), stuck = 0, hp = res.dog.health or 100, hpT = 0, busy = false }
    TriggerServerEvent('elyzea_k9:server:spawned', res.token, netId)
    spawning = false
    -- arrivée : le chien vient se mettre au pied
    C.Notify(('%s est avec toi. %s : menu · %s : ciblage.'):format(res.dog.name, Config.Keys.menu, Config.Keys.target), 'success')
    C.StartLoop()
end

local function cleanup()
    local d = C.dog
    if not d then return end
    C.dog = nil
    if d.blip and DoesBlipExist(d.blip) then RemoveBlip(d.blip) end
    if d.ped and DoesEntityExist(d.ped) then
        if IsEntityAttached(d.ped) then DetachEntity(d.ped, true, false) end
        if NetworkHasControlOfEntity(d.ped) then DeleteEntity(d.ped) end
    end
    if C.StopTarget then C.StopTarget() end
    C.HudHide()
end
C.Cleanup = cleanup

function C.StoreDog()
    local d = C.dog
    if not d then return end
    -- le chien rejoint son maître avant de partir (pas de disparition sous les yeux s'il est loin)
    if DoesEntityExist(d.ped) and not IsEntityAttached(d.ped) and #(GetEntityCoords(d.ped) - GetEntityCoords(PlayerPedId())) < 25.0 then
        d.busy = true
        ClearPedTasks(d.ped)
        TaskGoToEntity(d.ped, PlayerPedId(), 4000, 1.2, 2.0, 1073741824, 0)
        Wait(2500)
    end
    Ely.callback.await('elyzea_k9:store', false, d.side)
    cleanup()
end

RegisterNetEvent('elyzea_k9:client:despawned', function(side) if C.dog and C.dog.side == side then cleanup() end end)
RegisterNetEvent('elyzea_k9:client:renamed', function(side, name) if C.dog and C.dog.side == side then C.dog.name = name end end)
RegisterNetEvent('elyzea_k9:client:effects', function(side, e) if C.dog and C.dog.side == side then C.dog.effects = e end end)
AddEventHandler('onResourceStop', function(r) if r == GetCurrentResourceName() then cleanup() end end)
RegisterNetEvent('elyzea:client:playerUnloaded', function() cleanup() end)

-- ---------------------------------------------------------------------
--  Récompense (interaction avec le maître)
-- ---------------------------------------------------------------------
function C.Reward(silent)
    local d = C.dog
    if not d or not DoesEntityExist(d.ped) then return end
    local me = PlayerPedId()
    if IsEntityAttached(d.ped) then return end
    d.busy = true
    ClearPedTasks(d.ped)
    if #(GetEntityCoords(d.ped) - GetEntityCoords(me)) > 2.0 then
        TaskGoToEntity(d.ped, me, 4000, 1.0, 2.0, 1073741824, 0)
        local t = GetGameTimer() + 4000
        while GetGameTimer() < t and #(GetEntityCoords(d.ped) - GetEntityCoords(me)) > 1.6 do Wait(100) end
    end
    TaskTurnPedToFaceEntity(me, d.ped, 800)
    TaskTurnPedToFaceEntity(d.ped, me, 800)
    Wait(800)
    local pa = ANIM.petPlayer.anim
    if C.LoadDict(pa[1]) then TaskPlayAnim(me, pa[1], pa[2], 3.0, 3.0, 3500, 1, 0.0, false, false, false) end
    if not C.Pose(d.ped, 'petDog', 3500, false) then C.Pose(d.ped, 'beg', 3000, false) end
    Wait(3300)
    ClearPedTasks(me)
    if C.dog == d then d.busy = false d.task = nil end
    if not silent then C.Notify(('%s est content.'):format(d.name), 'success') end
end

-- ---------------------------------------------------------------------
--  Véhicules (le chien monte avec son maître, places arrière puis avant)
-- ---------------------------------------------------------------------
local SEATS = { { seat = 1, bone = 'seat_dside_r' }, { seat = 2, bone = 'seat_pside_r' }, { seat = 0, bone = 'seat_pside_f' } }
local function canCarry(veh)
    local m = GetEntityModel(veh)
    if IsThisModelABike(m) or IsThisModelABicycle(m) or IsThisModelAQuadbike(m) or IsThisModelABoat(m) or IsThisModelAHeli(m) or IsThisModelAPlane(m) then return false end
    return GetVehicleMaxNumberOfPassengers(veh) >= 1
end
local function board(d, veh)
    for _, s in ipairs(SEATS) do
        if s.seat <= GetVehicleMaxNumberOfPassengers(veh) - 1 and IsVehicleSeatFree(veh, s.seat) then
            local bone = GetEntityBoneIndexByName(veh, s.bone)
            if bone ~= -1 then
                ClearPedTasksImmediately(d.ped)
                AttachEntityToEntity(d.ped, veh, bone, 0.0, 0.0, 0.32, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                d.veh, d.seat, d.task = veh, s.seat, 'vehicle'
                C.Pose(d.ped, 'sit', -1, true)
                return true
            end
        end
    end
    return false
end
local function unboard(d)
    local veh, seat = d.veh, d.seat
    d.veh, d.seat, d.task = nil, nil, nil
    if not DoesEntityExist(d.ped) then return end
    DetachEntity(d.ped, true, false)
    local p = DoesEntityExist(veh) and GetOffsetFromEntityInWorldCoords(veh, seat == 1 and -1.6 or 1.6, -0.6, 0.0) or GetEntityCoords(PlayerPedId())
    local z = C.Ground(p.x, p.y, p.z + 1.0) or p.z
    SetEntityCoords(d.ped, p.x, p.y, z, false, false, false, false)
    ClearPedTasksImmediately(d.ped)
end

-- ---------------------------------------------------------------------
--  Boucle de comportement (une seule, 300 ms, seulement quand le chien est sorti)
-- ---------------------------------------------------------------------
local function healthPct(ped)
    local max, h = GetEntityMaxHealth(ped), GetEntityHealth(ped)
    return math.max(0, math.min(100, (h - 100) / math.max(1, max - 100) * 100))
end
local function pace(owner, dist)
    local s = 1.0
    if IsPedSprinting(owner) then s = 3.0 elseif IsPedRunning(owner) then s = 2.0 end
    if dist > 7.0 then s = math.max(s, 2.0) end
    if dist > 14.0 then s = 3.0 end
    return s
end
local function replaceNear(d, owner)
    local p = GetOffsetFromEntityInWorldCoords(owner, 0.8, -1.6, 0.0)
    local z = C.Ground(p.x, p.y, p.z + 1.0)
    if not z then return end
    SetEntityCoords(d.ped, p.x, p.y, z, false, false, false, false)
    d.task, d.stuck = nil, 0
end

local function step(d, owner, now)
    local ped = d.ped
    local pos, opos = GetEntityCoords(ped), GetEntityCoords(owner)
    local dist = #(pos - opos)
    if IsEntityDead(ped) or GetEntityHealth(ped) <= 101 then
        if not d.deadSent then d.deadSent = true TriggerServerEvent('elyzea_k9:server:health', d.side, 0, true) end
        return
    end
    if now - d.hpT > 15000 then
        d.hpT = now
        local hp = math.floor(healthPct(ped))
        if math.abs(hp - d.hp) >= 3 then d.hp = hp TriggerServerEvent('elyzea_k9:server:health', d.side, hp, false) end
    end
    SetPedMoveRateOverride(ped, d.effects.speed or 1.0)
    if d.busy then return end
    -- véhicule du maître
    local oveh = GetVehiclePedIsIn(owner, false)
    if d.veh then
        if oveh ~= d.veh or not DoesEntityExist(d.veh) then unboard(d) end
        return
    end
    if oveh ~= 0 then
        if (d.mode == 'follow' or d.mode == 'defend') and canCarry(oveh) and #(pos - GetEntityCoords(oveh)) <= 9.0 then
            if d.task ~= 'toVehicle' then
                ClearPedTasks(ped)
                TaskGoToEntity(ped, oveh, -1, 1.8, 3.0, 1073741824, 0)
                d.task, d.taskT = 'toVehicle', now
            elseif #(pos - GetEntityCoords(oveh)) < 2.8 or now - d.taskT > 6000 then
                if GetEntitySpeed(oveh) < 3.0 and board(d, oveh) then return end
                d.task, d.taskT = 'toVehicle', now
            end
        elseif d.task ~= 'waitVehicle' and d.mode ~= 'sit' and d.mode ~= 'lie' and d.mode ~= 'stay' then
            ClearPedTasks(ped)
            TaskStandStill(ped, -1)
            d.task = 'waitVehicle'
        end
        return
    end
    if d.task == 'waitVehicle' or d.task == 'toVehicle' then d.task = nil end
    if IsEntityDead(owner) then
        if d.task ~= 'guard' then ClearPedTasks(ped) C.Pose(ped, 'sit', -1, true) d.task = 'guard' end
        return
    end
    if d.mode == 'stay' or d.mode == 'sit' or d.mode == 'lie' then return end
    -- suivre (au pied), côté gauche, allure du maître
    local speed = pace(owner, dist)
    if d.task ~= 'follow' or d.speed ~= speed then
        if not (d.task == 'follow' and now - (d.speedT or 0) < 1500) then
            TaskFollowToOffsetOfEntity(ped, owner, -0.9, -1.6, 0.0, speed, -1, 1.2, true)
            d.task, d.speed, d.speedT = 'follow', speed, now
        end
    end
    -- bloqué : nouveau chemin, puis (loin, hors de l'écran) replacé près du maître
    if now - d.lastT >= 4000 then
        local moved = #(pos - d.last)
        d.last, d.lastT = pos, now
        if dist > 6.0 and moved < 0.4 then
            d.stuck = d.stuck + 1
            if d.stuck == 1 then
                ClearPedTasks(ped)
                TaskGoToEntity(ped, owner, -1, 1.6, 3.0, 1073741824, 0)
                d.task = 'unstuck'
            elseif d.stuck >= 3 and dist > 20.0 and not IsEntityOnScreen(ped) then replaceNear(d, owner) end
        else
            d.stuck = 0
            if d.task == 'unstuck' then d.task = nil end
        end
    end
    if dist > 60.0 and not IsEntityOnScreen(ped) and not IsPedSwimming(owner) then replaceNear(d, owner) end
end

local running = false
function C.StartLoop()
    if running then return end
    running = true
    CreateThread(function()
        while C.dog do
            local d = C.dog
            if not DoesEntityExist(d.ped) then
                if NetworkDoesNetworkIdExist(d.netId) then d.ped = NetToPed(d.netId)
                else TriggerServerEvent('elyzea_k9:server:lost', d.side) cleanup() break end
            else
                if not NetworkHasControlOfEntity(d.ped) then NetworkRequestControlOfEntity(d.ped) end
                local ok, err = pcall(step, d, PlayerPedId(), GetGameTimer())
                if not ok and Config.Debug then print('[K9] ' .. tostring(err)) end
            end
            Wait(300)
        end
        running = false
    end)
end

-- ---------------------------------------------------------------------
--  Ordres
-- ---------------------------------------------------------------------
local function ready(d)
    if not d or not DoesEntityExist(d.ped) then C.Notify('Sors ton chien d\'abord.', 'error') return false end
    if d.veh then C.Notify(('%s est dans le véhicule.'):format(d.name), 'error') return false end
    return true
end

-- Refus visible : le chien hésite, regarde son maître et ne bouge pas
local function refuse(d, fear)
    d.busy = true
    ClearPedTasks(d.ped)
    TaskTurnPedToFaceEntity(d.ped, PlayerPedId(), 1000)
    Wait(900)
    if fear then C.Vocal(d.ped, 'WHINE') C.Pose(d.ped, 'lie', 2500, false) else C.Pose(d.ped, 'sit', 2000, false) end
    Wait(2000)
    if C.dog == d then d.busy, d.task = false, nil end
end

-- Tâche « au pied » après un ordre
local function heel(d)
    if C.dog ~= d then return end
    d.busy, d.task = false, nil
    if d.mode ~= 'defend' then d.mode = 'follow' end
    TriggerServerEvent('elyzea_k9:server:mode', d.side, d.mode)
end
C.Heel = heel

-- Fait le tour d'une entité en reniflant (points autour), ms au total
local function sniffAround(d, ent, ms, points)
    local ped = d.ped
    local t = GetGameTimer() + ms
    local i = 0
    while GetGameTimer() < t and C.dog == d do
        i = i + 1
        local p = points[(i - 1) % #points + 1]
        local w = GetOffsetFromEntityInWorldCoords(ent, p[1], p[2], 0.0)
        TaskGoStraightToCoord(ped, w.x, w.y, w.z, 1.0, 4000, GetEntityHeading(ent), 0.3)
        local tt = GetGameTimer() + 3500
        while GetGameTimer() < tt and #(GetEntityCoords(ped) - w) > 0.9 do Wait(100) end
        TaskTurnPedToFaceEntity(ped, ent, 600)
        Wait(500)
        C.Pose(ped, 'sniff', 1400, false)
        Wait(1300)
    end
end

-- Va au contact d'une entité (marche / course) ; renvoie true si arrivé
local function reach(d, ent, run, near, timeout)
    local ped = d.ped
    ClearPedTasks(ped)
    TaskGoToEntity(ped, ent, -1, near or 1.2, run and 3.0 or 1.6, 1073741824, 0)
    local t = GetGameTimer() + (timeout or 15000)
    while GetGameTimer() < t and C.dog == d and DoesEntityExist(ent) do
        if #(GetEntityCoords(ped) - GetEntityCoords(ent)) <= (near or 1.2) + 0.6 then return true end
        Wait(150)
    end
    return false
end

local function playerPed(sid) local pl = GetPlayerFromServerId(sid) return pl ~= -1 and GetPlayerPed(pl) or nil end

-- Exécution d'un ordre validé par le serveur
local Exec = {}
Exec.follow = function(d) d.mode = 'follow' ClearPedTasks(d.ped) heel(d) end
Exec.stay = function(d) d.mode, d.task = 'stay', 'stay' ClearPedTasks(d.ped) TaskStandStill(d.ped, -1) TriggerServerEvent('elyzea_k9:server:mode', d.side, 'stay') end
Exec.sit = function(d) d.mode, d.task = 'sit', 'sit' ClearPedTasks(d.ped) C.Pose(d.ped, 'sit', -1, true) end
Exec.lie = function(d) d.mode, d.task = 'lie', 'lie' ClearPedTasks(d.ped) C.Pose(d.ped, 'lie', -1, true) end
Exec.come = function(d)
    d.mode, d.busy = 'follow', true
    if reach(d, PlayerPedId(), true, 1.0, 15000) then C.Pose(d.ped, 'sit', 1800, false) Wait(1600) end
    heel(d)
end
Exec.defend = function(d)
    d.mode = 'defend'
    ClearPedTasks(d.ped)
    d.busy, d.task = false, nil
    C.Notify(('%s te protège : il interviendra si on s\'en prend à toi.'):format(d.name), 'success')
    TriggerServerEvent('elyzea_k9:server:mode', d.side, 'defend')
end

Exec.sniffp = function(d, r)
    local tp = playerPed(r.target)
    if not tp then return heel(d) end
    d.busy = true
    if not reach(d, tp, false, 1.0, 12000) then C.Notify(('%s n\'arrive pas à approcher.'):format(d.name), 'error') TriggerServerEvent('elyzea_k9:server:cancel', d.side) return heel(d) end
    sniffAround(d, tp, r.sniffMs or 6000, { { 0.0, -0.9 }, { 0.7, 0.0 }, { 0.0, 0.8 }, { -0.7, 0.0 } })
    local res = Ely.callback.await('elyzea_k9:sniffPerson', false, d.side, r.target)
    if C.dog ~= d then return end
    if res and res.ok and res.marked then
        -- marquage passif : assis face à la personne, aboiement court
        TaskTurnPedToFaceEntity(d.ped, tp, 700) Wait(700)
        C.Pose(d.ped, 'sit', 3500, false) C.Vocal(d.ped, 'BARK')
        C.Notify(('%s MARQUE la personne : odeur de stupéfiants.%s'):format(d.name, res.xp and res.xp > 0 and (' (+%d XP)'):format(res.xp) or ''), 'success')
        Wait(3300)
    elseif res and res.ok then
        C.Notify(('%s ne marque pas : rien de détecté.'):format(d.name), 'inform')
    elseif res and res.error then C.Notify(res.error, 'error') end
    heel(d)
end

Exec.sniffv = function(d, r)
    local veh = NetToVeh(r.target)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return heel(d) end
    d.busy = true
    local mn, mx = GetModelDimensions(GetEntityModel(veh))
    local l, w = mx.y + 0.6, mx.x + 0.6
    local pts = { { 0.0, -l }, { w, -l * 0.4 }, { w, l * 0.4 }, { 0.0, l }, { -w, l * 0.4 }, { -w, -l * 0.4 } }
    if not reach(d, veh, false, math.max(l, w), 12000) then C.Notify(('%s n\'arrive pas à approcher du véhicule.'):format(d.name), 'error') TriggerServerEvent('elyzea_k9:server:cancel', d.side) return heel(d) end
    sniffAround(d, veh, (r.sniffMs or 6000) + 3000, pts)
    local res = Ely.callback.await('elyzea_k9:sniffVehicle', false, d.side, r.target)
    if C.dog ~= d then return end
    if res and res.ok and res.marked then
        local where = { trunk = 'le coffre', cabin = 'l\'habitacle', hidden = 'un endroit inhabituel du véhicule (cachette ?)' }
        local first = res.spots[1]
        local spot = first == 'trunk' and { 0.0, -l } or (first == 'cabin' and { w, 0.0 } or { -w, 0.2 })
        local p = GetOffsetFromEntityInWorldCoords(veh, spot[1], spot[2], 0.0)
        TaskGoStraightToCoord(d.ped, p.x, p.y, p.z, 1.0, 4000, 0.0, 0.3)
        Wait(2500)
        TaskTurnPedToFaceEntity(d.ped, veh, 700) Wait(700)
        if not C.Pose(d.ped, 'indicate', 3000, false) then C.Pose(d.ped, 'sit', 3000, false) end
        C.Vocal(d.ped, 'BARK')
        local list = {}
        for _, s in ipairs(res.spots) do list[#list + 1] = where[s] or s end
        C.Notify(('%s MARQUE %s.%s'):format(d.name, table.concat(list, ', '), res.xp and res.xp > 0 and (' (+%d XP)'):format(res.xp) or ''), 'success')
        Wait(3000)
    elseif res and res.ok then
        C.Notify(('%s ne marque pas le véhicule.'):format(d.name), 'inform')
    elseif res and res.error then C.Notify(res.error, 'error') end
    heel(d)
end

Exec.search = function(d, r)
    d.busy = true
    local c = GetEntityCoords(d.ped)
    ClearPedTasks(d.ped)
    TaskWanderInArea(d.ped, c.x, c.y, c.z, 10.0, 1.0, 1.0)
    C.Hud({ show = true, title = 'Fouille de zone', text = ('%s quadrille la zone…'):format(d.name) })
    Wait(r.sniffMs or 6000)
    local res = Ely.callback.await('elyzea_k9:searchZone', false, d.side)
    if C.dog ~= d then return end
    if not res or not res.ok then C.HudHide() if res and res.error then C.Notify(res.error, 'error') end return heel(d) end
    if #res.spots == 0 then
        C.HudHide()
        C.Notify(('%s n\'a rien trouvé dans la zone.'):format(d.name), 'inform')
        return heel(d)
    end
    local label = { person = 'une personne', drugs = 'des stupéfiants au sol', vehicle = 'un véhicule (coffre)' }
    for i, s in ipairs(res.spots) do
        if C.dog ~= d then return end
        C.Hud({ show = true, title = 'Fouille de zone', text = ('%s : piste %d / %d'):format(d.name, i, #res.spots) })
        local p = vector3(s.x, s.y, s.z)
        ClearPedTasks(d.ped)
        TaskFollowNavMeshToCoord(d.ped, p.x, p.y, p.z, 2.0, 15000, 1.5, true, 0.0)
        local t = GetGameTimer() + 15000
        while GetGameTimer() < t and #(GetEntityCoords(d.ped) - p) > 2.2 and C.dog == d do Wait(150) end
        if s.kind == 'person' then C.BarkAt(d.ped, p, 3500)
        else
            TaskTurnPedToFaceCoord(d.ped, p.x, p.y, p.z, 600) Wait(600)
            if not C.Pose(d.ped, 'indicate', 2800, false) then C.Pose(d.ped, 'sit', 2800, false) end
            C.Vocal(d.ped, 'BARK')
            Wait(2600)
        end
        C.Notify(('%s marque %s%s.'):format(d.name, label[s.kind] or '?', s.drugs and ' (odeur de stupéfiants)' or ''), 'success')
    end
    C.HudHide()
    if res.xp and res.xp > 0 then C.Notify(('Fouille de zone : +%d XP.'):format(res.xp), 'success') end
    heel(d)
end

-- Intimidation / aboiements sur une personne
local function pressure(d, r, kind)
    local tp = playerPed(r.target)
    if not tp then return heel(d) end
    d.busy = true
    reach(d, tp, true, 3.0, 12000)
    local res = Ely.callback.await('elyzea_k9:intimidate', false, d.side, r.target)
    if C.dog ~= d then return end
    if not res or not res.ok then if res and res.error then C.Notify(res.error, 'error') end return heel(d) end
    local t = GetGameTimer() + res.seconds * 1000
    while GetGameTimer() < t and C.dog == d do
        if #(GetEntityCoords(d.ped) - GetEntityCoords(tp)) > 3.5 then TaskGoToEntity(d.ped, tp, 2000, 2.5, 3.0, 1073741824, 0) Wait(800) end
        TaskTurnPedToFaceEntity(d.ped, tp, 500)
        C.Pose(d.ped, 'bark', 1200, false)
        C.Vocal(d.ped, (kind == 'intim' and math.random() < 0.4) and 'GROWL' or 'BARK')
        Wait(1100)
    end
    heel(d)
end
Exec.bark = function(d, r) pressure(d, r, 'bark') end
Exec.intim = function(d, r) pressure(d, r, 'intim') end

-- Attaque / mise au sol : poursuite, contact vérifié par le serveur, maintien
local function assault(d, target, kind, chaseSeconds)
    local tp = playerPed(target)
    if not tp then return heel(d) end
    d.busy = true
    local ped = d.ped
    ClearPedTasks(ped)
    C.Vocal(ped, 'GROWL')
    TaskGoToEntity(ped, tp, -1, 0.8, 3.0, 1073741824, 0)
    local deadline = GetGameTimer() + (chaseSeconds or Config.Attack.chaseSeconds) * 1000
    local lastTry = 0
    while GetGameTimer() < deadline and C.dog == d do
        if not DoesEntityExist(tp) then break end
        local dist = #(GetEntityCoords(ped) - GetEntityCoords(tp))
        if dist <= Config.Attack.contactDistance and GetGameTimer() - lastTry > 900 then
            lastTry = GetGameTimer()
            local res = Ely.callback.await('elyzea_k9:contact', false, d.side, target)
            if C.dog ~= d then return end
            if res and res.ok and res.success then
                -- morsure / maintien (les dégâts natifs sont coupés : la victime applique des dégâts contrôlés)
                TaskCombatPed(ped, tp, 0, 16)
                local hold = (res.hold or 0) > 0 and res.hold or 2
                C.Notify(('%s %s.%s'):format(d.name, (res.hold or 0) > 0 and 'maîtrise la cible au sol' or 'fait tomber la cible',
                    res.xp and res.xp > 0 and (' (+%d XP)'):format(res.xp) or ''), 'success')
                Wait(hold * 1000)
                ClearPedTasks(ped)
                C.Vocal(ped, 'BARK')
                return heel(d)
            elseif res and res.gaveUp then
                C.Notify(('%s n\'arrive pas à saisir la cible et abandonne.'):format(d.name), 'error')
                break
            elseif res and res.error then C.Notify(res.error, 'error') break end
            TaskGoToEntity(ped, tp, -1, 0.8, 3.0, 1073741824, 0)
        elseif dist > 2.5 and not GetIsTaskActive(ped, 35) then
            TaskGoToEntity(ped, tp, -1, 0.8, 3.0, 1073741824, 0)
        end
        Wait(150)
    end
    TriggerServerEvent('elyzea_k9:server:cancel', d.side)
    ClearPedTasks(ped)
    heel(d)
end
C.Assault = assault
Exec.attack = function(d, r) assault(d, r.target, 'attack', r.chase) end
Exec.takedown = function(d, r) assault(d, r.target, 'takedown', r.chase) end

-- Pistage : le chien suit la piste (positions envoyées par le serveur), le maître le suit
Exec.track = function(d, r)
    d.busy = true
    local ped = d.ped
    C.Pose(ped, 'sniff', 1500, false)
    Wait(1400)
    C.Hud({ show = true, title = 'Pistage', text = ('%s a pris la piste. Suis-le !'):format(d.name) })
    local nextPoll = 0
    while C.dog == d do
        if GetGameTimer() >= nextPoll then
            local res = Ely.callback.await('elyzea_k9:trackPoint', false, d.side)
            if C.dog ~= d then return end
            if not res or not res.ok then C.HudHide() if res and res.error then C.Notify(res.error, 'error') end break end
            if res.found then
                C.HudHide()
                local tp = playerPed(res.target)
                local p = vector3(res.x, res.y, res.z)
                if tp then TaskGoToEntity(ped, tp, 6000, 2.5, 3.0, 1073741824, 0) else TaskFollowNavMeshToCoord(ped, p.x, p.y, p.z, 3.0, 6000, 2.5, true, 0.0) end
                Wait(3500)
                C.BarkAt(ped, tp and GetEntityCoords(tp) or p, 5000)
                C.Notify(('%s a retrouvé la personne !%s'):format(d.name, res.xp and res.xp > 0 and (' (+%d XP)'):format(res.xp) or ''), 'success')
                break
            elseif res.lost then
                C.HudHide()
                local why = { time = 'la piste est trop ancienne', gone = 'la personne a disparu', far = 'la personne est trop loin', vehicle = 'la personne est partie en véhicule', scent = 'il a perdu l\'odeur' }
                C.Pose(ped, 'sniff', 2000, false)
                C.Notify(('%s perd la piste : %s.'):format(d.name, why[res.reason] or 'piste perdue'), 'error')
                break
            elseif not res.wait then
                TaskFollowNavMeshToCoord(ped, res.x, res.y, res.z, 2.6, -1, 2.0, true, 0.0)
                nextPoll = GetGameTimer() + (res.refresh or 4000)
                -- truffe au sol de temps en temps
                if math.random() < 0.35 then Wait(400) C.Pose(ped, 'sniff', 900, false) Wait(800) TaskFollowNavMeshToCoord(ped, res.x, res.y, res.z, 2.6, -1, 2.0, true, 0.0) end
            else
                nextPoll = GetGameTimer() + 1000
            end
        end
        Wait(200)
    end
    heel(d)
end

-- Donne un ordre (target : id serveur du joueur ou netId du véhicule)
function C.Order(orderId, target)
    local d = C.dog
    if not ready(d) then return end
    if d.ex then return C.Notify('Termine ton exercice d\'abord.', 'error') end
    local r = Ely.callback.await('elyzea_k9:order', false, d.side, orderId, target)
    if C.dog ~= d then return end
    if not r or not r.ok then return C.Notify(r and r.error or 'Ordre impossible.', 'error') end
    -- ordre de la voix : le maître montre / siffle
    local me = PlayerPedId()
    if C.LoadDict('gestures@m@standing@casual') and not IsPedInAnyVehicle(me, false) then
        TaskPlayAnim(me, 'gestures@m@standing@casual', orderId == 'come' and 'gesture_come_here_soft' or 'gesture_point', 4.0, -4.0, 1200, 48, 0.0, false, false, false)
    end
    d.busy = true
    if r.hesitate and r.hesitate > 0 then Wait(r.hesitate) end
    if C.dog ~= d then return end
    if not r.obey then
        C.Notify(r.fear and ('%s a peur : la cible est armée.'):format(d.name) or ('%s hésite et n\'obéit pas. Redonne l\'ordre.'):format(d.name), 'error')
        return refuse(d, r.fear)
    end
    d.busy = false
    local fn = Exec[orderId]
    if fn then fn(d, r) else heel(d) end
end

-- Défense automatique (ordre « Défends-moi ») et grognement face à une menace armée (gangs)
CreateThread(function()
    while true do
        local d = C.dog
        local wait = 2500   -- sans chien sorti : presque rien
        if d and DoesEntityExist(d.ped) and not d.veh then
            wait = 400
            local me = PlayerPedId()
            local mc = GetEntityCoords(me)
            local e = d.effects
            for _, pl in ipairs(GetActivePlayers()) do
                if pl ~= PlayerId() then
                    local op = GetPlayerPed(pl)
                    local oc = GetEntityCoords(op)
                    local dist = #(oc - mc)
                    if dist <= e.defendRadius then
                        local attacked = HasEntityBeenDamagedByEntity(me, op, true) or (IsPedShooting(op) and dist <= e.defendRadius)
                        if attacked and d.mode == 'defend' and not d.busy then
                            ClearEntityLastDamageEntity(me)
                            local sid = GetPlayerServerId(pl)
                            CreateThread(function()
                                local r = Ely.callback.await('elyzea_k9:defendTrigger', false, d.side, sid)
                                if r and r.ok and r.go and C.dog == d then
                                    d.busy = true
                                    Wait(r.reaction or 800)
                                    C.Notify(('%s s\'interpose !'):format(d.name), 'inform')
                                    C.Assault(d, sid, 'defend', 15)
                                end
                            end)
                            break
                        elseif Config.Defend.growlArmed and d.side == 'gang' and not d.busy and GetSelectedPedWeapon(op) ~= `WEAPON_UNARMED`
                            and (not d.growlT or GetGameTimer() - d.growlT > 12000) then
                            d.growlT = GetGameTimer()
                            TaskTurnPedToFaceEntity(d.ped, op, 800)
                            C.Vocal(d.ped, 'GROWL')
                        end
                    end
                end
            end
        end
        Wait(wait)
    end
end)
