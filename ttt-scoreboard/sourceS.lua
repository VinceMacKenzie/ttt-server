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
