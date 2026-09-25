-- Cache: activePlayerWeapons[player] = { sorok... } (a teljes inventory)
--        equippedByModel[player]     = { [weapon_model] = stats }  (csak a slotban lévők)
-- A sebzéslogika a kézben lévő fegyver modelljét ebben a táblában keresi SZINKRON módon,
-- így nincs időzítés-probléma (korábban egy aszinkron lekérdezés futott fegyverváltáskor).
local activePlayerWeapons = {}
local equippedByModel = {}

addEvent("requestPlayerWeapons", true)
addEvent("updateWeaponSlot", true)
addEvent("reloadPlayerWeapons", false) -- csak szerveroldalról hívjuk (triggerEvent)

local function getDB()
    return exports["ttt-sql"]:getDatabaseHandler()
end

-- SQL sor konvertálása tiszta táblává
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
        buff_fire = tonumber(row.buff_fire) or 0,
        buff_poison = tonumber(row.buff_poison) or 0,
        reload_speed_mod = tonumber(row.reload_speed_mod) or 0,
        curse_1_type = row.curse_1_type, curse_1_value = tonumber(row.curse_1_value) or 0,
        curse_2_type = row.curse_2_type, curse_2_value = tonumber(row.curse_2_value) or 0,
    }
end

-- Fejlesztő itemek (inventory tábla) küldése a kliensnek
function syncInventoryItems(player)
    if not isElement(player) then return end
    local db = getDB()
    if not db then return end
    dbQuery(function(qh, p)
        if not isElement(p) then return end
        local res = dbPoll(qh, 0)
        local row = res and res[1] or {}
        triggerClientEvent(p, "receivePlayerItems", p, {
            opt_adder = tonumber(row.opt_adder) or 0,
            opt_changer = tonumber(row.opt_changer) or 0,
            curse_remover = tonumber(row.curse_remover) or 0,
        })
    end, {player}, db, "SELECT opt_adder, opt_changer, curse_remover FROM inventory WHERE owner_name = ? LIMIT 1", getPlayerName(player))
end

-- Teljes inventory betöltése + equipped cache újraépítése
function syncWeapons(player)
    if not isElement(player) then return end
    local db = getDB()
    if not db then return end

    dbQuery(function(qh, p)
        if not isElement(p) then return end
        local res = dbPoll(qh, 0) or {}
        activePlayerWeapons[p] = res

        local equipped = {}
        for _, row in ipairs(res) do
            if tonumber(row.is_equipped) == 1 and tonumber(row.slot_type) > 0 then
                equipped[tonumber(row.weapon_model)] = getStatsFromRow(row)
            end
        end
        equippedByModel[p] = equipped

        triggerClientEvent(p, "receivePlayerWeapons", p, res)
    end, {player}, db, "SELECT * FROM weapons WHERE owner_name = ?", getPlayerName(player))
    syncInventoryItems(player)
end

-- A kézben lévő fegyverhez tartozó statok (szinkron, cache-ből)
function getPlayerActiveStats(player)
    local equipped = equippedByModel[player]
    if not equipped then return nil end
    local model = getPedWeapon(player)
    if not model or model == 0 then return nil end
    return equipped[model]
end

-- Exportált: a játékos betöltött fegyverei
function getPlayerWeapons(player)
    return activePlayerWeapons[player] or {}
end

-- ESEMÉNYEK
addEventHandler("requestPlayerWeapons", root, function() syncWeapons(client or source) end)
addEventHandler("reloadPlayerWeapons", root, function() syncWeapons(source) end)

-- Belépéskor (fiók betöltése után) azonnal töltsük be, hogy a shopban vett M4 rögtön kapja az optokat
addEvent("ttt:onPlayerLoaded", false)
addEventHandler("ttt:onPlayerLoaded", root, function() syncWeapons(source) end)

addEventHandler("onPlayerQuit", root, function()
    activePlayerWeapons[source] = nil
    equippedByModel[source] = nil
end)

addEventHandler("updateWeaponSlot", root, function(weaponID, newSlot)
    local player = client
    if not player then return end
    local db = getDB()
    if not db then return end
    local playerName = getPlayerName(player)
    weaponID, newSlot = tonumber(weaponID), tonumber(newSlot)
    if not weaponID or not newSlot or newSlot < 0 or newSlot > 5 then return end

    if newSlot > 0 then
        -- Aki eddig ebben a slotban volt, megy a táskába; a húzott fegyver a slotba
        dbQuery(function(qh, p)
            dbPoll(qh, 0)
            dbQuery(function(qh2, p2)
                dbPoll(qh2, 0)
                if isElement(p2) then syncWeapons(p2) end
            end, {p}, db, "UPDATE weapons SET is_equipped = 1, slot_type = ? WHERE id = ? AND owner_name = ?", newSlot, weaponID, playerName)
        end, {player}, db, "UPDATE weapons SET is_equipped = 0, slot_type = 0 WHERE owner_name = ? AND slot_type = ?", playerName, newSlot)
    else
        dbQuery(function(qh, p)
            dbPoll(qh, 0)
            if isElement(p) then syncWeapons(p) end
        end, {player}, db, "UPDATE weapons SET is_equipped = 0, slot_type = 0 WHERE id = ? AND owner_name = ?", weaponID, playerName)
    end
end)

-- /stats - a kézben lévő fegyver statisztikái
addCommandHandler("stats", function(player)
    local stats = getPlayerActiveStats(player)
    outputChatBox("--- Aktuális Fegyver Statisztikák ---", player, 0, 255, 255)
    if stats then
        outputChatBox("Modell: #ffffff" .. (getWeaponNameFromID(stats.weapon_model) or "Ismeretlen") .. " (" .. stats.weapon_model .. ")", player, 200, 200, 200, true)
        outputChatBox("Serial: #ffffff" .. stats.serial_number, player, 200, 200, 200, true)
        outputChatBox("Durability: #ffffff" .. stats.durability .. "%", player, 200, 200, 200, true)
        outputChatBox("HS bónusz: #00ff00+" .. stats.mod_head_dmg .. "% | Test: +" .. stats.mod_body_dmg .. "% | Kar: +" .. stats.mod_arm_dmg .. "% | Láb: +" .. stats.mod_leg_dmg .. "%", player, 200, 200, 200, true)
        outputChatBox("Buffok: tűz " .. stats.buff_fire .. " | sokk " .. stats.buff_stun .. " | méreg " .. stats.buff_poison .. " | életszívás " .. stats.buff_life_drain, player, 200, 200, 200, true)
    else
        local model = getPedWeapon(player)
        local equipped = equippedByModel[player] or {}
        local n = 0
        for _ in pairs(equipped) do n = n + 1 end
        outputChatBox("Nincs aktív fegyver adat! (kézben: " .. tostring(model) .. ", slotban lévő fegyverek: " .. n .. ")", player, 255, 0, 0)
        outputChatBox("Tipp: F2 -> húzd a fegyvert egy aktív slotba, és ugyanazt a fegyvert tartsd a kezedben.", player, 200, 200, 200)
    end
    outputChatBox("------------------------------------", player, 0, 255, 255)
end)
