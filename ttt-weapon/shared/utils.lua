Utils = {}

-- 1. Százalékos szorzó kalkulátor (pl. bejön 20, visszaad 1.2)
function Utils.getModifier(value)
    if not value or type(value) ~= "number" then return 1.0 end
    return 1 + (value / 100)
end

-- 2. Árképzés formázása (pl. 1000 -> 1.000 $)
function Utils.formatMoney(amount)
    local left, num, right = string.match(tostring(amount), '^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1.'):reverse()) .. right .. " $"
end

-- 3. Sorozatszám generátor (Egyedi azonosító a fegyvereknek)
-- Formátum: TTT-XXXXX (ahol X betű vagy szám)
local charset = "ABCDEFGHIJKLMNPQRSTUVWXYZ0123456789"
function Utils.generateSerial()
    local serial = "TTT-"
    for i = 1, 8 do
        local r = math.random(1, #charset)
        serial = serial .. string.sub(charset, r, r)
    end
    return serial
end

-- 4. Színkód kinyerése a durability (állapot) alapján
-- 100% = Zöld, 50% = Sárga, 10% = Piros
function Utils.getDurabilityColor(durability)
    if durability > 75 then return 0, 255, 0
    elseif durability > 30 then return 255, 255, 0
    else return 255, 0, 0 end
end

-- 5. Kerekítés (Mivel nem akarsz floatot, néha kerekíteni kell a végeredményt)
function Utils.round(num)
    return math.floor(num + 0.5)
end

-- 6. Debug üzenetek formázása (Csak hogy szép legyen a konzol)
function Utils.log(message, type)
    local prefix = "[TTT-Weapon]"
    if type == "error" then
        outputDebugString(prefix .. " ERROR: " .. message, 1, 255, 0, 0)
    elseif type == "info" then
        outputDebugString(prefix .. " INFO: " .. message, 3, 0, 255, 255)
    else
        outputDebugString(prefix .. " " .. message)
    end
end
