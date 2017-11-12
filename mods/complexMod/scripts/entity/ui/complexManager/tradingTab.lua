package.path = package.path .. ";data/scripts/lib/?.lua"
require ("utility")
require ("goods")

--complex Good-Management Menu
--Top
local soldGoodsListbox, intermediateGoodsListbox, boughtGoodsListbox
local soldGoodsListboxList, intermediateGoodsListboxList, boughtGoodsListboxList = {}, {}, {}
local soldToIntermediateButton, soldToBoughtButton
local intermediateToSoldButton, intermediateToBoughtButton
local boughtToIntermediateButton, boughtToSoldbutton
local goodListsSelected = {}
goodListsSelected.soldGoodsListbox = -1
goodListsSelected.intermediateGoodsListbox = -1
goodListsSelected.boughtGoodsListbox = -1
local goodSelected = nil
--Middle
local assignedCargoLabel
local currentGoodCargoLabel, currentGoodTextBox, currentGoodAcceptButton, currentGoodCargoLabelMin
--Bottom
local goodsOverviewsListBoxEx

--data
local tradingdata

function createTradingUI(tabWindow)
    local container = tabWindow:createContainer(Rect(vec2(0, 0), tabWindow.size))

    local hsplit = UIHorizontalSplitter(Rect(vec2(0, 0), container.size), 10, 10, 0.4)
    local vsplitList = {hsplit.top.size.x*0.26, hsplit.top.size.x*0.37, hsplit.top.size.x*0.63, hsplit.top.size.x*0.74}     --partition(0) gets 26%, partition(1) 11% partition(2) 26% ...
    local vlsplits = UIArbitraryVerticalSplitter(hsplit.top, 5, 5, unpack(vsplitList))

    soldGoodsListbox = container:createListBox(vlsplits:partition(0))
    local label = container:createLabel(vec2(vlsplits:partition(0).lower.x,vlsplits:partition(0).lower.y - 20), "Sold Goods" ,14)
    local lister = UIVerticalLister(vlsplits:partition(1), 10, 10)

    intermediateToSoldButton = container:createButton(Rect(),"<", "onIntermediateToSold")
    intermediateToSoldButton.active = false
    lister:placeElementCenter(intermediateToSoldButton)

    soldToIntermediateButton = container:createButton(Rect(),">", "onSoldToIntermediate")
    soldToIntermediateButton.active = false
    lister:placeElementCenter(soldToIntermediateButton)

    soldToBoughtButton = container:createButton(Rect(),">>", "onSoldToBought")
    soldToBoughtButton.active = false
    lister:placeElementCenter(soldToBoughtButton)

    intermediateGoodsListbox = container:createListBox(vlsplits:partition(2))
    local label = container:createLabel(vec2(vlsplits:partition(2).lower.x,vlsplits:partition(2).lower.y - 20), "Intermediate Goods" ,14)

    local lister = UIVerticalLister(vlsplits:partition(3), 10, 10)

    intermediateToBoughtButton = container:createButton(Rect(),">", "onIntermediateToBought")
    intermediateToBoughtButton.active = false
    lister:placeElementCenter(intermediateToBoughtButton)

    boughtToIntermediateButton = container:createButton(Rect(),"<", "onBoughtToIntermediate")
    boughtToIntermediateButton.active = false
    lister:placeElementCenter(boughtToIntermediateButton)

    boughtToSoldbutton = container:createButton(Rect(),"<<", "onBoughtToSold")
    boughtToSoldbutton.active = false
    lister:placeElementCenter(boughtToSoldbutton)

    boughtGoodsListbox = container:createListBox(vlsplits:partition(4))
    local label = container:createLabel(vec2(vlsplits:partition(4).lower.x,vlsplits:partition(4).lower.y - 20), "Bought Goods" ,14)


    local hsplit2 = UIHorizontalSplitter(hsplit.bottom, 0, 0, 0.25)
    local x, y = vlsplits:partition(0).lower.x, hsplit2.top.lower.y + 10

    assignedCargoLabel = container:createLabel(vec2(x,y), "Assignable Cargo: "..tostring("0") ,18)
    y = y + 35

    currentGoodCargoLabel = container:createLabel(vec2(x,y),"Select a Good from above", 18)
    y = y + 35

    local textboxSize = 200
    local assignButtonSize = 120
    local unAssignButtonSize = 120

    local rect = Rect(x, y, x + textboxSize, y+35)
    currentGoodTextBox = container:createTextBox(rect, "onAssignAmountChanged")
    currentGoodTextBox.text = "0"
    currentGoodTextBox.allowedCharacters = "0123456789"
    currentGoodTextBox.clearOnClick = 0
    x = x + textboxSize + 4

    rect = Rect(x, y, x + assignButtonSize, y+35)
    currentGoodAcceptButton = container:createButton(rect, "assign", "onCargoAssigned")
    x = x + assignButtonSize + 4

    rect = Rect(x, y, x + unAssignButtonSize, y+35)
    currentGoodAcceptButton = container:createButton(rect, "unassign", "onCargoUnAssigned")
    x = x + unAssignButtonSize + 4

    currentGoodCargoLabelMin = container:createLabel(vec2(x,y+5), "Min/Max: 0/0",18)

    goodsOverviewsListBoxEx = container:createListBoxEx(hsplit2.bottom )
    goodsOverviewsListBoxEx.columns = 6
    goodsOverviewsListBoxEx:addRow("Good", "Stock", "Max. Stock", "Size", "Cargospace", "CurrentPrice")

    container:createFrame(hsplit2.bottom)
end

function deactivateAllListButtons()
    soldToIntermediateButton.active = false
    soldToIntermediateButton.tooltip = "You need Alliance permission!"
    soldToBoughtButton.active = false
    soldToBoughtButton.tooltip = "You need Alliance permission!"
    intermediateToSoldButton.active = false
    intermediateToSoldButton.tooltip = "You need Alliance permission!"
    intermediateToBoughtButton.active = false
    intermediateToBoughtButton.tooltip = "You need Alliance permission!"
    boughtToIntermediateButton.active = false
    boughtToIntermediateButton.tooltip = "You need Alliance permission!"
    boughtToSoldbutton.active = false
    boughtToSoldbutton.tooltip = "You need Alliance permission!"
end

function removeTooltips()
    soldToIntermediateButton.tooltip = nil
    soldToBoughtButton.tooltip = nil
    intermediateToSoldButton.tooltip = nil
    intermediateToBoughtButton.tooltip = nil
    boughtToIntermediateButton.tooltip = nil
    boughtToSoldbutton.tooltip = nil
end

function updateTT(timeStep)                                               --checking if selection in the List has changed
    if soldGoodsListbox == nil then return end
    if boughtGoodsListbox == nil then return end
    if intermediateGoodsListbox == nil then return end
    if checkEntityInteractionPermissions(Entity(), unpack(mT.permissions[3].requiredPermissions)) then
        currentGoodAcceptButton.active = true
        currentGoodAcceptButton.tooltip = nil
        removeTooltips()
    else
        currentGoodAcceptButton.active = false
        currentGoodAcceptButton.tooltip = "You need Alliance permission!"
        deactivateAllListButtons()
        return
    end

    if goodListsSelected.soldGoodsListbox ~= soldGoodsListbox.selected then

        soldToIntermediateButton.active = true
        soldToBoughtButton.active = true
        intermediateToSoldButton.active = false
        intermediateToBoughtButton.active = false
        boughtToIntermediateButton.active = false
        boughtToSoldbutton.active = false


        intermediateGoodsListbox:deselect()
        boughtGoodsListbox:deselect()

        goodListsSelected.soldGoodsListbox = soldGoodsListbox.selected
        goodListsSelected.intermediateGoodsListbox = -1
        goodListsSelected.boughtGoodsListbox = -1
        goodSelected = nil
        updateCargoassignment()
    end
    if goodListsSelected.intermediateGoodsListbox ~= intermediateGoodsListbox.selected then

        soldToIntermediateButton.active = false
        soldToBoughtButton.active = false
        intermediateToSoldButton.active = true
        intermediateToBoughtButton.active = true
        boughtToIntermediateButton.active = false
        boughtToSoldbutton.active = false

        soldGoodsListbox:deselect()
        boughtGoodsListbox:deselect()

        goodListsSelected.soldGoodsListbox = -1
        goodListsSelected.intermediateGoodsListbox = intermediateGoodsListbox.selected
        goodListsSelected.boughtGoodsListbox = -1
        goodSelected = nil
        updateCargoassignment()
    end
    if goodListsSelected.boughtGoodsListbox ~= boughtGoodsListbox.selected then

        soldToIntermediateButton.active = false
        soldToBoughtButton.active = false
        intermediateToSoldButton.active = false
        intermediateToBoughtButton.active = false
        boughtToIntermediateButton.active = true
        boughtToSoldbutton.active = true

        soldGoodsListbox:deselect()
        intermediateGoodsListbox:deselect()

        goodListsSelected.soldGoodsListbox = -1
        goodListsSelected.intermediateGoodsListbox = -1
        goodListsSelected.boughtGoodsListbox = boughtGoodsListbox.selected
        goodSelected = nil
        updateCargoassignment()
    end
end

function updateTradingdata(pTradingdata)
    debugPrint(3, "updateTradingdata")
    tradingdata = pTradingdata or (tradingdata or {})
    if next(tradingdata) == nil then return end
    local numBought = 0
    local boughtGoods = {}
    for name, pair in pairs(tradingdata.boughtGoods) do
        local index, good = next(pair)
        boughtGoods[name] = {[index] = tableToGood(good)}
        numBought = numBought + 1
    end
    tradingdata.boughtGoods = boughtGoods
    tradingdata.numBought = numBought

    local numSold = 0
    local soldGoods = {}
    for name, pair in pairs(tradingdata.soldGoods) do
        local index, good = next(pair)
        soldGoods[name] = {[index] = tableToGood(good)}
        numSold = numSold + 1
    end
    tradingdata.soldGoods = soldGoods
    tradingdata.numSold = numSold

    local numIntermediate = 0
    local intermediateGoods = {}
    for name, pair in pairs(tradingdata.intermediateGoods) do
        local index, good = next(pair)
        intermediateGoods[name] = {[index] = tableToGood(good)}
        numIntermediate = numIntermediate + 1
    end
    tradingdata.intermediateGoods = intermediateGoods
    tradingdata.numIntermediate = numIntermediate

    updateTradingLists()
    updateGoodsOverview()
    updateCargoassignment()
end

function updateTradingLists()
    if soldGoodsListbox == nil then return end
    if tradingdata == nil then return end
    local sel = soldGoodsListbox.selected
    soldGoodsListbox:clear()
    soldGoodsListboxList = {}
    local i = 0
    for name,_ in spairs(tradingdata.soldGoods) do
        soldGoodsListboxList[i] = name
        if tradingdata.assignedCargoList[name] then name = name.."*" end
        soldGoodsListbox:addEntry(name)
        i = i + 1
    end
    if sel then soldGoodsListbox:select(sel) end
    sel = intermediateGoodsListbox.selected
    intermediateGoodsListbox:clear()
    intermediateGoodsListboxList = {}
    local i = 0
    for name,_ in spairs(tradingdata.intermediateGoods) do
        intermediateGoodsListboxList[i] = name
        if tradingdata.assignedCargoList[name] then name = name.."*" end
        intermediateGoodsListbox:addEntry(name)
        i = i + 1
    end
    if sel then intermediateGoodsListbox:select(sel) end
    sel = boughtGoodsListbox.selected
    boughtGoodsListbox:clear()
    boughtGoodsListboxList = {}
    local i = 0
    for name,_ in spairs(tradingdata.boughtGoods) do
        boughtGoodsListboxList[i] = name
        if tradingdata.assignedCargoList[name] then name = name.."*" end
        boughtGoodsListbox:addEntry(name)
        i = i + 1
    end
    if sel then boughtGoodsListbox:select(sel) end
end

function updateCargoassignment()
    local assignedCargo = 0
    for i,amount in pairs(tradingdata.assignedCargoList) do
        assignedCargo = assignedCargo + (amount * goods[i].size)
    end
    local freeCargo = Entity().maxCargoSpace - assignedCargo
    if soldGoodsListbox.selected >= 0 then
        local selected = soldGoodsListbox.selected
        goodSelected = soldGoodsListboxList[selected]
        local _, good = next(tradingdata.soldGoods[goodSelected])
        local back,maxStock = Entity():invokeFunction(CFSCRIPT, "pGetMaxStock", goodSelected)
        assignedCargoLabel.caption = "Unassigned Cargo: ".. tRN(math.floor(freeCargo/good.size))
        currentGoodCargoLabel.caption = goodSelected.." change from "..tRN(maxStock).." to: "
        currentGoodCargoLabelMin.caption = "Min/Max: "..tRN(Entity():getCargoAmount(goodSelected)).."/"..tRN(math.floor(freeCargo/good.size))
    end
    if intermediateGoodsListbox.selected >= 0 then
        local selected = intermediateGoodsListbox.selected
        goodSelected = intermediateGoodsListboxList[selected]
        local _, good = next(tradingdata.intermediateGoods[goodSelected])
        local back,maxStock = Entity():invokeFunction(CFSCRIPT, "pGetMaxStock", goodSelected)
        assignedCargoLabel.caption = "Unassigned Cargo: ".. tRN(math.floor(freeCargo/good.size))
        currentGoodCargoLabel.caption = goodSelected.." change from "..tRN(maxStock).." to: "
        currentGoodCargoLabelMin.caption = "Min/Max: "..tRN(Entity():getCargoAmount(goodSelected)).."/"..tRN(math.floor(freeCargo/good.size))
    end
    if boughtGoodsListbox.selected >= 0 then
        local selected = boughtGoodsListbox.selected
        goodSelected = boughtGoodsListboxList[selected]
        local _, good = next(tradingdata.boughtGoods[goodSelected])
        local back,maxStock = Entity():invokeFunction(CFSCRIPT, "pGetMaxStock", goodSelected)
        assignedCargoLabel.caption = "Unassigned Cargo: ".. tRN(math.floor(freeCargo/good.size))
        currentGoodCargoLabel.caption = goodSelected.." change from "..tRN(maxStock).." to: "
        currentGoodCargoLabelMin.caption = "Min/Max: "..tRN(Entity():getCargoAmount(goodSelected)).."/"..tRN(math.floor(freeCargo/good.size))
    end
end

function updateGoodsOverview()
    if goodsOverviewsListBoxEx == nil then return end
    if tradingdata == nil then return end
    goodsOverviewsListBoxEx:clear()
    goodsOverviewsListBoxEx:addRow("Good", "Stock", "Max. Stock", "Size", "Cargospace", "CurrentPrice")
    local rows = {}
    for name, pair in pairs(tradingdata.soldGoods) do
        local _,good = next(pair)
        local stock, size = Entity():getCargoAmount(name), good.size
        local status, maxStock = Entity():invokeFunction(CFSCRIPT, "pGetMaxStock", name)
        local factor = stock / maxStock -- 0 to 1 where 1 is 'full stock'
        factor = 1 - factor -- 1 to 0 where 0 is 'full stock'
        factor = factor * 0.4 -- 0.4 to 0
        factor = factor + 0.8 -- 1.2 to 0.8; 'no goods' to 'full'
        rows[name%_t] = {tRN(stock), tRN(maxStock), tRN(size), tRN(maxStock*size), createMonetaryString(round(good.price * factor))}
    end
    for name, pair in pairs(tradingdata.intermediateGoods) do
        local _,good = next(pair)
        local stock, size = Entity():getCargoAmount(name), good.size
        local status, maxStock = Entity():invokeFunction(CFSCRIPT, "pGetMaxStock", name)
        rows[name%_t] = {tRN(stock), tRN(maxStock), tRN(size) , tRN(maxStock*size), createMonetaryString(round(good.price, 2))}
    end
    for name, pair in pairs(tradingdata.boughtGoods) do
        local _,good = next(pair)
        local stock, size = Entity():getCargoAmount(name), good.size
        local status, maxStock = Entity():invokeFunction(CFSCRIPT, "pGetMaxStock", name)
        local factor = stock / maxStock
        factor = 1 - factor
        factor = factor * 0.4
        factor = factor + 0.8
        rows[name%_t] = {tRN(stock), tRN(maxStock), tRN(size) , tRN(maxStock*size), createMonetaryString(round(good.price * factor))}
    end

    for name, data in spairs(rows) do
        goodsOverviewsListBoxEx:addRow(name, unpack(data))
    end
end

function onIntermediateToSold()
    if goodSelected == nil then return end
    local boughtGoods, soldGoods, intermediateGoods = tradingdata.boughtGoods, tradingdata.soldGoods, tradingdata.intermediateGoods
    local numBought, numSold, numIntermediate = tradingdata.numBought, tradingdata.numSold, tradingdata.numIntermediate
    local list = {}

    local index, good = next(intermediateGoods[goodSelected])

    for name,pair in pairs(intermediateGoods) do
        local i, g = next(pair)
        if i > index then
            intermediateGoods[name] = {[i-1] = g}
        end
    end
    intermediateGoods[goodSelected] = nil
    numIntermediate = numIntermediate - 1

    numSold = numSold + 1
    soldGoods[good.name] = {[numSold] = good}

    list.boughtGoods = boughtGoods
    list.numBought = numBought
    list.soldGoods = soldGoods
    list.numSold = numSold
    list.intermediateGoods = intermediateGoods
    list.numIntermediate = numIntermediate
    local status = Entity():invokeFunction(CFSCRIPT, "setTradingLists", list)
    updateTradingdata()
end

function onSoldToIntermediate()
    if goodSelected == nil then return end
    local boughtGoods, soldGoods, intermediateGoods = tradingdata.boughtGoods, tradingdata.soldGoods, tradingdata.intermediateGoods
    local numBought, numSold, numIntermediate = tradingdata.numBought, tradingdata.numSold, tradingdata.numIntermediate
    local list = {}

    local index, good = next(soldGoods[goodSelected])

    for name,pair in pairs(soldGoods) do
        local i, g = next(pair)
        if i > index then
            soldGoods[name] = {[i-1] = g}
        end
    end
    soldGoods[goodSelected] = nil
    numSold = numSold - 1

    numIntermediate = numIntermediate + 1
    intermediateGoods[good.name] = {[numIntermediate] = good}

    list.boughtGoods = boughtGoods
    list.numBought = numBought
    list.soldGoods = soldGoods
    list.numSold = numSold
    list.intermediateGoods = intermediateGoods
    list.numIntermediate = numIntermediate
    local status = Entity():invokeFunction(CFSCRIPT, "setTradingLists", list)
    updateTradingdata()
end

function onSoldToBought()
    if goodSelected == nil then return end
    local boughtGoods, soldGoods, intermediateGoods = tradingdata.boughtGoods, tradingdata.soldGoods, tradingdata.intermediateGoods
    local numBought, numSold, numIntermediate = tradingdata.numBought, tradingdata.numSold, tradingdata.numIntermediate
    local list = {}

    local index, good = next(soldGoods[goodSelected])

    for name,pair in pairs(soldGoods) do
        local i, g = next(pair)
        if i > index then
            soldGoods[name] = {[i-1] = g}
        end
    end
    soldGoods[goodSelected] = nil
    numSold = numSold - 1

    numBought = numBought + 1
    boughtGoods[good.name] = {[numBought] = good}

    list.boughtGoods = boughtGoods
    list.numBought = numBought
    list.soldGoods = soldGoods
    list.numSold = numSold
    list.intermediateGoods = intermediateGoods
    list.numIntermediate = numIntermediate
    local status = Entity():invokeFunction(CFSCRIPT, "setTradingLists", list)
    updateTradingdata()
end

function onIntermediateToBought()
    if goodSelected == nil then return end
    local boughtGoods, soldGoods, intermediateGoods = tradingdata.boughtGoods, tradingdata.soldGoods, tradingdata.intermediateGoods
    local numBought, numSold, numIntermediate = tradingdata.numBought, tradingdata.numSold, tradingdata.numIntermediate
    local list = {}

    local index, good = next(intermediateGoods[goodSelected])

    for name,pair in pairs(intermediateGoods) do
        local i, g = next(pair)
        if i > index then
            intermediateGoods[name] = {[i-1] = g}
        end
    end
    intermediateGoods[goodSelected] = nil
    numIntermediate = numIntermediate - 1

    numBought = numBought + 1
    boughtGoods[good.name] = {[numBought] = good}

    list.boughtGoods = boughtGoods
    list.numBought = numBought
    list.soldGoods = soldGoods
    list.numSold = numSold
    list.intermediateGoods = intermediateGoods
    list.numIntermediate = numIntermediate
    local status = Entity():invokeFunction(CFSCRIPT, "setTradingLists", list)
    updateTradingdata()
end

function onBoughtToIntermediate()
    if goodSelected == nil then return end
    local boughtGoods, soldGoods, intermediateGoods = tradingdata.boughtGoods, tradingdata.soldGoods, tradingdata.intermediateGoods
    local numBought, numSold, numIntermediate = tradingdata.numBought, tradingdata.numSold, tradingdata.numIntermediate
    local list = {}
    local index, good = next(boughtGoods[goodSelected])

    for name,pair in pairs(boughtGoods) do
        local i, g = next(pair)
        if i > index then
            boughtGoods[name] = {[i-1] = g}
        end
    end
    boughtGoods[goodSelected] = nil
    numBought = numBought - 1

    numIntermediate = numIntermediate + 1
    intermediateGoods[good.name] = {[numIntermediate] = good}

    list.boughtGoods = boughtGoods
    list.numBought = numBought
    list.soldGoods = soldGoods
    list.numSold = numSold
    list.intermediateGoods = intermediateGoods
    list.numIntermediate = numIntermediate
    local status = Entity():invokeFunction(CFSCRIPT, "setTradingLists", list)
    updateTradingdata()
end

function onBoughtToSold()
    if goodSelected == nil then return end
    local boughtGoods, soldGoods, intermediateGoods = tradingdata.boughtGoods, tradingdata.soldGoods, tradingdata.intermediateGoods
    local numBought, numSold, numIntermediate = tradingdata.numBought, tradingdata.numSold, tradingdata.numIntermediate
    local list = {}

    local index, good = next(boughtGoods[goodSelected])

    for name,pair in pairs(boughtGoods) do
        local i, g = next(pair)
        if i > index then
            boughtGoods[name] = {[i-1] = g}
        end
    end
    boughtGoods[goodSelected] = nil
    numBought = numBought - 1

    numSold = numSold + 1
    soldGoods[good.name] = {[numSold] = good}

    list.boughtGoods = boughtGoods
    list.numBought = numBought
    list.soldGoods = soldGoods
    list.numSold = numSold
    list.intermediateGoods = intermediateGoods
    list.numIntermediate = numIntermediate
    local status = Entity():invokeFunction(CFSCRIPT, "setTradingLists", list)
    updateTradingdata()
end

function onAssignAmountChanged()
    if goodSelected == nil then return end
    local self = Entity()
    local enteredNumber = tonumber(currentGoodTextBox.text)
    if enteredNumber == nil then
        enteredNumber = 0
    end
    currentGoodTextBox.text = tostring(enteredNumber)
end

function onCargoAssigned()
    debugPrint(3, "onCargoAssigned", nil, goodSelected)
    if goodSelected == nil then return end
    local enteredNumber = tonumber(currentGoodTextBox.text)
    if enteredNumber == nil then
        enteredNumber = 0
    end

    local _, good = next(tradingdata.soldGoods[goodSelected] or {})
    if good == nil then
        _, good = next(tradingdata.boughtGoods[goodSelected]or {})
        if good == nil then
        _, good = next(tradingdata.intermediateGoods[goodSelected]or {})
            if good == nil then
                currentGoodTextBox.text = tostring(0)
                return
            end
        end
    end
    debugPrint(4, "good", nil, good.name)
    local m = Entity():getCargoAmount(goodSelected)
    if enteredNumber < m then
        enteredNumber = m
    end
    local status, assignedamt = Entity():invokeFunction(CFSCRIPT, "passChangeInStockLimit", goodSelected, enteredNumber)
    debugPrint(3, "onCargoAssigned", nil, goodSelected, status, assignedamt)
    tradingdata.assignedCargoList[goodSelected] = assignedamt
    currentGoodTextBox.text = tostring(assignedamt)
    updateTradingdata()
    updateCargoassignment()
end

function onCargoUnAssigned()
    if goodSelected == nil then return end
    local status = Entity():invokeFunction(CFSCRIPT, "unassignCargo", goodSelected)
    tradingdata.assignedCargoList[goodSelected] = nil
    updateTradingdata()
    updateCargoassignment()
end
