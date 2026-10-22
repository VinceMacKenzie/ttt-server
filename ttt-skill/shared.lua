-----------------------------------------
-- TTT SKILL - közös adatok (szerver + kliens)
-- Minden skillhez tartozik egy pontszám (0-1000), ami a GTA fegyverskill statokat (setPedStat) állítja.
-- Stat ID-k: https://wiki.multitheftauto.com/wiki/SetPedStat
--   69 Pistol | 70 Pistol Silenced | 71 Desert Eagle | 72 Shotgun | 73 Sawn-off | 74 SPAS-12
--   75 Micro Uzi (a Tec-9 is ezt használja) | 76 MP5 | 77 AK-47 | 78 M4 | 79 Sniper Rifle (a Country Rifle is)
-- Új skill felvételéhez: SKILLS (+ WEAPON_SKILL) bővítése, és a meglévő táblához az oszlop:
--   ALTER TABLE skills ADD COLUMN `skill_Xyz` INT NOT NULL DEFAULT 0;
-----------------------------------------
MAX_SKILL = 1000   -- a setPedStat 0 és 1000 közötti értéket fogad el

SKILLS = {
    { key = "skill_Pistol",   label = "Pistol",    weapons = "USP / Colt / Deagle",   stats = { 69, 70, 71 } },
    { key = "skill_SMG",      label = "SMG",       weapons = "Uzi / Tec-9",           stats = { 75 } },
    { key = "skill_Sniper",   label = "Sniper",    weapons = "Sniper / Country Rifle", stats = { 79 } },
    { key = "skill_AK",       label = "AK",        weapons = "AK-47",                 stats = { 77 } },
    { key = "skill_M4",       label = "M4",        weapons = "M4",                    stats = { 78 } },
    { key = "skill_MP5",      label = "MP5",       weapons = "MP5",                   stats = { 76 } },
    { key = "skill_Shotgun",  label = "Shotgun",   weapons = "Shotgun",               stats = { 72 } },
    { key = "skill_SavedOff", label = "Sawed-off", weapons = "Sawed-off Shotgun",     stats = { 73 } },
}

-- MTA fegyver ID -> skill (melyik fegyverrel ölve jár pont)
WEAPON_SKILL = {
    [22] = "skill_Pistol",   -- Colt 45
    [23] = "skill_Pistol",   -- Silenced (USP)
    [24] = "skill_Pistol",   -- Desert Eagle
    [25] = "skill_Shotgun",
    [26] = "skill_SavedOff", -- Sawed-off
    [28] = "skill_SMG",      -- Uzi
    [32] = "skill_SMG",      -- Tec-9
    [29] = "skill_MP5",
    [30] = "skill_AK",
    [31] = "skill_M4",
    [33] = "skill_Sniper",   -- Country Rifle
    [34] = "skill_Sniper",
}
