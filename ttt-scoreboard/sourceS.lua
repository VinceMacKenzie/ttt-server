local function setupJoinTick(player)
    if isElement(player) then
        -- A 'true' a végén biztosítja, hogy minden kliens azonnal megkapja az adatot
        setElementData(player, "joinTick", getTickCount(), true)
    end
end

addEventHandler("onPlayerJoin", root, function()
    setupJoinTick(source)
end)

addEventHandler("onResourceStart", resourceRoot, function()
    for _, p in ipairs(getElementsByType("player")) do
        setupJoinTick(p)
    end
end)