-- KÖZÖS TÁRGYLISTA (kliens + szerver)
-- A kliens csak az indexet küldi, az árat és a tartalmat a SZERVER innen olvassa,
-- így a kliens nem tud hamis árat küldeni.

-- {név, ár, fegyverID vagy "armor"/"medkit", mennyiség, kinek: "A"=mindenki, "T"=Traitor, "D"=Detective}
ShopItems = {
    {"AK-47",          1000, 30,      90,  "A"},
    {"Silenced Pistol",1500, 23,      17,  "T"},
    {"Desert Eagle",   2500, 24,      5,   "T"},
    {"Sniper Rifle",   5000, 34,      1,   "A"},
    {"Armor (Kevlar)", 2000, "armor", 100, "A"},
    {"M4 Carbine",     4500, 31,      50,  "D"},
    {"Combat Shotgun", 3500, 27,      14,  "D"},
    {"Grenade",        1000, 16,      1,   "A"},
    {"C4 Explosive",   8000, 39,      1,   "T"},
    {"Medkit",         1500, "medkit",100, "D"},
}

-- {név, ár, kulcs, ped stat ID (nil = még nincs implementálva)}
ShopSkills = {
    {"Silenced Pistol Skill", 0,    "skill_silenced", 69},
    {"Stamina Upgrade",       1000, "skill_stamina",  22},
    {"M4 Skill",              1000, "skill_m4",       78},
    {"Health Boost",          3000, "skill_hp",       nil}, -- TODO: implementálni
    {"Stealth Walk",          2000, "skill_stealth",  nil}, -- TODO: implementálni
    {"AK-47 Skill",           5000, "skill_ak-47",    77},
}

-- Visszaadja, hogy az adott szerep látja-e a tárgyat
function isShopItemForRole(item, role)
    local who = item[5]
    return who == "A" or (who == "T" and role == "Traitor") or (who == "D" and role == "Detective")
end
