-- server.lua
local BOT_URL = "http://127.0.0.1:3000/adminlog"

function sendAdminLog(adminName, targetName, rankName, levelNum)
    local data = {
        admin = tostring(adminName),
        target = tostring(targetName),
        rank = tostring(rankName or "Ismeretlen"),
        level = tonumber(levelNum) or 0
    }
    
    local jsonData = toJSON(data)
    -- Nagyon fontos: távolítsuk el a szögletes zárójeleket!
    jsonData = jsonData:sub(2, -2) 

    -- Itt a módosítás: a fetchRemote 4. paramétere legyen a JSON string
    fetchRemote(BOT_URL, function(data, err)
        if err == 0 then
            outputDebugString("[Discord-Bridge] SIKER!")
        else
            outputDebugString("[Discord-Bridge] HIBA: " .. tostring(err))
        end
    end, jsonData, false, { ["Content-Type"] = "application/json" })
end

function sendMoneyLog(adminName, targetName, actionDesc, amount)
    local data = {
        admin = adminName,
        target = targetName,
        rank = actionDesc, -- pl. "Pénz levonás"
        amount = amount,
        type = "money" -- Fontos: ez mondja meg a botnak, hogy pénzről van szó
    }
    local jsonData = toJSON(data):sub(2, -2)
    fetchRemote("http://127.0.0.1:3000/adminlog", function(data, err) end, jsonData, false)
end

function sendSkinLog(adminName, targetName, details)
    local data = {
        admin = tostring(adminName),
        target = tostring(targetName),
        rank = "Skin adása",
        details = tostring(details),
        type = "skin" 
    }
    local jsonData = toJSON(data):sub(2, -2)
    fetchRemote(BOT_URL, function(data, err) 
        outputDebugString("[DC-SkinLog] Err: "..tostring(err)) -- Ezt nézd meg a konzolban!
    end, jsonData, false, { ["Content-Type"] = "application/json" })
end

-- Teszt parancs (írd be a játékban: /testdc)
addCommandHandler("testdc", function(player)
    if isObjectInACLGroup("user."..getAccountName(getPlayerAccount(player)), aclGetGroup("Admin")) then
        sendAdminLog(getPlayerName(player), "Teszt_Elek", "Szuperadmin", 3)
        outputChatBox("Teszt üzenet elküldve a botnak!", player)
    end
end)