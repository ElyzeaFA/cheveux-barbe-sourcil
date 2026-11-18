-- =====================================================================
--  ELYZEA ENTREPRISES - serveur : modération par le staff (/entreprises_admin)
--  Permission : « entreprises_manage » (admin_menu) ou ACE « elyzea.entreprises ».
--  Liste, suspendre / réactiver (avec motif), retirer un logo ou une description
--  inappropriés, dissoudre (solde rendu au fondateur).
-- =====================================================================
local P = Ent
local core = exports.elyzea_core

local function Row(D)
    local v = P.PublicView(D, nil)
    v.enabled, v.reason, v.job, v.society, v.ownerCid = D.enabled, D.disabledReason, D.job, D.society, D.ownerCid
    v.balance = P.Balance(D)
    return v
end
local function Live(id) local D = P.shops[tonumber(id) or -1] return (D and not D.deleted) and D or nil end

P.Admin.list = { fn = function()
    local list = {}
    for _, D in pairs(P.shops) do if not D.deleted then list[#list + 1] = Row(D) end end
    table.sort(list, function(a, b) return a.id > b.id end)
    return { list = list }
end }

P.Admin.toggle = { fn = function(src, d)
    local D = Live(d.id)
    if not D then return { error = 'Entreprise introuvable.' } end
    local on = d.enabled == true
    local reason = P.Clean(d.reason, 160)
    if not on and reason == '' then return { error = 'Indiquez le motif de la suspension (le patron le verra).' } end
    D.enabled, D.disabledReason = on, (not on) and reason or nil
    if not on then for _, s in ipairs(P.CrewOnDuty(D.id)) do P.SetDuty(s, false, true) end end
    P.SaveShop(D)
    P.Touch()
    P.PushShop(D.id)
    P.AddLog(D.id, src, nil, nil, on and 'Réactivée par le staff' or 'Suspendue par le staff', nil, nil, reason ~= '' and reason or nil)
    P.Log(src, on and 'Entreprise réactivée' or 'Entreprise suspendue', ('%s%s'):format(D.name, reason ~= '' and (' · ' .. reason) or ''))
    local owner = core:GetSourceByCitizenId(D.ownerCid)
    if owner then P.Notify(owner, on and ('« %s » est réactivée.'):format(D.name) or ('« %s » est suspendue par le staff : %s'):format(D.name, reason), on and 'success' or 'error') end
    return { ok = true, message = on and 'Entreprise réactivée.' or 'Entreprise suspendue.' }
end }

-- Retirer un logo / une description inappropriés
P.Admin.clear = { fn = function(src, d)
    local D = Live(d.id)
    if not D then return { error = 'Entreprise introuvable.' } end
    local what = {}
    if d.logo == true then D.logo = '' what[#what + 1] = 'logo' end
    if d.description == true then D.description = 'Description retirée par le staff.' what[#what + 1] = 'description' end
    if #what == 0 then return { error = 'Rien à retirer.' } end
    P.SaveShop(D)
    P.Touch()
    P.PushShop(D.id)
    P.AddLog(D.id, src, nil, nil, 'Vitrine modérée', nil, nil, table.concat(what, ', '))
    P.Log(src, 'Vitrine modérée', ('%s · %s'):format(D.name, table.concat(what, ', ')))
    return { ok = true, message = ('Retiré : %s.'):format(table.concat(what, ', ')) }
end }

P.Admin.rename = { fn = function(src, d)
    local D = Live(d.id)
    if not D then return { error = 'Entreprise introuvable.' } end
    local name, why = P.ValidName(d.name, D.id)
    if not name then return { error = why } end
    local old = D.name
    D.name, D.jobLabel = name, name
    P.SaveShop(D)
    P.SyncCoreJob(D)
    P.Touch()
    P.PushShop(D.id)
    P.AddLog(D.id, src, nil, nil, 'Renommée par le staff', old, name, nil)
    return { ok = true, message = ('« %s » → « %s ».'):format(old, name) }
end }

P.Admin.dissolve = { fn = function(src, d)
    local D = Live(d.id)
    if not D then return { error = 'Entreprise introuvable.' } end
    local reason = P.Clean(d.reason, 160)
    if reason == '' then return { error = 'Indiquez le motif.' } end
    local balance = P.Balance(D)
    local refunded = 0
    if balance > 0 and P.SocietyRemove(D, balance, 'Dissolution par le staff : solde versé au fondateur') then
        if P.PayBank(D.ownerCid, balance, ('Dissolution de %s'):format(D.name)) then refunded = balance
        else P.SocietyAdd(D, balance, 'Annulation : versement au fondateur impossible') end
    end
    P.AddLog(D.id, src, nil, nil, 'Dissoute par le staff', nil, nil, reason)
    P.Log(src, 'Entreprise dissoute', ('%s · %s · solde rendu %d $'):format(D.name, reason, refunded))
    P.Dissolve(D, src, reason)
    return { ok = true, message = ('« %s » dissoute. Solde rendu au fondateur : %d $.'):format(D.name, refunded) }
end }
