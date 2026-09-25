-- KÖZÖS SKIN LISTA (kliens + szerver): {"Név", Ár, SkinID}
-- Az árat a SZERVER innen olvassa, a kliens csak a skin ID-t küldi.
SkinList = {
    {"basic",         0,     0},
    {"basic",         500,   1},
    {"Basic Guard",   1500,  71},
    {"Mafia Boss",    5000,  113},
    {"Swat Team",     3000,  285},
    {"Agent",         4500,  165},
    {"Darth Maul",    20000, 24},
    {"Ezio Auditore", 25000, 25},
    {"Chiss",         1000,  27},
    {"Gran",          1000,  28},
    {"Weequay",       1000,  29},
}

SkinByID = {}
for _, s in ipairs(SkinList) do SkinByID[s[3]] = s end

function getSkinDisplayName(skinID)
    local s = SkinByID[skinID]
    if not s or s[1] == "basic" then return "Skin #" .. tostring(skinID) end
    return s[1]
end
