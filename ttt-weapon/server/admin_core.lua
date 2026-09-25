-- Admin szint ellenőrzés (a ttt-admin "admin" elementData kulcsát használja)
function isPlayerAdmin(player, minLevel)
    if not player or getElementType(player) == "console" then return true end
    return (tonumber(getElementData(player, "admin")) or 0) >= (minLevel or 1)
end

-- Csak ezek az oszlopok módosíthatók /setweaponstat-tal (SQL injection ellen)
local EDITABLE_STATS = {
    durability = "number", mod_head_dmg = "number", mod_body_dmg = "number", mod_arm_dmg = "number", mod_leg_dmg = "number",
    buff_fire = "number", buff_stun = "number", buff_poison = "number", buff_life_drain = "number",
    reload_speed_mod = "number", ammo_capacity_mod = "number", fire_mode = "string",
    curse_1_type = "string", curse_1_value = "number", curse_2_type = "string", curse_2_value = "number",
}

local function reloadAll()
    for _, p in ipairs(getElementsByType("player")) do syncWeapons(p) end
end

-- /giveweapon [Név] [WeaponID] (Admin+)
addCommandHandler("giveweapon", function(player, cmd, targetName, weaponID)
    if not isPlayerAdmin(player) then return end
    local wID = tonumber(weaponID)
    if not wID then
        return outputChatBox("Használat: /giveweapon [Név] [WeaponID]", player, 255, 255, 255)
    end
    local target = getPlayerFromName(targetName or "") or player
    if not target or getElementType(target) ~= "player" then
        return outputChatBox("[SQL] Játékos nem található!", player, 255, 0, 0)
    end
    giveWeaponToPlayer(target, wID)
    outputChatBox("[SQL] Fegyver beírva a(z) " .. getPlayerName(target) .. " névhez!", player, 0, 255, 0)
end)

-- /setweaponstat [WeaponDB_ID] [Stat_Oszlop] [Érték] (Admin+)
addCommandHandler("setweaponstat", function(player, cmd, dbID, statName, value)
    if not isPlayerAdmin(player) then return end
    dbID = tonumber(dbID)
    local kind = statName and EDITABLE_STATS[statName]
    if not dbID or not kind then
        return outputChatBox("Használat: /setweaponstat [ID] [oszlop] [érték] - oszlopok: durability, mod_*_dmg, buff_*, reload_speed_mod, ammo_capacity_mod, fire_mode, curse_*", player, 255, 255, 255)
    end
    if kind == "number" then
        value = tonumber(value)
        if not value then return outputChatBox("Számot adj meg!", player, 255, 0, 0) end
    end

    exports["ttt-sql"]:dbQueryExec("UPDATE weapons SET `" .. statName .. "` = ? WHERE id = ?", value, dbID)
    outputChatBox("[Admin] Stat frissítve! (ID: " .. dbID .. " | " .. statName .. " = " .. tostring(value) .. ")", player, 0, 255, 0)
    reloadAll()
end)

-- /delweapon [WeaponDB_ID] (Admin+)
addCommandHandler("delweapon", function(player, cmd, dbID)
    if not isPlayerAdmin(player) then return end
    dbID = tonumber(dbID)
    if not dbID then return end
    exports["ttt-sql"]:dbQueryExec("DELETE FROM weapons WHERE id = ?", dbID)
    outputChatBox("[Admin] Fegyver véglegesen törölve az adatbázisból! (ID: " .. dbID .. ")", player, 255, 0, 0)
    reloadAll()
end)

-- Fejlesztő item adása (közös a /giveopt és /giveitem parancsoknak)
local ITEM_KEYS = { opt_adder = true, opt_changer = true, curse_remover = true, opt = "opt_adder", changer = "opt_changer", curse = "curse_remover" }
local function giveItem(admin, targetName, itemKey, amount)
    local target = getPlayerFromName(targetName or "")
    if not target then
        -- névrészletre is keresünk
        local part = (targetName or ""):lower()
        for _, pl in ipairs(getElementsByType("player")) do
            if #part > 0 and getPlayerName(pl):lower():find(part, 1, true) then target = pl break end
        end
    end
    local key = ITEM_KEYS[itemKey] == true and itemKey or ITEM_KEYS[itemKey]
    amount = tonumber(amount) or 1
    if not target or not key or amount < 1 or amount > 1000 then return false end

    local name = getPlayerName(target)
    exports["ttt-sql"]:dbQueryExec(
        "INSERT INTO inventory (owner_name, `" .. key .. "`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `" .. key .. "` = `" .. key .. "` + ?",
        name, amount, amount)
    syncInventoryItems(target)
    outputChatBox("[Admin] " .. amount .. "x " .. key .. " adva neki: " .. name, admin, 0, 255, 0)
    outputChatBox("#7cc576[Fejlesztés] #ffffffKaptál " .. amount .. "x " .. key .. " itemet egy admintól!", target, 255, 255, 255, true)
    return true
end

-- /giveopt [Név] [mennyiség]  (Admin+) - opt_adder adása fejlesztéshez/teszthez
addCommandHandler("giveopt", function(player, cmd, targetName, amount)
    if not isPlayerAdmin(player) then return end
    if not giveItem(player, targetName, "opt_adder", amount) then
        outputChatBox("Használat: /giveopt [Név] [mennyiség]", player, 255, 255, 255)
    end
end)

-- /giveitem [Név] [opt_adder|opt_changer|curse_remover] [db] (Admin+)
addCommandHandler("giveitem", function(player, cmd, targetName, itemKey, amount)
    if not isPlayerAdmin(player) then return end
    if not giveItem(player, targetName, itemKey, amount) then
        outputChatBox("Használat: /giveitem [Név] [opt_adder/opt_changer/curse_remover] [db]", player, 255, 255, 255)
    end
end)
