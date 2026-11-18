#!/usr/bin/env python3
"""Essai hors jeu du CLIENT d'elyzea_entreprises : charge les fichiers client avec des natives imitées et exécute
F6, la tablette, la proposition de recrutement, le panneau staff. Ne remplace pas un essai en jeu.
python3 tests/client_smoke.py"""
import os, sys, re
from lupa import lua54
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = lua54.LuaRuntime(unpack_returned_tuples=True)
L.execute(r'''
threads, nui, cmds, keys, events, sent, errors, server, notes = {}, {}, {}, {}, {}, {}, {}, {}, {}
function CreateThread(f) local co = coroutine.create(f) threads[#threads + 1] = co local ok, e = coroutine.resume(co) if not ok then errors[#errors + 1] = e end end
function Wait() if coroutine.isyieldable() then coroutine.yield() end end
T = 0 function GetGameTimer() T = T + 50 return T end
cur_state = nil
LocalPlayer = { state = setmetatable({}, { __index = function(_, k) if k == 'ent' then return cur_state end end }) }
function GetPlayerServerId() return 1 end function PlayerId() return 0 end function PlayerPedId() return 1 end
function RegisterNUICallback(n, f) nui[n] = f end
function RegisterCommand(n, f) cmds[n] = f end
function RegisterKeyMapping(n, _, _, k) keys[n] = k end
function RegisterNetEvent(n, f) if f then events[n] = f end end
function AddEventHandler(n, f) events[n] = f end
function AddStateBagChangeHandler(k, _, f) events['bag:' .. k] = f end
function SendNUIMessage(m) sent[#sent + 1] = m end
function TriggerServerEvent(n, ...) server[#server + 1] = { n, ... } end
FOCUS = false function SetNuiFocus(a) FOCUS = a end function SetNuiFocusKeepInput() end
JOBPHONE = 'started' TOGGLED = 0
function GetResourceState(r) if r == 'elyzea_jobphone' then return JOBPHONE end return 'started' end
exports = setmetatable({}, { __call = function(_, n, f) _G['EXP_' .. n] = f end, __index = function(_, r)
  if r == 'elyzea_jobphone' then return { TakesF6 = function() return true end, Toggle = function() TOGGLED = TOGGLED + 1 end } end
  if r == 'elyzea_core' then return { Notify = function(_, m) notes[#notes + 1] = m end } end
  return setmetatable({}, { __index = function() return function() end end }) end })
REPLY = {}
Ely = { callback = { await = function(name, _, action) local r = REPLY[name .. ':' .. tostring(action)] return r or { ok = true } end } }
function IsPedRagdoll() return false end function IsEntityDead() return false end
function HasAnimDictLoaded() return true end function HasModelLoaded() return true end
function DoesEntityExist() return true end function CreateObject() return 5 end
''')
L.execute(r'''setmetatable(_G, { __index = function(_, k) if type(k) == 'string' and k:match('^%u') then return function() return 0 end end end })''')
def load(f):
    src = open(os.path.join(root, f), encoding='utf-8').read()
    src = re.sub(r'`([A-Za-z_][A-Za-z0-9_]*)`', r'0', src)
    L.execute(src)
for f in ['config.lua', 'shared/perms.lua', 'client/main.lua', 'client/tablet.lua', 'client/phone.lua']:
    load(f)
L.execute(r'''
local function run(label, f)
  local co = coroutine.create(f) local ok, e = coroutine.resume(co)
  for _ = 1, 20 do if coroutine.status(co) ~= 'dead' then ok, e = coroutine.resume(co) end end
  if not ok then errors[#errors + 1] = label .. ' : ' .. tostring(e) end
  for _ = 1, 5 do for _, t in ipairs(threads) do if coroutine.status(t) ~= 'dead' then local ok2, e2 = coroutine.resume(t) if not ok2 then errors[#errors + 1] = label .. ' (fil) : ' .. tostring(e2) end end end end
end
function check(c, l) print((c and '  ok   ' or '  ÉCHEC ') .. l) if not c then errors[#errors + 1] = l end end
check(keys.entreprise_menu == 'F6', 'touche F6 déclarée')
run('F6 sans entreprise', function() cmds.entreprise_menu() end)
check(TOGGLED == 0, 'F6 sans entreprise : rien')
cur_state = { shop = 1, shopName = 'Vinewood', perms = { tablet = true, duty = true }, duty = false }
run('F6', function() cmds.entreprise_menu() end)
check(TOGGLED == 1, 'F6 : sort le téléphone de service')
JOBPHONE = 'missing'
run('F6 sans téléphone', function() cmds.entreprise_menu() end)
check(FOCUS == true and sent[#sent].action == 'tablet' and sent[#sent].show, 'sans téléphone de service : la tablette s\'ouvre')
run('fermer', function() nui.close({ ui = 'tablet' }, function() end) end)
check(FOCUS == false, 'fermeture : curseur rendu')
run('tablette (téléphone)', function() EXP_OpenTablet() end)
check(FOCUS == true, 'export OpenTablet (appli Tablette du téléphone de service)')
run('fermer', function() nui.close({ ui = 'tablet' }, function() end) end)
check(EXP_UiBusy() == false, 'UiBusy : rien d\'ouvert')
run('offre', function() events['ent:client:recruitOffer']({ id = 7, from = 'Alice', grade = 'Employé', job = 'Vinewood', timeout = 30 }) end)
check(FOCUS == true and sent[#sent].action == 'offer', 'proposition de recrutement affichée')
run('accepter', function() nui.offerAnswer({ accept = true }, function() end) end)
check(server[#server][1] == 'ent:server:recruitAnswer' and server[#server][2] == 7 and server[#server][3] == true and FOCUS == false, 'réponse « Accepter » envoyée au serveur')
REPLY['ent:admin:list'] = { list = {} }
run('staff', function() cmds.entreprises_admin() end)
check(FOCUS == true and sent[#sent].action == 'admin', '/entreprises_admin : panneau staff')
run('staff fermer', function() cmds.entreprises_admin() end)
REPLY['ent:admin:list'] = { error = 'Réservé au staff' }
run('pas staff', function() cmds.entreprises_admin() end)
check(FOCUS == false and notes[#notes] == 'Réservé au staff', 'joueur non staff : refus')
run('perte', function() events['bag:ent'](nil, nil, nil) end)
run('débloquer', function() cmds.entreprise_debloquer() end)
check(FOCUS == false, '/entreprise_debloquer')
''')
errs = list(L.globals().errors.values())
for e in errs: print('  ERREUR', e)
print(f'{len(errs)} erreur(s)')
sys.exit(1 if errs else 0)
