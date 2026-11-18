-- =====================================================================
--  ELYZEA K9 - CLIENT : mode ciblage
--  Molette : personne suivante / précédente · ◄ ► : changer d'ordre
--  E : confirmer · Échap / Retour arrière : annuler
--  Seules les personnes proches sont proposées, triées par distance ;
--  la sélection reste sur la même personne quand la liste se met à jour.
-- =====================================================================
C.target = { active = false }
local T = C.target

local function ordersWithTarget(side)
    local out = {}
    for _, o in ipairs(K9.OrdersFor(side)) do if o.target ~= 'none' then out[#out + 1] = o end end
    return out
end

local function label(sid) return ('Personne · ID %d'):format(sid) end

-- Liste des cibles : joueurs (ordre « personne ») ou véhicules (ordre « véhicule »)
local function refresh()
    local me = PlayerPedId()
    local mc = GetEntityCoords(me)
    local list = {}
    if T.order.target == 'vehicle' then
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            local dist = #(GetEntityCoords(veh) - mc)
            if dist <= Config.Target.vehicleDistance and NetworkGetEntityIsNetworked(veh) then
                local plate = (GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', '')
                list[#list + 1] = { key = 'v' .. VehToNet(veh), ent = veh, id = VehToNet(veh), dist = dist,
                    name = ('%s · %s'):format(GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(veh))), plate) }
            end
        end
    else
        for _, pl in ipairs(GetActivePlayers()) do
            if pl ~= PlayerId() then
                local ped = GetPlayerPed(pl)
                local dist = #(GetEntityCoords(ped) - mc)
                if dist <= Config.Target.maxDistance and not IsEntityDead(ped) then
                    local sid = GetPlayerServerId(pl)
                    list[#list + 1] = { key = 'p' .. sid, ent = ped, id = sid, dist = dist, name = label(sid),
                        inVehicle = IsPedInAnyVehicle(ped, false), visible = HasEntityClearLosToEntity(me, ped, 17) }
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    local keep = T.list[T.sel] and T.list[T.sel].key
    T.list, T.sel = list, 1
    for i, it in ipairs(list) do if it.key == keep then T.sel = i end end
end

local function hud()
    local cur = T.list[T.sel]
    C.Send('target', { show = true, order = T.order.label, orderIndex = T.oi, orderCount = #T.orders, kind = T.order.target,
        name = cur and cur.name or nil, dist = cur and math.floor(cur.dist + 0.5) or nil, index = T.sel, count = #T.list,
        warn = cur and (cur.inVehicle and (T.order.id == 'attack' or T.order.id == 'takedown') and 'Dans un véhicule' or (cur.visible == false and 'Hors de vue' or nil)) or nil,
        dog = C.dog and C.dog.name or '' })
end

function C.StopTarget()
    if not T.active then return end
    T.active = false
    C.Send('target', { show = false })
end

-- Démarre le mode ciblage (orderId facultatif : ordre choisi dans le menu)
function C.StartTarget(orderId)
    if T.active then return end
    if C.ui then return end
    local d = C.dog
    if not d or not DoesEntityExist(d.ped) then return C.Notify('Sors ton chien d\'abord (menu ' .. Config.Keys.menu .. ').', 'error') end
    if d.ex then return C.Notify('Termine ton exercice d\'abord.', 'error') end
    T.orders = ordersWithTarget(d.side)
    T.oi = 1
    for i, o in ipairs(T.orders) do if o.id == (orderId or T.lastOrder) then T.oi = i end end
    T.order = T.orders[T.oi]
    T.list, T.sel, T.active = {}, 1, true
    refresh()
    hud()
    CreateThread(function()
        local nextRefresh = 0
        while T.active do
            -- commandes bloquées pendant le ciblage (armes, roue des armes, attaque, échap)
            for _, c in ipairs({ 14, 15, 16, 17, 24, 25, 37, 38, 44, 140, 141, 142, 174, 175, 177, 199, 200, 257, 261, 262, 322 }) do DisableControlAction(0, c, true) end
            local changed = false
            if GetGameTimer() >= nextRefresh then nextRefresh = GetGameTimer() + Config.Target.refreshMs refresh() changed = true end
            if #T.list > 0 then
                if IsDisabledControlJustPressed(0, 15) or IsDisabledControlJustPressed(0, 261) then T.sel = T.sel % #T.list + 1 changed = true PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true) end
                if IsDisabledControlJustPressed(0, 14) or IsDisabledControlJustPressed(0, 262) then T.sel = (T.sel - 2) % #T.list + 1 changed = true PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true) end
            end
            if IsDisabledControlJustPressed(0, 175) or IsDisabledControlJustPressed(0, 174) then
                local dir = IsDisabledControlJustPressed(0, 175) and 1 or -1
                local wasKind = T.order.target
                T.oi = (T.oi - 1 + dir) % #T.orders + 1
                T.order = T.orders[T.oi]
                if T.order.target ~= wasKind then T.list, T.sel = {}, 1 refresh() end
                changed = true
                PlaySoundFrontend(-1, 'NAV_LEFT_RIGHT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
            end
            local cur = T.list[T.sel]
            if cur and DoesEntityExist(cur.ent) then
                local p = GetEntityCoords(cur.ent)
                local h = T.order.target == 'vehicle' and 1.6 or 1.25
                DrawMarker(2, p.x, p.y, p.z + h, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.35, 0.35, 0.35, 181, 123, 255, 220, true, true, 2, false, nil, nil, false)
                DrawMarker(25, p.x, p.y, p.z - 0.97, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.1, 1.1, 1.1, 181, 123, 255, 120, false, false, 2, false, nil, nil, false)
            end
            if changed then hud() end
            -- confirmer
            if IsDisabledControlJustPressed(0, 38) then
                if not cur then
                    C.Notify('Aucune cible à portée.', 'error')
                elseif not DoesEntityExist(cur.ent) or #(GetEntityCoords(cur.ent) - GetEntityCoords(PlayerPedId())) > (T.order.target == 'vehicle' and Config.Target.vehicleDistance or Config.Target.maxDistance) + 2.0 then
                    C.Notify('Cible hors de portée.', 'error')
                    refresh() hud()
                else
                    local order, id = T.order.id, cur.id
                    T.lastOrder = order
                    C.StopTarget()
                    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                    CreateThread(function() C.Order(order, id) end)
                    break
                end
            end
            -- annuler
            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 322) then
                C.StopTarget()
                PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                break
            end
            -- chien rangé / mort, ou maître hors d'état : on arrête
            if not C.dog or IsEntityDead(PlayerPedId()) then C.StopTarget() break end
            Wait(0)
        end
    end)
end
