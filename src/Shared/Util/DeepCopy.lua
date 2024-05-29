--[[
    Author(s):
        Alex/EnDarke
    Description:
        Allows to make secure copies of a single table or dictionary.
]]

return function (t: {}): {} | nil
    if not t then return end

    local function deepCopy(dictionary: {}): {}
        local copy = {}

        for index: string | number, value: {}? in pairs( dictionary ) do
            if type(value) == "table" then
                value = deepCopy(value)
            end

            copy[index] = value
        end

        return copy :: {}
    end
    
    return deepCopy(t) :: {}
end