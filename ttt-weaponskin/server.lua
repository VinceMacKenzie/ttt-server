-----------------------------------------
-- TTT WEAPONSKIN – FEGYVER SKINEK, szerver oldal
-- Táblák: owned_weapon_skins (megvett skinek), active_weapon_skins (fegyverenként felvett skin)
-- – automatikusan létrejönnek. A felvett skinek a "tttWSkins" elementData-ba kerülnek
-- ({[fegyverID] = kulcs}), ezt minden kliens látja és a kézben lévő fegyverre rárakja.
-----------------------------------------
local ownedCache = {}   -- [player] = {["30:candy"] = true}
local activeCache = {}  -- [player] = {[30] = "candy"}
local ready, pending = false, {}

addEvent("ttt:onPlayerLoaded", false)

local function msg(p, text) outputChatBox(text, p, 255, 255, 255, true) end
local function ownKey(wid, key) return tostring(wid) .. ":" .. key end

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
    dbExec(h, [[CREATE TABLE IF NOT EXISTS owned_weapon_skins (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        player_name VARCHAR(64) NOT NULL,
        weapon_id SMALLINT NOT NULL,
        skin_key VARCHAR(32) NOT NULL,
        price INT NOT NULL DEFAULT 0,
        bought_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uq_player_wskin (player_name, weapon_id, skin_key)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    dbExec(h, [[CREATE TABLE IF NOT EXISTS active_weapon_skins (
        player_name VARCHAR(64) NOT NULL,
        weapon_id SMALLINT NOT NULL,
        skin_key VARCHAR(32) NOT NULL,
        PRIMARY KEY (player_name, weapon_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    ready = true
    for _, fn in ipairs(pending) do fn() end
    pending = {}
end
addEventHandler("onResourceStart", resourceRoot, initTables)

-- elementData frissítése a cache-ből (üres tábla helyett törli)
local function syncData(p)
    local t, any = {}, false
    for wid, key in pairs(activeCache[p] or {}) do t[wid] = key; any = true end
    if any then setElementData(p, "tttWSkins", t) else removeElementData(p, "tttWSkins") end
end

local function sendToClient(p)
    local list = {}
    for k in pairs(ownedCache[p] or {}) do list[#list + 1] = k end
    triggerClientEvent(p, "ttt:receiveWeaponSkins", p, list, activeCache[p] or {})
end

-- Skin felvétele / levétele egy fegyverre (key = nil -> levétel)
local function applyWeaponSkin(p, wid, key, save)
    activeCache[p] = activeCache[p] or {}
    activeCache[p][wid] = key
    syncData(p)
    if save == false then return end
    local h = db()
    if not h then return end
    if key then
        dbExec(h, "REPLACE INTO active_weapon_skins (player_name, weapon_id, skin_key) VALUES (?, ?, ?)", getPlayerName(p), wid, key)
    else
        dbExec(h, "DELETE FROM active_weapon_skins WHERE player_name = ? AND weapon_id = ?", getPlayerName(p), wid)
    end
end

local function loadWeaponSkins(p)
    if not isElement(p) then return end
    whenReady(function()
        local h = db()
        if not h or not isElement(p) then return end
        local name = getPlayerName(p)
        dbQuery(function(qh, player)
            local res = dbPoll(qh, 0)
            if not isElement(player) then return end
            local owned = {}
            for _, row in ipairs(res or {}) do
                local wid = tonumber(row.weapon_id)
                if WSkinByKey[row.skin_key] and WSkinWeaponByID[wid] then owned[ownKey(wid, row.skin_key)] = true end
            end
            ownedCache[player] = owned
            dbQuery(function(qh2, player2)
                local res2 = dbPoll(qh2, 0)
                if not isElement(player2) then return end
                local active = {}
                for _, row in ipairs(res2 or {}) do
                    local wid = tonumber(row.weapon_id)
                    if owned[ownKey(wid, row.skin_key)] then active[wid] = row.skin_key end
                end
                activeCache[player2] = active
                syncData(player2)
                sendToClient(player2)
            end, {player}, h, "SELECT weapon_id, skin_key FROM active_weapon_skins WHERE player_name = ?", getPlayerName(player))
        end, {p}, h, "SELECT weapon_id, skin_key FROM owned_weapon_skins WHERE player_name = ?", name)
    end)
end

addEvent("ttt:requestWeaponSkins", true)
addEventHandler("ttt:requestWeaponSkins", root, function() loadWeaponSkins(client or source) end)
addEventHandler("ttt:onPlayerLoaded", root, function() loadWeaponSkins(source) end)
addEventHandler("onPlayerQuit", root, function() ownedCache[source] = nil; activeCache[source] = nil end)

-- A "tttWSkins" elementData-t csak a szerver állíthatja
addEventHandler("onElementDataChange", root, function(key, oldValue)
    if key == "tttWSkins" and client then
        if oldValue == nil then removeElementData(source, key) else setElementData(source, key, oldValue) end
    end
end)

-----------------------------------------
-- VÁSÁRLÁS (ttt-shop FEGYVERSKIN fül): a kliens csak a fegyver ID-t és a kulcsot küldi
-----------------------------------------
addEvent("ttt:buyWeaponSkin", true)
addEventHandler("ttt:buyWeaponSkin", root, function(wid, key)
    local p = client
    if not p then return end
    wid = tonumber(wid)
    local t, w = WSkinByKey[key], WSkinWeaponByID[wid]
    if not t or not w then return end
    local owned = ownedCache[p]
    if not owned then return msg(p, "#d9534f[Fegyverskin] #ffffffAz adataid még töltődnek, próbáld újra pár másodperc múlva!") end
    if owned[ownKey(wid, key)] then
        return msg(p, "#f1c40f[Fegyverskin] #ffffffEz már a tiéd! Felvenni az #00c3ffF4 #ffffffskin menü #00c3ff[4] #fffffffülén tudod.")
    end
    if not isWeaponSkinInSeason(key) then
        return msg(p, "#f1c40f[Fegyverskin] #ffffffEz a skin most nem vásárolható, csak a saját szezonjában!")
    end
    local price = getWeaponSkinPrice(wid, key)
    if getPlayerMoney(p) < price then
        return msg(p, "#d9534f[Fegyverskin] #ffffffNincs elég pénzed! ($" .. price .. ")")
    end
    local h = db()
    if not h then return msg(p, "#d9534f[Fegyverskin] #ffffffAz adatbázis most nem elérhető, próbáld később!") end

    takePlayerMoney(p, price)
    local name, fullName = getPlayerName(p), getWeaponSkinName(wid, key)
    dbExec(h, "INSERT IGNORE INTO owned_weapon_skins (player_name, weapon_id, skin_key, price) VALUES (?, ?, ?, ?)", name, wid, key, price)
    dbExec(h, "INSERT INTO shop_logs (player, action, cost) VALUES (?, ?, ?)", name, "Fegyverskin: " .. fullName, price)
    local dc = getResourceFromName("ttt-dc")
    if dc and getResourceState(dc) == "running" then
        exports["ttt-dc"]:sendMoneyLog("FEGYVERSKIN BOLT", name, "Vett: " .. fullName, price)
    end

    owned[ownKey(wid, key)] = true
    applyWeaponSkin(p, wid, key)   -- vásárlás után rögtön fel is veszi
    sendToClient(p)
    msg(p, "#7cc576[Fegyverskin] #ffffffSikeres vásárlás és felvétel: #00c3ff" .. fullName)
end)

-----------------------------------------
-- KIVÁLASZTÁS (F4 skin menü [4] fül): key = "none" -> levétel
-----------------------------------------
addEvent("ttt:setWeaponSkin", true)
addEventHandler("ttt:setWeaponSkin", root, function(wid, key)
    local p = client
    if not p then return end
    wid = tonumber(wid)
    local w = WSkinWeaponByID[wid]
    if not w then return end
    if key == "none" or key == nil then
        applyWeaponSkin(p, wid, nil)
        sendToClient(p)
        return msg(p, "#7cc576[Fegyverskin] #ffffffSkin levéve: #00c3ff" .. w.name)
    end
    if not WSkinByKey[key] then return end
    if not (ownedCache[p] and ownedCache[p][ownKey(wid, key)]) then
        return msg(p, "#d9534f[Fegyverskin] #ffffffEz a skin még nincs meg! Az #00c3ffF3 #ffffffshop #00c3ffFEGYVERSKIN #fffffffülén veheted meg.")
    end
    applyWeaponSkin(p, wid, key)
    sendToClient(p)
    msg(p, "#7cc576[Fegyverskin] #ffffffSkin felvéve: #00c3ff" .. getWeaponSkinName(wid, key))
end)

-----------------------------------------
-- EXPORTOK a ttt-adminnak (/giveweaponskin)
-- key = "all" -> az összes téma az adott fegyverre; wid = "all" -> az adott téma minden fegyverre
-----------------------------------------
function giveWeaponSkin(p, wid, key)
    if not isElement(p) then return false end
    local h = db()
    if not h then return false end
    local weapons, keys = {}, {}
    if wid == "all" then for _, w in ipairs(WSkinWeapons) do weapons[#weapons + 1] = w[1] end
    elseif WSkinWeaponByID[tonumber(wid)] then weapons[1] = tonumber(wid)
    else return false end
    if key == "all" then for _, t in ipairs(WSkinThemes) do keys[#keys + 1] = t.key end
    elseif WSkinByKey[key] then keys[1] = key
    else return false end

    ownedCache[p] = ownedCache[p] or {}
    local name = getPlayerName(p)
    for _, w in ipairs(weapons) do
        for _, k in ipairs(keys) do
            dbExec(h, "INSERT IGNORE INTO owned_weapon_skins (player_name, weapon_id, skin_key, price) VALUES (?, ?, ?, 0)", name, w, k)
            ownedCache[p][ownKey(w, k)] = true
        end
    end
    sendToClient(p)
    if #weapons == 1 and #keys == 1 then return getWeaponSkinName(weapons[1], keys[1]) end
    return #weapons * #keys .. " db fegyverskin"
end

function getWeaponSkinKeys()
    local keys = {}
    for i, t in ipairs(WSkinThemes) do keys[i] = t.key end
    return keys
end

function getWeaponSkinWeaponIDs()
    local ids = {}
    for i, w in ipairs(WSkinWeapons) do ids[i] = w[1] .. "=" .. w[2] end
    return ids
end
