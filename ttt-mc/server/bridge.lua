--[[
    ================================================================================
     TTT BRIDGE - a pálya és a szerver TTT resource-jai (ttt-core, ttt-shop...) közötti kapcsolat
    ================================================================================
    Ehhez a szerverhez igazítva:
      - szerep:   element data "tttRole" = "Traitor" / "Detective" / "Innocent" (halottnál false)   [ttt-core]
      - kredit:   a szerveren a pénz a kredit (ttt-shop is getPlayerMoney-t használ):
                  1 TTT kredit = Config.CREDIT_PRICE dollár (alap: $1000)
      - győzelem: a pálya "innocent win"-je (gyémántblokk a világítótoronyba) a ttt-core
                  checkTTTWin exportján keresztül zárja le a kört (Innocent győzelem)
      - kör:      a ttt-core "ttt:onRoundStart" / "ttt:onRoundEnd" eventjei (server/main.lua)
      - sebzés:   killPed(áldozat, csapdát aktiváló traitor) -> a ttt-core hullát készít, a replay rögzíti
      - fegyverek: a pálya fegyver/lőszer spawnjai MTA pickupként (mint a ttt-int pickupjai)
]]

Bridge = {}

-- TTT role numbers (as used by the map's ttt_logic_role entities)
ROLE_INNOCENT, ROLE_TRAITOR, ROLE_DETECTIVE = 0, 1, 2

local function coreResource()
    local res = getResourceFromName(Config.TTT_CORE_RESOURCE or "ttt-core")
    if res and getResourceState(res) == "running" then return res end
    return nil
end

local function coreExports(res)
    local set = {}
    for _, f in ipairs(getResourceExportedFunctions(res) or {}) do set[f] = true end
    return set
end

local function normalizeRole(r)
    if type(r) == "number" then return r end
    if type(r) == "string" then
        r = r:lower()
        if r:find("traitor") or r == "t" then return ROLE_TRAITOR end
        if r:find("detective") or r == "d" then return ROLE_DETECTIVE end
        return ROLE_INNOCENT
    end
    return ROLE_INNOCENT
end

-- a játékos szerepe (0 innocent, 1 traitor, 2 detective)
function Bridge.getRole(player)
    for _, key in ipairs({ "tttRole", "role", "ttt.role" }) do
        local r = getElementData(player, key)
        if r ~= nil and r ~= false then return normalizeRole(r) end
    end
    return ROLE_INNOCENT
end

-- TTT: outside an active round everyone counts as innocent for ttt_logic_role
function Bridge.getRoleNumber(player)
    if Rounds and Rounds.state ~= "active" then return ROLE_INNOCENT end
    return Bridge.getRole(player)
end

function Bridge.isActiveTraitor(player)
    if Rounds and Rounds.state ~= "active" then return false end
    return not isPedDead(player) and Bridge.getRole(player) == ROLE_TRAITOR
end

-- traitor "kreditbolt" szoba (T2): 1 kredit -> véletlen traitor tárgy. Itt a kredit = pénz.
function Bridge.takeCredits(player, amount)
    local price = (Config.CREDIT_PRICE or 1000) * amount
    if getPlayerMoney(player) < price then
        outputChatBox("[Minecraft] Nincs elég pénzed ($" .. price .. " kell egy tárgyhoz).", player, 217, 83, 79)
        return false
    end
    takePlayerMoney(player, price)
    outputChatBox("[Minecraft] -$" .. price .. " (traitor tárgy)", player, 124, 197, 118)
    Bridge.logPurchase(player, "Minecraft traitor szoba (" .. amount .. " kredit)", price)
    return true
end

local function running(name)
    local r = getResourceFromName(name)
    return r and getResourceState(r) == "running"
end

-- vásárlás naplózása ugyanúgy, mint a ttt-shop: shop_logs tábla (ttt-sql) + Discord (ttt-dc)
function Bridge.logPurchase(player, what, price)
    local name = getPlayerName(player)
    if running("ttt-sql") then
        pcall(function()
            exports["ttt-sql"]:dbQueryExec("INSERT INTO shop_logs (player, action, cost) VALUES (?, ?, ?)",
                name, "Vett: " .. what, price)
        end)
    end
    if running("ttt-dc") then
        pcall(function() exports["ttt-dc"]:sendMoneyLog("BLACK MARKET", name, "Vett: " .. what, price) end)
    end
end

-- a pálya által kiváltott győzelem (ttt_win InnocentWin: gyémántblokk a világítótoronyba)
-- Config.MAP_WIN: "end_teleport" = a ttt-core innocent win-je akkor fut le, amikor a pálya átteleportálja a
-- játékosokat az "end"-be (győzelmi szoba); "immediate" = rögtön; false = a pálya nem dönt győztesről.
Bridge.pendingWin = nil
function Bridge.declareWin(team)
    triggerEvent("onTTTMapWin", root, team)
    local mode = Config.MAP_WIN
    if not mode then
        outputDebugString("[mc] map win (" .. tostring(team) .. ") ignored: MAP_WIN = false")
        return
    end
    if mode == "end_teleport" then
        if Bridge.pendingWin then return end
        local gen = Engine.generation
        Bridge.pendingWin = { team = team, gen = gen }
        -- safety net: nobody got teleported (e.g. nobody alive in the trigger area)
        setTimer(function()
            if Bridge.pendingWin and Bridge.pendingWin.gen == gen then Bridge.finishWin() end
        end, Config.MAP_WIN_FALLBACK_MS or 15000, 1)
        return
    end
    Bridge.finishWin(team)
end

-- the first player arrives in the end (point_teleport Win_Teleport_*)
function Bridge.onEndTeleport()
    if Bridge.pendingWin then Bridge.finishWin() end
end

-- ttt-core's innocent / traitor win: the losing side leaves the round count, then checkTTTWin ends the round
-- ("Az Innocentek győztek!", stopTTTRound("Innocent"))
function Bridge.finishWin(team)
    team = team or (Bridge.pendingWin and Bridge.pendingWin.team)
    Bridge.pendingWin = nil
    if not team then return end
    outputDebugString("[mc] map win: " .. tostring(team))
    local res = coreResource()
    if res and coreExports(res).checkTTTWin then
        -- the losing side is taken out of the round count, then ttt-core ends the round itself
        for _, p in ipairs(getElementsByType("player")) do
            local role = getElementData(p, "tttRole")
            if role and ((team == "innocent" and role == "Traitor") or (team == "traitor" and role ~= "Traitor")) then
                setElementData(p, "tttRole", false)
            end
        end
        call(res, "checkTTTWin")
        return
    end
    outputChatBox("[Minecraft] " .. (team == "innocent" and "Az innocentek nyertek!" or team == "traitor" and "A traitorok nyertek!" or "Döntetlen!"), root, 0, 255, 0)
end

-- ttt_game_text: receive 0 = activator, 1 = mindenki, 2 = detectivek, 3 = traitorok, 4 = innocentek
function Bridge.gameText(msg, receive, activator, r, g, b)
    local targets = {}
    if receive == 0 then
        if Engine.isPlayer(activator) then targets = { activator } end
    else
        for _, pl in ipairs(getElementsByType("player")) do
            local role = Bridge.getRoleNumber(pl)
            if receive == 1 or (receive == 2 and role == ROLE_DETECTIVE) or (receive == 3 and role == ROLE_TRAITOR)
                or (receive == 4 and role ~= ROLE_TRAITOR) then
                targets[#targets + 1] = pl
            end
        end
    end
    if Config.TEXT_HIDE and Config.TEXT_HIDE[msg] then return end
    msg = (Config.TEXT_REPLACE and Config.TEXT_REPLACE[msg]) or msg
    -- GMod shows these on the HUD (a repeat just replaces it); in the chat the same line would pile up
    Bridge.lastText = Bridge.lastText or {}
    local now = getTickCount()
    for _, pl in ipairs(targets) do
        local seen = Bridge.lastText[pl] or {}
        Bridge.lastText[pl] = seen
        if not seen[msg] or now - seen[msg] > (Config.TEXT_REPEAT_MS or 20000) then
            seen[msg] = now
            outputChatBox(msg, pl, r, g, b)
        end
    end
end
addEventHandler("onPlayerQuit", root, function()
    if Bridge.lastText then Bridge.lastText[source] = nil end
    Bridge.deaths[source] = nil
end)

-- ttt-core makes a corpse (ped, element data "isCorpse", "corpse:name", "corpse:weapon") in onPlayerWasted.
-- For deaths caused by the map (lava, traps, falling off) GTA has no fitting weapon name ("Explosion",
-- "Flamethrower"...), so the corpse gets a readable one.
addEventHandler("onPlayerWasted", root, function()
    local d = Bridge.deaths[source]
    Bridge.deaths[source] = nil
    if not d or getTickCount() - d.t > 2000 then return end
    local name = getPlayerName(source)
    local x, y, z = getElementPosition(source)
    setTimer(function()
        local best, bestD
        for _, ped in ipairs(getElementsByType("ped")) do
            if getElementData(ped, "isCorpse") and getElementData(ped, "corpse:name") == name then
                local dist = getDistanceBetweenPoints3D(x, y, z, getElementPosition(ped))
                if dist < 5 and (not bestD or dist < bestD) then best, bestD = ped, dist end
            end
        end
        if best then setElementData(best, "corpse:weapon", d.label) end
    end, 100, 1)
end)

-- the player credited for trap kills (ttt_damageowner)
function Bridge.damageOwnerOf(inst)
    local o = inst and inst.damageOwner
    if o and isElement(o) then return o end
    return nil
end

-- what ttt-core's corpse shows as "Fegyver" for deaths caused by the map
local function deathLabel(dtype, killName, attacker)
    if killName == "fell off the map" then return "Leesett a pályáról" end
    local n = tonumber(dtype) or 0
    if dtype == "fall" or bitAnd(n, 32) ~= 0 then return "Esés" end
    if bitAnd(n, 8) ~= 0 then return "Tűz / láva" end
    if bitAnd(n, 16384) ~= 0 then return "Fulladás" end
    if attacker then return "Csapda (pálya)" end
    return "A pálya (csapda / zúzás)"
end

-- sebzés pályaelemektől (csapdák, láva, kill zónák). dtype: Source damage type (8 = égés, 32 = esés)
Bridge.deaths = {}
function Bridge.damagePlayer(player, amount, attacker, dtype, killName)
    if isPedDead(player) then return end
    local hp = getElementHealth(player)
    local weapon = (dtype == 8) and 37 or ((dtype == 32 or dtype == "fall") and 54 or 51)
    if hp - amount <= 0 then
        setElementData(player, "mc.killname", killName or "map", false)
        Bridge.deaths[player] = { label = deathLabel(dtype, killName, attacker and attacker ~= player), t = getTickCount() }
        if attacker and isElement(attacker) and attacker ~= player then
            killPed(player, attacker, weapon, 3)
        else
            killPed(player, nil, weapon, 3)
        end
    else
        setElementHealth(player, hp - amount)
    end
end

-- a pálya fegyver/lőszer spawnjai (GMod TTT osztály -> GTA fegyver ID, lőszer)
local WEAPONS = {
    weapon_zm_pistol = { 22, 34 }, weapon_ttt_glock = { 23, 40 }, weapon_zm_revolver = { 24, 14 },
    weapon_zm_shotgun = { 25, 16 }, weapon_zm_mac10 = { 28, 60 }, weapon_ttt_m16 = { 31, 60 },
    weapon_zm_rifle = { 34, 10 }, weapon_zm_sledge = { 30, 150 }, weapon_zm_molotov = { 18, 1 },
    weapon_ttt_confgrenade = { 16, 1 }, weapon_ttt_smokegrenade = { 17, 1 }, weapon_ttt_knife = { 4, 1 },
    weapon_ttt_sipistol = { 23, 20 },
    -- traitor items without a GTA equivalent (T2 credit room) -> closest GTA item
    weapon_ttt_flaregun = { 18, 2 },     -- molotov (fire)
    weapon_ttt_decoy = { 17, 2 },        -- tear gas
    weapon_ttt_radio = { 16, 1 },        -- grenade
    weapon_ttt_teleport = { "armor", 100 },
    item_ammo_pistol_ttt = { 22, 20 }, item_ammo_revolver_ttt = { 24, 12 }, item_box_buckshot_ttt = { 25, 8 },
    item_ammo_357_ttt = { 34, 10 }, item_ammo_smg1_ttt = { 31, 30 },
}
local RANDOM_WEAPONS = { "weapon_zm_pistol", "weapon_ttt_glock", "weapon_zm_revolver", "weapon_zm_shotgun",
    "weapon_zm_mac10", "weapon_ttt_m16", "weapon_zm_rifle", "weapon_zm_sledge", "weapon_zm_molotov" }
local RANDOM_AMMO = { "item_ammo_pistol_ttt", "item_ammo_revolver_ttt", "item_box_buckshot_ttt",
    "item_ammo_357_ttt", "item_ammo_smg1_ttt" }

Bridge.pickups = {}

-- items of the traitor credit room: always spawned (they are part of the room, not random loot)
local TRAITOR_ITEMS = { weapon_ttt_flaregun = true, weapon_ttt_decoy = true, weapon_ttt_radio = true,
    weapon_ttt_teleport = true, weapon_ttt_knife = true, weapon_ttt_sipistol = true }
function Bridge.isTraitorItem(cls) return TRAITOR_ITEMS[cls] == true end

function Bridge.spawnWeapon(cls, x, y, z, inst)
    if cls == "ttt_random_weapon" then cls = RANDOM_WEAPONS[math.random(#RANDOM_WEAPONS)] end
    if cls == "ttt_random_ammo" then cls = RANDOM_AMMO[math.random(#RANDOM_AMMO)] end
    local w = WEAPONS[cls]
    if not w then return nil end
    local p
    if w[1] == "armor" then
        p = createPickup(x, y, z, 1, w[2], 3600000)
    else
        p = createPickup(x, y, z, 2, w[1], 3600000, w[2])
    end
    if p then
        setElementDimension(p, Config.DIMENSION)
        setElementInterior(p, Config.INTERIOR)
        Bridge.pickups[p] = true
        setElementData(p, "mc.pickup", true)   -- (server/weapons.lua removes it once it is really used)
    end
    return p
end

function Bridge.clearWeapons()
    for p in pairs(Bridge.pickups) do if isElement(p) then destroyElement(p) end end
    Bridge.pickups = {}
end

-- short sound effects (client/fx.lua plays sounds/sfx/<name>.wav at the position, heard nearby)
function Bridge.sfx(name, x, y, z)
    if not Config.SOUND_EFFECTS then return end
    triggerClientEvent(root, "mc:sfx", resourceRoot, name, x, y, z)
end
function Bridge.sfxAt(name, inst)
    if inst and inst.obj and isElement(inst.obj) then
        local x, y, z = getElementPosition(inst.obj)
        Bridge.sfx(name, x, y, z)
    elseif inst then
        Bridge.sfx(name, toWorld(Engine.getOrigin(inst)))
    end
end
