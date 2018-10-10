package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

PlanGenerator = require ("plangenerator")

local se = {}

function se.addCollectors(plan)
    if not plan then
        plan = BlockPlan()
        plan:addBlock(vec3(0,0,0), vec3(1,1,1), -1, -1, ColorRGB(0.35, 0.35, 0.35), Material(MaterialType.Iron), Matrix(), BlockType.CargoBay)
    end
    return plan
end

function se.addConstructionScaffold(plan)
    local o = Matrix()
    local m = Material(MaterialType.Iron)
    local c = ColorRGB(0.35, 0.35, 0.35)
    local blank = BlockType.Hull


    if not plan then
        plan = BlockPlan()
        plan:addBlock(vec3(0,0,0), vec3(1,1,1), -1, -1, c, m, o, BlockType.CargoBay)
    end
    -- create scaffold mesh
    local scaffold = BlockPlan()


    local edge = BlockType.EdgeHull
    local middleDiameter = 2.25
    local middleBlock = 3.5
    local middleLength = 7.5
    local mlong = vec3(middleDiameter, middleDiameter, middleLength)
    local mblock = vec3(middleBlock, middleBlock, middleBlock)

    local longa = vec3(5, 1, 3)
    local longb = vec3(1, 5, 3)
    local longc = vec3(0.75, 5, 2.75)
    local blocka = vec3(2.0, 2.0, 3.5)
    local blockb = vec3(1.5, 1.5, 3.0)

    local hmlong = mlong * 0.5
    local hmblock = mblock * 0.5


    local lmid = -1
    local bmid = -1

    for i = 0, 10 do
        local p = vec3(0, 0, (mlong.z + mblock.z) * i)

        lmid = scaffold:addBlock(p + vec3(0, 0, 0), mlong, bmid, -1, c, m, o, blank)
        bmid = scaffold:addBlock(p + vec3(0, 0, hmlong.z + hmblock.z), mblock, lmid, -1, c, m, o, blank)


        local len = 5.0 - hmblock.x * 0.5
        bmid = scaffold:addBlock(p + vec3(-hmblock.x - len * 0.5, 0, hmlong.z + hmblock.z), vec3(len, middleDiameter, middleDiameter), lmid, -1, c, m, o, blank)

        -- side
        local l = bmid
        p = p + vec3(hmblock.x + longa.x * 0.5, 0, hmlong.z + hmblock.z)

        for j = 0, 4 do -- create a tilted bar from edge blocks
            l = scaffold:addBlock(p + vec3(longa.x * j, longa.y * j,        0), longa, l, -1, c, m, MatrixLookUp(vec3(-1, 0, 0), vec3(0, -1, 0)), edge)
            l = scaffold:addBlock(p + vec3(longa.x * j, longa.y * (j + 1),  0), longa, l, -1, c, m, MatrixLookUp(vec3(1, 0, 0), vec3(0, 1, 0)), edge)
        end

        p = p + vec3(longa.x * 4.5, longa.y * 5, 0)

        l = scaffold:addBlock(p + vec3(blocka.x * 0.5, 0, 0), blocka, l, -1, c, m, o, blank)

        p = p + vec3(blocka.x * 0.5, blocka.y * 0.5 + longb.y * 0.5, 0)

        for j = 0, 2 do -- create a tilted bar from edge blocks
            l = scaffold:addBlock(p + vec3(longb.x * j,         longb.y * j, 0), longb, l, -1, c, m, MatrixLookUp(vec3(1, 0, 0), vec3(0, 1, 0)), edge)
            l = scaffold:addBlock(p + vec3(longb.x * (j + 1),   longb.y * j, 0), longb, l, -1, c, m, MatrixLookUp(vec3(-1, 0, 0), vec3(0, -1, 0)), edge)
        end

        p = p + vec3(longb.x * 3, longb.y * 2.5, 0)

        l = scaffold:addBlock(p + vec3(0, blockb.y * 0.5, 0), blockb, l, -1, c, m, o, blank)

        p = p + vec3(0, blockb.y + longc.y * 0.5, 0)

        for j = 0, 1 do -- create a tilted bar from edge blocks
            l = scaffold:addBlock(p + vec3(-longc.x * j,         longc.y * j, 0), longc, l, -1, c, m, MatrixLookUp(vec3(-1, 0, 0), vec3(0, 1, 0)), edge)
            l = scaffold:addBlock(p + vec3(-longc.x * (j + 1),   longc.y * j, 0), longc, l, -1, c, m, MatrixLookUp(vec3(1, 0, 0), vec3(0, -1, 0)), edge)
        end
    end

    -- mirror the scaffold half
    scaffold:displace(vec3(5, 0, hmlong.z))

    local mirrored = copy(scaffold)
    mirrored:mirror(vec3(1, 0, 0), vec3(0, 0, 0))

    scaffold:addPlan(0, mirrored, 0)

    -- create a connector to add it to the plan
    local connector = scaffold:addBlock(vec3(0, 0, 0), vec3(10 + middleDiameter, middleDiameter, middleDiameter), 0, -1, c, m, o, blank)
    local root = scaffold:addBlock(vec3(0, 0, 0), mblock, connector, -1, c, m, o, blank)

    local highestZ = plan:getNthBlock(0)
    local lowestZ = highestZ

    for i = 1, plan.numBlocks - 1 do
        local block = plan:getNthBlock(i)

        local box = block.box
        if box.size.x >= middleDiameter and box.size.y >= middleDiameter then
            if box.upper.z > highestZ.box.upper.z then highestZ = block end
            if box.lower.z < lowestZ.box.lower.z then lowestZ = block end
        end
    end

    plan:addPlanDisplaced(highestZ.index, scaffold, root, highestZ.box.center + vec3(0, 0, highestZ.box.size.z * 0.5))

    if math.random() < 0.3 then
        -- add to highestZ
        scaffold:rotate(vec3(0, 1, 0), 1)
        scaffold:rotate(vec3(0, 1, 0), 1)

        plan:addPlanDisplaced(lowestZ.index, scaffold, root, lowestZ.box.center - vec3(0, 0, lowestZ.box.size.z * 0.5))
    end

    return plan
end

function se.addProductionCenters(plan, numAdditions, sizeX, sizeY)

    -- create panels mesh
    local panels = BlockPlan()

    local o = Matrix()
    local m = Material(MaterialType.Iron)
    local c = ColorRGB(0.5, 0.5, 0.5)
    local glowColor = ColorHSV(math.random() * 360, math.random(), 1.0)

    local hull = BlockType.Hull

    if not plan then
        plan = BlockPlan()
        plan:addBlock(vec3(0,0,0), vec3(1,1,1), -1, -1, c, m, o, BlockType.CargoBay)
    end

    local middleDiameter = 1
    local middle = vec3(middleDiameter, 10.0, middleDiameter)
    local side = vec3(2.5, 1.0, 1.0)
    local panel = vec3(5.0, 5.0, 1.5)
    local upper = vec3(5.0, 5.0, 1.0)
    local glow = vec3(5.0, 5.0, 0.2)

    local hpanel = panel * 0.5
    local hupper = upper * 0.5
    local hglow = glow * 0.5

    local mid = -1
    local additionals = sizeX or getInt(2, 5)
    local rows = sizeY or getInt(5, 8)

    -- build box
    local box1 = BlockPlan()
    local box2 = BlockPlan()

    local types = {}
    types[0] = 1
    types[1] = 1
    types[2] = 2
    types[3] = 3

    local panelType = getValueFromDistribution(types)

    for _, box in pairs({box1, box2}) do

        local bottom = BlockType.CargoBay
        if box == box2 then bottom = BlockType.Assembly end

        if panelType == 0 then

            local pi = box:addBlock(vec3(0, 0, 0), panel, -1, -1, c, m, o, bottom)
            local ui = box:addBlock(vec3(0, 0, panel.z * 0.5 + glow.z * 0.5), glow, pi, -1, glowColor, m, o, BlockType.Glow)
            local ui = box:addBlock(vec3(0, 0, panel.z * 0.5 + glow.z + upper.z * 0.5), upper, ui, -1, c, m, o, bottom)

        elseif panelType == 1 then

            local pi = box:addBlock(vec3(0, 0, 0), panel, -1, -1, c, m, o, bottom)
            local ui = box:addBlock(vec3(0, 0, panel.z * 0.5 + glow.z * 0.5), glow, pi, -1, glowColor, m, o, BlockType.Glow)
            local ui = box:addBlock(vec3(0, 0, panel.z * 0.5 + glow.z * 1.5), glow, ui, -1, c, m, o, bottom)

            local u = upper * vec3(0.25, 0.25, 1.0)
            local z = panel.z * 0.5 + glow.z * 2.0 + u.z * 0.5

            box:addBlock(vec3(panel.x * 0.25, panel.y * 0.25, z), u, ui, -1, c, m, o, bottom)
            box:addBlock(vec3(-panel.x * 0.25, panel.y * 0.25, z), u, ui, -1, c, m, o, bottom)
            box:addBlock(vec3(-panel.x * 0.25, -panel.y * 0.25, z), u, ui, -1, c, m, o, bottom)
            box:addBlock(vec3(panel.x * 0.25, -panel.y * 0.25, z), u, ui, -1, c, m, o, bottom)

        elseif panelType == 2 then

            local pi = box:addBlock(vec3(0, 0, 0), panel, -1, -1, c, m, o, bottom)
            local ui = box:addBlock(vec3(0, 0, panel.z * 0.5 + glow.z * 0.5), glow, pi, -1, glowColor, m, o, BlockType.Glow)

            local u = upper * vec3(0.5, 0.5, 1.0)
            local z = panel.z * 0.5 + glow.z + u.z * 0.5

            local corners = {BlockType.InnerCornerHull, BlockType.OuterCornerHull}
            local corner = corners[getInt(1, 2)]

            box:addBlock(vec3(panel.x * 0.25, panel.y * 0.25, z), u, ui, -1, c, m, MatrixLookUp(vec3(-1, 0, 0), vec3(0, 0, 1)), corner)
            box:addBlock(vec3(-panel.x * 0.25, panel.y * 0.25, z), u, ui, -1, c, m, MatrixLookUp(vec3(0, -1, 0), vec3(0, 0, 1)), corner)
            box:addBlock(vec3(-panel.x * 0.25, -panel.y * 0.25, z), u, ui, -1, c, m, MatrixLookUp(vec3(1, 0, 0), vec3(0, 0, 1)), corner)
            box:addBlock(vec3(panel.x * 0.25, -panel.y * 0.25, z), u, ui, -1, c, m, MatrixLookUp(vec3(0, 1, 0), vec3(0, 0, 1)), corner)

        elseif panelType == 3 then

            local pi = box:addBlock(vec3(0, 0, 0), panel, -1, -1, c, m, o, bottom)
            local ui = box:addBlock(vec3(0, 0, panel.z * 0.5 + glow.z * 0.5), glow, pi, -1, glowColor, m, o, BlockType.Glow)

            local u = upper * vec3(0.5, 0.5, 1.0)
            local z = panel.z * 0.5 + glow.z + u.z * 0.5

            local corners = {BlockType.InnerCornerHull, BlockType.OuterCornerHull, BlockType.CornerHull}
            local corner = corners[getInt(1, 3)]

            box:addBlock(vec3(panel.x * 0.25, panel.y * 0.25, z), u, ui, -1, c, m, MatrixLookUp(vec3(1, 0, 0), vec3(0, 0, 1)), corner)
            box:addBlock(vec3(-panel.x * 0.25, panel.y * 0.25, z), u, ui, -1, c, m, MatrixLookUp(vec3(0, 1, 0), vec3(0, 0, 1)), corner)
            box:addBlock(vec3(panel.x * 0.25, -panel.y * 0.25, z), u, ui, -1, c, m, MatrixLookUp(vec3(0, -1, 0), vec3(0, 0, 1)), corner)
            box:addBlock(vec3(-panel.x * 0.25, -panel.y * 0.25, z), u, ui, -1, c, m, MatrixLookUp(vec3(-1, 0, 0), vec3(0, 0, 1)), corner)

        end
    end

    -- build the entire production field
    for i = 0, rows - 1 do
        local p = vec3(0, i * 10, 0)

        local box = box1
        if i % 2 == 0 then box = box2 end

        mid = panels:addBlock(p + vec3(0, 0, 0), middle, mid, -1, c, m, o, hull)
        local s1 = panels:addBlock(p + vec3(-side.x * 0.5, 5.0, 0), side, mid, -1, c, m, o, hull)
        local s2 = panels:addBlock(p + vec3(side.x * 0.5, 5.0, 0), side, mid, -1, c, m, o, hull)

        local p1 = panels:addPlanDisplaced(s1, box, 0, p + vec3(-side.x - panel.x * 0.5, 5.0, 0))
        local p2 = panels:addPlanDisplaced(s1, box, 0, p + vec3(side.x + panel.x * 0.5, 5.0, 0))

        for j = 1, additionals do
            local offset = p + vec3((panel.x + side.x) * j, 0, 0)

            s2 = panels:addBlock(offset + vec3(side.x * 0.5, 5.0, 0), side, p2, -1, c, m, o, hull)
            p1 = panels:addPlanDisplaced(s1, box, 0, offset + vec3(side.x + panel.x * 0.5, 5.0, 0))

            local offset = p + vec3(-(panel.x + side.x) * j, 0, 0)

            s1 = panels:addBlock(offset + vec3(-side.x * 0.5, 5.0, 0), side, p1, -1, c, m, o, hull)
            p1 = panels:addPlanDisplaced(s1, box, 0, offset + vec3(-side.x - panel.x * 0.5, 5.0, 0))

        end
    end

    panels:rotate(vec3(1, 0, 0), -1)

    local center = panels:getBlock(0).box.center

    -- find extremest blocks for +z and -z
    local highestZ = plan:getNthBlock(0)
    local lowestZ = highestZ

    numAdditions = numAdditions or getInt(1, 4)

    for i = 1, plan.numBlocks - 1 do
        local block = plan:getNthBlock(i)

        local box = block.box
        if box.size.x >= middleDiameter and box.size.y >= middleDiameter then
            if box.upper.z > highestZ.box.upper.z then highestZ = block end
            if box.lower.z < lowestZ.box.lower.z then lowestZ = block end
        end
    end

    -- add to lowestZ
    plan:addPlanDisplaced(lowestZ.index, panels, 0, lowestZ.box.center - vec3(0, 0, lowestZ.box.size.z * 0.5))

    if numAdditions >= 2 then

        -- add to highestZ
        panels:rotate(vec3(0, 1, 0), 1)
        panels:rotate(vec3(0, 1, 0), 1)

        plan:addPlanDisplaced(highestZ.index, panels, 0, highestZ.box.center + vec3(0, 0, highestZ.box.size.z * 0.5))

        if numAdditions >= 3 then
            -- find places for more additions, without intersecting
            local highestX = highestZ
            local lowestX = highestZ

            local foundLowest = 0
            local foundHighest = 0

            for i = 1, plan.numBlocks - 1 do
                local block = plan:getNthBlock(i)
                local box = block.box

                if box.size.z >= middleDiameter and box.size.y >= middleDiameter then
                    if math.abs(box.center.y - highestZ.box.center.y) >= 4 then
                    if math.abs(box.center.y - lowestZ.box.center.y) >= 4 then
                        if box.upper.x > highestX.box.upper.x then highestX = block; foundHighest = 1 end
                        if box.lower.x < lowestX.box.lower.x then lowestX = block; foundLowest = 1 end
                    end
                    end
                end
            end

            if foundHighest == 1 then
                -- add to highestX
                panels:rotate(vec3(0, 1, 0), 1)
                plan:addPlanDisplaced(highestX.index, panels, 0, highestX.box.center + vec3(highestX.box.size.x * 0.5, 0, 0))
            end

            if numAdditions >= 4 then
                if foundLowest == 1 then
                    -- add to lowestX
                    panels:rotate(vec3(0, 1, 0), 1)
                    panels:rotate(vec3(0, 1, 0), 1)

                    plan:addPlanDisplaced(lowestX.index, panels, 0, lowestX.box.center - vec3(lowestX.box.size.x * 0.5, 0, 0))
                end
            end
        end
    end
    return plan
end

function se.addFarmingCenters(plan, arms, sizeX, sizeY)

    arms = arms or 1

    -- create panels mesh
    local panels = BlockPlan()

    local o = Matrix()
    local m = Material(MaterialType.Iron)
    local c = ColorRGB(0.5, 0.5, 0.5)

    local hull = BlockType.Hull
    local solar = BlockType.CargoBay

    if not plan then
        plan = BlockPlan()
        plan:addBlock(vec3(0,0,0), vec3(1,1,1), -1, -1, c, m, o, BlockType.CargoBay)
    end

    local middleDiameter = 1
    local middle = vec3(middleDiameter, 10.0, middleDiameter)
    local side = vec3(2.5, 1.0, 1.0)
    local panel = vec3(5.0, 5.0, 1.5)
    local glass = vec3(5.0, 5.0, 1.0)

    local mid = -1
    local additionals = sizeX or getInt(1, 4)
    local rows = sizeY or getInt(7, 15)

    for i = 0, rows - 1 do
        local p = vec3(0, i * 10, 0)

        mid = panels:addBlock(p + vec3(0, 0, 0), middle, mid, -1, c, m, o, hull)
        local s1 = panels:addBlock(p + vec3(-side.x * 0.5, 5.0, 0), side, mid, -1, c, m, o, hull)
        local s2 = panels:addBlock(p + vec3(side.x * 0.5, 5.0, 0), side, mid, -1, c, m, o, hull)

        local p1 = panels:addBlock(p + vec3(-side.x - panel.x * 0.5, 5.0, 0), panel, s1, -1, c, m, o, solar)
        local p2 = panels:addBlock(p + vec3(side.x + panel.x * 0.5, 5.0, 0), panel, s2, -1, c, m, o, solar)

        panels:addBlock(p + vec3(-side.x - panel.x * 0.5, 5.0, panel.z * 0.5 + glass.z * 0.5), glass, s1, -1, c, m, o, BlockType.Glass)
        panels:addBlock(p + vec3(side.x + panel.x * 0.5, 5.0, panel.z * 0.5 + glass.z * 0.5), glass, s2, -1, c, m, o, BlockType.Glass)

        for j = 1, additionals do
            local offset = p + vec3((panel.x + side.x) * j, 0, 0)

            s2 = panels:addBlock(offset + vec3(side.x * 0.5, 5.0, 0), side, p2, -1, c, m, o, hull)
            p2 = panels:addBlock(offset + vec3(side.x + panel.x * 0.5, 5.0, 0), panel, s2, -1, c, m, o, solar)

            panels:addBlock(offset + vec3(side.x + panel.x * 0.5, 5.0, panel.z * 0.5 + glass.z * 0.5), glass, s2, -1, c, m, o, BlockType.Glass)

            local offset = p + vec3(-(panel.x + side.x) * j, 0, 0)

            s1 = panels:addBlock(offset + vec3(-side.x * 0.5, 5.0, 0), side, p1, -1, c, m, o, hull)
            p1 = panels:addBlock(offset + vec3(-side.x - panel.x * 0.5, 5.0, 0), panel, s1, -1, c, m, o, solar)

            panels:addBlock(offset + vec3(-side.x - panel.x * 0.5, 5.0, panel.z * 0.5 + glass.z * 0.5), glass, s1, -1, c, m, o, BlockType.Glass)

        end
    end

    panels:rotate(vec3(1, 0, 0), -1)

    local center = panels:getBlock(0).box.center

    -- find extremest blocks for +z and -z
    local highestZ = plan:getNthBlock(0)
    local lowestZ = highestZ

    for i = 1, plan.numBlocks - 1 do
        local block = plan:getNthBlock(i)

        local box = block.box
        if box.size.x >= middleDiameter and box.size.y >= middleDiameter then
            if box.upper.z > highestZ.box.upper.z then highestZ = block end
            if box.lower.z < lowestZ.box.lower.z then lowestZ = block end
        end
    end

    -- add to lowestZ
    plan:addPlanDisplaced(lowestZ.index, panels, 0, lowestZ.box.center - vec3(0, 0, lowestZ.box.size.z * 0.5))

    -- add to highestZ
    panels:rotate(vec3(0, 1, 0), 1)
    panels:rotate(vec3(0, 1, 0), 1)

    if arms >= 2 then
        plan:addPlanDisplaced(highestZ.index, panels, 0, highestZ.box.center + vec3(0, 0, highestZ.box.size.z * 0.5))
    end

    local highestX = highestZ
    local lowestX = highestZ

    local foundLowest = 0
    local foundHighest = 0

    for i = 1, plan.numBlocks - 1 do
        local block = plan:getNthBlock(i)
        local box = block.box

        if box.size.z >= middleDiameter and box.size.y >= middleDiameter then
            if math.abs(box.center.y - highestZ.box.center.y) >= 4 then
            if math.abs(box.center.y - lowestZ.box.center.y) >= 4 then
                if box.upper.x > highestX.box.upper.x then highestX = block; foundHighest = 1 end
                if box.lower.x < lowestX.box.lower.x then lowestX = block; foundLowest = 1 end
            end
            end
        end
    end


    if foundHighest == 1 and arms >= 3 then
        -- add to highestX
        panels:rotate(vec3(0, 1, 0), 1)

        plan:addPlanDisplaced(highestX.index, panels, 0, highestX.box.center + vec3(highestX.box.size.x * 0.5, 0, 0))
    end

    if foundLowest == 1 and arms >= 4 then
        -- add to lowestX
        panels:rotate(vec3(0, 1, 0), 1)
        panels:rotate(vec3(0, 1, 0), 1)

        plan:addPlanDisplaced(lowestX.index, panels, 0, lowestX.box.center - vec3(lowestX.box.size.x * 0.5, 0, 0))
    end
    return plan
end

function se.addSolarPanels(plan, arms)

    arms = arms or 1

    -- create panels mesh
    local panels = BlockPlan()

    local o = Matrix()
    local m = Material(MaterialType.Iron)
    local c = ColorRGB(1, 1, 1)

    local hull = BlockType.Hull
    local solar = BlockType.SolarPanel

    if not plan then
        plan = BlockPlan()
        plan:addBlock(vec3(0,0,0), vec3(1,1,1), -1, -1, c, m, o, BlockType.CargoBay)
    end

    local middleDiameter = 1
    local middle = vec3(middleDiameter, 20.0, middleDiameter)
    local side = vec3(5, 0.2, 0.2)
    local panel = vec3(math.random() * 50 + 25, 15, 0.2)

    local additionals = getInt(1, 3)
    local rows = getInt(6, 15)

    if arms >= 3 then
        arms = arms - 2
        rows = rows * 2
    end

    local mid = panels:addBlock(vec3(0, 0, 0), middle * 1.2, mid, -1, c, m, o, hull)

    for i = 1, rows do
        local p = vec3(0, i * 20, 0)

        mid = panels:addBlock(p + vec3(0, 0, 0), middle, mid, -1, c, m, o, hull)
        local s1 = panels:addBlock(p + vec3(-2.5, 5.0, 0), side, mid, -1, c, m, o, hull)
        local s2 = panels:addBlock(p + vec3(2.5, 5.0, 0), side, mid, -1, c, m, o, hull)

        local p1 = panels:addBlock(p + vec3(-5 - panel.x * 0.5, 5.0, 0), panel, s1, -1, c, m, o, solar)
        local p2 = panels:addBlock(p + vec3(5 + panel.x * 0.5, 5.0, 0), panel, s2, -1, c, m, o, solar)


        for j = 1, additionals do
            local offset = p + vec3((panel.x + side.x) * j, 0, 0)

            s2 = panels:addBlock(offset + vec3(2.5, 5.0, 0), side, p2, -1, c, m, o, hull)
            p2 = panels:addBlock(offset + vec3(5 + panel.x * 0.5, 5.0, 0), panel, s2, -1, c, m, o, solar)

            local offset = p + vec3(-(panel.x + side.x) * j, 0, 0)

            s1 = panels:addBlock(offset + vec3(-2.5, 5.0, 0), side, p1, -1, c, m, o, hull)
            p1 = panels:addBlock(offset + vec3(-5 - panel.x * 0.5, 5.0, 0), panel, s1, -1, c, m, o, solar)
        end
    end

    -- find extremest blocks for +y and -y
    local highest = plan:getNthBlock(0)
    local lowest = highest

    local offsethigh
    local offsetlow

    if math.random() < 0.5 then
        for i = 1, plan.numBlocks - 1 do
            local block = plan:getNthBlock(i)

            local box = block.box
            if box.size.z >= middleDiameter and box.size.y >= middleDiameter then
                if box.upper.y > highest.box.upper.y then highest = block end
                if box.lower.y < lowest.box.lower.y then lowest = block end
            end
        end

        offsethigh = vec3(0, highest.box.size.y * 2, 0)
        offsetlow = vec3(0, lowest.box.size.y * 2, 0)
    else
        panels:rotate(vec3(0, 0, 1), -1)

        for i = 1, plan.numBlocks - 1 do
            local block = plan:getNthBlock(i)

            local box = block.box
            if box.size.z >= middleDiameter and box.size.y >= middleDiameter then
                if box.upper.x > highest.box.upper.x then highest = block end
                if box.lower.x < lowest.box.lower.x then lowest = block end
            end
        end

        offsethigh = vec3(highest.box.size.x * 0.5, 0, 0)
        offsetlow = vec3(lowest.box.size.x * 0.5, 0, 0)
    end

    -- add to highest
    plan:addPlanDisplaced(highest.index, panels, 0, highest.box.center + offsethigh)

    if arms >= 2 then
        -- add to lowest
        panels:rotate(vec3(0, 0, 1), 1)
        panels:rotate(vec3(0, 0, 1), 1)

        plan:addPlanDisplaced(lowest.index, panels, 0, lowest.box.center - offsetlow)
    end
    return plan
end

function se.addAsteroid(plan)
    if not plan then
        plan = BlockPlan()
        plan:addBlock(vec3(0,0,0), vec3(1,1,1), -1, -1, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Iron), Matrix(), BlockType.Hull)
    end

    local asteroid = PlanGenerator.makeBigAsteroidPlan(getFloat(80, 100), 0, Material(MaterialType.Iron), 15)

    -- make sure the station isn't too big, this looks weird in combination with the asteroid;
    -- 250 seems to be a good visually pleasing max height/width/depth
    local box = plan:getBoundingBox()
    local highest = math.max(box.size.x, math.max(box.size.y, box.size.z))

    if highest > 250 then
        local scale = 250 / highest
        plan:scale(vec3(scale, scale, scale))

        highest = 250
    end

    -- scale the asteroid so it's at maximum half as big as the station
    --local scale = highest / 2.0
    --local size = scale / asteroid.radius
    --asteroid:scale(vec3(size, size, size))

    -- now place the asteroid at the root of the station
    local block = plan:getBlock(0)
    plan:addPlanDisplaced(block.index, asteroid, 0, block.box.center + vec3(0, asteroid:getBoundingBox().size.y * 0.5, 0))
    return plan
end


function se.addCargoStorage(plan, numAdditions, sizeX, sizeY)
    -- create container mesh
    local containers = BlockPlan()

    local o = Matrix()
    local m = Material(MaterialType.Iron)
    local c = ColorRGB(0.5, 0.5, 0.5)

    local hull = BlockType.Hull

    if not plan then
        plan = BlockPlan()
        plan:addBlock(vec3(0,0,0), vec3(1,1,1), -1, -1, c, m, o, BlockType.CargoBay)
    end

    local bridgeDiameter = 1.2
    local spacing = 7
    local mainBridgeSize = vec3(bridgeDiameter, spacing, bridgeDiameter)
    local bridgeSize = vec3(3.0, bridgeDiameter, bridgeDiameter)
    local cargoSize = vec3(4.0, 5.0, 9.0)

    local mid = -1
    local rows = sizeY or getInt(3, 5)
    local additionals = sizeX or getInt(2, 5)

    -- build cargo box
    local box = BlockPlan()

    local pi = box:addBlock(vec3(0, 0, 0), cargoSize, -1, -1, c, m, o, BlockType.CargoBay)

    for i = 0, rows - 1 do
        local p = vec3(0, i * spacing, 0)

        mid = containers:addBlock(p + vec3(0, 1.5, 0), mainBridgeSize, mid, -1, c, m, o, hull)
        local s1 = containers:addBlock(p + vec3(-bridgeSize.x * 0.5, 5.0, 0), bridgeSize, mid, -1, c, m, o, hull)
        local s2 = containers:addBlock(p + vec3(bridgeSize.x * 0.5, 5.0, 0), bridgeSize, mid, -1, c, m, o, hull)

        local p1 = containers:addPlanDisplaced(s1, box, 0, p + vec3(-bridgeSize.x - cargoSize.x * 0.5, 5.0, 3.0))
        local p2 = containers:addPlanDisplaced(s1, box, 0, p + vec3(bridgeSize.x + cargoSize.x * 0.5, 5.0, 3.0))

        for j = 1, additionals do
            local offset = p + vec3((cargoSize.x + bridgeSize.x) * j, 0, 0)

            s2 = containers:addBlock(offset + vec3(bridgeSize.x * 0.5, 5.0, 0), bridgeSize, p2, -1, c, m, o, hull)
            p1 = containers:addPlanDisplaced(s1, box, 0, offset + vec3(bridgeSize.x + cargoSize.x * 0.5, 5.0, 3.0))

            local offset = p + vec3(-(cargoSize.x + bridgeSize.x) * j, 0, 0)

            s1 = containers:addBlock(offset + vec3(-bridgeSize.x * 0.5, 5.0, 0), bridgeSize, p1, -1, c, m, o, hull)
            p1 = containers:addPlanDisplaced(s1, box, 0, offset + vec3(-bridgeSize.x - cargoSize.x * 0.5, 5.0, 3.0))

        end
    end

    containers:rotate(vec3(1, 0, 0), -1)

    local center = containers:getBlock(0).box.center

    -- find extremest blocks for +z and -z
    local highestZ = plan:getNthBlock(0)
    local lowestZ = highestZ

    numAdditions = numAdditions or getInt(1, 4)

    for i = 1, plan.numBlocks - 1 do
        local block = plan:getNthBlock(i)

        local box = block.box
        if box.size.x >= bridgeDiameter and box.size.y >= bridgeDiameter then
            if box.upper.z > highestZ.box.upper.z then highestZ = block end
            if box.lower.z < lowestZ.box.lower.z then lowestZ = block end
        end
    end

    -- add to lowestZ
    plan:addPlanDisplaced(lowestZ.index, containers, 0, lowestZ.box.center - vec3(0, 0, lowestZ.box.size.z * 0.5))

    if numAdditions >= 2 then

        -- add to highestZ
        containers:rotate(vec3(0, 1, 0), 1)
        containers:rotate(vec3(0, 1, 0), 1)

        plan:addPlanDisplaced(highestZ.index, containers, 0, highestZ.box.center + vec3(0, 0, highestZ.box.size.z * 0.5))

        if numAdditions >= 3 then
            -- find places for more additions, without intersecting
            local highestX = highestZ
            local lowestX = highestZ

            local foundLowest = 0
            local foundHighest = 0

            for i = 1, plan.numBlocks - 1 do
                local block = plan:getNthBlock(i)
                local box = block.box

                if box.size.z >= bridgeDiameter and box.size.y >= bridgeDiameter then
                    if math.abs(box.center.y - highestZ.box.center.y) >= 4 then
                    if math.abs(box.center.y - lowestZ.box.center.y) >= 4 then
                        if box.upper.x > highestX.box.upper.x then highestX = block; foundHighest = 1 end
                        if box.lower.x < lowestX.box.lower.x then lowestX = block; foundLowest = 1 end
                    end
                    end
                end
            end

            if foundHighest == 1 then
                -- add to highestX
                containers:rotate(vec3(0, 1, 0), 1)
                plan:addPlanDisplaced(highestX.index, containers, 0, highestX.box.center + vec3(highestX.box.size.x * 0.5, 0, 0))
            end

            if numAdditions >= 4 then
                if foundLowest == 1 then
                    -- add to lowestX
                    containers:rotate(vec3(0, 1, 0), 1)
                    containers:rotate(vec3(0, 1, 0), 1)

                    plan:addPlanDisplaced(lowestX.index, containers, 0, lowestX.box.center - vec3(lowestX.box.size.x * 0.5, 0, 0))
                end
            end
        end
    end
    return plan
end

return se
