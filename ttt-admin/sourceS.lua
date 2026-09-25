-----------------------------------------
-- TTT ADMIN RENDSZER
-- Admin szint kulcs: "admin" elementData (0-3), az adatbázisban users.adminLevel
-----------------------------------------

-- Tulajdonosok serial alapján (név alapján NEM adunk jogot, mert azt bárki felveheti!)
local OWNER_SERIALS = {
    ["F2922808DBCADF044A74BF867CF5BC43"] = true, -- Paddy
}

local adminRanks = {
    [1] = {name = "Admin",      color = "#36a864"},
    [2] = {name = "Főadmin",    color = "#39aef7"},
    [3] = {name = "Tulajdonos", color = "#db594b"},
}

local roleNames = { traitor = "Traitor", detective = "Detective", innocent = "Innocent" }

-----------------------------------------
-- SEGÉDFÜGGVÉNYEK
-----------------------------------------
local function isConsole(p)
    return not p or getElementType(p) == "console"
end

-- Admin szint: konzol = 3
local function getLevel(p)
    if isConsole(p) then return 3 end
    return tonumber(getElementData(p, "admin")) or 0
end

local function nameOf(p)
    return isConsole(p) and "Konzol" or getPlayerName(p)
end

-- Üzenet játékosnak vagy konzolnak (színkódok automatikusan lekerülnek konzolon)
local function msg(p, text)
    if isConsole(p) then
        print((text:gsub("#%x%x%x%x%x%x", "")))
    else
        outputChatBox(text, p, 255, 255, 255, true)
    end
end

local function err(p, text)  msg(p, "#d9534f[Hiba] #ffffff" .. text) end
local function ok(p, text)   msg(p, "#7cc576[Admin] #ffffff" .. text) end
local function usage(p, text) msg(p, "#f1c40f[Használat] #ffffff" .. text) end

-- Jogosultság ellenőrzés; hiba esetén üzen és false-t ad
local function requireLevel(p, lvl)
    if getLevel(p) >= lvl then return true end
    err(p, "Nincs jogosultságod! (Szükséges admin szint: " .. lvl .. ")")
    return false
end

-- Játékos keresése (pontos név, majd névrészlet)
function findPlayer(name)
    if not name then return false end
    local target = getPlayerFromName(name)
    if target then return target end
    name = name:lower()
    for _, p in ipairs(getElementsByType("player")) do
        if getPlayerName(p):lower():find(name, 1, true) then return p end
    end
    return false
end

-- Legközelebbi ped adott távolságon belül
local function getNearestPed(p, maxDist)
    local x, y, z = getElementPosition(p)
    local nearest, minDist = nil, maxDist
    for _, ped in ipairs(getElementsByType("ped")) do
        local dist = getDistanceBetweenPoints3D(x, y, z, getElementPosition(ped))
        if dist < minDist then minDist, nearest = dist, ped end
    end
    return nearest
end

-- Admin szint beállítása + azonnali mentés az adatbázisba
local function setAdminLevel(target, level)
    setElementData(target, "admin", level)
    local id = getElementData(target, "charID")
    if id then
        exports["ttt-sql"]:dbQueryExec("UPDATE users SET adminLevel = ? WHERE ID = ?", level, id)
    end
end

-----------------------------------------
-- SQL + DISCORD LOG
-----------------------------------------
function logAdminAction(adminName, command, targetName, details)
    exports["ttt-sql"]:dbQueryExec("INSERT INTO admin_commands (admin_name, command, target_name, action_details) VALUES (?, ?, ?, ?)",
        tostring(adminName), tostring(command), tostring(targetName), tostring(details))

    local dc = getResourceFromName("ttt-dc")
    if dc and getResourceState(dc) == "running" then
        if command == "setadmin" then
            exports["ttt-dc"]:sendAdminLog(adminName, targetName, details, details)
        elseif command == "Pénz beállítása" or command == "Pénz adása" or command == "Pénz levonása" then
            exports["ttt-dc"]:sendMoneyLog(adminName, targetName, command, details)
        elseif command == "Skin adása" then
            exports["ttt-dc"]:sendSkinLog(adminName, targetName, details)
        end
    end
end

-----------------------------------------
-- BELÉPÉS: tulajdonos jog serial alapján
-----------------------------------------
-- A ttt-login akkor küldi, amikor a fiók betöltődött az adatbázisból
addEvent("ttt:onPlayerLoaded", false)
addEventHandler("ttt:onPlayerLoaded", root, function()
    local p = source
    if OWNER_SERIALS[getPlayerSerial(p)] and getLevel(p) < 3 then setAdminLevel(p, 3) end
end)

-- /fixadmin - a tulajdonos bármikor visszakapja a 3-as szintet (CSAK az OWNER_SERIALS-ban lévő serialok)
addCommandHandler("fixadmin", function(p)
    if isConsole(p) then return end
    if not OWNER_SERIALS[getPlayerSerial(p)] then
        return err(p, "Ez a parancs csak a szerver tulajdonosának elérhető!")
    end
    setAdminLevel(p, 3)
    outputChatBox("#7cc576[AdminSystem] #ffffffVisszakaptad a tulajdonosi jogot (3).", p, 255, 255, 255, true)
    logAdminAction(getPlayerName(p), "fixadmin", getPlayerName(p), "Tulajdonos (3)")
end)

-----------------------------------------
-- ADMIN PARANCSOK
-----------------------------------------

-- /setadmin [Név] [0-3]  (Főadmin+)
addCommandHandler("setadmin", function(p, cmd, targetName, level)
    if not requireLevel(p, 2) then return end
    local target, lvl = findPlayer(targetName), tonumber(level)
    if not target or not lvl or lvl < 0 or lvl > 3 then
        return usage(p, "/setadmin [Név] [0-3]")
    end
    -- Saját szintnél magasabbat csak konzol / tulajdonos adhat
    if not isConsole(p) and lvl > getLevel(p) then
        return err(p, "Nem adhatsz a sajátodnál magasabb szintet!")
    end

    setAdminLevel(target, lvl)
    local rankName = adminRanks[lvl] and adminRanks[lvl].name or "Játékos"
    ok(p, getPlayerName(target) .. " rangja beállítva: " .. rankName)
    outputChatBox("#7cc576[AdminSystem] #ffffffAz admin szinted módosítva lett: " .. rankName .. " (" .. lvl .. ")", target, 255, 255, 255, true)
    logAdminAction(nameOf(p), "setadmin", getPlayerName(target), rankName .. " (" .. lvl .. ")")
end)

-- Admin / Főadmin chat közös kezelője
local function adminChat(p, text, minLevel, tag, tagColor)
    if text == "" or getLevel(p) < minLevel then return end
    local lvl = getLevel(p)
    local prefix = isConsole(p) and "#ff0000[Konzol]" or (adminRanks[lvl].color .. "[" .. adminRanks[lvl].name .. "]")
    for _, target in ipairs(getElementsByType("player")) do
        if getLevel(target) >= minLevel then
            outputChatBox(tagColor .. "[" .. tag .. "] " .. prefix .. " #ffffff" .. nameOf(p) .. ": " .. text, target, 255, 255, 255, true)
        end
    end
    outputServerLog("[" .. tag .. "] " .. nameOf(p) .. ": " .. text)
end

-- /a [üzenet]  /fa [üzenet]
addCommandHandler("a",  function(p, cmd, ...) adminChat(p, table.concat({...}, " "), 1, "AdminChat",   "#4ae850") end)
addCommandHandler("fa", function(p, cmd, ...) adminChat(p, table.concat({...}, " "), 2, "FőadminChat", "#39aef7") end)

-- Chat prefixek: rang szín + név
addEventHandler("onPlayerChat", root, function(message, messageType)
    if messageType ~= 0 then return end
    cancelEvent()
    local lvl = getLevel(source)
    local pName = getPlayerName(source)
    local rank = adminRanks[lvl]
    if rank then
        outputChatBox(rank.color .. "[" .. rank.name .. "] #ffffff" .. pName .. ": " .. message, root, 255, 255, 255, true)
    else
        outputChatBox("#ffffff" .. pName .. ": " .. message, root, 255, 255, 255, true)
    end
    outputServerLog("CHAT: " .. pName .. ": " .. message)
end)

-----------------------------------------
-- PÉNZKEZELÉS (Admin+)
-----------------------------------------
local function moneyCommand(p, targetName, amount, mode)
    if not requireLevel(p, 1) then return end
    local target, amt = findPlayer(targetName), tonumber(amount)
    if not target or not amt or (mode ~= "set" and amt <= 0) then
        return usage(p, "/" .. (mode == "set" and "setmoney" or mode == "give" and "givemoney" or "revokemoney") .. " [Név] [Összeg]" .. (mode ~= "set" and " (pozitív szám)" or ""))
    end
    local tName = getPlayerName(target)

    if mode == "set" then
        setPlayerMoney(target, amt)
        ok(p, tName .. " pénze beállítva: $" .. amt)
        outputChatBox("#7cc576[Pénz] #ffffffAz új egyenleged: $" .. amt, target, 255, 255, 255, true)
        logAdminAction(nameOf(p), "Pénz beállítása", tName, "$" .. amt)
    elseif mode == "give" then
        givePlayerMoney(target, amt)
        ok(p, "Adtál $" .. amt .. " összeget neki: " .. tName)
        outputChatBox("#7cc576[Pénz] #ffffffKaptál $" .. amt .. " összeget!", target, 255, 255, 255, true)
        logAdminAction(nameOf(p), "Pénz adása", tName, "$" .. amt)
    else
        setPlayerMoney(target, math.max(0, getPlayerMoney(target) - amt))
        ok(p, "Levontál $" .. amt .. " összeget tőle: " .. tName)
        outputChatBox("#d9534f[Pénz] #ffffffLevontak tőled $" .. amt .. " összeget!", target, 255, 255, 255, true)
        logAdminAction(nameOf(p), "Pénz levonása", tName, "-$" .. amt)
    end
end

addCommandHandler("setmoney",    function(p, cmd, t, a) moneyCommand(p, t, a, "set") end)
addCommandHandler("givemoney",   function(p, cmd, t, a) moneyCommand(p, t, a, "give") end)
addCommandHandler("revokemoney", function(p, cmd, t, a) moneyCommand(p, t, a, "revoke") end)

-----------------------------------------
-- EGYÉB ADMIN PARANCSOK
-----------------------------------------

-- /getpos (Admin+)
addCommandHandler("getpos", function(p)
    if isConsole(p) or not requireLevel(p, 1) then return end
    local x, y, z = getElementPosition(p)
    local posString = string.format("%.3f, %.3f, %.3f", x, y, z)
    outputChatBox(string.format("#f1c40f[GetPos] #ffffffPozíció: %s | Int: %d | Dim: %d | Rot: %.1f",
        posString, getElementInterior(p), getElementDimension(p), getPedRotation(p)), p, 255, 255, 255, true)
    outputConsole("Kódhoz másolható: " .. posString, p)
end)

-- /freeze [Név] (Admin+) - név nélkül saját magad
addCommandHandler("freeze", function(p, cmd, targetName)
    if not requireLevel(p, 1) then return end
    local target = targetName and findPlayer(targetName) or (not isConsole(p) and p)
    if not target then return err(p, "Nem található ilyen nevű játékos!") end

    local frozen = not isElementFrozen(target)
    setElementFrozen(target, frozen)
    local status = frozen and "lefagyasztva" or "kiolvasztva"
    ok(p, getPlayerName(target) .. " " .. status .. ".")
    if target ~= p then
        outputChatBox("#d9534f[Admin] #ffffffEgy admin " .. status .. " téged.", target, 255, 255, 255, true)
    end
end)

-- /kick [Név] [Indok] (Admin+)
addCommandHandler("kick", function(p, cmd, targetName, ...)
    if not requireLevel(p, 1) then return end
    if not targetName then return usage(p, "/kick [Név] [Indok]") end
    local target = findPlayer(targetName)
    if not target then return err(p, "Játékos nem található!") end

    local reason = table.concat({...}, " ")
    if reason == "" then reason = "Nincs megadva indok." end
    outputChatBox("#d9534f[Kick] #ffffff" .. getPlayerName(target) .. " ki lett rúgva. Indok: " .. reason, root, 255, 255, 255, true)
    logAdminAction(nameOf(p), "kick", getPlayerName(target), reason)
    kickPlayer(target, isConsole(p) and "Console" or p, reason)
end)

-- /teams (Főadmin+)
addCommandHandler("teams", function(p)
    if not requireLevel(p, 2) then return end
    msg(p, "#7cc576[TTT-Admin] #ffffffAktuális csapatok:")
    local colors = { Traitor = "#e74c3c", Detective = "#3498db", Innocent = "#2ecc71" }
    for _, pl in ipairs(getElementsByType("player")) do
        local role = getElementData(pl, "tttRole") or "Nincs"
        msg(p, "- " .. getPlayerName(pl) .. ": " .. (colors[role] or "#aaaaaa") .. tostring(role))
    end
end)

-- /setteam [Név] [traitor/detective/innocent] (Főadmin+)
addCommandHandler("setteam", function(p, cmd, targetPart, newRole)
    if not requireLevel(p, 2) then return end
    if not targetPart or not newRole then return usage(p, "/setteam [Név részlet] [traitor/detective/innocent]") end
    local target = findPlayer(targetPart)
    if not target then return err(p, "Játékos nem található!") end
    local role = roleNames[newRole:lower()]
    if not role then return err(p, "Érvénytelen szerep!") end

    setElementData(target, "tttRole", role)
    ok(p, "Sikeresen módosítva: " .. getPlayerName(target) .. " -> " .. role)
    outputChatBox("#7cc576[TTT-Admin] #ffffffEgy admin megváltoztatta a szerepedet: #f1c40f" .. role, target, 255, 255, 255, true)
    exports["ttt-core"]:checkTTTWin()
end)

-- /sethp [Név] [0-100] (Admin+)
addCommandHandler("sethp", function(p, cmd, targetPart, hpValue)
    if not requireLevel(p, 1) then return end
    local hp = tonumber(hpValue)
    if not targetPart or not hp then return usage(p, "/sethp [Név részlet] [Érték]") end
    local target = findPlayer(targetPart)
    if not target then return err(p, "Játékos nem található!") end

    hp = math.max(0, math.min(hp, 100))
    setElementHealth(target, hp)
    ok(p, getPlayerName(target) .. " életereje átállítva: " .. hp .. "%")
    outputChatBox("#7cc576[TTT-Admin] #ffffffEgy admin átállította az életerőd: #f1c40f" .. hp .. "%", target, 255, 255, 255, true)
end)

-----------------------------------------
-- NPC TESZT PARANCSOK
-----------------------------------------

-- /npc (Admin+) - lerak egy "Trevi" NPC-t
addCommandHandler("npc", function(p)
    if isConsole(p) or not requireLevel(p, 1) then return end
    if isPedInVehicle(p) then return end
    local x, y, z = getElementPosition(p)
    local _, _, rot = getElementRotation(p)
    local npc = createPed(0, x + 1, y, z)
    if not npc then return end
    setElementRotation(npc, 0, 0, rot + 180)
    setElementInterior(npc, getElementInterior(p))
    setElementDimension(npc, getElementDimension(p))
    setElementFrozen(npc, true)
    setElementData(npc, "npcName", "Trevi")
    ok(p, "Trevi NPC lerakva!")
end)

-- /npcrole [traitor/detective/innocent] (Főadmin+) - legközelebbi NPC szerepe
addCommandHandler("npcrole", function(p, cmd, newRole)
    if isConsole(p) or not requireLevel(p, 2) then return end
    if not newRole then return usage(p, "/npcrole [traitor/detective/innocent]") end
    local role = roleNames[newRole:lower()]
    if not role then return err(p, "Érvénytelen szerep!") end
    local ped = getNearestPed(p, 4)
    if not ped then return err(p, "Nincs NPC a közeledben!") end
    setElementData(ped, "tttRole", role)
    ok(p, "NPC szerep beállítva: " .. role)
end)

-- /npcadmin [0-3] (Főadmin+) - legközelebbi NPC admin rangja (nametag teszt)
addCommandHandler("npcadmin", function(p, cmd, level)
    if isConsole(p) or not requireLevel(p, 2) then return end
    local lvl = tonumber(level)
    if not lvl or lvl < 0 or lvl > 3 then return usage(p, "/npcadmin [0-3]") end
    local ped = getNearestPed(p, 5)
    if not ped then return err(p, "Nincs NPC a közeledben!") end
    setElementData(ped, "admin", lvl)
    ok(p, "NPC rang frissítve: " .. lvl)
end)

-- /reveal (Főadmin+) - admin látmód: mindenki szerepe látszik a nametagen
addCommandHandler("reveal", function(p)
    if isConsole(p) or not requireLevel(p, 2) then return end
    local newState = not getElementData(p, "adminVision")
    setElementData(p, "adminVision", newState)
    outputChatBox("#00c3ff[Admin-Vision] #ffffffÖsszes szerep mutatása: " .. (newState and "#7cc576BEKAPCSOLVA" or "#d9534fKIKAPCSOLVA"), p, 255, 255, 255, true)
    logAdminAction(getPlayerName(p), "reveal", getPlayerName(p), newState and "ON" or "OFF")
end)

-----------------------------------------
-- SKIN PARANCSOK
-----------------------------------------

-- /giveskin [Név] [SkinID] [Skin neve...] (Admin+)
addCommandHandler("giveskin", function(p, cmd, targetName, skinID, ...)
    if not requireLevel(p, 1) then return end
    local skinName = table.concat({...}, " ")
    local sID = tonumber(skinID)
    local target = findPlayer(targetName)
    if not target or not sID or #skinName == 0 then
        return usage(p, "/giveskin [Név] [ID] [Skin neve]")
    end
    local tName = getPlayerName(target)

    exports["ttt-sql"]:dbQueryExec("INSERT INTO owned_skins (player_name, skin_id, skin_name, price) VALUES (?, ?, ?, 0)", tName, sID, skinName)
    triggerEvent("ttt:requestOwnedSkins", target) -- a ttt-skin frissíti a játékos listáját

    ok(p, "Adtál egy skint (" .. skinName .. ") neki: " .. tName)
    outputChatBox("#7cc576[Skin] #ffffffKaptál egy új skint az admintól: #7cc576" .. skinName, target, 255, 255, 255, true)
    logAdminAction(nameOf(p), "Skin adása", tName, "ID: " .. sID .. " | Név: " .. skinName)
end)

-- /pskin [ID] (Főadmin+) - skin előnézet saját magadon
addCommandHandler("pskin", function(p, cmd, skinID)
    if isConsole(p) or not requireLevel(p, 2) then return end
    local sID = tonumber(skinID)
    if not sID then return usage(p, "/pskin [ID]") end
    if not setElementModel(p, sID) then return err(p, "Érvénytelen skin ID!") end
    outputChatBox("#00c3ff[Preview-Skin] #ffffffSkin ideiglenesen megváltoztatva: #7cc576" .. sID, p, 255, 255, 255, true)
    outputDebugString("[Admin] " .. getPlayerName(p) .. " pskin-t használt. (Új: " .. sID .. ")")
end)
