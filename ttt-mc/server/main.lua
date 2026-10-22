--[[
    Round flow (TTT: map cleanup each round), client requests (+use, traitor buttons, damage),
    exports for the gamemode.
]]

Rounds = { state = "idle", ready = false, spawnWeapons = false, worldWater = {} }

local function templatedNames()
    local set = {}
    for _, def in ipairs(MAP_ENTS) do
        if def.classname == "point_template" then
            local keep = bitAnd(tonumber(def.kv.spawnflags) or 0, 1) ~= 0   -- "don't remove template entities"
            if not keep then
                for k, v in pairs(def.kv) do
                    if k:lower():match("^template%d+$") and v ~= "" then set[v:lower()] = true end
                end
            end
        end
    end
    return set
end

local function resolveParent(inst)
    local pn = inst.kv.parentname
    if pn and pn ~= "" then
        local p = Engine.findByName(pn)[1]
        if p then Engine.setParent(inst, p) end
    end
end

local function activate(inst)
    local c = Classes[inst.cls]
    if c and c.activate then
        local ok, err = pcall(c.activate, inst)
        if not ok then outputDebugString("[mc] activate error " .. inst.cls .. ": " .. tostring(err), 1) end
    end
end

function Engine.spawnTemplate(def)
    local inst = Engine.create(def, { template = true })
    resolveParent(inst)
    activate(inst)
    return inst
end

-- equivalent of TTT's game.CleanUpMap(): destroy everything and respawn all map entities
function Rounds.reset()
    Engine.generation = Engine.generation + 1
    Bridge.pendingWin = nil
    Engine.queue = {}
    for _, inst in ipairs(Engine.all()) do
        local c = Classes[inst.cls]
        if c and c.kill then pcall(c.kill, inst) end
        Engine.destroyElements(inst)
        inst.alive = false
    end
    Engine.ents, Engine.byName, Engine.list = {}, {}, nil
    Carry.reset()
    Bridge.clearWeapons()

    local templ = templatedNames()
    Engine.templated = templ
    Rounds.spawnWeapons = Config.SPAWN_WEAPONS
    local created = {}
    for _, def in ipairs(MAP_ENTS) do
        local tn = def.kv.targetname
        local staticCart = Config.REMOVE_STATIC_MINECARTS and def.classname == "func_physbox" and tn == "minecart"
        if not (tn and templ[tn:lower()]) and not staticCart then
            created[#created + 1] = Engine.create(def)
        end
    end
    Rounds.spawnWeapons = false
    for _, inst in ipairs(created) do resolveParent(inst) end
    for _, inst in ipairs(created) do activate(inst) end
    Rounds.ready = true

    -- logic_auto (global state "is_pc" is on in GMod): OnMapSpawn shortly after spawn
    for _, inst in ipairs(Engine.byClass("logic_auto")) do
        Engine.fireOutput(inst, "OnMapSpawn", nil, nil, 0.1)
        if bitAnd(inst.spawnflags, 1) ~= 0 then
            local gen = Engine.generation
            setTimer(function() if gen == Engine.generation then Engine.kill(inst) end end, 200, 1)
        end
    end
    triggerClientEvent(root, "mc:mapReset", resourceRoot)
    Engine.flush()
end

local function mapSettingsOutput(name, param)
    for _, inst in ipairs(Engine.byClass("ttt_map_settings")) do
        Engine.fireOutput(inst, name, nil, param)
    end
end

function Rounds.prep()
    Rounds.reset()
    Rounds.state = "prep"
    mapSettingsOutput("RoundPreparation")
end

function Rounds.start()
    if Rounds.state == "idle" then Rounds.prep() end
    Rounds.state = "active"
    mapSettingsOutput("RoundStart")
end

function Rounds.finish(result)
    Rounds.state = "post"
    mapSettingsOutput("RoundEnd", result)
end

-- exports ---------------------------------------------------------------------
function roundPreparation() Rounds.prep() return true end
function roundStart() Rounds.start() return true end
function roundEnd(result) Rounds.finish(result) return true end
function resetMap() Rounds.reset() return true end
function fireInput(target, input, param, delay) Engine.fireInput(target, input, param, delay) return true end

-- player spawn points in GTA coordinates: { {x,y,z,rot}, ... }
function getSpawnPoints()
    local r = {}
    for _, def in ipairs(MAP_ENTS) do
        if def.classname:match("^info_player_") then
            local x, y, z = toWorld(vec3(def.kv.origin))
            local _, yaw = vec3(def.kv.angles)
            r[#r + 1] = { x, y, z + PED_CENTER + 0.1, yaw - 90 }
        end
    end
    return r
end

-- weapon/ammo spawn points: { {class, x, y, z, templated}, ... }
function getWeaponSpawns()
    local r = {}
    local templ = templatedNames()
    for _, def in ipairs(MAP_ENTS) do
        local c = def.classname
        if c:match("^weapon_") or c:match("^item_") or c:match("^ttt_random_") then
            local x, y, z = toWorld(vec3(def.kv.origin))
            local tn = def.kv.targetname
            r[#r + 1] = { c, x, y, z, (tn and templ[tn:lower()]) and true or false }
        end
    end
    return r
end

function getMapInfo()
    return { name = MAP_DATA.name, offset = Config.OFFSET, dimension = Config.DIMENSION, interior = Config.INTERIOR,
             state = Rounds.state }
end

-- round events from the gamemode
for kind, ev in pairs(Config.ROUND_EVENTS) do
    addEvent(ev, false)   -- server-side only (the gamemode triggers these with triggerEvent)
    addEventHandler(ev, root, function(result)
        if kind == "prep" then Rounds.prep() elseif kind == "start" then Rounds.start() else Rounds.finish(result) end
    end)
end

-- client requests --------------------------------------------------------------
local function objectDistance(player, inst)
    local px, py, pz = getElementPosition(player)
    local x, y, z = toWorld(Engine.getOrigin(inst))
    local mn, mx = inst.def.mins or { 0, 0, 0 }, inst.def.maxs or { 0, 0, 0 }
    -- distance to the entity's bounding box
    local function axis(p, o, a, b)
        local lo, hi = o + a * SCALE, o + b * SCALE
        if p < lo then return lo - p elseif p > hi then return p - hi end
        return 0
    end
    local dx, dy, dz = axis(px, x, mn[1], mx[1]), axis(py, y, mn[2], mx[2]), axis(pz, z, mn[3], mx[3])
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local lastUse = {}
addEvent("mc:use", true)
addEventHandler("mc:use", resourceRoot, function(uid)
    local pl = client
    if not pl or isPedDead(pl) then return end
    if (lastUse[pl] or 0) + 150 > getTickCount() then return end
    lastUse[pl] = getTickCount()
    local inst = Engine.ents[uid]
    if not inst or not inst.alive then return end
    if inst.carrier ~= pl and objectDistance(pl, inst) > Config.USE_RANGE + 1.5 then return end
    local c = Classes[inst.cls]
    if c and c.use then c.use(inst, pl) end
    Engine.fireOutput(inst, "OnPlayerUse", pl)
    Engine.flush()
end)

addEvent("mc:tbutton", true)
addEventHandler("mc:tbutton", resourceRoot, function(uid)
    local pl = client
    if not pl or isPedDead(pl) then return end
    local inst = Engine.ents[uid]
    if not inst or not inst.alive or inst.cls ~= "ttt_traitor_button" then return end
    if not Bridge.isActiveTraitor(pl) then return end
    local px, py, pz = getElementPosition(pl)
    local x, y, z = toWorld(inst.ox, inst.oy, inst.oz)
    local range = (tonumber(inst.kv.usableRange) or Config.TRAITOR_BUTTON_RANGE) * SCALE
    if getDistanceBetweenPoints3D(px, py, pz, x, y, z) > range + 2 then return end
    Classes.ttt_traitor_button.press(inst, pl)
    Engine.flush()
end)

-- weapon id -> category (Config.BREAK_HITS)
local function weaponKind(w)
    w = tonumber(w)
    if not w then return "other" end
    if w <= 15 then return "melee" end
    if w >= 22 and w <= 24 then return "pistol" end
    if w >= 25 and w <= 27 then return "shotgun" end
    if w == 28 or w == 29 or w == 32 then return "smg" end
    if w == 30 or w == 31 then return "assault" end
    if w == 33 or w == 34 then return "rifle" end
    return "other"
end

-- iron / diamond ore blocks: a fixed number of hits per weapon type
local function hitDamage(inst, weapon, amount)
    local kind = inst.def.mdl and Config.BREAK_KIND_MODELS and Config.BREAK_KIND_MODELS[inst.def.mdl.name]
    local hits = kind and Config.BREAK_HITS and Config.BREAK_HITS[kind]
    if not hits or weapon == nil then return amount end
    local n = hits[weaponKind(weapon)] or hits.other or 1
    local full = tonumber(inst.def.kv.health) or inst.health or 1
    return full / math.max(1, n) + 0.001
end

addEvent("mc:damage", true)
addEventHandler("mc:damage", resourceRoot, function(uid, amount, weapon)
    local pl = client
    if not pl then return end
    local inst = Engine.ents[uid]
    if not inst or not inst.alive then return end
    amount = math.max(0, math.min(200, tonumber(amount) or 0))
    amount = hitDamage(inst, weapon, amount)
    if objectDistance(pl, inst) > 150 then return end
    local c = Classes[inst.cls]
    if c and c.damage then c.damage(inst, pl, amount) end
    Engine.flush()
end)

-- role info for clients (traitor button overlay)
local sentRole = {}
setTimer(function()
    for _, pl in ipairs(getElementsByType("player")) do
        local r = Bridge.isActiveTraitor(pl) and "traitor" or "other"
        if sentRole[pl] ~= r then
            sentRole[pl] = r
            triggerClientEvent(pl, "mc:role", resourceRoot, r)
        end
    end
end, 1000, 0)
addEventHandler("onPlayerQuit", root, function() sentRole[source] = nil lastUse[source] = nil end)
addEvent("mc:clientReady", true)
addEventHandler("mc:clientReady", resourceRoot, function()
    sentRole[client] = nil
    -- the player's client has loaded all map models/collisions (safe to spawn them on the map now)
    triggerEvent("onPlayerMinecraftMapReady", client)
end)
addEvent("onPlayerMinecraftMapReady", false)

-- arrival on the map ------------------------------------------------------------
-- Players are frozen on their spawn point until THEIR client has loaded the map models and the
-- collision under them is streamed in (otherwise they would fall through the map).
Arrival = { ready = {}, frozen = {} }

local function shuffled(n)
    local t = {}
    for i = 1, n do t[i] = i end
    for i = n, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

function Arrival.place(player, spawn)
    if not isElement(player) or isPedDead(player) then return false end
    Arrival.warned[player] = nil
    if Carry then Carry.dropByPlayer(player) end
    if isPedInVehicle(player) then removePedFromVehicle(player) end
    setElementInterior(player, Config.INTERIOR)
    setElementDimension(player, Config.DIMENSION)
    setCameraInterior(player, Config.INTERIOR)
    setElementPosition(player, spawn[1], spawn[2], spawn[3])
    setElementRotation(player, 0, 0, spawn[4], "default", true)
    setElementVelocity(player, 0, 0, 0)
    setElementFrozen(player, true)
    Arrival.frozen[player] = getTickCount()
    if Arrival.ready[player] then triggerClientEvent(player, "mc:arrived", resourceRoot) end
    return true
end

-- spread players over the map's info_player_start points (35 on this map)
function Arrival.placeAll(players)
    local spawns = getSpawnPoints()
    if #spawns == 0 then return 0 end
    local order = shuffled(#spawns)
    local n = 0
    for i, p in ipairs(players) do
        local sp = spawns[order[(i - 1) % #order + 1]]
        if Arrival.place(p, sp) then n = n + 1 end
    end
    return n
end

addEvent("mc:landed", true)
addEventHandler("mc:landed", resourceRoot, function()
    local p = client
    if p and Arrival.frozen[p] then
        Arrival.frozen[p] = nil
        Arrival.tries[p] = nil
        setElementFrozen(p, false)
    end
end)

-- the client found no floor under the spawn after 15 s: try another spawn point (max 3 times)
Arrival.tries = {}
addEvent("mc:noGround", true)
addEventHandler("mc:noGround", resourceRoot, function()
    local p = client
    if not p or not Arrival.frozen[p] then return end
    Arrival.tries[p] = (Arrival.tries[p] or 0) + 1
    if Arrival.tries[p] >= 3 then
        Arrival.frozen[p] = nil
        Arrival.tries[p] = nil
        setElementFrozen(p, false)
        return
    end
    local spawns = getSpawnPoints()
    Arrival.place(p, spawns[math.random(#spawns)])
end)

-- Other resources may unfreeze everybody (ttt-core does it at every round end, ttt-admin on command):
-- players still waiting for the map collision are kept frozen, otherwise they would fall through.
setTimer(function()
    for p, t in pairs(Arrival.frozen) do
        if not isElement(p) or isPedDead(p) then
            Arrival.frozen[p] = nil
        else
            if not isElementFrozen(p) then setElementFrozen(p, true) end
            if not Arrival.ready[p] and getTickCount() - t > 60000 and not Arrival.warned[p] then
                Arrival.warned[p] = true
                outputChatBox("[Minecraft] A pálya még töltődik nálad, addig nem mozdulhatsz (különben átesnél rajta).", p, 255, 200, 0)
                outputDebugString("[mc] " .. getPlayerName(p) .. " is still downloading the map after 60 s")
            end
        end
    end
end, 250, 0)
Arrival.warned = {}

addEventHandler("onPlayerWasted", root, function() Arrival.frozen[source] = nil end)
addEventHandler("onPlayerQuit", root, function()
    Arrival.frozen[source], Arrival.ready[source], Arrival.tries[source], Arrival.warned[source] = nil, nil, nil, nil
end)

addEventHandler("onPlayerMinecraftMapReady", root, function()
    Arrival.ready[source] = true
    if Arrival.frozen[source] then triggerClientEvent(source, "mc:arrived", resourceRoot) end
end)

-- ttt-core integration -----------------------------------------------------------
function Rounds.tttCoreRunning()
    local r = getResourceFromName(Config.TTT_CORE_RESOURCE)
    return r and getResourceState(r) == "running" or false
end

function Rounds.mode()
    if Config.MODE == "auto" then return Rounds.tttCoreRunning() and "ttt-core" or "standalone" end
    return Config.MODE
end

-- players taking part in the current ttt-core round (they have a role and are alive)
local function roundPlayers()
    local r = {}
    for _, p in ipairs(getElementsByType("player")) do
        if not isPedDead(p) and getElementData(p, "tttRole") then r[#r + 1] = p end
    end
    return r
end

local function tttRoundStarted()
    Rounds.prep()
    Rounds.start()
    if Config.TELEPORT_ON_ROUND_START then
        local n = Arrival.placeAll(roundPlayers())
        outputDebugString("[mc] round start: " .. n .. " players placed on " .. MAP_DATA.name)
    end
end

addEvent(Config.TTT_EVENTS.start, false)
addEventHandler(Config.TTT_EVENTS.start, root, function()
    if Rounds.mode() ~= "ttt-core" then return end
    tttRoundStarted()
end)

addEvent(Config.TTT_EVENTS.finish, false)
addEventHandler(Config.TTT_EVENTS.finish, root, function(winner)
    if Rounds.mode() ~= "ttt-core" then return end
    Rounds.finish(winner)
end)

-- watchdog: during a ttt-core round, alive players with a role must be on the map. Something else
-- (late ttt-login spawn at Grove Street, closing the ttt-skin shop...) may move them away -> bring them back.
setTimer(function()
    if Rounds.state ~= "active" or Rounds.mode() ~= "ttt-core" or not Config.TELEPORT_ON_ROUND_START then return end
    local spawns
    for _, p in ipairs(getElementsByType("player")) do
        if not isPedDead(p) and getElementData(p, "tttRole") and not Arrival.frozen[p]
            and getElementDimension(p) == Config.DIMENSION and getElementInterior(p) == Config.INTERIOR then
            local x, y, z = getElementPosition(p)
            if z > -50 and not nearMap(x, y, z, 40) then
                spawns = spawns or getSpawnPoints()
                Arrival.place(p, spawns[math.random(#spawns)])
            end
        end
    end
end, 1000, 0)

-- admin / test commands ----------------------------------------------------------
-- Csak adminoknak (server/security.lua: "admin" element data >= Config.ADMIN_LEVEL, ACL Admin, vagy konzol).
-- A válasz csak a parancsot használónak megy (konzolról a szerver konzolba), soha nem mindenkinek.
local function reply(p, text, r, g, b)
    if Security.isConsole(p) then
        print((text:gsub("#%x%x%x%x%x%x", "")))
    else
        outputChatBox(text, p, r or 120, g or 200, b or 255, true)
    end
end

local function findPlayerByName(name)
    if not name or name == "" then return nil end
    local exact = getPlayerFromName(name)
    if exact then return exact end
    name = name:lower()
    for _, pl in ipairs(getElementsByType("player")) do
        if getPlayerName(pl):lower():find(name, 1, true) then return pl end
    end
    return nil
end

local function logAdmin(p, cmd, details)
    local who = Security.isConsole(p) and "Konzol" or getPlayerName(p)
    outputServerLog("[mc] admin command /" .. cmd .. " by " .. who .. (details and (": " .. details) or ""))
end

-- a játékos mehet-e most a pályára
local function canGoOnMap(target)
    if isPedDead(target) then return false, "halott" end
    -- during a running ttt-core round (somebody has a role) only the round's players belong on the map
    if Rounds.mode() == "ttt-core" and Rounds.state == "active" and #roundPlayers() > 0
        and not getElementData(target, "tttRole") then
        return false, "kör közben csak élő, szereppel rendelkező játékos mehet a pályára"
    end
    return true
end

-- /mcmap            teleport a pályára (magad)
-- /mcmap [név]      a megadott játékos a pályára
-- /mcmap all        mindenki (aki mehet) a pályára
addCommandHandler("mcmap", function(p, cmd, targetName)
    if not Security.require(p) then return end
    local targets = {}
    if targetName and targetName:lower() == "all" then
        targets = getElementsByType("player")
    elseif targetName and targetName ~= "" then
        local t = findPlayerByName(targetName)
        if not t then return reply(p, "#d9534f[Minecraft] #ffffffNincs ilyen játékos: " .. targetName) end
        targets = { t }
    elseif not Security.isConsole(p) then
        targets = { p }
    else
        return reply(p, "[Minecraft] Használat: mcmap [név|all]")
    end
    local spawns = getSpawnPoints()
    local order = {}
    for i = 1, #spawns do order[i] = i end
    for i = #order, 2, -1 do local j = math.random(i) order[i], order[j] = order[j], order[i] end
    local moved = 0
    for _, t in ipairs(targets) do
        local ok, why = canGoOnMap(t)
        if ok then
            moved = moved + 1
            Arrival.place(t, spawns[order[(moved - 1) % #order + 1]])
        elseif #targets == 1 then
            return reply(p, "#d9534f[Minecraft] #ffffff" .. getPlayerName(t) .. ": " .. why .. ".")
        end
    end
    if #targets > 1 or targets[1] ~= p then
        reply(p, "#7cc576[Minecraft] #ffffff" .. moved .. " játékos a pályára teleportálva.")
    end
    logAdmin(p, "mcmap", targetName)
end)

-- admin help: where are the diamond ores / gold block right now (and which are already in the furnace)
addCommandHandler("mcdia", function(p)
    if not Security.require(p) then return end
    local px, py, pz = 0, 0, 0
    if not Security.isConsole(p) then px, py, pz = getElementPosition(p) end
    for _, inst in ipairs(Engine.all()) do
        local n = inst.name or ""
        if inst.alive and (n:find("^DiaOre_%d+$") or n == "GoldBlock" or n == "DiaBlock") then
            local x, y, z = toWorld(Engine.getOrigin(inst))
            reply(p, string.format("[Minecraft] %s - %.0f m-re (x %.1f, y %.1f, z %.1f)%s", n,
                getDistanceBetweenPoints3D(px, py, pz, x, y, z), x, y, z, inst.carrier and " - valaki viszi" or ""))
        end
    end
    do
        local cave = Engine.findByName("Cave2_Template")[1]
        if cave and cave.alive and not Engine.findByName("DiaOre_9")[1] then
            reply(p, "[Minecraft] A 9. gyémántérc még a barlangban lévő vasérc-blokkban van (Lődd/üsd szét!).")
        end
    end
    reply(p, "[Minecraft] Kemencében: " .. tostring((Engine.findByName("Furnace_Counter_Dia")[1] or {}).value or "?") .. " / 9")
    logAdmin(p, "mcdia")
end)

-- teleport an admin on top of a map block (frozen until his collision is loaded, like at the round start)
local function gotoBlock(p, inst, label)
    if inst.carrier and isElement(inst.carrier) then
        return reply(p, "#d9534f[Minecraft] #ffffff" .. label .. " épp " .. getPlayerName(inst.carrier) .. " viszi.")
    end
    if isPedDead(p) then return reply(p, "#d9534f[Minecraft] #ffffffHalottként nem lehet.") end
    local x, y, z = toWorld(Engine.getOrigin(inst))
    local top = (inst.def.maxs and inst.def.maxs[3] or 8) * SCALE
    local _, _, rz = getElementRotation(p)
    Arrival.place(p, { x, y, z + top + PED_CENTER + 0.05, rz })
    reply(p, "#7cc576[Minecraft] #ffffffTeleportálva: " .. label .. ".")
    return true
end

-- /gotogold: teleport to the (small) gold block - Főadmin (2) and above
addCommandHandler("gotogold", function(p)
    if Security.isConsole(p) then return reply(p, "[Minecraft] Ezt csak játékosként lehet használni.") end
    if not Security.require(p, Config.GOTOGOLD_ADMIN_LEVEL or 2) then return end
    local gold = Engine.findByName("GoldBlock")[1]
    if not gold or not gold.alive then
        return reply(p, "#d9534f[Minecraft] #ffffffAz aranyblokk most nincs a pályán (már a crafting asztalon van?).")
    end
    if gotoBlock(p, gold, "az aranyblokk") then logAdmin(p, "gotogold") end
end)

-- /gotodia       : the finished diamond block if it exists, otherwise the nearest diamond ore still on the map
-- /gotodia [1-9] : that diamond ore (DiaOre_N)        - Fejlesztő (3) and above
addCommandHandler("gotodia", function(p, cmd, which)
    if Security.isConsole(p) then return reply(p, "[Minecraft] Ezt csak játékosként lehet használni.") end
    if not Security.require(p, Config.GOTODIA_ADMIN_LEVEL or 3) then return end
    local n = tonumber(which)
    if n then
        local ore = Engine.findByName("DiaOre_" .. math.floor(n))[1]
        if not ore or not ore.alive then
            local hint = (math.floor(n) == 9) and " (a 9. érc a barlang vasérc-blokkjában van, amíg szét nem lövik)" or
                " (már a kemencében van?)"
            return reply(p, "#d9534f[Minecraft] #ffffffA(z) " .. math.floor(n) .. ". gyémántérc most nincs a pályán" .. hint .. ".")
        end
        if gotoBlock(p, ore, "a(z) " .. math.floor(n) .. ". gyémántérc") then logAdmin(p, "gotodia", tostring(n)) end
        return
    end
    local block = Engine.findByName("DiaBlock")[1]
    if block and block.alive then
        if gotoBlock(p, block, "a gyémántblokk") then logAdmin(p, "gotodia", "DiaBlock") end
        return
    end
    local px, py, pz = getElementPosition(p)
    local best, bestD, bestN
    for i = 1, 9 do
        local ore = Engine.findByName("DiaOre_" .. i)[1]
        if ore and ore.alive and not (ore.carrier and isElement(ore.carrier)) then
            local x, y, z = toWorld(Engine.getOrigin(ore))
            local d = getDistanceBetweenPoints3D(px, py, pz, x, y, z)
            if not bestD or d < bestD then best, bestD, bestN = ore, d, i end
        end
    end
    if not best then
        return reply(p, "#d9534f[Minecraft] #ffffffNincs gyémántérc a pályán (mind a kemencében, vagy valaki viszi). Lásd: /mcdia")
    end
    if gotoBlock(p, best, "a legközelebbi gyémántérc (" .. bestN .. ".)") then logAdmin(p, "gotodia", "DiaOre_" .. bestN) end
end)

addCommandHandler("mcreset", function(p)
    if not Security.require(p) then return end
    Rounds.prep()
    Rounds.start()
    reply(p, "[Minecraft] A pálya újraindítva.", 0, 255, 0)
    logAdmin(p, "mcreset")
end)

-- startup ----------------------------------------------------------------------
addEventHandler("onResourceStart", resourceRoot, function()
    -- (the swimmable GTA water is created by the clients: client/zones.lua)
    local mode = Rounds.mode()
    if mode == "ttt-core" then
        if #roundPlayers() > 0 then
            -- started while a ttt-core round is running: bring the round's players over right away
            tttRoundStarted()
        else
            Rounds.reset()
            Rounds.state = "idle"
        end
    elseif mode == "standalone" then
        Rounds.prep()
        setTimer(function() Rounds.start() end, 1000, 1)
    else
        Rounds.reset()
        Rounds.state = "idle"
    end
    outputDebugString("[mc] " .. MAP_DATA.name .. " loaded (" .. mode .. " mode): " .. #MAP_ENTS .. " entities")
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for p in pairs(Arrival.frozen) do
        if isElement(p) then setElementFrozen(p, false) end
    end
    -- the clients destroy the map now: move everybody standing on it to the lobby so nobody falls 600 m
    local l = Config.LOBBY_SPAWN
    for _, p in ipairs(getElementsByType("player")) do
        if not isPedDead(p) and getElementInterior(p) == Config.INTERIOR then
            local x, y, z = getElementPosition(p)
            if nearMap(x, y, z, 40) then
                setElementPosition(p, l[1] + math.random(-3, 3), l[2] + math.random(-3, 3), l[3])
            end
        end
    end
end)
