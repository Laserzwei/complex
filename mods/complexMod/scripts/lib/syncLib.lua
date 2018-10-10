-- client -> Server -> Client:  request -> send -> receive
-- server -> client:    send -> receive

--====== Subfactories ======
function requestSubfactory(index, subfactoryIndex)
    if not onClient() then return end
    invokeServerFunction("sendSubfactory", index, subfactoryIndex)
end

function sendSubfactory(index, subfactoryIndex)
    if not onServer() then return end

    if not indexedComplexData[index] or not indexedComplexData[index].subFactories[subfactoryIndex] then debugPrint(1, "sSf could not find index", index) return end
    local subFactory = indexedComplexData[index].subFactories[subfactoryIndex]
    local players = {Sector():getPlayers()}
    if #players > 1 then
        broadcastInvokeClientFunction("receiveSubfactory", index, subfactoryIndex, subFactory)
    elseif #players == 1 then
        invokeClientFunction(players[1], "receiveSubfactory", index, subfactoryIndex, subFactory)
    else
        print("sendSubfactory num players", #players)
    end
end

function receiveSubfactory(index, subfactoryIndex, subFactory)
    if not onClient() then return end
    if data_in == nil then return  end
    indexedComplexData[index].subFactories[subfactoryIndex] = subFactory
end

--====== IndexedComplexData ======
function requestIndexedComplexdata()
    if not onClient() then return end
    invokeServerFunction("sendIndexedComplexdata")
end

function sendIndexedComplexdata()
    if not onServer() then return end
    local players = {Sector():getPlayers()}
    if #players > 1 then
        broadcastInvokeClientFunction("receiveIndexedComplexdata", indexedComplexData)
    elseif #players == 1 then
        invokeClientFunction(players[1], "receiveIndexedComplexdata", indexedComplexData)
    else
        print("sendIndexedComplexdata num players", #players)
    end
end

function receiveIndexedComplexdata(pIndexedComplexdata)
    if not onClient() then return end
    indexedComplexData = pIndexedComplexData
end

function requestProductionData()
    if not onClient() then return end

    invokeServerFunction("sendProductionData")
end

function sendProductionData()
    if not onServer() then return end
    if not productionData then print("no productiondata to send") return end
    if #players > 1 then
        broadcastInvokeClientFunction("receiveProductionData", productionData)
    elseif #players == 1 then
        invokeClientFunction(players[1], "receiveProductionData", productionData)
    else
        print("send num players", #players)
    end
end

function receiveProductionData(pProductionData)
    if not onClient() then return end
    productionData = pProductionData
end

--TODO remove
-- ====== Template =====
function request()
    if not onClient() then return end
    invokeServerFunction("send")
end

function send()
    if not onServer() then return end

    if #players > 1 then
        broadcastInvokeClientFunction("receive")
    elseif #players == 1 then
        invokeClientFunction(players[1], "receive")
    else
        print("send num players", #players)
    end
end

function receive()
    if not onClient() then return end
end
