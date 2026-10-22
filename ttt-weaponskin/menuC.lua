-----------------------------------------
-- TTT WEAPONSKIN – ELŐNÉZET / FELVÉTEL MENÜ
-- Az F4 skin menü [4] FEGYVER SKINEK füle nyitja meg (vagy /fegyverskin).
-- A ruhabolt interiorban egy forgó fegyvermodellen mutatja a skint (mindenkit, nem csak a megvetteket).
--   W/S vagy fel/le nyíl : fegyver váltása
--   A/D vagy bal/jobb    : skin váltása
--   SPACE                : felvétel (ha megvan) / vásárlás (ha nincs meg – kétszer kell megnyomni)
--   1/2/3                : vissza a skin menü többi fülére | F4 / ESC: kilépés
-----------------------------------------
local screenW, screenH = guiGetScreenSize()
local isOpen = false
local weaponIdx, skinIdx = 1, 1
local skinList = {}              -- 1. elem: "Alap" (nincs skin), utána getWeaponSkinShopList()
local previewObj = nil
local savedPos = nil
local confirmBuyKey = nil        -- "wid:key" ha egyszer már megnyomta a SPACE-t vásárláshoz
local confirmTick = 0
local openTick = 0

-- Ugyanaz a ruhabolt interior, mint a skin menüben
local INTERIOR = 5
local TARGET = {x = 210.5, y = -11.4, z = 1001.6}   -- ide kerül a fegyver közepe
local CAM_DIR = {x = 0, y = -1, z = 0.12}           -- a kamera a fegyvertől erre van

local function curWeapon() return WSkinWeapons[weaponIdx] end

local function rebuildSkinList()
    local w = curWeapon()
    skinList = {{key = "none", name = "Alap (nincs skin)", desc = "A fegyver eredeti kinézete.", price = 0, owned = true}}
    for _, e in ipairs(getWeaponSkinShopList(w[1])) do skinList[#skinList + 1] = e end
    if skinIdx > #skinList then skinIdx = 1 end
end

-- Az aktív skinre ugrik az adott fegyvernél
local function selectActiveSkin()
    local active = getActiveWeaponSkin(curWeapon()[1])
    skinIdx = 1
    for i, e in ipairs(skinList) do if e.key == active then skinIdx = i end end
end

local function updatePreviewModel()
    local w = curWeapon()
    if isElement(previewObj) then
        clearWeaponSkinPreview(previewObj)
        destroyElement(previewObj)
    end
    previewObj = createObject(w[3], TARGET.x, TARGET.y, TARGET.z)
    if not previewObj then return end
    setElementInterior(previewObj, INTERIOR)
    setElementDimension(previewObj, getElementDimension(localPlayer))
    setElementCollisionsEnabled(previewObj, false)
    setElementDoubleSided(previewObj, true)
end

local function updatePreviewSkin()
    local e = skinList[skinIdx]
    if isElement(previewObj) then setWeaponSkinPreview(previewObj, curWeapon()[1], e and e.key or "none") end
    confirmBuyKey = nil
end

-- Minden frame: a fegyver forog a saját közepe körül, a kamera a mérethez igazodik
local function updateCamera()
    if not isElement(previewObj) then return end
    local x0, y0, z0, x1, y1, z1 = getElementBoundingBox(previewObj)
    if not x0 then return end
    local cx, cy, cz = (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2
    local size = math.max(x1 - x0, y1 - y0, z1 - z0, 0.2)

    local t = (getTickCount() - openTick) / 1000
    local yaw = math.sin(t * 0.7) * 35
    local r = math.rad(yaw)
    -- a középpont elforgatva, hogy a fegyver a saját közepe körül forogjon
    local rx = cx * math.cos(r) - cy * math.sin(r)
    local ry = cx * math.sin(r) + cy * math.cos(r)
    setElementPosition(previewObj, TARGET.x - rx, TARGET.y - ry, TARGET.z - cz)
    setElementRotation(previewObj, 0, 0, yaw)

    local dist = size * 1.25 + 0.15
    setCameraMatrix(TARGET.x + CAM_DIR.x * dist, TARGET.y + CAM_DIR.y * dist, TARGET.z + CAM_DIR.z * dist,
                    TARGET.x, TARGET.y, TARGET.z, 0, 70)
end

local function drawMenu()
    updateCamera()

    -- Felső fülek (mint a skin menüben)
    local menuW, menuH = 800, 45
    local mx, my = (screenW - menuW) / 2, 40
    local tabs = {"VÁSÁRLÁS [1]", "MEGVÁSÁROLVA [2]", "EFFEKTEK [3]", "FEGYVER SKINEK [4]"}
    local tw = menuW / #tabs
    for i, label in ipairs(tabs) do
        local tx = mx + (i - 1) * tw
        dxDrawRectangle(tx + 2, my, tw - 4, menuH, i == 4 and tocolor(0, 195, 255, 220) or tocolor(0, 0, 0, 180))
        dxDrawText(label, tx, my, tx + tw, my + menuH, tocolor(255, 255, 255), 1.2, "default-bold", "center", "center")
    end

    -- Bal oldali fegyverlista
    local lx, ly, lw, lh = 40, 120, 230, 32
    dxDrawRectangle(lx, ly - 34, lw, 30, tocolor(0, 0, 0, 200))
    dxDrawText("FEGYVEREK  [W / S]", lx, ly - 34, lx + lw, ly - 4, tocolor(0, 195, 255), 1, "default-bold", "center", "center")
    for i, w in ipairs(WSkinWeapons) do
        local y = ly + (i - 1) * (lh + 2)
        local sel = (i == weaponIdx)
        dxDrawRectangle(lx, y, lw, lh, sel and tocolor(0, 195, 255, 200) or tocolor(0, 0, 0, 170))
        dxDrawText(w[2], lx + 12, y, lx + lw, y + lh, tocolor(255, 255, 255, sel and 255 or 200), 1.05, "default-bold", "left", "center")
        local active = getActiveWeaponSkin(w[1])
        if active and WSkinByKey[active] then
            dxDrawText(WSkinByKey[active].name, lx, y, lx + lw - 10, y + lh, tocolor(255, 255, 255, sel and 230 or 120), 0.85, "default", "right", "center")
        end
    end

    -- Alsó doboz
    local e = skinList[skinIdx]
    if not e then return end
    local w = curWeapon()
    local boxW, boxH = 460, 150
    local bx, by = (screenW - boxW) / 2, screenH - 190
    local accent = e.catColor and tocolor(e.catColor[1], e.catColor[2], e.catColor[3], 255) or tocolor(0, 195, 255, 255)

    dxDrawText(e.desc or "", bx - 120, by - 52, bx + boxW + 120, by - 10, tocolor(255, 255, 255, 200), 1.1, "default-bold", "center", "bottom", false, true)
    dxDrawText(skinIdx .. " / " .. #skinList .. (e.catLabel and ("   •   " .. e.catLabel:upper()) or ""), bx, by - 78, bx + boxW, by - 52, accent, 1, "default-bold", "center", "bottom")

    dxDrawRectangle(bx, by, boxW, boxH, tocolor(0, 0, 0, 220))
    dxDrawRectangle(bx, by, boxW, 4, accent)
    dxDrawText("◄ A", bx + 20, by, bx + 70, by + boxH, tocolor(255, 255, 255), 1.5, "default-bold", "left", "center")
    dxDrawText("D ►", bx + boxW - 70, by, bx + boxW - 20, by + boxH, tocolor(255, 255, 255), 1.5, "default-bold", "right", "center")
    dxDrawText(w[2]:upper(), bx, by + 14, bx + boxW, 0, tocolor(255, 255, 255, 150), 1, "default-bold", "center", "top")
    dxDrawText(e.name:upper(), bx, by + 32, bx + boxW, 0, tocolor(255, 255, 255), 1.8, "default-bold", "center", "top")

    local active = getActiveWeaponSkin(w[1])
    local isActive = (e.key == "none" and not active) or (active == e.key)
    local priceText, priceColor, hint
    if isActive then
        priceText, priceColor = "AKTÍV", tocolor(0, 195, 255)
        hint = e.key == "none" and "EZ VAN RAJTA" or "[SPACE] SKIN LEVÉTELE"
    elseif e.owned then
        priceText, priceColor, hint = (e.key == "none") and "" or "BIRTOKOLVA", tocolor(0, 195, 255), "[SPACE] FELVÉTEL"
    elseif e.available == false then
        priceText, priceColor, hint = "SZEZONON KÍVÜL", tocolor(150, 150, 150), "CSAK A SAJÁT SZEZONJÁBAN VEHETŐ MEG"
    else
        priceText, priceColor = "$" .. e.price, tocolor(46, 204, 113)
        local ck = tostring(w[1]) .. ":" .. e.key
        if confirmBuyKey == ck and getTickCount() - confirmTick < 4000 then
            hint = "NYOMD MEG ÚJRA A [SPACE]-T A VÁSÁRLÁSHOZ!"
        else
            hint = "[SPACE] VÁSÁRLÁS  (EGYENLEG: $" .. getPlayerMoney(localPlayer) .. ")"
        end
    end
    dxDrawText(priceText, bx, by + 72, bx + boxW, 0, priceColor, 1.5, "default-bold", "center", "top")
    dxDrawText(hint, bx, by + 108, bx + boxW, 0, tocolor(255, 255, 255, 170), 1, "default", "center", "top")
    dxDrawText("W/S: FEGYVER  •  A/D: SKIN  •  F4 / ESC: KILÉPÉS", bx, by + 128, bx + boxW, 0, tocolor(255, 255, 255, 80), 0.8, "default", "center", "top")
end

local function closeMenu()
    if not isOpen then return end
    isOpen = false
    removeEventHandler("onClientRender", root, drawMenu)
    if isElement(previewObj) then
        clearWeaponSkinPreview(previewObj)
        destroyElement(previewObj)
    end
    previewObj = nil
    showCursor(false)
    setElementFrozen(localPlayer, false)
    setElementAlpha(localPlayer, 255)
    setCameraTarget(localPlayer)
    if savedPos then
        setElementInterior(localPlayer, savedPos.int)
        setElementDimension(localPlayer, savedPos.dim)
        setElementPosition(localPlayer, savedPos.x, savedPos.y, savedPos.z)
    end
    savedPos = nil
    guiSetInputMode("allow_binds")
end

local function openMenu()
    if isOpen or isPedDead(localPlayer) then return end
    if getElementData(localPlayer, "tttRole") then
        return outputChatBox("#d9534f[Fegyverskin] #ffffffKör közben nem nyithatod meg a skin menüt!", 255, 255, 255, true)
    end
    isOpen = true
    local x, y, z = getElementPosition(localPlayer)
    savedPos = {x = x, y = y, z = z, int = getElementInterior(localPlayer), dim = getElementDimension(localPlayer)}

    showCursor(true)
    setElementFrozen(localPlayer, true)
    setElementInterior(localPlayer, INTERIOR)
    setElementAlpha(localPlayer, 0)
    setElementPosition(localPlayer, 210.5, -8.5, 1001.5 - 5)

    -- a kezében lévő fegyveren nyíljon meg, ha az a listában van
    weaponIdx = 1
    local held = getPedWeapon(localPlayer)
    if WSkinWeaponByID[held] then weaponIdx = WSkinWeaponByID[held].index end
    openTick = getTickCount()
    rebuildSkinList()
    selectActiveSkin()
    updatePreviewModel()
    updatePreviewSkin()

    guiSetInputMode("no_binds")
    addEventHandler("onClientRender", root, drawMenu)
end

function toggleWeaponSkinMenu()
    if isOpen then closeMenu() else openMenu() end
end
function isWeaponSkinMenuOpen() return isOpen end
addCommandHandler("fegyverskin", toggleWeaponSkinMenu)

-- vissza a ttt-skin menübe egy adott fülre
local function backToSkinMenu(tab)
    closeMenu()
    local res = getResourceFromName("ttt-skin")
    if res and getResourceState(res) == "running" then
        exports["ttt-skin"]:toggleSkinShop(tab)
    end
end

addEventHandler("onClientKey", root, function(button, press)
    if not isOpen or not press then return end

    if button == "1" then return backToSkinMenu("BUY")
    elseif button == "2" then return backToSkinMenu("OWNED")
    elseif button == "3" then return backToSkinMenu("EFFECT")
    elseif button == "escape" or button == "f4" then
        cancelEvent()
        -- a ttt-skin F4 bindje ne nyissa újra rögtön a skin menüt
        return setTimer(closeMenu, 50, 1)
    end

    if button == "w" or button == "arrow_u" or button == "s" or button == "arrow_d" or button == "mouse_wheel_up" or button == "mouse_wheel_down" then
        cancelEvent()
        local dir = (button == "w" or button == "arrow_u" or button == "mouse_wheel_up") and -1 or 1
        weaponIdx = ((weaponIdx - 1 + dir) % #WSkinWeapons) + 1
        rebuildSkinList()
        selectActiveSkin()
        updatePreviewModel()
        updatePreviewSkin()
    elseif button == "a" or button == "arrow_l" or button == "d" or button == "arrow_r" then
        cancelEvent()
        local dir = (button == "a" or button == "arrow_l") and -1 or 1
        skinIdx = ((skinIdx - 1 + dir) % #skinList) + 1
        updatePreviewSkin()
    elseif button == "mouse1" then
        -- kattintás a bal oldali fegyverlistára
        local cx, cy = getCursorPosition()
        if not cx then return end
        cx, cy = cx * screenW, cy * screenH
        for i = 1, #WSkinWeapons do
            local y = 120 + (i - 1) * 34
            if cx >= 40 and cx <= 270 and cy >= y and cy <= y + 32 then
                weaponIdx = i
                rebuildSkinList()
                selectActiveSkin()
                updatePreviewModel()
                updatePreviewSkin()
                return
            end
        end
    elseif button == "space" then
        cancelEvent()
        local e, w = skinList[skinIdx], curWeapon()
        if not e then return end
        local active = getActiveWeaponSkin(w[1])
        if e.key == "none" then
            if active then triggerServerEvent("ttt:setWeaponSkin", localPlayer, w[1], "none") end
        elseif active == e.key then
            triggerServerEvent("ttt:setWeaponSkin", localPlayer, w[1], "none")
        elseif e.owned then
            triggerServerEvent("ttt:setWeaponSkin", localPlayer, w[1], e.key)
        elseif e.available ~= false then
            local ck = tostring(w[1]) .. ":" .. e.key
            if confirmBuyKey == ck and getTickCount() - confirmTick < 4000 then
                confirmBuyKey = nil
                triggerServerEvent("ttt:buyWeaponSkin", localPlayer, w[1], e.key)
            else
                confirmBuyKey, confirmTick = ck, getTickCount()
            end
        end
    end
end)

-- vásárlás / felvétel után frissüljön a lista (a kiválasztott skin maradjon)
addEventHandler("ttt:onWeaponSkinsChanged", root, function()
    if not isOpen then return end
    local key = skinList[skinIdx] and skinList[skinIdx].key
    rebuildSkinList()
    for i, e in ipairs(skinList) do if e.key == key then skinIdx = i end end
end)

-- Ha meghal vagy elindul a kör, zárjuk be
addEventHandler("onClientPlayerWasted", localPlayer, closeMenu)
addEventHandler("onClientElementDataChange", localPlayer, function(dataName)
    if dataName == "tttRole" and getElementData(localPlayer, "tttRole") then closeMenu() end
end)
addEventHandler("onClientResourceStop", resourceRoot, closeMenu)
