local screenW, screenH = guiGetScreenSize()
local reportCount = 0
local showReportUI = false
local selectedReport = nil
local messages = {}
local reportList = {}

-- TTT HUD Színkódok integrálása
local adminColors = {
    [1] = {r = 46, g = 204, b = 113, name = "ADMIN"},       -- Innocent zöld
    [2] = {r = 52, g = 152, b = 219, name = "FŐADMIN"},     -- Detective kék
    [3] = {r = 231, g = 76, b = 60, name = "TULAJDONOS"},   -- Traitor piros
}
local mainCyan = tocolor(0, 195, 255, 150)

-- UI Pozíciók
local uiW, uiH = 750, 500
local uiX, uiY = (screenW - uiW) / 2, (screenH - uiH) / 2
local chatX, chatY, chatW, chatH = uiX + 220, uiY + 55, uiW - 235, uiH - 145

-- HUD Indikátor pozíció
local rw, rh = 200, 50
local rx, ry = screenW - rw - 30, screenH - rh - 220

-- EditBox a bevitelhez
local msgInput = guiCreateEdit(chatX, uiY + uiH - 35, chatW, 25, "", false)
guiSetVisible(msgInput, false)
guiSetAlpha(msgInput, 0)
guiSetProperty(msgInput, "MaxTextLength", "100")

function drawCyberBorder(ax, ay, aw, ah, color, thickness)
    local l = 20
    dxDrawLine(ax, ay, ax + l, ay, color, thickness)
    dxDrawLine(ax, ay, ax, ay + l, color, thickness)
    dxDrawLine(ax + aw, ay, ax + aw - l, ay, color, thickness)
    dxDrawLine(ax + aw, ay, ax + aw, ay + l, color, thickness)
    dxDrawLine(ax, ay + ah, ax + l, ay + ah, color, thickness)
    dxDrawLine(ax, ay + ah, ax, ay + ah - l, color, thickness)
    dxDrawLine(ax + aw, ay + ah, ax + aw - l, ay + ah, color, thickness)
    dxDrawLine(ax + aw, ay + ah, ax + aw, ay + ah - l, color, thickness)
end

addEventHandler("onClientRender", root, function()
    local adminLvl = getElementData(localPlayer, "admin") or 0
    if adminLvl < 1 then return end

    -- HUD INDIKÁTOR
    dxDrawRectangle(rx, ry, rw, rh, tocolor(0, 15, 25, 200))
    drawCyberBorder(rx, ry, rw, rh, mainCyan, 2)
    dxDrawText("REPORT_SQUAD: " .. reportCount, rx + 15, ry, rx + rw, ry + rh, tocolor(255, 255, 255, 200), 1.0, "default-bold", "left", "center")

    if reportCount > 0 then
        local pulse = (math.sin(getTickCount()/200) * 100) + 155
        dxDrawCircle(rx + rw - 25, ry + rh / 2, 12, 0, 360, tocolor(231, 76, 60, pulse), tocolor(231, 76, 60, pulse), 32)
        dxDrawText("!", rx + rw - 29, ry + rh / 2 - 8, 0, 0, tocolor(255, 255, 255, 255), 1.2, "default-bold")
    end

    if showReportUI then
        -- FŐ PANEL
        dxDrawRectangle(uiX, uiY, uiW, uiH, tocolor(0, 10, 20, 253))
        drawCyberBorder(uiX, uiY, uiW, uiH, mainCyan, 3)
        dxDrawRectangle(uiX, uiY, uiW, 45, tocolor(0, 195, 255, 40))
        dxDrawText("ADMIN_REPORTS // TERMINAL_v2.1", uiX + 20, uiY, 0, uiY + 45, tocolor(255, 255, 255, 220), 1.2, "default-bold", "left", "center")
        dxDrawText("[ X ]", uiX + uiW - 60, uiY, uiX + uiW, uiY + 45, tocolor(231, 76, 60, 255), 1.2, "default-bold", "center", "center")

        -- LISTA (Bal oldal)
        dxDrawRectangle(uiX + 10, uiY + 55, 200, uiH - 65, tocolor(255, 255, 255, 5))
        for i, report in ipairs(reportList) do
            local ly = uiY + 55 + (i-1) * 45
            local isSel = selectedReport == report.Reports_ID
            dxDrawRectangle(uiX + 15, ly + 5, 190, 35, isSel and tocolor(0, 195, 255, 60) or tocolor(255, 255, 255, 10))
            dxDrawText("ID: " .. report.Reports_ID .. " | " .. report.Opener, uiX + 25, ly + 5, uiX + 200, ly + 40, tocolor(255, 255, 255, 200), 0.9, "default-bold", "left", "center", true)
        end

        -- CHAT (Jobb oldal)
        dxDrawRectangle(chatX, chatY, chatW, chatH, tocolor(0, 0, 0, 150))
        for i, msg in ipairs(messages) do
            local mY = chatY + chatH - (#messages - i + 1) * 45
            if mY > chatY then
                local isSystem = msg.Message:find("ÚJ REPORT!")
                local boxColor, borderColor, rankName

                if isSystem then
                    boxColor = tocolor(226, 247, 0, 70)
                    borderColor = tocolor(226, 247, 0, 200)
                    rankName = "SYSTEM"
                elseif not msg.Messager:find("GUEST") then
                    local displayLvl = (msg.Messager == getPlayerName(localPlayer):upper()) and adminLvl or 1
                    local cfg = adminColors[displayLvl] or adminColors[1]
                    boxColor = tocolor(cfg.r, cfg.g, cfg.b, 40)
                    borderColor = tocolor(cfg.r, cfg.g, cfg.b, 255)
                    rankName = cfg.name
                else
                    boxColor = tocolor(255, 255, 255, 10)
                    borderColor = tocolor(255, 255, 255, 80)
                    rankName = "PLAYER"
                end

                dxDrawRectangle(chatX + 5, mY, chatW - 10, 40, boxColor)
                dxDrawRectangle(chatX + 5, mY, 4, 40, borderColor)
                dxDrawText("[" .. rankName .. "] " .. msg.Messager .. ": " .. msg.Message, chatX + 15, mY, chatX + chatW - 15, mY + 40, tocolor(255,255,255,255), 0.9, "default-bold", "left", "center", true)
            end
        end

        -- LEZÁRÁS GOMB
        if selectedReport then
            local bx, by, bw, bh = chatX + chatW - 140, uiY + uiH - 75, 140, 30
            dxDrawRectangle(bx, by, bw, bh, tocolor(231, 76, 60, 150))
            dxDrawText("FIX_REPORT (Close)", bx, by, bx+bw, by+bh, tocolor(255, 255, 255, 255), 1.0, "default-bold", "center", "center")
        end

        -- INPUT DX
        dxDrawRectangle(chatX, uiY + uiH - 35, chatW, 25, tocolor(255, 255, 255, 20))
        dxDrawText("> " .. guiGetText(msgInput) .. (getTickCount() % 1000 < 500 and "_" or ""), chatX + 10, uiY + uiH - 35, 0, uiY + uiH - 10, tocolor(0, 195, 255, 255), 1.0, "default-bold", "left", "center")
    end
end)

addEventHandler("onClientClick", root, function(btn, state, absX, absY)
    if btn ~= "left" or state ~= "down" then return end
    local adminLvl = getElementData(localPlayer, "admin") or 0
    if adminLvl < 1 then return end

    if not showReportUI then
        if absX >= rx and absX <= rx + rw and absY >= ry and absY <= ry + rh then
            showReportUI = true
            showCursor(true)
            toggleAllControls(false)
            guiSetVisible(msgInput, true)
            guiSetInputEnabled(true)
            triggerServerEvent("fetchActiveReports", localPlayer) 
            guiBringToFront(msgInput)
            return
        end
    end

    if showReportUI then
        -- Bezárás
        if absX >= uiX + uiW - 60 and absX <= uiX + uiW and absY >= uiY and absY <= uiY + 45 then
            showReportUI = false
            showCursor(false)
            toggleAllControls(true)
            guiSetInputEnabled(false)
            guiSetVisible(msgInput, false)
            return
        end

        -- AZONNALI ELTÜNTETÉS LEZÁRÁSKOR
        if selectedReport then
            local bx, by, bw, bh = chatX + chatW - 140, uiY + uiH - 75, 140, 30
            if absX >= bx and absX <= bx + bw and absY >= by and absY <= by + bh then
                triggerServerEvent("closeReport", localPlayer, selectedReport)
                
                -- Helyi lista frissítése azonnal
                for i, report in ipairs(reportList) do
                    if report.Reports_ID == selectedReport then
                        table.remove(reportList, i)
                        break
                    end
                end
                
                selectedReport = nil
                messages = {}
                reportCount = #reportList
                return
            end
        end

        -- Kiválasztás
        for i, report in ipairs(reportList) do
            local ly = uiY + 55 + (i-1) * 45
            if absX >= uiX + 15 and absX <= uiX + 205 and absY >= ly + 5 and absY <= ly + 40 then
                selectedReport = report.Reports_ID
                triggerServerEvent("fetchMessages", localPlayer, selectedReport)
                guiBringToFront(msgInput)
                return
            end
        end

        if absX >= chatX and absX <= chatX + chatW and absY >= uiY + uiH - 35 and absY <= uiY + uiH - 10 then
            guiBringToFront(msgInput)
        end
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    setTimer(function()
        local adminLvl = getElementData(localPlayer, "admin") or 0
        if adminLvl >= 1 then triggerServerEvent("fetchActiveReports", localPlayer) end
    end, 1000, 1)
end)

addEventHandler("onClientKey", root, function(btn, press)
    if showReportUI and press then
        if btn == "enter" then
            local txt = guiGetText(msgInput)
            if #txt > 0 and selectedReport then
                triggerServerEvent("sendReportMessage", localPlayer, selectedReport, txt)
                guiSetText(msgInput, "")
                setTimer(function() if selectedReport then triggerServerEvent("fetchMessages", localPlayer, selectedReport) end end, 200, 1)
            end
            cancelEvent()
        elseif btn == "escape" then
            showReportUI = false
            showCursor(false)
            toggleAllControls(true)
            guiSetInputEnabled(false)
            guiSetVisible(msgInput, false)
            cancelEvent()
        end
    end
end)

addEvent("updateReportCount", true)
addEventHandler("updateReportCount", root, function(c) 
    if (getElementData(localPlayer, "admin") or 0) >= 1 then reportCount = c end
end)

addEvent("receiveActiveReports", true)
addEventHandler("receiveActiveReports", root, function(data) 
    if (getElementData(localPlayer, "admin") or 0) >= 1 then
        reportList = data 
        reportCount = #data 
    end
end)

addEvent("receiveMessages", true)
addEventHandler("receiveMessages", root, function(data) messages = data end)

addEvent("receiveNewMessage", true)
addEventHandler("receiveNewMessage", root, function(id) 
    if selectedReport == id then triggerServerEvent("fetchMessages", localPlayer, id) end 
end)