--package.path = package.path .. ";?"
local complexConfig = require ("mods/complexMod/config/complex")
if complexConfig.enableNPCTrading then
    table.insert(TradingUtility.getTradeableScripts(), "/complexFactory.lua")
end

return TradingUtility
