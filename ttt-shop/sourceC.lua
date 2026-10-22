local screenW, screenH = guiGetScreenSize()
local isShopVisible = false
local currentTab = "SHOP"

local shopW, shopH = 470, 520
local sx, sy = (screenW - shopW) / 2, (screenH - shopH) / 2

local selectedIdx = 1
local scrollOffset = 0
local maxVisibleItems = 7

local traitorRed = tocolor(231, 76, 60, 255)
local detectiveBlue = tocolor(52, 152, 219, 255)
local tabs = {"SHOP", "SKILLEK", "EFFEKTEK", "FEGYVERSKIN", "SKINEK"}

-- Effektek (aurák): a listát és a tulajdonlást a ttt-skin adja, itt csak cache-eljük
local effectItems = {}
local function refreshEffects()
    effectItems = {}
    local res = getResourceFromName("ttt-skin")
    if not res or getResourceState(res) ~= "running" then return end
    local ok, list = pcall(function() return exports["ttt-skin"]:getEffectShopList() end)
    if not ok or type(list) ~= "table" then return end
    for i, e in ipairs(list) do
        effectItems[i] = {name = e.name, price = e.price, index = i, key = e.key, owned = e.owned, active = e.active, desc = e.desc}
    end
end
addEvent("ttt:onEffectsChanged", false)
addEventHandler("ttt:onEffectsChanged", root, refreshEffects)

-- Fegyverskinek: a listát és a tulajdonlást a ttt-weaponskin adja, fegyverenként lapozva
local wskinWeapons, wskinWeaponIdx, wskinItems = {}, 1, {}
local function refreshWeaponSkins()
    wskinItems = {}
    local res = getResourceFromName("ttt-weaponskin")
    if not res or getResourceState(res) ~= "running" then wskinWeapons = {} return end
    local ok, weapons = pcall(function() return exports["ttt-weaponskin"]:getWeaponSkinWeaponList() end)
    if not ok or type(weapons) ~= "table" then return end
    wskinWeapons = weapons
    if wskinWeaponIdx > #wskinWeapons then wskinWeaponIdx = 1 end
    local w = wskinWeapons[wskinWeaponIdx]
    if not w then return end
    local ok2, list = pcall(function() return exports["ttt-weaponskin"]:getWeaponSkinShopList(w.id) end)
    if not ok2 or type(list) ~= "table" then return end
    for i, e in ipairs(list) do
        wskinItems[i] = {name = e.name, price = e.price, index = i, key = e.key, weaponID = w.id, owned = e.owned, active = e.active,
            desc = e.catLabel .. " • " .. (e.desc or ""), available = e.available, lockedText = "SZEZONON KÍVÜL"}
    end
end
addEvent("ttt:onWeaponSkinsChanged", false)
addEventHandler("ttt:onWeaponSkinsChanged", root, function() if currentTab == "FEGYVERSKIN" then refreshWeaponSkins() end end)

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
    elseif currentTab == "EFFEKTEK" then
        return effectItems
    elseif currentTab == "FEGYVERSKIN" then
        return wskinItems
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
        dxDrawText(tabName, tx, sy - 30, tx + tabW, sy, tocolor(255, 255, 255), 0.95, "default-bold", "center", "center")
    end

    if currentTab == "FEGYVERSKIN" then
        -- fegyver választó: ◄ / ► (bal/jobb nyíl vagy kattintás)
        local w = wskinWeapons[wskinWeaponIdx]
        dxDrawText("◄", sx + 15, sy + 5, sx + 55, sy + 50, isMouseInPosition(sx + 5, sy + 5, 50, 45) and themeColor or tocolor(255, 255, 255), 1.6, "default-bold", "center", "center")
        dxDrawText("►", sx + shopW - 55, sy + 5, sx + shopW - 15, sy + 50, isMouseInPosition(sx + shopW - 55, sy + 5, 50, 45) and themeColor or tocolor(255, 255, 255), 1.6, "default-bold", "center", "center")
        dxDrawText(w and w.name:upper() or "NEM ELÉRHETŐ", sx + 55, sy + 5, sx + shopW - 55, sy + 50, tocolor(255, 255, 255), 1.4, "default-bold", "center", "center")
    else
        dxDrawText(isTraitor and "TRAITOR BLACK MARKET" or "ARMORY", sx, sy + 10, sx + shopW, sy + 40, themeColor, isTraitor and 0.85 or 1.4, "bankgothic", "center", "center")
    end

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
        if entry.desc then
            dxDrawText(entry.name, sx + 30, itemY + 4, sx + shopW - 110, itemY + 30, nameColor, 1.1, "default-bold", "left", "center", true)
            dxDrawText(entry.desc, sx + 30, itemY + 28, sx + shopW - 30, itemY + 52, tocolor(255, 255, 255, 120), 0.85, "default", "left", "center", true)
        else
            dxDrawText(entry.name:upper(), sx + 30, itemY, 0, itemY + 55, nameColor, 1.1, "default-bold", "left", "center")
        end

        local priceTxt
        if entry.owned then priceTxt = entry.active and "AKTÍV" or "MEGVAN"
        elseif entry.available == false then priceTxt = entry.lockedText or "HAMAROSAN"
        elseif entry.price == 0 then priceTxt = "INGYENES"
        else priceTxt = "$" .. entry.price end
        dxDrawText(priceTxt, sx, itemY + (entry.desc and -10 or 0), sx + shopW - 30, itemY + 55 + (entry.desc and -10 or 0), isSelected and themeColor or tocolor(255, 255, 255, 120), 1.2, "default-bold", "right", "center")
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
    elseif currentTab == "EFFEKTEK" then
        if entry.owned then
            outputChatBox("#f1c40f[Effekt] #ffffffEz már a tiéd! Felvenni az #00c3ffF4 #ffffffskin menü #00c3ff[3] #fffffffülén tudod.", 255, 255, 255, true)
        else
            triggerServerEvent("ttt:buyEffect", localPlayer, entry.key)
        end
    elseif currentTab == "FEGYVERSKIN" then
        if entry.owned then
            outputChatBox("#f1c40f[Fegyverskin] #ffffffEz már a tiéd! Felvenni az #00c3ffF4 #ffffffskin menü #00c3ff[4] #fffffffülén tudod.", 255, 255, 255, true)
        elseif entry.available == false then
            outputChatBox("#f1c40f[Fegyverskin] #ffffffEz a skin most nem vásárolható, csak a saját szezonjában!", 255, 255, 255, true)
        else
            triggerServerEvent("ttt:buyWeaponSkin", localPlayer, entry.weaponID, entry.key)
        end
    end
end

local function switchTab(tabName)
    currentTab, selectedIdx, scrollOffset = tabName, 1, 0
    if tabName == "EFFEKTEK" then refreshEffects() end
    if tabName == "FEGYVERSKIN" then refreshWeaponSkins() end
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

    -- Fegyverskin fül: fegyver lapozása
    if currentTab == "FEGYVERSKIN" and #wskinWeapons > 0 then
        local dir
        if button == "arrow_l" then dir = -1 elseif button == "arrow_r" then dir = 1
        elseif button == "mouse1" and isMouseInPosition(sx + 5, sy + 5, 50, 45) then dir = -1
        elseif button == "mouse1" and isMouseInPosition(sx + shopW - 55, sy + 5, 50, 45) then dir = 1 end
        if dir then
            wskinWeaponIdx = ((wskinWeaponIdx - 1 + dir) % #wskinWeapons) + 1
            selectedIdx, scrollOffset = 1, 0
            refreshWeaponSkins()
            return
        end
    end

    if button == "mouse1" then
        local tabW = shopW / #tabs
        for i, tabName in ipairs(tabs) do
            if tabName ~= "SKINEK" and isMouseInPosition(sx + tabW * (i - 1), sy - 30, tabW, 30) then return switchTab(tabName) end
        end
        if isMouseInPosition(sx + tabW * (#tabs - 1), sy - 30, tabW, 30) then
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