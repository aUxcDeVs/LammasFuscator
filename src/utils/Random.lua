-- ================================================================
-- RANDOM - Seeded random number generator utilities
-- ================================================================

local Random = {}

-- Create new random generator with seed
function Random.new(seed)
    local self = {
        Seed = seed or os.time()
    }
    
    setmetatable(self, {__index = Random})
    return self
end

-- Generate next random number (0 to 1)
function Random:Next()
    self.Seed = (self.Seed * 9301 + 49297) % 233280
    return self.Seed / 233280
end

-- Generate random integer in range [min, max]
function Random:Range(min, max)
    return math.floor(self:Next() * (max - min + 1)) + min
end

-- Generate random float in range [min, max]
function Random:Float(min, max)
    return min + self:Next() * (max - min)
end

-- Pick random element from array
function Random:Choice(array)
    return array[self:Range(1, #array)]
end

-- Shuffle array in place
function Random:Shuffle(array)
    for i = #array, 2, -1 do
        local j = self:Range(1, i)
        array[i], array[j] = array[j], array[i]
    end
    return array
end

-- Generate random bytes
function Random:Bytes(count)
    local bytes = {}
    for i = 1, count do
        table.insert(bytes, self:Range(0, 255))
    end
    return bytes
end

-- Generate random string
function Random:String(length, charset)
    charset = charset or "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local result = {}
    for i = 1, length do
        local idx = self:Range(1, #charset)
        table.insert(result, charset:sub(idx, idx))
    end
    return table.concat(result)
end

return Random
