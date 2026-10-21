--[[
    Source entity I/O engine (server side).
    Every map entity becomes an "instance" table; outputs are queued with their delays exactly like
    Source's event queue, inputs are dispatched to the class handlers in classes.lua.
]]

Engine = {
    ents = {},        -- uid -> instance
    byName = {},      -- lowercase targetname -> { [inst] = true }
    list = {},        -- array of live instances (rebuilt lazily)
    queue = {},
    seq = 0,
    uidCounter = 0,
    flushing = false,
    templated = {},   -- lowercase names that only exist through point_template
    generation = 0,   -- bumps on every map reset (stale timers check it)
}
Classes = {}          -- classname -> { spawn=fn, inputs={lowercase=fn}, kill=fn }

local now = getTickCount

-------------------------------------------------------------------------------- instances
function Engine.create(def, opts)
    Engine.uidCounter = Engine.uidCounter + 1
    local kv = def.kv or {}
    local inst = {
        uid = Engine.uidCounter,
        def = def,
        cls = def.classname,
        kv = kv,
        name = kv.targetname,
        lname = lower(kv.targetname),
        alive = true,
        spawnflags = tonumber(kv.spawnflags) or 0,
        outputs = {},
    }
    inst.ox, inst.oy, inst.oz = vec3(kv.origin)
    inst.ap, inst.ay, inst.ar = vec3(kv.angles)
    for i, o in ipairs(def.outputs or {}) do
        inst.outputs[i] = { name = o[1], target = o[2], input = o[3], param = o[4], delay = o[5], times = o[6] }
    end
    Engine.ents[inst.uid] = inst
    Engine.list = nil
    if inst.lname and inst.lname ~= "" then
        Engine.byName[inst.lname] = Engine.byName[inst.lname] or {}
        Engine.byName[inst.lname][inst] = true
    end
    local c = Classes[inst.cls]
    if c and c.spawn then
        local ok, err = pcall(c.spawn, inst, opts or {})
        if not ok then outputDebugString("[mc] spawn error " .. inst.cls .. " " .. tostring(inst.name) .. ": " .. tostring(err), 1) end
    end
    return inst
end

function Engine.kill(inst)
    if not inst or not inst.alive then return end
    inst.alive = false
    local c = Classes[inst.cls]
    if c and c.kill then pcall(c.kill, inst) end
    Engine.destroyElements(inst)
    if inst.lname and Engine.byName[inst.lname] then
        Engine.byName[inst.lname][inst] = nil
    end
    Engine.ents[inst.uid] = nil
    Engine.list = nil
end

function Engine.destroyElements(inst)
    for _, key in ipairs({ "obj", "state", "water", "pickup" }) do
        local e = inst[key]
        if type(e) == "table" then
            for _, el in pairs(e) do if isElement(el) then destroyElement(el) end end
        elseif e and isElement(e) then
            destroyElement(e)
        end
        inst[key] = nil
    end
end

function Engine.all()
    if not Engine.list then
        local l = {}
        for _, inst in pairs(Engine.ents) do l[#l + 1] = inst end
        table.sort(l, function(a, b) return a.uid < b.uid end)
        Engine.list = l
    end
    return Engine.list
end

function Engine.byClass(cls)
    local r = {}
    for _, inst in ipairs(Engine.all()) do
        if inst.alive and inst.cls == cls then r[#r + 1] = inst end
    end
    return r
end

function Engine.findByName(name)
    local r = {}
    if not name or name == "" then return r end
    local n = lower(name)
    if n:sub(-1) == "*" then
        local pre = n:sub(1, -2)
        for _, inst in ipairs(Engine.all()) do
            if inst.alive and inst.lname and inst.lname:sub(1, #pre) == pre then r[#r + 1] = inst end
        end
        return r
    end
    local set = Engine.byName[n]
    if set then
        for inst in pairs(set) do if inst.alive then r[#r + 1] = inst end end
        table.sort(r, function(a, b) return a.uid < b.uid end)
    end
    if #r == 0 then
        -- Source also accepts a classname as target
        for _, inst in ipairs(Engine.all()) do
            if inst.alive and inst.cls == n then r[#r + 1] = inst end
        end
    end
    return r
end

-------------------------------------------------------------------------------- event queue
local function enqueue(t, ev)
    Engine.seq = Engine.seq + 1
    ev.time = t
    ev.seq = Engine.seq
    local q = Engine.queue
    -- insertion keeping (time, seq) order
    local pos = #q + 1
    while pos > 1 and (q[pos - 1].time > t) do pos = pos - 1 end
    table.insert(q, pos, ev)
end

-- Fire an output of an instance (Source: COutputEvent::FireOutput)
function Engine.fireOutput(inst, outputName, activator, value, delayExtra)
    if not inst then return end
    local outs = inst.outputs
    local lname = string.lower(outputName)
    local i = 1
    while i <= #outs do
        local o = outs[i]
        if string.lower(o.name) == lname then
            local param = o.param
            if param == nil or param == "" then param = value end
            mcDebug(tostring(inst.name or inst.cls), outputName, "->", o.target, o.input, tostring(param), "delay", o.delay)
            enqueue(now() + math.floor(((o.delay or 0) + (delayExtra or 0)) * 1000), {
                target = o.target, input = o.input, param = param, activator = activator, caller = inst,
                gen = Engine.generation,
            })
            if o.times and o.times > 0 then
                o.times = o.times - 1
                if o.times == 0 then
                    table.remove(outs, i)
                    i = i - 1
                end
            end
        end
        i = i + 1
    end
    Engine.flush()
end

-- Direct input (like ent_fire), optionally delayed
function Engine.fireInput(target, input, param, delay, activator, caller)
    enqueue(now() + math.floor((delay or 0) * 1000), {
        target = target, input = input, param = param, activator = activator, caller = caller, gen = Engine.generation,
    })
    Engine.flush()
end

function Engine.cancelPending(caller)
    local q = Engine.queue
    for i = #q, 1, -1 do
        if q[i].caller == caller then table.remove(q, i) end
    end
end

local function isPlayerActivator(a)
    return a and isElement(a) and getElementType(a) == "player"
end
Engine.isPlayer = isPlayerActivator

local function resolveTargets(target, activator, caller)
    local t = lower(target or "")
    if t == "!activator" then return { activator } end
    if t == "!self" or t == "!caller" then return { caller } end
    if t == "!player" or t == "!pvsplayer" then
        local p = getElementsByType("player")[1]
        return { p }
    end
    return Engine.findByName(target)
end

function Engine.dispatch(ev)
    local targets = resolveTargets(ev.target, ev.activator, ev.caller)
    for _, tgt in ipairs(targets) do
        if tgt then
            if type(tgt) == "table" then
                Engine.acceptInput(tgt, ev.input, ev.param, ev.activator, ev.caller)
            elseif isPlayerActivator(tgt) then
                Engine.playerInput(tgt, ev.input, ev.param, ev.activator, ev.caller)
            end
        end
    end
end

function Engine.flush()
    if Engine.flushing then return end
    Engine.flushing = true
    local guard = 0
    local q = Engine.queue
    while #q > 0 and q[1].time <= now() and guard < 20000 do
        local ev = table.remove(q, 1)
        guard = guard + 1
        if ev.gen == Engine.generation then
            local ok, err = pcall(Engine.dispatch, ev)
            if not ok then outputDebugString("[mc] I/O error " .. tostring(ev.target) .. "." .. tostring(ev.input) .. ": " .. tostring(err), 1) end
        end
    end
    Engine.flushing = false
end

-------------------------------------------------------------------------------- input dispatch
function Engine.acceptInput(inst, input, param, activator, caller)
    if not inst.alive then return end
    local li = string.lower(input or "")
    mcDebug("input", tostring(inst.name or inst.cls), input, tostring(param))
    local c = Classes[inst.cls]
    local h = c and c.inputs and c.inputs[li]
    if h then
        h(inst, param, activator, caller)
        return
    end
    -- generic inputs available on every entity
    if li == "kill" or li == "killhierarchy" then
        Engine.kill(inst)
        for _, child in ipairs(Engine.all()) do
            if li == "killhierarchy" and child.parent == inst then Engine.kill(child) end
        end
    elseif li:match("^fireuser%d$") then
        Engine.fireOutput(inst, "OnUser" .. li:sub(-1), activator)
    elseif li == "addoutput" then
        Engine.addOutput(inst, param)
    elseif li == "enable" and c and c.enable then
        c.enable(inst, true, activator)
    elseif li == "disable" and c and c.enable then
        c.enable(inst, false, activator)
    elseif li == "toggle" and c and c.enable then
        c.enable(inst, not inst.enabled, activator)
    elseif li == "setparent" then
        local p = Engine.findByName(param)[1]
        Engine.setParent(inst, p)
    elseif li == "clearparent" then
        Engine.setParent(inst, nil)
    else
        mcDebug("unhandled input", inst.cls, input)
    end
end

function Engine.addOutput(inst, param)
    if not param then return end
    local key, rest = param:match("^(%S+)%s+(.+)$")
    if not key then return end
    local tgt, inp, prm, dly, times = rest:match("^([^:]*):([^:]*):([^:]*):([^:]*):([^:]*)$")
    if tgt then
        table.insert(inst.outputs, { name = key, target = tgt, input = inp, param = prm, delay = tonumber(dly) or 0, times = tonumber(times) or -1 })
    else
        inst.kv[key] = rest
        if lower(key) == "targetname" then
            if inst.lname and Engine.byName[inst.lname] then Engine.byName[inst.lname][inst] = nil end
            inst.name, inst.lname = rest, lower(rest)
            Engine.byName[inst.lname] = Engine.byName[inst.lname] or {}
            Engine.byName[inst.lname][inst] = true
        end
    end
end

-------------------------------------------------------------------------------- parenting
function Engine.setParent(inst, parent)
    if parent then
        local px, py, pz = Engine.getOrigin(parent)
        local cx, cy, cz = Engine.getOrigin(inst)
        inst.parent = parent
        inst.parentOffset = { cx - px, cy - py, cz - pz }
    else
        local x, y, z = Engine.getOrigin(inst)
        inst.parent = nil
        inst.ox, inst.oy, inst.oz = x, y, z
    end
end

-- current origin in Source units (follows moving objects and parents)
function Engine.getOrigin(inst)
    if inst.parent and inst.parent.alive then
        local px, py, pz = Engine.getOrigin(inst.parent)
        local o = inst.parentOffset
        return px + o[1], py + o[2], pz + o[3]
    end
    if inst.carrier and isElement(inst.carrier) and Carry then
        local x, y, z = Carry.heldPosition(inst.carrier)
        return toSource(x, y, z)
    end
    local obj = type(inst.obj) == "userdata" and inst.obj or nil
    if obj and isElement(obj) then
        return toSource(getElementPosition(obj))
    end
    return inst.ox, inst.oy, inst.oz
end

-------------------------------------------------------------------------------- inputs on players (!activator)
function Engine.playerInput(player, input, param, activator, caller)
    local li = string.lower(input or "")
    if li == "ignite" then
        setElementOnFire(player, true)
        setTimer(function() if isElement(player) then setElementOnFire(player, false) end end, 10000, 1)
    elseif li == "ignitelifetime" then
        local t = tonumber(param) or 10
        setElementOnFire(player, true)
        setTimer(function() if isElement(player) then setElementOnFire(player, false) end end, math.max(50, t * 1000), 1)
    elseif li == "extinguish" then
        setElementOnFire(player, false)
    elseif li == "kill" then
        -- removing a player entity in Source kills it
        Bridge.damagePlayer(player, 1000, nil, "map")
    elseif li == "sethealth" then
        local h = tonumber(param) or 100
        if h <= 0 then Bridge.damagePlayer(player, 1000, nil, "map") else setElementHealth(player, h) end
    elseif li == "forcedrop" then
        if Carry then Carry.dropByPlayer(player) end
    elseif li == "addoutput" then
        -- e.g. "targetname foo": remember a name on the player
        local k, v = tostring(param):match("^(%S+)%s+(.+)$")
        if k and lower(k) == "targetname" then setElementData(player, "mc.targetname", v, false) end
    else
        mcDebug("unhandled player input", input)
    end
end

-- activator name (for filter_activator_name)
function Engine.activatorName(a)
    if type(a) == "table" then return a.name end
    if isPlayerActivator(a) then return getElementData(a, "mc.targetname") end
    return nil
end

function Engine.activatorClass(a)
    if type(a) == "table" then return a.cls end
    if isPlayerActivator(a) then return "player" end
    return nil
end

-- periodic queue processing (delayed outputs)
setTimer(function() Engine.flush() end, 50, 0)
