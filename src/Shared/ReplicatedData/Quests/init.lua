--[[
    Author(s):
        Alex/EnDarke
    Description:
        Grabs all quest modules from children.
]]

-- Initializing Module
local questList = {}

-- Get Utility List
for _, module in ipairs(script:GetChildren()) do
	if not module:IsA("ModuleScript") then
		continue
	end
	questList[module.Name] = require(module)
end

return questList :: {}