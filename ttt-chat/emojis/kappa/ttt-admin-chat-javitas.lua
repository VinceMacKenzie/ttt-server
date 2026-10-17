-- ttt-admin: ezt a részt cseréld le a meglévő onPlayerChat handlerre

-- A név a ttt-chat-től jön (effektes jelölés, ha a játékosnak van effektje).
-- Ha a ttt-chat épp nem fut, sima névvel megy tovább.
local function getChatDisplayName(player)
    local res = getResourceFromName("ttt-chat")
    if res and getResourceState(res) == "running" then
        return exports["ttt-chat"]:getEffectName(player)
    end
    return getPlayerName(player)
end

addEventHandler("onPlayerChat", root, function(message, messageType)
    if messageType ~= 0 then return end
    cancelEvent()
    local lvl = getLevel(source)
    local pName = getPlayerName(source)
    local dName = getChatDisplayName(source)
    local rank = adminRanks[lvl]
    if rank then
        outputChatBox(rank.color .. "[" .. rank.name .. "] #ffffff" .. dName .. ": " .. message, root, 255, 255, 255, true)
    else
        outputChatBox("#ffffff" .. dName .. ": " .. message, root, 255, 255, 255, true)
    end
    outputServerLog("CHAT: " .. pName .. ": " .. message)
end)
