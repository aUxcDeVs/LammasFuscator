-- ================================================================
-- RENAME VARIABLES - Scope-aware variable renaming
-- ================================================================

local Mangler = require("src.utils.Mangler")

local RenameVariables = {}

-- Visitor pattern for AST traversal
local function VisitNode(node, mangler, scope)
    if not node or type(node) ~= "table" then
        return node
    end
    
    if node.Type == "Identifier" then
        if scope[node.Name] then
            node.Name = scope[node.Name]
        end
        
    elseif node.Type == "LocalStatement" then
        -- Create new scope mappings for local variables
        for _, var in ipairs(node.Variables) do
            if var.Type == "Identifier" then
                local newName = mangler:GetMangledName(var.Name)
                scope[var.Name] = newName
                var.Name = newName
            end
        end
        
        -- Visit initializers
        for _, init in ipairs(node.Init) do
            VisitNode(init, mangler, scope)
        end
        
    elseif node.Type == "FunctionStatement" then
        -- Rename function name
        local newName = mangler:GetMangledName(node.Name)
        scope[node.Name] = newName
        node.Name = newName
        
        -- Create new scope for parameters
        local funcScope = setmetatable({}, {__index = scope})
        for _, param in ipairs(node.Parameters) do
            if param.Type == "Identifier" then
                local newParamName = mangler:GetMangledName(param.Name)
                funcScope[param.Name] = newParamName
                param.Name = newParamName
            end
        end
        
        -- Visit function body
        for _, stmt in ipairs(node.Body.Statements) do
            VisitNode(stmt, mangler, funcScope)
        end
        
    elseif node.Type == "FunctionExpression" then
        -- Create new scope for parameters
        local funcScope = setmetatable({}, {__index = scope})
        for _, param in ipairs(node.Parameters) do
            if param.Type == "Identifier" then
                local newParamName = mangler:GetMangledName(param.Name)
                funcScope[param.Name] = newParamName
                param.Name = newParamName
            end
        end
        
        -- Visit function body
        for _, stmt in ipairs(node.Body.Statements) do
            VisitNode(stmt, mangler, funcScope)
        end
        
    elseif node.Type == "AssignmentStatement" then
        for _, var in ipairs(node.Variables) do
            VisitNode(var, mangler, scope)
        end
        for _, init in ipairs(node.Init) do
            VisitNode(init, mangler, scope)
        end
        
    elseif node.Type == "CallExpression" then
        VisitNode(node.Base, mangler, scope)
        for _, arg in ipairs(node.Arguments) do
            VisitNode(arg, mangler, scope)
        end
        
    elseif node.Type == "BinaryExpression" then
        VisitNode(node.Left, mangler, scope)
        VisitNode(node.Right, mangler, scope)
        
    elseif node.Type == "UnaryExpression" then
        VisitNode(node.Argument, mangler, scope)
        
    elseif node.Type == "IndexExpression" then
        VisitNode(node.Base, mangler, scope)
        VisitNode(node.Index, mangler, scope)
        
    elseif node.Type == "MemberExpression" then
        VisitNode(node.Base, mangler, scope)
        
    elseif node.Type == "ReturnStatement" then
        for _, arg in ipairs(node.Arguments) do
            VisitNode(arg, mangler, scope)
        end
        
    elseif node.Type == "IfStatement" then
        VisitNode(node.Condition, mangler, scope)
        for _, stmt in ipairs(node.Consequent.Statements) do
            VisitNode(stmt, mangler, scope)
        end
        if node.Alternate then
            for _, stmt in ipairs(node.Alternate) do
                VisitNode(stmt, mangler, scope)
            end
        end
        
    elseif node.Type == "WhileStatement" then
        VisitNode(node.Condition, mangler, scope)
        for _, stmt in ipairs(node.Body.Statements) do
            VisitNode(stmt, mangler, scope)
        end
        
    elseif node.Type == "RepeatStatement" then
        for _, stmt in ipairs(node.Body.Statements) do
            VisitNode(stmt, mangler, scope)
        end
        VisitNode(node.Condition, mangler, scope)
        
    elseif node.Type == "ForNumericStatement" then
        local forScope = setmetatable({}, {__index = scope})
        local newVarName = mangler:GetMangledName(node.Variable)
        forScope[node.Variable] = newVarName
        node.Variable = newVarName
        
        VisitNode(node.Start, mangler, scope)
        VisitNode(node.End, mangler, scope)
        if node.Step then
            VisitNode(node.Step, mangler, scope)
        end
        
        for _, stmt in ipairs(node.Body.Statements) do
            VisitNode(stmt, mangler, forScope)
        end
        
    elseif node.Type == "ForGenericStatement" then
        local forScope = setmetatable({}, {__index = scope})
        for i, var in ipairs(node.Variables) do
            local newVarName = mangler:GetMangledName(var)
            forScope[var] = newVarName
            node.Variables[i] = newVarName
        end
        
        for _, iter in ipairs(node.Iterators) do
            VisitNode(iter, mangler, scope)
        end
        
        for _, stmt in ipairs(node.Body.Statements) do
            VisitNode(stmt, mangler, forScope)
        end
        
    elseif node.Type == "DoStatement" then
        for _, stmt in ipairs(node.Body.Statements) do
            VisitNode(stmt, mangler, scope)
        end
        
    elseif node.Type == "TableConstructor" then
        for _, field in ipairs(node.Fields) do
            if field.Key then
                VisitNode(field.Key, mangler, scope)
            end
            if field.Value then
                VisitNode(field.Value, mangler, scope)
            end
        end
    end
    
    return node
end

-- Main transform function
function RenameVariables.Transform(ast, config)
    local mangler = Mangler.new()
    local globalScope = {}
    
    for _, stmt in ipairs(ast.Body) do
        VisitNode(stmt, mangler, globalScope)
    end
    
    return ast
end

return RenameVariables
