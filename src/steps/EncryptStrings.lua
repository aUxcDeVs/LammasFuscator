-- ================================================================
-- ENCRYPT STRINGS - XOR string encryption
-- ================================================================

local Random = require("src.utils.Random")

local EncryptStrings = {}

-- Global string pool
local stringPool = {}
local stringCounter = 0

-- XOR encrypt a string
local function XOREncrypt(str, rng)
    local keyLength = rng:Range(8, 16)
    local key = {}
    
    for i = 1, keyLength do
        table.insert(key, rng:Range(1, 255))
    end
    
    local encrypted = {}
    for i = 1, #str do
        local byte = string.byte(str, i)
        local keyByte = key[((i - 1) % #key) + 1]
        table.insert(encrypted, bit32.bxor(byte, keyByte))
    end
    
    return {
        Data = encrypted,
        Key = key
    }
end

-- Visit nodes and encrypt strings
local function VisitNode(node, rng)
    if not node or type(node) ~= "table" then
        return node
    end
    
    if node.Type == "StringLiteral" then
        -- Don't encrypt very short strings or empty strings
        if #node.Value > 2 then
            local encrypted = XOREncrypt(node.Value, rng)
            local poolName = "_STR_" .. stringCounter
            stringCounter = stringCounter + 1
            
            stringPool[poolName] = encrypted
            
            -- Replace with reference to decrypted string
            node.PoolReference = poolName
        end
        
    elseif node.Type == "LocalStatement" then
        for _, init in ipairs(node.Init) do
            VisitNode(init, rng)
        end
        
    elseif node.Type == "AssignmentStatement" then
        for _, init in ipairs(node.Init) do
            VisitNode(init, rng)
        end
        
    elseif node.Type == "CallExpression" then
        VisitNode(node.Base, rng)
        for _, arg in ipairs(node.Arguments) do
            VisitNode(arg, rng)
        end
        
    elseif node.Type == "BinaryExpression" then
        VisitNode(node.Left, rng)
        VisitNode(node.Right, rng)
        
    elseif node.Type == "UnaryExpression" then
        VisitNode(node.Argument, rng)
        
    elseif node.Type == "IndexExpression" then
        VisitNode(node.Base, rng)
        VisitNode(node.Index, rng)
        
    elseif node.Type == "ReturnStatement" then
        for _, arg in ipairs(node.Arguments) do
            VisitNode(arg, rng)
        end
        
    elseif node.Type == "FunctionStatement" or node.Type == "FunctionExpression" then
        for _, stmt in ipairs(node.Body.Statements) do
            VisitNode(stmt, rng)
        end
        
    elseif node.Type == "IfStatement" then
        VisitNode(node.Condition, rng)
        for _, stmt in ipairs(node.Consequent.Statements) do
            VisitNode(stmt, rng)
        end
        if node.Alternate then
            for _, stmt in ipairs(node.Alternate) do
                VisitNode(stmt, rng)
            end
        end
        
    elseif node.Type == "WhileStatement" then
        VisitNode(node.Condition, rng)
        for _, stmt in ipairs(node.Body.Statements) do
            VisitNode(stmt, rng)
        end
        
    elseif node.Type == "RepeatStatement" then
        for _, stmt in ipairs(node.Body.Statements) do
            VisitNode(stmt, rng)
        end
        VisitNode(node.Condition, rng)
        
    elseif node.Type == "ForNumericStatement" then
        VisitNode(node.Start, rng)
        VisitNode(node.End, rng)
        if node.Step then
            VisitNode(node.Step, rng)
        end
        for _, stmt in ipairs(node.Body.Statements) do
            VisitNode(stmt, rng)
        end
        
    elseif node.Type == "ForGenericStatement" then
        for _, iter in ipairs(node.Iterators) do
            VisitNode(iter, rng)
        end
        for _, stmt in ipairs(node.Body.Statements) do
            VisitNode(stmt, rng)
        end
        
    elseif node.Type == "DoStatement" then
        for _, stmt in ipairs(node.Body.Statements) do
            VisitNode(stmt, rng)
        end
        
    elseif node.Type == "TableConstructor" then
        for _, field in ipairs(node.Fields) do
            if field.Key then
                VisitNode(field.Key, rng)
            end
            if field.Value then
                VisitNode(field.Value, rng)
            end
        end
    end
    
    return node
end

-- Main transform function
function EncryptStrings.Transform(ast, config)
    -- Reset pool
    stringPool = {}
    stringCounter = 0
    
    local rng = Random.new()
    
    for _, stmt in ipairs(ast.Body) do
        VisitNode(stmt, rng)
    end
    
    -- Store pool in AST for generator to use
    ast.StringPool = stringPool
    
    return ast
end

return EncryptStrings
