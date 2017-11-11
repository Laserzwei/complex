package.path = package.path .. ";data/scripts/lib/?.lua"
require ("galaxy")
require ("utility")
require ("goods")
require ("stringutility")
require ("player")
require ("faction")

VERSION = "[0.89] "
MOD = "[CPX3]"

DEBUGLEVEL = 2              -- is overwritten by DEBUGLEVEL in complexFactory.lua

CMSCRIPT = "mods/complexMod/scripts/entity/complexManager.lua"
buyPriceFactor = 1
sellPriceFactor = 1

boughtGoods = {}            -- {["name"] = {["index"] = good}};  index, good = next(boughtGoods["name"])
soldGoods = {}
intermediateGoods = {}
assignedCargoList = {}      --assignedCargoList[good.name] = amount
                            --assigned Cargo only alters, when assignCargo(good.name, maxStock) is called. Not even if it would exceed the total Cargospace!
                            --Therfore assigned Cargospace might not ever fill up.
assignedCargo = 0           --only gets altered when assigned Cargo gets altered

numAssignedCargo = 0
numSold = 0
numBought = 0
numIntermediate = 0

policies =
{
    sellsIllegal = false,
    buysIllegal = false,

    sellsStolen = false,
    buysStolen = false,

    sellsSuspicious = false,
    buysSuspicious = false,
}

-- UI
local scrollFrameBought, scrollFrameSold
boughtLines = {}

soldLines = {}

guiInitialized = false

--
useTimeCounter = 0 -- time counter for using up bought products

function debugPrint(debuglvl, msg, tableToPrint, ...)
    if debuglvl <= DEBUGLEVEL then
        print(MOD..VERSION..msg, ...)
        if type(tableToPrint) == "table" then
            printTable(tableToPrint)
        end
    end
end

-- help functions
function isSoldBySelf(good)
    if good.illegal and not policies.sellsIllegal then
        local msg = "This station doesn't sell illegal goods."%_t
        return false, msg
    end

    if good.stolen and not policies.sellsStolen then
        local msg = "This station doesn't sell stolen goods."%_t
        return false, msg
    end

    if good.suspicious and not policies.sellsSuspicious then
        local msg = "This station doesn't sell suspicious goods."%_t
        return false, msg
    end

    return true
end

function isBoughtBySelf(good)
    if good.illegal and not policies.buysIllegal then
        local msg = "This station doesn't buy illegal goods."%_t
        return false, msg
    end

    if good.stolen and not policies.buysStolen then
        local msg = "This station doesn't buy stolen goods."%_t
        return false, msg
    end

    if good.suspicious and not policies.buysSuspicious then
        local msg = "This station doesn't buy suspicious goods."%_t
        return false, msg
    end

    return true
end

function generateGoods(min, max)
    return bought, sold
end

function restoreTradingGoods(data)
    debugPrint(4, "restoring tradingdata")
    buyPriceFactor = data.buyPriceFactor
    sellPriceFactor = data.sellPriceFactor
    policies = data.policies
    assignedCargoList = data.assignedCargoList or {}
    numAssignedCargo = data.numAssignedCargo or 0

    debugPrint(3, "assignedCargoList", assignedCargoList, numAssignedCargo, assignedCargo)

    numAssignedCargo = 0
    for _,amount in pairs(assignedCargoList) do
        numAssignedCargo = numAssignedCargo + 1
        assignedCargo = assignedCargo + amount
    end

    numBought = 0
    boughtGoods = {}
    for name, pair in pairs(data.boughtGoods) do
        local index, goodTable = next(pair)
        numBought = numBought + 1
        boughtGoods[name] = {[numBought] = tableToGood(goodTable)}

    end
    debugPrint(3, "boughtGoods", boughtGoods)
    numSold = 0
    soldGoods = {}
    for name, pair in pairs(data.soldGoods) do
        local index, goodTable = next(pair)
        numSold = numSold + 1
        soldGoods[name] = {[numSold] = tableToGood(goodTable)}

    end
    debugPrint(3, "SoldGoods", soldGoods)
    numIntermediate = 0
    intermediateGoods = {}
    for name, pair in pairs(data.intermediateGoods) do
        local index, goodTable = next(pair)
        numIntermediate = numIntermediate + 1
        intermediateGoods[name] = {[numIntermediate] = tableToGood(goodTable)}

    end
    debugPrint(3, "intermediateGoods", intermediateGoods)

end

function secureTradingGoods()
    debugPrint(3, "securing Tradingdata")

    local data = {}
    data.buyPriceFactor = buyPriceFactor
    data.sellPriceFactor = sellPriceFactor
    data.policies = policies
    data.assignedCargoList = assignedCargoList
    data.numAssignedCargo = numAssignedCargo

    data.boughtGoods = {}
    for name, pair in pairs(boughtGoods) do
        local index, good = next(pair)
        debugPrint(3, "boughtGoods", nil, index, good.name)
        data.boughtGoods[name] = {[index] = goodToTable(good)}
    end

    data.soldGoods = {}
    for name, pair in pairs(soldGoods) do
        local index, good = next(pair)
        debugPrint(3, "soldGoods", nil, index, good.name)
        data.soldGoods[name] = {[index] = goodToTable(good)}
    end

    data.intermediateGoods = {}
    for name, pair in pairs(intermediateGoods) do
        local index, good = next(pair)
        debugPrint(3, "intermediateGoods", nil, index, good.name)
        data.intermediateGoods[name] = {[index] = goodToTable(good)}
    end

    return data
end

function synchTradingLists(boughtGoodsIn, soldGoodsIn, intermediateGoodsIn, calledOnServer, isRequest)
    debugPrint(4,"synchTradingLists input", {boughtGoodsIn, soldGoodsIn, intermediateGoodsIn}, calledOnServer, isRequest, callingPlayer)
    if isRequest == true then
        if onServer() == true then
            local sectorPlayers = Sector():getPlayers() or {}
            debugPrint(4,"PlayerList", sectorPlayers)
            --for _,player in pairs(sectorPlayers) do
                --if player.index == Entity().factionIndex then
                    broadcastInvokeClientFunction("synchTradingLists", boughtGoods, soldGoods, intermediateGoods, true)
                    --invokeClientFunction(Player(Entity().factionIndex), "synchTradingLists", boughtGoods, soldGoods, intermediateGoods, true)
                --end
            --end
        else
            invokeServerFunction("synchTradingLists", nil, nil, nil, false, true)
        end
        return
    end

    if onServer() == true then
        if calledOnServer == false then
            if checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations) then
                updateTradingLists(boughtGoodsIn, soldGoodsIn, intermediateGoodsIn)
            else
                debugPrint(0, "unathorized modification access on tradingLists from player with index: ", nil, callingPlayer)
            end
        else
            debugPrint(4, "synchTradingLists ", nil, calledOnServer, isRequest)
        end
    else
        if calledOnServer == nil then
            invokeServerFunction("synchTradingLists", boughtGoodsIn, soldGoodsIn, intermediateGoodsIn, false)
        else
            debugPrint(4, "synchTradingLists ", nil, calledOnServer, isRequest)
        end
        updateTradingLists(boughtGoodsIn, soldGoodsIn, intermediateGoodsIn)
    end

end

function updateTradingLists(boughtGoodsIn, soldGoodsIn, intermediateGoodsIn)
    if boughtGoodsIn ~= nil then
        numBought = 0
        boughtGoods = {}
        for _, g in pairs(boughtGoodsIn) do
            local index, good = next(g)
            if type(good) == "table" then good = tableToGood(good) end
            numBought = numBought + 1
            boughtGoods[good.name] = {[numBought] = good}
        end
    end

    if soldGoodsIn ~= nil then
        numSold = 0
        soldGoods = {}
        for _, g in pairs(soldGoodsIn) do
            local index, good = next(g)
            if type(good) == "table" then good = tableToGood(good) end
            numSold = numSold + 1
            soldGoods[good.name] = {[numSold] = good}
        end
    end

    if intermediateGoodsIn ~= nil then
        numIntermediate = 0
        intermediateGoods = {}
        for _, g in pairs(intermediateGoodsIn) do
            local index, good = next(g)
            if type(good) == "table" then good = tableToGood(good) end
            numIntermediate = numIntermediate + 1
            intermediateGoods[good.name] = {[numIntermediate] = good}
        end
    end
    if onClient() then
        local status = Entity():invokeFunction(CMSCRIPT, "passChangedTradingDataToTT", secureTradingGoods())
        debugPrint(3, "updateTradingLists to trading overview status:", nil, status)
    end
end

function addGoodToBoughtGoods(goodIn)
    local good, index = getGoodByName(goodIn.name)
    if good ~= nil then return false end
    if boughtGoods[goodIn.name] == nil then
        numBought = numBought + 1
        boughtGoods[goodIn.name] = {[numBought] = goodIn}
        return true
    else
        return false
    end
end

function addGoodToSoldGoods(goodIn)
    local good, index = getGoodByName(goodIn.name)
    if good ~= nil then return false end
    if soldGoods[goodIn.name] == nil then
        numSold = numSold + 1
        soldGoods[goodIn.name] = {[numSold] = goodIn}
        return true
    else
        return false
    end
end

function addGoodToIntermediateGoods(goodIn)
    local good, index = getGoodByName(goodIn.name)
    if good ~= nil then return false end
    if intermediateGoods[goodIn.name] == nil then
        numIntermediate = numIntermediate + 1
        intermediateGoods[goodIn.name] = {[numIntermediate] = goodIn}
        return true
    else
        return false
    end
end

function removeGoodFromAllLists(goodName)
    --if onServer() then broadcastInvokeClientFunction("removeGoodFromAllLists", goodName) end
    if assignedCargoList[goodName] ~= nil then
        unassignCargo(goodName)
    end
    if boughtGoods[goodName] ~= nil then
        local index = next(boughtGoods[goodName])
        boughtGoods[goodName] = nil
        numBought = numBought - 1
        for name, pair in pairs(boughtGoods) do
            local i,g = next(pair)
            if index < i then
                boughtGoods[name] = {[i-1] = g}
            end
        end
    end
    if soldGoods[goodName] ~= nil then
        local index = next(soldGoods[goodName])
        soldGoods[goodName] =  nil
        numSold = numSold - 1
        for name, pair in pairs(soldGoods) do
            local i,g = next(pair)
            if index < i then
                soldGoods[name] = {[i-1] = g}
            end
        end
    end
    if intermediateGoods[goodName] ~= nil then
        local index = next(intermediateGoods[goodName])
        intermediateGoods[goodName] = nil
        numIntermediate = numIntermediate - 1
        for name, pair in pairs(intermediateGoods) do
            local i,g = next(pair)
            if index < i then
                intermediateGoods[name] = {[i-1] = g}
            end
        end
    end
end

function getBuysFromOthers()
    return next(boughtGoods) ~= nil
end

function getSellsToOthers()
    return next(soldGoods) ~= nil
end

function getAllGoods()
    local goodList = {}
    for name,_ in pairs(boughtGoods or {}) do
        goodList[name] = true
    end
    for name,_ in pairs(soldGoods or {}) do
        goodList[name] = true
    end
    for name,_ in pairs(intermediateGoods or {}) do
        goodList[name] = true
    end
    return goodList
end

function requestGoods()
    if onServer() == true then debugPrint(0, "requestGoods() on Server not allowed!") return end
    boughtGoods = {}
    soldGoods = {}
    intermediateGoods = {}
    assignedCargoList = {}

    numBought = 0
    numSold = 0
    numIntermediate = 0
    numAssignedCargo = 0

    assignedCargo = 0

    invokeServerFunction("sendGoods", Player().index)
end

function sendGoods(playerIndex)
    if callingPlayer ~= playerIndex then debugPrint(0,"Wrong Player requested", nil, "expected: ", callingPlayer, "got: ", playerIndex) return end
    local player = Player(playerIndex)
    local data = {}
    data.buyPriceFactor = buyPriceFactor
    data.sellPriceFactor = sellPriceFactor
    data.boughtGoods = boughtGoods
    data.numBought = numBought
    data.soldGoods = soldGoods
    data.numSold = numSold
    data.intermediateGoods = intermediateGoods
    data.numIntermediate = numIntermediate
    data.policies = policies
    data.assignedCargoList = assignedCargoList
    data.assignedCargo = assignedCargo
    data.numAssignedCargo = numAssignedCargo


    invokeClientFunction(player, "receiveGoods", data)
end

function receiveGoods(data_in)
    buyPriceFactor = data_in.buyPriceFactor
    sellPriceFactor = data_in.sellPriceFactor
    assignedCargo = data_in.assignedCargo

    policies = data_in.policies

    boughtGoods = data_in.boughtGoods
    soldGoods = data_in.soldGoods
    intermediateGoods = data_in.intermediateGoods
    assignedCargoList = data_in.assignedCargoList

    numBought = data_in.numBought
    numSold = data_in.numSold
    numIntermediate = data_in.numIntermediate
    numAssignedCargo = data_in.numAssignedCargo

    for _,line in pairs(boughtLines) do
        line:hide()
    end

    for _,line in pairs(soldLines) do
        line:hide()
    end

    debugPrint(3, "boughtGoodsc", boughtGoods)
    for name, pair in pairs(boughtGoods) do
        local index , good = next(pair)
        updateBoughtGoodGui(index, good, getBuyPrice(name, Player().index))
    end
    debugPrint(3, "soldGoodsc", soldGoods)

    for name, pair in pairs(soldGoods) do
        local index , good = next(pair)
        updateSoldGoodGui(index, good, getSellPrice(name, Player().index))
    end
    debugPrint(3,"intermediateGoodsc", intermediateGoods)
end

function updateBoughtGoodGui(index, good, price)

    if not guiInitialized then return end

    local maxAmount = getMaxStock(good.name)
    local amount = getNumGoods(good.name)

    line = boughtLines[index]
    if line == nil then
        debugPrint(4, "creating new Line-bought", nil, good.name, index)
        genericLine(nil, scrollFrameSold, index, good.name)
        line = boughtLines[index]
        if line == nil then
            debugPrint(0, "creation of new line-bought failed:", boughtLines, good.name, index)
        end
    end
    line.name.caption = good.displayName
    line.stock.caption = amount .. "/" .. maxAmount
    line.price.caption = createMonetaryString(price)
    line.size.caption = round(good.size, 2)
    line.icon.picture = good.icon
    line.goodName = good.name

    local ownCargo = 0
    local ship = Entity(Player().craftIndex)
    if ship then
        ownCargo = ship:getCargoAmount(good) or 0
    end
    if ownCargo == 0 then ownCargo = "-" end
    line.you.caption = tostring(ownCargo)

    line:show()
end

function updateSoldGoodGui(index, good, price)
    debugPrint(3, "sold Goods", nil, tostring(guiInitialized))
    if not guiInitialized then return end

    local maxAmount = getMaxStock(good.name)
    local amount = getNumGoods(good.name)

    line = soldLines[index]
    if line == nil then
        debugPrint(4, "creating new Line-sold", nil, good.name, index)
        genericLine(scrollFrameBought, nil, index, good.name)
        line = soldLines[index]
        if line == nil then
            debugPrint(0, "creation of new line-sold failed:", soldLines, good.name, index)
        end
    end

    line.name.caption = good.displayName
    line.stock.caption = amount .. "/" .. maxAmount
    line.price.caption = createMonetaryString(price)
    line.size.caption = round(good.size, 2)
    line.icon.picture = good.icon
    line.goodName = good.name

    --for i, good in pairs(soldGoods) do
    --local line = soldLines[i]

    local ownCargo = 0
    local ship = Entity(Player().craftIndex)
    if ship then
        ownCargo = math.floor((ship.freeCargoSpace or 0) / good.size)
    end

    if ownCargo == 0 then ownCargo = "-" end
    line.you.caption = tostring(ownCargo)
    --end

    line:show()

end

function updateBoughtGoodAmount(goodName)
    if boughtGoods[goodName] == nil then return end
    local index, good = next(boughtGoods[goodName])

    if good ~= nil then -- it's possible that the production may start before the initialization of the client version of the factory
        local status = Entity():invokeFunction(CMSCRIPT, "updateTradingdata")
        debugPrint(3, "ubga", nil, status)
        updateBoughtGoodGui(index, good, getBuyPrice(good.name, Player().index))
    end

end

function updateSoldGoodAmount(goodName)
    if soldGoods[goodName] == nil then return end
    local index, good = next(soldGoods[goodName])

    if good ~= nil then -- it's possible that the production may start before the initialization of the client version of the factory
        local status = Entity():invokeFunction(CMSCRIPT, "updateTradingdata")
        debugPrint(3, "usga", nil, status)
        updateSoldGoodGui(index, good, getSellPrice(good.name, Player().index))
    end
end

function buildBuyGui(window)
    buildGui(window, 1)
end

function buildSellGui(window)
    buildGui(window, 0)
end

function buildGui(window, guiType)
    local size = window.size
    local scrollFrame = window:createScrollFrame(Rect(vec2(0,30), vec2(window.size.x, window.size.y-30)))
    scrollFrame.scrollSpeed = 35
    scrollFrame.paddingBottom = 18

    local nameX = 10
    local stockX = 310
    local volX = 480
    local priceX = 540
    local youX = 620

    local buttonSize = 70
    -- header
    window:createLabel(vec2(nameX, 5), "Name"%_t, 15)
    window:createLabel(vec2(stockX, 5), "Stock"%_t, 15)
    window:createLabel(vec2(priceX, 5), "Cr"%_t, 15)
    window:createLabel(vec2(volX, 5), "Vol"%_t, 15)

    if guiType == 1 then
        window:createLabel(vec2(youX, 5), "Max"%_t, 15)
    else
        window:createLabel(vec2(youX, 5), "You"%_t, 15)
    end

    if guiType == 1 then
        scrollFrameBought = scrollFrame
    else
        scrollFrameSold = scrollFrame
    end
    guiInitialized = true
end

function genericLine(pScrollFrameBought, pScrollFrameSold, index, goodName)
    if onServer() then debugPrint(0, "Error in generic Line: onServer") end
    local scrollFrame, line
    local guiType
    if pScrollFrameBought ~= nil then
        guiType = 1
        scrollFrame = pScrollFrameBought
    end
    if pScrollFrameSold ~= nil then
        guiType = 0
        scrollFrame = pScrollFrameSold
    end

    local buttonCaption = ""
    local buttonCallback = ""
    local textCallback = ""

    if guiType == 1 then
        buttonCaption = "Buy"%_t
        buttonCallback = "onBuyButtonPressed"
        textCallback = "onBuyTextEntered"
    else
        buttonCaption = "Sell"%_t
        buttonCallback = "onSellButtonPressed"
        textCallback = "onSellTextEntered"
    end

    local nameX = 10
    local pictureX = 270
    local stockX = 310
    local volX = 480
    local priceX = 540
    local youX = 620
    local textBoxX = 710
    local buttonX = 790

    local buttonSize = 70

    local y = 5 + 35*(index-1)

    --create Line-objects
    local yText = y + 6

    local frame = scrollFrame:createFrame(Rect(5, y, textBoxX - 10, 30 + y))

    local nameLabel = scrollFrame:createLabel(vec2(nameX, yText), "", 15)
    nameLabel.size = vec2(nameLabel.size.x,35)
    nameLabel.caption = goodName
    local icon = scrollFrame:createPicture(Rect(pictureX, yText - 5, 29 + pictureX, 29 + yText - 5), "")
    local stockLabel = scrollFrame:createLabel(vec2(stockX, yText), "", 15)
    stockLabel.size = vec2(stockLabel.size.x,35)

    local sizeLabel = scrollFrame:createLabel(vec2(volX, yText), "", 15)
    sizeLabel.size = vec2(100,35)
    local priceLabel = scrollFrame:createLabel(vec2(priceX, yText), "", 15)
    priceLabel.size = vec2(100,35)
    local youLabel = scrollFrame:createLabel(vec2(youX, yText), "", 15)
    youLabel.size = vec2(100,35)

    local numberTextBox = scrollFrame:createTextBox(Rect(textBoxX, yText - 6, 60 + textBoxX, 30 + yText - 6), textCallback)
    local button = scrollFrame:createButton(Rect(buttonX, yText - 6, scrollFrame.size.x-25, 30 + yText - 6), buttonCaption, buttonCallback)

    button.maxTextSize = 16

    numberTextBox.text = "0"
    numberTextBox.allowedCharacters = "0123456789"
    numberTextBox.clearOnClick = 1

    icon.isIcon = 1

    local show = function (self)
        self.icon:show()
        self.frame:show()
        self.name:show()
        self.stock:show()
        self.price:show()
        self.size:show()
        self.number:show()
        self.button:show()
        self.you:show()
    end
    local hide = function (self)
        self.icon:hide()
        self.frame:hide()
        self.name:hide()
        self.stock:hide()
        self.price:hide()
        self.size:hide()
        self.number:hide()
        self.button:hide()
        self.you:hide()
    end

    local line = {icon = icon, frame = frame, name = nameLabel, stock = stockLabel, price = priceLabel, you = youLabel, size = sizeLabel, number = numberTextBox, button = button, show = show, hide = hide, goodName = goodName}
    line:show()

    if guiType == 1 then
        soldLines[index] = line
    else
        boughtLines[index] = line
    end
end

function onBuyTextEntered(textBox)
    local enteredNumber = tonumber(textBox.text)
    if enteredNumber == nil then
        enteredNumber = 0
    end
    local newNumber = enteredNumber

    local goodIndex = nil
    for i, line in pairs(soldLines) do
        if line.number.index == textBox.index then
            goodIndex = i
            break
        end
    end
    local line = soldLines[goodIndex]
    if line == nil then debugPrint(1,"Line doesn't match to TextBox: ", soldLines, goodIndex) return end

    local goodName = line.goodName
    if goodName == nil then debugPrint(1, "goodID not found: ", nil, goodIndex)return end
    if soldGoods[goodName] == nil then debugPrint(1, goodName.." not sold") return end

    local _, good = next(soldGoods[goodName])
    if good == nil then
        debugPrint(1, "good with Name " .. goodName .. " isn't sold.")
        printEntityDebugInfo()
        return
    end

    -- make sure the player can't buy more than the station has in stock
    local stock = getNumGoods(good.name)
    if stock < newNumber then
        newNumber = stock
    end

    local ship = Player().craft
    if ship.freeCargoSpace == nil then return end --> no cargo bay

    -- make sure the player does not buy more than he can have in his cargo bay
    local maxShipHold = math.floor(ship.freeCargoSpace / good.size)
    local msg

    if maxShipHold < newNumber then
        newNumber = maxShipHold
        if newNumber == 0 then
            msg = "Not enough space in your cargo bay!"%_t
        else
            msg = "You can only store ${amount} of this good!"%_t % {amount = newNumber}
        end
    end

    -- make sure the player does not buy more than he can afford (if this isn't his station)
    if Faction().index ~= Player().index then
        local maxAffordable = math.floor(Player().money / getSellPrice(good.name, Player().index))
        if Player().infiniteResources then maxAffordable = math.huge end

        if maxAffordable < newNumber then
            newNumber = maxAffordable

            if newNumber == 0 then
                msg = "You can't afford any of this good!"%_t
            else
                msg = "You can only afford ${amount} of this good!"%_t % {amount = newNumber}
            end
        end
    end

    if msg then
        sendError(nil, msg)
    end

    if newNumber ~= enteredNumber then
        textBox.text = newNumber
    end
end

function onSellTextEntered(textBox)

    local enteredNumber = tonumber(textBox.text)
    if enteredNumber == nil then
        enteredNumber = 0
    end

    local newNumber = enteredNumber

    local goodIndex = nil
    for i, line in pairs(boughtLines) do
        if line.number.index == textBox.index then
            goodIndex = i
            break
        end
    end
    local line = boughtLines[goodIndex]
    if line == nil then debugPrint(1, "Line doesn't match to TextBox: ", nil, goodIndex) return end

    local goodName = line.goodName
    if goodName == nil then debugPrint(1, "goodID not found: ", nil, goodIndex)return end
    if boughtGoods[goodName] == nil then debugPrint(1, goodName.." not bought") return end

    local _, good = next(boughtGoods[goodName])
    if good == nil then
        debugPrint(1, "good with index " .. goodName .. " isn't bought")
        printEntityDebugInfo()
        return
    end

    local stock = getNumGoods(good.name)

    local maxAmountPlaceable = math.max(0, getMaxStock(good.name) - stock)
    if maxAmountPlaceable < newNumber then
        newNumber = maxAmountPlaceable
    end


    local ship = Player().craft

    local msg

    -- make sure the player does not sell more than he has in his cargo bay
    local amountOnPlayerShip = ship:getCargoAmount(good)
    if amountOnPlayerShip == nil then return end --> no cargo bay

    if amountOnPlayerShip < newNumber then
        newNumber = amountOnPlayerShip
        if newNumber == 0 then
            msg = "You don't have any of this!"%_t
        end
    end

    if msg then
        sendError(nil, msg)
    end

    -- maximum number of sellable things is the amount the player has on his ship
    if newNumber ~= enteredNumber then
        textBox.text = newNumber
    end
end

function onBuyButtonPressed(button)

    local shipIndex = Player().craftIndex

    local goodIndex = nil
    for i, line in ipairs(soldLines) do
        if line.button.index == button.index then
            goodIndex = i
        end
    end
    local line = soldLines[goodIndex]

    if line == nil then debugPrint(1, "Line doesn't match to Button: ", nil, goodIndex) return end
    local goodName = line.goodName

    if goodName == nil then debugPrint(1, "goodID not found: ", nil, goodIndex)return end
    if soldGoods[goodName] == nil then debugPrint(1, goodName.." not bought") return end

    local _, good = next(soldGoods[goodName])
    if good == nil then
        debugPrint(1, "internal error, good " .. goodName .. " of buy button not found.", nil, goodIndex)
        printEntityDebugInfo()
        return
    end

    local amount = soldLines[goodIndex].number.text
    if amount == "" then
        amount = 0
    else
        amount = tonumber(amount)
    end

    invokeServerFunction("sellToShip", shipIndex, good.name, amount)
end

function onSellButtonPressed(button)

    local shipIndex = Player().craftIndex

    local goodIndex = nil
    for i, line in ipairs(boughtLines) do
        if line.button.index == button.index then
            goodIndex = i
        end
    end
    local line = boughtLines[goodIndex]

    if line == nil then debugPrint(1, "Line doesn't match to Button: ", nil, goodIndex) return end
    local goodName = line.goodName

    if goodName == nil then debugPrint(1, "goodID not found: ", nil, goodIndex)return end
    if boughtGoods[goodName] == nil then debugPrint(1, goodName.." not bought") return end

    local _, good = next(boughtGoods[goodName])
    if good == nil then
        debugPrint(1, "internal error, good " .. goodName .. " of sell button not found.", nil, goodIndex)
        printEntityDebugInfo()
        return
    end

    local amount = boughtLines[goodIndex].number.text
    if amount == "" then
        amount = 0
    else
        amount = tonumber(amount)
    end
    amount = math.max(amount, 0)
    invokeServerFunction("buyFromShip", shipIndex, good.name, amount)

end

function sendError(faction, msg, ...)
    if onServer() then
        if faction.isPlayer then
            Player(faction.index):sendChatMessage(Entity().title, 1, msg, ...)
        end
    elseif onClient() then
        displayChatMessage(msg, Entity().title, 1)
    end
end

function transferMoney(owner, from, to, amount, fromDescription, toDescription)
    if from.index == to.index then return end

    local ownerMoney = amount

    if owner.index == from.index then
        from:pay(fromDescription or "", ownerMoney)
        to:receive(toDescription or "", amount)
    elseif owner.index == to.index then
        from:pay(fromDescription or "", amount)
        to:receive(toDescription or "", ownerMoney)
    else
        from:pay(fromDescription or "", amount)
        to:receive(toDescription or "", amount)
    end
end

function buyFromShip(shipIndex, goodName, amount, noDockCheck)
    local ship = Entity(shipIndex)
    local shipFaction = Faction(ship.factionIndex)

    -- check if the good can be bought
    if boughtGoods[goodName] == nil then
        sendError(shipFaction, "%s isn't bought."%_t, goodName)
        return
    end


    if ship.freeCargoSpace == nil then
        sendError(shipFaction, "Your ship has no cargo bay!"%_t)
        return
    end

    -- check if the specific good from the player can be bought (ie. it's not illegal or something like that)
    local cargos = ship:findCargos(goodName)
    local goodOnShip = nil
    local msg = "You don't have any %s that the station buys!"%_t
    local args = {goodName}

    for g, amount in pairs(cargos) do
        local ok
        ok, msg = isBoughtBySelf(g)
        args = {}
        if ok then
            goodOnShip = g
            break
        end
    end

    if not goodOnShip then
        sendError(shipFaction, msg, unpack(args))
        return
    end

    local station = Entity()
    local stationFaction = Faction()

    -- make sure the ship can not sell more than the station can have in stock
    local maxAmountPlaceable = getMaxStock(goodOnShip.name) - getNumGoods(goodOnShip.name);

    if maxAmountPlaceable < amount then
        amount = maxAmountPlaceable

        if maxAmountPlaceable == 0 then
            sendError(shipFaction, "This station is not able to take any more %s."%_t, goodOnShip.plural)
        end
    end

    -- make sure the player does not sell more than he has in his cargo bay
    local amountOnShip = ship:getCargoAmount(goodOnShip)

    if amountOnShip < amount then
        amount = amountOnShip

        if amountOnShip <= 0 then
            sendError(shipFaction, "You don't have any %s on your ship"%_t, goodOnShip.plural)
        end
    end

    if amount <= 0 then
        return
    end

    -- begin transaction
    -- calculate price. if the seller is the owner of the station, the price is 0
    local price = getBuyPrice(goodOnShip.name, shipFaction.index) * amount

    local canPay, msg, args = stationFaction:canPay(price);
    if not canPay then
        sendError(shipFaction, "This station's faction doesn't have enough money."%_t)
        return
    end

    if not noDockCheck then
        -- test the docking last so the player can know what he can buy from afar already
        local errors = {}
        errors[EntityType.Station] = "You must be docked to the station to trade."%_T
        errors[EntityType.Ship] = "You must be closer to the ship to trade."%_T
        if not CheckShipDocked(shipFaction, ship, station, errors) then
            return
        end
    end

    -- give money to ship faction
    shipFaction:receive(price)
    stationFaction:pay(price)

    -- remove goods from ship
    ship:removeCargo(goodOnShip, amount)

    -- add goods to station
    increaseGoods(goodOnShip.name, amount)

    -- trading (non-military) ships get double the relation gain
    local relationsChange = GetRelationChangeFromMoney(price)
    if ship:getNumArmedTurrets() <= 1 then
        relationsChange = relationsChange * 2
    end

    Galaxy():changeFactionRelations(shipFaction, stationFaction, relationsChange)

end

function sellToShip(shipIndex, goodName, amount, noDockCheck)
    local ship = Entity(shipIndex)
    local shipFaction = Faction(ship.factionIndex)

    good, index = getSoldGoodByName(goodName)
    if good == nil then
        sendError(shipFaction, "%s isn't sold."%_t, goodName)
        return
    end

    if ship.freeCargoSpace == nil then
        sendError(shipFaction, "Your ship has no cargo bay!"%_t)
        return
    end

    local station = Entity()
    local stationFaction = Faction()

    -- make sure the player can not buy more than the station has in stock
    local amountBuyable = getNumGoods(goodName)

    if amountBuyable < amount then
        amount = amountBuyable

        if amountBuyable == 0 then
             sendError(shipFaction, "This station has no more %s to sell."%_t, good.plural)
        end
    end

    -- make sure the player does not buy more than he can have in his cargo bay
    local maxShipHold = math.floor(ship.freeCargoSpace / good.size)

    if maxShipHold < amount then
        amount = maxShipHold

        if maxShipHold == 0 then
            sendError(shipFaction, "Your ship can not take more %s."%_t, good.plural)
        end
    end

    if amount == 0 then
        return
    end

    -- begin transaction
    -- calculate price. if the owner of the station wants to buy, the price is 0
    local price = getSellPrice(good.name, shipFaction.index) * amount

    local canPay, msg, args = shipFaction:canPay(price);
    if not canPay then
        sendError(shipFaction, msg, unpack(args))
        return
    end

    if not noDockCheck then
        -- test the docking last so the player can know what he can buy from afar already
        local errors = {}
        errors[EntityType.Station] = "You must be docked to the station to trade."%_T
        errors[EntityType.Ship] = "You must be closer to the ship to trade."%_T
        if not CheckShipDocked(shipFaction, ship, station, errors) then
            return
        end
    end

    -- make player pay
    shipFaction:pay(price)
    stationFaction:receive(price)

    -- give goods to player
    ship:addCargo(good, amount)

    -- remove goods from station
    decreaseGoods(good.name, amount)

    -- trading (non-military) ships get double the relation gain
    local relationsChange = GetRelationChangeFromMoney(price)
    if ship:getNumArmedTurrets() <= 1 then
        relationsChange = relationsChange * 2
    end

    Galaxy():changeFactionRelations(shipFaction, stationFaction, relationsChange)

end

function buyGoods(good, amount, otherFactionIndex, monetaryTransactionOnly)

    -- check if the good is even bought by the station
    if not getBoughtGoodByName(good.name) == nil then return 1 end

    local ok = isBoughtBySelf(good)
    if not ok then return 4 end

    local stationFaction = Faction()
    local otherFaction = Faction(otherFactionIndex)

    -- make sure the transaction can not sell more than the station can have in stock
    local buyable = getMaxStock(good.name) - getNumGoods(good.name);
    amount = math.min(buyable, amount)
    if amount <= 0 then return 2 end

    -- begin transaction
    -- calculate price. if the seller is the owner of the station, the price is 0
    local price = getBuyPrice(good.name, otherFactionIndex) * amount

    local canPay, msg, args = stationFaction:canPay(price);
    if not canPay then return 3 end

    local x, y = Sector():getCoordinates()
    local fromDescription = Format("\\s(%1%:%2%) %3% bought %4% %5% for %6% credits."%_T, x, y, Entity().title, math.floor(amount), good.translatablePlural, createMonetaryString(price))
    local toDescription = Format("\\s(%1%:%2%): sold %3% %4% for %5% credits."%_T, x, y, math.floor(amount), good.translatablePlural, createMonetaryString(price))

    -- give money to other faction
    transferMoney(stationFaction, stationFaction, otherFaction, price, fromDescription, toDescription)

    if not monetaryTransactionOnly then
        -- add goods to station
        increaseGoods(good.name, amount)
    end

    local relationsChange = GetRelationChangeFromMoney(price)
    Galaxy():changeFactionRelations(otherFaction, stationFaction, relationsChange)

    return 0
end

-- convenience function for selling goods to another faction. They're not added to another ship, they just disappear
function sellGoods(good, amount, otherFactionIndex, monetaryTransactionOnly)

    local stationFaction = Faction()
    local otherFaction = Faction(otherFactionIndex)

    local sellable = getNumGoods(good.name)
    amount = math.min(sellable, amount)
    if amount <= 0 then return 1 end

    local price = getSellPrice(good.name, otherFactionIndex) * amount
    local canPay = otherFaction:canPay(price);
    if not canPay then return 2 end

    local x, y = Sector():getCoordinates()
    local toDescription = Format("\\s(%1%:%2%) %3% sold %4% %5% for %6% credits."%_T, x, y, Entity().title, math.floor(amount), good.translatablePlural, createMonetaryString(price))
    local fromDescription = Format("\\s(%1%:%2%): Bought %3% %4% for %5% credits."%_T, x, y, math.floor(amount), good.translatablePlural, createMonetaryString(price))

    -- make other faction pay
    transferMoney(stationFaction, otherFaction, stationFaction, price, fromDescription, toDescription)

    if not monetaryTransactionOnly then
        -- remove goods from station
        decreaseGoods(good.name, amount)
    end

    local relationsChange = GetRelationChangeFromMoney(price)
    Galaxy():changeFactionRelations(otherFaction, stationFaction, relationsChange)

    return 0
end

function increaseGoods(goodName, delta)
    local boughtHasBeenIncreased, soldHasBeenIncreased, intermediateHasBeenIncreased = false, false, false

    local self = Entity()

    local good, index = getBoughtGoodByName(goodName)
    if good ~= nil then
        -- increase
        local current = self:getCargoAmount(good)
        delta = math.min(delta, getMaxStock(good.name) - current)
        delta = math.max(delta, 0)

        self:addCargo(good, delta)
        broadcastInvokeClientFunction("updateBoughtGoodAmount", goodName)
        boughtHasBeenIncreased = true
    end

    local good, index = getSoldGoodByName(goodName)
    if good ~= nil then
        -- increase
        local current = self:getCargoAmount(good)
        delta = math.min(delta, getMaxStock(good.name) - current)
        delta = math.max(delta, 0)

        self:addCargo(good, delta)
        broadcastInvokeClientFunction("updateSoldGoodAmount", goodName)
        soldHasBeenIncreased = true
    end

    local good, index = getIntermediateGoodByName(goodName)
    if good ~= nil then
        -- increase
        local current = self:getCargoAmount(good)
        delta = math.min(delta, getMaxStock(good.name) - current)
        delta = math.max(delta, 0)

        self:addCargo(good, delta)
        intermediateHasBeenIncreased = true
    end

end

function decreaseGoods(goodName, amount)
    local boughtHasBeenDecreased, soldHasBeenDecreased, intermediateHasBeenDecreased = false, false, false

    local self = Entity()

    local good, index = getBoughtGoodByName(goodName)
    if good ~= nil then
        --decrease
        self:removeCargo(good, amount)
        broadcastInvokeClientFunction("updateBoughtGoodAmount", goodName)
        boughtHasBeenDecreased = true
    end

    local good, index = getSoldGoodByName(goodName)
    if good ~= nil then
        --decrease
        self:removeCargo(good, amount)
        broadcastInvokeClientFunction("updateSoldGoodAmount", goodName)
        soldHasBeenDecreased = true
    end

    local good, index = getIntermediateGoodByName(goodName)
    if good ~= nil then
        -- decrease
        self:removeCargo(good, amount)
        intermediateHasBeenDecreased = true
    end

end

function useUpBoughtGoods(timeStep)
    debugPrint(0, " useUpBoughtGoods has been called: ", nil, timeStep)
end

function getBoughtGoods()
    local result = {}

    for name,_ in pairs(boughtGoods) do
        table.insert(result, name)
    end

    return unpack(result)
end

function getSoldGoods()
    local result = {}

    for name, _ in pairs(soldGoods) do
        table.insert(result, name)
    end

    return unpack(result)
end

function getIntermediateGoods()
    local result = {}

    for name,_ in pairs(intermediateGoods) do
        table.insert(result, name)
    end

    return unpack(result)
end

function getStock(name)
    return getNumGoods(name), getMaxGoods(name)
end

function getNumGoods(name)
    local self = Entity()

    local good = goods[name]:good()
    if not good then return 0 end

    return self:getCargoAmount(good)
end

function getMaxGoods(goodName)
    local amount = 0

    local good, index = getGoodByName(goodName)
    if good == nil or index == nil then debugPrint(3, "not In Staion: ", nil, goodName) return end

    return getMaxStock(goodName)
end

function getGoodSize(goodName)
    local good,_ = getGoodByName(goodName)

    if good ~= nil then
        return good.size
    else
       debugPrint(0, "error: " .. goodName .. " is neither bought nor sold")
    end
end

function getMaxStock(goodName)
    local self = Entity()
    local good = getGoodByName(goodName)
    if good == nil then return 0 end                    --maybe dangerous -> divide by zero
    local goodSize = good.size
    if assignedCargoList[goodName] ~= nil then
        if assignedCargo > self.maxCargoSpace then      --Something altered the cargoamount
            debugPrint(1, "more Cargo assigned than available: ", nil, assignedCargo, self.maxCargoSpace)
            if self.freeCargoSpace < (assignedCargoList[goodName] - self:getCargoAmount(goodName))* goodSize then
                return math.floor(self.freeCargoSpace/goodSize)
            else
                return assignedCargoList[goodName]
            end

        else
            return assignedCargoList[goodName]
        end
    else
        local unassignedCargospace = self.maxCargoSpace - assignedCargo
        local numUnassignedGoods = numBought + numSold + numIntermediate - numAssignedCargo

        if numUnassignedGoods > 0 then
            local spaceForEachUnassignedGood = unassignedCargospace / numUnassignedGoods
            return math.floor(spaceForEachUnassignedGood / goodSize)
        else
            debugPrint(0, "Could not find "..goodName.."in assigned and unassigned Cargo")
            return 0
        end
    end
end

function assignCargo(goodName, amount)                                                      --returns the assigned Cargo amount, never nil
    local self = Entity()
    if onClient() then
        invokeServerFunction("assignCargo", goodName, amount)
    end

    local good =  getGoodByName(goodName)
    if good == nil then
        debugPrint(0, "AssignGood failed to find", nil, goodName)
        return 0
    end
    local goodSize = good.size

    if amount == 0 or self.maxCargoSpace == nil then
        local ret = unassignCargo(goodName)
        if onServer() then
            debugPrint(3, "assignCargo on Server", nil, amount, ret)
        else
            debugPrint(3, "assignCargo on Client", nil, amount, ret)
        end
        return 0
    end

    if assignedCargoList[goodName] == nil then                                              --newly created assignment
        if assignedCargo > self.maxCargoSpace then
            return 0
        else
            local maxCargoToSpare = math.min(math.floor(self.maxCargoSpace-assignedCargo), amount * goodSize)
            assignedCargoList[goodName] = math.floor(maxCargoToSpare/goodSize)
            assignedCargo = assignedCargo + assignedCargoList[goodName] * goodSize
            numAssignedCargo = numAssignedCargo + 1
        end

    else                                                                                    --updating assignment
        assignedCargo = assignedCargo - assignedCargoList[goodName] * goodSize
        if assignedCargo > self.maxCargoSpace then
            assignedCargoList[goodName] = nil
            numAssignedCargo = numAssignedCargo - 1
            return 0
        else
            local maxCargoToSpare = math.min(math.floor(self.maxCargoSpace-assignedCargo), amount * goodSize)
            assignedCargoList[goodName] = math.floor(math.floor(maxCargoToSpare/goodSize))
            assignedCargo = assignedCargo + assignedCargoList[goodName] * goodSize
        end
    end
    if onClient() then
        debugPrint(3, "assignCargo on Client", nil, assignedCargoList[goodName])
    else
        debugPrint (3, "assignCargo on Server", nil, assignedCargoList[goodName])
    end
    return assignedCargoList[goodName]
end

function unassignCargo(goodName)
    debugPrint(3, "assigned Cargo", nil, assignedCargo)
    if assignedCargoList[goodName] == nil then
        return
    else
        local goodSize = getGoodByName(goodName).size
        numAssignedCargo = numAssignedCargo - 1
        assignedCargo = assignedCargo - assignedCargoList[goodName] * goodSize
        assignedCargoList[goodName] = nil
        return 0
    end
end

function getBoughtGoodByName(goodName)
    local good, index
    if boughtGoods[goodName] ~= nil then
        index, good = next(boughtGoods[goodName])
        if good == nil then debugPrint(0, "good not found in valid boughtGoods: ", nil, goodName) return end
    end
    return good, index
end

function getSoldGoodByName(goodName)
    local good, index
    if soldGoods[goodName] ~= nil then
        index, good = next(soldGoods[goodName])
        if good == nil then debugPrint(0, "good not found in valid soldGoods: ", nil, goodName) return end
    end
    return good, index
end

function getIntermediateGoodByName(goodName)
    local good, index
    if intermediateGoods[goodName] ~= nil then
        index, good = next(intermediateGoods[goodName])
        if good == nil then debugPrint(0, "good not found in valid intermediateGoods: ", nil, goodName) return end
    end
    return good, index
end

function getGoodByName(goodName)

    local index, good
    local hasBeenCalled = false

    local pGood, pIndex = getBoughtGoodByName(goodName)
    if pGood ~= nil then
        hasBeenCalled = true
        index, good = pIndex, pGood
    end

    local pGood, pIndex = getSoldGoodByName(goodName)
    if pGood ~= nil then
        if hasBeenDecreased then debugPrint(3, goodName.." has already been called in boughtGoods")end
        hasBeenCalled = true
        index, good = pIndex, pGood
    end

    local pGood, pIndex = getIntermediateGoodByName(goodName)
    if pGood ~= nil then
        if hasBeenDecreased then debugPrint(3, goodName.." has already been called in soldGoods")end
        hasBeenCalled = true
        index, good = pIndex, pGood
    end

    return good, index  -- is switched to stay compatible with tradingoverview.lua
end

-- price for which goods are bought by this from others
function getBuyPrice(goodName, sellingFaction)

    local good,_ = getBoughtGoodByName(goodName)
    if good == nil then return 0 end

    -- empty stock -> higher price
    local factor = getNumGoods(good.name) / getMaxStock(good.name) -- 0 to 1 where 1 is 'full stock'
    factor = 1 - factor -- 1 to 0 where 0 is 'full stock'
    factor = factor * 0.4 -- 0.4 to 0
    factor = factor + 0.8 -- 1.2 to 0.8; 'no goods' to 'full'

    local relationFactor = 1
    if sellingFaction then
        local sellerIndex = nil
        if type(sellingFaction) == "number" then
            sellerIndex = sellingFaction
        else
            sellerIndex = sellingFaction.index
        end

        if sellerIndex then
            local relations = Faction():getRelations(sellerIndex)

            if relations < -10000 then
                -- bad relations: faction pays less for the goods
                -- 10% to 100% from -100.000 to -10.000
                relationFactor = lerp(relations, -100000, -10000, 0.1, 1.0)
            elseif relations >= 50000 then
                -- very good relations: factions pays MORE for the goods
                -- 100% to 120% from 80.000 to 100.000
                relationFactor = lerp(relations, 80000, 100000, 1.0, 1.15)
            end

            if Faction().index == sellerIndex then relationFactor = 0 end
        end
    end

    return round(good.price * relationFactor * factor * buyPriceFactor)
end

-- price for which goods are sold from this to others
function getSellPrice(goodName, buyingFaction)

    local good, _ = getSoldGoodByName(goodName)
    if good == nil then return 0 end

    -- empty stock -> higher price
    local factor = getNumGoods(goodName) / getMaxStock(good.name) -- 0 to 1 where 1 is 'full stock'
    factor = 1 - factor -- 1 to 0 where 0 is 'full stock'
    factor = factor * 0.4 -- 0.4 to 0
    factor = factor + 0.8 -- 1.2 to 0.8; 'no goods' to 'full'


    local relationFactor = 1
    if buyingFaction then
        local sellerIndex = nil
        if type(buyingFaction) == "number" then
            sellerIndex = buyingFaction
        else
            sellerIndex = buyingFaction.index
        end

        if sellerIndex then
            local relations = Faction():getRelations(sellerIndex)

            if relations < -10000 then
                -- bad relations: faction wants more for the goods
                -- 200% to 100% from -100.000 to -10.000
                relationFactor = lerp(relations, -100000, -10000, 2.0, 1.0)
            elseif relations > 30000 then
                -- good relations: factions start giving player better prices
                -- 100% to 80% from 30.000 to 90.000
                relationFactor = lerp(relations, 30000, 90000, 1.0, 0.8)
            end

            if Faction().index == sellerIndex then relationFactor = 0 end
        end

    end

    return round(good.price * relationFactor * factor * sellPriceFactor)
end

function getRandomEntryFromTable(pTable, rand)
    local good, index
    local count = 1
    for name,data in pairs(pTable) do
        if count >= rand then
            index, good = next(data)
            break
        end
        count = count + 1
    end
    return good
end

local r = Random(Seed(os.time()))

local organizeUpdateFrequency
local organizeUpdateTime

local organizeDescription = [[
Organize ${amount} ${good.displayPlural} in 30 Minutes.

You will be paid the double of the usual price, plus a bonus.

Time Limit: 30 minutes
Reward: $${reward}
]]%_t

function updateOrganizeGoodsBulletins(timeStep)

    if not organizeUpdateFrequency then
        -- more frequent updates when there are more ingredients
        organizeUpdateFrequency = math.max(60 * 8, 60 * 60 - (numBought * 7.5 * 60))
    end

    if not organizeUpdateTime then
        -- by adding half the time here, we have a chance that a factory immediately has a bulletin
        organizeUpdateTime = 0

        local minutesSimulated = r:getInt(10, 80)
        for i = 1, minutesSimulated do -- simulate bulletin posting / removing
            updateOrganizeGoodsBulletins(60)
        end
    end

    organizeUpdateTime = organizeUpdateTime + timeStep

    -- don't execute the following code if the time hasn't exceeded the posting frequency
    if organizeUpdateTime < organizeUpdateFrequency then return end
    organizeUpdateTime = organizeUpdateTime - organizeUpdateFrequency

    -- choose a random ingredient
    local good = getRandomEntryFromTable(boughtGoods, r:getInt(1, numBought))
    if not good then return end

    local cargoVolume = 50 + r:getFloat(0, 200)
    local amount = math.min(math.floor(100 / good.size), 150)
    local reward = good.price * amount * 2.0 + 20000
    local x, y = Sector():getCoordinates()

    local bulletin =
    {
        brief = "Resource Shortage: ${amount} ${good.displayPlural}"%_T,
        description = organizeDescription,
        difficulty = "Easy"%_T,
        reward = string.format("$${reward}"%_T, createMonetaryString(reward)),
        script = "missions/organizegoods.lua",
        arguments = {good.name, amount, Entity().index, x, y, reward},
        formatArguments = {amount = amount, good = good, reward = createMonetaryString(reward)}
    }

    -- since in this case "add" can override "remove", adding a bulletin is slightly more probable
    local add = r:getFloat() < 0.5
    local remove = r:getFloat() < 0.5

    if not add and not remove then
        if r:getFloat() < 0.5 then
            add = true
        else
            remove = true
        end
    end

    if add then
        -- randomly add bulletins
        Entity():invokeFunction("bulletinboard", "postBulletin", bulletin)
    elseif remove then
        -- randomly remove bulletins
        Entity():invokeFunction("bulletinboard", "removeBulletin", bulletin.brief)
    end

end


local deliveryDescription = [[
Deliver ${amount} ${good.displayPlural} to a station near this location in 20 minutes.

You will have to make a deposit of $${deposit},
which will be reimbursed when the goods are delivered.

Deposit: $${deposit}
Time Limit: 20 minutes
Reward: $${reward}
]]%_t

local deliveryUpdateFrequency
local deliveryUpdateTime

function updateDeliveryBulletins(timeStep)

    if not deliveryUpdateFrequency then
        -- more frequent updates when there are more ingredients
        deliveryUpdateFrequency = math.max(60 * 8, 60 * 60 - (#soldGoods * 7.5 * 60))
    end

    if not deliveryUpdateTime then
        -- by adding half the time here, we have a chance that a factory immediately has a bulletin
        deliveryUpdateTime = 0

        local minutesSimulated = r:getInt(10, 80)
        for i = 1, minutesSimulated do -- simulate 1 hour of bulletin posting / removing
            updateDeliveryBulletins(60)
        end
    end

    deliveryUpdateTime = deliveryUpdateTime + timeStep

    -- don't execute the following code if the time hasn't exceeded the posting frequency
    if deliveryUpdateTime < deliveryUpdateFrequency then return end
    deliveryUpdateTime = deliveryUpdateTime - deliveryUpdateFrequency

    -- choose a sold good
    local good = getRandomEntryFromTable(soldGoods, r:getInt(1, numSold))
    if not good then return end

    local cargoVolume = 50 + r:getFloat(0, 200)
    local amount = math.min(math.floor(cargoVolume / good.size), 150)
    local reward = good.price * amount
    local x, y = Sector():getCoordinates()

    -- add a maximum of earnable money
    local maxEarnable = 20000 * Balancing_GetSectorRichnessFactor(x, y)
    if reward > maxEarnable then
        amount = math.floor(maxEarnable / good.price)
        reward = good.price * amount
    end

    if amount == 0 then return end

    reward = reward * 0.5 + 5000
    local deposit = math.floor(good.price * amount * 0.75 / 100) * 100
    local reward = math.floor(reward / 100) * 100

    -- todo: localization of entity titles
    local bulletin =
    {
        brief = "Delivery: ${good.displayPlural}"%_T,
        description = deliveryDescription,
        difficulty = "Easy"%_T,
        reward = string.format("$%s", createMonetaryString(reward)),
        formatArguments = {good = good, amount = amount, deposit = createMonetaryString(deposit), reward = createMonetaryString(reward)},

        script = "missions/delivery.lua",
        arguments = {good.name, amount, Entity().index, deposit + reward},

        checkAccept = [[
            local self, player = ...
            local ship = Entity(player.craftIndex)
            local space = ship.freeCargoSpace or 0
            if space < self.good.size * self.amount then
                player:sendChatMessage(self.sender, 1, self.msgCargo)
                return 0
            end
            if not Entity():isDocked(ship) then
                player:sendChatMessage(self.sender, 1, self.msgDock)
                return 0
            end
            local canPay = player:canPay(self.deposit)
            if not canPay then
                player:sendChatMessage(self.sender, 1, self.msgMoney)
                return 0
            end
            return 1
            ]],
        onAccept = [[
            local self, player = ...
            player:pay(self.deposit)
            local ship = Entity(player.craftIndex)
            ship:addCargo(goods[self.good.name]:good(), self.amount)
            ]],

        cargoVolume = cargoVolume,
        amount = amount,
        good = good,
        deposit = deposit,
        sender = "Client"%_T,
        msgCargo = "Not enough cargo space on your ship."%_T,
        msgDock = "You have to be docked to the station."%_T,
        msgMoney = "You don't have enough money for the deposit."%_T
    }

    -- since in this case "add" can override "remove", adding a bulletin is slightly more probable
    local add = r:getFloat() < 0.5
    local remove = r:getFloat() < 0.5

    if not add and not remove then
        if r:getFloat() < 0.5 then
            add = true
        else
            remove = true
        end
    end

    if add then
        -- randomly add bulletins
        Entity():invokeFunction("bulletinboard", "postBulletin", bulletin)
    elseif remove then
        -- randomly remove bulletins
        Entity():invokeFunction("bulletinboard", "removeBulletin", bulletin.brief)
    end

end

function toReadableNumber(number)
    local formatted = number
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k==0) then
            break
        end
    end
    return formatted
end
