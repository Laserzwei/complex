package.path = package.path .. ";data/scripts/lib/?.lua"
require ("utility")

FSCRIPT = "data/scripts/entity/merchants/factory.lua"
CMSCRIPT = "mods/complexMod/scripts/entity/complexManager.lua"

VERSION = "[0.89] "
MOD = "[CPX3]"

DEBUGLEVEL = 2
-- Complex building menu items
local dirButtonXP, dirButtonYP, dirButtonZP
local dirButtonXM, dirButtonYM, dirButtonZM

local advancedCheckbox
local sliderX
local sliderY
local sliderZ
local numberBoxX, numberBoxXValue = 0
local numberBoxY, numberBoxYValue = 0
local numberBoxZ, numberBoxZValue = 0

local stationCombo
local stationComboIndexList = {}
local directionToAdd = 2             -- 0:X+, 1:X-, 2:Y+, 3:Y-, 4:Z+, 5:Z-

local buttonNodeXP, buttonNodeYP, buttonNodeZP
local buttonNodeXM, buttonNodeYM, buttonNodeZM

local constructionButton
local refreshButton

local planDisplayer

--Complex Blockplans
local addedPlan
local preview

--Complex Data
local complexData = {}
local currentNodeIndex
local currentNodeOffset = vec3(0,0,0)
local targetCoreBlockIndex
local targetCoreBlockCoord
local constructionData = {}     --{[buildorder] = {[BlockID]= {["position"] = {x,y,z}, ["size"] = {x,y,z}, ["rootID"] = rootID}}}

local UIinititalised = false

function debugPrint(debuglvl, msg, tableToPrint, ...)
    if debuglvl <= DEBUGLEVEL then
        print(MOD..VERSION..msg, ...)
        if type(tableToPrint) == "table" then
            printTable(tableToPrint)
        end
    end
end

function createConstructionUI(tabWindow)
    local container = tabWindow:createContainer(Rect(vec2(0, 0), tabWindow.size));

    local vsplit = UIVerticalSplitter(Rect(vec2(0, 0), container.size), 10, 10, 0.25)

    local left = vsplit.left
    local right = vsplit.right

    container:createFrame(left);
    container:createFrame(right);

    local lister = UIVerticalLister(left, 10, 10)
    local l = container:createLabel(vec2(), "Select Station"%_t, 14);
    l.size = vec2(0, 0)
    lister.padding = 0
    lister:placeElementCenter(l)
    lister.padding = 10

    stationCombo = container:createComboBox(Rect(),"onStationComboSelect")
    --updateStationCombo()
    lister:placeElementCenter(stationCombo)
    lister.padding = 5

    --creating Station offset Buttons
    local l = container:createLabel(vec2(), "Move Station Offset"%_t, 14);
    l.size = vec2(0, 0)
    lister.padding = 0
    lister:placeElementCenter(l)
    lister.padding = 5

    local rect = lister:placeCenter(vec2(vsplit.left.width - 20, 30))
    local vmsplit = UIVerticalMultiSplitter(rect, 5, 3, 2)
    dirButtonXP = container:createButton(vmsplit:partition(0), "X+", "onSetOffsetXP");
    dirButtonYP = container:createButton(vmsplit:partition(1), "Y+", "onSetOffsetYP");
    dirButtonZP = container:createButton(vmsplit:partition(2), "Z+", "onSetOffsetZP");
    lister.padding = 5
    rect = lister:placeCenter(vec2(vsplit.left.width - 20, 30))
    local vmsplit2 = UIVerticalMultiSplitter(rect, 5, 3, 2)
    dirButtonXM = container:createButton(vmsplit2:partition(0), "X-", "onSetOffsetXM");
    dirButtonYM = container:createButton(vmsplit2:partition(1), "Y-", "onSetOffsetYM");
    dirButtonZM = container:createButton(vmsplit2:partition(2), "Z-", "onSetOffsetZM");
    lister.padding = 10
    setDirButtonsActive()

    -- create advanced check boxes
    advancedCheckbox = container:createCheckBox(Rect(), "Advanced Building Opotions"%_t, "onAdvancedChecked")
    lister:placeElementCenter(advancedCheckbox)
    lister.padding = 20

    --advanced Slider and Numberbox for X-Axis
    rect = lister:placeCenter(vec2(vsplit.left.width - 20, 30))
    local sliderSplit = UIVerticalSplitter(rect, 5, 0, 0.7)
    sliderX = container:createSlider(sliderSplit.left, -100, 100, 200, "X"%_t, "updatePlan")
    sliderX.value = 0;
    sliderX.visible = false
    sliderX.segments = 40

    numberBoxX = container:createTextBox(sliderSplit.right, "onNumberfieldEnteredX")
    numberBoxX.text = "0"
    numberBoxX.allowedCharacters = "-0123456789"
    numberBoxX.clearOnClick = 1
    numberBoxX.visible = false

    --advanced Slider and Numberbox for Y-Axis
    rect = lister:placeCenter(vec2(vsplit.left.width - 20, 30))
    local sliderSplit = UIVerticalSplitter(rect, 5, 0, 0.7)
    sliderY = container:createSlider(sliderSplit.left, -100, 100, 200, "Y"%_t, "updatePlan")
    sliderY.value = 0;
    sliderY.visible = false
    sliderY.segments = 40

    numberBoxY = container:createTextBox(sliderSplit.right, "onNumberfieldEnteredY")
    numberBoxY.text = "0"
    numberBoxY.allowedCharacters = "-0123456789"
    numberBoxY.clearOnClick = 1
    numberBoxY.visible = false

    --advanced Slider and Numberbox for Z-Axis
    rect = lister:placeCenter(vec2(vsplit.left.width - 20, 30))
    local sliderSplit = UIVerticalSplitter(rect, 5, 0, 0.7)
    sliderZ = container:createSlider(sliderSplit.left, -100, 100, 200, "Z"%_t, "updatePlan")
    sliderZ.value = 0;
    sliderZ.visible = false
    sliderZ.segments = 40

    numberBoxZ = container:createTextBox(sliderSplit.right, "onNumberfieldEnteredZ")
    numberBoxZ.text = "0"
    numberBoxZ.allowedCharacters = "-0123456789"
    numberBoxZ.clearOnClick = 1
    numberBoxZ.visible = false

    lister.padding = 10
    --creating Node offset Buttons
    local l = container:createLabel(vec2(), "Move to Node Offset"%_t, 14)
    l.size = vec2(0, 0)
    lister.padding = 0
    lister:placeElementCenter(l)
    lister.padding = 5
    local rect = lister:placeCenter(vec2(vsplit.left.width - 20, 30))
    local vmsplit = UIVerticalMultiSplitter(rect, 5, 3, 2)
    buttonNodeXP = container:createButton(vmsplit:partition(0), "X+", "onSetNodeOffsetXP")
    buttonNodeXP.active = false
    buttonNodeYP = container:createButton(vmsplit:partition(1), "Y+", "onSetNodeOffsetYP")
    buttonNodeYP.active = false
    buttonNodeZP = container:createButton(vmsplit:partition(2), "Z+", "onSetNodeOffsetZP")
    buttonNodeZP.active = false
    lister.padding = 5
    rect = lister:placeCenter(vec2(vsplit.left.width - 20, 30))
    local vmsplit2 = UIVerticalMultiSplitter(rect, 5, 3, 2)
    buttonNodeXM = container:createButton(vmsplit2:partition(0), "X-", "onSetNodeOffsetXM")
    buttonNodeXM.active = false
    buttonNodeYM = container:createButton(vmsplit2:partition(1), "Y-", "onSetNodeOffsetYM")
    buttonNodeYM.active = false
    buttonNodeZM = container:createButton(vmsplit2:partition(2), "Z-", "onSetNodeOffsetZM")
    buttonNodeZM.active = false
    setNodeButtonsActive()
    lister.padding = 10

    refreshButton = container:createButton(Rect(), "Refresh", "onRefreshPressed")
    lister:placeElementCenter(refreshButton)

    -- button at the bottom
    constructionButton = container:createButton(Rect(), "Build"%_t, "onConstructionButtonPress");
    local organizer = UIOrganizer(left)
    organizer.padding = 10
    organizer.margin = 10
    organizer:placeElementBottom(constructionButton)

    -- create the viewer
    planDisplayer = container:createPlanDisplayer(vsplit.right);
    planDisplayer.showStats = 0
    planDisplayer.autoCenter = 0
    planDisplayer.center = vec3(0,0,0)


    advancedCheckbox.checked = true
    --onAdvancedChecked()
    UIinititalised = true
end

function onRefreshPressed()
    updateStationCombo()
    updatePlan()
end

function updateCT(timestep)
    if Entity():getValue("complexChanged") and Entity():getPlan():getBlock(currentNodeIndex) then     --just because Entities get asynchronously changed and thus can't be used event driven.
        Entity():setValue("complexChanged", nil)
        if UIinititalised then
            updateStationCombo()
            updatePlan()
        end
    end
end

function updateComplexdataCT(pIndexedComplexdata)
    if onServer() then debugPrint(0,"updateComplexdataCT onServer not allowed !") end
    complexData = applyIndexedToComplexdata(pIndexedComplexdata)
    if UIinititalised == false then return end
    updateStationCombo()
    setNodeButtonsActive()
    updatePlan()
    debugPrint(3, "ComplexData =========", complexData)
end

function applyIndexedToComplexdata(pIndexedComplexData)
    local list = {}
    for _,data in pairs(pIndexedComplexData) do
        local t = {
        ["relativeCoords"] = data.relativeCoords,
        ["factoryTyp"] = data.factoryTyp,
        ["nodeOffset"] = data.nodeOffset,
        ["size"] = data.size,
        ["name"] = data.name}
        list[data.factoryBlockId] = t
    end
    return list
end

function cTRenderUI()
    local offset = 10
    if currentNodeIndex and complexData[currentNodeIndex] then
        local name = complexData[currentNodeIndex].name
        drawText(name, planDisplayer.lower.x + 10, planDisplayer.lower.y + offset, ColorRGB(1, 1, 1), 15, 0, 0, 2)
        offset = offset + 25
    end
    if addedPlan == nil then return end
        local planMoney = addedPlan:getMoneyValue()
        local planResources = {addedPlan:getResourceValue()}

        offset = offset + renderPrices(planDisplayer.lower + vec2(10, offset), "Construction Costs"%_t, planMoney, planResources)
end

function updatePlan()
    -- just to make sure that the interface is completely created, this function is called during initialization of the GUI, and not everything may be constructed yet
    if planDisplayer == nil then return end
    if stationCombo == nil then return  end
    if stationComboIndexList == nil then return end
    if sliderX == nil then return end
    if sliderY == nil then return end
    if sliderZ == nil then return end
    if directionToAdd == nil then return end
    if stationComboIndexList[stationCombo.selectedIndex + 1] == nil then
        constructionButton.active = false
        entityPlan = Entity():getPlan()
        planDisplayer.plan = entityPlan
        if currentNodeOffset == nil then currentNodeOffset = vec3(0,0,0) end
        currentNodeIndex = getNodeIDFromNodeOffset(currentNodeOffset) or entityPlan.rootIndex
        if complexData[currentNodeIndex] ~= nil then
            planDisplayer.center = complexData[currentNodeIndex].relativeCoords
        else
            planDisplayer.center = vec3(0,0,0)
        end
        return
    end
    if numberBoxX == nil then return end
    if numberBoxY == nil then return end
    if numberBoxZ == nil then return end

    if currentNodeOffset == nil then currentNodeOffset = vec3(0,0,0) end

    if not Sector():getEntity(stationComboIndexList[stationCombo.selectedIndex + 1]) then
        debugPrint(3, "Entity doesn't exist", nil, stationCombo.selectedIndex + 1, stationComboIndexList[stationCombo.selectedIndex + 1].string)
        updateStationCombo()
        return
    end

    local timer = Timer()
    local totalTimer = Timer()
    timer:start()
    totalTimer:start()

    local newPlan = Entity():getPlan()

    currentNodeIndex = getNodeIDFromNodeOffset(currentNodeOffset) or newPlan.rootIndex
    debugPrint(3,"update ", nil, currentNodeIndex)
    if complexData[currentNodeIndex] == nil then
        debugPrint(3, "complexData nil on Complex", nil, Entity().index)
        currentNodeIndex = newPlan.rootIndex
        currentNodeOffset = vec3(0,0,0)
        targetCoreBlockIndex = nil
        targetCoreBlockCoord = vec3(0,0,0)
    end

    addedPlan = BlockPlan()
    local addedStationPlan = Entity(stationComboIndexList[stationCombo.selectedIndex + 1]):getPlan()
    if complexData == nil or next(complexData) == nil then                          --inititalizing Complexdata
        local status , factoryData = Entity():invokeFunction(FSCRIPT, "secure", nil)
        if status ~= 0 then debugPrint(0, "Could not find Factory.lua on Station.", status, Entity().name, Entity().index.string)return end
        local name, args = formatFactoryName(factoryData.production, factoryData.maxNumProductions - 1)
        name = string.gsub(name, "${good}", tostring(args.good))
        name = string.gsub(name, "${size}", "S")
        local data = {["name"] = name, ["relativeCoords"] = vec3(0,0,0), ["nodeOffset"] = vec3(0,0,0), ["factoryTyp"] = factoryData.production, ["size"] = factoryData.maxNumProductions}
        complexData[newPlan.rootIndex] = data
    end

    constructionData[0] = {["targetID"] = stationComboIndexList[stationCombo.selectedIndex + 1]}

    local mainBB, addedBB = newPlan:getBoundingBox(), addedStationPlan:getBoundingBox()
    local xAdd, yAdd, zAdd = sliderX.value + (numberBoxXValue or 0), sliderY.value + (numberBoxYValue or 0), sliderZ.value + (numberBoxZValue or 0)
    local x, y, z = xAdd, yAdd, zAdd

    local nodeCoords = complexData[currentNodeIndex].relativeCoords
    if nodeCoords == nil then
        debugPrint(3,"nodeCoords nil ")
        invokeServerFunction("removeMissingFactories")
        return
    end

    if directionToAdd == 0 then -- X+
        x = mainBB.upper.x - nodeCoords.x - addedBB.lower.x + xAdd
    end
    if directionToAdd == 1 then -- X-
        x = mainBB.lower.x - nodeCoords.x - addedBB.upper.x + xAdd
    end
    if directionToAdd == 2 then -- Y+
        y = mainBB.upper.y - nodeCoords.y - addedBB.lower.y + yAdd
    end
    if directionToAdd == 3 then -- Y-
        y = mainBB.lower.y - nodeCoords.y - addedBB.upper.y + yAdd
    end
    if directionToAdd == 4 then -- Z+
        z = mainBB.upper.z - nodeCoords.z - addedBB.lower.z + zAdd
    end
    if directionToAdd == 5 then -- Z-
        z = mainBB.lower.z - nodeCoords.z - addedBB.upper.z + zAdd
    end

    debugPrint(3,"Needed ".. timer.microseconds/1000 .."ms for preparation")
    timer:restart()

    local sizeVec3
    local posVec3
    --prevent z fighting, overlapping and visually loose connections
    if y < 0 then
        sizeVec3 = vec3(2,-y,2)
        posVec3 = vec3(0,(y/2)-0.5,0)
    else
        sizeVec3 = vec3(2,y+2,2)
        posVec3 = vec3(0,(y/2)+0,0)
    end
    posVec3 = posVec3 + nodeCoords
    if not newPlan:getBlock(currentNodeIndex) then
        timer:stop()
        totalTimer:stop()
        debugPrint(3,"not cool man", nil, currentNodeIndex)
        return
    end
    local connectorY = newPlan:addBlock(posVec3, sizeVec3, currentNodeIndex, -1, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)
    addedPlan:addBlock(posVec3, sizeVec3, addedPlan.rootIndex, -1, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)                      --For price calculation
    constructionData[1] = {["BlockID"] = connectorY,["position"] = vec3ToTable(posVec3), ["size"] = vec3ToTable(sizeVec3), ["rootID"] = currentNodeIndex}
    if x < 0 then
        sizeVec3 = vec3(-x-2,2,2)
    else
        sizeVec3 = vec3(x-2,2,2)
    end
    posVec3 = vec3(x/2,y,0) + nodeCoords
    local connectorX = newPlan:addBlock(posVec3, sizeVec3, connectorY, -1, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)
    addedPlan:addBlock(posVec3, sizeVec3, addedPlan.rootIndex, -1, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)                      --For price calculation
    constructionData[2] = {["BlockID"] = connectorX,["position"] = vec3ToTable(posVec3), ["size"] = vec3ToTable(sizeVec3), ["rootID"] = connectorY}
    if z < 0 then
        if x == 0 then
            sizeVec3 = vec3(2,2,-z-2)
        else
            sizeVec3 = vec3(2,2,-z+2)
        end
    else
        if x == 0 then
            sizeVec3 = vec3(2,2,z-2)
        else
            sizeVec3 = vec3(2,2,z+2)
        end
    end
    posVec3 = vec3(x,y,z/2) + nodeCoords
    local connectorZ = newPlan:addBlock(posVec3, sizeVec3, connectorX, -1, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)
    addedPlan:addBlock(posVec3, sizeVec3, addedPlan.rootIndex, -1, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)                      --For price calculation
    constructionData[3] = {["BlockID"] = connectorZ,["position"] = vec3ToTable(posVec3), ["size"] = vec3ToTable(sizeVec3), ["rootID"] = connectorX}

    targetCoreBlockCoord = vec3(x,y,z) + nodeCoords
    targetCoreBlockIndex = newPlan:addBlock(targetCoreBlockCoord, vec3(5,5,5), connectorZ, -1, ColorRGB(0.5, 0.0, 0.0), Material(MaterialType.Trinium) , Matrix(), BlockType.Armor)
    addedPlan:addBlock(targetCoreBlockCoord, vec3(5,5,5), addedPlan.rootIndex, -1, ColorRGB(0.5, 0.0, 0.0), Material(MaterialType.Trinium) , Matrix(), BlockType.Armor)                   --For price calculation
    constructionData[4] = {["BlockID"] = targetCoreBlockIndex,["position"] = vec3ToTable(targetCoreBlockCoord), ["size"] = vec3ToTable(vec3(5,5,5)), ["rootID"] = connectorZ}

    debugPrint(3, "Needed ".. timer.microseconds/1000 .."ms until merge")
    timer:restart()

    newPlan:addPlanDisplaced(targetCoreBlockIndex, addedStationPlan, addedStationPlan.rootIndex,targetCoreBlockCoord)

    debugPrint(3,"Needed ".. timer.microseconds/1000 .."ms for addPlanDisplaced")
    timer:restart()

    -- set to display
    --preview = newPlan
    planDisplayer.plan = newPlan

    debugPrint(3, "Needed ".. timer.microseconds/1000 .."ms for Plandisplayer set plan")
    timer:restart()

    setDirButtonsActive()
    planDisplayer.center = complexData[currentNodeIndex].relativeCoords

    debugPrint(3, "Needed ".. timer.microseconds/1000 .."ms for Plandisplayer center")
    timer:restart()

    setDirButtonsActive()
    if  (directionToAdd == 0 and getNodeIDFromNodeOffset((currentNodeOffset + vec3(1,0,0)))) or             --Trying to add the Complex on the existing Node in X+
        (directionToAdd == 1 and getNodeIDFromNodeOffset((currentNodeOffset + vec3(-1,0,0)))) or            --Trying to add the Complex on the existing Node in X-
        (directionToAdd == 2 and getNodeIDFromNodeOffset((currentNodeOffset + vec3(0,1,0)))) or             --...
        (directionToAdd == 3 and getNodeIDFromNodeOffset((currentNodeOffset + vec3(0,-1,0)))) or
        (directionToAdd == 4 and getNodeIDFromNodeOffset((currentNodeOffset + vec3(0,0,1)))) or
        (directionToAdd == 5 and getNodeIDFromNodeOffset((currentNodeOffset + vec3(0,0,-1))))               --Trying to add the Complex on the existing Node in Z-
    then
        constructionButton.active = false
    else
        constructionButton.active = true
    end

    if not checkEntityInteractionPermissions(Entity(), unpack(mT.permissions[1].requiredPermissions)) then
        constructionButton.active = false
        constructionButton.tooltip = "You need Alliance permission!"
    else
        if  constructionButton.active then
            constructionButton.active = true
        end
        constructionButton.tooltip = nil
    end
    debugPrint(3, "Needed ".. timer.microseconds/1000 .."ms for construction of total ".. totalTimer.microseconds/1000 .."ms")
    timer:stop()
    totalTimer:stop()
end

function updateStationCombo()
    local stationsInSector = {Sector():getEntitiesByType(EntityType.Station)}
    local wantedStations = {}
    local enindex = Entity().index
    local index = 1
    local playerHasAlliance
    if Player().allianceIndex then
        playerHasAlliance = true
    else
        playerHasAlliance = false
    end
    stationCombo:clear()
    stationComboIndexList = {}
    for _, station in pairs(stationsInSector) do
        if station.index ~= enindex and station:hasScript("data/scripts/entity/merchants/factory.lua") then
            if checkEntityInteractionPermissions(station, unpack(mT.permissions[1].requiredPermissions)) then
                local status , factoryData = station:invokeFunction(FSCRIPT, "secure", nil)
                if next(factoryData.production) then
                    local name, args = formatFactoryName(factoryData.production, factoryData.maxNumProductions - 1)
                    name = string.gsub(name, "${good}", tostring(args.good))
                    name = string.gsub(name, "${size}", getFactoryClassBySize(factoryData.maxNumProductions))
                    debugPrint(3,"combolist entries ", nil, index, name)
                    stationComboIndexList[index] = station.index
                    stationCombo:addEntry(name)
                    index = index + 1
                end
            end
        end
    end
    updatePlan()
end

function getNodeSuccessor(dir, searchVector)
    if not currentNodeOffset then return nil end
    local smallestDistance = math.huge
    local biggestDistance = 0
    local smallestIndex = nil
    local plan = Entity():getPlan()
    for nodeID,data in pairs(complexData) do
        --debugPrint(4, "|"..tostring(data.nodeOffset), nil, tostring((currentNodeOffset + searchVector)))
        if vec3Equal(data.nodeOffset,(currentNodeOffset + searchVector)) then
            --debugPrint(4, "Selected1: "..tostring(data.nodeOffset))
            --debugPrint(4, "=================================")
            return nodeID
        end
        if searchVector[dir] == 1 then
            if data.nodeOffset[dir] >= (currentNodeOffset[dir] + searchVector[dir]) then
                local dist = getDistBetweenVectors(data.nodeOffset,(currentNodeOffset + searchVector))
                if dist < smallestDistance then
                    smallestDistance = dist
                    smallestIndex = nodeID
                    --debugPrint(4, "pre"..tostring(data.nodeOffset) .. " dist: " .. dist)
                end
            else  end
        end
        if searchVector[dir] == -1 then
            if data.nodeOffset[dir] <= (currentNodeOffset[dir] + searchVector[dir]) then
                local dist = getDistBetweenVectors(data.nodeOffset,(currentNodeOffset + searchVector))
                if dist < biggestDistance then
                    biggestDistance = dist
                    smallestIndex = nodeID
                    --debugPrint(4, "pre"..tostring(data.nodeOffset) .. " dist: " .. dist)
                end
            else  end
        end
    end
    if smallestIndex ~= nil then
        --debugPrint(4, "Selected: "..tostring(complexData[smallestIndex].nodeOffset))
    end
    --debugPrint(4, "=================================")
    return smallestIndex
end

function vec3Equal(vecIn1,vecIn2)
    if vecIn1 == nil or vecIn2 == nil then return false end
    return (vecIn1.x == vecIn2.x and vecIn1.y == vecIn2.y and vecIn1.z == vecIn2.z)
end

function getDistBetweenVectors(vector1, vector2)
    local vec = vector1 - vector2
    return math.sqrt(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z)
end

function getIndexById(orderedList, id)
    for ind,factoryId in pairs(orderedList) do
        if factoryId == id then
            return ind
        end
    end
    return nil

end

function getNodeIDFromNodeOffset(offset)
    local plan = Entity():getPlan()
    local nodeIndex
    for nodeID,data in pairs(complexData) do
        if vec3Equal(data.nodeOffset, offset)then
            nodeIndex = nodeID
        end
    end
    if complexData[plan.rootIndex] == nil and nodeIndex ~= nil and vec3Equal(vec3(0,0,0), offset) then
        complexData[plan.rootIndex] = complexData[nodeIndex]
        complexData[nodeIndex] = nil
        nodeindex = plan.rootIndex
    end
    return nodeIndex
end

function isNodeInComplexData(nodeOffset)
    for nodeID,data in pairs(complexData) do
        if vec3Equal(data.nodeOffset,nodeOffset) then
            return true
        end
    end
    return false
end

function findDirectional(searchVector)
     if not currentNodeOffset then return end
     local nextIndex = nil
     for nodeID,data in pairs(complexData) do
        if vec3Equal(data.nodeOffset, (currentNodeOffset + searchVector)) then
            nextIndex = nodeID
            break
        end
     end
     return nextIndex
end

function setDirButtonsActive()
    if findDirectional(vec3(1,0,0))  then dirButtonXP.active = false else dirButtonXP.active = true end
    if findDirectional(vec3(-1,0,0)) then dirButtonXM.active = false else dirButtonXM.active = true end
    if findDirectional(vec3(0,1,0))  then dirButtonYP.active = false else dirButtonYP.active = true end
    if findDirectional(vec3(0,-1,0)) then dirButtonYM.active = false else dirButtonYM.active = true end
    if findDirectional(vec3(0,0,1))  then dirButtonZP.active = false else dirButtonZP.active = true end
    if findDirectional(vec3(0,0,-1)) then dirButtonZM.active = false else dirButtonZM.active = true end
end

function setNodeButtonsActive()
    local hasCurrentNode = isNodeInComplexData(currentNodeOffset)
    if hasCurrentNode == false then
        currentNodeIndex, data = next(complexData)
        if currentNodeIndex == nil or data == nil then return end
        currentNodeOffset = data.nodeOffset
        if currentNodeOffset == nil then
            currentNodeOffset = vec3(0,0,0)
            synchComplexdata(nil, nil, true)
            debugPrint(0, "The current Node got messed up. resetting: "..tostring(currentNodeOffset))
        end
    end
    if not getNodeSuccessor("x", vec3(1,0,0)) then buttonNodeXP.active = false else buttonNodeXP.active = true end
    if not getNodeSuccessor("y", vec3(0,1,0)) then buttonNodeYP.active = false else buttonNodeYP.active = true end
    if not getNodeSuccessor("z", vec3(0,0,1)) then buttonNodeZP.active = false else buttonNodeZP.active = true end
    if not getNodeSuccessor("x", vec3(-1,0,0)) then buttonNodeXM.active = false else buttonNodeXM.active = true end
    if not getNodeSuccessor("y", vec3(0,-1,0)) then buttonNodeYM.active = false else buttonNodeYM.active = true end
    if not getNodeSuccessor("z", vec3(0,0,-1)) then buttonNodeZM.active = false else buttonNodeZM.active = true end

end

function onSetOffsetXP()
    directionToAdd = 0
    updatePlan();
end

function onSetOffsetXM()
    directionToAdd = 1
    updatePlan();
end

function onSetOffsetYP()
    directionToAdd = 2
    updatePlan();
end

function onSetOffsetYM()
    directionToAdd = 3
    updatePlan();
end

function onSetOffsetZP()
    directionToAdd = 4
    updatePlan();
end

function onSetOffsetZM()
    directionToAdd = 5
    updatePlan();
end


function onSetNodeOffsetXP()
    currentNodeIndex = getNodeSuccessor("x", vec3(1,0,0))
    currentNodeOffset = complexData[currentNodeIndex].nodeOffset
    setNodeButtonsActive()
    updatePlan();
end

function onSetNodeOffsetXM()
    currentNodeIndex = getNodeSuccessor("x", vec3(-1,0,0))
    currentNodeOffset = complexData[currentNodeIndex].nodeOffset
    setNodeButtonsActive()
    updatePlan();
end

function onSetNodeOffsetYP()
    currentNodeIndex = getNodeSuccessor("y", vec3(0,1,0))
    currentNodeOffset = complexData[currentNodeIndex].nodeOffset
    setNodeButtonsActive()
    updatePlan();
end

function onSetNodeOffsetYM()
    currentNodeIndex = getNodeSuccessor("y", vec3(0,-1,0))
    currentNodeOffset = complexData[currentNodeIndex].nodeOffset
    setNodeButtonsActive()
    updatePlan();
end

function onSetNodeOffsetZP()
    currentNodeIndex = getNodeSuccessor("z",vec3(0,0,1))
    currentNodeOffset = complexData[currentNodeIndex].nodeOffset
    setNodeButtonsActive()
    updatePlan();
end

function onSetNodeOffsetZM()
    currentNodeIndex = getNodeSuccessor("z", vec3(0,0,-1))
    currentNodeOffset = complexData[currentNodeIndex].nodeOffset
    setNodeButtonsActive()
    updatePlan();
end

function onAdvancedChecked()
    if advancedCheckbox.checked then
        sliderX.visible = true
        sliderY.visible = true
        sliderZ.visible = true

        numberBoxX.visible = true
        numberBoxY.visible = true
        numberBoxZ.visible = true
    else
        -- reset Sliders
        sliderX.visible = false
        sliderX.value = 0
        sliderY.visible = false
        sliderY.value = 0
        sliderZ.visible = false
        sliderZ.value = 0
        --reset numberboxes
        numberBoxX.visible = false
        numberBoxX.text = "0"
        numberBoxXValue = 0
        numberBoxY.visible = false
        numberBoxY.text = "0"
        numberBoxYValue = 0
        numberBoxZ.visible = false
        numberBoxZ.text = "0"
        numberBoxZValue = 0
    end
    updatePlan();
end

function onNumberfieldEnteredX()
    local value = tonumber(numberBoxX.text)
    if value then
        sliderX.value = 0
        numberBoxXValue = value
    else
        --numberBoxX.text = "0"
    end
    updatePlan();
end

function onNumberfieldEnteredY()
    local value = tonumber(numberBoxY.text)
    if value then
        sliderY.value = 0
        numberBoxYValue = value
    else
        --numberBoxY.text = "0"
    end
    updatePlan();
end

function onNumberfieldEnteredZ()
    local value = tonumber(numberBoxZ.text)
    if value then
        sliderZ.value = 0
        numberBoxZValue = value
    else
        --numberBoxZ.text = "0"
    end
    updatePlan();
end

function onStationComboSelect()
    updatePlan();
end

function onConstructionButtonPress()
    if not checkEntityInteractionPermissions(Entity(), unpack(mT.permissions[1].requiredPermissions)) then
        constructionButton.active = false
        constructionButton.tooltip = "You need Alliance permission!"
        return
    end
    local status , factoryData = Entity(stationComboIndexList[stationCombo.selectedIndex + 1]):invokeFunction(FSCRIPT, "secure", nil)
    local name, args = formatFactoryName(factoryData.production, factoryData.maxNumProductions - 1)
    name = string.gsub(name, "${good}", tostring(args.good))
    name = string.gsub(name, "${size}", getFactoryClassBySize(factoryData.maxNumProductions))
    local nodeOffset
    if directionToAdd == 0 then nodeOffset = vec3(1,0,0) + currentNodeOffset end
    if directionToAdd == 1 then nodeOffset = vec3(-1,0,0) + currentNodeOffset end
    if directionToAdd == 2 then nodeOffset = vec3(0,1,0) + currentNodeOffset end
    if directionToAdd == 3 then nodeOffset = vec3(0,-1,0) + currentNodeOffset end
    if directionToAdd == 4 then nodeOffset = vec3(0,0,1) + currentNodeOffset end
    if directionToAdd == 5 then nodeOffset = vec3(0,0,-1) + currentNodeOffset end
    currentNodeOffset = nodeOffset
    currentNodeIndex = targetCoreBlockIndex
    local data = {["name"] = name, ["relativeCoords"] = targetCoreBlockCoord, ["nodeOffset"] = nodeOffset, ["factoryTyp"] = factoryData.production, ["size"] = factoryData.maxNumProductions}
    local root = Entity():getPlan().rootIndex
    debugPrint(3, "roottable", complexData, root, targetCoreBlockIndex)
    local basefab = {   ["name"] = complexData[root].name,
                        ["relativeCoords"] = complexData[root].relativeCoords,
                        ["nodeOffset"] = complexData[root].nodeOffset,
                        ["factoryTyp"] = complexData[root].factoryTyp,
                        ["size"] = complexData[root].size,
                        ["factoryBlockId"] = root}

    complexData[targetCoreBlockIndex] = data
    data.factoryBlockId = targetCoreBlockIndex

    local count = 0
    for _,_ in pairs(complexData) do
        count = count + 1
    end
    if count > 2 then
        local status, data = Entity():invokeFunction(CMSCRIPT,"cmOnConstructionButtonPress",constructionData, addedPlan, data)
    else --initializing
        local status, data = Entity():invokeFunction(CMSCRIPT,"cmOnConstructionButtonPress",constructionData, addedPlan, data, basefab)
    end
    debugPrint(3,"build pressed", nil, currentNodeIndex)
    EntityIcon().icon = "data/textures/icons/pixel/crate.png"
    constructionButton.active = false                                                                       --Locking The construction Button to prevent inconsistent data. Gets activated after new Complexdata is send to the client
end
