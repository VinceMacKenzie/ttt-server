-----------------------------------------
-- TTT SPAWNS - SZERVER
-- /cspawn            játékos spawn létrehozása ott, ahol állsz (a földre, az aktuális interiorban)
-- /cweapon [fegyver] fegyver spawn létrehozása (fegyver ID vagy név, pl. 30 / ak-47; üresen: tetszőleges)
-- /showspawns        a spawn markerek mutatása / elrejtése (neked)
-- /delspawn [id]     törlés ID alapján, ID nélkül a hozzád legközelebbi (5 egységen belül)
-- Mentés: spawns.json a resource mappájában. Admin szint: element data "admin" >= 1.
-----------------------------------------
local SPAWN_FILE = "spawns.json"
local MIN_ADMIN = 1
local GROUND_OFFSET = 1.0    -- a játékos középpontja ennyivel van a talaj felett (állva)
local DELETE_RADIUS = 5.0

local spawns = {}            -- { id, type = "player"/"weapon", x, y, z, rot, int, dim, weapon }
local nextId = 1
local viewers = {}           -- [játékos] = true, akinél be van kapcsolva a marker mutatás

local function round2(n) return math.floor(n * 100 + 0.5) / 100 end

local function isAdmin(p)
    return (tonumber(getElementData(p, "admin")) or 0) >= MIN_ADMIN
end

local function say(p, text)
    outputChatBox("#00c3ff[Spawn] #ffffff" .. text, p, 255, 255, 255, true)
end

-----------------------------------------
-- Mentés / betöltés
-----------------------------------------
local function saveSpawns()
    if fileExists(SPAWN_FILE) then fileDelete(SPAWN_FILE) end
    local f = fileCreate(SPAWN_FILE)
    if not f then
        outputDebugString("[Spawn] A spawns.json írása nem sikerült!", 1)
        return false
    end
    fileWrite(f, toJSON(spawns, true))
    fileClose(f)
    return true
end

local function loadSpawns()
    spawns, nextId = {}, 1
    if not fileExists(SPAWN_FILE) then return end
    local f = fileOpen(SPAWN_FILE, true)
    if not f then return end
    local size = fileGetSize(f)
    local content = size > 0 and fileRead(f, size) or nil
    fileClose(f)
    local list = content and fromJSON(content)
    if type(list) ~= "table" then return end
    for _, s in ipairs(list) do
        if type(s) == "table" and s.x and s.y and s.z then
            s.int, s.dim = s.int or 0, s.dim or 0
            table.insert(spawns, s)
            if (s.id or 0) >= nextId then nextId = s.id + 1 end
        end
    end
    outputDebugString("[Spawn] Betöltve: " .. #spawns .. " spawn")
end

addEventHandler("onResourceStart", resourceRoot, loadSpawns)

-----------------------------------------
-- Szinkron a kliensekkel (csak a markereket bekapcsolt adminok kapják)
-----------------------------------------
local function syncTo(p)
    if viewers[p] then
        triggerClientEvent(p, "tttSpawns:sync", p, spawns)
    else
        triggerClientEvent(p, "tttSpawns:sync", p, false)
    end
end

local function syncViewers()
    for p in pairs(viewers) do
        if isElement(p) then syncTo(p) else viewers[p] = nil end
    end
end

addEventHandler("onPlayerQuit", root, function() viewers[source] = nil end)

-----------------------------------------
-- Létrehozás
-----------------------------------------
local function createSpawn(p, kind, weapon)
    if isPedInVehicle(p) then return say(p, "Szállj ki a járműből!") end
    local x, y, z = getElementPosition(p)
    local _, _, rz = getElementRotation(p)
    local s = {
        id = nextId, type = kind,
        x = round2(x), y = round2(y), z = round2(z - GROUND_OFFSET),
        rot = math.floor(rz),
        int = getElementInterior(p), dim = getElementDimension(p),
        weapon = weapon,
    }
    nextId = nextId + 1
    table.insert(spawns, s)
    saveSpawns()

    viewers[p] = true        -- a létrehozó rögtön látja a markert
    syncViewers()

    local what = kind == "player" and "Játékos spawn" or "Fegyver spawn"
    if weapon then what = what .. " (" .. getWeaponNameFromID(weapon) .. ")" end
    say(p, what .. " lerakva: #ffd75e#" .. s.id .. " #ffffff- interior " .. s.int .. ", " .. s.x .. ", " .. s.y .. ", " .. s.z)
end

addCommandHandler("cspawn", function(p)
    if not p or getElementType(p) ~= "player" then return end
    if not isAdmin(p) then return say(p, "Ehhez admin jog kell!") end
    createSpawn(p, "player")
end)

addCommandHandler("cweapon", function(p, cmd, ...)
    if not p or getElementType(p) ~= "player" then return end
    if not isAdmin(p) then return say(p, "Ehhez admin jog kell!") end
    local arg = table.concat({ ... }, " ")
    local weapon = nil
    if arg ~= "" then
        weapon = tonumber(arg) or getWeaponIDFromName(arg)
        if not weapon or not getWeaponNameFromID(weapon) then
            return say(p, "Ismeretlen fegyver! Használat: /cweapon [fegyver ID vagy név]")
        end
    end
    createSpawn(p, "weapon", weapon)
end)

-----------------------------------------
-- Mutatás / törlés
-----------------------------------------
addCommandHandler("showspawns", function(p)
    if not p or getElementType(p) ~= "player" then return end
    if not isAdmin(p) then return say(p, "Ehhez admin jog kell!") end
    viewers[p] = not viewers[p] or nil
    syncTo(p)
    local players, weapons = 0, 0
    for _, s in ipairs(spawns) do
        if s.type == "player" then players = players + 1 else weapons = weapons + 1 end
    end
    say(p, viewers[p] and ("Spawnok mutatva (játékos: " .. players .. ", fegyver: " .. weapons .. ").") or "Spawnok elrejtve.")
end)

addCommandHandler("delspawn", function(p, cmd, idArg)
    if not p or getElementType(p) ~= "player" then return end
    if not isAdmin(p) then return say(p, "Ehhez admin jog kell!") end

    local target, targetIdx = nil, nil
    if idArg then
        local id = tonumber(idArg)
        if not id then return say(p, "Használat: /delspawn [id]") end
        for i, s in ipairs(spawns) do
            if s.id == id then target, targetIdx = s, i break end
        end
        if not target then return say(p, "Nincs ilyen ID: #" .. id) end
    else
        local px, py, pz = getElementPosition(p)
        local int, dim = getElementInterior(p), getElementDimension(p)
        local best = DELETE_RADIUS
        for i, s in ipairs(spawns) do
            if s.int == int and s.dim == dim then
                local d = getDistanceBetweenPoints3D(px, py, pz, s.x, s.y, s.z)
                if d <= best then best, target, targetIdx = d, s, i end
            end
        end
        if not target then return say(p, "Nincs spawn " .. DELETE_RADIUS .. " egységen belül. (/delspawn [id], az ID a marker felett látszik)") end
    end

    table.remove(spawns, targetIdx)
    saveSpawns()
    syncViewers()
    say(p, "Törölve: #ffd75e#" .. target.id .. " #ffffff(" .. (target.type == "player" and "játékos" or "fegyver") .. " spawn)")
end)
