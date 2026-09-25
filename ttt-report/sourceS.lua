local activeReports = {}

local function getDB()
    return exports["ttt-sql"]:getDatabaseHandler()
end

local function isAdmin(p)
    return isElement(p) and (tonumber(getElementData(p, "admin")) or 0) >= 1
end

-- Számláló frissítése minden adminnál (exportált)
function refreshAdminReports()
    local count = 0
    for _ in pairs(activeReports) do count = count + 1 end
    for _, p in ipairs(getElementsByType("player")) do
        if isAdmin(p) then triggerClientEvent(p, "updateReportCount", p, count) end
    end
end

-- Betöltés SQL-ből
function loadReportsFromSQL()
    local db = getDB()
    if not db then
        outputDebugString("[TTT-REPORT] SQL handler még nem elérhető, várakozás...", 2)
        return setTimer(loadReportsFromSQL, 2000, 1)
    end
    dbQuery(function(qh)
        local res = dbPoll(qh, 0)
        if res then
            activeReports = {}
            for _, row in ipairs(res) do activeReports[row.Reports_ID] = row end
            refreshAdminReports()
            outputDebugString("[TTT-REPORT] Reportok betöltve az adatbázisból.")
        end
    end, db, "SELECT * FROM reports WHERE Active = 1")
end
addEventHandler("onResourceStart", resourceRoot, loadReportsFromSQL)

-- /report [JátékosNév] [Indok]
addCommandHandler("report", function(player, cmd, suspect, ...)
    local reason = table.concat({...}, " ")
    if not suspect or #reason < 1 then
        return outputChatBox("#ff4444[Report] #ffffffHasználat: /report [JátékosNév] [Indok]", player, 255, 255, 255, true)
    end
    local db = getDB()
    if not db then
        return outputChatBox("#ff4444[Report] #ffffffAz adatbázis nem elérhető, próbáld később!", player, 255, 255, 255, true)
    end
    local opener = getPlayerName(player)
    reason = reason:sub(1, 200)

    -- INSERT, majd a beszúrt ID-t a dbPoll 3. visszatérési értéke adja (nincs szükség időzítőre)
    dbQuery(function(qh, p)
        local _, affected, rID = dbPoll(qh, 0)
        if not rID or rID == 0 then return end
        activeReports[rID] = { Reports_ID = rID, Opener = opener, Suspect = suspect, Active = 1 }

        exports["ttt-sql"]:dbQueryExec("INSERT INTO report_messages (Report_ID, Messager, Message) VALUES (?, ?, ?)",
            rID, opener:upper(), "ÚJ REPORT! GYANÚSÍTOTT: " .. suspect .. " | INDOK: " .. reason)

        refreshAdminReports()
        if isElement(p) then
            outputChatBox("#7cc576[Report] #ffffffSikeresen beküldve! ID: " .. rID, p, 255, 255, 255, true)
        end
    end, {player}, db, "INSERT INTO reports (Opener, Suspect, Active) VALUES (?, ?, 1)", opener, suspect)
end)

-- Admin válasz
addEvent("sendReportMessage", true)
addEventHandler("sendReportMessage", root, function(reportID, message)
    if not isAdmin(client) then return end
    reportID = tonumber(reportID)
    if not reportID or type(message) ~= "string" or #message == 0 then return end
    message = message:sub(1, 200)

    exports["ttt-sql"]:dbQueryExec("INSERT INTO report_messages (Report_ID, Messager, Message, AdminLevel) VALUES (?, ?, ?, ?)",
        reportID, getPlayerName(client):upper(), message, getElementData(client, "admin") or 1)

    for _, p in ipairs(getElementsByType("player")) do
        if isAdmin(p) then triggerClientEvent(p, "receiveNewMessage", p, reportID) end
    end
end)

-- Report lista lekérése
addEvent("fetchActiveReports", true)
addEventHandler("fetchActiveReports", root, function()
    local p = client
    if not isAdmin(p) then return end
    local db = getDB()
    if not db then return end
    dbQuery(function(qh, pl)
        if not isElement(pl) then return end
        triggerClientEvent(pl, "receiveActiveReports", pl, dbPoll(qh, 0) or {})
    end, {p}, db, "SELECT * FROM reports WHERE Active = 1 ORDER BY Reports_ID ASC")
end)

-- Üzenetek lekérése egy ügyhöz
addEvent("fetchMessages", true)
addEventHandler("fetchMessages", root, function(reportID)
    local p = client
    if not isAdmin(p) then return end
    reportID = tonumber(reportID)
    local db = getDB()
    if not reportID or not db then return end
    dbQuery(function(qh, pl)
        if not isElement(pl) then return end
        triggerClientEvent(pl, "receiveMessages", pl, dbPoll(qh, 0) or {})
    end, {p}, db, "SELECT * FROM report_messages WHERE Report_ID = ? ORDER BY Message_ID ASC", reportID)
end)

-- Lezárás
addEvent("closeReport", true)
addEventHandler("closeReport", root, function(reportID)
    if not isAdmin(client) then return end
    reportID = tonumber(reportID)
    if not reportID then return end

    exports["ttt-sql"]:dbQueryExec("UPDATE reports SET Active = 0 WHERE Reports_ID = ?", reportID)
    activeReports[reportID] = nil
    refreshAdminReports()
    outputChatBox("#7cc576[Report] #ffffffSikeresen lezártad a(z) " .. reportID .. " azonosítójú ügyet.", client, 255, 255, 255, true)
end)
