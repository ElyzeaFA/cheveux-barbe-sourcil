-- =========================================================
--  LETTRES - SERVEUR (pont avec la ressource elyzea_lettres)
--  Onglet « Lettres » : longueur maximale, pages, styles d'écriture, papiers, consommation
--  des feuilles, enveloppes, animation ; liste des dernières lettres (sans leur contenu).
--  Permission « lettres_manage » vérifiée ici puis revérifiée par elyzea_lettres.
-- =========================================================
local AM = AdminMenu
local RES = 'elyzea_lettres'
local function available() return GetResourceState(RES) == 'started' end

AM.Actions.lettres = { perm = 'lettres_manage', fn = function(src, d)
    if not available() then return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error') end
    local ok, success, msg = pcall(function() return exports[RES]:AdminAction(src, tostring(d.name or ''), type(d.data) == 'table' and d.data or {}) end)
    if not ok then
        print(('^1[AdminMenu] Lettres « %s » : %s^7'):format(tostring(d.name), tostring(success)))
        return AM.notify(src, 'elyzea_lettres ne répond pas (redémarre la ressource).', 'error')
    end
    if msg and msg ~= '' then AM.notify(src, msg, success and 'success' or 'error') end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'lettres_manage') then return end
    if not available() then data.lettres = { available = false, resource = RES } return end
    local ok, d = pcall(function() return exports[RES]:AdminData() end)
    if ok and type(d) == 'table' then d.available = true data.lettres = d
    else data.lettres = { available = false, resource = RES, error = true } end
end)
