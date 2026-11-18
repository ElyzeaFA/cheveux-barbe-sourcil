-- =====================================================================
--  ELYZEA ENTREPRISES - permissions des grades (chaque entreprise a ses grades)
--  Le patron coche, grade par grade, ce que chacun peut faire (tablette ›
--  Direction › Permissions). Le client n'en décide jamais : chaque action
--  est revérifiée par le serveur.
-- =====================================================================
ENTPerms = {
    -- Service
    { key = 'duty',           group = 'Service',     label = 'Prendre son service (répondre aux appels et messages des clients)' },
    { key = 'tablet',         group = 'Service',     label = 'Accéder à la tablette' },
    { key = 'open',           group = 'Service',     label = 'Ouvrir / fermer l\'entreprise aux appels des clients' },
    -- Vitrine
    { key = 'profile',        group = 'Vitrine',     label = 'Modifier la vitrine : logo, spécialité, description, couleur' },
    -- Direction
    { key = 'direction',      group = 'Direction',   label = 'Accéder à la direction' },
    { key = 'recruit',        group = 'Direction',   label = 'Recruter' },
    { key = 'employees_view', group = 'Direction',   label = 'Consulter les employés' },
    { key = 'employees_edit', group = 'Direction',   label = 'Modifier les fiches des employés' },
    { key = 'promote',        group = 'Direction',   label = 'Promouvoir' },
    { key = 'demote',         group = 'Direction',   label = 'Rétrograder' },
    { key = 'fire',           group = 'Direction',   label = 'Retirer un employé de l\'entreprise' },
    { key = 'history_view',   group = 'Direction',   label = 'Consulter l\'historique du personnel' },
    { key = 'grades_manage',  group = 'Direction',   label = 'Créer, modifier et désactiver les grades' },
    { key = 'perms_manage',   group = 'Direction',   label = 'Choisir les permissions des grades' },
    -- Finance
    { key = 'finance',        group = 'Finance',     label = 'Voir les finances de l\'entreprise' },
    { key = 'deposit',        group = 'Finance',     label = 'Déposer de l\'argent sur le compte de l\'entreprise' },
    { key = 'withdraw',       group = 'Finance',     label = 'Retirer de l\'argent du compte de l\'entreprise' },
    { key = 'payroll',        group = 'Finance',     label = 'Régler les salaires horaires et payer' },
}

ENTPermSet = {}
for _, p in ipairs(ENTPerms) do ENTPermSet[p.key] = true end
