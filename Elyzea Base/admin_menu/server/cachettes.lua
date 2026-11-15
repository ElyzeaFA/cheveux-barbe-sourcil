-- =========================================================
--  CACHETTES VÉHICULES - SERVEUR
--  Pont entre le menu et elyzea_cachettes : catégories, capacités, emplacements,
--  mini-jeux, notifications de suspicion, permissions police, objets interdits,
--  recherche des cachettes d'un véhicule par plaque.
--  Permission « cachettes_manage » vérifiée par le dispatcher ; la ressource revalide tout.
-- =========================================================
local AM = AdminMenu
local RES = 'elyzea_cachettes'
local Lookups = {}   -- [src] = dernier résultat de recherche par plaque

local function available() return GetResourceState(RES) == 'started' end

AM.Actions.cachettes = { perm = 'cachettes_manage', fn = function(src, d)
    if not available() then return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error') end
    local name = tostring(d.name or '')
    local ok, success, msg, res = pcall(function() return exports[RES]:AdminAction(src, name, type(d.data) == 'table' and d.data or {}) end)
    if not ok then
        print(('^1[AdminMenu] Cachettes « %s » : %s^7'):format(name, tostring(success)))
        return AM.notify(src, 'elyzea_cachettes ne répond pas (redémarre la ressource).', 'error')
    end
    if name == 'lookup' then
        Lookups[src] = success and res or nil
        if not success and msg then AM.notify(src, msg, 'error') end
        return
    end
    if name == 'delete' and success and Lookups[src] then
        local ok2, s2, _, r2 = pcall(function() return exports[RES]:AdminAction(src, 'lookup', { plate = Lookups[src].plate }) end)
        if ok2 and s2 then Lookups[src] = r2 end
    end
    if msg and msg ~= '' then AM.notify(src, msg, success and 'success' or 'error') end
    if success then AM.addLog(src, 'Cachettes véhicules', tostring(msg)) end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'cachettes_manage') then return end
    if not available() then data.cachettes = { available = false, resource = RES } return end
    local ok, d = pcall(function() return exports[RES]:AdminData() end)
    data.cachettes = ok and d or { available = false, resource = RES, error = true }
    if ok and d then d.lookup = Lookups[src] end
end)

AddEventHandler('playerDropped', function() Lookups[source] = nil end)
