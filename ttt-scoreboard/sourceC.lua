local screenW, screenH = guiGetScreenSize()
local isVisible = false

-- Színek és Konfiguráció
local mainCyan = tocolor(0, 195, 255, 150)
local mainGreen = tocolor(46, 204, 113, 200)
local mainBg = tocolor(0, 15, 25, 230)

local adminRanks = {
    [1] = {name = "Admin", rgb = {54, 168, 100}},
    [2] = {name = "Főadmin", rgb = {57, 174, 247}},
    [3] = {name = "Tulajdonos", rgb = {219, 89, 75}}
}

-- Fejléc kiosztás (Tágasabb oszlopok)
local headers = {
    {n = "STATUS", w = 60, x = 25},
    {n = "RANK & USERNAME", w = 280, x = 100},
    {n = "CREDITS", w = 110, x = 400},
    {n = "PLAYTIME", w = 130, x = 530},
    {n = "PING", w = 70, x = 690}
}

local function drawCyberBorder(ax, ay, aw, ah, color, thickness)
    local t = thickness
    local l = 20
    dxDrawLine(ax, ay, ax + l, ay, color, t)
    dxDrawLine(ax, ay, ax, ay + l, color, t)
    dxDrawLine(ax + aw, ay, ax + aw - l, ay, color, t)
    dxDrawLine(ax + aw, ay, ax + aw, ay + l, color, t)
    dxDrawLine(ax, ay + ah, ax + l, ay + ah, color, t)
    dxDrawLine(ax, ay + ah, ax, ay + ah - l, color, t)
    dxDrawLine(ax + aw, ay + ah, ax + aw - l, ay + ah, color, t)
    dxDrawLine(ax + aw, ay + ah, ax + aw, ay + ah - l, color, t)
end

local function formatTime(totalsecs)
    totalsecs = math.max(0, math.floor(totalsecs or 0))
    return string.format("%02d:%02d:%02d", math.floor(totalsecs / 3600), math.floor((totalsecs % 3600) / 60), totalsecs % 60)
end

local function formatNumber(amount)
    local formatted = tostring(math.floor(amount or 0))
    while true do
        local k
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

addEventHandler("onClientRender", root, function()
    if not isVisible then return end

    local players = getElementsByType("player")
    local now = getRealTime().timestamp
    local rowHeight = 35
    local headerHeight = 40
    local width = 800
    local height = math.max(100, #players * rowHeight + headerHeight + 10)
    local x, y = (screenW - width) / 2, (screenH - height) / 2

    -- Háttér és Keret
    dxDrawRectangle(x, y, width, height, mainBg)
    drawCyberBorder(x - 2, y - 2, width + 4, height + 4, mainCyan, 2)
    
    -- Fejléc sáv
    dxDrawRectangle(x, y, width, headerHeight, tocolor(0, 195, 255, 30))
    
    -- --- FEJLÉC SZÖVEGEK (Fix 0.55-ös méret, hogy biztosan kicsi legyen) ---
    for _, h in ipairs(headers) do
        dxDrawText(h.n, x + h.x, y + 12, x + h.x + h.w, 0, tocolor(0, 195, 255, 200), 0.55, "bankgothic", "left", "top")
    end

    -- Játékosok
    for i, p in ipairs(players) do
        local py = y + headerHeight + (i-1) * rowHeight
        
        -- Státusz négyzet
        local statusColor = isPedDead(p) and tocolor(120, 120, 120, 150) or mainGreen
        dxDrawRectangle(x + 35, py + 13, 10, 10, statusColor)

        -- --- JÁTÉKOS ADATOK (Itt sima "default" fontot használunk 1.0-ás méretben) ---
        -- Ez garantáltan olvasható és nem lesz óriási.
        local pLevel = tonumber(getElementData(p, "admin")) or 0
        local startX = x + 55
        
        if pLevel >= 1 and adminRanks[pLevel] then
            local rank = adminRanks[pLevel]
            local r, g, b = unpack(rank.rgb)
            local rankTag = "[" .. rank.name .. "] "
            local tagW = dxGetTextWidth(rankTag, 1, "default-bold")
            
            dxDrawText(rankTag, startX, py + 10, 0, 0, tocolor(r, g, b, 255), 1, "default-bold")
            dxDrawText(getPlayerName(p), startX + tagW, py + 10, 0, 0, tocolor(255, 255, 255, 255), 1, "default-bold")
        else
            dxDrawText(getPlayerName(p), startX, py + 10, 0, 0, tocolor(255, 255, 255, 255), 1, "default-bold")
        end

        -- Értékek (szintén default fonttal a biztonság kedvéért)
        -- Kliensoldalon a getPlayerMoney() csak a SAJÁT pénzt adja vissza (nincs player paramétere),
        -- ezért a szerver által szinkronizált "money" elementData-t olvassuk
        dxDrawText("$" .. formatNumber(tonumber(getElementData(p, "money")) or 0), x + 400, py + 10, 0, 0, mainGreen, 1, "default-bold")
        
        -- Valódi játékidő: a szerver a belépéskor elmenti a "joinTime"-ot (unix mp)
        local joinTime = tonumber(getElementData(p, "joinTime")) or now
        dxDrawText(formatTime(now - joinTime), x + 530, py + 10, 0, 0, tocolor(200, 200, 200, 255), 1, "default-bold")
        
        local ping = getPlayerPing(p)
        dxDrawText(ping .. " MS", x + 690, py + 10, 0, 0, (ping > 100 and tocolor(231, 76, 60) or tocolor(200, 200, 200)), 1, "default-bold")
        
        dxDrawLine(x + 15, py + rowHeight, x + width - 15, py + rowHeight, tocolor(0, 195, 255, 15), 1)
    end
end)

bindKey("tab", "both", function(k, state) 
    isVisible = (state == "down") 
end)