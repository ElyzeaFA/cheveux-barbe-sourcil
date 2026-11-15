-- =====================================================================
--  ELYZEA CACHETTES - emplacements (partagé client / serveur)
--  id : identifiant enregistré en base · type : mini-jeu et capacité · where : texte des notifications
--  door : index de porte GTA à ouvrir pendant le démontage · bone : os du modèle (détection côté client)
--  seat : index de siège GTA (-1 = conducteur)
-- =====================================================================
Slots = {
    door_fl  = { type = 'door',   label = 'Portière avant gauche',       where = 'de la portière avant gauche',      door = 0, bone = 'door_dside_f' },
    door_fr  = { type = 'door',   label = 'Portière avant droite',       where = 'de la portière avant droite',      door = 1, bone = 'door_pside_f' },
    door_rl  = { type = 'door',   label = 'Portière arrière gauche',     where = 'de la portière arrière gauche',    door = 2, bone = 'door_dside_r' },
    door_rr  = { type = 'door',   label = 'Portière arrière droite',     where = 'de la portière arrière droite',    door = 3, bone = 'door_pside_r' },
    trunk    = { type = 'trunk',  label = 'Coffre (garniture)',          where = 'du coffre du véhicule',            door = 5, bone = 'boot' },
    wheel_fl = { type = 'wheel',  label = 'Passage de roue avant gauche', where = 'du passage de roue avant gauche', bone = 'wheel_lf' },
    wheel_fr = { type = 'wheel',  label = 'Passage de roue avant droit', where = 'du passage de roue avant droit',   bone = 'wheel_rf' },
    wheel_rl = { type = 'wheel',  label = 'Passage de roue arrière gauche', where = 'du passage de roue arrière gauche', bone = 'wheel_lr' },
    wheel_rr = { type = 'wheel',  label = 'Passage de roue arrière droit', where = 'du passage de roue arrière droit', bone = 'wheel_rr' },
    seat_d   = { type = 'seat',   label = 'Siège conducteur',            where = 'du siège conducteur',              seat = -1, door = 0, bone = 'seat_dside_f' },
    seat_p   = { type = 'seat',   label = 'Siège passager avant',        where = 'du siège passager avant',          seat = 0,  door = 1, bone = 'seat_pside_f' },
    seat_rl  = { type = 'seat',   label = 'Siège arrière gauche',        where = 'du siège arrière gauche',          seat = 1,  door = 2, bone = 'seat_dside_r' },
    seat_rr  = { type = 'seat',   label = 'Siège arrière droit',         where = 'du siège arrière droit',           seat = 2,  door = 3, bone = 'seat_pside_r' },
    saddle   = { type = 'saddle', label = 'Compartiment sous la selle',  where = 'du compartiment sous la selle',    bone = 'seat_f' },
}
SlotOrder = { 'door_fl', 'door_fr', 'door_rl', 'door_rr', 'trunk', 'wheel_fl', 'wheel_fr', 'wheel_rl', 'wheel_rr', 'seat_d', 'seat_p', 'seat_rl', 'seat_rr', 'saddle' }

SlotTypeLabels = { door = 'Portières', trunk = 'Coffre', wheel = 'Passages de roue', seat = 'Sièges', saddle = 'Sous la selle' }
GameLabels = {
    door = 'Retrait des vis et déclipsage du panneau',
    trunk = 'Démontage de la garniture et des fixations',
    wheel = 'Fixations du passage de roue et accès au compartiment',
    seat = 'Attaches du siège et revêtement',
    saddle = 'Déverrouillage et démontage du compartiment',
}

-- Types d'emplacement possibles selon le genre de véhicule
function SlotAllowedForKind(slotId, isBike)
    local s = Slots[slotId]
    if not s then return false end
    if isBike then return s.type == 'saddle' end
    return s.type ~= 'saddle'
end
