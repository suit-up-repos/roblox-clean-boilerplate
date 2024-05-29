--!strict

--[[
    Author(s):
        Alex/EnDarke
    Description:
        Waits for a true outcome to be reached or times out.
]]

return function (timeout: number, callback): boolean | nil
	-- Prohibit continuation without necessary information.
	if not ( timeout ) then return end

	-- Local Variables
	local timer: number = 0

	if not callback() then
		while timer < timeout do
			if callback() then
				timer = timeout
			end
			timer += task.wait()
		end
	end

	return true
end