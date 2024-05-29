--[[
    Author(s):
        Alex/EnDarke
    Description:
        Deep freezes tables, so absolutely every table value is frozen rather than just the first layer.
]]

return function (t: {}): {} | nil
	if not t then return end

    local function freeze(tab: {}): {}
		for _, value: {}? in pairs( tab ) do
			if type(value) == "table" then
				freeze(value)
			end
		end

		return table.freeze(tab)
	end

	return freeze(t)
end