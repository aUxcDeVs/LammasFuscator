-- ================================================================
-- PIPELINE - Orchestrates transformation steps
-- ================================================================

local Pipeline = {}
Pipeline.__index = Pipeline

-- Load transformation steps
local RenameVariables = require("src.steps.RenameVariables")
local EncryptStrings = require("src.steps.EncryptStrings")
local EncryptNumbers = require("src.steps.EncryptNumbers")
local ControlFlow = require("src.steps.ControlFlow")
local AntiTamper = require("src.steps.AntiTamper")

-- Create new pipeline
function Pipeline.new(config)
    local self = setmetatable({}, Pipeline)
    self.Config = config
    self.Steps = {}
    
    -- Register steps based on config
    if config.RenameVariables then
        table.insert(self.Steps, {
            Name = "RenameVariables",
            Transform = RenameVariables.Transform
        })
    end
    
    if config.EncryptStrings then
        table.insert(self.Steps, {
            Name = "EncryptStrings",
            Transform = EncryptStrings.Transform
        })
    end
    
    if config.EncryptNumbers then
        table.insert(self.Steps, {
            Name = "EncryptNumbers",
            Transform = EncryptNumbers.Transform
        })
    end
    
    if config.ControlFlowFlattening then
        table.insert(self.Steps, {
            Name = "ControlFlow",
            Transform = ControlFlow.Transform
        })
    end
    
    if config.AntiTamper then
        table.insert(self.Steps, {
            Name = "AntiTamper",
            Transform = AntiTamper.Transform
        })
    end
    
    return self
end

-- Run all transformation steps
function Pipeline:Transform(ast)
    local currentAst = ast
    
    for _, step in ipairs(self.Steps) do
        currentAst = step.Transform(currentAst, self.Config)
    end
    
    return currentAst
end

return Pipeline
