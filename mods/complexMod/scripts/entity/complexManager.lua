package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";mods/complexMod/scripts/entity/ui/complexManager/?.lua"
--package.path = package.path .. ";data/scripts/entity/?.lua"
require ("utility")
require ("faction")
require ("defaultscripts")
require ("randomext")
require ("stationextensions")
require ("productions")
require ("goods")
require ("stringutility")
require ("constructionTab")
require ("overviewTab")
require ("tradingTab")
mT = require ("managementTab")
Dialog = require("dialogutility")


VERSION = "[0.89] "
MOD = "[CPX3]"

DEBUGLEVEL = 2

COMPLEXINTEGRITYCHECK = 60   --default every 60 seconds
CFSCRIPT = "mods/complexMod/scripts/entity/merchants/complexFactory.lua"
FSCRIPT = "data/scripts/entity/merchants/factory.lua"
-- Menu items
local window

--UI Renderer
local selectedTab = 1               --1:BCU, 2:ICU, 3:TCU, 4:MCU

--Complex Data
local indexedComplexData = {}   --[priority] = {["factoryBlockId"] = num, ["relativeCoords"] = vec3(x,y,z), ["nodeOffset"] = vec3(x,y,z), ["factoryTyp"] = {}, ["size"] = num, ["name"] = ""}
local currentNodeID
local currentNodeOffset = vec3(0,0,0)
local targetCoreBlockIndex
local targetCoreBlockCoord
local productionData = {}
local constructionData = {}     --{[buildorder] = {["BlockID"]= num, ["position"] = {x,y,z}, ["size"] = {x,y,z}, ["rootID"] = rootID}}}
local bonusValues = {}

local timepassedAfterLastCheck = 65

permissions = mT.permissions



function debugPrint(debuglvl, msg, tableToPrint, ...)
    if debuglvl <= DEBUGLEVEL then
        print(MOD..VERSION..msg, ...)
        if type(tableToPrint) == "table" then
            printTable(tableToPrint)
        end
    end
end

function initialize()
    local station = Entity()

    if not station:hasScript(CFSCRIPT) then
        station:addScript(CFSCRIPT)
    end
    if onClient() then
        if not station:hasScript(FSCRIPT) then
            EntityIcon().icon = "data/textures/icons/pixel/crate.png"
        end
        InteractionText(station.index).text = Dialog.generateStationInteractionText(station, random())
    else
        mT.initialize()
    end

end

function getIcon()
    return "data/textures/icons/blockstats.png"
end


-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function interactionPossible(playerIndex, option)
    if checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations) then
        return true
    else
        --displayChatMessage("You need the Factionpermission: Manage Stations", Faction().name, 3)
        return false
    end
end

-- create all required UI elements for the client side
function initUI()

    local res = getResolution()*0.9
    local size = vec2(1100, 800)

    synchComplexdata(nil, nil, true)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(getResolution()*0.5 - res * 0.5, getResolution()*0.5 + res*0.5))

    window.caption = "Complex Manager "%_t..Entity().name
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "Manage Complex"%_t);
    local tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 10), window.size))
    tabbedWindow.onSelectedFunction = "onSelectedFunction"
--===============================================================================Build Complex UI======================================================================================================
    local constructionTab = tabbedWindow:createTab("BCU"%_t, "data/textures/icons/brick-pile.png", "Complex Construction"%_t)
    createConstructionUI(constructionTab)

--===============================================================================Info Complex UI=======================================================================================================
    local infoTab = tabbedWindow:createTab("ICU"%_t, "data/textures/icons/blockstats.png", "Complex Overview"%_t)
    createOverviewUI(infoTab)

--===============================================================================Trading Complex UI====================================================================================================
    local tradingTab = tabbedWindow:createTab("TCU"%_t, "data/textures/icons/trade.png", "Complex Trading Overview"%_t)
    createTradingUI(tradingTab)
--===============================================================================Manage Complex UI====================================================================================================
    local managementTab = tabbedWindow:createTab("MCU"%_t, "data/textures/icons/auto-repair.png", "Complex Management"%_t)
    mT.createManagementUI(managementTab)
end

-- this function gets called every time the window is shown on the client, ie. when a player presses F
function onShowWindow()
    invokeServerFunction("removeMissingFactories")
    updateStationCombo()
    permissions = mT.getPermissions()
end

function renderUI()
    if selectedTab == 1 then
        cTRenderUI()
    end
end

function getUpdateInterval()
    return 0.05
end

function update(timeStep)                                               --checking if selection in the List has changed
    if onClient() then
        updateCT(timeStep)
        updateOT(timeStep)
        updateTT(timeStep)
    else
        timepassedAfterLastCheck = timepassedAfterLastCheck + timeStep
        if timepassedAfterLastCheck >= COMPLEXINTEGRITYCHECK then
            debugPrint(3,"Complex integrity Check", nil, Entity().name)
            timepassedAfterLastCheck = 0
            if onServer() == true then
                Entity():removeBonus(4321234)--No Entity should have this BlockId
                Entity():addKeyedMultiplyableBias(StatsBonuses.ArmedTurrets,4321234, math.floor(Entity():getPlan():getMoneyValue()/600000))       --adding 1 Turret per 600,000 net worth of the complex
            end
            removeMissingFactories()
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
        updateOTListdataPanel()
     end
     if tabname == "TCU" then
        selectedTab = 3
        Entity():invokeFunction(CFSCRIPT, "synchTradingLists", nil,nil,nil,nil, true)
     end
     if tabname == "MCU" then
        selectedTab = 4
     end
end

function cmOnConstructionButtonPress(constructionData, addedPlan, addedComplexData, basefab)
    if basefab ~= nil then
        indexedComplexData[1] = basefab
    end

    indexedComplexData[#indexedComplexData + 1] = addedComplexData
    invokeServerFunction("startConstruction", constructionData, addedPlan, indexedComplexData, Player().index)
    debugPrint(3, "pre Fab added", indexedComplexData)
end

-- ######################################################################################################### --
-- ######################################     Both Sided     ############################################# --
-- ######################################################################################################### --

-- First synchronise the data, then update the corresponding Classes
function synchSingleComplexdata(priority, data, calledOnServer)
    if priority == nil then debugPrint(3, "synchSingleComplexdata nil found") return end
    if data == nil then debugPrint(3, "Synch single data nil") end
    --vec3 is userdata and gets converted to a Table, when transmitted. This turns tables back to vec3.
    if type(data.nodeOffset) == "table" then
        data.nodeOffset = tableToVec3(data.nodeOffset)
        debugPrint(4, "nodeOffset Table")
    end
    if type(data.relativeCoords) == "table" then
        data.relativeCoords = tableToVec3(data.relativeCoords)
         debugPrint(4, "relativeCoords Table")
    end

    if onServer() == true then
        if calledOnServer == nil then
            invokeClientFunction(Player(), "synchSingleComplexdata", priority, data, true)
        end
        updateSingleComplexdata(priority, data)
    else
        if calledOnServer == nil then
            invokeServerFunction("synchSingleComplexdata", priority, data, false)
        end
        updateSingleComplexdata(priority, data)
    end
end
--requests allow for simple sending without changing data
function synchComplexdata(pIndexedComplexData, calledOnServer, isrequest)
    if onServer() then
        debugPrint(3, "synchronising", indexedComplexData, Entity().index)
    end
    if isrequest == true then
        if onServer() then
            if callingPlayer ~= nil then
                invokeClientFunction(Player(callingPlayer), "synchComplexdata", indexedComplexData, true)
                return
            else
                --broadcastInvokeClientFunction("synchComplexdata", indexedComplexData, true)
                debugPrint(1, "wrong player:", nil, callingPlayer, calledOnServer)
                return
            end
        else
            if indexedComplexData == nil or next(indexedComplexData) == nil then
                invokeServerFunction("synchComplexdata", nil, nil, true)
            else
                updateComplexdata(indexedComplexData)
            end
        end
    end
    if pIndexedComplexData == nil then debugPrint(3, "synchComplexdata is nil") return end
    -- When transmitted, userdata vec3 gets converted to a Table. This turns tables back to vec3.
    for priority, data in pairs(pIndexedComplexData) do
        if type(data.nodeOffset) == "table" then
            data.nodeOffset = tableToVec3(data.nodeOffset)
        end
        if type(data.relativeCoords) == "table" then
            data.relativeCoords = tableToVec3(data.relativeCoords)
        end
        pIndexedComplexData[priority] = data
    end

    if onServer() == true then
        if calledOnServer == nil then
            broadcastInvokeClientFunction("synchComplexdata", pIndexedComplexData, true)
        end
        updateComplexdata(pIndexedComplexData)
    else
        if calledOnServer == nil then
            invokeServerFunction("synchComplexdata", pIndexedComplexData, false)
        end
        updateComplexdata(pIndexedComplexData)
    end
end

function updateSingleComplexdata(priority, data)
    if onServer() == true then
        indexedComplexData[priority] = data
        Entity():invokeFunction(CFSCRIPT, "setComplexData", indexedComplexData)
    else
        indexedComplexData[priority] = data
        updateOTComplexData(indexedComplexData)
        updateComplexdataCT(indexedComplexData)
    end
end

function updateComplexdata(pIndexedComplexData)
    if onServer() == true then
        indexedComplexData = pIndexedComplexData
        mT.transmitComplexNetWorth(pIndexedComplexData)
        local status = Entity():invokeFunction(CFSCRIPT, "setComplexData", indexedComplexData)
        debugPrint(3, "updateComplexdata "..CFSCRIPT.." status:", nil, status)
    else
        indexedComplexData = pIndexedComplexData
        mT.transmitComplexNetWorth(pIndexedComplexData)
        updateOTComplexData(indexedComplexData)
        updateComplexdataCT(indexedComplexData)
        Entity():invokeFunction(CFSCRIPT, "setComplexData", indexedComplexData)
    end
end

function passChangedTradingDataToTT(pTradingData)
    if onServer() == true then
        debugPrint(0, "passing TradingData to Server is not allowed!")
    else
        updateTradingdata(pTradingData)
    end
end

function synchProductionData(pProductionData, calledOnServer)
    debugPrint(3,"sync of ProductionData", pProductionData)
    if onServer() == true then
        if calledOnServer == nil then
            broadcastInvokeClientFunction("synchProductionData", pProductionData, true)
            updateProductionData(pProductionData)
        else
            debugPrint(0,"synchProductionData called from Client - This is not allowed!")
            return
        end
    else
        if calledOnServer == true then
            updateProductionData(pProductionData)
        else
            debugPrint(0,"synchProductionData called on Client- This is not allowed!")
            return
        end
    end
end

function updateProductionData(pProductionData)
    if onServer() == true then
        productionData = pProductionData -- To be able to save it on Sector-unload
    else
        --no need to store it on the clientside. We just pass it directly to the overview-tab
        updateOTFactoryList(pProductionData)
    end
end
-- only bonusType == "GeneratedEnergy"
function addStatBonus(id, bonusType, value)
    if onServer() then
        Entity():removeBonus(id)
        local v = Entity():addKeyedMultiplyableBias(StatsBonuses.GeneratedEnergy, id, value)  --add <factor> to the stat
        bonusValues[id] = value
    else
        invokeServerFunction("addStatBonus", id, bonusType, value)
    end
end

function removeBonus(id)
    if onServer() then
        bonusValues[id] =  nil
        Entity():removeBonus(id)
    else
        invokeServerFunction("removeBonus", id)
    end
end

function updateTradingTab()
    if onServer() then
        debugPrint(0, "updateTradingTab is not allowed on Server")
    else
        updateTradingdata()
    end
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

function vec3ToTable(vec)
    local retTable = {x = vec.x, y = vec.y, z = vec.z}
    return retTable
end

function tableToVec3(tab)
    local vec = vec3(tab.x, tab.y, tab.z)
    return vec
end

function removeMissingFactories()
    local complex = Entity():getPlan()
    local removedSomething = false
    for index,data in pairs(indexedComplexData) do
        local nodeID = data.factoryBlockId
        if not complex:getBlock(nodeID) then
            debugPrint(1, data.name.." has been removed from Complex: ", nil, Entity().name, Entity().title)
            local player = Player(Entity().factionIndex)
            if player then
                player:sendChatMessage( Entity().name, 2, data.name.." has been removed from your Complex: "..Entity().name)
            end
            indexedComplexData[index] = nil
            bonusValues[nodeID] = nil
            removedSomething = true
        end
    end

    if removedSomething == true then
        local t = 1
        local cleanList = {}
        for index,data in pairs(indexedComplexData) do
            cleanList[t] = data
            t = t + 1
        end
        indexedComplexData = cleanList
        if onServer() == true then
            debugPrint(2, "synch Missing fabs")
            synchComplexdata(indexedComplexData)
        else
            debugPrint(0, "removeMissingFactories should not be called onClient")
        end

    end
end
-- ######################################################################################################### --
-- ######################################     Server Sided     ############################################# --
-- ######################################################################################################### --
function startConstruction(pConstructionData, connectorPipePlan, pIndexedComplexData, playerIndex)
    if not checkEntityInteractionPermissions(Entity(), unpack(mT.permissions[1].requiredPermissions)) then
        debugPrint(0, "Permission mismatch")
        updatePlan()
        return
    end
    if pIndexedComplexData == nil or next(pIndexedComplexData) == nil then
        debugPrint(0, "IndexedComplexData incomplete")
        synchComplexdata(indexedComplexData)
        return
    end
    indexedComplexData = pIndexedComplexData
    constructionData = pConstructionData
    local self = Entity()
    local addedFactory = Entity(constructionData[0].targetID)
    local newComplex =self:getPlan()
    local addedFactoryPlan = addedFactory:getPlan()

    local timer = Timer()
    timer:start()
    local player = Player(callingPlayer)
    if (newComplex:getBlock(constructionData[1].BlockID)
    or newComplex:getBlock(constructionData[1].BlockID)
    or newComplex:getBlock(constructionData[1].BlockID)
    or newComplex:getBlock(constructionData[1].BlockID)) then
        debugPrint(0, "[CRITICAL] faulty complex construction data send. No changes were made")
        player:sendChatMessage(self.title, 3, "Could not add "..(addedFactory.translatedTitle or "error"))
        return
    end
    timer:stop()
    debugPrint(4, "Time check", nil, "took ".. timer.microseconds/1000 .."ms for faulty complexdata check" )
    -- get the money required for the plan
    local requiredMoney = connectorPipePlan:getMoneyValue()
    local requiredResources = {connectorPipePlan:getResourceValue()}
    local canPay, msg, args = player:canPay(requiredMoney, unpack(requiredResources))
    if not canPay then -- if there was an error, print it
        player:sendChatMessage(self.title, 1, msg, unpack(args))
        return
    end

    -- let the player pay
    player:pay("",requiredMoney, unpack(requiredResources))
    player:sendChatMessage(self.title, 0, "Complex Construction begins.")

    --extending Complex from data send
    newComplex:addBlock(tableToVec3(constructionData[1].position), tableToVec3(constructionData[1].size), constructionData[1].rootID, constructionData[1].BlockID, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)
    newComplex:addBlock(tableToVec3(constructionData[2].position), tableToVec3(constructionData[2].size), constructionData[2].rootID, constructionData[2].BlockID, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)
    newComplex:addBlock(tableToVec3(constructionData[3].position), tableToVec3(constructionData[3].size), constructionData[3].rootID, constructionData[3].BlockID, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)
    newComplex:addBlock(tableToVec3(constructionData[4].position), tableToVec3(constructionData[4].size), constructionData[4].rootID, constructionData[4].BlockID, ColorRGB(0.5, 0.0, 0.0), Material(MaterialType.Trinium) , Matrix(), BlockType.Armor)
    --adding new Station
    newComplex:addPlanDisplaced(constructionData[4].blockID, addedFactoryPlan, addedFactoryPlan.rootIndex, tableToVec3(constructionData[4].position))
    --set new Complex
    self:setPlan(newComplex)

    --carry over Crew and Storage

    local crew = addedFactory.crew
    for crewman, num in pairs(crew:getMembers()) do
        self:addCrew(num, crewman)
    end

    local facGoods = addedFactory:getCargos()
    for tg,num in pairs(facGoods)do
        self:addCargo(tg, num)
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
    synchComplexdata(indexedComplexData)
    Entity():invokeFunction(CFSCRIPT, "setComplexData", indexedComplexData)
    Entity():setValue("complexChanged", 1)
end

function applyBoni()
    for id,value in pairs(bonusValues) do
        debugPrint(3,"applyBoni", nil, id, value)
        addStatBonus(id, "GeneratedEnergy", value)
    end
end

function restore(restoreData)
    if callingPlayer == nil then
        debugPrint(3,"Manager ", restoreData, Entity().index)
        -- In case of unexpected data corruption we try to restore data from CFSCRIPT
        if (restoreData.indexedComplexData == nil or next(restoreData.indexedComplexData) == nil) and not Entity():hasScript(FSCRIPT) then
            debugPrint(0, "[CRITICAL] Trying to load backup data from "..CFSCRIPT, nil, "On Complex: ".. (Entity().title or "error") .. ", "..(Entity().name or "error"), "in sector:", Sector():getCoordinates() )
            local status, data  = Entity():invokeFunction(CFSCRIPT, "getComplexData2")
            if status == 0 and next(data) then
                debugPrint(0, "[less - CRITICAL] Got data from "..CFSCRIPT, data, ". You lucky Bastard!")
                indexedComplexData = data
            elseif status == 3 then -- Does not have CFSCRIPT, so it's not a complex
            else
                debugPrint(0, "[CRITICAL] Could not load backup data from "..CFSCRIPT..". You poor Bastard!", nil, "On Complex: ".. (Entity().title or "error") .. ", "..(Entity().name or "error"), "in sector:", Sector():getCoordinates() )
            end
        end
        for index, data in pairs(restoreData.indexedComplexData) do
            data.nodeOffset = tableToVec3(data.nodeOffset)
            data.relativeCoords = tableToVec3(data.relativeCoords)
            indexedComplexData[index] = data
        end
        for index, data in pairs(restoreData.productionData) do
            data.nodeOffset = vec3ToTable(data.nodeOffset)
            data.relativeCoords = vec3ToTable(data.relativeCoords)
            productionData[index] = data
        end
        bonusValues = restoreData.bonusValues or {}
        synchComplexdata(indexedComplexData)
        synchProductionData(productionData)
        applyBoni()
    end
end

function secure()
    local savedata = {}
    local pProductionData, pIndexedComplexData = {}, {}
    --Current production Data
    for index, data in pairs(productionData) do
        data.nodeOffset = vec3ToTable(data.nodeOffset)
        data.relativeCoords = vec3ToTable(data.relativeCoords)
        pProductionData[index] = data
    end
    --prioritised Complex Data
    for index, data in pairs(indexedComplexData) do
        data.nodeOffset = vec3ToTable(data.nodeOffset)
        data.relativeCoords = vec3ToTable(data.relativeCoords)
        pIndexedComplexData[index] = data
    end

    savedata["productionData"] = pProductionData
    savedata["indexedComplexData"] = pIndexedComplexData
    savedata.bonusValues = bonusValues
    return savedata
end
