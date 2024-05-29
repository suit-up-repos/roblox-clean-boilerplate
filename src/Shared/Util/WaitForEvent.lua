--!strict

--[[
    Author(s):
        Alex/EnDarke
    Description:
        Returns a signal that you can use :Wait() to yield with and cancels
        either if from a timeout or from an event signal
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Packages = ReplicatedStorage.Packages
local Signal = require( Packages.Signal )

return function (timeout: number, onEvent: RBXScriptSignal): any
	-- Prohibit continuation without necessary information.
	if not ( onEvent and timeout ) then return end

	-- Local Variables
	local signal = Signal.new()
	local listener = nil

	-- Listen for event
	listener = onEvent:Connect(function(...): ()
		listener:Disconnect()
		signal:Fire(...)
	end)

	-- Timeout
	task.delay(timeout, function(): ()
		if ( listener ) then
			listener:Disconnect()
			signal:Fire()
		end
	end)

	return signal
end