-----------------------------------------
-- TTT REPLAY - KLIENS: visszajátszás kliensoldali pedekkel (csak a néző admin látja)
-- Vezérlés: SPACE = szünet, ARROW_LEFT/RIGHT = -/+5 mp, NUM+/NUM- = sebesség, F7 = kamera követés váltás
-----------------------------------------
local screenW, screenH = guiGetScreenSize()
local replay = nil          -- a szervertől kapott felvétel
local peds = {}             -- [név] = {ped, track, frameIdx, dead}
local playTime = 0          -- visszajátszás ideje ms-ban
local lastTick = 0
local speed = 1.0
local paused = false
local followName = nil      -- kamera követés
local roleColors = { Traitor = {231, 76, 60}, Detective = {52, 152, 219}, Innocent = {46, 204, 113} }

local weaponNames = {
    [0] = "Ököl", [16] = "Gránát", [22] = "Colt 45", [23] = "Silenced", [24] = "Deagle", [25] = "Shotgun",
    [27] = "Combat Shotgun", [28] = "Uzi", [29] = "MP5", [30] = "AK-47", [31] = "M4", [32] = "Tec-9",
    [33] = "Rifle", [34] = "Sniper", [39] = "C4",
}

local function stopReplay()
    if not replay then return end
    removeEventHandler("onClientRender", root, renderReplay)
    for _, d in pairs(peds) do
        if isElement(d.ped) then destroyElement(d.ped) end
    end
    peds, replay, followName = {}, nil, nil
    setCameraTarget(localPlayer)
    outputChatBox("#00c3ff[Replay] #ffffffVisszajátszás leállítva.", 255, 255, 255, true)
end

-- Két képkocka közti interpolált állapot adott időpontra
local function sampleTrack(d, t)
    local frames = d.track.frames
    -- frameIdx-től előre lépünk (a lejátszás monoton; visszaugrásnál újraindítjuk az indexet)
    local i = d.frameIdx
    if frames[i] and frames[i][1] > t then i = 1 end
    while frames[i + 1] and frames[i + 1][1] <= t do i = i + 1 end
    d.frameIdx = i
    local a, b = frames[i], frames[i + 1]
    if not a then return nil end
    if not b or b[1] == a[1] then return a[2], a[3], a[4], a[5], a[6], a[7], a[8] end
    local f = (t - a[1]) / (b[1] - a[1])
    local rz = a[5] + ((b[5] - a[5] + 540) % 360 - 180) * f  -- legrövidebb irány
    return a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f, a[4] + (b[4] - a[4]) * f, rz, a[6], a[7], a[8]
end

function renderReplay()
    if not replay then return end
    local now = getTickCount()
    if not paused then playTime = playTime + (now - lastTick) * speed end
    lastTick = now
    if playTime > replay.length then playTime = replay.length; paused = true end
    if playTime < 0 then playTime = 0 end

    -- Pedek frissítése
    for name, d in pairs(peds) do
        local x, y, z, rz, weapon, alive, ducked = sampleTrack(d, playTime)
        if x and isElement(d.ped) then
            setElementPosition(d.ped, x, y, z)
            setPedRotation(d.ped, rz)
            if alive == 1 then
                if d.dead then
                    d.dead = false
                    setPedAnimation(d.ped)
                    setElementAlpha(d.ped, 255)
                end
                -- Mozgás animáció: ha elmozdult az előző mintához képest
                local moving = d.lx and (math.abs(x - d.lx) + math.abs(y - d.ly)) > 0.03
                local anim = moving and (ducked == 1 and "crouch" or "run") or "idle"
                if anim ~= d.anim then
                    d.anim = anim
                    if anim == "run" then setPedAnimation(d.ped, "ped", "run_player", -1, true, true, false, false)
                    elseif anim == "crouch" then setPedAnimation(d.ped, "ped", "GunCrouchFwd", -1, true, true, false, false)
                    else setPedAnimation(d.ped) end
                end
                d.lx, d.ly = x, y
            elseif not d.dead then
                d.dead = true
                d.anim = nil
                setPedAnimation(d.ped, "WCC", "ped_dead_front", -1, false, false, false, true)
                setElementAlpha(d.ped, 160)
            end
            -- Nametag a ped fölött
            local sx, sy = getScreenFromWorldPosition(x, y, z + 1.1)
            if sx then
                local c = roleColors[d.track.role] or {255, 255, 255}
                local label = name .. "  [" .. tostring(d.track.role) .. "]  " .. (weaponNames[weapon] or ("#" .. tostring(weapon)))
                dxDrawText(label, sx + 1, sy + 1, sx + 1, sy + 1, tocolor(0, 0, 0, 200), 1.1, "default-bold", "center", "center")
                dxDrawText(label, sx, sy, sx, sy, tocolor(c[1], c[2], c[3], alive == 1 and 255 or 140), 1.1, "default-bold", "center", "center")
            end
            if followName == name then
                setCameraMatrix(x + math.sin(math.rad(rz)) * 4, y - math.cos(math.rad(rz)) * 4, z + 2.5, x, y, z + 0.8)
            end
        end
    end

    -- Felső sáv: idő, sebesség, események
    local timeStr = string.format("%02d:%02d / %02d:%02d", math.floor(playTime / 60000), math.floor(playTime / 1000) % 60,
        math.floor(replay.length / 60000), math.floor(replay.length / 1000) % 60)
    dxDrawRectangle(screenW / 2 - 260, 60, 520, 34, tocolor(0, 15, 25, 200))
    dxDrawText("REPLAY  " .. timeStr .. "  x" .. speed .. (paused and "  [SZÜNET]" or "") .. "   Győztes: " .. tostring(replay.winner),
        screenW / 2 - 260, 60, screenW / 2 + 260, 94, tocolor(0, 195, 255, 255), 1.0, "default-bold", "center", "center")
    dxDrawText("SPACE szünet | <- -> 5 mp | NUM+/- sebesség | F7 követés | /replaystop", screenW / 2 - 260, 94, screenW / 2 + 260, 110,
        tocolor(255, 255, 255, 120), 0.8, "default", "center", "top")

    -- Progress bar
    dxDrawRectangle(screenW / 2 - 260, 112, 520, 4, tocolor(255, 255, 255, 30))
    dxDrawRectangle(screenW / 2 - 260, 112, 520 * (playTime / math.max(1, replay.length)), 4, tocolor(0, 195, 255, 255))

    -- Már megtörtént események (utolsó 5)
    local shown, y = 0, 125
    for i = #replay.events, 1, -1 do
        local ev = replay.events[i]
        if ev[1] <= playTime then
            local age = playTime - ev[1]
            local alpha = age < 1000 and 255 or 180
            dxDrawText(string.format("[%02d:%02d] %s", math.floor(ev[1] / 60000), math.floor(ev[1] / 1000) % 60, ev[2]),
                screenW / 2 - 255, y, screenW / 2 + 255, y + 18, tocolor(255, 200, 80, alpha), 0.9, "default-bold", "left", "top")
            y = y + 18
            shown = shown + 1
            if shown >= 5 then break end
        end
    end
end

addEvent("ttt:replayData", true)
addEventHandler("ttt:replayData", root, function(rec)
    if replay then stopReplay() end
    if not rec or not rec.players then return end
    replay = rec
    playTime, speed, paused = 0, 1.0, false
    lastTick = getTickCount()

    for name, track in pairs(rec.players) do
        local f = track.frames[1]
        if f then
            local ped = createPed(track.skin or 0, f[2], f[3], f[4], f[5])
            if ped then
                setElementFrozen(ped, true)
                setElementCollisionsEnabled(ped, false)
                setElementData(ped, "isReplayPed", true, false)
                setElementData(ped, "npcName", "[R] " .. name, false)
                peds[name] = { ped = ped, track = track, frameIdx = 1, dead = false }
            end
        end
    end
    -- Az első felvett játékosra ugrik a kamera
    for name in pairs(peds) do followName = name break end
    addEventHandler("onClientRender", root, renderReplay)
end)

addEvent("ttt:replayStop", true)
addEventHandler("ttt:replayStop", root, stopReplay)

addEventHandler("onClientKey", root, function(button, press)
    if not replay or not press then return end
    if button == "space" then
        paused = not paused
        cancelEvent()
    elseif button == "arrow_left" then
        playTime = math.max(0, playTime - 5000)
        for _, d in pairs(peds) do d.frameIdx = 1 end
        cancelEvent()
    elseif button == "arrow_right" then
        playTime = math.min(replay.length, playTime + 5000)
        cancelEvent()
    elseif button == "num_add" then
        speed = math.min(8, speed * 2)
    elseif button == "num_sub" then
        speed = math.max(0.25, speed / 2)
    elseif button == "F7" then
        -- Következő játékos követése, a végén szabad kamera
        local names = {}
        for name in pairs(peds) do table.insert(names, name) end
        table.sort(names)
        local nextIdx = nil
        for i, n in ipairs(names) do if n == followName then nextIdx = i + 1 end end
        if not followName then nextIdx = 1 end
        followName = names[nextIdx]
        if not followName then setCameraTarget(localPlayer) end
        outputChatBox("#00c3ff[Replay] #ffffffKamera: " .. (followName or "szabad"), 255, 255, 255, true)
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, stopReplay)
