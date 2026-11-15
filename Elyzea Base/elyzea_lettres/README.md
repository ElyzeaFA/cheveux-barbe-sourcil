# elyzea_lettres — lettres manuscrites

Un joueur prend une **feuille de papier** et un **stylo à bille** dans son inventaire et écrit sa lettre au clavier. Le texte s'affiche **en direct sur une vraie feuille**, en écriture manuscrite. Une fois terminée, la lettre devient un objet : on peut la donner, la ranger dans un coffre, la poser au sol, la mettre sous enveloppe, et la relire autant qu'on veut.

Branché sur ce qui existe déjà : **elyzea_inventory** (objets, don, coffres, sauvegarde), **elyzea_core** (notifications, personnage, base de données), **admin_menu** (onglet « Lettres »), animation `notepad` d'elyzea_animations. Aucun inventaire, téléphone ou menu nouveau.

---

## Installation

1. Le dossier `elyzea_lettres` va dans `resources` (déjà dans `Elyzea Base`).
2. `server.cfg` : la ligne est déjà ajoutée, **après** `elyzea_inventory` et `admin_menu` :
   ```cfg
   ensure elyzea_lettres
   ```
3. Redémarrez le serveur (ou `restart elyzea_inventory`, `restart admin_menu`, puis `ensure elyzea_lettres`).
4. **SQL : rien à faire.** La table `elyzea_letters` est créée toute seule au démarrage (le fichier `install/elyzea_letters.sql` sert seulement si vous préférez la créer à la main).
5. Les supérettes posées **à partir de maintenant** proposent feuilles, stylos et enveloppes (rayon « Divers »). Pour une supérette **déjà posée** : menu admin › éditeur › la supérette › ajouter `feuille_papier`, `stylo_bille`, `enveloppe`.
6. Pour tester tout de suite : `/egive [id] feuille_papier 5`, `/egive [id] stylo_bille 1`, `/egive [id] enveloppe 2`.

**Dépendances :** `elyzea_core`, `elyzea_inventory` (obligatoires), `admin_menu` (pour les réglages en jeu). Polices manuscrites **embarquées** (`html/fonts`, licence OFL) : rien n'est téléchargé, ça marche hors ligne.

## Objets (déclarés dans `elyzea_inventory/shared/items.lua`, images dans `elyzea_inventory/html/img/`)

| Objet | Nom | Poids | Rôle |
|---|---|---|---|
| `feuille_papier` | Feuille de papier | 5 g, pile de 50 | Utiliser : ouvre la rédaction. Consommée **seulement** quand la lettre est terminée. |
| `stylo_bille` | Stylo à bille | 10 g, pile de 5 | Obligatoire pour écrire, **jamais consommé**. L'utiliser ouvre aussi la rédaction (s'il y a une feuille). |
| `lettre` | Lettre · *destinataire* | 5 g, unique | Utiliser : lire. Se donne / se range / se pose. Onglet « Papiers ». |
| `enveloppe` | Enveloppe | 5 g, pile de 20 | Enveloppe vide (option). |
| `enveloppe_lettre` | Enveloppe · *destinataire* | 10 g, unique | Lettre sous enveloppe cachetée. Utiliser : voir l'enveloppe, l'ouvrir, lire, sortir la lettre. |

## Utilisation en jeu

**Écrire**
- Inventaire › utiliser la **feuille** (ou le stylo). Sans stylo : « Il vous faut un stylo à bille pour écrire une lettre. »
- On écrit au clavier, le texte apparaît sur la feuille avec un curseur d'encre :
  - **Tab** passe du destinataire à la lettre puis à la signature ;
  - **Entrée** va à la ligne (paragraphes, lignes vides respectés) ;
  - flèches, retour arrière, Suppr, Ctrl+A, copier / coller fonctionnent normalement ;
  - un **clic sur la feuille** place le stylo à cet endroit.
- En bas : style d'écriture (**Élégante**, **Naturelle**, **Arrondie**), papier (**Crème**, **Blanc ligné**, **Vieilli**), compteur de caractères, numéro de page.
- Quand le texte dépasse la feuille, une **nouvelle page** se crée toute seule. Les flèches ‹ › font défiler les pages.
- **Aperçu** : la lettre exactement comme elle sera lue. **Continuer d'écrire** pour y revenir.
- **Terminer la lettre** : confirmation (« elle ne pourra plus être modifiée »), puis la lettre se plie et arrive dans l'inventaire.
- **Annuler / Échap** : si quelque chose est écrit, une fenêtre demande **Garder le brouillon**, **Continuer d'écrire** ou **Jeter le brouillon**. La feuille n'est jamais consommée.
- Le brouillon est aussi **sauvegardé automatiquement** toutes les 4 s : une fermeture, un crash ou une déconnexion ne fait rien perdre. Il revient à la prochaine feuille.

**Lire, donner, ranger**
- Utiliser la lettre : elle s'affiche avec la même mise en page (date, destinataire, texte, signature, pages). ← → pour les pages, Échap pour fermer. Pas besoin de stylo ni de feuille pour lire.
- Donner : clic droit › Donner (joueur à moins de 3 m), comme tout objet.
- Coffres : glisser la lettre dans un coffre (véhicule, stash, propriété) puis la reprendre.

**Enveloppe** (si activée)
- Avec une enveloppe vide sur soi, ouvrir la lettre › **Mettre sous enveloppe** : l'enveloppe est cachetée, le nom du destinataire écrit dessus.
- Utiliser l'enveloppe : on la voit (destinataire, cachet de cire) › **Ouvrir l'enveloppe** › la lettre s'affiche › **Sortir la lettre de l'enveloppe** (l'enveloppe ouverte est jetée).

## Réglages (menu admin › Autres › **Lettres**, permission `lettres_manage`)

| Réglage | Par défaut | Bornes |
|---|---|---|
| Caractères maximum par lettre | 3 000 | 200 à 10 000 (≈ 800 par page pleine) |
| Pages maximum par lettre | 4 | 1 à 10 |
| Consommation des feuilles | 1 feuille par lettre | ou 1 feuille **par page**, ou aucune |
| Styles d'écriture | les 3 activés | clic droit sur un style = style par défaut |
| Papiers | les 3 activés | — |
| Enveloppes | activées | — |
| Animation | activée | — |

Les réglages sont gardés par le serveur (KVP de la ressource) et s'appliquent aux prochaines feuilles ouvertes. L'onglet montre aussi le nombre de lettres et les 25 dernières (identifiant, auteur, destinataire, date, pages) **sans leur contenu**, qui reste privé. Le Fondateur a la permission d'office ; pour un autre grade, cochez-la dans l'onglet Grades.

Autres réglages (fichier `config.lua`) : noms des objets, ville écrite devant la date (`Config.City`), longueur du destinataire / de la signature (60), animations et objets tenus en main.

## Données enregistrées

Table `elyzea_letters` (une ligne par lettre, **jamais modifiée** après création) :
`id` (unique, ex. `LF9DDC46815E`), `author_cid` et `author_name` (personnage), `recipient`, `body` (texte intégral), `signature`, `font`, `paper`, `pages`, `layout` (`lettre-v1`), `created`.

L'objet `lettre` ne contient que `{ letter = id, label, description }`. Le texte ne passe jamais par l'inventaire ; il est relu en base à chaque lecture.

## Sécurité

- Jeton de rédaction **à usage unique**, lié au joueur, donné par le serveur à l'ouverture de la feuille. Un 2ᵉ envoi, un jeton inventé ou un ancien jeton (après déconnexion) est refusé.
- Le serveur revérifie au moment de terminer : stylo **et** feuille(s) sur le joueur, longueurs (en caractères, accents et emojis compris), UTF-8 valide, style et papier autorisés, nombre de pages (borne calculée par le serveur, il ne croit pas le nombre annoncé s'il est trop bas).
- Ordre de création : texte en base → lettre ajoutée → feuille(s) retirée(s). Au moindre échec tout est annulé : aucune feuille perdue, aucune lettre fantôme. Inventaire plein : refus clair (sauf si la lettre peut prendre la place de la dernière feuille).
- Verrou par joueur et anti-spam sur chaque action.
- Métadonnées : seules elyzea_inventory et elyzea_lettres les écrivent ; la lettre ne se renomme pas. Le client ne choisit jamais quelle lettre lire : le serveur prend l'identifiant dans l'objet réellement présent dans l'inventaire.
- Copier l'objet ne copie que la clé : le texte est le même, en lecture seule, rien n'est « dupliqué » en valeur.
- Texte nettoyé : retours Windows normalisés, caractères de contrôle et caractères d'inversion du sens d'écriture retirés. Tout le reste (lignes vides, espaces, retraits, guillemets « », apostrophes, emojis) est gardé **à l'identique** pour que la lettre lue soit exactement l'aperçu.

## Fichiers

```
elyzea_lettres/
  fxmanifest.lua, config.lua, README.md
  shared/text.lua           nettoyage du texte, borne de pages
  server/main.lua           feuille, stylo, rédaction, création, lecture, enveloppes, brouillons
  server/admin.lua          données et actions de l'onglet admin
  client/main.lua           ouverture de l'interface, animation, relais
  html/index.html, css/style.css
  html/js/layout.js         mise en page et pagination (identiques à l'écriture et à la lecture)
  html/js/app.js            interface
  html/fonts/               Dancing Script, Caveat, Patrick Hand (OFL)
  install/elyzea_letters.sql
  tests/                    tests serveur (MariaDB) et interface (Chromium)
Modifiés ailleurs :
  elyzea_inventory/shared/items.lua          5 objets
  elyzea_inventory/html/img/                 5 images (feuille_papier, stylo_bille, lettre, enveloppe, enveloppe_lettre)
  admin_menu/server/lettres.lua, html/lettres.js (nouveaux), fxmanifest.lua, html/index.html,
  admin_menu/permissions_extra.lua, config.lua (permission, rayon « Divers » des nouvelles supérettes)
  Serveur cfg/server.cfg                     ensure elyzea_lettres
```

## Tests

```bash
pip install lupa pymysql            # + un serveur MariaDB local
python3 tests/run_server_sim.py     # 76 vérifications : vrai elyzea_inventory + vrai elyzea_lettres + vraie base
npm i playwright                    # (Chromium)
node tests/ui_lettres.cjs [dossier_captures]       # 55 vérifications de l'interface
node ../admin_menu/tests/lettres_ui.cjs            # onglet Lettres du menu admin
```

### À faire en jeu à deux joueurs (non testable hors du jeu)

Les tests ci-dessus font tourner le vrai code serveur et la vraie interface, mais **pas** le client FiveM (natives, animation, focus de la NUI). À vérifier sur le serveur :

1. Joueur A sans stylo : utiliser une feuille → message « Il vous faut un stylo à bille… ».
2. A avec feuille + stylo : la feuille s'ouvre, le personnage tient un carnet et un crayon ; le texte s'affiche en tapant (accents, `« »`, `’`, `œ`).
3. Taper, Entrée, corriger, cliquer dans le texte, Tab vers la signature.
4. Lettre longue : passage à la page 2 tout seul.
5. Échap → « Garder le brouillon » : l'animation s'arrête, A peut bouger, la feuille est toujours là. Reprendre une feuille : le brouillon revient.
6. Terminer : une seule feuille en moins, une lettre « Lettre · … » dans l'inventaire (onglet Papiers).
7. Lire, fermer, relire. Donner la lettre à B (clic droit › Donner) : B lit exactement le même texte, sans stylo ni feuille.
8. Ranger la lettre dans un coffre de véhicule, la reprendre.
9. Écrire une 2ᵉ lettre : les deux coexistent, chacune avec son texte.
10. Enveloppe : mettre sous enveloppe, la donner, l'ouvrir, sortir la lettre.
11. Se déconnecter / reconnecter, puis `restart elyzea_lettres` et `restart elyzea_inventory` : lettres présentes, texte identique, aucune en double.

## Limites connues

- Le client FiveM (animation, objets en main, focus clavier de la NUI dans le jeu) n'a pas pu être testé ici : voir la liste ci-dessus.
- La pagination est calculée par l'interface (mesure réelle du rendu). Elle est identique chez tous les joueurs (feuille de taille fixe, polices embarquées) ; le serveur n'en vérifie qu'une borne basse.
- Pendant l'écriture, la NUI a le focus du clavier : le personnage ne marche pas en écrivant (il bouge dès la fermeture, l'animation ne le bloque jamais).
- Le staff ne voit pas le contenu des lettres dans le menu (choix de confidentialité) ; en cas de signalement, il se lit dans la table `elyzea_letters` avec l'identifiant affiché.
- `elyzea_inventory/tests/run_money_sim.py` échouait **déjà avant** ce travail (il n'imite pas `GetNumResources`, utilisé par `shared/items.lua` pour les recettes d'elyzea_cuisine) ; non lié aux lettres.
