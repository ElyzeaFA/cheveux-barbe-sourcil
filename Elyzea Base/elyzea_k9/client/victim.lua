-- =====================================================================
--  ELYZEA K9 - CLIENT : côté de la personne visée
--  Mise au sol, maintien, intimidation. Les dégâts natifs des chiens K9
--  sont coupés : seuls des dégâts contrôlés (Config.Attack) s'appliquent,
--  sans jamais descendre sous le plancher de santé (un chien ne tue pas).
-- =====================================================================
local REL = joaat('ELY_K9')

-- Les chiens K9 n'infligent pas de dégâts natifs au joueur (réappliqué si le personnage change)
CreateThread(function()
    AddRelationshipGroup('ELY_K9')
    local last = 0
    while true do
        local ped = PlayerPedId()
        if ped ~= last then last = ped SetEntityCanBeDamagedByRelationshipGroup(ped, false, REL) end
        Wait(5000)
    end
end)

local held = false
local function protect(floor, ms)
    -- plancher de santé pendant l'action du chien (et un peu après)
    local t = GetGameTimer() + ms
    CreateThread(function()
        while GetGameTimer() < t do
            local ped = PlayerPedId()
            if not IsEntityDead(ped) and GetEntityHealth(ped) < floor then SetEntityHealth(ped, floor) end
            Wait(0)
        end
    end)
end
local function bite(dmg, floor)
    local ped = PlayerPedId()
    local h = GetEntityHealth(ped)
    if h > floor then SetEntityHealth(ped, math.max(floor, h - dmg)) end
    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.08)
end

RegisterNetEvent('elyzea_k9:client:takedown', function(d)
    if type(d) ~= 'table' or held then return end
    local dog = NetToPed(tonumber(d.dog) or 0)
    local floor = math.max(101, tonumber(d.floor) or 120)
    local hold = math.max(0, tonumber(d.hold) or 0)
    local dmg = math.max(0, tonumber(d.damage) or 0)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return end
    held = true
    protect(floor, (hold + 4) * 1000)
    SetPedToRagdoll(ped, 2600, 2600, 0, false, false, false)
    bite(dmg, floor)
    Ely.notify({ title = 'K9', description = hold > 0 and 'Un chien te plaque au sol et te maintient.' or 'Un chien te fait tomber !', type = 'error' })
    local t = GetGameTimer() + hold * 1000
    local nextBite, nextRag = GetGameTimer() + 2500, GetGameTimer() + 2000
    while GetGameTimer() < t do
        ped = PlayerPedId()
        if IsEntityDead(ped) then break end
        -- maintien : seulement tant que le chien est contre la personne
        if not DoesEntityExist(dog) or #(GetEntityCoords(dog) - GetEntityCoords(ped)) > 4.0 then break end
        DisableControlAction(0, 21, true) DisableControlAction(0, 22, true) DisableControlAction(0, 24, true) DisableControlAction(0, 25, true)
        DisableControlAction(0, 30, true) DisableControlAction(0, 31, true) DisableControlAction(0, 44, true) DisableControlAction(0, 140, true)
        if GetGameTimer() >= nextRag then nextRag = GetGameTimer() + 2000 SetPedToRagdoll(ped, 2200, 2200, 0, false, false, false) end
        if GetGameTimer() >= nextBite then nextBite = GetGameTimer() + 2500 bite(dmg, floor) end
        Wait(0)
    end
    held = false
end)

-- Intimidation : niveau 1 aboiements ; 2 tremblement ; 3 ne peut plus courir ; 4 ni sauter ni courir ; 5 tétanisé au début
local intimUntil = 0
RegisterNetEvent('elyzea_k9:client:intimidated', function(d)
    if type(d) ~= 'table' then return end
    local dog = NetToPed(tonumber(d.dog) or 0)
    local level = math.max(1, math.min(5, tonumber(d.level) or 1))
    local secs = math.max(2, math.min(20, tonumber(d.seconds) or 6))
    local texts = { 'Un chien t\'aboie dessus.', 'Un chien grogne et t\'aboie dessus.', 'Un chien menaçant te fait face : tu n\'oses plus courir.',
        'Un chien très menaçant te bloque : tu n\'oses plus bouger vite.', 'Un chien te tétanise.' }
    Ely.notify({ title = 'K9', description = texts[level], type = level >= 3 and 'error' or 'warning' })
    if intimUntil > GetGameTimer() then intimUntil = GetGameTimer() + secs * 1000 return end
    intimUntil = GetGameTimer() + secs * 1000
    CreateThread(function()
        local freezeUntil = level >= 5 and GetGameTimer() + 3000 or 0
        if level >= 2 then ShakeGameplayCam('HAND_SHAKE', 0.15 * level) end
        while GetGameTimer() < intimUntil do
            local ped = PlayerPedId()
            if IsEntityDead(ped) or not DoesEntityExist(dog) or #(GetEntityCoords(dog) - GetEntityCoords(ped)) > 12.0 then break end
            if level >= 3 then DisableControlAction(0, 21, true) end
            if level >= 4 then DisableControlAction(0, 22, true) end
            if GetGameTimer() < freezeUntil then DisableControlAction(0, 30, true) DisableControlAction(0, 31, true) end
            Wait(0)
        end
        StopGameplayCamShaking(false)
    end)
end)
