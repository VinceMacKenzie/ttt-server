addEvent("applyWeaponUpgrade", true)
addEventHandler("applyWeaponUpgrade", root, function(weaponID, upgradeType)
    local db = exports["ttt-sql"]:getDatabaseHandler()
    local playerName = getPlayerName(client)

    -- 1. Lekérjük a fegyver jelenlegi statjait az adatbázisból
    dbQuery(function(qh)
        local res = dbPoll(qh, 0)
        if not res or #res == 0 then return end
        local weapon = res[1]

        -- 2. Ellenőrizzük, van-e a játékosnak ilyen itemje
        dbQuery(function(qh2)
            local invRes = dbPoll(qh2, 0)
            if not invRes or #invRes == 0 or (invRes[1][upgradeType] or 0) <= 0 then
                outputChatBox("#ff0000[Hiba] #ffffffNincs elég fejlesztő itemed!", client, 255, 255, 255, true)
                return
            end

            -- 3. SZABÁLYOK ÉS FEJLESZTÉS
            if upgradeType == "opt_adder" then
                local success, statKey, newVal = generateNewStat(weapon)
                if success then
                    dbExec(db, "UPDATE weapons SET " .. statKey .. " = ? WHERE id = ?", newVal, weaponID)
                    dbExec(db, "UPDATE inventory SET " .. upgradeType .. " = " .. upgradeType .. " - 1 WHERE owner_name = ?", playerName)
                    outputChatBox("#00ff00[Fejlesztés] #ffffffSikeresen hozzáadva: #00ff00" .. statKey, client, 255, 255, 255, true)
                else
                    outputChatBox("#ff0000[Hiba] #ffffffEzen a fegyveren már minden slot betelt!", client, 255, 255, 255, true)
                end
            end

            -- Adatok frissítése a kliensnél
            triggerEvent("requestPlayerWeapons", client)
            -- Itt küldd el az új inventory adatokat is!
        end, db, "SELECT * FROM inventory WHERE owner_name = ?", playerName)
    end, db, "SELECT * FROM weapons WHERE id = ?", weaponID)
end)

-- Stat generáló segédfüggvény a szabályaid alapján
function generateNewStat(w)
    -- 3 Sebzés slot (Head, Body, Arm/Leg)
    if (w.mod_head_dmg or 0) == 0 then return true, "mod_head_dmg", math.random(5, 15) end
    if (w.mod_body_dmg or 0) == 0 then return true, "mod_body_dmg", math.random(5, 10) end
    if (w.mod_arm_dmg or 0) == 0 then return true, "mod_arm_dmg", math.random(3, 8) end

    -- 1 Buff slot
    local buffs = {"buff_fire", "buff_stun", "buff_poison", "buff_life_drain"}
    for _, b in ipairs(buffs) do
        if (w[b] or 0) == 0 then return true, b, 1 end
    end

    -- 1 Utility slot
    if (w.reload_speed_mod or 0) == 0 then return true, "reload_speed_mod", math.random(10, 25) end

    return false -- Ha minden tele van
end