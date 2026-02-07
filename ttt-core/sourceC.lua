-----------------------------------------
-- TTT CORE - KLIENS OLDAL
-----------------------------------------

local screenW, screenH = guiGetScreenSize()
local roundEndTime = 0
local myRole = ""
local roleColors = {
    ["Traitor"] = {231, 76, 60},
    ["Innocent"] = {46, 204, 113},
    ["Detective"] = {52, 152, 219}
}

addEventHandler("onClientRender", root, function()
    local now = getTickCount()
    
    -- 1. DX VISSZASZÁMLÁLÓ
    if roundEndTime > now then
        local remaining = (roundEndTime - now) / 1000
        local mins = math.floor(remaining / 60)
        local secs = math.floor(remaining % 60)
        local timeStr = string.format("%02d:%02d", mins, secs)
        
        -- Háttér és szöveg felül középütt
        dxDrawRectangle(screenW/2 - 40, 20, 80, 30, tocolor(0, 0, 0, 150))
        dxDrawText(timeStr, screenW/2 - 40, 20, screenW/2 + 40, 50, tocolor(255, 255, 255, 255), 1.5, "default-bold", "center", "center")
    end
end)

-- Amikor megváltozik a szerepünk
addEventHandler("onClientElementDataChange", localPlayer, function(dataName)
    if dataName == "tttRole" then
        local role = getElementData(localPlayer, "tttRole")
        if role then
            myRole = role
            setTimer(function() myRole = "" end, 7000, 1) -- 7 mp után eltűnik a felirat
        else
            myRole = ""
        end
    end
end)

-- Idő szinkronizálása a szerverről
addEvent("ttt:updateTime", true)
addEventHandler("ttt:updateTime", root, function(durationMs)
    roundEndTime = getTickCount() + durationMs
end)


local selectedCorpse = nil

-- Kattintás figyelése
addEventHandler("onClientClick", root, function(button, state, absoluteX, absoluteY, worldX, worldY, worldZ, clickedElement)
    if button == "left" and state == "down" then
        if clickedElement and getElementData(clickedElement, "isCorpse") then
            -- Ha rákattintunk egy hullára, kijelöljük
            if selectedCorpse == clickedElement then
                selectedCorpse = nil -- Ha újra rákattintunk, eltűnik a GUI
            else
                selectedCorpse = clickedElement
            end
        else
            selectedCorpse = nil -- Ha máshova kattintunk, eltűnik
        end
    end
end)

-- DX Megjelenítés (a hulla felett)
addEventHandler("onClientRender", root, function()
    if selectedCorpse and isElement(selectedCorpse) then
        local cx, cy, cz = getElementPosition(selectedCorpse)
        local sx, sy = getScreenFromWorldPosition(cx, cy, cz + 1.2) -- A hulla felett 1.2 méterrel
        
        if sx and sy then
            local name = getElementData(selectedCorpse, "corpse:name") or "Ismeretlen"
            local role = getElementData(selectedCorpse, "corpse:role") or "Ismeretlen"
            local weapon = getElementData(selectedCorpse, "corpse:weapon") or "Ismeretlen"
            local time = getElementData(selectedCorpse, "corpse:time") or "Ismeretlen"
            
            -- Szín a szerep alapján
            local roleColor = "#ffffff"
            if role == "Traitor" then roleColor = "#db594b"
            elseif role == "Detective" then roleColor = "#39aef7"
            elseif role == "Innocent" then roleColor = "#36a864" end

            local text = string.format(
                "#ffffffNév: #aaaaaa%s\n#ffffffSzerep: %s%s\n#ffffffFegyver: #aaaaaa%s\n#ffffffIdő: #aaaaaa%s",
                name, roleColor, role, weapon, time
            )
            
            -- Háttér téglalap
            dxDrawRectangle(sx - 100, sy - 10, 200, 90, tocolor(0, 0, 0, 180))
            dxDrawText(text, sx - 95, sy, sx + 95, sy + 80, tocolor(255, 255, 255, 255), 1.1, "default-bold", "left", "top", false, false, false, true)
        end
    end
end)

-- M betű lenyomására kurzor ki/bekapcsolása
bindKey("m", "down", function()
    local currentState = showCursor(not isCursorShowing()) -- Megfordítja az aktuális állapotot
end)