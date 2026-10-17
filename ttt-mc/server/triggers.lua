--[[
    Server-side touch detection for brush triggers (Source: StartTouch / EndTouch / Touch),
    using the exact brush planes of every trigger and the Source player hull.
]]

Triggers = { onMap = {}, lastGround = {} }
local now = getTickCount
local fire = function(...) return Engine.fireOutput(...) end
local POLL_MS = 100
local HURT_MS = 500

local function flags(inst) return inst.spawnflags end
local function hasFlag(inst, f) return bitAnd(inst.spawnflags, f) ~= 0 end

-- which activators may touch this trigger (Source spawnflags)
local function allowsPlayers(inst) return hasFlag(inst, 1) or hasFlag(inst, 64) end
local function allowsPhysics(inst) return hasFlag(inst, 8) or hasFlag(inst, 64) or hasFlag(inst, 1024) end

local function gatherActivators()
    local acts = {}
    for _, pl in ipairs(getElementsByType("player")) do
        if not isPedDead(pl) and getElementDimension(pl) == Config.DIMENSION
            and getElementInterior(pl) == Config.INTERIOR then
            local x, y, z = pedSourceOrigin(pl)
            acts[#acts + 1] = { a = pl, player = true, x = x, y = y, z = z, mins = PLAYER_MINS, maxs = PLAYER_MAXS }
        end
    end
    for _, inst in ipairs(Engine.all()) do
        if inst.alive and inst.isPhysics and inst.obj then
            local x, y, z = Engine.getOrigin(inst)
            acts[#acts + 1] = { a = inst, player = false, x = x, y = y, z = z, mins = inst.def.mins, maxs = inst.def.maxs }
        end
    end
    return acts
end

local function teleportDest(inst)
    local t = inst.kv.target
    if not t or t == "" then return nil end
    return Engine.findByName(t)[1]
end

local function hurt(inst, pl, interval)
    local dmg = (tonumber(inst.kv.damage) or 10) * interval
    if dmg <= 0 then return end
    local owner = Bridge.damageOwnerOf(inst)
    local dtype = tonumber(inst.kv.damagetype) or 0
    Bridge.damagePlayer(pl, dmg, owner, dtype, inst.killName)
    fire(inst, "OnHurtPlayer", pl)
    fire(inst, "OnHurt", pl)
end

local function itemSound(inst, act)
    if act.player or not Bridge or not Bridge.sfx then return end
    local fname = inst.kv.filtername
    local f = fname and fname ~= "" and Engine.findByName(fname)[1]
    if not f or f.cls ~= "filter_activator_name" or (f.kv.Negated or f.kv.negated) == "1" then return end
    local tn = string.lower((inst.kv.targetname or "") .. " " .. fname)
    local x, y, z = toWorld(act.x, act.y, act.z)
    Bridge.sfx("place", x, y, z)
    if tn:find("furnace", 1, true) then Bridge.sfx("furnace", x, y, z)
    elseif tn:find("diablock", 1, true) then Bridge.sfx("chest", x, y, z) end
end

local function onStartTouch(inst, a, act)
    itemSound(inst, act)
    local cls = inst.cls
    fire(inst, "OnStartTouch", a)
    if not inst.alive then return end
    if inst.touchCount == 1 then fire(inst, "OnStartTouchAll", a) end
    if cls == "trigger_teleport" then
        local dest = teleportDest(inst)
        if dest then Engine.teleportTo(a, dest) end
    elseif cls == "trigger_hurt" then
        if act.player then
            inst.lastHurt = inst.lastHurt or {}
            if now() - (inst.lastHurt[a] or 0) >= HURT_MS then
                inst.lastHurt[a] = now()
                hurt(inst, a, 0.5)
            end
        end
    elseif cls == "trigger_once" then
        fire(inst, "OnTrigger", a)
        Engine.kill(inst)
        return
    elseif cls == "trigger_multiple" then
        if now() >= inst.nextTrigger then
            fire(inst, "OnTrigger", a)
            local wait = tonumber(inst.kv.wait) or 0.2
            inst.nextTrigger = (wait < 0) and math.huge or (now() + math.max(0.05, wait) * 1000)
        end
    end
end

local function onEndTouch(inst, a)
    fire(inst, "OnEndTouch", a)
    if inst.alive and inst.touchCount == 0 then fire(inst, "OnEndTouchAll", a) end
end

function Triggers.poll()
    if not Rounds or not Rounds.ready then return end
    Engine.holdPoll()
    local acts = gatherActivators()
    for _, inst in ipairs(Engine.all()) do
        if inst.alive and inst.isTrigger and inst.enabled and inst.def.brushes then
            local ox, oy, oz = Engine.getOrigin(inst)
            local present = {}
            local pp, ph = allowsPlayers(inst), allowsPhysics(inst)
            for _, act in ipairs(acts) do
                if (act.player and pp) or (not act.player and ph) then
                    if brushesTouch(inst.def, ox, oy, oz, act.x, act.y, act.z, act.mins, act.maxs)
                        and Engine.passesFilter(inst.kv.filtername, act.a) then
                        present[act.a] = act
                    end
                end
            end
            -- new touches
            for a, act in pairs(present) do
                if inst.alive and inst.enabled and not inst.touching[a] then
                    inst.touching[a] = true
                    inst.touchCount = inst.touchCount + 1
                    onStartTouch(inst, a, act)
                end
            end
            -- ended touches
            if inst.alive then
                for a in pairs(inst.touching) do
                    if not present[a] then
                        inst.touching[a] = nil
                        inst.touchCount = inst.touchCount - 1
                        onEndTouch(inst, a)
                    end
                end
            end
            -- continuous touch
            if inst.alive and inst.enabled and inst.touchCount > 0 then
                if inst.cls == "trigger_multiple" and now() >= inst.nextTrigger then
                    local a = next(inst.touching)
                    fire(inst, "OnTrigger", a)
                    local wait = tonumber(inst.kv.wait) or 0.2
                    inst.nextTrigger = (wait < 0) and math.huge or (now() + math.max(0.05, wait) * 1000)
                elseif inst.cls == "trigger_hurt" then
                    inst.lastHurt = inst.lastHurt or {}
                    for a in pairs(inst.touching) do
                        if Engine.isPlayer(a) and now() - (inst.lastHurt[a] or 0) >= HURT_MS then
                            inst.lastHurt[a] = now()
                            hurt(inst, a, 0.5)
                        end
                    end
                elseif inst.cls == "trigger_teleport" then
                    local dest = teleportDest(inst)
                    if dest then
                        for a in pairs(inst.touching) do Engine.teleportTo(a, dest) end
                    end
                end
            end
        end
    end

    -- touch-activated func_buttons
    for _, inst in ipairs(Engine.all()) do
        if inst.alive and inst.touchActivated and inst.cls == "func_button" then
            local ox, oy, oz = Engine.getOrigin(inst)
            for _, act in ipairs(acts) do
                if act.player and brushesTouch({ mins = { inst.def.mins[1] - 2, inst.def.mins[2] - 2, inst.def.mins[3] - 2 },
                                                 maxs = { inst.def.maxs[1] + 2, inst.def.maxs[2] + 2, inst.def.maxs[3] + 2 } },
                        ox, oy, oz, act.x, act.y, act.z, act.mins, act.maxs) then
                    Classes.func_button.press(inst, act.a)
                end
            end
        end
    end

    -- players who were ON the map and fell out of it (nobody elsewhere in the GTA world is touched:
    -- e.g. ttt-core's Grove Street spawn or the dead-player parking spot at 0,0,-100)
    for _, act in ipairs(acts) do
        if act.player then
            local p = act.a
            local wx, wy, wz = getElementPosition(p)
            if getElementInterior(p) ~= Config.INTERIOR then
                Triggers.onMap[p] = nil
            elseif nearMap(wx, wy, wz, 4) then
                Triggers.onMap[p] = true
                if isPedOnGround and isPedOnGround(p) then Triggers.lastGround[p] = { wx, wy, wz } end
            elseif not insideMapXY(wx, wy, 40) then
                Triggers.onMap[p] = nil
            elseif Triggers.onMap[p] and wz < MAP_WMIN[3] - Config.FALL_KILL_MARGIN and wz > MAP_WMIN[3] - 300 then
                Triggers.onMap[p] = nil
                -- die where he fell off, so ttt-core's corpse can be found and identified
                local g = Triggers.lastGround[p]
                if g then setElementPosition(p, g[1], g[2], g[3]) end
                Bridge.damagePlayer(p, 1000, nil, "fall", "fell off the map")
            end
        end
    end
    Engine.flush()
end

setTimer(function()
    local ok, err = pcall(Triggers.poll)
    if not ok then outputDebugString("[mc] trigger poll error: " .. tostring(err), 1) end
end, POLL_MS, 0)

addEventHandler("onPlayerSpawn", root, function() Triggers.onMap[source] = nil end)
addEventHandler("onPlayerWasted", root, function() Triggers.onMap[source] = nil end)

-- forget players that leave
addEventHandler("onPlayerQuit", root, function()
    Triggers.onMap[source] = nil
    Triggers.lastGround[source] = nil
    for _, inst in ipairs(Engine.all()) do
        if inst.touching and inst.touching[source] then
            inst.touching[source] = nil
            inst.touchCount = inst.touchCount - 1
            onEndTouch(inst, source)
        end
    end
end)
