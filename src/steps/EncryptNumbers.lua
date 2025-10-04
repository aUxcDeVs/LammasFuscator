-- ================================================================
-- ENCRYPT NUMBERS - Number obfuscation
-- ================================================================

local Random = require("src.utils.Random")

local EncryptNumbers = {}

-- Obfuscate a number
local function ObfuscateNumber(num, rng)
    -- Don't obfuscate 0, 1, or very large numbers
    if num == 0 or num == 1 or math.abs(num) > 1000000 then
        return nil
    end
    
    local method = rng:Range(1, 4)
    
    if method == 1 and num == math.floor(num) and num > 0 then
        -- Arithmetic decomposition: (a + b)
        local a = rng:Range(1, 100)
        local b = num - a
        return string.format("(%d+%d)", a, b)
        
    elseif method == 2 and num == math.floor(num) then
        -- Bitwise OR with 0: bit32.bor(num, 0)
        return string.format("bit32.bor(%d,0)", num)
        
    elseif method == 3 and num == math.floor(num) and num > 0 then
        -- Multiplication: (a * b)
        local factors = {}
        local temp = num
        for i = 2, math.sqrt(num) do
            while temp % i == 0 do
                table.insert(factors, i)
                temp = temp / i
            end
        end
        if temp > 1 then
            table.insert(factors, temp)
        end
        
        if #factors >= 2 then
            return string.format("(%d*%d)", factors[1], num / factors[1])
        end
        
    elseif method == 4 and num == math.floor(num) and num > 0 then
        -- XOR trick: bit32.bxor(a, b)
        local a = rng:Range(1, 255)
        local b = bit32.bxor(num, a)
        return string.format("bit32.bxor(%d,%d)", a, b)
    end
    
    return nil
end

-- Visit nodes and obfuscate numbers
local function VisitNode(node, rng)
    if not node or type(node) ~= "table" then
        return node
    end
    
    if node.Type == "NumberLiteral" then
        local obfuscated = ObfuscateNumber(node.Value, rng)
        if obfuscated then
            node.Obfuscated = obfuscated
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
function EncryptNumbers.Transform(ast, config)
    local rng = Random.new()
    
    for _, stmt in ipairs(ast.Body) do
        VisitNode(stmt, rng)
    end
    
    return ast
end

return EncryptNumbers
