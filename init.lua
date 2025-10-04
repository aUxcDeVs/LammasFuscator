-- ================================================================
-- ADVANCED LUA OBFUSCATOR
-- Main Entry Point
-- ================================================================

local Obfuscator = {}
Obfuscator.Version = "1.0.0"

-- Load modules
local Lexer = require("src.lexer")
local Parser = require("src.parser")
local Pipeline = require("src.pipeline")
local Generator = require("src.generator")

-- Default configuration
Obfuscator.DefaultConfig = {
    -- Core options
    RenameVariables = true,
    RenameGlobals = false,
    
    -- Encryption
    EncryptStrings = true,
    EncryptNumbers = true,
    
    -- Advanced
    ControlFlowFlattening = false,
    Virtualization = false,
    AntiTamper = true,
    
    -- Output
    Minify = false,
    BeautifyOutput = false,
    
    -- Performance
    MaxIterations = 100,
}

-- Main obfuscation function
function Obfuscator.Obfuscate(source, config)
    -- Merge config with defaults
    config = config or {}
    for k, v in pairs(Obfuscator.DefaultConfig) do
        if config[k] == nil then
            config[k] = v
        end
    end
    
    -- Validate input
    if type(source) ~= "string" or #source == 0 then
        return nil, "Invalid source code"
    end
    
    local success, result = pcall(function()
        -- Step 1: Lexical Analysis
        local tokens = Lexer.Tokenize(source)
        
        -- Step 2: Parse into AST
        local ast = Parser.Parse(tokens)
        
        -- Step 3: Run transformation pipeline
        local pipeline = Pipeline.new(config)
        ast = pipeline:Transform(ast)
        
        -- Step 4: Generate obfuscated code
        local output = Generator.Generate(ast, config)
        
        return output
    end)
    
    if not success then
        return nil, "Obfuscation failed: " .. tostring(result)
    end
    
    return result
end

-- Load from file
function Obfuscator.ObfuscateFile(inputPath, outputPath, config)
    local file = io.open(inputPath, "r")
    if not file then
        return nil, "Cannot open input file: " .. inputPath
    end
    
    local source = file:read("*all")
    file:close()
    
    local output, err = Obfuscator.Obfuscate(source, config)
    if not output then
        return nil, err
    end
    
    if outputPath then
        local outFile = io.open(outputPath, "w")
        if not outFile then
            return nil, "Cannot write to output file: " .. outputPath
        end
        outFile:write(output)
        outFile:close()
    end
    
    return output
end

return Obfuscator
