-- Amikor a játékos belép vagy a kliens kéri (onClientResourceStart-nál hívtuk meg)
addEvent("ttt:requestOwnedSkins", true)
addEventHandler("ttt:requestOwnedSkins", root, function()
    local p = client
    local playerName = getPlayerName(p)
    
    local dbHandler = exports["ttt-sql"]:getDatabaseHandler() 
    
    if dbHandler then
        -- Kiegészítve a skin_name lekérésével!
        dbQuery(function(qh)
            local res = dbPoll(qh, 0)
            local ownedTable = {}
            if res then
                for _, row in ipairs(res) do
                    -- Most már nem true-t, hanem a konkrét nevet mentjük el az ID-hez!
                    -- row.skin_id lesz a kulcs (pl. 181), row.skin_name az érték (pl. "Motoros")
                    ownedTable[row.skin_id] = row.skin_name or "Ismeretlen Skin"
                end
            end
            -- Visszaküldjük a kliensnek a táblázatot, amiben már benne vannak a nevek is
            triggerClientEvent(p, "ttt:receiveOwnedSkins", p, ownedTable)
            outputDebugString("[SkinSystem] " .. playerName .. " megvett skinjei betöltve (nevekkel).")
        end, dbHandler, "SELECT skin_id, skin_name FROM owned_skins WHERE player_name = ?", playerName)
    end
end)

-- Vásárlás és Felvétel kezelése
addEvent("ttt:buySkin", true)
addEventHandler("ttt:buySkin", root, function(name, price, skinID, isFree)
    local p = client
    local playerName = getPlayerName(p)
    local playerMoney = getPlayerMoney(p)

    if isFree then
        -- Ha már megvan az SQL-ben, csak rátesszük a skint
        setElementModel(p, skinID)
        outputChatBox("#7cc576[Skin] #ffffffSkin sikeresen felvéve!", p, 255, 255, 255, true)
    else
        -- Ha még nincs meg, ellenőrizzük a pénzt
        if playerMoney >= price then
            takePlayerMoney(p, price)
            setElementModel(p, skinID)
            
            -- Mentés az adatbázisba a ttt-sql-en keresztül
            local displayName = (name == "basic") and ("Skin #"..skinID) or name
            local success = exports["ttt-sql"]:dbQueryExec("INSERT INTO owned_skins (player_name, skin_id, skin_name, price) VALUES (?, ?, ?, ?)", 
                playerName, skinID, displayName, price)
            
            if success then
                outputChatBox("#7cc576[Skin] #ffffffSikeres vásárlás: #00c3ff" .. displayName, p, 255, 255, 255, true)
                -- Azonnal frissítjük a kliensnél a listát, hogy ne kelljen újra belépnie
                triggerClientEvent(p, "ttt:addOwnedSkinToClient", p, skinID)
            end
        else
            outputChatBox("#d9534f[Skin] #ffffffNincs elég pénzed a vásárláshoz! ($" .. price .. ")", p, 255, 255, 255, true)
        end
    end
end)