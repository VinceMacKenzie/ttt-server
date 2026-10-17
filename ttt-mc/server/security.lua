--[[
    Admin jogosultság + adatvédelem

    Admin: ugyanaz a rendszer, mint a szerver többi resource-ában (ttt-admin, ttt-int, ttt-spawn, ttt-replay...):
    az "admin" element data (0-4, a ttt-login tölti be az adatbázisból). Konzol = mindig admin.
    Ezen felül az MTA ACL "Admin" / "Console" csoport tagjai is adminnak számítanak.

    Adatvédelem: MTA-ban a kliens a SAJÁT element datáját is átírhatja (setElementData a kliensen), és ez
    szinkronizálódik a szerverre. Így egy csaló kliens beállíthatná magának az "admin" szintet vagy a
    "tttRole"-t, és akkor minden admin parancs (a haverod resource-ainak parancsai is, mert mind az "admin"
    element datát nézik) elérhető lenne neki, sőt a ttt-login kilépéskor el is mentené az adatbázisba.
    Ezért a kliens által módosított védett kulcsokat a szerver azonnal visszaállítja. A szerver resource-ai
    (ttt-admin /setadmin, ttt-login, ttt-core...) ugyanúgy állíthatják őket, mint eddig.
]]

Security = {}

function Security.isConsole(p)
    return not p or not isElement(p) or getElementType(p) == "console"
end

local function inAclGroup(p)
    local acc = getPlayerAccount(p)
    if not acc or isGuestAccount(acc) then return false end
    local obj = "user." .. getAccountName(acc)
    for _, g in ipairs(Config.ADMIN_ACL_GROUPS or {}) do
        local group = aclGetGroup(g)
        if group and isObjectInACLGroup(obj, group) then return true end
    end
    return false
end

-- admin szint: konzol = 4, különben az "admin" element data
function Security.level(p)
    if Security.isConsole(p) then return 4 end
    if getElementType(p) ~= "player" then return 0 end
    return tonumber(getElementData(p, "admin")) or 0
end

function Security.isAdmin(p, minLevel)
    if Security.isConsole(p) then return true end
    if getElementType(p) ~= "player" then return false end
    if Security.level(p) >= (minLevel or Config.ADMIN_LEVEL or 1) then return true end
    return inAclGroup(p)
end

-- parancsokhoz: false + hibaüzenet, ha nincs jog
function Security.require(p, minLevel)
    if Security.isAdmin(p, minLevel) then return true end
    if isElement(p) and getElementType(p) == "player" then
        outputChatBox("#d9534f[Minecraft] #ffffffEhhez admin jog kell!", p, 255, 255, 255, true)
    end
    return false
end

-------------------------------------------------------------------------------- védett element data
local function isProtected(key)
    if type(key) ~= "string" then return false end
    if (Config.PROTECTED_DATA or {})[key] then return true end
    for _, prefix in ipairs(Config.PROTECTED_DATA_PREFIXES or {}) do
        if key:sub(1, #prefix) == prefix then return true end
    end
    return false
end

Security.blocked = 0
addEventHandler("onElementDataChange", root, function(key, oldValue, newValue)
    if not Config.PROTECT_ELEMENT_DATA then return end
    -- "client" csak akkor van beállítva, ha a változást egy kliens küldte (a szerver resource-ai nem érintettek)
    if not client or not isProtected(key) then return end
    local el, who = source, client
    if oldValue == nil then
        removeElementData(el, key)
    else
        setElementData(el, key, oldValue)
    end
    Security.blocked = Security.blocked + 1
    local name = isElement(who) and getPlayerName(who) or "?"
    local msg = ("[mc] SECURITY: %s (%s) tried to change protected element data '%s' -> %s (reverted)")
        :format(name, isElement(who) and getPlayerSerial(who) or "?", key, tostring(newValue))
    outputDebugString(msg, 2)
    outputServerLog(msg)
    -- az online adminok is lássák (ugyanúgy, mint a ttt-admin admin chatje)
    for _, p in ipairs(getElementsByType("player")) do
        if p ~= who and Security.level(p) >= 1 then
            outputChatBox("#d9534f[Minecraft] #ffffff" .. name .. " megpróbálta átírni a(z) '" .. key ..
                "' adatot (visszaállítva).", p, 255, 255, 255, true)
        end
    end
end)
