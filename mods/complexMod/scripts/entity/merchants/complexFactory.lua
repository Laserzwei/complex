package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";mods/complexMod/scripts/lib/complextradingmanager.lua"

complexConfig = require ("mods/complexMod/config/complex")
--complexConfig = dofile("mods/complexMod/config/complex.lua")
require ("utility")
require ("complextradingmanager")
require ("goods")
require ("productions")
require ("stringutility")

MOD = complexConfig.modName
VERSION = complexConfig.version
DEBUGLEVEL = complexConfig.debuglvl
CFSCRIPT = complexConfig.CFSCRIPT
CMSCRIPT = complexConfig.CMSCRIPT
FSCRIPT = complexConfig.FSCRIPT
local minDuration = complexConfig.minDuration
local baseProductionCapacity = complexConfig.baseProductionCapacity
debugPrint = complexConfig.debugPrint

subFactories = {}

local currentProductionCycle = {}

lowestPriceFactor = 0.5
highestPriceFactor = 1.5

local currentlyProducing = false
--UI
buyTab = nil
sellTab = nil

function restore(data)
    if callingPlayer == nil then
        for id, dat in pairs(data.subFactories) do
            dat.nodeOffset = tableToVec3(dat.nodeOffset)
            dat.relativeCoords = tableToVec3(dat.relativeCoords)
            subFactories[id] = dat
        end
        currentProductionCycle = data.currentProductionCycle or {}
        restoreTradingGoods(data.tradingData)
    end
end

function secure()
    local data = {}
    local savedata = {}
    for id, dat in pairs(subFactories) do
        dat.nodeOffset = vec3ToTable(dat.nodeOffset)
        dat.relativeCoords = vec3ToTable(dat.relativeCoords)
        savedata[id] = dat
    end
    data.subFactories = savedata
    data.currentProductionCycle = currentProductionCycle
    data.tradingData = secureTradingGoods()
    return data
end

function getComplexData2()--if the Manager gets corrupted this is a fallback
    return subFactories
end

function vec3ToTable(vec)
    local retTable = {x = vec.x, y = vec.y, z = vec.z}
    return retTable
end

function tableToVec3(tab)
    local vec = vec3(tab.x, tab.y, tab.z)
    return vec
end

-- this function gets called on creation of the entity the script is attached to, on client and server
function initialize()

    if onServer() then

    else
        requestGoods()
        --sync()
    end

end

function interactionPossible(playerIndex, option)
    if next(boughtGoods) or next(soldGoods) or next(intermediateGoods) then
        return true
    else
        return false
    end
end

function setComplexData(indexedComplexData)
    debugPrint(3, "setComplexData in CFAB")

    subFactories = indexedComplexData
    setTradingGoods(subFactories)
end

function setTradingGoods(orderedSubFactories)
    --remove missing ones
    local goodList = getAllGoods()
    for _,data in pairs(orderedSubFactories) do
        local production = data.factoryTyp
        for _, result in pairs(production.results) do
            if goodList[result.name] == true then
                goodList[result.name] = false
            end
        end

        for _, garbage in pairs(production.garbages) do
            if goodList[garbage.name] == true then
                goodList[garbage.name] = false
            end
        end

        for _, ingredient in pairs(production.ingredients) do
            if goodList[ingredient.name] == true then
                goodList[ingredient.name] = false
            end
        end
    end
    debugPrint(3, "goodlist for review", goodList)
    for name, tag in pairs(goodList) do
        if tag == true then
            debugPrint(3, "found unused good", nil, name)
            removeGoodFromAllLists(name)
        end
    end

    --add possible new ones
    for _,data in pairs(orderedSubFactories) do
        local production = data.factoryTyp
        local a
        for _, result in pairs(production.results) do
            a = addGoodToSoldGoods(goods[result.name]:good())
        end

        for _, garbage in pairs(production.garbages) do
            a = addGoodToSoldGoods(goods[garbage.name]:good())
        end

        for _, ingredient in pairs(production.ingredients) do
            a = addGoodToBoughtGoods(goods[ingredient.name]:good())
        end
    end
    --boughtGoods, soldGoods, intermediateGoods, calledOnServer, isRequest
    synchTradingLists(nil,nil,nil,nil, true)
    debugPrint(3, "==============Bought==================", boughtGoods)
    debugPrint(3, "==============Sold====================", soldGoods)
    debugPrint(3, "==============Intermediate============", intermediateGoods)

end

function initUI()

    local res = getResolution()
    local size = vec2(950, 650)

    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5));
    menu:registerWindow(window, "Buy/Sell Goods"%_t);

    window.caption = "[Complex] "%_t..Entity().name
    window.showCloseButton = 1
    window.moveable = 1

    -- create a tabbed window inside the main window
    tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 10), size - 10))

    -- create buy tab
    buyTab = tabbedWindow:createTab("Buy"%_t, "data/textures/icons/purse.png", "Buy from station"%_t)
    buildBuyGui(buyTab)

    -- create sell tab
    sellTab = tabbedWindow:createTab("Sell"%_t, "data/textures/icons/coins.png", "Sell to station"%_t)
    buildSellGui(sellTab)

    guiInitialized = true

    requestGoods()
end

function onShowWindow()

    if buyTab then
        if numSold == 0 then
            tabbedWindow:deactivateTab(buyTab)
        else
            tabbedWindow:activateTab(buyTab)
        end
    end

    if sellTab then
        if numBought == 0 then
            tabbedWindow:deactivateTab(sellTab)
        else
            tabbedWindow:activateTab(sellTab)
        end
    end

    requestGoods()

end

function setTradingLists(lists)
    if onClient() then
        debugPrint(3, "setTradingLists Client")
        synchTradingLists(lists.boughtGoods, lists.soldGoods, lists.intermediateGoods)
    else
        debugPrint(0, "setTradingLists on Server not allowed!")
    end
end

function pGetMaxStock(goodName)
    return getMaxStock(goodName)
end

-- this functions gets called when the indicator of the station is rendered on the client
function renderUIIndicator(px, py, size)
    if currentProductionCycle.productionrequirement == nil or currentProductionCycle.processedP == nil then
         return
    end
    x = px - size / 2;
    y = py + size / 2;

    local index = 1

    -- outer rect
    dx = x
    dy = y + index * 5

    sx = size + 2
    sy = 4

    drawRect(Rect(dx, dy, sx + dx, sy + dy), ColorRGB(0, 0, 0));

    -- inner rect
    dx = dx + 1
    dy = dy + 1

    sx = sx - 2
    sy = sy - 2

    sx = sx * math.min(1.0,currentProductionCycle.processedP / currentProductionCycle.productionrequirement)

    drawRect(Rect(dx, dy, sx + dx, sy + dy), ColorRGB(0.66, 0.66, 1.0));

end

function updateProcessedP(totalP, procP)
    currentProductionCycle.productionrequirement = totalP
    currentProductionCycle.processedP = procP
    currentlyProducing = true
end

function passChangeInStockLimit(goodName, amount)
    local status = assignCargo(goodName, amount)
    return status
end

function startNextProductionCycle(isProducing)
    currentProductionCycle.processedP = 0
    currentProductionCycle.production, currentProductionCycle.consumption, currentProductionCycle.productionrequirement = getAllPossibleProduction()
    if currentProductionCycle.production ~= nil and next(currentProductionCycle.production) then
        consumeGoods(currentProductionCycle.consumption)
        broadcastInvokeClientFunction("updateProcessedP", currentProductionCycle.productionrequirement, 0)
        currentlyProducing = true
    end
end

function getAllPossibleProduction()
    local productionList = {}               --has productions from productionIndex.lua
    local goodsGettingProduced = {}         -- [good.name] = amount
    local goodRequired = {}                 -- [good.name] = amount
    local productionValue = 0
    for i,data in ipairs(subFactories) do
        local value = 0
        local size = data.size
        local hasEnoughResources = hasEnoughResourcesForProduction(data.factoryTyp, size, goodRequired)
        if hasEnoughResources == true then
            --has enough space for products/garbage?
            local hasSpaceForResults = true
            local hasSpaceForSingleResult = false
            for _, result in pairs(data.factoryTyp.results) do
                if (getNumGoods(result.name) + result.amount * size + (goodsGettingProduced[result.name] or 0 )) > getMaxGoods(result.name) then
                    hasSpaceForResults = false
                    debugPrint(3, "result false", data, result.name, getMaxGoods(result.name))
                else
                    local good = goods[result.name]
                    if good then
                        value = value + good.price * size * result.amount * math.max(1, good.level)
                    end
                    hasSpaceForSingleResult = true
                end
            end

            if not hasSpaceForResults and hasSpaceForSingleResult and not next(data.factoryTyp.garbages) and not next(data.factoryTyp.ingredients) then -- allow gas collectors and noble metal mines to continue producing
                hasSpaceForResults = true
            end

            local hasSpaceForGarbage = true
            for _, garbage in pairs(data.factoryTyp.garbages) do
                if (getNumGoods(garbage.name) + garbage.amount * size + (goodsGettingProduced[garbage.name] or 0 )) > getMaxGoods(garbage.name) then
                    hasSpaceForGarbage = false
                    debugPrint(3, "garbage false", data, garbage.name, getMaxGoods(garbage.name))
                else
                    local good = goods[garbage.name]
                    if good then
                        value = value + good.price * size * garbage.amount
                    end
                end
            end

            if hasSpaceForResults == true and hasSpaceForGarbage == true then
                for _,ingredient in pairs(data.factoryTyp.ingredients) do
                    goodRequired[ingredient.name] = ingredient.amount * size + (goodRequired[ingredient.name] or 0)
                end
                productionList[i] = data
            end

            if hasSpaceForResults then
                productionValue = productionValue + value
            end
        end
    end

    if Entity():hasScript(CMSCRIPT) and #subFactories > 1 then
        Entity():invokeFunction(CMSCRIPT, "synchProductionData", productionList, productionValue)
    end
    return productionList, goodRequired, productionValue
end

function consumeGoods(goodsToConsume)
    if goodsToConsume == nil then return end
    if onServer() and callingPlayer == nil then
        for name,amount in pairs(goodsToConsume) do
            debugPrint(3, "consuming:", nil, name, amount)
            decreaseGoods(name, amount)
        end
    end
end

function hasEnoughResourcesForProduction(production, size, goodRequired)
    if size == nil then return false end
    if next(production.ingredients) == nil then return true end
    for _,ingredient in pairs(production.ingredients) do
        if ingredient.amount * size + (goodRequired[ingredient.name] or 0) > getNumGoods(ingredient.name) then
            return false
        end
    end
    return true
end

function getUpdateInterval()
    return minDuration
end

-- this function gets called once each frame, on client and server
function updateServer(timeStep)
    local productionCapacity = Plan():getStats().productionCapacity + (baseProductionCapacity * math.max(1,#subFactories))
    local productionProduced = productionCapacity * timeStep
    if currentlyProducing == true then
        currentProductionCycle.processedP = currentProductionCycle.processedP + productionProduced
        broadcastInvokeClientFunction("updateProcessedP", currentProductionCycle.productionrequirement, currentProductionCycle.processedP)
        if currentProductionCycle.processedP >= currentProductionCycle.productionrequirement then
            debugPrint(3, "nextProductiona after", currentProductionCycle, Entity().index.string)
            currentlyProducing = false
            addProducts(currentProductionCycle.production)
            currentProductionCycle = {}
            startNextProductionCycle()
        end
    else
        debugPrint(3, "nextProduction", nil, Entity().index.string)
        startNextProductionCycle()
    end
end

function addProducts(data)
    if onServer() and callingPlayer == nil then
        local totalAdded = {}
        local factoryHasProduced = {}                       --factoryHasProduced[priority] = {good.name, amount}
        for i,data in pairs(currentProductionCycle.production) do
            local production = data.factoryTyp
            local size = data.size
            for _, result in pairs(production.results) do
                increaseGoods(result.name, result.amount * size)
                factoryHasProduced[i] = {[result.name] = result.amount * size}
                totalAdded[result.name] = result.amount * size + (totalAdded[result.name] or 0)
            end

            for _, garbage in pairs(production.garbages) do
                increaseGoods(garbage.name, garbage.amount * size)
                factoryHasProduced[i] = {[garbage.name] = garbage.amount * size}
                totalAdded[garbage.name] = garbage.amount * size + (totalAdded[garbage.name] or 0)
            end
        end
        --[[
        for priority,produced in pairs(factoryHasProduced) do
            for name, amount in pairs(produced) do
                if subFactories[priority] ~= nil then
                    debugPrint(3, "ProductionStats", priority, subFactories[priority].name, subFactories[priority].factoryBlockId, "produced: ", name, amount)
                else
                    debugPrint(3, "Did The Complex Layout change?")
                end
            end
        end]]--
    end
end
