--[[
    Author(s):
        Alex/EnDarke
    Description:
        Bootstraps the server to the Knit framework.
]]

local Parent = script.Parent

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Packages = ReplicatedStorage.Packages
local Knit = require( Packages.Knit )

-- Folders
local ServiceFolder: Folder = Parent.Services

-- Constants
local INIT_TIME_STAMP: number = workspace:GetServerTimeNow()

-- Initializing Knit
local Services = Knit.AddServicesDeep(ServiceFolder)

Knit.Start():catch(warn):andThen(function(): ()
    local function forEachService(funcName: string, onMultithread: boolean, ...): ()
        if not funcName then return end

        -- Run through all functions
        for _, service in ipairs( Services ) do
            -- Check if service has function
            if not ( service[funcName] ) then continue end

            -- Run the function!
            if ( onMultithread ) then
                task.spawn(service[funcName], ...)
            else
                service[funcName](...)
            end
        end
    end

    -- Run player join code for any players in game that may have been missed
    for _, player: Player in ipairs( Players:GetPlayers() ) do
        forEachService("PlayerAdded", true, player)
    end

    -- Listen for player joining and leaving
    Players.PlayerAdded:Connect(function(player: Player)
        forEachService("PlayerAdded", true, player)
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        forEachService("PlayerRemoving", false, player)
    end)

    -- Logging how long it took to initialize Knit on the server.
    print(("✅ | Server took %ims to initialize!"):format(1000 * (workspace:GetServerTimeNow() - INIT_TIME_STAMP)))
end)