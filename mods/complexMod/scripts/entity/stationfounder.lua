require ("productions")

local oldFoundFactory = StationFounder.foundFactory

StationFounder.foundFactory = function (goodName, productionIndex)
    if anynils(goodName, productionIndex) then return end

    local buyer, ship, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FoundStations)
    if not buyer then return end

    local settings = GameSettings()
    if settings.maximumPlayerStations > 0 and buyer.numStations >= settings.maximumPlayerStations then
        player:sendChatMessage("Server"%_t, 1, "Maximum station limit per faction (%s) of this server reached!"%_t, settings.maximumPlayerStations)
        return
    end
    print("hi1", goodName, productionIndex)
    local production = productionsByGood[goodName][productionIndex]

    if production == nil then
        player:sendChatMessage("Server"%_t, 1, "The production line you chose doesn't exist."%_t)
        return
    end

    -- check if player has enough money
    local cost = getFactoryCost(production)

    local canPay, msg, args = buyer:canPay(cost)
    if not canPay then
        player:sendChatMessage("Station Founder"%_t, 1, msg, unpack(args))
        return
    end

    local station = StationFounder.transformToStation()
    if not station then return end

    buyer:pay("Paid %1% credits to found a factory."%_T, cost)

    -- make a factory
    station:addScript("data/scripts/entity/merchants/factory.lua", "nothing")
    station:invokeFunction("factory", "setProduction", production, 1)

    -- remove all cargo that might have been added by the factory script
    for cargo, amount in pairs(station:getCargos()) do
        station:removeCargo(cargo, amount)
    end

    -- insert cargo of the ship that founded the station
    for good, amount in pairs(ship:getCargos()) do
        station:addCargo(good, amount)
    end
    station:addScript("mods/complexMod/scripts/entity/complexManager.lua")
end
