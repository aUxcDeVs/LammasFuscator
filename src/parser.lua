-- ================================================================
-- PARSER - Builds Abstract Syntax Tree from tokens
-- ================================================================

local Parser = {}

-- AST Node types
Parser.NodeType = {
    Chunk = "Chunk",
    Block = "Block",
    
    -- Statements
    LocalStatement = "LocalStatement",
    AssignmentStatement = "AssignmentStatement",
    FunctionStatement = "FunctionStatement",
    ReturnStatement = "ReturnStatement",
    BreakStatement = "BreakStatement",
    IfStatement = "IfStatement",
    WhileStatement = "WhileStatement",
    RepeatStatement = "RepeatStatement",
    ForNumericStatement = "ForNumericStatement",
    ForGenericStatement = "ForGenericStatement",
    DoStatement = "DoStatement",
    
    -- Expressions
    Identifier = "Identifier",
    NumberLiteral = "NumberLiteral",
    StringLiteral = "StringLiteral",
    BooleanLiteral = "BooleanLiteral",
    NilLiteral = "NilLiteral",
    VarargLiteral = "VarargLiteral",
    FunctionExpression = "FunctionExpression",
    TableConstructor = "TableConstructor",
    BinaryExpression = "BinaryExpression",
    UnaryExpression = "UnaryExpression",
    CallExpression = "CallExpression",
    IndexExpression = "IndexExpression",
    MemberExpression = "MemberExpression",
}

-- Create parser instance
local function NewParser(tokens)
    return {
        Tokens = tokens,
        Position = 1,
        Scope = {Variables = {}, Parent = nil}
    }
end

-- Peek token at offset
local function Peek(parser, offset)
    offset = offset or 0
    return parser.Tokens[parser.Position + offset] or parser.Tokens[#parser.Tokens]
end

-- Consume and return current token
local function Consume(parser)
    local token = Peek(parser)
    parser.Position = parser.Position + 1
    return token
end

-- Check if current token matches type and optionally value
local function Check(parser, tokenType, value)
    local token = Peek(parser)
    if token.Type ~= tokenType then
        return false
    end
    if value and token.Value ~= value then
        return false
    end
    return true
end

-- Expect specific token
local function Expect(parser, tokenType, value)
    if not Check(parser, tokenType, value) then
        local token = Peek(parser)
        error(string.format("Expected %s%s but got %s '%s' at line %d", 
            tokenType, 
            value and (" '" .. value .. "'") or "",
            token.Type,
            tostring(token.Value),
            token.Line))
    end
    return Consume(parser)
end

-- Forward declarations
local ParseExpression
local ParseStatement
local ParseBlock

-- Parse primary expression
local function ParsePrimaryExpression(parser)
    local token = Peek(parser)
    
    -- Literals
    if token.Type == "Number" then
        Consume(parser)
        return {Type = Parser.NodeType.NumberLiteral, Value = token.Value}
    elseif token.Type == "String" then
        Consume(parser)
        return {Type = Parser.NodeType.StringLiteral, Value = token.Value}
    elseif token.Type == "Keyword" then
        if token.Value == "true" or token.Value == "false" then
            Consume(parser)
            return {Type = Parser.NodeType.BooleanLiteral, Value = token.Value == "true"}
        elseif token.Value == "nil" then
            Consume(parser)
            return {Type = Parser.NodeType.NilLiteral}
        elseif token.Value == "function" then
            Consume(parser)
            Expect(parser, "Symbol", "(")
            
            local params = {}
            while not Check(parser, "Symbol", ")") do
                if Check(parser, "Symbol", "...") then
                    Consume(parser)
                    table.insert(params, {Type = Parser.NodeType.VarargLiteral})
                    break
                else
                    local param = Expect(parser, "Identifier")
                    table.insert(params, {Type = Parser.NodeType.Identifier, Name = param.Value})
                    if Check(parser, "Symbol", ",") then
                        Consume(parser)
                    end
                end
            end
            
            Expect(parser, "Symbol", ")")
            local body = ParseBlock(parser)
            Expect(parser, "Keyword", "end")
            
            return {
                Type = Parser.NodeType.FunctionExpression,
                Parameters = params,
                Body = body
            }
        end
    elseif token.Type == "Identifier" then
        Consume(parser)
        return {Type = Parser.NodeType.Identifier, Name = token.Value}
    elseif Check(parser, "Symbol", "(") then
        Consume(parser)
        local expr = ParseExpression(parser)
        Expect(parser, "Symbol", ")")
        return expr
    elseif Check(parser, "Symbol", "{") then
        -- Table constructor
        Consume(parser)
        local fields = {}
        
        while not Check(parser, "Symbol", "}") do
            if Check(parser, "Symbol", "[") then
                Consume(parser)
                local key = ParseExpression(parser)
                Expect(parser, "Symbol", "]")
                Expect(parser, "Symbol", "=")
                local value = ParseExpression(parser)
                table.insert(fields, {Key = key, Value = value})
            elseif Peek(parser, 1).Type == "Symbol" and Peek(parser, 1).Value == "=" then
                local key = {Type = Parser.NodeType.StringLiteral, Value = Expect(parser, "Identifier").Value}
                Expect(parser, "Symbol", "=")
                local value = ParseExpression(parser)
                table.insert(fields, {Key = key, Value = value})
            else
                table.insert(fields, {Value = ParseExpression(parser)})
            end
            
            if Check(parser, "Symbol", ",") or Check(parser, "Symbol", ";") then
                Consume(parser)
            end
        end
        
        Expect(parser, "Symbol", "}")
        return {Type = Parser.NodeType.TableConstructor, Fields = fields}
    elseif Check(parser, "Symbol", "...") then
        Consume(parser)
        return {Type = Parser.NodeType.VarargLiteral}
    end
    
    error("Unexpected token in expression: " .. token.Value .. " at line " .. token.Line)
end

-- Parse suffix expression (function calls, indexing)
local function ParseSuffixExpression(parser)
    local expr = ParsePrimaryExpression(parser)
    
    while true do
        if Check(parser, "Symbol", "(") then
            Consume(parser)
            local args = {}
            while not Check(parser, "Symbol", ")") do
                table.insert(args, ParseExpression(parser))
                if Check(parser, "Symbol", ",") then
                    Consume(parser)
                end
            end
            Expect(parser, "Symbol", ")")
            expr = {Type = Parser.NodeType.CallExpression, Base = expr, Arguments = args}
        elseif Check(parser, "Symbol", "[") then
            Consume(parser)
            local index = ParseExpression(parser)
            Expect(parser, "Symbol", "]")
            expr = {Type = Parser.NodeType.IndexExpression, Base = expr, Index = index}
        elseif Check(parser, "Symbol", ".") then
            Consume(parser)
            local member = Expect(parser, "Identifier")
            expr = {Type = Parser.NodeType.MemberExpression, Base = expr, Identifier = member.Value}
        elseif Check(parser, "Symbol", ":") then
            Consume(parser)
            local method = Expect(parser, "Identifier")
            Expect(parser, "Symbol", "(")
            local args = {}
            while not Check(parser, "Symbol", ")") do
                table.insert(args, ParseExpression(parser))
                if Check(parser, "Symbol", ",") then
                    Consume(parser)
                end
            end
            Expect(parser, "Symbol", ")")
            expr = {
                Type = Parser.NodeType.CallExpression,
                Base = {Type = Parser.NodeType.MemberExpression, Base = expr, Identifier = method.Value},
                Arguments = args,
                IsMethodCall = true
            }
        else
            break
        end
    end
    
    return expr
end

-- Parse unary expression
local function ParseUnaryExpression(parser)
    local token = Peek(parser)
    
    if token.Type == "Keyword" and (token.Value == "not" or token.Value == "not") then
        Consume(parser)
        return {
            Type = Parser.NodeType.UnaryExpression,
            Operator = token.Value,
            Argument = ParseUnaryExpression(parser)
        }
    elseif token.Type == "Symbol" and (token.Value == "-" or token.Value == "#") then
        Consume(parser)
        return {
            Type = Parser.NodeType.UnaryExpression,
            Operator = token.Value,
            Argument = ParseUnaryExpression(parser)
        }
    end
    
    return ParseSuffixExpression(parser)
end

-- Parse binary expression with precedence
local function ParseBinaryExpression(parser, minPrec)
    minPrec = minPrec or 0
    
    local left = ParseUnaryExpression(parser)
    
    local precedence = {
        ["or"] = 1,
        ["and"] = 2,
        ["<"] = 3, [">"] = 3, ["<="] = 3, [">="] = 3, ["~="] = 3, ["=="] = 3,
        [".."] = 4,
        ["+"] = 5, ["-"] = 5,
        ["*"] = 6, ["/"] = 6, ["%"] = 6,
        ["^"] = 7
    }
    
    while true do
        local token = Peek(parser)
        local op = token.Value
        local prec = precedence[op]
        
        if not prec or prec < minPrec then
            break
        end
        
        Consume(parser)
        local right = ParseBinaryExpression(parser, prec + 1)
        
        left = {
            Type = Parser.NodeType.BinaryExpression,
            Left = left,
            Operator = op,
            Right = right
        }
    end
    
    return left
end

-- Main expression parser
ParseExpression = function(parser)
    return ParseBinaryExpression(parser, 0)
end

-- Parse statement
ParseStatement = function(parser)
    local token = Peek(parser)
    
    if token.Type == "Keyword" then
        if token.Value == "local" then
            Consume(parser)
            local variables = {}
            
            repeat
                local var = Expect(parser, "Identifier")
                table.insert(variables, {Type = Parser.NodeType.Identifier, Name = var.Value})
                if Check(parser, "Symbol", ",") then
                    Consume(parser)
                else
                    break
                end
            until false
            
            local init = {}
            if Check(parser, "Symbol", "=") then
                Consume(parser)
                repeat
                    table.insert(init, ParseExpression(parser))
                    if Check(parser, "Symbol", ",") then
                        Consume(parser)
                    else
                        break
                    end
                until false
            end
            
            return {Type = Parser.NodeType.LocalStatement, Variables = variables, Init = init}
        elseif token.Value == "function" then
            Consume(parser)
            local name = Expect(parser, "Identifier")
            
            Expect(parser, "Symbol", "(")
            local params = {}
            while not Check(parser, "Symbol", ")") do
                if Check(parser, "Symbol", "...") then
                    Consume(parser)
                    table.insert(params, {Type = Parser.NodeType.VarargLiteral})
                    break
                else
                    local param = Expect(parser, "Identifier")
                    table.insert(params, {Type = Parser.NodeType.Identifier, Name = param.Value})
                    if Check(parser, "Symbol", ",") then
                        Consume(parser)
                    end
                end
            end
            Expect(parser, "Symbol", ")")
            
            local body = ParseBlock(parser)
            Expect(parser, "Keyword", "end")
            
            return {
                Type = Parser.NodeType.FunctionStatement,
                Name = name.Value,
                Parameters = params,
                Body = body
            }
        elseif token.Value == "return" then
            Consume(parser)
            local args = {}
            
            if not Check(parser, "Keyword", "end") and not Check(parser, "EOF") then
                repeat
                    table.insert(args, ParseExpression(parser))
                    if Check(parser, "Symbol", ",") then
                        Consume(parser)
                    else
                        break
                    end
                until false
            end
            
            return {Type = Parser.NodeType.ReturnStatement, Arguments = args}
        elseif token.Value == "break" then
            Consume(parser)
            return {Type = Parser.NodeType.BreakStatement}
        elseif token.Value == "do" then
            Consume(parser)
            local body = ParseBlock(parser)
            Expect(parser, "Keyword", "end")
            return {Type = Parser.NodeType.DoStatement, Body = body}
        elseif token.Value == "while" then
            Consume(parser)
            local condition = ParseExpression(parser)
            Expect(parser, "Keyword", "do")
            local body = ParseBlock(parser)
            Expect(parser, "Keyword", "end")
            return {Type = Parser.NodeType.WhileStatement, Condition = condition, Body = body}
        elseif token.Value == "repeat" then
            Consume(parser)
            local body = ParseBlock(parser)
            Expect(parser, "Keyword", "until")
            local condition = ParseExpression(parser)
            return {Type = Parser.NodeType.RepeatStatement, Body = body, Condition = condition}
        elseif token.Value == "if" then
            Consume(parser)
            local condition = ParseExpression(parser)
            Expect(parser, "Keyword", "then")
            local consequent = ParseBlock(parser)
            
            local alternate = nil
            if Check(parser, "Keyword", "else") then
                Consume(parser)
                alternate = ParseBlock(parser)
            elseif Check(parser, "Keyword", "elseif") then
                alternate = {ParseStatement(parser)}
            end
            
            Expect(parser, "Keyword", "end")
            return {
                Type = Parser.NodeType.IfStatement,
                Condition = condition,
                Consequent = consequent,
                Alternate = alternate
            }
        elseif token.Value == "for" then
            Consume(parser)
            local var = Expect(parser, "Identifier")
            
            if Check(parser, "Symbol", "=") then
                -- Numeric for
                Consume(parser)
                local start = ParseExpression(parser)
                Expect(parser, "Symbol", ",")
                local stop = ParseExpression(parser)
                local step = nil
                if Check(parser, "Symbol", ",") then
                    Consume(parser)
                    step = ParseExpression(parser)
                end
                Expect(parser, "Keyword", "do")
                local body = ParseBlock(parser)
                Expect(parser, "Keyword", "end")
                return {
                    Type = Parser.NodeType.ForNumericStatement,
                    Variable = var.Value,
                    Start = start,
                    End = stop,
                    Step = step,
                    Body = body
                }
            else
                -- Generic for
                local variables = {var.Value}
                while Check(parser, "Symbol", ",") do
                    Consume(parser)
                    table.insert(variables, Expect(parser, "Identifier").Value)
                end
                Expect(parser, "Keyword", "in")
                local iterators = {}
                repeat
                    table.insert(iterators, ParseExpression(parser))
                    if Check(parser, "Symbol", ",") then
                        Consume(parser)
                    else
                        break
                    end
                until false
                Expect(parser, "Keyword", "do")
                local body = ParseBlock(parser)
                Expect(parser, "Keyword", "end")
                return {
                    Type = Parser.NodeType.ForGenericStatement,
                    Variables = variables,
                    Iterators = iterators,
                    Body = body
                }
            end
        end
    else
        -- Assignment or call expression
        local expr = ParseExpression(parser)
        
        if Check(parser, "Symbol", "=") then
            Consume(parser)
            local values = {}
            repeat
                table.insert(values, ParseExpression(parser))
                if Check(parser, "Symbol", ",") then
                    Consume(parser)
                else
                    break
                end
            until false
            return {Type = Parser.NodeType.AssignmentStatement, Variables = {expr}, Init = values}
        else
            return expr
        end
    end
    
    return {Type = "EmptyStatement"}
end

-- Parse block of statements
ParseBlock = function(parser)
    local statements = {}
    
    while not Check(parser, "Keyword", "end") and 
          not Check(parser, "Keyword", "else") and
          not Check(parser, "Keyword", "elseif") and
          not Check(parser, "Keyword", "until") and
          not Check(parser, "EOF") do
        table.insert(statements, ParseStatement(parser))
    end
    
    return {Type = Parser.NodeType.Block, Statements = statements}
end

-- Main parse function
function Parser.Parse(tokens)
    local parser = NewParser(tokens)
    local body = ParseBlock(parser)
    
    return {
        Type = Parser.NodeType.Chunk,
        Body = body.Statements
    }
end

return Parser
