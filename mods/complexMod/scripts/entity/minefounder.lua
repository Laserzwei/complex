require ("productions")

function foundFactory(goodName, productionIndex, name)
    if anynils(goodName, productionIndex, name) then return end

    local buyer, asteroid, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FoundStations)
    if not buyer then return end

    local settings = GameSettings()
    if settings.maximumPlayerStations > 0 and buyer.numStations >= settings.maximumPlayerStations then
        player:sendChatMessage("Server"%_t, 1, "Maximum station limit per faction (%s) of this server reached!"%_t, settings.maximumPlayerStations)
        return
    end

    -- don't allow empty names
    name = name or ""
    if name == "" then
        name = "${good} Mine"%_t % {good = goodName}
    end

    if player:ownsShip(name) then
        player:sendChatMessage("Server"%_t, 1, "You already own an object called ${name}."%_t % {name = name})
        return
    end

    DebugInfo():log("goodName: %s productionIndex: %s name: %s", tostring(goodName), tostring(productionIndex), tostring(name))
    local production = productionsByGood[goodName][productionIndex]

    if production == nil then
        player:sendChatMessage("Server"%_t, 1, "The production line you chose doesn't exist."%_t)
        return
    end

    -- check if player has enough money
    local cost = getFactoryCost(production)
    local canPay, msg, args = buyer:canPay(cost)
    if not canPay then
        player:sendChatMessage("Server"%_t, 1, msg, unpack(args))
        return
    end

    buyer:pay("Paid %1% credits to found a mine."%_T, cost)

    local station = transformToStation(asteroid, name)
    if goodName == "Raw Oil" then
        station.title = "Oil Rig"%_t
    else
        station.title = "${good} Mine"%_t % {good = goodName}
    end

    -- make a factory
    station:addScript("data/scripts/entity/merchants/factory.lua", "nothing")

    station:invokeFunction("factory", "setProduction", production, 1)

    -- remove all goods from mine, it should start from scratch
    local stock, max = station:invokeFunction("factory", "getStock", goodName)
    station:invokeFunction("factory", "decreaseGoods", goodName, stock)

    -- remove all cargo that might have been added by the factory script
    for cargo, amount in pairs(station:getCargos()) do
        station:removeCargo(cargo, amount)
    end
    station:addScript("mods/complexMod/scripts/entity/complexManager.lua")
end
