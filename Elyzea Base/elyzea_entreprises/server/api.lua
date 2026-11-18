-- =====================================================================
--  ELYZEA ENTREPRISES - exports
--  Téléphone perso (Elyzea Aura, appli « Entreprises ») :
--  · PhoneList(src)            → toutes les entreprises actives (vitrine, numéro public, ouverte, en service)
--  · PhoneMine(src)            → l'entreprise du joueur, ou de quoi en créer une
--  · PhoneCreate(src, data)    → « Lancer mon Business » (paiement + création)
--  · PhoneProfile(src, data)   → modifier la vitrine (permission « profile »)
--  · PhoneReclaim(src, data)   → le fondateur reprend sa place de patron
--  · PhoneLogoCode(src) / PhoneLogoPending(src) / PhoneLogoTake(src) → logo depuis l'ordinateur
--  Autres :
--  · GetCompanies()            → liste (id, nom, métier, compte, active)
--  · GetPlayerCompany(src)     → id de l'entreprise du joueur, ou nil
-- =====================================================================
local P = Ent

local function Guard(src, fn)
    src = tonumber(src)
    if not src or not P.ready then return { ok = false, error = 'Les entreprises démarrent, réessayez dans un instant.' } end
    if not P.Allowed(src, 15) then return { ok = false, error = 'Trop de demandes, patientez une seconde.' } end
    local ok, res = pcall(fn, src)
    if not ok then print(('^1[ENTREPRISES] Téléphone : %s^0'):format(tostring(res))) return { ok = false, error = 'Erreur serveur.' } end
    res = res or {}
    if res.error then res.ok = false elseif res.ok == nil then res.ok = true end
    return res
end

exports('PhoneList', function(src) return Guard(src, function() return { list = P.PublicList(), specialties = Config.Specialties } end) end)
exports('PhoneMine', function(src)
    return Guard(src, function(s)
        local v = P.MineView(s)
        v.specialties, v.colors, v.price, v.descriptionMax, v.nameMax = Config.Specialties, Config.Colors, Config.Create.price, Config.Create.descriptionMax, Config.Create.nameMax
        return v
    end)
end)
exports('PhoneCreate', function(src, data)
    return Guard(src, function(s)
        local r = P.CreateCompany(s, type(data) == 'table' and data or {})
        if r.ok then P.LogoTake(s) end
        return r
    end)
end)
exports('PhoneProfile', function(src, data)
    return Guard(src, function(s)
        local r = P.Request(s, 'profileSave', type(data) == 'table' and data or {})
        if r.ok then P.LogoTake(s) end
        return r
    end)
end)
exports('PhoneReclaim', function(src, data) return Guard(src, function(s) return P.Pub.reclaim.fn(s, type(data) == 'table' and data or {}) end) end)
exports('PhoneLogoCode', function(src) return Guard(src, function(s) return P.LogoCode(s) end) end)
exports('PhoneLogoPending', function(src) return Guard(src, function(s) return P.LogoPending(s) end) end)
exports('PhoneLogoTake', function(src) return Guard(src, function(s) P.LogoTake(s) return { ok = true } end) end)

exports('GetCompanies', function()
    local list = {}
    for _, D in pairs(P.shops) do
        if not D.deleted then list[#list + 1] = { id = D.id, name = D.name, job = D.job, society = D.society, enabled = D.enabled, specialty = D.specialty } end
    end
    return list
end)
exports('GetPlayerCompany', function(src) local D = P.ShopOf(tonumber(src) or -1) return D and D.id or nil end)
