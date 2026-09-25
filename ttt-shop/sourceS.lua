-- --- SEGÉD: LOGOLÁS (SQL + Discord) ---
local function logPurchase(player, action, price, dcType)
    local playerName = getPlayerName(player)
    exports["ttt-sql"]:dbQueryExec("INSERT INTO shop_logs (player, action, cost) VALUES (?, ?, ?)", playerName, action, price)

    local dc = getResourceFromName("ttt-dc")
    if dc and getResourceState(dc) == "running" then
        exports["ttt-dc"]:sendMoneyLog(dcType, playerName, action, price)
    end
end

-- --- VÁSÁRLÁS: a kliens csak az indexet küldi, minden mást a szerver dönt el ---
addEvent("ttt:buyItem", true)
addEventHandler("ttt:buyItem", root, function(itemIndex)
    if not client or isPedDead(client) then return end

    local role = getElementData(client, "tttRole")
    if role ~= "Traitor" and role ~= "Detective" then return end

    local item = ShopItems[tonumber(itemIndex) or 0]
    if not item or not isShopItemForRole(item, role) then return end

    local name, price, id, qty = item[1], item[2], item[3], item[4]
    if getPlayerMoney(client) < price then
        return outputChatBox("#d9534f[Shop] #ffffffNincs elég pénzed! ($" .. price .. ")", client, 255, 255, 255, true)
    end

    takePlayerMoney(client, price)
    if id == "armor" then
        setPedArmor(client, qty)
    elseif id == "medkit" then
        setElementHealth(client, qty)
    else
        giveWeapon(client, id, qty, true)
    end
    outputChatBox("#7cc576[Shop] #ffffffSikeres vásárlás: " .. name, client, 255, 255, 255, true)
    logPurchase(client, "Vett: " .. name, price, (role == "Traitor") and "BLACK MARKET" or "ARMORY")
end)

-- --- SKILL FEJLESZTÉS ---
addEvent("ttt:buySkill", true)
addEventHandler("ttt:buySkill", root, function(skillIndex)
    if not client or isPedDead(client) then return end

    local skill = ShopSkills[tonumber(skillIndex) or 0]
    if not skill then return end
    local name, price, statID = skill[1], skill[2], skill[4]

    if not statID then
        return outputChatBox("#f1c40f[Skill] #ffffffEz a fejlesztés még nem elérhető.", client, 255, 255, 255, true)
    end
    if getPedStat(client, statID) >= 1000 then
        return outputChatBox("#f1c40f[Skill] #ffffffEz a fejlesztés már a maximumon van!", client, 255, 255, 255, true)
    end
    if getPlayerMoney(client) < price then
        return outputChatBox("#d9534f[Shop] #ffffffNincs elég pénzed a fejlesztésre! ($" .. price .. ")", client, 255, 255, 255, true)
    end

    takePlayerMoney(client, price)
    setPedStat(client, statID, 1000)
    outputChatBox("#7cc576[Skill] #ffffffSikeres fejlesztés: " .. name, client, 255, 255, 255, true)
    logPurchase(client, "Skill: " .. name, price, "SKILL UPGRADE")
end)
