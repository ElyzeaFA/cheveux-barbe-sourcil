-- =========================================================
--  APPLI « ENTREPRISES » : passerelle vers elyzea_entreprises
--  · Onglet « Entreprise » : toutes les entreprises des joueurs (logo, spécialité,
--    description, numéro public) ; Appeler / Message → leur téléphone de service.
--  · Onglet « Lancer mon Business » : création payante, ou gestion de la vitrine
--    de son entreprise (logo depuis la galerie, un lien ou l'ordinateur).
--  · Toute la logique (paiement, droits, validation) est dans elyzea_entreprises.
-- =========================================================
local A = AuraCore
local Register = A.Register
local RES = 'elyzea_entreprises'

local function Ent() return GetResourceState(RES) == 'started' and exports[RES] or nil end
local function Call(fn, src, args)
    local e = Ent()
    if not e then return { ok = false, error = 'Annuaire des entreprises indisponible' } end
    local ok, r = pcall(function() return e[fn](e, src, args) end)
    if not ok or type(r) ~= 'table' then return { ok = false, error = 'Entreprises indisponibles, réessayez' } end
    return r
end

Register('entList', function(src) return Call('PhoneList', src) end)
Register('entMine', function(src) return Call('PhoneMine', src) end)
Register('entCreate', function(src, me, args) return Call('PhoneCreate', src, args) end)
Register('entProfile', function(src, me, args) return Call('PhoneProfile', src, args) end)
Register('entReclaim', function(src, me, args) return Call('PhoneReclaim', src, args) end)
Register('entLogoCode', function(src) return Call('PhoneLogoCode', src) end)
Register('entLogoPending', function(src) return Call('PhoneLogoPending', src) end)
Register('entLogoTake', function(src) return Call('PhoneLogoTake', src) end)
