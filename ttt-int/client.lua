-----------------------------------------
-- TTT INTERIORS - KLIENS: /int panel (cyberpunk stílus, mint a ttt-hud)
-- /int          = panel megnyitása / bezárása
-- Gépelj a keresőbe (név vagy interior ID), görgetés = egérgörgő,
-- kattintás egy sorra = teleport, ENTER = az egyetlen találatra teleport, ESC = bezár
-----------------------------------------
local sw, sh = guiGetScreenSize()
local PW, PH = 780, 560
local px, py = math.floor((sw - PW) / 2), math.floor((sh - PH) / 2)
local ROW_H, ROWS = 34, 11
local LIST_X, LIST_Y, LIST_W = px + 20, py + 138, PW - 40 - 14   -- 14 px a görgetősávnak
local MIN_ADMIN = 1

local isOpen = false
local edit = nil
local filtered = {}      -- a szűrt lista elemei: indexek az INTERIORS-ban
local lastQuery = nil
local lastText = nil     -- az utolsó keresőszöveg (csak ha ez változik, ugrik vissza a lista tetejére)
local scroll = 0         -- hány sort görgettünk le
local lerpScroll = 0
local renderPanelState = nil
local hiddenSet = {}     -- [INTERIORS index] = true: az X-szel kivett helyek
local hiddenCount = 0
local counts = {}       -- [interior név] = { players, weapons } a panel soraihoz

addEvent("tttInt:hidden", true)
addEventHandler("tttInt:hidden", root, function(list, spawnCounts)
    counts = spawnCounts or {}
    hiddenSet, hiddenCount = {}, 0
    for _, i in ipairs(list or {}) do
        hiddenSet[i] = true
        hiddenCount = hiddenCount + 1
    end
    lastQuery = nil
end)

local CYAN = tocolor(0, 195, 255, 150)
local CYAN_SOLID = tocolor(0, 195, 255, 255)
local GREEN = tocolor(46, 204, 113, 200)
local BG = tocolor(0, 15, 25, 215)

-- Cyberpunk sarkok a ttt-hud-ból
local function drawCyberBorder(ax, ay, aw, ah, color, t)
    local l = 20
    dxDrawLine(ax, ay, ax + l, ay, color, t)
    dxDrawLine(ax, ay, ax, ay + l, color, t)
    dxDrawLine(ax + aw, ay, ax + aw - l, ay, color, t)
    dxDrawLine(ax + aw, ay, ax + aw, ay + l, color, t)
    dxDrawLine(ax, ay + ah, ax + l, ay + ah, color, t)
    dxDrawLine(ax, ay + ah, ax, ay + ah - l, color, t)
    dxDrawLine(ax + aw, ay + ah, ax + aw - l, ay + ah, color, t)
    dxDrawLine(ax + aw, ay + ah, ax + aw, ay + ah - l, color, t)
end

local function inside(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

-- Szűrés: név részlet VAGY pontos interior ID
local function refilter()
    local q = guiGetText(edit):gsub("^%s+", ""):gsub("%s+$", ""):lower()
    if q == lastQuery then return end
    lastQuery = q
    filtered = {}
    for i, e in ipairs(INTERIORS) do
        if not hiddenSet[i] and (q == "" or tostring(e[1]) == q or e[2]:lower():find(q, 1, true)) then
            table.insert(filtered, i)
        end
    end
    if q ~= lastText then
        lastText = q
        scroll, lerpScroll = 0, 0
    end
    scroll = math.min(scroll, math.max(0, #filtered - ROWS))
    lerpScroll = math.min(lerpScroll, scroll)
end

local function maxScroll()
    return math.max(0, #filtered - ROWS)
end

local function hideInterior(idx)
    if hiddenSet[idx] then return end
    hiddenSet[idx] = true
    hiddenCount = hiddenCount + 1
    lastQuery = nil                      -- újraszűrés a következő képkockán
    triggerServerEvent("tttInt:hide", localPlayer, idx)
end

local function doTeleport(interiorIdx)
    triggerServerEvent("tttInt:teleport", localPlayer, interiorIdx)
end

local function closePanel()
    if not isOpen then return end
    isOpen = false
    removeEventHandler("onClientRender", root, renderPanel)
    if isElement(edit) then destroyElement(edit) end
    edit = nil
    guiSetInputEnabled(false)
    showCursor(false)
end

local function openPanel()
    if isOpen then return end
    isOpen = true
    lastQuery, lastText = nil, nil
    edit = guiCreateEdit(0, 0, 10, 10, "", false)
    guiSetAlpha(edit, 0)               -- a gépelést a rejtett edit kezeli, mi rajzoljuk ki
    guiBringToFront(edit)
    guiSetInputEnabled(true)
    showCursor(true)
    refilter()
    triggerServerEvent("tttInt:getHidden", localPlayer)   -- az elrejtett lista a szerverről jön
    addEventHandler("onClientRender", root, renderPanel)
end

function renderPanel()
    if not isOpen then return end
    if not isElement(edit) then return closePanel() end
    refilter()
    lerpScroll = lerpScroll + (scroll - lerpScroll) * 0.25

    local mx, my = getCursorPosition()
    mx, my = (mx or 0) * sw, (my or 0) * sh
    local now = getTickCount()

    -- Háttér + keret
    dxDrawRectangle(px, py, PW, PH, BG)
    drawCyberBorder(px - 2, py - 2, PW + 4, PH + 4, CYAN, 3)

    -- Fejléc
    dxDrawRectangle(px, py, PW, 54, tocolor(0, 195, 255, 30))
    dxDrawText("INTERIOR TELEPORT", px + 20, py, px + PW, py + 54, CYAN_SOLID, 1.1, "bankgothic", "left", "center")
    dxDrawText(#filtered .. " / " .. (#INTERIORS - hiddenCount) .. " HELY", px, py, px + PW - 60, py + 54, tocolor(255, 255, 255, 120), 0.9, "default-bold", "right", "center")
    dxDrawLine(px, py + 54, px + PW, py + 54, tocolor(0, 195, 255, 60), 1)

    -- Bezár gomb
    local cx, cy, cw, ch = px + PW - 44, py + 12, 30, 30
    local hoverClose = inside(mx, my, cx, cy, cw, ch)
    dxDrawRectangle(cx, cy, cw, ch, hoverClose and tocolor(231, 76, 60, 90) or tocolor(255, 255, 255, 10))
    dxDrawText("X", cx, cy, cx + cw, cy + ch, tocolor(231, 76, 60, 255), 1.0, "default-bold", "center", "center")

    -- Kereső
    local text = guiGetText(edit)
    local sx, sy, sW, sH = px + 20, py + 68, PW - 40, 40
    dxDrawRectangle(sx, sy, sW, sH, tocolor(255, 255, 255, 10))
    dxDrawLine(sx, sy + sH, sx + sW, sy + sH, tocolor(0, 195, 255, 255), 1)
    if text == "" then
        dxDrawText("SEARCH // írj egy nevet vagy interior ID-t (pl. 12)...", sx + 12, sy, sx + sW, sy + sH, tocolor(255, 255, 255, 70), 1.0, "default-bold", "left", "center")
    else
        local cursor = (math.floor(now / 500) % 2 == 0) and "_" or ""
        dxDrawText(text .. cursor, sx + 12, sy, sx + sW, sy + sH, tocolor(255, 255, 255, 230), 1.1, "default-bold", "left", "center", true)
    end

    -- Oszlopcímek
    dxDrawText("ID", LIST_X + 10, py + 114, LIST_X + 70, py + 138, tocolor(255, 255, 255, 80), 0.8, "default-bold", "left", "center")
    dxDrawText("HELYSZÍN", LIST_X + 80, py + 114, LIST_X + 400, py + 138, tocolor(255, 255, 255, 80), 0.8, "default-bold", "left", "center")
    dxDrawText("KOORDINÁTA", LIST_X, py + 114, LIST_X + LIST_W - 10, py + 138, tocolor(255, 255, 255, 80), 0.8, "default-bold", "right", "center")

    -- Lista (a lerpScroll miatt egy plusz sort is kirajzolunk, a render target kivágja)
    local first = math.floor(lerpScroll)
    local frac = lerpScroll - first
    local hoverRow, hoverRemove = nil, nil
    for r = 0, ROWS do
        local fi = first + r + 1
        local idx = filtered[fi]
        if idx then
            local ry = LIST_Y + (r - frac) * ROW_H
            if ry >= LIST_Y - 1 and ry + ROW_H <= LIST_Y + ROWS * ROW_H + 1 then
                local e = INTERIORS[idx]
                local xw, xh = 26, ROW_H - 10
                local xx, xy = LIST_X + LIST_W - xw - 8, ry + 4
                local onX = inside(mx, my, xx, xy, xw, xh)
                local hover = inside(mx, my, LIST_X, ry, LIST_W, ROW_H) and not onX
                if onX then hoverRemove = idx elseif hover then hoverRow = idx end
                dxDrawRectangle(LIST_X, ry, LIST_W, ROW_H - 2, hover and tocolor(0, 195, 255, 45) or tocolor(255, 255, 255, (fi % 2 == 0) and 6 or 0))
                if hover then dxDrawRectangle(LIST_X, ry, 3, ROW_H - 2, CYAN_SOLID) end
                -- ID jelvény
                dxDrawRectangle(LIST_X + 10, ry + 6, 44, ROW_H - 14, tocolor(0, 195, 255, 40))
                dxDrawText(tostring(e[1]), LIST_X + 10, ry + 6, LIST_X + 54, ry + ROW_H - 8, CYAN_SOLID, 0.95, "default-bold", "center", "center")
                -- Név
                dxDrawText(e[2], LIST_X + 66, ry, LIST_X + 440, ry + ROW_H - 2, tocolor(255, 255, 255, hover and 255 or 210), 1.0, "default-bold", "left", "center", true)
                -- Mentett spawnok száma ebben az interiorban
                local cnt = counts[e[2]]
                if cnt then
                    dxDrawText(string.format("%d SPAWN  %d FEGYVER", cnt.players, cnt.weapons), LIST_X + 250, ry, LIST_X + 432, ry + ROW_H - 2,
                        tocolor(46, 204, 113, hover and 255 or 200), 0.8, "default-bold", "right", "center")
                end
                -- Koordináta
                dxDrawText(string.format("%.1f, %.1f, %.1f", e[3], e[4], e[5]), LIST_X + 440, ry, LIST_X + LIST_W - 46, ry + ROW_H - 2,
                    hover and GREEN or tocolor(255, 255, 255, 90), 0.9, "default-bold", "right", "center")
                -- X gomb: kiveszi az interiort a listából
                dxDrawRectangle(xx, xy, xw, xh, onX and tocolor(231, 76, 60, 110) or tocolor(231, 76, 60, 25))
                dxDrawText("X", xx, xy, xx + xw, xy + xh, tocolor(231, 76, 60, onX and 255 or 170), 0.9, "default-bold", "center", "center")
            end
        end
    end
    if #filtered == 0 then
        dxDrawText("NINCS TALÁLAT", LIST_X, LIST_Y, LIST_X + LIST_W, LIST_Y + ROWS * ROW_H, tocolor(231, 76, 60, 200), 1.2, "bankgothic", "center", "center")
    end

    -- Görgetősáv
    local trackX, trackY, trackH = px + PW - 34, LIST_Y, ROWS * ROW_H
    dxDrawRectangle(trackX, trackY, 6, trackH, tocolor(255, 255, 255, 12))
    if #filtered > ROWS then
        local thumbH = math.max(30, trackH * ROWS / #filtered)
        local thumbY = trackY + (trackH - thumbH) * (lerpScroll / maxScroll())
        dxDrawRectangle(trackX, thumbY, 6, thumbH, CYAN)
    end

    -- Lábléc: vissza az eredeti helyre + súgó
    local by = py + PH - 54
    dxDrawLine(px, by - 4, px + PW, by - 4, tocolor(0, 195, 255, 60), 1)
    local bx, bw, bh = px + 20, 230, 36
    local hoverBack = inside(mx, my, bx, by, bw, bh)
    dxDrawRectangle(bx, by, bw, bh, hoverBack and tocolor(46, 204, 113, 70) or tocolor(46, 204, 113, 25))
    dxDrawLine(bx, by + bh, bx + bw, by + bh, tocolor(46, 204, 113, 255), 1)
    dxDrawText("VISSZA AZ EREDETI HELYRE", bx, by, bx + bw, by + bh, tocolor(46, 204, 113, 255), 0.9, "default-bold", "center", "center")
    local rx, rw = px + 260, 250
    local hoverRestore = hiddenCount > 0 and inside(mx, my, rx, by, rw, bh)
    if hiddenCount > 0 then
        dxDrawRectangle(rx, by, rw, bh, hoverRestore and tocolor(0, 195, 255, 70) or tocolor(0, 195, 255, 25))
        dxDrawLine(rx, by + bh, rx + rw, by + bh, CYAN_SOLID, 1)
        dxDrawText("ELREJTETTEK VISSZAÁLLÍTÁSA (" .. hiddenCount .. ")", rx, by, rx + rw, by + bh, CYAN_SOLID, 0.85, "default-bold", "center", "center")
    end
    dxDrawText("KATTINTÁS = teleport | X = elrejt | ENTER | ESC", px + 520, by, px + PW - 20, by + bh,
        tocolor(255, 255, 255, 90), 0.75, "default-bold", "right", "center")

    -- az egér állapotát a click handlernek is átadjuk
    renderPanelState = { hoverRow = hoverRow, hoverRemove = hoverRemove, hoverClose = hoverClose, hoverBack = hoverBack, hoverRestore = hoverRestore }
end

addEventHandler("onClientClick", root, function(button, state)
    if not isOpen or button ~= "left" or state ~= "down" then return end
    local s = renderPanelState
    if not s then return end
    if s.hoverClose then
        closePanel()
    elseif s.hoverBack then
        triggerServerEvent("tttInt:back", localPlayer)
    elseif s.hoverRestore then
        triggerServerEvent("tttInt:restoreAll", localPlayer)
    elseif s.hoverRemove then
        hideInterior(s.hoverRemove)
    elseif s.hoverRow then
        doTeleport(s.hoverRow)
    end
    if isElement(edit) then guiBringToFront(edit) end   -- a fókusz maradjon a keresőn
end)

addEventHandler("onClientKey", root, function(key, press)
    if not isOpen or not press then return end
    if key == "escape" then
        cancelEvent()
        closePanel()
    elseif key == "mouse_wheel_up" then
        scroll = math.max(0, scroll - 2)
    elseif key == "mouse_wheel_down" then
        scroll = math.min(maxScroll(), scroll + 2)
    elseif key == "enter" or key == "num_enter" then
        if #filtered == 1 then doTeleport(filtered[1]) end
    end
end)

addCommandHandler("int", function()
    if (tonumber(getElementData(localPlayer, "admin")) or 0) < MIN_ADMIN then
        return outputChatBox("#00c3ff[Interior] #ffffffEhhez admin jog kell!", 255, 255, 255, true)
    end
    if isOpen then closePanel() else openPanel() end
end)

addEventHandler("onClientResourceStop", resourceRoot, closePanel)


-----------------------------------------
-- SPAWN MARKEREK + INFO PANEL (/showspawns, /cspawn, /cweapon)
-- Játékos spawn = cián, fegyver spawn: norm = szürke, epic = lila, legendary = arany.
-- A markerek az interiorhoz kötöttek, csak abban látszanak, ahová lettek rakva.
-----------------------------------------
local spawnEntries = {}     -- { marker, s }
local spawnList = {}
local spawnRender = false
local currentName = nil     -- melyik interiorban vagy (a szerver küldi)

local PLAYER_COLOR = { 0, 195, 255 }
local TIER_COLORS = { norm = { 200, 200, 200 }, epic = { 170, 80, 255 }, legendary = { 255, 170, 0 } }

local function spawnColor(s)
    if s.type == "player" then return PLAYER_COLOR end
    return TIER_COLORS[s.tier] or TIER_COLORS.norm
end

local function clearSpawnMarkers()
    for _, e in ipairs(spawnEntries) do
        if isElement(e.marker) then destroyElement(e.marker) end
    end
    spawnEntries, spawnList = {}, {}
end

function renderSpawns()
    local cx, cy, cz = getCameraMatrix()
    local int = getElementInterior(localPlayer)

    -- feliratok a markerek felett
    for _, e in ipairs(spawnEntries) do
        local s = e.s
        if s.int == int then
            local dist = getDistanceBetweenPoints3D(cx, cy, cz, s.x, s.y, s.z)
            if dist < 30 then
                local c = spawnColor(s)
                if s.type == "player" and s.rot then      -- a vonal a nézési irányt mutatja
                    local rad = math.rad(s.rot)
                    dxDrawLine3D(s.x, s.y, s.z + 0.1, s.x - math.sin(rad) * 1.2, s.y + math.cos(rad) * 1.2, s.z + 0.1, tocolor(c[1], c[2], c[3], 220), 3)
                end
                local sx, sy = getScreenFromWorldPosition(s.x, s.y, s.z + 1.0)
                if sx then
                    local scale = math.max(0.6, 1.2 - dist / 40)
                    local label = s.type == "player" and ("SPAWN #" .. s.id) or ("WEAPON #" .. s.id .. "  " .. string.upper(s.tier or "norm"))
                    dxDrawText(label, sx + 1, sy + 1, sx + 1, sy + 1, tocolor(0, 0, 0, 220), scale, "default-bold", "center", "center")
                    dxDrawText(label, sx, sy, sx, sy, tocolor(c[1], c[2], c[3], 255), scale, "default-bold", "center", "center")
                end
            end
        end
    end

    -- info panel (bal felül): hol vagy és mennyi spawn van ott
    local players, weapons = 0, { norm = 0, epic = 0, legendary = 0 }
    for _, s in ipairs(spawnList) do
        if currentName and s.interior == currentName then
            if s.type == "player" then players = players + 1
            else weapons[s.tier or "norm"] = (weapons[s.tier or "norm"] or 0) + 1 end
        end
    end
    local bx, by, bw, bh = 30, 30, 340, 86
    dxDrawRectangle(bx, by, bw, bh, tocolor(0, 15, 25, 200))
    drawCyberBorder(bx - 2, by - 2, bw + 4, bh + 4, tocolor(0, 195, 255, 150), 3)
    dxDrawText("SPAWN EDITOR", bx + 14, by + 8, bx + bw, by + 28, tocolor(0, 195, 255, 255), 0.95, "default-bold")
    local where = currentName and (currentName .. "  [ID " .. int .. "]") or "NINCS (normál világ)"
    dxDrawText("INTERIOR: " .. where, bx + 14, by + 30, bx + bw - 10, by + 48, tocolor(255, 255, 255, 220), 0.9, "default-bold", "left", "top", true)
    dxDrawText("PLAYER: " .. players, bx + 14, by + 52, bx + 120, by + 70, tocolor(PLAYER_COLOR[1], PLAYER_COLOR[2], PLAYER_COLOR[3], 255), 0.85, "default-bold")
    dxDrawText("N " .. weapons.norm, bx + 110, by + 52, bx + 160, by + 70, tocolor(200, 200, 200, 255), 0.85, "default-bold")
    dxDrawText("E " .. weapons.epic, bx + 165, by + 52, bx + 215, by + 70, tocolor(170, 80, 255, 255), 0.85, "default-bold")
    dxDrawText("L " .. weapons.legendary, bx + 220, by + 52, bx + 270, by + 70, tocolor(255, 170, 0, 255), 0.85, "default-bold")
end

addEvent("tttSpawns:sync", true)
addEventHandler("tttSpawns:sync", root, function(payload)
    clearSpawnMarkers()
    if type(payload) ~= "table" then
        currentName = nil
        if spawnRender then
            removeEventHandler("onClientRender", root, renderSpawns)
            spawnRender = false
        end
        return
    end
    currentName = payload.current or nil
    spawnList = payload.list or {}
    for _, s in ipairs(spawnList) do
        local c = spawnColor(s)
        local m = createMarker(s.x, s.y, s.z, "checkpoint", 1.4, c[1], c[2], c[3], 140)
        if m then
            setElementInterior(m, s.int or 0)
            table.insert(spawnEntries, { marker = m, s = s })
        end
    end
    if not spawnRender then
        addEventHandler("onClientRender", root, renderSpawns)
        spawnRender = true
    end
end)

addEvent("tttSpawns:current", true)
addEventHandler("tttSpawns:current", root, function(name)
    currentName = name or nil
end)

addEventHandler("onClientResourceStop", resourceRoot, clearSpawnMarkers)
