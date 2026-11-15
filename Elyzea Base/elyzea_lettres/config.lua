-- =====================================================================
--  ELYZEA LETTRES · CONFIGURATION
--  Les valeurs « Defaults » ne servent qu'au premier démarrage : ensuite tout se règle en jeu,
--  dans le menu admin › Lettres (permission « lettres_manage »). Les réglages faits en jeu sont
--  gardés par le serveur (KVP de la ressource) et passent avant ce fichier.
-- =====================================================================
Config = {}

-- Noms des objets (déclarés dans elyzea_inventory/shared/items.lua)
Config.Items = {
    paper    = 'feuille_papier',    -- feuille vierge : ouvre la rédaction
    pen      = 'stylo_bille',       -- obligatoire pour écrire, jamais consommé
    letter   = 'lettre',            -- lettre terminée (l'objet n'est qu'une clé : le texte est en base)
    envelope = 'enveloppe',         -- enveloppe vide
    sealed   = 'enveloppe_lettre',  -- enveloppe contenant une lettre
}

-- Styles d'écriture (police manuscrite embarquée dans html/fonts, licences OFL à côté)
Config.Fonts = {
    { id = 'elegante',  label = 'Élégante' },   -- Dancing Script
    { id = 'naturelle', label = 'Naturelle' },  -- Caveat
    { id = 'arrondie',  label = 'Arrondie' },   -- Patrick Hand
}

-- Papiers (personnalisation)
Config.Papers = {
    { id = 'creme',  label = 'Crème' },
    { id = 'ligne',  label = 'Blanc ligné' },
    { id = 'ancien', label = 'Vieilli' },
}

-- Réglages par défaut (modifiables en jeu)
Config.Defaults = {
    maxChars   = 3000,        -- caractères du corps de la lettre
    maxPages   = 4,           -- pages par lettre
    fonts      = { elegante = true, naturelle = true, arrondie = true },
    defaultFont = 'elegante',
    papers     = { creme = true, ligne = true, ancien = true },
    -- Consommation des feuilles : 'letter' = 1 feuille par lettre, 'page' = 1 feuille par page écrite,
    -- 'none' = aucune (il faut quand même avoir une feuille sur soi pour écrire)
    consume    = 'letter',
    envelopes  = true,        -- enveloppes activées
    animation  = true,        -- animation d'écriture / de lecture
}

-- Bornes acceptées par le menu admin
Config.Limits = {
    maxChars = { 200, 10000 },
    maxPages = { 1, 10 },
}

Config.MaxRecipient = 60      -- caractères du destinataire
Config.MaxSignature = 60      -- caractères de la signature
Config.City = 'Los Santos'    -- lieu écrit devant la date (« Los Santos, le 15 novembre 2026 ») ; '' pour ne mettre que la date

-- Contrôle serveur du nombre de pages (le rendu est fait par l'interface, le serveur vérifie une borne basse)
Config.Layout = {
    linesPerPage = 22,        -- lignes sur une page pleine : 21 mesurées (feuille de 600 × 848 px, interligne 34 px), +1 de marge
    charsPerLine = 150,       -- borne haute de caractères par ligne (police la plus serrée, caractères les plus fins)
}

Config.DraftAutosave = 4      -- secondes entre deux sauvegardes automatiques du brouillon

-- Animations (déjà utilisées par l'emote « notepad » d'elyzea_animations)
Config.Anim = {
    write = {
        dict = 'missheistdockssetup1clipboard@base', clip = 'base', flag = 49,
        props = {
            { model = 'prop_notepad_01', bone = 18905, pos = { 0.1, 0.02, 0.05 }, rot = { 10.0, 0.0, 0.0 } },
            { model = 'prop_pencil_01',  bone = 58866, pos = { 0.11, -0.02, 0.001 }, rot = { -120.0, 0.0, 0.0 } },
        },
    },
    read = {
        dict = 'amb@world_human_clipboard@male@idle_a', clip = 'idle_a', flag = 49,
        props = {
            { model = 'prop_cliff_paper', bone = 60309, pos = { 0.097, -0.028, -0.017 }, rot = { 107.4, 3.27, -10.5 } },
        },
    },
}
