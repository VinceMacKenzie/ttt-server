local screenW, screenH = guiGetScreenSize()
local isSkinShopActive = false
local currentSkinIdx = 1
local currentShopTab = "BUY"   -- "BUY", "OWNED" vagy "EFFECT"
local ownedSkins = {}          -- {[id] = "Skin neve"}
local ownedList = {}           -- rendezett id lista (OWNED fülhöz, cache-elve)

-- Ruhabolt interior
local interiorID = 5
local pedPos = {x = 210.5, y = -8.5, z = 1001.5}
local camPos = {x = 210.5, y = -13.5, z = 1001.5}
local previewPed = nil

-- Visszatéréshez elmentett állapot
local savedPos = nil

-- Egyedi modellek: {fájlnév, skinID}
local replaceableSkins = {
    {"darth_maul", 24}, {"Ezio", 25}, {"Chiss", 27}, {"Gran", 28}, {"Weequay", 29}, {"phoenix", 26}, {"palpatine", 68}, {"bean", 95},
}

local function rebuildOwnedList()
    ownedList = {}
    for id in pairs(ownedSkins) do table.insert(ownedList, id) end
    table.sort(ownedList)
end

local function getSkinNameByID(id)
    return ownedSkins[id] or getSkinDisplayName(id)
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    for _, data in ipairs(replaceableSkins) do
        local name, id = data[1], data[2]
        if fileExists("skins/" .. name .. ".txd") then
            local txd = engineLoadTXD("skins/" .. name .. ".txd")
            if txd then engineImportTXD(txd, id) end
        end
        if fileExists("skins/" .. name .. ".dff") then
            local dff = engineLoadDFF("skins/" .. name .. ".dff")
            if dff then engineReplaceModel(dff, id) end
        end
    end
    triggerServerEvent("ttt:requestOwnedSkins", localPlayer)
end)

addEvent("ttt:receiveOwnedSkins", true)
addEventHandler("ttt:receiveOwnedSkins", root, function(ownedTable)
    ownedSkins = ownedTable or {}
    rebuildOwnedList()
end)

addEvent("ttt:addOwnedSkinToClient", true)
addEventHandler("ttt:addOwnedSkinToClient", root, function(id, name)
    ownedSkins[id] = name or getSkinDisplayName(id)
    rebuildOwnedList()
end)

-- Aktuális fül szerinti skin ID
local function getCurrentSkinID()
    if currentShopTab == "EFFECT" then return nil end
    if currentShopTab == "BUY" then
        return SkinList[currentSkinIdx][3]
    end
    return ownedList[currentSkinIdx]
end

local function updatePreview()
    if not isElement(previewPed) then return end
    if currentShopTab == "EFFECT" then
        -- Effekt fül: a saját jelenlegi skineden mutatjuk az éppen kiválasztott effektet
        setElementModel(previewPed, getElementModel(localPlayer))
        local e = EffectMenuList[currentSkinIdx]
        setPreviewEffect(previewPed, e and e.key ~= "none" and e.key or nil)
        return
    end
    local id = getCurrentSkinID()
    if id then setElementModel(previewPed, id) end
    setPreviewEffect(previewPed, getActiveEffect())   -- skin nézegetésnél az aktív effekted látszik
end

local function drawSkinShop()
    local menuW, menuH = 800, 45
    local mx, my = (screenW - menuW) / 2, 40
    local menuTabs = {{"BUY", "VÁSÁRLÁS [1]"}, {"OWNED", "MEGVÁSÁROLVA [2]"}, {"EFFECT", "EFFEKTEK [3]"}, {"WEAPON", "FEGYVER SKINEK [4]"}}   -- [4]: ttt-weaponskin
    local tw = menuW / #menuTabs
    for i, t in ipairs(menuTabs) do
        local tx = mx + (i - 1) * tw
        dxDrawRectangle(tx + 2, my, tw - 4, menuH, currentShopTab == t[1] and tocolor(0, 195, 255, 220) or tocolor(0, 0, 0, 180))
        dxDrawText(t[2], tx, my, tx + tw, my + menuH, tocolor(255, 255, 255), 1.2, "default-bold", "center", "center")
    end

    local displayName, priceText, isOwned, hintText
    if currentShopTab == "EFFECT" then
        local e = EffectMenuList[currentSkinIdx]
        local active = getActiveEffect()
        displayName = e.name
        if e.key == "none" then
            isOwned = true
            priceText = active and "" or "AKTÍV"
            hintText = active and "[SPACE] EFFEKT LEVÉTELE" or "NINCS AKTÍV EFFEKTED"
        elseif active == e.key then
            isOwned, priceText, hintText = true, "AKTÍV", "[SPACE] EFFEKT LEVÉTELE"
        elseif isEffectOwned(e.key) then
            isOwned, priceText, hintText = true, "BIRTOKOLVA", "[SPACE] EFFEKT FELVÉTELE"
        else
            isOwned, priceText, hintText = false, "$" .. e.price, "MEGVEHETŐ: F3 SHOP → EFFEKTEK FÜL"
        end
        -- leírás + lapozó a doboz felett
        local bx, by = (screenW - 400) / 2, screenH - 180
        dxDrawText(e.desc or "", bx - 100, by - 50, bx + 500, by - 8, tocolor(255, 255, 255, 200), 1.1, "default-bold", "center", "bottom", false, true)
        dxDrawText(currentSkinIdx .. " / " .. #EffectMenuList, bx, by - 75, bx + 400, by - 50, tocolor(0, 195, 255, 200), 1, "default-bold", "center", "bottom")
    elseif currentShopTab == "BUY" then
        local data = SkinList[currentSkinIdx]
        displayName = getSkinDisplayName(data[3]):upper()
        isOwned = ownedSkins[data[3]] ~= nil or data[2] == 0
        priceText = isOwned and "MEGVÁSÁROLVA" or "$" .. data[2]
    elseif #ownedList > 0 then
        displayName = getSkinNameByID(ownedList[currentSkinIdx]):upper()
        priceText, isOwned = "BIRTOKOLVA", true
    else
        displayName, priceText, isOwned = "NINCS MEGVETT SKIN", "-", false
    end

    local boxW, boxH = 400, 140
    local bx, by = (screenW - boxW) / 2, screenH - 180
    dxDrawRectangle(bx, by, boxW, boxH, tocolor(0, 0, 0, 220))
    dxDrawRectangle(bx, by, boxW, 4, tocolor(0, 195, 255, 255))
    dxDrawText("◄ A", bx + 20, by, bx + 70, by + boxH, tocolor(255, 255, 255), 1.5, "default-bold", "left", "center")
    dxDrawText("D ►", bx + boxW - 70, by, bx + boxW - 20, by + boxH, tocolor(255, 255, 255), 1.5, "default-bold", "right", "center")
    dxDrawText(displayName, bx, by + 25, bx + boxW, 0, tocolor(255, 255, 255), 1.8, "default-bold", "center", "top")
    dxDrawText(priceText, bx, by + 65, bx + boxW, 0, isOwned and tocolor(0, 195, 255) or tocolor(46, 204, 113), 1.5, "default-bold", "center", "top")
    dxDrawText(hintText or (isOwned and "[SPACE] SKIN FELVÉTELE" or "[SPACE] VÁSÁRLÁS"), bx, by + 105, bx + boxW, 0, tocolor(255, 255, 255, 150), 1, "default", "center", "top")
    dxDrawText("F4 / ESC: KILÉPÉS", bx, by + 120, bx + boxW, 0, tocolor(255, 255, 255, 80), 0.8, "default", "center", "top")
end

-- startTab: "BUY" (alap), "OWNED" vagy "EFFECT" (a ttt-weaponskin menüjéből visszalépéskor)
function toggleSkinShop(startTab)
    if isPedDead(localPlayer) then return end
    -- Kör közben nem nyitható (a játékos láthatatlan és mozdulatlan lenne)
    if not isSkinShopActive and getElementData(localPlayer, "tttRole") then
        return outputChatBox("#d9534f[Skin] #ffffffKör közben nem nyithatod meg a skin boltot!", 255, 255, 255, true)
    end

    isSkinShopActive = not isSkinShopActive

    if isSkinShopActive then
        local x, y, z = getElementPosition(localPlayer)
        savedPos = {x = x, y = y, z = z, int = getElementInterior(localPlayer), dim = getElementDimension(localPlayer)}

        showCursor(true)
        setElementFrozen(localPlayer, true)
        setElementInterior(localPlayer, interiorID)
        setElementAlpha(localPlayer, 0)
        setElementPosition(localPlayer, pedPos.x, pedPos.y, pedPos.z - 5)

        currentSkinIdx, currentShopTab = 1, (startTab == "OWNED" or startTab == "EFFECT") and startTab or "BUY"
        if isElement(previewPed) then destroyElement(previewPed) end
        previewPed = createPed(SkinList[1][3], pedPos.x, pedPos.y, pedPos.z)
        setElementInterior(previewPed, interiorID)
        setElementDimension(previewPed, getElementDimension(localPlayer))
        setPedRotation(previewPed, 180)
        setPreviewEffect(previewPed, getActiveEffect())
        if currentShopTab == "EFFECT" then
            local active = getActiveEffect()
            for i, e in ipairs(EffectMenuList) do if e.key == active then currentSkinIdx = i end end
        end
        if currentShopTab ~= "BUY" then updatePreview() end

        setCameraMatrix(camPos.x, camPos.y, camPos.z, pedPos.x, pedPos.y, pedPos.z)
        guiSetInputMode("no_binds")
        addEventHandler("onClientRender", root, drawSkinShop)
    else
        removeEventHandler("onClientRender", root, drawSkinShop)
        showCursor(false)
        setElementFrozen(localPlayer, false)
        setElementAlpha(localPlayer, 255)
        setCameraTarget(localPlayer)
        if isElement(previewPed) then
            setPreviewEffect(previewPed, nil)
            destroyElement(previewPed)
        end
        if savedPos then
            setElementInterior(localPlayer, savedPos.int)
            setElementDimension(localPlayer, savedPos.dim)
            setElementPosition(localPlayer, savedPos.x, savedPos.y, savedPos.z)
        else
            setElementInterior(localPlayer, 0)
            setElementPosition(localPlayer, 1948.875, -1713.143, 13.547)
        end
        guiSetInputMode("allow_binds")
    end
end
bindKey("f4", "down", toggleSkinShop)

addEventHandler("onClientKey", root, function(button, press)
    if not isSkinShopActive or not press then return end

    if button == "1" then
        currentShopTab, currentSkinIdx = "BUY", 1
        updatePreview()
    elseif button == "2" then
        currentShopTab, currentSkinIdx = "OWNED", 1
        updatePreview()
    elseif button == "3" then
        currentShopTab, currentSkinIdx = "EFFECT", 1
        -- az aktív effekten nyíljon meg
        local active = getActiveEffect()
        for i, e in ipairs(EffectMenuList) do if e.key == active then currentSkinIdx = i end end
        updatePreview()
    elseif button == "4" then
        -- Fegyver skinek: a ttt-weaponskin saját előnézeti menüje
        cancelEvent()
        local wsRes = getResourceFromName("ttt-weaponskin")
        if wsRes and getResourceState(wsRes) == "running" then
            toggleSkinShop()
            exports["ttt-weaponskin"]:toggleWeaponSkinMenu()
        else
            outputChatBox("#d9534f[Hiba] #ffffffA fegyverskin menü jelenleg nem elérhető!", 255, 255, 255, true)
        end
    elseif button == "arrow_left" or button == "a" or button == "arrow_right" or button == "d" then
        cancelEvent()
        local count = (currentShopTab == "BUY") and #SkinList or (currentShopTab == "EFFECT") and #EffectMenuList or #ownedList
        if count > 0 then
            local dir = (button == "arrow_left" or button == "a") and -1 or 1
            currentSkinIdx = ((currentSkinIdx - 1 + dir) % count) + 1
            updatePreview()
        end
    elseif button == "space" and currentShopTab == "EFFECT" then
        cancelEvent()
        local e = EffectMenuList[currentSkinIdx]
        if not e then return end
        local active = getActiveEffect()
        if e.key == "none" or active == e.key then
            if active then triggerServerEvent("ttt:setEffect", localPlayer, "none") end
        elseif isEffectOwned(e.key) then
            triggerServerEvent("ttt:setEffect", localPlayer, e.key)
        else
            outputChatBox("#f1c40f[Effekt] #ffffffEz még nincs meg! Az #00c3ffF3 #ffffffshop #00c3ffEFFEKTEK #fffffffülén veheted meg ($" .. e.price .. ").", 255, 255, 255, true)
        end
    elseif button == "space" then
        cancelEvent()
        local id = getCurrentSkinID()
        if id then
            local alreadyOwned = ownedSkins[id] ~= nil or (SkinByID[id] and SkinByID[id][2] == 0)
            triggerServerEvent("ttt:buySkin", localPlayer, id)
            if not alreadyOwned then toggleSkinShop() end
        end
    elseif button == "escape" then
        cancelEvent()
        toggleSkinShop()
    end
end)

-- Effekt váltás/vásárlás után frissüljön az előnézet (ha nyitva a menü)
addEventHandler("ttt:onEffectsChanged", root, function()
    if isSkinShopActive and currentShopTab ~= "EFFECT" then updatePreview() end
end)
