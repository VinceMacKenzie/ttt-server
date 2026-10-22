--[[
    Local player interaction: +use (buttons, doors, carrying blocks), traitor buttons,
    damaging breakables (bullets + crowbar), trigger_push, Minecraft ladders.
]]

local sx, sy = guiGetScreenSize()
local myRole = "other"
local focusedButton = nil

local function dist3(x1, y1, z1, x2, y2, z2)
    return math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2 + (z1 - z2) ^ 2)
end

local function onMap()
    if getElementDimension(localPlayer) ~= Config.DIMENSION or getElementInterior(localPlayer) ~= Config.INTERIOR then
        return false
    end
    local x, y, z = getElementPosition(localPlayer)
    return nearMap(x, y, z, 40)
end

local function findObjectByUid(uid)
    for _, obj in ipairs(getElementsByType("object", resourceRoot)) do
        if getElementData(obj, "mc.uid") == uid then return obj end
    end
end

local function carriedObject()
    for _, obj in ipairs(getElementsByType("object", resourceRoot)) do
        if getElementData(obj, "mc.carrier") == localPlayer then return obj end
    end
end

addEvent("mc:role", true)
addEventHandler("mc:role", resourceRoot, function(r) myRole = r end)

-------------------------------------------------------------------------------- +use
-- What can be used (like GMod's +use): buttons / levers, doors opened by use, small blocks to carry and
-- anything with an OnPlayerUse output. The target is found with the entity's box, so invisible buttons
-- (most levers are an invisible func_button in front of the lever) and non-solid ones work too.
local USE_KIND = {}
for _, def in ipairs(MAP_ENTS) do
    local c, sf = def.classname, tonumber(def.kv.spawnflags) or 0
    local kind
    if (c == "func_button" or c == "func_rot_button") and bitAnd(sf, 1024) ~= 0 then kind = "button"
    elseif (c == "func_door" or c == "func_door_rotating") and bitAnd(sf, 256) ~= 0 then kind = "door"
    elseif c:match("^func_physbox") and def.mins and math.max(def.maxs[1] - def.mins[1], def.maxs[2] - def.mins[2],
        def.maxs[3] - def.mins[3]) <= Config.CARRY_MAX_SIZE then kind = "carry"
    end
    if not kind then
        for _, o in ipairs(def.outputs or {}) do if o[1] == "OnPlayerUse" then kind = "button" break end end
    end
    if kind and def.mins and def.maxs and def.mdl then USE_KIND[def.id] = kind end
end
local USE_TEXT = { button = "Használat", door = "Ajtó", carry = "Felvétel" }

local function rayBox(ox, oy, oz, dx, dy, dz, mn, mx)
    local tmin, tmax = 0, 1e9
    local o, d = { ox, oy, oz }, { dx, dy, dz }
    for i = 1, 3 do
        if math.abs(d[i]) < 1e-6 then
            if o[i] < mn[i] or o[i] > mx[i] then return nil end
        else
            local t1, t2 = (mn[i] - o[i]) / d[i], (mx[i] - o[i]) / d[i]
            if t1 > t2 then t1, t2 = t2, t1 end
            if t1 > tmin then tmin = t1 end
            if t2 < tmax then tmax = t2 end
            if tmin > tmax then return nil end
        end
    end
    return tmin
end

local useTarget = nil       -- { obj, kind, x, y, z }
local function findUseTarget()
    local cx, cy, cz, lx, ly, lz = getCameraMatrix()
    local dx, dy, dz = lx - cx, ly - cy, lz - cz
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
    if len < 0.001 then return nil end
    dx, dy, dz = dx / len, dy / len, dz / len
    local px, py, pz = getElementPosition(localPlayer)
    local best, bestT
    for _, obj in ipairs(getElementsByType("object", resourceRoot)) do
        local id = getElementData(obj, "mc.entid")
        local kind = id and USE_KIND[id]
        if kind and not getElementData(obj, "mc.carrier") then
            local def = MAP_ENTS[id]
            local x, y, z = getElementPosition(obj)
            local e = 0.06
            local mn = { x + def.mins[1] * SCALE - e, y + def.mins[2] * SCALE - e, z + def.mins[3] * SCALE - e }
            local mx = { x + def.maxs[1] * SCALE + e, y + def.maxs[2] * SCALE + e, z + def.maxs[3] * SCALE + e }
            local t = rayBox(cx, cy, cz, dx, dy, dz, mn, mx)
            if t and (not bestT or t < bestT) then
                local hx, hy, hz = cx + dx * t, cy + dy * t, cz + dz * t
                if dist3(px, py, pz, hx, hy, hz) <= Config.USE_RANGE + 0.3 then
                    best, bestT = { obj = obj, kind = kind, x = hx, y = hy, z = hz }, t
                end
            end
        end
    end
    if not best then return nil end
    -- not through a wall (the target box may stick a bit into the wall it is mounted on)
    local hit, hx, hy, hz, el = processLineOfSight(cx, cy, cz, best.x, best.y, best.z, true, false, false, true, false, false, false, false, localPlayer)
    if hit and el ~= best.obj and dist3(cx, cy, cz, hx, hy, hz) < bestT - 0.2 then return nil end
    return best
end

local function useAction()
    if isPedDead(localPlayer) or isCursorShowing() or isChatBoxInputActive() or isConsoleActive() or guiGetInputEnabled()
        or isMTAWindowActive() or isElementFrozen(localPlayer) then return end
    if onMap() then
        local carried = carriedObject()
        if carried then
            triggerServerEvent("mc:use", resourceRoot, getElementData(carried, "mc.uid"))
            return
        end
        local t = findUseTarget()
        if t then
            triggerServerEvent("mc:use", resourceRoot, getElementData(t.obj, "mc.uid"))
            return
        end
    end
    -- [F] Felvétel: swap the weapon in hand for the one on the ground (client/weapons.lua)
    if WeaponsC and WeaponsC.tryTake() then return end
    if not onMap() then return end
    if focusedButton and isElement(focusedButton) then
        triggerServerEvent("mc:tbutton", resourceRoot, getElementData(focusedButton, "uid"))
    end
end
bindKey(Config.USE_KEY, "down", useAction)

local function hint(txt, x, y, col)
    dxDrawText(txt, x + 1, y + 1, x + 1, y + 1, tocolor(0, 0, 0, 220), 1.15, "default-bold", "center", "center")
    dxDrawText(txt, x, y, x, y, col or tocolor(255, 255, 255, 240), 1.15, "default-bold", "center", "center")
end

MC_USE_BUSY = false   -- a door / button / block hint is shown: the weapon swap hint waits
addEventHandler("onClientRender", root, function()
    useTarget = nil
    MC_USE_BUSY = false
    if not Config.USE_HINTS or isPedDead(localPlayer) or not onMap() then return end
    local key = "[" .. Config.USE_KEY:upper() .. "] "
    if carriedObject() then
        MC_USE_BUSY = true
        hint(key .. "Lerakás  (a kemence / asztal / láda mellett: bele)", sx / 2, sy * 0.62)
        return
    end
    useTarget = findUseTarget()
    MC_USE_BUSY = useTarget ~= nil
    if useTarget then
        local scx, scy = getScreenFromWorldPosition(useTarget.x, useTarget.y, useTarget.z, 0.1)
        if scx then
            if getElementData(useTarget.obj, "mc.locked") then
                hint("Zárva", scx, scy + 18, tocolor(255, 120, 120, 240))
            else
                hint(key .. USE_TEXT[useTarget.kind], scx, scy + 18)
            end
        end
    end
end)

-------------------------------------------------------------------------------- traitor buttons (TTT overlay)
addEventHandler("onClientRender", root, function()
    focusedButton = nil
    if myRole ~= "traitor" or not onMap() or isPedDead(localPlayer) then return end
    local px, py, pz = getElementPosition(localPlayer)
    local best, bestD = nil, 70
    for _, el in ipairs(getElementsByType("mc_ent", resourceRoot)) do
        if getElementData(el, "tbutton") then
            local x, y, z = getElementData(el, "x"), getElementData(el, "y"), getElementData(el, "z")
            local range = getElementData(el, "range") or 32
            local d = dist3(px, py, pz, x, y, z)
            if d <= range then
                local scx, scy = getScreenFromWorldPosition(x, y, z, 0.05)
                if scx then
                    local ready = getElementData(el, "ready")
                    local col = ready and tocolor(255, 60, 60, 220) or tocolor(120, 120, 120, 160)
                    dxDrawRectangle(scx - 9, scy - 9, 18, 18, tocolor(0, 0, 0, 150))
                    dxDrawRectangle(scx - 6, scy - 6, 12, 12, col)
                    local sd = math.sqrt((scx - sx / 2) ^ 2 + (scy - sy / 2) ^ 2)
                    if ready and sd < bestD then best, bestD = el, sd end
                end
            end
        end
    end
    if best then
        focusedButton = best
        local x, y, z = getElementData(best, "x"), getElementData(best, "y"), getElementData(best, "z")
        local scx, scy = getScreenFromWorldPosition(x, y, z, 0.05)
        if scx then
            local txt = "[" .. Config.USE_KEY:upper() .. "] " .. tostring(getElementData(best, "desc"))
            dxDrawText(txt, scx + 1, scy + 15, scx + 1, scy + 15, tocolor(0, 0, 0, 220), 1.1, "default-bold", "center", "top")
            dxDrawText(txt, scx, scy + 14, scx, scy + 14, tocolor(255, 90, 90, 255), 1.1, "default-bold", "center", "top")
        end
    end
end)

-------------------------------------------------------------------------------- damaging breakables
local lastShot = { uid = nil, t = 0 }
addEventHandler("onClientPlayerWeaponFire", localPlayer, function(weapon, ammo, clip, hx, hy, hz, hitEl)
    if hitEl and isElement(hitEl) and getElementType(hitEl) == "object" then
        local uid = getElementData(hitEl, "mc.uid")
        if uid then
            -- a shotgun shot counts once, however many of its pellets hit the block
            local now = getTickCount()
            if weapon >= 25 and weapon <= 27 and lastShot.uid == uid and now - lastShot.t < 150 then return end
            lastShot.uid, lastShot.t = uid, now
            -- Source (GMod TTT) damage per shot: a shotgun shot is all its pellets at once
            local dmg = Config.BREAK_DAMAGE[weapon] or tonumber(getWeaponProperty(weapon, "pro", "damage")) or 10
            triggerServerEvent("mc:damage", resourceRoot, uid, dmg, weapon)
        end
    end
end)

-- melee (crowbar / fist): onClientPlayerWeaponFire is not triggered for melee weapons
local wasFiring = false
addEventHandler("onClientRender", root, function()
    local firing = getPedControlState(localPlayer, "fire")
    if firing and not wasFiring and not isPedDead(localPlayer) and getPedWeaponSlot(localPlayer) <= 1 then
        setTimer(function()
            if isPedDead(localPlayer) then return end
            local x, y, z = getElementPosition(localPlayer)
            local _, _, rz = getElementRotation(localPlayer)
            local a = math.rad(rz)
            local fx, fy = -math.sin(a), math.cos(a)
            for _, dz in ipairs({ 0.4, 0.0, -0.5 }) do
                local hit, hx, hy, hz, el = processLineOfSight(x, y, z + dz, x + fx * 1.6, y + fy * 1.6, z + dz,
                    true, false, false, true, false, false, false, false, localPlayer)
                if hit and el and isElement(el) and getElementData(el, "mc.uid") then
                    triggerServerEvent("mc:damage", resourceRoot, getElementData(el, "mc.uid"), Config.MELEE_DAMAGE,
                        getPedWeapon(localPlayer))
                    return
                end
            end
        end, 250, 1)
    end
    wasFiring = firing
end)

-------------------------------------------------------------------------------- trigger_push (client physics)
local pushCache = {}
local function pushData(el)
    local id = getElementData(el, "id")
    local c = pushCache[id]
    if not c then
        local def = MAP_ENTS[id]
        local ox, oy, oz = vec3(def.kv.origin)
        local p, y = vec3(def.kv.pushdir)
        local dx, dy, dz = anglesToForward(p, y)
        local sf = tonumber(def.kv.spawnflags) or 0
        c = { def = def, ox = ox, oy = oy, oz = oz, dx = dx, dy = dy, dz = dz,
              players = bitAnd(sf, 1) ~= 0 or bitAnd(sf, 64) ~= 0 }
        pushCache[id] = c
    end
    return c
end

local ladderCache = nil
local function ladderBoxes()
    if not ladderCache then
        ladderCache = {}
        for _, l in ipairs(MAP_DATA.ladders) do
            -- the ladder brush is a thin plate on the wall: its thin axis is the wall normal
            local thin = (l.maxs[1] - l.mins[1] <= l.maxs[2] - l.mins[2]) and 1 or 2
            ladderCache[#ladderCache + 1] = { mins = { l.mins[1] - 10, l.mins[2] - 10, l.mins[3] - 4 },
                                              maxs = { l.maxs[1] + 10, l.maxs[2] + 10, l.maxs[3] + 8 },
                                              thin = thin, mid = (l.mins[thin] + l.maxs[thin]) / 2 }
        end
    end
    return ladderCache
end

-- returns the ladder's top (Source units) and the outward wall normal (the player is on the open side)
local function onLadder(px, py, pz)
    for _, b in ipairs(ladderBoxes()) do
        if brushesTouch(b, 0, 0, 0, px, py, pz, PLAYER_MINS, PLAYER_MAXS) then
            if b.side == nil then
                -- which side of the plate is the wall: probe a short way to both sides at mid height
                local c = { (b.mins[1] + b.maxs[1]) / 2, (b.mins[2] + b.maxs[2]) / 2, (b.mins[3] + b.maxs[3]) / 2 }
                c[b.thin] = b.mid
                local hits = {}
                for _, sgn in ipairs({ 1, -1 }) do
                    local q = { c[1], c[2], c[3] }
                    q[b.thin] = q[b.thin] + sgn * 12
                    local x1, y1, z1 = toWorld(c[1], c[2], c[3])
                    local x2, y2, z2 = toWorld(q[1], q[2], q[3])
                    hits[sgn] = processLineOfSight(x1, y1, z1, x2, y2, z2, true, false, false, true, false, false, false, false, localPlayer) and true or false
                end
                if hits[1] and not hits[-1] then b.side = -1
                elseif hits[-1] and not hits[1] then b.side = 1
                else b.side = false end
            end
            local n = { 0, 0 }
            n[b.thin] = b.side or (((b.thin == 1 and px or py) >= b.mid) and 1 or -1)
            return b.maxs[3] - 8, n
        end
    end
    for _, el in ipairs(getElementsByType("mc_ent", resourceRoot)) do
        if getElementData(el, "cls") == "func_useableladder" and getElementData(el, "on") then
            local p0, p1 = getElementData(el, "p0"), getElementData(el, "p1")
            if p0 and p1 then
                local zmin, zmax = math.min(p0[3], p1[3]), math.max(p0[3], p1[3])
                if math.abs(px - p0[1]) < 26 and math.abs(py - p0[2]) < 26 and pz >= zmin - 8 and pz <= zmax + 8 then return zmax end
            end
        end
    end
    return false
end

addEventHandler("onClientPreRender", root, function(dtms)
    -- (frozen: spawn arrival, ttt-admin /freeze, win room hold - nothing may move the player)
    if isPedDead(localPlayer) or not onMap() or isElementFrozen(localPlayer) then return end
    local dt = math.min(0.1, dtms / 1000)
    local px, py, pz = pedSourceOrigin(localPlayer)

    -- trigger_push
    for _, el in ipairs(getElementsByType("mc_ent", resourceRoot)) do
        if getElementData(el, "cls") == "trigger_push" and getElementData(el, "enabled") then
            local c = pushData(el)
            if c.players and brushesTouch(c.def, c.ox, c.oy, c.oz, px, py, pz, PLAYER_MINS, PLAYER_MAXS) then
                local speed = (getElementData(el, "speed") or tonumber(c.def.kv.speed) or 100) * SCALE
                local vx, vy, vz = getElementVelocity(localPlayer)
                local tv = speed / 50
                local along = vx * c.dx + vy * c.dy + vz * c.dz
                if isPedOnGround(localPlayer) or isElementInWater(localPlayer) then
                    if math.abs(c.dz) > 0.7 then
                        setElementVelocity(localPlayer, vx, vy, c.dz * tv)
                    else
                        local x, y, z = getElementPosition(localPlayer)
                        local step = speed * dt
                        local nx, ny = x + c.dx * step, y + c.dy * step
                        if isLineOfSightClear(x, y, z, nx + c.dx * 0.4, ny + c.dy * 0.4, z, true, false, false, true, false, true, false, localPlayer) then
                            setElementPosition(localPlayer, nx, ny, z, false)
                        end
                    end
                elseif along < tv then
                    local add = math.min(tv - along, tv * dt * 8)
                    setElementVelocity(localPlayer, vx + c.dx * add, vy + c.dy * add, vz + c.dz * add)
                end
            end
        end
    end

    -- Minecraft ladders. Movement is relative to the camera (the GTA ped turning into the walking direction
    -- does not matter): towards the wall = up (at the top you step onto the block), away from the wall = down,
    -- left / right = sideways along the ladder, no keys = you stay on the ladder, jump = let go.
    local ladderTop, wallN = onLadder(px, py, pz)
    if ladderTop and not getPedControlState(localPlayer, "jump") and not (Move and Move.hop) then
        local vx, vy, vz = getElementVelocity(localPlayer)
        local ground = isPedOnGround(localPlayer)
        local v = Config.LADDER_SPEED / 50
        local fwd = (getPedControlState(localPlayer, "forwards") and 1 or 0) - (getPedControlState(localPlayer, "backwards") and 1 or 0)
        local side = (getPedControlState(localPlayer, "right") and 1 or 0) - (getPedControlState(localPlayer, "left") and 1 or 0)
        local cx, cy, cz, lx, ly, lz = getCameraMatrix()
        local cfx, cfy = lx - cx, ly - cy
        local cl = math.sqrt(cfx * cfx + cfy * cfy)
        if cl > 0.001 then cfx, cfy = cfx / cl, cfy / cl else cfx, cfy = 0, 1 end
        local crx, cry = cfy, -cfx                                         -- camera right
        local wx, wy = cfx * fwd + crx * side, cfy * fwd + cry * side      -- wished direction
        local nx, ny
        if wallN then
            nx, ny = wallN[1], wallN[2]
        else
            -- HL2 style ladder entity: the wall is where the ped looks
            local fx, fy = 0, 1
            if Move then fx, fy = Move.facing() end
            nx, ny = -fx, -fy
        end
        local into = -(wx * nx + wy * ny)                                  -- > 0: towards the wall
        local tx, ty = -ny, nx                                             -- along the wall
        local lat = wx * tx + wy * ty
        local lookDown = false
        local ll = math.sqrt((lx - cx) ^ 2 + (ly - cy) ^ 2 + (lz - cz) ^ 2)
        if ll > 0 then lookDown = (lz - cz) / ll < -0.6 end
        local up = 0
        if into > 0.3 then up = lookDown and -1 or 1 elseif into < -0.3 then up = -1 end
        local sideV = lat * v * 0.8
        if up > 0 and pz > ladderTop - 48 and Move and Move.ladderExit(-nx, -ny) then
            -- stepped off at the top
        elseif ground and up <= 0 then
            -- standing on the floor (top or bottom): normal walking, stepping off the top edge starts the descent
        elseif up ~= 0 or math.abs(lat) > 0.3 then
            setElementVelocity(localPlayer, tx * sideV - nx * 0.01, ty * sideV - ny * 0.01, up * v)
        elseif not ground then
            setElementVelocity(localPlayer, -nx * 0.005, -ny * 0.005, 0.004)       -- holding on
        end
    elseif Move then
        Move.frame(dt)
    end
end)

-------------------------------------------------------------------------------- carried block follows the view pitch
local lastAim, lastAimSent = 0, 0
addEventHandler("onClientRender", root, function()
    if not carriedObject() then return end
    local cx, cy, cz, lx, ly, lz = getCameraMatrix()
    local h = math.sqrt((lx - cx) ^ 2 + (ly - cy) ^ 2)
    local pitch = math.atan2(lz - cz, h)
    local dz = math.max(-1.1, math.min(1.0, math.tan(pitch) * 1.4 + 0.45))
    if math.abs(dz - lastAim) > 0.08 and getTickCount() - lastAimSent > 150 then
        lastAim, lastAimSent = dz, getTickCount()
        triggerServerEvent("mc:carryAim", resourceRoot, dz)
    end
end)

-------------------------------------------------------------------------------- server requests
addEvent("mc:groundQuery", true)
addEventHandler("mc:groundQuery", resourceRoot, function(uid, x, y, z)
    local obj = findObjectByUid(uid)
    local hit, hx, hy, hz = processLineOfSight(x, y, z, x, y, z - 150, true, false, false, true, false, false, false, false, obj)
    triggerServerEvent("mc:groundReply", resourceRoot, uid, hit and hz or false)
end)

-- placed on the map by the server (frozen): wait until the collision under us is streamed in
local arrival = nil
addEvent("mc:arrived", true)
addEventHandler("mc:arrived", resourceRoot, function()
    setCameraTarget(localPlayer)
    if arrival and isTimer(arrival.timer) then killTimer(arrival.timer) end
    arrival = { t0 = getTickCount() }
    arrival.timer = setTimer(function()
        if not Models.ready then return end
        local x, y, z = getElementPosition(localPlayer)
        local hit = processLineOfSight(x, y, z + 0.5, x, y, z - 4, true, false, false, true, false, false, false, false, localPlayer)
        if hit then
            killTimer(arrival.timer)
            arrival = nil
            triggerServerEvent("mc:landed", resourceRoot)
        elseif getTickCount() - arrival.t0 > 15000 then
            killTimer(arrival.timer)
            arrival = nil
            triggerServerEvent("mc:noGround", resourceRoot)   -- server picks another spawn point
        end
    end, 100, 0)
end)

addEvent("mc:teleported", true)
addEventHandler("mc:teleported", resourceRoot, function()
    setCameraTarget(localPlayer)
end)

addEvent("mc:impulse", true)
addEventHandler("mc:impulse", resourceRoot, function(ix, iy, iz)
    local vx, vy, vz = getElementVelocity(localPlayer)
    setElementVelocity(localPlayer, vx + ix, vy + iy, vz + iz)
end)

addEvent("mc:clientcommand", true)
addEventHandler("mc:clientcommand", resourceRoot, function(cmd)
    cmd = tostring(cmd):lower()
    local function toggleDuck()
        setPedControlState(localPlayer, "crouch", true)
        setTimer(function() setPedControlState(localPlayer, "crouch", false) end, 100, 1)
    end
    if cmd == "+duck" and not isPedDucked(localPlayer) then toggleDuck()
    elseif cmd == "-duck" and isPedDucked(localPlayer) then toggleDuck() end
end)
