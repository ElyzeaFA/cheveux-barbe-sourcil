-- =====================================================================
--  ELYZEA K9 - CLIENT : exercices d'entraînement (en jeu, pas dans un menu)
--  Le résultat dépend du joueur (réactivité, suivi) ET des compétences du
--  chien (obéissance, flair, pistage, attaque…). Échap : abandonner.
-- =====================================================================
local NPC_MODELS = { police = 's_m_m_security_01', gang = 'g_m_y_mexgoon_01' }
local spawned = {}   -- entités créées pour l'exercice (nettoyées à la fin)

local function keyHud(ex, text, progress, extra)
    C.Hud({ show = true, title = ex.label, text = text, progress = progress, extra = extra, abort = 'Échap : abandonner' })
end
local function aborted()
    DisableControlAction(0, 200, true) DisableControlAction(0, 322, true)
    return IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 322)
end
local function cleanupEx()
    for _, e in ipairs(spawned) do if DoesEntityExist(e) then DeleteEntity(e) end end
    spawned = {}
    C.HudHide()
end
local function groundAt(x, y, z) return C.Ground(x, y, z + 2.0) or z end
local function spawnNpc(side, pos, heading)
    local hash = C.LoadModel(NPC_MODELS[side] or 's_m_m_security_01')
    if not hash then return nil end
    local npc = CreatePed(4, hash, pos.x, pos.y, pos.z, heading or 0.0, true, true)
    SetModelAsNoLongerNeeded(hash)
    SetEntityAsMissionEntity(npc, true, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    SetEntityInvincible(npc, true)
    SetPedCanRagdollFromPlayerImpact(npc, false)
    SetPedFleeAttributes(npc, 0, false)
    spawned[#spawned + 1] = npc
    return npc
end
local function pointAround(origin, minR, maxR)
    for _ = 1, 12 do
        local a = math.random() * math.pi * 2
        local r = minR + math.random() * (maxR - minR)
        local x, y = origin.x + math.cos(a) * r, origin.y + math.sin(a) * r
        local z = C.Ground(x, y, origin.z)
        if z and math.abs(z - origin.z) < 4.0 then return vector3(x, y, z) end
    end
    return vector3(origin.x + minR, origin.y, origin.z)
end

local EX = {}

-- 1. Obéissance : 6 ordres affichés, le maître les donne (E), le chien obéit… ou pas
EX.obey = function(d, ex, e)
    local cmds = { { 'sit', 'Assis' }, { 'lie', 'Couché' }, { 'stay', 'Reste' }, { 'come', 'Au pied' } }
    local ok, rounds = 0, 6
    for i = 1, rounds do
        local c = cmds[math.random(#cmds)]
        local deadline = GetGameTimer() + 5000
        local given = false
        while GetGameTimer() < deadline do
            keyHud(ex, ('Ordre %d / %d : « %s » — appuie sur E pour le donner'):format(i, rounds, c[2]), (i - 1) / rounds, ('Réussis : %d'):format(ok))
            if aborted() then return nil end
            if IsControlJustPressed(0, 38) then given = true break end
            Wait(0)
        end
        if given then
            Wait(e.hesitateMs)
            if math.random() < e.obeyChance then
                ok = ok + 1
                if c[1] == 'come' then
                    TaskGoToEntity(d.ped, PlayerPedId(), 4000, 1.0, 2.0, 1073741824, 0) Wait(2200) C.Pose(d.ped, 'sit', 1800, false)
                elseif c[1] == 'stay' then ClearPedTasks(d.ped) TaskStandStill(d.ped, 2500) else C.Pose(d.ped, c[1], 2500, false) end
                C.Notify(('%s : « %s » réussi.'):format(d.name, c[2]), 'success')
            else
                TaskTurnPedToFaceEntity(d.ped, PlayerPedId(), 1000)
                C.Notify(('%s hésite et ne fait pas « %s ».'):format(d.name, c[2]), 'error')
            end
        else
            C.Notify('Trop tard : donne les ordres franchement.', 'error')
        end
        Wait(2600)
        ClearPedTasks(d.ped)
    end
    return ok / rounds
end

-- 2. Reniflage : 3 leurres cachés + 2 fausses pistes ; le chien marque, le maître valide (E près du leurre)
EX.sniff = function(d, ex, e)
    local me = GetEntityCoords(PlayerPedId())
    local hash = C.LoadModel('prop_paper_bag_small')
    local lures, decoys = {}, {}
    for i = 1, 3 do
        local p = pointAround(me, 8.0, 20.0)
        local obj = hash and CreateObject(hash, p.x, p.y, p.z, false, false, false) or nil
        if obj then PlaceObjectOnGroundProperly(obj) FreezeEntityPosition(obj, true) spawned[#spawned + 1] = obj end
        lures[i] = { pos = p, found = false }
    end
    for i = 1, 2 do decoys[i] = pointAround(me, 6.0, 18.0) end
    keyHud(ex, 'Trois leurres sont cachés autour de toi. Appuie sur E pour lancer « Cherche ! ».', 0)
    while not IsControlJustPressed(0, 38) do if aborted() then return nil end Wait(0) end
    local found, t0 = 0, GetGameTimer()
    local deadline = t0 + ex.seconds * 1000
    local queue = {}
    for _, l in ipairs(lures) do
        if math.random() > e.sniffChance and #decoys > 0 then queue[#queue + 1] = { pos = table.remove(decoys), decoy = true } end
        queue[#queue + 1] = { pos = l.pos, lure = l }
    end
    for _, q in ipairs(queue) do
        if GetGameTimer() > deadline then break end
        TaskFollowNavMeshToCoord(d.ped, q.pos.x, q.pos.y, q.pos.z, 1.8, 15000, 1.0, true, 0.0)
        local t = GetGameTimer() + 15000
        while GetGameTimer() < t and #(GetEntityCoords(d.ped) - q.pos) > 1.6 do
            keyHud(ex, ('%s cherche…'):format(d.name), (GetGameTimer() - t0) / (ex.seconds * 1000), ('Leurres trouvés : %d / 3'):format(found))
            if aborted() then return nil end
            Wait(0)
        end
        C.Pose(d.ped, 'sniff', e.sniffMs / 3, false)
        Wait(math.floor(e.sniffMs / 3))
        if q.decoy then
            C.Notify(('%s s\'attarde sur une fausse piste…'):format(d.name), 'inform')
        else
            if not C.Pose(d.ped, 'indicate', -1, true) then C.Pose(d.ped, 'sit', -1, true) end
            C.Vocal(d.ped, 'BARK')
            local vt = GetGameTimer() + 12000
            while GetGameTimer() < vt do
                local near = #(GetEntityCoords(PlayerPedId()) - q.pos) < 2.8
                keyHud(ex, near and 'Le chien marque ! Appuie sur E pour valider et le récompenser.' or ('%s marque un leurre : rejoins-le.'):format(d.name),
                    (GetGameTimer() - t0) / (ex.seconds * 1000), ('Leurres trouvés : %d / 3'):format(found))
                if aborted() then return nil end
                if near and IsControlJustPressed(0, 38) then found = found + 1 q.lure.found = true PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true) break end
                Wait(0)
            end
            ClearPedTasks(d.ped)
        end
    end
    local timeBonus = math.max(0.6, 1 - (GetGameTimer() - t0) / (ex.seconds * 1000) * 0.4)
    return found / 3 * timeBonus
end

-- 3. Pistage : une piste invisible ; le chien la suit (plus ou moins précis), le maître le suit
EX.track = function(d, ex, e)
    local me = GetEntityCoords(PlayerPedId())
    local pts, cur = {}, me
    local heading = math.random() * math.pi * 2
    for i = 1, 7 do
        heading = heading + (math.random() - 0.5) * 1.2
        local r = 14.0 + math.random() * 8.0
        local x, y = cur.x + math.cos(heading) * r, cur.y + math.sin(heading) * r
        local z = C.Ground(x, y, cur.z)
        if not z or math.abs(z - cur.z) > 5.0 then heading = heading + math.pi * 0.6 z = cur.z x, y = cur.x + math.cos(heading) * r, cur.y + math.sin(heading) * r end
        cur = vector3(x, y, groundAt(x, y, cur.z))
        pts[i] = cur
    end
    local hash = C.LoadModel('prop_cs_heist_bag_01')
    if hash then local obj = CreateObject(hash, cur.x, cur.y, cur.z, false, false, false) PlaceObjectOnGroundProperly(obj) FreezeEntityPosition(obj, true) spawned[#spawned + 1] = obj end
    keyHud(ex, 'Une piste a été tracée. Appuie sur E : « Cherche, piste ! » puis suis ton chien.', 0)
    while not IsControlJustPressed(0, 38) do if aborted() then return nil end Wait(0) end
    local t0, far, lost = GetGameTimer(), 0, 0
    local deadline = t0 + ex.seconds * 1000
    for i, p in ipairs(pts) do
        local err = e.trackError / 3
        local q = vector3(p.x + (math.random() - 0.5) * err, p.y + (math.random() - 0.5) * err, p.z)
        if math.random() > e.trackChance then
            lost = lost + 1
            C.Pose(d.ped, 'sniff', 2500, false)
            C.Notify(('%s hésite sur la piste…'):format(d.name), 'inform')
            Wait(2600)
        end
        TaskFollowNavMeshToCoord(d.ped, q.x, q.y, q.z, 2.2, 20000, 1.5, true, 0.0)
        local t = GetGameTimer() + 20000
        while GetGameTimer() < t and #(GetEntityCoords(d.ped) - q) > 2.0 do
            if GetGameTimer() > deadline then return 0.2 end
            local dist = #(GetEntityCoords(d.ped) - GetEntityCoords(PlayerPedId()))
            if dist > 25.0 then far = far + 1 end
            keyHud(ex, dist > 25.0 and 'Tu es trop loin de ton chien : rattrape-le !' or ('%s suit la piste (%d / %d)'):format(d.name, i, #pts),
                (GetGameTimer() - t0) / (ex.seconds * 1000))
            if aborted() then return nil end
            Wait(0)
        end
    end
    if not C.Pose(d.ped, 'indicate', 3000, false) then C.Pose(d.ped, 'sit', 3000, false) end
    C.Vocal(d.ped, 'BARK')
    local score = 1 - math.min(0.5, lost * 0.12) - math.min(0.3, far / 2000)
    return math.max(0.2, score)
end

-- 4. Attaque contrôlée : envoyer (E), saisie de la manche, puis « Lâche ! » (G)
EX.attack = function(d, ex, e)
    local me = PlayerPedId()
    local start = GetOffsetFromEntityInWorldCoords(me, 0.0, 22.0, 0.0)
    local npc = spawnNpc(d.side, vector3(start.x, start.y, groundAt(start.x, start.y, start.z)), GetEntityHeading(me) + 180.0)
    if not npc then return nil end
    TaskGoToEntity(npc, me, -1, 14.0, 1.0, 1073741824, 0)
    keyHud(ex, 'L\'homme d\'attaque approche. Appuie sur E pour envoyer ton chien.', 0)
    while not IsControlJustPressed(0, 38) do if aborted() then return nil end Wait(0) end
    local t0 = GetGameTimer()
    Wait(e.hesitateMs)
    TaskGoToEntity(d.ped, npc, -1, 0.8, 3.0, 1073741824, 0)
    local grabbed, tries = false, 0
    while GetGameTimer() - t0 < 25000 and not grabbed do
        if aborted() then return nil end
        if #(GetEntityCoords(d.ped) - GetEntityCoords(npc)) < 2.2 then
            tries = tries + 1
            if math.random() < e.attackChance then grabbed = true else
                C.Notify(('%s manque sa saisie.'):format(d.name), 'inform')
                Wait(900)
                TaskGoToEntity(d.ped, npc, -1, 0.8, 3.0, 1073741824, 0)
            end
        end
        keyHud(ex, ('%s fonce sur l\'homme d\'attaque…'):format(d.name), (GetGameTimer() - t0) / 25000)
        Wait(100)
    end
    if not grabbed then return 0.15 end
    TaskCombatPed(d.ped, npc, 0, 16)
    TaskHandsUp(npc, 6000, d.ped, -1, true)
    C.Notify(('%s saisit la manche !'):format(d.name), 'success')
    Wait(1500)
    local released, orders = false, 0
    local tt = GetGameTimer() + 15000
    while GetGameTimer() < tt and not released do
        keyHud(ex, 'Appuie sur G : « Lâche ! »', 0.6, ('Ordres de lâcher : %d'):format(orders))
        if aborted() then return nil end
        if IsControlJustPressed(0, 47) then
            orders = orders + 1
            Wait(e.hesitateMs)
            if math.random() < e.obeyChance then released = true else C.Notify(('%s ne lâche pas !'):format(d.name), 'error') end
        end
        Wait(0)
    end
    ClearPedTasks(d.ped)
    TaskGoToEntity(d.ped, PlayerPedId(), 5000, 1.2, 2.0, 1073741824, 0)
    local s = 0.55 + (released and (orders <= 1 and 0.45 or 0.3) or 0) - math.min(0.2, (tries - 1) * 0.07)
    return math.max(0.1, s)
end

-- 5. Défense : un individu fonce sur le maître, le chien doit l'intercepter
EX.defense = function(d, ex, e)
    local me = PlayerPedId()
    keyHud(ex, 'Appuie sur E pour mettre ton chien en garde.', 0)
    while not IsControlJustPressed(0, 38) do if aborted() then return nil end Wait(0) end
    C.Pose(d.ped, 'sit', 2000, false)
    Wait(1500 + math.random(1500))
    local a = math.random() * math.pi * 2
    local mc = GetEntityCoords(me)
    local sx, sy = mc.x + math.cos(a) * 26.0, mc.y + math.sin(a) * 26.0
    local npc = spawnNpc(d.side, vector3(sx, sy, groundAt(sx, sy, mc.z)), 0.0)
    if not npc then return nil end
    TaskGoToEntity(npc, me, -1, 1.0, 3.0, 1073741824, 0)
    C.Notify('Un individu menaçant fonce sur toi !', 'error')
    local t0 = GetGameTimer()
    local reacted = false
    local willReact = math.random() < e.defendChance
    while GetGameTimer() - t0 < 20000 do
        if aborted() then return nil end
        local npcToMe = #(GetEntityCoords(npc) - GetEntityCoords(me))
        if not reacted and willReact and GetGameTimer() - t0 > e.defendReactionMs and npcToMe < e.defendRadius + 12.0 then
            reacted = true
            C.Vocal(d.ped, 'GROWL')
            TaskGoToEntity(d.ped, npc, -1, 0.8, 3.0, 1073741824, 0)
        end
        if reacted and #(GetEntityCoords(d.ped) - GetEntityCoords(npc)) < 2.2 then
            TaskCombatPed(d.ped, npc, 0, 16)
            ClearPedTasks(npc)
            SetPedToRagdoll(npc, 3000, 3000, 0, false, false, false)
            C.Notify(('%s intercepte l\'individu !'):format(d.name), 'success')
            Wait(2500)
            ClearPedTasks(d.ped)
            return math.max(0.4, 1 - (GetGameTimer() - t0) / 20000 * 0.5)
        end
        if npcToMe < 1.5 then
            C.Notify(('%s n\'a pas réagi à temps.'):format(d.name), 'error')
            return 0.1
        end
        keyHud(ex, reacted and ('%s intervient !'):format(d.name) or 'Reste calme… ton chien doit réagir.', (GetGameTimer() - t0) / 20000)
        Wait(0)
    end
    return 0.1
end

-- 6. Intimidation : le chien met la pression (E à chaque ordre) jusqu'à ce que l'individu lève les mains
EX.intim = function(d, ex, e)
    local me = PlayerPedId()
    local p = GetOffsetFromEntityInWorldCoords(me, 0.0, 9.0, 0.0)
    local npc = spawnNpc(d.side, vector3(p.x, p.y, groundAt(p.x, p.y, p.z)), GetEntityHeading(me) + 180.0)
    if not npc then return nil end
    TaskGoToEntity(d.ped, npc, 6000, 3.0, 2.0, 1073741824, 0)
    local fear, t0 = 0.0, GetGameTimer()
    local limit = ex.seconds * 1000
    while GetGameTimer() - t0 < limit do
        if aborted() then return nil end
        keyHud(ex, 'Appuie sur E pour faire aboyer / grogner ton chien.', fear / 100, ('Peur de l\'individu : %d %%'):format(math.floor(fear)))
        if IsControlJustPressed(0, 38) then
            TaskTurnPedToFaceEntity(d.ped, npc, 500)
            C.Pose(d.ped, 'bark', 1100, false)
            C.Vocal(d.ped, math.random() < 0.5 and 'GROWL' or 'BARK')
            if math.random() < e.obeyChance then fear = fear + 6 + e.intimLevel * 3 end
        end
        if fear >= 100 then
            TaskHandsUp(npc, 5000, d.ped, -1, true)
            C.Notify('L\'individu lève les mains !', 'success')
            Wait(2500)
            return math.max(0.4, 1 - (GetGameTimer() - t0) / limit * 0.6)
        end
        fear = math.max(0, fear - 0.04)
        Wait(0)
    end
    return math.min(0.5, fear / 200)
end

-- ---------------------------------------------------------------------
function C.StartExercise(exId)
    local d = C.dog
    if not d or not DoesEntityExist(d.ped) then return C.Notify('Sors ton chien d\'abord.', 'error') end
    if d.veh or IsPedInAnyVehicle(PlayerPedId(), false) then return C.Notify('Descends du véhicule.', 'error') end
    if d.ex then return end
    local ex = K9.Exercise(exId)
    local fn = ex and EX[exId]
    if not fn then return end
    local ok, res = Ely.callback.await('elyzea_k9:exStart', false, d.side, exId)
    if not ok then return C.Notify(res or 'Exercice impossible.', 'error') end
    d.ex, d.busy = exId, true
    ClearPedTasks(d.ped)
    local okRun, score = pcall(fn, d, ex, res.effects or d.effects)
    cleanupEx()
    if C.dog ~= d then TriggerServerEvent('elyzea_k9:server:exAbort') return end
    d.ex = nil
    if not okRun or score == nil then
        TriggerServerEvent('elyzea_k9:server:exAbort')
        C.Notify('Exercice abandonné.', 'inform')
        return C.Heel(d)
    end
    local ok2, r = Ely.callback.await('elyzea_k9:exFinish', false, d.side, exId, score)
    if ok2 and r then
        if (r.xp or 0) > 0 then
            C.Notify(('%s : %d %% de réussite · +%d XP.'):format(ex.label, math.floor((r.score or score) * 100), r.xp), 'success')
            if (r.score or score) >= 0.5 then C.Reward(true) end
        else
            C.Notify(r.msg or ('%s : aucune expérience (limite du jour atteinte ?).'):format(ex.label), 'inform')
        end
    else
        C.Notify(r or 'Exercice non validé.', 'error')
    end
    C.Heel(d)
end
