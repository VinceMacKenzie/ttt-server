local screenW, screenH = guiGetScreenSize()
local hudW, hudH = 450, 180
local x = 30
local y = screenH - hudH - 30

-- Animációs változók
local lerpHP, lerpArmor, lerpMoney = 0, 0, 0
local showAnnounce = false
local announceText, announceStart = "", 0
local announceColor = {255, 255, 255}
local announceDuration = 5000

function formatNumber(amount)
    local formatted = tostring(math.floor(amount + 0.5)) 
    while true do  
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k == 0) then break end
    end
    return formatted
end

-- Segédfüggvény a Cyberpunk sarkok kirajzolásához
function drawCyberBorder(ax, ay, aw, ah, color, thickness)
    local t = thickness
    local l = 20 -- A sarkok hossza
    dxDrawLine(ax, ay, ax + l, ay, color, t)
    dxDrawLine(ax, ay, ax, ay + l, color, t)
    dxDrawLine(ax + aw, ay, ax + aw - l, ay, color, t)
    dxDrawLine(ax + aw, ay, ax + aw, ay + l, color, t)
    dxDrawLine(ax, ay + ah, ax + l, ay + ah, color, t)
    dxDrawLine(ax, ay + ah, ax, ay + ah - l, color, t)
    dxDrawLine(ax + aw, ay + ah, ax + aw - l, ay + ah, color, t)
    dxDrawLine(ax + aw, ay + ah, ax + aw, ay + ah - l, color, t)
end

function drawTTTHud()
    local player = localPlayer
    if not player then return end
    local now = getTickCount()
    
    local health = getElementHealth(player)
    local armor = getPedArmor(player)
    local money = getPlayerMoney(player)
    local ping = getPlayerPing(player)
    local role = getElementData(player, "tttRole") or "Innocent"
    local timeStr = string.format("%02d:%02d", getRealTime().hour, getRealTime().minute)

    -- Animációk
    lerpHP = lerpHP + (health - lerpHP) * 0.1
    lerpArmor = lerpArmor + (armor - lerpArmor) * 0.1
    lerpMoney = lerpMoney + (money - lerpMoney) * 0.05

    -- Színek beállítása
    local r, g, b = 46, 204, 113 -- Innocent zöld
    if role == "Traitor" then r, g, b = 231, 76, 60
    elseif role == "Detective" then r, g, b = 52, 152, 219 end
    local roleColor = tocolor(r, g, b, 255)
    local mainCyan = tocolor(0, 195, 255, 150)
    local hpFixGreen = tocolor(46, 204, 113, 200)

    -- 1. HÁTTÉR ÉS KERET
    dxDrawRectangle(x, y, hudW, hudH, tocolor(0, 15, 25, 200)) 
    drawCyberBorder(x - 2, y - 2, hudW + 4, hudH + 4, mainCyan, 3)

    -- 2. SZERKEZETI SÁVOK
    local rowH = hudH / 4
    for i = 1, 3 do
        dxDrawRectangle(x, y + (i * rowH), hudW, 1, tocolor(0, 195, 255, 40))
    end

    -- --- 1. SÁV: SZEREP ---
    dxDrawRectangle(x, y, hudW, rowH, tocolor(r, g, b, 30))
    dxDrawText(role:upper(), x, y, x + hudW, y + rowH, roleColor, 1.6, "bankgothic", "center", "center")

    -- --- 2. SÁV: HP ÉS STÁTUSZ ---
    local statusText = "OK"
    local statusColor = hpFixGreen
    if health <= 24 then statusText = "DANGER"; statusColor = tocolor(231, 76, 60, 255)
    elseif health <= 59 then statusText = "Damaged"; statusColor = tocolor(230, 126, 34, 200)
    elseif health <= 89 then statusText = "Moderate"; statusColor = tocolor(241, 196, 15, 200) end

    dxDrawText("VITAL STATUS: " .. statusText, x + 20, y + 55, 0, 0, statusColor, 0.8, "default-bold")
    dxDrawRectangle(x + 20, y + 70, 180, 15, tocolor(255, 255, 255, 10))
    dxDrawRectangle(x + 20, y + 70, (180 * (math.max(0, lerpHP) / 100)), 15, hpFixGreen)
    dxDrawLine(x + 20, y + 70, x + 200, y + 70, tocolor(46, 204, 113, 255), 1)

    -- --- 3. SÁV: ARMOR, NÉV, CREDITS ---
    local armorVal = math.floor(armor)
    dxDrawText("ARMOR: " .. armorVal .. "%", x + 20, y + 95, 0, 0, tocolor(0, 195, 255, 200), 1.1, "default-bold")
    dxDrawRectangle(x + 20, y + 112, 180, 10, tocolor(255, 255, 255, 10))
    dxDrawRectangle(x + 20, y + 112, (180 * (lerpArmor / 100)), 10, tocolor(0, 195, 255, 150))
    
    dxDrawText("ID: " .. getPlayerName(player):upper(), x + 230, y + rowH * 1 + 15, x + hudW, y + rowH * 2, tocolor(0, 195, 255, 180), 1.0, "default-bold")
    dxDrawText("CREDITS", x + 230, y + rowH * 2 + 4, 0, 0, tocolor(255, 255, 255, 80), 0.7, "default-bold")
    dxDrawText("$"..formatNumber(lerpMoney), x + 230, y + rowH * 2 + 12, 0, 0, hpFixGreen, 1.4, "default-bold")

    -- --- 4. SÁV: SYS INFO ---
    dxDrawText("SYS_TIME: "..timeStr, x + 15, y + rowH * 3, x + hudW, y + hudH, tocolor(255, 255, 255, 120), 0.9, "default-bold", "left", "center")
    dxDrawText("LATENCY: "..ping.." MS", x, y + rowH * 3, x + hudW - 15, y + hudH, (ping > 100 and tocolor(231, 76, 60, 200) or tocolor(255, 255, 255, 120)), 0.9, "default-bold", "right", "center")

    -- ANNOUNCE
    if showAnnounce then
        local elapsed = now - announceStart
        if elapsed < announceDuration then
            local alpha = (elapsed < 800) and (elapsed/800)*255 or (elapsed > 4200 and (1-(elapsed-4200)/800)*255 or 255)
            dxDrawRectangle(0, screenH * 0.4, screenW, screenH * 0.2, tocolor(0, 0, 0, alpha * 0.8))
            drawCyberBorder(screenW * 0.2, screenH * 0.4, screenW * 0.6, screenH * 0.2, tocolor(announceColor[1], announceColor[2], announceColor[3], alpha), 4)
            dxDrawText(announceText, 0, 0, screenW, screenH * 1.0, tocolor(announceColor[1], announceColor[2], announceColor[3], alpha), 4, "bankgothic", "center", "center")
        else showAnnounce = false end
    end
end
addEventHandler("onClientRender", root, drawTTTHud)

---------------------------------------------------------
-- NAMETAG RENDSZER (Javított Reveal funkcióval)
---------------------------------------------------------
local maxDistance = 18
local adminRanks = {
    [1] = {name = "Admin", r = 54, g = 168, b = 100},
    [2] = {name = "Főadmin", r = 57, g = 174, b = 247},
    [3] = {name = "Tulajdonos", r = 219, g = 89, b = 75}
}

addEventHandler("onClientRender", root, function()
    local cx, cy, cz = getCameraMatrix()
    
    -- Itt kérjük le, hogy TE (az admin) bekapcsoltad-e a látmódot
    local adminVision = getElementData(localPlayer, "adminVision") == true

    local elements = getElementsByType("player", root, true)
    local peds = getElementsByType("ped", root, true)
    for i, v in ipairs(peds) do table.insert(elements, v) end

    for _, target in ipairs(elements) do
        if target ~= localPlayer then
            local tx, ty, tz = getElementPosition(target)
            local dist = getDistanceBetweenPoints3D(cx, cy, cz, tx, ty, tz)

            if dist < maxDistance then
                if isLineOfSightClear(cx, cy, cz, tx, ty, tz, true, false, false, true, false, false, false, target) then
                    local sx, sy = getScreenFromWorldPosition(tx, ty, tz + 1.1)
                    if sx and sy then
                        local scale = 1 - (dist / maxDistance)
                        local fontSize = 2 * scale
                        local alpha = 255 * scale
                        local name = getElementData(target, "npcName") or getPlayerName(target)
                        local adminLvl = getElementData(target, "adminLevel") or 0
                        
                        -- HA AZ ADMIN LÁTMÓD BE VAN KAPCSOLVA (MINDENKI SZEREPÉT LÁTOD)
                        if adminVision then
                            local role = getElementData(target, "tttRole") or "Innocent"
                            local rr, rg, rb = 46, 204, 113
                            if role == "Traitor" then rr, rg, rb = 231, 76, 60
                            elseif role == "Detective" then rr, rg, rb = 52, 152, 219 end
                            
                            local rText = "["..role:upper().."]"
                            local rOff = 35 * scale
                            
                            dxDrawText(rText, sx + 1, sy - rOff + 1, sx + 1, sy - rOff + 1, tocolor(0, 0, 0, alpha), fontSize * 0.75, "default-bold", "center", "center")
                            dxDrawText(rText, sx, sy - rOff, sx, sy - rOff, tocolor(rr, rg, rb, alpha), fontSize * 0.75, "default-bold", "center", "center")
                        end

                        -- RANG ÉS NÉV
                        if adminRanks[adminLvl] then
                            local rD = adminRanks[adminLvl]
                            local rT = "[" .. rD.name .. "]"
                            local sW = dxGetTextWidth(" ", fontSize, "default-bold")
                            local rW = dxGetTextWidth(rT, fontSize, "default-bold")
                            local nW = dxGetTextWidth(name, fontSize, "default-bold")
                            local fW = rW + sW + nW
                            local sX = sx - (fW / 2) - 2 

                            -- Rang
                            dxDrawText(rT, sX + 1, sy + 1, sX + rW + 1, sy + 1, tocolor(0, 0, 0, alpha), fontSize, "default-bold", "left", "center")
                            dxDrawText(rT, sX, sy, sX + rW, sy, tocolor(rD.r, rD.g, rD.b, alpha), fontSize, "default-bold", "left", "center")
                            -- Név
                            local nX = sX + rW + sW
                            dxDrawText(name, nX + 1, sy + 1, nX + nW + 1, sy + 1, tocolor(0, 0, 0, alpha), fontSize, "default-bold", "left", "center")
                            dxDrawText(name, nX, sy, nX + nW, sy, tocolor(255, 255, 255, alpha), fontSize, "default-bold", "left", "center")
                        else
                            -- Név rang nélkül
                            dxDrawText(name, sx + 1, sy + 1, sx + 1, sy + 1, tocolor(0, 0, 0, alpha), fontSize, "default-bold", "center", "center")
                            dxDrawText(name, sx, sy, sx, sy, tocolor(255, 255, 255, alpha), fontSize, "default-bold", "center", "center")
                        end
                    end
                end
            end
        end
    end
end)

addEventHandler("onClientElementDataChange", localPlayer, function(dataName)
    if dataName == "tttRole" then
        local val = getElementData(localPlayer, "tttRole")
        if val then
            announceText = val:upper()
            announceStart, showAnnounce = getTickCount(), true
            if val == "Traitor" then announceColor = {231, 76, 60}
            elseif val == "Detective" then announceColor = {52, 152, 219}
            else announceColor = {46, 204, 113} end
        end
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    setPlayerHudComponentVisible("all", false)    -- Életerő
    setPlayerHudComponentVisible("crosshair", true)    -- Életerő
end)

bindKey("m", "down", function()
    local currentState = showCursor(not isCursorShowing()) -- Megfordítja az aktuális állapotot
end)