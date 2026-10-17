-- Fejlesztő itemek használata (a kliens húzza rá a fegyverre az F2 menüben)
--   opt_adder     : új stat a következő szabad slotba (3 sebzés -> 1 buff -> 1 utility)
--   opt_changer   : a meglévő sebzés-optok újrapörgetése (a már betöltött slotok új értéket kapnak)
--   curse_remover : az átkok törlése
local VALID_ITEMS = { opt_adder = true, opt_changer = true, curse_remover = true }

local DMG_STATS = { "mod_head_dmg", "mod_body_dmg", "mod_arm_dmg", "mod_leg_dmg" }
local BUFF_STATS = { "buff_fire", "buff_stun", "buff_poison", "buff_life_drain" }

-- Stat generáló: 3 sebzés slot -> 1 buff slot -> 1 utility slot
function generateNewStat(w)
    if (tonumber(w.mod_head_dmg) or 0) == 0 then return true, "mod_head_dmg", math.random(5, 15) end
    if (tonumber(w.mod_body_dmg) or 0) == 0 then return true, "mod_body_dmg", math.random(5, 10) end
    if (tonumber(w.mod_arm_dmg) or 0) == 0 then return true, "mod_arm_dmg", math.random(3, 8) end

    for _, b in ipairs(BUFF_STATS) do
        if (tonumber(w[b]) or 0) == 0 then return true, b, 1 end
    end

    if (tonumber(w.reload_speed_mod) or 0) == 0 then return true, "reload_speed_mod", math.random(10, 25) end
    return false
end

-- Opt cserélő: minden már betöltött sebzés-stat új értéket kap (Config.MinOptValue..MaxOptValue)
local function rerollExistingStats(w)
    local sets, desc = {}, {}
    for _, key in ipairs(DMG_STATS) do
        if (tonumber(w[key]) or 0) ~= 0 then
            local v = math.random(Config.MinOptValue, Config.MaxOptValue)
            table.insert(sets, "`" .. key .. "` = " .. v)
            table.insert(desc, key .. " +" .. v)
        end
    end
    -- Ha van buff, azt is újrahúzzuk egy másikra
    for _, b in ipairs(BUFF_STATS) do
        if (tonumber(w[b]) or 0) ~= 0 then
            local newBuff = BUFF_STATS[math.random(#BUFF_STATS)]
            table.insert(sets, "`" .. b .. "` = 0")
            table.insert(sets, "`" .. newBuff .. "` = 1")
            table.insert(desc, "buff -> " .. newBuff)
            break
        end
    end
    return sets, desc
end

addEvent("applyWeaponUpgrade", true)
addEventHandler("applyWeaponUpgrade", root, function(weaponID, upgradeType)
    local p = client
    if not p or not VALID_ITEMS[upgradeType] then return end
    weaponID = tonumber(weaponID)
    if not weaponID then return end

    local db = exports["ttt-sql"]:getDatabaseHandler()
    if not db then return end
    local playerName = getPlayerName(p)

    -- 1. A fegyver (csak a sajátja!)
    dbQuery(function(qh, player)
        if not isElement(player) then return end
        local res = dbPoll(qh, 0)
        if not res or #res == 0 then return end
        local weapon = res[1]

        -- 2. Van-e elég fejlesztő item
        dbQuery(function(qh2, player2)
            if not isElement(player2) then return end
            local invRes = dbPoll(qh2, 0)
            if not invRes or #invRes == 0 or (tonumber(invRes[1][upgradeType]) or 0) <= 0 then
                return outputChatBox("#ff0000[Hiba] #ffffffNincs elég fejlesztő itemed! (" .. upgradeType .. ")", player2, 255, 255, 255, true)
            end

            local done = false
            if upgradeType == "opt_adder" then
                local success, statKey, newVal = generateNewStat(weapon)
                if not success then
                    return outputChatBox("#ff0000[Hiba] #ffffffEzen a fegyveren már minden slot betelt!", player2, 255, 255, 255, true)
                end
                -- statKey a fix listából jön, nem a klienstől
                exports["ttt-sql"]:dbQueryExec("UPDATE weapons SET `" .. statKey .. "` = ? WHERE id = ?", newVal, weaponID)
                outputChatBox("#00ff00[Fejlesztés] #ffffffÚj opt: #00ff00" .. statKey .. " (+" .. newVal .. ")", player2, 255, 255, 255, true)
                done = true

            elseif upgradeType == "opt_changer" then
                local sets, desc = rerollExistingStats(weapon)
                if #sets == 0 then
                    return outputChatBox("#ff0000[Hiba] #ffffffEzen a fegyveren még nincs opt, amit cserélni lehetne!", player2, 255, 255, 255, true)
                end
                exports["ttt-sql"]:dbQueryExec("UPDATE weapons SET " .. table.concat(sets, ", ") .. " WHERE id = ?", weaponID)
                outputChatBox("#00ff00[Opt cserélő] #ffffffÚj értékek: #00ff00" .. table.concat(desc, ", "), player2, 255, 255, 255, true)
                done = true

            elseif upgradeType == "curse_remover" then
                local c1, c2 = weapon.curse_1_type, weapon.curse_2_type
                if (not c1 or c1 == "") and (not c2 or c2 == "") then
                    return outputChatBox("#ff0000[Hiba] #ffffffEzen a fegyveren nincs átok!", player2, 255, 255, 255, true)
                end
                exports["ttt-sql"]:dbQueryExec("UPDATE weapons SET curse_1_type = NULL, curse_1_value = 0, curse_2_type = NULL, curse_2_value = 0 WHERE id = ?", weaponID)
                outputChatBox("#00ff00[Átoktörő] #ffffffAz átkok eltávolítva a fegyverről!", player2, 255, 255, 255, true)
                done = true
            end

            if done then
                -- Item levonása (csak ha van; a WHERE véd a mínusz ellen)
                exports["ttt-sql"]:dbQueryExec("UPDATE inventory SET `" .. upgradeType .. "` = `" .. upgradeType .. "` - 1 WHERE owner_name = ? AND `" .. upgradeType .. "` > 0", playerName)
                -- Frissítés a kliensnél (fegyverek + itemek + equipped cache)
                setTimer(function(pl)
                    if isElement(pl) then syncWeapons(pl) end
                end, 200, 1, player2)
            end
        end, {player}, db, "SELECT * FROM inventory WHERE owner_name = ? LIMIT 1", playerName)
    end, {p}, db, "SELECT * FROM weapons WHERE id = ? AND owner_name = ? LIMIT 1", weaponID, playerName)
end)
