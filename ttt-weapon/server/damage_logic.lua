-- server/damage_logic.lua
--
-- FIGYELEM (ismert korlát): a szerveroldali onPlayerDamage NEM szakítható meg (cancelEvent nem hat rá),
-- ezért a játékos-játékos sebzésnél az MTA alap sebzése IS érvényesül, és erre jön rá a custom érték.
-- Végleges megoldás: kliensoldali onClientPlayerDamage cancel + a szerver számolja a sebzést.

local function updateWeaponDurability(weaponID)
    if not weaponID then return end
    if math.random(1, 10) == 1 then
        exports["ttt-sql"]:dbQueryExec("UPDATE weapons SET durability = GREATEST(0, durability - 1) WHERE id = ?", weaponID)
    end
end

local function applyFireBuff(victim)
    local duration = (Config.Buffs.fire and Config.Buffs.fire.duration) or 3
    setElementOnFire(victim, true)
    setTimer(function(target)
        if isElement(target) and getElementHealth(target) > 0 then
            setElementHealth(target, math.max(0, getElementHealth(target) - 1))
            if getElementType(target) == "ped" then
                setPedAnimation(target, "ped", "ev_step", 500, false, true, true, false)
            end
        end
    end, 1000, duration, victim)
    setTimer(function(target)
        if isElement(target) then setElementOnFire(target, false) end
    end, duration * 1000, 1, victim)
end

local function applyCustomDamage(victim, attacker, weapon, bodypart, loss)
    if not isElement(attacker) or getElementType(attacker) ~= "player" then return end
    if not isElement(victim) then return end

    local weaponData = getPlayerActiveStats(attacker)
    if not weaponData or weaponData.weapon_model ~= getPedWeapon(attacker) then return end

    cancelEvent()

    bodypart = tonumber(bodypart)
    local isHeadshot = (bodypart == 9)

    -- 1. Sebzés
    local finalDamage
    if isHeadshot then finalDamage = weaponData.mod_head_dmg
    elseif bodypart == 3 then finalDamage = weaponData.mod_body_dmg
    else finalDamage = loss or 10 end

    -- 2. Állapot szorzó
    finalDamage = finalDamage * math.max(0.1, weaponData.durability / 100)

    -- 3. Élet levonása
    local currentHP = getElementHealth(victim)
    if isHeadshot and finalDamage >= 100 then
        killPed(victim, attacker, weapon, bodypart)
    else
        setElementHealth(victim, math.max(0, currentHP - finalDamage))
    end

    -- 4. Tűz buff
    if weaponData.buff_fire > 0 and math.random(1, 100) <= weaponData.buff_fire then
        applyFireBuff(victim)
    end

    -- 5. Életszívás
    if weaponData.buff_life_drain == 1 then
        local drainAmt = (Config.Buffs.life_drain and Config.Buffs.life_drain.amount) or 5
        setElementHealth(attacker, math.min(100, getElementHealth(attacker) + drainAmt))
    end

    -- 6. Amortizáció
    updateWeaponDurability(weaponData.id)
end

-- Kliensről jövő jel (pedekhez)
addEvent("onCustomPedDamage", true)
addEventHandler("onCustomPedDamage", root, function(victim, weapon, bodypart, loss)
    if not client or not isElement(victim) or getElementType(victim) ~= "ped" then return end
    applyCustomDamage(victim, client, weapon, bodypart, loss)
end)

-- Szerveroldali figyelő (játékosokhoz)
addEventHandler("onPlayerDamage", root, function(attacker, weapon, bodypart, loss)
    applyCustomDamage(source, attacker, weapon, bodypart, loss)
end)
