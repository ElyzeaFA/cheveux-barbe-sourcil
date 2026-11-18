-- =====================================================================
--  ELYZEA K9 : tables (créées automatiquement au démarrage ; ce fichier est là pour une installation manuelle)
-- =====================================================================
CREATE TABLE IF NOT EXISTS `elyzea_k9_dogs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `owner` VARCHAR(64) NOT NULL,            -- citizenid du maître
  `side` VARCHAR(8) NOT NULL,              -- police | gang
  `group_name` VARCHAR(64) NULL,           -- police, ou nom du groupe (elyzea_illegal)
  `name` VARCHAR(24) NOT NULL,
  `breed` VARCHAR(24) NOT NULL,            -- race (Config.Breeds)
  `specialty` VARCHAR(16) NULL,            -- police : detection | attack | tracking
  `level` INT NOT NULL DEFAULT 1,
  `xp` INT NOT NULL DEFAULT 0,
  `points` INT NOT NULL DEFAULT 0,         -- points de compétence non dépensés
  `skills` TEXT NOT NULL,                  -- JSON { sniff, obey, attack, track } ou { attack, defense, intim }
  `health` INT NOT NULL DEFAULT 100,
  `injured_until` INT NOT NULL DEFAULT 0,  -- horodatage : blessé (au chenil) jusqu'à
  `stats` TEXT NOT NULL,                   -- JSON : interventions, séances, anti-farm du jour
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `owner_side` (`owner`, `side`)
);

CREATE TABLE IF NOT EXISTS `elyzea_k9_history` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `dog_id` INT NOT NULL,
  `kind` VARCHAR(12) NOT NULL,             -- train | mission | level | skill | info
  `label` VARCHAR(120) NOT NULL,
  `xp` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `dog` (`dog_id`, `id`)
);
