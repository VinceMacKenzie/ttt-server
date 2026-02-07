local screenW, screenH = guiGetScreenSize()
local isInventoryOpen = false
local uiW, uiH = 800, 600
local uiX, uiY = (screenW - uiW) / 2, (screenH - uiH) / 2

local playerWeapons = {} 
local selectedWeapon = nil
local draggingWeapon = nil

-- SLOT KORLÁTOZÁSOK (Melyik fegyver hova mehet)
local slotRestrictions = {
    [1] = {30, 31},             -- AK-47, M4
    [2] = {28, 29, 32},         -- Uzi, MP5, Tec9
    [3] = {22, 23, 24},         -- Colt, Silenced, Deagle
    [4] = {33, 34},             -- Rifle, Sniper
    [5] = {100},                -- Armor (Példa ID, írd át amire kell)
}

-- Fegyvernevek fordító táblázata
local weaponNames = {
    [0] = "Ököl", [22] = "Colt 45", [23] = "Silenced Colt", [24] = "Desert Eagle", 
    [25] = "Sörétes puska", [28] = "Uzi", [29] = "MP5", [30] = "AK-47", 
    [31] = "M4", [32] = "Tec-9", [33] = "Rifle", [34] = "Sniper", [100] = "Kevlár Mellény"
}

-- Segédfüggvény: Ellenőrzi, hogy a fegyver bemehet-e az adott slotba
function canWeaponGoToSlot(model, slotID)
    if slotID == 0 then return true end -- Táskába bármi mehet
    if not slotRestrictions[slotID] then return false end
    for _, allowedID in ipairs(slotRestrictions[slotID]) do
        if allowedID == model then return true end
    end
    return false
end

function getWeaponNameFromID(id)
    return weaponNames[id] or "Tárgy #"..id
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
        draggingWeapon = nil
    end
end)

local function drawWeaponIcon(modelID, x, y, size, alpha)
    local iconPath = "icons/" .. modelID .. ".png"
    
    -- Ha nem létezik a kép, váltson az error.png-re
    if not fileExists(iconPath) then
        iconPath = "icons/error.png"
    end

    -- Csak akkor rajzolunk, ha legalább az error.png megvan
    if fileExists(iconPath) then
        dxDrawImage(x + 5, y + 5, size - 10, size - 10, iconPath, 0, 0, 0, tocolor(255, 255, 255, alpha))
    end
end

local playerItems = { opt_adder = 50, opt_changer = 0, curse_remover = 0 }

-- Esemény, amivel a szerver frissíti az adataidat
addEvent("receivePlayerItems", true)
addEventHandler("receivePlayerItems", root, function(data)
    playerItems = data
end)

function drawWeaponUI()
    local itemPanelX = uiX - 210
    local itemW = 200
    dxDrawRectangle(itemPanelX, uiY, itemW, 250, tocolor(15, 15, 15, 230)) 
    dxDrawRectangle(itemPanelX, uiY, itemW, 30, tocolor(0, 150, 255, 150))
    dxDrawText("FEJLESZTŐK", itemPanelX, uiY, itemPanelX + itemW, uiY + 30, tocolor(255, 255, 255), 1, "default-bold", "center", "center")

    local upgItems = {
        {key = "opt_adder", name = "Új Optoló", icon = "icons/opt_adder.png"},
        {key = "opt_changer", name = "Opt Cserélő", icon = "icons/opt_changer.png"},
        {key = "curse_remover", name = "Átoktörő", icon = "icons/curse_remover.png"}
    }

    -- Most már a globális/külső playerItems-ből fog olvasni
    for i, it in ipairs(upgItems) do
        local iy = uiY + 40 + (i-1) * 65
        dxDrawRectangle(itemPanelX + 10, iy, itemW - 20, 60, tocolor(30, 30, 30, 200))
        
        local count = playerItems[it.key] or 0
        dxDrawText(it.name .. ": " .. count, itemPanelX + 60, iy, 0, iy + 60, tocolor(255, 255, 255), 1, "default", "left", "center")
        
        if fileExists(it.icon) then
            dxDrawImage(itemPanelX + 15, iy + 10, 40, 40, it.icon)
        end
        
        it.x, it.y, it.w, it.h = itemPanelX + 10, iy, itemW - 20, 60
    end

    -- 1. FŐ KERET ÉS FEJLÉC
    dxDrawRectangle(uiX, uiY, uiW, uiH, tocolor(15, 15, 15, 230))
    dxDrawRectangle(uiX, uiY, uiW, 30, tocolor(30, 30, 30, 255))
    dxDrawText("TTT WEAPON INVENTORY", uiX, uiY, uiX + uiW, uiY + 30, tocolor(255, 255, 255, 200), 1.1, "default-bold", "center", "center")

    local slotSize = 85
    local padding = 10
    local startX, startY = uiX + 25, uiY + 60

    -- 2. TÁSKA RÁCS (ZÖLD) - Slot Type: 0
    local invSlots = {}
    for _, wp in ipairs(playerWeapons) do 
        if wp.slot_type == 0 then table.insert(invSlots, wp) end 
    end

    local sIdx = 1
    for row = 0, 3 do
        for col = 0, 4 do
            local x = startX + (col * (slotSize + padding))
            local y = startY + (row * (slotSize + padding))
            dxDrawRectangle(x, y, slotSize, slotSize, tocolor(0, 200, 0, 40))
            dxDrawRectangle(x, y, slotSize, 2, tocolor(0, 255, 0, 50))
            
            if invSlots[sIdx] then
                local alpha = (draggingWeapon and draggingWeapon.id == invSlots[sIdx].id) and 50 or 255
                -- Meghívjuk a fenti segédfüggvényt
                drawWeaponIcon(invSlots[sIdx].weapon_model, x, y, slotSize, alpha)
            end
            sIdx = sIdx + 1
        end
    end

    -- 3. AKTÍV HELYEK (SÁRGA 1-4, KÉK 5)
    local bottomY = uiY + uiH - 120
    for i = 1, 5 do
        local x = startX + ((i-1) * (slotSize + padding))
        
        -- Validáció a fényerőhöz: ha húzunk valamit, és nem ebbe a slotba való, elhalványítjuk
        local alphaMult = 1.0
        if draggingWeapon and not canWeaponGoToSlot(draggingWeapon.weapon_model, i) then
            alphaMult = 0.2
        end

        local color = (i <= 4) and tocolor(200, 200, 0, 40 * alphaMult) or tocolor(0, 150, 255, 40 * alphaMult)
        local lineCol = (i <= 4) and tocolor(255, 255, 0, 100 * alphaMult) or tocolor(0, 150, 255, 100 * alphaMult)
        
        dxDrawRectangle(x, bottomY, slotSize, slotSize, color)
        dxDrawRectangle(x, bottomY + slotSize - 5, slotSize, 5, lineCol)
        
        -- Szám jelölés a slotokhoz
        dxDrawText(i, x + 5, bottomY + 5, 0, 0, tocolor(255, 255, 255, 50 * alphaMult), 0.8, "default-bold")

        for _, wp in ipairs(playerWeapons) do
            if wp.slot_type == i then
                local alpha = (draggingWeapon and draggingWeapon.id == wp.id) and 50 or (220 * alphaMult)
                -- Csak az ikon kirajzolása
                local iconPath = "icons/" .. wp.weapon_model .. ".png"
                if fileExists(iconPath) then
                    dxDrawImage(x + 5, bottomY + 5, slotSize - 10, slotSize - 10, iconPath, 0, 0, 0, tocolor(255, 255, 255, alpha))
                end
            end
        end
    end

    -- 4. INFORMÁCIÓS PANEL (JOBB OLDAL)
    local infoX = uiX + 510
    dxDrawRectangle(infoX, uiY + 60, 265, uiH - 180, tocolor(25, 25, 25, 255))
    
    if selectedWeapon then
        local wName = getWeaponNameFromID(selectedWeapon.weapon_model)
        dxDrawText(wName:upper(), infoX, uiY + 75, infoX + 265, 0, tocolor(0, 255, 0, 255), 1.4, "default-bold", "center")
        dxDrawLine(infoX + 20, uiY + 110, infoX + 245, uiY + 110, tocolor(255, 255, 255, 50))
        
        dxDrawText("Állapot: " .. selectedWeapon.durability .. "%", infoX + 25, uiY + 120, 0, 0, tocolor(220, 220, 220), 1, "default-bold")
        dxDrawText("Serial: " .. selectedWeapon.serial_number, infoX + 25, uiY + 135, 0, 0, tocolor(100, 100, 100), 0.8)

        local allStats = {
            {key = "mod_head_dmg", label = "Headshot sebzés", color = {124, 197, 118}},
            {key = "mod_body_dmg", label = "Testi sebzés", color = {200, 200, 200}},
            {key = "mod_arm_dmg", label = "Kar sebzés", color = {200, 200, 200}},
            {key = "mod_leg_dmg", label = "Láb sebzés", color = {200, 200, 200}},
            {key = "buff_fire", label = "Tűzsebzés esély", color = {255, 100, 0}},
            {key = "buff_stun", label = "Kábítás esély", color = {0, 200, 255}},
            {key = "buff_poison", label = "Mérgezés esély", color = {150, 255, 0}},
            {key = "buff_life_drain", label = "Életszívás esély", color = {255, 50, 50}},
            {key = "reload_speed_mod", label = "Gyorstöltés", color = {255, 200, 0}},
            {key = "ammo_capacity_mod", label = "Tárkapacitás", color = {200, 200, 200}},
        }

        local startStatY = uiY + 175
        local foundAny = false
        for _, stat in ipairs(allStats) do
            local val = tonumber(selectedWeapon[stat.key]) or 0
            if val ~= 0 then
                foundAny = true
                local prefix = (val > 0) and "+" or ""
                local displayVal = prefix .. val
                if val == 1 and string.find(stat.key, "buff") then displayVal = "AKTÍV" end

                dxDrawText("• " .. stat.label .. ":", infoX + 25, startStatY, 0, 0, tocolor(180, 180, 180, 200))
                dxDrawText(displayVal, infoX + 205, startStatY, 0, 0, tocolor(unpack(stat.color)), 1, "default-bold")
                startStatY = startStatY + 22
            end
        end

        if selectedWeapon.curse_1_type and selectedWeapon.curse_1_type ~= "" and selectedWeapon.curse_1_type ~= "NULL" then
            dxDrawText("⚠ ÁTOK: " .. selectedWeapon.curse_1_type, infoX, startStatY + 10, infoX + 265, 0, tocolor(255, 0, 0, 255), 1, "default-bold", "center")
        end
    else
        dxDrawText("Válassz egy fegyvert\na statok megtekintéséhez!", infoX, uiY + 60, infoX + 265, uiY + uiH - 120, tocolor(100, 100, 100), 1, "default", "center", "center")
    end

    -- HÚZÁS EFFEKT
    if draggingWeapon then
        local cx, cy = getCursorPosition()
        cx, cy = cx * screenW, cy * screenH
        local iconPath = "icons/" .. draggingWeapon.weapon_model .. ".png"
        if fileExists(iconPath) then
            dxDrawImage(cx - 40, cy - 40, 80, 80, iconPath, 0, 0, 0, tocolor(255, 255, 255, 180))
        end
    end
end

-- EGÉR KEZELÉS (Click & Drag)
addEventHandler("onClientClick", root, function(btn, state)
    if not isInventoryOpen or btn ~= "left" then return end
    local cx, cy = getCursorPosition()
    cx, cy = cx * screenW, cy * screenH

    local slotSize = 85
    local padding = 10
    local startX, startY = uiX + 25, uiY + 60
    local bottomY = uiY + uiH - 120

    if state == "down" then
        -- 1. Inventory kattintás (Slot 0)
        local invWeapons = {}
        for _, wp in ipairs(playerWeapons) do 
            if wp.slot_type == 0 then table.insert(invWeapons, wp) end 
        end
        
        local sIdx = 1
        for row = 0, 3 do
            for col = 0, 4 do
                local x = startX + (col * (slotSize + padding))
                local y = startY + (row * (slotSize + padding))
                if cx >= x and cx <= x + slotSize and cy >= y and cy <= y + slotSize then
                    if invWeapons[sIdx] then 
                        selectedWeapon = invWeapons[sIdx] 
                        draggingWeapon = invWeapons[sIdx] 
                        playSoundFrontEnd(41)
                        return 
                    end
                end
                sIdx = sIdx + 1
            end
        end
        -- 2. Aktív slot kattintás (Slot 1-5)
        for i = 1, 5 do
            local x = startX + ((i-1) * (slotSize + padding))
            if cx >= x and cx <= x + slotSize and cy >= bottomY and cy <= bottomY + slotSize then
                for _, wp in ipairs(playerWeapons) do
                    if wp.slot_type == i then 
                        selectedWeapon = wp 
                        draggingWeapon = wp 
                        playSoundFrontEnd(41)
                        return 
                    end
                end
            end
        end
        selectedWeapon = nil

    elseif state == "up" and draggingWeapon then
        local droppedOnSlot = false

        -- Ledobtuk egy aktív slotra (1-5)?
        for i = 1, 5 do
            local x = startX + ((i-1) * (slotSize + padding))
            if cx >= x and cx <= x + slotSize and cy >= bottomY and cy <= bottomY + slotSize then
                if canWeaponGoToSlot(draggingWeapon.weapon_model, i) then                 
                    -- --- GUI AZONNALI FRISSÍTÉSE (Optimistic Update) ---
                    for _, wp in ipairs(playerWeapons) do
                        if wp.slot_type == i then
                            -- Aki ott volt, megy a táskába
                            wp.slot_type = 0
                            wp.is_equipped = 0
                        end
                    end
                    -- A húzott tárgy bekerül a slotba
                    draggingWeapon.slot_type = i
                    draggingWeapon.is_equipped = 1
                    -- --------------------------------------------------
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
        -- Ledobtuk a táska területére? (Slot 0)
        if not droppedOnSlot and cy < bottomY and cy > uiY + 30 then
            -- Ha épp egy aktív slotból húztuk ki, azonnal tegyük a táskába vizuálisan
            draggingWeapon.slot_type = 0
            draggingWeapon.is_equipped = 0
            
            triggerServerEvent("updateWeaponSlot", localPlayer, draggingWeapon.id, 0)
            playSoundFrontEnd(42)
        end
        
        draggingWeapon = nil
    end
end)

addEvent("receivePlayerWeapons", true)
addEventHandler("receivePlayerWeapons", root, function(data)
    playerWeapons = data
    if selectedWeapon then
        for _, wp in ipairs(data) do
            if wp.id == selectedWeapon.id then selectedWeapon = wp break end
        end
    end
end)