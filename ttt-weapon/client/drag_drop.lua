local draggingItem = nil -- Az éppen húzott Upgrade Item (Optoló, stb.)
-- Megjegyzés: A draggingWeapon már létezik a kódodban a fegyverekhez!

addEventHandler("onClientClick", root, function(button, state)
    if not isInventoryOpen or button ~= "left" then return end
    
    local cx, cy = getCursorPosition()
    cx, cy = cx * screenW, cy * screenH

    local slotSize, padding = 85, 10
    local startX, startY = uiX + 25, uiY + 60
    local bottomY = uiY + uiH - 120

    if state == "down" then
        -- 1. FEJLESZTŐK (Bal panel) ellenőrzése
        local itemPanelX = uiX - 210
        for i, it in ipairs(upgItems) do
            local iy = uiY + 40 + (i-1) * 65
            if cx >= itemPanelX + 10 and cx <= itemPanelX + 190 and cy >= iy and cy <= iy + 60 then
                if (playerItems[it.key] or 0) > 0 then
                    draggingItem = it
                    playSoundFrontEnd(41)
                    return
                end
            end
        end

        -- 2. TÁSKA (Zöld slotok) ellenőrzése
        local invWeapons = {}
        for _, wp in ipairs(playerWeapons) do if wp.slot_type == 0 then table.insert(invWeapons, wp) end end
        
        local sIdx = 1
        for row = 0, 3 do
            for col = 0, 4 do
                local x = startX + (col * (slotSize + padding))
                local y = startY + (row * (slotSize + padding))
                if cx >= x and cx <= x + slotSize and cy >= y and cy <= y + slotSize then
                    if invWeapons[sIdx] then 
                        selectedWeapon, draggingWeapon = invWeapons[sIdx], invWeapons[sIdx]
                        playSoundFrontEnd(41)
                        return 
                    end
                end
                sIdx = sIdx + 1
            end
        end

        -- 3. AKTÍV SLOTOK (Lent) ellenőrzése
        for i = 1, 5 do
            local x = startX + ((i-1) * (slotSize + padding))
            if cx >= x and cx <= x + slotSize and cy >= bottomY and cy <= bottomY + slotSize then
                for _, wp in ipairs(playerWeapons) do
                    if wp.slot_type == i then 
                        selectedWeapon, draggingWeapon = wp, wp
                        playSoundFrontEnd(41)
                        return 
                    end
                end
            end
        end

    elseif state == "up" then
        -- --- ELENGEDÉS: FEJLESZTŐ ITEM ---
        if draggingItem then
            local infoX = uiX + 510
            -- Ha a jobb oldali info panel fölött engedjük el:
            if selectedWeapon and cx >= infoX and cx <= infoX + 265 and cy >= uiY + 60 and cy <= uiY + uiH - 120 then
                triggerServerEvent("applyWeaponUpgrade", localPlayer, selectedWeapon.id, draggingItem.key)
            end
            draggingItem = nil
        end

        -- --- ELENGEDÉS: FEGYVER ---
        if draggingWeapon then
            local droppedOnSlot = false
            -- Slotba rakás
            for i = 1, 5 do
                local x = startX + ((i-1) * (slotSize + padding))
                if cx >= x and cx <= x + slotSize and cy >= bottomY and cy <= bottomY + slotSize then
                    if canWeaponGoToSlot(draggingWeapon.weapon_model, i) then
                        for _, wp in ipairs(playerWeapons) do
                            if wp.slot_type == i then wp.slot_type = 0; wp.is_equipped = 0 end
                        end
                        draggingWeapon.slot_type, draggingWeapon.is_equipped = i, 1
                        triggerServerEvent("updateWeaponSlot", localPlayer, draggingWeapon.id, i)
                        playSoundFrontEnd(42)
                    else
                        playSoundFrontEnd(32)
                    end
                    droppedOnSlot = true
                    break
                end
            end
            -- Táskába vissza (ha nem slotra ment, de az UI-n belül van)
            if not droppedOnSlot and cy < bottomY and cy > uiY + 30 then
                draggingWeapon.slot_type, draggingWeapon.is_equipped = 0, 0
                triggerServerEvent("updateWeaponSlot", localPlayer, draggingWeapon.id, 0)
                playSoundFrontEnd(42)
            end
            draggingWeapon = nil
        end
    end
end)