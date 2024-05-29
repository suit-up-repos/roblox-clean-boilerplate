--[[
    AnalyticsController.lua
    Author: Javi M (dig1t)

    Description: Handles impression part tracking
]]

--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage.Packages
local Dumpster = require(Packages.Dumpster)
local Knit = require(Packages.Knit)

local IMPRESSION_INTERVAL: number = 1
local IMPRESSION_MAX_DISTANCE: number = 100
local IMPRESSION_TAG = "ImpressionPart"
local IMPRESSION_ATTRIBUTE_NAME = "ImpressionName"

local localPlayer: Player = Players.LocalPlayer

local AnalyticsController = Knit.CreateController({
	Name = "AnalyticsController",
})

export type ImpressionPart = {
	part: BasePart,
	name: string,
}

-- Private
function AnalyticsController:_handleCharacterAdded(character: Model): ()
	self._character = character

	self._janitor:Add(function()
		self._character = nil
	end)

	self._janitor:Add(RunService.RenderStepped:Connect(function(_deltaTime: number)
		if os.time() - self._lastTrackedAt < IMPRESSION_INTERVAL then
			return
		end

		self._lastTrackedAt = os.time()
		self:_track()
	end))
end

function AnalyticsController:_addImpressionObject(part: BasePart): ()
	if not part or not part:IsA("BasePart") then return end

	local tagName: string = part:GetAttribute(IMPRESSION_ATTRIBUTE_NAME) or part.Name

	self._impressionParts[#self._impressionParts + 1] = {
		part = part,
		name = tagName,
	} :: ImpressionPart
end

function AnalyticsController:_track(): ()
	local playerOrigin: Vector3? = self._character and self._character.HumanoidRootPart and self._character.HumanoidRootPart.Position
	local camera: Camera? = Workspace.CurrentCamera

	if not playerOrigin or not camera then return end

	for index: number = #self._impressionParts, 1, -1 do
		local data: ImpressionPart = self._impressionParts[index]
		if not data.part or not data.part.Parent then
			table.remove(self._impressionParts, index)
			continue
		end

		local _vector: Vector3, isOnScreen: boolean = camera:WorldToScreenPoint(data.part.Position)

        local impressionDistance: number = (playerOrigin - data.part.Position).Magnitude
		if not isOnScreen or IMPRESSION_MAX_DISTANCE > impressionDistance then continue end

		self.AnalyticsService.AddTrackedValue:Fire({
			value = "Stats:PartImpression:" .. data.name,
		})
	end
end

-- Startup
function AnalyticsController:KnitInit(): ()
	self.AnalyticsService = Knit.GetService("AnalyticsService")

	self._janitor = Dumpster.new()

	self._impressionParts = {} :: { BasePart }
	self._lastTrackedAt = 0 :: number
end

function AnalyticsController:KnitStart(): ()
	task.spawn(function(): ()
		local playerTeleportedToGame: boolean = false
		local timeout: number = 10

		local teleportData = ReplicatedFirst:WaitForChild("teleportData", timeout) :: StringValue
        if not teleportData then return end

		playerTeleportedToGame = teleportData.Value == "no data" or #teleportData.Value == 0

		if playerTeleportedToGame then
			self.AnalyticsService.LogEvent:Fire({
				event = "Player:TeleportedToGame",
			})
		end
	end)

	task.spawn(function(): ()
		local playerJoinedFriend: boolean = false

		for _, _player: Player in pairs(Players:GetPlayers()) do
			if _player ~= localPlayer and localPlayer:IsFriendsWith(_player.UserId) then
				break
			end
		end

		if playerJoinedFriend then
			self.AnalyticsService.LogEvent:Fire({
				event = "Player:JoinedFriend",
			})
		end
	end)

	if localPlayer.Character then
		self:_handleCharacterAdded(localPlayer.Character)
	end

	localPlayer.CharacterAdded:Connect(function(character: Model)
		self:_handleCharacterAdded(character)
	end)

	localPlayer.CharacterRemoving:Connect(function()
		self._janitor:Cleanup()
	end)

	task.spawn(function(): ()
		for _, part in CollectionService:GetTagged(IMPRESSION_TAG) do
			self:_addImpressionObject(part)
		end

		CollectionService:GetInstanceAddedSignal(IMPRESSION_TAG):Connect(function(part: Instance?)
			self:_addImpressionObject(part)
		end)

		CollectionService:GetInstanceRemovedSignal(IMPRESSION_TAG):Connect(function(part: Instance?)
			for index, data: ImpressionPart in pairs(self._impressionParts) do
                if data.part ~= part then continue end

				table.remove(self._impressionParts, index)
				break
			end
		end)
	end)
end

return AnalyticsController