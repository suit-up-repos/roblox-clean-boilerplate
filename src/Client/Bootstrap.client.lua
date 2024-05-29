--[[
    Author(s):
        Alex/EnDarke
    Description:
        Bootstraps the client to the Knit framework.
]]

local Parent = script.Parent

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Packages = ReplicatedStorage.Packages
local Knit = require( Packages.Knit )

-- Folders
local ControllerFolder: Folder = Parent.Controllers

-- Waiting for player data to load
local _dataLoaded: boolean = Knit.Player:GetAttribute("DataLoaded") or Knit.Player:GetAttributeChangedSignal("DataLoaded"):Wait()

-- Initializing Knit
local INIT_TIME_STAMP: number = workspace:GetServerTimeNow()
Knit.AddControllersDeep(ControllerFolder)

Knit.Start({ ServicePromises = false }):catch(warn):andThen(function(): ()
    -- Logging how long it took to initialize Knit on the client.
    print(("✅ | Client took %ims to initialize!"):format(1000 * (workspace:GetServerTimeNow() - INIT_TIME_STAMP)))
end)