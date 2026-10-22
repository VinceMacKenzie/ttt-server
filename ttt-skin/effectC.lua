-----------------------------------------
-- TTT SKIN – EFFEKT (aura) RENDERER, kliens oldal
-- Saját particle rendszer dxDrawMaterialLine3D-vel (Metin2 stílusú aurák).
-- A játékosok aktív effektje a szinkronizált "tttEffect" elementData-ban van (csak a szerver állítja).
-- /effektek  -> más játékosok effektjeinek ki/bekapcsolása (FPS miatt, csak nálad)
-----------------------------------------
local MAX_DISTANCE       = 45    -- ennél messzebb nem rajzolunk
local MAX_PARTS_PER_PED  = 170   -- részecske limit / játékos
local DENSITY            = 1.8   -- sűrűség szorzó (kevesebb = jobb FPS, több = dúsabb aura)
local MAX_SPAWN_PER_FRAME = 8    -- akadás után se szórjon egyszerre túl sokat

local TEX_NAMES = {"glow", "spark", "flame", "smoke", "flake", "beam"}
local textures = {}

local states = {}        -- [ped] = {key, t, acc = {}, parts = {}}
local previewPeds = {}   -- [ped] = kulcs (pl. a skin bolt előnézeti pedje)
local ownedEffects = {}  -- [kulcs] = true
local activeEffect = nil
local showOthers = true

local BODY = {1, 3, 4, 5, 8, 22, 23, 24, 32, 33, 34, 41, 42, 51, 52}
local TWO_PI = math.pi * 2
local random, sin, cos, sqrt, min = math.random, math.sin, math.cos, math.sqrt, math.min

-----------------------------------------
-- ADATOK (szervertől)
-----------------------------------------
addEvent("ttt:receiveEffects", true)
addEvent("ttt:onEffectsChanged", false)   -- helyi esemény: a ttt-shop erre frissíti a listáját

addEventHandler("onClientResourceStart", resourceRoot, function()
    for _, n in ipairs(TEX_NAMES) do
        textures[n] = dxCreateTexture("effects/" .. n .. ".png", "argb", true, "clamp")
    end
    triggerServerEvent("ttt:requestOwnedEffects", localPlayer)
end)

addEventHandler("ttt:receiveEffects", root, function(ownedList, active)
    ownedEffects = {}
    for _, k in ipairs(ownedList or {}) do ownedEffects[k] = true end
    activeEffect = active
    triggerEvent("ttt:onEffectsChanged", localPlayer)
end)

function getOwnedEffects() return ownedEffects end
function getActiveEffect() return activeEffect end
function isEffectOwned(key) return ownedEffects[key] == true end

-- Előnézet egy tetszőleges pedre (nil = levétel)
function setPreviewEffect(ped, key)
    if not isElement(ped) then return end
    if key and EffectByKey[key] then previewPeds[ped] = key else previewPeds[ped] = nil end
    states[ped] = nil
end

-- EXPORT a ttt-shopnak: {key, name, price, desc, owned, active}
function getEffectShopList()
    local list = {}
    for i, e in ipairs(EffectList) do
        list[i] = {key = e.key, name = e.name, price = e.price, desc = e.desc,
                   owned = ownedEffects[e.key] == true, active = (activeEffect == e.key)}
    end
    return list
end

addCommandHandler("effektek", function()
    showOthers = not showOthers
    outputChatBox("#00c3ff[Effekt] #ffffffMás játékosok effektjei: " .. (showOthers and "#7cc576BEKAPCSOLVA" or "#d9534fKIKAPCSOLVA"),
        255, 255, 255, true)
end)

-----------------------------------------
-- SEGÉDEK
-----------------------------------------
local function R(v)
    if type(v) == "table" then return v[1] + random() * (v[2] - v[1]) end
    return v or 0
end

local camX, camY, camZ, rX, rY, rZ, uX, uY, uZ = 0, 0, 0, 1, 0, 0, 0, 0, 1
local function updateCamera()
    local cx, cy, cz, lx, ly, lz = getCameraMatrix()
    camX, camY, camZ = cx, cy, cz
    local fx, fy, fz = lx - cx, ly - cy, lz - cz
    local fl = sqrt(fx * fx + fy * fy + fz * fz)
    if fl < 0.0001 then return end
    fx, fy, fz = fx / fl, fy / fl, fz / fl
    local rl = sqrt(fy * fy + fx * fx)
    if rl < 0.0001 then rX, rY, rZ = 1, 0, 0 else rX, rY, rZ = fy / rl, -fx / rl, 0 end
    uX, uY, uZ = rY * fz - rZ * fy, rZ * fx - rX * fz, rX * fy - rY * fx
end

-- Kamera felé néző, forgatható sprite
local function drawSprite(tex, x, y, z, size, rot, color)
    local c, s = cos(rot), sin(rot)
    local ax, ay, az = uX * c + rX * s, uY * c + rY * s, uZ * c + rZ * s
    local h = size * 0.5
    dxDrawMaterialLine3D(x + ax * h, y + ay * h, z + az * h, x - ax * h, y - ay * h, z - az * h,
        tex, size, color, false, camX, camY, camZ)
end

-- Mindig függőleges sprite (láng, fényoszlop)
local function drawUpright(tex, x, y, z, w, h, color)
    dxDrawMaterialLine3D(x, y, z + h * 0.5, x, y, z - h * 0.5, tex, w, color, false, camX, camY, camZ)
end

-- Földre fektetett, forgatott négyzet (rúnakör)
local function drawFlat(tex, x, y, z, radius, rot, color)
    local c, s = cos(rot), sin(rot)
    dxDrawMaterialLine3D(x - c * radius, y - s * radius, z, x + c * radius, y + s * radius, z,
        tex, radius * 2, color, false, x, y, z + 10)
end

-- Ped közepe (gerinc) és a talaj magassága (a lábfejek alapján, guggolásnál is jó)
local function getAnchor(ped)
    local cx, cy = getPedBonePosition(ped, 3)
    local _, _, z1 = getPedBonePosition(ped, 44)
    local _, _, z2 = getPedBonePosition(ped, 54)
    if not (cx and z1 and z2) then
        local px, py, pz = getElementPosition(ped)
        return px, py, pz - 1.0
    end
    return cx, cy, min(z1, z2) - 0.06
end

local function lerp(a, b, t) return a + (b - a) * t end

-----------------------------------------
-- RÉSZECSKÉK
-----------------------------------------
local function spawnAt(st, em, x, y, z, cx, cy)
    local parts = st.parts
    if #parts >= MAX_PARTS_PER_PED then return end
    local dir = random() * TWO_PI
    local h = R(em.vxy)
    local vx, vy = cos(dir) * h, sin(dir) * h
    if em.swirl then
        local dx, dy = x - cx, y - cy
        local l = sqrt(dx * dx + dy * dy)
        if l > 0.01 then vx, vy = vx - dy / l * em.swirl, vy + dx / l * em.swirl end
    end
    parts[#parts + 1] = {
        x = x, y = y, z = z, vx = vx, vy = vy, vz = R(em.vz),
        age = 0, life = R(em.life or {0.8, 1.2}), em = em,
        rot = random() * TWO_PI, spin = R(em.spin), sm = 0.8 + random() * 0.4, ph = random() * TWO_PI,
    }
end

local function spawn(st, em, ped, cx, cy, gz)
    local x, y, z
    local anchor = em.anchor or "body"
    if anchor == "feet" then
        local a, r = random() * TWO_PI, sqrt(random()) * (em.radius or 0.6)
        x, y, z = cx + cos(a) * r, cy + sin(a) * r, gz + R(em.height)
    elseif anchor == "around" then
        local a, r = random() * TWO_PI, (em.radius or 0.6) * (0.85 + random() * 0.3)
        x, y, z = cx + cos(a) * r, cy + sin(a) * r, gz + R(em.height or {0, 2})
    else
        local bones = em.bones or BODY
        local bx, by, bz = getPedBonePosition(ped, bones[random(#bones)])
        if not bx then return end
        local j = em.jitter or 0.08
        x, y, z = bx + (random() * 2 - 1) * j, by + (random() * 2 - 1) * j, bz + (random() * 2 - 1) * j
    end
    spawnAt(st, em, x, y, z, cx, cy)
end

local function updateParts(st, dt)
    local parts = st.parts
    for i = #parts, 1, -1 do
        local p = parts[i]
        p.age = p.age + dt
        if p.age >= p.life then
            parts[i] = parts[#parts]
            parts[#parts] = nil
        else
            local em = p.em
            if em.gravity then p.vz = p.vz + em.gravity * dt end
            p.x, p.y, p.z = p.x + p.vx * dt, p.y + p.vy * dt, p.z + p.vz * dt
            p.rot = p.rot + p.spin * dt

            local t = p.age / p.life
            local size = lerp(em.size[1], em.size[2], t) * p.sm
            local a = (em.alpha or 255) * min(1, t / 0.15) * min(1, (1 - t) / 0.4)
            if em.twinkle then a = a * (0.55 + 0.45 * sin(p.age * em.twinkle + p.ph)) end
            local c1, c2 = em.color, em.color2
            local r, g, b = c1[1], c1[2], c1[3]
            if c2 then r, g, b = lerp(r, c2[1], t), lerp(g, c2[2], t), lerp(b, c2[3], t) end
            local color = tocolor(r, g, b, a)
            local tex = textures[em.tex]
            if tex then
                if em.upright then
                    drawUpright(tex, p.x, p.y, p.z, size, size * (em.stretch or 1.6), color)
                else
                    drawSprite(tex, p.x, p.y, p.z, size, p.rot, color)
                end
            end
        end
    end
end

-----------------------------------------
-- EGY PED FELDOLGOZÁSA
-----------------------------------------
local function processPed(ped, key, dt, seen)
    local def = EffectByKey[key]
    if not def then return end
    seen[ped] = true

    local st = states[ped]
    if not st or st.key ~= key then
        st = {key = key, t = 0, acc = {}, parts = {}}
        states[ped] = st
    end
    st.t = st.t + dt

    local cx, cy, gz = getAnchor(ped)
    local T = st.t

    for i, em in ipairs(def.emitters) do
        local mode = em.mode or "burst"
        local tex = textures[em.tex]
        local c = em.color

        if mode == "burst" then
            local acc = (st.acc[i] or 0) + em.rate * DENSITY * dt
            local n = 0
            while acc >= 1 and n < MAX_SPAWN_PER_FRAME do
                acc, n = acc - 1, n + 1
                spawn(st, em, ped, cx, cy, gz)
            end
            st.acc[i] = (acc >= 1) and 0 or acc

        elseif mode == "ring" and tex then
            local r = em.radius * (1 + (em.pulse or 0) * sin(T * 3))
            drawFlat(tex, cx, cy, gz + (em.zOff or 0.03), r, T * (em.rot or 0), tocolor(c[1], c[2], c[3], em.alpha or 160))

        elseif mode == "attach" and tex then
            for bi, b in ipairs(em.bones) do
                local bx, by, bz = getPedBonePosition(ped, b)
                if bx then
                    local a = (em.alpha or 60) * (0.65 + 0.35 * sin(T * (em.pulse or 2) + bi * 1.7))
                    drawSprite(tex, bx, by, bz, em.size, 0, tocolor(c[1], c[2], c[3], a))
                end
            end

        elseif mode == "orbit" and tex then
            local trail = em.trail
            local acc = (st.acc[i] or 0) + (trail and trail.rate or 0) * dt
            local doTrail = acc >= 1
            if doTrail then acc = acc - 1 end
            st.acc[i] = (acc >= 1) and 0 or acc
            for k = 1, em.count do
                local a = T * em.speed + (k - 1) * TWO_PI / em.count
                local x = cx + cos(a) * em.radius
                local y = cy + sin(a) * em.radius
                local z = gz + em.height + sin(T * (em.bobSpeed or 2) + k * 2.1) * (em.bob or 0.2)
                drawSprite(tex, x, y, z, em.size, T * 2, tocolor(c[1], c[2], c[3], em.alpha or 220))
                if doTrail then spawnAt(st, trail, x, y, z, cx, cy) end
            end
        end
    end

    updateParts(st, dt)
end

local function canShow(ped, myDim, myInt)
    if not isElement(ped) then return false end
    if isPedDead(ped) or getElementAlpha(ped) < 100 then return false end
    if getElementDimension(ped) ~= myDim or getElementInterior(ped) ~= myInt then return false end
    local x, y, z = getElementPosition(ped)
    if getDistanceBetweenPoints3D(x, y, z, camX, camY, camZ) > MAX_DISTANCE then return false end
    return isElementOnScreen(ped)
end

addEventHandler("onClientPreRender", root, function(dtMs)
    local dt = min((dtMs or 16) / 1000, 0.1)
    updateCamera()
    local myDim, myInt = getElementDimension(localPlayer), getElementInterior(localPlayer)
    local seen = {}

    for _, p in ipairs(getElementsByType("player", root, true)) do
        local key = getElementData(p, "tttEffect")
        if key and (showOthers or p == localPlayer) and canShow(p, myDim, myInt) then
            processPed(p, key, dt, seen)
        end
    end
    for ped, key in pairs(previewPeds) do
        if not isElement(ped) then
            previewPeds[ped] = nil
        elseif canShow(ped, myDim, myInt) then
            processPed(ped, key, dt, seen)
        end
    end
    for ped in pairs(states) do
        if not seen[ped] then states[ped] = nil end
    end
end)
