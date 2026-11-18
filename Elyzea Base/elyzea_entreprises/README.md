# elyzea_entreprises — entreprises créées par les joueurs

Les joueurs créent **leur propre entreprise** depuis leur téléphone (Elyzea Aura › appli **Entreprises**) : nom, spécialité,
**logo** (galerie, lien ou **depuis leur ordinateur**), description, paiement. L'entreprise devient un vrai métier :
le créateur en est le **patron**, avec le **téléphone de service** et la **tablette** de l'entreprise (F6), il recrute,
gère les grades, les permissions, les salaires et le compte. Tout le monde voit les entreprises dans l'appli et peut les
**appeler** ou leur **envoyer un message** : l'appel sonne sur le téléphone de service de **tous les employés en service**,
le premier qui décroche prend le client. **Pas de point ni de logo sur la carte.**

> **État : non testé en jeu.** Vérifié hors jeu : 100 contrôles serveur (`tests/run_ent_sim.py` : vrais scripts
> d'elyzea_entreprises, du téléphone de service et d'Elyzea Aura chargés ensemble sur une vraie base MariaDB, redémarrage compris),
> 28 contrôles de l'appli du téléphone (`elyzea_aura/tests/ui_entreprises.cjs`), 17 de la tablette et du panneau staff
> (`tests/ui_tablet.cjs`), 12 de la page d'import du logo (`tests/ui_logo_page.cjs`), 12 du client (`tests/client_smoke.py`).

---

## 1. Installation

1. Copie `elyzea_entreprises` dans tes `resources`.
2. Remplace les fichiers modifiés des autres ressources (section 7).
3. `server.cfg` (déjà ajouté) : `ensure elyzea_entreprises` **après** `elyzea_core`, **avant** `elyzea_jobphone`.
4. Démarre : les tables `ent_*` se créent toutes seules (ou à la main : `sql/install.sql`).
5. Logo depuis l'ordinateur : rien à faire si l'appareil photo d'Elyzea Aura marche déjà (clé Fivemanage dans
   `elyzea_aura/config.lua`) et si l'import de musique d'ElyFy trouve l'adresse du serveur. Sinon, mets l'adresse publique du
   serveur dans `Config.Logo.import.url` (ex. `'http://123.45.67.89:30120'`). La page est servie **par ton serveur**
   (`http://IP:PORT/elyzea_entreprises/logo`) : il faut que le port du serveur soit ouvert en TCP (c'est déjà le cas pour FiveM).
6. Staff : permission **« Entreprises des joueurs : modérer »** (`entreprises_manage`) dans l'éditeur de grades d'admin_menu
   (donnée au SuperAdmin au premier démarrage ; le Fondateur a tout), ou ACE : `add_ace group.admin elyzea.entreprises allow`.

## 2. Pour les joueurs

### Appli « Entreprises » (téléphone perso, sur l'accueil, pas besoin de l'installer)

| Onglet | Contenu |
|---|---|
| **Entreprise** | Toutes les entreprises des joueurs : logo, nom, spécialité, description, « n en service ». Recherche et filtre par spécialité. Appui sur une carte : fiche complète (numéro public, employés, fondateur). **Appeler** / **Message**. |
| **Lancer mon Business** | Coût (25 000 $ par défaut, payé depuis la **banque**), nom, logo, spécialité, couleur, description → **Payer et créer**. Si le joueur a déjà un métier (police, mécano…), il est prévenu qu'il le quittera. |
| **Mon business** (même onglet, une fois employé) | Sa vitrine : logo, spécialité, couleur, description (grades avec la permission « Modifier la vitrine »). |

**Logo** : « Choisir un logo » propose
- **Depuis mon ordinateur** : une page s'ouvre dans le navigateur de l'ordinateur (Alt+Tab), code déjà rempli ; on choisit une
  image (PNG, JPG, WEBP, GIF, 5 Mo max, recadrée en carré 512 × 512 si on laisse la case cochée) ; elle arrive toute seule
  dans le téléphone. L'image va directement chez l'hébergeur de l'appareil photo d'Elyzea Aura, jamais par le serveur FiveM.
- **Galerie du téléphone** (photos prises en jeu),
- **Lien d'une image** (https).

**Contacter une entreprise**
- **Appeler** : ça sonne sur le téléphone de service de **tous les employés en service** ; le premier qui décroche a le client,
  la sonnerie s'arrête chez les autres. Personne en service (ou entreprise fermée par le patron) : appel refusé,
  « laissez-lui un message ».
- **Message** : conversation dans l'appli Messages avec le numéro public de l'entreprise ; il arrive dans l'appli
  **Entreprise** du téléphone de service (notification aux employés en service), la réponse revient dans Messages.

### Les employés

| Action | Comment |
|---|---|
| Téléphone de service | **F6** : service, annuaire, messages internes, appels, collègues, appli **Entreprise** (messages des clients, ouvrir / fermer aux appels), **Tablette**. Numéro pro 919-XXXX, numéro public de l'entreprise 919-0001, 919-0002… |
| Tablette | Appli Tablette du téléphone de service (ou `/entreprise`) : tableau de bord, vitrine, recrutement, employés, grades, permissions, historique, finances, transactions. |
| Recruter | Tablette › Recrutement : la personne la plus proche (5 m) reçoit « Accepter / Refuser » (30 s). |
| Paie | Le temps de service est compté par le serveur ; la direction fixe un taux horaire par grade et paie depuis le compte de l'entreprise (Finance). |
| Compte | Finance › **Déposer** (depuis sa banque) / **Retirer** (vers sa banque) selon les permissions. |
| Quitter / dissoudre | Tableau de bord › « Quitter l'entreprise » ; le **fondateur** a « Dissoudre » : il retape le nom, tous les employés perdent le métier, le solde du compte lui est versé. |

Le fondateur qui prend un autre métier garde la propriété : l'appli lui propose « **Reprendre ma place de patron** ».

## 3. Grades et permissions

Grades créés avec chaque entreprise (tout se change dans la tablette) : **Employé** (1, recrues), **Responsable** (2),
**Directeur** (3), **Patron** (4, toutes les permissions, donné au créateur). Salaire de départ : 0 $/h (le patron le fixe).

Permissions : service, tablette, ouvrir / fermer aux appels, **vitrine**, direction, recruter, voir / modifier les employés,
promouvoir, rétrograder, renvoyer, historique, grades, permissions, finances, **dépôt**, **retrait**, salaires.
Mêmes règles que les autres métiers : on n'agit que sur un grade inférieur au sien et on ne donne que des permissions qu'on possède.

## 4. Réglages (`config.lua`)

- `Config.Create` : **prix** (25 000 $), capital de départ, longueurs du nom et de la description, nombre d'entreprises par
  personnage (1), délai avant de recréer après une dissolution (30 min), **mots interdits** dans le nom (police, LSPD, EMS…).
- `Config.Specialties` : la liste des spécialités (16 par défaut : commerce, restauration, transport, automobile, sécurité privée…).
- `Config.Colors` : couleurs proposées pour la vitrine.
- `Config.Logo.allowedHosts` : sites d'images autorisés pour un logo collé en lien (vide = tout lien https) ;
  `Config.Logo.import` : import depuis l'ordinateur (actif, durée du code, taille maximale, adresse publique du serveur).
- `Config.DefaultGrades`, `Config.Statuses`, `Config.Recruit`, `Config.Pay`, `Config.Money`, `Config.Keys` (F6).

## 5. Sécurité

- **Le serveur décide de tout** : prix et paiement (banque vérifiée, remboursé si la création échoue), noms (nettoyés, balises
  retirées, unicité sans tenir compte des accents ni de la casse, mots interdits, noms des métiers du serveur), spécialité,
  description, couleur, **liens d'image** (https seulement, sans guillemets ni parenthèses, hébergeurs autorisés), permissions
  de chaque action, hiérarchie des grades, montants (dépôt, retrait, salaires recalculés), une seule création à la fois.
- Anti-spam : limite de requêtes par seconde et par joueur.
- Import du logo : code à 6 caractères (15 min, 5 images au plus), taille et type vérifiés avant l'envoi, lien d'envoi à usage
  unique donné par l'hébergeur (la clé reste sur le serveur), lien final vérifié, **blocage après 8 mauvais codes** depuis une même adresse.
- Modération staff (`/entreprises_admin`) : suspendre / réactiver (motif obligatoire, le patron le voit, plus d'appels ni de
  service), retirer un logo ou une description, renommer, dissoudre (solde rendu au fondateur). Tout est journalisé (logs admin_menu).

## 6. Base de données

`ent_companies`, `ent_grades`, `ent_employees`, `ent_admin_log`, `ent_sessions`, `ent_rates`, `ent_transactions`
(créées toutes seules). Chaque entreprise a son métier `ent_<id>` et son compte de société `ent_<id>` dans elyzea_core.
Le numéro public et les messages des clients sont dans les tables du téléphone de service (`jobphone_business`, `jobphone_biz_messages`).

## 7. Fichiers des autres ressources modifiés

| Ressource | Fichier | Changement |
|---|---|---|
| elyzea_aura | `server/entreprises.lua` | **nouveau** : requêtes de l'appli Entreprises (passerelle vers elyzea_entreprises) |
| elyzea_aura | `html/js/entreprises.js`, `html/entreprises.css` | **nouveaux** : l'appli |
| elyzea_aura | `html/js/system.js` | appli « Entreprises » sur l'accueil |
| elyzea_aura | `html/js/icons.js` | icônes |
| elyzea_aura | `html/index.html`, `fxmanifest.lua` | chargement des nouveaux fichiers |
| elyzea_aura | `server/elyfy.lua` | exports `UploadUrl`, `UploadHostAllowed`, `ImportBase` (lien d'envoi de l'hébergeur, adresse du serveur) |
| elyzea_jobphone | `config.lua` | métier « Entreprise » (préfixe 919) |
| elyzea_jobphone | `server/business.lua` | une entreprise de joueurs est joignable dès sa création (les autres restent fermées jusqu'à « Ouvrir ») |
| admin_menu | `permissions_extra.lua`, `server/main.lua` | permission `entreprises_manage` (donnée au SuperAdmin au premier démarrage) |
| Serveur cfg | `server.cfg` | `ensure elyzea_entreprises` |

`admin_menu/config.lua` n'est pas modifié.

## 8. Limites de FiveM

- **Pas de bouton « Parcourir » dans le téléphone** : le navigateur intégré de FiveM ne peut pas ouvrir les fichiers de
  l'ordinateur. C'est pour ça que l'import passe par une **page web** ouverte dans le navigateur de l'ordinateur (avec le code).
  Si le serveur n'est pas joignable de l'extérieur sur son port (pare-feu, hébergeur), utilise la galerie ou un lien d'image.
- Un logo collé en **lien** dépend du site qui l'héberge (s'il supprime l'image, le logo disparaît) ; les logos importés
  depuis l'ordinateur sont chez l'hébergeur de l'appareil photo.
- Un joueur n'a **qu'un métier** dans elyzea_core : créer ou rejoindre une entreprise remplace son métier actuel (il est prévenu).
- Un appel du téléphone de service et un appel du téléphone perso utilisent le même canal de voix : pas les deux en même temps.

## 9. À essayer en jeu (à deux)

1. Joueur A : téléphone › Entreprises › Lancer mon Business : logo depuis l'ordinateur, création (25 000 $ retirés).
2. F6 : téléphone de service ; Tablette › Recrutement : recruter B ; B accepte.
3. B prend son service (F6). Joueur C : Entreprises › Appeler → ça sonne chez B ; B décroche, ils se parlent.
4. C envoie un message → B le voit dans l'appli Entreprise du téléphone de service et répond → C le reçoit dans Messages.
5. A : Finance › déposer, fixer un taux, payer B. Vitrine : changer la description → visible chez C.
6. Staff : `/entreprises_admin` › suspendre puis réactiver. A : dissoudre (solde reversé).
