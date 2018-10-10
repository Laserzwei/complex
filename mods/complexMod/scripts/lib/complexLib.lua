-- some misc functions

function getFactoryClassBySize(factorySize)
    local size = ""
    if factorySize == 2 then size =      "Class I"
    elseif factorySize == 2 then size =  "Class II"
    elseif factorySize == 3 then size =  "Class III"
    elseif factorySize == 4 then size =  "Class IV"
    elseif factorySize == 5 then size =  "Class V"
    elseif factorySize == 6 then size =  "Class VI"
    elseif factorySize == 7 then size =  "Class VII"
    elseif factorySize == 8 then size =  "Class VIII"
    elseif factorySize == 9 then size =  "Class IX"
    elseif factorySize == 10 then size = "Class X"
    else debugPrint(1, "got wrong size: H ".. tostring(factorySize))
    end
    return size
end

function tableToVec3(table)
    return vec3(table.x, table.y, table.z)
end

function vec3ToTable(vec)
    return {x = vec.x, y = vec.y, z = vec.z}
end

function tableToVec2(table)
    return vec2(table.x, table.y)
end

function vec2ToTable(vec)
    return {x = vec.x, y = vec.y}
end

function vec3Equal(vecIn1,vecIn2)
    if vecIn1 == nil or vecIn2 == nil then return false end
    return (vecIn1.x == vecIn2.x and vecIn1.y == vecIn2.y and vecIn1.z == vecIn2.z)
end

function getDistBetweenVectors(vector1, vector2)
    local vec = vector1 - vector2
    return math.sqrt(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z)
end

--toReadableNumber
function tRN(number)
    number = tonumber(number)
    if number == nil then return 0 end
    number = math.floor(number*100)/100     --keep last 2 digit
    local formatted = number
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k==0) then
            break
        end
    end
    return formatted
end
