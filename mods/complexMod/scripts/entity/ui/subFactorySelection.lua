local se = require ("mods.complexMod.scripts.lib.stationextensionLib")

-- subfactory selection
--local factorySelectionWindow
local factorySelector
local stationExtensionChecked
local factoryMap = {}
local factoryDisplayer
local selectedAsteroid
local factoryPlan
local blockCountLabel

--Design selection
local shipSelectionWindow
local selectDesignButton
local acceptDesignbutton
local cancelDesignButton
local planSelection
local selectionPlandisplayer
local customPlan


function initSFUI(tabWindow)
    local size = vec2(1100, 900)
    local res = getResolution()
    factorySelectionWindow = tabWindow:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    factorySelectionWindow.caption = "Factory Selection"%_t
    factorySelectionWindow.showCloseButton = 1
    factorySelectionWindow.moveable = 1
    factorySelectionWindow.visible = false

    factorySelectionWindow:createCheckBox(Rect(10,10,150,35), "Station-Extensions", "onStationExtensionsChecked")
    local cb = factorySelectionWindow:createCheckBox(Rect(160,10,300,35), "Custom Designs", "onCustomDesignsChecked")
    cb:setCheckedNoCallback(false)
    --custom designs
    selectDesignButton = factorySelectionWindow:createButton(Rect(310,10,450,35), "Select Design"%_t, "onDesignButtonPress")
    selectDesignButton.active = false

    blockCountLabel = factorySelectionWindow:createLabel(vec2(450, 10), "#error"%_t, 12)
    blockCountLabel.wordBreak = false

    factorySelector = factorySelectionWindow:createListBox(Rect(10, 40, 250, size.y - 80))
    addFactoriesToSelection(factorySelector)
    factorySelector.onSelectFunction = "onFactorySelected"

    factorySelectionWindow:createButton(Rect(20, size.y-60, 240, size.y-25), "Chose this Factory", "onFactoryChoosePressed")

    factoryDisplayer = factorySelectionWindow:createPlanDisplayer(Rect(270, 40, factorySelectionWindow.size.x -20, factorySelectionWindow.size.y-20))
    factoryDisplayer.showStats = 0
    factoryDisplayer.autoCenter = 0
    factoryDisplayer.center = vec3(0,0,0)
    factoryDisplayer.autoRotationSpeed = 0

    -- borrowed from advanced Shipyard mod
    shipSelectionWindow = factorySelectionWindow:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))

    shipSelectionWindow.caption = "Select your Design"%_t
    shipSelectionWindow.showCloseButton = 1
    shipSelectionWindow.moveable = 1
    shipSelectionWindow.visible = 0

    acceptDesignbutton = shipSelectionWindow:createButton(Rect(vec2(10, shipSelectionWindow.size.y-50), vec2(90, shipSelectionWindow.size.y-10)), "Select", "onPlanSelectedPressed")
    cancelDesignButton = shipSelectionWindow:createButton(Rect(vec2(110, shipSelectionWindow.size.y-50), vec2(190, shipSelectionWindow.size.y-10)), "Unselect", "onDesignCancelPressed")

    planSelection = shipSelectionWindow:createSavedDesignsSelection(Rect(vec2(10, 10), vec2(shipSelectionWindow.size.x/2, shipSelectionWindow.size.y - 100)), 5)
    planSelection.dropIntoSelfEnabled = false
    planSelection.dropIntoEnabled = false
    planSelection.dragFromEnabled = false
    planSelection.entriesSelectable = true
    planSelection.onSelectedFunction = "onDesignSelected"
    planSelection.padding = 4

    selectionPlandisplayer = shipSelectionWindow:createPlanDisplayer(Rect(vec2(shipSelectionWindow.size.x/2, 0), vec2(shipSelectionWindow.size.x, shipSelectionWindow.size.y - 100)))

end

function addFactoriesToSelection()
    -- TODO ? sort by most relevant resource-fulfiller > producer-from-results > unconnected
    local ownedEntities = {Sector():getEntitiesByFaction(Entity().factionIndex)}
    local listchanged = valid(selectedAsteroid)
    selectedAsteroid = nil
    for _,e in ipairs(ownedEntities) do
        if e.type == EntityType.Asteroid then
            if e:hasScript("data/scripts/entity/minefounder.lua") then  -- claimed Asteroids
                listchanged = not listchanged
                selectedAsteroid = e
                break
            end
        elseif e.type == EntityType.Station and e:hasScript("data/scripts/entity/merchants/factory.lua") then -- already set up mines
            --selectedAsteroid = e
        end
    end
    if listchanged or factorySelector.rows < 1 then
        factoryMap = {}
        factorySelector:clear()
        for _,prod in ipairs(productions) do
            if (config.mines == true or valid(selectedAsteroid)) or not (string.match(prod.factory, "Mine") or string.match(prod.factory, "Oil Rig")) then
                local name = getTranslatedFactoryName(prod)
                table.insert(factoryMap, prod)
                factorySelector:addEntry(name)
            end
        end
    end
end

function onFactorySelectionPressed(button)
    factorySelectionWindow.visible = true
end

function onCustomDesignsChecked(cb)
    print("Custom Desgin checked", cb.checked)
    selectDesignButton.active = cb.checked
    if cb.checked == false then
        customPlan = nil
        onFactorySelected()
    end
end

function onStationExtensionsChecked(cb)
    print("Station extension checked", cb.checked)
    stationExtensionChecked = cb.checked
    onFactorySelected()
end

-- borrowed from my advanced Shipyard mod
function onDesignSelected()
    local planItem = planSelection.selected
    if not planItem then
        displayChatMessage("You have no plan selected."%_t, "Complex"%_t, 1)
        return
    end
    if planItem.type ~= SavedDesignType.CraftDesign then
        displayChatMessage("You may only select ship blueprints."%_t, "Complex"%_t, 1)
        return
    end

    local plan = planItem.plan
    if not plan then return end
    --customPlan = plan
    selectionPlandisplayer.plan = plan
    print("Custom Plan selected")
end

function onDesignButtonPress()
    shipSelectionWindow.visible = 1
    planSelection:refreshTopLevelFolder()
end

function onDesignCancelPressed()
    shipSelectionWindow.visible = 0
    planSelection:unselect()
    customPlan = nil
    onFactorySelected()
end

function onPlanSelectedPressed()
    shipSelectionWindow.visible = 0
    if planSelection.selected and planSelection.selected.plan then
        customPlan = planSelection.selected.plan
    end
    print("Plan Selected choosen")
    onFactorySelected()
end


function onFactorySelected()
    if factorySelector.selected == -1 then return end
    local name = factorySelector:getSelectedEntry()
    local production = factoryMap[factorySelector.selected+1]
    local tip = name .. "\n"

    local str = ""
    for _,p in ipairs(production.ingredients) do str = str.."-"..tostring(p.amount).."x  "..p.name.."\n" end
    if str ~= "" then tip = tip .. "Ingredients\n".. str end
    str = ""
    for _,p in ipairs(production.results) do str = str.."+"..tostring(p.amount).."x  "..p.name.."\n" end
    if str ~= "" then tip = tip .. "Results\n" .. str end
    str = ""
    for _,p in ipairs(production.garbages) do str = str.."+"..tostring(p.amount).."x  "..p.name.."\n" end
    if str ~= "" then tip = tip .. "Garbages\n" .. str end
    tip = tip..createMonetaryString(getFactoryCost(production)).."Cr"
    factorySelector.tooltip = tip

    local arms = 1
    local plan = BlockPlan()
    plan:addBlock(vec3(0,0,0), vec3(5,5,5), plan.rootIndex, -1, ColorInt(rootBlockColor), Material(MaterialType.Trinium) , Matrix(), BlockType.Armor)
    if customPlan then
        plan:addPlanDisplaced(plan.rootIndex, customPlan, customPlan.rootIndex, vec3(0,0,0))
    end
    if stationExtensionChecked == true then
        if string.match(production.factory, "Solar") then
            print("solar")
            plan = se.addSolarPanels(plan, arms)
        end

        if string.match(production.factory, "Farm") or string.match(production.factory, "Ranch") then
            print("Farm")
            local x = 4 + math.floor(arms * 2.5)
            local y = 5 + arms * 4

            plan = se.addFarmingCenters(plan, arms, x, y)
        end

        if string.match(production.factory, "Factory")
            or string.match(production.factory, "Manufacturer")
            or string.match(production.factory, "Extractor") then

            print("Fac, Manu, Extr")
            local x = 4 + math.floor(arms * 1.5)
            local y = 5 + arms * 2

            plan = se.addProductionCenters(plan, arms, x, y)
        end

        if string.match(production.factory, "Collector") then
            print("collector")
            plan = se.addCollectors(plan, arms)
        end

        if string.match(production.factory, "Mine") or string.match(production.factory, "Oil Rig") then
            print("Mine")
            if selectedAsteroid ~= nil then
                local asteroid = selectedAsteroid:getPlan()
                plan:addPlanDisplaced(plan.rootIndex, asteroid, asteroid.rootIndex, vec3(0,0,0))

            end
            --plan = se.addAsteroid(plan)
        end
    end
    factoryDisplayer.plan = plan
    factoryPlan = plan
    local rootB = plan:getBlock(plan.rootIndex)
    blockCountLabel.caption = tostring(factoryPlan.numBlocks).."  Blocks"
    --addFactoriesToSelection()
end

function onFactoryChoosePressed(button)
    factorySelectionWindow.visible = false
    if factorySelector.selected == -1 then return end
    setAddedPlan(factoryPlan)
    updatePlan()
    print("factory choosen")
end
