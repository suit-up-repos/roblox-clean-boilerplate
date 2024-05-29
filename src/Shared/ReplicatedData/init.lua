--[[
    Author(s):
        Alex/EnDarke
    Description:
        Pulls all replicated data constants into a returned table.
]]

local Parent = script.Parent

-- Shared
local Util = require(Parent.Util) :: {}

-- Initializing Module
local utilityList = {}

-- Get Utility List
for _, module in ipairs( script:GetChildren() ) do
    if not module:IsA("ModuleScript") then continue end
    utilityList[module.Name] = require(module)
end

return Util.ReadOnly(utilityList) :: {}