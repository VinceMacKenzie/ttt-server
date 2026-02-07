-- server/damage_logic.lua

local function applyCustomDamage(victim, attacker, weapon, bodypart, loss)
    if not attacker or not isElement(attacker) or getElementType(attacker) ~= "player" then return end
    if not victim or not isElement(victim) then return end

    local weaponData = getPlayerActiveStats(attacker)
    
    if weaponData and tonumber(weaponData.weapon_model) == getPedWeapon(attacker) then
        cancelEvent()

        local finalDamage = 0
        local bodypart = tonumber(bodypart)
        local isHeadshot = (bodypart == 9)

        -- 1. SEBZÉS KISZÁMÍTÁSA
        if isHeadshot then
            finalDamage = tonumber(weaponData.mod_head_dmg) or 0
        elseif bodypart == 3 then
            finalDamage = tonumber(weaponData.mod_body_dmg) or 0
        else
            finalDamage = loss or 10
        end

        -- 2. DURABILITY SZORZÓ
        local durability = tonumber(weaponData.durability) or 100
        local conditionMul = math.max(0.1, durability / 100)
        finalDamage = finalDamage * conditionMul

        -- 3. ÉLET LEVONÁSA
        local currentHP = getElementHealth(victim)
        if isHeadshot and finalDamage >= 100 then
            setElementHealth(victim, 0)
            killPed(victim, attacker, weapon, bodypart)
        else
            setElementHealth(victim, math.max(0, currentHP - finalDamage))
        end

        -- 4. TŰZ EFFEKT (BRUTÁLIS MÓDSZER)
        if tonumber(weaponData.buff_fire) > 0 then
            local chance = tonumber(weaponData.buff_fire)
            
            if math.random(1, 100) <= chance then
                -- Pozíció lekérése a pontos effekthez
                local x, y, z = getElementPosition(victim)
                
                -- A) Vizuális tűz effekt létrehozása az NPC-re (Kliens is látja)
                setElementOnFire(victim, true)
                
                outputDebugString("[BUFF] Tűz próbálkozás: " .. getPlayerName(attacker) .. " -> " .. getElementType(victim))

                -- C) Kényszerített HP vonás (hogy biztosan sebezzen)
                local fireDuration = 3
                setTimer(function(target)
                    if isElement(target) and getElementHealth(target) > 0 then
                        local hp = getElementHealth(target)
                        setElementHealth(target, math.max(0, hp - 1))
                        -- Ha ped, akkor kényszerítsük a "tűz" animációt
                        if getElementType(target) == "ped" then
                            setPedAnimation(target, "ped", "ev_step", 500, false, true, true, false)
                        end
                    end
                end, 1000, fireDuration, victim)

                -- Eloltás
                setTimer(function(target)
                    if isElement(target) then 
                        setElementOnFire(target, false) 
                    end
                end, fireDuration * 1000, 1, victim)
            end
        end
        
        -- 5. ÉLETSZÍVÁS
        if tonumber(weaponData.buff_life_drain) == 1 then
            local drainAmt = 5
            if Config and Config.Buffs and Config.Buffs["life_drain"] then
                drainAmt = Config.Buffs["life_drain"].amount or 5
            end
            setElementHealth(attacker, math.min(100, getElementHealth(attacker) + drainAmt))
        end

        -- 6. AMORTIZÁCIÓ
        if weaponData.id then updateWeaponDurability(weaponData.id) end
        
        outputDebugString("[DAMAGE] Target HP: " .. getElementHealth(victim))
    end
end

-- Kliensről jövő jel fogadása (Pedekhez)
addEvent("onCustomPedDamage", true)
addEventHandler("onCustomPedDamage", root, function(victim, weapon, bodypart, loss)
    applyCustomDamage(victim, client, weapon, bodypart, loss)
end)

-- Szerveroldali figyelő (Játékosokhoz)
addEventHandler("onPlayerDamage", root, function(attacker, weapon, bodypart, loss)
    applyCustomDamage(source, attacker, weapon, bodypart, loss)
end)

-- Segédfüggvény a fegyver állapotának frissítéséhez
function updateWeaponDurability(weaponID)
    if not weaponID then return end
    if math.random(1, 10) == 1 then
        exports["ttt-sql"]:dbQueryExec("UPDATE weapons SET durability = GREATEST(0, durability - 1) WHERE id = ?", weaponID)
    end
end