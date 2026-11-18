-- =====================================================================
--  ELYZEA K9 - CLIENT : état, menu (NUI), touches, outils
-- =====================================================================
C = {
    dog = nil,          -- chien sorti : { side, id, ped, netId, name, effects, mode, task, ... }
    menu = nil,         -- données du menu ouvert
    side = nil,         -- côté affiché dans le menu
    ui = false,
}

function C.Notify(msg, kind) Ely.notify({ title = 'K9', description = msg, type = kind or 'inform' }) end
RegisterNetEvent('elyzea_k9:client:notify', function(msg, kind) C.Notify(msg, kind) end)

function C.LoadModel(model, timeout)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local t = GetGameTimer() + (timeout or 8000)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > t then return nil end
        Wait(0)
    end
    return hash
end
function C.LoadDict(dict)
    if not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(0) end
    return HasAnimDictLoaded(dict)
end
function C.Ground(x, y, z)
    for _, dz in ipairs({ 1.5, 5.0, 25.0 }) do
        local ok, gz = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, z + dz, false)
        if ok and gz and math.abs(gz - z) < dz + 2.0 then return gz end
    end
end
-- Les modèles « addon » absents du jeu sont grisés dans le menu
function C.ModelAvailable(model) local h = joaat(model) return IsModelInCdimage(h) and IsModelValid(h) end

-- ---------------------------------------------------------------------
--  Menu
-- ---------------------------------------------------------------------
local function send(action, data) SendNUIMessage({ action = action, data = data }) end
C.Send = send

function C.OpenMenu()
    if C.ui then return end
    if C.target and C.target.active then return end
    local r = Ely.callback.await('elyzea_k9:open', false)
    if not r or not r.ok then return C.Notify(r and r.error or 'Menu indisponible.', 'error') end
    for _, b in ipairs(r.breeds) do b.available = C.ModelAvailable(b.model) end
    r.active = C.dog and { side = C.dog.side, mode = C.dog.mode } or nil
    r.keys = Config.Keys
    C.menu = r
    C.ui = true
    SetNuiFocus(true, true)
    send('open', r)
end
function C.CloseMenu()
    if not C.ui then return end
    C.ui = false
    SetNuiFocus(false, false)
    send('close')
    if C.StopPreview then C.StopPreview() end
end
RegisterNUICallback('close', function(_, cb) cb({}) C.CloseMenu() end)

RegisterCommand('k9', function() C.OpenMenu() end, false)
RegisterKeyMapping('k9', 'K9 : menu du chien', 'keyboard', Config.Keys.menu)
RegisterCommand('k9cible', function() if C.StartTarget then C.StartTarget() end end, false)
RegisterKeyMapping('k9cible', 'K9 : mode ciblage (molette, E, Échap)', 'keyboard', Config.Keys.target)

-- Actions du menu
RegisterNUICallback('create', function(d, cb)
    local ok, res = Ely.callback.await('elyzea_k9:create', false, d.side, d.breed, d.specialty, d.name)
    if C.StopPreview then C.StopPreview() end
    cb({ ok = ok, error = not ok and res or nil, dog = ok and res or nil })
end)
RegisterNUICallback('rename', function(d, cb)
    local ok, res = Ely.callback.await('elyzea_k9:rename', false, d.side, d.name)
    if ok and C.dog and C.dog.side == d.side then C.dog.name = res.name end
    cb({ ok = ok, error = not ok and res or nil, dog = ok and res or nil })
end)
RegisterNUICallback('upgrade', function(d, cb)
    local ok, res = Ely.callback.await('elyzea_k9:upgrade', false, d.side, d.skill)
    if ok then PlaySoundFrontend(-1, 'MEDAL_UP', 'HUD_MINI_GAME_SOUNDSET', true) end
    cb({ ok = ok, error = not ok and res or nil, dog = ok and res or nil })
end)
RegisterNUICallback('spawn', function(d, cb)
    cb({})
    C.CloseMenu()
    CreateThread(function() C.SpawnDog(d.side) end)
end)
RegisterNUICallback('store', function(_, cb)
    cb({})
    C.CloseMenu()
    CreateThread(function() C.StoreDog() end)
end)
RegisterNUICallback('order', function(d, cb)
    cb({})
    C.CloseMenu()
    local o = K9.Order(d.order)
    if not o then return end
    CreateThread(function()
        if o.target == 'none' then C.Order(o.id) else C.StartTarget(o.id) end
    end)
end)
RegisterNUICallback('reward', function(_, cb) cb({}) C.CloseMenu() CreateThread(function() C.Reward() end) end)
RegisterNUICallback('exercise', function(d, cb)
    cb({})
    C.CloseMenu()
    CreateThread(function() C.StartExercise(d.id) end)
end)
RegisterNUICallback('preview', function(d, cb) cb({}) if C.Preview then C.Preview(d.model) end end)
RegisterNUICallback('previewRotate', function(d, cb) cb({}) if C.PreviewRotate then C.PreviewRotate(tonumber(d.deg) or 30) end end)
RegisterNUICallback('previewStop', function(_, cb) cb({}) if C.StopPreview then C.StopPreview() end end)

-- Mises à jour du chien (expérience, niveau) pendant que le menu est ouvert
RegisterNetEvent('elyzea_k9:client:dogUpdate', function(dog)
    if C.dog and dog and dog.id == C.dog.id then C.dog.name = dog.name end
    if C.ui then send('dog', dog) end
end)
RegisterNetEvent('elyzea_k9:client:levelUp', function()
    PlaySoundFrontend(-1, 'RANK_UP', 'HUD_AWARDS', true)
end)

-- ---------------------------------------------------------------------
--  Petit affichage d'aide (exercices, pistage)
-- ---------------------------------------------------------------------
function C.Hud(data) send('hud', data) end
function C.HudHide() send('hud', { show = false }) end
