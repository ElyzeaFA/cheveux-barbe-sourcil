-- Table des lettres (elyzea_lettres). Elle est créée AUTOMATIQUEMENT au démarrage de la ressource :
-- ce fichier ne sert que si vous préférez la créer vous-même (phpMyAdmin › SQL).
CREATE TABLE IF NOT EXISTS `elyzea_letters` (
    `id` VARCHAR(16) NOT NULL,
    `author_cid` VARCHAR(64) NULL,
    `author_name` VARCHAR(100) NULL,
    `recipient` VARCHAR(255) NOT NULL DEFAULT '',
    `body` MEDIUMTEXT NOT NULL,
    `signature` VARCHAR(255) NOT NULL DEFAULT '',
    `font` VARCHAR(20) NOT NULL,
    `paper` VARCHAR(20) NOT NULL,
    `pages` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `layout` VARCHAR(20) NOT NULL DEFAULT 'lettre-v1',
    `created` DATETIME NOT NULL,
    PRIMARY KEY (`id`), KEY `author_cid` (`author_cid`), KEY `created` (`created`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
