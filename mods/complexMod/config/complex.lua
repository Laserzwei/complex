
config = {}
config.modName = "[CPX3]"
config.version = "[0.19.0] "
config.debuglvl = 4
config.complexIntegrityCheck = 60
config.CFSCRIPT = "mods/complexMod/scripts/entity/merchants/complexFactory.lua"
config.CMSCRIPT = "mods/complexMod/scripts/entity/complexManager.lua"
config.FSCRIPT = "data/scripts/entity/merchants/factory.lua"
config.debugPrint = function (debuglvl, ...)
    if debuglvl <= config.debuglvl then
        print(select("#", ...))
        local list = {}
        for i = 1, select("#", ...) do
            local d = select(i, ...)
            if type(d) == "table" then
                printTable(d)
            else
                table.insert(list,d)
            end
        end
        print(config.modName..config.version, unpack(list))
    end
end


config.enableNPCTrading = true
config.mines = false
config.minDuration = 15.0
config.baseProductionCapacity = 100.0
return config
