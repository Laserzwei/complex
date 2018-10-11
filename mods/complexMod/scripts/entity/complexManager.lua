package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";mods/complexMod/scripts/entity/ui/?.lua"

require ("utility")
require ("faction")
require ("randomext")
require ("productions")
require ("goods")
require ("stringutility")

require ("constructionTab")
--require ("overviewTab")
--require ("tradingTab")

require ("mods.complexMod.scripts.lib.complexLib")
require ("mods.complexMod.scripts.lib.syncLib")

--mT = require ("managementTab")
Dialog = require ("dialogutility")
config = require ("mods.complexMod.config.complex")


COMPLEXINTEGRITYCHECK = config.complexIntegrityCheck
CFSCRIPT = config.CFSCRIPT
CMSCRIPT = config.CMSCRIPT
FSCRIPT = config.FSCRIPT
baseProductionCapacity = config.baseProductionCapacity
debugPrint = config.debugPrint

rootBlockColor = 8388608 -- == RGB(127,0,0) ~= ColorRGB(0.5,0.0,0.0)

-- Menu items
local selectedTab = 1               --1:BCU, 2:ICU, 3:TCU, 4:MCU

--Complex Data
indexedComplexData = {}
--[[
[priority] = {
    production = {                      original factories production data. Is used to
        results = {},                   to distinguish between different prioritised factories
        garbages = {},
        ingredients = {}
    },
    size = <int>,                       current utilization [0-sum(sf[x].active and sf[x].fabSize)]
    subfactories = [<int>]={
        factoryBlockId = <int>,         BlockID of the coreblock in the Blockplan
        relativeCoords = <vec3(x,y,z)>, position of the coreblock in the Blockplan
        nodeOffset = <vec3(x,y,z)>,     position relative to other factories on the grid
        name = <String>,                formatted factory name
        fabSize = <int>,                [1-10]
        active = <bool>                 shows, if factory is capable of producing or needs maintainance
    }
}
]]
--[[
Adds all data required into the indexedComplexData List.
Factories are equal, if their production is equal. (See isSameProduction())
Requires an Serversided Check beforehand.
newSubfactory = {
    factoryBlockId = <int>,         BlockID of the coreblock in the Blockplan
    relativeCoords = <vec3(x,y,z)>, position of the coreblock in the Blockplan
    nodeOffset = <vec3(x,y,z)>,     position relative to other factories on the grid
}
]]
function addFactory(factoryEntity, newSubfactory)
    if not onServer() then return end
    local status , factoryData = factoryEntity:invokeFunction(FSCRIPT, "secure", nil)
    if status ~= 0 then print("could not get factoryData", status) return end

    local factoryProduction = {
    results = factoryData.production.results,
    garbages = factoryData.production.garbages,
    ingredients = factoryData.production.ingredients}

    newSubfactory.name = factoryData.production.factory
    newSubfactory.fabSize = factoryData.maxNumProduction
    newSubfactory.active = true

    local factoryTypeIsInComplex = false
    for _,complexData in ipairs(indexedComplexData) do
        if isSameProduction(complexData.production, factoryProduction) then
            complexData.size = complexData.size + factoryData.maxNumProductions
            complexData.subfactories[#complexData.subfactories+1] = newSubfactory
            factoryTypeIsInComplex = true
            --TODO send new subfactoy to client
            return
        end
    end
    if factoryTypeIsInComplex == false then
        local newComplexData = {}

        newComplexData.production = factoryProduction
        newComplexData.size = factoryData.maxNumProductions
        newComplexData.subfactories = {newSubfactory}
        indexedComplexData[#indexedComplexData+1] = newComplexData
        --TODO send new index and subfactory to client
    end
end
-- compares productionA and productionB and returns true, if all consumed and produced goods are the same, with the same quantities
function isSameProduction(productionA, productionB)
    local sameResult, sameGarbage, sameIngredient = false, false, false
    local count, compare = 0,0
    for _,cResult in pairs(productionA.results) do
        count = count + 1
        for _,fResult in pairs(productionB.results) do
            if cResult.name == fResult.name and cResult.amount == fResult.amount then
                compare = compare + 1
            end
        end
    end
    if count == compare then sameResult = true else return false end

    for _,cGarbage in pairs(productionA.garbage) do
        count = count + 1
        for _,fGarbage in pairs(productionB.garbage) do
            if cGarbage.name == fGarbage.name and cGarbage.amount == fGarbage.amount then
                compare = compare + 1
            end
        end
    end
    if count == compare then sameGarbage = true else return false end

    for _,cIngredient in pairs(productionA.ingredient) do
        count = count + 1
        for _,fIngredient in pairs(productionB.ingredient) do
            if cIngredient.name == fIngredient.name and cIngredient.amount == fIngredient.amount then
                compare = compare + 1
            end
        end
    end
    if count == compare then sameIngredient = true else return false end

    if sameResult == true and sameGarbage == true and sameIngredient == true then
        return true
    end
end
--[[
Removes a single subfactory from the Complex. If no more subfactoris of that type exist,
the whole factory type(priority) will be removed.
Returns true, if the factory got removed, false when not
]]
function removeFactory(priority, subfactoryIndex)
    if not onServer() then return end
    if indexedComplexData[priority] and indexedComplexData[priority].subfactories[subfactoryIndex] then
        --removing last factory
        if #indexedComplexData[priority].subfactories < 1 then
            while priority < #indexedComplexData do
                indexedComplexData[priority] = indexedComplexData[priority+1]
                priority = priority + 1
            end
            indexedComplexData[priority] = nil
            return true
        end
        --removing a single subfactory
        local subfacSize = indexedComplexData[priority].subfactories[subfactoryIndex].fabSize
        if indexedComplexData[priority].size < subfacSize then
            indexedComplexData[priority].size = 0
        else
            indexedComplexData[priority].size = indexedComplexData[priority].size - subfacSize
        end
        indexedComplexData[priority].subfactories[subfactoryIndex] = nil
        return true
    end
    return false
end

-- The sum of the production capacity of all active factories of that type.
function getMaxProductionCapacity(priority)
    if not indexedComplexData[priority] then return 0 end
    local capacity = 0
    for _,subfactory in ipairs(indexedComplexData[priority].subFactories) do
        if subfactory.active then
            capacity = capacity + subfactory.fabSize
        end
    end
    return capacity
end

local timepassedAfterLastCheck = 65

--permissions = mT.permissions

function initialize()
    local station = Entity()
    if onClient() then
        if not station:hasScript(FSCRIPT) then
            EntityIcon().icon = "mods/complexMod/textures/icons/complex.png"
        end
        InteractionText(station.index).text = Dialog.generateStationInteractionText(station, random())
    end
end

function getIcon()
    return "mods/complexMod/textures/icons/complex.png"
end

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function interactionPossible(playerIndex, option)
    if checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations) then
        return true
    else
        return false
    end
end

-- create all required UI elements for the client side
function initUI()

    local res = getResolution()*0.9
    local size = vec2(1100, 800)

    local menu = ScriptUI()
    local window = menu:createWindow(Rect(getResolution()*0.5 - res * 0.5, getResolution()*0.5 + res*0.5))

    window.caption = "Complex Manager "%_t..Entity().name
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "Manage Complex"%_t)
    local tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 10), window.size))
    tabbedWindow.onSelectedFunction = "onSelectedFunction"
--===============================================================================Build Complex UI======================================================================================================
    local constructionTab = tabbedWindow:createTab("BCU"%_t, "data/textures/icons/brick-pile.png", "Complex Construction"%_t)
    createConstructionUI(constructionTab)

--===============================================================================Info Complex UI=======================================================================================================
    local infoTab = tabbedWindow:createTab("ICU"%_t, "data/textures/icons/blockstats.png", "Complex Overview"%_t)
    --createOverviewUI(infoTab)

--===============================================================================Trading Complex UI====================================================================================================
    local tradingTab = tabbedWindow:createTab("TCU"%_t, "data/textures/icons/trade.png", "Complex Trading Overview"%_t)
    --createTradingUI(tradingTab)
--===============================================================================Manage Complex UI====================================================================================================
    local managementTab = tabbedWindow:createTab("MCU"%_t, "data/textures/icons/auto-repair.png", "Complex Management"%_t)
    --mT.createManagementUI(managementTab)

end

-- this function gets called every time the window is shown on the client, ie. when a player presses F
function onShowWindow()
end

function renderUI()
    if selectedTab == 1 then
        cTRenderUI()
    end
end

function update(timeStep)                                               --checking if selection in the List has changed
    if onClient() then
        updateCT(timeStep)
        --updateOT(timeStep)
        --updateTT(timeStep)
    else
        timepassedAfterLastCheck = timepassedAfterLastCheck + timeStep
        if timepassedAfterLastCheck >= COMPLEXINTEGRITYCHECK then
            debugPrint(3,"Complex integrity Check", nil, Entity().name)
            timepassedAfterLastCheck = 0
            diableMissingFactories()
        end
    end
end

function onSelectedFunction(tabIndex)
    local tabname = TabbedWindow(tabIndex):getActiveTab().name
     if tabname == "BCU" then
        selectedTab = 1
     end
     if tabname == "ICU" then
        selectedTab = 2
     end
     if tabname == "TCU" then
        selectedTab = 3
     end
     if tabname == "MCU" then
        selectedTab = 4
     end
end

-- Searches for Subfactories without a coreblock and disables them.
function diableMissingFactories()
    Entity():waitUntilAsyncWorkFinished()
    if not onServer() then return end
    local complex = Entity():getPlan()
    for index,data in ipairs(indexedComplexData) do
        for subfactoryIndex, subfactory in ipairs(data.subFactories) do
            if subfactory.active == true then
                if not complex:getBlock(subfactory.factoryBlockId) then
                    deactivateSubfactory(index, subfactoryIndex)
                    debugPrint(1, subfactory.name.." has been suspended from production in Complex: ", nil, Entity().name, Entity().title)
                    local player = Player(Entity().factionIndex)
                    if player then
                        player:sendChatMessage(Entity().name, 2, subfactory.name.." has been suspended from production in Complex: "..(Entity().name or "null name"))
                    end
                end
            end
        end
    end
end

-- Deactivates a single subfactory. Might also change the total production capacity (size)
function deactivateSubfactory(priority, subfactoryIndex)
    if not onServer() then return end
    if  not indexedComplexData[priority] or
        not indexedComplexData[priority].subfactories[subfactoryIndex] or
        not indexedComplexData[priority].subfactories[subfactoryIndex].acive then print("did not deactivate") return end
    local subfactory = indexedComplexData[priority].subfactories[subfactoryIndex]
    subfactory.active = false
    local totalCapacity = getMaxProductionCapacity(priority)
    if indexedComplexData[priority].size > totalCapacity then
        indexedComplexData[priority].size = totalCapacity
        --TODO send changes in active setting of subfactory and change in Type-size
    else
        --TODO send change in active setting of subfactory
    end
end

-- ######################################################################################################### --
-- ######################################     Both Sided     ############################################# --
-- ######################################################################################################### --




-- ######################################################################################################### --
-- ######################################     Server Sided     ############################################# --
-- ######################################################################################################### --
function startConstruction(constructionData)
    print("return")
    if 1 == 1 then return end
    if not checkEntityInteractionPermissions(Entity(), unpack(mT.permissions[1].requiredPermissions)) then
        debugPrint(0, "Permission mismatch")
        return
    end

    local complex = Entity()
    local addedFactory = Entity(constructionData[0].targetID)
    local newComplex = complex:getPlan()
    local addedFactoryPlan = addedFactory:getPlan()

    local timer = Timer()
    timer:start()
    local player = Player(callingPlayer)
    if (newComplex:getBlock(constructionData[1].BlockID)
    or newComplex:getBlock(constructionData[1].BlockID)
    or newComplex:getBlock(constructionData[1].BlockID)
    or newComplex:getBlock(constructionData[1].BlockID)) then
        debugPrint(0, "[CRITICAL] faulty complex construction data send. No changes were made")
        player:sendChatMessage(complex.title, 3, "Could not add "..(addedFactory.translatedTitle or "error"))
        return
    end
    timer:stop()
    debugPrint(4, "Time check", nil, "took ".. timer.microseconds/1000 .."ms for faulty complexdata check" )
    local moneyPlan = BlockPlan()
    moneyPlan:addBlock(tableToVec3(constructionData[1].position), tableToVec3(constructionData[1].size), constructionData[1].rootID, constructionData[1].BlockID, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)
    moneyPlan:addBlock(tableToVec3(constructionData[2].position), tableToVec3(constructionData[2].size), constructionData[2].rootID, constructionData[2].BlockID, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)
    moneyPlan:addBlock(tableToVec3(constructionData[3].position), tableToVec3(constructionData[3].size), constructionData[3].rootID, constructionData[3].BlockID, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)
    moneyPlan:addBlock(tableToVec3(constructionData[4].position), tableToVec3(constructionData[4].size), constructionData[4].rootID, constructionData[4].BlockID, ColorRGB(0.5, 0.0, 0.0), Material(MaterialType.Trinium) , Matrix(), BlockType.Armor)
    -- get the money required for the plan
    local requiredMoney = moneyPlan:getMoneyValue()
    local requiredResources = {moneyPlan:getResourceValue()}
    local canPay, msg, args = player:canPay(requiredMoney, unpack(requiredResources))
    if not canPay then -- if there was an error, print it
        player:sendChatMessage(complex.title, 1, msg, unpack(args))
        return
    end

    -- check for config.maxBlockCountMultiplier

    -- let the player pay
    player:pay("",requiredMoney, unpack(requiredResources))
    player:sendChatMessage(complex.title, 0, "Complex Construction begins.")

    --extending Complex from data send
    newComplex:addBlock(tableToVec3(constructionData[1].position), tableToVec3(constructionData[1].size), constructionData[1].rootID, constructionData[1].BlockID, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)
    newComplex:addBlock(tableToVec3(constructionData[2].position), tableToVec3(constructionData[2].size), constructionData[2].rootID, constructionData[2].BlockID, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)
    newComplex:addBlock(tableToVec3(constructionData[3].position), tableToVec3(constructionData[3].size), constructionData[3].rootID, constructionData[3].BlockID, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)
    newComplex:addBlock(tableToVec3(constructionData[4].position), tableToVec3(constructionData[4].size), constructionData[4].rootID, constructionData[4].BlockID, ColorRGB(0.5, 0.0, 0.0), Material(MaterialType.Trinium) , Matrix(), BlockType.Armor)
    --adding new Station
    newComplex:addPlanDisplaced(constructionData[4].blockID, addedFactoryPlan, addedFactoryPlan.rootIndex, tableToVec3(constructionData[4].position))
    --set new Complex
    complex:setMovePlan(newComplex)
    local subfactory = {
        factoryBlockId = constructionData[4].rootID,
        relativeCoords = tableToVec3(constructionData[4].position),
        nodeOffset = tableToVec3(constructionData.nodeOffset)
    }
    addFactory(addedFactory, subfactory)
    --carry over Crew and Storage

    local crew = addedFactory.crew
    for crewman, num in pairs(crew:getMembers()) do
        complex:addCrew(num, crewman)
    end

    local facGoods = addedFactory:getCargos()
    for tg,num in pairs(facGoods)do
        complex:addCargo(tg, num)
    end
    addedFactory:destroyCargo(addedFactory.maxCargoSpace)

    Sector():deleteEntityJumped(addedFactory)


    if Entity():hasScript(FSCRIPT) then
        Entity():removeScript(FSCRIPT)
    end
    if not Entity():hasScript(CFSCRIPT) then
        Entity():addScript(CFSCRIPT)
    end
    debugPrint(3, "sending indexedComplexData to Client:", indexedComplexData)
    complex:waitUntilAsyncWorkFinished()


    Entity():invokeFunction(CFSCRIPT, "setComplexData", indexedComplexData)
    Entity():setValue("confighanged", 1)
end

function restore(restoreData)
    if restoreData.indexedComplexData and next(restoreData.indexedComplexData) then
        local k,v = next(restoreData.indexedComplexData)
        if restoreData.indexedComplexData[k].production then
            indexedComplexData = restoreData.indexedComplexData
        else
            print("Old Complex ?")
            return
        end
    end
    productionData = restoreData.productionData
end

function secure()
    local savedata = {}

    savedata["productionData"] = productionData
    savedata["indexedComplexData"] = indexedComplexData
    return savedata
end
