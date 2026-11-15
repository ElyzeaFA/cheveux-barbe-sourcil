-- =====================================================================
--  ELYZEA CACHETTES - menu admin (pont : admin_menu/server/cachettes.lua)
--  admin_menu vérifie la permission « cachettes_manage » ; chaque valeur est revalidée ici.
-- =====================================================================
local inv = exports.elyzea_inventory

exports('AdminData', function()
    local S = Cach.S
    local cats = {}
    for _, k in ipairs(Config.CategoryOrder) do
        cats[#cats + 1] = { id = k, label = Config.Categories[k].label, caps = S.caps[k], defCaps = Config.Categories[k].caps }
    end
    local classes = {}
    for class = 0, 22 do
        if S.classCategory[class] ~= nil then
            classes[#classes + 1] = { class = class, label = Config.ClassLabels[class] or ('Classe ' .. class), category = S.classCategory[class], def = Config.ClassCategory[class] }
        end
    end
    local models = {}
    for name, cat in pairs(S.modelCategory) do models[#models + 1] = { model = name, category = cat } end
    table.sort(models, function(a, b) return a.model < b.model end)
    local games = {}
    for _, t in ipairs({ 'door', 'trunk', 'wheel', 'seat', 'saddle' }) do
        local g = S.minigames[t]
        games[#games + 1] = { type = t, label = SlotTypeLabels[t], game = GameLabels[t], enabled = S.slotTypes[t] == true,
            difficulty = g.difficulty, length = g.length, maxErrors = g.maxErrors, timeLimit = g.timeLimit }
    end
    local black = {}
    for name in pairs(S.blacklist) do black[#black + 1] = name end
    table.sort(black)
    local total = MySQL.scalar.await('SELECT COUNT(*) FROM `elyzea_cachettes` WHERE `state` = 1') or 0
    return {
        available = true, categories = cats, classes = classes, models = models, games = games,
        access = S.access, minSeconds = S.minSeconds, inspect = S.inspect, blacklist = black,
        tool = Config.ToolItem, installed = tonumber(total) or 0,
    }
end)

local function Lookup(plate)
    plate = tostring(plate or ''):upper():gsub('[^A-Z0-9 ]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if plate == '' then return false, 'Plaque vide.' end
    local row = MySQL.single.await('SELECT `id`, `citizenid`, `vehicle` FROM `player_vehicles` WHERE `plate` = ? OR `plate` = ? LIMIT 1', { plate, ' ' .. plate })
    if not row then return false, ('Aucun véhicule immatriculé « %s ».'):format(plate) end
    Rows[row.id] = nil
    local rows = Cach.LoadRows(row.id)
    local list = {}
    for _, slot in ipairs(SlotOrder) do
        local r = rows[slot]
        if r then
            local items = Cach.StashItems(row.id, slot)
            local n = 0
            for _, it in ipairs(items) do n = n + (it.count or 0) end
            list[#list + 1] = { slot = slot, label = Slots[slot].label, state = r.state, attempts = r.attempts, suspicion = r.suspicion,
                capacity = r.capacity / 1000, discovered = r.discovered, items = n, busy = Locks[('%d:%s'):format(row.id, slot)] ~= nil }
        end
    end
    return true, nil, { plate = plate, vehicleId = row.id, model = row.vehicle, owner = row.citizenid, list = list }
end

exports('AdminAction', function(src, name, d)
    d = type(d) == 'table' and d or {}
    local S = Cach.S
    if name == 'save' then
        -- d = réglages complets envoyés par le menu (mêmes clés que AdminData)
        local raw = { access = d.access, minSeconds = d.minSeconds, inspect = d.inspect, caps = {}, classCategory = {}, modelCategory = {},
            slotTypes = {}, minigames = {}, blacklist = {} }
        for _, c in ipairs(type(d.categories) == 'table' and d.categories or {}) do if type(c) == 'table' and c.id then raw.caps[c.id] = c.caps end end
        for _, c in ipairs(type(d.classes) == 'table' and d.classes or {}) do if type(c) == 'table' then raw.classCategory[tostring(c.class)] = c.category end end
        for _, m in ipairs(type(d.models) == 'table' and d.models or {}) do if type(m) == 'table' and m.model then raw.modelCategory[m.model] = m.category end end
        for _, g in ipairs(type(d.games) == 'table' and d.games or {}) do
            if type(g) == 'table' and g.type then raw.slotTypes[g.type] = g.enabled == true raw.minigames[g.type] = g end
        end
        for _, b in ipairs(type(d.blacklist) == 'table' and d.blacklist or {}) do raw.blacklist[#raw.blacklist + 1] = b end
        for k, v in pairs(S) do if raw[k] == nil then raw[k] = v end end
        Cach.S = Cach.Sanitize(raw)
        Cach.SaveSettings()
        return true, 'Réglages des cachettes enregistrés (nouvelles installations et prochaines ouvertures).'
    elseif name == 'reset' then
        Cach.ResetSettings()
        return true, 'Valeurs par défaut remises (config.lua).'
    elseif name == 'lookup' then
        local ok, msg, res = Lookup(d.plate)
        return ok, msg, res
    elseif name == 'delete' then
        local vehId, slot = tonumber(d.vehicleId), tostring(d.slot or '')
        if not vehId or not Slots[slot] then return false, 'Cachette inconnue.' end
        if Locks[('%d:%s'):format(vehId, slot)] then return false, 'Quelqu\'un utilise cette cachette en ce moment.' end
        local items = Cach.StashItems(vehId, slot)
        if #items > 0 then return false, 'La cachette contient encore des objets : elle doit être vidée en jeu avant d\'être supprimée.' end
        MySQL.update.await('DELETE FROM `elyzea_cachettes` WHERE `vehicle_id` = ? AND `slot` = ?', { vehId, slot })
        Rows[vehId] = nil
        Cach.Log(vehId, slot, 'admin_delete', src)
        return true, ('Cachette « %s » supprimée.'):format(Slots[slot].label)
    end
    return false, 'Action inconnue.'
end)
