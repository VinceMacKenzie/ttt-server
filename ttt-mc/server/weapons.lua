--[[
    Fegyverek: legfeljebb 1 fő fegyver + 1 pisztoly (Config.WEAPON_LIMIT), csere megerősítéssel, eldobás Q-val

    Kategóriák (GTA slotok): pisztoly = 2 (Colt, hangtompítós, Deagle);
    fő fegyver = 3 (shotgunok), 4 (Uzi, MP5, Tec-9), 5 (AK, M4), 6 (puskák), 7 (nehézfegyverek).
    Kés / ütőfegyverek (1), gránátok (8) és a többi nem számít bele.

    - A pálya fegyverei (és az eldobott fegyverek): ha az adott kategóriában már van nálad MÁS fegyver, nem veszed fel
      automatikusan, hanem "[F] Felvétel" felirat jelenik meg; F-re cseréled: a kézben lévő a földre kerül a teljes
      lőszerével, az új a kezedbe. Üres kategóriába (vagy ugyanabból a fegyverből lőszerért) automatikusan felveszed.
    - Más forrásból kapott fegyver (ttt-shop, admin, más resource pickupja): a régi a lábad elé esik a lőszerével.
    - Q: a kézben lévő fegyver eldobása (a GTA Q-s fegyverváltása helyett; client/weapons.lua).
]]

Weapons = { snap = {}, drops = {} }

local GROUPS = { { 3, 4, 5, 6, 7 }, { 2 } }
local GROUP_OF = { [2] = 2, [3] = 1, [4] = 1, [5] = 1, [6] = 1, [7] = 1 }

local function slotOf(w) return getSlotFromWeapon(w) end

local function state(p)
    local t = {}
    for slot = 2, 7 do
        local w = getPedWeapon(p, slot)
        if w and w > 0 then t[slot] = { w, getPedTotalAmmo(p, slot) or 0 } end
    end
    return t
end

-- the weapons the player would have to give up for weapon w: { {slot, id, ammo}, ... }
function Weapons.conflicts(p, w)
    local r = {}
    local s = slotOf(w)
    local g = s and GROUP_OF[s]
    if not g or not Config.WEAPON_LIMIT then return r end
    for _, slot in ipairs(GROUPS[g]) do
        local have = getPedWeapon(p, slot)
        if have and have > 0 and have ~= w then r[#r + 1] = { slot, have, getPedTotalAmmo(p, slot) or 0 } end
    end
    return r
end

-- a weapon pickup on the ground (at x, y, z = floor level + PICKUP_HEIGHT, or at the player's feet)
function Weapons.drop(p, weapon, ammo, x, y, z)
    ammo = math.floor(tonumber(ammo) or 0)
    if ammo <= 0 then return nil end
    if not x then
        local px, py, pz = getElementPosition(p)
        x, y, z = px, py, pz - PED_CENTER + (Config.PICKUP_HEIGHT or 0.5)
    end
    local pk = createPickup(x, y, z, 2, weapon, 3600000, ammo)
    if not pk then return nil end
    setElementDimension(pk, getElementDimension(p))
    setElementInterior(pk, getElementInterior(p))
    setElementData(pk, "mc.pickup", true)
    Weapons.drops[pk] = { owner = p, t = getTickCount() }
    if Bridge and Bridge.pickups then Bridge.pickups[pk] = true end   -- cleared with the map's pickups each round
    return pk
end

local function removePickupSoon(pk)
    Weapons.drops[pk] = nil
    setTimer(function()
        if isElement(pk) then destroyElement(pk) end
        if Bridge and Bridge.pickups then Bridge.pickups[pk] = nil end
    end, 100, 1)
end

-- weapons that arrived from anywhere else (shop, admin, foreign pickups): the old one falls to the ground
function Weapons.check(p)
    if not Config.WEAPON_LIMIT or not isElement(p) then return end
    if isPedDead(p) then Weapons.snap[p] = nil return end
    local cur = state(p)
    local old = Weapons.snap[p] or {}
    for _, group in ipairs(GROUPS) do
        -- a new weapon replaced the old one in the same GTA slot: the old one falls to the ground
        for _, s in ipairs(group) do
            if old[s] and cur[s] and old[s][1] ~= cur[s][1] then Weapons.drop(p, old[s][1], old[s][2]) end
        end
        -- weapons in more than one slot of the category: keep the newest, drop the others
        local occ, newest = {}, nil
        for _, s in ipairs(group) do
            if cur[s] then
                occ[#occ + 1] = s
                if not (old[s] and old[s][1] == cur[s][1]) then newest = s end
            end
        end
        if #occ > 1 then
            local keep = newest or occ[#occ]
            for _, s in ipairs(occ) do
                if s ~= keep then
                    Weapons.drop(p, cur[s][1], cur[s][2])
                    takeWeapon(p, cur[s][1])
                    cur[s] = nil
                end
            end
        end
    end
    Weapons.snap[p] = cur
end

addEventHandler("onPickupUse", root, function(player)
    if getElementType(player) ~= "player" then return end
    local pk = source
    local ours = Bridge and Bridge.pickups and Bridge.pickups[pk]
    if ours then
        -- your own just dropped weapon is not picked up again while you stand on it
        local d = Weapons.drops[pk]
        if d and d.owner == player and getTickCount() - d.t < (Config.WEAPON_DROP_PROTECT_MS or 1500) then
            cancelEvent()
            return
        end
        -- a swap needs confirmation ([F] Felvétel, mc:takeWeapon): no automatic pickup
        if getPickupType(pk) == 2 and #Weapons.conflicts(player, getPickupWeapon(pk)) > 0 then
            cancelEvent()
            return
        end
        removePickupSoon(pk)
    end
    if not Config.WEAPON_LIMIT then return end
    -- foreign pickups: remember the exact ammo of what may be replaced, check right after
    if not isPedDead(player) then Weapons.snap[player] = state(player) end
    setTimer(Weapons.check, 50, 1, player)
end)

-- [F] Felvétel: swap the weapon in hand (same category) for the one on the ground
addEvent("mc:takeWeapon", true)
addEventHandler("mc:takeWeapon", resourceRoot, function(pk)
    local p = client
    if not p or isPedDead(p) or not isElement(pk) or getElementType(pk) ~= "pickup" then return end
    if not (Bridge and Bridge.pickups and Bridge.pickups[pk]) or getPickupType(pk) ~= 2 then return end
    if getElementDimension(pk) ~= getElementDimension(p) or getElementInterior(pk) ~= getElementInterior(p) then return end
    local px, py, pz = getElementPosition(p)
    local x, y, z = getElementPosition(pk)
    if getDistanceBetweenPoints3D(px, py, pz, x, y, z) > 2.5 then return end
    local w, ammo = getPickupWeapon(pk), getPickupAmmo(pk)
    removePickupSoon(pk)
    if isElement(pk) then setElementPosition(pk, x, y, z - 1000) end   -- nobody else can grab it meanwhile
    for _, c in ipairs(Weapons.conflicts(p, w)) do
        takeWeapon(p, c[2])
        Weapons.drop(p, c[2], c[3], x, y, z)          -- your old weapon lies where the new one was
    end
    giveWeapon(p, w, ammo, true)
    Weapons.snap[p] = state(p)
    if Bridge and Bridge.sfx then Bridge.sfx("pickup", x, y, z) end
end)

-- Q: drop the weapon in hand (x, y, z: the spot in front of the player the client found on the floor)
addEvent("mc:dropWeapon", true)
addEventHandler("mc:dropWeapon", resourceRoot, function(weapon, x, y, z)
    local p = client
    if not p or isPedDead(p) or isPedInVehicle(p) then return end
    weapon = tonumber(weapon)
    local slot = weapon and slotOf(weapon)
    if not slot or slot < 1 or slot > 9 or getPedWeapon(p, slot) ~= weapon then return end
    local ammo = getPedTotalAmmo(p, slot) or 0
    if slot == 1 then ammo = math.max(1, ammo) end              -- knife / bat
    local px, py, pz = getElementPosition(p)
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not (x and y and z) or getDistanceBetweenPoints3D(px, py, pz, x, y, z) > 2.5 then x, y, z = nil, nil, nil end
    takeWeapon(p, weapon)
    Weapons.drop(p, weapon, ammo, x, y, z)
    Weapons.snap[p] = state(p)
    if Bridge and Bridge.sfx then Bridge.sfx("drop", px, py, pz - PED_CENTER) end
end)

setTimer(function()
    if not Config.WEAPON_LIMIT then return end
    for _, p in ipairs(getElementsByType("player")) do Weapons.check(p) end
    for pk in pairs(Weapons.drops) do
        if not isElement(pk) then Weapons.drops[pk] = nil end
    end
end, 250, 0)

-- death / respawn: the weapons are gone, nothing to drop
addEventHandler("onPlayerWasted", root, function() Weapons.snap[source] = nil end)
addEventHandler("onPlayerSpawn", root, function() Weapons.snap[source] = nil end)
addEventHandler("onPlayerQuit", root, function() Weapons.snap[source] = nil end)
