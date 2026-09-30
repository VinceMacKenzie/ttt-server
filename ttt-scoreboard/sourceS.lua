-- Belépési idő (unix másodperc) elmentése, hogy a scoreboard valódi játékidőt mutasson
local function setupJoinTime(player)
    if isElement(player) then
        setElementData(player, "joinTime", getRealTime().timestamp)
    end
end

addEventHandler("onPlayerJoin", root, function() setupJoinTime(source) end)

addEventHandler("onResourceStart", resourceRoot, function()
    for _, p in ipairs(getElementsByType("player")) do setupJoinTime(p) end
end)

-- Pénz szinkronizálása a scoreboardnak: a kliens csak a saját pénzét tudja lekérni,
-- ezért 1 mp-enként frissítjük a "money" elementData-t (csak változásnál küld)
setTimer(function()
    for _, p in ipairs(getElementsByType("player")) do
        local money = getPlayerMoney(p)
        if getElementData(p, "money") ~= money then
            setElementData(p, "money", money)
        end
    end
end, 1000, 0)
