-----------------------------------------
-- TTT SPAWNS - KLIENS: a spawn pontok megjelenítése (kör alakú marker + felirat)
-- Játékos spawn = cián, fegyver spawn = narancs. A markerek az interiorhoz kötöttek,
-- tehát csak abban az interiorban látszanak, ahová le lettek rakva.
-----------------------------------------
local entries = {}       -- { marker, s }
local renderOn = false

local COLORS = {
    player = { 0, 195, 255 },
    weapon = { 255, 170, 0 },
}

local function clearMarkers()
    for _, e in ipairs(entries) do
        if isElement(e.marker) then destroyElement(e.marker) end
    end
    entries = {}
end

function renderSpawnLabels()
    local cx, cy, cz = getCameraMatrix()
    local int, dim = getElementInterior(localPlayer), getElementDimension(localPlayer)
    for _, e in ipairs(entries) do
        local s = e.s
        if s.int == int and s.dim == dim then
            local dist = getDistanceBetweenPoints3D(cx, cy, cz, s.x, s.y, s.z)
            if dist < 30 then
                local c = COLORS[s.type] or COLORS.player
                -- játékos spawnnál a nyíl a nézési irányt mutatja
                if s.type == "player" and s.rot then
                    local rad = math.rad(s.rot)
                    dxDrawLine3D(s.x, s.y, s.z + 0.1, s.x - math.sin(rad) * 1.2, s.y + math.cos(rad) * 1.2, s.z + 0.1, tocolor(c[1], c[2], c[3], 220), 3)
                end
                local sx, sy = getScreenFromWorldPosition(s.x, s.y, s.z + 1.0)
                if sx then
                    local scale = math.max(0.6, 1.2 - dist / 40)
                    local label
                    if s.type == "player" then
                        label = "SPAWN #" .. s.id
                    else
                        label = "WEAPON #" .. s.id .. "  " .. (s.weapon and getWeaponNameFromID(s.weapon) or "RANDOM")
                    end
                    dxDrawText(label, sx + 1, sy + 1, sx + 1, sy + 1, tocolor(0, 0, 0, 220), scale, "default-bold", "center", "center")
                    dxDrawText(label, sx, sy, sx, sy, tocolor(c[1], c[2], c[3], 255), scale, "default-bold", "center", "center")
                end
            end
        end
    end
end

addEvent("tttSpawns:sync", true)
addEventHandler("tttSpawns:sync", root, function(list)
    clearMarkers()
    if type(list) ~= "table" then
        if renderOn then
            removeEventHandler("onClientRender", root, renderSpawnLabels)
            renderOn = false
        end
        return
    end
    for _, s in ipairs(list) do
        local c = COLORS[s.type] or COLORS.player
        local m = createMarker(s.x, s.y, s.z, "checkpoint", 1.4, c[1], c[2], c[3], 140)
        if m then
            setElementInterior(m, s.int or 0)
            setElementDimension(m, s.dim or 0)
            table.insert(entries, { marker = m, s = s })
        end
    end
    if not renderOn then
        addEventHandler("onClientRender", root, renderSpawnLabels)
        renderOn = true
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, clearMarkers)
