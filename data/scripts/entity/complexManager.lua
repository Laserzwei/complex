package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";mods/complexMod/scripts/entity/?.lua"
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

function update(timestep)
    if Entity():getValue("managerMigrationFinished") then
        print("Manager Terminate", Entity().name)
        terminate()
    end
end

function restore(restoreData)
    Entity():addScriptOnce("mods/complexMod/scripts/entity/complexManager.lua")
    local status = Entity():invokeFunction("mods/complexMod/scripts/entity/complexManager.lua", "restore", restoreData)
    debugPrint(0,"Migrationstatus for ComplexManager: ", restoreData, Entity().name, status)
    print("ComplexManager migration finished", Entity().name)
    Entity():setValue("managerMigrationFinished", true)
end
