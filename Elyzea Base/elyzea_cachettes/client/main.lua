-- =====================================================================
--  ELYZEA CACHETTES - client
--  · Menu ALT (celui d'elyzea_police, pour tout le monde) : exports AltOptions / AltSelect.
--      - avec un tournevis : « Cacher un objet de contrebande »
--      - police en service (permissions de grade) : « Inspecter le véhicule », « Démonter un emplacement »
--  · Détection des emplacements RÉELS du modèle (os des portières, roues, coffre, sièges) : un emplacement
--    absent du modèle n'est jamais proposé.
--  · Animation + tournevis en main pendant le mini-jeu ET tant que la cachette est ouverte,
--    arrêtés proprement dans tous les cas (réussite, échec, annulation, interface fermée, mort, ressource arrêtée).
-- =====================================================================
local busy = false          -- une seule opération à la fois
local current = nil         -- { token, veh, slot, type }
local scene = nil           -- { prop, door, anim = { dict, clip } }
local nuiResolve = nil      -- promesse du mini-jeu / du choix d'emplacement

local function Notify(text, kind) exports.elyzea_core:Notify(text, kind or 'inform') end
local function Req(name, ...)
    local ok, a = pcall(function(...) return Ely.callback.await(name, false, ...) end, ...)
    if not ok or type(a) ~= 'table' then return { error = 'Le serveur ne répond pas.' } end
    return a
end
local function G() return GlobalState.cachettes or {} end

-- ---------------------------------------------------------------------
-- Compatibilité du véhicule (affichage seulement : le serveur décide)
-- ---------------------------------------------------------------------
local function IsBike(veh)
    local m = GetEntityModel(veh)
    return IsThisModelABike(m) or IsThisModelAQuadbike(m)
end

local function CategoryOf(veh)
    local g = G()
    local m = GetEntityModel(veh) % 4294967296
    local over = g.models and g.models[tostring(m)]
    if over then return over end
    return (g.classes or {})[tostring(GetVehicleClass(veh))] or 'none'
end

local function HasBone(veh, name) return GetEntityBoneIndexByName(veh, name) ~= -1 end

-- Emplacements réellement présents sur ce modèle
local function DetectSlots(veh)
    local out = {}
    if IsBike(veh) then
        if GetVehicleClass(veh) ~= 13 then out[#out + 1] = 'saddle' end
        return out
    end
    for _, id in ipairs({ 'door_fl', 'door_fr', 'door_rl', 'door_rr' }) do
        if HasBone(veh, Slots[id].bone) then out[#out + 1] = id end
    end
    if HasBone(veh, 'boot') then out[#out + 1] = 'trunk' end
    for _, id in ipairs({ 'wheel_fl', 'wheel_fr', 'wheel_rl', 'wheel_rr' }) do
        if HasBone(veh, Slots[id].bone) then out[#out + 1] = id end
    end
    local seats = GetVehicleModelNumberOfSeats(GetEntityModel(veh))
    local need = { seat_d = 1, seat_p = 2, seat_rl = 3, seat_rr = 4 }
    for _, id in ipairs({ 'seat_d', 'seat_p', 'seat_rl', 'seat_rr' }) do
        if seats >= need[id] then out[#out + 1] = id end
    end
    return out
end

local function HasTool()
    local ok, n = pcall(function() return exports.elyzea_inventory:Search('count', G().tool or Config.ToolItem) end)
    return ok and (tonumber(n) or 0) > 0
end

local function Police()
    local st = LocalPlayer.state.police
    if not st or st.duty ~= true or type(st.perms) ~= 'table' then return nil end
    return st.perms
end

-- ---------------------------------------------------------------------
-- Menu ALT
-- ---------------------------------------------------------------------
exports('AltOptions', function(ctx)
    if not ctx or ctx.kind ~= 'vehicle' or not ctx.entity or not DoesEntityExist(ctx.entity) then return {} end
    local veh = ctx.entity
    if IsPedInAnyVehicle(PlayerPedId(), false) then return {} end
    local out = {}
    local compatible = CategoryOf(veh) ~= 'none'
    local tool = HasTool()
    local perms = Police()
    local g = G()
    if tool and compatible then
        out[#out + 1] = { id = 'hide', label = 'Cacher un objet de contrebande', icon = 'stash',
            desc = busy and 'Opération en cours' or nil, disabled = busy }
    end
    if perms and perms[g.inspectPerm or 'veh_inspect'] then
        out[#out + 1] = { id = 'inspect', label = 'Inspecter le véhicule', icon = 'inspect', disabled = busy }
    end
    if perms and perms[g.openPerm or 'veh_cachettes'] and compatible then
        local noTool = g.policeNeedsTool and not tool
        out[#out + 1] = { id = 'search', label = 'Démonter un emplacement (fouille)', icon = 'stash',
            disabled = busy or noTool, desc = noTool and 'Il vous faut un tournevis' or nil }
    end
    return out
end)

-- ---------------------------------------------------------------------
-- NUI
-- ---------------------------------------------------------------------
local function Focus(on)
    SetNuiFocus(on, on)
    SetNuiFocusKeepInput(false)
end

local function NuiAwait(msg)
    local p = promise.new()
    nuiResolve = p
    Focus(true)
    SendNUIMessage(msg)
    local res = Citizen.Await(p)
    return res
end
local function NuiResolve(data)
    local p = nuiResolve
    nuiResolve = nil
    Focus(false)
    if p then p:resolve(data or {}) end
end

RegisterNUICallback('pick', function(d, cb) cb({}) NuiResolve({ slot = d and d.slot }) end)
RegisterNUICallback('close', function(_, cb) cb({}) NuiResolve({ closed = true }) end)
RegisterNUICallback('result', function(d, cb) cb({}) NuiResolve({ result = d }) end)
RegisterNUICallback('progress', function(d, cb)
    cb({})
    if current and d and tonumber(d.errors) then TriggerServerEvent('elyzea_cachettes:progress', current.token, tonumber(d.errors)) end
end)

local function NuiClose()
    SendNUIMessage({ action = 'hide' })
    if nuiResolve then NuiResolve({ closed = true, aborted = true }) end
end

-- ---------------------------------------------------------------------
-- Mise en scène : position, animation, tournevis, porte ouverte
-- ---------------------------------------------------------------------
local ANIMS = {
    door   = { 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer' },  -- accroupi contre le panneau
    seat   = { 'amb@prop_human_bum_bin@base', 'base' },                                       -- penché dans l'habitacle
    trunk  = { 'mini@repair', 'fixing_a_player' },                                             -- penché dans le coffre
    wheel  = { 'amb@medic@standing@tendtodead@base', 'base' },                                -- un genou à terre, sous l'aile
    saddle = { 'mini@repair', 'fixing_a_ped' },                                                -- debout, à côté de la selle
}
local TOOL_PROP = `prop_tool_screwdvr01`

local function LoadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end

local function Control(veh)
    if NetworkHasControlOfEntity(veh) then return true end
    NetworkRequestControlOfEntity(veh)
    local t = GetGameTimer() + 1200
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() < t do Wait(0) NetworkRequestControlOfEntity(veh) end
    return NetworkHasControlOfEntity(veh)
end

-- Point où se placer pour travailler sur un emplacement (côté extérieur du véhicule)
local function WorkPoint(veh, slot)
    local s = Slots[slot]
    local min, max = GetModelDimensions(GetEntityModel(veh))
    if s.type == 'trunk' then
        return GetOffsetFromEntityInWorldCoords(veh, 0.0, min.y - 0.55, 0.0), GetOffsetFromEntityInWorldCoords(veh, 0.0, min.y + 0.4, 0.0)
    end
    local bone = s.bone
    if s.type == 'seat' then bone = Slots[({ [0] = 'door_fl', [1] = 'door_fr', [2] = 'door_rl', [3] = 'door_rr' })[s.door]].bone end
    local idx = GetEntityBoneIndexByName(veh, bone)
    local world = idx ~= -1 and GetWorldPositionOfEntityBone(veh, idx) or GetEntityCoords(veh)
    local local_ = GetOffsetFromEntityGivenWorldCoords(veh, world.x, world.y, world.z)
    local side = local_.x >= 0 and 1 or -1
    if s.type == 'saddle' then side = 1 end
    local stand = GetOffsetFromEntityInWorldCoords(veh, (side > 0 and max.x or min.x) + side * (s.type == 'door' and 1.0 or 0.55), local_.y, 0.0)
    return stand, world
end

local function GoTo(veh, slot)
    local ped = PlayerPedId()
    local stand, look = WorkPoint(veh, slot)
    local h = GetHeadingFromVector_2d(look.x - stand.x, look.y - stand.y)
    TaskGoStraightToCoord(ped, stand.x, stand.y, stand.z, 1.0, 5000, h, 0.15)
    local t = GetGameTimer() + 5000
    while GetGameTimer() < t and #(GetEntityCoords(ped).xy - stand.xy) > 0.35 do Wait(50) end
    ClearPedTasks(ped)
    SetEntityHeading(ped, h)
    return look
end

local function StopScene(closeDoor)
    local ped = PlayerPedId()
    if scene then
        if scene.anim then StopAnimTask(ped, scene.anim[1], scene.anim[2], 1.0) end
        if scene.prop and DoesEntityExist(scene.prop) then DeleteEntity(scene.prop) end
        if closeDoor ~= false and scene.door and scene.veh and DoesEntityExist(scene.veh) then
            Control(scene.veh)
            SetVehicleDoorShut(scene.veh, scene.door, false)
        end
    end
    scene = nil
    ClearPedTasks(ped)
end

local function StartScene(veh, slot)
    StopScene(false)
    local s = Slots[slot]
    local ped = PlayerPedId()
    scene = { veh = veh }
    if s.door ~= nil and s.type ~= 'wheel' then
        if Control(veh) then SetVehicleDoorOpen(veh, s.door, false, false) end
        scene.door = s.door
    end
    local a = ANIMS[s.type]
    if a and LoadDict(a[1]) then
        TaskPlayAnim(ped, a[1], a[2], 3.0, 1.0, -1, 1, 0, false, false, false)
        scene.anim = a
    end
    RequestModel(TOOL_PROP)
    local t = GetGameTimer() + 2000
    while not HasModelLoaded(TOOL_PROP) and GetGameTimer() < t do Wait(10) end
    if HasModelLoaded(TOOL_PROP) then
        local c = GetEntityCoords(ped)
        local prop = CreateObject(TOOL_PROP, c.x, c.y, c.z, true, true, false)
        AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 57005), 0.10, 0.03, -0.02, -80.0, 0.0, 10.0, true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(TOOL_PROP)
        scene.prop = prop
    end
end

-- Garde l'animation en boucle (une autre ressource ou un choc peut l'interrompre)
CreateThread(function()
    while true do
        if scene and scene.anim then
            local ped = PlayerPedId()
            if not IsEntityPlayingAnim(ped, scene.anim[1], scene.anim[2], 3) and not IsPedRagdoll(ped) then
                TaskPlayAnim(ped, scene.anim[1], scene.anim[2], 3.0, 1.0, -1, 1, 0, false, false, false)
            end
            Wait(400)
        else
            Wait(800)
        end
    end
end)

-- Interruption forcée : mort, menotté, véhicule disparu ou trop loin
local function Interrupted(veh)
    local ped = PlayerPedId()
    if IsEntityDead(ped) or LocalPlayer.state.cuffed or LocalPlayer.state.emsDown then return 'Vous avez été interrompu.' end
    if not DoesEntityExist(veh) then return 'Le véhicule a disparu.' end
    if #(GetEntityCoords(ped) - GetEntityCoords(veh)) > Config.Distance + 1.5 then return 'Vous vous êtes éloigné du véhicule.' end
    return nil
end

-- ---------------------------------------------------------------------
-- Opération complète : choix de l'emplacement → mini-jeu → inventaire → remontage
-- ---------------------------------------------------------------------
local function Finish(reason)
    if current then
        local c = current
        current = nil
        if reason ~= 'closed' then TriggerServerEvent('elyzea_cachettes:abort', c.token) end
    end
    StopScene(true)
    busy = false
end

-- Remontage du panneau quand l'inventaire de la cachette se ferme
RegisterNetEvent('elyzea_cachettes:ended', function(reason)
    if not current or not current.opened then return end
    local c = current
    current = nil
    if reason == 'closed' and scene then
        exports.elyzea_core:ProgressBar({ duration = Config.CloseDuration, label = ('Remontage · %s'):format(Slots[c.slot].label),
            canCancel = false, disable = { move = true, car = true, combat = true } })
    elseif reason == 'far' then
        Notify('Vous vous êtes éloigné : la cachette a été refermée.', 'error')
    end
    StopScene(true)
    busy = false
end)

local function Run(veh, role)
    if busy then return end
    busy = true
    local netId = VehToNet(veh)
    local menu = Req('cach:menu', netId, role, { class = GetVehicleClass(veh), slots = DetectSlots(veh) })
    if menu.error then Notify(menu.error, 'error') busy = false return end
    local pick = NuiAwait({ action = 'slots', role = role, plate = menu.plate, category = menu.category, slots = menu.slots })
    SendNUIMessage({ action = 'hide' })
    if not pick.slot then busy = false return end
    local st = Req('cach:start', pick.slot)
    if st.error then Notify(st.error, 'error') busy = false return end
    current = { token = st.token, veh = veh, slot = st.slot, type = st.game }
    GoTo(veh, st.slot)
    if Interrupted(veh) then Notify(Interrupted(veh), 'error') Finish('abort') return end
    StartScene(veh, st.slot)

    -- surveillance pendant le mini-jeu
    local watching = true
    CreateThread(function()
        while watching do
            local why = Interrupted(veh)
            if why then
                watching = false
                Notify(why, 'error')
                SendNUIMessage({ action = 'abort' })
                NuiResolve({ result = { cancelled = true, aborted = true } })
                return
            end
            Wait(250)
        end
    end)
    local res = NuiAwait({ action = 'game', game = st.game, mode = st.mode, label = st.label, params = st.params })
    watching = false
    SendNUIMessage({ action = 'hide' })
    local r = res.result or { cancelled = true }
    if r.aborted then Finish('abort') return end
    if not current then StopScene(true) busy = false return end
    local fin = Req('cach:finish', current.token, { success = r.success == true, cancelled = r.cancelled == true, errors = tonumber(r.errors) or 0 })
    if fin.opened then
        current.opened = true
        if fin.installed then
            Notify(('Cachette aménagée : %s (%s kg).'):format(st.label, fin.capacity), 'success')
        elseif fin.found then
            Notify(('Compartiment dissimulé découvert : %s.'):format(st.label), 'warning')
        end
        return  -- l'inventaire est ouvert ; « elyzea_cachettes:ended » déclenche le remontage
    end
    current = nil
    if fin.empty then
        Notify(('Rien n\'est dissimulé au niveau %s.'):format(Slots[st.slot].where), 'inform')
        exports.elyzea_core:ProgressBar({ duration = Config.CloseDuration, label = 'Remontage', canCancel = false, disable = { move = true, car = true, combat = true } })
    elseif fin.failed then
        Notify(st.mode == 'install' and 'Échec : le démontage n\'a pas abouti. Recommencez.' or 'Échec : impossible d\'accéder au compartiment.', 'error')
    elseif fin.cancelled then
        Notify(fin.counted and 'Opération annulée : le travail bâclé laisse des traces (essai compté).' or 'Opération annulée.', 'inform')
    elseif fin.error then
        Notify(fin.error, 'error')
    end
    StopScene(true)
    busy = false
end

-- ---------------------------------------------------------------------
-- Inspection (police)
-- ---------------------------------------------------------------------
local function Inspect(veh)
    if busy then return end
    busy = true
    local r = Req('cach:inspectStart', VehToNet(veh))
    if r.error then Notify(r.error, 'error') busy = false return end
    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, veh, 800)
    Wait(800)
    local ok = exports.elyzea_core:ProgressBar({ duration = r.duration, label = 'Inspection du véhicule', canCancel = true,
        disable = { move = true, car = true, combat = true }, anim = { scenario = 'CODE_HUMAN_POLICE_INVESTIGATE' } })
    ClearPedTasks(ped)
    local f = Req('cach:inspectFinish', r.token, not ok)
    if f.error then Notify(f.error, 'error') elseif f.cancelled then Notify('Inspection annulée.', 'inform') end
    busy = false
end

exports('AltSelect', function(id, ctx)
    local veh = ctx and ctx.entity
    if not veh or not DoesEntityExist(veh) then return end
    if id == 'hide' then CreateThread(function() Run(veh, 'crime') end)
    elseif id == 'search' then CreateThread(function() Run(veh, 'police') end)
    elseif id == 'inspect' then CreateThread(function() Inspect(veh) end) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if nuiResolve or busy then SetNuiFocus(false, false) end
    StopScene(true)
end)
