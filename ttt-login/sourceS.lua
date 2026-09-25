-----------------------------------------
-- TTT LOGIN - serial alapú fiók, egy név = egy fiók
-----------------------------------------
local START_MONEY = 1000
local START_SKIN = 0
local SPAWN = {1948.875, -1713.143, 13.547}

-- Megjegyzés: a callback-es lekérdezéseket közvetlenül a DB handlerrel futtatjuk,
-- mert MTA-ban exportokon keresztül nem lehet függvényt (callback-et) átadni.
local function getDB()
    return exports["ttt-sql"]:getDatabaseHandler()
end

local function isValidName(name)
    -- 3-22 karakter, csak betű/szám/_ . [ ] - (MTA nickname szabály közeli)
    return type(name) == "string" and #name >= 3 and #name <= 22 and name:match("^[%w_%.%[%]%-]+$") ~= nil
end

local function setupPlayerAccount(player, data)
    if not isElement(player) then return end
    local admin = tonumber(data.adminLevel) or 0
    local accName = data["Név"]

    -- A fiók neve a hivatalos név: ha más nickkel jött be, visszaállítjuk
    if getPlayerName(player) ~= accName then
        -- Ha valaki más épp ezt a nevet használja (bitorló, akinek Guest fiókja van), kirúgjuk
        local impostor = getPlayerFromName(accName)
        if impostor and impostor ~= player then
            kickPlayer(impostor, "A(z) " .. accName .. " név a fiók tulajdonosáé!")
        end
        setPlayerName(player, accName)
        outputChatBox("#f1c40f[TTT] #ffffffA neved a fiókod nevére lett állítva: " .. accName, player, 255, 255, 255, true)
    end

    setElementData(player, "charID", data.ID)
    setElementData(player, "accName", accName)
    setElementData(player, "admin", admin)        -- egységes kulcs: minden resource ezt használja
    setElementData(player, "money", tonumber(data.Money) or 0)

    setPlayerMoney(player, tonumber(data.Money) or 0)
    spawnPlayer(player, SPAWN[1], SPAWN[2], SPAWN[3], 0, START_SKIN)
    fadeCamera(player, true)
    setCameraTarget(player, player)
    triggerEvent("ttt:onPlayerLoaded", player, data.ID)
end

local function loadPlayer(player, serial, isNew)
    local db = getDB()
    if not db or not isElement(player) then return end
    dbQuery(function(qh, p)
        if not isElement(p) then return end
        local res = dbPoll(qh, 0)
        if res and res[1] then
            setupPlayerAccount(p, res[1])
            outputChatBox(isNew and "#7cc576[TTT] #ffffffSikeres automatikus regisztráció!" or "#7cc576[TTT] #ffffffÜdv újra a szerveren!", p, 255, 255, 255, true)
        end
    end, {player}, db, "SELECT * FROM users WHERE Serial = ? LIMIT 1", serial)
end

-- Új fiók: a belépéskori nick lesz a fiók neve, ha szabad; különben Guest_XXXX
local function registerPlayer(player, serial, db)
    local wantedName = getPlayerName(player)
    if not isValidName(wantedName) then wantedName = "Guest_" .. math.random(1000, 9999) end

    dbQuery(function(qh, p)
        if not isElement(p) then return end
        local res = dbPoll(qh, 0)
        local finalName = wantedName
        if res and #res > 0 then
            -- Ez a név már valaki másé -> nem lehet két Paddy
            finalName = "Guest_" .. math.random(1000, 9999)
            outputChatBox("#d9534f[TTT] #ffffffA(z) " .. wantedName .. " név már foglalt egy másik fiók által! Ideiglenes neved: " .. finalName, p, 255, 255, 255, true)
        end
        dbQuery(function(qh2, p2)
            local _, affected = dbPoll(qh2, 0)
            if affected and affected > 0 then
                loadPlayer(p2, serial, true)
            else
                outputDebugString("[TTT-Login] Regisztráció sikertelen: " .. serial, 1)
            end
        end, {p}, db, "INSERT INTO users (`Név`, `adminLevel`, `Serial`, `Money`, `Kill`, `PremiumPoint`) VALUES (?, 0, ?, ?, 0, 0)",
            finalName, serial, START_MONEY)
    end, {player}, db, "SELECT ID FROM users WHERE `Név` = ? LIMIT 1", wantedName)
end

addEventHandler("onPlayerJoin", root, function()
    local player = source
    local serial = getPlayerSerial(player)
    local db = getDB()
    if not db then
        outputChatBox("#d9534f[TTT] #ffffffAz adatbázis nem elérhető, próbálj újracsatlakozni!", player, 255, 255, 255, true)
        return
    end

    -- Ha valaki más már bent van ugyanezzel a serial-lal (dupla kliens), kirúgjuk az újat
    for _, other in ipairs(getElementsByType("player")) do
        if other ~= player and getPlayerSerial(other) == serial then
            return kickPlayer(player, "Ezzel a fiókkal már valaki bent van a szerveren!")
        end
    end

    dbQuery(function(qh, p)
        if not isElement(p) then return end
        local res = dbPoll(qh, 0)
        if res and #res > 0 then
            loadPlayer(p, serial, false)
        else
            registerPlayer(p, serial, db)
        end
    end, {player}, db, "SELECT ID FROM users WHERE Serial = ? LIMIT 1", serial)
end)

-- Névváltás tiltása: a fiók neve a hivatalos (a setPlayerName-ünk a "setupPlayerAccount"-ból engedett)
local allowRename = {}
addEventHandler("onPlayerChangeNick", root, function(oldNick, newNick)
    if allowRename[source] then return end
    local accName = getElementData(source, "accName")
    if accName and newNick ~= accName then
        cancelEvent()
        outputChatBox("#d9534f[TTT] #ffffffA neved a fiókodhoz van kötve, nem változtathatod meg.", source, 255, 255, 255, true)
    end
end)

-- /changename [újnév] - saját fióknév módosítása, ha szabad (költség nélkül)
addCommandHandler("changename", function(player, cmd, newName)
    local id = getElementData(player, "charID")
    if not id then return end
    if not isValidName(newName) then
        return outputChatBox("#d9534f[TTT] #ffffffHasználat: /changename [3-22 karakter, betű/szám/_]", player, 255, 255, 255, true)
    end
    local db = getDB()
    if not db then return end
    dbQuery(function(qh, p)
        if not isElement(p) then return end
        local res = dbPoll(qh, 0)
        if res and #res > 0 then
            return outputChatBox("#d9534f[TTT] #ffffffEz a név már foglalt!", p, 255, 255, 255, true)
        end
        exports["ttt-sql"]:dbQueryExec("UPDATE users SET `Név` = ? WHERE ID = ?", newName, id)
        allowRename[p] = true
        setPlayerName(p, newName)
        allowRename[p] = nil
        setElementData(p, "accName", newName)
        outputChatBox("#7cc576[TTT] #ffffffÚj neved: " .. newName, p, 255, 255, 255, true)
    end, {player}, db, "SELECT ID FROM users WHERE `Név` = ? AND ID <> ? LIMIT 1", newName, id)
end)

local function savePlayer(player)
    local id = getElementData(player, "charID")
    if not id then return end
    exports["ttt-sql"]:dbQueryExec("UPDATE users SET Money = ?, adminLevel = ? WHERE ID = ?",
        getPlayerMoney(player), getElementData(player, "admin") or 0, id)
end

addEventHandler("onPlayerQuit", root, function()
    savePlayer(source)
    allowRename[source] = nil
end)

-- Resource leállításakor (pl. restart) mindenkit mentünk, hogy ne vesszen el a pénz
addEventHandler("onResourceStop", resourceRoot, function()
    for _, p in ipairs(getElementsByType("player")) do savePlayer(p) end
end)

-- Biztonsági mentés 5 percenként
setTimer(function()
    for _, p in ipairs(getElementsByType("player")) do savePlayer(p) end
end, 300000, 0)
