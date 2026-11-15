# elyzea_skate

Skateboard du kit de départ (objet `skateboard`, elyzea_inventory).

- **Utiliser l'objet** : la planche est posée au sol et le joueur monte directement dessus (l'utiliser à nouveau la range).
- **F** : descendre : le skate retourne directement dans l'inventaire · **W** : avancer · **S** : freiner puis reculer · **A / D** : tourner
- Physique simple mais réaliste : élan conservé en roue libre, rayon de virage qui s'élargit avec la vitesse, légère glisse si on tourne fort, pentes.
- Skate fixe : la planche reste à plat (aucun roulis ni balancement), seule la pente est suivie. Le joueur regarde la route et penche à peine dans les virages.
- Pas de saut.
- Posture debout (première animation disponible de `Config.RideAnims`), direction progressive, pentes prises en compte.
- Conduite simple : **30 km/h maximum** en avant, 15 km/h en arrière (`Config.MaxSpeed`, `Config.MaxReverse`). Le skate est déplacé directement : aucun à-coup, trottoirs et petits objets franchis.
- Un vrai mur ou un véhicule arrête le skate, sans chute.
- La planche (`v_res_skateboard`) est posée sur un petit véhicule RC invisible (`rcbandito`, build 2060+) qui donne
  les roues, les pentes et les collisions. Le joueur est attaché debout, et recalé juste après être monté (mesure des os des orteils) : la ligne des deux pieds est tournée dans la longueur de la planche, centrée, semelles sur le plateau.
- Un skate par joueur ; l'objet reste dans l'inventaire (rien ne se perd à la déconnexion).

Test hors jeu : `python3 tests/run_skate_sim.py`
