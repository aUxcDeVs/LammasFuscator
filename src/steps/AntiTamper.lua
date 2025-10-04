-- ================================================================
-- ANTI TAMPER - Anti-debug and anti-tamper protection
-- ================================================================

local AntiTamper = {}

-- Generate anti-debug code
local function GenerateAntiDebug()
    return [[
local _AD=(function()
    local s=tick()
    wait()
    if tick()-s>0.5 then 
        return error("Tamper detected",0)
    end
end)()
]]
end

-- Generate checksum validation
local function GenerateChecksumValidation()
    return [[
local _CS=(function()
    local function _H(s)
        local h=0
        for i=1,#s do
            h=bit32.bxor(h*31+s:byte(i),0xFFFFFFFF)
        end
        return h
    end
    return _H
end)()
]]
end

-- Generate environment check
local function GenerateEnvironmentCheck()
    return [[
local _EC=(function()
    if not game or not workspace then
        return error("Invalid environment",0)
    end
    if getfenv().script~=script then
        return error("Environment tampered",0)
    end
end)()
]]
end

-- Main transform function
function AntiTamper.Transform(ast, config)
    -- Create anti-tamper wrapper nodes
    local antiDebugNode = {
        Type = "AntiDebug",
        Code = GenerateAntiDebug()
    }
    
    local checksumNode = {
        Type = "ChecksumValidation",
        Code = GenerateChecksumValidation()
    }
    
    local envCheckNode = {
        Type = "EnvironmentCheck",
        Code = GenerateEnvironmentCheck()
    }
    
    -- Insert at beginning of AST body
    table.insert(ast.Body, 1, envCheckNode)
    table.insert(ast.Body, 1, checksumNode)
    table.insert(ast.Body, 1, antiDebugNode)
    
    return ast
end

return AntiTamper
