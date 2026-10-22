--[[
    Movement helpers for Minecraft blocks with a GTA ped.

    A GTA ped collides with three spheres (0.45 m .. 1.95 m above its feet). With 1 m blocks this gives:
      * next to a 1 block step the middle sphere "stands" on the block's edge (the player is lifted a bit),
      * when leaving a block's edge the ped can hang half inside the block or get wedged in a falling pose,
      * jumping onto a 1 block step often turns into GTA's slow ledge-climb, and a 1 block high bank can
        hardly be climbed from the water.
    Source (GMod) uses a box: you jump onto a block, you walk off an edge. This file does the same:
      * jump in front of a step 0.55 .. 1.6 m high  -> a short hop onto it (GTA's jump/climb is not used there)
      * swim against a bank                         -> climb out of the water
      * standing / hanging on an edge               -> moved off it (or onto the block when walking onto it)
      * wedged in the air for a moment              -> pushed free, after 1.5 s put onto the nearest floor
]]

Move = { hop = nil, jumpOff = false, ledge = nil, stuckT = 0, waterT = 0, keys = {} }

local FEET = PED_CENTER or 1.0
local CLEAR_H = 1.95            -- ped height

local function ray(x1, y1, z1, x2, y2, z2)
    local hit, hx, hy, hz = processLineOfSight(x1, y1, z1, x2, y2, z2, true, false, false, true, false, false, false, false, localPlayer)
    return hit, hz, hx, hy
end

local function clear(x1, y1, z1, x2, y2, z2)
    return isLineOfSightClear(x1, y1, z1, x2, y2, z2, true, false, false, true, false, false, false, localPlayer)
end

local function groundAt(x, y, zTop, zBottom)
    local hit, hz = ray(x, y, zTop, x, y, zBottom)
    if hit then return hz end
end

local function facing()
    local _, _, rz = getElementRotation(localPlayer)
    local a = math.rad(rz)
    return -math.sin(a), math.cos(a)
end

local function moving()
    return getPedControlState(localPlayer, "forwards") or getPedControlState(localPlayer, "backwards")
        or getPedControlState(localPlayer, "left") or getPedControlState(localPlayer, "right")
end

-- a step in front of the ped whose top is base+minH .. base+maxH, with room to stand on it
local function ledgeAhead(x, y, z, fx, fy, base, minH, maxH, maxD, noShin)
    for d = 0.3, maxD, 0.15 do
        local px, py = x + fx * d, y + fy * d
        local gz = groundAt(px, py, base + maxH + 0.4, base + minH - 0.3)
        if gz then
            if gz > base + maxH then return nil end                -- too high (wall)
            if gz >= base + minH then
                -- something in the way at shin height (it really is a step, not a slope we can walk)
                if not noShin and clear(x, y, base + 0.3, px, py, base + 0.3) then return nil end
                -- the top must be free for a standing ped, also straight above us to rise
                local tx, ty = x + fx * (d + 0.3), y + fy * (d + 0.3)
                local tg = groundAt(tx, ty, gz + 0.5, gz - 0.3)
                if not tg or math.abs(tg - gz) > 0.2 then return nil end
                if not clear(tx, ty, gz + 0.1, tx, ty, gz + CLEAR_H) then return nil end
                if not clear(x, y, z, x, y, gz + CLEAR_H) then return nil end
                return tx, ty, gz
            end
        end
    end
    return nil
end

-------------------------------------------------------------------------------- hop onto a step
local function startHop(tx, ty, top)
    local x, y, z = getElementPosition(localPlayer)
    Move.hop = { t = 0, dur = 0.3, sx = x, sy = y, sz = z, tx = tx, ty = ty, tz = top + FEET + 0.03 }
end

local function updateHop(dt)
    local h = Move.hop
    h.t = h.t + dt
    local t = math.min(1, h.t / h.dur)
    -- up first, then forward (never through the block's edge)
    local up = math.min(1, t / 0.55)
    up = 1 - (1 - up) * (1 - up)
    local fw = math.max(0, (t - 0.3) / 0.7)
    fw = fw * fw * (3 - 2 * fw)
    local z = h.sz + (h.tz + 0.12 - h.sz) * up - 0.12 * fw
    setElementPosition(localPlayer, h.sx + (h.tx - h.sx) * fw, h.sy + (h.ty - h.sy) * fw, z, false)
    setElementVelocity(localPlayer, 0, 0, 0)
    if t >= 1 then
        local fx, fy = h.tx - h.sx, h.ty - h.sy
        local l = math.sqrt(fx * fx + fy * fy)
        if l > 0.01 then setElementVelocity(localPlayer, fx / l * 0.03, fy / l * 0.03, 0) end
        Move.hop = nil
    end
end

-- GTA's own jump is switched off only while a ledge is ahead (the hop replaces it). Other resources also
-- switch controls (ttt-report: toggleAllControls while its window is open): we never switch the jump back
-- on while they have the controls locked, and never "steal" a jump that somebody else switched off.
local function setJumpOff(off)
    off = off and true or false
    if off == (Move.jumpOff or false) then return end
    if off then
        if not isControlEnabled("jump") then return end
        toggleControl("jump", false)
        Move.jumpOff = true
    else
        Move.jumpOff = false
        if isControlEnabled("forwards") then toggleControl("jump", true) end
    end
end

local function onJumpKey()
    if Move.ledge and not Move.hop and not isChatBoxInputActive() and not isConsoleActive() and not isCursorShowing()
        and not guiGetInputEnabled() and Move.active() then
        startHop(Move.ledge[1], Move.ledge[2], Move.ledge[3])
    end
end

local function bindJumpKeys()
    local keys = getBoundKeys("jump")
    if type(keys) ~= "table" then return end
    for key in pairs(keys) do
        if not Move.keys[key] then
            bindKey(key, "down", onJumpKey)
            Move.keys[key] = true
        end
    end
end
bindJumpKeys()
setTimer(bindJumpKeys, 5000, 0)

-------------------------------------------------------------------------------- block edges
-- the higher side (a step 0.7 .. 1.3 m above 'below') around the ped
local function higherSide(x, y, z, below)
    local hx, hy, n, top = 0, 0, 0, nil
    for i = 0, 7 do
        local a = i * math.pi / 4
        local dx, dy = math.cos(a), math.sin(a)
        local g = groundAt(x + dx * 0.36, y + dy * 0.36, z + 0.6, below - 0.1)
        if g and g > below + 0.7 and g < below + 1.3 then
            hx, hy, n = hx + dx, hy + dy, n + 1
            top = math.max(top or g, g)
        end
    end
    if n == 0 or n == 8 then return nil end
    local l = math.sqrt(hx * hx + hy * hy)
    if l < 0.01 then return nil end
    return hx / l, hy / l, top
end

local function push(dx, dy, speed, vzOverride)
    local vx, vy, vz = getElementVelocity(localPlayer)
    local along = vx * dx + vy * dy
    if along < speed then
        local add = speed - along
        vx, vy = vx + dx * add, vy + dy * add
    end
    setElementVelocity(localPlayer, vx, vy, vzOverride or math.min(vz, 0))
end

local function nearestFloor(x, y, z)
    local feet = z - FEET
    local best, bestScore
    local g0 = groundAt(x, y, z, z - 3.0)
    if g0 and g0 < feet - 0.3 and clear(x, y, g0 + 0.15, x, y, g0 + CLEAR_H) then return { x, y, g0 } end
    for r = 0.5, 2.0, 0.5 do
        for i = 0, 11 do
            local a = i * math.pi / 6
            local cx, cy = x + math.cos(a) * r, y + math.sin(a) * r
            local g = groundAt(cx, cy, z + 1.0, z - 3.0)
            if g and clear(cx, cy, g + 0.15, cx, cy, g + CLEAR_H) then
                local score = r + math.abs(g - feet) * 0.5
                if not bestScore or score < bestScore then best, bestScore = { cx, cy, g }, score end
            end
        end
        if best then return best end
    end
    return nil
end

-- in the air but hardly moving (wedged between blocks / on an edge, sliding down slowly), measured over
-- 0.25 s windows. During GTA's own climbing only the last resort (after 2.5 s) is used.
local function stuckCheck(x, y, z, below, dt, busy)
    local w = Move.win
    if not w then
        Move.win = { t = 0, x = x, y = y, z = z }
        return
    end
    w.t = w.t + dt
    if w.t < 0.25 then return end
    local moved = math.sqrt((x - w.x) ^ 2 + (y - w.y) ^ 2)
    local dropped = w.z - z
    if moved < 0.2 and dropped < 0.25 and math.abs(dropped) < 0.25 then
        Move.stuckT = Move.stuckT + w.t
    else
        Move.stuckT = 0
    end
    Move.win = { t = 0, x = x, y = y, z = z }
    if not busy and Move.stuckT >= 0.5 then
        local hx, hy = higherSide(x, y, z, below)
        if hx then push(-hx, -hy, 0.06, -0.05) else setElementVelocity(localPlayer, 0, 0, -0.1) end
    end
    if Move.stuckT >= (busy and 2.5 or 1.0) then
        local f = nearestFloor(x, y, z)
        if f then setElementPosition(localPlayer, f[1], f[2], f[3] + FEET + 0.02) end
        Move.stuckT = 0
    end
end

-------------------------------------------------------------------------------- per frame
-- GTA's own climbing (ledges higher than the hop) / jumping is left alone
local function busyTask()
    local t = getPedSimplestTask and getPedSimplestTask(localPlayer)
    return type(t) == "string" and (t:find("CLIMB", 1, true) or t:find("JUMP", 1, true)) and true or false
end
Move.busyTask = busyTask
Move.facing = facing
Move.moving = moving
Move.ray = ray

-- top of a ladder: step onto the block in front (as in GMod, where you just walk off the ladder)
function Move.ladderExit(dx, dy)
    if Move.hop then return true end
    local x, y, z = getElementPosition(localPlayer)
    local fx, fy = facing()
    if dx then fx, fy = dx, dy end
    local feet = z - FEET
    local tx, ty, top = ledgeAhead(x, y, z, fx, fy, feet, -0.3, 1.2, 0.9, true)
    if tx then
        startHop(tx, ty, top)
        return true
    end
    return false
end

-- the helpers only work for a normal, controllable player on the map: not while frozen (spawn arrival,
-- ttt-admin /freeze, win room hold, ttt-skin preview), in another dimension / interior (ttt-replay viewer,
-- ttt-int /int) or while another resource has the controls locked
function Move.active()
    return not isPedDead(localPlayer) and not isElementFrozen(localPlayer) and not isPedInVehicle(localPlayer)
        and getElementDimension(localPlayer) == Config.DIMENSION and getElementInterior(localPlayer) == Config.INTERIOR
        and isControlEnabled("forwards")
end

function Move.frame(dt)
    if not Move.active() then setJumpOff(false) Move.ledge, Move.hop = nil, nil Move.stuckT, Move.win = 0, nil return end
    if Move.hop then updateHop(dt) return end
    local x, y, z = getElementPosition(localPlayer)
    if not nearMap(x, y, z, 10) then setJumpOff(false) Move.ledge = nil return end
    if busyTask() then
        Move.ledge = nil
        setJumpOff(false)
        if Config.EDGE_FIX and not isElementInWater(localPlayer) and not isPedOnGround(localPlayer) then
            stuckCheck(x, y, z, groundAt(x, y, z, z - 2.5) or (z - FEET - 2.5), dt, true)
        end
        return
    end
    local feet = z - FEET
    local fx, fy = facing()
    local inWater = isElementInWater(localPlayer)
    local onGround = isPedOnGround(localPlayer)

    -- jump onto a step / climb out of the water
    Move.ledge = nil
    if Config.JUMP_ASSIST then
        if inWater then
            -- any block in front whose top is between the swimming feet and ~1.9 m above them: the shallow
            -- blocks under the surface as well as the bank itself
            local tx, ty, top = ledgeAhead(x, y, z, fx, fy, feet, 0.1, 1.9, 1.1, true)
            if tx and moving() then
                Move.waterT = Move.waterT + dt
                if Move.waterT > 0.15 then
                    Move.waterT = 0
                    startHop(tx, ty, top)
                    return
                end
            else
                Move.waterT = 0
            end
        elseif onGround then
            local tx, ty, top = ledgeAhead(x, y, z, fx, fy, feet, 0.55, 1.6, 0.9)
            if tx then Move.ledge = { tx, ty, top } end
        end
    end
    setJumpOff(Move.ledge ~= nil)

    if not Config.EDGE_FIX or inWater then Move.stuckT, Move.win = 0, nil return end
    local below = groundAt(x, y, z, z - 2.5) or (feet - 2.5)
    local lift = feet - below

    if onGround then
        Move.stuckT, Move.win = 0, nil
        if lift < 0.05 then return end
        local hx, hy, top = higherSide(x, y, z, below)
        if not hx then return end
        if lift >= 0.7 and moving() and fx * hx + fy * hy > 0.3
            and clear(x + hx * 0.3, y + hy * 0.3, top + 0.1, x + hx * 0.3, y + hy * 0.3, top + CLEAR_H) then
            -- hanging just below the top while walking onto the block: step up
            setElementPosition(localPlayer, x + hx * 0.3, y + hy * 0.3, top + FEET + 0.02, false)
            return
        end
        if lift < 0.35 then
            -- lifted by the step's edge: back onto the floor, a few cm away from the step
            setElementPosition(localPlayer, x - hx * 0.03, y - hy * 0.03, below + FEET, false)
        end
        push(-hx, -hy, 0.03)                                   -- off the edge / away from the step
        return
    end

    stuckCheck(x, y, z, below, dt, false)
end

-- leave GTA's jump alone outside the map
setTimer(function()
    if Move.jumpOff and not Move.active() then
        setJumpOff(false)
        Move.ledge, Move.hop = nil, nil
    end
end, 500, 0)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if Move.jumpOff and isControlEnabled("forwards") then toggleControl("jump", true) end
end)
