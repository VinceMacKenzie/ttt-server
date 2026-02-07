addEventHandler("onClientPedDamage", root, function(attacker, weapon, bodypart, loss)
    -- Csak akkor küldjük, ha MI vagyunk a támadók
    if attacker == localPlayer then
        -- Meghívjuk a szerveroldali eseményt
        triggerServerEvent("onCustomPedDamage", localPlayer, source, weapon, bodypart, loss)
    end
end)