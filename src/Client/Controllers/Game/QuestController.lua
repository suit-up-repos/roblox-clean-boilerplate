--[[
    Author(s):
        Alex/EnDarke
    Description:
        Utility system for quest management and interaction. This code is run from the client.
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

-- Shared
local Shared = ReplicatedStorage.Shared
local ReplicatedData = require( Shared.ReplicatedData )

-- Replicated Data
local QuestData = ReplicatedData["Quests"]

-- Knit
local QuestController = Knit.CreateController({
	Name = "QuestController",
})

-- Public
function QuestController:GetPlayerQuestData(): {}
	return self.QuestData :: {}
end

function QuestController:GetQuestStatus(questName: string): {}
	local questData = self:GetPlayerQuestData()
	return questData[questName] :: {}
end

function QuestController:GetSegmentData(questName: string, segmentId: number): {} | nil
	if not (questName and segmentId) then
		return
	end

	-- Get the data for this quest
	local replicatedQuestData = QuestData[questName]
	local questSegments = if replicatedQuestData then replicatedQuestData.Segments else nil
	local segmentData = if questSegments then questSegments[segmentId] else nil
	if not segmentData then
		return
	end

	return segmentData :: {}
end

function QuestController:HasCompletedQuest(questName: string): boolean | nil
	if not questName then
		return
	end

	-- Get the player's quest status
	local questStatus = self:GetQuestStatus(questName)
	if not questStatus then
		return
	end

	return questStatus.Completed :: boolean | nil
end

-- Private
function QuestController:_onEnterQuest(questName): nil
	if not questName then
		return
	end

	-- Make sure the player has quest data for this quest
	if not self.QuestData[questName] then
		self.QuestData[questName] = {}
	end

	-- Override the quest data
	local savedData = self.QuestData[questName]
	savedData.Completed = false
	savedData.Segment = 1
	savedData.State = 0

	-- Setup the segment function for this quest
	if savedData._segmentCompleted then
		savedData._segmentCompleted()
		savedData._segmentCompleted = nil
	end

	-- Get the replicated quest data
	local replicatedQuestData = QuestData[questName]
	local segmentData = if replicatedQuestData then replicatedQuestData.Segments[1] else nil
	if not segmentData then
		return
	end

	-- Attempt to find if this segment has a startup function
	local startupFunction = segmentData.Client
	if not startupFunction then
		return
	end

	local segmentCompleted = startupFunction()
	if segmentCompleted then
		savedData._segmentCompleted = segmentCompleted
	end

	return
end

function QuestController:_onIncrement(questData: { string & number }): nil
	if not questData then
		return
	end

	-- Extract the data from `questData`
	local questName: string = questData[1]
	local segmentCount: number = questData[2]
	local stateCount: number = questData[3]
	if not (questName and segmentCount and stateCount) then
		return
	end

	-- Find the player's stored data for this quest
	local savedData = self.QuestData[questName]
	if not savedData then
		return
	end

	-- Override the quest data
	savedData.Segment = segmentCount
	savedData.State = stateCount

	return
end

function QuestController:_onNextSegment(questData: { string & number }): nil
	if not questData then
		return
	end

	-- Extract the data from `questData`
	local questName: string = questData[1]
	local segmentCount: number = questData[2]
	if not (questName and segmentCount) then
		return
	end

	-- Find the player's stored data for this quest
	local savedData = self.QuestData[questName]
	if not savedData then
		return
	end

	if savedData._segmentCompleted then
		savedData._segmentCompleted()
		savedData._segmentCompleted = nil
	end

	-- Get the replicated quest data
	local replicatedQuestData = QuestData[questName]
	local segmentData = if replicatedQuestData then replicatedQuestData.Segments[segmentCount] else nil
	if not segmentData then
		return
	end

	-- Attempt to find if this segment has a startup function
	local startupFunction = segmentData.Client
	if not startupFunction then
		return
	end

	-- Set the new segment completion function
	local segmentCompleted = startupFunction()
	if segmentCompleted then
		savedData._segmentCompleted = segmentCompleted
	end

	return
end

function QuestController:_onQuestComplete(questName: string): nil
	if not questName then
		return
	end

	-- Find the player's stored data for this quest
	local savedData = self.QuestData[questName]
	if not savedData then
		return
	end

	-- Make sure the segment completed function is set to nil
	if savedData._segmentCompleted then
		savedData._segmentCompleted()
		savedData._segmentCompleted = nil
	end

	savedData.Completed = true

	return
end

function QuestController:_setupSegmentFunctions(): nil
	-- Loop through the player's quest data
	for questName, savedData in ipairs(self.QuestData) do
		if savedData.Completed then
			continue
		end

		-- Make sure we can find data for this quest's saved segment
		local replicatedQuestData = QuestData[questName]
		local segmentData = if replicatedQuestData then replicatedQuestData.Segments[savedData.Segment] else nil
		if not segmentData then
			continue
		end

		-- Attempt to find if this segment has a startup function
		local startupFunction = segmentData.Client
		if not startupFunction then
			continue
		end

		-- Run the startup function and store the completion function
		local segmentCompleted = startupFunction()
		if segmentCompleted then
			savedData._segmentCompleted = segmentCompleted
		end
	end

	return
end

-- Startup
function QuestController:KnitInit()
	-- Services
	self._questService = Knit.GetService("QuestService")

	-- Properties
	self.QuestData = {}
end

function QuestController:KnitStart()
	-- Network Listeners
	self._questService.EnteredQuest:Connect(function(questName: string)
		self:_onEnterQuest(questName)
	end)

	self._questService.IncrementQuest:Connect(function(questData: { string & number })
		self:_onIncrement(questData)
	end)

	self._questService.NextSegment:Connect(function(questData: { string & number })
		self:_onNextSegment(questData)
	end)

	self._questService.CompletedQuest:Connect(function(questName: string)
		self:_onQuestComplete(questName)
	end)

	-- Let the server know that the client is ready for quest changes
	-- This is completely okay to do as it has no change other than ensuring load efforts are successful.
	local playerQuestData = self._questService:ClientLoaded()
	if playerQuestData then
		self.QuestData = playerQuestData
	end

	-- Load the player's quests
	self:_setupSegmentFunctions()
end

return QuestController