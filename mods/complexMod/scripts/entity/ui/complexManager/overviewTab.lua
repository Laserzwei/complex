package.path = package.path .. ";data/scripts/lib/?.lua"
require ("utility")

CMSCRIPT = "mods/complexMod/scripts/entity/complexManager.lua"

VERSION = "[0.89] "
MOD = "[CPX3]"

DEBUGLEVEL = 2              -- is overwritten by DEBUGLEVEL in complexManager.lua 
--UI
local factoryList
local lastKnownSelected
local moveUpButton, MoveDownButton
local maxEnergyLabel, nametag, factorySizeSelector
local windowContainer
local scrollFrame
local split
local uiTrashLiast = {}
local changeSizeButton

--data
local indexedComplexData
local productionData
local upgradeMap = {}

function debugPrint(debuglvl, msg, tableToPrint, ...)
    if debuglvl <= DEBUGLEVEL then
        print(MOD..VERSION..msg, ...)
        if type(tableToPrint) == "table" then
            printTable(tableToPrint)
        end
    end
end

function createOverviewUI(tabWindow)
    windowContainer = tabWindow:createContainer(Rect(vec2(0, 0), tabWindow.size))
    local vsplit = UIVerticalSplitter(Rect(vec2(0, 0), windowContainer.size), 10, 10, 0.25)
    
    local left, right = vsplit.left, vsplit.right
    windowContainer:createFrame(left)
    --windowContainer:createFrame(right)
    
    --left
    local hsplit = UIHorizontalSplitter(left, 10, 10, 0.5)
    hsplit.bottomSize = 40
    
    factoryList = windowContainer:createListBox(hsplit.top)
    factoryList.visible = true
    factoryList.fontSize = 15
    factoryList:addEntry("Complex Overview")
    factoryList:setEntry(0, "Complex Overview", false, false, ColorRGB(0.9,0.5,0.0)) 
    
    local vmsplit = UIVerticalMultiSplitter(hsplit.bottom, 5, 3, 3)
    
    moveUpButton = windowContainer:createButton(vmsplit:partition(1), "↑", "onMoveUpPressed")
    moveUpButton.active = false
    moveDownButton = windowContainer:createButton(vmsplit:partition(2), "↓", "onMoveDownPressed")
    moveDownButton.active = false
    
    --right
    local hsplit = UIHorizontalSplitter(right, 0, 1, 0.05)
      
    nametag = windowContainer:createLabel(vec2(), "Complex Overview", 20)
    UIOrganizer(hsplit.top):placeElementCenter(nametag)
    
    scrollFrame = windowContainer:createScrollFrame(hsplit.bottom)
    scrollFrame.scrollSpeed = 25
    scrollFrame.paddingBottom = 10
    
    split = UIVerticalSplitter(hsplit.bottom, 10, 10, 0.5)
    
    --windowContainer:createFrame(split.left)
    --windowContainer:createFrame(split.right)
    
    maxEnergyLabel = scrollFrame:createLabel(vec2(), "", 18)
    maxEnergyLabel.visible = false
    factorySizeSelector = scrollFrame:createComboBox(Rect(), "onfactorySizeSelected") 
    factorySizeSelector.visible = false
end

function updateOT(timestep)
    if factoryList == nil then return end
    
    if factoryList.selected == -1 and factoryList.rows > 0 then
            factoryList:select(0)
    end
    if checkEntityInteractionPermissions(Entity(), unpack(mT.permissions[2].requiredPermissions)) then
        moveUpButton.tooltip = nil
        moveDownButton.tooltip = nil
        if changeSizeButton then
            changeSizeButton.active = true
            changeSizeButton.tooltip = nil
        end
        if factoryList.selected <= 1 then
            moveUpButton.active = false
        else
            moveUpButton.active = true
        end
        if factoryList.selected >= factoryList.size - 1 or factoryList.selected <= 0 then
            moveDownButton.active = false
        else
            moveDownButton.active = true
        end
    else
        moveUpButton.active = false
        moveUpButton.tooltip = "You need Alliance permission!"
        moveDownButton.active = false
        moveDownButton.tooltip = "You need Alliance permission!"
        if changeSizeButton then
            changeSizeButton.active = false
            changeSizeButton.tooltip = "You need Alliance permission!"
        end
    end
    if factoryList.selected ~= lastKnownSelected then
        lastKnownSelected = factoryList.selected
        updateOTListdataPanel()
    end
end

function updateOTFactoryList(pProductionData)
    if pProductionData ~= nil then 
        productionData = pProductionData
    else
        productionData = productionData or {}
    end
    if indexedComplexData == nil then return end
    if factoryList == nil then return end
    factoryList:clear()
    factoryList:addEntry("Complex Overview")
    factoryList:setEntry(0, "Complex Overview", false, false, ColorRGB(0.9,0.5,0.0))
    for index, data in pairs(indexedComplexData) do
        --factoryList:addEntry(data.name.."   "..data.factoryBlockId) -- TODO remove blockID
        factoryList:addEntry(data.name)
        debugPrint(3, "new Productiondata", nil, factoryList.size-1,data.name)
    end
    
    for index,data in pairs(indexedComplexData) do
        if index < factoryList.rows then
            local title = factoryList:getEntry(index)--data.name
            if productionData[index] == nil then            
                factoryList:setEntry(index, title, false, false, ColorRGB(0.8,0.0,0.0))
            else
                factoryList:setEntry(index, title, false, false, ColorRGB(0.0,0.8,0.0))
            end
        else
            debugPrint(3,"overextended reach in updateOTFactoryList", nil, index, factoryList.rows, data.name, data.factoryBlockId)
        end
    end

    if lastKnownSelected == nil then 
        factoryList:select(0)
        lastKnownSelected = 0
        return
    end
    if lastKnownSelected > factoryList.rows then
        factoryList:select(0)
        lastKnownSelected = 0
    else
        factoryList:select(lastKnownSelected)
    end
end

function updateOTListdataPanel()
    debugPrint(3,"Updating ListDataPanel" )
    if factoryList == nil then return end
    local selectedIndex = factoryList.selected
    if selectedIndex == nil or selectedIndex < 0 then return end          -- do special handling for selectedIndex == 0
    if indexedComplexData == nil then return end
    if indexedComplexData[selectedIndex] == nil and selectedIndex > 0 then return end
    --clearing old data
    for _,uiItem in pairs(uiTrashLiast) do
        uiItem.visible = false
        uiItem = nil
    end
    
    if selectedIndex == 0 then                                          --whole Complex
        local x,y = 5,15
        factorySizeSelector.visible = false
        maxEnergyLabel.visible = false 
        
        nametag.caption = "Complex Overview"
        local productions, consumption = {}, {}
        for index, data in pairs(indexedComplexData) do
            local production = data.factoryTyp
            local size = data.size or 2                                 --default back to 2 for S-size Factory
            for _,ingredient in pairs(production.ingredients) do
                if consumption[ingredient.name] then
                    consumption[ingredient.name] = consumption[ingredient.name] + ingredient.amount * size
                else
                    consumption[ingredient.name] = ingredient.amount * size
                end
            end
            for _,result in pairs(production.results) do
                if productions[result.name] then
                    productions[result.name] = productions[result.name] + result.amount * size
                else
                    productions[result.name] = result.amount * size
                end
            end
            for _,garbage in pairs(production.garbages) do
                if productions[garbage.name] then
                    productions[garbage.name] = productions[garbage.name] + garbage.amount * size
                else
                    productions[garbage.name] = garbage.amount * size
                end
            end
        end
        local lblSize = scrollFrame.size.x/2 - 50
        if next(consumption) then
            local pUI = scrollFrame:createLabel(vec2(x,y), "Consumption", 18)
            pUI.size = vec2(lblSize,pUI.size.y)
            table.insert(uiTrashLiast, pUI)
            y = y + 35
        end
        for name,amount in spairs(consumption) do
            nameT, amountT = name, amount
            
            local pUI = scrollFrame:createLabel(vec2(x, y), "", 14)
			local productionRatio = "No production!"
			if productions[name] and productions[name] > 0 then
				if productions[name] < amount then
					productionRatio = "- Missing goods: " .. amount - productions[name] .. "!"
                    pUI.color = ColorRGB(0.6, 0.0, 0.0)
				elseif productions[name] == amount then
                    productionRatio = ""
                    pUI.color = ColorRGB(0.0, 0.8, 0.0)
                else
					productionRatio = "- Overflow: " .. productions[name] - amount
                    pUI.color = ColorRGB(0.0, 0.5, 0.0)
				end
            end
            local ingredData = name%_t..": -"..amount.."/cycle " .. productionRatio
            pUI.caption = ingredData
            pUI.size = vec2(lblSize,pUI.size.y)
            table.insert(uiTrashLiast, pUI)
            y = y + 25
        end
        local x,y = scrollFrame.size.x/2 -10, 15
        if next(productions) then
            local pUI = scrollFrame:createLabel(vec2(x,y), "Production", 18)
            pUI.size = vec2(lblSize,pUI.size.y)
            scrollFrame:createFrame(pUI.rect)
            table.insert(uiTrashLiast, pUI)
            y = y + 35
        end
        for name,amount in spairs(productions, function(t,a,b) return t[b]["sorting"] < t[a]["sorting"] end) do
            local ingredData = name%_t..": "..amount.."/cycle"
            local pUI = scrollFrame:createLabel(vec2(x,y), ingredData, 14)
            pUI.size = vec2(lblSize,pUI.size.y)
            table.insert(uiTrashLiast, pUI)
            y = y + 25
        end
    else
        local x,y = 5,15
        local data = indexedComplexData[selectedIndex]
        if data == nil then debugPrint(2,"no data for Panel") return end
        local factoryBlockId = data.factoryBlockId
        local production = data.factoryTyp
        local name = data.name
        local size = data.size or 2
        local lblSize = scrollFrame.size.x/2 - 50
        
        nametag.caption = name
        
        if next(production.ingredients) then
            local pUI = scrollFrame:createLabel(vec2(x,y), "Consumption", 18)
            pUI.size = vec2(lblSize,pUI.size.y)
            table.insert(uiTrashLiast, pUI)
            y = y + 25
        end
        for _,ingredient in pairs(production.ingredients) do
            local ingredData = ingredient.name%_t..": -"..(ingredient.amount * size).."/cycle"
            local pUI = scrollFrame:createLabel(vec2(x, y), ingredData, 14)
            pUI.size = vec2(lblSize,pUI.size.y)
            table.insert(uiTrashLiast, pUI)
            y = y + 25
        end
        if next(production.results) then
            y = y + 10
            local pUI = scrollFrame:createLabel(vec2(x,y), "Production", 18)
            pUI.size = vec2(lblSize,pUI.size.y)
            table.insert(uiTrashLiast, pUI)
            y = y + 25
        end
        for _,result in pairs(production.results) do
            local ingredData = result.name%_t..": "..(result.amount * size).."/cycle"
            local pUI = scrollFrame:createLabel(vec2(x,y), ingredData, 14)
            pUI.size = vec2(lblSize,pUI.size.y)
            table.insert(uiTrashLiast, pUI)
            y = y + 25
        end
        if next(production.garbages) then
            y = y + 10
            local pUI = scrollFrame:createLabel(vec2(x,y), "Garbage", 18)
            pUI.size = vec2(lblSize,pUI.size.y)
            table.insert(uiTrashLiast, pUI)
            y = y + 25
        end
        for _,garbage in pairs(production.garbages) do
            local ingredData = garbage.name%_t..": "..(garbage.amount * size).."/cycle"
            local pUI = scrollFrame:createLabel(vec2(x,y), ingredData, 14)
            pUI.size = vec2(lblSize,pUI.size.y)
            table.insert(uiTrashLiast, pUI)
            y = y + 25
        end
        
        
        local x,y = scrollFrame.size.x/2 -10, 15
        
        maxEnergyLabel.visible = false
        maxEnergyLabel = nil

        local eSys = EnergySystem()
        debugPrint(4,"Energy", nil, toReadableValue(eSys.energy), 
        toReadableValue(eSys.capacity), 
        toReadableValue(eSys.productionRate), 
        toReadableValue(eSys.consumableEnergy), 
        toReadableValue(eSys.requiredEnergy), 
        toReadableValue(eSys.rechargeRate), 
        toReadableValue(eSys.superflousEnergy))
        local freeEnergy = eSys.productionRate - eSys.requiredEnergy
        local capText = tostring(toReadableValue(freeEnergy).. "W Free")
        if freeEnergy < 0 then 
            maxEnergyLabel = scrollFrame:createLabel(vec2(x,y), "Not enough Energy", 18)
            maxEnergyLabel.size = vec2(lblSize,maxEnergyLabel.size.y)
            maxEnergyLabel.color = ColorRGB(0.5, 0.0, 0.0)
        else
            maxEnergyLabel = scrollFrame:createLabel(vec2(x,y), capText, 18)
            maxEnergyLabel.size = vec2(lblSize,maxEnergyLabel.size.y)
            maxEnergyLabel.color = ColorRGB(0.0, 0.5, 0.0)
        end
        maxEnergyLabel.visible = true
        y = y + 35
        
        factorySizeSelector.visible = false
        factorySizeSelector:clear()
        --factorySizeSelector = scrollFrame:createComboBox(Rect(vec2(x,y), vec2(x+split.right.size.x, y+30)), "onfactorySizeSelected")   
        factorySizeSelector.upper = vec2(maxEnergyLabel.upper.x, maxEnergyLabel.lower.y + 30 + 35)
        factorySizeSelector.lower = vec2(maxEnergyLabel.lower.x, maxEnergyLabel.lower.y + 35)
        --factorySizeSelector.center = vec2(x,y)
        --factorySizeSelector.rect = Rect(vec2(x,y), vec2(x+split.right.size.x, y+30))
        factorySizeSelector.visible = true
        y = y + 50
        
        local pUI = scrollFrame:createLabel(vec2(x, y), "Energy required for Factory size:", 16)
        pUI.size = vec2(lblSize,pUI.size.y)
        table.insert(uiTrashLiast, pUI)
        y = y + 30
        local comboIndex = 0 
        for i = 2,10 do
            local fabECost, currentFabECost = getEnergycostForFactory(production, i), getEnergycostForFactory(production, size)
            local value, suffix = getReadableValue(math.abs( fabECost - currentFabECost))
            local text = ""
            if fabECost - currentFabECost < 0 then
                text = getFactoryClassBySize(i)..": +" ..value..suffix.."W"
            else
                text = getFactoryClassBySize(i)..": -" ..value..suffix.."W"
            end
            local pUI = scrollFrame:createLabel(vec2(x, y), text, 14)
            pUI.size = vec2(lblSize,pUI.size.y)
            if freeEnergy + currentFabECost - fabECost > 0 then
                if i ~= size then
                    local name = getFactoryClassBySize(i)
                    factorySizeSelector:addEntry(name)
                    table.insert(upgradeMap, comboIndex, i)
                    comboIndex = comboIndex + 1
                    if fabECost - currentFabECost < 0 then
                        pUI.color = ColorRGB(0.0, 0.7, 0.0)
                    else
                        pUI.color = ColorRGB(0.4, 0.0, 0.0)
                    end
                else
                    pUI.caption = "Current Class"
                    pUI.color = ColorRGB(0.0, 0.4, 0.0)
                end
            else
                if i ~= size then
                    pUI.color = ColorRGB(0.6, 0.0, 0.0)
                else
                    pUI.caption = "Current Class"
                    pUI.color = ColorRGB(0.0, 0.4, 0.0)
                end
                
            end
            y = y + 25
            
            table.insert(uiTrashLiast, pUI)
        end
        y = y + 5
        changeSizeButton = scrollFrame:createButton(Rect(vec2(x,y), vec2(x+120, y +25)), "set size", "onSizeSet")
        table.insert(uiTrashLiast, changeSizeButton)
    end
end

function updateOTComplexData(pIndexedComplexData)
    indexedComplexData = pIndexedComplexData
    updateOTListdataPanel()
    updateOTFactoryList()
end

function onMoveUpPressed()
    if factoryList == nil then return end
    local selected = factoryList.selected
    if selected == -1 then return end
    --if factoryList.selected == 0 then moveUpButton.active = false return end
    local selectedEntry = {factoryList:getEntry(selected)}
    local aboveEntry = {factoryList:getEntry(selected - 1)}
    local selectedFactoryData, aboveFactoryData = indexedComplexData[selected], indexedComplexData[selected - 1]
    factoryList:setEntry(selected - 1, unpack(selectedEntry))
    factoryList:setEntry(selected, unpack(aboveEntry))
    
    
    indexedComplexData[selected - 1] = selectedFactoryData
    indexedComplexData[selected] = aboveFactoryData
    
    local selProdData, aboveProdData = productionData[selected], productionData[selected - 1]
    productionData[selected] = aboveProdData
    productionData[selected - 1] = selProdData
    
    
    factoryList:select(selected - 1)
    lastKnownSelected = lastKnownSelected - 1
    local status, data = Entity():invokeFunction(CMSCRIPT,"synchComplexdata",indexedComplexData)
end

function onMoveDownPressed()
    if factoryList == nil then return end
    local selected = factoryList.selected
    if factoryList.selected == -1 then return end
    --if factoryList.selected >= factoryList.size - 1 then moveDownButton.active = false return end
    local selectedEntry = {factoryList:getEntry(selected)}
    local belowEntry = {factoryList:getEntry(selected + 1)}
    local selectedFactoryData, belowFactoryData = indexedComplexData[selected], indexedComplexData[selected + 1]
    factoryList:setEntry(selected + 1, unpack(selectedEntry))
    factoryList:setEntry(selected, unpack(belowEntry))
    
    indexedComplexData[selected + 1] = selectedFactoryData
    indexedComplexData[selected] = belowFactoryData
    
    local selProdData, belowProdData = productionData[selected], productionData[selected + 1]
    productionData[selected] = belowProdData
    productionData[selected + 1] = selProdData
    
    factoryList:select(selected + 1)
    lastKnownSelected = lastKnownSelected + 1
    local status, data = Entity():invokeFunction(CMSCRIPT,"synchComplexdata", indexedComplexData)
end

function onfactorySizeSelected()
    
end

function onSizeSet()
    debugPrint(3,"change Energy consumption to:", nil, factorySizeSelector.selectedIndex)
    if factoryList == nil then return end
    if factoryList.selected == nil then return end
    if factoryList.selected < 1 then return end
    
    --check for Energy
    local index = factoryList.selected
    
    local data = indexedComplexData[index]
    local size = upgradeMap[factorySizeSelector.selectedIndex] or 0
    debugPrint(4, "pre size ", nil, factorySizeSelector.selectedIndex, size)
    local energyConsumption, currentEnergyUsage = getEnergycostForFactory(data.factoryTyp, size), getEnergycostForFactory(data.factoryTyp, data.size)
    if energyConsumption - currentEnergyUsage > EnergySystem().productionRate - EnergySystem().requiredEnergy then
        debugPrint(0, "Energyconsumption too big:", nil, energyConsumption - EnergySystem().productionRate - EnergySystem().requiredEnergy)
        return
    end
    
    data.size = size
    if size == 2 then
        local status = Entity():invokeFunction(CMSCRIPT, "removeBonus", data.factoryBlockId)
        Entity():removeBonus(data.factoryBlockId)
    else
        Entity():addKeyedMultiplyableBias(StatsBonuses.GeneratedEnergy, data.factoryBlockId, -energyConsumption)
        local status = Entity():invokeFunction(CMSCRIPT, "addStatBonus", data.factoryBlockId, "GeneratedEnergy", -energyConsumption)
    end
    local name, args = formatFactoryName(data.factoryTyp, data.size - 1)
    name = string.gsub(name, "${good}", tostring(args.good))
    name = string.gsub(name, "${size}", getFactoryClassBySize(data.size))
    data.name = name
    indexedComplexData[index] = data
    
    
    local status, data = Entity():invokeFunction(CMSCRIPT, "synchSingleComplexdata", index,data)
    updateOTFactoryList()
    updateOTListdataPanel()
end

function tRN(number)
    number = tonumber(number)
    if number == nil then return 0 end
    number = math.floor(number*100)/100     --keep last 2 digit
    local formatted = number
    while true do  
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k==0) then
            break
        end
    end
    return formatted
end

function getFactoryClassBySize(factorySize)
    local size = ""
    if factorySize == 2 then size =      "Class II"
    elseif factorySize == 3 then size =  "Class III"
    elseif factorySize == 4 then size =  "Class IV"
    elseif factorySize == 5 then size =  "Class V"
    elseif factorySize == 6 then size =  "Class VI"
    elseif factorySize == 7 then size =  "Class VII"
    elseif factorySize == 8 then size =  "Class VIII"
    elseif factorySize == 9 then size =  "Class IX"
    elseif factorySize == 10 then size = "Class X"
    else debugPrint(1, "got wrong size: H ".. tostring(factorySize))
    end
    return size
end


function getEnergycostForFactory(production, size)
    if size > 10 or size < 0 then return -1 end
    if size <=2 then return 0 end
    local factorycost = getFactoryCost(production)
    local base = 2500
    
    local energyConsumption = math.floor(factorycost * base * (1 + 1/(11 - size)) * (size-1))
    return energyConsumption
end

function getFactoryCost(production)

    -- calculate the difference between the value of ingredients and results
    local ingredientValue = 0
    local resultValue = 0

    for _, ingredient in pairs(production.ingredients) do
        local good = goods[ingredient.name]
        ingredientValue = ingredientValue + good.price * ingredient.amount
    end

    for _, result in pairs(production.results) do
        local good = goods[result.name]
        resultValue = resultValue + good.price * result.amount
    end

    local diff = resultValue - ingredientValue

    local costs = 3000000 -- 3 mio minimum for a factory
    costs = costs + diff * 4500
    return costs
end



function spairs(t)  --Hammelpilaw
    -- collect the keys
    local keys = {}
    for k in pairs(t) do
		keys[#keys+1] = k
	end

	table.sort(keys, compare)
    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

function compare(a,b)--Hammelpilaw
  return a%_t < b%_t
end