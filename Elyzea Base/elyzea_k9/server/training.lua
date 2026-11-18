-- =====================================================================
--  ELYZEA K9 - SERVEUR : entraînement (exercices en jeu, anti-farm)
--  Le client fait l'exercice ; le serveur vérifie la durée, le délai entre
--  deux exercices identiques, les répétitions et le plafond journalier.
-- =====================================================================
local Notify, TooFast, Access = K9S.Notify, K9S.TooFast, K9S.Access
local Running = {}   -- [src] = { side, ex, t, dog }

local function int(v, d) v = tonumber(v) if not v or v ~= v then return d end return math.floor(v) end

Ely.callback.register('elyzea_k9:exStart', function(src, side, exId)
    if TooFast(src, 'exStart', 2000) then return false, 'Patiente un instant.' end
    local ok, err = Access(src, side, true)
    if not ok then return false, err end
    local e = K9.Exercise(exId)
    if not e or not e.sides[side] then return false, 'Exercice indisponible.' end
    local d, a = K9S.ActiveDog(src, side)
    if not d then return false, a end
    if Running[src] then return false, 'Un exercice est déjà en cours.' end
    local ped = GetPlayerPed(src)
    if GetVehiclePedIsIn(ped, false) ~= 0 then return false, 'Descends du véhicule.' end
    local last = d.stats.ex[e.id]
    local t = os.time()
    if last and t - last.t < Config.Training.cooldownMinutes * 60 then
        return false, ('%s doit se reposer avant de refaire cet exercice (%d min).'):format(d.name, math.ceil((last.t + Config.Training.cooldownMinutes * 60 - t) / 60))
    end
    Running[src] = { side = side, ex = e.id, t = t, dog = d.id, gt = GetGameTimer() }
    K9S.Busy[src] = true
    K9S.Orders[d.id] = nil
    return true, { effects = K9.Effects(d), seconds = e.seconds }
end)

-- score : 0 à 1 (réussites / essais, mesuré pendant l'exercice)
Ely.callback.register('elyzea_k9:exFinish', function(src, side, exId, score)
    local r = Running[src]
    Running[src] = nil
    K9S.Busy[src] = nil
    if not r or r.ex ~= exId or r.side ~= side then return false, 'Aucun exercice en cours.' end
    local e = K9.Exercise(exId)
    local d = K9S.Dogs[r.dog]
    if not d then return false, 'Chien introuvable.' end
    local secs = (GetGameTimer() - r.gt) / 1000
    score = math.max(0, math.min(1, tonumber(score) or 0))
    if score <= 0 then return true, { xp = 0, msg = 'Exercice raté : aucune expérience.' } end
    if secs < e.minSeconds then return false, 'Exercice trop court : aucune expérience.' end
    if secs > e.seconds + 60 then score = score * 0.5 end
    -- répétitions dans l'heure : moins d'expérience à chaque fois
    local t = os.time()
    local last = d.stats.ex[e.id]
    local rep = (last and t - last.t < 3600) and (last.n or 1) or 0
    d.stats.ex[e.id] = { t = t, n = rep + 1 }
    d.stats.trained[e.skill] = (d.stats.trained[e.skill] or 0) + 1
    local xp = math.floor(e.xp * score * (Config.Training.repeatPenalty ^ rep))
    local got = K9S.AddXp(src, d, xp, 'train', ('Entraînement : %s (%d %%)'):format(e.label, math.floor(score * 100)))
    return true, { xp = got, score = score }
end)

RegisterNetEvent('elyzea_k9:server:exAbort', function()
    local src = source
    Running[src] = nil
    K9S.Busy[src] = nil
end)
AddEventHandler('playerDropped', function() Running[source] = nil end)
