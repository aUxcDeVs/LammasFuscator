-- ================================================================
-- LEXER - Tokenizes Lua source code
-- ================================================================

local Lexer = {}

-- Token types
Lexer.TokenType = {
    Keyword = "Keyword",
    Identifier = "Identifier",
    String = "String",
    Number = "Number",
    Symbol = "Symbol",
    Whitespace = "Whitespace",
    Comment = "Comment",
    EOF = "EOF"
}

-- Lua keywords
local Keywords = {
    ["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true,
    ["elseif"] = true, ["end"] = true, ["false"] = true, ["for"] = true,
    ["function"] = true, ["if"] = true, ["in"] = true, ["local"] = true,
    ["nil"] = true, ["not"] = true, ["or"] = true, ["repeat"] = true,
    ["return"] = true, ["then"] = true, ["true"] = true, ["until"] = true,
    ["while"] = true, ["goto"] = true
}

-- Create new lexer instance
local function NewLexer(source)
    return {
        Source = source,
        Position = 1,
        Line = 1,
        Column = 1,
        Tokens = {}
    }
end

-- Peek character at offset
local function Peek(lexer, offset)
    offset = offset or 0
    local pos = lexer.Position + offset
    if pos > #lexer.Source then
        return "\0"
    end
    return lexer.Source:sub(pos, pos)
end

-- Consume and return current character
local function Consume(lexer)
    local char = Peek(lexer)
    lexer.Position = lexer.Position + 1
    if char == "\n" then
        lexer.Line = lexer.Line + 1
        lexer.Column = 1
    else
        lexer.Column = lexer.Column + 1
    end
    return char
end

-- Create token
local function MakeToken(lexer, tokenType, value)
    return {
        Type = tokenType,
        Value = value,
        Line = lexer.Line,
        Column = lexer.Column
    }
end

-- Skip whitespace
local function SkipWhitespace(lexer)
    while Peek(lexer):match("%s") do
        Consume(lexer)
    end
end

-- Skip comments
local function SkipComment(lexer)
    if Peek(lexer) == "-" and Peek(lexer, 1) == "-" then
        Consume(lexer) -- -
        Consume(lexer) -- -
        
        -- Check for multi-line comment
        if Peek(lexer) == "[" and Peek(lexer, 1) == "[" then
            Consume(lexer) -- [
            Consume(lexer) -- [
            
            while not (Peek(lexer) == "]" and Peek(lexer, 1) == "]") do
                if Peek(lexer) == "\0" then
                    error("Unterminated multi-line comment at line " .. lexer.Line)
                end
                Consume(lexer)
            end
            
            Consume(lexer) -- ]
            Consume(lexer) -- ]
        else
            -- Single line comment
            while Peek(lexer) ~= "\n" and Peek(lexer) ~= "\0" do
                Consume(lexer)
            end
        end
        
        return true
    end
    return false
end

-- Read string literal
local function ReadString(lexer)
    local quote = Consume(lexer) -- " or '
    local value = ""
    
    while Peek(lexer) ~= quote do
        if Peek(lexer) == "\0" then
            error("Unterminated string at line " .. lexer.Line)
        end
        
        if Peek(lexer) == "\\" then
            Consume(lexer) -- \
            local escape = Consume(lexer)
            
            if escape == "n" then value = value .. "\n"
            elseif escape == "t" then value = value .. "\t"
            elseif escape == "r" then value = value .. "\r"
            elseif escape == "\\" then value = value .. "\\"
            elseif escape == '"' then value = value .. '"'
            elseif escape == "'" then value = value .. "'"
            elseif escape == "a" then value = value .. "\a"
            elseif escape == "b" then value = value .. "\b"
            elseif escape == "f" then value = value .. "\f"
            elseif escape == "v" then value = value .. "\v"
            elseif escape:match("%d") then
                -- Numeric escape
                local num = escape
                if Peek(lexer):match("%d") then num = num .. Consume(lexer) end
                if Peek(lexer):match("%d") then num = num .. Consume(lexer) end
                value = value .. string.char(tonumber(num))
            else
                value = value .. escape
            end
        else
            value = value .. Consume(lexer)
        end
    end
    
    Consume(lexer) -- closing quote
    return MakeToken(lexer, Lexer.TokenType.String, value)
end

-- Read number
local function ReadNumber(lexer)
    local value = ""
    
    -- Handle hex numbers
    if Peek(lexer) == "0" and (Peek(lexer, 1) == "x" or Peek(lexer, 1) == "X") then
        value = Consume(lexer) .. Consume(lexer)
        while Peek(lexer):match("[0-9a-fA-F]") do
            value = value .. Consume(lexer)
        end
    else
        -- Decimal number
        while Peek(lexer):match("%d") do
            value = value .. Consume(lexer)
        end
        
        -- Decimal point
        if Peek(lexer) == "." and Peek(lexer, 1):match("%d") then
            value = value .. Consume(lexer)
            while Peek(lexer):match("%d") do
                value = value .. Consume(lexer)
            end
        end
        
        -- Exponent
        if Peek(lexer):match("[eE]") then
            value = value .. Consume(lexer)
            if Peek(lexer):match("[%+%-]") then
                value = value .. Consume(lexer)
            end
            while Peek(lexer):match("%d") do
                value = value .. Consume(lexer)
            end
        end
    end
    
    return MakeToken(lexer, Lexer.TokenType.Number, tonumber(value))
end

-- Read identifier or keyword
local function ReadIdentifier(lexer)
    local value = ""
    
    while Peek(lexer):match("[%w_]") do
        value = value .. Consume(lexer)
    end
    
    local tokenType = Keywords[value] and Lexer.TokenType.Keyword or Lexer.TokenType.Identifier
    return MakeToken(lexer, tokenType, value)
end

-- Read symbol/operator
local function ReadSymbol(lexer)
    local char = Consume(lexer)
    local next = Peek(lexer)
    
    -- Two-character operators
    local twoChar = char .. next
    local twoCharOps = {
        ["=="] = true, ["~="] = true, ["<="] = true, [">="] = true,
        [".."] = true, ["::"] = true, ["//"] = true
    }
    
    if twoCharOps[twoChar] then
        Consume(lexer)
        return MakeToken(lexer, Lexer.TokenType.Symbol, twoChar)
    end
    
    -- Three-character operators
    if char == "." and next == "." and Peek(lexer, 1) == "." then
        Consume(lexer)
        Consume(lexer)
        return MakeToken(lexer, Lexer.TokenType.Symbol, "...")
    end
    
    return MakeToken(lexer, Lexer.TokenType.Symbol, char)
end

-- Main tokenize function
function Lexer.Tokenize(source)
    local lexer = NewLexer(source)
    
    while lexer.Position <= #lexer.Source do
        SkipWhitespace(lexer)
        
        if lexer.Position > #lexer.Source then
            break
        end
        
        -- Skip comments
        if SkipComment(lexer) then
            -- Comment skipped, continue
        elseif Peek(lexer) == '"' or Peek(lexer) == "'" then
            table.insert(lexer.Tokens, ReadString(lexer))
        elseif Peek(lexer):match("%d") then
            table.insert(lexer.Tokens, ReadNumber(lexer))
        elseif Peek(lexer):match("[%a_]") then
            table.insert(lexer.Tokens, ReadIdentifier(lexer))
        elseif Peek(lexer):match("[%p]") then
            table.insert(lexer.Tokens, ReadSymbol(lexer))
        else
            error("Unexpected character '" .. Peek(lexer) .. "' at line " .. lexer.Line)
        end
    end
    
    table.insert(lexer.Tokens, MakeToken(lexer, Lexer.TokenType.EOF, ""))
    
    return lexer.Tokens
end

return Lexer
