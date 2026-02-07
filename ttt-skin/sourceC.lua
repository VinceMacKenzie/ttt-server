local screenW, screenH = guiGetScreenSize()
local isSkinShopActive = false
local currentSkinIdx = 1
local currentShopTab = "BUY" -- "BUY" vagy "OWNED"
local ownedSkins = {} -- Tároljuk az adatokat: {[id] = "Skin Neve"}

-- SKIN LISTA: {"Név", Ár, SkinID}
local skinList = {
    {"basic", 0, 0}, 
    {"basic", 500, 1},
    {"Basic Guard", 1500, 71},
    {"Mafia Boss", 5000, 113},
    {"Swat Team", 3000, 285},
    {"Agent", 4500, 165},
    {"Darth Maul", 20000, 24},
    {"Ezio Auditore", 25000, 25},
    {"Chiss", 1000, 27},
    {"Gran", 1000, 28},
    {"Weequay", 1000, 29},
}

-- Interior 5 (Ruhabolt)
local interiorID = 5
local pedPos = {x = 210.5, y = -8.5, z = 1001.5}
local camPos = {x = 210.5, y = -13.5, z = 1001.5}
local previewPed = nil

-- Modellspecifikus adatok dinamikus betöltése
local replaceableSkins = {
    {"darth_maul", 24},
    {"Ezio", 25},
    {"Chiss", 27},
    {"Gran", 28},
    {"Weequay", 29},
    {"Clay", 248},
}

-- --- SEGÉDFÜGGVÉNYEK AZ EGYEDI NEVEKHEZ ---
function getSkinNameByID(id)
    -- 1. ELSŐDLEGES: Megnézzük, hogy a szervertől kapott táblában van-e név az ID-hez
    -- Mivel az SQL-edben ott a "Motoros", ez az ág fog lefutni a 181-es ID-nél.
    if ownedSkins[id] and type(ownedSkins[id]) == "string" then
        return ownedSkins[id]
    end

    -- 2. MÁSODLAGOS: Ha nincs az SQL táblában (pl. most vette meg), nézzük meg a skinList-ben
    for _, v in ipairs(skinList) do
        if v[3] == id then return v[1] end
    end

    -- 3. VÉGSZÜKSÉG: Ha sehol nincs név
    return "ISMERETLEN #" .. id
end

function getOwnedSkinList()
    local list = {}
    for id, data in pairs(ownedSkins) do
        -- Akkor vesszük bele, ha az értéke nem false/nil
        if data then
            table.insert(list, id)
        end
    end
    table.sort(list) 
    return list
end
-- -----------------------------------------

addEventHandler("onClientResourceStart", resourceRoot, function()
    for _, data in ipairs(replaceableSkins) do
        local name, id = data[1], data[2]
        if fileExists("skins/"..name..".txd") then
            local txd = engineLoadTXD("skins/"..name..".txd")
            engineImportTXD(txd, id)
        end
        if fileExists("skins/"..name..".dff") then
            local dff = engineLoadDFF("skins/"..name..".dff")
            engineReplaceModel(dff, id)
        end
    end
    triggerServerEvent("ttt:requestOwnedSkins", localPlayer)
end)

-- Amikor megkapjuk a szervertől: {[id] = "Név", [id2] = "Név2"}
addEvent("ttt:receiveOwnedSkins", true)
addEventHandler("ttt:receiveOwnedSkins", root, function(ownedTable)
    ownedSkins = ownedTable or {}
end)

addEvent("ttt:addOwnedSkinToClient", true)
addEventHandler("ttt:addOwnedSkinToClient", root, function(id, name)
    ownedSkins[id] = name or "Ismeretlen Skin"
end)

function toggleSkinShop()
    if isPedDead(localPlayer) then return end
    isSkinShopActive = not isSkinShopActive
    
    if isSkinShopActive then
        showCursor(true)
        setElementFrozen(localPlayer, true)
        setElementInterior(localPlayer, interiorID)
        setElementAlpha(localPlayer, 0)
        setElementPosition(localPlayer, pedPos.x, pedPos.y, pedPos.z - 5)
        
        currentSkinIdx = 1
        currentShopTab = "BUY"
        
        if isElement(previewPed) then destroyElement(previewPed) end
        previewPed = createPed(skinList[currentSkinIdx][3], pedPos.x, pedPos.y, pedPos.z)
        setElementInterior(previewPed, interiorID)
        setElementDimension(previewPed, getElementDimension(localPlayer))
        setPedRotation(previewPed, 180) 
        
        setCameraMatrix(camPos.x, camPos.y, camPos.z, pedPos.x, pedPos.y, pedPos.z)
        guiSetInputMode("no_binds") 
    else
        showCursor(false)
        setElementFrozen(localPlayer, false)
        setElementAlpha(localPlayer, 255)
        setCameraTarget(localPlayer)
        setElementInterior(localPlayer, 0)
        if isElement(previewPed) then destroyElement(previewPed) end
        setElementPosition(localPlayer, 1462.5, -1134.5, 23.8)
        guiSetInputMode("allow_binds")
    end
end
bindKey("f4", "down", toggleSkinShop)

addEventHandler("onClientRender", root, function()
    if not isSkinShopActive then return end

    local menuW, menuH = 400, 45
    local mx, my = (screenW - menuW) / 2, 40
    
    dxDrawRectangle(mx, my, menuW/2 - 2, menuH, currentShopTab == "BUY" and tocolor(0, 195, 255, 220) or tocolor(0, 0, 0, 180))
    dxDrawText("VÁSÁRLÁS [1]", mx, my, mx + menuW/2, my + menuH, tocolor(255, 255, 255), 1.2, "default-bold", "center", "center")
    
    dxDrawRectangle(mx + menuW/2 + 2, my, menuW/2, menuH, currentShopTab == "OWNED" and tocolor(0, 195, 255, 220) or tocolor(0, 0, 0, 180))
    dxDrawText("MEGVÁSÁROLVA [2]", mx + menuW/2, my, mx + menuW, my + menuH, tocolor(255, 255, 255), 1.2, "default-bold", "center", "center")

    local displayID, displayName, priceText, isOwned
    
    if currentShopTab == "BUY" then
        local data = skinList[currentSkinIdx]
        displayID = data[3]
        displayName = data[1] == "basic" and "SKIN: #"..displayID or data[1]:upper()
        isOwned = ownedSkins[displayID] and true or false
        priceText = isOwned and "MEGVÁSÁROLVA" or "$" .. data[2]
    else
        local ownedList = getOwnedSkinList()
        if #ownedList > 0 then
            displayID = ownedList[currentSkinIdx] or ownedList[1]
            displayName = getSkinNameByID(displayID):upper()
            priceText = "BIRTOKOLVA"
            isOwned = true
        else
            displayName = "NINCS MEGVETT SKIN"
            priceText = "-"
            displayID = 0
            isOwned = false
        end
    end
    
    local boxW, boxH = 400, 140
    local bx, by = (screenW - boxW) / 2, screenH - 180
    
    dxDrawRectangle(bx, by, boxW, boxH, tocolor(0, 0, 0, 220))
    dxDrawRectangle(bx, by, boxW, 4, tocolor(0, 195, 255, 255))
    
    dxDrawText("◄ A", bx + 20, by, bx + 70, by + boxH, tocolor(255, 255, 255), 1.5, "default-bold", "left", "center")
    dxDrawText("D ►", bx + boxW - 70, by, bx + boxW - 20, by + boxH, tocolor(255, 255, 255), 1.5, "default-bold", "right", "center")
    
    dxDrawText(displayName, bx, by + 25, bx + boxW, 0, tocolor(255, 255, 255), 1.8, "default-bold", "center", "top")
    dxDrawText(priceText, bx, by + 65, bx + boxW, 0, isOwned and tocolor(0, 195, 255) or tocolor(46, 204, 113), 1.5, "default-bold", "center", "top")
    
    local footerMsg = isOwned and "[SPACE] SKIN FELVÉTELE" or "[SPACE] VÁSÁRLÁS"
    dxDrawText(footerMsg, bx, by + 105, bx + boxW, 0, tocolor(255, 255, 255, 150), 1, "default", "center", "top")
end)

addEventHandler("onClientKey", root, function(button, press)
    if not isSkinShopActive or not press then return end

    if button == "1" then
        currentShopTab = "BUY"
        currentSkinIdx = 1
        if isElement(previewPed) then setElementModel(previewPed, skinList[currentSkinIdx][3]) end
    elseif button == "2" then
        currentShopTab = "OWNED"
        currentSkinIdx = 1
        local ownedList = getOwnedSkinList()
        if #ownedList > 0 and isElement(previewPed) then
            setElementModel(previewPed, ownedList[currentSkinIdx])
        end
    end

    if button == "arrow_left" or button == "a" then
        cancelEvent()
        if currentShopTab == "BUY" then
            currentSkinIdx = currentSkinIdx <= 1 and #skinList or currentSkinIdx - 1
            if isElement(previewPed) then setElementModel(previewPed, skinList[currentSkinIdx][3]) end
        else
            local ownedList = getOwnedSkinList()
            if #ownedList > 0 then
                currentSkinIdx = currentSkinIdx <= 1 and #ownedList or currentSkinIdx - 1
                if isElement(previewPed) then setElementModel(previewPed, ownedList[currentSkinIdx]) end
            end
        end
    elseif button == "arrow_right" or button == "d" then
        cancelEvent()
        if currentShopTab == "BUY" then
            currentSkinIdx = currentSkinIdx >= #skinList and 1 or currentSkinIdx + 1
            if isElement(previewPed) then setElementModel(previewPed, skinList[currentSkinIdx][3]) end
        else
            local ownedList = getOwnedSkinList()
            if #ownedList > 0 then
                currentSkinIdx = currentSkinIdx >= #ownedList and 1 or currentSkinIdx + 1
                if isElement(previewPed) then setElementModel(previewPed, ownedList[currentSkinIdx]) end
            end
        end
    elseif button == "space" then
        cancelEvent()
        local sID, sName, sPrice, sOwned
        
        if currentShopTab == "BUY" then
            local data = skinList[currentSkinIdx]
            sID, sName, sPrice, sOwned = data[3], data[1], data[2], (ownedSkins[data[3]] and true or false)
        else
            local ownedList = getOwnedSkinList()
            if #ownedList > 0 then
                sID = ownedList[currentSkinIdx]
                sName = getSkinNameByID(sID)
                sPrice = 0
                sOwned = true
            end
        end
        
        if sID then
            triggerServerEvent("ttt:buySkin", localPlayer, sName, sPrice, sID, sOwned)
            if not sOwned then toggleSkinShop() end
        end
    end
end)