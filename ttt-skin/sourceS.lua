-- Szerveroldali cache: ownedCache[player] = {[skinID] = "Név"}
-- Ebből döntjük el, hogy egy skin ingyen felvehető-e (a kliensnek nem hiszünk).
local ownedCache = {}

local function loadOwnedSkins(p)
    if not isElement(p) then return end
    local db = exports["ttt-sql"]:getDatabaseHandler()
    if not db then return end
    local playerName = getPlayerName(p)

    dbQuery(function(qh, player)
        if not isElement(player) then return end
        local res = dbPoll(qh, 0)
        local owned = {}
        if res then
            for _, row in ipairs(res) do
                owned[tonumber(row.skin_id)] = row.skin_name or "Ismeretlen Skin"
            end
        end
        ownedCache[player] = owned
        triggerClientEvent(player, "ttt:receiveOwnedSkins", player, owned)
    end, {p}, db, "SELECT skin_id, skin_name FROM owned_skins WHERE player_name = ?", playerName)
end

-- Kliens kéri (resource start), vagy a ttt-admin triggereli /giveskin után (ilyenkor source a játékos)
addEvent("ttt:requestOwnedSkins", true)
addEventHandler("ttt:requestOwnedSkins", root, function()
    loadOwnedSkins(client or source)
end)

addEventHandler("onPlayerQuit", root, function() ownedCache[source] = nil end)

-- Vásárlás / felvétel: a kliens csak a skin ID-t küldi
addEvent("ttt:buySkin", true)
addEventHandler("ttt:buySkin", root, function(skinID)
    local p = client
    if not p then return end
    skinID = tonumber(skinID)
    local skin = SkinByID[skinID]
    if not skin then return end

    local owned = ownedCache[p] or {}
    local displayName = getSkinDisplayName(skinID)

    -- Már megvan (vagy ingyenes alap skin): csak felvesszük
    if owned[skinID] or skin[2] == 0 then
        setElementModel(p, skinID)
        return outputChatBox("#7cc576[Skin] #ffffffSkin sikeresen felvéve: #00c3ff" .. displayName, p, 255, 255, 255, true)
    end

    local price = skin[2]
    if getPlayerMoney(p) < price then
        return outputChatBox("#d9534f[Skin] #ffffffNincs elég pénzed a vásárláshoz! ($" .. price .. ")", p, 255, 255, 255, true)
    end

    takePlayerMoney(p, price)
    setElementModel(p, skinID)
    owned[skinID] = displayName
    ownedCache[p] = owned

    exports["ttt-sql"]:dbQueryExec("INSERT INTO owned_skins (player_name, skin_id, skin_name, price) VALUES (?, ?, ?, ?)",
        getPlayerName(p), skinID, displayName, price)
    exports["ttt-sql"]:dbQueryExec("INSERT INTO shop_logs (player, action, cost) VALUES (?, ?, ?)",
        getPlayerName(p), "Skin: " .. displayName, price)

    outputChatBox("#7cc576[Skin] #ffffffSikeres vásárlás: #00c3ff" .. displayName, p, 255, 255, 255, true)
    triggerClientEvent(p, "ttt:addOwnedSkinToClient", p, skinID, displayName)
end)
