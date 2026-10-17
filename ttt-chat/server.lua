-- ttt-chat / server.lua
-- A kliens ide küldi a chat üzenetet és a parancsokat.
-- A kiírás outputChatBox-szal történik, így a többi script üzenetei is a chatben jelennek meg.

addEvent("ttt-chat:send", true)
addEvent("ttt-chat:cmd", true)
addEvent("ttt-chat:requestCss", true)
addEvent("ttt-chat:setCss", true)

local MAX_LEN  = 250
local COOLDOWN = 1500 -- ms két üzenet között

local lastMsg = {}

local adminRanks = {
    [1] = {name = "Admin",      r = 54,  g = 168, b = 100},
    [2] = {name = "Főadmin",    r = 57,  g = 174, b = 247},
    [3] = {name = "Fejlesztő", r = 115, g = 3,  b = 252},
    [4] = {name = "Tulajdonos", r = 219, g = 89,  b = 75}
}

---------------------------------------------------------
-- CSS EFFEKTEK
-- A lista a meta.xml <file src="css/valami.css" /> soraiból épül fel.
---------------------------------------------------------
local effects, effectSet = {}, {}
local choices = {}                    -- choices[serial] = effekt neve
local CHOICES_FILE = "css_choices.json"

local function loadEffects()
    effects, effectSet = {}, {}
    local xml = xmlLoadFile("meta.xml")
    if not xml then
        outputDebugString("ttt-chat: nem tudtam beolvasni a meta.xml-t", 2)
        return
    end
    for _, node in ipairs(xmlNodeGetChildren(xml)) do
        if xmlNodeGetName(node) == "file" then
            local src = xmlNodeGetAttribute(node, "src")
            local name = src and src:match("^css/([%w_%-]+)%.css$")
            if name and not effectSet[name] then
                effectSet[name] = true
                effects[#effects + 1] = name
            end
        end
    end
    xmlUnloadFile(xml)
    table.sort(effects)
end

local function loadChoices()
    choices = {}
    if not fileExists(CHOICES_FILE) then return end
    local f = fileOpen(CHOICES_FILE, true)
    if not f then return end
    local data = fileRead(f, fileGetSize(f))
    fileClose(f)
    local t = data and data ~= "" and fromJSON(data)
    if type(t) == "table" then choices = t end
end

local function saveChoices()
    if fileExists(CHOICES_FILE) then fileDelete(CHOICES_FILE) end
    local f = fileCreate(CHOICES_FILE)
    if not f then return end
    fileWrite(f, toJSON(choices, true))
    fileClose(f)
end

local function applyChoice(player)
    local fx = choices[getPlayerSerial(player)]
    if fx and effectSet[fx] then
        setElementData(player, "chatCss", fx)
    else
        removeElementData(player, "chatCss")
    end
end

---------------------------------------------------------
-- EMOJI LISTA (a kliens választója és a TAB kiegészítés ebből dolgozik)
---------------------------------------------------------
local emojiNames = {}
local EMOJI_EXT = {"png", "jpg", "gif", "webp"}

local function loadEmojiNames()
    local set = {}
    emojiNames = {}

    local function add(dir)
        if type(dir) ~= "string" then return end
        dir = dir:match("([^/\\]+)[/\\]*$")
        if not dir or not dir:match("^[%w_%-]+$") then return end
        local name = dir:lower()
        if set[name] then return end
        for _, ext in ipairs(EMOJI_EXT) do
            if fileExists("emojis/" .. dir .. "/emoji." .. ext) then
                set[name] = true
                emojiNames[#emojiNames + 1] = name
                return
            end
        end
    end

    -- MTA 1.6+: a mappák felsorolása (így a wildcardos meta.xml sorokkal is működik)
    if pathListDir then
        local ok, list = pcall(pathListDir, "emojis")
        if ok and type(list) == "table" then
            for _, d in ipairs(list) do add(d) end
        end
    end

    -- régebbi szerver: a meta.xml-ben egyenként felvett emojik
    local xml = xmlLoadFile("meta.xml")
    if xml then
        for _, node in ipairs(xmlNodeGetChildren(xml)) do
            if xmlNodeGetName(node) == "file" then
                local src = xmlNodeGetAttribute(node, "src")
                local dir = src and src:match("^emojis/([^/%*]+)/emoji%.%w+$")
                if dir then add(dir) end
            end
        end
        xmlUnloadFile(xml)
    end

    table.sort(emojiNames)
    if #emojiNames == 0 then
        outputDebugString("ttt-chat: nem találtam emojit (MTA 1.6 alatt a meta.xml-be egyenként vedd fel őket)", 2)
    end
end

addEventHandler("onResourceStart", resourceRoot, function()
    loadEffects()
    loadChoices()
    loadEmojiNames()
    for _, p in ipairs(getElementsByType("player")) do applyChoice(p) end
end)

addEventHandler("onPlayerJoin", root, function()
    applyChoice(source)
end)

addEventHandler("ttt-chat:requestCss", root, function()
    if isElement(client) then
        triggerClientEvent(client, "ttt-chat:cssList", resourceRoot, effects)
        triggerClientEvent(client, "ttt-chat:emojiList", resourceRoot, emojiNames)
    end
end)

addEventHandler("ttt-chat:setCss", root, function(fx)
    local player = client
    if not isElement(player) or type(fx) ~= "string" then return end

    if fx == "none" then
        choices[getPlayerSerial(player)] = nil
        removeElementData(player, "chatCss")
        outputChatBox("Név effekt kikapcsolva.", player, 255, 200, 80)
    elseif effectSet[fx] then
        choices[getPlayerSerial(player)] = fx
        setElementData(player, "chatCss", fx)
        outputChatBox("Név effekt beállítva: " .. fx, player, 80, 255, 80)
    else
        return
    end
    saveChoices()
end)

---------------------------------------------------------
-- CHAT
---------------------------------------------------------

-- színkódok (#RRGGBB), vezérlőkarakterek és { } jelek kiszedése a játékosok szövegéből
-- (a { } azért, hogy senki ne tudjon {{css|...}} jelölést hamisítani)
local ESC = "\1" -- a kliens így jelöli a szövegként küldött kettőspontot (kikapcsolt automatikus átalakítás)

-- keepEsc = true: az ESC jelek megmaradnak (csak a chat üzenetnél kell)
local function clean(str, keepEsc)
    str = tostring(str or "")
    if keepEsc then
        str = str:gsub("[%z\2-\31\127]", "")
    else
        str = str:gsub("%c", "")
    end
    local n
    repeat str, n = str:gsub("#%x%x%x%x%x%x", "") until n == 0 -- "##ffffffffffff" se maradjon színkód
    str = str:gsub("[{}]", "")
    return (str:match("^%s*(.-)%s*$"))
end

-- exportált: más scriptek (pl. TTT core) is ezzel íratják ki a nevet, így az effekt náluk is látszik
function getChatName(player)
    local name = clean(getPlayerName(player))
    local prefix = ""
    local lvl = tonumber(getElementData(player, "admin")) or 0
    local rank = adminRanks[lvl]
    if rank then
        prefix = string.format("#%02x%02x%02x[%s] ", rank.r, rank.g, rank.b, rank.name)
    end

    local fx = getElementData(player, "chatCss")
    if fx and effectSet[fx] then
        -- a kliens ezt CEF-es effektes névvé alakítja
        return string.format("%s{{css|%s|%s}}#ffffff", prefix, fx, name)
    end

    local r, g, b = getPlayerNametagColor(player)
    return string.format("%s#%02x%02x%02x%s#ffffff", prefix, r, g, b, name)
end

addEventHandler("ttt-chat:send", root, function(text)
    local player = client
    if not isElement(player) or type(text) ~= "string" then return end

    text = clean(text, true):sub(1, MAX_LEN)
    local plain = text:gsub(ESC, ":") -- más scriptek (onPlayerChat) sima szöveget kapnak
    if plain == "" then return end

    if isPlayerMuted(player) then
        outputChatBox("Némítva vagy!", player, 255, 80, 80)
        return
    end

    local now = getTickCount()
    if lastMsg[player] and now - lastMsg[player] < COOLDOWN then return end
    lastMsg[player] = now

    -- A többi script (pl. TTT core) is lássa az üzenetet az onPlayerChat-en keresztül.
    -- Ha valamelyik cancelEvent()-eli (és maga írja ki), mi nem írjuk ki újra.
    if not triggerEvent("onPlayerChat", player, plain, 0) then
        outputDebugString("ttt-chat: az üzenetet egy másik script cancelEvent()-elte az onPlayerChat-en, ezért nem a ttt-chat írja ki (effekt sem látszik)", 3)
        return
    end

    -- {:} = szövegként küldött kettőspont, a kliensek ebből nem csinálnak emojit
    outputChatBox(getChatName(player) .. ": " .. (text:gsub(ESC, "{:}")), root, 255, 255, 255, true)
end)

addEventHandler("ttt-chat:cmd", root, function(cmd, args)
    local player = client
    if not isElement(player) or type(cmd) ~= "string" or type(args) ~= "string" then return end

    cmd  = cmd:sub(1, 64)
    args = args:sub(1, MAX_LEN)

    -- beépített parancs, amit az executeCommandHandler nem ismer
    if cmd:lower() == "me" then
        local text = clean(args)
        if text ~= "" then
            outputChatBox("* " .. clean(getPlayerName(player)) .. " " .. text, root, 200, 120, 255)
        end
        return
    end

    -- az addCommandHandler-es parancsok változatlanul futnak (ACL-t is ellenőrzi)
    if not executeCommandHandler(cmd, player, args) then
        outputChatBox("Ismeretlen parancs: /" .. cmd, player, 255, 80, 80)
    end
end)

addEventHandler("onPlayerQuit", root, function()
    lastMsg[source] = nil
end)

