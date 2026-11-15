-- =========================================================
--  ELYCHAT : tables (créées automatiquement au démarrage par server/elychat.lua)
--  Les comptes (nom d'utilisateur, nom affiché) sont dans elyzea_accounts (app = 'elychat').
-- =========================================================
CREATE TABLE IF NOT EXISTS `elyzea_ec_profiles` (
  `identifier` VARCHAR(64) NOT NULL,
  `avatar` VARCHAR(500) NULL,
  `color` VARCHAR(9) NOT NULL DEFAULT '#FFD60A',
  `score` INT NOT NULL DEFAULT 0,
  `share` VARCHAR(8) NOT NULL DEFAULT 'off',
  `share_list` TEXT NULL,
  `last_x` FLOAT NULL,
  `last_y` FLOAT NULL,
  `last_ts` INT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`)
);

CREATE TABLE IF NOT EXISTS `elyzea_ec_friends` (
  `a` VARCHAR(64) NOT NULL,
  `b` VARCHAR(64) NOT NULL,
  `status` VARCHAR(8) NOT NULL DEFAULT 'pending',
  `requester` VARCHAR(64) NOT NULL,
  `streak` INT NOT NULL DEFAULT 0,
  `streak_day` INT NOT NULL DEFAULT 0,
  `a_day` INT NOT NULL DEFAULT 0,
  `b_day` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`a`, `b`),
  KEY `b` (`b`)
);

CREATE TABLE IF NOT EXISTS `elyzea_ec_snaps` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `sender` VARCHAR(64) NOT NULL,
  `recipient` VARCHAR(64) NOT NULL,
  `url` VARCHAR(500) NULL,
  `caption` VARCHAR(120) NOT NULL DEFAULT '',
  `duration` INT NOT NULL DEFAULT 5,
  `opened` TINYINT NOT NULL DEFAULT 0,
  `opened_at` INT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `recipient` (`recipient`, `opened`),
  KEY `pair` (`sender`, `recipient`, `id`)
);

CREATE TABLE IF NOT EXISTS `elyzea_ec_messages` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `a` VARCHAR(64) NOT NULL,
  `b` VARCHAR(64) NOT NULL,
  `sender` VARCHAR(64) NOT NULL,
  `body` VARCHAR(500) NOT NULL,
  `seen` TINYINT NOT NULL DEFAULT 0,
  `seen_at` INT NULL,
  `saved` TINYINT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `pair` (`a`, `b`, `id`)
);
