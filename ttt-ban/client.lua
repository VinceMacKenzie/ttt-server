-----------------------------------------
-- TTT BAN - kliens oldal: sötét képernyő a ttt-hud stílusában
-----------------------------------------
local screenW, screenH = guiGetScreenSize()
local banInfo = false
local chatWasVisible = true
local keepTimer

addEvent("ttt-ban:show", true)
addEvent("ttt-ban:hide", true)

local mainCyan = tocolor(0, 195, 255, 150)

local function drawCyberBorder(ax, ay, aw, ah, color, thickness)
    local t, l = thickness, 20
    dxDrawLine(ax, ay, ax + l, ay, color, t, true)
    dxDrawLine(ax, ay, ax, ay + l, color, t, true)
    dxDrawLine(ax + aw, ay, ax + aw - l, ay, color, t, true)
    dxDrawLine(ax + aw, ay, ax + aw, ay + l, color, t, true)
    dxDrawLine(ax, ay + ah, ax + l, ay + ah, color, t, true)
    dxDrawLine(ax, ay + ah, ax, ay + ah - l, color, t, true)
    dxDrawLine(ax + aw, ay + ah, ax + aw - l, ay + ah, color, t, true)
    dxDrawLine(ax + aw, ay + ah, ax + aw, ay + ah - l, color, t, true)
end

addEventHandler("onClientRender", root, function()
    if not banInfo then return end

    -- teljes sötét képernyő (postGUI = true: a többi HUD fölé kerül)
    dxDrawRectangle(0, 0, screenW, screenH, tocolor(0, 0, 0, 255), true)

    local w = math.min(780, screenW - 60)
    local rowTitle, rowAdmin, rowReason = 76, 56, 130
    local h = rowTitle + rowAdmin + rowReason
    local x, y = (screenW - w) / 2, (screenH - h) / 2

    dxDrawRectangle(x, y, w, h, tocolor(0, 15, 25, 220), true)
    drawCyberBorder(x - 2, y - 2, w + 4, h + 4, mainCyan, 3)

    -- 1. sáv: cím (mint a ttt-hud szerep sávja, pirosban)
    dxDrawRectangle(x, y, w, rowTitle, tocolor(231, 76, 60, 30), true)
    dxDrawText("BANNOLVA VAGY", x, y, x + w, y + rowTitle, tocolor(231, 76, 60, 255), 1.6, "bankgothic", "center", "center", false, false, true)
    dxDrawRectangle(x, y + rowTitle, w, 1, tocolor(0, 195, 255, 40), true)

    -- 2. sáv: a bannoló admin
    local ay = y + rowTitle
    dxDrawText("Admin neve aki bannolt: " .. banInfo.admin, x + 30, ay, x + w - 30, ay + rowAdmin, tocolor(0, 195, 255, 220), 1.2, "default-bold", "left", "center", true, false, true)
    dxDrawRectangle(x, ay + rowAdmin, w, 1, tocolor(0, 195, 255, 40), true)

    -- 3. sáv: indok (hosszú szöveg több sorba tör)
    local ry = ay + rowAdmin
    dxDrawText("Indok: " .. banInfo.reason, x + 30, ry + 16, x + w - 30, ry + rowReason - 10, tocolor(255, 255, 255, 230), 1.2, "default-bold", "left", "top", true, true, true)
end)

local function lock()
    showChat(false)
    toggleAllControls(false, true, false)
end

local function restore()
    banInfo = false
    if isTimer(keepTimer) then killTimer(keepTimer) end
    toggleAllControls(true, true, true)
    showChat(chatWasVisible)
end

addEventHandler("ttt-ban:show", resourceRoot, function(admin, reason)
    if not banInfo then chatWasVisible = isChatVisible() end
    banInfo = { admin = tostring(admin), reason = tostring(reason) }
    lock()
    -- más resource visszakapcsolhatja a vezérlést / chatet, ezért másodpercenként újra letiltjuk
    if not isTimer(keepTimer) then
        keepTimer = setTimer(function() if banInfo then lock() end end, 1000, 0)
    end
end)

addEventHandler("ttt-ban:hide", resourceRoot, restore)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if banInfo then restore() end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    triggerServerEvent("ttt-ban:ready", localPlayer)
end)
