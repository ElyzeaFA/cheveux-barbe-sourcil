-- Scénario du test serveur (lancé par run_server_sim.py) : deux joueurs, vrai inventaire, vraie base.
local fails, passes = 0, 0
local function check(c, l) if c then passes = passes + 1 io.write('  ok    ', l, '\n') else fails = fails + 1 io.write('  ÉCHEC ', l, '\n') end end
local function section(t) io.write('\n[', t, ']\n') end
local function step() NOW = NOW + 2000 end   -- anti-spam entre deux actions

BOOT()
local I = LET.Config.Items
local INVX = function() return EXPORTS.elyzea_inventory end
local function join(src, cid, name, pos) PLAYERS[src] = { cid = cid, name = name, pos = pos } FIRE('elyzea_inv:ready', src) end
local function count(src, item, md) return INVX().Search(src, 'count', item, md) end
local function slots(src, item) return INVX().Search(src, 'slots', item) end
local function slotOf(src, item, md) local l = INVX().Search(src, 'slots', item, md) return l[1] and l[1].slot, l[1] end
local function lastSent(src, ev) for i = #SENT, 1, -1 do local s = SENT[i] if s.s == src and s.n == ev then return s end end end
local function lastNote(src) for i = #NOTES, 1, -1 do if NOTES[i].s == src then return NOTES[i].text or '' end end return '' end
local function clearLogs() SENT, NOTES = {}, {} end
local function use(src, item, md) step() local s = slotOf(src, item, md) FIRE('elyzea_inv:action', src, 'use', { from = s }) end
local function openWriter(src) clearLogs() use(src, I.paper) local o = lastSent(src, 'elyzea_lettres:openWriter') return o and o.args[1] end
local function finish(src, token, data) step() clearLogs() FIRE('elyzea_lettres:finish', src, token, data) local r = lastSent(src, 'elyzea_lettres:finished') return r and r.args[1], r and r.args[2] end
local function dbCount() return py_scalar('SELECT COUNT(*) FROM `elyzea_letters`') end
local function dbRow(id) return py_single('SELECT * FROM `elyzea_letters` WHERE `id` = ?', { id }) end
local function readAs(src, md) clearLogs() use(src, I.letter, md) local r = lastSent(src, 'elyzea_lettres:read') return r and r.args[1], r and r.args[2] end

join(1, 'CIT001', 'Hugo Martin', vector3(0, 0, 0))
join(2, 'CIT002', 'Élodie Faure', vector3(1.5, 0, 0))

-- =========================================================
section('Rédaction : feuille et stylo')
INVX().AddItem(1, I.paper, 3)
openWriter(1)
check(lastSent(1, 'elyzea_lettres:openWriter') == nil and lastNote(1):find('stylo'), 'feuille sans stylo : refus « ' .. lastNote(1) .. ' »')
check(count(1, I.paper) == 3, 'feuille non consommée par la tentative')
INVX().AddItem(2, I.pen, 1)
clearLogs() use(2, I.pen)
check(lastSent(2, 'elyzea_lettres:openWriter') == nil and lastNote(2):find('feuille'), 'stylo sans feuille : refus « ' .. lastNote(2) .. ' »')
INVX().AddItem(1, I.pen, 1)
local W = openWriter(1)
check(W and type(W.token) == 'string' and W.limits.maxChars == 3000 and W.limits.maxPages == 4 and #W.fonts == 3, 'feuille + stylo : la feuille s\'ouvre (jeton, limites, 3 styles)')
check(W and W.date:find('^Los Santos, le %d') ~= nil, 'date du jour en français : « ' .. tostring(W and W.date) .. ' »')
check(count(1, I.paper) == 3 and count(1, I.pen) == 1, 'ouvrir la feuille ne consomme rien')

section('Annuler')
step() FIRE('elyzea_lettres:cancel', 1, W.token, false)
check(count(1, I.paper) == 3, 'annulation : feuille non consommée')
W = openWriter(1)
step() FIRE('elyzea_lettres:saveDraft', 1, W.token, { recipient = 'Élodie', body = 'Chère Élodie,\n\nBrouillon…', signature = 'Hugo', font = 'naturelle', paper = 'ligne' })
step() FIRE('elyzea_lettres:cancel', 1, W.token, true, { recipient = 'Élodie', body = 'Chère Élodie,\n\nBrouillon gardé', signature = 'Hugo', font = 'naturelle', paper = 'ligne' })
check(count(1, I.paper) == 3, 'annulation avec brouillon : feuille non consommée')
W = openWriter(1)
check(W.draft and W.draft.body == 'Chère Élodie,\n\nBrouillon gardé' and W.draft.font == 'naturelle' and W.draft.paper == 'ligne', 'brouillon retrouvé à la feuille suivante (texte, style, papier)')
step() FIRE('elyzea_lettres:cancel', 2, W.token, false)
check(LET.Letters.getDraft('CIT001') ~= nil, 'un autre joueur ne peut pas annuler la feuille de quelqu\'un (jeton lié au joueur)')

section('Validation côté serveur')
local good = { recipient = 'Élodie Faure', body = 'Chère Élodie,\n\nÇa fait longtemps ! « Où es-tu ? » L\'été… cœur, Œdipe, à è ù ê ï — 100 % d\'accord 😊\n   Retrait gardé.\n\nÀ bientôt.',
    signature = 'Ton ami, Hugo', font = 'elegante', paper = 'creme', pages = 1 }
local function with(t) local r = {} for k, v in pairs(good) do r[k] = v end for k, v in pairs(t) do r[k] = v end return r end
local ok, msg = finish(1, 'faux-jeton', good)
check(ok == false and msg:find('plus ouverte'), 'jeton inventé : refusé')
ok, msg = finish(1, W.token, with({ body = '   \n\n  ' }))
check(ok == false and msg:find('vide'), 'lettre vide : refusée')
ok, msg = finish(1, W.token, with({ body = ('a'):rep(3001) }))
check(ok == false and msg:find('3000'), 'plus de 3000 caractères : refusée')
ok, msg = finish(1, W.token, with({ font = 'comic' }))
check(ok == false and msg:find('style'), 'style d\'écriture inexistant : refusé')
ok, msg = finish(1, W.token, with({ paper = 'or' }))
check(ok == false and msg:find('papier'), 'papier inexistant : refusé')
ok, msg = finish(1, W.token, with({ body = ('ligne\n'):rep(120), pages = 1 }))
check(ok == false and msg:find('pages'), '120 lignes annoncées sur 1 page : refusé (contrôle des pages)')
ok, msg = finish(1, W.token, with({ recipient = ('x'):rep(61) }))
check(ok == false and msg:find('Destinataire'), 'destinataire trop long : refusé')
ok, msg = finish(1, W.token, with({ body = '\255\254 invalide' }))
check(ok == false, 'texte qui n\'est pas de l\'UTF-8 : refusé')
check(count(1, I.paper) == 3 and count(1, I.letter) == 0 and dbCount() == 0, 'après tous ces refus : 3 feuilles, aucune lettre, rien en base')

section('Terminer la lettre')
ok, msg = finish(1, W.token, good)
check(ok == true, 'lettre valide : acceptée (' .. tostring(msg) .. ')')
check(count(1, I.paper) == 2, 'une seule feuille consommée (3 → 2)')
check(count(1, I.pen) == 1, 'le stylo n\'est pas consommé')
local L1s, L1 = slotOf(1, I.letter)
check(L1 and type(L1.metadata.letter) == 'string' and L1.metadata.label == 'Lettre · Élodie Faure', 'objet « lettre » dans l\'inventaire : ' .. tostring(L1 and L1.metadata.label))
check(L1 and L1.metadata.body == nil and L1.metadata.description:find('Pour : Élodie Faure'), 'le texte n\'est pas dans l\'objet (seulement l\'identifiant et l\'étiquette)')
local id1 = L1.metadata.letter
local row = dbRow(id1)
check(row and row.body == good.body, 'texte enregistré à l\'identique (accents, guillemets, emoji, retours à la ligne, retrait)')
check(row and row.recipient == 'Élodie Faure' and row.signature == 'Ton ami, Hugo' and row.font == 'elegante' and row.paper == 'creme', 'destinataire, signature, style et papier enregistrés')
check(row and row.author_cid == 'CIT001' and row.author_name == 'Hugo Martin' and row.pages == 1 and row.layout == 'lettre-v1' and row.created, 'auteur, pages, mise en page et date enregistrés')
check(LET.Letters.getDraft('CIT001') == nil, 'brouillon supprimé une fois la lettre terminée')
ok, msg = finish(1, W.token, good)
check(ok == false and count(1, I.paper) == 2 and count(1, I.letter) == 1 and dbCount() == 1, 'même jeton renvoyé une 2e fois : refusé, rien de consommé ni créé en double')

section('Plusieurs lettres indépendantes')
W = openWriter(1)
ok = finish(1, W.token, with({ recipient = 'Marc', body = 'Deuxième lettre, pour Marc.', signature = 'H.' }))
local letters1 = slots(1, I.letter)
check(ok == true and #letters1 == 2 and letters1[1].slot ~= letters1[2].slot, 'deux lettres = deux objets distincts (non empilés)')
check(letters1[1].metadata.letter ~= letters1[2].metadata.letter and dbCount() == 2, 'identifiants différents, deux lignes en base')
local id2 = letters1[1].metadata.letter == id1 and letters1[2].metadata.letter or letters1[1].metadata.letter
check(dbRow(id2).body == 'Deuxième lettre, pour Marc.' and dbRow(id1).body == good.body, 'aucune lettre n\'écrase l\'autre')

section('Lecture')
local v, o = readAs(1, { letter = id1 })
check(v and v.body == good.body and v.recipient == 'Élodie Faure' and v.signature == 'Ton ami, Hugo' and v.font == 'elegante' and v.paper == 'creme', 'lecture : texte, destinataire, signature, style, papier')
check(v and v.date:find('Los Santos, le') and v.pages == 1, 'lecture : date et pages')
check(count(1, I.letter) == 2, 'lire ne consomme pas la lettre')
v = readAs(1, { letter = id1 })
check(v and v.body == good.body, 'relue une 2e fois : identique')

section('Donner la lettre au joueur 2')
step()
FIRE('elyzea_inv:action', 1, 'give', { from = slotOf(1, I.letter, { letter = id1 }), target = 2 })
check(count(1, I.letter, { letter = id1 }) == 0 and count(2, I.letter, { letter = id1 }) == 1, 'la lettre passe du joueur 1 au joueur 2')
local _, L2 = slotOf(2, I.letter, { letter = id1 })
check(L2.metadata.label == L1.metadata.label and L2.metadata.description == L1.metadata.description, 'étiquette conservée au transfert')
check(count(2, I.paper) == 0, 'le joueur 2 n\'a pas de feuille')
v = readAs(2, { letter = id1 })
check(v and v.body == good.body and v.signature == 'Ton ami, Hugo', 'le joueur 2 lit EXACTEMENT le même texte, sans feuille')

section('Protection des métadonnées')
step()
FIRE('elyzea_inv:action', 2, 'renameWeapon', { slot = slotOf(2, I.letter, { letter = id1 }), name = 'Fausse lettre' })
_, L2 = slotOf(2, I.letter, { letter = id1 })
check(L2.metadata.label == 'Lettre · Élodie Faure', 'renommer la lettre depuis l\'inventaire : refusé')
check(dbRow(id1).body == good.body, 'le contenu en base n\'a pas bougé')
local nrows = dbCount()
-- le client ne peut jamais choisir l'identifiant lu : il vient de l'objet que le serveur trouve dans l'inventaire
clearLogs() FIRE('elyzea_lettres:openEnvelope', 2)
check(lastSent(2, 'elyzea_lettres:read') == nil, 'ouvrir une enveloppe qu\'on n\'a pas : rien')
check(dbCount() == nrows, 'aucune lettre créée sans passer par une feuille')

section('Coffre')
INV.RegisterStash('coffre_test', 'Coffre test', 10, 50000)
INV.ForceOpen(2, 'stash', 'coffre_test')
step()
FIRE('elyzea_inv:action', 2, 'store', { from = slotOf(2, I.letter, { letter = id1 }) })
check(count(2, I.letter) == 0 and INVX().Search('coffre_test', 'count', I.letter, { letter = id1 }) == 1, 'lettre déposée dans le coffre')
FIRE('elyzea_inv:close', 2)
local stashRow = py_scalar('SELECT `items` FROM `elyzea_stashes` WHERE `id` = ?', { 'coffre_test' })
check(stashRow and stashRow:find(id1, 1, true), 'coffre sauvegardé en base avec la lettre')
INV.ForceOpen(1, 'stash', 'coffre_test')
local cs = INVX().Search('coffre_test', 'slots', I.letter)[1]
step()
FIRE('elyzea_inv:action', 1, 'take', { from = cs.slot })
FIRE('elyzea_inv:close', 1)
check(count(1, I.letter, { letter = id1 }) == 1 and INVX().Search('coffre_test', 'count', I.letter) == 0, 'le joueur 1 la récupère dans le coffre')
v = readAs(1, { letter = id1 })
check(v and v.body == good.body, 'lettre récupérée : contenu intact')

section('Enveloppe')
INVX().AddItem(1, I.envelope, 1)
v, o = readAs(1, { letter = id1 })
check(o and o.canEnvelope == true, 'lecture avec une enveloppe vide sur soi : « Mettre sous enveloppe » proposé')
step() clearLogs() FIRE('elyzea_lettres:putInEnvelope', 1)
local _, E = slotOf(1, I.sealed, { letter = id1 })
check(E and count(1, I.letter, { letter = id1 }) == 0 and count(1, I.envelope) == 0, 'lettre glissée dans l\'enveloppe (lettre et enveloppe vide retirées)')
check(E and E.metadata.label == 'Enveloppe · Élodie Faure' and not E.metadata.opened, 'enveloppe cachetée au nom du destinataire')
clearLogs() use(1, I.sealed, { letter = id1 })
local env = lastSent(1, 'elyzea_lettres:envelope')
check(env and env.args[1].recipient == 'Élodie Faure' and env.args[1].opened == false and env.args[1].body == nil, 'enveloppe vue : destinataire seulement, pas le texte')
step() clearLogs() FIRE('elyzea_lettres:openEnvelope', 1)
local rd = lastSent(1, 'elyzea_lettres:read')
_, E = slotOf(1, I.sealed, { letter = id1 })
check(rd and rd.args[1].body == good.body and rd.args[2].fromEnvelope and E.metadata.opened == true, 'enveloppe ouverte : la lettre se lit, l\'enveloppe reste « ouverte »')
step() FIRE('elyzea_inv:action', 1, 'give', { from = slotOf(1, I.sealed, { letter = id1 }), target = 2 })
check(count(2, I.sealed, { letter = id1 }) == 1, 'l\'enveloppe se donne comme un objet')
step() clearLogs() FIRE('elyzea_lettres:takeOut', 1)
check(count(1, I.letter, { letter = id1 }) == 0, 'sortir la lettre d\'une enveloppe donnée entre-temps : impossible')
clearLogs() use(2, I.sealed, { letter = id1 })
step() FIRE('elyzea_lettres:openEnvelope', 2)
step() FIRE('elyzea_lettres:takeOut', 2)
check(count(2, I.letter, { letter = id1 }) == 1 and count(2, I.sealed) == 0, 'le joueur 2 sort la lettre de l\'enveloppe')

section('Réglages (menu admin) : consommation par page')
PERMS[1] = { lettres_manage = true }
local okA = EXPORTS.elyzea_lettres.AdminAction(2, 'save', { consume = 'page' })
check(okA == false and LET.Letters.getSettings().consume == 'letter', 'sans la permission : réglages refusés')
okA = EXPORTS.elyzea_lettres.AdminAction(1, 'save', { maxChars = 99999, maxPages = 6, consume = 'page', fonts = { elegante = false, naturelle = true, arrondie = true },
    papers = { creme = true, ligne = false, ancien = true }, envelopes = true, animation = false, defaultFont = 'elegante' })
local S = LET.Letters.getSettings()
check(okA == true and S.maxChars == 10000 and S.maxPages == 6 and S.consume == 'page' and S.fonts.elegante == false and S.defaultFont == 'naturelle' and S.animation == false,
    'réglages enregistrés, bornés (99 999 → 10 000) et cohérents (style par défaut désactivé → naturelle)')
W = openWriter(1)
check(#W.fonts == 2 and W.fonts[1].id == 'naturelle' and #W.papers == 2 and W.animation == false, 'la feuille suivante applique les réglages (styles, papiers, animation)')
local long = ('Une ligne de lettre assez longue pour remplir.\n'):rep(30)
check(count(1, I.paper) == 1, 'le joueur 1 n\'a plus qu\'une feuille')
ok, msg = finish(1, W.token, { recipient = 'X', body = long, signature = 'H', font = 'naturelle', paper = 'creme', pages = 2 })
check(ok == false and msg:find('2 feuilles'), '2 pages avec 1 feuille (1 feuille / page) : refusé « ' .. tostring(msg) .. ' »')
INVX().AddItem(1, I.paper, 4)
ok = finish(1, W.token, { recipient = 'X', body = long, signature = 'H', font = 'naturelle', paper = 'creme', pages = 1 })
local _, L3 = slotOf(1, I.letter, { label = 'Lettre · X' })
check(ok == true and count(1, I.paper) == 3 and dbRow(L3.metadata.letter).pages == 2, 'pages annoncées trop basses (1) : le serveur compte 2 pages et prend 2 feuilles (5 → 3)')
EXPORTS.elyzea_lettres.AdminAction(1, 'reset')
check(LET.Letters.getSettings().consume == 'letter' and LET.Letters.getSettings().fonts.elegante == true, 'valeurs par défaut rétablies')

section('Inventaire plein')
local inv1 = INV.Inv[1]
local filled = {}
-- toutes les cases libres prises par des objets légers (le poids reste sous la limite, comme en jeu)
local function fill() filled = {} for i = 1, inv1.size do if not inv1.slots[i] then inv1.slots[i] = { name = 'carte_identite', count = 1 } filled[#filled + 1] = i end end end
local function unfill() for _, i in ipairs(filled) do inv1.slots[i] = nil end end
INVX().AddItem(1, I.paper, 3)
W = openWriter(1)
fill()
local before, rows = count(1, I.paper), dbCount()
ok, msg = finish(1, W.token, with({ body = 'Lettre sans place.' }))
check(ok == false and msg:find('plein') and count(1, I.paper) == before and dbCount() == rows and count(1, I.letter, { label = 'Lettre · Élodie Faure' }) >= 0, 'plus aucune case et plusieurs feuilles : refusé, aucune feuille perdue, rien en base')
unfill()
ok = finish(1, W.token, with({ body = 'Lettre avec de la place.' }))
check(ok == true and count(1, I.paper) == before - 1 and dbCount() == rows + 1, 'case libérée : même feuille, même jeton, lettre créée (1 feuille utilisée)')
-- dernière feuille et inventaire plein : la lettre prend la place de la feuille
local extra = count(1, I.paper) - 1
INVX().RemoveItem(1, I.paper, extra)
W = openWriter(1)
fill()
local nl = count(1, I.letter)
ok, msg = finish(1, W.token, with({ body = 'Écrite sur la dernière feuille.' }))
check(ok == true and count(1, I.paper) == 0 and count(1, I.letter) == nl + 1, 'dernière feuille, inventaire plein : la lettre remplace la feuille (' .. tostring(msg) .. ')')
unfill()
INVX().AddItem(1, I.paper, extra)

section('Nettoyage du texte')
W = openWriter(1)
ok = finish(1, W.token, with({ recipient = 'A\nB', body = 'L1\r\nL2\0\27[31m\226\128\174RTL', signature = 'S' }))
local last = slots(1, I.letter)
local newest
for _, s in ipairs(last) do local r = dbRow(s.metadata.letter) if r.body:find('^L1') then newest = r end end
check(ok == true and newest and newest.body == 'L1\nL2[31mRTL' and newest.recipient == 'A B', 'retours Windows normalisés, caractères de contrôle et d\'inversion retirés')

section('Déconnexion pendant l\'écriture')
INVX().AddItem(2, I.paper, 1)
W = openWriter(2)
FIRE('playerDropped', 2)
join(2, 'CIT002', 'Élodie Faure', vector3(1.5, 0, 0))
check(count(2, I.paper) == 1, 'déconnexion pendant l\'écriture : feuille non consommée (retrouvée à la reconnexion)')
ok, msg = finish(2, W.token, good)
check(ok == false, 'après reconnexion, l\'ancienne feuille ne peut plus être validée')

section('Sauvegarde, redémarrage, persistance')
local totalBefore = dbCount()
local keys = {}
for _, src in ipairs({ 1, 2 }) do for _, s in ipairs(slots(src, I.letter)) do keys[#keys + 1] = { src = src, id = s.metadata.letter, label = s.metadata.label } end end
for _, src in ipairs({ 1, 2 }) do INV.SaveInventory(src) end
-- la ressource redémarre : tout l'état Lua des deux ressources est perdu, seuls la base et les KVP restent
PLAYERS = {}
BOOT()
join(1, 'CIT001', 'Hugo Martin', vector3(0, 0, 0))
join(2, 'CIT002', 'Élodie Faure', vector3(1.5, 0, 0))
local allBack, sameText = true, true
for _, k in ipairs(keys) do
    if count(k.src, I.letter, { letter = k.id }) ~= 1 then allBack = false end
    local _, s = slotOf(k.src, I.letter, { letter = k.id })
    if not s or s.metadata.label ~= k.label then allBack = false end
end
check(#keys >= 5 and allBack, ('%d lettres retrouvées chez leur propriétaire après redémarrage, étiquettes intactes'):format(#keys))
v = readAs(2, { letter = id1 })
check(v and v.body == good.body, 'après redémarrage : texte identique au caractère près')
check(dbCount() == totalBefore, 'aucune lettre perdue ni dupliquée en base')
local n = 0
for _, src in ipairs({ 1, 2 }) do n = n + #slots(src, I.letter) end
check(n == #keys, 'aucun objet lettre dupliqué ou perdu dans les inventaires')
check(count(1, I.pen) == 1, 'le stylo est toujours là')
-- réglages et brouillons survivent aussi (KVP)
PERMS[1] = { lettres_manage = true }
EXPORTS.elyzea_lettres.AdminAction(1, 'save', { maxChars = 1500 })
INVX().AddItem(1, I.paper, 1)
W = openWriter(1)
step() FIRE('elyzea_lettres:cancel', 1, W.token, true, { recipient = 'R', body = 'Brouillon avant redémarrage', signature = '', font = 'elegante', paper = 'creme' })
for _, src in ipairs({ 1, 2 }) do INV.SaveInventory(src) end
PLAYERS = {}
BOOT()
join(1, 'CIT001', 'Hugo Martin', vector3(0, 0, 0))
W = openWriter(1)
check(W and W.limits.maxChars == 1500 and W.draft and W.draft.body == 'Brouillon avant redémarrage', 'réglages et brouillon conservés au redémarrage')

section('Menu admin : données')
local AD = EXPORTS.elyzea_lettres.AdminData()
check(AD.stats.total == dbCount() and #AD.recent >= 5 and AD.recent[1].author_name and AD.recent[1].body == nil, 'statistiques et dernières lettres, sans le contenu')

io.write(('\n%d réussi(s), %d échec(s)\n'):format(passes, fails))
return fails
