--[[
    Author(s):
        Alex/EnDarke
    Description:
        Pulls all utility modules into a returned table.
]]

-- Initializing Module
local utilityList = {}

-- Get Utility List
for _, module in ipairs( script:GetChildren() ) do
    if not module:IsA("ModuleScript") then continue end
    utilityList[module.Name] = require(module)
end

return utilityList :: {}