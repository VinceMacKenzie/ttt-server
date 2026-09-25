-----------------------------------------
-- TTT CORE - KLIENS OLDAL
-----------------------------------------
local screenW, screenH = guiGetScreenSize()
local roundEndTime = 0
local selectedCorpse = nil

local roleHex = {
    Traitor   = "#db594b",
    Detective = "#39aef7",
    Innocent  = "#36a864",
}

-- Idő szinkronizálása a szerverről (0 = óra elrejtése)
addEvent("ttt:updateTime", true)
addEventHandler("ttt:updateTime", root, function(durationMs)
    roundEndTime = (durationMs and durationMs > 0) and (getTickCount() + durationMs) or 0
end)

-- Kattintás hullára: kijelölés / elrejtés
addEventHandler("onClientClick", root, function(button, state, _, _, _, _, _, clickedElement)
    if button ~= "left" or state ~= "down" then return end
    if clickedElement and getElementData(clickedElement, "isCorpse") then
        selectedCorpse = (selectedCorpse == clickedElement) and nil or clickedElement
    else
        selectedCorpse = nil
    end
end)

-- Egyetlen render handler: visszaszámláló + hulla infó
addEventHandler("onClientRender", root, function()
    local now = getTickCount()

    -- 1. Visszaszámláló felül középen
    if roundEndTime > now then
        local remaining = (roundEndTime - now) / 1000
        local timeStr = string.format("%02d:%02d", math.floor(remaining / 60), math.floor(remaining % 60))
        dxDrawRectangle(screenW / 2 - 40, 20, 80, 30, tocolor(0, 0, 0, 150))
        dxDrawText(timeStr, screenW / 2 - 40, 20, screenW / 2 + 40, 50, tocolor(255, 255, 255, 255), 1.5, "default-bold", "center", "center")
    end

    -- 2. Kijelölt hulla adatai
    if selectedCorpse then
        if not isElement(selectedCorpse) then
            selectedCorpse = nil
            return
        end
        local cx, cy, cz = getElementPosition(selectedCorpse)
        local sx, sy = getScreenFromWorldPosition(cx, cy, cz + 1.2)
        if sx and sy then
            local role = getElementData(selectedCorpse, "corpse:role") or "Ismeretlen"
            local text = string.format(
                "#ffffffNév: #aaaaaa%s\n#ffffffSzerep: %s%s\n#ffffffFegyver: #aaaaaa%s\n#ffffffIdő: #aaaaaa%s",
                getElementData(selectedCorpse, "corpse:name") or "Ismeretlen",
                roleHex[role] or "#ffffff", role,
                getElementData(selectedCorpse, "corpse:weapon") or "Ismeretlen",
                getElementData(selectedCorpse, "corpse:time") or "Ismeretlen"
            )
            dxDrawRectangle(sx - 100, sy - 10, 200, 90, tocolor(0, 0, 0, 180))
            dxDrawText(text, sx - 95, sy, sx + 95, sy + 80, tocolor(255, 255, 255, 255), 1.1, "default-bold", "left", "top", false, false, false, true)
        end
    end
end)

-- M: kurzor ki/be (csak itt van bindolva - a ttt-hud-ból kivéve, mert a két bind kioltotta egymást)
bindKey("m", "down", function()
    showCursor(not isCursorShowing())
end)
