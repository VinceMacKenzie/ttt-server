-----------------------------------------
-- TTT CORE - SZERVER OLDAL
-----------------------------------------
setGameType("TTT")

local SPAWN = {1948.875, -1713.143, 13.547}
local MIN_PLAYERS = 2          -- Teszteléshez 1, élesben 2+
local ROUND_RESTART_DELAY = 10000

local roundTimer = nil
local startTimer = nil
local roundDuration = 150
local isRoundRunning = false
local corpses = {}             -- {ped, ped, ...} - kör végén töröljük

addEvent("ttt:onRoundStart", false)
addEvent("ttt:onRoundEnd", false)

-- Segéd: kör indítás ütemezése (csak egy időzítő fusson egyszerre)
local function scheduleRoundStart(delay)
    if isTimer(startTimer) then killTimer(startTimer) end
    startTimer = setTimer(startTTTRound, delay, 1)
end

local function clearCorpses()
    for _, c in ipairs(corpses) do
        if isElement(c) then destroyElement(c) end
    end
    corpses = {}
end

local function respawnForRound(player)
    setElementFrozen(player, false)
    spawnPlayer(player, SPAWN[1] + math.random(-3, 3), SPAWN[2] + math.random(-3, 3), SPAWN[3], math.random(0, 359), getElementModel(player), 0, 0)
    setElementHealth(player, 100)
    setCameraTarget(player, player)
    fadeCamera(player, true)
end

function startTTTRound()
    if isRoundRunning then return end
    local players = getElementsByType("player")
    if #players < MIN_PLAYERS then return end

    isRoundRunning = true
    clearCorpses()

    -- Játékosok megkeverése (Fisher-Yates)
    local shuffled = {}
    for _, p in ipairs(players) do table.insert(shuffled, p) end
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    -- Szerepek kiosztása
    for i, player in ipairs(shuffled) do
        respawnForRound(player)
        if i == 1 then
            setElementData(player, "tttRole", "Traitor")
            outputChatBox("#e74c3c[TTT] Te ÁRULÓ (Traitor) vagy!", player, 255, 255, 255, true)
        elseif i == 2 and #shuffled >= 3 then
            setElementData(player, "tttRole", "Detective")
            outputChatBox("#3498db[TTT] Te NYOMOZÓ (Detective) vagy!", player, 255, 255, 255, true)
        else
            setElementData(player, "tttRole", "Innocent")
            outputChatBox("#2ecc71[TTT] Te ÁRTATLAN (Innocent) vagy!", player, 255, 255, 255, true)
        end
    end

    outputChatBox(string.format("#f1c40f[TTT] A kör elkezdődött! Idő: %d:%02d", math.floor(roundDuration / 60), roundDuration % 60), root, 255, 255, 255, true)
    triggerClientEvent(root, "ttt:updateTime", root, roundDuration * 1000)

    if isTimer(roundTimer) then killTimer(roundTimer) end
    roundTimer = setTimer(endRoundByTime, roundDuration * 1000, 1)

    -- Más resource-ok (pl. ttt-replay) innen tudják, hogy elindult a kör
    triggerEvent("ttt:onRoundStart", root, roundDuration)
end

function checkTTTWin()
    if not isRoundRunning then return end
    local aliveTraitors, aliveInnocents = 0, 0

    for _, p in ipairs(getElementsByType("player")) do
        if not isPedDead(p) then
            local role = getElementData(p, "tttRole")
            if role == "Traitor" then aliveTraitors = aliveTraitors + 1
            elseif role == "Innocent" or role == "Detective" then aliveInnocents = aliveInnocents + 1 end
        end
    end

    if aliveTraitors == 0 then
        outputChatBox("#2ecc71[TTT] Az Innocentek győztek!", root, 255, 255, 255, true)
        stopTTTRound("Innocent")
    elseif aliveInnocents == 0 then
        outputChatBox("#e74c3c[TTT] A Traitorok győztek!", root, 255, 255, 255, true)
        stopTTTRound("Traitor")
    end
end

function stopTTTRound(winner)
    isRoundRunning = false
    triggerEvent("ttt:onRoundEnd", root, winner or "none")
    if isTimer(roundTimer) then killTimer(roundTimer) end
    triggerClientEvent(root, "ttt:updateTime", root, 0)
    for _, p in ipairs(getElementsByType("player")) do
        setElementData(p, "tttRole", false)
        setElementFrozen(p, false)
    end
    outputChatBox("#ffffff[TTT] Új kör indul " .. (ROUND_RESTART_DELAY / 1000) .. " másodperc múlva...", root, 255, 255, 255, true)
    scheduleRoundStart(ROUND_RESTART_DELAY)
end

function endRoundByTime()
    if isRoundRunning then
        outputChatBox("#2ecc71[TTT] Lejárt az idő! Az Innocentek győztek.", root, 255, 255, 255, true)
        stopTTTRound("Innocent")
    end
end

addEventHandler("onPlayerJoin", root, function()
    if not isRoundRunning then scheduleRoundStart(5000) end
end)

-- Ha valaki kilép kör közben, újra kell számolni a győzelmet
addEventHandler("onPlayerQuit", root, function()
    if isRoundRunning then setTimer(checkTTTWin, 100, 1) end
end)

addCommandHandler("setttt", function(sourceElement, cmd, sec)
    local isConsole = (not sourceElement or getElementType(sourceElement) == "console")
    local canAccess = isConsole or (getElementData(sourceElement, "admin") or 0) >= 2
    if not canAccess then return end

    local s = tonumber(sec)
    if s and s >= 120 and s <= 240 then
        roundDuration = s
        outputChatBox("#7cc576[TTT] Köridő beállítva: " .. s .. " mp.", sourceElement or root, 255, 255, 255, true)
    elseif not isConsole then
        outputChatBox("#d9534f[TTT] Használat: /setttt [120-240]", sourceElement, 255, 255, 255, true)
    end
end)

-----------------------------------------
-- HULLÁK
-----------------------------------------
local function setupCorpse(corpse, name, role, weapon, timeStr)
    setElementFrozen(corpse, true)
    setElementData(corpse, "isCorpse", true)
    setElementData(corpse, "corpse:name", name)
    setElementData(corpse, "corpse:role", role or "Innocent")
    setElementData(corpse, "corpse:weapon", weapon or "Ismeretlen")
    setElementData(corpse, "corpse:time", timeStr or "Ismeretlen")
    setPedAnimation(corpse, "WCC", "ped_dead_front", -1, false, false, false, true)
    table.insert(corpses, corpse)
    return corpse
end

function createCorpse(player, weapon, timeOffset)
    local x, y, z = getElementPosition(player)
    local _, _, rz = getElementRotation(player)
    local corpse = createPed(getElementModel(player), x, y, z, rz)
    if not corpse then return false end
    setElementInterior(corpse, getElementInterior(player))
    setElementDimension(corpse, getElementDimension(player))
    return setupCorpse(corpse, getPlayerName(player), getElementData(player, "tttRole"), weapon, timeOffset)
end

-- Teszt parancs: letesz egy hullát eléd
addCommandHandler("testcorpse", function(player)
    if (getElementData(player, "admin") or 0) < 1 then return end
    local x, y, z = getElementPosition(player)
    local _, _, rz = getElementRotation(player)
    local tx = x + math.sin(math.rad(-rz)) * 2
    local ty = y + math.cos(math.rad(-rz)) * 2
    local corpse = createPed(24, tx, ty, z, rz)
    if corpse then
        setupCorpse(corpse, "Paddy (TESZT)", "Traitor", "Desert Eagle", "02:45")
        outputChatBox("#7cc576[TTT] #ffffffTeszt hulla létrehozva!", player, 255, 255, 255, true)
    end
end)

-- /tc [üzenet] - Traitor chat
addCommandHandler("tc", function(player, cmd, ...)
    if getElementData(player, "tttRole") ~= "Traitor" then return end
    local msg = table.concat({...}, " ")
    if #msg == 0 then return end
    for _, p in ipairs(getElementsByType("player")) do
        if getElementData(p, "tttRole") == "Traitor" then
            outputChatBox("#e74c3c[Traitor Chat] #ffffff" .. getPlayerName(player) .. ": " .. msg, p, 255, 255, 255, true)
        end
    end
end)

-- Halál: hulla létrehozása, "szellem" eltüntetése, győzelem ellenőrzése
addEventHandler("onPlayerWasted", root, function(totalAmmo, attacker, weapon)
    if isRoundRunning then
        local p = source

        local timeStr = "00:00"
        if isTimer(roundTimer) then
            local ms = getTimerDetails(roundTimer)
            timeStr = string.format("%02d:%02d", math.floor(ms / 60000), math.floor((ms % 60000) / 1000))
        end

        local weaponName = weapon and getWeaponNameFromID(weapon) or "Ismeretlen"
        createCorpse(p, weaponName, timeStr)

        -- Az MTA alap hulláját elrejtjük: messzire spawnoljuk és lefagyasztjuk
        setTimer(function()
            if isElement(p) and isRoundRunning then
                spawnPlayer(p, 0, 0, -100, 0, getElementModel(p), 0, 0)
                setElementFrozen(p, true)
                setElementData(p, "tttRole", false)  -- halott: nem számít a győzelembe
            end
        end, 1000, 1)
    end

    setTimer(checkTTTWin, 500, 1)
end)
