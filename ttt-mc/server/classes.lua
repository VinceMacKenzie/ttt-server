--[[
    Behaviour of every Source entity class used by the map.
]]

local now = getTickCount
local fire = function(...) return Engine.fireOutput(...) end
local S = function() return SCALE end

local function kvnum(inst, key, default)
    local v = inst.kv[key]
    if v == nil then
        -- keyvalues are case-insensitive in Source
        local lk = string.lower(key)
        for k, val in pairs(inst.kv) do if string.lower(k) == lk then v = val break end end
    end
    return tonumber(v) or default
end

local function kvstr(inst, key, default)
    local v = inst.kv[key]
    if v == nil then
        local lk = string.lower(key)
        for k, val in pairs(inst.kv) do if string.lower(k) == lk then return val end end
        return default
    end
    return v
end

local function hasFlag(inst, f) return bitAnd(inst.spawnflags, f) ~= 0 end

-------------------------------------------------------------------------------- shared state elements
-- Client-relevant state is published through element data on a dummy element per entity
-- (synced automatically to joining players).
local function stateElement(inst, extra)
    if inst.state and isElement(inst.state) then return inst.state end
    local el = createElement("mc_ent", "mcent" .. inst.uid)
    setElementData(el, "id", inst.def.id)
    setElementData(el, "uid", inst.uid)
    setElementData(el, "cls", inst.cls)
    for k, v in pairs(extra or {}) do setElementData(el, k, v) end
    inst.state = el
    return el
end

local function setState(inst, key, value)
    if inst.state and isElement(inst.state) then setElementData(inst.state, key, value) end
end

-------------------------------------------------------------------------------- brush objects
function Engine.createObject(inst)
    local mdl = inst.def.mdl
    if not mdl then return nil end
    if inst.obj and isElement(inst.obj) then return inst.obj end
    local x, y, z = toWorld(inst.ox, inst.oy, inst.oz)
    local obj = createObject(Config.PLACEHOLDER_MODEL, x, y, z, 0, 0, 0)
    setElementDimension(obj, Config.DIMENSION)
    setElementInterior(obj, Config.INTERIOR)
    setElementData(obj, "mc.model", mdl.name)
    setElementData(obj, "mc.col", mdl.col and true or false)
    setElementData(obj, "mc.uid", inst.uid)
    setElementData(obj, "mc.cls", inst.cls)
    setElementData(obj, "mc.entid", inst.def.id)     -- e.g. the client keeps a func_water_analog's water while it exists
    local rc = inst.kv.rendercolor
    if rc and rc ~= "" and rc ~= "255 255 255" and (inst.kv.rendermode or "0") ~= "10" then
        setElementData(obj, "mc.color", rc)
    end
    inst.obj = obj
    inst.rx, inst.ry, inst.rz = 0, 0, 0
    return obj
end

function Engine.destroyObject(inst)
    if inst.obj and isElement(inst.obj) then destroyElement(inst.obj) end
    inst.obj = nil
end

-- generic brush entity with Enable/Disable visibility (func_brush & co)
-- "hold" volumes (see build.py): players inside are frozen in place while the entity exists
Engine.holds = {}
local function holdBox(inst)
    local ox, oy, oz = Engine.getOrigin(inst)
    local mn, mx = inst.def.mins, inst.def.maxs
    return ox + mn[1], oy + mn[2], oz + mn[3], ox + mx[1], oy + mx[2], oz + mx[3]
end
function Engine.holdPoll()
    local frozen = Engine.holdFrozen or {}
    Engine.holdFrozen = frozen
    local want = {}
    for inst in pairs(Engine.holds) do
        if inst.alive and inst.enabled then
            local x1, y1, z1, x2, y2, z2 = holdBox(inst)
            for _, p in ipairs(getElementsByType("player")) do
                if not isPedDead(p) and getElementDimension(p) == Config.DIMENSION
                    and getElementInterior(p) == Config.INTERIOR then
                    local x, y, z = pedSourceOrigin(p)
                    if x > x1 and x < x2 and y > y1 and y < y2 and z > z1 - 8 and z < z2 then want[p] = true end
                end
            end
        else
            Engine.holds[inst] = nil
        end
    end
    for p in pairs(want) do
        if not frozen[p] then
            -- somebody else (e.g. an admin's /freeze) already froze him: leave him frozen when the hold ends
            frozen[p] = isElementFrozen(p) and "other" or true
            setElementVelocity(p, 0, 0, 0)
            setElementFrozen(p, true)
        elseif not isElementFrozen(p) then
            -- ttt-core unfreezes everybody at the round end: the hold (a solid volume in GMod) still holds him
            setElementVelocity(p, 0, 0, 0)
            setElementFrozen(p, true)
        end
    end
    for p in pairs(frozen) do
        if not want[p] then
            local mine = frozen[p] == true
            frozen[p] = nil
            -- only if he is still on the map (ttt-core parks dead players frozen at 0,0,-100: not ours to touch)
            local px, py, pz
            if isElement(p) then px, py, pz = getElementPosition(p) end
            if px and mine and not (Arrival and Arrival.frozen[p]) and nearMap(px, py, pz, 40) then
                setElementFrozen(p, false)
                setElementVelocity(p, 0, 0, 0)
            end
        end
    end
end

local BrushToggle = {
    spawn = function(inst)
        inst.enabled = kvstr(inst, "StartDisabled", "0") ~= "1"
        if inst.def.hold then Engine.holds[inst] = true return end
        if inst.enabled then Engine.createObject(inst) end
    end,
    enable = function(inst, on)
        inst.enabled = on
        if on then Engine.createObject(inst) else Engine.destroyObject(inst) end
    end,
    inputs = {
        color = function(inst, param)
            inst.kv.rendercolor = param
            if inst.obj then setElementData(inst.obj, "mc.color", param) end
        end,
        alpha = function(inst, param)
            if inst.obj then setElementAlpha(inst.obj, math.max(0, math.min(255, tonumber(param) or 255))) end
        end,
    },
}
Classes.func_brush = BrushToggle
Classes.func_wall = BrushToggle
Classes.func_wall_toggle = BrushToggle
Classes.func_illusionary = BrushToggle
Classes.func_lod = BrushToggle

-- locked buttons / doors: the client shows "Zárva" instead of "[E] ..."
local function syncLocked(inst)
    if inst.obj and isElement(inst.obj) then setElementData(inst.obj, "mc.locked", inst.locked and true or false) end
end
Engine.syncLocked = syncLocked

-------------------------------------------------------------------------------- func_door_rotating / func_door
local function doorAxis(inst)
    if hasFlag(inst, 64) then return 1 end    -- X axis (roll)
    if hasFlag(inst, 128) then return 2 end   -- Y axis (pitch)
    return 3                                   -- Z axis (yaw)
end

local function doorCurrentAngle(inst)
    local m = inst.motion
    if not m then return inst.angle end
    local f = math.min(1, (now() - m.t0) / math.max(1, m.dur))
    return m.from + (m.to - m.from) * f
end

local function doorMoveTo(inst, target, onDone)
    local obj = inst.obj
    local cur = doorCurrentAngle(inst)
    if inst.motion and inst.motion.timer and isTimer(inst.motion.timer) then killTimer(inst.motion.timer) end
    if obj and isElement(obj) then stopObject(obj) end
    -- re-sync to the exact current angle (stopObject keeps the interpolated rotation)
    inst.angle = cur
    local speed = math.max(1, kvnum(inst, "speed", 100))
    local dur = math.max(50, math.floor(math.abs(target - cur) / speed * 1000))
    local d = target - cur
    if obj and isElement(obj) then
        local x, y, z = toWorld(inst.ox, inst.oy, inst.oz)
        local ax = inst.axis
        moveObject(obj, dur, x, y, z, ax == 1 and d or 0, ax == 2 and d or 0, ax == 3 and d or 0)
    end
    local gen = Engine.generation
    inst.motion = { from = cur, to = target, t0 = now(), dur = dur }
    inst.motion.timer = setTimer(function()
        if gen ~= Engine.generation or not inst.alive then return end
        inst.motion = nil
        inst.angle = target
        onDone()
        Engine.flush()
    end, dur, 1)
end

local function doorOpen(inst, activator)
    if inst.doorState == "open" or inst.doorState == "opening" then return end
    inst.doorState = "opening"
    local target = inst.dir * inst.distance
    -- two-way doors swing away from the activator
    if not hasFlag(inst, 16) and Engine.isPlayer(activator) and inst.axis == 3 then
        local px, py = pedSourceOrigin(activator)
        local cx = (inst.def.mins[1] + inst.def.maxs[1]) / 2
        local cy = (inst.def.mins[2] + inst.def.maxs[2]) / 2
        local best, bestd = target, -1
        for _, cand in ipairs({ inst.distance, -inst.distance }) do
            local a = math.rad(cand)
            local wx = inst.ox + cx * math.cos(a) - cy * math.sin(a)
            local wy = inst.oy + cx * math.sin(a) + cy * math.cos(a)
            local dd = (wx - px) ^ 2 + (wy - py) ^ 2
            if dd > bestd then best, bestd = cand, dd end
        end
        target = best
    end
    fire(inst, "OnOpen", activator)
    doorMoveTo(inst, target, function()
        inst.doorState = "open"
        fire(inst, "OnFullyOpen", activator)
        local wait = kvnum(inst, "wait", 4)
        if wait >= 0 and not hasFlag(inst, 32) then
            local gen = Engine.generation
            inst.closeTimer = setTimer(function()
                if gen == Engine.generation and inst.alive and inst.doorState == "open" then
                    Classes.func_door_rotating.close(inst, activator)
                end
            end, math.max(50, wait * 1000), 1)
        end
    end)
end

local function doorClose(inst, activator)
    if inst.doorState == "closed" or inst.doorState == "closing" then return end
    if inst.closeTimer and isTimer(inst.closeTimer) then killTimer(inst.closeTimer) end
    inst.doorState = "closing"
    fire(inst, "OnClose", activator)
    doorMoveTo(inst, 0, function()
        inst.doorState = "closed"
        fire(inst, "OnFullyClosed", activator)
    end)
end

Classes.func_door_rotating = {
    spawn = function(inst)
        Engine.createObject(inst)
        inst.axis = doorAxis(inst)
        inst.dir = hasFlag(inst, 2) and -1 or 1
        inst.distance = kvnum(inst, "distance", 90)
        inst.angle = 0
        inst.doorState = "closed"
        inst.locked = hasFlag(inst, 2048)
        syncLocked(inst)
        if kvnum(inst, "spawnpos", 0) == 1 or hasFlag(inst, 1) then
            -- starts open
            inst.angle = inst.dir * inst.distance
            inst.doorState = "open"
            if inst.obj then
                local ax = inst.axis
                setElementRotation(inst.obj, ax == 1 and inst.angle or 0, ax == 2 and inst.angle or 0, ax == 3 and inst.angle or 0)
            end
        end
    end,
    close = doorClose,
    open = doorOpen,
    use = function(inst, player)
        if not hasFlag(inst, 256) then return false end
        if inst.locked then fire(inst, "OnLockedUse", player) return true end
        if inst.doorState == "open" or inst.doorState == "opening" then
            if kvnum(inst, "wait", 4) == -1 or hasFlag(inst, 32) then doorClose(inst, player) end
        else
            doorOpen(inst, player)
        end
        return true
    end,
    kill = function(inst)
        if inst.motion and inst.motion.timer and isTimer(inst.motion.timer) then killTimer(inst.motion.timer) end
        if inst.closeTimer and isTimer(inst.closeTimer) then killTimer(inst.closeTimer) end
    end,
    inputs = {
        open = function(inst, p, a) doorOpen(inst, a) end,
        close = function(inst, p, a) doorClose(inst, a) end,
        toggle = function(inst, p, a)
            if inst.doorState == "open" or inst.doorState == "opening" then doorClose(inst, a) else doorOpen(inst, a) end
        end,
        lock = function(inst) inst.locked = true syncLocked(inst) end,
        unlock = function(inst) inst.locked = false syncLocked(inst) end,
        setspeed = function(inst, p) inst.kv.speed = tostring(tonumber(p) or 100) end,
    },
}
Classes.func_door = Classes.func_door_rotating

-------------------------------------------------------------------------------- func_movelinear
local function linearMove(inst, frac, activator)
    local obj = inst.obj
    local cur = inst.pos
    if inst.motion then
        local m = inst.motion
        local f = math.min(1, (now() - m.t0) / math.max(1, m.dur))
        cur = m.from + (m.to - m.from) * f
        if isTimer(m.timer) then killTimer(m.timer) end
        if obj and isElement(obj) then stopObject(obj) end
    end
    local dist = inst.movedistance
    local speed = math.max(1, kvnum(inst, "speed", 100))
    local dur = math.max(50, math.floor(math.abs(frac - cur) * dist / speed * 1000))
    if obj and isElement(obj) then
        local d = frac * dist
        moveObject(obj, dur, toWorld(inst.ox + inst.mdx * d, inst.oy + inst.mdy * d, inst.oz + inst.mdz * d))
    end
    local gen = Engine.generation
    inst.motion = { from = cur, to = frac, t0 = now(), dur = dur }
    inst.motion.timer = setTimer(function()
        if gen ~= Engine.generation or not inst.alive then return end
        inst.motion = nil
        inst.pos = frac
        if frac >= 1 then fire(inst, "OnFullyOpen", activator) elseif frac <= 0 then fire(inst, "OnFullyClosed", activator) end
        Engine.flush()
    end, dur, 1)
end

Classes.func_movelinear = {
    spawn = function(inst)
        Engine.createObject(inst)
        local p, y = vec3(inst.kv.movedir)
        inst.mdx, inst.mdy, inst.mdz = anglesToForward(p, y)
        inst.movedistance = kvnum(inst, "movedistance", 100)
        inst.pos = kvnum(inst, "startposition", 0)
        if inst.pos ~= 0 and inst.obj then
            local d = inst.pos * inst.movedistance
            setElementPosition(inst.obj, toWorld(inst.ox + inst.mdx * d, inst.oy + inst.mdy * d, inst.oz + inst.mdz * d))
        end
    end,
    inputs = {
        open = function(inst, p, a) linearMove(inst, 1, a) end,
        close = function(inst, p, a) linearMove(inst, 0, a) end,
        setposition = function(inst, p, a) linearMove(inst, math.max(0, math.min(1, tonumber(p) or 0)), a) end,
        setspeed = function(inst, p) inst.kv.speed = tostring(tonumber(p) or 100) end,
    },
}

-------------------------------------------------------------------------------- func_button
local function buttonPress(inst, activator)
    if inst.locked then
        fire(inst, "OnUseLocked", activator)
        return
    end
    if inst.pressed then return end
    fire(inst, "OnPressed", activator)
    local wait = kvnum(inst, "wait", 3)
    inst.pressed = true
    fire(inst, "OnIn", activator)
    if wait >= 0 then
        local gen = Engine.generation
        setTimer(function()
            if gen == Engine.generation and inst.alive then
                inst.pressed = false
                fire(inst, "OnOut", activator)
            end
        end, math.max(50, wait * 1000), 1)
    end
end

Classes.func_button = {
    spawn = function(inst)
        Engine.createObject(inst)
        inst.locked = hasFlag(inst, 2048)
        syncLocked(inst)
        inst.pressed = false
        inst.touchActivated = hasFlag(inst, 256)
    end,
    press = buttonPress,
    use = function(inst, player)
        if not hasFlag(inst, 1024) then return false end
        if inst.locked then
            Bridge.sfxAt("locked", inst)
        elseif string.lower(inst.kv.targetname or ""):find("chest", 1, true) then
            Bridge.sfxAt("chest", inst)
        else
            Bridge.sfxAt("click", inst)
        end
        buttonPress(inst, player)
        return true
    end,
    damage = function(inst, player, amount)
        if hasFlag(inst, 512) then
            fire(inst, "OnDamaged", player)
            buttonPress(inst, player)
        end
    end,
    inputs = {
        press = function(inst, p, a) buttonPress(inst, a) end,
        lock = function(inst) inst.locked = true syncLocked(inst) end,
        unlock = function(inst) inst.locked = false syncLocked(inst) end,
    },
}
Classes.func_rot_button = Classes.func_button

-------------------------------------------------------------------------------- func_breakable / physbox
local function breakEntity(inst, activator)
    if not inst.alive then return end
    local x, y, z = Engine.getOrigin(inst)
    local wx, wy, wz = toWorld(x, y, z)
    local mat = kvnum(inst, "material", 1)
    local size = 1
    if inst.def.mins then
        size = math.max(inst.def.maxs[1] - inst.def.mins[1], inst.def.maxs[2] - inst.def.mins[2], inst.def.maxs[3] - inst.def.mins[3]) * SCALE
    end
    triggerClientEvent(root, "mc:breakFx", resourceRoot, wx, wy, wz, mat, size)
    fire(inst, "OnBreak", activator)
    if Carry then Carry.release(inst) end
    Engine.kill(inst)
end
Engine.breakEntity = breakEntity

local function damageEntity(inst, player, amount)
    if not inst.alive then return end
    if inst.health == nil or inst.health <= 0 then return end -- unbreakable
    if hasFlag(inst, 1) and inst.cls == "func_breakable" then return end -- only break on trigger
    inst.health = inst.health - amount
    fire(inst, "OnHealthChanged", player, inst.health)
    if inst.health <= 0 then breakEntity(inst, player) end
end

Classes.func_breakable = {
    spawn = function(inst)
        Engine.createObject(inst)
        inst.health = kvnum(inst, "health", 1)
        if inst.health <= 0 then inst.health = nil end
    end,
    damage = damageEntity,
    inputs = {
        ["break"] = function(inst, p, a) breakEntity(inst, a) end,
        sethealth = function(inst, p, a) inst.health = tonumber(p) or 0 if inst.health <= 0 then breakEntity(inst, a) end end,
        addhealth = function(inst, p) inst.health = (inst.health or 0) + (tonumber(p) or 0) end,
        removehealth = function(inst, p, a) damageEntity(inst, a, tonumber(p) or 0) end,
    },
}
Classes.func_breakable_surf = Classes.func_breakable

Classes.func_physbox = {
    spawn = function(inst, opts)
        -- in GMod physics boxes fall onto the ground / onto each other (minecarts, blocks): the converter
        -- precomputed where they come to rest
        if not (opts and opts.template) and inst.def.settle then inst.oz = inst.def.settle end
        Engine.createObject(inst)
        if opts and opts.template and Carry then
            setTimer(function() if inst.alive then Carry.settle(inst) end end, 150, 1)
        end
        inst.health = kvnum(inst, "health", 0)
        if inst.health <= 0 then inst.health = nil end
        inst.motionEnabled = true
        inst.isPhysics = true
        -- small blocks (gold/diamond/clay/brick...) can be carried with +use like in GMod
        local sx = inst.def.maxs[1] - inst.def.mins[1]
        local sy = inst.def.maxs[2] - inst.def.mins[2]
        local sz = inst.def.maxs[3] - inst.def.mins[3]
        inst.carryable = math.max(sx, sy, sz) <= Config.CARRY_MAX_SIZE
    end,
    damage = damageEntity,
    use = function(inst, player)
        if not inst.carryable or inst.noPickup or not inst.motionEnabled then return false end
        if inst.carrier then
            if inst.carrier == player then Carry.drop(inst) end
            return true
        end
        Carry.pickup(inst, player)
        return true
    end,
    kill = function(inst) if Carry then Carry.release(inst) end end,
    inputs = {
        ["break"] = function(inst, p, a) breakEntity(inst, a) end,
        enablemotion = function(inst)
            inst.motionEnabled = true
            Carry.settle(inst)
        end,
        disablemotion = function(inst)
            inst.motionEnabled = false
            if inst.carrier then Carry.drop(inst, true) end
        end,
        wake = function(inst) Carry.settle(inst) end,
        sleep = function() end,
        forcedrop = function(inst) if inst.carrier then Carry.drop(inst) end end,
        disablephyscannonpickup = function(inst) inst.noPickup = true end,
        enablephyscannonpickup = function(inst) inst.noPickup = false end,
    },
}
Classes.func_physbox_multiplayer = Classes.func_physbox

-------------------------------------------------------------------------------- func_water_analog
-- the water itself is created by every client (client/zones.lua) while this entity's object exists
Classes.func_water_analog = {
    spawn = function(inst)
        Engine.createObject(inst)
    end,
}

-------------------------------------------------------------------------------- trains
local function pathNext(node)
    local t = node.kv.target
    if not t or t == "" then return nil end
    local alt = node.altEnabled and node.kv.altpath
    return Engine.findByName(alt or t)[1]
end

local function trainGo(inst, activator)
    if not inst.alive or not inst.moving then return end
    local cur = inst.node
    local nxt = cur and pathNext(cur)
    if not nxt then
        inst.moving = false
        return
    end
    local x, y, z = Engine.getOrigin(inst)
    local tx, ty, tz = nxt.ox, nxt.oy, nxt.oz + inst.height
    local dist = math.sqrt((tx - x) ^ 2 + (ty - y) ^ 2 + (tz - z) ^ 2)
    local teleport = hasFlag(nxt, 16)
    local dur = (teleport or dist < 0.01) and 0 or math.floor(dist / math.max(1, inst.speed) * 1000)
    local obj = inst.obj
    local yawDelta = 0
    if not inst.fixedOrientation and dist > 1 then
        local yaw = math.deg(math.atan2(ty - y, tx - x))
        yawDelta = ((yaw - inst.yaw + 180) % 360) - 180
        inst.yaw = inst.yaw + yawDelta
    end
    if obj and isElement(obj) then
        if dur <= 50 then
            setElementPosition(obj, toWorld(tx, ty, tz))
            setElementRotation(obj, 0, 0, inst.yaw)
        else
            moveObject(obj, dur, tx * SCALE + Config.OFFSET[1], ty * SCALE + Config.OFFSET[2], tz * SCALE + Config.OFFSET[3], 0, 0, yawDelta)
        end
    else
        inst.ox, inst.oy, inst.oz = tx, ty, tz
    end
    local gen = Engine.generation
    inst.moveTimer = setTimer(function()
        if gen ~= Engine.generation or not inst.alive then return end
        inst.ox, inst.oy, inst.oz = tx, ty, tz
        inst.node = nxt
        fire(nxt, "OnPass", inst)
        local spd = tonumber(nxt.kv.speed) or 0
        if spd > 0 then inst.speed = spd end
        if hasFlag(nxt, 1) then inst.moving = false return end   -- disabled node stops the train
        if hasFlag(nxt, 8) then inst.moving = false return end   -- "disable train"
        trainGo(inst, activator)
    end, math.max(50, dur), 1)
end

local function trainStop(inst)
    inst.moving = false
    if inst.moveTimer and isTimer(inst.moveTimer) then killTimer(inst.moveTimer) end
    if inst.obj and isElement(inst.obj) then
        stopObject(inst.obj)
        inst.ox, inst.oy, inst.oz = toSource(getElementPosition(inst.obj))
    end
end

Classes.func_tanktrain = {
    spawn = function(inst)
        Engine.createObject(inst)
        inst.height = kvnum(inst, "height", 0)
        inst.speed = kvnum(inst, "startspeed", 100)
        inst.fixedOrientation = hasFlag(inst, 16)
        inst.yaw = 0
        inst.moving = false
    end,
    activate = function(inst)
        -- the train starts on its first path_track (needs all path_tracks to exist)
        local first = Engine.findByName(inst.kv.target)[1]
        if first then
            inst.node = first
            inst.ox, inst.oy, inst.oz = first.ox, first.oy, first.oz + inst.height
            if inst.obj then setElementPosition(inst.obj, toWorld(inst.ox, inst.oy, inst.oz)) end
        end
    end,
    kill = function(inst) if inst.moveTimer and isTimer(inst.moveTimer) then killTimer(inst.moveTimer) end end,
    inputs = {
        startforward = function(inst, p, a)
            if inst.moving then return end
            inst.moving = true
            inst.speed = (inst.speed > 0) and inst.speed or kvnum(inst, "startspeed", 100)
            trainGo(inst, a)
        end,
        resume = function(inst, p, a) if not inst.moving then inst.moving = true trainGo(inst, a) end end,
        stop = function(inst) trainStop(inst) end,
        toggle = function(inst, p, a)
            if inst.moving then trainStop(inst) else inst.moving = true trainGo(inst, a) end
        end,
        setspeed = function(inst, p) inst.speed = (tonumber(p) or 0) * kvnum(inst, "startspeed", 100) end,
        setspeedreal = function(inst, p) inst.speed = tonumber(p) or 0 end,
    },
}
Classes.func_tracktrain = Classes.func_tanktrain

Classes.path_track = {
    spawn = function(inst) inst.altEnabled = false end,
    inputs = {
        enablealternatepath = function(inst) inst.altEnabled = true end,
        disablealternatepath = function(inst) inst.altEnabled = false end,
        togglealternatepath = function(inst) inst.altEnabled = not inst.altEnabled end,
        enablepath = function(inst) inst.spawnflags = bitAnd(inst.spawnflags, bitNot(1)) end,
        disablepath = function(inst) inst.spawnflags = bitOr(inst.spawnflags, 1) end,
    },
}

-------------------------------------------------------------------------------- triggers
-- trigger behaviour lives in triggers.lua (polling); classes only hold state + inputs
local function triggerSpawn(inst)
    inst.enabled = kvstr(inst, "StartDisabled", "0") ~= "1"
    inst.touching = {}
    inst.touchCount = 0
    inst.nextTrigger = 0
    inst.isTrigger = true
    if inst.cls == "trigger_push" or inst.cls == "trigger_gravity" or inst.cls == "trigger_hurt" then
        stateElement(inst, { enabled = inst.enabled })
    end
end

local function triggerEnable(inst, on)
    inst.enabled = on
    if not on then
        inst.touching = {}
        inst.touchCount = 0
    end
    setState(inst, "enabled", on)
end

for _, cls in ipairs({ "trigger_multiple", "trigger_once", "trigger_teleport", "trigger_hurt", "trigger_push",
                       "trigger_gravity", "trigger_look", "trigger_proximity", "trigger_soundscape", "trigger_physics_trap" }) do
    Classes[cls] = { spawn = triggerSpawn, enable = triggerEnable, inputs = {} }
end
Classes.trigger_hurt.inputs.setdamage = function(inst, p) inst.kv.damage = tostring(tonumber(p) or 0) end
Classes.trigger_push.inputs.setspeed = function(inst, p) inst.kv.speed = tostring(tonumber(p) or 0) setState(inst, "speed", tonumber(p)) end
Classes.trigger_teleport.inputs.settarget = function(inst, p) inst.kv.target = p end
Classes.trigger_multiple.inputs.touchtest = function(inst, p, a)
    if inst.touchCount > 0 then fire(inst, "OnTouching", a) else fire(inst, "OnNotTouching", a) end
end

-------------------------------------------------------------------------------- filters
local function nameMatch(pattern, name)
    if not pattern or not name then return false end
    pattern, name = string.lower(pattern), string.lower(name)
    if pattern:sub(-1) == "*" then return name:sub(1, #pattern - 1) == pattern:sub(1, -2) end
    return pattern == name
end

function Engine.passesFilter(filterName, activator)
    if not filterName or filterName == "" then return true end
    local f = Engine.findByName(filterName)[1]
    if not f then return true end
    local negated = (f.kv.Negated or f.kv.negated) == "1"
    local result
    if f.cls == "filter_activator_name" then
        result = nameMatch(f.kv.filtername, Engine.activatorName(activator))
    elseif f.cls == "filter_activator_class" then
        result = nameMatch(f.kv.filterclass, Engine.activatorClass(activator))
    elseif f.cls == "filter_multi" then
        local orMode = (tonumber(f.kv.filtertype) or 0) == 1
        result = not orMode
        for i = 1, 10 do
            local sub = f.kv[string.format("Filter%02d", i)]
            if sub and sub ~= "" then
                local r = Engine.passesFilter(sub, activator)
                if orMode and r then result = true break end
                if not orMode and not r then result = false break end
            end
        end
    else
        result = true
    end
    if negated then return not result end
    return result
end

-------------------------------------------------------------------------------- logic
Classes.logic_relay = {
    spawn = function(inst) inst.enabled = kvstr(inst, "StartDisabled", "0") ~= "1" end,
    enable = function(inst, on) inst.enabled = on end,
    inputs = {
        trigger = function(inst, p, a)
            if not inst.enabled then return end
            fire(inst, "OnTrigger", a)
            if hasFlag(inst, 1) then Engine.kill(inst) end
        end,
        cancelpending = function(inst) Engine.cancelPending(inst) end,
        enablerefire = function() end,
    },
}

Classes.logic_auto = {
    spawn = function(inst) end,
}

-- Source: PickRandom fires a random OnCase output *that has at least one connection*
local function caseValues(inst)
    local list = {}
    for i = 1, 16 do
        local out = string.format("oncase%02d", i)
        for _, o in ipairs(inst.outputs) do
            if string.lower(o.name) == out then list[#list + 1] = i break end
        end
    end
    return list
end

Classes.logic_case = {
    spawn = function(inst) inst.shuffle = {} end,
    inputs = {
        pickrandom = function(inst, p, a)
            local list = caseValues(inst)
            if #list == 0 then return end
            local i = list[math.random(#list)]
            fire(inst, string.format("OnCase%02d", i), a)
        end,
        pickrandomshuffle = function(inst, p, a)
            local list = caseValues(inst)
            if #list == 0 then return end
            if #inst.shuffle == 0 then
                for _, v in ipairs(list) do inst.shuffle[#inst.shuffle + 1] = v end
                for i = #inst.shuffle, 2, -1 do
                    local j = math.random(i)
                    inst.shuffle[i], inst.shuffle[j] = inst.shuffle[j], inst.shuffle[i]
                end
            end
            local i = table.remove(inst.shuffle)
            fire(inst, string.format("OnCase%02d", i), a)
        end,
        invalue = function(inst, p, a)
            for i = 1, 16 do
                local v = inst.kv[string.format("Case%02d", i)]
                if v and v ~= "" and string.lower(v) == string.lower(tostring(p)) then
                    fire(inst, string.format("OnCase%02d", i), a)
                    return
                end
            end
            fire(inst, "OnDefault", a, p)
        end,
    },
}

local function branchListenersUpdate(changed)
    for _, l in ipairs(Engine.byClass("logic_branch_listener")) do
        local watches = false
        local trues, total = 0, 0
        for i = 1, 16 do
            local n = l.kv[string.format("Branch%02d", i)]
            if n and n ~= "" then
                for _, b in ipairs(Engine.findByName(n)) do
                    if b.cls == "logic_branch" then
                        total = total + 1
                        if b.value then trues = trues + 1 end
                        if b == changed then watches = true end
                    end
                end
            end
        end
        if watches and total > 0 then
            local st = (trues == total) and "true" or (trues == 0) and "false" or "mixed"
            if st ~= l.lastState then
                l.lastState = st
                fire(l, st == "true" and "OnAllTrue" or st == "false" and "OnAllFalse" or "OnMixed")
            end
        end
    end
end

local function branchSet(inst, v, a, test)
    local old = inst.value
    inst.value = v
    if test then fire(inst, v and "OnTrue" or "OnFalse", a) end
    if old ~= v then branchListenersUpdate(inst) end
end

Classes.logic_branch = {
    spawn = function(inst) inst.value = (tonumber(inst.kv.InitialValue) or 0) ~= 0 end,
    inputs = {
        setvalue = function(inst, p, a) branchSet(inst, (tonumber(p) or 0) ~= 0, a, false) end,
        setvaluetest = function(inst, p, a) branchSet(inst, (tonumber(p) or 0) ~= 0, a, true) end,
        toggle = function(inst, p, a) branchSet(inst, not inst.value, a, false) end,
        toggletest = function(inst, p, a) branchSet(inst, not inst.value, a, true) end,
        test = function(inst, p, a) fire(inst, inst.value and "OnTrue" or "OnFalse", a) end,
    },
}
Classes.logic_branch_listener = {
    spawn = function(inst) inst.lastState = nil end,
    inputs = {
        test = function(inst) inst.lastState = nil branchListenersUpdate(nil) end,
    },
}

local function counterSet(inst, v, a, nofire)
    local mn, mx = kvnum(inst, "min", 0), kvnum(inst, "max", 0)
    if mn < mx then v = math.max(mn, math.min(mx, v)) end
    inst.value = v
    if nofire then return end
    fire(inst, "OutValue", a, v)
    if mn < mx then
        if v >= mx then
            if not inst.hitMax then inst.hitMax = true fire(inst, "OnHitMax", a) end
        else inst.hitMax = false end
        if v <= mn then
            if not inst.hitMin then inst.hitMin = true fire(inst, "OnHitMin", a) end
        else inst.hitMin = false end
    end
end

Classes.math_counter = {
    spawn = function(inst)
        inst.enabled = kvstr(inst, "StartDisabled", "0") ~= "1"
        inst.value = kvnum(inst, "startvalue", 0)
        inst.hitMax, inst.hitMin = false, false
    end,
    enable = function(inst, on) inst.enabled = on end,
    inputs = {
        add = function(inst, p, a) if inst.enabled then counterSet(inst, inst.value + (tonumber(p) or 0), a) end end,
        subtract = function(inst, p, a) if inst.enabled then counterSet(inst, inst.value - (tonumber(p) or 0), a) end end,
        multiply = function(inst, p, a) if inst.enabled then counterSet(inst, inst.value * (tonumber(p) or 1), a) end end,
        divide = function(inst, p, a) local d = tonumber(p) or 1 if inst.enabled and d ~= 0 then counterSet(inst, inst.value / d, a) end end,
        setvalue = function(inst, p, a) if inst.enabled then counterSet(inst, tonumber(p) or 0, a) end end,
        setvaluenofire = function(inst, p, a) if inst.enabled then counterSet(inst, tonumber(p) or 0, a, true) end end,
        getvalue = function(inst, p, a) fire(inst, "OnGetValue", a, inst.value) end,
        sethitmax = function(inst, p) inst.kv.max = tostring(tonumber(p) or 0) end,
        sethitmin = function(inst, p) inst.kv.min = tostring(tonumber(p) or 0) end,
    },
}

Classes.point_template = {
    spawn = function(inst) end,
    inputs = {
        forcespawn = function(inst, p, a)
            for i = 1, 16 do
                local n = inst.kv[string.format("Template%02d", i)]
                if n and n ~= "" then
                    for _, def in ipairs(MAP_ENTS) do
                        local tn = def.kv.targetname
                        if tn and string.lower(tn) == string.lower(n) then
                            Engine.spawnTemplate(def)
                        end
                    end
                end
            end
            fire(inst, "OnEntitySpawned", a)
        end,
    },
}

-- teleport an instance or player to a destination entity
function Engine.teleportTo(what, dest)
    local x, y, z = dest.ox, dest.oy, dest.oz
    local _, yaw = dest.ap, dest.ay
    if Engine.isPlayer(what) then
        local wx, wy, wz = toWorld(x, y, z)
        if Carry then Carry.dropByPlayer(what) end
        setElementPosition(what, wx, wy, wz + PED_CENTER + 0.05)
        setElementRotation(what, 0, 0, (dest.ay or 0) - 90, "default", true)
        setElementVelocity(what, 0, 0, 0)
        triggerClientEvent(what, "mc:teleported", resourceRoot, (dest.ay or 0))
    elseif type(what) == "table" and what.alive then
        if Carry then Carry.release(what) end
        what.ox, what.oy, what.oz = x, y, z
        if what.obj and isElement(what.obj) then
            stopObject(what.obj)
            setElementPosition(what.obj, toWorld(x, y, z))
            setElementRotation(what.obj, 0, 0, 0)
        end
    end
end

Classes.point_teleport = {
    spawn = function(inst) end,
    inputs = {
        teleport = function(inst, p, a, caller)
            local tgt = inst.kv.target
            if not tgt or tgt == "" then return end
            local l = string.lower(tgt)
            if l == "!activator" then
                if a then Engine.teleportTo(a, inst) end
                -- the win sequence: the diamond block is in, players arrive in the end -> ttt-core innocent win
                if a and Engine.isPlayer(a) and (inst.name or ""):find("^Win_Teleport_") and Bridge.onEndTeleport then
                    Bridge.onEndTeleport()
                end
            elseif l == "!player" then
                local pl = getElementsByType("player")[1]
                if pl then Engine.teleportTo(pl, inst) end
            else
                for _, t in ipairs(Engine.findByName(tgt)) do Engine.teleportTo(t, inst) end
            end
        end,
    },
}
Classes.info_teleport_destination = { spawn = function() end }

-------------------------------------------------------------------------------- effects / point entities
Classes.env_explosion = {
    spawn = function(inst) end,
    inputs = {
        explode = function(inst, p, a)
            local x, y, z = Engine.getOrigin(inst)
            local wx, wy, wz = toWorld(x, y, z)
            local mag = kvnum(inst, "iMagnitude", 100)
            local nodamage = hasFlag(inst, 1)
            local owner = Bridge.damageOwnerOf(inst)
            local etype = mag >= 150 and 7 or (mag >= 60 and 2 or 0)
            if nodamage then
                triggerClientEvent(root, "mc:explosionFx", resourceRoot, wx, wy, wz)
            else
                if owner and isElement(owner) then
                    createExplosion(wx, wy, wz, etype, owner)
                else
                    createExplosion(wx, wy, wz, etype)
                end
                -- breakables / physboxes in range
                local r = kvnum(inst, "iRadiusOverride", 0)
                if r <= 0 then r = mag * 2.5 end
                for _, e in ipairs(Engine.all()) do
                    if e.alive and e.health and e.obj and (e.cls == "func_breakable" or e.cls == "func_physbox") then
                        local ex, ey, ez = Engine.getOrigin(e)
                        local d = math.sqrt((ex - x) ^ 2 + (ey - y) ^ 2 + (ez - z) ^ 2)
                        if d < r then
                            local c = Classes[e.cls]
                            if c.damage then c.damage(e, owner, mag * (1 - d / r)) end
                        end
                    end
                end
            end
            if not hasFlag(inst, 2) then Engine.kill(inst) end
        end,
    },
}

Classes.env_physexplosion = {
    spawn = function(inst) end,
    inputs = {
        explode = function(inst)
            local x, y, z = Engine.getOrigin(inst)
            local mag = kvnum(inst, "magnitude", 100)
            local r = kvnum(inst, "radius", 0)
            if r <= 0 then r = mag * 2.5 end
            for _, pl in ipairs(getElementsByType("player")) do
                if not isPedDead(pl) and getElementDimension(pl) == Config.DIMENSION then
                    local px, py, pz = pedSourceOrigin(pl)
                    local dx, dy, dz = px - x, py - y, pz - z
                    local d = math.sqrt(dx * dx + dy * dy + dz * dz)
                    if d < r and d > 0.1 then
                        local f = (1 - d / r) * mag * SCALE * 0.15
                        triggerClientEvent(pl, "mc:impulse", resourceRoot, dx / d * f, dy / d * f, dz / d * f + f * 0.3)
                    end
                end
            end
        end,
    },
}

local function clientFxEntity(extra)
    return {
        spawn = function(inst)
            local x, y, z = toWorld(inst.ox, inst.oy, inst.oz)
            local data = { x = x, y = y, z = z, on = true }
            if extra then extra(inst, data) end
            stateElement(inst, data)
        end,
    }
end

Classes.env_fire = clientFxEntity(function(inst, d)
    d.on = hasFlag(inst, 4)   -- "Start On"
    d.size = kvnum(inst, "firesize", 64) * SCALE
end)
Classes.env_fire.inputs = {
    startfire = function(inst) setState(inst, "on", true) end,
    extinguish = function(inst) setState(inst, "on", false) end,
    extinguishtemporary = function(inst) setState(inst, "on", false) end,
}

Classes.light_dynamic = clientFxEntity(function(inst, d)
    local r, g, b = vec3(inst.kv._light)
    d.r, d.g, d.b = r, g, b
    d.radius = kvnum(inst, "distance", 120) * SCALE
    d.on = not hasFlag(inst, 1)
end)
Classes.light_dynamic.inputs = {
    color = function(inst, p)
        local r, g, b = vec3(p)
        setState(inst, "r", r) setState(inst, "g", g) setState(inst, "b", b)
    end,
    turnon = function(inst) setState(inst, "on", true) end,
    turnoff = function(inst) setState(inst, "on", false) end,
    toggle = function(inst) setState(inst, "on", not getElementData(inst.state, "on")) end,
    distance = function(inst, p) setState(inst, "radius", (tonumber(p) or 120) * SCALE) end,
}

Classes.light = { spawn = function() end, inputs = {
    -- lighting is baked into the map's vertex colours; switching lights is not possible at runtime
    turnon = function() end, turnoff = function() end, toggle = function() end,
} }
Classes.light_spot = Classes.light

Classes.point_tesla = clientFxEntity(function(inst, d)
    d.on = false
    d.radius = kvnum(inst, "m_flRadius", 200) * SCALE
    local r, g, b = vec3(inst.kv.m_Color)
    d.r, d.g, d.b = r, g, b
end)
Classes.point_tesla.inputs = {
    turnon = function(inst) setState(inst, "on", true) end,
    turnoff = function(inst) setState(inst, "on", false) end,
    dospark = function(inst) triggerClientEvent(root, "mc:spark", resourceRoot, inst.uid) end,
}

Classes.ambient_generic = clientFxEntity(function(inst, d)
    d.on = false
    d.sound = inst.kv.message
    d.radius = kvnum(inst, "radius", 1250) * SCALE
    d.everywhere = hasFlag(inst, 1)
    d.loop = not hasFlag(inst, 32)
end)
Classes.ambient_generic.inputs = {
    playsound = function(inst) setState(inst, "on", true) triggerClientEvent(root, "mc:sound", resourceRoot, inst.uid, true) end,
    stopsound = function(inst) setState(inst, "on", false) triggerClientEvent(root, "mc:sound", resourceRoot, inst.uid, false) end,
    togglesound = function(inst)
        local on = not getElementData(inst.state, "on")
        setState(inst, "on", on)
        triggerClientEvent(root, "mc:sound", resourceRoot, inst.uid, on)
    end,
}

Classes.env_fog_controller = clientFxEntity(function(inst, d)
    d.on = kvnum(inst, "fogenable", 1) == 1
    d.fogstart = kvnum(inst, "fogstart", 500) * SCALE
    d.fogend = kvnum(inst, "fogend", 2000) * SCALE
    local r, g, b = vec3(inst.kv.fogcolor)
    d.r, d.g, d.b = r, g, b
end)
Classes.env_fog_controller.inputs = {
    turnon = function(inst) setState(inst, "on", true) end,
    turnoff = function(inst) setState(inst, "on", false) end,
    setstartdist = function(inst, p) setState(inst, "fogstart", (tonumber(p) or 0) * SCALE) end,
    setenddist = function(inst, p) setState(inst, "fogend", (tonumber(p) or 0) * SCALE) end,
}

Classes.env_fade = {
    spawn = function() end,
    inputs = {
        fade = function(inst, p, a)
            local r, g, b = vec3(inst.kv.rendercolor or "0 0 0")
            local dur = kvnum(inst, "duration", 2)
            local hold = kvnum(inst, "holdtime", 1)
            local targets = (hasFlag(inst, 4) and Engine.isPlayer(a)) and { a } or getElementsByType("player")
            for _, pl in ipairs(targets) do
                triggerClientEvent(pl, "mc:fade", resourceRoot, r, g, b, dur, hold, hasFlag(inst, 1), hasFlag(inst, 8))
            end
        end,
    },
}

Classes.game_text = {
    spawn = function() end,
    inputs = {
        display = function(inst, p, a)
            local msg = inst.kv.message or ""
            if Config.TEXT_HIDE and Config.TEXT_HIDE[msg] then return end
            msg = (Config.TEXT_REPLACE and Config.TEXT_REPLACE[msg]) or msg
            local r, g, b = vec3(inst.kv.color or "255 255 255")
            local x, y = kvnum(inst, "x", -1), kvnum(inst, "y", -1)
            local hold = kvnum(inst, "holdtime", 3)
            local fadein, fadeout = kvnum(inst, "fadein", 0.5), kvnum(inst, "fadeout", 0.5)
            local ch = kvnum(inst, "channel", 1)
            local targets = (hasFlag(inst, 1)) and getElementsByType("player") or (Engine.isPlayer(a) and { a } or {})
            for _, pl in ipairs(targets) do
                triggerClientEvent(pl, "mc:gametext", resourceRoot, msg, r, g, b, x, y, hold, fadein, fadeout, ch)
            end
        end,
    },
}

Classes.point_clientcommand = {
    spawn = function() end,
    inputs = {
        command = function(inst, p, a)
            if Engine.isPlayer(a) then triggerClientEvent(a, "mc:clientcommand", resourceRoot, tostring(p)) end
        end,
    },
}

Classes.logic_collision_pair = { spawn = function() end, inputs = {
    disablecollisions = function() end, enablecollisions = function() end } }

for _, cls in ipairs({ "filter_activator_name", "filter_activator_class", "filter_multi", "info_player_start",
                       "info_player_deathmatch", "info_player_counterterrorist", "info_player_terrorist",
                       "info_ladder_dismount", "water_lod_control", "light_environment", "worldspawn" }) do
    Classes[cls] = Classes[cls] or { spawn = function() end }
end

Classes.func_useableladder = clientFxEntity(function(inst, d)
    local x0, y0, z0 = vec3(inst.kv.point0)
    local x1, y1, z1 = vec3(inst.kv.point1)
    d.p0 = { x0, y0, z0 }
    d.p1 = { x1, y1, z1 }
    d.on = kvstr(inst, "StartDisabled", "0") ~= "1"
end)
Classes.func_useableladder.inputs = {
    enable = function(inst) setState(inst, "on", true) end,
    disable = function(inst) setState(inst, "on", false) end,
}

-------------------------------------------------------------------------------- TTT entities
Classes.ttt_map_settings = { spawn = function() end }
Classes.ttt_logic_role = {
    spawn = function() end,
    inputs = {
        testactivator = function(inst, p, a)
            if not Engine.isPlayer(a) then return end
            local role = Bridge.getRoleNumber(a)
            local want = kvnum(inst, "Role", 3)
            if want == 3 or want == role then fire(inst, "OnPass", a) else fire(inst, "OnFail", a) end
        end,
    },
}

Classes.ttt_traitor_check = {
    spawn = function() end,
    inputs = {
        checkfortraitor = function(inst, p, a)
            local count = 0
            for _, pl in ipairs(getElementsByType("player")) do
                if not isPedDead(pl) and Bridge.isActiveTraitor(pl) then
                    local x, y, z = pedSourceOrigin(pl)
                    local ox, oy, oz = Engine.getOrigin(inst)
                    local mn, mx = inst.def.mins, inst.def.maxs
                    if x >= ox + mn[1] and x <= ox + mx[1] and y >= oy + mn[2] and y <= oy + mx[2]
                        and z >= oz + mn[3] - 2 and z <= oz + mx[3] then
                        count = count + 1
                    end
                end
            end
            fire(inst, "TraitorsFound", a, count)
        end,
    },
}

Classes.ttt_traitor_button = {
    spawn = function(inst)
        inst.locked = hasFlag(inst, 2048)
        inst.nextUse = 0
        local x, y, z = toWorld(inst.ox, inst.oy, inst.oz)
        stateElement(inst, {
            x = x, y = y, z = z,
            desc = inst.kv.description or "?",
            range = kvnum(inst, "usableRange", Config.TRAITOR_BUTTON_RANGE) * SCALE,
            ready = true,
        })
        setElementData(inst.state, "tbutton", true)
    end,
    press = function(inst, player)
        if inst.locked or now() < inst.nextUse then return false end
        fire(inst, "OnPressed", player)
        if kvnum(inst, "RemoveOnPress", 0) == 1 then
            Engine.kill(inst)
            return true
        end
        local wait = kvnum(inst, "wait", 15)
        if wait < 0 then
            inst.locked = true
            setState(inst, "ready", false)
        else
            inst.nextUse = now() + wait * 1000
            if wait > 0 then
                setState(inst, "ready", false)
                local gen = Engine.generation
                setTimer(function() if gen == Engine.generation and inst.alive then setState(inst, "ready", not inst.locked) end end, math.max(50, wait * 1000), 1)
            end
        end
        return true
    end,
    inputs = {
        lock = function(inst) inst.locked = true setState(inst, "ready", false) end,
        unlock = function(inst) inst.locked = false setState(inst, "ready", true) end,
        toggle = function(inst) inst.locked = not inst.locked setState(inst, "ready", not inst.locked) end,
    },
}

Classes.ttt_damageowner = {
    spawn = function() end,
    inputs = {
        setactivatorasdamageowner = function(inst, p, a)
            for _, d in ipairs(Engine.findByName(inst.kv.damager)) do
                d.damageOwner = Engine.isPlayer(a) and a or nil
                d.killName = inst.kv.killname
            end
        end,
        cleardamageowner = function(inst)
            for _, d in ipairs(Engine.findByName(inst.kv.damager)) do d.damageOwner = nil end
        end,
    },
}

Classes.ttt_win = {
    spawn = function() end,
    inputs = {
        innocentwin = function() Bridge.declareWin("innocent") end,
        traitorwin = function() Bridge.declareWin("traitor") end,
        draw = function() Bridge.declareWin("draw") end,
    },
}

Classes.ttt_credit_adjust = {
    spawn = function() end,
    inputs = {
        takecredits = function(inst, p, a)
            if not Engine.isPlayer(a) then return end
            local amount = math.abs(tonumber(inst.kv.credits) or 1)
            if Bridge.takeCredits(a, amount) then fire(inst, "OnSuccess", a) else fire(inst, "OnFail", a) end
        end,
    },
}

Classes.ttt_game_text = {
    spawn = function() end,
    inputs = {
        display = function(inst, p, a)
            local r, g, b = vec3(inst.kv.color or "255 255 255")
            Bridge.gameText(inst.kv.message or "", tonumber(inst.kv.receive) or 0, a, r, g, b)
        end,
    },
}

-- weapon / ammo entities (spawned as pickups through the bridge)
local function weaponClass()
    return {
        spawn = function(inst, opts)
            local spawn = opts.template
            if not spawn and Config.SPAWN_WEAPONS and Rounds and Rounds.spawnWeapons then
                local c = inst.cls
                if c:match("^item_") or c == "ttt_random_ammo" then
                    spawn = Config.SPAWN_AMMO
                elseif Bridge.isTraitorItem(c) then
                    spawn = true
                else
                    spawn = math.random() < (Config.WEAPON_SPAWN_CHANCE or 1)
                end
            end
            if spawn then
                -- like the GMod physics props: on the floor below the spawn point
                local gz = (not opts.template) and inst.def.ground or inst.oz
                local x, y, z = toWorld(inst.ox, inst.oy, math.min(gz, inst.oz))
                inst.pickup = Bridge.spawnWeapon(inst.cls, x, y, z + (Config.PICKUP_HEIGHT or 0.5), inst)
            end
        end,
    }
end
for _, def in ipairs(MAP_ENTS) do
    local c = def.classname
    if (c:match("^weapon_") or c:match("^item_") or c:match("^ttt_random_")) and not Classes[c] then
        Classes[c] = weaponClass()
    end
end

-- func_clip_vphysics only blocks physics props in Source (players walk through) -> state only
Classes.func_clip_vphysics = {
    spawn = function(inst) inst.enabled = (inst.kv.StartDisabled or "0") ~= "1" end,
    enable = function(inst, on) inst.enabled = on end,
}
