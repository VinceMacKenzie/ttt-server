--[[
    +use carrying of func_physbox blocks (gold block, diamond ores, clay, bricks, diamond block),
    like picking up physics props in GMod. Dropped blocks fall to the ground (ground height is
    measured by a client with processLineOfSight because the server has no collision world).
]]

Carry = { byPlayer = {}, pending = {}, aim = {} }
local HOLD_DIST, HOLD_UP = 1.4, 0.15

local function heldPosition(player)
    local x, y, z = getElementPosition(player)
    local _, _, rz = getElementRotation(player)
    local a = math.rad(rz)
    local up = HOLD_UP + (Carry.aim[player] or 0)
    return x - math.sin(a) * HOLD_DIST, y + math.cos(a) * HOLD_DIST, z + up, rz
end
Carry.heldPosition = heldPosition

function Carry.pickup(inst, player)
    if Carry.byPlayer[player] or not (inst.obj and isElement(inst.obj)) then return end
    inst.carrier = player
    Carry.byPlayer[player] = inst
    stopObject(inst.obj)
    attachElements(inst.obj, player, 0, HOLD_DIST, HOLD_UP + (Carry.aim[player] or 0))
    setElementData(inst.obj, "mc.carrier", player)
    Bridge.sfxAt("pickup", inst)
    Engine.fireOutput(inst, "OnPlayerPickup", player)
end

-- detach without dropping logic (entity killed / teleported)
function Carry.release(inst)
    local pl = inst.carrier
    if not pl then return end
    inst.carrier = nil
    Carry.byPlayer[pl] = nil
    if inst.obj and isElement(inst.obj) then
        detachElements(inst.obj)
        setElementData(inst.obj, "mc.carrier", false)
    end
end

-- A trigger near the player that wants exactly this block (furnace <- diamond ore, crafting table <- gold
-- block, lighthouse <- diamond block, pigman furnace <- clay...): dropping the block puts it right there.
local function targetTrigger(inst, pl)
    local px, py, pz = getElementPosition(pl)
    local best, bestD
    for _, t in ipairs(Engine.all()) do
        local f = t.kv and t.kv.filtername
        if t.alive and t.isTrigger and t.enabled and f and f ~= "" and t.def.mins and Engine.passesFilter(f, inst) then
            local ox, oy, oz = Engine.getOrigin(t)
            local cx = ox + (t.def.mins[1] + t.def.maxs[1]) / 2
            local cy = oy + (t.def.mins[2] + t.def.maxs[2]) / 2
            local cz = oz + (t.def.mins[3] + t.def.maxs[3]) / 2
            local wx, wy, wz = toWorld(cx, cy, cz)
            local d = getDistanceBetweenPoints3D(px, py, pz, wx, wy, wz)
            if d <= Config.DROP_ASSIST_RANGE and (not bestD or d < bestD) then
                best, bestD = { cx, cy, oz + t.def.mins[3], t }, d
            end
        end
    end
    return best
end

function Carry.drop(inst, frozen)
    local pl = inst.carrier
    if not pl then return end
    local x, y, z = heldPosition(pl)
    local tgt = (not frozen) and Config.DROP_ASSIST_RANGE and targetTrigger(inst, pl)
    if tgt then
        Carry.release(inst)
        if inst.obj and isElement(inst.obj) then
            local sx, sy, sz = tgt[1], tgt[2], tgt[3] - inst.def.mins[3]
            local wx, wy, wz = toWorld(sx, sy, sz)
            setElementPosition(inst.obj, wx, wy, wz)
            setElementRotation(inst.obj, 0, 0, 0)
            inst.ox, inst.oy, inst.oz = sx, sy, sz
            -- (the sound comes from the trigger that takes the block: server/triggers.lua)
            Engine.fireOutput(inst, "OnPhysGunDrop", pl)
        end
        return
    end
    Carry.release(inst)
    if inst.obj and isElement(inst.obj) then
        setElementPosition(inst.obj, x, y, z)
        setElementRotation(inst.obj, 0, 0, 0)
        inst.ox, inst.oy, inst.oz = toSource(x, y, z)
        Bridge.sfx("drop", x, y, z)
        Engine.fireOutput(inst, "OnPhysGunDrop", pl)
        if not frozen then Carry.settle(inst, pl) end
    end
end

function Carry.dropByPlayer(player)
    local inst = Carry.byPlayer[player]
    if inst then Carry.drop(inst) end
end

-- let an object fall onto whatever is below it
function Carry.settle(inst, askPlayer)
    if not inst.alive or inst.carrier or not (inst.obj and isElement(inst.obj)) then return end
    local x, y, z = getElementPosition(inst.obj)
    local pl = askPlayer
    if not (pl and isElement(pl)) then
        local best
        for _, p in ipairs(getElementsByType("player")) do
            local px, py, pz = getElementPosition(p)
            local d = (px - x) ^ 2 + (py - y) ^ 2 + (pz - z) ^ 2
            if not best or d < best then best, pl = d, p end
        end
    end
    if not pl then return end
    Carry.pending[inst.uid] = Engine.generation
    triggerClientEvent(pl, "mc:groundQuery", resourceRoot, inst.uid, x, y, z)
end

addEvent("mc:groundReply", true)
addEventHandler("mc:groundReply", resourceRoot, function(uid, groundZ)
    if Carry.pending[uid] ~= Engine.generation then return end
    Carry.pending[uid] = nil
    local inst = Engine.ents[uid]
    if not inst or not inst.alive or inst.carrier or not (inst.obj and isElement(inst.obj)) then return end
    if type(groundZ) ~= "number" then return end
    local x, y, z = getElementPosition(inst.obj)
    local half = -inst.def.mins[3] * SCALE
    local tz = groundZ + half
    if tz >= z - 0.02 then return end
    if z - tz > Config.SETTLE_MAX_DROP then return end   -- no ground found nearby: stay (never lose a block)
    local h = z - tz
    local dur = math.max(50, math.floor(math.sqrt(2 * h / 9.81) * 1000))
    moveObject(inst.obj, dur, x, y, tz, 0, 0, 0, "InQuad")
    inst.ox, inst.oy, inst.oz = toSource(x, y, tz)
end)

-- the carrier's view pitch moves the block up/down (like holding props in GMod)
addEvent("mc:carryAim", true)
addEventHandler("mc:carryAim", resourceRoot, function(dz)
    local pl = client
    dz = math.max(-1.1, math.min(1.0, tonumber(dz) or 0))
    Carry.aim[pl] = dz
    local inst = Carry.byPlayer[pl]
    if inst and inst.obj and isElement(inst.obj) then
        setElementAttachedOffsets(inst.obj, 0, HOLD_DIST, HOLD_UP + dz)
    end
end)

addEventHandler("onPlayerWasted", root, function() Carry.dropByPlayer(source) end)
addEventHandler("onPlayerQuit", root, function() Carry.dropByPlayer(source) Carry.aim[source] = nil end)

function Carry.reset()
    Carry.byPlayer = {}
    Carry.pending = {}
end
