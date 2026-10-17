--[[
    Loads all converted models (DFF/COL/TXD), creates the static world chunks and swaps the
    real models onto the server-created entity objects (doors, buttons, blocks, trains...).
]]

Models = { ids = {}, world = {}, worldZone = {}, txd = nil, ready = false, shaders = {} }
MAP_TEXTURES = MAP_DATA.textures or {}
MAP_DECALS = MAP_DATA.decals or {}

-------------------------------------------------------------------------------- world shader
-- client/world.fx draws every map texture as texture x baked lightmap with the map's own fog (no GTA
-- dynamic lighting). Without shader model 2 GTA draws the models itself (still prelit-only, see the DFFs).
Models.fog = { on = 1, r = 173 / 255, g = 199 / 255, b = 1, s = 62.5, e = 109.4 }

local function newWorldShader(priority)
    local sh, tec = dxCreateShader("client/world.fx", priority or 0, 0, false, "object")
    if not sh then return nil end
    if tec ~= "world" then
        destroyElement(sh)
        return nil
    end
    local f = Models.fog
    dxSetShaderValue(sh, "gMapFogColor", f.r, f.g, f.b)
    dxSetShaderValue(sh, "gMapFogStart", f.s)
    dxSetShaderValue(sh, "gMapFogEnd", f.e)
    dxSetShaderValue(sh, "gMapFogOn", f.on)
    dxSetShaderValue(sh, "gBrightness", Config.MAP_BRIGHTNESS or 1)
    Models.shaders[sh] = true
    return sh
end

function Models.setFog(on, r, g, b, fstart, fend)
    Models.fog = { on = on and 1 or 0, r = r / 255, g = g / 255, b = b / 255, s = fstart, e = fend }
    for sh in pairs(Models.shaders) do
        if isElement(sh) then
            dxSetShaderValue(sh, "gMapFogColor", r / 255, g / 255, b / 255)
            dxSetShaderValue(sh, "gMapFogStart", fstart)
            dxSetShaderValue(sh, "gMapFogEnd", fend)
            dxSetShaderValue(sh, "gMapFogOn", on and 1 or 0)
        else
            Models.shaders[sh] = nil
        end
    end
end

local function createWorldShaders()
    if not Config.WORLD_SHADER then return end
    local isDecal = {}
    for _, t in ipairs(MAP_DECALS) do isDecal[t] = true end
    local world = newWorldShader(0)
    if not world then
        outputDebugString("[mc] world.fx not supported on this PC - GTA renders the map (prelit only)", 2)
        return
    end
    for _, t in ipairs(MAP_TEXTURES) do
        if not isDecal[t] then engineApplyShaderToWorldTexture(world, t) end
    end
    Models.worldShader = world
    local decal = newWorldShader(0)
    if decal then
        dxSetShaderValue(decal, "gDecal", Config.DECAL_PULL)
        for _, t in ipairs(MAP_DECALS) do engineApplyShaderToWorldTexture(decal, t) end
        Models.decalShader = decal
    end
end

local function loadModel(name, hasCol, alpha)
    local id = engineRequestModel("object", Config.MODEL_PARENT)
    if not id then
        outputDebugString("[mc] engineRequestModel failed for " .. name, 1)
        return nil
    end
    engineImportTXD(Models.txd, id)
    local dff = engineLoadDFF("models/" .. name .. ".dff")
    if not dff or not engineReplaceModel(dff, id, alpha and true or false) then
        outputDebugString("[mc] failed to load models/" .. name .. ".dff", 1)
    end
    -- every model has a COL: GTA culls objects by its bounding sphere (non-solid models get a COL that only
    -- carries the bounds; their collisions are switched off on the object)
    local colPath = "models/" .. name .. ".col"
    if fileExists(colPath) then
        local col = engineLoadCOL(colPath)
        if col then engineReplaceCOL(col, id) end
    end
    engineSetModelLODDistance(id, Config.LOD_DISTANCE)
    if alpha and engineSetModelFlag then pcall(engineSetModelFlag, id, "draw_last", true) end
    Models.ids[name] = id
    return id
end

-- Source rendercolor tint: a per object instance of the world shader (higher priority than the shared one)
Models.tints = {}
function Models.applyTint(obj)
    local rc = getElementData(obj, "mc.color")
    local sh = Models.tints[obj]
    if not rc or rc == "255 255 255" then
        if sh then
            if isElement(sh) then engineRemoveShaderFromWorldTexture(sh, "*", obj) destroyElement(sh) end
            Models.shaders[sh] = nil
            Models.tints[obj] = nil
        end
        return
    end
    if not sh then
        sh = newWorldShader(1)
        if not sh then return end
        engineApplyShaderToWorldTexture(sh, "*", obj)
        Models.tints[obj] = sh
    end
    local r, g, b = vec3(rc)
    dxSetShaderValue(sh, "gColor", r / 255, g / 255, b / 255, 1)
end

addEventHandler("onClientElementDestroy", root, function()
    local sh = Models.tints[source]
    if sh then
        if isElement(sh) then destroyElement(sh) end
        Models.shaders[sh] = nil
        Models.tints[source] = nil
    end
end)

-- apply the real model to a server-created placeholder object
function Models.apply(obj)
    if not isElement(obj) then return end
    local name = getElementData(obj, "mc.model")
    if not name then return end
    local id = Models.ids[name]
    if not id then return end
    if getElementModel(obj) ~= id then setElementModel(obj, id) end
    -- models without our COL would inherit the parent model's collision -> disable it
    local col = getElementData(obj, "mc.col")
    local carrier = getElementData(obj, "mc.carrier")
    setElementCollisionsEnabled(obj, col and not (carrier and isElement(carrier)) or false)
    Models.applyTint(obj)
    if Zones then Zones.applyTo(obj, Zones.objectZone(obj)) end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    Models.txd = engineLoadTXD("models/map.txd", Config.TEXTURE_FILTERING)
    -- world chunks
    for _, w in ipairs(MAP_DATA.world) do
        local id = loadModel(w.name, w.col, w.alpha)
        if id then
            local x, y, z = w.pos[1] + Config.OFFSET[1], w.pos[2] + Config.OFFSET[2], w.pos[3] + Config.OFFSET[3]
            local obj = createObject(id, x, y, z)
            if obj then
                -- dimension -1 = visible in every dimension (e.g. ttt-replay viewers watch in their own dimension)
                if not (Config.VISIBLE_IN_ALL_DIMENSIONS and setElementDimension(obj, -1)) then
                    setElementDimension(obj, Config.DIMENSION)
                end
                setElementInterior(obj, Config.INTERIOR)
                if not w.col then setElementCollisionsEnabled(obj, false) end
                Models.world[#Models.world + 1] = obj
                Models.worldZone[obj] = w.zone or 0
            end
        end
    end
    -- entity models
    local done = {}
    for _, def in ipairs(MAP_ENTS) do
        local m = def.mdl
        if m and not done[m.name] then
            done[m.name] = true
            loadModel(m.name, m.col, m.alpha)
        end
    end
    createWorldShaders()
    Models.ready = true
    for _, obj in ipairs(getElementsByType("object", resourceRoot)) do Models.apply(obj) end
    triggerServerEvent("mc:clientReady", resourceRoot)
end)

addEventHandler("onClientElementStreamIn", root, function()
    if getElementType(source) == "object" and Models.ready then Models.apply(source) end
end)

addEventHandler("onClientElementDataChange", root, function(key)
    if getElementType(source) ~= "object" then return end
    if key == "mc.model" or key == "mc.carrier" or key == "mc.col" or key == "mc.color" then Models.apply(source) end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    for _, obj in ipairs(Models.world) do if isElement(obj) then destroyElement(obj) end end
    for _, id in pairs(Models.ids) do engineFreeModel(id) end
end)
