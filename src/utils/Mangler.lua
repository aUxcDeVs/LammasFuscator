-- ================================================================
-- MANGLER - Variable name obfuscation
-- ================================================================

local Random = require("src.utils.Random")

local Mangler = {}

-- Lua reserved keywords (cannot be used as variable names)
local ReservedKeywords = {
    ["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true,
    ["elseif"] = true, ["end"] = true, ["false"] = true, ["for"] = true,
    ["function"] = true, ["if"] = true, ["in"] = true, ["local"] = true,
    ["nil"] = true, ["not"] = true, ["or"] = true, ["repeat"] = true,
    ["return"] = true, ["then"] = true, ["true"] = true, ["until"] = true,
    ["while"] = true, ["goto"] = true
}

-- Roblox global functions (should not be renamed)
local RobloxGlobals = {
    ["game"] = true, ["workspace"] = true, ["script"] = true,
    ["print"] = true, ["warn"] = true, ["error"] = true,
    ["wait"] = true, ["spawn"] = true, ["delay"] = true,
    ["tick"] = true, ["time"] = true, ["typeof"] = true,
    ["pairs"] = true, ["ipairs"] = true, ["next"] = true,
    ["select"] = true, ["tonumber"] = true, ["tostring"] = true,
    ["type"] = true, ["pcall"] = true, ["xpcall"] = true,
    ["getmetatable"] = true, ["setmetatable"] = true,
    ["rawget"] = true, ["rawset"] = true, ["rawequal"] = true,
    ["assert"] = true, ["collectgarbage"] = true, ["require"] = true,
    ["loadstring"] = true, ["newproxy"] = true,
    ["coroutine"] = true, ["string"] = true, ["table"] = true,
    ["math"] = true, ["bit32"] = true, ["utf8"] = true,
    ["os"] = true, ["debug"] = true, ["_G"] = true, ["_VERSION"] = true
}

-- Create new mangler
function Mangler.new(seed)
    local self = {
        Random = Random.new(seed or os.time()),
        UsedNames = {},
        NameMap = {}
    }
    
    setmetatable(self, {__index = Mangler})
    return self
end

-- Check if name should not be mangled
function Mangler:ShouldSkip(name)
    return ReservedKeywords[name] or RobloxGlobals[name]
end

-- Generate confusing variable name
function Mangler:GenerateName(style)
    style = style or "confusing"
    
    local name
    local attempts = 0
    
    repeat
        if style == "confusing" then
            -- Use confusing similar-looking characters
            local chars = {"l", "I", "i", "j", "o", "O", "0", "1", "_"}
            local length = self.Random:Range(12, 20)
            name = "_"
            for i = 1, length do
                name = name .. self.Random:Choice(chars)
            end
            
        elseif style == "chinese" then
            -- Use unicode-like variable names (if supported)
            local bytes = self.Random:Bytes(self.Random:Range(15, 25))
            name = "_"
            for _, byte in ipairs(bytes) do
                name = name .. string.format("%02x", byte)
            end
            
        elseif style == "short" then
            -- Short but confusing
            local chars = {"l", "I", "i", "o", "O", "_"}
            local length = self.Random:Range(8, 12)
            name = "_"
            for i = 1, length do
                name = name .. self.Random:Choice(chars)
            end
        else
            -- Default alphanumeric
            name = "_" .. self.Random:String(self.Random:Range(15, 25), "abcdefghijklmnopqrstuvwxyz")
        end
        
        attempts = attempts + 1
        if attempts > 100 then
            -- Fallback to guaranteed unique name
            name = "_var_" .. tostring(self.Random:Range(100000, 999999))
            break
        end
    until not self.UsedNames[name] and not self:ShouldSkip(name)
    
    self.UsedNames[name] = true
    return name
end

-- Get or create mangled name for original name
function Mangler:GetMangledName(originalName, style)
    if self:ShouldSkip(originalName) then
        return originalName
    end
    
    if not self.NameMap[originalName] then
        self.NameMap[originalName] = self:GenerateName(style)
    end
    
    return self.NameMap[originalName]
end

-- Reset mangler state
function Mangler:Reset()
    self.UsedNames = {}
    self.NameMap = {}
end

return Mangler
