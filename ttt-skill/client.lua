-----------------------------------------
-- TTT SKILL - kliens oldal: F1-re megnyíló skill HUD (a ttt-hud stílusában)
-----------------------------------------
local screenW, screenH = guiGetScreenSize()
local visible = false

local mainCyan = tocolor(0, 195, 255, 150)
local valueGreen = tocolor(46, 204, 113, 255)

local function drawCyberBorder(ax, ay, aw, ah, color, thickness)
    local t, l = thickness, 20
    dxDrawLine(ax, ay, ax + l, ay, color, t)
    dxDrawLine(ax, ay, ax, ay + l, color, t)
    dxDrawLine(ax + aw, ay, ax + aw - l, ay, color, t)
    dxDrawLine(ax + aw, ay, ax + aw, ay + l, color, t)
    dxDrawLine(ax, ay + ah, ax + l, ay + ah, color, t)
    dxDrawLine(ax, ay + ah, ax, ay + ah - l, color, t)
    dxDrawLine(ax + aw, ay + ah, ax + aw - l, ay + ah, color, t)
    dxDrawLine(ax + aw, ay + ah, ax + aw, ay + ah - l, color, t)
end

addEventHandler("onClientRender", root, function()
    if not visible then return end

    local w, headerH, rowH, footerH = 470, 56, 42, 30
    local h = headerH + #SKILLS * rowH + footerH
    local x, y = (screenW - w) / 2, (screenH - h) / 2

    dxDrawRectangle(x, y, w, h, tocolor(0, 15, 25, 200))
    drawCyberBorder(x - 2, y - 2, w + 4, h + 4, mainCyan, 3)

    -- fejléc sáv (mint a ttt-hud szerep sávja)
    dxDrawRectangle(x, y, w, headerH, tocolor(0, 195, 255, 30))
    dxDrawText("SKILLS", x, y, x + w, y + headerH, tocolor(0, 195, 255, 255), 1.6, "bankgothic", "center", "center")

    for i, s in ipairs(SKILLS) do
        local value = math.min(MAX_SKILL, math.floor(tonumber(getElementData(localPlayer, s.key)) or 0))
        local ry = y + headerH + (i - 1) * rowH

        dxDrawRectangle(x, ry, w, 1, tocolor(0, 195, 255, 40))
        dxDrawText(s.label:upper(), x + 20, ry + 5, x + w - 140, ry + 24, tocolor(255, 255, 255, 230), 1.0, "default-bold", "left", "top", true)
        dxDrawText(s.weapons, x + 20, ry + 22, x + w - 140, ry + 36, tocolor(255, 255, 255, 80), 0.75, "default-bold", "left", "top", true)
        dxDrawText(value .. " / " .. MAX_SKILL, x + w - 130, ry, x + w - 20, ry + rowH, valueGreen, 1.2, "default-bold", "right", "center")

        local barW = w - 40
        dxDrawRectangle(x + 20, ry + rowH - 7, barW, 3, tocolor(255, 255, 255, 10))
        dxDrawRectangle(x + 20, ry + rowH - 7, barW * (value / MAX_SKILL), 3, tocolor(0, 195, 255, 150))
    end

    local fy = y + headerH + #SKILLS * rowH
    dxDrawRectangle(x, fy, w, 1, tocolor(0, 195, 255, 40))
    dxDrawText("[F1] BEZÁRÁS", x, fy, x + w, fy + footerH, tocolor(255, 255, 255, 90), 0.8, "default-bold", "center", "center")
end)

bindKey("F1", "down", function()
    if isChatBoxInputActive() or isConsoleActive() then return end
    if getElementData(localPlayer, "banned") then return end
    visible = not visible
end)
