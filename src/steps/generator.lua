-- ================================================================
-- GENERATOR - Generates Lua code from AST (NO LINE BREAKS)
-- ================================================================

local Generator = {}

-- Generate expression code
local function GenerateExpression(node)
    if not node then
        return ""
    end
    
    if node.Type == "NumberLiteral" then
        if node.Obfuscated then
            return node.Obfuscated
        end
        return tostring(node.Value)
        
    elseif node.Type == "StringLiteral" then
        if node.PoolReference then
            return node.PoolReference
        end
        -- Escape string properly
        local escaped = node.Value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
        return '"' .. escaped .. '"'
        
    elseif node.Type == "BooleanLiteral" then
        return tostring(node.Value)
        
    elseif node.Type == "NilLiteral" then
        return "nil"
        
    elseif node.Type == "VarargLiteral" then
        return "..."
        
    elseif node.Type == "Identifier" then
        return node.Name
        
    elseif node.Type == "BinaryExpression" then
        local left = GenerateExpression(node.Left)
        local right = GenerateExpression(node.Right)
        return "(" .. left .. node.Operator .. right .. ")"
        
    elseif node.Type == "UnaryExpression" then
        local arg = GenerateExpression(node.Argument)
        return "(" .. node.Operator .. arg .. ")"
        
    elseif node.Type == "CallExpression" then
        local base = GenerateExpression(node.Base)
        local args = {}
        for _, arg in ipairs(node.Arguments) do
            table.insert(args, GenerateExpression(arg))
        end
        return base .. "(" .. table.concat(args, ",") .. ")"
        
    elseif node.Type == "IndexExpression" then
        local base = GenerateExpression(node.Base)
        local index = GenerateExpression(node.Index)
        return base .. "[" .. index .. "]"
        
    elseif node.Type == "MemberExpression" then
        local base = GenerateExpression(node.Base)
        return base .. "." .. node.Identifier
        
    elseif node.Type == "FunctionExpression" then
        local params = {}
        for _, param in ipairs(node.Parameters) do
            if param.Type == "VarargLiteral" then
                table.insert(params, "...")
            else
                table.insert(params, param.Name)
            end
        end
        
        local body = {}
        for _, stmt in ipairs(node.Body.Statements) do
            table.insert(body, GenerateStatement(stmt))
        end
        
        return "function(" .. table.concat(params, ",") .. ")" .. table.concat(body, "") .. "end"
        
    elseif node.Type == "TableConstructor" then
        local fields = {}
        for _, field in ipairs(node.Fields) do
            if field.Key then
                local key = GenerateExpression(field.Key)
                local value = GenerateExpression(field.Value)
                table.insert(fields, "[" .. key .. "]=" .. value)
            else
                table.insert(fields, GenerateExpression(field.Value))
            end
        end
        return "{" .. table.concat(fields, ",") .. "}"
    end
    
    return ""
end

-- Generate statement code
function GenerateStatement(node)
    if not node then
        return ""
    end
    
    if node.Type == "LocalStatement" then
        local vars = {}
        for _, var in ipairs(node.Variables) do
            table.insert(vars, var.Name)
        end
        
        if #node.Init > 0 then
            local inits = {}
            for _, init in ipairs(node.Init) do
                table.insert(inits, GenerateExpression(init))
            end
            return "local " .. table.concat(vars, ",") .. "=" .. table.concat(inits, ",") .. ";"
        else
            return "local " .. table.concat(vars, ",") .. ";"
        end
        
    elseif node.Type == "AssignmentStatement" then
        local vars = {}
        for _, var in ipairs(node.Variables) do
            table.insert(vars, GenerateExpression(var))
        end
        
        local inits = {}
        for _, init in ipairs(node.Init) do
            table.insert(inits, GenerateExpression(init))
        end
        
        return table.concat(vars, ",") .. "=" .. table.concat(inits, ",") .. ";"
        
    elseif node.Type == "FunctionStatement" then
        local params = {}
        for _, param in ipairs(node.Parameters) do
            if param.Type == "VarargLiteral" then
                table.insert(params, "...")
            else
                table.insert(params, param.Name)
            end
        end
        
        local body = {}
        for _, stmt in ipairs(node.Body.Statements) do
            table.insert(body, GenerateStatement(stmt))
        end
        
        return "function " .. node.Name .. "(" .. table.concat(params, ",") .. ")" .. table.concat(body, "") .. "end;"
        
    elseif node.Type == "ReturnStatement" then
        if #node.Arguments > 0 then
            local args = {}
            for _, arg in ipairs(node.Arguments) do
                table.insert(args, GenerateExpression(arg))
            end
            return "return " .. table.concat(args, ",") .. ";"
        else
            return "return;"
        end
        
    elseif node.Type == "BreakStatement" then
        return "break;"
        
    elseif node.Type == "IfStatement" then
        local code = "if " .. GenerateExpression(node.Condition) .. " then "
        
        for _, stmt in ipairs(node.Consequent.Statements) do
            code = code .. GenerateStatement(stmt)
        end
        
        if node.Alternate then
            code = code .. "else "
            for _, stmt in ipairs(node.Alternate) do
                code = code .. GenerateStatement(stmt)
            end
        end
        
        code = code .. "end;"
        return code
        
    elseif node.Type == "WhileStatement" then
        local code = "while " .. GenerateExpression(node.Condition) .. " do "
        
        for _, stmt in ipairs(node.Body.Statements) do
            code = code .. GenerateStatement(stmt)
        end
        
        return code .. "end;"
        
    elseif node.Type == "RepeatStatement" then
        local code = "repeat "
        
        for _, stmt in ipairs(node.Body.Statements) do
            code = code .. GenerateStatement(stmt)
        end
        
        return code .. "until " .. GenerateExpression(node.Condition) .. ";"
        
    elseif node.Type == "ForNumericStatement" then
        local code = "for " .. node.Variable .. "=" .. GenerateExpression(node.Start) .. "," .. GenerateExpression(node.End)
        
        if node.Step then
            code = code .. "," .. GenerateExpression(node.Step)
        end
        
        code = code .. " do "
        
        for _, stmt in ipairs(node.Body.Statements) do
            code = code .. GenerateStatement(stmt)
        end
        
        return code .. "end;"
        
    elseif node.Type == "ForGenericStatement" then
        local vars = table.concat(node.Variables, ",")
        local iters = {}
        for _, iter in ipairs(node.Iterators) do
            table.insert(iters, GenerateExpression(iter))
        end
        
        local code = "for " .. vars .. " in " .. table.concat(iters, ",") .. " do "
        
        for _, stmt in ipairs(node.Body.Statements) do
            code = code .. GenerateStatement(stmt)
        end
        
        return code .. "end;"
        
    elseif node.Type == "DoStatement" then
        local code = "do "
        
        for _, stmt in ipairs(node.Body.Statements) do
            code = code .. GenerateStatement(stmt)
        end
        
        return code .. "end;"
        
    elseif node.Type == "JunkCode" then
        return node.Code
        
    elseif node.Type == "OpaquePredicate" then
        return "if " .. node.Condition .. " then end;"
        
    elseif node.Type == "AntiDebug" or node.Type == "ChecksumValidation" or node.Type == "EnvironmentCheck" then
        return node.Code
        
    elseif node.Type == "CallExpression" then
        return GenerateExpression(node) .. ";"
    end
    
    return ""
end

-- Generate string decryption code
local function GenerateStringDecryption(stringPool)
    if not stringPool or not next(stringPool) then
        return ""
    end
    
    local code = "local _D=function(d,k)local r=\"\"for i=1,#d do r=r..string.char(bit32.bxor(d[i],k[((i-1)%#k)+1]))end return r end;"
    
    for name, encrypted in pairs(stringPool) do
        local dataStr = "{" .. table.concat(encrypted.Data, ",") .. "}"
        local keyStr = "{" .. table.concat(encrypted.Key, ",") .. "}"
        code = code .. "local " .. name .. "=_D(" .. dataStr .. "," .. keyStr .. ");"
    end
    
    return code
end

-- Main generate function
function Generator.Generate(ast, config)
    local output = {}
    
    -- Add header comment
    table.insert(output, "-- Obfuscated by Advanced Lua Obfuscator")
    
    -- Wrap in IIFE
    table.insert(output, "return(function()")
    
    -- Generate string decryption if needed
    if ast.StringPool then
        table.insert(output, GenerateStringDecryption(ast.StringPool))
    end
    
    -- Generate all statements (NO LINE BREAKS - all in one line)
    for _, stmt in ipairs(ast.Body) do
        table.insert(output, GenerateStatement(stmt))
    end
    
    table.insert(output, "end)()")
    
    -- Join everything with NO line breaks (except the comment)
    return output[1] .. "\n" .. table.concat(output, "", 2)
end

return Generator
