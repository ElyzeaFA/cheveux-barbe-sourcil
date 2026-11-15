-- =====================================================================
--  ELYZEA LETTRES · MENU ADMIN (onglet « Lettres » d'admin_menu, permission « lettres_manage »)
--  admin_menu vérifie la permission puis appelle AdminData / AdminAction ; elle est revérifiée ici.
--  Le contenu des lettres n'est pas affiché au staff (correspondance privée des joueurs) :
--  seulement l'identifiant, l'auteur, le destinataire, la date et le nombre de pages.
-- =====================================================================
local PERM = 'lettres_manage'

local function allowed(src)
    if src == 0 then return true end
    local ok, r = pcall(function() return exports.admin_menu:HasPermission(src, PERM) end)
    return ok and r == true
end

exports('AdminData', function()
    local s = Letters.getSettings()
    local stats = { total = 0, today = 0, week = 0 }
    local recent = {}
    pcall(function()
        local row = MySQL.single.await([[SELECT COUNT(*) AS total,
            SUM(`created` >= CURDATE()) AS today, SUM(`created` >= NOW() - INTERVAL 7 DAY) AS week FROM `elyzea_letters`]])
        if row then stats = { total = tonumber(row.total) or 0, today = tonumber(row.today) or 0, week = tonumber(row.week) or 0 } end
        recent = MySQL.query.await([[SELECT `id`, `author_name`, `author_cid`, `recipient`, `pages`, `font`,
            DATE_FORMAT(`created`, '%d/%m/%Y %H:%i') AS `created` FROM `elyzea_letters` ORDER BY `created` DESC LIMIT 25]]) or {}
    end)
    return {
        settings = s,
        limits = Config.Limits,
        fonts = Config.Fonts,
        papers = Config.Papers,
        items = Config.Items,
        stats = stats,
        recent = recent,
    }
end)

exports('AdminAction', function(src, name, data)
    if not allowed(src) then return false, 'Permission refusée.' end
    data = type(data) == 'table' and data or {}
    if name == 'save' then
        local s = Letters.setSettings(data)
        pcall(function() exports.admin_menu:AddLog(src, 'Lettres', ('Réglages : %d caractères, %d pages, consommation %s'):format(s.maxChars, s.maxPages, s.consume)) end)
        return true, 'Réglages des lettres enregistrés.'
    elseif name == 'reset' then
        Letters.setSettings(Config.Defaults)
        return true, 'Réglages des lettres remis par défaut.'
    end
    return false, 'Action inconnue.'
end)
