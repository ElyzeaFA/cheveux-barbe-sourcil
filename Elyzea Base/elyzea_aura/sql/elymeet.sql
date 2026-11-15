-- =========================================================
--  ELYMEET : tables (créées automatiquement au démarrage par server/elymeet.lua)
--  Les anciennes tables d'Étincelle (elyzea_dating_*) ne sont pas touchées : elles servent à pré-remplir l'inscription.
-- =========================================================
CREATE TABLE IF NOT EXISTS `elyzea_em_profiles` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(64) NOT NULL,
  `name` VARCHAR(30) NOT NULL,
  `age` INT NOT NULL,
  `gender` VARCHAR(8) NOT NULL,
  `seek` VARCHAR(8) NOT NULL,
  `looking` VARCHAR(12) NOT NULL DEFAULT 'unsure',
  `photos` TEXT NOT NULL,
  `interests` TEXT NOT NULL,
  `bio` VARCHAR(300) NOT NULL DEFAULT '',
  `job` VARCHAR(40) NOT NULL DEFAULT '',
  `age_min` INT NOT NULL DEFAULT 18,
  `age_max` INT NOT NULL DEFAULT 99,
  `visible` TINYINT NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `identifier` (`identifier`)
);

CREATE TABLE IF NOT EXISTS `elyzea_em_crossings` (
  `a` INT NOT NULL,
  `b` INT NOT NULL,
  `count` INT NOT NULL DEFAULT 1,
  `last_ts` INT NOT NULL,
  `x` FLOAT NOT NULL,
  `y` FLOAT NOT NULL,
  PRIMARY KEY (`a`, `b`),
  KEY `b` (`b`),
  KEY `last` (`last_ts`)
);

CREATE TABLE IF NOT EXISTS `elyzea_em_likes` (
  `who` INT NOT NULL,
  `target` INT NOT NULL,
  `kind` VARCHAR(6) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`who`, `target`),
  KEY `target` (`target`, `kind`)
);

CREATE TABLE IF NOT EXISTS `elyzea_em_matches` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `a` INT NOT NULL,
  `b` INT NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `pair` (`a`, `b`),
  KEY `b` (`b`)
);

CREATE TABLE IF NOT EXISTS `elyzea_em_messages` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `match_id` INT NOT NULL,
  `sender` INT NOT NULL,
  `body` VARCHAR(500) NOT NULL,
  `seen` TINYINT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `match` (`match_id`, `id`)
);
