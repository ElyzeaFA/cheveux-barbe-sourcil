#!/usr/bin/env python3
"""Simulation hors jeu du skate (client.lua + server.lua) avec de faux FiveM.  python3 tests/run_skate_sim.py"""
import os, sys
from lupa.lua54 import LuaRuntime
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fails = 0
def check(c, l):
    global fails
    print(('  ok   ' if c else '  ÉCHEC ') + l)
    if not c: fails += 1

# ------------------------------------------------------------------ client
L = LuaRuntime()
L.execute(r'''
T = 0
threads, events, exportsT = {}, {}, {}
function CreateThread(f) threads[#threads + 1] = coroutine.create(f) end
function Wait() coroutine.yield() end
function GetGameTimer() return T end
function GetFrameTime() return 0.016 end
local V = {} V.__index = V
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function joaat(s) return #s end
function IsModelInCdimage() return true end function RequestModel() end function HasModelLoaded() return true end function SetModelAsNoLongerNeeded() end
DICTS = { ['pickup_object'] = true, ['amb@world_human_stand_impatient@male@no_sign@base'] = true }   -- la 1re posture « n'existe pas » : repli testé
function DoesAnimDictExist(d) return DICTS[d] == true end
function RequestAnimDict() end function HasAnimDictLoaded(d) return DICTS[d] == true end
PLAYED = {}
function TaskPlayAnim(_, d, n) PLAYED[#PLAYED + 1] = d PLAYING = d end
function IsEntityPlayingAnim(_, d) return PLAYING == d end
function ClearPedTasks() PLAYING = nil end
function ClearPedTasksImmediately() PLAYING = nil end
PITCH = 0
function GetEntityPitch() return PITCH end
function IsPedRagdoll() return false end
ROLL = {}
function SetEntityRotation(e, x, y, z) ENT[e].h = z % 360 ROLL[#ROLL + 1] = y end
function SetEntityAngularVelocity() end
LOOK = 0
function TaskLookAtCoord() LOOK = LOOK + 1 end
function TaskClearLookAt() end
function PlayerPedId() return 1 end
ENT = { [1] = { pos = vector3(0, 0, 1), h = 0 } }
local nextE = 10
function CreateVehicle(_, x, y, z, h) nextE = nextE + 1 ENT[nextE] = { pos = vector3(x, y, z), h = h, vel = vector3(0, 0, 0), veh = true } return nextE end
function CreateObject(_, x, y, z) nextE = nextE + 1 ENT[nextE] = { pos = vector3(x, y, z), h = 0 } return nextE end
function DoesEntityExist(e) return ENT[e] ~= nil end
function GetEntityCoords(e) if ATT[e] then return worldOf(e) end return ENT[e].pos end
function GetEntityHeading(e) return ENT[e].h end
function SetEntityHeading(e, h) ENT[e].h = h end
function GetEntityForwardVector(e) local r = math.rad(ENT[e].h) return vector3(-math.sin(r), math.cos(r), 0) end
function GetOffsetFromEntityInWorldCoords(e, x, y, z) local p = ENT[e].pos return vector3(p.x + x, p.y + y, p.z + z) end
function GetEntityVelocity(e) return ENT[e].vel end
function SetEntityVelocity(e, x, y, z) ENT[e].vel = vector3(x, y, z) SETV = ENT[e].vel end
HAG = 0.18
function GetEntityHeightAboveGround() return HAG end
function GetEntityModel() return 1 end
function GetModelDimensions() return vector3(-0.1, -0.4, -0.05), vector3(0.1, 0.4, 0.05) end
ATT = {}
function AttachEntityToEntity(a, b, bone, x, y, z, rx, ry, rz) ATT[a] = { to = b, x = x, y = y, z = z, rx = rx, ry = ry, rz = rz } end
-- position réelle d'une entité attachée (véhicule au cap 0 pendant le recalage)
function worldOf(e) if ATT[e] then local p = worldOf(ATT[e].to) return vector3(p.x + ATT[e].x, p.y + ATT[e].y, p.z + ATT[e].z) end return ENT[e].pos end
-- personnage simulé : orteils 1,10 m sous le bassin, posés 10 cm trop à droite
-- pieds l'un devant l'autre selon le sens du corps (rz), 17 cm de part et d'autre, décalés de 10 cm à droite
function GetPedBoneCoords(ped, b)
    local p, a = worldOf(ped), ATT[ped]
    local r = math.rad(a and a.rz or 0)
    local k = ((b == 20781 or b == 14201) and -0.17 or 0.17)
    return vector3(p.x + 0.10 - math.sin(r) * k, p.y + math.cos(r) * k, p.z - 1.10)
end
function GetOffsetFromEntityGivenWorldCoords(e, x, y, z) local p = ENT[e].pos return vector3(x - p.x, y - p.y, z - p.z) end
function IsEntityAttachedToEntity(a, b) return ATT[a] and ATT[a].to == b end
function DetachEntity(a) ATT[a] = nil end
function IsPedInAnyVehicle() return false end function IsEntityDead() return false end
for _, n in ipairs({ 'SetVehicleOnGroundProperly', 'SetEntityVisible', 'SetVehicleDoorsLocked', 'SetVehicleEngineOn', 'SetVehicleRadioEnabled', 'SetEntityProofs',
  'SetEntityAsMissionEntity', 'SetEntityCollision', 'SetEntityCoordsNoOffset', 'SetEntityCoords', 'FreezeEntityPosition', 'SetVehicleHandbrake', 'BeginTextCommandDisplayHelp',
  'AddTextComponentSubstringPlayerName', 'DisableControlAction', 'AddEventHandler' }) do _G[n] = function() end end
RAG = false
HELPN = 0
function EndTextCommandDisplayHelp() HELPN = HELPN + 1 end
function SetPedToRagdoll() RAG = true end
SERVER = {}
function TriggerServerEvent(n, ...) SERVER[#SERVER + 1] = { n, ... } end
function NetworkGetNetworkIdFromEntity(e) return e + 1000 end
function RegisterNetEvent(n, f) events[n] = f end
function exports(n, f) exportsT[n] = f end
exports = setmetatable({}, { __call = function(_, n, f) exportsT[n] = f end, __index = function() return setmetatable({}, { __index = function() return function() end end }) end })
KEYS, JUST = {}, {}
function IsDisabledControlPressed(_, c) return KEYS[c] == true end
function IsDisabledControlJustPressed(_, c) return JUST[c] == true end
function IsControlJustPressed(_, c) return JUST[c] == true end
GROUNDF = function(x, y) return 0.0 end
function GetGroundZFor_3dCoord(x, y, z) local g = GROUNDF(x, y) if g > z then return false, 0.0 end return true, g end
WALL = false
function StartExpensiveSynchronousShapeTestLosProbe() return 1 end
function GetShapeTestResult() return 1, WALL and 1 or 0 end
function SetEntityHasGravity(e, on) ENT[e].grav = on end
function SetEntityCoordsNoOffset(e, x, y, z) ENT[e].pos = vector3(x, y, z) end
''')
L.execute(open(os.path.join(root, 'config.lua'), encoding='utf-8').read())
L.execute(open(os.path.join(root, 'client.lua'), encoding='utf-8').read())
L.execute(r'''
function step(n, ms)
  for _ = 1, n or 1 do
    T = T + (ms or 16)
    for _, c in ipairs(threads) do if coroutine.status(c) ~= 'dead' then local ok, e = coroutine.resume(c) if not ok then error(e) end end end
    JUST = {}
  end
end
-- placer : la co-routine de l'événement attend 450 ms
function fire(n, ...) local co = coroutine.create(events[n]) threads[#threads + 1] = co coroutine.resume(co, ...) end
''')
g = L.globals()
g.fire('elyzea_skate:place')
g.step(80)
placed = [e for e in g.SERVER.values() if e[1] == 'elyzea_skate:placed']
check(len(placed) == 1, 'objet utilisé : skate posé au sol, signalé au serveur')
L.execute("for e, x in pairs(ENT) do if x.veh then VEH = e end end")
VEH = g.VEH
check(g.ENT[VEH].pos.y > 0.3, 'posé devant le joueur')
check(g.ATT[1] is not None and g.ATT[1].to == VEH, 'facile : le joueur monte directement dessus')
g.step(60)
toe = L.eval("GetPedBoneCoords(1, 20781)")
deckz = L.eval("(function() for e, a in pairs(ATT) do if e ~= 1 then return worldOf(e).z + 0.05 end end end)()")
check(abs((toe.z - 0.04) - deckz) < 0.02, f'pieds recalés pile sur le plateau (écart {abs((toe.z - 0.04) - deckz) * 100:.1f} cm)')
feet = [L.eval(f"GetPedBoneCoords(1, {b})") for b in (20781, 35502)]
check(all(abs(f.x - g.ENT[VEH].pos.x) < 0.04 for f in feet), 'les DEUX pieds sur la planche : ligne des pieds tournée dans sa longueur, centrée (' + ', '.join(f'{(f.x - g.ENT[VEH].pos.x) * 100:+.1f} cm' for f in feet) + ' de l\'axe)')
check(all(abs(f.y - g.ENT[VEH].pos.y) < 0.35 for f in feet), 'pieds dans la longueur de la planche (ni devant, ni derrière)')
check(g.PLAYING == 'amb@world_human_stand_impatient@male@no_sign@base', 'posture DEBOUT jouée (repli automatique si une animation manque)')
MAX = 30 / 3.6
def spd():
    v = g.ENT[VEH].vel
    return (v.x ** 2 + v.y ** 2) ** 0.5
check(g.ENT[VEH].grav is False, 'sur le skate : déplacé directement (plus de physique qui accroche la route)')
# W : accélère en douceur jusqu'à 30 km/h
y0 = g.ENT[VEH].pos.y
L.execute("KEYS[32] = true")
sp = []
for _ in range(400):
    g.step(1)
    sp.append(spd())
mx = max(sp)
check(MAX - 0.01 < mx <= MAX + 1e-6, f'W : avance jusqu\'à {mx * 3.6:.1f} km/h, jamais plus de 30 km/h')
inc = [sp[i + 1] - sp[i] for i in range(len(sp) - 1)]
check(min(inc) >= -1e-9 and max(inc) < 0.06, 'accélération régulière : aucun à-coup, aucun recul')
check(g.ENT[VEH].pos.y - y0 > 20, f'le skate avance vraiment ({g.ENT[VEH].pos.y - y0:.0f} m)')
check(abs(g.exportsT['GetSpeed']() - 30) < 0.1, 'vitesse lisible par le HUD (export GetSpeed)')
# trottoir de 20 cm puis redescente : jamais bloqué, la vitesse ne bouge pas
yc = g.ENT[VEH].pos.y
L.execute(f"GROUNDF = function(x, y) if y > {yc + 2} and y < {yc + 7} then return 0.2 end return 0.0 end")
g.step(25)
z_up = g.ENT[VEH].pos.z
check(abs(z_up - (0.2 + 0.18)) < 0.02 and spd() > MAX - 0.01, f'trottoir : monté sans être bloqué ni ralenti ({spd() * 3.6:.0f} km/h)')
g.step(40)
check(abs(g.ENT[VEH].pos.z - 0.18) < 0.02 and spd() > MAX - 0.01, 'redescente du trottoir : toujours à pleine vitesse')
L.execute("GROUNDF = function() return 0.0 end")
# petits objets de la route : ignorés (seuls murs / véhicules sont testés, à hauteur de genou)
check(abs(g.ENT[VEH].pos.x) < 1e-6, 'tout droit : trajectoire parfaitement droite')
# vrai mur : arrêt net, sans tomber
L.execute("WALL = true")
g.step(2)
check(spd() < 0.01 and g.ATT[1] is not None and not g.RAG, 'mur ou véhicule devant : arrêt, le joueur reste sur le skate')
L.execute("WALL = false")
g.step(200)
# virage
h0 = g.ENT[VEH].h
L.execute("KEYS[34] = true")
g.step(62)
L.execute("KEYS[34] = false")
yaw = (g.ENT[VEH].h - h0) % 360
check(35 < yaw < 90, f'A : tourne en douceur ({yaw:.0f}° en 1 s à pleine vitesse)')
g.step(60)
# roue libre
L.execute("KEYS[32] = false")
s0 = spd()
g.step(62)
check(s0 - 1.5 < spd() < s0 - 0.8, f'touches lâchées : ralentit doucement ({s0 * 3.6:.0f} → {spd() * 3.6:.0f} km/h en 1 s)')
# S : freine puis recule
L.execute("KEYS[33] = true")
yb = None
mn = 99
for i in range(500):
    g.step(1)
    f = g.ENT[VEH].vel
    fwd = -__import__('math').sin(__import__('math').radians(g.ENT[VEH].h)) * f.x + __import__('math').cos(__import__('math').radians(g.ENT[VEH].h)) * f.y
    mn = min(mn, fwd)
check(-15 / 3.6 - 1e-6 <= mn < -15 / 3.6 + 0.01, f'S : freine puis recule ({-mn * 3.6:.0f} km/h max en arrière)')
L.execute("KEYS[33] = false")
g.step(400)
check(spd() < 0.01, 'touches lâchées : s\'arrête tout seul')
# plus de saut
L.execute("JUST[22] = true")
g.step(1)
check(g.ENT[VEH].vel.z <= 0.01, 'Espace : aucun saut')
# le serveur range le skate, on le ressort (objet utilisé) : on remonte directement
L.execute("KEYS[32] = false RAG = false SERVER = {}")
g.fire('elyzea_skate:stowed')
g.fire('elyzea_skate:place')
g.step(80)
check(g.ATT[1] is not None, 'objet réutilisé : skate reposé, on remonte directement')
# descendre avec F : le skate part directement dans l'inventaire
L.execute("JUST[23] = true")
g.step(2)
check(g.ATT[1] is None and not g.RAG, 'F : on descend, sans tomber')
L.execute("for e, x in pairs(ENT) do if x.veh then VEH2 = e end end")
check(g.ENT[g.VEH2].grav is True, 'en descendant : le skate retrouve sa physique normale')
check(g.PLAYING is None, 'après la descente : aucune animation en boucle, le joueur peut bouger')
g.step(30)
check(g.PLAYING is None, 'toujours libre quelques instants plus tard (plus de blocage)')
check(any(e[1] == 'elyzea_skate:pickup' and e[2] is True for e in g.SERVER.values()), 'F : le skate retourne directement dans l\'inventaire')

# ------------------------------------------------------------------ serveur
S = LuaRuntime()
S.execute(r'''
local V = {} V.__index = V
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
T = 0 function GetGameTimer() T = T + 2000 return T end
function CreateThread() end function SetTimeout() end function Wait() end
events, sent, USABLE = {}, {}, nil
function RegisterNetEvent(n, f) events[n] = f end
function AddEventHandler(n, f) events[n] = f end
function TriggerClientEvent(n, s, ...) sent[#sent + 1] = { n = n, s = s, a = { ... } } end
function GetResourceState() return 'started' end
function GetCurrentResourceName() return 'elyzea_skate' end
ITEMS = { [5] = 1 }
exports = setmetatable({}, { __index = function() return {
  RegisterUsableItem = function(_, n, f) USABLE = f end,
  GetItemCount = function(_, src) return ITEMS[src] or 0 end } end })
POS = { [5] = vector3(0, 0, 0) }
ENT = {}
function GetPlayerPed(s) return s end
function GetEntityCoords(e) return ENT[e] and ENT[e].pos or POS[e] end
function GetVehiclePedIsIn() return 0 end
function NetworkGetEntityFromNetworkId(n) return ENT[n] and n or 0 end
function DoesEntityExist(e) return ENT[e] ~= nil end
function DeleteEntity(e) ENT[e] = nil end
function NetworkGetEntityOwner(e) return ENT[e].owner end
function GetEntityModel(e) return ENT[e].model end
function joaat(s) return #s end
function GetPlayerPing() return 30 end
STATE = {}
function Entity(e) return { state = { set = function(_, k, v) STATE[e] = v end } } end
''')
S.execute(open(os.path.join(root, 'config.lua'), encoding='utf-8').read())
S.execute(open(os.path.join(root, 'server.lua'), encoding='utf-8').read())
S.execute(r'''
local f = events['onResourceStart'] f('elyzea_inventory')
function lastSent(n) for i = #sent, 1, -1 do if sent[i].n == n then return sent[i] end end end
function use(src) source = src return USABLE(src) end
function placed(src, v, p) source = src return events['elyzea_skate:placed'](v, p) end
''')
sg = S.globals()
# l'enregistrement de l'objet utilisable passe par un CreateThread non exécuté : on appelle register via onResourceStart (SetTimeout factice)
S.execute("SetTimeout = function(_, f) f() end; events['onResourceStart']('elyzea_inventory')")
check(sg.USABLE is not None, 'objet « skateboard » utilisable enregistré dans l\'inventaire')
sg.use(5)
check(sg.lastSent('elyzea_skate:place') is not None, 'utiliser : le client pose le skate')
S.execute("ENT[11] = { pos = vector3(0, 1, 0), owner = 5, model = #Config.BaseVehicle } ENT[12] = { pos = vector3(0, 1, 0), owner = 5, model = #Config.BoardProp }")
sg.placed(5, 11, 12)
check(sg.STATE[11] == 5, 'skate enregistré au nom du joueur')
S.execute("ENT[21] = { pos = vector3(0, 1, 0), owner = 6, model = #Config.BaseVehicle } ENT[22] = { pos = vector3(0, 1, 0), owner = 6, model = #Config.BoardProp }")
sg.placed(5, 21, 22)
check(sg.STATE[21] is None, 'entité d\'un autre joueur refusée')
S.execute("sent = {}")
sg.use(5)
check(sg.ENT[11] is None and sg.ENT[12] is None and sg.lastSent('elyzea_skate:stowed') is not None, 'réutiliser à côté : skate rangé (planche et base supprimées)')
sg.use(5)
S.execute("ENT[31] = { pos = vector3(0, 1, 0), owner = 5, model = #Config.BaseVehicle } ENT[32] = { pos = vector3(0, 1, 0), owner = 5, model = #Config.BoardProp }")
sg.placed(5, 31, 32)
S.execute("POS[5] = vector3(300, 0, 0) sent = {}")
sg.use(5)
check(sg.ENT[31] is None and sg.lastSent('elyzea_skate:place') is not None, 'skate loin : l\'ancien disparaît, un nouveau est posé')
S.execute("ENT[41] = { pos = vector3(300, 1, 0), owner = 5, model = #Config.BaseVehicle } ENT[42] = { pos = vector3(300, 1, 0), owner = 5, model = #Config.BoardProp }")
sg.placed(5, 41, 42)
S.execute("source = 5 events['playerDropped']()")
check(sg.ENT[41] is None and sg.ENT[42] is None, 'déconnexion : le skate disparaît (l\'objet reste dans l\'inventaire)')
S.execute("ITEMS[5] = 0 ENT[51] = { pos = vector3(0, 1, 0), owner = 5, model = #Config.BaseVehicle } ENT[52] = { pos = vector3(0, 1, 0), owner = 5, model = #Config.BoardProp }")
sg.placed(5, 51, 52)
check(sg.ENT[51] is None, 'sans l\'objet dans l\'inventaire : aucun skate')
S.execute("ITEMS[5] = 1 POS[5] = vector3(0, 0, 0) ENT[61] = { pos = vector3(6, 0, 0), owner = 5, model = #Config.BaseVehicle } ENT[62] = { pos = vector3(6, 0, 0), owner = 5, model = #Config.BoardProp }")
sg.placed(5, 61, 62)
S.execute("source = 5 events['elyzea_skate:pickup'](true)")
check(sg.ENT[61] is None and sg.lastSent('elyzea_skate:stowed') is not None, 'descente : skate rangé même s\'il a roulé quelques mètres')
print('\nÉCHECS :', fails)
sys.exit(1 if fails else 0)
