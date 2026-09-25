-- server.lua - Discord bot híd (a bot külön Node.js app, ebben a repóban nincs benne)
local BOT_URL = "http://127.0.0.1:3000/adminlog"
local HEADERS = { ["Content-Type"] = "application/json" }

-- Közös küldő: MTA toJSON tömbbe csomagol ([{...}]), ezért levágjuk a [ ] zárójeleket
local function postToBot(data, tag)
    local jsonData = toJSON(data):sub(2, -2)
    fetchRemote(BOT_URL, function(_, err)
        if err ~= 0 then
            outputDebugString("[Discord-Bridge] " .. (tag or "") .. " HIBA: " .. tostring(err), 2)
        end
    end, jsonData, false, HEADERS)
end

function sendAdminLog(adminName, targetName, rankName, levelNum)
    postToBot({
        admin = tostring(adminName),
        target = tostring(targetName or "-"),
        rank = tostring(rankName or "Ismeretlen"),
        level = tonumber(levelNum) or 0,
    }, "AdminLog")
end

function sendMoneyLog(adminName, targetName, actionDesc, amount)
    postToBot({
        admin = tostring(adminName),
        target = tostring(targetName),
        rank = tostring(actionDesc),   -- pl. "Pénz levonása"
        amount = tonumber(amount) or tostring(amount),
        type = "money",
    }, "MoneyLog")
end

function sendSkinLog(adminName, targetName, details)
    postToBot({
        admin = tostring(adminName),
        target = tostring(targetName),
        rank = "Skin adása",
        details = tostring(details),
        type = "skin",
    }, "SkinLog")
end

-- Teszt parancs (írd be a játékban: /testdc)
addCommandHandler("testdc", function(player)
    if (tonumber(getElementData(player, "admin")) or 0) >= 2 then
        sendAdminLog(getPlayerName(player), "Teszt_Elek", "Szuperadmin", 3)
        outputChatBox("Teszt üzenet elküldve a botnak!", player)
    end
end)