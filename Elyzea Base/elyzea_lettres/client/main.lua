-- =====================================================================
--  ELYZEA LETTRES · CLIENT
--  Ouvre l'interface (rédaction, lecture, enveloppe), joue l'animation et relaie les choix au serveur.
--  Le client ne décide de rien : le serveur revérifie tout (jeton, objets, texte).
-- =====================================================================
local open = nil          -- 'write' | 'read' | 'envelope' | nil
local token = nil         -- jeton de rédaction donné par le serveur
local animProps = {}
local animKind = nil

local function notify(text, kind)
    pcall(function() exports.elyzea_core:Notify(text, kind or 'inform') end)
end

-- ---------------------------------------------------------------------
-- Animation (n'empêche jamais de bouger après la fermeture : tout est retiré à la fermeture)
-- ---------------------------------------------------------------------
local function stopAnim()
    local ped = PlayerPedId()
    if animKind then
        local a = Config.Anim[animKind]
        if a then StopAnimTask(ped, a.dict, a.clip, 2.0) end
    end
    for _, obj in ipairs(animProps) do
        if DoesEntityExist(obj) then DetachEntity(obj, true, false) DeleteEntity(obj) end
    end
    animProps, animKind = {}, nil
end

local function startAnim(kind)
    stopAnim()
    local a = Config.Anim[kind]
    local ped = PlayerPedId()
    if not a or IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedSwimming(ped) then return end
    CreateThread(function()
        RequestAnimDict(a.dict)
        local t = GetGameTimer() + 2000
        while not HasAnimDictLoaded(a.dict) and GetGameTimer() < t do Wait(10) end
        if not open or not HasAnimDictLoaded(a.dict) then return end
        animKind = kind
        TaskPlayAnim(ped, a.dict, a.clip, 3.0, 3.0, -1, a.flag or 49, 0, false, false, false)
        local pos = GetEntityCoords(ped)
        for _, p in ipairs(a.props or {}) do
            local model = joaat(p.model)
            RequestModel(model)
            local tm = GetGameTimer() + 2000
            while not HasModelLoaded(model) and GetGameTimer() < tm do Wait(10) end
            if HasModelLoaded(model) and open then
                local obj = CreateObject(model, pos.x, pos.y, pos.z + 0.2, true, true, false)
                SetEntityCollision(obj, false, false)
                AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, p.bone), p.pos[1], p.pos[2], p.pos[3], p.rot[1], p.rot[2], p.rot[3], true, true, false, true, 1, true)
                animProps[#animProps + 1] = obj
                SetModelAsNoLongerNeeded(model)
            end
        end
        RemoveAnimDict(a.dict)
    end)
end

-- ---------------------------------------------------------------------
-- Ouverture / fermeture
-- ---------------------------------------------------------------------
local function show(kind, msg, anim)
    pcall(function() exports.elyzea_inventory:closeInventory() end)
    open = kind
    SetNuiFocus(true, true)
    SendNUIMessage(msg)
    if anim then startAnim(kind == 'write' and 'write' or 'read') else stopAnim() end
end

local function hide()
    if not open then return end
    local was = open
    open, token = nil, nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    stopAnim()
    if was ~= 'write' then TriggerServerEvent('elyzea_lettres:closed') end
end

RegisterNetEvent('elyzea_lettres:openWriter', function(d)
    token = d.token
    show('write', { action = 'write', data = d }, d.animation)
end)

RegisterNetEvent('elyzea_lettres:read', function(letter, opts)
    opts = opts or {}
    show('read', { action = 'read', letter = letter, opts = opts }, opts.animation)
end)

RegisterNetEvent('elyzea_lettres:envelope', function(env, opts)
    opts = opts or {}
    show('envelope', { action = 'envelope', envelope = env, opts = opts }, opts.animation)
end)

RegisterNetEvent('elyzea_lettres:finished', function(ok, msg)
    if open ~= 'write' then return end
    SendNUIMessage({ action = 'finished', ok = ok == true, message = msg })
    if ok then
        notify(msg, 'success')
        token = nil
        SetTimeout(1300, function() if open == 'write' then open = 'done' hide() end end)
    end
end)

RegisterNetEvent('elyzea_lettres:closeUi', function() hide() end)

-- ---------------------------------------------------------------------
-- Rappels de l'interface
-- ---------------------------------------------------------------------
RegisterNUICallback('draft', function(data, cb)
    cb('ok')
    if open == 'write' and token then TriggerServerEvent('elyzea_lettres:saveDraft', token, data) end
end)

RegisterNUICallback('finish', function(data, cb)
    cb('ok')
    if open == 'write' and token then TriggerServerEvent('elyzea_lettres:finish', token, data) end
end)

RegisterNUICallback('cancel', function(data, cb)
    cb('ok')
    if open == 'write' and token then TriggerServerEvent('elyzea_lettres:cancel', token, data and data.keep == true, data and data.draft) end
    hide()
end)

RegisterNUICallback('close', function(_, cb) cb('ok') hide() end)
RegisterNUICallback('openEnvelope', function(_, cb) cb('ok') TriggerServerEvent('elyzea_lettres:openEnvelope') end)
RegisterNUICallback('putInEnvelope', function(_, cb) cb('ok') TriggerServerEvent('elyzea_lettres:putInEnvelope') end)
RegisterNUICallback('takeOut', function(_, cb) cb('ok') TriggerServerEvent('elyzea_lettres:takeOut') end)

-- Mort, menottes, voiture… pendant l'écriture : l'animation s'arrête, l'interface reste (le texte n'est pas perdu)
CreateThread(function()
    while true do
        Wait(500)
        if open and animKind then
            local ped = PlayerPedId()
            if IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) or IsPedRagdoll(ped) then stopAnim() end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if open then SetNuiFocus(false, false) end
    stopAnim()
end)
