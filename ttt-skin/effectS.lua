-----------------------------------------
-- TTT SKIN – EFFEKTEK, szerver oldal
-- Táblák: owned_effects (megvett effektek), active_effects (kiválasztott effekt) – automatikusan létrejönnek.
-- Az aktív effekt a "tttEffect" elementData-ba kerül, ezt minden kliens látja és kirajzolja.
-----------------------------------------
local ownedCache = {}   -- [player] = {[kulcs] = true}
local ready, pending = false, {}

addEvent("ttt:onPlayerLoaded", false)

local function msg(p, text) outputChatBox(text, p, 255, 255, 255, true) end

local function db()
    local r = getResourceFromName("ttt-sql")
    if not r or getResourceState(r) ~= "running" then return false end
    return exports["ttt-sql"]:getDatabaseHandler()
end

local function whenReady(fn)
    if ready then fn() else pending[#pending + 1] = fn end
end

local function initTables()
    if ready then return end
    local h = db()
    if not h then return setTimer(initTables, 3000, 1) end
    dbExec(h, [[CREATE TABLE IF NOT EXISTS owned_effects (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        player_name VARCHAR(64) NOT NULL,
        effect_key VARCHAR(32) NOT NULL,
        price INT NOT NULL DEFAULT 0,
        bought_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uq_player_effect (player_name, effect_key)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    dbExec(h, [[CREATE TABLE IF NOT EXISTS active_effects (
        player_name VARCHAR(64) NOT NULL PRIMARY KEY,
        effect_key VARCHAR(32) NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    ready = true
    for _, fn in ipairs(pending) do fn() end
    pending = {}
end
addEventHandler("onResourceStart", resourceRoot, initTables)

-- Az aktív effekt beállítása (nil = levétel). save=false: csak elementData, DB-t nem írja.
local function applyEffect(p, key, save)
    if key and EffectByKey[key] then
        setElementData(p, "tttEffect", key)
    else
        key = nil
        removeElementData(p, "tttEffect")
    end
    if save ~= false then
        local h = db()
        if h then
            if key then
                dbExec(h, "REPLACE INTO active_effects (player_name, effect_key) VALUES (?, ?)", getPlayerName(p), key)
            else
                dbExec(h, "DELETE FROM active_effects WHERE player_name = ?", getPlayerName(p))
            end
        end
    end
end

local function sendToClient(p)
    local list = {}
    for k in pairs(ownedCache[p] or {}) do list[#list + 1] = k end
    triggerClientEvent(p, "ttt:receiveEffects", p, list, getElementData(p, "tttEffect"))
end

local function loadEffects(p)
    if not isElement(p) then return end
    whenReady(function()
        local h = db()
        if not h or not isElement(p) then return end
        dbQuery(function(qh, player)
            local res = dbPoll(qh, 0)
            if not isElement(player) then return end
            local owned, active = {}, nil
            for _, row in ipairs(res or {}) do
                if EffectByKey[row.effect_key] then
                    owned[row.effect_key] = true
                    if tonumber(row.is_active) == 1 then active = row.effect_key end
                end
            end
            ownedCache[player] = owned
            applyEffect(player, active, false)
            sendToClient(player)
        end, {p}, h, [[SELECT o.effect_key, (a.effect_key IS NOT NULL AND a.effect_key = o.effect_key) AS is_active
                       FROM owned_effects o LEFT JOIN active_effects a ON a.player_name = o.player_name
                       WHERE o.player_name = ?]], getPlayerName(p))
    end)
end

addEvent("ttt:requestOwnedEffects", true)
addEventHandler("ttt:requestOwnedEffects", root, function() loadEffects(client or source) end)
addEventHandler("ttt:onPlayerLoaded", root, function() loadEffects(source) end)
addEventHandler("onPlayerQuit", root, function() ownedCache[source] = nil end)

-- Az effekt elementData-t csak a szerver állíthatja
addEventHandler("onElementDataChange", root, function(key, oldValue)
    if key == "tttEffect" and client then
        if oldValue == nil then removeElementData(source, key) else setElementData(source, key, oldValue) end
    end
end)

-----------------------------------------
-- VÁSÁRLÁS (a ttt-shop EFFEKTEK fülről): a kliens csak a kulcsot küldi
-----------------------------------------
addEvent("ttt:buyEffect", true)
addEventHandler("ttt:buyEffect", root, function(key)
    local p = client
    if not p then return end
    local e = EffectByKey[key]
    if not e then return end
    local owned = ownedCache[p]
    if not owned then return msg(p, "#d9534f[Effekt] #ffffffAz adataid még töltődnek, próbáld újra pár másodperc múlva!") end
    if owned[key] then
        return msg(p, "#f1c40f[Effekt] #ffffffEz már a tiéd! Felvenni az #00c3ffF4 #ffffffskin menü #00c3ff[3] #fffffffülén tudod.")
    end
    if getPlayerMoney(p) < e.price then
        return msg(p, "#d9534f[Effekt] #ffffffNincs elég pénzed! ($" .. e.price .. ")")
    end
    local h = db()
    if not h then return msg(p, "#d9534f[Effekt] #ffffffAz adatbázis most nem elérhető, próbáld később!") end

    takePlayerMoney(p, e.price)
    local name = getPlayerName(p)
    dbExec(h, "INSERT IGNORE INTO owned_effects (player_name, effect_key, price) VALUES (?, ?, ?)", name, key, e.price)
    dbExec(h, "INSERT INTO shop_logs (player, action, cost) VALUES (?, ?, ?)", name, "Effekt: " .. e.name, e.price)
    local dc = getResourceFromName("ttt-dc")
    if dc and getResourceState(dc) == "running" then
        exports["ttt-dc"]:sendMoneyLog("EFFEKT BOLT", name, "Vett: " .. e.name, e.price)
    end

    owned[key] = true
    applyEffect(p, key)   -- vásárlás után rögtön fel is veszi
    sendToClient(p)
    msg(p, "#7cc576[Effekt] #ffffffSikeres vásárlás és felvétel: #00c3ff" .. e.name)
end)

-----------------------------------------
-- KIVÁLASZTÁS (skin menü [3] fül): "none" = levétel
-----------------------------------------
addEvent("ttt:setEffect", true)
addEventHandler("ttt:setEffect", root, function(key)
    local p = client
    if not p then return end
    if key == "none" or key == nil then
        applyEffect(p, nil)
        sendToClient(p)
        return msg(p, "#7cc576[Effekt] #ffffffEffekt levéve.")
    end
    local e = EffectByKey[key]
    if not e then return end
    if not (ownedCache[p] and ownedCache[p][key]) then
        return msg(p, "#d9534f[Effekt] #ffffffEz az effekt még nincs meg! Az #00c3ffF3 #ffffffshop #00c3ffEFFEKTEK #fffffffülén veheted meg.")
    end
    applyEffect(p, key)
    sendToClient(p)
    msg(p, "#7cc576[Effekt] #ffffffEffekt felvéve: #00c3ff" .. e.name)
end)

-----------------------------------------
-- EXPORT a ttt-adminnak (/giveeffect)
-----------------------------------------
function giveEffect(p, key)
    if not isElement(p) or not EffectByKey[key] then return false end
    local h = db()
    if not h then return false end
    dbExec(h, "INSERT IGNORE INTO owned_effects (player_name, effect_key, price) VALUES (?, ?, 0)", getPlayerName(p), key)
    ownedCache[p] = ownedCache[p] or {}
    ownedCache[p][key] = true
    sendToClient(p)
    return EffectByKey[key].name
end

function getEffectKeys()
    local keys = {}
    for i, e in ipairs(EffectList) do keys[i] = e.key end
    return keys
end
