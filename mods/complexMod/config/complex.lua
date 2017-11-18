
config = {}
config.modName = "[CPX3]"
config.version = "[0.90b] "
config.debuglvl = 2
config.complexIntegrityCheck = 60
config.CFSCRIPT = "mods/complexMod/scripts/entity/merchants/complexFactory.lua"
config.CMSCRIPT = "mods/complexMod/scripts/entity/complexManager.lua"
config.FSCRIPT = "data/scripts/entity/merchants/factory.lua"
config.debugPrint = function (debuglvl, msg, tableToPrint, ...)
    if debuglvl <= DEBUGLEVEL then
        print(MOD..VERSION..msg, ...)
        if type(tableToPrint) == "table" then
            printTable(tableToPrint)
        end
    end
end


config.enableNPCTrading = true
config.minDuration = 1.0
config.baseProductionCapacity = 100.0
return config
