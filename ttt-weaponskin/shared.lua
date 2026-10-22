-----------------------------------------
-- TTT WEAPONSKIN – FEGYVER SKINEK – KÖZÖS LISTA (kliens + szerver)
-- Az árat a SZERVER innen olvassa, a kliens csak a fegyver ID-t és a skin kulcsát küldi.
-- Vásárlás: F3 shop -> FEGYVERSKIN fül, vagy az F4 skin menü [4] FEGYVER SKINEK fülén (SPACE kétszer)
-- Felvétel: F4 skin menü -> [4] FEGYVER SKINEK (vagy /fegyverskin)
--
-- Hogyan működik: a weaponskin.fx shader a fegyver eredeti (custom) textúráját festi át egy
-- csempézhető mintával (patterns/*.png). A minta a modell saját térében kerül fel, ezért
-- bármilyen fegyvermodellen működik, nem kell hozzá a modell UV-ja. Csak az adott játékos
-- kezében lévő fegyveren látszik (mindenki látja, a "tttWSkins" elementData szinkronizálja).
--
-- Új skin hozzáadása: tegyél egy 512x512-es csempézhető PNG-t a patterns/ mappába
-- (opcionálisan egy <név>_e.png világító maszkot: rgb = fény színe, alfa = villogás fázisa),
-- vedd fel a meta.xml-be, és írj ide egy új sort a WSkinThemes-be.
-- Kézzel festett, a modell UV-jához illő textúra is megadható fegyverenként: override = {[30] = "patterns/ak_valami.png"}
--
-- MEGRAJZOLT (livery) SKINEK: livery = "<név>" -> livery/<név>_bg.png (2048x512, vízszintesen csempézhető sáv),
-- livery/<név>_fg.png (1280x512, átlátszó matricák: felirat, figurák) + opcionális _bg_e / _fg_e világító maszkok.
-- Ezeket a shader a fegyver két oldalára vetíti a modell befoglaló dobozához igazítva (lásd WSkinWeaponLivery).
-----------------------------------------

WSkinConfig = {
    -- true: a szezonális skinek CSAK a saját szezonjukban vehetők meg (a megvettek mindig felvehetők)
    SEASONAL_SHOP = false,
}

-- Kategóriák. season = {"HH-NN", "HH-NN"} (lehet évfordulós is, pl. dec 1 – jan 10)
WSkinCategories = {
    xmas      = { label = "Karácsony",  color = {220, 60, 60},   season = {"12-01", "01-10"} },
    halloween = { label = "Halloween",  color = {255, 140, 30},  season = {"10-10", "11-10"} },
    newyear   = { label = "Szilveszter", color = {240, 200, 80}, season = {"12-20", "01-15"} },
    valentine = { label = "Valentin",   color = {255, 110, 160}, season = {"02-01", "02-20"} },
}
WSkinCategoryOrder = {"xmas", "halloween", "newyear", "valentine"}

-- Fegyverek: {MTA fegyver ID, megjelenő név, objektum modell ID (előnézethez), ár szorzó}
-- A nevek Paddy szerverén lévő custom modelleké, az ID-k a GTA fegyverek, amiket lecserélnek.
WSkinWeapons = {
    {22, "Glock 19",            346, 0.8},
    {23, "Silenced Five-Seven", 347, 0.8},
    {24, "Desert Eagle",        348, 1.0},
    {26, "Sawed Off Shotgun",   350, 1.0},
    {25, "MP-155 Shotgun",      349, 1.0},
    {32, "TEC-9",               372, 0.9},
    {28, "Kriss Vector",        352, 1.0},
    {29, "MP5",                 353, 1.0},
    {30, "AK-47",               355, 1.2},
    {31, "M4 / AR15",           356, 1.2},
    {34, "AWM",                 358, 1.3},
    {33, "M1 Garand",           357, 1.1},
}

-- Megrajzolt (livery) skinek elhelyezése fegyverenként (opcionális, fegyver ID szerint).
-- Alapból a modell dobozát a kliens automatikusan méri (vagy a GTA alap modell méretét veszi).
-- Ha egy custom modellen rossz helyen van a kép, itt állítható (élőben a /wskinbox paranccsal lehet kikísérletezni):
--   box = {minX, maxX, minY, maxY, minZ, maxZ}  a modell doboza méterben
--   flip = true          ha a cső -X felé néz (fordítva jelenne meg a kép)
--   swap = true          ha a modell hossz tengelye Y (alapból automatikus)
--   fgCenter = {u, v}    a matricák (felirat, figurák) közepe: u = hossz mentén (0 = tus vége, 1 = cső vége),
--                        v = magasság (0 = a fegyver teteje, 1 = alja: tár/markolat)
--   fgScale = 0.45       a matricák magassága a fegyver teljes magasságához képest
WSkinWeaponLivery = {
    -- [30] = { fgCenter = {0.40, 0.28}, fgScale = 0.5 },
}

-- A matricák alap helye modellenként {u, v, méret}: a tok/szán közepére, a tár/markolat fölé
WSkinDefaultFG = {
    [346] = {0.55, 0.30, 0.42}, [347] = {0.45, 0.30, 0.40}, [348] = {0.55, 0.30, 0.45}, [372] = {0.55, 0.35, 0.38},
    [349] = {0.40, 0.42, 0.45}, [350] = {0.45, 0.40, 0.48}, [351] = {0.40, 0.40, 0.45},
    [352] = {0.55, 0.30, 0.38}, [353] = {0.45, 0.40, 0.40},
    [355] = {0.40, 0.30, 0.42}, [356] = {0.40, 0.33, 0.42}, [357] = {0.40, 0.40, 0.45}, [358] = {0.40, 0.42, 0.45},
}

-- GTA alap fegyvermodellek doboza (tartalék, ha a kliens nem tudja lemérni): {minX, maxX, minY, maxY, minZ, maxZ}
WSkinDefaultBox = {
    [346] = {-0.007, 0.242, 0.003, 0.056, -0.055, 0.128},  -- colt45
    [347] = {-0.007, 0.363, 0.003, 0.068, -0.055, 0.152},  -- silenced
    [348] = {0.004, 0.353, -0.015, 0.052, -0.067, 0.124},  -- desert_eagle
    [349] = {-0.270, 0.774, -0.062, 0.092, -0.094, 0.224}, -- chromegun
    [350] = {-0.251, 0.329, -0.035, 0.062, -0.053, 0.135}, -- sawnoff
    [351] = {0.013, 0.727, -0.050, 0.056, -0.064, 0.243},  -- shotgspa
    [352] = {-0.069, 0.244, -0.014, 0.049, -0.264, 0.131}, -- micro_uzi
    [353] = {-0.082, 0.457, -0.038, 0.056, -0.079, 0.256}, -- mp5lng
    [355] = {-0.308, 0.784, -0.056, 0.075, -0.140, 0.176}, -- ak47
    [356] = {-0.255, 0.739, -0.053, 0.063, -0.111, 0.166}, -- m4
    [357] = {-0.280, 0.747, -0.053, 0.095, -0.094, 0.214}, -- cuntgun
    [358] = {-0.318, 0.764, -0.056, 0.093, -0.069, 0.176}, -- sniper
    [372] = {0.002, 0.409, -0.005, 0.070, -0.231, 0.138},  -- tec9
}

-- Skin témák. tex = patterns/<tex>.png (+ patterns/<tex>_e.png ha glow > 0)
-- scale: minta ismétlés / méter | strength: fedés 0..1 | detail: eredeti részletek 0..1
-- keepDark: sötét részek (cső, lyukak) érintetlenül 0..1 | gloss: csillanás | glow/glowSpeed/glowMin: világítás
WSkinThemes = {
    -- KARÁCSONY
    { key = "candy",   cat = "xmas", name = "Cukorbot",        price = 4000, tex = "xmas_candy",
      scale = 4.0, detail = 0.4, keepDark = 0.7, gloss = 0.55,
      desc = "Piros-fehér-zöld csíkos, fényes cukorka festés." },
    { key = "sweater", cat = "xmas", name = "Ronda Pulcsi",    price = 4500, tex = "xmas_sweater",
      scale = 3.0, detail = 0.45, keepDark = 0.6, gloss = 0.0,
      desc = "Kötött karácsonyi pulóver: hópelyhek, fenyők, cikcakk." },
    { key = "frost",   cat = "xmas", name = "Fagyos",          price = 6000, tex = "xmas_frost",
      scale = 3.5, detail = 0.7, keepDark = 0.5, gloss = 0.8, glow = 0.55, glowSpeed = 1.6, glowMin = 0.1,
      desc = "Jégkék dér, csillogó jégkristályokkal." },
    { key = "lights",  cat = "xmas", name = "Fényfüzér",       price = 8000, tex = "xmas_lights",
      scale = 3.0, detail = 0.6, keepDark = 0.6, gloss = 0.2, glow = 1.1, glowSpeed = 3.0, glowMin = 0.05,
      desc = "Fenyőzöld, villogó színes karácsonyi izzókkal." },
    { key = "gift",    cat = "xmas", name = "Ajándékcsomag",   price = 5000, tex = "xmas_gift",
      scale = 3.0, detail = 0.55, keepDark = 0.6, gloss = 0.45, glow = 0.6, glowSpeed = 2.5, glowMin = 0.0,
      desc = "Piros csomagolópapír arany szalaggal és csillagokkal." },

    { key = "mezeskalacs", cat = "xmas", name = "Mézeskalács", premium = true, price = 15000, tex = "xmas_ginger",
      scale = 3.0, detail = 0.5, keepDark = 0.6, gloss = 0.35, glow = 0.8, glowSpeed = 2.0, glowMin = 0.1,
      livery = "mezeskalacs", liveryGlow = 0.8,
      desc = "Megrajzolt skin: mézeskalács tészta cukormázzal, gumicukrok, mézeskalács ember, HO HO HO." },

    -- HALLOWEEN
    { key = "pumpkin", cat = "halloween", name = "Tökfej",     price = 7000, tex = "hw_pumpkin",
      scale = 2.2, detail = 0.6, keepDark = 0.6, gloss = 0.25, glow = 1.2, glowSpeed = 9.0, glowMin = 0.55,
      desc = "Bordázott tök, pislákoló gyertyafényes töklámpás arcokkal." },
    { key = "web",     cat = "halloween", name = "Pókháló",    price = 4500, tex = "hw_web",
      scale = 3.0, detail = 0.6, keepDark = 0.3, gloss = 0.15,
      desc = "Sötétlila alap, fehér pókhálók és apró pókok." },
    { key = "liderc",  cat = "halloween", name = "Lidérc", premium = true, price = 15000, tex = "hw_ecto",
      scale = 2.5, detail = 0.6, keepDark = 0.6, gloss = 0.5, glow = 1.0, glowSpeed = 2.2, glowMin = 0.25,
      livery = "liderc", liveryGlow = 1.0,
      desc = "Megrajzolt skin: lila alap, csöpögő zöld lidércnyálka, szellem és töklámpás, világító felirat." },
    { key = "tokkiraly", cat = "halloween", name = "Tökkirály", premium = true, price = 15000, tex = "hw_pumpkin",
      scale = 2.2, detail = 0.6, keepDark = 0.6, gloss = 0.3, glow = 1.0, glowSpeed = 7.0, glowMin = 0.55,
      livery = "tokkiraly", liveryGlow = 1.0,
      desc = "Megrajzolt skin: lángoló alj, indák, cukorka, koronás töklámpás király." },
    { key = "ecto",    cat = "halloween", name = "Lidércfény", price = 9000, tex = "hw_ecto",
      scale = 2.5, detail = 0.65, keepDark = 0.4, gloss = 0.5, glow = 1.3, glowSpeed = 2.2, glowMin = 0.2,
      desc = "Sötét lila fegyver, lüktető zöld lidércfény erekkel." },
    { key = "bones",   cat = "halloween", name = "Csontváz",   price = 6000, tex = "hw_bones",
      scale = 3.0, detail = 0.5, keepDark = 0.3, gloss = 0.2, glow = 0.9, glowSpeed = 1.5, glowMin = 0.1,
      desc = "Fekete alap, csontok és izzó szemű koponyák." },

    -- EGYÉB
    { key = "nye",     cat = "newyear",   name = "Pezsgő",     price = 7500, tex = "misc_nye",
      scale = 3.5, detail = 0.6, keepDark = 0.6, gloss = 0.9, glow = 0.9, glowSpeed = 4.0, glowMin = 0.0,
      desc = "Arany csillámfesték konfettivel és szikrázó csillagokkal." },
    { key = "hearts",  cat = "valentine", name = "Szívtipró",  price = 5000, tex = "misc_valentine",
      scale = 3.0, detail = 0.5, keepDark = 0.5, gloss = 0.35, glow = 0.5, glowSpeed = 2.0, glowMin = 0.2,
      desc = "Rózsaszín alap, piros és fehér szívecskék." },
}

-----------------------------------------
-- Segédtáblák / függvények
-----------------------------------------
WSkinByKey = {}
for _, t in ipairs(WSkinThemes) do WSkinByKey[t.key] = t end

WSkinWeaponByID = {}
for i, w in ipairs(WSkinWeapons) do WSkinWeaponByID[w[1]] = {id = w[1], name = w[2], model = w[3], mult = w[4], index = i} end

-- Ár egy adott fegyverre (téma alapár * fegyver szorzó, 100-ra kerekítve)
function getWeaponSkinPrice(weaponID, key)
    local t, w = WSkinByKey[key], WSkinWeaponByID[tonumber(weaponID)]
    if not t or not w then return nil end
    return math.floor(t.price * (w.mult or 1) / 100 + 0.5) * 100
end

function getWeaponSkinName(weaponID, key)
    local t, w = WSkinByKey[key], WSkinWeaponByID[tonumber(weaponID)]
    if not t or not w then return nil end
    return w.name .. " | " .. t.name
end

local function mmdd(s)
    local m, d = s:match("^(%d+)-(%d+)$")
    return tonumber(m) * 100 + tonumber(d)
end

-- Szezonban van-e most a téma (ha SEASONAL_SHOP ki van kapcsolva, mindig true)
function isWeaponSkinInSeason(key)
    if not WSkinConfig.SEASONAL_SHOP then return true end
    local t = WSkinByKey[key]
    local cat = t and WSkinCategories[t.cat]
    if not cat or not cat.season then return true end
    local rt = getRealTime()
    local now = (rt.month + 1) * 100 + rt.monthday
    local from, to = mmdd(cat.season[1]), mmdd(cat.season[2])
    if from <= to then return now >= from and now <= to end
    return now >= from or now <= to   -- évfordulós (pl. dec 1 – jan 10)
end

-- Ezeket a textúrákat SOHA nem festjük át (torkolattűz, HUD ikon, célkereszt)
function isWeaponSkinIgnoredTexture(name)
    local n = name:lower()
    return n:find("muzzle", 1, true) or n:find("icon", 1, true) or n:find("crosshair", 1, true)
end
