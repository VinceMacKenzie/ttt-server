-----------------------------------------
-- TTT SKILL - szerver oldal
-- Minden megölt játékos +1 pont a használt fegyver skilljéhez (az összevont skillek a shared.lua-ban).
-- A pontok a ttt_server "skills" táblájában vannak (user_id = users.ID), és a setPedStat-tal a GTA
-- fegyverskill statokba kerülnek (69-79), így a játékban is érezhető a fejlődés.
-- Belépéskor betöltődik az elementData-ba (skill_Pistol, ...), a kliens HUD (F1) onnan olvas.
-----------------------------------------
local KILL_CREDIT_WINDOW = 10000   -- ms: ennyi ideig számít a "lövés után meghalt" (pl. égés) még ölésnek
local SHOW_KILL_MESSAGE = true     -- kis chat üzenet minden pontszerzésnél (kikapcsolható)
local lastHit = {}                 -- [áldozat] = { attacker, weapon, tick }

addEvent("ttt:onPlayerLoaded", false)

local SKILL_BY_KEY = {}
for _, s in ipairs(SKILLS) do SKILL_BY_KEY[s.key] = s end

-----------------------------------------
-- ADATBÁZIS
-----------------------------------------
local ready, pending = false, {}

local function sqlRunning()
    local r = getResourceFromName("ttt-sql")
    return r and getResourceState(r) == "running"
end

local function createTableSQL()
    local cols = {}
    for _, s in ipairs(SKILLS) do cols[#cols + 1] = "`" .. s.key .. "` INT NOT NULL DEFAULT 0" end
    return "CREATE TABLE IF NOT EXISTS skills (user_id INT NOT NULL PRIMARY KEY, " .. table.concat(cols, ", ")
        .. ", updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
end

local function whenReady(fn)
    if ready then fn() else pending[#pending + 1] = fn end
end

-- A tábla létrehozása (ha még nincs); a ttt-sql indulására vár
local function initTable()
    if ready then return end
    if not sqlRunning() then
        setTimer(initTable, 3000, 1)
        return
    end
    exports["ttt-sql"]:dbQueryExec(createTableSQL())
    ready = true
    for _, fn in ipairs(pending) do fn() end
    pending = {}
end

-----------------------------------------
-- GTA FEGYVERSKILL (setPedStat)
-- exact = true : pontosan a pontszámra állítja (betöltés, levonás)
-- exact = false: csak felfelé emel, így a shopban vett skillt (ttt-shop, 1000-re állítja) nem veszi vissza
-----------------------------------------
local function applySkill(p, key, exact)
    local skill = SKILL_BY_KEY[key]
    if not skill or not isElement(p) then return end
    local value = math.min(MAX_SKILL, math.max(0, tonumber(getElementData(p, key)) or 0))
    for _, stat in ipairs(skill.stats) do
        if exact or (getPedStat(p, stat) or 0) < value then
            setPedStat(p, stat, value)
        end
    end
end

local function applyAllSkills(p, exact)
    for _, s in ipairs(SKILLS) do applySkill(p, s.key, exact) end
end

-----------------------------------------
-- PONT HOZZÁADÁSA (negatív érték levon; 0 és 1000 között marad)
-----------------------------------------
local function addSkill(uid, key, amount)
    if not sqlRunning() then return false end

    -- online játékosnál azonnal frissül az érték és a GTA stat is
    for _, p in ipairs(getElementsByType("player")) do
        if tonumber(getElementData(p, "charID")) == uid then
            local value = (tonumber(getElementData(p, key)) or 0) + amount
            setElementData(p, key, math.min(MAX_SKILL, math.max(0, value)))
            applySkill(p, key, amount < 0)
        end
    end

    -- a "key" csak a SKILLS listából jöhet (SKILL_BY_KEY), ezért biztonságos a lekérdezésbe írni
    local sql = string.format(
        "INSERT INTO skills (user_id, `%s`) VALUES (?, LEAST(%d, GREATEST(0, ?))) ON DUPLICATE KEY UPDATE `%s` = LEAST(%d, GREATEST(0, `%s` + ?))",
        key, MAX_SKILL, key, MAX_SKILL, key)
    whenReady(function() exports["ttt-sql"]:dbQueryExec(sql, uid, amount, amount) end)
    return true
end

-----------------------------------------
-- BELÉPÉSKOR BETÖLTÉS
-----------------------------------------
local function loadSkills(p)
    if not isElement(p) then return end
    local uid = tonumber(getElementData(p, "charID"))
    if not uid then return end

    whenReady(function()
        if not isElement(p) or not sqlRunning() then return end
        local db = exports["ttt-sql"]:getDatabaseHandler()
        if not db then return end
        dbQuery(function(qh, pl)
            local res = dbPoll(qh, 0)
            if not res or not isElement(pl) then return end   -- lekérdezési hiba: ne írjuk felül nullákkal
            local row = res[1]
            for _, s in ipairs(SKILLS) do
                setElementData(pl, s.key, math.min(MAX_SKILL, (row and tonumber(row[s.key])) or 0))
            end
            applyAllSkills(pl, true)
            if not row then exports["ttt-sql"]:dbQueryExec("INSERT IGNORE INTO skills (user_id) VALUES (?)", uid) end
        end, {p}, db, "SELECT * FROM skills WHERE user_id = ? LIMIT 1", uid)
    end)
end

addEventHandler("ttt:onPlayerLoaded", root, function() loadSkills(source) end)

addEventHandler("onResourceStart", resourceRoot, function()
    initTable()
    for _, p in ipairs(getElementsByType("player")) do loadSkills(p) end   -- már bejelentkezettek
end)

-- Újraspawnolás után biztosan érvényesek maradnak a statok
addEventHandler("onPlayerSpawn", root, function() applyAllSkills(source, false) end)

-----------------------------------------
-- ÖLÉS FIGYELÉSE
-----------------------------------------
-- A ttt-weapon saját sebzést számol (setElementHealth), ilyenkor az onPlayerWasted nem biztos,
-- hogy megkapja a gyilkost és a fegyvert. Ezért a találatokat is követjük.
addEventHandler("onPlayerDamage", root, function(attacker, weapon)
    if attacker and isElement(attacker) and getElementType(attacker) == "player"
       and attacker ~= source and WEAPON_SKILL[weapon] then
        lastHit[source] = { attacker = attacker, weapon = weapon, tick = getTickCount() }
    end
end)

addEventHandler("onPlayerWasted", root, function(_, killer, killerWeapon)
    local victim = source
    local hit = lastHit[victim]
    lastHit[victim] = nil

    local attacker, weapon = killer, killerWeapon
    local direct = killer and isElement(killer) and getElementType(killer) == "player" and WEAPON_SKILL[killerWeapon]
    if not direct then
        if hit and getTickCount() - hit.tick <= KILL_CREDIT_WINDOW then
            attacker, weapon = hit.attacker, hit.weapon
        else
            return
        end
    end

    if not isElement(attacker) or attacker == victim then return end
    -- csak körön belüli ölés számít (a lobbiban nem lehet skillt farmolni)
    if not getElementData(attacker, "tttRole") or not getElementData(victim, "tttRole") then return end

    local key = WEAPON_SKILL[weapon]
    local uid = tonumber(getElementData(attacker, "charID"))
    if not key or not uid then return end

    local before = tonumber(getElementData(attacker, key)) or 0
    if addSkill(uid, key, 1) and SHOW_KILL_MESSAGE then
        local now = tonumber(getElementData(attacker, key)) or 0
        if now > before then
            outputChatBox("#00c3ff[Skill] #ffffff+1 " .. SKILL_BY_KEY[key].label .. " (" .. now .. "/" .. MAX_SKILL .. ")",
                attacker, 255, 255, 255, true)
        end
    end
end)

addEventHandler("onPlayerQuit", root, function()
    lastHit[source] = nil
    for victim, hit in pairs(lastHit) do
        if hit.attacker == source then lastHit[victim] = nil end
    end
end)

-----------------------------------------
-- EXPORTOK (a ttt-admin parancsai használják)
-----------------------------------------
function giveSkill(userId, key, amount)
    userId, amount = tonumber(userId), tonumber(amount)
    if not userId or userId <= 0 or not amount or not SKILL_BY_KEY[key] then return false end
    return addSkill(userId, key, math.floor(amount))
end

function getSkillKeys()
    local keys = {}
    for _, s in ipairs(SKILLS) do keys[#keys + 1] = s.key end
    return keys
end
