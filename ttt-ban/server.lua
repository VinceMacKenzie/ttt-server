-----------------------------------------
-- TTT BAN - szerver oldal
-- Belépéskor serial alapján ellenőrzi a "bans" táblát. A bannolt játékos bent marad a szerveren, de:
--  * a kliensén sötét képernyő jelenik meg a ban adataival (client.lua),
--  * külön dimenzióba kerül, lefagyasztva és némítva,
--  * "banned" elementData-t kap, a ttt-core ezért nem oszt neki szerepet.
-- A /ban és /unban parancs a ttt-admin-ban van, az exportokon (applyBan / liftBan) keresztül szól ide.
-----------------------------------------
local BAN_DIM = 60000                        -- ide kerülnek a bannolt játékosok (senkivel nem találkoznak)
local LOBBY = { -5.651, -24.687, 615.000 }   -- unban után ide kerül a játékos (ugyanaz, mint a ttt-login SPAWN)
local banned = {}                            -- [player] = { admin, reason, wasMuted }

addEvent("ttt-ban:ready", true)
addEvent("ttt:onPlayerLoaded", false)

local function getDB()
    return exports["ttt-sql"]:getDatabaseHandler()
end

local function enforce(p)
    if not isElement(p) or not banned[p] then return end
    if getElementData(p, "banned") ~= true then setElementData(p, "banned", true) end
    if getElementDimension(p) ~= BAN_DIM then setElementDimension(p, BAN_DIM) end
    setElementFrozen(p, true)
    if not isPlayerMuted(p) then setPlayerMuted(p, true) end
end

local function sendInfo(p)
    local info = banned[p]
    if info and isElement(p) then
        triggerClientEvent(p, "ttt-ban:show", resourceRoot, info.admin, info.reason)
    end
end

local function setBanned(p, admin, reason)
    if not banned[p] then banned[p] = { wasMuted = isPlayerMuted(p) } end
    banned[p].admin, banned[p].reason = tostring(admin), tostring(reason)
    enforce(p)
    sendInfo(p)
end

local function release(p, respawn)
    local info = banned[p]
    banned[p] = nil
    if not isElement(p) or not info then return end
    removeElementData(p, "banned")
    setPlayerMuted(p, info.wasMuted)
    setElementFrozen(p, false)
    setElementDimension(p, 0)
    if respawn then
        spawnPlayer(p, LOBBY[1], LOBBY[2], LOBBY[3], 0, getElementModel(p), 0, 0)
        fadeCamera(p, true)
        setCameraTarget(p, p)
    end
    triggerClientEvent(p, "ttt-ban:hide", resourceRoot)
end

-----------------------------------------
-- EXPORTOK (a ttt-admin hívja)
-----------------------------------------
function applyBan(player, adminName, reason)
    if not isElement(player) then return false end
    -- kör közben a bannolt játékos "meghal", hogy a kör logikája ne számoljon vele tovább
    if getElementData(player, "tttRole") and not isPedDead(player) then killPed(player) end
    setBanned(player, adminName, reason)
    return true
end

function liftBan(serial)
    for p in pairs(banned) do
        if isElement(p) and getPlayerSerial(p) == serial then release(p, true) end
    end
end

-----------------------------------------
-- BELÉPÉSKORI ELLENŐRZÉS
-----------------------------------------
local function checkPlayer(p)
    if not isElement(p) then return end
    local db = getDB()
    if not db then   -- az adatbázis még nem kész: pár mp múlva újra
        setTimer(checkPlayer, 3000, 1, p)
        return
    end
    dbQuery(function(qh, pl)
        if not isElement(pl) then return end
        local res = dbPoll(qh, 0)
        local ban = res and res[1]
        if ban and not banned[pl] then setBanned(pl, ban.admin_name, ban.reason) end
    end, {p}, db, "SELECT admin_name, reason FROM bans WHERE serial = ? AND active = 1 ORDER BY id DESC LIMIT 1", getPlayerSerial(p))
end

addEventHandler("onPlayerJoin", root, function() checkPlayer(source) end)

addEventHandler("onResourceStart", resourceRoot, function()
    for _, p in ipairs(getElementsByType("player")) do checkPlayer(p) end
end)

-- A kliens jelzi, hogy betöltött: ekkor küldjük a ban adatait (ha korábban küldtük, elveszhetett)
addEventHandler("ttt-ban:ready", root, function()
    if client then sendInfo(client) end
end)

-- A ttt-login a betöltés végén újra spawnol / dimenziót állít, ezért utána újra érvényesítjük
addEventHandler("ttt:onPlayerLoaded", root, function() enforce(source) end)
setTimer(function() for p in pairs(banned) do enforce(p) end end, 2000, 0)

addEventHandler("onPlayerQuit", root, function() banned[source] = nil end)

-- Ha a resource leáll, senkit nem hagyunk lefagyasztva
addEventHandler("onResourceStop", resourceRoot, function()
    for p in pairs(banned) do release(p, false) end
end)
