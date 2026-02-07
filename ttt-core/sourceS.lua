-----------------------------------------
-- TTT CORE - SZERVER OLDAL
-----------------------------------------
setGameType("TTT")
local roundTimer = nil
local roundDuration = 150 
local isRoundRunning = false

function startTTTRound()
    local players = getElementsByType("player")
    
    if #players < 2 then -- Teszteléshez 1, élesben 2+
        return 
    end

    isRoundRunning = true
    
    -- Játékosok megkeverése
    local shuffled = {}
    for _, p in ipairs(players) do table.insert(shuffled, p) end
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    -- Csapatok kiosztása
    for i, player in ipairs(shuffled) do
        setElementData(player, "tttRole", false)
        setElementHealth(player, 100)
        
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

    outputChatBox("#f1c40f[TTT] A kör elkezdődött! Idő: " .. math.floor(roundDuration/60) .. ":" .. (roundDuration%60), root, 255, 255, 255, true)
    
    -- Kliens óra indítása
    triggerClientEvent(root, "ttt:updateTime", root, roundDuration * 1000)
    
    if isTimer(roundTimer) then killTimer(roundTimer) end
    roundTimer = setTimer(endRoundByTime, roundDuration * 1000, 1)
end

function checkTTTWin()
    if not isRoundRunning then return end
    local aliveTraitors = 0
    local aliveInnocents = 0

    for _, p in ipairs(getElementsByType("player")) do
        if not isPedDead(p) then
            local role = getElementData(p, "tttRole")
            if role == "Traitor" then aliveTraitors = aliveTraitors + 1
            elseif role == "Innocent" or role == "Detective" then aliveInnocents = aliveInnocents + 1 end
        end
    end

    if aliveTraitors == 0 then
        outputChatBox("#2ecc71[TTT] Az Innocentek győztek!", root, 255, 255, 255, true)
        stopTTTRound()
    elseif aliveInnocents == 0 then
        outputChatBox("#e74c3c[TTT] A Traitorok győztek!", root, 255, 255, 255, true)
        stopTTTRound()
    end
end

function stopTTTRound()
    isRoundRunning = false
    if isTimer(roundTimer) then killTimer(roundTimer) end
    -- Töröljük a szerepeket a kör végén
    for _, p in ipairs(getElementsByType("player")) do setElementData(p, "tttRole", false) end
    outputChatBox("#ffffff[TTT] Új kör indul 10 másodperc múlva...", root, 255, 255, 255, true)
    setTimer(startTTTRound, 10000, 1)
end

function endRoundByTime()
    if isRoundRunning then
        outputChatBox("#2ecc71[TTT] Lejárt az idő! Az Innocentek győztek.", root, 255, 255, 255, true)
        stopTTTRound()
    end
end

addEventHandler("onPlayerWasted", root, function()
    setTimer(checkTTTWin, 500, 1) -- Kis késleltetés a biztos halál-ellenőrzéshez
end)

addEventHandler("onPlayerJoin", root, function()
    if not isRoundRunning then setTimer(startTTTRound, 5000, 1) end
end)

addCommandHandler("setttt", function(sourceElement, cmd, sec)
    local canAccess = (not sourceElement or getElementType(sourceElement) == "console")
    if not canAccess then
        if (getElementData(sourceElement, "admin") or 0) >= 2 then canAccess = true end
    end

    if canAccess then
        local s = tonumber(sec)
        if s and s >= 120 and s <= 240 then
            roundDuration = s
            outputChatBox("#7cc576[TTT] Köridő beállítva: " .. s .. " mp.", sourceElement or root, 255, 255, 255, true)
        end
    end
end)



-- Hullák tárolása (hogy tudjuk, melyik Ped egy hulla)
local corpses = {}

-- Függvény hulla létrehozásához
function createCorpse(player, weapon, timeOffset)
    local x, y, z = getElementPosition(player)
    local rx, ry, rz = getElementRotation(player)
    local skin = getElementModel(player)
    
    -- Létrehozzuk a Ped-et (NPC)
    local corpse = createPed(skin, x, y, z, rz)
    setElementFrozen(corpse, true) -- Ne mozogjon
    setElementData(corpse, "isCorpse", true)
    
    -- Elmentjük az adatokat a Ped-be
    setElementData(corpse, "corpse:name", getPlayerName(player))
    setElementData(corpse, "corpse:role", getElementData(player, "tttRole") or "Innocent")
    setElementData(corpse, "corpse:weapon", weapon or "Ismeretlen")
    setElementData(corpse, "corpse:time", timeOffset or "Ismeretlen")
    
    -- Animáció: feküdjön a földön
    setPedAnimation(corpse, "WCC", "ped_dead_front", -1, false, false, false, true)
    
    return corpse
end

-- Teszt parancs: Letesz egy hullát eléd (Paddy adatokkal)
addCommandHandler("testcorpse", function(player)
    if (getElementData(player, "admin") or 0) >= 1 then
        local x, y, z = getElementPosition(player)
        local _, _, rz = getElementRotation(player)
        -- Kicsit elé tesszük
        local tx = x + math.sin(math.rad(-rz)) * 2
        local ty = y + math.cos(math.rad(-rz)) * 2
        
        local corpse = createPed(24, tx, ty, z, rz)
        setElementData(corpse, "isCorpse", true)
        setElementData(corpse, "corpse:name", "Paddy (TESZT)")
        setElementData(corpse, "corpse:role", "Traitor")
        setElementData(corpse, "corpse:weapon", "Desert Eagle")
        setElementData(corpse, "corpse:time", "02:45")
        setPedAnimation(corpse, "WCC", "ped_dead_front", -1, false, false, false, true)
        
        outputChatBox("#7cc576[TTT] #ffffffTeszt hulla létrehozva!", player, 255, 255, 255, true)
    end
end)

addCommandHandler("tc", function(player, cmd, ...)
    local role = getElementData(player, "tttRole")
    if role == "Traitor" then
        local msg = table.concat({...}, " ")
        if #msg > 0 then
            local players = getElementsByType("player")
            for _, p in ipairs(players) do
                if getElementData(p, "tttRole") == "Traitor" then
                    outputChatBox("#e74c3c[Traitor Chat] #ffffff" .. getPlayerName(player) .. ": " .. msg, p, 255, 255, 255, true)
                end
            end
        end
    end
end)

addEventHandler("onPlayerWasted", root, function(totalAmmo, attacker, weapon)
    if isRoundRunning then
        local p = source
        
        -- Kiszámoljuk a hátralévő időt (perc:másodperc)
        local timeStr = "00:00"
        if isTimer(roundTimer) then
            local ms = getTimerDetails(roundTimer)
            local mins = math.floor(ms / 60000)
            local secs = math.floor((ms % 60000) / 1000)
            timeStr = string.format("%02d:%02d", mins, secs)
        end

        -- Fegyver neve
        local weaponName = "Ismeretlen"
        if weapon then
            weaponName = getWeaponNameFromID(weapon)
        end

        -- MEGHÍVJUK A FÜGGVÉNYEDET
        -- Fontos: A te createCorpse függvényed 3 paramétert vár: player, weapon, timeOffset
        local corpse = createCorpse(p, weaponName, timeStr)
        
        if isElement(corpse) then
            outputDebugString("[TTT] Hulla létrehozva: " .. getPlayerName(p))
        end

        -- Eltüntetjük a "szellemet" (a láthatatlan hullát, amit az MTA alapból otthagy)
        -- Így csak a mi createPed-es hullánk fog látszódni.
        setTimer(function()
            if isElement(p) then
                spawnPlayer(p, 0, 0, -100, 0, getElementModel(p), 0, 0) -- Elteleportáljuk messzire
                setElementFrozen(p, true) -- Megállítjuk
            end
        end, 1000, 1)
    end
    
    -- Győzelem ellenőrzése marad
    setTimer(checkTTTWin, 500, 1)
end)