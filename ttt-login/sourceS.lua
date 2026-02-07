local START_MONEY = 1000
local START_SKIN = 0

local function setupPlayerAccount(player, data)
    if not isElement(player) then return end
    setElementData(player, "charID", data.ID)
    setElementData(player, "accName", data["Név"])
    setElementData(player, "adminLevel", tonumber(data.adminLevel) or 0)
    setElementData(player, "money", tonumber(data.Money) or 0)
    
    setPlayerMoney(player, tonumber(data.Money) or 0)
    setElementModel(player, START_SKIN)
    spawnPlayer(player, 1948.875, -1713.143, 13.547)
    fadeCamera(player, true)
    setCameraTarget(player, player)
end

addEventHandler("onPlayerJoin", root, function()
    local player = source
    local serial = getPlayerSerial(player)

    -- FONTOS: Itt dbQuery kell, mert választ várunk a SELECT-re!
    exports["ttt-sql"]:dbQuery(function(qh, p)
        if not isElement(p) then return end
        local res = dbPoll(qh, 0)

        if res and #res > 0 then
            -- LÉTEZŐ JÁTÉKOS
            setupPlayerAccount(p, res[1])
            outputChatBox("#7cc576[TTT] #ffffffÜdv újra a szerveren!", p, 255, 255, 255, true)
        else
            -- ÚJ JÁTÉKOS REGISZTRÁCIÓ
            local guestName = "Guest_" .. math.random(100, 999)
            
            -- Itt dbQueryExec kell, mert csak beírunk (INSERT)
            local insert = exports["ttt-sql"]:dbQueryExec(
                "INSERT INTO users (`Név`, `adminLevel`, `Serial`, `Money`, `Kill`, `PremiumPoint`) VALUES (?, ?, ?, ?, ?, ?)",
                guestName, 0, serial, START_MONEY, 0, 0
            )

            if insert then
                -- Beszúrás után lekérjük az adatokat, hogy megkapjuk az új ID-t
                exports["ttt-sql"]:dbQuery(function(qh2, p2)
                    if not isElement(p2) then return end
                    local res2 = dbPoll(qh2, 0)
                    if res2 and res2[1] then
                        setupPlayerAccount(p2, res2[1])
                        outputChatBox("#7cc576[TTT] #ffffffSikeres automatikus regisztráció!", p2, 255, 255, 255, true)
                    end
                end, p, "SELECT * FROM users WHERE Serial = ?", serial)
            end
        end
    end, player, "SELECT * FROM users WHERE Serial = ?", serial)
end)

addEventHandler("onPlayerQuit", root, function()
    local id = getElementData(source, "charID")
    if id then
        local money = getPlayerMoney(source)
        local admin = getElementData(source, "adminLevel") or 0
        -- Mentésnél dbQueryExec kell (UPDATE)
        exports["ttt-sql"]:dbQueryExec("UPDATE users SET Money = ?, adminLevel = ? WHERE ID = ?", money, admin, id)
    end
end)