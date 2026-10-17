Config = {}

Config.DatabaseName = "ttt_server"

-- Slot típusok
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

-- Buffok (chance = % esély pörgetésnél / találatnál, duration = mp)
Config.Buffs = {
    fire       = { label = "Tűz", chance = 20, duration = 3 },
    stun       = { label = "Sokk", chance = 5, duration = 2 },
    poison     = { label = "Méreg", chance = 10, duration = 8 },
    life_drain = { label = "Életelszívás", amount = 5 } -- 5 HP-t ad vissza
}

-- Átkok
Config.Curses = {
    recoil = { label = "Nagy visszarúgás" },
    heavy  = { label = "Lassú mozgás" },
    jam    = { label = "Beragadás esély" }
}

-- Sebzés szorzók határértékei pörgetésnél (%)
Config.MinOptValue = 5
Config.MaxOptValue = 20

Config.Colors = {
    GREEN = {0, 255, 0},
    YELLOW = {255, 255, 0},
    BLUE = {0, 150, 255},
    RED = {255, 0, 0},
    WHITE = {255, 255, 255}
}
