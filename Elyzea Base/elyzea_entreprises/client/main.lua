-- =====================================================================
--  ELYZEA ENTREPRISES - client : socle (état, requêtes, curseur)
-- =====================================================================
ENTC = { cfg = nil, ui = {} }
local C = ENTC

function C.Notify(msg, kind) exports.elyzea_core:Notify(msg, kind or 'inform') end

-- État publié par le serveur (affichage seulement)
function C.State() return LocalPlayer.state.ent end
function C.IsMember() return C.State() ~= nil end
function C.IsDown() return LocalPlayer.state.emsDown == true end
function C.OnDuty() local s = C.State() return s ~= nil and s.duty == true end
function C.Can(perm) local s = C.State() return s ~= nil and type(s.perms) == 'table' and s.perms[perm] == true end

local function Call(name, action, data)
    local ok, res = pcall(function() return Ely.callback.await(name, false, action, data or {}) end)
    if not ok or type(res) ~= 'table' then return { error = 'Le serveur ne répond pas.' } end
    return res
end
function C.Req(action, data) return Call('ent:req', action, data) end
function C.Pub(action, data) return Call('ent:pub', action, data) end
function C.Adm(action, data) return Call('ent:admin', action, data) end

function C.LoadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end

-- ---------------------------------------------------------------------
-- Curseur : un seul gestionnaire pour tous les écrans
-- ---------------------------------------------------------------------
local open = {}
local function Refresh()
    local any = next(open) ~= nil
    SetNuiFocus(any, any)
    SetNuiFocusKeepInput(false)
end
function C.Focus(name, on) open[name] = on and true or nil Refresh() end
function C.IsOpen(name) return open[name] ~= nil end
function C.AnyOpen() return next(open) ~= nil end

RegisterNUICallback('close', function(body, cb)
    cb({})
    local name = body and body.ui
    if name and C.ui[name] and C.ui[name].close then C.ui[name].close(true) else C.Focus(name or '', false) end
end)
RegisterNUICallback('req', function(body, cb) cb(C.Req(body.action, body.data)) end)
RegisterNUICallback('pub', function(body, cb) cb(C.Pub(body.action, body.data)) end)
RegisterNUICallback('adm', function(body, cb) cb(C.Adm(body.action, body.data)) end)

CreateThread(function()
    Wait(2000)
    local r = C.Pub('init')
    if not r.error then
        C.cfg = r
        SendNUIMessage({ action = 'init', cfg = r })
    end
end)
AddStateBagChangeHandler('ent', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
    SendNUIMessage({ action = 'state', state = value })
    if value == nil then
        for _, ui in pairs(C.ui) do if ui.close then ui.close(true) end end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if next(open) then SetNuiFocus(false, false) SetNuiFocusKeepInput(false) end
end)

-- Secours : /entreprise_debloquer rend toujours le curseur
RegisterCommand('entreprise_debloquer', function()
    for _, ui in pairs(C.ui) do if ui.close then ui.close(true) end end
    open = {}
    Refresh()
    SendNUIMessage({ action = 'closeAll' })
end, false)

-- ---------------------------------------------------------------------
-- F6 : téléphone de service (elyzea_jobphone) ; sans lui, la tablette
-- ---------------------------------------------------------------------
RegisterCommand('entreprise_menu', function()
    if not C.IsMember() then return end
    if GetResourceState('elyzea_jobphone') == 'started' then
        local ok, takes = pcall(function() return exports.elyzea_jobphone:TakesF6() end)
        if ok and takes then return exports.elyzea_jobphone:Toggle() end
    end
    if C.OpenTablet then C.OpenTablet() end
end, false)
RegisterKeyMapping('entreprise_menu', 'Entreprise : téléphone de service', 'keyboard', Config.Keys.menu)
RegisterCommand('entreprise', function() if C.IsMember() and C.OpenTablet then C.OpenTablet() end end, false)

-- ---------------------------------------------------------------------
-- Staff : /entreprises_admin
-- ---------------------------------------------------------------------
local adminOpen = false
local function CloseAdmin()
    if not adminOpen then return end
    adminOpen = false
    C.Focus('admin', false)
    SendNUIMessage({ action = 'admin', show = false })
end
C.ui.admin = { close = CloseAdmin }
RegisterCommand('entreprises_admin', function()
    if adminOpen then return CloseAdmin() end
    local r = C.Adm('list')
    if r.error then return C.Notify(r.error, 'error') end
    adminOpen = true
    C.Focus('admin', true)
    SendNUIMessage({ action = 'admin', show = true, data = r, cfg = C.cfg })
end, false)
