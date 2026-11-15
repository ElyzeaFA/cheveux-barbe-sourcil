-- =====================================================================
--  ELYZEA CACHETTES - tables (créées AUTOMATIQUEMENT au démarrage de la ressource)
--  Ce fichier contient les mêmes requêtes, si tu préfères les lancer à la main.
--  Le contenu des cachettes est dans la table `elyzea_stashes` d'elyzea_inventory
--  (identifiant « cach:<id du véhicule>:<emplacement> ») : aucune table d'inventaire en plus.
-- =====================================================================

-- Une ligne par emplacement aménagé (ou en cours d'aménagement) d'un véhicule immatriculé
CREATE TABLE IF NOT EXISTS `elyzea_cachettes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `vehicle_id` int(11) NOT NULL,                 -- player_vehicles.id (suit le véhicule : vente, nouvelle plaque)
  `slot` varchar(16) NOT NULL,                   -- door_fl, door_fr, door_rl, door_rr, trunk, wheel_fl … seat_rr, saddle
  `state` tinyint(1) NOT NULL DEFAULT 0,         -- 0 = installation pas encore réussie, 1 = cachette installée
  `attempts` int(11) NOT NULL DEFAULT 0,         -- essais RATÉS avant la réussite de l'installation
  `suspicion` tinyint(1) NOT NULL DEFAULT 0,     -- 0 aucune · 1 légère · 2 élevée (fixée à l'installation)
  `capacity` int(11) NOT NULL DEFAULT 0,         -- grammes (capacité propre à cet emplacement)
  `category` varchar(16) DEFAULT NULL,           -- small · medium · large · moto
  `installed_by` varchar(50) DEFAULT NULL,       -- citizenid (information seulement)
  `installed_at` timestamp NULL DEFAULT NULL,
  `opened_at` timestamp NULL DEFAULT NULL,
  `discovered` tinyint(1) NOT NULL DEFAULT 0,    -- déjà ouverte par la police
  PRIMARY KEY (`id`),
  UNIQUE KEY `vehicle_slot` (`vehicle_id`, `slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Journal : installations, essais ratés, ouvertures, fouilles, saisies, inspections, suppressions staff
CREATE TABLE IF NOT EXISTS `elyzea_cachettes_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `vehicle_id` int(11) NOT NULL,
  `slot` varchar(16) NOT NULL,
  `action` varchar(24) NOT NULL,                 -- install_fail, install, open, store, take, police_empty, police_found, seize, inspect, admin_delete
  `citizenid` varchar(50) DEFAULT NULL,
  `detail` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `vehicle_id` (`vehicle_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
