--[[
    ttt_minecraft_b5 for MTA:SA - configuration (shared)
    Converted from the Garry's Mod TTT map "ttt_minecraft_b5" (by Finniespin).
    Scale: 1 Minecraft block (32 Source units) = 1 metre.
]]

Config = {
    -- Where the map's origin (Source 0,0,0) is placed in the GTA world, in metres.
    -- Default: high above San Andreas so nothing of the GTA world interferes.
    OFFSET = { 0, 0, 600 },
    DIMENSION = 0,
    INTERIOR = 0,

    -- Round flow -------------------------------------------------------------
    -- MODE:
    --   "auto"       : if the "ttt-core" resource is running -> "ttt-core" mode, otherwise "standalone"
    --   "ttt-core"   : rounds follow ttt-core's events (ttt:onRoundStart / ttt:onRoundEnd). On every round
    --                  start the map is cleaned up and every player with a TTT role is teleported onto the map.
    --   "standalone" : the map resets itself on start and runs one endless "round" (testing / non-TTT servers).
    --                  Use /mcmap to get onto the map.
    MODE = "auto",
    TTT_CORE_RESOURCE = "ttt-core",
    TTT_EVENTS = { start = "ttt:onRoundStart", finish = "ttt:onRoundEnd" },
    TELEPORT_ON_ROUND_START = true,     -- put the round's players onto the map's spawn points
    -- Generic events / exports for other gamemodes (exports.ttt_minecraft_b5:roundPreparation() etc.)
    ROUND_EVENTS = {
        prep  = "onTTTRoundPreparation",   -- triggerEvent(name, root)  -> map cleanup + RoundPreparation outputs
        start = "onTTTRoundStart",         -- triggerEvent(name, root)  -> RoundStart outputs
        finish = "onTTTRoundEnd",          -- triggerEvent(name, root, result) -> RoundEnd outputs
    },
    -- Admin parancsok (/mcmap, /mcreset, /mcdia) CSAK adminoknak: "admin" element data >= ADMIN_LEVEL
    -- (ugyanaz, mint a ttt-admin / ttt-int / ttt-replay rendszere), az ACL csoportok tagjai, vagy a konzol.
    ADMIN_LEVEL = 1,
    ADMIN_ACL_GROUPS = { "Admin", "Console" },
    -- A kliens nem írhatja át ezeket az element datákat (csalás ellen: pl. saját "admin" szint vagy "tttRole"
    -- beállítása a kliensen). Csak a szerver resource-ai módosíthatják őket (server/security.lua).
    PROTECT_ELEMENT_DATA = true,
    PROTECTED_DATA = { admin = true, tttRole = true, money = true, charID = true, accName = true,
                       adminVision = true, chatCss = true, joinTime = true, isCorpse = true, npcName = true,
                       role = true, ["ttt.role"] = true },
    PROTECTED_DATA_PREFIXES = { "mc.", "corpse:" },
    LOBBY_SPAWN = { 1948.875, -1713.143, 13.547 },   -- ttt-core's spawn: players on the map go here if the map stops

    -- Controls ---------------------------------------------------------------
    USE_KEY = "f",                 -- +use: buttons, doors, carrying blocks, traitor buttons (E switches weapons)
    TRAITOR_BUTTON_RANGE = 1024,   -- Source units (TTT default)
    USE_RANGE = 3.0,               -- metres, how far you can "use" things

    -- Visuals ----------------------------------------------------------------
    NO_COLOR_FILTER = true,        -- switch off GTA's weather colour filter on the map (it made it overbright)
    MAP_BRIGHTNESS = 0.92,         -- 1.0 = exactly the GMod lightmaps
    WORLD_SHADER = true,           -- client/world.fx: texture x baked lightmap + the map's fog, exactly like GMod
    MAP_FOG = true,                -- use the map's env_fog_controller (fog 62m..109m, like in GMod)
    FAR_CLIP = 400,                -- metres; the whole map must be inside the view distance
    ZONE_CULLING = true,           -- like Source's PVS: only the map area the camera is in is drawn (sealed
                                   -- rooms such as the win room no longer show as a black box from outside)
    DECAL_PULL = 0.001,            -- ore overlays / rails are drawn this fraction closer (no z-fighting)
    LOCK_TIME = true,              -- keep midday + clear weather while on the map (lightmaps are baked)
    TIME = { 12, 0 },
    WEATHER = 1,
    TEXTURE_FILTERING = true,      -- mip-mapping in the distance (the texels stay crisp up close)
    LOD_DISTANCE = 300,
    VISIBLE_IN_ALL_DIMENSIONS = true,  -- map geometry also visible in other dimensions (ttt-replay viewers)
    WATER_COLOR = { 23, 90, 234, 0 },  -- GTA water used for swimming; alpha 0 = only the map's water texture is visible
    TORCH_GLOW = true,             -- small coronas on the env_fire torch flames

    -- Gameplay ---------------------------------------------------------------
    SPAWN_WEAPONS = true,          -- spawn the map's weapon entities as pickups (see bridge.lua)
    -- Legfeljebb 2 fegyver: 1 fő fegyver (shotgun / SMG / gépkarabély / puska / nehézfegyver) + 1 pisztoly.
    -- Ha más forrásból (ttt-shop, admin) kapsz fegyvert egy olyan kategóriában, amiben már van, a régi a lábad elé
    -- esik a lőszerével. A kés, az ütőfegyverek és a gránátok nem számítanak.
    -- A pálya fegyvereinél a cserét meg kell erősíteni: "[F] Felvétel" (a kézben lévő a földre kerül a lőszerével).
    WEAPON_LIMIT = true,
    DROP_KEY = "q",                -- a kézben lévő fegyver eldobása (a GTA Q-s fegyverváltása helyett); nil = kikapcsolva
    WEAPON_DROP_PROTECT_MS = 1500, -- az eldobott fegyvert ennyi ideig nem veszed fel újra (ne cserélgessen magától)
    REMOVE_STATIC_MINECARTS = true,   -- a pályán álló (fizikai) minecartok kivéve; a traitor TNT-s kocsija marad
    -- A kész gyémántblokk a világítótoronyba -> a pálya mindenkit átteleportál az "end"-be (győzelmi szoba):
    --   "end_teleport" : ekkor fut le a ttt-core innocent win-je ("Az Innocentek győztek!", kör vége)
    --   "immediate"    : már a blokk berakásakor (mint GModban)
    --   false          : a pálya nem dönt győztesről, csak a ttt-core
    MAP_WIN = "end_teleport",
    MAP_WIN_FALLBACK_MS = 15000,   -- ha senkit nem teleportált át, ennyi idő után akkor is innocent win
    GOTOGOLD_ADMIN_LEVEL = 2,      -- /gotogold: Főadmin (2) és felette
    GOTODIA_ADMIN_LEVEL = 3,       -- /gotodia: Fejlesztő (3) és felette
    SPAWN_AMMO = false,            -- the map's ammo boxes (GTA has no ammo pickups: they showed up as guns)
    WEAPON_SPAWN_CHANCE = 0.5,     -- each round this share of the map's weapon spots gets a weapon (random);
                                   -- traitor items and weapons spawned by map logic always appear
    PICKUP_HEIGHT = 0.5,           -- metres above the floor
    -- Hány találat kell a vasérc- és gyémántérc-blokkokhoz fegyvertípusonként (a többi törhető elemnél a
    -- BREAK_DAMAGE / MELEE_DAMAGE sebzés számít). melee = ököl / kés / ütőfegyver.
    BREAK_HITS = {
        iron    = { pistol = 10, shotgun = 3, assault = 5,  smg = 7,  rifle = 3, melee = 5,  other = 5 },
        diamond = { pistol = 20, shotgun = 6, assault = 10, smg = 14, rifle = 6, melee = 10, other = 10 },
    },
    -- a pálya törhető blokkjai textúra szerint (MINECRAFT/IRON, MINECRAFT/DIAMOND)
    BREAK_KIND_MODELS = {
        e122 = "iron", e123 = "iron", e124 = "iron", e125 = "iron", e126 = "iron", e127 = "iron", e128 = "iron",
        e129 = "iron", e278 = "iron", e279 = "iron", e280 = "iron", e281 = "iron", e284 = "iron", e285 = "iron",
        e323 = "iron", e324 = "iron", e342 = "iron", e343 = "iron", e344 = "iron", e345 = "iron",
        e277 = "diamond",
    },
    MELEE_DAMAGE = 25,             -- fist / melee damage vs breakable blocks (= the GMod crowbar)
    -- damage of one shot vs breakable blocks, like the GMod TTT weapons (GTA counts a shotgun shot as one pellet)
    BREAK_DAMAGE = { [22] = 25, [23] = 25, [24] = 37, [25] = 88, [26] = 88, [27] = 60, [28] = 12, [29] = 18,
                     [30] = 23, [31] = 23, [32] = 12, [33] = 50, [34] = 50, [38] = 23 },
    FALL_KILL_MARGIN = 12,         -- metres: a player who was ON the map and falls this far below its lowest
                                   -- point dies (players elsewhere in the GTA world are never touched)
    -- the map's messages in Hungarian (and fitted to GTA: no crowbar, the traitor room items are GTA weapons)
    TEXT_REPLACE = {
        ["The traitor room is now available!"] = "A traitor szoba mostantól elérhető!",
        ["Traitor tester is now available!"] = "A traitor tester mostantól használható!",
        ["Crowbar the iron ore!"] = "Lődd vagy üsd szét a vasércet!",
        ["You've got a Decoy!"] = "Könnygázt kaptál!",
        ["You've got a Radio!"] = "Gránátot kaptál!",
        ["You've got a Knife!"] = "Kést kaptál!",
        ["You've got a Teleporter!"] = "Golyóálló mellényt kaptál!",
        ["You've got a Silenced Pistol!"] = "Hangtompítós pisztolyt kaptál!",
        ["You've got a Flaregun!"] = "Molotov-koktélokat kaptál!",
        ["You are playing in either sandbox mode or other a gamemode!"] = "Nem TTT módban játszol!",
        ["Some events will not trigger!"] = "Néhány pályaesemény nem fog működni!",
    },
    -- the map's messages that are never shown (welcome text, credits)
    TEXT_HIDE = {
        ["Welcome to ttt_minecraft. Enjoy you play."] = true,
        ["Made by Finniespin. Visit http://conjointgaming.com/"] = true,
    },
    TEXT_REPEAT_MS = 20000,        -- the same map message is shown to a player at most once in this time
    SOUND_EFFECTS = true,          -- pick up / drop / furnace / chest / button sounds (sounds/sfx)
    CREDIT_PRICE = 1000,           -- TTT credits are money on this server: 1 credit = $1000 (traitor item room,
                                   -- same price level as the ttt-shop; purchases are logged like ttt-shop's)
    CARRY_MAX_SIZE = 24,           -- Source units: physics boxes up to this size can be carried (blocks yes,
                                   -- minecarts no - like heavy props in GMod)
    DROP_ASSIST_RANGE = 2.5,       -- metres: a carried block dropped near the furnace / crafting table / ... goes in
    SETTLE_MAX_DROP = 6.0,         -- metres a released block may fall (a far client may not have the collision)
    USE_HINTS = true,              -- "[F] ..." hint on usable buttons, doors, levers and blocks
    JUMP_ASSIST = true,            -- jumping in front of a 1 block step lifts the player onto it (like in GMod),
                                   -- swimming against a low bank climbs out of the water
    EDGE_FIX = true,               -- keep the player from hanging on / being lifted by 1 block high edges
    LADDER_SPEED = 3.0,            -- m/s climbing speed on Minecraft ladders

    -- Technical --------------------------------------------------------------
    PLACEHOLDER_MODEL = 1337,      -- server-side placeholder for objects (clients swap in the real model)
    MODEL_PARENT = 1337,           -- parent model for engineRequestModel
    DEBUG = false,                 -- print entity I/O to the server console
}
