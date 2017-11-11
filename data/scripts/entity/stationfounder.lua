package.path = package.path .. ";data/scripts/lib/?.lua"
require ("galaxy")
require ("utility")
require ("faction")
require ("productions")
require ("stringutility")
require ("goods")
require ("defaultscripts")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace StationFounder
StationFounder = {}

local productionsByButton = {}
local stationsByButton = {}
local selectedProduction = {}
local selectedStation

local warnWindow
local warnWindowLabel

local calculateConsumerValue = function(collected)
    local sum = 0

    for _, name in pairs(collected) do
        local good = goods[name]
        if good then
            sum = sum + good.price
        end
    end

    local base = 5000000

    return base + round(math.sqrt(sum * 2500) / 10) * 10000
end

local stations =
{
    {
        name = "Biotope"%_t,
        tooltip = "The population on this station buys and consumes a range of organic goods. These goods can be picked up for free by the owner of the station. Attracts NPC traders."%_t,
        scripts = {{script = "data/scripts/entity/merchants/biotope.lua"}},
        getPrice = function()
            return calculateConsumerValue({"Food", "Food Bar", "Fungus", "Wood", "Glass", "Sheep", "Cattle", "Wheat", "Corn", "Rice", "Vegetable", "Water", "Coal"})
        end
    },
    {
        name = "Casino"%_t,
        tooltip = "The population on this station buys and consumes a range of luxury goods. These goods can be picked up for free by the owner of the station. Attracts NPC traders."%_t,
        scripts = {{script = "data/scripts/entity/merchants/casino.lua"}},
        getPrice = function()
            return calculateConsumerValue({"Beer", "Wine", "Liquor", "Food", "Luxury Food", "Water", "Medical Supplies"})
        end
    },
    {
        name = "Habitat"%_t,
        tooltip = "The population on this station buys and consumes a range of common day to day goods. These goods can be picked up for free by the owner of the station. Attracts NPC traders."%_t,
        scripts = {{script = "data/scripts/entity/merchants/habitat.lua"}},
        getPrice = function()
            return calculateConsumerValue({"Beer", "Wine", "Liquor", "Food", "Tea", "Luxury Food", "Spices", "Vegetable", "Fruit", "Cocoa", "Coffee", "Wood", "Meat", "Water"})
        end
    },
    {
        name = "Equipment Dock"%_t,
        tooltip = "Buys and sells upgrades, turrets and fighters. The owner of the equipment dock gets 20% of the money of every transaction, as well as cheaper prices."%_t .. "\n\n" ..
                  "The population on this station buys and consumes a range of technological goods. These goods can be picked up for free by the owner of the station. Attracts NPC traders."%_t,
        scripts = {
            {script = "data/scripts/entity/merchants/equipmentdock.lua"},
            {script = "data/scripts/entity/merchants/turretmerchant.lua"},
            {script = "data/scripts/entity/merchants/fightermerchant.lua"},
            {script = "data/scripts/entity/merchants/consumer.lua", args = {EquipmentDockConsumerArguments()}},
        },
        getPrice = function()
            return 25000000 +
                calculateConsumerValue({EquipmentDockConsumerArguments()})
        end
    },
    {
        name = "Fighter Factory"%_t,
        tooltip = "Produces custom fighters. The owner of the factory gets 20% of the money of every transaction, as well as cheaper prices."%_t,
        scripts = {{script = "data/scripts/entity/merchants/fighterfactory.lua"}},
        price = 35000000
    },
    -- {
    --     name = "Headquarters"%_t,
    --     tooltip = "Can be used as headquarters for an alliance. [Not yet implemented.]"%_t,
    --     scripts = {{script = "data/scripts/entity/merchants/headquarters.lua"}},
    --     price = 5000000
    -- },
    {
        name = "Research Station"%_t,
        tooltip = "Upgrades and turrets can be researched here to get better upgrades and turrets."%_t .. "\n\n" ..
                  "The population of this station buys and consumes a range of science goods. These goods can be picked up for free by the owner of the station. Attracts NPC traders."%_t,
        scripts = {
            {script = "data/scripts/entity/merchants/researchstation.lua"},
            {script = "data/scripts/entity/merchants/consumer.lua", args = {ResearchStationConsumerArguments()}},
        },
        getPrice = function()
            return 5000000 +
                    calculateConsumerValue({ResearchStationConsumerArguments()})
        end
    },
    {
        name = "Resource Depot"%_t,
        tooltip = "Sells and buys resources such as Iron or Titanium and the like. The owner gets 20% of every transaction, as well as cheaper prices."%_t,
        scripts = {{script = "data/scripts/entity/merchants/resourcetrader.lua"}},
        price = 15000000
    },
    {
        name = "Smuggler's Market"%_t,
        tooltip = "Sells and buys stolen and other illegal goods. The owner gets 20% of every transaction, as well as cheaper prices."%_t,
        scripts = {{script = "data/scripts/entity/merchants/smugglersmarket.lua"}},
        price = 25000000
    },
    {
        name = "Trading Post"%_t,
        tooltip = "Sells and buys a random range of goods. The owner gets 20% of every transaction, as well as cheaper prices. Attracts NPC traders."%_t,
        scripts = {{script = "data/scripts/entity/merchants/tradingpost.lua"}},
        price = 25000000
    },
    {
        name = "Turret Factory"%_t,
        tooltip = "Produces customized turrets and sells turret parts for high prices. The owner gets 20% of every transaction, as well as cheaper prices."%_t,
        scripts = {{script = "data/scripts/entity/merchants/turretfactory.lua"}},
        price = 30000000
    },
    {
        name = "Military Outpost"%_t,
        tooltip = "Provides combat missions to players."%_t .. "\n\n" ..
                  "The population on this station buys and consumes a range of military goods. These goods can be picked up for free by the owner of the station. Attracts NPC traders."%_t,
        scripts = {
            {script = "data/scripts/entity/merchants/militaryoutpost.lua"},
            {script = "data/scripts/entity/merchants/consumer.lua", args = {MilitaryOutpostConsumerArguments()}},
        },
        getPrice = function()
            return calculateConsumerValue({MilitaryOutpostConsumerArguments()})
        end
    },

    {
        name = "Shipyard"%_t,
        tooltip = "Builds ships. The owner gets the production fee paid by other players. Production fee is free for the owner of the shipyard."%_t .. "\n\n" ..
                  "The population on this station buys and consumes a range of technological goods. These goods can be picked up for free by the owner of the station. Attracts NPC traders."%_t,
        scripts = {
            {script = "data/scripts/entity/merchants/shipyard.lua"},
            {script = "data/scripts/entity/merchants/repairdock.lua"},
            {script = "data/scripts/entity/merchants/consumer.lua", args = {ShipyardConsumerArguments()}},
        },
        getPrice = function()
            return 20000000 +
                    calculateConsumerValue({ShipyardConsumerArguments()})
        end
    },
    {
        name = "Repair Dock"%_t,
        tooltip = "Repairs ships. The owner gets 20% of every transaction, as well as cheaper prices."%_t .. "\n\n" ..
                  "The population on this station buys and consumes a range of technological goods. These goods can be picked up for free by the owner of the station. Attracts NPC traders."%_t,
        scripts = {
            {script = "data/scripts/entity/merchants/repairdock.lua"},
            {script = "data/scripts/entity/merchants/consumer.lua", args = {RepairDockConsumerArguments()}},
        },
        getPrice = function()
            return 10000000 +
                    calculateConsumerValue({RepairDockConsumerArguments()})
        end
    },
}

-- if this function returns false, the script will not be listed in the interaction window on the client,
-- even though its UI may be registered
--
function StationFounder.interactionPossible(playerIndex, option)

    if checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FoundStations) then
        return true, ""
    end

    return false
end

function StationFounder.getIcon()
    return "data/textures/icons/flying-flag.png"
end


-- this function gets called on creation of the entity the script is attached to, on client and server
--function initialize()
--
--end

-- this function gets called on creation of the entity the script is attached to, on client only
-- AFTER initialize above
-- create all required UI elements for the client side
function StationFounder.initUI()
    local res = getResolution()
    local size = vec2(650, 575)

    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))

    window.caption = "Transform to Station"%_t
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "Found Station"%_t);

    -- create a tabbed window inside the main window
    local tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 10), size - 10))

    -- create buy tab
    local buyTab0 = tabbedWindow:createTab("Basic"%_t, "data/textures/icons/factory-arm.png", "Basic Factories"%_t)
    local buyTab1 = tabbedWindow:createTab("Low"%_t, "data/textures/icons/factory-arm.png", "Low Tech Factories"%_t)
    local buyTab2 = tabbedWindow:createTab("Advanced"%_t, "data/textures/icons/factory-arm.png", "Advanced Factories"%_t)
    local buyTab3 = tabbedWindow:createTab("High"%_t, "data/textures/icons/factory-arm.png", "High Tech Factories"%_t)
    local buyTab4 = tabbedWindow:createTab("Other Stations"%_t, "data/textures/icons/stars-stack.png", "Other Stations"%_t)

    StationFounder.buildMiscStationGui(buyTab4)
    StationFounder.buildFactoryGui({0}, buyTab0)
    StationFounder.buildFactoryGui({1, 2, 3}, buyTab1)
    StationFounder.buildFactoryGui({4, 5, 6}, buyTab2)
    StationFounder.buildFactoryGui({7, 8, 9}, buyTab3)

    -- warn box
    local size = vec2(550, 230)
    warnWindow = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    warnWindow.caption = "Confirm Transformation"%_t
    warnWindow.showCloseButton = 1
    warnWindow.moveable = 1
    warnWindow.visible = false

    local hsplit = UIHorizontalSplitter(Rect(vec2(), warnWindow.size), 10, 10, 0.5)
    hsplit.bottomSize = 40

    warnWindow:createFrame(hsplit.top)

    local ihsplit = UIHorizontalSplitter(hsplit.top, 10, 10, 0.5)
    ihsplit.topSize = 20

    local label = warnWindow:createLabel(ihsplit.top.lower, "Warning"%_t, 16)
    label.size = ihsplit.top.size
    label.bold = true
    label.color = ColorRGB(0.8, 0.8, 0)
    label:setTopAligned();

    warnWindowLabel = warnWindow:createLabel(ihsplit.bottom.lower, "Text"%_t, 14)
    warnWindowLabel.size = ihsplit.bottom.size
    warnWindowLabel:setTopAligned();


    local vsplit = UIVerticalSplitter(hsplit.bottom, 10, 0, 0.5)
    warnWindow:createButton(vsplit.left, "OK"%_t, "onConfirmTransformationButtonPress")
    warnWindow:createButton(vsplit.right, "Cancel"%_t, "onCancelTransformationButtonPress")


end

function StationFounder.buildMiscStationGui(tab)
    -- make levels a table with key == value

    -- create background
    local frame = tab:createScrollFrame(Rect(vec2(), tab.size))
    frame.scrollSpeed = 40
    frame.paddingBottom = 17


    local count = 0
    for index, station in pairs(stations) do

        local stationName = station.name

        local padding = 10
        local height = 30
        local width = frame.size.x - padding * 4

        local lower = vec2(padding, padding + ((height + padding) * count))
        local upper = lower + vec2(width, height)

        local rect = Rect(lower, upper)

        local vsplit = UIVerticalSplitter(rect, 10, 0, 0.8)
        vsplit.rightSize = 100

        local button = frame:createButton(vsplit.right, "Transform"%_t, "onFoundStationButtonPress")
        button.textSize = 16
        button.bold = false

        frame:createFrame(vsplit.left)

        vsplit = UIVerticalSplitter(vsplit.left, 10, 7, 0.7)

        local label = frame:createLabel(vsplit.left.lower, stationName, 14)
        label.size = vec2(vsplit.left.size.x, vsplit.left.size.y)
        label:setLeftAligned()

        label.tooltip = station.tooltip or ""

        local costs = StationFounder.getStationCost(station)

        local label = frame:createLabel(vsplit.right.lower, createMonetaryString(costs) .. " Cr"%_t, 14)
        label.size = vec2(vsplit.right.size.x, vsplit.right.size.y)
        label:setRightAligned()

        stationsByButton[button.index] = index

        count = count + 1
    end

end

function StationFounder.buildFactoryGui(levels, tab)

    -- make levels a table with key == value
    local l = {}
    for _, v in pairs(levels) do
        l[v] = v
    end
    levels = l

    -- create background
    local frame = tab:createScrollFrame(Rect(vec2(), tab.size))
    frame.scrollSpeed = 40
    frame.paddingBottom = 17

    local usedProductions = {}
    local possibleProductions = {}

    for _, productions in pairs(productionsByGood) do

        for index, production in pairs(productions) do

            -- mines shouldn't be built just like that, they need asteroids
            if not string.match(production.factory, "Mine") then

                -- read data from production
                local result = goods[production.results[1].name];

                -- only insert if the level is in the list
                if levels[result.level] ~= nil and not usedProductions[production.index] then
                    usedProductions[production.index] = true
                    table.insert(possibleProductions, {production=production, index=index})
                end
            end
        end
    end

    local comp = function(a, b)
        local nameA = a.production.factory
        if a.production.fixedName == false then
            nameA = a.production.results[1].name%_t .. " " .. nameA%_t
        end

        local nameB = b.production.factory
        if b.production.fixedName == false then
            nameB = b.production.results[1].name%_t .. " " .. nameB%_t
        end

        return nameA < nameB
    end

    table.sort(possibleProductions, comp)

    local count = 0
    for _, p in pairs(possibleProductions) do

        local production = p.production
        local index = p.index

        local result = goods[production.results[1].name];
        local factoryName = getTranslatedFactoryName(production)

        local padding = 10
        local height = 30
        local width = frame.size.x - padding * 4

        local lower = vec2(padding, padding + ((height + padding) * count))
        local upper = lower + vec2(width, height)

        local rect = Rect(lower, upper)

        local vsplit = UIVerticalSplitter(rect, 10, 0, 0.8)
        vsplit.rightSize = 100

        local button = frame:createButton(vsplit.right, "Transform"%_t, "onFoundFactoryButtonPress")
        button.textSize = 16
        button.bold = false

        frame:createFrame(vsplit.left)

        vsplit = UIVerticalSplitter(vsplit.left, 10, 7, 0.7)

        local label = frame:createLabel(vsplit.left.lower, factoryName, 14)
        label.size = vec2(vsplit.left.size.x, vsplit.left.size.y)
        label:setLeftAligned()

        local tooltip = "Produces:\n"%_t
        for i, result in pairs(production.results) do
            if i > 1 then tooltip = tooltip .. "\n" end
            tooltip = tooltip .. " - " .. result.name%_t
        end


        local first = 1
        for _, i in pairs(production.ingredients) do
            if first == 1 then
                tooltip = tooltip .. "\n\n" .. "Requires:"%_t
                first = 0
            end
            tooltip = tooltip .. "\n - " .. i.name%_t
        end
        label.tooltip = tooltip

        local costs = StationFounder.getFactoryCost(production)

        local label = frame:createLabel(vsplit.right.lower, createMonetaryString(costs) .. " Cr"%_t, 14)
        label.size = vec2(vsplit.right.size.x, vsplit.right.size.y)
        label:setRightAligned()


        productionsByButton[button.index] = {goodName = result.name, factory=factoryName, index = index, production = production}

        count = count + 1

    end
end

function StationFounder.onFoundFactoryButtonPress(button)
    selectedProduction = productionsByButton[button.index]
    selectedStation = nil

    warnWindowLabel.caption = "This action is irreversible."%_t .."\n\n" ..
        "You're about to transform your ship into a ${factory}.\n"%_t % {factory = getTranslatedFactoryName(selectedProduction.production)} ..
        "Your ship will become immobile and, if required, will receive production extensions.\n"%_t ..
        "Due to a systems change all turrets will be removed from your station."%_t
    warnWindowLabel.fontSize = 14

    warnWindow:show()
end

function StationFounder.onConfirmTransformationButtonPress(button)
    invokeServerFunction("foundFactory", selectedProduction.goodName, selectedProduction.index)
end


function StationFounder.onFoundStationButtonPress(button)
    selectedStation = stationsByButton[button.index]
    selectedProduction = nil

    local template = stations[selectedStation]

    warnWindowLabel.caption = "This action is irreversible."%_t .."\n\n" ..
        "You're about to transform your ship into a ${stationName}.\n"%_t % {stationName = template.name} ..
        "Your ship will become immobile and, if required, will receive production extensions.\n"%_t ..
        "Due to a systems change all turrets will be removed from your station."%_t
    warnWindowLabel.fontSize = 14

    warnWindow:show()
end

function StationFounder.onConfirmTransformationButtonPress(button)
    if selectedProduction then
        invokeServerFunction("foundFactory", selectedProduction.goodName, selectedProduction.index)
    elseif selectedStation then
        invokeServerFunction("foundStation", selectedStation)
    end
end

function StationFounder.onCancelTransformationButtonPress(button)
    warnWindow:hide()
end

function StationFounder.foundFactory(goodName, productionIndex)

    local buyer, ship, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FoundStations)
    if not buyer then return end

    local settings = GameSettings()
    if settings.maximumPlayerStations > 0 and buyer.numStations >= settings.maximumPlayerStations then
        player:sendChatMessage("Server"%_t, 1, "Maximum station limit per faction (%s) of this server reached!"%_t, settings.maximumPlayerStations)
        return
    end

    local production = productionsByGood[goodName][productionIndex]

    if production == nil then
        player:sendChatMessage("Server"%_t, 1, "The production line you chose doesn't exist."%_t)
        return
    end

    -- check if player has enough money
    local cost = StationFounder.getFactoryCost(production)

    local canPay, msg, args = buyer:canPay(cost)
    if not canPay then
        player:sendChatMessage("Station Founder"%_t, 1, msg, unpack(args))
        return
    end

    local station = StationFounder.transformToStation()
    if not station then return end

    buyer:pay("Paid %1% credits to found a factory."%_T, cost)

    -- make a factory
    station:addScript("data/scripts/entity/merchants/factory.lua", "nothing")
    station:invokeFunction("factory", "setProduction", production, 1)

    -- remove all cargo that might have been added by the factory script
    for cargo, amount in pairs(station:getCargos()) do
        station:removeCargo(cargo, amount)
    end

    -- insert cargo of the ship that founded the station
    for good, amount in pairs(ship:getCargos()) do
        station:addCargo(good, amount)
    end
    package.path = package.path .. ";mods/complexMod/scripts/entity/complexManager.lua"
    station:addScript("mods/complexMod/scripts/entity/complexManager.lua")
end

function StationFounder.foundStation(selected)

    local buyer, ship, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FoundStations)
    if not buyer then return end

    local settings = GameSettings()
    if settings.maximumPlayerStations > 0 and buyer.numStations >= settings.maximumPlayerStations then
        player:sendChatMessage("Server"%_t, 1, "Maximum station limit per faction (%s) of this server reached!"%_t, settings.maximumPlayerStations)
        return
    end

    local template = stations[selected]

    if template == nil then
        player:sendChatMessage("Server"%_t, 1, "The station you chose doesn't exist."%_t)
        return
    end

    -- check if player has enough money
    local cost = StationFounder.getStationCost(template)

    local canPay, msg, args = buyer:canPay(cost)
    if not canPay then
        player:sendChatMessage("Station Founder"%_t, 1, msg, unpack(args))
        return
    end

    local station = StationFounder.transformToStation()
    if not station then return end

    buyer:pay(Format("Paid %2% credits to found a %1%."%_T, template.name), cost)

    -- make a factory
    for _, script in pairs(template.scripts) do
        local path = script.script
        local args = script.args or {}

        station:addScript(path, unpack(args))
    end

    -- remove all cargo that might have been added by scripts
    for cargo, amount in pairs(station:getCargos()) do
        station:removeCargo(cargo, amount)
    end

    -- insert cargo of the ship that founded the station
    for good, amount in pairs(ship:getCargos()) do
        station:addCargo(good, amount)
    end

end


function StationFounder.transformToStation()

    local ship = Entity()
    local player = Player(callingPlayer)

    -- transform ship into station
    -- has to be at least 2 km from the nearest station
    local sector = Sector()

    local stations = {sector:getEntitiesByType(EntityType.Station)}
    local ownSphere = ship:getBoundingSphere()
    local minDist = 300
    local tooNear

    for _, station in pairs(stations) do
        local sphere = station:getBoundingSphere()

        local d = distance(sphere.center, ownSphere.center) - sphere.radius - ownSphere.radius
        if d < minDist then
            tooNear = true
            break
        end
    end

    if tooNear then
        player:sendChatMessage("Server"%_t, 1, "You're too close to another station."%_t)
        return
    end

    -- create the station
    -- get plan of ship
    local plan = ship:getPlan()
    local crew = ship.crew

    -- create station
    local desc = StationDescriptor()
    desc.factionIndex = ship.factionIndex
    desc:setPlan(plan)
    desc.position = ship.position
    desc:addScript("data/scripts/entity/crewboard.lua")
    desc.name = ship.name

    ship.name = ""

    local station = Sector():createEntity(desc)

    AddDefaultStationScripts(station)

    -- this will delete the ship and deactivate the collision detection so the ship doesn't interfere with the new station
    ship:setPlan(BlockPlan())

    -- assign all values of the ship
    -- crew
    station.crew = crew
    station.shieldDurability = ship.shieldDurability

    -- transfer insurance
    local ret, values = ship:invokeFunction("insurance.lua", "getValues")
    if ret == 0 then
        ship:removeScript("insurance.lua")
        station:addScriptOnce("insurance.lua")
        station:invokeFunction("insurance.lua", "restore", values)
    end

    return station
end

function StationFounder.getFactoryCost(production)

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


function StationFounder.getStationCost(station)
    return station.price or station:getPrice()
end


-- this function gets called every time the window is closed on the client
function StationFounder.onCloseWindow()
    warnWindow:hide()
end
