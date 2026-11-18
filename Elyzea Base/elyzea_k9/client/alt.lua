-- =====================================================================
--  ELYZEA K9 - CLIENT : menu ALT (elyzea_police, fournisseur « k9: »)
--  ALT sur son chien : ordres rapides ; ALT sur le chien d'un autre : sa médaille.
-- =====================================================================
local function info(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    if C.dog and C.dog.ped == ent then return { mine = true, title = ('Mon chien · %s'):format(C.dog.name) } end
    local st = Entity(ent).state.k9
    if type(st) == 'table' then return { mine = false, title = ('Chien K9 · %s'):format(st.name or '?'), data = st } end
end

exports('AltTarget', function(ent) local t = info(ent) return t and t.title or nil end)
exports('AltNearby', function()
    local d = C.dog
    if d and DoesEntityExist(d.ped) and #(GetEntityCoords(d.ped) - GetEntityCoords(PlayerPedId())) <= 3.0 then return d.ped, ('Mon chien · %s'):format(d.name) end
end)
exports('AltOptions', function(ctx)
    local t = info(ctx and ctx.entity)
    if not t then return {} end
    if not t.mine then return { { id = 'info', label = 'Lire la médaille', icon = 'info' } } end
    return {
        { id = 'follow', label = 'Au pied', icon = 'follow' },
        { id = 'stay', label = 'Reste', icon = 'stay' },
        { id = 'sit', label = 'Assis', icon = 'sit' },
        { id = 'lie', label = 'Couché', icon = 'lie' },
        { id = 'defend', label = 'Défends-moi', icon = 'shield' },
        { id = 'reward', label = 'Récompenser', icon = 'heart' },
        { id = 'target', label = 'Mode ciblage', icon = 'target' },
        { id = 'menu', label = 'Ouvrir le menu du chien', icon = 'menu' },
        { id = 'store', label = 'Renvoyer au chenil', icon = 'out' },
    }
end)
exports('AltSelect', function(id, ctx)
    local t = info(ctx and ctx.entity) or (C.dog and info(C.dog.ped))
    if not t then return end
    CreateThread(function()
        if not t.mine then
            local st = t.data or {}
            return C.Notify(('Médaille : « %s » — %s.'):format(st.name or '?', st.side == 'police' and 'chien de la police' or 'chien'), 'inform')
        end
        if id == 'reward' then C.Reward()
        elseif id == 'target' then C.StartTarget()
        elseif id == 'menu' then C.OpenMenu()
        elseif id == 'store' then C.StoreDog()
        else C.Order(id) end
    end)
end)
