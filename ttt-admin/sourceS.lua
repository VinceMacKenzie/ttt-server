local spawnX, spawnY, spawnZ = 1948.875, -1713.143, 13.547
function joinHandler()
	spawnPlayer(source, spawnX, spawnY, spawnZ)
	fadeCamera(source, true)
	setCameraTarget(source, source)
	
    local playerName = getPlayerName(source)
    if playerName == "Paddy" then
        -- Beállítjuk neki a 3-as szintet (Tulajdonos)
        setElementData(source, "admin", 3)
        setPlayerMoney(source, 500000)
        setElementData(source, "tttRole", "Traitor")
        setElementModel(source, 248)
    end
end
addEventHandler("onPlayerJoin", getRootElement(), joinHandler)

-- Admin rangok és színek definíciója
local adminRanks = {
    [1] = {name = "Admin", color = "#36a864"},
    [2] = {name = "Főadmin", color = "#39aef7"},
    [3] = {name = "Tulajdonos", color = "#db594b"}
}

-- SEGÉDFÜGGVÉNY: Játékos keresése (részletre is)
function findPlayer(name)
    if not name then return false end
    local target = getPlayerFromName(name)
    if target then return target end
    for _, p in ipairs(getElementsByType("player")) do
        if string.find(getPlayerName(p):lower(), name:lower(), 1, true) then
            return p
        end
    end
    return false
end

-----------------------------------------
-- 0. SQL + DC
-----------------------------------------

function logAdminAction(adminName, command, targetName, details)
    -- 1. SQL MENTÉS (Változatlan)
    if exports["ttt-sql"] then
        exports["ttt-sql"]:dbQueryExec("INSERT INTO admin_commands (admin_name, command, target_name, action_details) VALUES (?, ?, ?, ?)", 
            tostring(adminName), tostring(command), tostring(targetName), tostring(details))
    end

    -- 2. DISCORD MENTÉS
    if exports["ttt-dc"] then
        if command == "setadmin" then
            exports["ttt-dc"]:sendAdminLog(adminName, targetName, details, details)
        elseif command == "Pénz beállítása" or command == "Pénz adása" or command == "Pénz levonása" then
            exports["ttt-dc"]:sendMoneyLog(adminName, targetName, command, details)
        elseif command == "Skin adása" then
            -- Új ág a skineknek
            exports["ttt-dc"]:sendSkinLog(adminName, targetName, details)
        end
    end
end

-----------------------------------------
-- 1. ADMIN RENDSZER PARANCSOK
-----------------------------------------

-- /setadmin [Név] [Szint]
addCommandHandler("setadmin", function(sourceElement, cmd, targetName, level)
    local canAccess = false
    
    -- Konzol vagy Főadmin+ jogosultság ellenőrzése
    if (not sourceElement or getElementType(sourceElement) == "console") then 
        canAccess = true 
    else
        local pLevel = getElementData(sourceElement, "admin") or 0
        if pLevel >= 2 then canAccess = true end
    end

    if canAccess then
        if targetName and level then
            local target = findPlayer(targetName)
            local levelNum = tonumber(level)
            
            if target and levelNum and levelNum >= 0 and levelNum <= 3 then
                setElementData(target, "admin", levelNum)
                local rankName = adminRanks[levelNum] and adminRanks[levelNum].name or "Játékos"
                local msg = "[AdminSystem] " .. getPlayerName(target) .. " rangja beállítva: " .. rankName
                
                -- --- DISCORD LOG ELŐKÉSZÍTÉSE ---
                local aName = "Konzol"
                if sourceElement and isElement(sourceElement) then
                    aName = getPlayerName(sourceElement)
                end
                local tName = getPlayerName(target)
                local rName = rankName
                -- -------------------------------

                if not sourceElement or getElementType(sourceElement) == "console" then
                    outputServerLog(msg)
                else
                    outputChatBox("#7cc576" .. msg, sourceElement, 255, 255, 255, true)
                end

                logAdminAction(aName, "setadmin", tName, rankName .. " (" .. levelNum .. ")")
                outputChatBox("#7cc576[AdminSystem] #ffffffAz admin szinted módosítva lett: " .. levelNum, target, 255, 255, 255, true)

            else
                local eMsg = "Hiba: Ervenytelen nev vagy szint (0-3)!"
                if not sourceElement or getElementType(sourceElement) == "console" then print(eMsg) else outputChatBox("#d9534f" .. eMsg, sourceElement, 255, 255, 255, true) end
            end
        else
            local uMsg = "Hasznalat: setadmin [Nev] [0-3]"
            if not sourceElement or getElementType(sourceElement) == "console" then print(uMsg) else outputChatBox("#d9534f" .. uMsg, sourceElement, 255, 255, 255, true) end
        end
    else
        outputChatBox("#d9534f[Hiba] #ffffffNincs ehhez jogosultságod!", sourceElement, 255, 255, 255, true)
    end
end)

-- /a [üzenet] - Admin Chat
addCommandHandler("a", function(player, cmd, ...)
    local msg = table.concat({...}, " ")
    if msg == "" then return end

    local isConsole = (not player or getElementType(player) == "console")
    local pLevel = isConsole and 3 or (getElementData(player, "admin") or 0)

    if pLevel >= 1 then
        local name = isConsole and "Konzol" or getPlayerName(player)
        local prefix = isConsole and "#ff0000[Konzol]" or (adminRanks[pLevel].color .. "[" .. adminRanks[pLevel].name .. "]")
        
        for _, p in ipairs(getElementsByType("player")) do
            if (getElementData(p, "admin") or 0) >= 1 then
                outputChatBox("#4ae850[AdminChat] " .. prefix .. " #ffffff" .. name .. ": " .. msg, p, 255, 255, 255, true)
            end
        end
        outputServerLog("[AdminChat] " .. name .. ": " .. msg)
    end
end)

-- /fa [üzenet] - Főadmin Chat
addCommandHandler("fa", function(player, cmd, ...)
    local msg = table.concat({...}, " ")
    if msg == "" then return end

    local isConsole = (not player or getElementType(player) == "console")
    local pLevel = isConsole and 3 or (getElementData(player, "admin") or 0)

    if pLevel >= 2 then
        local name = isConsole and "Konzol" or getPlayerName(player)
        local prefix = isConsole and "#ff0000[Konzol]" or (adminRanks[pLevel].color .. "[" .. adminRanks[pLevel].name .. "]")
        
        for _, p in ipairs(getElementsByType("player")) do
            if (getElementData(p, "admin") or 0) >= 2 then
                outputChatBox("#39aef7[FőadminChat] " .. prefix .. " #ffffff" .. name .. ": " .. msg, p, 255, 255, 255, true)
            end
        end
        outputServerLog("[FőadminChat] " .. name .. ": " .. msg)
    end
end)

-- Chat prefixek kezelése - TELJES FELÜLBÍRÁLÁS
addEventHandler("onPlayerChat", root, function(message, messageType)
    -- Csak a sima chatet (0) és a játékosoktól jövő üzeneteket nézzük
    if messageType == 0 and not isElement(source) == false then
        local pLevel = getElementData(source, "admin") or 0
        local pName = getPlayerName(source)
        
        -- Minden esetben megállítjuk az alap üzenetet
        cancelEvent()
        
        if pLevel >= 1 then
            -- Ha ADMIN: Rangszín [Rang] + Fehér név
            local rankData = adminRanks[pLevel]
            outputChatBox(rankData.color .. "[" .. rankData.name .. "] #ffffff" .. pName .. ": " .. message, root, 255, 255, 255, true)
        else
            -- Ha JÁTÉKOS: Sima fehér név (így nem lesz duplázódás náluk sem)
            outputChatBox("#ffffff" .. pName .. ": " .. message, root, 255, 255, 255, true)
        end
        
        -- Logolás a konzolba, hogy ne tűnjön el a cancelEvent miatt
        outputServerLog("CHAT: " .. pName .. ": " .. message)
    end
end)

-----------------------------------------
-- 2. PÉNZKEZELŐ PARANCSOK (Főadmin+)
-----------------------------------------

-- SEGÉDFÜGGVÉNY: Jogosultság ellenőrzés (Főadmin+)
local function hasAdminAccess(player)
    if not player or getElementType(player) == "console" then return true end
    return (getElementData(player, "admin") or 0) >= 1
end

-- /setmoney [Név] [Összeg]
addCommandHandler("setmoney", function(player, cmd, targetName, amount)
    if hasAdminAccess(player) then
        local target = findPlayer(targetName)
        local amt = tonumber(amount)
        if target and amt then
            setPlayerMoney(target, amt)
            local msg = "[Money] " .. getPlayerName(target) .. " pénze beállítva: $" .. amt
            if not player or getElementType(player) == "console" then print(msg) else outputChatBox("#7cc576" .. msg, player, 255, 255, 255, true) end
            outputChatBox("#7cc576[Pénz] #ffffffAz új egyenleged: $" .. amt, target, 255, 255, 255, true)
        else
            local eMsg = "Használat: /setmoney [Név] [Összeg]"
            if not player or getElementType(player) == "console" then print(eMsg) else outputChatBox("#d9534f" .. eMsg, player, 255, 255, 255, true) end
        end
        local aName = (not player or getElementType(player) == "console") and "Console" or getPlayerName(player)
        logAdminAction(aName, "Pénz beállítása", getPlayerName(target), "$" .. amt)
    end
end)

-- /givemoney [Név] [Összeg]
addCommandHandler("givemoney", function(player, cmd, targetName, amount)
    if hasAdminAccess(player) then
        local target = findPlayer(targetName)
        local amt = tonumber(amount)
        if target and amt and amt > 0 then
            givePlayerMoney(target, amt)
            local msg = "[Money] Adtál $" .. amt .. " összeget neki: " .. getPlayerName(target)
            if not player or getElementType(player) == "console" then print(msg) else outputChatBox("#7cc576" .. msg, player, 255, 255, 255, true) end
            outputChatBox("#7cc576[Pénz] #ffffffKaptál $" .. amt .. " összeget!", target, 255, 255, 255, true)
        else
            local eMsg = "Használat: /givemoney [Név] [Összeg] (pozitív szám)"
            if not player or getElementType(player) == "console" then print(eMsg) else outputChatBox("#d9534f" .. eMsg, player, 255, 255, 255, true) end
        end
        local aName = (not player or getElementType(player) == "console") and "Console" or getPlayerName(player)

        logAdminAction(aName, "Pénz adása", getPlayerName(target), "$" .. amt)
    end
end)

-- /revokemoney [Név] [Összeg]
addCommandHandler("revokemoney", function(player, cmd, targetName, amount)
    if hasAdminAccess(player) then
        local target = findPlayer(targetName)
        local amt = tonumber(amount)
        if target and amt and amt > 0 then
            local currentMoney = getPlayerMoney(target)
            local newMoney = math.max(0, currentMoney - amt) -- Ne mehessen mínuszba
            setPlayerMoney(target, newMoney)
            
            local msg = "[Money] Levontál $" .. amt .. " összeget tőle: " .. getPlayerName(target)
            if not player or getElementType(player) == "console" then print(msg) else outputChatBox("#7cc576" .. msg, player, 255, 255, 255, true) end
            outputChatBox("#d9534f[Pénz] #ffffffLevontak tőled $" .. amt .. " összeget!", target, 255, 255, 255, true)
        else
            local eMsg = "Használat: /revokemoney [Név] [Összeg] (pozitív szám)"
            if not player or getElementType(player) == "console" then print(eMsg) else outputChatBox("#d9534f" .. eMsg, player, 255, 255, 255, true) end
        end
        local aName = (not player or getElementType(player) == "console") and "Console" or getPlayerName(player)
        logAdminAction(aName, "Pénz levonása", getPlayerName(target), "-$" .. amt)
    end
end)

-- /getpos parancs
addCommandHandler("getpos", function(player, cmd)
    -- Csak Admin (1+) használhassa, hogy ne spammeljék a chatet
    local pLevel = getElementData(player, "admin") or 0
    if pLevel >= 1 then
        local x, y, z = getElementPosition(player)
        local int = getElementInterior(player)
        local dim = getElementDimension(player)
        local rotz = getPedRotation(player) -- A nézési irány is fontos lehet

        -- Megformázzuk a szöveget, hogy könnyen kimásolható legyen a kódba
        local posString = string.format("%.3f, %.3f, %.3f", x, y, z)
        local fullString = string.format("Pozíció: %s | Int: %d | Dim: %d | Rot: %.1f", posString, int, dim, rotz)

        -- Kiírjuk a chatbe
        outputChatBox("#f1c40f[GetPos] #ffffff" .. fullString, player, 255, 255, 255, true)
        
        -- Kiírjuk a konzolba is (F8), mert onnan könnyebb kimásolni a szöveget (Ctrl+C)
        outputConsole("Kódhoz másolható: " .. posString, player)
    else
        outputChatBox("#d9534f[Hiba] #ffffffEhhez a parancshoz admin jogosultság kell!", player, 255, 255, 255, true)
    end
end)

-- /freeze [Név]
addCommandHandler("freeze", function(player, cmd, targetName)
    local pLevel = getElementData(player, "admin") or 0
    
    if pLevel >= 1 then
        -- Ha nem adtál meg nevet, saját magad fagyasztod le
        local target = targetName and findPlayer(targetName) or player
        
        if target then
            local isFrozen = isElementFrozen(target)
            setElementFrozen(target, not isFrozen)
            
            local status = not isFrozen and "lefagyasztva" or "kiolvasztva"
            outputChatBox("#7cc576[Admin] #ffffff" .. getPlayerName(target) .. " " .. status .. ".", player, 255, 255, 255, true)
            if target ~= player then
                outputChatBox("#d9534f[Admin] #ffffffEgy admin " .. status .. " téged.", target, 255, 255, 255, true)
            end
        else
            outputChatBox("#d9534f[Hiba] #ffffffNem található ilyen nevű játékos!", player, 255, 255, 255, true)
        end
    else
        outputChatBox("#d9534f[Hiba] #ffffffNincs jogosultságod! (Admin szinted: " .. pLevel .. ")", player, 255, 255, 255, true)
    end
end)

-- /kick [Név] [Indok]
addCommandHandler("kick", function(player, cmd, targetName, ...)
    -- Ha nincs player, akkor console (true), egyébként ellenőrizzük a szintet
    local isConsole = not player or getElementType(player) == "console"
    local pLevel = not isConsole and (getElementData(player, "admin") or 0) or 0
    
    if isConsole or pLevel >= 1 then
        if not targetName then 
            if isConsole then print("Használat: /kick [Név] [Indok]") 
            else outputChatBox("#d9534f[Használat] #ffffff/kick [Név] [Indok]", player, 255, 255, 255, true) end
            return 
        end

        local target = findPlayer(targetName)
        local reason = table.concat({...}, " ")
        if reason == "" then reason = "Nincs megadva indok." end

        if target then
            outputChatBox("#d9534f[Kick] #ffffff" .. getPlayerName(target) .. " ki lett rúgva. Indok: " .. reason, root, 255, 255, 255, true)
            if isConsole then print("Sikeresen kirúgtad: " .. getPlayerName(target)) end
            kickPlayer(target, player or "Console", reason)
        else
            if isConsole then print("Hiba: Játékos nem található!") 
            else outputChatBox("#d9534f[Hiba] #ffffffJátékos nem található!", player, 255, 255, 255, true) end
        end
    else
        outputChatBox("#d9534f[Hiba] #ffffffNincs jogosultságod!", player, 255, 255, 255, true)
    end
end)

-- /teams
addCommandHandler("teams", function(player)
    local isConsole = not player or getElementType(player) == "console"
    local adminLevel = not isConsole and (getElementData(player, "admin") or 0) or 0
    
    if isConsole or adminLevel >= 2 then
        if isConsole then print("--- Aktuális csapatok ---")
        else outputChatBox("#7cc576[TTT-Admin] #ffffffAktuális csapatok:", player, 255, 255, 255, true) end
        
        for _, p in ipairs(getElementsByType("player")) do
            local role = getElementData(p, "tttRole") or "Nincs"
            local color = "#2ecc71"
            if role == "Traitor" then color = "#e74c3c"
            elseif role == "Detective" then color = "#3498db" end
            
            if isConsole then 
                print("- " .. getPlayerName(p) .. ": " .. tostring(role))
            else 
                outputChatBox("- " .. getPlayerName(p) .. ": " .. color .. tostring(role), player, 255, 255, 255, true) 
            end
        end
    else
        outputChatBox("#e74c3c[Hiba] #ffffffEhhez a parancshoz legalább 2-es szintű admin rang kell!", player, 255, 255, 255, true)
    end
end)

-- /setteam [név] [role]
addCommandHandler("setteam", function(player, cmd, targetPart, newRole)
    local isConsole = not player or getElementType(player) == "console"
    local adminLevel = not isConsole and (getElementData(player, "admin") or 0) or 0
    
    if isConsole or adminLevel >= 2 then
        if not targetPart or not newRole then
            if isConsole then print("Használat: setteam [Név] [traitor/detective/innocent]")
            else outputChatBox("#f1c40f[Használat]: #ffffff/setteam [Név részlet] [traitor/detective/innocent]", player, 255, 255, 255, true) end
            return
        end

        local targetPlayer = findPlayer(targetPart)

        if targetPlayer then
            local roleToSet = false
            local lowerRole = string.lower(newRole)
            
            if lowerRole == "traitor" then roleToSet = "Traitor"
            elseif lowerRole == "detective" then roleToSet = "Detective"
            elseif lowerRole == "innocent" then roleToSet = "Innocent" end

            if roleToSet then
                setElementData(targetPlayer, "tttRole", roleToSet)
                
                local msg = "#7cc576[TTT-Admin] #ffffffSikeresen módosítva: #7cc576" .. getPlayerName(targetPlayer) .. " #ffffff-> #f1c40f" .. roleToSet
                if isConsole then print("Sikeres szerepváltás!") else outputChatBox(msg, player, 255, 255, 255, true) end
                
                outputChatBox("#7cc576[TTT-Admin] #ffffffEgy admin megváltoztatta a szerepedet: #f1c40f" .. roleToSet, targetPlayer, 255, 255, 255, true)
                -- exports["ttt-core"]:checkTTTWin()                                                                                                                          EZT MAJD VISSZA KELL TENNI ÉLESBEN
            else
                if isConsole then print("Hiba: Érvénytelen szerep!") 
                else outputChatBox("#e74c3c[Hiba] #ffffffÉrvénytelen szerep!", player, 255, 255, 255, true) end
            end
        else
            if isConsole then print("Hiba: Játékos nem található!") 
            else outputChatBox("#e74c3c[Hiba] #ffffffJátékos nem található!", player, 255, 255, 255, true) end
        end
    else
        outputChatBox("#e74c3c[Hiba] #ffffffNincs jogosultságod ehhez!", player, 255, 255, 255, true)
    end
end)

-- /sethp [név] [érték]
addCommandHandler("sethp", function(player, cmd, targetPart, hpValue)
    local isConsole = not player or getElementType(player) == "console"
    local adminLevel = not isConsole and (getElementData(player, "admin") or 0) or 0
    
    -- Minimum 1-es admin szint kell hozzá (vagy konzol)
    if isConsole or adminLevel >= 1 then
        if not targetPart or not hpValue or not tonumber(hpValue) then
            if isConsole then print("Használat: sethp [Név részlet] [Érték]")
            else outputChatBox("#f1c40f[Használat]: #ffffff/sethp [Név részlet] [Érték]", player, 255, 255, 255, true) end
            return
        end

        local targetPlayer = findPlayer(targetPart) -- A korábban megírt kereső függvényt használja
        local newHP = math.clamp(0, tonumber(hpValue), 100) -- 0 és 100 közé szorítjuk az értéket

        if targetPlayer then
            setElementHealth(targetPlayer, newHP)
            
            local adminName = isConsole and "Console" or getPlayerName(player)
            local targetName = getPlayerName(targetPlayer)

            -- Visszajelzés az adminnak
            if isConsole then 
                print("Sikeres HP állítás: " .. targetName .. " -> " .. newHP) 
            else 
                outputChatBox("#7cc576[TTT-Admin] #ffffff" .. targetName .. " életereje átállítva: #7cc576" .. newHP .. "%", player, 255, 255, 255, true) 
            end

            -- Visszajelzés a játékosnak
            outputChatBox("#7cc576[TTT-Admin] #ffffffEgy admin átállította az életerőd: #f1c40f" .. newHP .. "%", targetPlayer, 255, 255, 255, true)
        else
            if isConsole then print("Hiba: Játékos nem található!") 
            else outputChatBox("#e74c3c[Hiba] #ffffffJátékos nem található!", player, 255, 255, 255, true) end
        end
    else
        outputChatBox("#e74c3c[Hiba] #ffffffNincs jogosultságod ehhez!", player, 255, 255, 255, true)
    end
end)

-- Segédfüggvény az érték korlátozásához (ha nincs alapból a rendszerben)
function math.clamp(low, n, high)
    return math.max(low, math.min(n, high))
end


-- /npc parancs
addCommandHandler("npc", function(playerSource)
    if not isPedInVehicle(playerSource) then
        local x, y, z = getElementPosition(playerSource)
        local _, _, rot = getElementRotation(playerSource)
        local interior = getElementInterior(playerSource)
        local dimension = getElementDimension(playerSource)

        local npc = createPed(0, x + 1, y, z) -- Skin ID: 0 (CJ)
        setElementRotation(npc, 0, 0, rot + 180)
        setElementInterior(npc, interior)
        setElementDimension(npc, dimension)
        setElementFrozen(npc, true) -- Ne sétáljon el
        
        -- Név beállítása data-ba a nametagnek
        setElementData(npc, "npcName", "Trevi")
        outputChatBox("[NPC] Trevi sikeresen lerakva!", playerSource, 46, 204, 113)
    end
end)

addCommandHandler("npcrole", function(playerSource, cmd, newRole)
    -- Jogosultság ellenőrzése (Főadmin+)
    local adminLvl = getElementData(playerSource, "admin") or 0
    if adminLvl < 2 then 
        outputChatBox("#e74c3c[Hiba] #ffffffNincs jogosultságod ehhez!", playerSource, 255, 255, 255, true)
        return 
    end

    if not newRole then
        outputChatBox("#f1c40f[Használat]: #ffffff/npcrole [traitor/detective/innocent]", playerSource, 255, 255, 255, true)
        return
    end

    -- Szerep felismerése
    local roleToSet = false
    local lowerRole = string.lower(newRole)
    if lowerRole == "traitor" then roleToSet = "Traitor"
    elseif lowerRole == "detective" then roleToSet = "Detective"
    elseif lowerRole == "innocent" then roleToSet = "Innocent" end

    if not roleToSet then
        outputChatBox("#e74c3c[Hiba] #ffffffÉrvénytelen szerep!", playerSource, 255, 255, 255, true)
        return
    end

    -- Legközelebbi NPC megkeresése
    local x, y, z = getElementPosition(playerSource)
    local nearestPed = nil
    for _, ped in ipairs(getElementsByType("ped")) do
        local dist = getDistanceBetweenPoints3D(x, y, z, getElementPosition(ped))
        if dist < 4 then nearestPed = ped break end
    end

    if nearestPed then
        local roleToSet = false
        local lowerRole = tostring(newRole):lower()
        if lowerRole == "traitor" then roleToSet = "Traitor"
        elseif lowerRole == "detective" then roleToSet = "Detective"
        elseif lowerRole == "innocent" then roleToSet = "Innocent" end

        if roleToSet then
            setElementData(nearestPed, "tttRole", roleToSet)
            -- KIVETVE: revealRole automatikus true-ra állítása
            outputChatBox("#7cc576[TTT-NPC] #ffffffSzerep beállítva: #f1c40f" .. roleToSet, playerSource, 255, 255, 255, true)
        end
    end
end)

-- /npcadmin [1/2/3] parancs
addCommandHandler("npcadmin", function(playerSource, cmd, level)
    local lvl = tonumber(level)
    if not lvl or lvl < 0 or lvl > 3 then
        outputChatBox("Használat: /npcadmin [0-3]", playerSource, 231, 76, 60)
        return
    end

    -- Megkeressük a legközelebbi NPC-t
    local x, y, z = getElementPosition(playerSource)
    local nearestPed = nil
    local minDist = 5 -- 5 méteren belül kell lennie

    for _, ped in ipairs(getElementsByType("ped")) do
        local px, py, pz = getElementPosition(ped)
        local dist = getDistanceBetweenPoints3D(x, y, z, px, py, pz)
        if dist < minDist then
            minDist = dist
            nearestPed = ped
        end
    end

    if nearestPed then
        setElementData(nearestPed, "adminLevel", lvl)
        outputChatBox("[NPC] Rang frissítve a legközelebbi NPC-n! Szint: " .. lvl, playerSource, 52, 152, 219)
    else
        outputChatBox("[HIBA] Nincs NPC a közeledben!", playerSource, 231, 76, 60)
    end
end)

addCommandHandler("reveal", function(playerSource)
    local adminLvl = getElementData(playerSource, "admin") or 0
    if adminLvl < 2 then 
        outputChatBox("#d9534f[Hiba] #ffffffEzt csak Főadmin+ használhatja!", playerSource, 255, 255, 255, true)
        return 
    end

    -- Az ADMIN állapotát kapcsoljuk ki/be
    local currentState = getElementData(playerSource, "adminVision") or false
    local newState = not currentState
    setElementData(playerSource, "adminVision", newState)

    local statusMsg = newState and "#7cc576BEKAPCSOLVA" or "#d9534fKIKAPCSOLVA"
    outputChatBox("#00c3ff[Admin-Vision] #ffffffÖsszes szerep mutatása: " .. statusMsg, playerSource, 255, 255, 255, true)

    -- Logolás az SQL-be és Discordra
    local pName = getPlayerName(playerSource)
    exports["ttt-sql"]:dbQueryExec("INSERT INTO shop_logs (player, action, cost, date) VALUES (?, ?, ?, CURRENT_TIMESTAMP)", pName, "ADMIN_VISION "..(newState and "ON" or "OFF"), 0)
    
    if exports["ttt-dc"] then
        exports["ttt-dc"]:sendAdminLog("**[VISION]** " .. pName .. " bekapcsolta az admin látmódot: " .. (newState and "BE" or "KI"))
    end
end)

addCommandHandler("fixadmin", function(playerSource)
    setElementData(playerSource, "admin", 3)
    outputChatBox("#7cc576[AdminSystem] #ffffffVisszakaptad az adminodat!", target, 255, 255, 255, true)
end)

addCommandHandler("giveskin", function(player, cmd, targetName, skinID, ...)
    if hasAdminAccess(player) then
        local skinName = table.concat({...}, " ")
        local sID = tonumber(skinID)
        local target = findPlayer(targetName)
        
        if target and sID and #skinName > 0 then
            local targetNameRaw = getPlayerName(target)
            local adminName = (not player or getElementType(player) == "console") and "Console" or getPlayerName(player)
            
            -- 1. Mentés az SQL-be (Ez eddig is jó volt)
            if exports["ttt-sql"] then
                local dbHandler = exports["ttt-sql"]:getDatabaseHandler()
                dbExec(dbHandler, "INSERT INTO owned_skins (player_name, skin_id, skin_name) VALUES (?, ?, ?)", 
                    targetNameRaw, sID, skinName)
                
                -- Frissítjük a játékosnál a listát
                triggerEvent("ttt:requestOwnedSkins", target) 
            end

            -- 2. Visszajelzés
            outputChatBox("#7cc576[Skin] #ffffffAdtál egy skint (#7cc576" .. skinName .. "#ffffff) neki: #7cc576" .. targetNameRaw, player, 255, 255, 255, true)
            outputChatBox("#7cc576[Skin] #ffffffKaptál egy új skint az admintól: #7cc576" .. skinName, target, 255, 255, 255, true)

            -- 3. LOGOLÁS - Itt volt a hiba, target helyett targetNameRaw kell!
            logAdminAction(adminName, "Skin adása", targetNameRaw, "ID: "..sID.." | Név: "..skinName)
        else
            outputChatBox("#d9534f[Hiba] #ffffffHasználat: /giveskin [Név] [ID] [Név]", player, 255, 255, 255, true)
        end
    end
end)

addCommandHandler("pskin", function(playerSource, cmd, skinID)
    -- 1. Lekérjük az admin szintet
    local adminLvl = getElementData(playerSource, "admin") or 0

    if hasAdminAccess(playerSource) then
        
        -- HA FŐADMIN VAGY NAGYOBB (Level 2+)
        if adminLvl >= 2 then 
            local sID = tonumber(skinID)
            if sID then
                local oldSkin = getElementModel(playerSource)
                setElementModel(playerSource, sID)
                
                outputChatBox("#00c3ff[Preview-Skin] #ffffffSkin ideiglenesen megváltoztatva: #7cc576" .. sID, playerSource, 255, 255, 255, true)
                outputDebugString("[Admin] " .. getPlayerName(playerSource) .. " pskin-t használt. (Új: " .. sID .. ")")
            else
                outputChatBox("#d9534f[Hiba] #ffffffHasználat: /pskin [ID]", playerSource, 255, 255, 255, true)
            end
            
        -- HA CSAK 1-ES ADMIN VAGY
        elseif adminLvl == 1 then
            outputChatBox("#d9534f[Hiba] #ffffffNincs jogosultságod ehhez a parancshoz! (Főadmin+)", playerSource, 255, 255, 255, true)
        end
    end
end)