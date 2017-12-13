package.path = package.path .. ";data/scripts/lib/?.lua"
require ("galaxy")
require ("utility")
require ("faction")
require ("productions")
require ("goods")
require ("randomext")
require ("defaultscripts")
require ("stringutility")
Dialog = require("dialogutility")

local productionsByButton = {}
local selectedProduction = {}

local warnWindow
local warnWindowLabel
local inputWindow

-- if this function returns false, the script will not be listed in the interaction window on the client,
-- even though its UI may be registered
--
function interactionPossible(playerIndex, option)

    if checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FoundStations) then
        return true, ""
    end

    return false
end

function getIcon()
    return "data/textures/icons/flying-flag.png"
end


-- this function gets called on creation of the entity the script is attached to, on client and server
--function initialize()
--
--end

-- this function gets called on creation of the entity the script is attached to, on client only
-- AFTER initialize above
-- create all required UI elements for the client side
function initUI()
    local res = getResolution()
    local size = vec2(650, 575)

    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))

    window.caption = "Transform to Mine /*window title*/"%_t
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "Found Mine"%_t);

    -- create a tabbed window inside the main window
    local tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 10), size - 10))

    -- create buy tab
    local buyTab = tabbedWindow:createTab("Mines"%_t, "data/textures/icons/purse.png", "Mines"%_t)

    buildGui({0}, buyTab)

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

    warnWindowLabel = warnWindow:createLabel(ihsplit.bottom.lower, "Text", 14)
    warnWindowLabel.size = ihsplit.bottom.size
    warnWindowLabel:setTopAligned();

    local vsplit = UIVerticalSplitter(hsplit.bottom, 10, 0, 0.5)
    warnWindow:createButton(vsplit.left, "OK"%_t, "onConfirmTransformationButtonPress")
    warnWindow:createButton(vsplit.right, "Cancel"%_t, "onCancelTransformationButtonPress")

    -- input window
    inputWindow = window:createInputWindow()
    inputWindow.onOKFunction = "onNameEntered"
    inputWindow.caption = "Mine Name"%_t
    inputWindow.textBox:forbidInvalidFilenameChars()
    inputWindow.textBox.maxCharacters = 35

end

function buildGui(levels, tab)

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

    local entity = Entity()

    local usedProductions = {}
    local possibleProductions = {}

    for _, productions in pairs(productionsByGood) do

        for index, production in pairs(productions) do

            if string.match(production.factory, "Mine") or string.match(production.factory, "Oil Rig") then

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

    local comp =
        function(a, b)
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

        local index = p.index
        local production = p.production
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

        local tooltip = "Produces:"%_t .. "\n"
        for i, result in pairs(production.results) do
            if i > 1 then tooltip = tooltip .. "\n" end
            tooltip = tooltip .. " - " .. result.name % _t
        end

        local first = 1
        for _, i in pairs(production.ingredients) do
            if first == 1 then
                tooltip = tooltip .. "\n\n".."Requires:"%_t
                first = 0
            end
            tooltip = tooltip .. "\n - " .. i.name % _t
        end
        label.tooltip = tooltip

        local costs = getFactoryCost(production)

        local label = frame:createLabel(vsplit.right.lower, createMonetaryString(costs) .. " Cr", 14)
        label.size = vec2(vsplit.right.size.x, vsplit.right.size.y)
        label:setRightAligned()

        productionsByButton[button.index] = {goodName = result.name, factory = factoryName, index = index, production = production}

        count = count + 1
    end
end

function onFoundFactoryButtonPress(button)
    selectedProduction = productionsByButton[button.index]

    warnWindowLabel.caption = "This action is irreversible."%_t .. "\n\n" ..
        "You're about to transform your asteroid into a ${mine}."%_t % {mine = getTranslatedFactoryName(selectedProduction.production)}

    warnWindowLabel.fontSize = 14

    warnWindow:show()
end

function onConfirmTransformationButtonPress(button)
    inputWindow:show("Please enter a name for your mine:"%_t)
end

function onNameEntered(window, name)
    invokeServerFunction("foundFactory", selectedProduction.goodName, selectedProduction.index, name)
end

function onCancelTransformationButtonPress(button)
    warnWindow:hide()
end

function foundFactory(goodName, productionIndex, name)

    local buyer, asteroid, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FoundStations)
    if not buyer then return end

    local settings = GameSettings()
    if settings.maximumPlayerStations > 0 and buyer.numStations >= settings.maximumPlayerStations then
        player:sendChatMessage("Server"%_t, 1, "Maximum station limit per faction (%s) of this server reached!"%_t, settings.maximumPlayerStations)
        return
    end

    -- don't allow empty names
    name = name or ""
    if name == "" then
        name = "${good} Mine"%_t % {good = goodName}
    end

    if player:ownsShip(name) then
        player:sendChatMessage("Server"%_t, 1, "You already own an object called ${name}."%_t % {name = name})
        return
    end

    local production = productionsByGood[goodName][productionIndex]

    if production == nil then
        player:sendChatMessage("Server"%_t, 1, "The production line you chose doesn't exist."%_t)
        return
    end

    -- check if player has enough money
    local cost = getFactoryCost(production)
    local canPay, msg, args = buyer:canPay(cost)
    if not canPay then
        player:sendChatMessage("Server"%_t, 1, msg, unpack(args))
        return
    end

    buyer:pay("Paid %1% credits to found a mine."%_T, cost)

    local station = transformToStation(asteroid, name)
    if goodName == "Raw Oil" then
        station.title = "Oil Rig"%_t
    else
        station.title = "${good} Mine"%_t % {good = goodName}
    end

    -- make a factory
    station:addScript("data/scripts/entity/merchants/factory.lua", "nothing")

    station:invokeFunction("factory", "setProduction", production, 1)

    -- remove all goods from mine, it should start from scratch
    local stock, max = station:invokeFunction("factory", "getStock", goodName)
    station:invokeFunction("factory", "decreaseGoods", goodName, stock)

    -- remove all cargo that might have been added by the factory script
    for cargo, amount in pairs(station:getCargos()) do
        station:removeCargo(cargo, amount)
    end

    package.path = package.path .. ";mods/complexMod/scripts/entity/complexManager.lua"
    station:addScript("mods/complexMod/scripts/entity/complexManager.lua")
end

function transformToStation(asteroid, name)

    -- create the station
    -- get plan of asteroid
    local plan = asteroid:getMovePlan()

    -- this will delete the asteroid and deactivate the collision detection so the original asteroid doesn't interfere with the new station
    asteroid:setPlan(BlockPlan())

    -- create station
    local desc = StationDescriptor()
    desc.factionIndex = asteroid.factionIndex
    desc:setMovePlan(plan)
    desc.position = asteroid.position
    desc:addScript("data/scripts/entity/crewboard.lua")
    desc.name = name

    local station = Sector():createEntity(desc)

    AddDefaultStationScripts(station)

    return station
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

-- this functions gets called when the indicator of the station is rendered on the client
--function renderUIIndicator(px, py, size)
--
--end

-- this function gets called every time the window is shown on the client, ie. when a player presses F and if interactionPossible() returned 1
-- function onShowWindow()
--
-- end

---- this function gets called every time the window is closed on the client
function onCloseWindow()
    warnWindow:hide()
end

---- this function gets called once each frame, on client and server
--function update(timeStep)
--
--end
--
---- this function gets called once each frame, on client only
--function updateClient(timeStep)
--
--end
--
---- this function gets called once each frame, on server only
--function updateServer(timeStep)
--
--end
--
---- this function gets called whenever the ui window gets rendered, AFTER the window was rendered (client only)
--function renderUI()
--
--end




