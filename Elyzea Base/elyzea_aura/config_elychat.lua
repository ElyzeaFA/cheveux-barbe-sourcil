-- =========================================================
--  ELYCHAT : messagerie photo (comme Snapchat) : snaps, chat éphémère, amis,
--  carte des amis (partage de position), ElyScore et flammes.
--  Fichier séparé de config.lua : ton config.lua (clé d'hébergeur…) n'est pas touché.
-- =========================================================
Config.ElyChat = {
    MessageLength = 400,        -- caractères par message
    CaptionLength = 80,         -- texte posé sur un snap
    Durations = { 3, 5, 10, 0 },-- durées d'affichage d'un snap (secondes ; 0 = sans limite, jusqu'à ce qu'on le ferme)
    MaxRecipients = 15,         -- destinataires d'un même snap
    ChatHours = 24,             -- un message vu disparaît après ce délai (sauf s'il est enregistré)
    SnapDays = 30,              -- un snap jamais ouvert disparaît après ce délai
    ScoreSend = 1,              -- ElyScore gagné par destinataire quand on envoie un snap photo
    ScoreOpen = 1,              -- ElyScore gagné quand on ouvre un snap reçu
    StreakHours = 24,           -- flammes : il faut s'échanger un snap chaque jour (la flamme s'éteint sinon)
    MapRefresh = 15,            -- secondes entre deux mises à jour de la carte ouverte
    SavePositionEvery = 60,     -- secondes : dernière position connue enregistrée (amis hors ligne)
    Colors = { '#FFD60A', '#FF5A5F', '#FF8A3D', '#3DDC97', '#2EC4F1', '#5B6CFF', '#B15CFF', '#FF6FB5' },
}
