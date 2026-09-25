local screenW, screenH = guiGetScreenSize()
local isSkinShopActive = false
local currentSkinIdx = 1
local currentShopTab = "BUY"   -- "BUY" vagy "OWNED"
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
    {"darth_maul", 24}, {"Ezio", 25}, {"Chiss", 27}, {"Gran", 28}, {"Weequay", 29}, {"clay", 248},
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
    if currentShopTab == "BUY" then
        return SkinList[currentSkinIdx][3]
    end
    return ownedList[currentSkinIdx]
end

local function updatePreview()
    local id = getCurrentSkinID()
    if id and isElement(previewPed) then setElementModel(previewPed, id) end
end

local function drawSkinShop()
    local menuW, menuH = 400, 45
    local mx, my = (screenW - menuW) / 2, 40

    dxDrawRectangle(mx, my, menuW / 2 - 2, menuH, currentShopTab == "BUY" and tocolor(0, 195, 255, 220) or tocolor(0, 0, 0, 180))
    dxDrawText("VÁSÁRLÁS [1]", mx, my, mx + menuW / 2, my + menuH, tocolor(255, 255, 255), 1.2, "default-bold", "center", "center")
    dxDrawRectangle(mx + menuW / 2 + 2, my, menuW / 2, menuH, currentShopTab == "OWNED" and tocolor(0, 195, 255, 220) or tocolor(0, 0, 0, 180))
    dxDrawText("MEGVÁSÁROLVA [2]", mx + menuW / 2, my, mx + menuW, my + menuH, tocolor(255, 255, 255), 1.2, "default-bold", "center", "center")

    local displayName, priceText, isOwned
    if currentShopTab == "BUY" then
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
    dxDrawText(isOwned and "[SPACE] SKIN FELVÉTELE" or "[SPACE] VÁSÁRLÁS", bx, by + 105, bx + boxW, 0, tocolor(255, 255, 255, 150), 1, "default", "center", "top")
    dxDrawText("F4 / ESC: KILÉPÉS", bx, by + 120, bx + boxW, 0, tocolor(255, 255, 255, 80), 0.8, "default", "center", "top")
end

function toggleSkinShop()
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

        currentSkinIdx, currentShopTab = 1, "BUY"
        if isElement(previewPed) then destroyElement(previewPed) end
        previewPed = createPed(SkinList[1][3], pedPos.x, pedPos.y, pedPos.z)
        setElementInterior(previewPed, interiorID)
        setElementDimension(previewPed, getElementDimension(localPlayer))
        setPedRotation(previewPed, 180)

        setCameraMatrix(camPos.x, camPos.y, camPos.z, pedPos.x, pedPos.y, pedPos.z)
        guiSetInputMode("no_binds")
        addEventHandler("onClientRender", root, drawSkinShop)
    else
        removeEventHandler("onClientRender", root, drawSkinShop)
        showCursor(false)
        setElementFrozen(localPlayer, false)
        setElementAlpha(localPlayer, 255)
        setCameraTarget(localPlayer)
        if isElement(previewPed) then destroyElement(previewPed) end
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
    elseif button == "arrow_left" or button == "a" or button == "arrow_right" or button == "d" then
        cancelEvent()
        local count = (currentShopTab == "BUY") and #SkinList or #ownedList
        if count > 0 then
            local dir = (button == "arrow_left" or button == "a") and -1 or 1
            currentSkinIdx = ((currentSkinIdx - 1 + dir) % count) + 1
            updatePreview()
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
