-----------------------------------------
-- TTT WEAPONSKIN – FEGYVER SKINEK, kliens oldal
-- A játékosok felvett fegyverskinjei a szinkronizált "tttWSkins" elementData-ban vannak
-- ({[fegyverID] = kulcs}, csak a szerver állítja). Mindig csak a KÉZBEN LÉVŐ fegyverre
-- rakjuk rá a shadert, az adott játékosra szűkítve (engineApplyShaderToWorldTexture targetElement),
-- így mindenki a saját skinjét viszi, és más játékos ugyanolyan fegyvere nem változik.
--
-- /fegyverskinek  -> más játékosok fegyverskinjeinek ki/bekapcsolása (csak nálad)
-- /wskindebug     -> a kezedben lévő fegyver textúraneveit és a shader állapotát írja ki
-----------------------------------------
local SHADER_FILE  = "weaponskin.fx"
local UPDATE_MS    = 150      -- milyen gyakran nézzük meg, mi van a játékosok kezében

local textures = {}           -- [útvonal] = texture
local shaders = {}            -- ["wid:kulcs"] = shader | false (ha nem sikerült)
local shaderTech = nil        -- a lefordult technika neve (debughoz)
local texNameCache = {}       -- [modell ID] = {textúranevek}
local applied = {}            -- [element] = {sid, shader, names, model, pedModel}
local ownedWSkins = {}        -- ["30:candy"] = true
local activeWSkins = {}       -- [30] = "candy"
local showOthers = true

-- Ha a modell TXD-jéből nem tudjuk kiolvasni a neveket, ezek a GTA alap nevek
local DEFAULT_TEX = {
    [346] = {"colt_all"}, [347] = {"colt_all"}, [348] = {"desert_eagle2"}, [349] = {"gun_chrome_shot2"},
    [350] = {"sawnoff"}, [351] = {"gun_spas12", "gun_trigs_16col"}, [352] = {"micro_uzi"}, [353] = {"gun_mp5_LONG2"},
    [355] = {"ak47"}, [356] = {"gun_m4"}, [357] = {"countryside_rifle"}, [358] = {"ak47_all"}, [372] = {"tec_9b"},
}

addEvent("ttt:receiveWeaponSkins", true)
addEvent("ttt:onWeaponSkinsChanged", false)   -- helyi esemény: a ttt-shop és az F4 menü erre frissül

local function ownKey(wid, key) return tostring(wid) .. ":" .. key end

-----------------------------------------
-- ADATOK (szervertől)
-----------------------------------------
addEventHandler("ttt:receiveWeaponSkins", root, function(ownedList, active)
    ownedWSkins = {}
    for _, k in ipairs(ownedList or {}) do ownedWSkins[k] = true end
    activeWSkins = {}
    for wid, key in pairs(active or {}) do activeWSkins[tonumber(wid)] = key end
    triggerEvent("ttt:onWeaponSkinsChanged", localPlayer)
end)

function isWeaponSkinOwned(wid, key) return ownedWSkins[ownKey(wid, key)] == true end
function getActiveWeaponSkin(wid) return activeWSkins[tonumber(wid)] end

-----------------------------------------
-- SHADEREK / TEXTÚRÁK
-----------------------------------------
local function getTexture(path)
    if textures[path] == nil then
        textures[path] = fileExists(path) and dxCreateTexture(path, "argb", true, "wrap") or false
        if not textures[path] then outputDebugString("[ttt-weaponskin] Hiányzó fegyverskin textúra: " .. path, 2) end
    end
    return textures[path]
end

local function getShader(wid, key)
    local sid = ownKey(wid, key)
    if shaders[sid] ~= nil then return shaders[sid] end
    local t = WSkinByKey[key]
    if not t then shaders[sid] = false return false end

    local sh, tech = dxCreateShader(SHADER_FILE, 0, 0, false, "ped,object")
    if not sh then
        outputDebugString("[ttt-weaponskin] A fegyverskin shader nem jött létre (videókártya / memória?)", 1)
        shaders[sid] = false
        return false
    end
    if not shaderTech then
        shaderTech = tech
        if tech == "fallback" then
            outputChatBox("#f1c40f[Fegyverskin] #ffffffA videókártyád nem támogatja a fegyverskin shadert, a skinek nálad nem látszanak.", 255, 255, 255, true)
        end
    end

    dxSetShaderValue(sh, "gPattern", getTexture("patterns/" .. t.tex .. ".png"))
    local glow = t.glow or 0
    local emiss = glow > 0 and getTexture("patterns/" .. t.tex .. "_e.png") or nil
    dxSetShaderValue(sh, "gEmissive", emiss or getTexture("patterns/blank.png"))
    dxSetShaderValue(sh, "gGlow", emiss and glow or 0)
    dxSetShaderValue(sh, "gGlowSpeed", t.glowSpeed or 2)
    dxSetShaderValue(sh, "gGlowMin", t.glowMin or 0.3)
    dxSetShaderValue(sh, "gScale", t.scale or 4)
    dxSetShaderValue(sh, "gStrength", t.strength or 1)
    dxSetShaderValue(sh, "gDetail", t.detail or 0.6)
    dxSetShaderValue(sh, "gKeepDark", t.keepDark or 0.5)
    dxSetShaderValue(sh, "gGloss", t.gloss or 0.25)
    local tint = t.tint or {1, 1, 1}
    dxSetShaderValue(sh, "gTint", tint[1], tint[2], tint[3])

    -- megrajzolt (livery) réteg a fegyver két oldalára
    if t.livery then
        local base = "livery/" .. t.livery
        local blank = getTexture("patterns/blank.png")
        dxSetShaderValue(sh, "gLivBG", getTexture(base .. "_bg.png") or blank)
        dxSetShaderValue(sh, "gLivFG", getTexture(base .. "_fg.png") or blank)
        dxSetShaderValue(sh, "gLivBGE", fileExists(base .. "_bg_e.png") and getTexture(base .. "_bg_e.png") or blank)
        dxSetShaderValue(sh, "gLivFGE", fileExists(base .. "_fg_e.png") and getTexture(base .. "_fg_e.png") or blank)
        dxSetShaderValue(sh, "gLivGlow", t.liveryGlow or 1)
        dxSetShaderValue(sh, "gUseLivery", 1)
        applyLiveryPlacement(sh, wid, t)
    else
        dxSetShaderValue(sh, "gUseLivery", 0)
    end

    local over = t.override and t.override[wid]
    local overTex = over and getTexture(over)
    dxSetShaderValue(sh, "gOverride", overTex or getTexture("patterns/blank.png"))
    dxSetShaderValue(sh, "gUseOverride", overTex and 1 or 0)

    shaders[sid] = sh
    return sh
end

-----------------------------------------
-- LIVERY ELHELYEZÉS: a fegyvermodell doboza (auto mérés -> config -> GTA alap)
-----------------------------------------
local boxCache = {}      -- [wid] = {minL, maxL, minZ, maxZ, swap, flip, src}
local liveOverride = {}  -- [wid] = {...} /wskinbox-szal élőben állított értékek (csak nálad)

local function measureModelBox(model)
    local obj = createObject(model, 0, 0, -300)
    if not obj then return nil end
    setElementCollisionsEnabled(obj, false)
    setElementAlpha(obj, 0)
    local x0, y0, z0, x1, y1, z1 = getElementBoundingBox(obj)
    destroyElement(obj)
    if not x0 then return nil end
    local len, hgt = math.max(x1 - x0, y1 - y0), z1 - z0
    if len < 0.15 or len > 2.5 or hgt < 0.05 or hgt > 0.8 then return nil end
    return {x0, x1, y0, y1, z0, z1}
end

function getWeaponLiveryBox(wid)
    if boxCache[wid] then return boxCache[wid] end
    local w = WSkinWeaponByID[wid]
    if not w then return nil end
    local cfg = WSkinWeaponLivery[wid] or {}
    local b, src = nil, "config"
    if cfg.box then b = cfg.box end
    if not b then b, src = measureModelBox(w.model), "auto" end
    if not b then b, src = WSkinDefaultBox[w.model], "gta" end
    if not b then b, src = {-0.3, 0.8, -0.05, 0.05, -0.15, 0.2}, "alap" end
    local swap = cfg.swap
    if swap == nil then swap = (b[4] - b[3]) > (b[2] - b[1]) * 1.2 end
    local minL, maxL = b[1], b[2]
    if swap then minL, maxL = b[3], b[4] end
    local flip = cfg.flip and true or false
    if flip then minL, maxL = -maxL, -minL end
    boxCache[wid] = {minL, maxL, b[5], b[6], swap = swap, flip = flip, src = src}
    return boxCache[wid]
end

function applyLiveryPlacement(sh, wid, t)
    local box = getWeaponLiveryBox(wid)
    if not box then return end
    local cfg = WSkinWeaponLivery[wid] or {}
    local live = liveOverride[wid] or {}
    local b = live.box or box
    local w = WSkinWeaponByID[wid]
    local ctr = live.fgCenter or cfg.fgCenter or WSkinDefaultFG[w.model] or {0.42, 0.3}
    dxSetShaderValue(sh, "gBox", b[1], b[2], b[3], b[4])
    dxSetShaderValue(sh, "gSwapXY", box.swap and 1 or 0)
    dxSetShaderValue(sh, "gFlipX", (live.flip ~= nil and live.flip or box.flip) and 1 or 0)
    dxSetShaderValue(sh, "gFGCenter", ctr[1], ctr[2])
    dxSetShaderValue(sh, "gFGScale", live.fgScale or cfg.fgScale or (WSkinDefaultFG[w.model] or {})[3] or 0.45)
    dxSetShaderValue(sh, "gBGAspect", 4)
    dxSetShaderValue(sh, "gFGAspect", 2.5)
end

local function refreshLiveryShaders(onlyWid)
    for sid, sh in pairs(shaders) do
        if sh then
            local wid, key = sid:match("^(%d+):(.+)$")
            wid = tonumber(wid)
            local t = WSkinByKey[key]
            if t and t.livery and (not onlyWid or onlyWid == wid) then applyLiveryPlacement(sh, wid, t) end
        end
    end
end

-- A fegyvermodell átfestendő textúrái (a custom modell TXD-jéből olvassuk ki futás közben)
local function getWeaponTextureNames(model)
    if texNameCache[model] then return texNameCache[model] end
    local list = {}
    local names = engineGetModelTextureNames(tostring(model))
    for _, n in ipairs(names or {}) do
        if not isWeaponSkinIgnoredTexture(n) then list[#list + 1] = n end
    end
    if #list == 0 then list = DEFAULT_TEX[model] or {} end
    texNameCache[model] = list
    return list
end

local function clearElement(el)
    local a = applied[el]
    if not a then return end
    if isElement(el) and a.shader then
        for _, n in ipairs(a.names) do engineRemoveShaderFromWorldTexture(a.shader, n, el) end
    end
    applied[el] = nil
end

-- wid/key skin rárakása egy elemre (ped: a kezében lévő fegyver; objektum: előnézet)
local function applyToElement(el, wid, key)
    local w = WSkinWeaponByID[wid]
    if not w or not WSkinByKey[key] then return clearElement(el) end
    local sid = ownKey(wid, key)
    local pedModel = getElementType(el) ~= "object" and getElementModel(el) or nil
    local a = applied[el]
    if a and a.sid == sid and a.pedModel == pedModel then return end
    clearElement(el)

    local sh = getShader(wid, key)
    if not sh then return end

    -- a ped saját (ruha) textúráit kihagyjuk, ha véletlenül ugyanaz a nevük
    local exclude = {}
    if pedModel then
        for _, n in ipairs(engineGetModelTextureNames(tostring(pedModel)) or {}) do exclude[n] = true end
    end
    local used = {}
    for _, n in ipairs(getWeaponTextureNames(w.model)) do
        if not exclude[n] then
            engineApplyShaderToWorldTexture(sh, n, el)
            used[#used + 1] = n
        end
    end
    applied[el] = {sid = sid, shader = sh, names = used, pedModel = pedModel}
end

-----------------------------------------
-- FRISSÍTÉS: a betöltött (streamelt) játékosok kezében lévő fegyver
-----------------------------------------
local function getSkinKeyFor(p, wid)
    if p ~= localPlayer and not showOthers then return nil end
    local data = getElementData(p, "tttWSkins")
    if type(data) ~= "table" then return nil end
    return data[wid] or data[tostring(wid)]
end

local previewElements = {}   -- [objektum] = true (ezeket a frissítő nem bántja)

local function update()
    local seen = {}
    for _, p in ipairs(getElementsByType("player", root, true)) do
        seen[p] = true
        local wid = getPedWeapon(p)
        local key = wid and getSkinKeyFor(p, wid)
        if key then applyToElement(p, wid, key) elseif applied[p] then clearElement(p) end
    end
    for el in pairs(applied) do
        if not previewElements[el] and not seen[el] then
            if isElement(el) then clearElement(el) else applied[el] = nil end
        end
    end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    triggerServerEvent("ttt:requestWeaponSkins", localPlayer)
    setTimer(update, UPDATE_MS, 0)
end)

-- Ha bármelyik resource (pl. a fegyvermodelleket betöltő) elindul, újraolvassuk a textúraneveket
addEventHandler("onClientResourceStart", root, function(res)
    if res == getThisResource() then return end
    setTimer(function()
        texNameCache = {}
        boxCache = {}
        refreshLiveryShaders()
        local redo = {}
        for el, a in pairs(applied) do redo[#redo + 1] = {el, a.sid} end
        for _, r in ipairs(redo) do
            local el = r[1]
            clearElement(el)
            if previewElements[el] and isElement(el) then
                local wid, key = r[2]:match("^(%d+):(.+)$")
                applyToElement(el, tonumber(wid), key)
            end
        end
        -- a játékosokat a következő update() úgyis újra felrakja
    end, 1000, 1)
end)

addEventHandler("onClientElementDestroy", root, function()
    if applied[source] then applied[source] = nil end
    previewElements[source] = nil
end)

-----------------------------------------
-- ELŐNÉZET (F4 skin menü [4] fül) – objektumra rakja a skint
-----------------------------------------
function setWeaponSkinPreview(obj, wid, key)
    if not isElement(obj) then return end
    previewElements[obj] = true
    if key and key ~= "none" then applyToElement(obj, wid, key) else clearElement(obj) end
end

function clearWeaponSkinPreview(obj)
    if obj then clearElement(obj); previewElements[obj] = nil end
end

-----------------------------------------
-- LISTÁK (ttt-shop FEGYVERSKIN fül és az F4 menü)
-----------------------------------------
function getWeaponSkinWeaponList()
    local list = {}
    for i, w in ipairs(WSkinWeapons) do list[i] = {id = w[1], name = w[2], model = w[3]} end
    return list
end

-- Egy fegyver összes skinje: {key, name, desc, price, owned, active, available, cat, catLabel, catColor}
function getWeaponSkinShopList(wid)
    wid = tonumber(wid)
    local list = {}
    if not WSkinWeaponByID[wid] then return list end
    for _, cat in ipairs(WSkinCategoryOrder) do
        local c = WSkinCategories[cat]
        local themes = {}
        for _, t in ipairs(WSkinThemes) do if t.cat == cat and t.premium then themes[#themes + 1] = t end end
        for _, t in ipairs(WSkinThemes) do if t.cat == cat and not t.premium then themes[#themes + 1] = t end end
        for _, t in ipairs(themes) do
            do
                list[#list + 1] = {
                    premium = t.premium,
                    key = t.key, name = t.name, desc = t.desc, price = getWeaponSkinPrice(wid, t.key),
                    owned = isWeaponSkinOwned(wid, t.key), active = activeWSkins[wid] == t.key,
                    available = isWeaponSkinInSeason(t.key), cat = cat, catLabel = c.label .. (t.premium and " • PRÉMIUM" or ""), catColor = c.color,
                }
            end
        end
    end
    return list
end

-----------------------------------------
-- PARANCSOK
-----------------------------------------
addCommandHandler("fegyverskinek", function()
    showOthers = not showOthers
    outputChatBox("#00c3ff[Fegyverskin] #ffffffMás játékosok fegyverskinjei: " .. (showOthers and "#7cc576BE" or "#d9534fKI"), 255, 255, 255, true)
end)

addCommandHandler("wskindebug", function()
    local wid = getPedWeapon(localPlayer)
    local w = WSkinWeaponByID[wid]
    outputChatBox("#00c3ff[WSkin] #ffffffFegyver ID: " .. tostring(wid) .. (w and (" (" .. w.name .. ", modell " .. w.model .. ")") or " (nincs a listában)"), 255, 255, 255, true)
    if w then
        local all = engineGetModelTextureNames(tostring(w.model)) or {}
        outputChatBox("#00c3ff[WSkin] #ffffffTXD textúrák: " .. (#all > 0 and table.concat(all, ", ") or "(üres)"), 255, 255, 255, true)
        outputChatBox("#00c3ff[WSkin] #ffffffÁtfestve: " .. table.concat(getWeaponTextureNames(w.model), ", "), 255, 255, 255, true)
    end
    local a = applied[localPlayer]
    outputChatBox("#00c3ff[WSkin] #ffffffAktív skin rajtad: " .. (a and a.sid or "nincs") .. " | shader technika: " .. tostring(shaderTech), 255, 255, 255, true)
end)

-- /wskinbox                        -> a kezedben lévő fegyver livery dobozának kiírása
-- /wskinbox minX maxX minZ maxZ    -> élő állítás (csak nálad), és kiírja a shared.lua-ba másolható sort
-- /wskinbox flip                   -> a kép megfordítása (ha a cső -X felé néz)
-- /wskinbox fg u v [méret]         -> a matricák helye (u: 0 = tus, 1 = cső vége | v: 0 = teteje, 1 = alja) és mérete
-- /wskinbox reset                  -> élő állítások törlése
addCommandHandler("wskinbox", function(_, a, b, c, d)
    local wid = getPedWeapon(localPlayer)
    local w = WSkinWeaponByID[wid]
    if not w then return outputChatBox("#d9534f[WSkin] #ffffffVegyél kézbe egy listában lévő fegyvert!", 255, 255, 255, true) end
    local box = getWeaponLiveryBox(wid)
    liveOverride[wid] = liveOverride[wid] or {}
    local live = liveOverride[wid]
    if a == "reset" then
        liveOverride[wid] = nil
    elseif a == "flip" then
        live.flip = not ((live.flip ~= nil) and live.flip or box.flip)
    elseif a == "fg" then
        live.fgCenter = {tonumber(b) or 0.42, tonumber(c) or 0.3}
        live.fgScale = tonumber(d) or live.fgScale
    elseif tonumber(a) and tonumber(b) and tonumber(c) and tonumber(d) then
        live.box = {tonumber(a), tonumber(b), tonumber(c), tonumber(d)}
    end
    refreshLiveryShaders(wid)
    live = liveOverride[wid] or {}
    local bb = live.box or box
    outputChatBox(("#00c3ff[WSkin] #ffffff%s doboz (%s): hossz %.3f .. %.3f | magasság %.3f .. %.3f | swap=%s flip=%s"):format(
        w.name, box.src, bb[1], bb[2], bb[3], bb[4], tostring(box.swap), tostring(live.flip ~= nil and live.flip or box.flip)), 255, 255, 255, true)
    if live.box or live.flip ~= nil or live.fgCenter or live.fgScale then
        local parts = {}
        if live.box then
            local o = box.swap and {"?", "?", live.box[1], live.box[2]} or {live.box[1], live.box[2], "?", "?"}
            parts[#parts + 1] = ("box = {%s, %s, %s, %s, %.3f, %.3f}"):format(tostring(o[1]), tostring(o[2]), tostring(o[3]), tostring(o[4]), live.box[3], live.box[4])
        end
        if live.flip ~= nil then parts[#parts + 1] = "flip = " .. tostring(live.flip) end
        if live.fgCenter then parts[#parts + 1] = ("fgCenter = {%.2f, %.2f}"):format(live.fgCenter[1], live.fgCenter[2]) end
        if live.fgScale then parts[#parts + 1] = ("fgScale = %.2f"):format(live.fgScale) end
        outputChatBox("#f1c40f[WSkin] #ffffffshared.lua WSkinWeaponLivery: #ffffff[" .. wid .. "] = { " .. table.concat(parts, ", ") .. " },", 255, 255, 255, true)
    end
end)
