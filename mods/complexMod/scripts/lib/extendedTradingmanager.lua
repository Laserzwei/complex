package.path = package.path .. ";data/scripts/lib/?.lua"
require ("galaxy")
require ("utility")
require ("goods")
require ("stringutility")
require ("player")
require ("faction")
require ("merchantutility")
local TradingAPI = require ("tradingmanager")
local TradingManager = {}
TradingManager = TradingAPI:CreateNamespace()
TradubgManager.trader.assignedCargo = {}
-- assignable Cargo in here
-- buy sell tab in here
-- other



return TradingManager
