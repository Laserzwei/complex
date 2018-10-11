require ("mods.complexMod.scripts.lib.constructionLib")
require ("mods.complexMod.scripts.entity.ui.subFactorySelection")

-- Complex building menu items
local dirButtonXP, dirButtonYP, dirButtonZP
local dirButtonXM, dirButtonYM, dirButtonZM

local sliderX
local sliderY
local sliderZ
local numberBoxX, numberBoxXValue = 0
local numberBoxY, numberBoxYValue = 0
local numberBoxZ, numberBoxZValue = 0

local factorySelectionButton
local directionToAdd = vec3(0,1,0)             -- 0:X+, 1:X-, 2:Y+, 3:Y-, 4:Z+, 5:Z-

local buttonNodeXP, buttonNodeYP, buttonNodeZP
local buttonNodeXM, buttonNodeYM, buttonNodeZM

local constructionButton
local refreshButton

local planDisplayer

--Complex Blockplans
local addedPlan
local preview

--Complex Data
local selectedProduction
local complexData = {}
local currentNodeIndex
local currentNodeOffset = vec3(0,0,0)
local targetCoreBlockIndex
local targetCoreBlockCoord
local constructionData = {}     --{nodeOffset = vec3, [buildorder] = {[BlockID]= {["position"] = {x,y,z}, ["size"] = {x,y,z}, ["rootID"] = rootID}}}

local UIinititalised = false

function createConstructionUI(tabWindow)
    local res = getResolution()
    local container = tabWindow:createContainer(Rect(vec2(0, 0), tabWindow.size))

    local vsplit = UIVerticalSplitter(Rect(vec2(0, 0), container.size), 10, 10, 0.25)

    local left = vsplit.left
    local right = vsplit.right

    container:createFrame(left)
    container:createFrame(right)

    local lister = UIVerticalLister(left, 10, 10)
    local l = container:createLabel(vec2(), "Select Station"%_t, 14)
    lister.padding = 0
    lister:placeElementCenter(l)
    lister.padding = 10

    -- subfactory selection
    initSFUI(tabWindow)

    factorySelectionButton = container:createButton(Rect(),"Select Factory", "onFactorySelectionPressed")
    lister:placeElementCenter(factorySelectionButton)
    lister.padding = 5

    --creating Station offset Buttons
    local l = container:createLabel(vec2(), "Move Station Offset"%_t, 14)
    l.size = vec2(0, 0)
    lister.padding = 0
    lister:placeElementCenter(l)
    lister.padding = 5

    local rect = lister:placeCenter(vec2(vsplit.left.width - 20, 30))
    local vmsplit = UIVerticalMultiSplitter(rect, 5, 3, 2)
    dirButtonXP = container:createButton(vmsplit:partition(0), "X+", "onSetOffsetXP")
    dirButtonYP = container:createButton(vmsplit:partition(1), "Y+", "onSetOffsetYP")
    dirButtonZP = container:createButton(vmsplit:partition(2), "Z+", "onSetOffsetZP")
    lister.padding = 5
    rect = lister:placeCenter(vec2(vsplit.left.width - 20, 30))
    local vmsplit2 = UIVerticalMultiSplitter(rect, 5, 3, 2)
    dirButtonXM = container:createButton(vmsplit2:partition(0), "X-", "onSetOffsetXM")
    dirButtonYM = container:createButton(vmsplit2:partition(1), "Y-", "onSetOffsetYM")
    dirButtonZM = container:createButton(vmsplit2:partition(2), "Z-", "onSetOffsetZM")
    lister.padding = 10
    setDirButtonsActive()

    --advanced Slider and Numberbox for X-Axis
    rect = lister:placeCenter(vec2(vsplit.left.width - 20, 30))
    local sliderSplit = UIVerticalSplitter(rect, 5, 0, 0.7)
    sliderX = container:createSlider(sliderSplit.left, -100, 100, 200, "X"%_t, "updatePlan")
    sliderX.value = 0
    sliderX.segments = 40

    numberBoxX = container:createTextBox(sliderSplit.right, "onNumberfieldEnteredX")
    numberBoxX.text = "0"
    numberBoxX.allowedCharacters = "-0123456789"
    numberBoxX.clearOnClick = 1

    --advanced Slider and Numberbox for Y-Axis
    rect = lister:placeCenter(vec2(vsplit.left.width - 20, 30))
    local sliderSplit = UIVerticalSplitter(rect, 5, 0, 0.7)
    sliderY = container:createSlider(sliderSplit.left, -100, 100, 200, "Y"%_t, "updatePlan")
    sliderY.value = 0
    sliderY.segments = 40

    numberBoxY = container:createTextBox(sliderSplit.right, "onNumberfieldEnteredY")
    numberBoxY.text = "0"
    numberBoxY.allowedCharacters = "-0123456789"
    numberBoxY.clearOnClick = 1

    --advanced Slider and Numberbox for Z-Axis
    rect = lister:placeCenter(vec2(vsplit.left.width - 20, 30))
    local sliderSplit = UIVerticalSplitter(rect, 5, 0, 0.7)
    sliderZ = container:createSlider(sliderSplit.left, -100, 100, 200, "Z"%_t, "updatePlan")
    sliderZ.value = 0
    sliderZ.segments = 40

    numberBoxZ = container:createTextBox(sliderSplit.right, "onNumberfieldEnteredZ")
    numberBoxZ.text = "0"
    numberBoxZ.allowedCharacters = "-0123456789"
    numberBoxZ.clearOnClick = 1

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
    constructionButton = container:createButton(Rect(), "Build"%_t, "onConstructionButtonPress")
    local organizer = UIOrganizer(left)
    organizer.padding = 10
    organizer.margin = 10
    organizer:placeElementBottom(constructionButton)

    -- create the viewer
    planDisplayer = container:createPlanDisplayer(vsplit.right)
    planDisplayer.showStats = 0
    planDisplayer.autoCenter = 0
    planDisplayer.center = vec3(0,0,0)
    planDisplayer.autoRotationSpeed = 0

    UIinititalised = true
    updatePlan()
end

function onFactorySelectionPressed(button)
    factorySelectionWindow.visible = true
end

function onRefreshPressed()
    updatePlan()
end

function updateCT(timestep)

end

function updateComplexdataCT(pIndexedComplexdata)
    if onServer() then debugPrint(0,"updateComplexdataCT onServer not allowed !") end
    complexData = applyIndexedToComplexdata(pIndexedComplexdata)
    if UIinititalised == false then return end
    setNodeButtonsActive()
    updatePlan()
    debugPrint(3, "ComplexData =========", complexData)
end

function cTRenderUI()
    if factorySelectionWindow.visible == false then
        local offset = 10
        local numBlocks = (addedPlan and addedPlan.numBlocks or 0) + Entity():getPlan().numBlocks
        local maxBlocks = config.maxBlockCount
        if maxBlocks == -1 then
            drawText(numBlocks.."/".."unlimited"%_t.." Blocks", planDisplayer.lower.x + 10, planDisplayer.lower.y + offset, ColorRGB(1, 1, 1), 12, 0, 0, 2)
        else
            if numBlocks <= maxBlocks then
                drawText(numBlocks.."/"..maxBlocks.." Blocks", planDisplayer.lower.x + 10, planDisplayer.lower.y + offset, ColorRGB(1, 1, 1), 12, 0, 0, 2)
            else
                drawText(numBlocks.."/"..maxBlocks.." Blocks", planDisplayer.lower.x + 10, planDisplayer.lower.y + offset, ColorRGB(1, 0.1, 0.1), 12, 0, 0, 2)
            end
        end
        offset = offset + 25
        if currentNodeIndex and complexData[currentNodeIndex] then
            local name = complexData[currentNodeIndex].name
            drawText(name, planDisplayer.lower.x + 10, planDisplayer.lower.y + offset, ColorRGB(1, 1, 1), 15, 0, 0, 2)
            offset = offset + 25
        end
        if addedPlan == nil then return end
        local planMoney = addedPlan:getMoneyValue()
        local planResources = {addedPlan:getResourceValue()}

        offset = offset + renderPrices(planDisplayer.lower + vec2(10, offset), "Construction Costs"%_t, planMoney, planResources)
    else

    end
end

function setAddedPlan(plan)
    addedPlan = plan
end

function updatePlan()
    -- just to make sure that the interface is completely created, this function is called during initialization of the GUI, and not everything may be constructed yet
    if not UIinititalised then return end
    if directionToAdd == nil then return end
    if currentNodeOffset == nil then currentNodeOffset = vec3(0,0,0) end

    local timer = HighResolutionTimer()
    local totalTimer = HighResolutionTimer()
    timer:start()
    totalTimer:start()

    -- find starting block
    local newPlan = Entity():getPlan()
    local hasToPayForRootBlock = false
    -- startingblock for very first Factory
    if complexData == nil or next(complexData) == nil then
        if not isBlockFactoryBlock(newPlan.root) then
            local bp = BlockPlan()
            local index = bp:addBlock(vec3(0,0,0), vec3(5,5,5), -1, -1, ColorInt(rootBlockColor), Material(MaterialType.Trinium) , Matrix(), BlockType.Armor)
            bp:addPlan(index, newPlan, newPlan.rootIndex)
            newPlan = bp
            hasToPayForRootBlock = true
            print("neuer Plan", index, bp.rootIndex, newPlan.rootIndex)
        end
    end

    local factoryCoreBlock
    -- equals factory root?
    if vec3Equal(vec3(0,0,0),currentNodeOffset) then
        if isBlockFactoryBlock(newPlan.root) then
            factoryCoreBlock = newPlan.rootIndex
        else
            print("factory block at root not found")
            return
        end
    else -- get factory core block from selected subfactory
        factoryCoreBlock = getNodeIDFromNodeOffset(currentNodeOffset)
        if not factoryCoreBlock then
            print("factory block at offset not found", currentNodeOffset:__tostring())
            return
        end
    end

    if addedPlan then
        -- core block chosen
        -- expect selected Plan with its factory core block (as root?)
        -- position Boundingboxes next to each other
        local mainBB, addedBB = newPlan:getBoundingBox(), addedPlan:getBoundingBox()
        local offset = vec3(sliderX.value + (numberBoxXValue or 0), sliderY.value + (numberBoxYValue or 0), sliderZ.value + (numberBoxZValue or 0))
        local nodeCoords
        if complexData[factoryCoreBlock] then
            print("cD has fcb")
            nodeCoords = complexData[factoryCoreBlock].relativeCoords
        else
            print("cD has no fcb")
            nodeCoords = newPlan.root.box.center
        end

        local addedVec = placeBoundingBoxNextToEachOther(mainBB, addedBB, directionToAdd, nodeCoords, offset)

        print("addedVec", addedVec:__tostring())
        debugPrint(3,"Needed ".. timer.microseconds/1000 .."ms for preparation")
        timer:restart()
        -- add Connectors
        local constructionData, connectionPlan = createConnectionPipes(nodeCoords, addedVec, newPlan, currentNodeIndex)

        debugPrint(3, "Needed ".. timer.microseconds/1000 .."ms until merge")
        timer:restart()


        --add addedPlan to newPlan
        local connIndex = constructionData[3].BlockID
        newPlan:addPlanDisplaced(connIndex, addedPlan, addedPlan.rootIndex, nodeCoords + addedVec)

        targetCoreBlockIndex = newPlan:getBlock(connIndex):getChildren()
        local tcBlock = newPlan:getBlock(targetCoreBlockIndex)
        local rBox = tcBlock.box
        local rColor = tcBlock.color
        -- is root a valid factory-root-block?
        print("sel Block main?", isBlockFactoryBlock(tcBlock))
        targetCoreBlockCoord = tcBlock.box.center

        debugPrint(3,"Needed ".. timer.microseconds/1000 .."ms for addPlanDisplaced")
        timer:restart()
    else
        print("noplan")
    end
    -- set to display

    -- TODO check for config.maxBlockCountMultiplier
    --preview = newPlan
    planDisplayer.plan = newPlan

    debugPrint(3, "Needed ".. timer.microseconds/1000 .."ms for Plandisplayer set plan")
    timer:restart()

    planDisplayer.center = complexData[currentNodeIndex] and complexData[currentNodeIndex].relativeCoords or newPlan.root.box.center

    debugPrint(3, "Needed ".. timer.microseconds/1000 .."ms for Plandisplayer center")
    timer:restart()

    setDirButtonsActive()

    if  getNodeIDFromNodeOffset(currentNodeOffset + directionToAdd) then
        constructionButton.active = false
    else
        constructionButton.active = true
    end

    if not checkEntityInteractionPermissions(Entity(), nil) then--unpack(mT.permissions[1].requiredPermissions)) then
        constructionButton.active = false
        constructionButton.tooltip = "You need Alliance permission!"
    else
        constructionButton.active = true
        constructionButton.tooltip = nil
    end
    debugPrint(3, "Needed ".. timer.microseconds/1000 .."ms for construction of total ".. totalTimer.microseconds/1000 .."ms")
    timer:stop()
    totalTimer:stop()
end

function getNodeSuccessor(dir, searchVector)
    if not currentNodeOffset then return nil end
    local smallestDistance = math.huge
    local biggestDistance = 0
    local smallestIndex = nil
    local plan = Entity():getPlan()
    for nodeID,data in pairs(complexData) do
        if vec3Equal(data.nodeOffset,(currentNodeOffset + searchVector)) then
            return nodeID
        end
        if searchVector[dir] == 1 then
            if data.nodeOffset[dir] >= (currentNodeOffset[dir] + searchVector[dir]) then
                local dist = getDistBetweenVectors(data.nodeOffset,(currentNodeOffset + searchVector))
                if dist < smallestDistance then
                    smallestDistance = dist
                    smallestIndex = nodeID
                end
            else  end
        end
        if searchVector[dir] == -1 then
            if data.nodeOffset[dir] <= (currentNodeOffset[dir] + searchVector[dir]) then
                local dist = getDistBetweenVectors(data.nodeOffset,(currentNodeOffset + searchVector))
                if dist < biggestDistance then
                    biggestDistance = dist
                    smallestIndex = nodeID
                end
            else  end
        end
    end
    return smallestIndex
end

function getNodeIDFromNodeOffset(offset)
    local plan = Entity():getPlan()
    local nodeIndex
    for nodeID,data in pairs(complexData) do
        if vec3Equal(data.nodeOffset, offset)then
            nodeIndex = nodeID
        end
    end
    print("nodeIndex", nodeIndex)
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
            debugPrint(0, "The current Node got messed up.")
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
    directionToAdd = vec3(1, 0, 0)
    updatePlan()
end

function onSetOffsetXM()
    directionToAdd = vec3(-1, 0, 0)
    updatePlan()
end

function onSetOffsetYP()
    directionToAdd = vec3(0, 1, 0)
    updatePlan()
end

function onSetOffsetYM()
    directionToAdd = vec3(0, -1, 0)
    updatePlan()
end

function onSetOffsetZP()
    directionToAdd = vec3(0, 0, 1)
    updatePlan()
end

function onSetOffsetZM()
    directionToAdd = vec3(0, 0, -1)
    updatePlan()
end


function onSetNodeOffsetXP()
    currentNodeIndex = getNodeSuccessor("x", vec3(1,0,0))
    currentNodeOffset = complexData[currentNodeIndex].nodeOffset
    setNodeButtonsActive()
    updatePlan()
end

function onSetNodeOffsetXM()
    currentNodeIndex = getNodeSuccessor("x", vec3(-1,0,0))
    currentNodeOffset = complexData[currentNodeIndex].nodeOffset
    setNodeButtonsActive()
    updatePlan()
end

function onSetNodeOffsetYP()
    currentNodeIndex = getNodeSuccessor("y", vec3(0,1,0))
    currentNodeOffset = complexData[currentNodeIndex].nodeOffset
    setNodeButtonsActive()
    updatePlan()
end

function onSetNodeOffsetYM()
    currentNodeIndex = getNodeSuccessor("y", vec3(0,-1,0))
    currentNodeOffset = complexData[currentNodeIndex].nodeOffset
    setNodeButtonsActive()
    updatePlan()
end

function onSetNodeOffsetZP()
    currentNodeIndex = getNodeSuccessor("z",vec3(0,0,1))
    currentNodeOffset = complexData[currentNodeIndex].nodeOffset
    setNodeButtonsActive()
    updatePlan()
end

function onSetNodeOffsetZM()
    currentNodeIndex = getNodeSuccessor("z", vec3(0,0,-1))
    currentNodeOffset = complexData[currentNodeIndex].nodeOffset
    setNodeButtonsActive()
    updatePlan()
end

function onNumberfieldEnteredX()
    local value = tonumber(numberBoxX.text)
    if value then
        sliderX.value = 0
        numberBoxXValue = value
    else
        --numberBoxX.text = "0"
    end
    updatePlan()
end

function onNumberfieldEnteredY()
    local value = tonumber(numberBoxY.text)
    if value then
        sliderY.value = 0
        numberBoxYValue = value
    else
        --numberBoxY.text = "0"
    end
    updatePlan()
end

function onNumberfieldEnteredZ()
    local value = tonumber(numberBoxZ.text)
    if value then
        sliderZ.value = 0
        numberBoxZValue = value
    else
        --numberBoxZ.text = "0"
    end
    updatePlan()
end

function onConstructionButtonPress()
    if not checkEntityInteractionPermissions(Entity(), unpack(mT.permissions[1].requiredPermissions)) then
        constructionButton.active = false
        constructionButton.tooltip = "You need Alliance permission!"
        return
    end

    -- TODO check for config.maxBlockCountMultiplier
    -- TODO use selectedProduction
    local name, args = formatFactoryName(factoryData.production, factoryData.maxNumProductions - 1)
    name = string.gsub(name, "${good}", tostring(args.good))
    name = string.gsub(name, "${size}", getFactoryClassBySize(factoryData.maxNumProductions))
    local nodeOffset = directionToAdd + currentNodeOffset


    currentNodeOffset = nodeOffset
    currentNodeIndex = targetCoreBlockIndex
    local data = {["name"] = name, ["relativeCoords"] = targetCoreBlockCoord, ["nodeOffset"] = nodeOffset, ["factoryTyp"] = factoryData.production, ["size"] = factoryData.maxNumProductions}
    local root = Entity():getPlan().rootIndex
    debugPrint(3, "roottable", complexData, root, targetCoreBlockIndex)

    complexData[targetCoreBlockIndex] = data
    data.factoryBlockId = targetCoreBlockIndex

    constructionData.nodeOffset = nodeOffset
    local count = 0
    for _,_ in pairs(complexData) do
        count = count + 1
    end
    if count > 2 then
        local status, data = Entity():invokeFunction(CMSCRIPT,"cmOnConstructionButtonPress",constructionData, addedPlan, data)
    else --initializing
        local basefab = {   ["name"] = complexData[root].name,
                            ["relativeCoords"] = complexData[root].relativeCoords,
                            ["nodeOffset"] = complexData[root].nodeOffset,
                            ["factoryTyp"] = complexData[root].factoryTyp,
                            ["size"] = complexData[root].size,
                            ["factoryBlockId"] = root}
        local status, data = Entity():invokeFunction(CMSCRIPT,"cmOnConstructionButtonPress",constructionData, addedPlan, data, basefab)
    end
    debugPrint(3,"build pressed", nil, currentNodeIndex)
    EntityIcon().icon = "data/textures/icons/pixel/crate.png"
    constructionButton.active = false                                                                       --Locking The construction Button to prevent inconsistent data. Gets activated after new Complexdata is send to the client
end
