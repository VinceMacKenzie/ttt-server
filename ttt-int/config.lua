-----------------------------------------
-- BEÁLLÍTÁSOK (szerver) - ezt a fájlt szerkeszd
-----------------------------------------

-- Fegyver spawn szintek: /cweapon [norm|epic|legendary]
-- Ide írd be, hogy az adott szintű spawnon MELYIK fegyverek (ID-k) jelenhetnek meg.
-- Minden körnél véletlenszerűen választ a listából.
-- Egy elem lehet sima ID (30), vagy { ID, lőszer } (pl. { 34, 15 }), ha egyedi lőszer kell.
-- Fegyver ID-k: https://wiki.multitheftauto.com/wiki/Weapons
WEAPON_TIERS = {
    norm      = { 22, 23, 25, 28, 32 },     -- Colt, Silenced, Shotgun, Uzi, Tec-9
    epic      = { 24, 26, 29, 30, 31 },     -- Deagle, Sawed-off, MP5, AK-47, M4
    legendary = { 27, 33, 34 },             -- Combat Shotgun, Rifle, Sniper
}

-- Alap lőszer szintenként (felülírható a fenti listában { ID, lőszer } formával)
TIER_AMMO = {
    norm = 50,
    epic = 80,
    legendary = 120,
}

-- Körkezdéskor ("ttt:onRoundStart") az összes fegyver spawn újradobása
REROLL_ON_ROUND_START = true

-- Felvétel után hány ms múlva jelenjen meg új (újra dobott) fegyver ugyanott.
-- 0 = nem jelenik meg újra (TTT-s működés: körönként egyszer)
PICKUP_RESPAWN_MS = 0
