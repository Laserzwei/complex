package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";mods/complexMod/scripts/entity/merchants/?.lua"
require ("utility")

VERSION = "[0.89] "
MOD = "[CPX3]"

DEBUGLEVEL = 5

function debugPrint(debuglvl, msg, tableToPrint, ...)
    if debuglvl <= DEBUGLEVEL then
        print(MOD..VERSION..msg, ...)
        if type(tableToPrint) == "table" then
            printTable(tableToPrint)
        end
    end
end

function restore(restoreData)
    Entity():addScriptOnce("mods/complexMod/scripts/entity/merchants/complexFactory.lua")
    local status = Entity():invokeFunction("mods/complexMod/scripts/entity/merchants/complexFactory.lua", "restore", restoreData)
    debugPrint(0,"Migrationstatus for ComplexFactory: ", restoreData, status)
    Entity():removeScript("data/scripts/entity/merchants/complexFactory.lua")
    terminate()
end