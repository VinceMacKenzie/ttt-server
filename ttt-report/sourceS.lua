local activeReports = {}

-- Betöltés SQL-ből (Ugyanaz a logika, mint a skinnél)
function loadReportsFromSQL()
    local dbHandler = exports["ttt-sql"]:getDatabaseHandler()
    
    -- Csak akkor indulunk el, ha az SQL tényleg visszaadta a handlert
    if dbHandler then
        dbQuery(function(qh)
            local res = dbPoll(qh, 0)
            if res then
                activeReports = {}
                for _, row in ipairs(res) do
                    activeReports[row.Reports_ID] = row
                end
                refreshAdminReports()
                outputDebugString("[TTT-REPORT] Reportok betöltve az adatbázisból.")
            end
        end, dbHandler, "SELECT * FROM reports WHERE Active = 1")
    else
        -- Ha még nincs handler, várunk 2 mp-et és újra megpróbáljuk
        outputDebugString("[TTT-REPORT] SQL handler még nem elérhető, várakozás...", 2)
        setTimer(loadReportsFromSQL, 2000, 1)
    end
end
addEventHandler("onResourceStart", resourceRoot, loadReportsFromSQL)

-- Új report nyitása
addCommandHandler("report", function(player, cmd, suspect, ...)
    local reason = table.concat({...}, " ")
    if not suspect or #reason < 1 then
        return outputChatBox("#ff4444[Report] #ffffffHasználat: /report [JátékosNév] [Indok]", player, 255, 255, 255, true)
    end

    local opener = getPlayerName(player)
    
    -- Beszúrjuk az új reportot
    exports["ttt-sql"]:dbQueryExec("INSERT INTO reports (Opener, Suspect, Active) VALUES (?, ?, 1)", opener, suspect)
    
    -- Megkeressük az ID-t, amit az SQL generált (hogy tudjunk üzenetet fűzni hozzá)
    setTimer(function()
        local dbHandler = exports["ttt-sql"]:getDatabaseHandler()
        if dbHandler then
            dbQuery(function(qh)
                local res = dbPoll(qh, 0)
                if res and res[1] then
                    local rID = res[1].Reports_ID
                    activeReports[rID] = res[1]
                    
                    -- Első rendszerüzenet a chat táblába
                    exports["ttt-sql"]:dbQueryExec("INSERT INTO report_messages (Report_ID, Messager, Message) VALUES (?, ?, ?)", 
                        rID, opener:upper(), "ÚJ REPORT! GYANÚSÍTOTT: "..suspect.." | INDOK: "..reason)
                    
                    refreshAdminReports()
                    outputChatBox("#7cc576[Report] #ffffffSikeresen beküldve! ID: " .. rID, player, 255, 255, 255, true)
                end
            end, dbHandler, "SELECT Reports_ID FROM reports WHERE Opener = ? ORDER BY Reports_ID DESC LIMIT 1", opener)
        end
    end, 500, 1)
end)

-- Admin válasz kezelése
addEvent("sendReportMessage", true)
addEventHandler("sendReportMessage", root, function(reportID, message)
    if not client then return end
    local adminName = getPlayerName(client)
    
    -- Mentés SQL-be
    exports["ttt-sql"]:dbQueryExec("INSERT INTO report_messages (Report_ID, Messager, Message) VALUES (?, ?, ?)", 
        reportID, adminName:upper(), message)
    
    -- Értesítjük a klienseket, hogy frissítsék a chat ablakot
    triggerClientEvent(root, "receiveNewMessage", root, reportID)
end)

-- Report lista lekérése (Amikor az admin megnyitja a panelt)
addEvent("fetchActiveReports", true)
addEventHandler("fetchActiveReports", root, function()
    local p = client
    local dbHandler = exports["ttt-sql"]:getDatabaseHandler()
    if dbHandler then
        dbQuery(function(qh)
            local res = dbPoll(qh, 0)
            triggerClientEvent(p, "receiveActiveReports", p, res or {})
        end, dbHandler, "SELECT * FROM reports WHERE Active = 1")
    end
end)

-- Konkrét üzenetek lekérése egy ügyhöz
addEvent("fetchMessages", true)
addEventHandler("fetchMessages", root, function(reportID)
    local p = client
    local dbHandler = exports["ttt-sql"]:getDatabaseHandler()
    if dbHandler then
        dbQuery(function(qh)
            local res = dbPoll(qh, 0)
            triggerClientEvent(p, "receiveMessages", p, res or {})
        end, dbHandler, "SELECT * FROM report_messages WHERE Report_ID = ? ORDER BY Message_ID ASC", reportID)
    end
end)

-- Számláló frissítése minden adminnál
function refreshAdminReports()
    local count = 0
    for _ in pairs(activeReports) do count = count + 1 end
    triggerClientEvent(root, "updateReportCount", root, count)
end

addEvent("closeReport", true)
addEventHandler("closeReport", root, function(reportID)
    if not reportID then return end
    local adminName = getPlayerName(client)
    
    -- SQL frissítés: Active = 0
    exports["ttt-sql"]:dbQueryExec("UPDATE reports SET Active = 0 WHERE Reports_ID = ?", reportID)
    
    -- Törlés a helyi táblából és adminok értesítése
    activeReports[reportID] = nil
    refreshAdminReports()
    
    -- Üzenet az adminnak
    outputChatBox("#7cc576[Report] #ffffffSikeresen lezártad a(z) " .. reportID .. " azonosítójú ügyet.", client, 255, 255, 255, true)
end)