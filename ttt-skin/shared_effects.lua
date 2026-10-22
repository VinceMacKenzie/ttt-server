-----------------------------------------
-- TTT SKIN – EFFEKTEK (Metin2 stílusú aurák) – KÖZÖS LISTA (kliens + szerver)
-- Az árat a SZERVER innen olvassa, a kliens csak a kulcsot küldi.
-- Vásárlás: F3 shop -> EFFEKTEK fül | Felvétel: F4 skin menü -> [3] EFFEKTEK
--
-- Emitter módok:
--   "burst"  (alap) részecskéket szór: rate/mp, life {min,max}, size {kezdő,vég}, color {r,g,b}, color2 (vég szín),
--            alpha, vz/vxy (sebesség), gravity, spin, twinkle, upright (mindig álló sprite), stretch (magasság szorzó),
--            anchor: "body" (csontokon) | "feet" (talpnál korongban, radius) | "around" (henger palástján, radius + height)
--   "ring"   földre fektetett, forgó kör: radius, rot (rad/mp), pulse, zOff (jelenleg egyik effekt sem használja)
--   "attach" csontokra rögzített, pulzáló fény: bones, size, pulse
--   "orbit"  körbe keringő gömbök: count, radius, speed, height, bob, trail (kis burst-emitter definíció)
-----------------------------------------
local BODY  = {1, 3, 4, 5, 8, 22, 23, 24, 32, 33, 34, 41, 42, 51, 52}
local ARMS  = {22, 23, 24, 32, 33, 34}
local UPPER = {3, 4, 5, 22, 32}

EffectList = {
    { key = "nm_arany", name = "Nagymester Aura - Arany", price = 25000,
      desc = "Felszálló arany csillagszikrák és fényoszlopok.",
      emitters = {
        { mode = "attach", tex = "glow",  bones = {3, 4, 22, 32}, size = 0.55, color = {255, 200, 90}, alpha = 85, pulse = 3 },
        { tex = "spark", anchor = "body", rate = 14, life = {0.7, 1.3}, vz = {0.3, 0.8}, vxy = 0.1, size = {0.20, 0.04},
          color = {255, 220, 120}, alpha = 255, twinkle = 14, spin = {-3, 3} },
        { tex = "glow",  anchor = "feet", radius = 0.8, rate = 8, life = {1.2, 1.8}, vz = {0.6, 1.1}, size = {0.22, 0.05},
          color = {255, 180, 60}, alpha = 200 },
        { tex = "beam",  anchor = "feet", radius = 0.75, rate = 1.5, life = {0.7, 1.0}, vz = 0.5, size = {0.22, 0.16},
          stretch = 7, upright = true, color = {255, 210, 120}, alpha = 160 },
      } },

    { key = "nm_azur", name = "Nagymester Aura - Azúr", price = 25000,
      desc = "Villódzó kék szikrák a vérten, kék fényoszlopok.",
      emitters = {
        { mode = "attach", tex = "glow",  bones = {3, 4, 22, 32}, size = 0.55, color = {100, 190, 255}, alpha = 85, pulse = 4 },
        { tex = "spark", anchor = "body", rate = 18, life = {0.25, 0.45}, vxy = 0.9, vz = {-0.2, 0.4}, size = {0.16, 0.03},
          color = {200, 235, 255}, alpha = 255, spin = {-8, 8} },
        { tex = "glow",  anchor = "feet", radius = 0.8, rate = 9, life = {1.0, 1.6}, vz = {0.7, 1.2}, size = {0.20, 0.04},
          color = {80, 170, 255}, alpha = 200 },
        { tex = "beam",  anchor = "feet", radius = 0.75, rate = 1.5, life = {0.6, 0.9}, vz = 0.6, size = {0.2, 0.14},
          stretch = 7, upright = true, color = {130, 200, 255}, alpha = 160 },
      } },

    { key = "nm_lang", name = "Lángoló Vért", price = 20000,
      desc = "Lángnyelvek a vállakon és karokon, felszálló parázs.",
      emitters = {
        { tex = "flame", anchor = "body", bones = {3, 4, 22, 23, 32, 33}, rate = 34, life = {0.35, 0.6}, vz = {0.6, 1.0},
          vxy = 0.08, size = {0.32, 0.08}, upright = true, color = {255, 200, 80}, color2 = {255, 60, 10}, alpha = 220 },
        { tex = "spark", anchor = "body", rate = 10, life = {0.8, 1.4}, vz = {0.8, 1.6}, vxy = 0.3, size = {0.10, 0.02},
          color = {255, 170, 60}, alpha = 255, twinkle = 20 },
        { tex = "glow", anchor = "feet", radius = 0.5, rate = 6, life = {0.6, 0.9}, vz = {0.2, 0.4}, size = {0.6, 0.2},
          color = {255, 90, 20}, alpha = 90 },
      } },

    { key = "nm_arny", name = "Árnyvért", price = 20000,
      desc = "Örvénylő lila árnyékfüst a lábaknál, sötét szikrák.",
      emitters = {
        { tex = "smoke", anchor = "feet", radius = 0.6, rate = 12, life = {1.5, 2.2}, vz = {0.15, 0.35}, swirl = 0.6,
          size = {0.5, 1.1}, color = {120, 50, 190}, color2 = {25, 0, 45}, alpha = 150, spin = {-1, 1} },
        { mode = "attach", tex = "glow", bones = {4, 22, 32}, size = 0.5, color = {140, 60, 220}, alpha = 95, pulse = 2 },
        { tex = "spark", anchor = "body", rate = 14, life = {0.6, 1.0}, vz = {0.2, 0.6}, vxy = 0.15, size = {0.17, 0.03},
          color = {200, 120, 255}, alpha = 255, twinkle = 12, spin = {-3, 3} },
      } },

    { key = "nm_fagy", name = "Fagyvért", price = 20000,
      desc = "Hópelyhek kavarognak körülötted, hideg pára a földön.",
      emitters = {
        { tex = "flake", anchor = "around", radius = 0.7, height = {1.6, 2.1}, rate = 9, life = {2.0, 2.8},
          vz = {-0.45, -0.25}, swirl = 0.5, size = {0.16, 0.10}, color = {200, 240, 255}, alpha = 230, spin = {-2, 2} },
        { tex = "smoke", anchor = "feet", radius = 0.6, rate = 6, life = {1.6, 2.2}, vz = {0.05, 0.15},
          size = {0.6, 1.2}, color = {210, 240, 255}, alpha = 80, spin = {-0.5, 0.5} },
        { tex = "spark", anchor = "body", rate = 6, life = {0.5, 0.9}, vz = {0.1, 0.3}, size = {0.12, 0.03},
          color = {230, 250, 255}, alpha = 255, twinkle = 18 },
      } },

    { key = "nm_lelek", name = "Lélekvért", price = 18000,
      desc = "Három zöld lélekgömb kering körülötted, fénycsíkot húzva.",
      emitters = {
        { mode = "orbit", tex = "glow", count = 3, radius = 0.75, speed = 2.2, height = 1.1, bob = 0.35,
          size = 0.32, color = {120, 255, 160}, alpha = 230,
          trail = { tex = "glow", rate = 30, life = {0.4, 0.6}, size = {0.20, 0.02}, color = {90, 255, 140}, alpha = 160 } },
        { tex = "spark", anchor = "body", rate = 6, life = {0.6, 1.0}, vz = {0.2, 0.5}, size = {0.13, 0.03},
          color = {180, 255, 200}, alpha = 255, twinkle = 12 },
      } },

    { key = "nm_vihar", name = "Viharvért", price = 22000,
      desc = "Pattogó villámszikrák és felvillanó fényoszlopok.",
      emitters = {
        { tex = "spark", anchor = "body", rate = 45, life = {0.18, 0.32}, vxy = 1.6, vz = {-0.5, 0.5}, size = {0.22, 0.05},
          color = {235, 225, 255}, color2 = {140, 100, 255}, alpha = 255, spin = {-12, 12} },
        { tex = "beam", anchor = "feet", radius = 0.7, rate = 5, life = {0.15, 0.25}, size = {0.25, 0.25},
          stretch = 9, upright = true, color = {200, 180, 255}, alpha = 170 },
        { mode = "attach", tex = "glow", bones = {24, 34}, size = 0.35, color = {170, 140, 255}, alpha = 90, pulse = 18 },
      } },

    { key = "nm_ver", name = "Sárkányvér Vért", price = 22000,
      desc = "Bíbor köd és izzó vörös parázs.",
      emitters = {
        { tex = "smoke", anchor = "feet", radius = 0.6, rate = 7, life = {1.2, 1.8}, vz = {0.2, 0.4}, swirl = 0.3,
          size = {0.4, 0.9}, color = {200, 20, 30}, color2 = {60, 0, 0}, alpha = 110 },
        { tex = "spark", anchor = "body", rate = 12, life = {0.7, 1.2}, vz = {0.4, 0.9}, vxy = 0.12, size = {0.17, 0.04},
          color = {255, 90, 80}, alpha = 255, twinkle = 10, spin = {-3, 3} },
        { mode = "attach", tex = "glow", bones = {3, 4}, size = 0.65, color = {255, 40, 40}, alpha = 75, pulse = 2.5 },
      } },

    { key = "nm_jade", name = "Jáde Sárkány Aura", price = 24000,
      desc = "Spirálban felkúszó türkiz szikrák.",
      emitters = {
        { tex = "spark", anchor = "around", radius = 0.6, height = {0.0, 0.3}, rate = 20, life = {1.4, 1.9}, vz = {0.9, 1.2},
          swirl = 1.4, size = {0.16, 0.05}, color = {120, 255, 220}, color2 = {20, 180, 160}, alpha = 255, twinkle = 9 },
        { tex = "glow", anchor = "around", radius = 0.6, height = {0.0, 0.3}, rate = 10, life = {1.4, 1.9}, vz = {0.9, 1.2},
          swirl = 1.4, size = {0.22, 0.06}, color = {40, 220, 190}, alpha = 140 },
      } },

    { key = "nm_csillag", name = "Csillagvért", price = 30000,
      desc = "Kozmikus aura: keringő csillagok, rózsaszín-lila csillagpor.",
      emitters = {
        { mode = "orbit", tex = "spark", count = 4, radius = 0.85, speed = -1.6, height = 1.3, bob = 0.5,
          size = 0.35, color = {255, 230, 255}, alpha = 255,
          trail = { tex = "spark", rate = 18, life = {0.5, 0.8}, size = {0.14, 0.02}, color = {255, 150, 230}, alpha = 220,
                    spin = {-4, 4} } },
        { tex = "glow", anchor = "body", rate = 10, life = {0.8, 1.2}, vz = {0.2, 0.5}, size = {0.18, 0.03},
          color = {200, 140, 255}, alpha = 200 },
        { tex = "beam", anchor = "feet", radius = 0.8, rate = 1.2, life = {0.8, 1.1}, vz = 0.4, size = {0.2, 0.15},
          stretch = 7, upright = true, color = {255, 170, 240}, alpha = 150 },
      } },
}

EffectByKey = {}
for _, e in ipairs(EffectList) do EffectByKey[e.key] = e end

-- Skin menü [3] fülének listája: első elem a "nincs effekt"
EffectMenuList = { { key = "none", name = "Nincs effekt", price = 0, desc = "Az aktív effekt levétele." } }
for _, e in ipairs(EffectList) do EffectMenuList[#EffectMenuList + 1] = e end
