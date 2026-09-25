local screenW, screenH = guiGetScreenSize()
local isShopVisible = false
local currentTab = "SHOP"

local shopW, shopH = 400, 520
local sx, sy = (screenW - shopW) / 2, (screenH - shopH) / 2

local selectedIdx = 1
local scrollOffset = 0
local maxVisibleItems = 7

local traitorRed = tocolor(231, 76, 60, 255)
local detectiveBlue = tocolor(52, 152, 219, 255)
local tabs = {"SHOP", "SKILLEK", "SKINEK"}

-- Aktuálisan látható tárgyak: {item = ShopItems[i], index = i}
local currentVisibleItems = {}

local function isMouseInPosition(x, y, width, height)
    if not isCursorShowing() then return false end
    local cx, cy = getCursorPosition()
    cx, cy = cx * screenW, cy * screenH
    return cx >= x and cx <= x + width and cy >= y and cy <= y + height
end

local function drawShopBorder(ax, ay, aw, ah, color, t)
    local l = 30
    dxDrawLine(ax, ay, ax + l, ay, color, t)
    dxDrawLine(ax, ay, ax, ay + l, color, t)
    dxDrawLine(ax + aw, ay, ax + aw - l, ay, color, t)
    dxDrawLine(ax + aw, ay, ax + aw, ay + l, color, t)
    dxDrawLine(ax, ay + ah, ax + l, ay + ah, color, t)
    dxDrawLine(ax, ay + ah, ax, ay + ah - l, color, t)
    dxDrawLine(ax + aw, ay + ah, ax + aw - l, ay + ah, color, t)
    dxDrawLine(ax + aw, ay + ah, ax + aw, ay + ah - l, color, t)
end

-- Az aktív fül listája: minden elem {name, price, index}
local function getCurrentList()
    if currentTab == "SHOP" then
        return currentVisibleItems
    elseif currentTab == "SKILLEK" then
        local list = {}
        for i, s in ipairs(ShopSkills) do list[i] = {name = s[1], price = s[2], index = i, available = s[4] ~= nil} end
        return list
    end
    return {}
end

local function drawUniversalShop()
    if not isShopVisible then return end

    local role = getElementData(localPlayer, "tttRole")
    local isTraitor = (role == "Traitor")
    local themeColor = isTraitor and traitorRed or detectiveBlue
    local themeFaint = themeColor - tocolor(0, 0, 0, 200)

    dxDrawRectangle(sx, sy, shopW, shopH, tocolor(0, 15, 25, 240))
    drawShopBorder(sx - 2, sy - 2, shopW + 4, shopH + 4, themeColor, 3)

    -- Fülek
    local tabW = shopW / #tabs
    for i, tabName in ipairs(tabs) do
        local tx = sx + (i - 1) * tabW
        if currentTab == tabName then
            dxDrawRectangle(tx, sy - 30, tabW, 30, themeColor)
            dxDrawRectangle(sx + 5, sy + 5, shopW - 10, 45, themeFaint)
        else
            dxDrawRectangle(tx, sy - 30, tabW, 30, tocolor(0, 0, 0, 200))
        end
        dxDrawText(tabName, tx, sy - 30, tx + tabW, sy, tocolor(255, 255, 255), 1, "default-bold", "center", "center")
    end

    dxDrawText(isTraitor and "TRAITOR BLACK MARKET" or "ARMORY", sx, sy + 10, sx + shopW, sy + 40, themeColor, isTraitor and 0.85 or 1.4, "bankgothic", "center", "center")

    -- Lista
    local list = getCurrentList()
    local drawCount = 0
    for i = 1 + scrollOffset, #list do
        drawCount = drawCount + 1
        if drawCount > maxVisibleItems then break end

        local entry = list[i]
        local itemY = sy + 60 + (drawCount - 1) * 60
        if isMouseInPosition(sx + 10, itemY, shopW - 20, 55) then selectedIdx = i end
        local isSelected = (selectedIdx == i)

        dxDrawRectangle(sx + 10, itemY, shopW - 20, 55, isSelected and themeFaint or tocolor(255, 255, 255, 5))
        if isSelected then dxDrawRectangle(sx + 10, itemY, 4, 55, themeColor) end

        local nameColor = (entry.available == false) and tocolor(150, 150, 150, 180) or tocolor(255, 255, 255, 220)
        dxDrawText(entry.name:upper(), sx + 30, itemY, 0, itemY + 55, nameColor, 1.1, "default-bold", "left", "center")

        local priceTxt
        if entry.available == false then priceTxt = "HAMAROSAN"
        elseif entry.price == 0 then priceTxt = "INGYENES"
        else priceTxt = "$" .. entry.price end
        dxDrawText(priceTxt, sx, itemY, sx + shopW - 30, itemY + 55, isSelected and themeColor or tocolor(255, 255, 255, 120), 1.2, "default-bold", "right", "center")
    end

    -- Görgetősáv
    if #list > maxVisibleItems then
        local scrollHeight = maxVisibleItems * 60 - 5
        local barHeight = (maxVisibleItems / #list) * scrollHeight
        local barY = sy + 60 + (scrollOffset / #list) * scrollHeight
        dxDrawRectangle(sx + shopW - 8, sy + 60, 4, scrollHeight, tocolor(255, 255, 255, 20))
        dxDrawRectangle(sx + shopW - 8, barY, 4, barHeight, themeColor)
    end

    -- Lábléc
    dxDrawRectangle(sx, sy + shopH - 45, shopW, 45, tocolor(0, 0, 0, 150))
    dxDrawText("EGYENLEG: $" .. getPlayerMoney(localPlayer), sx + 20, sy + shopH - 45, sx + shopW, sy + shopH, tocolor(46, 204, 113, 200), 1.0, "default-bold", "left", "center")
    dxDrawText("F3: BEZÁRÁS", sx, sy + shopH - 45, sx + shopW - 20, sy + shopH, tocolor(255, 255, 255, 100), 0.8, "default-bold", "right", "center")
end

local function buySelected(list)
    local entry = list[selectedIdx]
    if not entry then return end
    if currentTab == "SHOP" then
        triggerServerEvent("ttt:buyItem", localPlayer, entry.index)
    elseif currentTab == "SKILLEK" then
        triggerServerEvent("ttt:buySkill", localPlayer, entry.index)
    end
end

local function switchTab(tabName)
    currentTab, selectedIdx, scrollOffset = tabName, 1, 0
end

local function handleShopInput(button, press)
    if not isShopVisible or not press then return end

    local list = getCurrentList()
    local maxItems = #list

    if button == "mouse_wheel_up" then
        if scrollOffset > 0 then scrollOffset = scrollOffset - 1 end
        return
    elseif button == "mouse_wheel_down" then
        if scrollOffset < maxItems - maxVisibleItems then scrollOffset = scrollOffset + 1 end
        return
    end

    if button == "mouse1" then
        local tabW = shopW / #tabs
        if isMouseInPosition(sx, sy - 30, tabW, 30) then return switchTab("SHOP") end
        if isMouseInPosition(sx + tabW, sy - 30, tabW, 30) then return switchTab("SKILLEK") end
        if isMouseInPosition(sx + tabW * 2, sy - 30, tabW, 30) then
            toggleShop()
            local skinRes = getResourceFromName("ttt-skin")
            if skinRes and getResourceState(skinRes) == "running" then
                exports["ttt-skin"]:toggleSkinShop()
            else
                outputChatBox("#d9534f[Hiba] #ffffffA Skin Shop jelenleg nem elérhető!", 255, 255, 255, true)
            end
            return
        end
    end

    if button == "arrow_up" then
        selectedIdx = (selectedIdx <= 1) and maxItems or selectedIdx - 1
        if selectedIdx <= scrollOffset then scrollOffset = selectedIdx - 1 end
        if selectedIdx == maxItems then scrollOffset = math.max(0, maxItems - maxVisibleItems) end
    elseif button == "arrow_down" then
        selectedIdx = (selectedIdx >= maxItems) and 1 or selectedIdx + 1
        if selectedIdx > scrollOffset + maxVisibleItems then scrollOffset = selectedIdx - maxVisibleItems end
        if selectedIdx == 1 then scrollOffset = 0 end
    elseif button == "enter" or button == "num_enter" then
        buySelected(list)
    elseif button == "mouse1" then
        local drawPos = selectedIdx - scrollOffset
        if drawPos >= 1 and drawPos <= maxVisibleItems then
            local itemY = sy + 60 + (drawPos - 1) * 60
            if isMouseInPosition(sx + 10, itemY, shopW - 20, 55) then buySelected(list) end
        end
    end
end
addEventHandler("onClientKey", root, handleShopInput)

local function closeShop()
    if isShopVisible then
        removeEventHandler("onClientRender", root, drawUniversalShop)
        isShopVisible = false
        showCursor(false)
    end
end

function toggleShop()
    local role = getElementData(localPlayer, "tttRole")
    if (role ~= "Traitor" and role ~= "Detective") or isPedDead(localPlayer) then
        return closeShop()
    end

    isShopVisible = not isShopVisible
    if isShopVisible then
        currentVisibleItems = {}
        for i, item in ipairs(ShopItems) do
            if isShopItemForRole(item, role) then
                table.insert(currentVisibleItems, {name = item[1], price = item[2], index = i})
            end
        end
        switchTab("SHOP")
        addEventHandler("onClientRender", root, drawUniversalShop)
    else
        removeEventHandler("onClientRender", root, drawUniversalShop)
    end
    showCursor(isShopVisible)
end
bindKey("f3", "down", toggleShop)

-- Ha a kör véget ér (szerep törlődik) vagy meghalunk, zárjuk be a boltot
addEventHandler("onClientElementDataChange", localPlayer, function(dataName)
    if dataName == "tttRole" and not getElementData(localPlayer, "tttRole") then closeShop() end
end)
addEventHandler("onClientPlayerWasted", localPlayer, closeShop)
