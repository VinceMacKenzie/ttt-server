Config = {}

-- Az adatbázis neve (ahogy korábban beszéltük)
Config.DatabaseName = "ttt_server"

-- Slot típusok definíciója
Config.Slots = {
    STORAGE = 0,    -- Táska/Inventory
    PRIMARY = 1,    -- Nagyfegyver (Sárga)
    SECONDARY = 2,  -- Kicsi (Sárga)
    SMG = 3,        -- SMG (Sárga)
    ARMOR = 4,      -- Kevlár (Sárga)
    SPECIAL = 5     -- Speciális (Kék)
}

-- Fegyverek alapbeállításai (MTA Weapon ID alapján)
Config.WeaponDefaults = {
    [30] = { name = "AK-47", defaultAmmo = 30, baseDamage = 20 },
    [31] = { name = "M4", defaultAmmo = 50, baseDamage = 18 },
    [24] = { name = "Desert Eagle", defaultAmmo = 7, baseDamage = 45 },
    [25] = { name = "Shotgun", defaultAmmo = 1, baseDamage = 10 } -- 10 per sörét
}

-- Buffok listája (Itt adhatod meg a nevüket és az esélyeket)
Config.Buffs = {
    ["fire"] = { label = "Tűz", chance = 10, duration = 5 }, -- 10% esély, 5 mp
    ["stun"] = { label = "Sokk", chance = 5, duration = 2 },
    ["poison"] = { label = "Méreg", chance = 15, duration = 8 },
    ["life_drain"] = { label = "Életelszívás", amount = 5 } -- 5 HP-t ad vissza
}

-- Átkok listája
Config.Curses = {
    ["recoil"] = { label = "Nagy visszarúgás" },
    ["heavy"] = { label = "Lassú mozgás" },
    ["jam"] = { label = "Beragadás esély" }
}

-- Sebzés szorzók határértékei (Pörgetésnél ezek közé essen az érték)
Config.MinOptValue = 5   -- 5%
Config.MaxOptValue = 20  -- 35%

-- Színkódok a GUI-hoz (Hogy ne kelljen mindenhol beírni)
Config.Colors = {
    GREEN = {0, 255, 0},
    YELLOW = {255, 255, 0},
    BLUE = {0, 150, 255},
    RED = {255, 0, 0},
    WHITE = {255, 255, 255}
}