-- --- VÁSÁRLÁS KEZELÉSE ---
addEvent("ttt:buyItem", true)
addEventHandler("ttt:buyItem", root, function(name, price, id, qty)
    if not client or isPedDead(client) then return end
    
    local role = getElementData(client, "tttRole")
    if role ~= "Traitor" and role ~= "Detective" then return end
    
    local price = tonumber(price) or 0
    local qty = tonumber(qty) or 0
    local playerMoney = getPlayerMoney(client)

    if playerMoney >= price then
        takePlayerMoney(client, price)
        
        if id == "armor" then
            setPedArmor(client, qty)
            outputChatBox("#7cc576[Shop] #ffffffSikeres vásárlás: Kevlár mellény!", client, 255, 255, 255, true)
        elseif id == "medkit" then
            setElementHealth(client, qty)
            outputChatBox("#7cc576[Shop] #ffffffSikeres vásárlás: Életerő!", client, 255, 255, 255, true)
        else
            giveWeapon(client, id, qty, true)
            outputChatBox("#7cc576[Shop] #ffffffSikeres vásárlás: " .. name, client, 255, 255, 255, true)
        end
        
        -- Logolások (Discord & SQL)
        if exports["ttt-dc"] and exports["ttt-dc"].sendMoneyLog then
            local shopType = (role == "Traitor") and "BLACK MARKET" or "ARMORY"
            exports["ttt-dc"]:sendMoneyLog(shopType, getPlayerName(client), "Vett: " .. name, price)
        end

        if exports["ttt-sql"] then
            local playerName = getPlayerName(client)
            exports["ttt-sql"]:dbQueryExec("INSERT INTO shop_logs (player, action, cost) VALUES (?, ?, ?)", playerName, tostring(name), price)
        end
    else
        outputChatBox("#d9534f[Shop] #ffffffNincs elég pénzed!", client, 255, 255, 255, true)
    end
end)

-- --- SKILL FEJLESZTÉS KEZELÉSE ---
addEvent("ttt:logSkillUpgrade", true)
addEventHandler("ttt:logSkillUpgrade", root, function(skillName, value, price) -- Hozzáadva a 'price'
    if not client or isPedDead(client) then return end
    
    local price = tonumber(price) or 0
    local playerMoney = getPlayerMoney(client)
    local playerName = getPlayerName(client)

    -- Pénz ellenőrzése
    if playerMoney >= price then
        -- Pénz levonása
        takePlayerMoney(client, price)

        -- Tényleges képesség odaadása
        if skillName == "Silenced Pistol Skill" then
            setPedStat(client, 69, 1000) -- Javítva 69-re (Silenced Pistol)
            outputChatBox("#7cc576[Skill] #ffffffSikeres fejlesztés: Silenced Pistol (Hitman szint)!", client, 255, 255, 255, true)
        elseif skillName == "Stamina Upgrade" then
            setPedStat(client, 22, 1000) -- Max Stamina
            outputChatBox("#7cc576[Skill] #ffffffSikeres fejlesztés: Állóképesség megnövelve!", client, 255, 255, 255, true)
        elseif skillName == "M4 Skill" then
            setPedStat(client, 78, 1000) -- Max Stamina
            outputChatBox("#7cc576[Skill] #ffffffSikeres fejlesztés: M4 használat.", client, 255, 255, 255, true)
        elseif skillName == "AK-47 Skill" then
            setPedStat(client, 77, 1000) -- Max Stamina
            outputChatBox("#7cc576[Skill] #ffffffSikeres fejlesztés: AK-47 használat.", client, 255, 255, 255, true)
        end
        
        -- SQL Mentés az aktuális árral
        if exports["ttt-sql"] then
            exports["ttt-sql"]:dbQueryExec("INSERT INTO shop_logs (player, action, cost) VALUES (?, ?, ?)", 
                playerName, "Skill: " .. skillName, price)
        end
        
        -- Discord Log
        if exports["ttt-dc"] and exports["ttt-dc"].sendMoneyLog then
            exports["ttt-dc"]:sendMoneyLog("SKILL UPGRADE", playerName, skillName, price)
        end
    else
        outputChatBox("#d9534f[Shop] #ffffffNincs elég pénzed a fejlesztésre! ($" .. price .. ")", client, 255, 255, 255, true)
    end
end)