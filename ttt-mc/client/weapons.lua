--[[
    Fegyverek a kliensen:
    - "[F] Felvétel" csere megerősítése: ha a földön lévő fegyver kategóriájában (fő fegyver / pisztoly) már van nálad
      egy másik, nem veszed fel automatikusan; F-re cseréled (a régi a földre kerül a lőszerével).
    - Q (Config.DROP_KEY): a kézben lévő fegyver eldobása. A GTA ezen a gombon lévő fegyverváltását (alapból
      "előző fegyver") ilyenkor nem engedjük lefutni; az egérgörgő és az E továbbra is vált.
]]

WeaponsC = { target = nil }

local sx, sy = guiGetScreenSize()
local GROUP_OF = { [2] = 2, [3] = 1, [4] = 1, [5] = 1, [6] = 1, [7] = 1 }
local GROUPS = { { 3, 4, 5, 6, 7 }, { 2 } }

local function blocked()
    return isPedDead(localPlayer) or isCursorShowing() or isChatBoxInputActive() or isConsoleActive()
        or guiGetInputEnabled() or isMTAWindowActive() or isPedInVehicle(localPlayer)
end

-- the weapon in hand you would give up for weapon w (nil = it would simply be picked up)
local function conflict(w)
    if not Config.WEAPON_LIMIT then return nil end
    local s = getSlotFromWeapon(w)
    local g = s and GROUP_OF[s]
    if not g then return nil end
    for _, slot in ipairs(GROUPS[g]) do
        local have = getPedWeapon(localPlayer, slot)
        if have and have > 0 and have ~= w then return have end
    end
    return nil
end

-- the nearest weapon on the ground that needs a confirmed swap
function WeaponsC.find()
    if isPedDead(localPlayer) or isPedInVehicle(localPlayer) then return nil end
    local x, y, z = getElementPosition(localPlayer)
    local dim = getElementDimension(localPlayer)
    local best, bestD
    for _, pk in ipairs(getElementsByType("pickup", root, true)) do
        if getElementData(pk, "mc.pickup") and getPickupType(pk) == 2 and getElementDimension(pk) == dim then
            local px, py, pz = getElementPosition(pk)
            local d = getDistanceBetweenPoints3D(x, y, z - 0.5, px, py, pz)
            if d < 1.6 and (not bestD or d < bestD) then
                local w = getPickupWeapon(pk)
                local old = conflict(w)
                if old then best, bestD = { pk = pk, w = w, old = old }, d end
            end
        end
    end
    return best
end

-- F (called from client/player.lua's use key, after doors / buttons / blocks)
function WeaponsC.tryTake()
    if blocked() or isElementFrozen(localPlayer) then return false end
    local t = WeaponsC.find()
    if not t then return false end
    triggerServerEvent("mc:takeWeapon", resourceRoot, t.pk)
    return true
end

addEventHandler("onClientRender", root, function()
    WeaponsC.target = nil
    if not Config.USE_HINTS or isPedDead(localPlayer) or MC_USE_BUSY then return end
    local t = WeaponsC.find()
    WeaponsC.target = t
    if not t then return end
    local txt = "[" .. Config.USE_KEY:upper() .. "] Felvétel: " .. tostring(getWeaponNameFromID(t.w)) ..
        "   (helyette eldobod: " .. tostring(getWeaponNameFromID(t.old)) .. ")"
    dxDrawText(txt, sx / 2 + 1, sy * 0.62 + 1, sx / 2 + 1, sy * 0.62 + 1, tocolor(0, 0, 0, 220), 1.15, "default-bold", "center", "center")
    dxDrawText(txt, sx / 2, sy * 0.62, sx / 2, sy * 0.62, tocolor(255, 255, 255, 240), 1.15, "default-bold", "center", "center")
end)

-------------------------------------------------------------------------------- Q: drop the weapon in hand
local function dropSpot()
    local x, y, z = getElementPosition(localPlayer)
    local _, _, rz = getElementRotation(localPlayer)
    local a = math.rad(rz)
    local fx, fy = -math.sin(a), math.cos(a)
    local tx, ty = x + fx * 0.9, y + fy * 0.9
    if not isLineOfSightClear(x, y, z, tx, ty, z, true, false, false, true, false, false, false, localPlayer) then
        tx, ty = x, y                                       -- wall in front: at the feet
    end
    local hit, _, _, hz = processLineOfSight(tx, ty, z, tx, ty, z - 3, true, false, false, true, false, false, false, false, localPlayer)
    local floor = hit and hz or (z - 1.0)
    return tx, ty, floor + (Config.PICKUP_HEIGHT or 0.5)
end

local function controlsOnKey(key)
    local r = {}
    for _, c in ipairs({ "previous_weapon", "next_weapon" }) do
        local keys = getBoundKeys(c)
        if type(keys) == "table" and keys[key] ~= nil then r[#r + 1] = c end
    end
    if #r == 0 then r[1] = "previous_weapon" end   -- GTA's default for Q
    return r
end

local switchedOff = {}
addEventHandler("onClientKey", root, function(key, press)
    local dk = Config.DROP_KEY
    if not dk or key ~= dk then return end
    if press then
        if blocked() then return end
        -- GTA's weapon switch on this key must not run
        cancelEvent()
        for _, c in ipairs(controlsOnKey(dk)) do
            if isControlEnabled(c) then
                toggleControl(c, false)
                switchedOff[c] = true
            end
        end
        local w = getPedWeapon(localPlayer)
        local slot = w and getSlotFromWeapon(w)
        if w and w > 0 and slot and slot >= 1 and slot <= 9 then
            triggerServerEvent("mc:dropWeapon", resourceRoot, w, dropSpot())
        end
    else
        setTimer(function()
            for c in pairs(switchedOff) do toggleControl(c, true) end
            switchedOff = {}
        end, 50, 1)
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    for c in pairs(switchedOff) do toggleControl(c, true) end
end)
