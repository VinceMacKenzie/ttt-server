-----------------------------------------
-- TTT REPLAY - KLIENS
--  1) Felvétel közben 5 Hz-en elküldi a saját kameránk mátrixát a szervernek
--  2) Visszajátszás kliensoldali pedekkel a saját replay-dimenziónkban:
--     interpolált pozíció + forgás, fegyver a kézben (givePedWeapon), célzás, séta/futás/sprint/guggolás anim,
--     a követett játékos EREDETI kamerája (vagy váll mögötti / szabad kamera)
-- Vezérlés: SPACE szünet | <- -> 5 mp | NUM+/- sebesség | F7 következő játékos | F6 kameramód | kattintható idővonal | ESC/replaystop kilépés
-----------------------------------------
local screenW, screenH = guiGetScreenSize()

-- ---------- FELVÉTEL: kamera küldése ----------
local isRecording = false
local lastCamSend = 0
local firedSinceLastSend = false
addEvent("ttt:replayRecording", true)
addEventHandler("ttt:replayRecording", root, function(state) isRecording = state end)

addEventHandler("onClientRender", root, function()
    if not isRecording then return end
    local now = getTickCount()
    if now - lastCamSend < 100 then return end
    lastCamSend = now
    -- Csak ha élünk és van szerepünk (halottak kamerája nem érdekes)
    if not getElementData(localPlayer, "tttRole") or isPedDead(localPlayer) then return end
    local cx, cy, cz, lx, ly, lz = getCameraMatrix()
    -- Mozgásállapot: 0 áll, 1 sétál, 2 fut, 3 sprintel (a control state csak kliensen kérdezhető le)
    local vx, vy, vz = getElementVelocity(localPlayer)
    local move = 0
    if (vx * vx + vy * vy + vz * vz) >= 0.0004 then
        if getControlState("sprint") then move = 3
        elseif getControlState("walk") then move = 1
        else move = 2 end
    end
    local aim = getControlState("aim_weapon") and 1 or 0
    local fire = firedSinceLastSend and 1 or 0
    firedSinceLastSend = false
    -- Célzott pont: ahova a játékos ténylegesen céloz (a kamera sugara mentén az első találat, max 300 m)
    local tx, ty, tz = 0, 0, 0
    if aim == 1 then
        local dx, dy, dz = lx - cx, ly - cy, lz - cz
        local len = math.sqrt(dx * dx + dy * dy + dz * dz)
        if len > 0 then
            local ex, ey, ez = cx + dx / len * 300, cy + dy / len * 300, cz + dz / len * 300
            local hit, hx, hy, hz = processLineOfSight(cx, cy, cz, ex, ey, ez, true, true, true, true, true, false, false, false, localPlayer)
            if hit then tx, ty, tz = hx, hy, hz else tx, ty, tz = ex, ey, ez end
        end
    end
    -- Ugrás / mászás a ped taskjaiból
    local jump = 0
    for slot = 0, 4 do
        local task = getPedTask(localPlayer, "primary", slot)
        if task then
            if task:find("CLIMB") then jump = 2 break end
            if task:find("JUMP") then jump = 1 end
        end
    end
    triggerServerEvent("ttt:replayCam", localPlayer, cx, cy, cz, lx, ly, lz, move, aim, fire, tx, ty, tz, jump)
end)

addEventHandler("onClientPlayerWeaponFire", localPlayer, function()
    firedSinceLastSend = true
end)

-- ---------- VISSZAJÁTSZÁS ----------
local replay = nil
local peds = {}             -- [név] = {ped, track, frameIdx, dead, weapon, anim, ...}
local playTime, lastTick = 0, 0
local speed, paused = 1.0, false
local followName = nil
local timelineDrag = false  -- idővonal csúszka húzása
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
local F_T, F_X, F_Y, F_Z, F_RZ, F_WEP, F_ALIVE, F_DUCK, F_MOVE, F_AIM, F_CX, F_CY, F_CZ, F_LX, F_LY, F_LZ, F_FIRE, F_TX, F_TY, F_TZ, F_JUMP = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21

local function stopReplay()
    if not replay then return end
    removeEventHandler("onClientRender", root, renderReplay)
    for _, d in pairs(peds) do
        if isElement(d.ped) then destroyElement(d.ped) end
    end
    peds, replay, followName, timelineDrag = {}, nil, nil, false
    showCursor(false)
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
    for k = 1, 21 do s[k] = a[k] end
    s[F_X], s[F_Y], s[F_Z] = lerp(a[F_X], b[F_X], f), lerp(a[F_Y], b[F_Y], f), lerp(a[F_Z], b[F_Z], f)
    s[F_RZ] = lerpAngle(a[F_RZ], b[F_RZ], f)
    for k = F_CX, F_LZ do s[k] = lerp(a[k], b[k], f) end
    if a[F_TX] and b[F_TX] and a[F_TX] ~= 0 and b[F_TX] ~= 0 then
        for k = F_TX, F_TZ do s[k] = lerp(a[k], b[k], f) end
    end
    return s
end

local MOVE_CONTROLS = { "forwards", "backwards", "left", "right", "sprint", "walk", "fire", "aim_weapon", "jump" }

local function clearControls(ped)
    for _, c in ipairs(MOVE_CONTROLS) do setPedControlState(ped, c, false) end
end

local function getRotationTo(x1, y1, x2, y2)
    local rot = -math.deg(math.atan2(x2 - x1, y2 - y1))
    if rot < 0 then rot = rot + 360 end
    return rot
end

-- HIBRID lejátszás: a pozíciót minden képkockán MI állítjuk (interpolált, pontos, warp nélkül),
-- a control state-ek (forwards/sprint/walk/crouch/aim_weapon/fire) pedig csak az animációt adják -
-- így a GTA saját séta/futás/célzás/lövés animációi mennek, de a ped nem csúszik el és nem marad le.
local ROT_SMOOTH = 0.35   -- forgás simítás (0..1, nagyobb = gyorsabb)

local function applyPedState(d, s, dt)
    local ped = d.ped

    -- Halott
    if s[F_ALIVE] ~= 1 then
        if not d.dead then
            d.dead = true
            clearControls(ped)
            setPedControlState(ped, "crouch", false)
            setElementPosition(ped, s[F_X], s[F_Y], s[F_Z], false)
            setPedAnimation(ped, "WCC", "ped_dead_front", -1, false, false, false, true)
            setElementAlpha(ped, 160)
        end
        return
    end
    if d.dead then
        d.dead = false
        setPedAnimation(ped)
        setElementAlpha(ped, 255)
    end

    -- Fegyver a kézben
    local wep = s[F_WEP] or 0
    if wep ~= d.weapon then
        d.weapon = wep
        if wep > 0 then givePedWeapon(ped, wep, 9999, true) else setPedWeaponSlot(ped, 0) end
    end

    -- Mozgásirány a minta elmozdulásából (előző képkocka -> mostani)
    local mx, my = s[F_X] - (d.lx or s[F_X]), s[F_Y] - (d.ly or s[F_Y])
    d.lx, d.ly = s[F_X], s[F_Y]
    local moveLen = math.sqrt(mx * mx + my * my)
    local moving = (s[F_MOVE] or 0) > 0 and moveLen > 0.002 * (dt / 16)

    -- Célzás a kamera irányába + piros vonal
    local aiming = (s[F_AIM] == 1 and wep > 0)
    local facing = s[F_RZ]
    d.aimPoint = nil
    if aiming then
        local tx, ty, tz = s[F_TX], s[F_TY], s[F_TZ]
        if not tx or (tx == 0 and ty == 0 and tz == 0) then
            -- régi felvétel: a kamera irányába 40 m
            local ax, ay, az = s[F_LX] - s[F_CX], s[F_LY] - s[F_CY], s[F_LZ] - s[F_CZ]
            local len = math.sqrt(ax * ax + ay * ay + az * az)
            if len > 0 then tx, ty, tz = s[F_X] + ax / len * 40, s[F_Y] + ay / len * 40, s[F_Z] + 0.6 + az / len * 40 end
        end
        if tx then
            setPedAimTarget(ped, tx, ty, tz)
            facing = getRotationTo(s[F_X], s[F_Y], tx, ty)
            d.aimPoint = { tx, ty, tz }
        end
    elseif moving then
        facing = getRotationTo(0, 0, mx, my)
    end

    -- Simított forgás
    d.rot = d.rot and lerpAngle(d.rot, facing, ROT_SMOOTH) or facing
    setPedRotation(ped, d.rot)

    -- Pozíció: mozgás közben a ped saját járása viszi, csak akkor igazítunk, ha eltér (nem rángatjuk minden képkockán)
    -- Ugrás / mászás: a "jump" egy impulzus; a GTA maga mászik, ha akadály van előtte.
    -- Amíg tart, nem igazítjuk a pozíciót (különben megszakadna az animáció).
    local jumpState = s[F_JUMP] or 0
    if jumpState > 0 and (d.lastJump or 0) ~= jumpState then
        d.lastJump = jumpState
        d.jumpUntil = getTickCount() + (jumpState == 2 and 1500 or 900)
        setPedControlState(ped, "jump", true)
        setTimer(function(pd) if isElement(pd) then setPedControlState(pd, "jump", false) end end, 60, 1, ped)
    elseif jumpState == 0 then
        d.lastJump = 0
    end
    local inJump = d.jumpUntil and getTickCount() < d.jumpUntil

    local px, py, pz = getElementPosition(ped)
    local ex, ey, ez = s[F_X] - px, s[F_Y] - py, s[F_Z] - pz
    local err = math.sqrt(ex * ex + ey * ey)
    local tol = inJump and 2.5 or (moving and 0.25 or 0.08)
    local ztol = inJump and 3.0 or 0.6
    if err > tol or math.abs(ez) > ztol then
        setElementPosition(ped, s[F_X], s[F_Y], s[F_Z], false)
    end

    -- Control state-ek (csak animációhoz)
    setPedControlState(ped, "aim_weapon", aiming)
    setPedControlState(ped, "fire", aiming and s[F_FIRE] == 1)
    if moving then
        if aiming then
            local rel = (getRotationTo(0, 0, mx, my) - d.rot + 540) % 360 - 180
            setPedControlState(ped, "forwards",  math.abs(rel) < 67.5)
            setPedControlState(ped, "backwards", math.abs(rel) > 112.5)
            setPedControlState(ped, "left",  rel > 22.5 and rel < 157.5)
            setPedControlState(ped, "right", rel < -22.5 and rel > -157.5)
        else
            setPedControlState(ped, "forwards", true)
            setPedControlState(ped, "backwards", false)
            setPedControlState(ped, "left", false)
            setPedControlState(ped, "right", false)
        end
        setPedControlState(ped, "sprint", s[F_MOVE] == 3)
        setPedControlState(ped, "walk",   s[F_MOVE] == 1)
    else
        setPedControlState(ped, "forwards", false)
        setPedControlState(ped, "backwards", false)
        setPedControlState(ped, "left", false)
        setPedControlState(ped, "right", false)
        setPedControlState(ped, "sprint", false)
        setPedControlState(ped, "walk", false)
    end

    -- Guggolás: a "crouch"-ot NEM szabad nyomva tartani (a ped feláll tőle, MTA #488),
    -- egy rövid "lenyom + 50 ms múlva elenged" impulzus kell, és csak akkor, ha az állapot eltér.
    local wantDuck = (s[F_DUCK] == 1)
    local now = getTickCount()
    if wantDuck ~= isPedDucked(ped) and (now - (d.lastDuckPress or 0)) > 350 then
        d.lastDuckPress = now
        setPedControlState(ped, "crouch", true)
        setTimer(function(pd)
            if isElement(pd) then setPedControlState(pd, "crouch", false) end
        end, 50, 1, ped)
    end
end

-- Piros célzóvonal a ped fejétől a ténylegesen célzott pontig
local function drawAimLine(d, s)
    if not d.aimPoint then return end
    local a = d.aimPoint
    dxDrawLine3D(s[F_X], s[F_Y], s[F_Z] + 0.6, a[1], a[2], a[3], tocolor(255, 40, 40, 200), 2.5)
    -- kis jelölő a célponton
    local sx, sy = getScreenFromWorldPosition(a[1], a[2], a[3])
    if sx then dxDrawRectangle(sx - 3, sy - 3, 6, 6, tocolor(255, 40, 40, 230)) end
end

local function drawLabel(name, d, s)
    local sx, sy = getScreenFromWorldPosition(s[F_X], s[F_Y], s[F_Z] + 1.1)
    if not sx then return end
    local c = roleColors[d.track.role] or {255, 255, 255}
    local label = name .. "  [" .. tostring(d.track.role) .. "]  " .. (weaponNames[s[F_WEP]] or ("#" .. tostring(s[F_WEP])))
    dxDrawText(label, sx + 1, sy + 1, sx + 1, sy + 1, tocolor(0, 0, 0, 200), 1.1, "default-bold", "center", "center")
    dxDrawText(label, sx, sy, sx, sy, tocolor(c[1], c[2], c[3], s[F_ALIVE] == 1 and 255 or 140), 1.1, "default-bold", "center", "center")
end

-- Idővonal (csúszka) geometriája
local TL_W = 600
local TL_X = screenW / 2 - TL_W / 2
local TL_Y, TL_H = 114, 10
local function isMouseOverTimeline()
    if not isCursorShowing() then return false end
    local cx, cy = getCursorPosition()
    if not cx then return false end
    cx, cy = cx * screenW, cy * screenH
    return cx >= TL_X - 6 and cx <= TL_X + TL_W + 6 and cy >= TL_Y - 10 and cy <= TL_Y + TL_H + 10
end

-- Ugrás adott időpontra: a pedek pozícióját azonnal beállítjuk
function seekTo(t)
    playTime = math.max(0, math.min(replay.length, t))
    for _, d in pairs(peds) do
        d.frameIdx = 1
        d.lx, d.ly = nil, nil
        local s = sampleTrack(d, playTime)
        if s and isElement(d.ped) then setElementPosition(d.ped, s[F_X], s[F_Y], s[F_Z], false) end
    end
end

function renderReplay()
    if not replay then return end
    local now = getTickCount()
    local dt = now - lastTick
    lastTick = now

    -- Csúszka húzása
    if timelineDrag then
        local cx = getCursorPosition()
        if cx then
            local frac = math.max(0, math.min(1, (cx * screenW - TL_X) / TL_W))
            seekTo(frac * replay.length)
        end
    elseif not paused then
        playTime = playTime + dt * speed
    end
    if playTime > replay.length then playTime = replay.length; paused = true end
    if playTime < 0 then playTime = 0 end

    local followSample = nil
    for name, d in pairs(peds) do
        local s = sampleTrack(d, playTime)
        if s and isElement(d.ped) then
            applyPedState(d, s, dt)
            drawAimLine(d, s)
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
        if camMode ~= 3 and now - lastStreamMove > 500 then
            lastStreamMove = now
            setElementPosition(localPlayer, s[F_X], s[F_Y], s[F_Z] + 0.5)
        end
    end

    -- Felső sáv
    local timeStr = string.format("%02d:%02d / %02d:%02d", math.floor(playTime / 60000), math.floor(playTime / 1000) % 60,
        math.floor(replay.length / 60000), math.floor(replay.length / 1000) % 60)
    dxDrawRectangle(TL_X, 60, TL_W, 34, tocolor(0, 15, 25, 200))
    dxDrawText("REPLAY  " .. timeStr .. "  x" .. speed .. (paused and "  [SZÜNET]" or "") .. "   Győztes: " .. tostring(replay.winner) ..
        "   Kamera: " .. camModeNames[camMode] .. (followName and (" (" .. followName .. ")") or ""),
        TL_X, 60, TL_X + TL_W, 94, tocolor(0, 195, 255, 255), 1.0, "default-bold", "center", "center")
    dxDrawText("SPACE szünet | <- -> 5 mp | NUM+/- sebesség | F7 játékos | F6 kameramód | ESC kilépés | M kurzor   " .. tostring(replay.fileName or ""),
        TL_X, 94, TL_X + TL_W, 110, tocolor(255, 255, 255, 120), 0.8, "default", "center", "top")

    -- Kattintható / húzható idővonal
    local frac = playTime / math.max(1, replay.length)
    local hover = timelineDrag or isMouseOverTimeline()
    dxDrawRectangle(TL_X, TL_Y, TL_W, TL_H, tocolor(255, 255, 255, hover and 50 or 30))
    dxDrawRectangle(TL_X, TL_Y, TL_W * frac, TL_H, tocolor(0, 195, 255, 255))
    -- események jelölése az idővonalon
    for _, ev in ipairs(replay.events) do
        local ex = TL_X + TL_W * (ev[1] / math.max(1, replay.length))
        dxDrawRectangle(ex - 1, TL_Y - 2, 2, TL_H + 4, tocolor(255, 200, 80, 220))
    end
    -- fogantyú
    local hx = TL_X + TL_W * frac
    dxDrawRectangle(hx - 5, TL_Y - 4, 10, TL_H + 8, tocolor(255, 255, 255, 255))
    if hover then
        local cx = getCursorPosition()
        if cx then
            local t = math.max(0, math.min(1, (cx * screenW - TL_X) / TL_W)) * replay.length
            dxDrawText(string.format("%02d:%02d", math.floor(t / 60000), math.floor(t / 1000) % 60), cx * screenW - 30, TL_Y + TL_H + 4, cx * screenW + 30, TL_Y + TL_H + 20, tocolor(255, 255, 255, 230), 0.9, "default-bold", "center", "top")
        end
    end

    -- Már megtörtént események (utolsó 5)
    local shown, y = 0, TL_Y + TL_H + 24
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
                setElementData(ped, "isReplayPed", true, false)
                peds[name] = { ped = ped, track = track, frameIdx = 1, dead = false, weapon = 0, sample = {} }
            end
        end
    end
    followName = sortedNames()[1]
    -- Azonnal a felvétel helyére visszük a saját (láthatatlan) játékosunkat, különben a pedek nem streamelődnek be
    local first = followName and peds[followName]
    if first then
        local f = first.track.frames[1]
        setElementPosition(localPlayer, f[F_X], f[F_Y], f[F_Z] + 0.5)
        setElementFrozen(localPlayer, false)
    end
    lastStreamMove = 0
    showCursor(true)
    addEventHandler("onClientRender", root, renderReplay)
end)

-- A visszajátszott pedek valóban lőnek; a nézőt (láthatatlan, saját dimenzióban) ne sebezzék
addEventHandler("onClientPlayerDamage", localPlayer, function()
    if replay then cancelEvent() end
end)

addEvent("ttt:replayStop", true)
addEventHandler("ttt:replayStop", root, stopReplay)

-- Idővonal: kattintás = ugrás, lenyomva tartva = húzás
addEventHandler("onClientClick", root, function(button, state)
    if not replay or button ~= "left" then return end
    if state == "down" then
        if isMouseOverTimeline() then
            timelineDrag = true
            local cx = getCursorPosition()
            seekTo(math.max(0, math.min(1, (cx * screenW - TL_X) / TL_W)) * replay.length)
        end
    else
        timelineDrag = false
    end
end)

addEventHandler("onClientKey", root, function(button, press)
    if not replay or not press then return end
    if button == "space" then
        paused = not paused
        cancelEvent()
    elseif button == "arrow_left" or button == "arrow_right" then
        seekTo(playTime + (button == "arrow_left" and -5000 or 5000))
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
    elseif button == "F6" then
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
