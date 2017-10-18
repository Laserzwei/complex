package.path = package.path .. ";data/scripts/lib/?.lua"
require ("utility")

managementTab = {}

VERSION = "[0.89] "
MOD = "[CPX3]"

DEBUGLEVEL = 2              -- is overwritten by DEBUGLEVEL in complexManager.lua

--data
managementTab.allPermissions = {
    [AlliancePrivilege.Invite + 1] = "Invite",
    [AlliancePrivilege.Kick + 1] = "Kick",
    [AlliancePrivilege.Promote + 1] = "Promote",
    [AlliancePrivilege.Demote + 1] = "Demote",
    [AlliancePrivilege.EditRanks + 1] = "Edit Ranks",
    [AlliancePrivilege.AddItems + 1] = "Add Items",
    [AlliancePrivilege.SpendItems + 1] = "Spend Items",
    [AlliancePrivilege.TakeItems + 1] = "Take Items",
    [AlliancePrivilege.AddResources + 1] = "Add Resources",
    [AlliancePrivilege.SpendResources + 1] = "Spend Resources",
    [AlliancePrivilege.TakeResources + 1] = "Take Resources",
    [AlliancePrivilege.FoundShips + 1] = "Found Ships",
    [AlliancePrivilege.FoundStations + 1] = "Found Stations",
    [AlliancePrivilege.ManageShips + 1] = "Manage Ships",
    [AlliancePrivilege.ManageStations + 1] = "Manage Stations",
    [AlliancePrivilege.FlyCrafts + 1] = "Fly Crafts",
    [AlliancePrivilege.ModifyCrafts + 1] = "Modify Crafts",
    [AlliancePrivilege.ModifyMessageOfTheDay + 1] = "Modify Message Of The Day"
}

function managementTab.getDefaultPerms()  -- all Permissions are required
    local default = {}
    for perm,_ in ipairs(managementTab.allPermissions) do
        default[#default+1]= perm - 1
    end
    return default
end

managementTab.permissions = {     --permissions is stateless and receives, its permissions from the alliance
    [1] = {["permission"]= "Build Complex", ["requiredPermissions"] = managementTab.getDefaultPerms()},
    [2] = {["permission"]= "Production Management", ["requiredPermissions"] = managementTab.getDefaultPerms()},
    [3] = {["permission"]= "Trading Management", ["requiredPermissions"] = managementTab.getDefaultPerms()},
    [4] = {["permission"]= "Change Name & Title", ["requiredPermissions"] = managementTab.getDefaultPerms()},
    [5] = {["permission"]= "Transfer Complex", ["requiredPermissions"] = managementTab.getDefaultPerms()},
    [6] = {["permission"]= "Sell Complex", ["requiredPermissions"] = managementTab.getDefaultPerms()}
}
local networth = 0

--ui
managementTab.checkBoxList = {}
managementTab.uiInitialized = false
local windowContainer
local firstCheckboxIndex = 0


local stationNameTextbox, stationNameButton
local stationTitleTextbox, stationTitleButton

local sellButton, transferButton

local warnWindow, warnWindowLabel

function debugPrint(debuglvl, msg, tableToPrint, ...)
    if debuglvl <= DEBUGLEVEL then
        print(MOD..VERSION..msg, ...)
        if type(tableToPrint) == "table" then
            printTable(tableToPrint)
        end
    end
end

function managementTab.initialize()
  if onServer() then
    managementTab.getPermissions()
  end
end

function managementTab.createManagementUI(tabWindow)
    windowContainer = tabWindow:createContainer(Rect(vec2(0, 0), tabWindow.size))
    local offset = 300
    local size = vec2(20, 20)
    local y = 80
    local spacing = 30
    local heigt = 20

    for i, permission in ipairs(managementTab.allPermissions) do
        local pos = vec2(offset + (spacing + size.x)*i, heigt + heigt*((i-1)%3))
        local label = windowContainer:createLabel(pos, permission, 12)
    end

    windowContainer:createLabel(vec2(10, y-10), "Grant Permissions for:", 18)
    local label
    local lblY = y
    for i, data in ipairs(managementTab.permissions) do
        lblY = lblY + 30
        label = windowContainer:createLabel(vec2(10, lblY), data.permission, 16)
    end
    firstCheckboxIndex = label.index
    for i, _ in ipairs(managementTab.permissions) do
        y = y + 30
        for j, permission in ipairs(managementTab.allPermissions) do
            local position = vec2(j*size.x + j*spacing + offset, y)
            local checkBox = windowContainer:createCheckBox(Rect(position, position + size), "", "onGenericPermissionCheckboxChecked")
            checkBox.tooltip = permission
            checkBox.checked = 1
            if Faction(Entity().factionIndex).isPlayer then
                checkBox.active = false
                checkBox.tooltip = "No permission Management for players. Transfer the complex to your alliance first."
            end
            table.insert(managementTab.checkBoxList, checkBox)
            --print(j, permission, #managementTab.allPermissions)
        end
    end
    y = y + 40

    if not checkEntityInteractionPermissions(Entity(), AlliancePrivilege.EditRanks) then
        for i, cb in pairs(managementTab.checkBoxList) do
            cb.active = false
        end
    end

    local textboxSize = vec2(200,35)
    local buttonSize = vec2(120, 35)
    --Station naming
    stationNameTextbox = windowContainer:createTextBox(Rect(vec2(0, y), vec2(spacing, y) + textboxSize), "")
    stationNameTextbox.text = Entity().name
    stationNameButton = windowContainer:createButton(Rect(vec2(spacing + textboxSize.x, y), vec2(2*spacing + textboxSize.x, y) + buttonSize), "Change Name", "onChangeName")
    stationNameButton.maxTextSize = 16
    y = y + 40

    --station title
    stationTitleTextbox = windowContainer:createTextBox(Rect(vec2(0, y), vec2(spacing, y) + textboxSize), "")
    stationTitleTextbox.text = Entity().title
    stationNameButton = windowContainer:createButton(Rect(vec2(spacing + textboxSize.x, y), vec2(2*spacing + textboxSize.x, y) + buttonSize), "Change Title", "onChangeTitle")
    stationNameButton.maxTextSize = 16
    y = y + 40

    --transfer ownership
    transferButton = windowContainer:createButton(Rect(vec2(0, y), vec2(spacing, y) + textboxSize), "", "onTransferOwnershipPressed")
    transferButton.maxTextSize = 16
    if Faction(Entity().factionIndex).isPlayer then
        transferButton.caption = "Transfer Ownership To Alliance"
    else
        transferButton.caption = "Transfer Ownership To Player"
    end
    y = y + 40

    --sell Complex
    sellButton = windowContainer:createButton(Rect(vec2(0, y), vec2(spacing, y) + textboxSize), "Sell Complex", "onSellComplexPressed")
    sellButton.maxTextSize = 16
    sellButton.tooltip = "Worth: ".. createMonetaryString(networth/0.7) .."Sell for: "..createMonetaryString(networth)
    managementTab.uiInitialized = true


    -- warn box
    local size = vec2(550, 230)
    local res = getResolution()
    warnWindow = tabWindow:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    warnWindow.caption = "Confirm Sell"
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
    warnWindow:createButton(vsplit.left, "Sell"%_t, "onConfirmSellButtonPress")
    warnWindow:createButton(vsplit.right, "Cancel"%_t, "onCancelSellButtonPress")


    managementTab.getPermissions()
    client_receivePermissions(managementTab.permissions)
end

function onConfirmSellButtonPress()
    invokeServerFunction("SellComplex", networth)
    warnWindow:hide()
end

function onCancelSellButtonPress()
    warnWindow:hide()
end

function onSellComplexPressed()
    warnWindowLabel.caption = "This action is irreversible." .."\n\n" ..
        "You're about to sell your Complex:\n" ..Entity().name .. "\n\n" ..
        "This will remove all production capabilities." .."\n" ..
        "The structure will stay in intact. "
    warnWindowLabel.fontSize = 14
    warnWindow:show()
end

function onGenericPermissionCheckboxChecked(cb)
    if managementTab.uiInitialized then
        local permIndex = cb.index - firstCheckboxIndex
        local complexPermission = math.ceil(permIndex / #managementTab.allPermissions)
        local alliancePermission = permIndex - ((complexPermission - 1) * #managementTab.allPermissions) - 1
        --print("checkboxpressed", permIndex, complexPermission, alliancePermission)
        if cb.checked then
            client_requestChangePermissions(complexPermission, alliancePermission, true)
        else
            client_requestChangePermissions(complexPermission, alliancePermission, false)
        end

    end
end

function onChangeName()
    if stationNameTextbox.text ~= nil then
        if string.len(stationNameTextbox.text) < 4 then
            displayChatMessage("Stationname needs to be at least 4 Characters long!", "Complex", 3)
            stationNameTextbox.text = "-_-_-"
        else
            invokeServerFunction("changeName", stationNameTextbox.text)
        end
    end
end

function onChangeTitle()
    if stationTitleTextbox.text ~= nil then
        if string.len(stationTitleTextbox.text) < 4 then
            displayChatMessage("Stationtitle needs to be at least 4 Characters long!", "Complex", 3)
            stationTitleTextbox.text = "-_-_-"
        else
            invokeServerFunction("changeTitle", stationTitleTextbox.text)
        end
    end
end

function onTransferOwnershipPressed()
    if Faction(Entity().factionIndex).isPlayer then
        transferButton.caption = "Transfer Ownership To Player"
        for _,chkbx in pairs(managementTab.checkBoxList) do chkbx.active = true end
    else
        transferButton.caption = "Transfer Ownership To Alliance"
        for _,chkbx in pairs(managementTab.checkBoxList) do chkbx.active = false end
    end
    invokeServerFunction("transferOwnership")
end

function managementTab.getPermissions()
    local owner = Entity().factionIndex
    if not owner then return end
    if not Faction(owner) then return end
    if not Faction(owner).isAlliance then return end
    local alliance = Alliance(owner)
    for i, data in pairs(managementTab.permissions) do
        if alliance:rankExists(data.permission) then
            local privs = {alliance:getRank(data.permission):getPrivileges()}
            managementTab.permissions[i].requiredPermissions = privs
        end
    end
    return managementTab.permissions
end


function client_receivePermissions(pPermissions)
    if not pPermissions then return end
    if not checkEntityInteractionPermissions(Entity(), AlliancePrivilege.EditRanks) then
        for i, cb in pairs(managementTab.checkBoxList) do
            cb.active = false
        end
    end
    managementTab.permissions = pPermissions
    managementTab.uiInitialized = false   --checkboxes don't have an option to be checked without calling the checked function
    for i, cb in pairs(managementTab.checkBoxList) do
        cb.checked = false
    end
    for i, data in ipairs(managementTab.permissions) do
        for _, perm in pairs(data.requiredPermissions) do
            local checkboxIndex = (i-1) * #managementTab.allPermissions + perm + 1
            managementTab.checkBoxList[checkboxIndex].checked = true
        end
    end

    managementTab.uiInitialized = true
end

function client_requestChangePermissions(complexPermission, alliancePermission, state)
    invokeServerFunction("server_processChangePermission", complexPermission, alliancePermission, state)
end

function server_processChangePermission(complexPermission, alliancePermission, state)
    if not callingPlayer then return end
    if not complexPermission or not alliancePermission then return end
    local owner = Faction(Entity().factionIndex)
    managementTab.getPermissions()
    if owner.isPlayer then -- only owners or factionleaders can modify Complex permissions
        if callingPlayer == owner.index then
            --players can't change permissions
        else
            Player(callingPlayer):sendChatMessage(Entity().name, 2, "You are not allowed to modify Complex Permissions!")
        end
    elseif owner.isAlliance then
        if checkEntityInteractionPermissions(Entity(), AlliancePrivilege.EditRanks) then
            local alliance = Alliance(owner.index)
            --complex Permissions
            if not state then
                managementTab.permissions[complexPermission].requiredPermissions[#managementTab.permissions[complexPermission].requiredPermissions + 1] = nil
            else
                managementTab.permissions[complexPermission].requiredPermissions[#managementTab.permissions[complexPermission].requiredPermissions + 1] = alliancePermission
            end
            --Alliance Permissions
            if alliance:rankExists(managementTab.permissions[complexPermission].permission) then
                if state then
                    alliance:addRankPrivilege(managementTab.permissions[complexPermission].permission, alliancePermission)
                else
                    alliance:removeRankPrivilege(managementTab.permissions[complexPermission].permission, alliancePermission)
                end
            else
                alliance:addRank(managementTab.permissions[complexPermission].permission, "")
                for _, perm in pairs(managementTab.permissions[complexPermission].requiredPermissions) do
                    alliance:addRankPrivilege(managementTab.permissions[complexPermission].permission, perm)
                end
            end
            managementTab.getPermissions()
            broadcastInvokeClientFunction("client_receivePermissions", managementTab.permissions)
        else
            Player(callingPlayer):sendChatMessage(Entity().name, 2, "You are not allowed to modify Complex Permissions!")
            invokeClientFunction(Player(callingPlayer), "client_receivePermissions",managementTab.permissions)
        end
    else --not supposed to happen
        debugPrint(0, "Wrong type of owner", nil, owner.index)
    end
end


function changeName(newName)
    if onClient() then debugPrint(0,"Wrong Side in CT-change Name") return end
    if not checkEntityInteractionPermissions(Entity(), unpack(managementTab.permissions[4].requiredPermissions)) then return end
    Player(callingPlayer):sendChatMessage(Entity().name, 3, "Your Complex: "..Entity().name.." has been renamed to: "..newName, Entity().name)
    Entity().name = newName
end

function changeTitle(newTitle)
    if onClient() then debugPrint(0,"Wrong Side in CT-change Name") return end
    if not checkEntityInteractionPermissions(Entity(), unpack(managementTab.permissions[4].requiredPermissions)) then return end
    Player(callingPlayer):sendChatMessage(Entity().name, 3, "Your Complex: "..Entity().name.." has been renamed to: "..newTitle, Entity().name)
    Entity().title = newTitle
end

function transferOwnership()
    local factionIndex = Entity().factionIndex
    if not factionIndex then debugPrint(0, "[Critical] Complex without Faction", nil, Entity().index) return end

    if not checkEntityInteractionPermissions(Entity(), unpack(managementTab.permissions[5].requiredPermissions)) then return end

    if Faction(factionIndex).isAlliance then
        Entity().factionIndex = callingPlayer
    elseif Faction(factionIndex).isPlayer then
        if Player(callingPlayer).allianceIndex then
            Entity().factionIndex = Player(callingPlayer).allianceIndex
            managementTab.getPermissions()
            broadcastInvokeClientFunction("client_receivePermissions", managementTab.permissions)
        end
    else

    end

end

function managementTab.transmitComplexNetWorth(pIndexedComplexData)
    if not pIndexedComplexData then return 0 end
    local money = 0
    for _, data in pairs(pIndexedComplexData) do
        local production = data.factoryTyp
        money =  money + managementTab.getSingleFactoryCost(production)

    end
    networth = money * 0.7
    if managementTab.uiInitialized then
        sellButton.tooltip = "Worth: ".. createMonetaryString(networth/0.7) .. "\nSell for: " .. createMonetaryString(networth)
    end

end

function SellComplex(clientMoney)
    if not checkEntityInteractionPermissions(Entity(), unpack(managementTab.permissions[6].requiredPermissions)) then return end
    if clientMoney ~= networth then
        Player():sendChatMessage(Entity().name, 1, "Could not Sell Complex. Server and client aren't synched.")
        return
    end
    local owner = Faction(Entity().factionIndex)
    owner:receiveMoney(networth)
    Entity():removeScript("mods/complexMod/scripts/entity/merchants/complexFactory.lua")
    Entity():setValue("isComplex", nil)
    terminate()
end

function managementTab.getSingleFactoryCost(production)

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

return managementTab
