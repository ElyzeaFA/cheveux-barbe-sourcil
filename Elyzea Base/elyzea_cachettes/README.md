# elyzea_cachettes — Cachettes de contrebande dans les véhicules

Les joueurs aménagent des cachettes dans un véhicule avec un **tournevis**, grâce à des mini-jeux de démontage.
Chaque emplacement a **son propre inventaire, sa propre capacité et sa propre suspicion**.
La police **inspecte** le véhicule (notifications d'anomalies), puis **démonte** les emplacements suspects avec **les mêmes mini-jeux** pour saisir le contenu.

Dépendances : `elyzea_core`, `elyzea_inventory` (obligatoires) ; `elyzea_police` (menu ALT et permissions police) ; `admin_menu` (réglages).
Aucun nouvel inventaire, aucun nouveau menu ALT, aucun nouveau menu admin : tout passe par les systèmes existants.

---

## 1. Installation

1. Le dossier `elyzea_cachettes` est dans `Elyzea Base` (déjà dans `resources`).
2. `server.cfg` : `ensure elyzea_cachettes` **après** `elyzea_inventory`, `elyzea_police` et `admin_menu` (déjà ajouté, section Illégal, après `noirx`).
3. Base de données : les tables `elyzea_cachettes` et `elyzea_cachettes_log` sont créées **automatiquement** au démarrage (`sql/install.sql` contient les mêmes requêtes). Le **contenu** des cachettes est dans la table existante `elyzea_stashes` d'elyzea_inventory.
4. Redémarrer `elyzea_inventory`, `elyzea_police`, `admin_menu` puis `elyzea_cachettes` (ou le serveur) : ces ressources ont reçu de petits ajouts (section 9).
5. Objet : `tournevis` (déjà déclaré dans `elyzea_inventory/shared/items.lua`, image `screwdriverset.png` déjà présente). À donner avec `/egive [id] tournevis 1`, ou à vendre : il est ajouté au modèle de PNJ « Vendeur d'outils » de l'éditeur de map (45 $) pour les **nouveaux** PNJ ; pour un vendeur déjà posé, ajoute-le à sa boutique dans l'éditeur.

## 2. Utilisation

| Qui | Touche | Action |
|---|---|---|
| Joueur **avec un tournevis** (et les clés du véhicule) | **ALT** sur le véhicule › « Cacher un objet de contrebande » | Liste des emplacements réellement présents sur le modèle → « Installer » (emplacement libre) ou « Ouvrir » (cachette existante) → mini-jeu → inventaire du joueur + inventaire de la cachette côte à côte |
| Policier en service, permission `veh_inspect` | **ALT** › « Inspecter le véhicule » | Animation d'enquête (12 s), puis une notification par emplacement suspect, ou « aucun élément suspect » |
| Policier en service, permission `veh_cachettes` (+ tournevis par défaut) | **ALT** › « Démonter un emplacement (fouille) » | Choix de **n'importe quel** emplacement (la liste ne dit pas où sont les cachettes) → même mini-jeu → s'il y a une cachette, son inventaire s'ouvre : glisser les objets dans son inventaire = **saisie** (journalisée) ; sinon « rien n'est dissimulé » |

- Sans tournevis, l'action « Cacher un objet de contrebande » n'apparaît pas. Le tournevis n'est jamais consommé.
- **Échap** annule le mini-jeu proprement (animation, outil et portière remis en place).
- À la fermeture de l'inventaire de la cachette : remontage du panneau (3,5 s), puis tout est rangé.
- Portières, sièges et coffre : le véhicule doit être **déverrouillé** (civils). Un siège occupé ne peut pas être démonté.

## 3. Emplacements et capacités (chaque emplacement est indépendant)

| Catégorie | Chaque portière | Coffre | Chaque passage de roue | Chaque siège | Sous la selle |
|---|---:|---:|---:|---:|---:|
| Petits véhicules | 5 kg | 5 kg | 5 kg | 5 kg | — |
| Véhicules moyens | 10 kg | 15 kg | 10 kg | 10 kg | — |
| SUV et grands véhicules | 15 kg | 30 kg | 15 kg | 15 kg | — |
| Motos et scooters | — | — | — | — | 5 kg |

Emplacements : portières avant gauche / avant droite / arrière gauche / arrière droite, coffre, passages de roue (×4), siège conducteur, passager avant, arrière gauche, arrière droit, compartiment sous la selle (motos et scooters uniquement).
**Détection réelle** : un emplacement n'est proposé que s'il existe sur le modèle (os `door_dside_f`, `door_pside_r`, `boot`, `wheel_lf`… et nombre de sièges du modèle). Une 2 portes n'a pas de portières arrière, un véhicule sans os `boot` n'a pas de coffre.
La capacité est **fixée à l'installation** (un changement de réglage s'applique aux nouvelles cachettes). 12 cases par cachette ; le poids reste la vraie limite.

### Véhicules compatibles (par défaut, modifiable en jeu)

| Classe GTA | Catégorie |
|---|---|
| Compactes, Coupés, Sportives classiques, Sportives, Supersportives | Petit |
| Berlines, Muscle cars, Services | Moyen |
| SUV, Tout-terrain, Utilitaires, Fourgons, Commerciaux | SUV / grand |
| Motos et scooters | Moto (selle seulement) |
| Industriels, Vélos, Bateaux, Hélicoptères, Avions, Urgences, Militaires, Trains, Monoplaces | Aucune cachette |

Exceptions par modèle (nom de spawn → catégorie ou « aucune ») dans le menu admin.
Seuls les véhicules **immatriculés** (`player_vehicles`) peuvent recevoir une cachette : c'est ce qui garantit la sauvegarde.

## 4. Mini-jeux (identiques pour la police et les criminels)

Trois étapes par emplacement, chacune avec sa propre mécanique (aucune n'est reprise d'un emplacement à l'autre) :

| Emplacement | Étape 1 | Étape 2 | Étape 3 |
|---|---|---|---|
| Portière | Vis du panneau : ESPACE quand l'aiguille passe dans la zone verte (4 quarts de tour par vis) | Clips : maintenir pour faire levier, relâcher dans la zone (trop fort = clip cassé) | Dépose : tirer le panneau **lentement** (câble de la vitre), puis débrancher la commande (E) |
| Coffre | Rivets : mémoriser l'ordre puis cliquer dans le même ordre | Vis : choisir le bon embout (1-4), puis tenir la vis qui bouge | Loquets du double fond : chercher le cran (lueur), maintenir ESPACE |
| Passage de roue | Écrous rouillés : garder l'aiguille de couple dans la zone (souris haut/bas) | Agrafes cachées : les trouver à la lampe et cliquer pile dessus | Pare-boue : pomper à la molette (ou ESPACE), tenir dans la zone sans dépasser |
| Siège | Glissières : à-coups en rythme (Q/← et D/→) | Agrafes : pince en deux temps (saisir puis arracher) avant qu'elles filent | Couture : suivre le fil en maintenant le clic, sans sortir ni aller trop vite |
| Sous la selle | Serrure : soulever chaque goupille à sa hauteur (vibration), la tenir immobile, ESPACE | Boulons : tourner autour dans le sens inverse des aiguilles d'une montre (4 tours), sans déraper | Bac : il remonte seul, le garder à plat avec Q/D |

- **Résultats** : réussite → cachette installée / ouverte ; échec (trop d'erreurs ou temps écoulé) → rien n'est ouvert, il faut recommencer ; annulation (Échap) → arrêt propre.
- **Durée** : réglée pour 1 à 2 minutes. Mesure faite par un joueur automatique **parfait** (aucune erreur, réactions instantanées) : portière 54 s, coffre 57 s, roue 49 s, siège 55 s, selle 53 s. Un humain met donc plus d'une minute.
- **Anti-triche** : le serveur mesure lui-même la durée ; une réussite plus rapide que `MinSeconds × durée` (40 s par défaut) est refusée.

## 5. Suspicion

Fixée **une seule fois, à l'installation**, par le nombre d'essais nécessaires, et enregistrée **par emplacement** :

| Installation réussie au… | Suspicion | Inspection policière |
|---|---|---|
| 1er essai | Aucune | rien n'est signalé |
| 2e essai | Légère | « Une petite anomalie semble présente au niveau de la portière avant droite. » |
| 3e essai ou plus | Élevée | « Il semblerait qu'une intervention ait été effectuée au niveau du coffre du véhicule. » |

- Un essai raté = un mini-jeu d'installation échoué, **ou** annulé / interrompu / déconnecté **après au moins une erreur** (impossible d'effacer un essai raté en quittant). Une annulation sans erreur ne compte pas.
- Les essais ratés sont sauvegardés même avant la réussite (déconnexion, redémarrage).
- Les ouvertures suivantes (même ratées) ne changent jamais la suspicion. Une cachette découverte ne révèle pas les autres. Les notifications ne révèlent jamais le contenu.

## 6. Persistance, sécurité, anti-duplication

- Identifiant du véhicule : **`player_vehicles.id`** (pas la plaque) → les cachettes suivent le véhicule en cas de vente, de transfert ou de changement de plaque. Export `TransferCachettes(ancienId, nouvelId)` si un système recrée un véhicule avec un autre identifiant.
- Contenu : coffre elyzea_inventory `cach:<id véhicule>:<emplacement>`, sauvegardé à la fermeture, toutes les 30 s et à l'arrêt (mécanisme existant de l'inventaire).
- **Un seul joueur à la fois par emplacement** (verrou du début du mini-jeu jusqu'à la fermeture de l'inventaire) ; les autres voient « Quelqu'un travaille déjà ici ».
- Tous les transferts passent par l'inventaire existant (poids réel, capacité de la cachette, règles). En plus, un **garde-fou** refuse tout dépôt / retrait si la cachette n'est plus ouverte par ce joueur (inventaire resté affiché, client modifié) et refuse les objets interdits.
- Une cachette ne peut pas être ouverte sans mini-jeu (ouverture directe refusée).
- Inventaire fermé automatiquement si le joueur s'éloigne ou si le véhicule disparaît.

## 7. Réglages (menu admin F10 › Illégal › Cachettes véhicules, permission `cachettes_manage`)

Capacité de chaque emplacement par catégorie · catégorie de chaque classe · exceptions par modèle · types d'emplacements activés · mini-jeux (difficulté 1-5, durée 0,6-1,6, erreurs tolérées, temps limite) · seuil anti-triche · durée de l'inspection et textes des notifications · permissions police utilisées · tournevis obligatoire pour la police · clés obligatoires pour les civils · objets interdits · **recherche des cachettes d'un véhicule par plaque** (état, essais, suspicion, découverte, nombre d'objets, suppression d'une cachette vide).
Les valeurs sont gardées par la ressource (KVP) ; « Valeurs par défaut » revient à `config.lua`. La permission est donnée au SuperAdmin (le Fondateur a tout).

**Permissions police** (tablette › Direction › Grades) : `veh_inspect` (Cadet et plus par défaut), `veh_cachettes` (Gardien de la paix et plus). Sur une base existante, elles sont ajoutées automatiquement une fois aux grades correspondants.

## 8. Tests

| Test | Commande (depuis `elyzea_cachettes/`) | Résultat |
|---|---|---|
| Serveur (VRAI elyzea_inventory + cette ressource, MySQL simulé) | `python3 tests/run_server_sim.py` (`pip install lupa`) | 78 / 78 |
| Mini-jeux et choix d'emplacement (Chromium) | `node tests/minigames.e2e.cjs` | 26 / 26 |
| Onglet du menu admin (Chromium) | `node tests/admin_ui.cjs` | 8 / 8 |

Non-régression : `elyzea_police/tests/run_alt_sim.py` 24/24, `elyzea_police/tests/alt_ui.cjs` 0 échec, `elyzea_inventory/tests/run_trunk_sim.py` 9/9.

**Pas testé en jeu** (pas de serveur FiveM ni de client GTA dans l'environnement de développement) : rendu des animations, position du joueur à côté de chaque emplacement, tournevis en main, ouverture des portières, détection des os sur les vrais modèles, synchronisation entre deux clients. Protocole à faire avec deux joueurs (un criminel, un policier) :

1. Criminel sans tournevis : ALT sur sa voiture → pas d'action « Cacher… ». `/egive [id] tournevis 1` → l'action apparaît.
2. Installer une portière en réussissant du 1er coup, le coffre au 2e essai, une roue au 3e. Ranger des objets jusqu'à la limite (15 kg portière d'un SUV). Fermer, rouvrir : même contenu.
3. Moto / scooter : seul « Compartiment sous la selle », 5 kg.
4. Policier : `veh_inspect` → « Inspecter le véhicule » : 2 notifications (coffre légère, roue élevée), rien pour la portière propre. Véhicule sans cachette : « aucun élément suspect ».
5. Policier : démonter la portière propre → la cachette s'ouvre (trouvée par la fouille) ; démonter une portière vide → « rien n'est dissimulé ». Saisir un objet. La roue n'est pas révélée.
6. Les deux joueurs sur le même emplacement : le second voit « Quelqu'un travaille déjà ici ».
7. Déconnexion / reconnexion, `restart elyzea_cachettes`, redémarrage serveur : contenu et suspicion identiques. F8 : aucune erreur.

## 9. Fichiers

**Nouveaux** : `elyzea_cachettes/` (fxmanifest, config, shared/slots, server/settings · main · admin, client/main, html/index · style · games · app, sql/install.sql, tests/), `admin_menu/server/cachettes.lua`, `admin_menu/html/cachettes.js`.

**Modifiés (ajouts uniquement)** :
- `elyzea_inventory/server/main.lua` : `RegisterStashGuard(prefix, cb)` (contrôle des dépôts / retraits d'un coffre) et `GetViewing(src)` (second inventaire ouvert) ; rien d'autre ne change.
- `elyzea_inventory/shared/items.lua` : objet `tournevis` + image.
- `elyzea_police` : fournisseur ALT `elyzea_cachettes` (`client/alt.lua`), permissions `veh_inspect` / `veh_cachettes` (`shared/perms.lua`, `server/main.lua` NEW_PERMS, grades par défaut de `config.lua`), icônes 🪛 🔦 (`html/app.js`).
- `admin_menu` : onglet (fxmanifest, `html/index.html`, catégorie Illégal dans `html/script.js`), permission `cachettes_manage` (`permissions_extra.lua`, SuperAdmin dans `config.lua` + migration `meta.v51`), tournevis au vendeur d'outils (`config.lua`).
- `Serveur cfg/server.cfg` : `ensure elyzea_cachettes`.

## 10. Limites connues

- Le serveur FiveM ne peut pas lire les os d'un modèle : la liste des emplacements présents est fournie par le client, et le serveur vérifie seulement le genre de véhicule (moto / auto), la catégorie et les types autorisés. Un client modifié pourrait demander, par exemple, une portière arrière sur une 2 portes.
- La classe du véhicule (catégorie) est aussi fournie par le client ; le serveur garde la première valeur reçue pour chaque modèle. Une exception par modèle dans le menu admin est vérifiée par le serveur.
- Le mini-jeu se joue dans l'interface du client : le serveur ne peut pas rejouer la partie. Il vérifie la durée réelle, la distance, l'outil, les permissions et le verrou.
- Les véhicules non immatriculés (PNJ, volés sans carte grise) ne peuvent pas recevoir de cachette.
- La saisie se fait en glissant les objets dans l'inventaire du policier (pas de bouton « tout saisir » dans l'inventaire existant).
