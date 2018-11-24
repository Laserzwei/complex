require ("mods.complexMod.scripts.lib.constructionLib")
require ("mods.complexMod.scripts.entity.ui.subFactorySelection")

-- Complex building menu items
local dirButtonXP, dirButtonYP, dirButtonZP
local dirButtonXM, dirButtonYM, dirButtonZM

local sliderID, sliderVal = {}, {x = 0, y = 0, z = 0}
local numBoxID, numboxVal = {}, {x = 0, y = 0, z = 0}

local factorySelectionButton
local directionToAdd = vec3(0,1,0)             -- 0:X+, 1:X-, 2:Y+, 3:Y-, 4:Z+, 5:Z-

local buttonNodeXP, buttonNodeYP, buttonNodeZP
local buttonNodeXM, buttonNodeYM, buttonNodeZM

local constructionButton
local refreshButton

local planDisplayer

--Complex Blockplans
local addedPlan, copiedaddedPlan
local factoryData

--Complex Data
local selectedProduction
local complexData = {}
local currentNodeIndex
local currentNodeOffset = vec3(0,0,0)
local targetCoreBlockIndex
local targetCoreBlockCoord
local constructionData = {}     --{nodeOffset = vec3, [buildorder] = {[BlockID]= {["position"] = {x,y,z}, ["size"] = {x,y,z}, ["rootID"] = rootID}}}
local connectionPlan, connectionData
local costs = {money = 0, resources = {}}

local UIinititalised = false

function createConstructionUI(tabWindow)
    local res = getResolution()
    local container = tabWindow:createContainer(Rect(vec2(0, 0), tabWindow.size))

    local vsplit = UIVerticalSplitter(Rect(vec2(0, 0), container.size), 10, 10, 0.25)

    local left = vsplit.left
    local right = vsplit.right

    container:createFrame(left)
    container:createFrame(right)

    local l = container:createLabel(left.lower + vec2(10, 10), "Select Factory"%_t, 16)

    local lister = UIVerticalLister(Rect(left.lower+vec2(0,35), left.upper), 10, 10)

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
    local slider = container:createSlider(sliderSplit.left, -100, 100, 200, "X"%_t, "onSliderUpdate")
    slider.segments = 40
    slider:setValueNoCallback(0)
    sliderID[slider.index] = "x"

    local numBox = container:createTextBox(sliderSplit.right, "onNumberfieldEntered")
    numBox.text = "0"
    numBox.allowedCharacters = "-.0123456789"
    numBox.clearOnClick = 1
    numBoxID[numBox.index] = "x"

    --advanced Slider and Numberbox for Y-Axis
    rect = lister:placeCenter(vec2(vsplit.left.width - 20, 30))
    local sliderSplit = UIVerticalSplitter(rect, 5, 0, 0.7)
    slider = container:createSlider(sliderSplit.left, -100, 100, 200, "Y"%_t, "onSliderUpdate")
    slider.segments = 40
    slider:setValueNoCallback(0)
    sliderID[slider.index] = "y"

    numBox = container:createTextBox(sliderSplit.right, "onNumberfieldEntered")
    numBox.text = "0"
    numBox.allowedCharacters = "-0123456789"
    numBox.clearOnClick = 1
    numBoxID[numBox.index] = "y"

    --advanced Slider and Numberbox for Z-Axis
    rect = lister:placeCenter(vec2(vsplit.left.width - 20, 30))
    local sliderSplit = UIVerticalSplitter(rect, 5, 0, 0.7)
    slider = container:createSlider(sliderSplit.left, -100, 100, 200, "Z"%_t, "onSliderUpdate")
    slider.segments = 40
    slider:setValueNoCallback(0)
    sliderID[slider.index] = "z"

    numBox = container:createTextBox(sliderSplit.right, "onNumberfieldEntered")
    numBox.text = "0"
    numBox.allowedCharacters = "-0123456789"
    numBox.clearOnClick = 1
    numBoxID[numBox.index] = "z"

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
        local numBlocks = Entity():getPlan().numBlocks + 3 + (addedPlan and addedPlan.numBlocks or 0)
        local maxBlocks = config.maxBlockCount
        if maxBlocks <= -1 then
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
            drawText(complexData[currentNodeIndex].name, planDisplayer.lower.x + 10, planDisplayer.lower.y + offset, ColorRGB(1, 1, 1), 15, 0, 0, 2)
            offset = offset + 25
        end
        if addedPlan then
            offset = offset + renderPrices(planDisplayer.lower + vec2(10, offset), "Construction Costs"%_t, costs.money, costs.resources)
        end
    else

    end
end

function setAddedPlan(plan, copyPlan, production)
    addedPlan = plan
    copiedaddedPlan = copyPlan
    factoryData = production
    updatePlan()
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
            print("new Plan", index, bp.rootIndex, newPlan.rootIndex)
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
        -- costs
        local planMoney = addedPlan:getMoneyValue()
        local planResources = {addedPlan:getResourceValue()}

        -- core block chosen
        -- expect selected Plan with its factory core block as root
        -- position Boundingboxes next to each other
        local mainBB, addedBB = newPlan:getBoundingBox(), addedPlan:getBoundingBox()
        local offset = vec3(sliderVal.x + numboxVal.x, sliderVal.y + numboxVal.y, sliderVal.z + numboxVal.z)
        local nodeCoords
        if complexData[factoryCoreBlock] then
            print("cD has fcb")
            nodeCoords = complexData[factoryCoreBlock].relativeCoords
        else
            print("cD has no fcb")
            nodeCoords = newPlan.root.box.center
        end

        local addedVec = placeBoundingBoxNextToEachOther(mainBB, addedBB, directionToAdd, nodeCoords)
        addedVec = addedVec + offset

        debugPrint(3,"Needed ".. timer.microseconds/1000 .."ms for preparation")
        timer:restart()
        -- add Connectors
        connectionData, connectionPlan = createConnectionPipes(nodeCoords, addedVec, newPlan, currentNodeIndex)
        constructionData.nodeCoords = nodeCoords
        constructionData.addedVec = addedVec
        if not hasToPayForRootBlock then
            constructionData.currentNodeIndex = currentNodeIndex
        end

        local connectionMoney = connectionPlan:getMoneyValue()
        local connectionResources = {connectionPlan:getResourceValue()}

        for i,v in pairs(planResources) do
            planResources[i] = v + connectionResources[i]
        end

        if hasToPayForRootBlock then
            planMoney = planMoney + 1140
            planResources[4] = planResources[4] + 1000  -- 1000 Trinium
        end

        costs.money = planMoney
        costs.resources = planResources


        debugPrint(3, "Needed ".. timer.microseconds/1000 .."ms until merge")
        timer:restart()

        constructionData.displacement = nodeCoords + addedVec
        --add addedPlan to newPlan, this consumes copiedaddedPlan
        local connIndex = connectionData[3].BlockID
        newPlan:addPlanDisplaced(connIndex, copiedaddedPlan, copiedaddedPlan.rootIndex, nodeCoords + addedVec)

        targetCoreBlockIndex = newPlan:getBlock(connIndex):getChildren()
        local tcBlock = newPlan:getBlock(targetCoreBlockIndex)
        -- is root a valid factory-root-block?
        print("sel Block main?", isBlockFactoryBlock(tcBlock))
        targetCoreBlockCoord = tcBlock.box.center

        debugPrint(3,"Needed ".. timer.microseconds/1000 .."ms for addPlanDisplaced")
        timer:restart()
    else
        costs.money = 0
        costs.resources = {}
        print("noplan")
    end
    -- set to display
    planDisplayer.plan = newPlan

    debugPrint(3, "Needed ".. timer.microseconds/1000 .."ms for Plandisplayer set plan")
    timer:restart()

    planDisplayer.center = complexData[currentNodeIndex] and complexData[currentNodeIndex].relativeCoords or newPlan.root.box.center

    debugPrint(3, "Needed ".. timer.microseconds/1000 .."ms for Plandisplayer center")
    timer:restart()

    setDirButtonsActive()
    debugPrint(3, "Needed ".. timer.microseconds/1000 .."ms for construction of total ".. totalTimer.microseconds/1000 .."ms")
    timer:stop()
    totalTimer:stop()

    local canBuild, error = false, ""
    if not checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FoundStations) then--unpack(mT.permissions[1].requiredPermissions)) then
        canBuild = false
        error = error.."\n".."You need Alliance permission!"
    else
        canBuild = true
        error = ""
    end

    if not addedPlan then
        error = error.."\n".."Select a factory to build!"
        canBuild = false
    end

    if addedPlan and Entity():getPlan().numBlocks +addedPlan.numBlocks + 3 > config.maxBlockCount then
        error = error.."\n".."Adding this factory building exceeds the block-count-limit!"
        canBuild = false
    end

    if canBuild == true or error == "" then
        constructionButton.active = true
        constructionButton.tooltip = nil
    else
        constructionButton.active = false
        constructionButton.tooltip = error
    end


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
    for nodeID,data in pairs(complexData) do
        if vec3Equal(data.nodeOffset, offset)then
            print("nodeIndex", nodeID)
            return nodeID
        end
    end
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

function onSliderUpdate(slider, value)
    if not UIinititalised then return end
    local sliderValue = sliderVal[sliderID[slider.index]]
    if sliderValue ~= value then
        sliderVal[sliderID[slider.index]] = value
        updatePlan()
    end
end

function onNumberfieldEntered(numberBox)
    if not UIinititalised then return end
    if string.len(numberBox.text) > 10 then
        numberBox.text = "0"
        numboxVal[numBoxID[numberBox.index]] = 0
        return
    end
    local value = tonumber(numberBox.text)
    if value then
        numboxVal[numBoxID[numberBox.index]] = value
    end
    updatePlan()
end


function onConstructionButtonPress()
    if not checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FoundStations) then --TODO[[unpack(mT.permissions[1].requiredPermissions]])) then
        constructionButton.active = false
        constructionButton.tooltip = "You need Alliance permission!"
        return
    end

    if not addedPlan then
        constructionButton.active = false
        constructionButton.tooltip = "Select a factory to build!"
        return
    end

    if (Entity():getPlan().numBlocks + 3 + addedPlan.numBlocks) > config.maxBlockCount then
        constructionButton.active = false
        constructionButton.tooltip = "Adding this factory exceeds the block-count-limit!"
        return
    end

    local name, args = formatFactoryName(factoryData, 2)
    name = string.gsub(name, "${good}", tostring(args.good))
    name = string.gsub(name, "${size}", getFactoryClassBySize(2))
    local nodeOffset = directionToAdd + currentNodeOffset


    currentNodeOffset = nodeOffset
    currentNodeIndex = targetCoreBlockIndex
    local data = {["name"] = name, ["relativeCoords"] = targetCoreBlockCoord, ["nodeOffset"] = nodeOffset, ["factoryTyp"] = factoryData.production, ["size"] = 2}
    local root = Entity():getPlan().rootIndex
    debugPrint(3, "roottable",  root, targetCoreBlockIndex)

    --complexData[targetCoreBlockIndex] = data
    --data.factoryBlockId = targetCoreBlockIndex
    constructionData.nodeOffset = nodeOffset

    local status, data = Entity():invokeFunction(CMSCRIPT,"checkNewFactory",constructionData, addedPlan, data)

    debugPrint(3,"build pressed", nil, currentNodeIndex, status)
    --TODO EntityIcon().icon = "data/textures/icons/pixel/crate.png"
    constructionButton.active = false                                                                       --Locking The construction Button to prevent inconsistent data. Gets activated after new Complexdata is send to the client
end
