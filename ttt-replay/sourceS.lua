-----------------------------------------
-- TTT REPLAY - SZERVER: a kör rögzítése
-- 5x/mp minden játékosról: pozíció, forgás, fegyver, él-e. Plusz események (ölések).
-- A felvételt a /replay parancs a kérő admin kliensére küldi, ahol kliensoldali pedek játsszák vissza.
-----------------------------------------
local FRAME_MS = 200          -- felvételi lépés (5 Hz)
local MAX_SAVED_ROUNDS = 3    -- ennyi kört tartunk meg memóriában

local recording = nil         -- aktuális felvétel
local recTimer = nil
local savedRounds = {}        -- [1] = legutóbbi

addEvent("ttt:onRoundStart", false)
addEvent("ttt:onRoundEnd", false)
addEvent("ttt:requestReplay", true)

local function recordFrame()
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
        -- {idő, x, y, z, rz, fegyver, él, guggol}
        table.insert(track.frames, { t, math.floor(x * 100) / 100, math.floor(y * 100) / 100, math.floor(z * 100) / 100,
            math.floor(rz), getPedWeapon(p), alive, isPedDucked(p) and 1 or 0 })
    end
end

addEventHandler("ttt:onRoundStart", root, function(duration)
    recording = { startTick = getTickCount(), duration = duration, players = {}, events = {}, date = getRealTime().timestamp }
    if isTimer(recTimer) then killTimer(recTimer) end
    recTimer = setTimer(recordFrame, FRAME_MS, 0)
    recordFrame()
end)

addEventHandler("ttt:onRoundEnd", root, function(winner)
    if not recording then return end
    if isTimer(recTimer) then killTimer(recTimer) end
    recordFrame()
    recording.winner = winner
    recording.length = getTickCount() - recording.startTick
    table.insert(savedRounds, 1, recording)
    while #savedRounds > MAX_SAVED_ROUNDS do table.remove(savedRounds) end
    recording = nil
    outputDebugString("[Replay] Kör elmentve (" .. math.floor(savedRounds[1].length / 1000) .. " mp), tárolt körök: " .. #savedRounds)
end)

-- Események: ölések
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

-- /replay [1-3] - a legutóbbi (vagy N-edik) kör visszajátszása (Admin+)
addCommandHandler("replay", function(p, cmd, idx)
    if not p or getElementType(p) ~= "player" then return end
    if (tonumber(getElementData(p, "admin")) or 0) < 1 then
        return outputChatBox("#d9534f[Replay] #ffffffEhhez admin jog kell!", p, 255, 255, 255, true)
    end
    if getElementData(p, "tttRole") then
        return outputChatBox("#d9534f[Replay] #ffffffKör közben nem nézhetsz visszajátszást (csak halottként / körök között).", p, 255, 255, 255, true)
    end
    idx = tonumber(idx) or 1
    local rec = savedRounds[idx]
    if not rec then
        return outputChatBox("#d9534f[Replay] #ffffffNincs ilyen mentett kör! (tárolva: " .. #savedRounds .. ")", p, 255, 255, 255, true)
    end
    triggerClientEvent(p, "ttt:replayData", p, rec)
    outputChatBox("#00c3ff[Replay] #ffffffVisszajátszás indul (" .. math.floor(rec.length / 1000) .. " mp, győztes: " .. tostring(rec.winner) .. "). /replaystop a leállításhoz.", p, 255, 255, 255, true)
end)

addCommandHandler("replaystop", function(p)
    if p and getElementType(p) == "player" then triggerClientEvent(p, "ttt:replayStop", p) end
end)

addCommandHandler("replays", function(p)
    if not p or (tonumber(getElementData(p, "admin")) or 0) < 1 then return end
    outputChatBox("#00c3ff[Replay] #ffffffMentett körök: " .. #savedRounds, p, 255, 255, 255, true)
    for i, r in ipairs(savedRounds) do
        local n = 0
        for _ in pairs(r.players) do n = n + 1 end
        outputChatBox(string.format("  #%d - %d mp, %d játékos, győztes: %s, %d esemény", i, math.floor(r.length / 1000), n, tostring(r.winner), #r.events), p, 255, 255, 255, true)
    end
end)
