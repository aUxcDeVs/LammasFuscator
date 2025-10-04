-- ================================================================
-- CONTROL FLOW - Control flow obfuscation
-- ================================================================

local Random = require("src.utils.Random")

local ControlFlow = {}

-- Generate opaque predicates (always true/false but looks complex)
local function GenerateOpaquePredicate(rng, alwaysTrue)
    local predicates
    
    if alwaysTrue then
        predicates = {
            function()
                local x = rng:Range(1, 100)
                return string.format("((%d*%d)>=0)", x, x)
            end,
            function()
                local x = rng:Range(1, 255)
                return string.format("(bit32.band(%d,%d)==%d)", x, x, x)
            end,
            function()
                local x = rng:Range(1, 100)
                return string.format("((%d+1)>%d)", x, x)
            end,
            function()
                local x = rng:Range(1, 100)
                return string.format("(math.abs(%d)==%d)", x, x)
            end,
            function()
                return "(true==true)"
            end
        }
    else
        predicates = {
            function()
                local x = rng:Range(1, 100)
                return string.format("((%d*%d)<0)", x, x)
            end,
            function()
                local x = rng:Range(1, 255)
                return string.format("(bit32.band(%d,%d)~=%d)", x, x, x)
            end,
            function()
                local x = rng:Range(1, 100)
                return string.format("((%d+1)<%d)", x, x)
            end,
            function()
                return "(true==false)"
            end
        }
    end
    
    return predicates[rng:Range(1, #predicates)]()
end

-- Generate junk code
local function GenerateJunkCode(rng)
    local junkTypes = {
        function()
            local varName = "_" .. rng:String(10, "abcdefghijklmnopqrstuvwxyz")
            local value = rng:Range(1, 1000)
            return string.format("local %s=%d;", varName, value)
        end,
        function()
            local varName = "_" .. rng:String(10, "abcdefghijklmnopqrstuvwxyz")
            return string.format("for %s=1,0 do end;", varName)
        end,
        function()
            local pred = GenerateOpaquePredicate(rng, false)
            return string.format("if %s then return end;", pred)
        end,
        function()
            local a = rng:Range(1, 255)
            local varName = "_" .. rng:String(10, "abcdefghijklmnopqrstuvwxyz")
            return string.format("local %s=bit32.bxor(%d,%d);", varName, a, a)
        end,
        function()
            local varName = "_" .. rng:String(10, "abcdefghijklmnopqrstuvwxyz")
            local char = rng:Range(65, 90)
            return string.format("local %s=string.char(%d);", varName, char)
        end
    }
    
    return junkTypes[rng:Range(1, #junkTypes)]()
end

-- Insert junk statements into block
local function InsertJunkStatements(statements, rng, count)
    count = count or rng:Range(2, 5)
    
    for i = 1, count do
        local junk = GenerateJunkCode(rng)
        local pos = rng:Range(1, #statements + 1)
        
        -- Create a junk statement node
        local junkNode = {
            Type = "JunkCode",
            Code = junk
        }
        
        table.insert(statements, pos, junkNode)
    end
end

-- Insert opaque predicates
local function InsertOpaquePredicates(statements, rng, count)
    count = count or rng:Range(1, 3)
    
    for i = 1, count do
        local pred = GenerateOpaquePredicate(rng, true)
        local pos = rng:Range(1, #statements + 1)
        
        local predNode = {
            Type = "OpaquePredicate",
            Condition = pred
        }
        
        table.insert(statements, pos, predNode)
    end
end

-- Visit nodes and add control flow obfuscation
local function VisitNode(node, rng, depth)
    depth = depth or 0
    
    if not node or type(node) ~= "table" or depth > 20 then
        return node
    end
    
    if node.Type == "FunctionStatement" or node.Type == "FunctionExpression" then
        if node.Body and node.Body.Statements then
            InsertJunkStatements(node.Body.Statements, rng)
            InsertOpaquePredicates(node.Body.Statements, rng)
            
            for _, stmt in ipairs(node.Body.Statements) do
                VisitNode(stmt, rng, depth + 1)
            end
        end
        
    elseif node.Type == "IfStatement" then
        if node.Consequent and node.Consequent.Statements then
            InsertJunkStatements(node.Consequent.Statements, rng, 1)
            for _, stmt in ipairs(node.Consequent.Statements) do
                VisitNode(stmt, rng, depth + 1)
            end
        end
        
        if node.Alternate then
            for _, stmt in ipairs(node.Alternate) do
                VisitNode(stmt, rng, depth + 1)
            end
        end
        
    elseif node.Type == "WhileStatement" then
        if node.Body and node.Body.Statements then
            InsertJunkStatements(node.Body.Statements, rng, 1)
            for _, stmt in ipairs(node.Body.Statements) do
                VisitNode(stmt, rng, depth + 1)
            end
        end
        
    elseif node.Type == "RepeatStatement" then
        if node.Body and node.Body.Statements then
            InsertJunkStatements(node.Body.Statements, rng, 1)
            for _, stmt in ipairs(node.Body.Statements) do
                VisitNode(stmt, rng, depth + 1)
            end
        end
        
    elseif node.Type == "ForNumericStatement" or node.Type == "ForGenericStatement" then
        if node.Body and node.Body.Statements then
            InsertJunkStatements(node.Body.Statements, rng, 1)
            for _, stmt in ipairs(node.Body.Statements) do
                VisitNode(stmt, rng, depth + 1)
            end
        end
        
    elseif node.Type == "DoStatement" then
        if node.Body and node.Body.Statements then
            InsertJunkStatements(node.Body.Statements, rng, 1)
            for _, stmt in ipairs(node.Body.Statements) do
                VisitNode(stmt, rng, depth + 1)
            end
        end
    end
    
    return node
end

-- Main transform function
function ControlFlow.Transform(ast, config)
    local rng = Random.new()
    
    -- Add junk to main body
    if ast.Body then
        InsertJunkStatements(ast.Body, rng, 3)
        
        for _, stmt in ipairs(ast.Body) do
            VisitNode(stmt, rng)
        end
    end
    
    return ast
end

return ControlFlow
