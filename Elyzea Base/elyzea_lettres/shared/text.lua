-- =====================================================================
--  ELYZEA LETTRES · TEXTE (partagé)
--  Nettoyage des textes envoyés par l'interface : UTF-8 valide, caractères de contrôle retirés,
--  retours à la ligne normalisés. Les accents, apostrophes (’ '), guillemets (« »), tirets et
--  emojis sont gardés tels quels. Les longueurs se comptent en caractères, pas en octets.
-- =====================================================================
LetterText = {}

-- Longueur en caractères (nil si le texte n'est pas de l'UTF-8 valide)
function LetterText.len(s)
    if type(s) ~= 'string' then return nil end
    return utf8.len(s)
end

-- Retire les caractères invisibles dangereux pour l'affichage : contrôle C0 (sauf \n), DEL, C1,
-- marques de direction (U+202A-202E, U+2066-2069) qui retourneraient le texte.
local function strip(s, multiline)
    s = s:gsub('\r\n', '\n'):gsub('\r', '\n'):gsub('\t', '    ')
    if not multiline then s = s:gsub('\n', ' ') end
    s = s:gsub('[%z\1-\9\11-\31\127]', '')
    local out = {}
    for _, cp in utf8.codes(s) do
        local bad = (cp >= 0x80 and cp <= 0x9F) or (cp >= 0x202A and cp <= 0x202E) or (cp >= 0x2066 and cp <= 0x2069)
            or cp == 0xFEFF or (cp >= 0xFFF9 and cp <= 0xFFFB)
        if not bad then out[#out + 1] = utf8.char(cp) end
    end
    return table.concat(out)
end

-- Nettoie un texte. Renvoie (texte, nil) ou (nil, raison).
-- Le texte gardé est EXACTEMENT celui que l'auteur a vu dans l'aperçu : seuls les caractères invisibles
-- de contrôle sont retirés (le clavier ne peut pas les taper). Lignes vides, espaces, retraits : intacts.
-- opts = { max = caractères, multiline = bool }
function LetterText.clean(s, opts)
    opts = opts or {}
    if s == nil then s = '' end
    if type(s) ~= 'string' then return nil, 'type' end
    if #s > (opts.max or 0) * 4 + 64 then return nil, 'too_long' end   -- borne en octets avant tout calcul
    if not utf8.len(s) then return nil, 'utf8' end
    s = strip(s, opts.multiline)
    local n = utf8.len(s)
    if opts.max and n > opts.max then return nil, 'too_long' end
    return s, nil
end

-- Nombre minimal de pages que ce corps occupe (borne basse, quelle que soit la police)
function LetterText.minPages(body, linesPerPage, charsPerLine)
    local lines = 0
    for line in (body .. '\n'):gmatch('([^\n]*)\n') do
        local n = utf8.len(line) or #line
        lines = lines + math.max(1, math.ceil(n / charsPerLine))
    end
    -- première page : date + destinataire ; dernière : signature (2 lignes chacune environ)
    return math.max(1, math.ceil((lines + 4) / linesPerPage))
end
