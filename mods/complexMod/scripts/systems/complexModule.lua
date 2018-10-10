
package.path = package.path .. ";data/scripts/systems/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
require ("basesystem")
require ("randomext")
require ("utility")

-- optimization so that energy requirement doesn't have to be read every frame
FixedEnergyRequirement = true

function getNumSlots(seed, rarity)
    math.randomseed(seed)
    if rarity.value == RarityType.Legendary then
        return 16
    else
        return math.max(1, (rarity.value + 1) * 2 + round(math.random() * math.min(3,rarity.value + 1)))
    end
end

function getNumTurrets(seed, rarity)
    math.randomseed(seed)
    local num = round(rarity.value / 2 + (math.random() * rarity.value)/2)
    return math.max(1, rarity.value + 1 + num)
end

function onInstalled(seed, rarity)
    if onClient() then
        if not Entity().isStation then
            displayChatMessage("This module only has an effect on Factories and complexes!", "ship",0)
            displayChatMessage("This module only has an effect on Factories and complexes!", "ship",2)
        end
        return
    end
    if not Entity().isStation then return end

    local additionalSlots = getNumSlots(seed, rarity)
    local slots = Entity():getValue("complexSlots")
    if not slots then
        Entity():setValue("complexSlots", additionalSlots)
    else
        Entity():setValue("complexSlots", slots + additionalSlots)
    end
    addMultiplyableBias(StatsBonuses.ArbitraryTurrets, getNumTurrets(seed, rarity))

end

function onUninstalled(seed, rarity)
    if onClient() then return end
    if not Entity().isStation then return end
    local additionalSlots = getNumSlots(seed, rarity)
    local slots = Entity():getValue("complexSlots")
    if not slots then
        Entity():setValue("complexSlots", 0)
    else
        Entity():setValue("complexSlots", slots - additionalSlots)
    end
end

function getName(seed, rarity)
    return "Factory-Complex Extension C-FCE-${num}"%_t % {num = getNumSlots(seed, rarity)}
end

function getIcon(seed, rarity)
    return "mods/complexMod/textures/icons/complex.png" -- "data/textures/icons/cog.png"
end

function getEnergy(seed, rarity)
    local num = getNumSlots(seed, rarity)
    if rarity.value == RarityType.Legendary then
        math.randomseed(seed)
        local energy = num * 51 * 1000 * 1000 * 1000 / (0.8 ^ rarity.value)
        energy = energy * 1.025
        energy = energy * (math.random(90, 105)/100) -- +/- 10%
        return energy
    else
        return num * 51 * 1000 * 1000 * 1000 / (0.8 ^ rarity.value) --smaller modules are more energy efficient!
    end
end

function getPrice(seed, rarity)
    local num = getNumSlots(seed, rarity)
    local price = 5000 * num
    return price * 2.5 ^ rarity.value
end

function getTooltipLines(seed, rarity)
    return
    {
        {ltext = "Additional Complex slots"%_t, rtext = "+" .. getNumSlots(seed, rarity), icon = "data/textures/icons/cog.png"},
        {ltext = "Armed or Unarmed Turrets"%_t, rtext = "+" .. getNumTurrets(seed, rarity), icon = "data/textures/icons/turret.png"}
    }
end

function getDescriptionLines(seed, rarity)
    return
    {
        {ltext = "Factory-Complex Extension System"%_t, rtext = "", icon = ""},
        {ltext = "Adds slots for more Factories"%_t, rtext = "", icon = ""},
        {ltext = "*only works on Stations"%_t, rtext = "", icon = ""}
    }
end
