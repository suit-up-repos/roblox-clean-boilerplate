--[[
    Author(s):
        Alex/EnDarke
    Description:
        Player data service to handle storing and loading player data.
]]

local Parent = script.Parent

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Packages
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

-- Dev Packages
local DevPackages = ServerStorage.DevPackages
local ProfileService: { () -> any } = require(DevPackages.ProfileService)

-- System Modules
local SystemModules = Parent.Parent.Parent.Modules
local DataSettings = require( SystemModules.DataSettings )
local PlayerDataFormat = require( SystemModules.PlayerDataFormat )

-- Custom Types
type void = nil
type func = (any) -> any

-- Constants
local KEY: string = DataSettings["DATA_KEY"]
local DATA_VERSION: string = DataSettings["DATA_SCOPE"]

local PROFILES = {}
local PLAYER_STORE = ProfileService.GetProfileStore({ Name = "Players", Scope = DATA_VERSION }, PlayerDataFormat)

-- Initializing Knit
local DataService = Knit.CreateService({
	Name = "DataService",
	Client = {
		OnDataUpdate = Knit.CreateSignal(),
	},
})

-- Local Utility Functions
local function createPlayerKey(userId: number): string | nil
	if not userId then return end
	return KEY .. userId
end

local function runProfileFunction(player: Player, funcName: string, ...): ()
	if not (player and funcName) then return end

	-- Local Variables
	local profile = PROFILES[player]

	-- Check for profile and run profile function
	if not profile then return end
	profile[funcName](profile, ...)
end

-- Knit Spot Functions
function DataService.PlayerAdded(player: Player): ...any
	if not player then return end

	-- Local Variables
	local userId: number = player and player.UserId
	local profile = PLAYER_STORE:LoadProfileAsync(createPlayerKey(userId), "ForceLoad")

	-- Did the profile load correctly?
	if not profile then
		player:Kick("Failed to load data!")
		return false
	end

	-- Did the player leave before data was loaded?
	if not player:IsDescendantOf(Players) then
		profile:Release()
		return false
	end

	-- Finalizing profile setup
	PROFILES[player] = profile

	-- Profile config
	runProfileFunction(player, "AddUserId", userId)
	runProfileFunction(player, "Reconcile")

	-- Listen for player profile unloading
	runProfileFunction(player, "ListenToRelease", function()
		player:Kick("Data ran into an error! Please rejoin!")
	end)

	-- Data load finalization
	player:SetAttribute("DataLoaded", true)

	return true
end

function DataService.PlayerRemoving(player: Player): ...any
	if not player then return end

	-- Find player data
	local playerData = DataService:Get(player)
	if not playerData then return end

	-- Remove temporary data
	playerData.Temporary = nil

	-- Release profile
	runProfileFunction(player, "Release")
end

-- Knit Two-Spot Functions
function DataService:Get(player: Player, from: string, specific: string): {} | nil
	if not player then return end
	if not player:IsDescendantOf(Players) then return end
	if not player:GetAttribute("DataLoaded") then
		local _dataLoaded = player:GetAttribute("DataLoaded") or player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end

	-- Local Variables
	local profile = PROFILES[player]
	local playerData = if profile then profile.Data else nil
	if not playerData then return end

	-- Check if it's a specific value
	if from then
		if not specific then
			return playerData[from]
		end
		return playerData[from][specific]
	end

	return playerData :: {}
end

function DataService:Set(player: Player, from: string, specific: string, value: any): boolean | nil
	if not (player and from and specific) then return end
	if not player:GetAttribute("DataLoaded") then
		local _dataLoaded = player:GetAttribute("DataLoaded") or player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end

	-- Local Variables
	local playerData = self:Get(player)

	-- Check for data loaded success
	if not playerData then return end

	-- Set the data value
	if from then
		if not specific then
			playerData[from] = value
		else
			playerData[from][specific] = value
		end
	end

	return true
end

function DataService:Update(player: Player, from: string, specific: string, callback: func): boolean | nil
	if not (player and from and specific) then return end
	if not player:GetAttribute("DataLoaded") then
		local _dataLoaded = player:GetAttribute("DataLoaded") or player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end

	-- Local Variables
	local playerData = self:Get(player)
	if not playerData then return end

	-- Check for proper data
	if from then
		if not specific then
			local callbackResult: any = callback(playerData[from])
			if callbackResult == nil then return end

			self:Set(player, from, nil, callbackResult)
			return true
		end
	end

	-- Run the callback function
	local callbackResult: any = callback(playerData[from][specific])
	if callbackResult == nil then return end

	-- Set the data value
	self:Set(player, from, specific, callbackResult)

	return true
end

function DataService:_Reconcile(player: Player): ...any
	if not player then return end
	runProfileFunction(player, "Reconcile")
end

function DataService:_Wipe(player: Player): ...any
	if not player then return end
	runProfileFunction(player, "WipeProfileAsync")
end

-- Knit Client Functions
function DataService.Client:Get(player: Player, ...): {} | nil
	if not player then return end
	return self.Server:Get(player, ...) :: {}
end

-- Knit Startup
function DataService:KnitInit()
end

function DataService:KnitStart()
end

return DataService
