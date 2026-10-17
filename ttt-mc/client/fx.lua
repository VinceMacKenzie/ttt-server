--[[
    Client effects: sky colours, fog / time / weather, torch glow, dynamic lights, tesla arcs,
    game_text HUD messages, screen fades, break effects, sounds.
]]

local sx, sy = guiGetScreenSize()
local FX = { coronas = {}, lights = {}, texts = {}, sparks = {}, sounds = {} }

local function stateElements(cls)
    local r = {}
    for _, el in ipairs(getElementsByType("mc_ent", resourceRoot)) do
        if not cls or getElementData(el, "cls") == cls then r[#r + 1] = el end
    end
    return r
end
FXStateElements = stateElements

-------------------------------------------------------------------------------- environment
local function fogState()
    for _, el in ipairs(stateElements("env_fog_controller")) do
        return el
    end
end

-- the map's environment (fog, sky, time, water colour) is only applied while the camera is at the map,
-- so the rest of the GTA world (e.g. ttt-core's lobby spawn) keeps its normal look
function FX.isAtMap()
    if getElementInterior(localPlayer) ~= Config.INTERIOR then return false end
    local cx, cy, cz = getCameraMatrix()
    return nearMap(cx, cy, cz, 60)
end

FX.envActive = nil
function FX.applyEnvironment()
    local active = FX.isAtMap()
    if not active then
        if FX.envActive ~= false then
            resetFogDistance()
            resetFarClipDistance()
            resetSkyGradient()
            resetWaterColor()
            if FX.colorFilterOff then resetColorFilter() FX.colorFilterOff = nil end
            if FX.savedEnv then
                local e = FX.savedEnv
                setTime(e.h, e.m)
                setMinuteDuration(e.md)
                setWeather(e.w)
                FX.savedEnv = nil
            end
            FX.envActive = false
        end
        return
    end
    if FX.envActive ~= true and Config.LOCK_TIME then
        local h, m = getTime()
        FX.savedEnv = { h = h, m = m, md = getMinuteDuration(), w = getWeather() }
    end
    FX.envActive = true
    if Config.LOCK_TIME then
        setTime(Config.TIME[1], Config.TIME[2])
        setMinuteDuration(60000)
        setWeather(Config.WEATHER)
    end
    -- the Minecraft sky is a plain gradient: GTA's own sky with the skybox colours (always behind everything)
    local sky = MAP_DATA.sky
    local top = sky and sky.top or { 132, 166, 255 }
    local fog = fogState()
    local fr, fg, fb = 173, 199, 255
    local fs, fe = 62.5, 109.4
    local fogOn = Config.MAP_FOG and fog and getElementData(fog, "on") and true or false
    if fog then
        fr, fg, fb = getElementData(fog, "r") or fr, getElementData(fog, "g") or fg, getElementData(fog, "b") or fb
        fs, fe = getElementData(fog, "fogstart") or fs, getElementData(fog, "fogend") or fe
    end
    -- horizon = fog colour, so fogged blocks blend seamlessly into the sky (like in GMod)
    local hr, hg, hb = fr, fg, fb
    if not fogOn and sky and sky.bottom then hr, hg, hb = sky.bottom[1], sky.bottom[2], sky.bottom[3] end
    setSkyGradient(top[1], top[2], top[3], hr, hg, hb)
    -- the fog is drawn by client/world.fx; the view distance must cover the whole map (a short far clip
    -- cut the map into slices in game)
    if Models and Models.setFog then Models.setFog(fogOn, fr, fg, fb, fs, fe) end
    resetFogDistance()
    if getFarClipDistance() < Config.FAR_CLIP then setFarClipDistance(Config.FAR_CLIP) end
    local wc = Config.WATER_COLOR
    setWaterColor(wc[1], wc[2], wc[3], wc[4])
    -- GTA's weather colour filter adds a yellowish brightness over the whole screen (LS sunny noon): the
    -- map then looked overbright and the sky white
    if Config.NO_COLOR_FILTER then
        setColorFilter(0, 0, 0, 0, 0, 0, 0, 0)
        FX.colorFilterOff = true
    end
end

-- Like in GMod, other players disappear in the fog (otherwise they would stand out crisp against the fogged
-- map from far away). Only players whose alpha nobody else controls are touched (e.g. ttt-replay sets its own).
FX.fade = {}
local function fadeRestore()
    for p, a in pairs(FX.fade) do
        if isElement(p) and getElementAlpha(p) == a then setElementAlpha(p, 255) end
    end
    FX.fade = {}
end
setTimer(function()
    local f = Models and Models.fog
    if not FX.envActive or not f or f.on ~= 1 then
        if next(FX.fade) then fadeRestore() end
        return
    end
    local cx, cy, cz = getCameraMatrix()
    for _, p in ipairs(getElementsByType("player", root, true)) do
        if p ~= localPlayer then
            local cur, mine = getElementAlpha(p), FX.fade[p]
            if mine and cur ~= mine then
                FX.fade[p] = nil                       -- someone else changed it: hands off
            elseif mine or cur == 255 then
                local x, y, z = getElementPosition(p)
                local d = getDistanceBetweenPoints3D(cx, cy, cz, x, y, z)
                local k = math.max(0, math.min(1, (d - f.s) / math.max(0.01, f.e - f.s)))
                local a = math.floor(255 * (1 - k) + 0.5)
                if a ~= cur then setElementAlpha(p, a) end
                FX.fade[p] = (a ~= 255) and a or nil
            end
        end
    end
end, 100, 0)
addEventHandler("onClientResourceStop", resourceRoot, function() fadeRestore() end)

setTimer(function() FX.applyEnvironment() end, 2000, 0)
-- react quickly when the camera arrives at / leaves the map
setTimer(function()
    local a = FX.isAtMap()
    if a ~= FX.envActive then FX.applyEnvironment() end
end, 250, 0)

-------------------------------------------------------------------------------- torches & lights
local function refreshPointFx()
    for _, m in pairs(FX.coronas) do if isElement(m) then destroyElement(m) end end
    FX.coronas = {}
    if Config.TORCH_GLOW then
        for _, el in ipairs(stateElements("env_fire")) do
            if getElementData(el, "on") then
                local x, y, z = getElementData(el, "x"), getElementData(el, "y"), getElementData(el, "z")
                local m = createMarker(x, y, z + 0.05, "corona", 0.45, 255, 170, 60, 110)
                if m then
                    setElementDimension(m, Config.DIMENSION)
                    setElementInterior(m, Config.INTERIOR)
                    FX.coronas[el] = m
                end
            end
        end
    end
    for _, l in pairs(FX.lights) do if isElement(l) then destroyElement(l) end end
    FX.lights = {}
    for _, el in ipairs(stateElements("light_dynamic")) do
        if getElementData(el, "on") then
            -- createLight only lights peds; the visible glow on the map is a coloured corona
            local x, y, z = getElementData(el, "x"), getElementData(el, "y"), getElementData(el, "z")
            local r, g, b = getElementData(el, "r") or 255, getElementData(el, "g") or 255, getElementData(el, "b") or 255
            local l = createLight(0, x, y, z, math.max(1, getElementData(el, "radius") or 4), r, g, b)
            local m = createMarker(x, y, z, "corona", 0.6, r, g, b, 90)
            for _, e in ipairs({ l, m }) do
                if e then
                    setElementDimension(e, Config.DIMENSION)
                    setElementInterior(e, Config.INTERIOR)
                end
            end
            FX.lights[el] = l
            FX.lights[tostring(el) .. "c"] = m
        end
    end
end

local refreshPending = false
local function scheduleRefresh()
    if refreshPending then return end
    refreshPending = true
    setTimer(function() refreshPending = false refreshPointFx() FX.applyEnvironment() end, 100, 1)
end

addEventHandler("onClientElementDataChange", resourceRoot, function()
    if getElementType(source) == "mc_ent" then scheduleRefresh() end
end)
addEventHandler("onClientElementDestroy", resourceRoot, function()
    if getElementType(source) == "mc_ent" then scheduleRefresh() end
end)
addEvent("mc:mapReset", true)
addEventHandler("mc:mapReset", resourceRoot, function() scheduleRefresh() end)

-------------------------------------------------------------------------------- tesla arcs (win sequence)
addEventHandler("onClientRender", root, function()
    local t = getTickCount()
    for _, el in ipairs(stateElements("point_tesla")) do
        if getElementData(el, "on") then
            local nextT = FX.sparks[el] or 0
            if t >= nextT then
                FX.sparks[el] = t + math.random(100, 400)
                local x, y, z = getElementData(el, "x"), getElementData(el, "y"), getElementData(el, "z")
                local r = getElementData(el, "radius") or 8
                FX.bolts = FX.bolts or {}
                for i = 1, math.random(12, 18) do
                    local a, b = math.random() * math.pi * 2, (math.random() - 0.5) * math.pi
                    local ex, ey, ez = x + math.cos(a) * math.cos(b) * r, y + math.sin(a) * math.cos(b) * r, z + math.sin(b) * r
                    local hit, hx, hy, hz = processLineOfSight(x, y, z, ex, ey, ez, true, false, false, true)
                    if hit then ex, ey, ez = hx, hy, hz end
                    FX.bolts[#FX.bolts + 1] = { x, y, z, ex, ey, ez, t + math.random(300, 400) }
                end
            end
        end
    end
    if FX.bolts then
        for i = #FX.bolts, 1, -1 do
            local b = FX.bolts[i]
            if t > b[7] then
                table.remove(FX.bolts, i)
            else
                -- jagged bolt
                local px, py, pz = b[1], b[2], b[3]
                for s = 1, 6 do
                    local f = s / 6
                    local nx = b[1] + (b[4] - b[1]) * f + (s < 6 and (math.random() - 0.5) * 0.4 or 0)
                    local ny = b[2] + (b[5] - b[2]) * f + (s < 6 and (math.random() - 0.5) * 0.4 or 0)
                    local nz = b[3] + (b[6] - b[3]) * f + (s < 6 and (math.random() - 0.5) * 0.4 or 0)
                    dxDrawLine3D(px, py, pz, nx, ny, nz, tocolor(200, 220, 255, 230), 2.5)
                    px, py, pz = nx, ny, nz
                end
            end
        end
    end
end)

-------------------------------------------------------------------------------- game_text (HUD)
addEvent("mc:gametext", true)
addEventHandler("mc:gametext", resourceRoot, function(msg, r, g, b, x, y, hold, fadein, fadeout, channel)
    FX.texts[channel or 1] = { msg = msg, r = r, g = g, b = b, x = x, y = y, t0 = getTickCount(),
                               hold = hold * 1000, fin = fadein * 1000, fout = fadeout * 1000 }
end)

addEventHandler("onClientRender", root, function()
    local t = getTickCount()
    for ch, tx in pairs(FX.texts) do
        local e = t - tx.t0
        local total = tx.fin + tx.hold + tx.fout
        if e > total then
            FX.texts[ch] = nil
        else
            local a = 255
            if e < tx.fin then a = 255 * e / math.max(1, tx.fin)
            elseif e > tx.fin + tx.hold then a = 255 * (1 - (e - tx.fin - tx.hold) / math.max(1, tx.fout)) end
            local px = (tx.x < 0) and sx / 2 or tx.x * sx
            local py = (tx.y < 0) and sy / 2 or tx.y * sy
            local align = (tx.x < 0) and "center" or "left"
            local w = sx
            dxDrawText(tx.msg, px - (align == "center" and w / 2 or 0) + 2, py + 2, px + (align == "center" and w / 2 or w) + 2, py + 2,
                tocolor(0, 0, 0, a * 0.8), 1.6, "default-bold", align, "center")
            dxDrawText(tx.msg, px - (align == "center" and w / 2 or 0), py, px + (align == "center" and w / 2 or w), py,
                tocolor(tx.r, tx.g, tx.b, a), 1.6, "default-bold", align, "center")
        end
    end
end)

-------------------------------------------------------------------------------- env_fade
addEvent("mc:fade", true)
addEventHandler("mc:fade", resourceRoot, function(r, g, b, dur, hold, fadeIn, stayOut)
    if fadeIn then
        fadeCamera(false, 0, r, g, b)
        fadeCamera(true, dur)
        return
    end
    fadeCamera(false, dur, r, g, b)
    if not stayOut then
        setTimer(function() fadeCamera(true, dur) end, math.max(50, (dur + hold) * 1000), 1)
    end
end)

-------------------------------------------------------------------------------- break / explosion effects
addEvent("mc:breakFx", true)
addEventHandler("mc:breakFx", resourceRoot, function(x, y, z, mat, size)
    local count = math.max(8, math.min(60, math.floor(size * 12)))
    if mat == 0 or mat == 7 then
        fxAddGlass(x, y, z, 200, 220, 255, 160, 0.5, count)
    elseif mat == 1 then
        fxAddWood(x, y, z, 0, 0, 1, count)
    else
        fxAddDebris(x, y, z, 120, 120, 120, 255, 0.4, count)
    end
end)

addEvent("mc:explosionFx", true)
addEventHandler("mc:explosionFx", resourceRoot, function(x, y, z)
    fxAddSparks(x, y, z, 0, 0, 1, 2, 40)
end)

-------------------------------------------------------------------------------- ambient_generic
-- The map's sounds are Source/HL2 game sounds and are not packed in the BSP. To get them, put the
-- files into sounds/ (e.g. sounds/ambient/wind/windgust.wav), list them in meta.xml and they play.
addEvent("mc:sound", true)
addEventHandler("mc:sound", resourceRoot, function(uid, on)
    local el
    for _, e in ipairs(stateElements("ambient_generic")) do if getElementData(e, "uid") == uid then el = e end end
    if not el then return end
    if FX.sounds[uid] and isElement(FX.sounds[uid]) then destroyElement(FX.sounds[uid]) end
    FX.sounds[uid] = nil
    if not on then return end
    local path = "sounds/" .. tostring(getElementData(el, "sound") or ""):gsub("\\", "/")
    if not fileExists(path) then return end
    local s
    if getElementData(el, "everywhere") then
        s = playSound(path, getElementData(el, "loop"))
    else
        s = playSound3D(path, getElementData(el, "x"), getElementData(el, "y"), getElementData(el, "z"), getElementData(el, "loop"))
        if s then setSoundMaxDistance(s, getElementData(el, "radius") or 40) end
    end
    FX.sounds[uid] = s
end)

-------------------------------------------------------------------------------- start / stop
addEventHandler("onClientResourceStart", resourceRoot, function()
    FX.applyEnvironment()
    scheduleRefresh()
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    resetFogDistance()
    resetFarClipDistance()
    resetSkyGradient()
    resetWaterColor()
    if FX.colorFilterOff then resetColorFilter() end
end)

-- short sound effects from the server (carrying, furnace, chest, buttons)
addEvent("mc:sfx", true)
addEventHandler("mc:sfx", resourceRoot, function(name, x, y, z)
    if type(name) ~= "string" or not name:match("^[%w_]+$") then return end
    local path = "sounds/sfx/" .. name .. ".wav"
    if not fileExists(path) then return end
    local s = playSound3D(path, x, y, z)
    if s then
        -- Minecraft plays its block / item sounds with a random pitch
        if name == "pickup" or name == "drop" or name == "place" then setSoundSpeed(s, 0.8 + math.random() * 0.5) end
        setSoundMaxDistance(s, 30)
        setElementDimension(s, getElementDimension(localPlayer))
        setElementInterior(s, getElementInterior(localPlayer))
    end
end)
