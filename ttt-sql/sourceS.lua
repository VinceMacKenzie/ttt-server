local dbHandler = false 
local _mta_dbQuery = dbQuery -- Elmentjük az eredeti MTA funkciót

function connectDB()
    local host = "192.168.1.50"
    local port = "3306"
    local dbName = "ttt_server"
    local user = "paddy"
    local pass = "paddy"

    dbHandler = dbConnect("mysql", "dbname="..dbName..";host="..host..";port="..port..";charset=utf8", user, pass, "share=1")

    if dbHandler then
        outputDebugString("[TTT-SQL] Adatbázis kapcsolat OK!")
    else
        outputDebugString("[TTT-SQL] HIBA: Kapcsolódás sikertelen! Újrapróbálás 5mp múlva...", 1)
        setTimer(connectDB, 5000, 1)
    end
end
addEventHandler("onResourceStart", resourceRoot, connectDB)

function dbQueryExec(queryString, ...)
    -- HA NINCS KAPCSOLAT, AZONNAL LÉPJEN KI, NE HÍVJA MEG AZ MTA-T
    if not dbHandler then return false end
    return dbExec(dbHandler, queryString, ...)
end

function dbQuery(callback, extraArgs, queryString, ...)
    -- HA NINCS KAPCSOLAT, AZONNAL LÉPJEN KI, NE HÍVJA MEG AZ MTA-T
    if not dbHandler then 
        return false 
    end
    -- Csak akkor hívjuk meg az MTA dbQuery-jét, ha a dbHandler létezik
    return _mta_dbQuery(callback, extraArgs, dbHandler, queryString, ...)
end

function getDatabaseHandler()
    return dbHandler
end