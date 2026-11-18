#!/usr/bin/env python3
"""Essai hors jeu du CLIENT d'elyzea_k9 : charge tous les fichiers client avec des natives simulées et exécute
les chemins principaux (sortir le chien, chaque ordre, ciblage, victime, exercices, ALT) pour trouver les erreurs
(fonction inexistante, variable nil…). Ne remplace pas un essai en jeu.   python3 tests/client_smoke.py"""
import os, sys, re
from lupa import lua54
here = os.path.dirname(os.path.abspath(__file__))
root = os.path.dirname(here)
L = lua54.LuaRuntime(unpack_returned_tuples=True)
L.execute(r'''
T = 0
local V = {} V.__index = V
function vector3(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, V) end
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function joaat(s) return #tostring(s) end
threads, nui, events, cbres, notes, errors = {}, {}, {}, {}, {}, {}
function CreateThread(f) local co = coroutine.create(f) threads[#threads + 1] = co local ok, e = coroutine.resume(co) if not ok then errors[#errors + 1] = e end end
function Wait() if coroutine.isyieldable() then coroutine.yield() end T = T + 100 end
function SetTimeout(_, f) CreateThread(f) end
function GetGameTimer() T = T + 50 return T end
DOGPOS = vector3(3, 0, 30)   -- le chien est déjà au contact des cibles
local POS = { [1] = vector3(0, 0, 30) }
function PlayerPedId() return 1 end
function PlayerId() return 0 end
function GetEntityCoords(e) if e == 500 then return DOGPOS end return POS[e] or vector3(3, 0, 30) end
function GetOffsetFromEntityInWorldCoords(e, x, y, z) local p = GetEntityCoords(e) return vector3(p.x + x, p.y + y, p.z + z) end
function DoesEntityExist(e) return e ~= nil and e ~= 0 end
function CreatePed() return 500 end
function CreateObject() return 600 end
function NetworkGetEntityIsNetworked() return true end
function PedToNet() return 42 end
function NetToPed(n) return n == 42 and 500 or 77 end
function NetToVeh() return 88 end
function VehToNet() return 3001 end
function GetActivePlayers() return { 0, 3 } end
function GetPlayerPed(pl) return pl == 0 and 1 or 77 end
function GetPlayerServerId(pl) return pl == 0 and 1 or 12 end
function GetPlayerFromServerId(s) return s == 12 and 3 or -1 end
function GetGamePool() return { 88 } end
function GetModelDimensions() return vector3(-1, -2.4, -0.5), vector3(1, 2.4, 1) end
function GetEntityMaxHealth() return 300 end
function GetEntityHealth() return 290 end
function GetVehiclePedIsIn() return 0 end
function IsPedInAnyVehicle() return false end
function IsEntityDead() return false end
function GetSelectedPedWeapon() return joaat('WEAPON_UNARMED') end
function IsModelInCdimage() return true end function IsModelValid() return true end function HasModelLoaded() return true end
function DoesAnimDictExist() return true end function HasAnimDictLoaded() return true end
function IsEntityPlayingAnim() return true end
function C_Ground() return 30.0 end
function GetGroundZFor_3dCoord() return true, 30.0 end
function GetVehicleNumberPlateText() return ' AB123CD ' end
function GetDisplayNameFromVehicleModel() return 'ADDER' end
function GetLabelText(s) return s end
function NetworkDoesNetworkIdExist() return true end
function NetworkHasControlOfEntity() return true end
function GetVehicleMaxNumberOfPassengers() return 3 end
function IsVehicleSeatFree() return true end
function GetEntityBoneIndexByName() return 2 end
function GetEntitySpeed() return 0.0 end
function GetEntityHeading() return 0.0 end
function GetEntityModel() return 1 end
function HasEntityClearLosToEntity() return true end
function IsControlJustPressed(_, c) return press_keys and press_keys[c] end
function IsDisabledControlJustPressed(_, c) return press_keys and press_keys[c] end
function GetPlayerName() return 'J' end
Entity = function() return { state = {} } end
exports = setmetatable({}, { __call = function(_, n, f) _G['EXP_' .. n] = f end, __index = function() return setmetatable({}, { __index = function() return function() end end }) end })
function RegisterNUICallback(n, f) nui[n] = f end
function RegisterNetEvent(n, f) if f then events[n] = f end end
function AddEventHandler(n, f) events[n] = f end
function SendNUIMessage(m) LASTNUI = m end
Ely = { notify = function(d) notes[#notes + 1] = d.description end, callback = { await = function(n, _, ...) local r = cbres[n] if type(r) == 'function' then return r(...) end if type(r) == 'table' and r.__multi then return table.unpack(r) end return r end } }
''')
g = L.globals()
# toute autre native (nom en majuscule) : fonction qui ne fait rien et renvoie 0
L.execute(r'''setmetatable(_G, { __index = function(_, k)
    if type(k) ~= 'string' or not k:match('^%u') then return nil end
    if k:match('^Is') or k:match('^Has') or k:match('^Does') then return function() return false end end
    return function() return 0 end
end })''')
def load(f):
    src = open(os.path.join(root, f), encoding='utf-8').read()
    src = re.sub(r'`([A-Z][A-Z0-9_]+)`', r'joaat("\1")', src)
    L.execute(src)
for f in ['config.lua', 'shared/k9.lua', 'client/main.lua', 'client/dog.lua', 'client/target.lua', 'client/victim.lua', 'client/training.lua', 'client/preview.lua', 'client/alt.lua']:
    load(f)
L.execute(r'''
C.Ground = function() return 30.0 end
function run(label, f)
    local co = coroutine.create(f)
    local ok, e = coroutine.resume(co)
    local n = 0
    while ok and coroutine.status(co) ~= 'dead' and n < 3000 do n = n + 1 ok, e = coroutine.resume(co) end
    -- fait tourner les autres fils (boucles, rappels)
    for _ = 1, 50 do for i, t in ipairs(threads) do if coroutine.status(t) ~= 'dead' then local ok2, e2 = coroutine.resume(t) if not ok2 then errors[#errors + 1] = label .. ' (fil) : ' .. tostring(e2) end end end end
    if not ok then errors[#errors + 1] = label .. ' : ' .. tostring(e) end
    return ok
end
local E = K9.Effects({ side = 'police', breed = 'shepherd', specialty = 'attack', level = 5, skills = { sniff = 2, obey = 3, track = 2, attack = 4 } })
cbres['elyzea_k9:requestSpawn'] = { true, { token = 't', model = 'a_c_shepherd', dog = { id = 1, name = 'Rex', health = 90 }, effects = E }, __multi = true }
run('sortir', function() C.SpawnDog('police') end)
assert(C.dog and C.dog.ped == 500, 'chien non sorti')
for _, o in ipairs({ 'follow', 'stay', 'sit', 'lie', 'come', 'defend', 'search', 'sniffp', 'sniffv', 'bark', 'intim', 'attack', 'takedown', 'track' }) do
    local target = (o == 'sniffv') and 3001 or 12
    cbres['elyzea_k9:order'] = { ok = true, obey = true, hesitate = 100, order = o, target = target, chase = 1, sniffMs = 600, seconds = 1, refresh = 500 }
    cbres['elyzea_k9:sniffPerson'] = { ok = true, marked = true, xp = 60 }
    cbres['elyzea_k9:sniffVehicle'] = { ok = true, marked = true, spots = { 'trunk', 'hidden_door', 'hidden_seat' }, xp = 60 }
    cbres['elyzea_k9:searchZone'] = { ok = true, spots = { { kind = 'person', x = 3, y = 0, z = 30 }, { kind = 'drugs', x = 4, y = 0, z = 30 } }, xp = 90 }
    cbres['elyzea_k9:intimidate'] = { ok = true, level = 3, seconds = 1 }
    cbres['elyzea_k9:contact'] = { ok = true, success = true, hold = 1, xp = 70 }
    cbres['elyzea_k9:trackPoint'] = { ok = true, found = true, x = 3, y = 0, z = 30, target = 12, xp = 90 }
    C.dog.busy = false
    run('ordre ' .. o, function() C.Order(o, target) end)
end
cbres['elyzea_k9:order'] = { ok = true, obey = false, fear = true, hesitate = 100 }
run('refus', function() C.Order('attack', 12) end)
-- ciblage : ouvrir, molette, changer d'ordre, confirmer
cbres['elyzea_k9:order'] = { ok = true, obey = true, hesitate = 0, order = 'bark', target = 12, seconds = 1 }
C.dog.busy = false
run('ciblage', function()
    C.StartTarget('bark')
    press_keys = { [15] = true } Wait() press_keys = { [175] = true } Wait() press_keys = { [174] = true } Wait() press_keys = { [38] = true } Wait() press_keys = nil
end)
-- victime
run('victime mise au sol', function() events['elyzea_k9:client:takedown']({ dog = 42, hold = 1, damage = 6, floor = 120 }) end)
run('victime intimidée', function() events['elyzea_k9:client:intimidated']({ dog = 42, level = 5, seconds = 1 }) end)
-- exercices (E automatique)
for _, ex in ipairs({ 'obey', 'sniff', 'track', 'attack', 'defense', 'intim' }) do
    cbres['elyzea_k9:exStart'] = { true, { effects = E, seconds = 60 }, __multi = true }
    cbres['elyzea_k9:exFinish'] = { true, { xp = 40, score = 0.8 }, __multi = true }
    C.dog.ex, C.dog.busy = nil, false
    press_keys = { [38] = true, [47] = true }
    run('exercice ' .. ex, function() C.StartExercise(ex) end)
    press_keys = nil
end
-- ALT
assert(EXP_AltTarget(500) ~= nil, 'ALT : chien non reconnu')
assert(#EXP_AltOptions({ entity = 500 }) >= 8, 'ALT : options')
run('ALT', function() EXP_AltSelect('sit', { entity = 500 }) end)
-- menu (NUI)
cbres['elyzea_k9:open'] = { ok = true, sides = {}, breeds = { { id = 'shepherd', model = 'a_c_shepherd' } } }
run('menu', function() C.OpenMenu() nui.close({}, function() end) end)
run('aperçu', function() C.Preview('a_c_shepherd') Wait() C.PreviewRotate(30) C.StopPreview() end)
cbres['elyzea_k9:store'] = true
run('renvoyer', function() C.StoreDog() end)
assert(C.dog == nil, 'chien non rangé')
''')
for n in g.notes.values(): print('  note :', n)
errs = list(g.errors.values())
for e in errs: print('  ERREUR', e)
print(f'{len(list(g.notes.values()))} notifications ; {len(errs)} erreur(s)')
sys.exit(1 if errs else 0)
