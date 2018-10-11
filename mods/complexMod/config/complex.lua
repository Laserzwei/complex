
config = {}
config.modName = "[complexMod]"
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


config.enableNPCTrading = true  -- enables NPC's to trade with the complex. Default: [true]
config.mines = false    -- [false] mines can only be added with a claimed asteroid, of the same faction as the complex, in the sector | [true] mines can be added to a compelex at any time. Default: [false]
config.minDuration = 15.0   -- minimum time between production cycles. Default: 15.0
config.baseProductionCapacity = 100.0   -- The complex gains this much production capacity with every subfactory added. Can otherwise be increased with assembly blocks. Default: 100.0
config.maxBlockCount = 100000   -- max Block count in a complex. Default: 100000
return config
