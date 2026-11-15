-- =====================================================================
--  ELYZEA SKATE - réglages
-- =====================================================================
Config = {}

Config.Item = 'skateboard'          -- objet (elyzea_inventory/shared/items.lua), donné dans le kit de départ
Config.AutoMount = true             -- utiliser l'objet : le skate est posé ET le joueur monte dessus directement
Config.StowOnDismount = true        -- descendre (ou tomber) : le skate retourne directement dans l'inventaire

-- Conduite simple : W avance, S freine puis recule, A / D tournent
Config.MaxSpeed = 30.0              -- km/h maximum en avant
Config.MaxReverse = 15.0            -- km/h maximum en marche arrière
Config.Accel = 3.0                  -- accélération (m/s²) : 0 → 30 km/h en ~3 s, sans à-coups
Config.Brake = 6.0                  -- freinage avec la touche opposée (m/s²)
Config.Coast = 1.2                  -- ralentissement sans toucher aux touches (m/s²)
Config.TurnRate = 90.0              -- degrés / s pour tourner (un peu moins à pleine vitesse)
Config.SteerResponse = 10.0         -- douceur de la direction (plus haut = plus vif)
Config.Lean = 5.0                   -- légère inclinaison du corps dans les virages (degrés)
Config.StepUp = 0.6                 -- hauteur franchie sans être bloqué (trottoirs, bosses), en m
Config.WallHeight = 0.7             -- au-dessus de cette hauteur, un mur ou un véhicule arrête le skate (sans chute)

Config.MountDistance = 2.0          -- distance pour remonter (F) ou ramasser (E)
Config.Keys = { mount = 23, pickup = 38 }   -- F, E

-- Modèles : la planche visible est posée sur un petit véhicule RC invisible (roues, pentes, collisions)
Config.BoardProp = 'v_res_skateboard'
Config.BaseVehicle = 'rcbandito'
Config.DeckHeight = 0.13            -- hauteur du plateau au-dessus du sol (m)
Config.Stance = 30.0                -- angle de départ du corps ; corrigé ensuite pour que les DEUX pieds soient sur la planche
Config.SoleOffset = 0.04            -- épaisseur sous l'os des orteils (m) : les pieds sont recalés pile sur le plateau

-- Posture sur la planche : DEBOUT (pieds posés, sans accroupissement). La première animation qui existe dans le jeu
-- est utilisée ; le corps est ensuite tourné et recalé pour que les deux pieds soient sur la planche.
Config.RideAnims = {
    { dict = 'anim@heists@heist_corona@team_idles@male_a', name = 'idle' },
    { dict = 'amb@world_human_stand_impatient@male@no_sign@base', name = 'base' },
    { dict = 'anim@heists@heist_corona@single_team', name = 'single_team_loop_boss' },
}
