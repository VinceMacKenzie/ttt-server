local activePlayerWeapons = {}
local activeWeaponStats = {}

addEvent("requestPlayerWeapons", true)
addEvent("updateWeaponSlot", true)

-- Segédfüggvény: SQL sor konvertálása tiszta táblává
function getStatsFromRow(row)
    if not row then return nil end
    return {
        id = row.id,
        weapon_model = tonumber(row.weapon_model) or 0,
        serial_number = row.serial_number or "N/A",
        durability = tonumber(row.durability) or 100,
        mod_head_dmg = tonumber(row.mod_head_dmg) or 0,
        mod_body_dmg = tonumber(row.mod_body_dmg) or 0,
        mod_arm_dmg = tonumber(row.mod_arm_dmg) or 0,
        mod_leg_dmg = tonumber(row.mod_leg_dmg) or 0,
        buff_stun = tonumber(row.buff_stun) or 0,
        buff_life_drain = tonumber(row.buff_life_drain) or 0,
        buff_fire = tonumber(row.buff_fire) or 0
    }
end

function syncWeapons(player)
    if not isElement(player) then return end
    local dbHandler = exports["ttt-sql"]:getDatabaseHandler()
    local playerName = getPlayerName(player)
    
    dbQuery(function(qh)
        local res = dbPoll(qh, 0) or {}
        activePlayerWeapons[player] = res
        triggerClientEvent(player, "receivePlayerWeapons", player, res)
    end, dbHandler, "SELECT * FROM weapons WHERE owner_name = ?", playerName)
end

function loadActiveWeaponStats(player, weaponModel)
    if not isElement(player) or not weaponModel then return end
    local db = exports["ttt-sql"]:getDatabaseHandler()
    local name = getPlayerName(player)
    local wModel = tonumber(weaponModel)

    dbQuery(function(qh)
        local res = dbPoll(qh, 0)
        if res and #res > 0 then
            activeWeaponStats[player] = getStatsFromRow(res[1])
            outputDebugString("[WeaponSystem] Statok betöltve: " .. (activeWeaponStats[player].serial_number))
        else
            activeWeaponStats[player] = nil
        end
    end, db, "SELECT * FROM weapons WHERE owner_name = ? AND weapon_model = ? AND is_equipped = 1 LIMIT 1", name, wModel)
end

function getPlayerActiveStats(player)
    return activeWeaponStats[player]
end

-- ESEMÉNYEK
addEventHandler("requestPlayerWeapons", root, function() syncWeapons(client) end)

addEventHandler("onPlayerWeaponSwitch", root, function(prevSlot, curSlot)
    local weaponID = getPedWeapon(source, curSlot)
    if weaponID and weaponID > 0 then
        loadActiveWeaponStats(source, weaponID)
    else
        activeWeaponStats[source] = nil
    end
end)

addEventHandler("updateWeaponSlot", root, function(weaponID, newSlot)
    local dbHandler = exports["ttt-sql"]:getDatabaseHandler()
    local player = client
    local playerName = getPlayerName(player)
    local weaponID = tonumber(weaponID)
    local newSlot = tonumber(newSlot)

    if newSlot > 0 then
        dbQuery(function(qh)
            local res = dbPoll(qh, 0)
            if res then
                for _, row in ipairs(res) do
                    exports["ttt-sql"]:dbQueryExec("UPDATE weapons SET is_equipped = 0, slot_type = 0 WHERE id = ?", row.id)
                end
            end
            exports["ttt-sql"]:dbQueryExec("UPDATE weapons SET is_equipped = 1, slot_type = ? WHERE id = ? AND owner_name = ?", newSlot, weaponID, playerName)
            
            setTimer(function(p)
                if isElement(p) then
                    syncWeapons(p)
                    local curWep = getPedWeapon(p)
                    if curWep and curWep > 0 then loadActiveWeaponStats(p, curWep) end
                end
            end, 300, 1, player)
        end, dbHandler, "SELECT id FROM weapons WHERE owner_name = ? AND slot_type = ?", playerName, newSlot)
    else
        exports["ttt-sql"]:dbQueryExec("UPDATE weapons SET is_equipped = 0, slot_type = 0 WHERE id = ? AND owner_name = ?", weaponID, playerName)
        setTimer(syncWeapons, 200, 1, player)
        activeWeaponStats[player] = nil
    end
end)

-- STATS PARANCS
addCommandHandler("stats", function(player)
    local stats = getPlayerActiveStats(player)
    outputChatBox("--- Aktuális Fegyver Statisztikák ---", player, 0, 255, 255)
    if stats then
        outputChatBox("Modell: #ffffff" .. (getWeaponNameFromID(stats.weapon_model) or "Ismeretlen") .. " (" .. stats.weapon_model .. ")", player, 200, 200, 200, true)
        outputChatBox("Serial: #ffffff" .. (stats.serial_number or "N/A"), player, 200, 200, 200, true)
        outputChatBox("Durability: #ffffff" .. stats.durability .. "%", player, 200, 200, 200, true)
        outputChatBox("HS bónusz: #00ff00+" .. stats.mod_head_dmg .. "%", player, 200, 200, 200, true)
        outputChatBox("Test bónusz: #00ff00+" .. stats.mod_body_dmg .. "%", player, 200, 200, 200, true)
        local fireStatus = (tonumber(stats.buff_fire) > 0) and "#00ff00Igen" or "#ff0000Nem"
        outputChatBox("Tűz buff: " .. fireStatus .. " #ffffff(Érték: " .. stats.buff_fire .. ")", player, 255, 255, 255, true)
    else
        outputChatBox("Nincs aktív fegyver adat!", player, 255, 0, 0)
    end
    outputChatBox("------------------------------------", player, 0, 255, 255)
end)