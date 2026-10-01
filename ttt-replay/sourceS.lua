-----------------------------------------
-- TTT REPLAY - SZERVER: a kör rögzítése + JSON mentés + néző dimenzió kezelés
--
-- Frame (tömb, hogy kicsi legyen a JSON):
--  { t, x, y, z, rz, weapon, alive, ducked, move, aim, cx, cy, cz, lx, ly, lz, fire }
--   move: 0 áll, 1 sétál, 2 fut, 3 sprintel   aim: 1 ha célzott   fire: 1 ha lőtt az elmúlt 200 ms-ban
--   cx..lz: a JÁTÉKOS kamerája (pozíció + nézett pont) - a kliens küldi 5 Hz-en
-- Fájlok: replays/replay_ÉÉÉÉ-HH-NN_ÓÓ-PP-MM.json + replays/index.json
-----------------------------------------
local FRAME_MS = 100          -- felvételi lépés (10 Hz)
local MAX_SAVED_FILES = 50
local REPLAY_DIM_BASE = 60000   -- minden néző saját dimenziót kap: BASE + sorszám
local INDEX_FILE = "replays/index.json"

local recording = nil
local recTimer = nil
local lastCam = {}              -- [player] = {cx,cy,cz,lx,ly,lz}
local index = {}                -- [1] = legutóbbi: {file, date, dateStr, winner, length, players, events}
local viewers = {}              -- [player] = {dim, int, x, y, z}
local recordFrame               -- előre deklarálva (a /replaysave is használja)

addEvent("ttt:onRoundStart", false)
addEvent("ttt:onRoundEnd", false)
addEvent("ttt:replayCam", true)
addEvent("ttt:replayEnded", true)

local function round2(v) return math.floor(v * 100 + 0.5) / 100 end

-----------------------------------------
-- INDEX (fájllista) kezelése - az MTA-ban nincs mappa-listázás, ezért vezetjük
-----------------------------------------
local function loadIndex()
    if not fileExists(INDEX_FILE) then index = {} return end
    local f = fileOpen(INDEX_FILE, true)
    if not f then index = {} return end
    local data = fileRead(f, fileGetSize(f))
    fileClose(f)
    index = fromJSON(data) or {}
end

local function saveIndex()
    if fileExists(INDEX_FILE) then fileDelete(INDEX_FILE) end
    local f = fileCreate(INDEX_FILE)
    if not f then return end
    fileWrite(f, toJSON(index, true))
    fileClose(f)
end

local lastError = nil
local lastSaved = nil

local function saveRecordingUnsafe(rec)
    local rt = getRealTime(rec.date)
    local dateStr = string.format("%04d-%02d-%02d_%02d-%02d-%02d", rt.year + 1900, rt.month + 1, rt.monthday, rt.hour, rt.minute, rt.second)
    local fileName = "replays/replay_" .. dateStr .. ".json"

    local json = toJSON(rec, true)
    if not json then
        error("toJSON sikertelen (túl nagy vagy nem szerializálható felvétel)")
    end

    local f = fileCreate(fileName)
    if not f then
        error("fileCreate sikertelen: " .. fileName .. " (létezik a ttt-replay/replays mappa? írható a resource mappa?)")
    end
    fileWrite(f, json)
    fileClose(f)

    local n = 0
    for _ in pairs(rec.players) do n = n + 1 end
    table.insert(index, 1, {
        file = fileName, date = rec.date, dateStr = dateStr:gsub("_", " "):gsub("%-(%d%d)%-(%d%d)$", ":%1:%2"),
        winner = rec.winner, length = rec.length, players = n, events = #rec.events,
    })
    while #index > MAX_SAVED_FILES do
        local old = table.remove(index)
        if old.file and fileExists(old.file) then fileDelete(old.file) end
    end
    saveIndex()
    lastSaved = fileName
    outputDebugString("[Replay] Mentve: " .. fileName .. " (" .. math.floor(rec.length / 1000) .. " mp, " .. n .. " játékos)")
end

-- Mentés hibavédetten: ha bármi elszáll (toJSON, fájl írás), a hiba a konzolba és a /replaydebug-ba kerül
local function saveRecording(rec)
    local ok, err = pcall(saveRecordingUnsafe, rec)
    if not ok then
        lastError = tostring(err)
        outputDebugString("[Replay] MENTÉSI HIBA: " .. lastError, 1)
        outputChatBox("#d9534f[Replay] #ffffffA kör mentése nem sikerült, nézd meg a szerver konzolt! (" .. lastError .. ")", root, 255, 255, 255, true)
    end
end

local function loadRecording(entry)
    if not entry or not entry.file or not fileExists(entry.file) then return nil end
    local f = fileOpen(entry.file, true)
    if not f then return nil end
    local data = fileRead(f, fileGetSize(f))
    fileClose(f)
    return fromJSON(data)
end

addEventHandler("onResourceStart", resourceRoot, function()
    loadIndex()
    outputDebugString("[Replay] Indítva, mentett körök az indexben: " .. #index .. " (index fájl: " .. tostring(fileExists(INDEX_FILE)) .. ")")
end)

-- /replaydebug - állapot kiírása hibakereséshez (Admin+)
addCommandHandler("replaydebug", function(p)
    if p and getElementType(p) == "player" and (tonumber(getElementData(p, "admin")) or 0) < 1 then return end
    local lines = {}
    if recording then
        local n, frames = 0, 0
        for _, tr in pairs(recording.players) do n = n + 1; frames = frames + #tr.frames end
        table.insert(lines, "Felvétel: AKTÍV | " .. n .. " játékos, " .. frames .. " frame, " .. #recording.events .. " esemény, " .. math.floor((getTickCount() - recording.startTick) / 1000) .. " mp")
    else
        table.insert(lines, "Felvétel: nincs (kör közben indul a ttt:onRoundStart eventre)")
    end
    table.insert(lines, "Index: " .. #index .. " bejegyzés | index.json létezik: " .. tostring(fileExists(INDEX_FILE)))
    table.insert(lines, "Utolsó mentés: " .. tostring(lastSaved) .. " | utolsó hiba: " .. tostring(lastError))
    table.insert(lines, "Kamera adat érkezett: " .. (function() local c = 0 for _ in pairs(lastCam) do c = c + 1 end return c end)() .. " játékostól")
    for _, l in ipairs(lines) do
        if p and getElementType(p) == "player" then outputChatBox("#00c3ff[ReplayDebug] #ffffff" .. l, p, 255, 255, 255, true) else print("[ReplayDebug] " .. l) end
    end
end)

-- /replaysave - az aktuális (futó) felvétel azonnali mentése teszthez (Admin+)
addCommandHandler("replaysave", function(p)
    if p and getElementType(p) == "player" and (tonumber(getElementData(p, "admin")) or 0) < 1 then return end
    if not recording then
        if p then outputChatBox("#d9534f[Replay] #ffffffNincs futó felvétel.", p, 255, 255, 255, true) end
        return
    end
    recordFrame()
    local copy = {}
    for k, v in pairs(recording) do copy[k] = v end
    copy.winner = "teszt"
    copy.length = getTickCount() - recording.startTick
    copy.startTick = nil
    saveRecording(copy)
    if p then outputChatBox("#00c3ff[Replay] #ffffffMentés megkísérelve, lásd /replays és a konzol.", p, 255, 255, 255, true) end
end)

-----------------------------------------
-- FELVÉTEL
-----------------------------------------
-- A kliens 5 Hz-en küldi a saját kamerájának mátrixát
-- A kliens 5 Hz-en küldi: kamera mátrix + mozgásállapot + célzás
-- (a getPedControlState CSAK kliensoldalon létezik, ezért ezeket a kliens számolja)
addEventHandler("ttt:replayCam", root, function(cx, cy, cz, lx, ly, lz, move, aim, fire)
    if not client or not recording then return end
    if type(cx) ~= "number" or type(lz) ~= "number" then return end
    lastCam[client] = { round2(cx), round2(cy), round2(cz), round2(lx), round2(ly), round2(lz),
        move = tonumber(move) or 0, aim = tonumber(aim) or 0, fire = tonumber(fire) or 0 }
end)

-- Ha (még) nincs kliens adat: csak áll/mozog a sebességből
local function getMoveStateFallback(p)
    local vx, vy, vz = getElementVelocity(p)
    if (vx * vx + vy * vy + vz * vz) < 0.0004 then return 0 end
    return 2
end

recordFrame = function()
    if not recording then return end
    local t = getTickCount() - recording.startTick
    for _, p in ipairs(getElementsByType("player")) do
        local name = getPlayerName(p)
        local track = recording.players[name]
        if not track then
            track = { skin = getElementModel(p), role = getElementData(p, "tttRole") or "Innocent", frames = {} }
            recording.players[name] = track
        end
        local x, y, z = getElementPosition(p)
        local _, _, rz = getElementRotation(p)
        local alive = (not isPedDead(p)) and (getElementData(p, "tttRole") ~= false) and 1 or 0
        local cam = lastCam[p]
        if not cam then
            -- Még nem jött kliens adat: a fej mögötti pontot használjuk
            cam = { round2(x + math.sin(math.rad(rz)) * 3), round2(y - math.cos(math.rad(rz)) * 3), round2(z + 1.5),
                round2(x), round2(y), round2(z + 0.7), move = getMoveStateFallback(p), aim = 0, fire = 0 }
        end
        table.insert(track.frames, {
            t, round2(x), round2(y), round2(z), math.floor(rz), getPedWeapon(p) or 0, alive, isPedDucked(p) and 1 or 0,
            cam.move, cam.aim,
            cam[1], cam[2], cam[3], cam[4], cam[5], cam[6],
            cam.fire or 0,
        })
    end
end

addEventHandler("ttt:onRoundStart", root, function(duration)
    -- Aki épp replayt néz, azt visszahozzuk (a core új körbe spawnolja)
    for p in pairs(viewers) do
        if isElement(p) then triggerClientEvent(p, "ttt:replayStop", p) end
    end
    viewers = {}

    recording = { version = 2, startTick = getTickCount(), duration = duration, players = {}, events = {}, date = getRealTime().timestamp }
    lastCam = {}
    triggerClientEvent(root, "ttt:replayRecording", root, true)
    if isTimer(recTimer) then killTimer(recTimer) end
    recTimer = setTimer(recordFrame, FRAME_MS, 0)
    recordFrame()
    outputDebugString("[Replay] Felvétel elindult (" .. tostring(duration) .. " mp-es kör)")
end)

addEventHandler("ttt:onRoundEnd", root, function(winner)
    triggerClientEvent(root, "ttt:replayRecording", root, false)
    if not recording then
        return outputDebugString("[Replay] Kör vége, de nem volt aktív felvétel (a resource kör közben indult?)", 2)
    end
    if isTimer(recTimer) then killTimer(recTimer) end
    recordFrame()
    recording.winner = winner
    recording.length = getTickCount() - recording.startTick
    recording.startTick = nil
    saveRecording(recording)
    recording = nil
end)

addEventHandler("onPlayerWasted", root, function(ammo, attacker, weapon)
    if not recording then return end
    local t = getTickCount() - recording.startTick
    local victim = getPlayerName(source)
    local text
    if attacker and isElement(attacker) and getElementType(attacker) == "player" and attacker ~= source then
        text = getPlayerName(attacker) .. " (" .. tostring(getElementData(attacker, "tttRole")) .. ") megölte: " .. victim ..
            " (" .. tostring(getElementData(source, "tttRole")) .. ") - " .. (weapon and getWeaponNameFromID(weapon) or "?")
    else
        text = victim .. " meghalt"
    end
    table.insert(recording.events, { t, text })
end)

addEventHandler("onPlayerQuit", root, function()
    lastCam[source] = nil
    viewers[source] = nil
end)

-----------------------------------------
-- VISSZAJÁTSZÁS: néző külön dimenzióba, adat küldése
-----------------------------------------
local function freeDimension()
    local used = {}
    for _, v in pairs(viewers) do used[v.dim] = true end
    local d = REPLAY_DIM_BASE
    while used[d] do d = d + 1 end
    return d
end

local function restoreViewer(p)
    local v = viewers[p]
    if not v then return end
    viewers[p] = nil
    if not isElement(p) then return end
    setElementDimension(p, v.dim0)
    setElementInterior(p, v.int)
    setElementPosition(p, v.x, v.y, v.z)
    setElementAlpha(p, 255)
end

addEventHandler("ttt:replayEnded", root, function()
    if client then restoreViewer(client) end
end)

-- /replay [sorszám] - 1 = legutóbbi (lásd /replays)
addCommandHandler("replay", function(p, cmd, idx)
    if not p or getElementType(p) ~= "player" then return end
    if (tonumber(getElementData(p, "admin")) or 0) < 1 then
        return outputChatBox("#d9534f[Replay] #ffffffEhhez admin jog kell!", p, 255, 255, 255, true)
    end
    if getElementData(p, "tttRole") then
        return outputChatBox("#d9534f[Replay] #ffffffKör közben nem nézhetsz visszajátszást (csak halottként / körök között).", p, 255, 255, 255, true)
    end
    idx = tonumber(idx) or 1
    local entry = index[idx]
    if not entry then
        return outputChatBox("#d9534f[Replay] #ffffffNincs ilyen mentett kör! (tárolva: " .. #index .. ", lista: /replays)", p, 255, 255, 255, true)
    end
    local rec = loadRecording(entry)
    if not rec then
        return outputChatBox("#d9534f[Replay] #ffffffA fájl nem olvasható: " .. tostring(entry.file), p, 255, 255, 255, true)
    end

    -- Néző elmentése és átrakása saját dimenzióba (ott csak a saját kliensoldali pedjeit látja)
    if viewers[p] then restoreViewer(p) end
    local x, y, z = getElementPosition(p)
    local dim = freeDimension()
    viewers[p] = { dim = dim, dim0 = getElementDimension(p), int = getElementInterior(p), x = x, y = y, z = z }
    setElementDimension(p, dim)
    setElementInterior(p, 0)
    setElementAlpha(p, 0)

    rec.dimension = dim
    rec.fileName = entry.file
    -- Nagy adat -> latent event (nem akasztja meg a többi forgalmat)
    triggerLatentClientEvent(p, "ttt:replayData", 500000, false, p, rec)
    outputChatBox("#00c3ff[Replay] #ffffffBetöltés: " .. entry.dateStr .. " (" .. math.floor(rec.length / 1000) .. " mp, győztes: " .. tostring(rec.winner) .. "). /replaystop a leállításhoz.", p, 255, 255, 255, true)
end)

addCommandHandler("replaystop", function(p)
    if p and getElementType(p) == "player" then
        triggerClientEvent(p, "ttt:replayStop", p)
        restoreViewer(p)
    end
end)

addCommandHandler("replays", function(p)
    if not p or (tonumber(getElementData(p, "admin")) or 0) < 1 then return end
    outputChatBox("#00c3ff[Replay] #ffffffMentett körök: " .. #index .. " (replays/ mappa)", p, 255, 255, 255, true)
    for i, r in ipairs(index) do
        if i > 15 then outputChatBox("  ... és még " .. (#index - 15), p, 200, 200, 200) break end
        outputChatBox(string.format("  #%d  %s  |  %d mp, %d játékos, győztes: %s, %d esemény", i, r.dateStr, math.floor(r.length / 1000), r.players, tostring(r.winner), r.events), p, 255, 255, 255, true)
    end
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for p in pairs(viewers) do restoreViewer(p) end
end)
