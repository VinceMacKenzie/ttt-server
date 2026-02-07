-- Segédfüggvény az admin szint ellenőrzéséhez (igazítsd a saját rendszeredhez)
function isPlayerAdmin(player)
    return getElementData(player, "admin") or 0 >= 1
end

-- /giveweapon [Név/ID] [WeaponID]
addCommandHandler("giveweapon", function(player, cmd, targetName, weaponID)
    -- Ha nem írtál nevet, a saját nevedet használja
    local name = targetName or getPlayerName(player)
    local wID = tonumber(weaponID)

    if not wID then
        outputChatBox("Használat: /giveweapon [Név] [WeaponID]", player, 255, 255, 255)
        return
    end

    local serial = Utils.generateSerial()

    -- Itt most az 'owner_id' helyett (vagy abba) a nevet írjuk be stringként
    -- Feltételezve, hogy a táblád owner_id oszlopa elfogad szöveget, 
    -- vagy van egy 'owner_name' oszlopod.
    local success = exports["ttt-sql"]:dbQueryExec([[
        INSERT INTO weapons (owner_name, weapon_model, serial_number, durability, mod_head_dmg, mod_body_dmg) 
        VALUES (?, ?, ?, 100, 15, 10)
        ]], name, wID, serial)

    if success then
        outputChatBox("[SQL] Fegyver beírva a(z) " .. name .. " névhez!", player, 0, 255, 0)
    else
        outputChatBox("[SQL] Hiba történt az íráskor!", player, 255, 0, 0)
    end
end)
-- /setweaponstat [WeaponDB_ID] [Stat_Oszlop] [Érték]
-- Példa: /setweaponstat 45 mod_head_dmg 50 (50% headshot bónusz a 45-ös ID-jű fegyverre)
addCommandHandler("setweaponstat", function(player, cmd, dbID, statName, value)
    if not isPlayerAdmin(player) then return end
    
    dbID = tonumber(dbID)
    value = tonumber(value) or value -- Lehet string is (pl. fire_mode)

    if dbID and statName then
        exports["ttt-sql"]:dbQueryExec("UPDATE weapons SET " .. statName .. " = ? WHERE id = ?", value, dbID)
        outputChatBox("[Admin] Stat frissítve! (ID: " .. dbID .. " | " .. statName .. " = " .. value .. ")", player, 0, 255, 0)
        
        -- Frissítjük a szerveren tartózkodó összes játékosnál, hátha nála van a fegyver
        for _, p in ipairs(getElementsByType("player")) do
            triggerEvent("reloadPlayerWeapons", p)
        end
    end
end)

-- /delweapon [WeaponDB_ID]
addCommandHandler("delweapon", function(player, cmd, dbID)
    if not isPlayerAdmin(player) then return end
    
    dbID = tonumber(dbID)
    if dbID then
        exports["ttt-sql"]:dbQueryExec("DELETE FROM weapons WHERE id = ?", dbID)
        outputChatBox("[Admin] Fegyver véglegesen törölve az adatbázisból! (ID: " .. dbID .. ")", player, 255, 0, 0)
    end
end)