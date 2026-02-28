local ItemData = {}

-- 🎲 THE WEIGHTED TABLE
-- Higher numbers = more common. 
-- As a CS student, you can think of this as a basic probability distribution.
local ITEMS = {
    {Name = "SpeedBoost", Weight = 70}, -- 70% chance
    {Name = "TripleBoost", Weight = 20}, -- 20% chance
    {Name = "Invincibility", Weight = 10} -- 10% chance
}

function ItemData.getRandomItem()
    local totalWeight = 0
    for _, item in ipairs(ITEMS) do
        totalWeight += item.Weight
    end

    local randomRoll = math.random(1, totalWeight)
    local currentWeight = 0

    for _, item in ipairs(ITEMS) do
        currentWeight += item.Weight
        if randomRoll <= currentWeight then
            return item.Name
        end
    end
    
    return ITEMS[1].Name -- Fallback
end

return ItemData