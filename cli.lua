-- ================================================================
-- CLI - Command Line Interface
-- ================================================================

local Obfuscator = require("init")

-- Parse command line arguments
local function ParseArgs(args)
    local config = {
        InputFile = nil,
        OutputFile = nil,
        Config = {}
    }
    
    local i = 1
    while i <= #args do
        local arg = args[i]
        
        if arg == "-i" or arg == "--input" then
            config.InputFile = args[i + 1]
            i = i + 2
        elseif arg == "-o" or arg == "--output" then
            config.OutputFile = args[i + 1]
            i = i + 2
        elseif arg == "--no-rename" then
            config.Config.RenameVariables = false
            i = i + 1
        elseif arg == "--no-strings" then
            config.Config.EncryptStrings = false
            i = i + 1
        elseif arg == "--no-numbers" then
            config.Config.EncryptNumbers = false
            i = i + 1
        elseif arg == "--control-flow" then
            config.Config.ControlFlowFlattening = true
            i = i + 1
        elseif arg == "--no-antitamper" then
            config.Config.AntiTamper = false
            i = i + 1
        elseif arg == "-h" or arg == "--help" then
            print([[
Advanced Lua Obfuscator - CLI

Usage: lua cli.lua [options]

Options:
  -i, --input <file>      Input Lua file
  -o, --output <file>     Output obfuscated file
  --no-rename             Disable variable renaming
  --no-strings            Disable string encryption
  --no-numbers            Disable number obfuscation
  --control-flow          Enable control flow flattening
  --no-antitamper         Disable anti-tamper protection
  -h, --help              Show this help message

Examples:
  lua cli.lua -i script.lua -o obfuscated.lua
  lua cli.lua -i script.lua -o output.lua --control-flow
  lua cli.lua -i script.lua -o output.lua --no-strings --no-numbers
]])
            os.exit(0)
        else
            i = i + 1
        end
    end
    
    return config
end

-- Main CLI function
local function Main(args)
    local config = ParseArgs(args)
    
    if not config.InputFile then
        print("Error: Input file not specified. Use -h for help.")
        os.exit(1)
    end
    
    if not config.OutputFile then
        config.OutputFile = config.InputFile:gsub("%.lua$", "") .. "_obfuscated.lua"
    end
    
    print("Advanced Lua Obfuscator v" .. Obfuscator.Version)
    print("Input:  " .. config.InputFile)
    print("Output: " .. config.OutputFile)
    print("")
    
    -- Read input file
    local inputFile = io.open(config.InputFile, "r")
    if not inputFile then
        print("Error: Cannot open input file: " .. config.InputFile)
        os.exit(1)
    end
    
    local source = inputFile:read("*all")
    inputFile:close()
    
    print("Processing...")
    
    -- Obfuscate
    local output, err = Obfuscator.Obfuscate(source, config.Config)
    
    if not output then
        print("Error: " .. err)
        os.exit(1)
    end
    
    -- Write output file
    local outputFile = io.open(config.OutputFile, "w")
    if not outputFile then
        print("Error: Cannot write to output file: " .. config.OutputFile)
        os.exit(1)
    end
    
    outputFile:write(output)
    outputFile:close()
    
    print("Done! Obfuscated code written to: " .. config.OutputFile)
    print("")
    print("Statistics:")
    print("  Original size: " .. #source .. " bytes")
    print("  Obfuscated size: " .. #output .. " bytes")
    print("  Ratio: " .. string.format("%.2f", #output / #source) .. "x")
end

-- Run CLI
Main({...})

return Main
