
function applyIndexedToComplexdata(pIndexedComplexData)
    local list = {}
    for _,subFactoryType in ipairs(pIndexedComplexData) do
        for _, subFactory in ipairs(subFactoryType.subFactories) do
            local t = {
            ["relativeCoords"] = data.relativeCoords,
            ["factoryTyp"] = data.factoryTyp,
            ["nodeOffset"] = data.nodeOffset,
            ["size"] = data.fabSize,
            ["name"] = data.name}
            list[data.factoryBlockId] = t
        end
    end
    return list
end

function placeBoundingBoxNextToEachOther(mainBB, addedBB, directionToAdd, nodeCoords)
    local vec = vec3(0, 0, 0)

    if directionToAdd.x + directionToAdd.y + directionToAdd.z >= 0 then
        vec = (mainBB.upper - nodeCoords - addedBB.lower) * directionToAdd
    else
        vec = (mainBB.lower - nodeCoords - addedBB.upper) * directionToAdd:__unm()
    end
    return vec
end

function createConnectionPipes(nodeCoords, offset, plan, currentNodeIndex)
    local connectionPlan = BlockPlan()  -- money plan
    local connectionData = {}


    local sizeY = vec3(2, math.abs(offset.y) - 2, 2)
    local sizeX = vec3(math.abs(offset.x) + 2 , 2, 2)
    local sizeZ = vec3(2, 2, math.abs(offset.z) - 2)
    local posY = vec3(0, offset.y/2, 0) + nodeCoords
    local posX = vec3(offset.x/2, offset.y, 0) + nodeCoords
    local posZ = vec3(offset.x, offset.y, offset.z/2) + nodeCoords

    local connectorY = plan:addBlock(posY, sizeY, currentNodeIndex, -1, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)
    connectionPlan:addBlock(posY, sizeY, connectionPlan.rootIndex, -1, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)                      --For price calculation
    connectionData[1] = {["BlockID"] = connectorY,["position"] = vec3ToTable(posY), ["size"] = vec3ToTable(sizeY), ["rootID"] = currentNodeIndex}

    local connectorX = plan:addBlock(posX, sizeX, connectorY, -1, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)
    connectionPlan:addBlock(posX, sizeX, connectionPlan.rootIndex, -1, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)                      --For price calculation
    connectionData[2] = {["BlockID"] = connectorX,["position"] = vec3ToTable(posX), ["size"] = vec3ToTable(sizeX), ["rootID"] = connectorY}

    local connectorZ = plan:addBlock(posZ, sizeZ, connectorX, -1, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)
    connectionPlan:addBlock(posZ, sizeZ, connectionPlan.rootIndex, -1, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)                      --For price calculation
    connectionData[3] = {["BlockID"] = connectorZ,["position"] = vec3ToTable(posZ), ["size"] = vec3ToTable(sizeZ), ["rootID"] = connectorX}

    return connectionData, connectionPlan
end

function isBlockFactoryBlock(blockPlanBlock)
    local rBox = blockPlanBlock.box
    local rColor = blockPlanBlock.color
    -- is root a valid factory-root-block?
    --print(rBox.size.x == 5, rBox.size.y == 5, rBox.size.z == 5, rColor:toInt() == rootBlockColor, blockPlanBlock.material:__eq(Material(MaterialType.Trinium)), blockPlanBlock.blockIndex == BlockType.Armor)
    if    rBox.size.x == 5
      and rBox.size.y == 5
      and rBox.size.z == 5
      and rColor:toInt() == rootBlockColor
      and blockPlanBlock.material:__eq(Material(MaterialType.Trinium))
      and blockPlanBlock.blockIndex == BlockType.Armor then
        return true
    else
        return false
    end
end

-- not used, because to slow: ~10ms /100Blocks
-- blockplan_in has to have at least 1 Block (root)
-- don't add outPlan/rootIndex as attribute, when calling
function deepCopyBlockPlan(blockplan_in, outPlan, rootIndex)
    local outPlan = outPlan or BlockPlan()
    if not rootIndex then
        local root = blockplan_in.root
        --maybe root.box.center for position?
        local suc = outPlan:addBlock(root.box.position, root.box.size, -1, root.index, root.color, root.material, root.orientation, root.blockIndex)
        local hasChildren = root:getChildren()
        if hasChildren then
            outPlan = deepCopyBlockPlan(blockplan_in, outPlan, root.index)
        end
    else
        local root = blockplan_in:getBlock(rootIndex)
        children = {root:getChildren()}
        for _, childIndex in ipairs(children) do
            local child = blockplan_in:getBlock(childIndex)
            outPlan:addBlock(child.box.position, child.box.size, root.index, childIndex, child.color, child.material, child.orientation, child.blockIndex)
            outPlan = deepCopyBlockPlan(blockplan_in, outPlan, child.index)
        end
    end
    return outPlan
end
