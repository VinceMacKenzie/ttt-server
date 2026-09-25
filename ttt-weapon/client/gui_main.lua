local screenW, screenH = guiGetScreenSize()
local isInventoryOpen = false
local uiW, uiH = 800, 600
local uiX, uiY = (screenW - uiW) / 2, (screenH - uiH) / 2

local playerWeapons = {}
local selectedWeapon = nil
local draggingWeapon = nil
local draggingItem = nil  -- éppen húzott fejlesztő item

-- Elrendezés
local slotSize, padding = 85, 10
local startX, startY = uiX + 25, uiY + 60
local bottomY = uiY + uiH - 120
local infoX, infoW = uiX + 510, 265
local itemPanelX, itemW = uiX - 210, 200

-- Fejlesztő itemek (a szerver az inventory táblából küldi a darabszámot)
local playerItems = { opt_adder = 0, opt_changer = 0, curse_remover = 0 }
local upgItems = {
    {key = "opt_adder",     name = "Új Optoló",   icon = "icons/opt_adder.png"},
    {key = "opt_changer",   name = "Opt Cserélő", icon = "icons/opt_changer.png"},
    {key = "curse_remover", name = "Átoktörő",    icon = "icons/curse_remover.png"},
}

-- Slot korlátozások (melyik fegyver hova mehet)
local slotRestrictions = {
    [1] = {30, 31},       -- AK-47, M4
    [2] = {28, 29, 32},   -- Uzi, MP5, Tec9
    [3] = {22, 23, 24},   -- Colt, Silenced, Deagle
    [4] = {33, 34},       -- Rifle, Sniper
    [5] = {100},          -- Armor (példa ID)
}

local weaponNames = {
    [0] = "Ököl", [22] = "Colt 45", [23] = "Silenced Colt", [24] = "Desert Eagle",
    [25] = "Sörétes puska", [28] = "Uzi", [29] = "MP5", [30] = "AK-47",
    [31] = "M4", [32] = "Tec-9", [33] = "Rifle", [34] = "Sniper", [100] = "Kevlár Mellény",
}

local allStats = {
    {key = "mod_head_dmg",      label = "Headshot sebzés",  color = {124, 197, 118}},
    {key = "mod_body_dmg",      label = "Testi sebzés",     color = {200, 200, 200}},
    {key = "mod_arm_dmg",       label = "Kar sebzés",       color = {200, 200, 200}},
    {key = "mod_leg_dmg",       label = "Láb sebzés",       color = {200, 200, 200}},
    {key = "buff_fire",         label = "Tűzsebzés esély",  color = {255, 100, 0}},
    {key = "buff_stun",         label = "Kábítás esély",    color = {0, 200, 255}},
    {key = "buff_poison",       label = "Mérgezés esély",   color = {150, 255, 0}},
    {key = "buff_life_drain",   label = "Életszívás esély", color = {255, 50, 50}},
    {key = "reload_speed_mod",  label = "Gyorstöltés",      color = {255, 200, 0}},
    {key = "ammo_capacity_mod", label = "Tárkapacitás",     color = {200, 200, 200}},
}

-- fileExists cache (ne ellenőrizzünk fájlt minden képkockán)
local iconCache = {}
local function getIconPath(modelID)
    local cached = iconCache[modelID]
    if cached ~= nil then return cached or nil end
    local path = "icons/" .. tostring(modelID) .. ".png"
    if not fileExists(path) then path = fileExists("icons/error.png") and "icons/error.png" or false end
    iconCache[modelID] = path
    return path or nil
end
local function iconExists(path)
    if iconCache[path] == nil then iconCache[path] = fileExists(path) end
    return iconCache[path]
end

function canWeaponGoToSlot(model, slotID)
    if slotID == 0 then return true end
    if not slotRestrictions[slotID] then return false end
    for _, allowedID in ipairs(slotRestrictions[slotID]) do
        if allowedID == model then return true end
    end
    return false
end

function getWeaponNameFromID(id)
    return weaponNames[id] or "Tárgy #" .. tostring(id)
end

local function getInventoryWeapons()
    local list = {}
    for _, wp in ipairs(playerWeapons) do
        if tonumber(wp.slot_type) == 0 then table.insert(list, wp) end
    end
    return list
end

local function getWeaponInSlot(slot)
    for _, wp in ipairs(playerWeapons) do
        if tonumber(wp.slot_type) == slot then return wp end
    end
end

local function inRect(cx, cy, x, y, w, h)
    return cx >= x and cx <= x + w and cy >= y and cy <= y + h
end

local function drawWeaponIcon(modelID, x, y, size, alpha)
    local path = getIconPath(modelID)
    if path then
        dxDrawImage(x + 5, y + 5, size - 10, size - 10, path, 0, 0, 0, tocolor(255, 255, 255, alpha))
    end
end

function drawWeaponUI()
    -- FEJLESZTŐK PANEL (bal)
    dxDrawRectangle(itemPanelX, uiY, itemW, 250, tocolor(15, 15, 15, 230))
    dxDrawRectangle(itemPanelX, uiY, itemW, 30, tocolor(0, 150, 255, 150))
    dxDrawText("FEJLESZTŐK", itemPanelX, uiY, itemPanelX + itemW, uiY + 30, tocolor(255, 255, 255), 1, "default-bold", "center", "center")

    for i, it in ipairs(upgItems) do
        local iy = uiY + 40 + (i - 1) * 65
        local count = playerItems[it.key] or 0
        local isDrag = draggingItem == it
        dxDrawRectangle(itemPanelX + 10, iy, itemW - 20, 60, isDrag and tocolor(0, 150, 255, 120) or tocolor(30, 30, 30, 200))
        dxDrawText(it.name .. ": " .. count, itemPanelX + 60, iy, 0, iy + 60, count > 0 and tocolor(255, 255, 255) or tocolor(120, 120, 120), 1, "default", "left", "center")
        if iconExists(it.icon) then
            dxDrawImage(itemPanelX + 15, iy + 10, 40, 40, it.icon)
        end
    end

    -- FŐ KERET
    dxDrawRectangle(uiX, uiY, uiW, uiH, tocolor(15, 15, 15, 230))
    dxDrawRectangle(uiX, uiY, uiW, 30, tocolor(30, 30, 30, 255))
    dxDrawText("TTT WEAPON INVENTORY", uiX, uiY, uiX + uiW, uiY + 30, tocolor(255, 255, 255, 200), 1.1, "default-bold", "center", "center")

    -- TÁSKA RÁCS (slot_type 0)
    local invSlots = getInventoryWeapons()
    local sIdx = 1
    for row = 0, 3 do
        for col = 0, 4 do
            local x = startX + col * (slotSize + padding)
            local y = startY + row * (slotSize + padding)
            dxDrawRectangle(x, y, slotSize, slotSize, tocolor(0, 200, 0, 40))
            dxDrawRectangle(x, y, slotSize, 2, tocolor(0, 255, 0, 50))
            local wp = invSlots[sIdx]
            if wp then
                local alpha = (draggingWeapon and draggingWeapon.id == wp.id) and 50 or 255
                drawWeaponIcon(wp.weapon_model, x, y, slotSize, alpha)
            end
            sIdx = sIdx + 1
        end
    end

    -- AKTÍV SLOTOK (1-4 sárga, 5 kék)
    for i = 1, 5 do
        local x = startX + (i - 1) * (slotSize + padding)
        local alphaMult = (draggingWeapon and not canWeaponGoToSlot(draggingWeapon.weapon_model, i)) and 0.2 or 1.0
        local color = (i <= 4) and tocolor(200, 200, 0, 40 * alphaMult) or tocolor(0, 150, 255, 40 * alphaMult)
        local lineCol = (i <= 4) and tocolor(255, 255, 0, 100 * alphaMult) or tocolor(0, 150, 255, 100 * alphaMult)

        dxDrawRectangle(x, bottomY, slotSize, slotSize, color)
        dxDrawRectangle(x, bottomY + slotSize - 5, slotSize, 5, lineCol)
        dxDrawText(i, x + 5, bottomY + 5, 0, 0, tocolor(255, 255, 255, 50 * alphaMult), 0.8, "default-bold")

        local wp = getWeaponInSlot(i)
        if wp then
            local alpha = (draggingWeapon and draggingWeapon.id == wp.id) and 50 or (220 * alphaMult)
            drawWeaponIcon(wp.weapon_model, x, bottomY, slotSize, alpha)
        end
    end

    -- INFORMÁCIÓS PANEL (jobb)
    local infoHover = false
    if draggingItem and selectedWeapon then
        local mx, my = getCursorPosition()
        infoHover = inRect(mx * screenW, my * screenH, infoX, uiY + 60, infoW, uiH - 180)
    end
    dxDrawRectangle(infoX, uiY + 60, infoW, uiH - 180, infoHover and tocolor(25, 60, 25, 255) or tocolor(25, 25, 25, 255))

    if selectedWeapon then
        dxDrawText(getWeaponNameFromID(selectedWeapon.weapon_model):upper(), infoX, uiY + 75, infoX + infoW, 0, tocolor(0, 255, 0, 255), 1.4, "default-bold", "center")
        dxDrawLine(infoX + 20, uiY + 110, infoX + 245, uiY + 110, tocolor(255, 255, 255, 50))
        dxDrawText("Állapot: " .. tostring(selectedWeapon.durability) .. "%", infoX + 25, uiY + 120, 0, 0, tocolor(220, 220, 220), 1, "default-bold")
        dxDrawText("Serial: " .. tostring(selectedWeapon.serial_number), infoX + 25, uiY + 135, 0, 0, tocolor(100, 100, 100), 0.8)

        local statY = uiY + 175
        for _, stat in ipairs(allStats) do
            local val = tonumber(selectedWeapon[stat.key]) or 0
            if val ~= 0 then
                local displayVal = (val > 0 and "+" or "") .. val
                if val == 1 and stat.key:find("buff") then displayVal = "AKTÍV" end
                dxDrawText("• " .. stat.label .. ":", infoX + 25, statY, 0, 0, tocolor(180, 180, 180, 200))
                dxDrawText(displayVal, infoX + 205, statY, 0, 0, tocolor(unpack(stat.color)), 1, "default-bold")
                statY = statY + 22
            end
        end

        local curse = selectedWeapon.curse_1_type
        if curse and curse ~= "" and curse ~= "NULL" then
            dxDrawText("⚠ ÁTOK: " .. curse, infoX, statY + 10, infoX + infoW, 0, tocolor(255, 0, 0, 255), 1, "default-bold", "center")
        end
        if draggingItem then
            dxDrawText("Engedd el ide a fejlesztéshez", infoX, uiY + uiH - 150, infoX + infoW, uiY + uiH - 120, tocolor(0, 255, 0, 200), 0.9, "default-bold", "center", "center")
        end
    else
        dxDrawText("Válassz egy fegyvert\na statok megtekintéséhez!", infoX, uiY + 60, infoX + infoW, uiY + uiH - 120, tocolor(100, 100, 100), 1, "default", "center", "center")
    end

    -- HÚZÁS EFFEKT
    if draggingWeapon or draggingItem then
        local cx, cy = getCursorPosition()
        cx, cy = cx * screenW, cy * screenH
        if draggingWeapon then
            local path = getIconPath(draggingWeapon.weapon_model)
            if path then dxDrawImage(cx - 40, cy - 40, 80, 80, path, 0, 0, 0, tocolor(255, 255, 255, 180)) end
        elseif iconExists(draggingItem.icon) then
            dxDrawImage(cx - 20, cy - 20, 40, 40, draggingItem.icon, 0, 0, 0, tocolor(255, 255, 255, 180))
        else
            dxDrawText(draggingItem.name, cx + 10, cy, 0, 0, tocolor(255, 255, 255, 200), 1, "default-bold")
        end
    end
end

-- F2 Megnyitás / Bezárás
bindKey("f2", "down", function()
    isInventoryOpen = not isInventoryOpen
    showCursor(isInventoryOpen)
    if isInventoryOpen then
        triggerServerEvent("requestPlayerWeapons", localPlayer)
        addEventHandler("onClientRender", root, drawWeaponUI)
    else
        removeEventHandler("onClientRender", root, drawWeaponUI)
        draggingWeapon, draggingItem = nil, nil
    end
end)

-- EGÉR KEZELÉS (Click & Drag) - fegyverek és fejlesztő itemek
addEventHandler("onClientClick", root, function(btn, state)
    if not isInventoryOpen or btn ~= "left" then return end
    local cx, cy = getCursorPosition()
    cx, cy = cx * screenW, cy * screenH

    if state == "down" then
        -- 1. Fejlesztő item felvétele
        for i, it in ipairs(upgItems) do
            local iy = uiY + 40 + (i - 1) * 65
            if inRect(cx, cy, itemPanelX + 10, iy, itemW - 20, 60) then
                if (playerItems[it.key] or 0) > 0 then
                    draggingItem = it
                    playSoundFrontEnd(41)
                end
                return
            end
        end

        -- 2. Táska
        local invWeapons = getInventoryWeapons()
        local sIdx = 1
        for row = 0, 3 do
            for col = 0, 4 do
                local x = startX + col * (slotSize + padding)
                local y = startY + row * (slotSize + padding)
                if inRect(cx, cy, x, y, slotSize, slotSize) then
                    if invWeapons[sIdx] then
                        selectedWeapon, draggingWeapon = invWeapons[sIdx], invWeapons[sIdx]
                        playSoundFrontEnd(41)
                    end
                    return
                end
                sIdx = sIdx + 1
            end
        end

        -- 3. Aktív slotok
        for i = 1, 5 do
            local x = startX + (i - 1) * (slotSize + padding)
            if inRect(cx, cy, x, bottomY, slotSize, slotSize) then
                local wp = getWeaponInSlot(i)
                if wp then
                    selectedWeapon, draggingWeapon = wp, wp
                    playSoundFrontEnd(41)
                end
                return
            end
        end

        -- Üres helyre kattintás az UI-n belül: kijelölés törlése (az info panel kivételével)
        if inRect(cx, cy, uiX, uiY, uiW, uiH) and not inRect(cx, cy, infoX, uiY + 60, infoW, uiH - 180) then
            selectedWeapon = nil
        end

    elseif state == "up" then
        -- Fejlesztő item elengedése az info panel fölött
        if draggingItem then
            if selectedWeapon and inRect(cx, cy, infoX, uiY + 60, infoW, uiH - 180) then
                triggerServerEvent("applyWeaponUpgrade", localPlayer, selectedWeapon.id, draggingItem.key)
                playSoundFrontEnd(42)
            end
            draggingItem = nil
        end

        -- Fegyver elengedése
        if draggingWeapon then
            local droppedOnSlot = false
            for i = 1, 5 do
                local x = startX + (i - 1) * (slotSize + padding)
                if inRect(cx, cy, x, bottomY, slotSize, slotSize) then
                    if canWeaponGoToSlot(draggingWeapon.weapon_model, i) then
                        -- Optimista frissítés
                        local prev = getWeaponInSlot(i)
                        if prev then prev.slot_type, prev.is_equipped = 0, 0 end
                        draggingWeapon.slot_type, draggingWeapon.is_equipped = i, 1
                        triggerServerEvent("updateWeaponSlot", localPlayer, draggingWeapon.id, i)
                        playSoundFrontEnd(42)
                    else
                        outputChatBox("#ff0000[Inventory] #ffffffEz a fegyver nem való ebbe a slotba!", 255, 255, 255, true)
                        playSoundFrontEnd(32)
                    end
                    droppedOnSlot = true
                    break
                end
            end
            -- Vissza a táskába
            if not droppedOnSlot and cy < bottomY and cy > uiY + 30 and tonumber(draggingWeapon.slot_type) ~= 0 then
                draggingWeapon.slot_type, draggingWeapon.is_equipped = 0, 0
                triggerServerEvent("updateWeaponSlot", localPlayer, draggingWeapon.id, 0)
                playSoundFrontEnd(42)
            end
            draggingWeapon = nil
        end
    end
end)

addEvent("receivePlayerWeapons", true)
addEventHandler("receivePlayerWeapons", root, function(data)
    playerWeapons = data or {}
    if selectedWeapon then
        local found = nil
        for _, wp in ipairs(playerWeapons) do
            if wp.id == selectedWeapon.id then found = wp break end
        end
        selectedWeapon = found
    end
end)

addEvent("receivePlayerItems", true)
addEventHandler("receivePlayerItems", root, function(data)
    playerItems = data or playerItems
end)
