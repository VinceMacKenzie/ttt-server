-- Újrapörgetés (Reroll) kezelése
addEvent("requestWeaponReroll", true)
addEventHandler("requestWeaponReroll", root, function(weaponID, cost)
    local playerMoney = getPlayerMoney(client) -- Vagy a TTT pénznemed

    if playerMoney >= cost then
        takePlayerMoney(client, cost)

        -- Új statok generálása (Egész számok 0-35 között a Config alapján)
        local newHead = math.random(Config.MinOptValue, Config.MaxOptValue)
        local newBody = math.random(Config.MinOptValue, Config.MaxOptValue)
        local newArm  = math.random(Config.MinOptValue, Config.MaxOptValue)
        
        -- Buff generálás (pl. 20% esély egy random buffra)
        local hasFire = (math.random(1, 100) <= 20) and 1 or 0
        local hasPoison = (math.random(1, 100) <= 10) and 1 or 0

        -- SQL frissítés
        exports["ttt-sql"]:dbQueryExec([[ 
            UPDATE weapons SET 
            mod_head_dmg = ?, 
            mod_body_dmg = ?, 
            mod_arm_dmg = ?, 
            buff_fire = ?, 
            buff_poison = ? 
            WHERE id = ? AND owner_id = ?
        ]], newHead, newBody, newArm, hasFire, hasPoison, weaponID, getElementData(client, "dbid"))

        outputChatBox("[TTT-Shop] Sikeres újrapörgetés!", client, 0, 255, 0)
        
        -- Frissítjük a kliensnél az adatokat
        triggerEvent("reloadPlayerWeapons", client)
    else
        outputChatBox("[TTT-Shop] Nincs elég pénzed!", client, 255, 0, 0)
    end
end)

-- Új fegyver vásárlása/adása
function giveWeaponToPlayer(player, weaponModel)
    if not player or not weaponModel then return end
    
    local serial = Utils.generateSerial()
    local ownerID = getElementData(player, "dbid") -- A ttt-sql usertáblájából az ID

    exports["ttt-sql"]:dbQueryExec([[
        INSERT INTO weapons (owner_id, weapon_model, serial_number, durability, fire_mode) 
        VALUES (?, ?, ?, 100, 'auto')
    ]], ownerID, weaponModel, serial)

    outputChatBox("[TTT-Weapon] Új fegyver hozzáadva az inventorydhoz!", player, 0, 255, 255)
    triggerEvent("reloadPlayerWeapons", player)
end