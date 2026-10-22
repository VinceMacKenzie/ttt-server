-----------------------------------------
-- TTT INTERIORS + SPAWNS - SZERVER
--
-- /int (kliens)        interior lista + teleport (X = elrejtés), /intback = vissza
-- /cspawn              játékos spawn ott, ahol állsz (a földre), abba az interiorba, ahol vagy
-- /cweapon [szint]     fegyver spawn: norm | epic | legendary (alap: norm), a fegyverek a config.lua táblázatból jönnek
-- /showspawns          spawn markerek + info panel mutatása / elrejtése (neked)
-- /delspawn [id]       törlés ID alapján, ID nélkül a legközelebbi (5 egységen belül)
-- /respawnweapons      a jelenlegi interior fegyvereinek újradobása
--
-- Mentés: spawns.json, interiorok szerint csoportosítva, soronként egy spawn.
-- Admin szint: element data "admin" >= 1.
-----------------------------------------
local MIN_ADMIN = 1
local GROUND_OFFSET = 1.0     -- a játékos középpontja ennyivel van a talaj felett (állva)
local PICKUP_HEIGHT = 0.6     -- a fegyver ennyivel lebeg a spawn pont felett
local DELETE_RADIUS = 5.0
local GUESS_RADIUS = 100.0    -- ennyin belüli, azonos ID-jú interiort tippelünk, ha nem /int-tel jöttél
local SPAWN_FILE = "spawns.json"
local HIDDEN_FILE = "hidden.json"
local TIERS = { "norm", "epic", "legendary" }

addEvent("tttInt:teleport", true)
addEvent("tttInt:back", true)
addEvent("tttInt:getHidden", true)
addEvent("tttInt:hide", true)
addEvent("tttInt:restoreAll", true)
addEvent("ttt:onRoundStart", false)

local byName = {}             -- [interior név] = INTERIORS elem
for _, e in ipairs(INTERIORS) do byName[e[2]] = e end

local data = {}               -- [interior név] = { interior = n, players = {}, weapons = {} }
local nextId = 1
local backPos = {}            -- [játékos] = {x, y, z, int, dim} az első /int teleport előtti hely
local currentName = {}        -- [játékos] = az utolsó /int-tel meglátogatott interior neve (megjegyezzük, hol vagy)
local viewers = {}            -- [játékos] = true, akinél be van kapcsolva a /showspawns
local lastCur = {}            -- [játékos] = utoljára a kliensnek küldött interior név
local pickupInfo = {}         -- [pickup elem] = { ws = spawn, d = interior adat }

local function round2(n) return math.floor(n * 100 + 0.5) / 100 end
local function isAdmin(p) return (tonumber(getElementData(p, "admin")) or 0) >= MIN_ADMIN end
local function say(p, text) outputChatBox("#00c3ff[Interior] #ffffff" .. text, p, 255, 255, 255, true) end

local function isTier(t)
    for _, v in ipairs(TIERS) do if v == t then return true end end
    return false
end

-----------------------------------------
-- Interior nevek
-----------------------------------------
local function nearestInteriorName(int, x, y, z, maxDist)
    local bestName, bestD
    for _, e in ipairs(INTERIORS) do
        if e[1] == int then
            local d = getDistanceBetweenPoints3D(x, y, z, e[3], e[4], e[5])
            if not bestD or d < bestD then bestName, bestD = e[2], d end
        end
    end
    if bestName and (not maxDist or bestD <= maxDist) then return bestName end
    return "Interior " .. int
end

-- Melyik interiorban vagy? (megjegyzett /int cél, különben a legközelebbi azonos ID-jú)
local function currentInterior(p)
    local int = getElementInterior(p)
    if int == 0 then return nil end
    local cn = currentName[p]
    if cn and byName[cn] and byName[cn][1] == int then return cn end
    local x, y, z = getElementPosition(p)
    return nearestInteriorName(int, x, y, z, GUESS_RADIUS)
end

local function ensureInterior(name, int)
    if not data[name] then data[name] = { interior = int, players = {}, weapons = {} } end
    return data[name]
end

-----------------------------------------
-- Mentés (olvasható JSON: interiorok szerint, soronként egy spawn)
-----------------------------------------
local function esc(s)
    return (s:gsub("\\", "\\\\"):gsub('"', '\\"'))
end

local function listBlock(key, items, isLast)
    local s = '    "' .. key .. '": ['
    if #items > 0 then s = s .. "\n" .. table.concat(items, ",\n") .. "\n    " end
    return s .. "]" .. (isLast and "" or ",")
end

local function saveSpawns()
    local names = {}
    for name, d in pairs(data) do
        if #d.players + #d.weapons > 0 then names[#names + 1] = name end
    end
    table.sort(names, function(a, b)
        if data[a].interior ~= data[b].interior then return data[a].interior < data[b].interior end
        return a < b
    end)

    local blocks = {}
    for _, name in ipairs(names) do
        local d = data[name]
        local pl, we = {}, {}
        for _, s in ipairs(d.players) do
            pl[#pl + 1] = string.format('      {"id": %d, "x": %.2f, "y": %.2f, "z": %.2f, "rot": %d}', s.id, s.x, s.y, s.z, s.rot or 0)
        end
        for _, s in ipairs(d.weapons) do
            we[#we + 1] = string.format('      {"id": %d, "x": %.2f, "y": %.2f, "z": %.2f, "tier": "%s"}', s.id, s.x, s.y, s.z, s.tier)
        end
        blocks[#blocks + 1] = table.concat({
            '  "' .. esc(name) .. '": {',
            '    "interior": ' .. d.interior .. ",",
            listBlock("players", pl, false),
            listBlock("weapons", we, true),
            "  }",
        }, "\n")
    end

    local text = #blocks > 0 and ("{\n" .. table.concat(blocks, ",\n") .. "\n}\n") or "{}\n"
    if fileExists(SPAWN_FILE) then fileDelete(SPAWN_FILE) end
    local f = fileCreate(SPAWN_FILE)
    if not f then
        outputDebugString("[Spawn] A spawns.json írása nem sikerült!", 1)
        return false
    end
    fileWrite(f, text)
    fileClose(f)
    return true
end

-----------------------------------------
-- Betöltés (a régi, lapos formátumot is átalakítja)
-----------------------------------------
local function loadSpawns()
    data, nextId = {}, 1
    if not fileExists(SPAWN_FILE) then return end
    local f = fileOpen(SPAWN_FILE, true)
    if not f then return end
    local size = fileGetSize(f)
    local content = size > 0 and fileRead(f, size) or nil
    fileClose(f)
    if not content or content:match("^%s*$") then return end

    local parsed
    if content:match("^%s*{") then parsed = fromJSON("[" .. content .. "]") else parsed = fromJSON(content) end
    if type(parsed) ~= "table" then
        -- hibás fájlt nem írunk felül: kimentjük, hogy ne vesszen el
        fileCopy(SPAWN_FILE, "spawns_broken.json", true)
        outputDebugString("[Spawn] A spawns.json nem olvasható! Lemásolva: spawns_broken.json", 1)
        return
    end

    local migrated = false
    local function addPlayer(d, s)
        local id = tonumber(s.id)
        if not id then id = nextId end
        if id >= nextId then nextId = id + 1 end
        table.insert(d.players, { id = id, x = s.x, y = s.y, z = s.z, rot = s.rot or 0 })
    end
    local function addWeapon(d, s)
        local id = tonumber(s.id)
        if not id then id = nextId end
        if id >= nextId then nextId = id + 1 end
        local tier = isTier(s.tier) and s.tier or "norm"
        table.insert(d.weapons, { id = id, x = s.x, y = s.y, z = s.z, tier = tier })
    end

    if parsed[1] ~= nil then
        -- RÉGI formátum: lapos lista { type, x, y, z, rot, int, ... }
        migrated = true
        for _, s in ipairs(parsed) do
            if type(s) == "table" and s.x and s.y and s.z then
                local int = tonumber(s.int) or 0
                local d = ensureInterior(nearestInteriorName(int, s.x, s.y, s.z), int)
                if s.type == "weapon" then addWeapon(d, s) else addPlayer(d, s) end
            end
        end
    else
        for name, d0 in pairs(parsed) do
            if type(d0) == "table" and type(name) == "string" then
                local int = tonumber(d0.interior) or (byName[name] and byName[name][1]) or 0
                local d = ensureInterior(name, int)
                for _, s in ipairs(d0.players or {}) do if s.x and s.y and s.z then addPlayer(d, s) end end
                for _, s in ipairs(d0.weapons or {}) do if s.x and s.y and s.z then addWeapon(d, s) end end
            end
        end
    end

    local np, nw = 0, 0
    for _, d in pairs(data) do np, nw = np + #d.players, nw + #d.weapons end
    outputDebugString("[Spawn] Betöltve: " .. np .. " játékos spawn, " .. nw .. " fegyver spawn" .. (migrated and " (régi formátum átalakítva)" or ""))
    if migrated then saveSpawns() end
end

-----------------------------------------
-- Fegyver pickupok
-----------------------------------------
local function pickWeapon(tier)
    local list = WEAPON_TIERS and WEAPON_TIERS[tier]
    if type(list) ~= "table" or #list == 0 then return nil end
    local entry = list[math.random(#list)]
    local id, ammo = entry, nil
    if type(entry) == "table" then id, ammo = entry[1], entry[2] end
    if not tonumber(id) or not getWeaponNameFromID(id) then return nil end
    return id, ammo or (TIER_AMMO and TIER_AMMO[tier]) or 60
end

local function removePickup(ws)
    if isTimer(ws._timer) then killTimer(ws._timer) end
    if isElement(ws._pickup) then
        pickupInfo[ws._pickup] = nil
        destroyElement(ws._pickup)
    end
    ws._pickup, ws._timer = nil, nil
end

local function spawnPickup(d, ws)
    removePickup(ws)
    local id, ammo = pickWeapon(ws.tier)
    if not id then
        outputDebugString("[Spawn] A(z) '" .. tostring(ws.tier) .. "' szinthez nincs érvényes fegyver a config.lua-ban!", 2)
        return false
    end
    local pk = createPickup(ws.x, ws.y, ws.z + PICKUP_HEIGHT, 2, id, 3600000, ammo)
    if not pk then return false end
    setElementInterior(pk, d.interior)
    ws._pickup = pk
    pickupInfo[pk] = { ws = ws, d = d }
    return true
end

-- Egy interior összes fegyver spawnjának újradobása (exportálva is)
function spawnWeapons(interiorName)
    local d = data[interiorName]
    if not d then return false end
    for _, ws in ipairs(d.weapons) do spawnPickup(d, ws) end
    return true
end

local function spawnAllWeapons()
    for _, d in pairs(data) do
        for _, ws in ipairs(d.weapons) do spawnPickup(d, ws) end
    end
end

addEventHandler("onPickupUse", root, function()
    local info = pickupInfo[source]
    if not info then return end
    local pk, ws, d = source, info.ws, info.d
    -- a fegyvert az engine adja át, mi csak utána vesszük el a pickupot (és ha kell, újra dobjuk)
    setTimer(function()
        if ws._deleted or ws._pickup ~= pk then return end
        removePickup(ws)
        if (PICKUP_RESPAWN_MS or 0) > 0 then
            ws._timer = setTimer(function()
                ws._timer = nil
                if not ws._deleted then spawnPickup(d, ws) end
            end, PICKUP_RESPAWN_MS, 1)
        end
    end, 100, 1)
end)

addEventHandler("ttt:onRoundStart", root, function()
    if REROLL_ON_ROUND_START then spawnAllWeapons() end
end)

-- Véletlen játékos spawn egy interiorból (exportálva): x, y, z, rot, interior
function getRandomSpawn(interiorName)
    local d = data[interiorName]
    if not d or #d.players == 0 then return false end
    local s = d.players[math.random(#d.players)]
    return s.x, s.y, s.z + GROUND_OFFSET, s.rot, d.interior
end

-----------------------------------------
-- Elrejtett interiorok (X gomb) + állapot a panelnek
-----------------------------------------
local hidden = {}   -- [kulcs] = true, kulcs: "interiorID|név"

local function keyOf(e) return e[1] .. "|" .. e[2] end

local function loadHidden()
    hidden = {}
    if not fileExists(HIDDEN_FILE) then return end
    local f = fileOpen(HIDDEN_FILE, true)
    if not f then return end
    local size = fileGetSize(f)
    local content = size > 0 and fileRead(f, size) or nil
    fileClose(f)
    local list = content and fromJSON(content)
    if type(list) == "table" then
        for _, k in ipairs(list) do hidden[k] = true end
    end
end

local function saveHidden()
    local list = {}
    for k in pairs(hidden) do table.insert(list, k) end
    table.sort(list)
    if fileExists(HIDDEN_FILE) then fileDelete(HIDDEN_FILE) end
    local f = fileCreate(HIDDEN_FILE)
    if not f then return outputDebugString("[Interior] A hidden.json írása nem sikerült!", 1) end
    fileWrite(f, toJSON(list, true))
    fileClose(f)
end

local function hiddenIndices()
    local out = {}
    for i, e in ipairs(INTERIORS) do
        if hidden[keyOf(e)] then table.insert(out, i) end
    end
    return out
end

-- hány spawn van interioronként (a panel ezt írja ki a sorok mellé)
local function spawnCounts()
    local out = {}
    for name, d in pairs(data) do
        if #d.players + #d.weapons > 0 then out[name] = { players = #d.players, weapons = #d.weapons } end
    end
    return out
end

local function sendState(p)
    triggerClientEvent(p, "tttInt:hidden", p, hiddenIndices(), spawnCounts())
end

-----------------------------------------
-- Szinkron a markerekhez
-----------------------------------------
local function flatList()
    local list = {}
    for name, d in pairs(data) do
        for _, s in ipairs(d.players) do
            list[#list + 1] = { id = s.id, type = "player", interior = name, int = d.interior, x = s.x, y = s.y, z = s.z, rot = s.rot }
        end
        for _, s in ipairs(d.weapons) do
            list[#list + 1] = { id = s.id, type = "weapon", interior = name, int = d.interior, x = s.x, y = s.y, z = s.z, tier = s.tier }
        end
    end
    return list
end

local function syncTo(p)
    if viewers[p] then
        local cur = currentInterior(p)
        lastCur[p] = cur or false
        triggerClientEvent(p, "tttSpawns:sync", p, { list = flatList(), current = cur or false })
    else
        triggerClientEvent(p, "tttSpawns:sync", p, false)
    end
end

local function syncViewers()
    for p in pairs(viewers) do
        if isElement(p) then syncTo(p) else viewers[p] = nil end
    end
end

-- az info panelhez: ha máshova mész, frissítjük a kijelzett interior nevet
setTimer(function()
    for p in pairs(viewers) do
        if isElement(p) then
            local cur = currentInterior(p) or false
            if lastCur[p] ~= cur then
                lastCur[p] = cur
                triggerClientEvent(p, "tttSpawns:current", p, cur)
            end
        else
            viewers[p] = nil
        end
    end
end, 1500, 0)

addEventHandler("onResourceStart", resourceRoot, function()
    math.randomseed(getTickCount())
    loadHidden()
    loadSpawns()
    spawnAllWeapons()
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for _, d in pairs(data) do
        for _, ws in ipairs(d.weapons) do removePickup(ws) end
    end
end)

addEventHandler("onPlayerQuit", root, function()
    backPos[source], currentName[source], viewers[source], lastCur[source] = nil, nil, nil, nil
end)

-----------------------------------------
-- /int teleport
-----------------------------------------
addEventHandler("tttInt:teleport", root, function(idx)
    local p = client
    if not p or not isElement(p) then return end
    if not isAdmin(p) then return say(p, "Ehhez admin jog kell!") end

    local e = INTERIORS[tonumber(idx) or -1]
    if not e then return end
    local int, name = e[1], e[2]
    local x, y, z, rot = e[3], e[4], e[5], nil
    local extra = ""

    -- ha az interiorban már vannak mentett spawnok, véletlenszerűen az egyikre dobjuk
    local d = data[name]
    if d and #d.players > 0 then
        local s = d.players[math.random(#d.players)]
        x, y, z, rot = s.x, s.y, s.z + GROUND_OFFSET, s.rot
        extra = " - véletlen spawn: #ffd75e#" .. s.id .. "#ffffff"
    end

    -- az eredeti helyet csak egyszer jegyezzük meg, így több ugrás után is vissza lehet jönni
    if not backPos[p] then
        local px, py, pz = getElementPosition(p)
        backPos[p] = { px, py, pz, getElementInterior(p), getElementDimension(p) }
    end

    if isPedInVehicle(p) then removePedFromVehicle(p) end
    setElementInterior(p, int)
    setElementPosition(p, x, y, z)
    if rot then setElementRotation(p, 0, 0, rot) end
    setCameraInterior(p, int)
    currentName[p] = name       -- megjegyezzük, hol vagy (a /cspawn ide menti a spawnt)

    say(p, "Teleportálva: #ffd75e" .. name .. " #ffffff(interior ID " .. int .. ")" .. extra .. ". Vissza: #00c3ff/intback")
    if viewers[p] then syncTo(p) end
end)

local function goBack(p)
    local b = backPos[p]
    if not b then return say(p, "Nincs hova visszamenni.") end
    if isPedInVehicle(p) then removePedFromVehicle(p) end
    setElementInterior(p, b[4])
    setElementDimension(p, b[5])
    setElementPosition(p, b[1], b[2], b[3])
    setCameraInterior(p, b[4])
    backPos[p], currentName[p] = nil, nil
    say(p, "Visszatérés az eredeti helyre.")
    if viewers[p] then syncTo(p) end
end

addEventHandler("tttInt:back", root, function()
    local p = client
    if p and isAdmin(p) then goBack(p) end
end)

addCommandHandler("intback", function(p)
    if p and getElementType(p) == "player" and isAdmin(p) then goBack(p) end
end)

addEventHandler("tttInt:getHidden", root, function()
    local p = client
    if p and isAdmin(p) then sendState(p) end
end)

addEventHandler("tttInt:hide", root, function(idx)
    local p = client
    if not p or not isAdmin(p) then return end
    local e = INTERIORS[tonumber(idx) or -1]
    if not e then return end
    hidden[keyOf(e)] = true
    saveHidden()
    say(p, "Kivéve a listából: #ffd75e" .. e[2])
end)

addEventHandler("tttInt:restoreAll", root, function()
    local p = client
    if not p or not isAdmin(p) then return end
    hidden = {}
    saveHidden()
    sendState(p)
    say(p, "Az összes elrejtett interior visszakerült a listába.")
end)

-----------------------------------------
-- Spawn parancsok
-----------------------------------------
local function createSpawn(p, kind, tier)
    if isPedInVehicle(p) then return say(p, "Szállj ki a járműből!") end
    local int = getElementInterior(p)
    local name = currentInterior(p)
    if not name then return say(p, "A normál világban (interior 0) nem lehet spawnt lerakni, menj egy interiorba (/int).") end

    local x, y, z = getElementPosition(p)
    local _, _, rz = getElementRotation(p)
    local d = ensureInterior(name, int)
    local s = { id = nextId, x = round2(x), y = round2(y), z = round2(z - GROUND_OFFSET) }
    nextId = nextId + 1

    if kind == "player" then
        s.rot = math.floor(rz)
        table.insert(d.players, s)
    else
        s.tier = tier
        table.insert(d.weapons, s)
        spawnPickup(d, s)               -- rögtön megjelenik egy fegyver
    end
    saveSpawns()

    viewers[p] = true                   -- a létrehozó rögtön látja a markert
    syncViewers()

    local what = kind == "player" and "Játékos spawn" or ("Fegyver spawn (" .. tier .. ")")
    say(p, what .. " lerakva: #ffd75e#" .. s.id .. " #ffffff- " .. name .. " (" .. s.x .. ", " .. s.y .. ", " .. s.z .. ")")
end

addCommandHandler("cspawn", function(p)
    if not p or getElementType(p) ~= "player" then return end
    if not isAdmin(p) then return say(p, "Ehhez admin jog kell!") end
    createSpawn(p, "player")
end)

addCommandHandler("cweapon", function(p, cmd, tier)
    if not p or getElementType(p) ~= "player" then return end
    if not isAdmin(p) then return say(p, "Ehhez admin jog kell!") end
    tier = tier and tier:lower() or "norm"
    if not isTier(tier) then return say(p, "Használat: /cweapon [norm|epic|legendary]") end
    createSpawn(p, "weapon", tier)
end)

addCommandHandler("showspawns", function(p)
    if not p or getElementType(p) ~= "player" then return end
    if not isAdmin(p) then return say(p, "Ehhez admin jog kell!") end
    viewers[p] = not viewers[p] or nil
    syncTo(p)
    say(p, viewers[p] and "Spawnok mutatva." or "Spawnok elrejtve.")
end)

addCommandHandler("delspawn", function(p, cmd, idArg)
    if not p or getElementType(p) ~= "player" then return end
    if not isAdmin(p) then return say(p, "Ehhez admin jog kell!") end

    local tList, tIdx, tSpawn, tKind
    if idArg then
        local id = tonumber(idArg)
        if not id then return say(p, "Használat: /delspawn [id]") end
        for _, d in pairs(data) do
            for _, kind in ipairs({ "players", "weapons" }) do
                for i, s in ipairs(d[kind]) do
                    if s.id == id then tList, tIdx, tSpawn, tKind = d[kind], i, s, kind end
                end
            end
        end
        if not tSpawn then return say(p, "Nincs ilyen ID: #" .. id) end
    else
        local px, py, pz = getElementPosition(p)
        local int = getElementInterior(p)
        local best = DELETE_RADIUS
        for _, d in pairs(data) do
            if d.interior == int then
                for _, kind in ipairs({ "players", "weapons" }) do
                    for i, s in ipairs(d[kind]) do
                        local dist = getDistanceBetweenPoints3D(px, py, pz, s.x, s.y, s.z)
                        if dist <= best then best, tList, tIdx, tSpawn, tKind = dist, d[kind], i, s, kind end
                    end
                end
            end
        end
        if not tSpawn then return say(p, "Nincs spawn " .. DELETE_RADIUS .. " egységen belül. (/delspawn [id], az ID a marker felett látszik)") end
    end

    if tKind == "weapons" then
        tSpawn._deleted = true
        removePickup(tSpawn)
    end
    table.remove(tList, tIdx)
    saveSpawns()
    syncViewers()
    say(p, "Törölve: #ffd75e#" .. tSpawn.id .. " #ffffff(" .. (tKind == "players" and "játékos" or "fegyver") .. " spawn)")
end)

addCommandHandler("respawnweapons", function(p)
    if not p or getElementType(p) ~= "player" then return end
    if not isAdmin(p) then return say(p, "Ehhez admin jog kell!") end
    local name = currentInterior(p)
    if not name or not data[name] or #data[name].weapons == 0 then
        return say(p, "Ebben az interiorban nincs fegyver spawn.")
    end
    spawnWeapons(name)
    say(p, "Fegyverek újradobva: #ffd75e" .. name .. " #ffffff(" .. #data[name].weapons .. " db)")
end)
