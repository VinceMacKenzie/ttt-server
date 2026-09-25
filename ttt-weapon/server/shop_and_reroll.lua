local REROLL_COST = 2500 -- Az újrapörgetés ára (a kliens nem küldhet árat)

-- Újrapörgetés (Reroll)
addEvent("requestWeaponReroll", true)
addEventHandler("requestWeaponReroll", root, function(weaponID)
    local p = client
    if not p then return end
    weaponID = tonumber(weaponID)
    if not weaponID then return end

    if getPlayerMoney(p) < REROLL_COST then
        return outputChatBox("[TTT-Shop] Nincs elég pénzed! ($" .. REROLL_COST .. ")", p, 255, 0, 0)
    end

    local db = exports["ttt-sql"]:getDatabaseHandler()
    if not db then return end

    -- Csak a saját fegyverét pörgetheti újra
    dbQuery(function(qh, player)
        if not isElement(player) then return end
        local res = dbPoll(qh, 0)
        if not res or #res == 0 then
            return outputChatBox("[TTT-Shop] Ez nem a te fegyvered!", player, 255, 0, 0)
        end

        takePlayerMoney(player, REROLL_COST)

        local newHead = math.random(Config.MinOptValue, Config.MaxOptValue)
        local newBody = math.random(Config.MinOptValue, Config.MaxOptValue)
        local newArm  = math.random(Config.MinOptValue, Config.MaxOptValue)
        local hasFire   = (math.random(1, 100) <= Config.Buffs.fire.chance) and 1 or 0
        local hasPoison = (math.random(1, 100) <= Config.Buffs.poison.chance) and 1 or 0

        exports["ttt-sql"]:dbQueryExec([[
            UPDATE weapons SET mod_head_dmg = ?, mod_body_dmg = ?, mod_arm_dmg = ?, buff_fire = ?, buff_poison = ?
            WHERE id = ? AND owner_name = ?
        ]], newHead, newBody, newArm, hasFire, hasPoison, weaponID, getPlayerName(player))

        outputChatBox("[TTT-Shop] Sikeres újrapörgetés!", player, 0, 255, 0)
        syncWeapons(player)
    end, {p}, db, "SELECT id FROM weapons WHERE id = ? AND owner_name = ? LIMIT 1", weaponID, getPlayerName(p))
end)

-- Új fegyver adása (exportált is)
function giveWeaponToPlayer(player, weaponModel)
    if not isElement(player) or not tonumber(weaponModel) then return false end

    local serial = Utils.generateSerial()
    local success = exports["ttt-sql"]:dbQueryExec([[
        INSERT INTO weapons (owner_name, weapon_model, serial_number, durability, mod_head_dmg, mod_body_dmg, fire_mode)
        VALUES (?, ?, ?, 100, 15, 10, 'auto')
    ]], getPlayerName(player), tonumber(weaponModel), serial)

    if success then
        outputChatBox("[TTT-Weapon] Új fegyver hozzáadva az inventorydhoz! (" .. serial .. ")", player, 0, 255, 255)
        syncWeapons(player)
    end
    return success
end
