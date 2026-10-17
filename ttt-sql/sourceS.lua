local dbHandler = false 
local _mta_dbQuery = dbQuery -- Elmentjük az eredeti MTA funkciót

-- Kapcsolati adatok: elsőként a szerver mtaserver.conf <settings>-ből / a resource settings-ből olvassuk,
-- ha nincs megadva, a lenti alapértékeket használjuk. (Élesben NE maradjon a jelszó a kódban!)
local function setting(key, default)
    local v = get(key)
    return (v ~= nil and v ~= false and v ~= "") and tostring(v) or default
end

function connectDB()
    local host   = setting("db_host", "192.168.1.50")
    local port   = setting("db_port", "3306")
    local dbName = setting("db_name", "ttt_server")
    local user   = setting("db_user", "paddy")
    local pass   = setting("db_pass", "paddy")

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

-- FIGYELEM: exporton keresztül callback függvényt NEM lehet átadni MTA-ban,
-- ezért a többi resource a getDatabaseHandler()-rel és a natív dbQuery-vel dolgozik.
-- Ez az export csak ttt-sql-en belüli használatra / kompatibilitásra maradt.
function dbQuery(callback, extraArgs, queryString, ...)
    if not dbHandler then return false end
    return _mta_dbQuery(callback, extraArgs, dbHandler, queryString, ...)
end

function getDatabaseHandler()
    return dbHandler
end