--!strict

--[[
    Author(s):
        Alex/EnDarke
    Description:
        Returns a signal that you can use :Wait() to yield with and cancels
        if any of the event signals that were passed get fired
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Packages = ReplicatedStorage.Packages
local Signal = require( Packages.Signal )

return function (events: {}): any
	if not events then return end

	-- Local Variables
	local signal = Signal.new()
	local listeners: { RBXScriptConnection } = {}
    local received: boolean = false

	-- Listen for event
	for index, event in ipairs( events ) do
        listeners[index] = event:Connect(function(...): ()
            if received then return end
            received = true

            signal:Fire(event, ...)

            for _, eventConnection: RBXScriptConnection in ipairs( listeners ) do
                if not ( eventConnection.Connected ) then return end
                eventConnection:Disconnect()
            end
        end)
    end

	return signal
end