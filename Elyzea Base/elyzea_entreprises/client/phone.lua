-- =====================================================================
--  Téléphone de service (elyzea_jobphone) - pont client du métier
--  La tablette et le menu rapide existants s'ouvrent depuis le téléphone.
-- =====================================================================
local C = ENTC

exports('OpenTablet', function() if C.OpenTablet then C.OpenTablet() end end)
exports('OpenMenu', function() if C.OpenTablet then C.OpenTablet() end end)
exports('UiBusy', function() return C.AnyOpen() end)
