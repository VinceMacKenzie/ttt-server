local screenW, screenH = guiGetScreenSize()
local isShopVisible = false
local currentTab = "SHOP" 

-- HUD konfiguráció
local shopW, shopH = 400, 520 
local sx = (screenW - shopW) / 2
local sy = (screenH - shopH) / 2

local selectedIdx = 1
local scrollOffset = 0 
local maxVisibleItems = 7 

local traitorRed = tocolor(231, 76, 60, 255)
local detectiveBlue = tocolor(52, 152, 219, 255)

-- TÁRGYAK LISTÁJA [Név] [Pénz] [ID] [Lőszer] [Roleoknak]
local allItems = {
    {"AK-47", 1000, 30, 90, "A"}, -- EZT MAJD CSAK T-NEK LESZ
    {"Silenced Pistol", 1500, 23, 17, "T"},
    {"Desert Eagle", 2500, 24, 5, "T"},
    {"Sniper Rifle", 5000, 34, 1, "A"},
    {"Armor (Kevlar)", 2000, "armor", 100, "A"},
    {"M4 Carbine", 4500, 31, 50, "D"},
    {"Combat Shotgun", 3500, 27, 14, "D"},
    {"Grenade", 1000, 16, 1, "A"},
    {"C4 Explosive", 8000, 39, 1, "T"},
    {"Medkit", 1500, "medkit", 100, "D"},
}

-- SKILLEK LISTÁJA
local skillList = {
    {"Silenced Pistol Skill", 0, "skill_silenced", 1000}, 
    {"Stamina Upgrade", 1000, "skill_stamina", 500},
    {"M4 Skill", 1000, "skill_m4", 1000},
    {"Health Boost", 3000, "skill_hp", 150},
    {"Stealth Walk", 2000, "skill_stealth", 1},
    {"AK-47 Skill", 5000, "skill_ak-47", 1000},
}

local currentVisibleItems = {}

function isMouseInPosition(x, y, width, height)
    if not isCursorShowing() then return false end
    local cx, cy = getCursorPosition()
    cx, cy = cx * screenW, cy * screenH
    return (cx >= x and cx <= x + width) and (cy >= y and cy <= y + height)
end

function drawShopBorder(ax, ay, aw, ah, color, thickness)
    local t, l = thickness, 30
    dxDrawLine(ax, ay, ax + l, ay, color, t)
    dxDrawLine(ax, ay, ax, ay + l, color, t)
    dxDrawLine(ax + aw, ay, ax + aw - l, ay, color, t)
    dxDrawLine(ax + aw, ay, ax + aw, ay + l, color, t)
    dxDrawLine(ax, ay + ah, ax + l, ay + ah, color, t)
    dxDrawLine(ax, ay + ah, ax, ay + ah - l, color, t)
    dxDrawLine(ax + aw, ay + ah, ax + aw - l, ay + ah, color, t)
    dxDrawLine(ax + aw, ay + ah, ax + aw, ay + ah - l, color, t)
end

function drawUniversalShop()
    if not isShopVisible then return end
    
    local role = getElementData(localPlayer, "tttRole")
    local themeColor = (role == "Traitor") and traitorRed or detectiveBlue
    local title = (role == "Traitor") and "TRAITOR BLACK MARKET" or "ARMORY"

    dxDrawRectangle(sx, sy, shopW, shopH, tocolor(0, 15, 25, 240))
    drawShopBorder(sx - 2, sy - 2, shopW + 4, shopH + 4, themeColor, 3)
    
    -- TABS SORREND CSERÉLVE: SHOP, SKILLEK, SKINEK
    local tabs = {"SHOP", "SKILLEK", "SKINEK"}
    local tabW = shopW / #tabs
    for i, tabName in ipairs(tabs) do
        local tx = sx + (i-1) * tabW
        local isActive = (currentTab == tabName)
        
        -- Itt adjuk vissza a színes hátteret az aktív fülnek
        if isActive then
            dxDrawRectangle(tx, sy - 30, tabW, 30, themeColor) -- Ez a rang színe (Piros vagy Kék)
            dxDrawRectangle(sx + 5, sy + 5, shopW - 10, 45, themeColor - tocolor(0, 0, 0, 200))
        else
            dxDrawRectangle(tx, sy - 30, tabW, 30, tocolor(0, 0, 0, 200)) -- Inaktív fül
        end
        
        dxDrawText(tabName, tx, sy - 30, tx + tabW, sy, tocolor(255,255,255), 1, "default-bold", "center", "center")
    end

    dxDrawText(title, sx, sy + 10, sx + shopW, sy + 40, themeColor, (role == "Traitor" and 0.85 or 1.4), "bankgothic", "center", "center")
    
    -- Csak SHOP és SKILLEK listát rajzolunk ide, a SKINEK átirányít
    local listToDraw = (currentTab == "SHOP") and currentVisibleItems or (currentTab == "SKILLEK" and skillList or {})
    
    if currentTab == "SHOP" or currentTab == "SKILLEK" then
        local drawCount = 0
        for i = 1 + scrollOffset, #listToDraw do
            drawCount = drawCount + 1
            if drawCount > maxVisibleItems then break end
            
            local item = listToDraw[i]
            local itemY = sy + 60 + ((drawCount - 1) * 60)
            local isHovered = isMouseInPosition(sx + 10, itemY, shopW - 20, 55)
            
            if isHovered then selectedIdx = i end
            local isSelected = (selectedIdx == i)
            
            dxDrawRectangle(sx + 10, itemY, shopW - 20, 55, isSelected and (themeColor - tocolor(0,0,0,200)) or tocolor(255, 255, 255, 5))
            if isSelected then dxDrawRectangle(sx + 10, itemY, 4, 55, themeColor) end
            
            dxDrawText(item[1]:upper(), sx + 30, itemY, 0, itemY + 55, tocolor(255, 255, 255, 220), 1.1, "default-bold", "left", "center")
            local priceTxt = (currentTab == "SKILLEK" and item[2] == 0) and "INGYENES" or "$" .. item[2]
            dxDrawText(priceTxt, sx, itemY, sx + shopW - 30, itemY + 55, (isSelected and themeColor or tocolor(255, 255, 255, 120)), 1.2, "default-bold", "right", "center")
        end

        if #listToDraw > maxVisibleItems then
            local scrollHeight = maxVisibleItems * 60 - 5
            local barHeight = (maxVisibleItems / #listToDraw) * scrollHeight
            local barY = sy + 60 + (scrollOffset / #listToDraw) * scrollHeight
            dxDrawRectangle(sx + shopW - 8, sy + 60, 4, scrollHeight, tocolor(255, 255, 255, 20))
            dxDrawRectangle(sx + shopW - 8, barY, 4, barHeight, themeColor)
        end
    end
    
    local money = getPlayerMoney(localPlayer)
    dxDrawRectangle(sx, sy + shopH - 45, shopW, 45, tocolor(0, 0, 0, 150))
    dxDrawText("EGYENLEG: $" .. money, sx + 20, sy + shopH - 45, sx + shopW, sy + shopH, tocolor(46, 204, 113, 200), 1.0, "default-bold", "left", "center")
    dxDrawText("F3: BEZÁRÁS", sx, sy + shopH - 45, sx + shopW - 20, sy + shopH, tocolor(255, 255, 255, 100), 0.8, "default-bold", "right", "center")
end
addEventHandler("onClientRender", root, drawUniversalShop)

function handleShopInput(button, press)
    if not isShopVisible or not press then return end
    
    local listToDraw = (currentTab == "SHOP") and currentVisibleItems or (currentTab == "SKILLEK" and skillList or {})
    local maxItems = #listToDraw

    if button == "mouse_wheel_up" then
        if scrollOffset > 0 then scrollOffset = scrollOffset - 1 end
    elseif button == "mouse_wheel_down" then
        if scrollOffset < maxItems - maxVisibleItems then scrollOffset = scrollOffset + 1 end
    end

    if button == "mouse1" then
        local tabW = shopW / 3
        -- SHOP TAB
        if isMouseInPosition(sx, sy - 30, tabW, 30) then 
            currentTab = "SHOP" 
            selectedIdx = 1 
            scrollOffset = 0 
            return 
        end
        -- SKILLEK TAB (Most a középső)
        if isMouseInPosition(sx + tabW, sy - 30, tabW, 30) then 
            currentTab = "SKILLEK" 
            selectedIdx = 1 
            scrollOffset = 0 
            return 
        end
        -- SKINEK TAB (Most a szélső) -> Átirányítás a másik scriptre
        if isMouseInPosition(sx + tabW*2, sy - 30, tabW, 30) then 
            toggleShop() -- F3 bezárása
            -- Az export hívása (ellenőrizzük, hogy a resource fut-e)
            if getResourceFromName("ttt-skin") and getResourceState(getResourceFromName("ttt-skin")) == "running" then
                exports["ttt-skin"]:toggleSkinShop()
            else
                outputChatBox("#d9534f[Hiba] #ffffffA Skin Shop jelenleg nem elérhető!", 255, 255, 255, true)
            end
            return 
        end
    end

    -- Navigáció és vásárlás kezelése csak a két aktív fülön
    if currentTab ~= "SKINEK" then
        if button == "arrow_up" then
            selectedIdx = (selectedIdx <= 1) and maxItems or selectedIdx - 1
            if selectedIdx <= scrollOffset then scrollOffset = selectedIdx - 1 end
        elseif button == "arrow_down" then
            selectedIdx = (selectedIdx >= maxItems) and 1 or selectedIdx + 1
            if selectedIdx > scrollOffset + maxVisibleItems then scrollOffset = selectedIdx - maxVisibleItems end
            if selectedIdx == 1 then scrollOffset = 0 end
        elseif button == "enter" or button == "num_enter" or button == "mouse1" then
            local drawPos = selectedIdx - scrollOffset
            if drawPos >= 1 and drawPos <= maxVisibleItems then
                local itemY = sy + 60 + ((drawPos - 1) * 60)
                if button ~= "mouse1" or isMouseInPosition(sx + 10, itemY, shopW - 20, 55) then
                    if currentTab == "SHOP" then
                        local data = listToDraw[selectedIdx]
                        if data then
                            triggerServerEvent("ttt:buyItem", localPlayer, data[1], tonumber(data[2]), data[3], tonumber(data[4]))
                        end
                    elseif currentTab == "SKILLEK" then
                        local skill = listToDraw[selectedIdx]
                        if skill then
                            triggerServerEvent("ttt:logSkillUpgrade", localPlayer, skill[1], skill[4], skill[2])
                        end
                    end
                end
            end
        end
    end
end
addEventHandler("onClientKey", root, handleShopInput)

function toggleShop()
    local role = getElementData(localPlayer, "tttRole")
    if role ~= "Traitor" and role ~= "Detective" or isPedDead(localPlayer) then return end

    isShopVisible = not isShopVisible
    if isShopVisible then
        currentVisibleItems = {}
        local myInitial = (role == "Traitor") and "T" or "D"
        for _, item in ipairs(allItems) do
            if item[5] == "A" or item[5] == myInitial then table.insert(currentVisibleItems, item) end
        end
        selectedIdx = 1
        scrollOffset = 0
        currentTab = "SHOP"
    end
    showCursor(isShopVisible)
end
bindKey("f3", "down", toggleShop)