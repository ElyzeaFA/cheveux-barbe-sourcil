# elyzea_k9 — chiens de la police et des gangs

Unité cynophile pour la **police** (détection de stupéfiants, attaque et intervention, recherche et pistage) et chiens
pour les **groupes illégaux** (attaque, défense, intimidation) : races aux modèles réellement différents, dressage et
progression sauvegardés, ordres avec **ciblage à la molette**, exercices d'entraînement **en jeu**.

> **État : non testé en jeu.** Vérifié hors jeu : 69 contrôles serveur sur une vraie base MariaDB (`tests/run_k9_sim.py`,
> redémarrage compris), 29 contrôles de l’interface (`tests/ui_k9.cjs`) et un essai de tous les chemins du client avec
> des natives simulées (`tests/client_smoke.py`). Le comportement des chiens (navigation, animations, sons) doit être vérifié
> en jeu : voir « Tests à faire en jeu ».

---

## 1. Installation

1. Copie le dossier `elyzea_k9` dans tes `resources`.
2. Remplace les fichiers modifiés des ressources existantes (section 7).
3. `server.cfg` (déjà ajouté) : `ensure elyzea_k9` **après** `elyzea_core`, `elyzea_inventory`, `elyzea_police`, `elyzea_illegal`, `elyzea_cachettes`.
4. Démarre : les tables `elyzea_k9_dogs` et `elyzea_k9_history` sont créées toutes seules (ou à la main : `sql/install.sql`).
5. Permissions :
   - **Police** : nouvelle permission « Unité cynophile (K9) » (`k9`) dans la tablette › Direction › Grades. Donnée par défaut
     du grade Brigadier au Commandant (le Commissaire a tout). Sur un serveur existant, elle est ajoutée automatiquement aux grades correspondants au démarrage.
   - **Groupes illégaux** : nouvelle permission « Avoir un chien du groupe (K9) » (catégorie Chiens) dans la tablette du groupe (F5) › Grades.
     Le chef (OG / Parrain / Patron) l'a toujours ; les nouveaux groupes la donnent à partir de Lieutenant / Capo / Capitaine.

Dépendances : `elyzea_core`, `elyzea_inventory` (obligatoires) ; `elyzea_police` (chiens de police, menu ALT),
`elyzea_illegal` (chiens de gang), `elyzea_cachettes` (détection des cachettes, facultatif). OneSync.

## 2. Pour les joueurs

| Action | Comment |
|---|---|
| Menu du chien | **O** (ou `/k9`) : adopter, fiche, sortir / renvoyer, dressage, ordres, historique. Police et groupe : onglets en haut si tu as accès aux deux. |
| Adopter | Choix de la race (aperçu réel du modèle devant toi, bouton Tourner), spécialité (police), nom. Un chien par côté et par personnage. |
| Sortir le chien | Menu › Mon chien › Faire sortir (police : en service). Il te suit à ton allure, monte en voiture avec toi (places arrière puis avant). |
| Ordres | Menu › Ordres, ou **ALT** sur ton chien (ordres rapides), ou **I** : mode ciblage. |
| Mode ciblage | **I** : les personnes proches (35 m) sont listées par distance. **Molette** : personne suivante / précédente. **◄ ►** : changer d'ordre. **E** : confirmer. **Échap** : annuler. Une flèche violette et un cercle au sol marquent la personne choisie ; l'encart affiche « Personne · ID n », la distance et un avertissement (en véhicule, hors de vue). Pour « Renifler le véhicule », ce sont les véhicules proches (12 m). |
| Dressage | Menu › Dressage : dépenser les points de compétence, lancer un exercice (le chien doit être sorti). |
| Récompenser | Menu › Récompenser ou ALT › Récompenser (caresses, animation des deux côtés). |

### Ordres

| Ordre | Police | Gang | Effet |
|---|:-:|:-:|---|
| Au pied, Reste, Assis, Couché, Viens | ✔ | ✔ | Suivre, attendre, poses, rappel. |
| Défends-moi | ✔ | ✔ | Le chien intervient seul contre quiconque blesse ou tire près de son maître. |
| Fouiller la zone | ✔ | | Personnes cachées (pistage) + stupéfiants au sol / coffres chargés (reniflage) autour du chien. |
| Renifler la personne | ✔ | | Le chien tourne autour de la personne ; s'il détecte des stupéfiants, il **marque** (assis, aboiement). |
| Renifler le véhicule | ✔ | | Tour du véhicule ; marque le **coffre**, l'**habitacle** (occupants) et les **cachettes** (`elyzea_cachettes`, bien mieux dès le reniflage 3). |
| Aboyer, Intimider | ✔ | ✔ | Pression sur la personne (elle ne peut plus courir, puis plus sauter, puis est tétanisée selon le niveau). |
| Attaquer | ✔ | ✔ | Poursuite, saisie, **maintien au sol** (4 à 10 s selon le niveau). |
| Faire tomber | ✔ | ✔ | Poursuite et mise au sol, sans maintien. |
| Pister | ✔ | | Le chien prend l'odeur et suit la personne (même si elle s'enfuit loin), le maître le suit ; il aboie quand il la retrouve. |

Un chien de police n'attaque pas un agent en service (`Config.Police.protectOnDutyPolice`).

## 3. Progression et effets réels

- **Niveaux 1 à 30** (≈ 12 000 XP au total : plusieurs semaines de jeu normal). 1 point de compétence par niveau (+1 aux niveaux 10, 20, 30).
- **Compétences** (5 niveaux) — coût d'une amélioration vers le niveau L : L − 1 points.
  - Police : Reniflage, Obéissance, Attaque, Pistage. **Plafonds selon la spécialité** : détection (reniflage 5, pistage 3, attaque 2),
    attaque (attaque 5, pistage 3, reniflage 2), pistage (pistage 5, reniflage 3, attaque 2) ; obéissance 5 pour tous. La spécialité commence au niveau 2 et donne +10 % de réussite.
  - Gang : Attaque, Défense, Intimidation (pas de spécialité) ; l'obéissance d'un chien de gang suit son niveau général.
- Ce que les compétences changent **vraiment** (calculé par le serveur, `shared/k9.lua › K9.Effects`) :
  - Obéissance : chance d'exécuter un ordre (≈ 58 % → 99 %), hésitation avant d'agir (2,2 s → 0,15 s). Un chien peu dressé
    (attaque 1 + obéissance ≤ 2) **a peur** d'une cible armée et refuse.
  - Reniflage : chance de détection, durée de la fouille (9 s → 3,5 s), rayon de recherche des stupéfiants (8 → 24 m), faux marquages
    au niveau 1-2, cachettes de véhicule repérées à partir du niveau 3.
  - Pistage : chance, précision de la piste (28 m → 4 m d'erreur), fréquence de mise à jour, rayon de recherche de personnes (15 → 45 m), risque de perdre la piste.
  - Attaque : chance de saisie, durée du maintien au sol.
  - Défense (gang) / obéissance (police) : portée de protection (6 → 18 m), délai de réaction, chance d'intervenir.
  - Intimidation : niveau de pression et durée.
  - Race : vitesse de course réelle, santé, bonus de flair / pistage / attaque / défense / intimidation.

### Expérience et anti-farm
- **Interventions** (sur de vrais joueurs) : stupéfiants trouvés 60, fouille sans résultat 10, mise au sol 70, intimidation 15,
  personne retrouvée 90, protection 50. **Pas d'XP deux fois pour la même personne / le même véhicule pendant 30 min.** Plafond : 900 XP / jour / chien.
- **Entraînement** : plafond 700 XP / jour / chien ; **repos de 6 min** avant de refaire le même exercice ; refait dans l'heure : × 0,6 à chaque fois ;
  durée minimale vérifiée par le serveur ; XP proportionnelle à la réussite.

## 4. Exercices (en jeu)

| Exercice | Côté | Déroulement |
|---|---|---|
| Obéissance | Tous | 6 ordres affichés (assis, couché, reste, au pied) ; **E** pour donner l'ordre à temps ; le chien obéit ou hésite selon son obéissance. |
| Reniflage | Police | 3 leurres (sacs) cachés autour de toi + fausses pistes ; le chien cherche, **marque** ; tu le rejoins et valides (**E**). |
| Pistage | Police | Une piste invisible (7 étapes) ; le chien la suit plus ou moins précisément ; tu dois rester près de lui. |
| Attaque contrôlée | Tous | Un homme d'attaque approche ; **E** : envoyer, le chien saisit la manche ; **G** : « Lâche ! ». |
| Défense | Gang | Un individu fonce sur toi ; le chien doit l'intercepter avant qu'il ne t'atteigne. |
| Intimidation | Tous | **E** : faire aboyer / grogner ; la peur de l'individu monte jusqu'à ce qu'il lève les mains. |

Échap : abandonner. Les figurants (homme d'attaque, individus) sont créés pour l'exercice et supprimés à la fin.

## 5. Réglages (`config.lua`)

- `Config.Keys` : touches par défaut (**O** menu, **I** ciblage ; chaque joueur peut les changer dans Paramètres › Raccourcis › FiveM).
- `Config.Police` / `Config.Gang` : activation, nom de la permission, service obligatoire, protection des policiers, types de groupes autorisés.
- `Config.Breeds` : races (modèle, côtés, description, caractéristiques affichées, bonus réels). Ajouter un modèle addon : `addon = true`.
- `Config.Specialties`, `Config.Skills`, `Config.GangStart`, `Config.GangCaps` : spécialités, compétences et plafonds.
- `Config.Progress` : niveau max, courbe d'XP, points par niveau, historique gardé.
- `Config.MissionXp`, `Config.Training` : XP, anti-farm, exercices (XP, durée, durée minimale).
- `Config.Target`, `Config.Orders`, `Config.Attack`, `Config.Track`, `Config.Search`, `Config.Defend` : distances, durées,
  dégâts des morsures, **plancher de santé** (`healthFloor = 120` : un chien ne tue jamais ; GTA : mort à 100 sur 200).
- `Config.Drugs` : objets d'`elyzea_inventory` détectés (préfixes, exclusions, ajouts).
- `Config.Health` : invincibilité des chiens, durée de convalescence après une blessure grave.

## 6. Sécurité et optimisation

- Toutes les décisions sont prises par le **serveur** : permissions (police : grade + service ; groupe : type + grade),
  propriété du chien, existence de l'entité et modèle, distance chien-maître (60 m), distance maître-cible, cible valide (connectée,
  debout, pas dans un véhicule pour une attaque), tirages d'obéissance / détection / réussite, contact chien-cible avant la mise au sol
  (2,6 m), délai de poursuite, anti-spam par action, XP et plafonds. Le client ne fait que jouer le comportement autorisé.
- Un seul chien sorti par joueur, une seule entité par chien (l'ancienne est supprimée côté serveur) ; rangé à la déconnexion,
  au changement de personnage et à l'arrêt de la ressource ; chien mis hors de combat → au chenil (`injuredMinutes`).
- Dégâts : les dégâts natifs des chiens K9 sur les joueurs sont coupés ; la victime applique des morsures contrôlées et un plancher de santé.
- Une seule boucle de comportement (300 ms) et une boucle de défense (400 ms) **seulement quand un chien est sorti** ; le mode ciblage
  ne tourne que pendant le ciblage ; aucune boucle permanente côté serveur hors ménage toutes les 10 min.

## 7. Fichiers des autres ressources modifiés (ajouts uniquement)

| Ressource | Fichier | Ajout |
|---|---|---|
| elyzea_police | `shared/perms.lua` | permission `k9` |
| elyzea_police | `config.lua` | `k9` dans les grades Brigadier → Commandant (nouvelle installation) |
| elyzea_police | `server/main.lua` | `k9` dans `NEW_PERMS` (ajout automatique sur un serveur existant) |
| elyzea_police | `client/alt.lua` | fournisseur ALT `elyzea_k9` (`k9:`) |
| elyzea_police | `html/app.js` | icônes des options ALT du chien |
| elyzea_illegal | `shared/constants.lua` | permission de grade `k9` |
| elyzea_illegal | `config.lua` | `k9` dans les modèles de grades (nouveaux groupes) |
| elyzea_inventory | `server/main.lua` | export `GetDropsInRadius` (lecture seule) |
| elyzea_cachettes | `server/main.lua` | export `GetVehicleHiddenItems` (lecture seule) |
| Serveur cfg | `server.cfg` | `ensure elyzea_k9` |

## 8. Limites de GTA V / FiveM (et ce qui a été fait)

- **Races** : GTA V ne contient que 4 grands chiens : berger allemand (`a_c_shepherd`), rottweiler (`a_c_rottweiler`, et `a_c_chop`,
  sa « lignée de rue »), husky (`a_c_husky`), labrador / retriever (`a_c_retriever`). **Le malinois, le dobermann et le berger
  hollandais n'existent pas dans GTA V.** Ils sont prévus dans la configuration comme modèles **addon** : il suffit d'installer
  un modèle de chien portant ce nom (`a_c_malinois`, `a_c_doberman`, `a_c_dutchshepherd`, ou le nom de ton choix dans `Config.Breeds`).
  Tant qu'il n'est pas installé, la race apparaît grisée (« modèle non installé ») : jamais un simple changement de couleur.
- **Animations** : GTA n'a pas d'animation de « reniflage » dédiée pour les chiens. Le chien fait le tour de la cible au pas,
  s'arrête à chaque point avec l'animation d'indication basse (`creatures@rottweiler@indication@`), puis marque (assis /
  indication haute, aboiement). Attaque : poursuite par la navigation native, morsure par la tâche de combat native pendant le maintien.
- **Mise au sol d'un joueur** : seul le jeu de la victime peut faire tomber son personnage ; le serveur lui envoie l'ordre après
  avoir vérifié le contact. La victime voit donc la chute sur son écran comme les autres.
- **Sons** : vocalisations natives des animaux (aboiement, grognement, gémissement) quand le jeu les fournit pour le modèle, et les sons des scénarios d'aboiement.

## 9. Tests à faire en jeu (à deux)

1. Policier avec la permission K9, en service : **O** › adopter (aperçu, rotation), sortir le chien, le suivre à pied, en courant, en voiture.
2. **I** sur un joueur : molette, ◄ ►, flèche visible, E ; Échap annule.
3. Renifler la personne (avec et sans drogue), renifler un véhicule (coffre chargé, cachette d'`elyzea_cachettes`), fouiller une zone.
4. Attaquer / faire tomber (le joueur ciblé tombe, est maintenu, ne meurt pas) ; pister quelqu'un qui s'enfuit à pied puis en voiture.
5. Défends-moi : un joueur frappe le maître → le chien intervient.
6. Membre de gang avec la permission : adopter (thème rouge), intimider, attaquer ; grognement quand un joueur armé approche.
7. Les six exercices ; refaire un exercice tout de suite (repos) ; dépenser des points.
8. Se déconnecter avec le chien sorti, revenir : chien rangé, progression intacte. Redémarrer la ressource : aucun chien en double.
