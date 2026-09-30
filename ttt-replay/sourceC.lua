-----------------------------------------
-- TTT REPLAY - KLIENS
--  1) Felvétel közben 5 Hz-en elküldi a saját kameránk mátrixát a szervernek
--  2) Visszajátszás kliensoldali pedekkel a saját replay-dimenziónkban:
--     interpolált pozíció + forgás, fegyver a kézben (givePedWeapon), célzás, séta/futás/sprint/guggolás anim,
--     a követett játékos EREDETI kamerája (vagy váll mögötti / szabad kamera)
-- Vezérlés: SPACE szünet | <- -> 5 mp | NUM+/- sebesség | F7 következő játékos | F8 kameramód | ESC/replaystop kilépés
-----------------------------------------
local screenW, screenH = guiGetScreenSize()

-- ---------- FELVÉTEL: kamera küldése ----------
local isRecording = false
local lastCamSend = 0
addEvent("ttt:replayRecording", true)
addEventHandler("ttt:replayRecording", root, function(state) isRecording = state end)

addEventHandler("onClientRender", root, function()
    if not isRecording then return end
    local now = getTickCount()
    if now - lastCamSend < 200 then return end
    lastCamSend = now
    -- Csak ha élünk és van szerepünk (halottak kamerája nem érdekes)
    if not getElementData(localPlayer, "tttRole") or isPedDead(localPlayer) then return end
    local cx, cy, cz, lx, ly, lz = getCameraMatrix()
    triggerServerEvent("ttt:replayCam", localPlayer, cx, cy, cz, lx, ly, lz)
end)

-- ---------- VISSZAJÁTSZÁS ----------
local replay = nil
local peds = {}             -- [név] = {ped, track, frameIdx, dead, weapon, anim, ...}
local playTime, lastTick = 0, 0
local speed, paused = 1.0, false
local followName = nil
local camMode = 1           -- 1 = a játékos eredeti kamerája, 2 = váll mögött, 3 = szabad (a saját pozíciód)
local camModeNames = { "JÁTÉKOS KAMERA", "VÁLL MÖGÜL", "SZABAD" }
local lastStreamMove = 0
local roleColors = { Traitor = {231, 76, 60}, Detective = {52, 152, 219}, Innocent = {46, 204, 113} }

local weaponNames = {
    [0] = "Ököl", [16] = "Gránát", [22] = "Colt 45", [23] = "Silenced", [24] = "Deagle", [25] = "Shotgun",
    [27] = "Combat Shotgun", [28] = "Uzi", [29] = "MP5", [30] = "AK-47", [31] = "M4", [32] = "Tec-9",
    [33] = "Rifle", [34] = "Sniper", [39] = "C4",
}

-- Frame mezők indexei
local F_T, F_X, F_Y, F_Z, F_RZ, F_WEP, F_ALIVE, F_DUCK, F_MOVE, F_AIM, F_CX, F_CY, F_CZ, F_LX, F_LY, F_LZ = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16

-- Animációk: [move][ducked]
local ANIMS = {
    [0] = { [0] = nil,                          [1] = {"ped", "GUNCROUCH"} },
    [1] = { [0] = {"ped", "WALK_player"},       [1] = {"ped", "GunCrouchFwd"} },
    [2] = { [0] = {"ped", "run_player"},        [1] = {"ped", "GunCrouchFwd"} },
    [3] = { [0] = {"ped", "sprint_civi"},       [1] = {"ped", "GunCrouchFwd"} },
}

local function stopReplay()
    if not replay then return end
    removeEventHandler("onClientRender", root, renderReplay)
    for _, d in pairs(peds) do
        if isElement(d.ped) then destroyElement(d.ped) end
    end
    peds, replay, followName = {}, nil, nil
    setCameraTarget(localPlayer)
    triggerServerEvent("ttt:replayEnded", localPlayer)  -- a szerver visszarak az eredeti dimenzióba
    outputChatBox("#00c3ff[Replay] #ffffffVisszajátszás leállítva.", 255, 255, 255, true)
end

local function lerp(a, b, f) return a + (b - a) * f end
local function lerpAngle(a, b, f) return a + ((b - a + 540) % 360 - 180) * f end

-- Interpolált állapot adott időpontra: visszaad egy 16 elemű táblát (a frame formátumában)
local function sampleTrack(d, t)
    local frames = d.track.frames
    local i = d.frameIdx
    if frames[i] and frames[i][F_T] > t then i = 1 end
    while frames[i + 1] and frames[i + 1][F_T] <= t do i = i + 1 end
    d.frameIdx = i
    local a, b = frames[i], frames[i + 1]
    if not a then return nil end
    if not b or b[F_T] == a[F_T] then return a end
    local f = (t - a[F_T]) / (b[F_T] - a[F_T])
    local s = d.sample
    for k = 1, 16 do s[k] = a[k] end
    s[F_X], s[F_Y], s[F_Z] = lerp(a[F_X], b[F_X], f), lerp(a[F_Y], b[F_Y], f), lerp(a[F_Z], b[F_Z], f)
    s[F_RZ] = lerpAngle(a[F_RZ], b[F_RZ], f)
    for k = F_CX, F_LZ do s[k] = lerp(a[k], b[k], f) end
    return s
end

local function applyPedState(d, s)
    local ped = d.ped
    setElementPosition(ped, s[F_X], s[F_Y], s[F_Z])
    setElementRotation(ped, 0, 0, s[F_RZ], "default", true)

    if s[F_ALIVE] ~= 1 then
        if not d.dead then
            d.dead, d.anim = true, "dead"
            setPedAnimation(ped, "WCC", "ped_dead_front", -1, false, false, false, true)
            setElementAlpha(ped, 160)
        end
        return
    end
    if d.dead then
        d.dead, d.anim = false, nil
        setPedAnimation(ped)
        setElementAlpha(ped, 255)
    end

    -- Fegyver a kézben
    local wep = s[F_WEP] or 0
    if wep ~= d.weapon then
        d.weapon = wep
        if wep > 0 then givePedWeapon(ped, wep, 9999, true) else setPedWeaponSlot(ped, 0) end
    end

    -- Célzás: a játékos kamerájának irányába
    local aiming = (s[F_AIM] == 1 and wep > 0)
    if aiming then
        local dx, dy, dz = s[F_LX] - s[F_CX], s[F_LY] - s[F_CY], s[F_LZ] - s[F_CZ]
        local len = math.sqrt(dx * dx + dy * dy + dz * dz)
        if len > 0 then
            setPedAimTarget(ped, s[F_X] + dx / len * 30, s[F_Y] + dy / len * 30, s[F_Z] + 0.6 + dz / len * 30)
        end
    end
    if aiming ~= d.aiming then
        d.aiming = aiming
        setPedControlState(ped, "aim_weapon", aiming)
    end

    -- Mozgás animáció (csak változásnál)
    local animKey = (aiming and "aim_" or "") .. s[F_MOVE] .. "_" .. s[F_DUCK]
    if animKey ~= d.anim then
        d.anim = animKey
        local a = ANIMS[s[F_MOVE]] and ANIMS[s[F_MOVE]][s[F_DUCK]]
        if aiming and s[F_MOVE] == 0 then
            setPedAnimation(ped)            -- célzó pózt a setPedAimTarget adja
        elseif a then
            setPedAnimation(ped, a[1], a[2], -1, true, true, false, false)
        else
            setPedAnimation(ped)
        end
    end
end

local function drawLabel(name, d, s)
    local sx, sy = getScreenFromWorldPosition(s[F_X], s[F_Y], s[F_Z] + 1.1)
    if not sx then return end
    local c = roleColors[d.track.role] or {255, 255, 255}
    local label = name .. "  [" .. tostring(d.track.role) .. "]  " .. (weaponNames[s[F_WEP]] or ("#" .. tostring(s[F_WEP])))
    dxDrawText(label, sx + 1, sy + 1, sx + 1, sy + 1, tocolor(0, 0, 0, 200), 1.1, "default-bold", "center", "center")
    dxDrawText(label, sx, sy, sx, sy, tocolor(c[1], c[2], c[3], s[F_ALIVE] == 1 and 255 or 140), 1.1, "default-bold", "center", "center")
end

function renderReplay()
    if not replay then return end
    local now = getTickCount()
    if not paused then playTime = playTime + (now - lastTick) * speed end
    lastTick = now
    if playTime > replay.length then playTime = replay.length; paused = true end
    if playTime < 0 then playTime = 0 end

    local followSample = nil
    for name, d in pairs(peds) do
        local s = sampleTrack(d, playTime)
        if s and isElement(d.ped) then
            applyPedState(d, s)
            drawLabel(name, d, s)
            if followName == name then followSample = s end
        end
    end

    -- Kamera
    if followSample then
        local s = followSample
        if camMode == 1 then
            setCameraMatrix(s[F_CX], s[F_CY], s[F_CZ], s[F_LX], s[F_LY], s[F_LZ])
        elseif camMode == 2 then
            local rz = math.rad(s[F_RZ])
            setCameraMatrix(s[F_X] + math.sin(rz) * 4, s[F_Y] - math.cos(rz) * 4, s[F_Z] + 2.0, s[F_X], s[F_Y], s[F_Z] + 0.8)
        end
        -- A saját (láthatatlan) játékosunkat a követett ped közelében tartjuk, hogy a világ streamelődjön
        if camMode ~= 3 and now - lastStreamMove > 1000 then
            lastStreamMove = now
            setElementPosition(localPlayer, s[F_X], s[F_Y], s[F_Z] + 0.5)
        end
    end

    -- Felső sáv
    local timeStr = string.format("%02d:%02d / %02d:%02d", math.floor(playTime / 60000), math.floor(playTime / 1000) % 60,
        math.floor(replay.length / 60000), math.floor(replay.length / 1000) % 60)
    dxDrawRectangle(screenW / 2 - 300, 60, 600, 34, tocolor(0, 15, 25, 200))
    dxDrawText("REPLAY  " .. timeStr .. "  x" .. speed .. (paused and "  [SZÜNET]" or "") .. "   Győztes: " .. tostring(replay.winner) ..
        "   Kamera: " .. camModeNames[camMode] .. (followName and (" (" .. followName .. ")") or ""),
        screenW / 2 - 300, 60, screenW / 2 + 300, 94, tocolor(0, 195, 255, 255), 1.0, "default-bold", "center", "center")
    dxDrawText("SPACE szünet | <- -> 5 mp | NUM+/- sebesség | F7 játékos | F8 kameramód | ESC kilépés   " .. tostring(replay.fileName or ""),
        screenW / 2 - 300, 94, screenW / 2 + 300, 110, tocolor(255, 255, 255, 120), 0.8, "default", "center", "top")
    dxDrawRectangle(screenW / 2 - 300, 112, 600, 4, tocolor(255, 255, 255, 30))
    dxDrawRectangle(screenW / 2 - 300, 112, 600 * (playTime / math.max(1, replay.length)), 4, tocolor(0, 195, 255, 255))

    -- Már megtörtént események (utolsó 5)
    local shown, y = 0, 125
    for i = #replay.events, 1, -1 do
        local ev = replay.events[i]
        if ev[1] <= playTime then
            local alpha = (playTime - ev[1]) < 1000 and 255 or 180
            dxDrawText(string.format("[%02d:%02d] %s", math.floor(ev[1] / 60000), math.floor(ev[1] / 1000) % 60, ev[2]),
                screenW / 2 - 295, y, screenW / 2 + 295, y + 18, tocolor(255, 200, 80, alpha), 0.9, "default-bold", "left", "top")
            y = y + 18
            shown = shown + 1
            if shown >= 5 then break end
        end
    end
end

local function sortedNames()
    local names = {}
    for name in pairs(peds) do table.insert(names, name) end
    table.sort(names)
    return names
end

addEvent("ttt:replayData", true)
addEventHandler("ttt:replayData", root, function(rec)
    if replay then
        -- csendes újraindítás (a szerver már átrakott a dimenzióba)
        removeEventHandler("onClientRender", root, renderReplay)
        for _, d in pairs(peds) do if isElement(d.ped) then destroyElement(d.ped) end end
        peds = {}
    end
    if not rec or not rec.players then return end
    replay = rec
    playTime, speed, paused, camMode = 0, 1.0, false, 1
    lastTick = getTickCount()
    local dim = rec.dimension or getElementDimension(localPlayer)

    for name, track in pairs(rec.players) do
        local f = track.frames and track.frames[1]
        if f then
            local ped = createPed(track.skin or 0, f[F_X], f[F_Y], f[F_Z], f[F_RZ])
            if ped then
                setElementDimension(ped, dim)
                setElementCollisionsEnabled(ped, false)
                setElementData(ped, "isReplayPed", true, false)
                peds[name] = { ped = ped, track = track, frameIdx = 1, dead = false, weapon = 0, aiming = false, anim = nil, sample = {} }
            end
        end
    end
    followName = sortedNames()[1]
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
        local names = sortedNames()
        local nextIdx = 1
        for i, n in ipairs(names) do if n == followName then nextIdx = i + 1 end end
        followName = names[nextIdx] or names[1]
        outputChatBox("#00c3ff[Replay] #ffffffKövetett játékos: " .. tostring(followName), 255, 255, 255, true)
    elseif button == "F8" then
        camMode = camMode % 3 + 1
        if camMode == 3 then setCameraTarget(localPlayer) end
        outputChatBox("#00c3ff[Replay] #ffffffKameramód: " .. camModeNames[camMode], 255, 255, 255, true)
    elseif button == "escape" then
        cancelEvent()
        stopReplay()
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if replay then stopReplay() end
end)
