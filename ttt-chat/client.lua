-- ttt-chat / client.lua
-- Cyberpunk stílusú chat a bal felső sarokban: emojik (png/jpg/gif/webp), görgetés, a meglévő parancsok támogatása.

local screenW, screenH = guiGetScreenSize()

addEvent("ttt-chat:cssList", true)
addEvent("ttt-chat:emojiList", true)

---------------------------------------------------------
-- BEÁLLÍTÁSOK
---------------------------------------------------------
local CFG = {
    x = 30, y = 30,          -- bal felső sarok
    w = 520,                 -- chat szélesség
    visibleLines = 12,       -- ennyi sor látszik egyszerre
    lineH = 22,              -- sormagasság
    headerH = 28,
    emojiSize = 20,
    jumboSize = 40,          -- ha az üzenet csak emojikból áll, ekkorák (2 sor magas)
    fontScale = 1.25,
    font = "default-bold",
    maxLines = 500,          -- ennyi sort tárol
    showTime = 9000,         -- zárt chatnél ennyi ideig látszik egy üzenet (ms)
    fadeTime = 1500,         -- és ennyi idő alatt halványul el
    maxInputLen = 200,
    scrollStep = 3,
    cssPadTop = 16,          -- name.html-lel egyezzen: hely a lángoknak/ragyogásnak
    cssPadL = 6,
    cssPadBottom = 6,
    maxBrowsers = 40,        -- ennyi effektes név-böngésző élhet egyszerre
    gifRes = 2,              -- animált emoji felbontása (2 = kétszeres, élesebb)
    maxGifBrowsers = 30,     -- ennyi különböző animált emoji lehet egyszerre
    buttonEmoji = "d",       -- a beviteli sáv végén lévő gomb képe: emojis/d/emoji.(png|jpg|gif|webp)
                             -- (Windows-on a mappanévben nem lehet ":", ezért nem "D:" a neve)
    showCursorInChat = true, -- nyitott chatnél látszik az egér (kell a gombhoz és a választóhoz)
}

local panelH = CFG.headerH + 6 + CFG.visibleLines * CFG.lineH + 8

local COL = {
    bg        = tocolor(0, 15, 25, 200),
    headerBg  = tocolor(0, 195, 255, 25),
    cyan      = tocolor(0, 195, 255, 150),
    cyanSolid = tocolor(0, 195, 255, 255),
    divider   = tocolor(0, 195, 255, 40),
    white     = tocolor(255, 255, 255, 255),
    dim       = tocolor(255, 255, 255, 90),
    warn      = tocolor(241, 196, 15, 255),
}

---------------------------------------------------------
-- ÁLLAPOT
---------------------------------------------------------
local lines = {}             -- kiszámolt (tördelt) sorok
local scroll = 0             -- hány sorral vagyunk feljebb a legújabbtól
local chatActive = false
local openedAt = 0
local input = {}             -- bevitel elemei: {c="a", w=..} vagy {e="kappa", tex=.., w=..}
local cursor = 0
local history, histIdx = {}, nil
local heldKey, heldStart, heldLast = nil, 0, 0
local cssOpen = false        -- a /css ablak nyitva van-e (a chat is figyeli az egér miatt)
local settings = {autoConvert = true}  -- a játékos saját beállításai (@settings.json)
local emojiNames = {}        -- az összes elérhető emoji neve ABC sorrendben (választó + TAB)
local emojiNameSet = {}
local pickerOpen, pickerScroll = false, 0
local completion = nil       -- TAB lista: {start = index, names = {...}}, ha több találat van

local SETTINGS_FILE = "@settings.json" -- a "@" miatt csak ezen a szerveren, csak ennél a játékosnál

local function loadSettings()
    if not fileExists(SETTINGS_FILE) then return end
    local f = fileOpen(SETTINGS_FILE, true)
    if not f then return end
    local data = fileRead(f, fileGetSize(f))
    fileClose(f)
    local t = data and data ~= "" and fromJSON(data)
    if type(t) == "table" and type(t.autoConvert) == "boolean" then
        settings.autoConvert = t.autoConvert
    end
end

local function saveSettings()
    if fileExists(SETTINGS_FILE) then fileDelete(SETTINGS_FILE) end
    local f = fileCreate(SETTINGS_FILE)
    if not f then return end
    fileWrite(f, toJSON({autoConvert = settings.autoConvert}))
    fileClose(f)
end

---------------------------------------------------------
-- SEGÉDFÜGGVÉNYEK
---------------------------------------------------------
local function drawCyberBorder(ax, ay, aw, ah, color, thickness)
    local t, l = thickness, 20
    dxDrawLine(ax, ay, ax + l, ay, color, t)
    dxDrawLine(ax, ay, ax, ay + l, color, t)
    dxDrawLine(ax + aw, ay, ax + aw - l, ay, color, t)
    dxDrawLine(ax + aw, ay, ax + aw, ay + l, color, t)
    dxDrawLine(ax, ay + ah, ax + l, ay + ah, color, t)
    dxDrawLine(ax, ay + ah, ax, ay + ah - l, color, t)
    dxDrawLine(ax + aw, ay + ah, ax + aw - l, ay + ah, color, t)
    dxDrawLine(ax + aw, ay + ah, ax + aw, ay + ah - l, color, t)
end

local function maxScroll()
    return math.max(0, #lines - CFG.visibleLines)
end

local function scrollBy(n)
    scroll = math.max(0, math.min(maxScroll(), scroll + n))
end

---------------------------------------------------------
-- EMOJIK  (emojis/<név>/emoji.png | jpg | gif | webp)
-- png/jpg: sima textúra. gif/webp: animált, ezért egy kis átlátszó CEF böngésző játssza le
-- (az MTA textúrái nem animálnak). Minden emojihoz egy böngésző tartozik, amit mindenhol megosztunk.
---------------------------------------------------------
local emojiCache = {}        -- név -> textúra | animált bejegyzés | false
local emojiByBrowser = {}    -- böngésző -> animált bejegyzés
local gifCount = 0

local STATIC_EXT = {"png", "jpg"}
local ANIM_EXT   = {"gif", "webp"}

local function createAnimatedEmoji(name, ext)
    local size = CFG.jumboSize * CFG.gifRes
    local browser = createBrowser(size, size, true, true) -- helyi oldal, átlátszó háttér
    if not browser then return false end
    gifCount = gifCount + 1
    local entry = {browser = browser, ready = false, name = name, ext = ext}
    emojiByBrowser[browser] = entry
    return entry
end

local function getEmoji(name)
    name = name:lower()
    if #name > 32 then return nil end

    local cached = emojiCache[name]
    if cached ~= nil then return cached or nil end

    local result = false

    for _, ext in ipairs(STATIC_EXT) do
        local path = "emojis/" .. name .. "/emoji." .. ext
        if fileExists(path) then
            result = dxCreateTexture(path, "argb", true, "clamp") or false
            if result then break end
        end
    end

    if not result then
        for _, ext in ipairs(ANIM_EXT) do
            if fileExists("emojis/" .. name .. "/emoji." .. ext) then
                if gifCount >= CFG.maxGifBrowsers then return nil end -- nem cache-eljük, később még lehet hely
                result = createAnimatedEmoji(name, ext)
                if result then break end
            end
        end
    end

    emojiCache[name] = result
    return result or nil
end

local ALL_EXT = {"png", "jpg", "gif", "webp"}

local function emojiFileExists(name)
    for _, ext in ipairs(ALL_EXT) do
        if fileExists("emojis/" .. name .. "/emoji." .. ext) then return true end
    end
    return false
end

-- a választó és a TAB ebből a listából dolgozik (a szerver küldi, + MTA 1.6-on a helyi mappa)
local function addEmojiNames(list)
    if type(list) ~= "table" then return end
    for _, n in ipairs(list) do
        if type(n) == "string" then
            n = n:match("([^/\\]+)[/\\]*$")
            n = n and n:lower()
            if n and n:match("^[%w_%-]+$") and #n <= 32 and not emojiNameSet[n] and emojiFileExists(n) then
                emojiNameSet[n] = true
                emojiNames[#emojiNames + 1] = n
            end
        end
    end
    table.sort(emojiNames)
end

-- emoji kirajzolása (textúra vagy animált böngésző)
local function drawEmoji(tex, x, y, size, color)
    if type(tex) == "table" then
        if tex.ready and isElement(tex.browser) then
            dxDrawImage(x, y, size, size, tex.browser, 0, 0, 0, color)
        end
    else
        dxDrawImage(x, y, size, size, tex, 0, 0, 0, color)
    end
end

---------------------------------------------------------
-- CSS EFFEKTES NEVEK (CEF)
-- Minden (effekt + név + szélesség) párhoz egy kis átlátszó böngésző tartozik,
-- amit textúraként rajzolunk a chatbe.
---------------------------------------------------------
local nameBrowsers = {}      -- key -> {browser, ready, fx, name, textW, w, h, lastUsed}
local browserByElement = {}  -- browser -> entry

local function jsEscape(str)
    return (str:gsub("[%c\\\"'<>&]", function(c) return string.format("\\x%02x", c:byte()) end))
end

local function evictOldestBrowser()
    local oldestKey, oldestTick
    local count = 0
    for key, e in pairs(nameBrowsers) do
        count = count + 1
        if not oldestTick or e.lastUsed < oldestTick then oldestKey, oldestTick = key, e.lastUsed end
    end
    if count >= CFG.maxBrowsers and oldestKey then
        local e = nameBrowsers[oldestKey]
        browserByElement[e.browser] = nil
        if isElement(e.browser) then destroyElement(e.browser) end
        nameBrowsers[oldestKey] = nil
    end
end

local function getNameBrowser(fx, name, textW)
    local key = fx .. "|" .. name .. "|" .. textW
    local e = nameBrowsers[key]
    if e then
        if isElement(e.browser) then
            e.lastUsed = getTickCount()
            return e
        end
        browserByElement[e.browser] = nil
        nameBrowsers[key] = nil
    end

    evictOldestBrowser()

    local bw = textW + CFG.cssPadL + 8
    local bh = CFG.lineH + CFG.cssPadTop + CFG.cssPadBottom
    local browser = createBrowser(bw, bh, true, true) -- helyi oldal, átlátszó háttér
    if not browser then return nil end

    e = {browser = browser, ready = false, fx = fx, name = name, textW = textW, w = bw, h = bh, lastUsed = getTickCount()}
    nameBrowsers[key] = e
    browserByElement[browser] = e
    return e
end

addEventHandler("onClientBrowserCreated", root, function()
    if browserByElement[source] then
        loadBrowserURL(source, "http://mta/local/name.html")
    elseif emojiByBrowser[source] then
        loadBrowserURL(source, "http://mta/local/emoji.html")
    end
end)

addEventHandler("onClientBrowserDocumentReady", root, function()
    -- animált emoji
    local anim = emojiByBrowser[source]
    if anim then
        if anim.started then return end
        anim.started = true
        executeBrowserJavascript(source, string.format('setup("%s","%s")', anim.name, anim.ext))
        setTimer(function() anim.ready = true end, 250, 1) -- adjunk időt a kép betöltésére
        return
    end

    -- effektes név
    local e = browserByElement[source]
    if not e or e.started then return end
    e.started = true
    executeBrowserJavascript(source, string.format('setup("%s","%s",%d)', e.fx, jsEscape(e.name), e.textW))
    setTimer(function() e.ready = true end, 200, 1) -- adjunk időt a css betöltésére
end)

-- kirajzol egy effektes nevet; ha a böngésző még nem kész, sima szöveg látszik
local function drawNameFx(fx, name, x, y, textW, alpha)
    local e = getNameBrowser(fx, name, textW)
    if e and e.ready and isElement(e.browser) then
        dxDrawImage(x - CFG.cssPadL, y - CFG.cssPadTop, e.w, e.h, e.browser, 0, 0, 0, tocolor(255, 255, 255, alpha))
    else
        dxDrawText(name, x, y, x + textW, y + CFG.lineH, tocolor(255, 255, 255, alpha), CFG.fontScale, CFG.font, "left", "center")
    end
end

-- EXPORT: más resource (pl. ttt-scoreboard) is ezzel rajzolhat effektes nevet.
-- Csak onClientRender-ből hívd! y = a sor teteje (a szöveg függőleges közepe y + 11),
-- textW = dxGetTextWidth(name, 1, "default-bold") felkerekítve.
function drawChatNameFx(fx, name, x, y, textW, alpha)
    if type(fx) ~= "string" or not fx:match("^[%w_%-]+$") then return false end
    if type(name) ~= "string" or type(textW) ~= "number" then return false end
    drawNameFx(fx, name, x, y, math.max(1, math.floor(textW)), alpha or 255)
    return true
end

---------------------------------------------------------
-- ÜZENETEK FELDOLGOZÁSA (színkódok + emojik + sortörés)
---------------------------------------------------------
local function parseAtoms(text, baseColor)
    local atoms = {}
    local cur = baseColor

    -- {:} = szövegként küldött kettőspont (kikapcsolt automatikus átalakításnál) -> ebből nem lesz emoji
    text = text:gsub("{:}", "\1")
    local function unesc(s) return (s:gsub("\1", ":")) end

    local function addChunk(chunk)
        local p = 1
        while p <= #chunk do
            local s, e, name = chunk:find(":([%w_%-]+):", p)
            if not s then
                atoms[#atoms + 1] = {k = "text", s = unesc(chunk:sub(p)), c = cur}
                break
            end
            local tex = getEmoji(name)
            if tex then
                if s > p then atoms[#atoms + 1] = {k = "text", s = unesc(chunk:sub(p, s - 1)), c = cur} end
                atoms[#atoms + 1] = {k = "emoji", tex = tex}
                p = e + 1
            else
                atoms[#atoms + 1] = {k = "text", s = unesc(chunk:sub(p, s)), c = cur}
                p = s + 1
            end
        end
    end

    -- #RRGGBB színkódok
    local function addColored(seg)
        local pos = 1
        while true do
            local s, e = seg:find("#%x%x%x%x%x%x", pos)
            if not s then
                addChunk(seg:sub(pos))
                break
            end
            addChunk(seg:sub(pos, s - 1))
            local hex = seg:sub(s + 1, e)
            cur = {tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)}
            pos = e + 1
        end
    end

    -- {{css|effekt|Név}} jelölés a szervertől
    local pos = 1
    while true do
        local s, e, fx, name = text:find("{{css|([%w_%-]+)|(.-)}}", pos)
        if not s then
            addColored(text:sub(pos))
            break
        end
        addColored(text:sub(pos, s - 1))
        atoms[#atoms + 1] = {k = "css", fx = fx, name = name, c = cur}
        pos = e + 1
    end

    return atoms
end

-- jumbo = true: az üzenet csak emojikból áll, ezért nagy emojik, és minden sor 2 sor magas.
-- A második sor egy üres kitöltő bejegyzés, ami csak a helyet foglalja (a görgetés így sorokban számol tovább).
local function layoutAtoms(atoms, jumbo)
    local out = {}
    local maxW = CFG.w - 36
    local fs, font = CFG.fontScale, CFG.font
    local now = getTickCount()
    local cur = {parts = {}, w = 0, time = now, jumbo = jumbo}

    local function pushLine()
        out[#out + 1] = cur
        if jumbo then out[#out + 1] = {parts = {}, w = 0, time = now, filler = true} end
    end

    local function newLine()
        pushLine()
        cur = {parts = {}, w = 0, time = now, jumbo = jumbo}
    end

    local function addText(str, color, w)
        cur.parts[#cur.parts + 1] = {k = "text", s = str, c = color, w = w, x = cur.w}
        cur.w = cur.w + w
    end

    for _, a in ipairs(atoms) do
        if a.k == "emoji" then
            local w = (jumbo and CFG.jumboSize + 4 or CFG.emojiSize + 3)
            if cur.w + w > maxW and cur.w > 0 then newLine() end
            cur.parts[#cur.parts + 1] = {k = "emoji", tex = a.tex, x = cur.w}
            cur.w = cur.w + w
        elseif a.k == "css" then
            local w = math.ceil(dxGetTextWidth(a.name, fs, font)) + 3
            if cur.w + w > maxW and cur.w > 0 then newLine() end
            cur.parts[#cur.parts + 1] = {k = "css", fx = a.fx, name = a.name, w = w, x = cur.w}
            cur.w = cur.w + w
        else
            for word in a.s:gmatch("%S*%s*") do
                if word ~= "" then
                    local core = (word:gsub("%s+$", ""))
                    local coreW = dxGetTextWidth(core, fs, font)
                    if cur.w + coreW > maxW and cur.w > 0 then newLine() end

                    if coreW > maxW then
                        -- túl hosszú szó: karakterenként törjük
                        local buf = ""
                        for i = 1, (utf8.len(word) or 0) do
                            local ch = utf8.sub(word, i, i)
                            if cur.w + dxGetTextWidth(buf .. ch, fs, font) > maxW and (buf ~= "" or cur.w > 0) then
                                if buf ~= "" then addText(buf, a.c, dxGetTextWidth(buf, fs, font)) end
                                newLine()
                                buf = ""
                            end
                            buf = buf .. ch
                        end
                        if buf ~= "" then addText(buf, a.c, dxGetTextWidth(buf, fs, font)) end
                    else
                        addText(word, a.c, dxGetTextWidth(word, fs, font))
                    end
                end
            end
        end
    end

    if #cur.parts > 0 then pushLine() end
    return out
end

-- Igaz, ha az üzenet "Név: " után csak emojikból (és szóközökből) áll.
-- A "Név: " rész legfeljebb egy kettőspontot tartalmazhat, így a "Valaki: :kappa:" szöveg nem számít annak.
local function isEmojiOnly(atoms)
    local count, i = 0, #atoms
    while i >= 1 do
        local a = atoms[i]
        if a.k == "emoji" then
            count = count + 1
        elseif not (a.k == "text" and a.s:match("^%s*$")) then
            break
        end
        i = i - 1
    end
    if count == 0 or i < 1 then return false end

    local prev = atoms[i]
    return prev.k == "text" and prev.s:match("^[^:]*:%s*$") ~= nil
end

local function addMessage(text, r, g, b)
    local atoms = parseAtoms(text, {r or 255, g or 255, b or 255})
    local newLines = layoutAtoms(atoms, isEmojiOnly(atoms))
    if #newLines == 0 then return end

    for _, l in ipairs(newLines) do lines[#lines + 1] = l end
    while #lines > CFG.maxLines do table.remove(lines, 1) end

    -- ha visszagörgettél, ne ugorjon el a nézet
    if scroll > 0 then scrollBy(#newLines) end
end

---------------------------------------------------------
-- BEVITEL KEZELÉSE
---------------------------------------------------------
local function charItem(ch)
    return {c = ch, w = dxGetTextWidth(ch, CFG.fontScale, CFG.font)}
end

local function emojiItem(name, tex)
    return {e = name, tex = tex, w = CFG.emojiSize + 3}
end

local ESC = "\1"             -- így megy a szervernek a szövegként küldött kettőspont

-- escapeColons = true: a sima (nem emoji) kettőspontok ESC-ként mennek, így másnál sem lesz belőlük emoji
local function serialize(items, escapeColons)
    local t = {}
    for _, it in ipairs(items) do
        if it.e then
            t[#t + 1] = ":" .. it.e .. ":"
        elseif escapeColons and it.c == ":" then
            t[#t + 1] = ESC
        else
            t[#t + 1] = it.c
        end
    end
    return table.concat(t)
end

local function copyItems(items)
    local t = {}
    for i, it in ipairs(items) do t[i] = it end
    return t
end

local function isNameChar(it)
    return it ~= nil and it.c ~= nil and it.c:match("^[%w_%-]$") ~= nil
end

local function textItems(str)
    local items = {}
    for ch in str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        items[#items + 1] = charItem(ch)
    end
    return items
end

-- A kurzor előtti ":név:" (bárhol) vagy szó eleji ":név" részt emojivá alakítja, ha létezik ilyen emoji.
-- Csak bekapcsolt automatikus átalakításnál fut.
local function tryConvert()
    if not settings.autoConvert then return false end
    local i = cursor
    local closed = false
    if i >= 1 and input[i].c == ":" then closed, i = true, i - 1 end
    local last = i
    while i >= 1 and isNameChar(input[i]) do i = i - 1 end
    if i == last or i < 1 or input[i].c ~= ":" then return false end
    if not closed then
        local prev = input[i - 1]
        if prev and prev.c and prev.c ~= " " then return false end
    end

    local chars = {}
    for k = i + 1, last do chars[#chars + 1] = input[k].c end
    local name = table.concat(chars):lower()
    local tex = getEmoji(name)
    if not tex then return false end

    for k = cursor, i, -1 do table.remove(input, k) end
    table.insert(input, i, emojiItem(name, tex))
    cursor = i
    return true
end

local function insertChar(ch)
    if #input >= CFG.maxInputLen then return end
    if ch == " " then tryConvert() end
    table.insert(input, cursor + 1, charItem(ch))
    cursor = cursor + 1
    if ch == ":" then tryConvert() end -- ":kappa:" a záró kettősponttal azonnal átalakul
end

-- a választóból kattintott emoji mindig emojiként kerül be
local function insertEmoji(name)
    if #input >= CFG.maxInputLen then return end
    local tex = getEmoji(name)
    if not tex then return end
    table.insert(input, cursor + 1, emojiItem(name, tex))
    cursor = cursor + 1
end

local function editKey(key)
    if key == "backspace" then
        if cursor > 0 then table.remove(input, cursor) cursor = cursor - 1 end
    elseif key == "delete" then
        if cursor < #input then table.remove(input, cursor + 1) end
    elseif key == "arrow_l" then
        cursor = math.max(0, cursor - 1)
    elseif key == "arrow_r" then
        cursor = math.min(#input, cursor + 1)
    end
end

local function openChat()
    chatActive = true
    openedAt = getTickCount()
    input, cursor, histIdx = {}, 0, nil
    scroll = 0
    heldKey = nil
    pickerOpen, completion = false, nil
    guiSetInputEnabled(true) -- a többi bind (pl. M) ne fusson gépelés közben
    if CFG.showCursorInChat then showCursor(true) end
end

local function closeChat()
    chatActive = false
    heldKey = nil
    pickerOpen, completion = false, nil
    guiSetInputEnabled(false)
    if CFG.showCursorInChat and not cssOpen then showCursor(false) end
end

local function submit()
    cursor = #input
    tryConvert() -- ha az utolsó szó ":valami", azt is alakítsuk át
    local items = copyItems(input)
    local plain = serialize(items, false):match("^%s*(.-)%s*$")
    closeChat()
    if plain == "" then return end

    local last = history[#history]
    if not last or last.text ~= plain then
        history[#history + 1] = {text = plain, items = items}
        if #history > 50 then table.remove(history, 1) end
    end

    if plain:sub(1, 1) == "/" then
        local cmd, args = plain:match("^/(%S+)%s*(.*)$")
        if cmd then
            -- előbb kliens oldali parancs, ha nincs ilyen, megy a szervernek
            if not executeCommandHandler(cmd, args) then
                triggerServerEvent("ttt-chat:cmd", localPlayer, cmd, args)
            end
        end
    else
        -- kikapcsolt automatikus átalakításnál a beírt :név: szövegként megy el (másnál sem lesz emoji),
        -- a választóból kattintott emojik viszont emojik maradnak
        local text = serialize(items, not settings.autoConvert):match("^%s*(.-)%s*$")
        triggerServerEvent("ttt-chat:send", localPlayer, text)
    end
end

---------------------------------------------------------
-- /css ABLAK: effekt választó
---------------------------------------------------------
local WIN = {w = 480, h = 372, headerH = 32, cols = 3, boxW = 140, boxH = 48, gap = 10, rows = 4}
local cssList = {}
local cssScroll = 0
local selectedFx = nil
local BOX_SCALE = 1.3

local function inRect(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

local function cssItems()
    local items = {"none"}
    for _, n in ipairs(cssList) do items[#items + 1] = n end
    return items
end

local function cssMaxScroll()
    return math.max(0, math.ceil(#cssItems() / WIN.cols) - WIN.rows)
end

local function winPos()
    return math.floor((screenW - WIN.w) / 2), math.floor((screenH - WIN.h) / 2)
end

local function boxRect(idx)
    local wx, wy = winPos()
    local row = math.floor((idx - 1) / WIN.cols) - cssScroll
    local col = (idx - 1) % WIN.cols
    if row < 0 or row >= WIN.rows then return nil end
    return wx + 20 + col * (WIN.boxW + WIN.gap), wy + WIN.headerH + 44 + row * (WIN.boxH + WIN.gap), WIN.boxW, WIN.boxH
end

local function openCss()
    cssOpen = true
    cssScroll = 0
    selectedFx = getElementData(localPlayer, "chatCss") or nil
    showCursor(true)
end

local function closeCss()
    cssOpen = false
    showCursor(chatActive and CFG.showCursorInChat)
end

local function drawBoxOutline(x, y, w, h, color)
    dxDrawLine(x, y, x + w, y, color, 2)
    dxDrawLine(x, y + h, x + w, y + h, color, 2)
    dxDrawLine(x, y, x, y + h, color, 2)
    dxDrawLine(x + w, y, x + w, y + h, color, 2)
end

-- név kirajzolása középre igazítva egy adott pont köré
local function drawCenteredFx(fx, name, cx, cy)
    local textW = math.ceil(dxGetTextWidth(name, BOX_SCALE, CFG.font))
    local e = fx and getNameBrowser(fx, name, textW)
    if e and e.ready and isElement(e.browser) then
        dxDrawImage(cx - textW / 2 - CFG.cssPadL, cy - CFG.lineH / 2 - CFG.cssPadTop, e.w, e.h, e.browser)
    else
        dxDrawText(name, cx - 200, cy - 20, cx + 200, cy + 20, tocolor(255, 255, 255, fx and 120 or 255), BOX_SCALE, CFG.font, "center", "center")
    end
end

local function drawCssWindow()
    if not cssOpen then return end
    local wx, wy = winPos()
    local mx, my = getCursorPosition()
    if mx then mx, my = mx * screenW, my * screenH else mx, my = -1, -1 end

    dxDrawRectangle(wx, wy, WIN.w, WIN.h, COL.bg)
    drawCyberBorder(wx - 2, wy - 2, WIN.w + 4, WIN.h + 4, COL.cyan, 3)
    dxDrawRectangle(wx, wy, WIN.w, WIN.headerH, COL.headerBg)
    dxDrawRectangle(wx, wy + WIN.headerH, WIN.w, 1, COL.divider)
    dxDrawText("NAME FX // /css", wx + 14, wy, wx + WIN.w, wy + WIN.headerH, COL.cyanSolid, 0.9, "default-bold", "left", "center")

    -- bezáró gomb
    local cbx, cby = wx + WIN.w - 32, wy + 4
    local closeHover = inRect(mx, my, cbx, cby, 24, 24)
    dxDrawRectangle(cbx, cby, 24, 24, closeHover and tocolor(231, 76, 60, 120) or tocolor(255, 255, 255, 15))
    dxDrawText("X", cbx, cby, cbx + 24, cby + 24, COL.white, 0.9, "default-bold", "center", "center")

    local hint = "Kattints egy effektre a kiválasztáshoz"
    if cssMaxScroll() > 0 then hint = hint .. "   (GÖRGŐ: lapozás)" end
    dxDrawText(hint, wx + 20, wy + WIN.headerH + 12, wx + WIN.w - 20, wy + WIN.headerH + 36, COL.dim, 0.8, "default-bold", "left", "top")

    local hovered = nil
    for idx, item in ipairs(cssItems()) do
        local bx, by, bw, bh = boxRect(idx)
        if bx then
            local isHover = inRect(mx, my, bx, by, bw, bh)
            local isSel = (item == "none" and not selectedFx) or item == selectedFx
            if isHover then hovered = item end

            dxDrawRectangle(bx, by, bw, bh, tocolor(255, 255, 255, isHover and 30 or 12))
            drawBoxOutline(bx, by, bw, bh, isSel and tocolor(46, 204, 113, 255) or (isHover and COL.cyanSolid or COL.divider))
            drawCenteredFx(item ~= "none" and item or nil, item, bx + bw / 2, by + bh / 2)
        end
    end

    -- előnézet: a saját neved az aktuális (vagy épp fölé vitt) effekttel
    local previewY = wy + WIN.h - 34
    dxDrawRectangle(wx + 20, previewY - 28, WIN.w - 40, 1, COL.divider)
    dxDrawText("ELŐNÉZET", wx + 20, previewY - 20, wx + 120, previewY + 20, COL.dim, 0.8, "default-bold", "left", "center")
    local pname = (getPlayerName(localPlayer):gsub("#%x%x%x%x%x%x", ""))
    local fx = hovered or selectedFx
    if fx == "none" then fx = nil end
    drawCenteredFx(fx, pname, wx + WIN.w / 2 + 30, previewY)
end
addEventHandler("onClientRender", root, drawCssWindow)

addEventHandler("onClientClick", root, function(button, state, cx, cy)
    if not cssOpen or button ~= "left" or state ~= "down" then return end
    local wx, wy = winPos()

    if inRect(cx, cy, wx + WIN.w - 32, wy + 4, 24, 24) then
        closeCss()
        return
    end

    for idx, item in ipairs(cssItems()) do
        local bx, by, bw, bh = boxRect(idx)
        if bx and inRect(cx, cy, bx, by, bw, bh) then
            selectedFx = (item ~= "none") and item or nil
            triggerServerEvent("ttt-chat:setCss", localPlayer, item)
            return
        end
    end
end)

addEventHandler("ttt-chat:cssList", resourceRoot, function(list)
    cssList = list or {}
end)

addCommandHandler("css", function()
    if cssOpen then closeCss() else openCss() end
end)

---------------------------------------------------------
-- EMOJI GOMB + VÁLASZTÓ + TAB KIEGÉSZÍTÉS
---------------------------------------------------------
local PK = {cols = 8, rows = 5, cell = 38, emoji = 28, pad = 10, headerH = 26, footerH = 32}
local BTN = 26 -- a gomb mérete

local function cursorXY()
    if not isCursorShowing() then return -1, -1 end
    local mx, my = getCursorPosition()
    if not mx then return -1, -1 end
    return mx * screenW, my * screenH
end

local function inputRect()
    return CFG.x, CFG.y + panelH + 10, CFG.w, 36
end

local function buttonRect()
    local ix, iy, iw, ih = inputRect()
    return ix + iw - BTN - 6, iy + math.floor((ih - BTN) / 2), BTN
end

local function pickerVisibleRows()
    return math.max(1, math.min(PK.rows, math.ceil(#emojiNames / PK.cols)))
end

local function pickerMaxScroll()
    return math.max(0, math.ceil(#emojiNames / PK.cols) - PK.rows)
end

-- a lenyíló ablak a beviteli sáv alatt, jobbra igazítva a gombhoz
local function pickerRect()
    local ix, iy, iw, ih = inputRect()
    local pw = PK.cols * PK.cell + PK.pad * 2
    local ph = PK.headerH + PK.pad + pickerVisibleRows() * PK.cell + PK.pad + PK.footerH
    return ix + iw - pw, iy + ih + 10, pw, ph
end

local function pickerCellRect(idx)
    local px, py = pickerRect()
    local row = math.floor((idx - 1) / PK.cols) - pickerScroll
    if row < 0 or row >= pickerVisibleRows() then return nil end
    local col = (idx - 1) % PK.cols
    return px + PK.pad + col * PK.cell, py + PK.headerH + PK.pad + row * PK.cell, PK.cell, PK.cell
end

local function pickerFooterRect()
    local px, py, pw, ph = pickerRect()
    return px, py + ph - PK.footerH, pw, PK.footerH
end

local function drawEmojiButton(mx, my)
    local bx, by, bs = buttonRect()
    local hover = inRect(mx, my, bx, by, bs, bs)
    local active = pickerOpen or hover
    dxDrawRectangle(bx, by, bs, bs, active and tocolor(0, 195, 255, 55) or tocolor(255, 255, 255, 12))
    drawBoxOutline(bx, by, bs, bs, active and COL.cyanSolid or COL.divider)
    local tex = getEmoji(CFG.buttonEmoji)
    if tex then
        drawEmoji(tex, bx + 3, by + 3, bs - 6, COL.white)
    else
        dxDrawText(":)", bx, by, bx + bs, by + bs, COL.cyanSolid, 1, "default-bold", "center", "center")
    end
    return hover
end

-- visszaadja: a fölé vitt emoji nevét, és hogy a pipa sora fölött van-e az egér
local function drawPicker(mx, my)
    if not pickerOpen then return nil, false end
    local px, py, pw, ph = pickerRect()
    dxDrawRectangle(px, py, pw, ph, COL.bg)
    drawCyberBorder(px - 2, py - 2, pw + 4, ph + 4, COL.cyan, 3)
    dxDrawRectangle(px, py, pw, PK.headerH, COL.headerBg)
    dxDrawRectangle(px, py + PK.headerH, pw, 1, COL.divider)
    dxDrawText("EMOJI // " .. #emojiNames, px + 10, py, px + pw, py + PK.headerH, COL.cyanSolid, 0.85, "default-bold", "left", "center")
    if pickerMaxScroll() > 0 then
        dxDrawText("GÖRGŐ: lapozás", px, py, px + pw - 10, py + PK.headerH, COL.dim, 0.75, "default-bold", "right", "center")
    end

    local hovered = nil
    if #emojiNames == 0 then
        dxDrawText("Nincs elérhető emoji", px, py + PK.headerH, px + pw, py + PK.headerH + PK.pad * 2 + PK.cell, COL.dim, 0.9, "default-bold", "center", "center")
    end
    local off = (PK.cell - PK.emoji) / 2
    for idx, name in ipairs(emojiNames) do
        local cx, cy, cw, chh = pickerCellRect(idx)
        if cx then
            if inRect(mx, my, cx, cy, cw, chh) then
                hovered = name
                dxDrawRectangle(cx, cy, cw, chh, tocolor(0, 195, 255, 45))
                drawBoxOutline(cx, cy, cw, chh, COL.cyanSolid)
            end
            local tex = getEmoji(name)
            if tex then drawEmoji(tex, cx + off, cy + off, PK.emoji, COL.white) end
        end
    end

    -- pipa: automatikus átalakítás
    local fx, fy, fw, fh = pickerFooterRect()
    local fHover = inRect(mx, my, fx, fy, fw, fh)
    dxDrawRectangle(fx, fy, fw, 1, COL.divider)
    if fHover then dxDrawRectangle(fx, fy + 1, fw, fh - 1, tocolor(255, 255, 255, 10)) end
    local on = settings.autoConvert
    local cbx, cby = fx + PK.pad, fy + math.floor((fh - 16) / 2)
    dxDrawRectangle(cbx, cby, 16, 16, tocolor(255, 255, 255, fHover and 30 or 12))
    drawBoxOutline(cbx, cby, 16, 16, on and tocolor(46, 204, 113, 255) or COL.cyan)
    if on then dxDrawRectangle(cbx + 4, cby + 4, 8, 8, tocolor(46, 204, 113, 255)) end
    dxDrawText("Automatikus átalakítás", cbx + 26, fy, fx + fw, fy + fh, on and COL.white or COL.dim, 0.9, "default-bold", "left", "center")
    return hovered, fHover
end

local function drawTooltip(text, mx, my)
    local w = math.ceil(dxGetTextWidth(text, 0.9, "default-bold")) + 16
    local h = 22
    local tx, ty = mx + 14, my + 18
    if tx + w > screenW - 4 then tx = screenW - w - 4 end
    if ty + h > screenH - 4 then ty = my - h - 6 end
    dxDrawRectangle(tx, ty, w, h, tocolor(0, 10, 18, 235))
    drawBoxOutline(tx, ty, w, h, COL.cyanSolid)
    dxDrawText(text, tx, ty, tx + w, ty + h, COL.white, 0.9, "default-bold", "center", "center")
end

-- TAB: a kurzor előtti ":név" rész (a név üres is lehet). Visszaad: a ":" indexe, a név eleje kisbetűvel
local function findCompletionToken()
    local i = cursor
    while i >= 1 and isNameChar(input[i]) do i = i - 1 end
    if i < 1 or input[i].c ~= ":" then return nil end
    local chars = {}
    for k = i + 1, cursor do chars[#chars + 1] = input[k].c end
    return i, table.concat(chars):lower()
end

-- a startI..cursor részt lecseréli a megadott elemekre
local function replaceToken(startI, items)
    if #input - (cursor - startI + 1) + #items > CFG.maxInputLen then return false end
    for k = cursor, startI, -1 do table.remove(input, k) end
    for n, it in ipairs(items) do table.insert(input, startI + n - 1, it) end
    cursor = startI + #items - 1
    return true
end

-- teljes név: bekapcsolt átalakításnál emoji lesz belőle, különben ":név:" szöveg
local function completeWith(startI, name)
    if settings.autoConvert then
        local tex = getEmoji(name)
        if tex then return replaceToken(startI, {emojiItem(name, tex)}) end
    end
    return replaceToken(startI, textItems(":" .. name .. ":"))
end

local function commonPrefix(list)
    local p = list[1] or ""
    for k = 2, #list do
        local s, l = list[k], 0
        while l < #p and l < #s and p:byte(l + 1) == s:byte(l + 1) do l = l + 1 end
        p = p:sub(1, l)
    end
    return p
end

-- Mint a Linux shellben: egy találat -> kiegészíti; több -> a közös részig egészít ki;
-- ha már nincs mit hozzátenni, kilistázza a lehetőségeket (kattintással is választható)
local function tabComplete()
    local startI, prefix = findCompletionToken()
    if not startI then completion = nil return end

    local cands = {}
    for _, n in ipairs(emojiNames) do
        if n:sub(1, #prefix) == prefix then cands[#cands + 1] = n end
    end

    if #cands == 0 then
        completion = nil
    elseif #cands == 1 then
        completion = nil
        completeWith(startI, cands[1])
    else
        local lcp = commonPrefix(cands)
        if #lcp > #prefix then
            completion = nil
            replaceToken(startI, textItems(":" .. lcp))
        else
            completion = {start = startI, names = cands}
            pickerOpen = false
        end
    end
end

local function drawCompletion(mx, my)
    if not completion then return end
    local ix, iy, iw, ih = inputRect()
    local x0, y0 = ix, iy + ih + 10
    local pad, eh, gap, maxRows = 8, 26, 6, 4
    local rects, cx, cy, row, shown = {}, pad, pad, 1, 0

    for _, name in ipairs(completion.names) do
        local label = ":" .. name .. ":"
        local w = 4 + 20 + 6 + math.ceil(dxGetTextWidth(label, 0.9, "default-bold")) + 8
        if cx + w > iw - pad and cx > pad then
            if row >= maxRows then break end
            row, cx, cy = row + 1, pad, cy + eh + gap
        end
        rects[#rects + 1] = {x0 + cx, y0 + cy, w, eh, name = name, label = label}
        cx = cx + w + gap
        shown = shown + 1
    end

    local more = #completion.names - shown
    local h = cy + eh + pad + (more > 0 and 18 or 0)
    dxDrawRectangle(x0, y0, iw, h, COL.bg)
    drawCyberBorder(x0 - 2, y0 - 2, iw + 4, h + 4, COL.cyan, 2)

    for _, r in ipairs(rects) do
        local hov = inRect(mx, my, r[1], r[2], r[3], r[4])
        dxDrawRectangle(r[1], r[2], r[3], r[4], tocolor(255, 255, 255, hov and 35 or 10))
        if hov then drawBoxOutline(r[1], r[2], r[3], r[4], COL.cyanSolid) end
        local tex = getEmoji(r.name)
        if tex then drawEmoji(tex, r[1] + 4, r[2] + 3, 20, COL.white) end
        dxDrawText(r.label, r[1] + 30, r[2], r[1] + r[3], r[2] + r[4], COL.white, 0.9, "default-bold", "left", "center")
    end
    if more > 0 then
        dxDrawText("... és még " .. more .. " (írj tovább, majd TAB)", x0 + pad, y0 + h - 22, x0 + iw, y0 + h - 4, COL.dim, 0.8, "default-bold", "left", "center")
    end
    completion.rects = rects
end

-- kattintás: gomb, választó, pipa, TAB lista
addEventHandler("onClientClick", root, function(button, state, cx, cy)
    if not chatActive or button ~= "left" or state ~= "down" then return end

    if completion and completion.rects then
        for _, r in ipairs(completion.rects) do
            if inRect(cx, cy, r[1], r[2], r[3], r[4]) then
                local startI = completion.start
                completion = nil
                completeWith(startI, r.name)
                return
            end
        end
    end

    local bx, by, bs = buttonRect()
    if inRect(cx, cy, bx, by, bs, bs) then
        pickerOpen = not pickerOpen
        pickerScroll = 0
        completion = nil
        return
    end

    if pickerOpen then
        local px, py, pw, ph = pickerRect()
        if inRect(cx, cy, px, py, pw, ph) then
            local fx, fy, fw, fh = pickerFooterRect()
            if inRect(cx, cy, fx, fy, fw, fh) then
                settings.autoConvert = not settings.autoConvert
                saveSettings()
                return
            end
            for idx, name in ipairs(emojiNames) do
                local ex, ey, ew, eh = pickerCellRect(idx)
                if ex and inRect(cx, cy, ex, ey, ew, eh) then
                    insertEmoji(name)
                    return
                end
            end
            return
        end
        pickerOpen = false -- máshova kattintottál: bezárjuk
    end
end)

addEventHandler("ttt-chat:emojiList", resourceRoot, function(list)
    addEmojiNames(list)
end)

---------------------------------------------------------
-- BILLENTYŰK
---------------------------------------------------------
addEventHandler("onClientKey", root, function(key, press)
    -- /css ablak: görgő és ESC
    if cssOpen and press and not chatActive then
        if key == "escape" then
            closeCss()
            cancelEvent()
            return
        elseif key == "mouse_wheel_up" then
            cssScroll = math.max(0, cssScroll - 1)
            return
        elseif key == "mouse_wheel_down" then
            cssScroll = math.min(cssMaxScroll(), cssScroll + 1)
            return
        end
    end

    if not chatActive then
        if press and key == "t" and not isConsoleActive() and not isMainMenuActive() and not guiGetInputEnabled() then
            openChat()
            cancelEvent()
        end
        return
    end

    -- görgetés (az emoji választó fölött a választót lapozza)
    if key == "mouse_wheel_up" or key == "mouse_wheel_down" then
        if press then
            local up = key == "mouse_wheel_up"
            local mx, my = cursorXY()
            local px, py, pw, ph = pickerRect()
            if pickerOpen and inRect(mx, my, px, py, pw, ph) then
                pickerScroll = math.max(0, math.min(pickerMaxScroll(), pickerScroll + (up and -1 or 1)))
            else
                scrollBy(up and CFG.scrollStep or -CFG.scrollStep)
            end
        end
        return
    end

    if not press then
        if key == heldKey then heldKey = nil end
        return
    end

    -- a TAB lista csak a következő gombnyomásig látszik (mint a shellben)
    local hadPopup = pickerOpen or completion ~= nil
    if key ~= "tab" and not key:find("^mouse") then completion = nil end

    if key == "enter" or key == "num_enter" then
        submit()
    elseif key == "tab" then
        tabComplete()
        cancelEvent()
    elseif key == "escape" then
        if hadPopup then
            pickerOpen, completion = false, nil -- előbb a lenyíló ablak zárul, másodikra a chat
        else
            closeChat()
        end
        cancelEvent()
    elseif key == "backspace" or key == "delete" or key == "arrow_l" or key == "arrow_r" then
        editKey(key)
        heldKey, heldStart, heldLast = key, getTickCount(), getTickCount()
    elseif key == "home" then
        cursor = 0
    elseif key == "end" then
        cursor = #input
    elseif key == "pgup" then
        scrollBy(CFG.visibleLines - 1)
    elseif key == "pgdn" then
        scrollBy(-(CFG.visibleLines - 1))
    elseif key == "arrow_u" then
        if #history > 0 then
            histIdx = histIdx and math.max(1, histIdx - 1) or #history
            input = copyItems(history[histIdx].items)
            cursor = #input
        end
    elseif key == "arrow_d" then
        if histIdx then
            histIdx = histIdx + 1
            if histIdx > #history then
                histIdx, input = nil, {}
            else
                input = copyItems(history[histIdx].items)
            end
            cursor = #input
        end
    end
end)

addEventHandler("onClientCharacter", root, function(ch)
    if not chatActive then return end
    local b = ch:byte()
    if not b or b < 32 or b == 127 then return end
    -- a megnyitó "t" betű ne kerüljön be
    if (ch == "t" or ch == "T") and getTickCount() - openedAt < 150 then return end
    insertChar(ch)
end)

---------------------------------------------------------
-- ÜZENETEK ÉRKEZÉSE (minden outputChatBox ide jön)
---------------------------------------------------------
addEventHandler("onClientChatMessage", root, function(text, r, g, b)
    addMessage(text, r, g, b)
    cancelEvent() -- az alap MTA chatbe ne írja ki
end)

---------------------------------------------------------
-- RAJZOLÁS
---------------------------------------------------------
local function drawParts(line, x, y, alpha)
    local fs, font, lh = CFG.fontScale, CFG.font, CFG.lineH
    local H = line.jumbo and lh * 2 or lh -- a sor magassága (jumbo: 2 sor)
    for _, p in ipairs(line.parts) do
        local px = x + p.x
        if p.k == "emoji" then
            local es = line.jumbo and CFG.jumboSize or CFG.emojiSize
            drawEmoji(p.tex, px, y + (H - es) / 2, es, tocolor(255, 255, 255, alpha))
        elseif p.k == "css" then
            drawNameFx(p.fx, p.name, px, y + (H - lh) / 2, p.w - 3, alpha)
        else
            dxDrawText(p.s, px + 1, y + 1, px + p.w + 1, y + H + 1, tocolor(0, 0, 0, alpha), fs, font, "left", "center")
            dxDrawText(p.s, px, y, px + p.w, y + H, tocolor(p.c[1], p.c[2], p.c[3], alpha), fs, font, "left", "center")
        end
    end
end

local function drawInput(mx, my)
    local ix, iy, iw, ih = inputRect()
    local fs, font = CFG.fontScale, CFG.font

    dxDrawRectangle(ix, iy, iw, ih, COL.bg)
    drawCyberBorder(ix - 2, iy - 2, iw + 4, ih + 4, COL.cyan, 3)

    local isCmd = input[1] and input[1].c == "/"
    dxDrawText(isCmd and "cmd:" or ">", ix + 12, iy, ix, iy + ih, isCmd and COL.warn or COL.cyanSolid, fs, font, "left", "center")

    -- jobb oldalt: karakterszámláló + emoji gomb. A beírt szöveg ezek elé nem lóghat be.
    local bx = buttonRect()
    local counterR = bx - 8
    local counterL = counterR - 56
    local baseX = ix + 52
    local availW = counterL - 4 - baseX

    -- honnan rajzoljuk, hogy a kurzor látszódjon
    local startI, acc = 1, 0
    for i = cursor, 1, -1 do
        acc = acc + input[i].w
        if acc > availW - 6 then startI = i + 1 break end
    end

    local px, caretX = baseX, baseX
    for i = startI, #input do
        local it = input[i]
        if px + it.w > baseX + availW then break end
        if it.e then
            local es = CFG.emojiSize
            drawEmoji(it.tex, px, iy + (ih - es) / 2, es, COL.white)
        else
            dxDrawText(it.c, px, iy, px + it.w, iy + ih, COL.white, fs, font, "left", "center")
        end
        px = px + it.w
        if i == cursor then caretX = px end
    end
    if cursor < startI then caretX = baseX end

    if getTickCount() % 1000 < 500 then
        dxDrawRectangle(caretX, iy + 8, 2, ih - 16, COL.cyanSolid)
    end

    dxDrawText(#input .. "/" .. CFG.maxInputLen, counterL, iy, counterR, iy + ih, COL.dim, 0.8, "default-bold", "right", "center")

    return drawEmojiButton(mx, my)
end

addEventHandler("onClientRender", root, function()
    local now = getTickCount()
    local x, y = CFG.x, CFG.y
    local textX = x + 14
    local areaTop = y + CFG.headerH + 6

    -- gomb ismétlés (backspace, nyilak)
    if chatActive and heldKey and now - heldStart > 400 and now - heldLast > 35 then
        heldLast = now
        editKey(heldKey)
    end

    if chatActive then
        dxDrawRectangle(x, y, CFG.w, panelH, COL.bg)
        drawCyberBorder(x - 2, y - 2, CFG.w + 4, panelH + 4, COL.cyan, 3)
        dxDrawRectangle(x, y, CFG.w, CFG.headerH, COL.headerBg)
        dxDrawRectangle(x, y + CFG.headerH, CFG.w, 1, COL.divider)
        dxDrawText("COMMS // CHAT", x + 14, y, x + CFG.w, y + CFG.headerH, COL.cyanSolid, 0.9, "default-bold", "left", "center")
        if scroll > 0 then
            dxDrawText("ARCHIVE VIEW  +" .. scroll, x, y, x + CFG.w - 14, y + CFG.headerH, COL.warn, 0.8, "default-bold", "right", "center")
        else
            dxDrawText("LIVE", x, y, x + CFG.w - 14, y + CFG.headerH, tocolor(46, 204, 113, 255), 0.8, "default-bold", "right", "center")
        end

        local total = #lines
        local last = total - scroll
        local first = math.max(1, last - CFG.visibleLines + 1)
        local row = 0
        for i = first, last do
            if not (lines[i].jumbo and i == last) then
                drawParts(lines[i], textX, areaTop + row * CFG.lineH, 255)
            end
            row = row + 1
        end

        -- görgetősáv
        if total > CFG.visibleLines then
            local trackH = CFG.visibleLines * CFG.lineH
            local trackX = x + CFG.w - 10
            local thumbH = math.max(20, trackH * CFG.visibleLines / total)
            local ratio = scroll / maxScroll() -- 0 = legalul (legújabb)
            local thumbY = areaTop + (trackH - thumbH) * (1 - ratio)
            dxDrawRectangle(trackX, areaTop, 4, trackH, tocolor(255, 255, 255, 15))
            dxDrawRectangle(trackX, thumbY, 4, thumbH, COL.cyan)
        end

        local mx, my = cursorXY()
        local btnHover = drawInput(mx, my)
        local hovEmoji, footHover = drawPicker(mx, my)
        drawCompletion(mx, my)
        if hovEmoji then
            drawTooltip(":" .. hovEmoji .. ":", mx, my)
        elseif footHover then
            drawTooltip(settings.autoConvert and "BE: a beírt :név: emojivá alakul"
                or "KI: a beírt :név: szövegként megy el, másnál sem lesz emoji", mx, my)
        elseif btnHover then
            drawTooltip("Emojik", mx, my)
        end
    else
        -- zárt chat: csak a friss üzenetek látszanak, elhalványulva
        local visible = {}
        for i = #lines, 1, -1 do
            local age = now - lines[i].time
            if age > CFG.showTime + CFG.fadeTime or #visible >= CFG.visibleLines then break end
            table.insert(visible, 1, lines[i])
        end

        local function fadeAlpha(l)
            local age = now - l.time
            local a = 255
            if age > CFG.showTime then
                a = 255 * (1 - (age - CFG.showTime) / CFG.fadeTime)
            end
            return math.max(0, math.min(255, math.floor(a)))
        end

        -- 1. kör: az összes háttércsík (a több soros, pl. nagy emojis üzenetek tartalmát
        --    így nem takarja el a következő sor csíkja)
        for idx, l in ipairs(visible) do
            local a = fadeAlpha(l)
            local yy = areaTop + (idx - 1) * CFG.lineH
            dxDrawRectangle(x, yy, CFG.w, CFG.lineH, tocolor(0, 15, 25, math.floor(150 * a / 255)))
            dxDrawRectangle(x, yy, 2, CFG.lineH, tocolor(0, 195, 255, a))
        end

        -- 2. kör: a tartalom a csíkok fölé
        for idx, l in ipairs(visible) do
            drawParts(l, textX, areaTop + (idx - 1) * CFG.lineH, fadeAlpha(l))
        end
    end
end)

---------------------------------------------------------
-- INDÍTÁS / LEÁLLÍTÁS
---------------------------------------------------------
addEventHandler("onClientResourceStart", resourceRoot, function()
    showChat(false) -- alap MTA chat elrejtése
    loadSettings()
    if pathListDir then -- MTA 1.6+: a helyi emoji mappák (a szerver is elküldi a listát)
        local ok, list = pcall(pathListDir, "emojis")
        if ok then addEmojiNames(list) end
    end
    triggerServerEvent("ttt-chat:requestCss", localPlayer)
    addMessage("#00c3ffTTT CHAT #ffffffaktív, #00c3ffgörgő#ffffff: görgetés, #00c3ff:emoji#ffffff + SPACE, #00c3ff:emo#ffffff + #00c3ffTAB#ffffff: kiegészítés", 255, 255, 255)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    guiSetInputEnabled(false)
    showCursor(false)
    showChat(true)
end)

addCommandHandler("clearchat", function()
    lines, scroll = {}, 0
end)