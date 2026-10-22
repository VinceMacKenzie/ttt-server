--[[
    Source PVS emulation + map water.

    Zones: the map's BSP clusters grouped into areas that can never see each other (overworld, nether,
    sealed win room...). Like Source's visibility culling, only the zone the camera is in is drawn: the other
    zones' models get an invisible shader (their collision stays, so nobody falls through anything).
    Without this the inside of the sealed win room showed as a black box in the sky.

    Water: GTA water is a flat quad and everything below it counts as under water, at any depth. The water
    quads (only the real water surfaces) are created on this client only while the camera is in their zone,
    so the nether (deep under the ocean) is not "under water".
]]

Zones = { current = nil, hidden = {}, shader = nil, waters = {}, boxZone = {}, modelZone = {} }

local Z = MAP_DATA.zones

-- point (Source units) -> zone id
function Zones.at(x, y, z)
    if not Z or not Z.nodes or #Z.nodes == 0 then return 0 end
    local n = 0
    for _ = 1, 4096 do
        local nd = Z.nodes[n + 1]
        local pl = Z.planes[nd[1] + 1]
        local d = pl[1] * x + pl[2] * y + pl[3] * z - pl[4]
        local c = (d >= 0) and nd[2] or nd[3]
        if c < 0 then return -1 - c end
        n = c
    end
    return 0
end

-- Source decides by the view position; a GTA third person camera often sits inside a wall, so the player's
-- head is used (the camera when the player is far away, e.g. spectating)
function Zones.cameraZone()
    local cx, cy, cz = getCameraMatrix()
    local x, y, z = getElementPosition(localPlayer)
    -- the camera is somewhere else (ttt-replay: recorded camera, ttt-skin preview...): use the camera itself
    if not isPedDead(localPlayer) and getCameraTarget() == localPlayer
        and getDistanceBetweenPoints3D(cx, cy, cz, x, y, z) < 12 then
        return Zones.at(toSource(x, y, z + 0.6))
    end
    return Zones.at(toSource(cx, cy, cz))
end

for _, def in ipairs(MAP_ENTS) do
    if def.mdl then Zones.modelZone[def.mdl.name] = def.mdl.zone or 0 end
end

local function hideShader()
    if Zones.shader == nil then
        local sh = dxCreateShader("client/hide.fx", 2, 0, false, "object")
        Zones.shader = sh or false
    end
    return Zones.shader
end

-- show / hide one object according to the current zone
function Zones.applyTo(obj, zone)
    if not isElement(obj) then return end
    local sh = hideShader()
    if not sh then return end
    local hide = Config.ZONE_CULLING and Zones.current ~= nil and (zone or 0) ~= Zones.current
    if hide and not Zones.hidden[obj] then
        engineApplyShaderToWorldTexture(sh, "*", obj)
        Zones.hidden[obj] = true
    elseif not hide and Zones.hidden[obj] then
        engineRemoveShaderFromWorldTexture(sh, "*", obj)
        Zones.hidden[obj] = nil
    end
end

-- world chunks have a fixed zone; entity objects (doors, blocks that get teleported around...) use the zone of
-- their current position
function Zones.objectZone(obj)
    local wz = Models.worldZone and Models.worldZone[obj]
    if wz then return wz end
    local def = MAP_ENTS[getElementData(obj, "mc.entid") or 0]
    local x, y, z = getElementPosition(obj)
    local sx, sy, sz = toSource(x, y, z)
    if def and def.mins and def.maxs then
        sx = sx + (def.mins[1] + def.maxs[1]) / 2
        sy = sy + (def.mins[2] + def.maxs[2]) / 2
        sz = sz + (def.mins[3] + def.maxs[3]) / 2
    end
    return Zones.at(sx, sy, sz)
end

function Zones.refreshEntities()
    for _, obj in ipairs(getElementsByType("object", resourceRoot)) do
        if getElementData(obj, "mc.model") then
            -- like the world models: doors, blocks, ores... also visible for ttt-replay viewers (own dimension)
            if Config.VISIBLE_IN_ALL_DIMENSIONS and getElementDimension(obj) == Config.DIMENSION then
                setElementDimension(obj, -1)
            end
            Zones.applyTo(obj, Zones.objectZone(obj))
        end
    end
end

function Zones.refreshAll()
    for _, obj in ipairs(Models.world) do Zones.applyTo(obj, Zones.objectZone(obj)) end
    Zones.refreshEntities()
    for obj in pairs(Zones.hidden) do
        if not isElement(obj) then Zones.hidden[obj] = nil end
    end
end

-------------------------------------------------------------------------------- water
local function liveEntities()
    local alive = {}
    for _, obj in ipairs(getElementsByType("object", resourceRoot)) do
        local id = getElementData(obj, "mc.entid")
        if id then alive[id] = true end
    end
    return alive
end

local function createQuads(i, w)
    local list = {}
    local o = Config.OFFSET
    local z = w.maxs[3] * SCALE + o[3] - 0.03   -- just under the map's water texture
    for _, q in ipairs(w.quads or {}) do
        -- MTA puts water corners on even coordinates: snap outward so nothing shrinks
        local x1 = math.floor((q[1] + o[1] + 0.01) / 2) * 2
        local y1 = math.floor((q[2] + o[2] + 0.01) / 2) * 2
        local x2 = math.ceil((q[3] + o[1] - 0.01) / 2) * 2
        local y2 = math.ceil((q[4] + o[2] - 0.01) / 2) * 2
        if x2 - x1 >= 2 and y2 - y1 >= 2 then
            local el = createWater(x1, y1, z, x2, y1, z, x1, y2, z, x2, y2, z)
            if el then
                setElementDimension(el, Config.DIMENSION)
                setElementInterior(el, Config.INTERIOR)
                list[#list + 1] = el
            end
        end
    end
    Zones.waters[i] = list
end

local function destroyQuads(i)
    for _, el in ipairs(Zones.waters[i] or {}) do if isElement(el) then destroyElement(el) end end
    Zones.waters[i] = nil
end

function Zones.updateWater(cz)
    local alive = liveEntities()
    for i, w in ipairs(MAP_DATA.water or {}) do
        if Zones.boxZone[i] == nil then
            Zones.boxZone[i] = Zones.at((w.mins[1] + w.maxs[1]) / 2, (w.mins[2] + w.maxs[2]) / 2, w.maxs[3] - 1)
        end
        local want = (w.ent == nil or alive[w.ent] == true) and (cz == nil or cz == Zones.boxZone[i])
        if want and not Zones.waters[i] then
            createQuads(i, w)
        elseif not want and Zones.waters[i] then
            destroyQuads(i)
        end
    end
end

-------------------------------------------------------------------------------- loop
function Zones.tick()
    if not Models.ready then return end
    local cz = Zones.cameraZone()
    if cz ~= Zones.current then
        Zones.current = cz
        Zones.refreshAll()
    else
        Zones.refreshEntities()
    end
    Zones.updateWater(cz)
end

setTimer(function() Zones.tick() end, 100, 0)

addEventHandler("onClientResourceStop", resourceRoot, function()
    for i in pairs(Zones.waters) do destroyQuads(i) end
end)
