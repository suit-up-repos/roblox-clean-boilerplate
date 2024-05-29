--[[
    Author(s):
        Alex/EnDarke
    Description:
        Utility system for quest management and interaction. This code is run from the server.
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

-- Shared
local Shared = ReplicatedStorage.Shared
local ReplicatedData = require( Shared.ReplicatedData )

-- Replicated Data Constants
local QuestData = ReplicatedData["Quests"]

-- Knit
local QuestService = Knit.CreateService({
	Name = "QuestService",
	Client = {
		EnteredQuest = Knit.CreateSignal(),
		IncrementQuest = Knit.CreateSignal(),
		NextSegment = Knit.CreateSignal(),
		CompletedQuest = Knit.CreateSignal(),
	},
})

-- Local Utility Functions
local function waitForOutcome(timeout: number, callback)
	if not (timeout and callback) then
		return
	end

	-- Local Variables
	local timer: number = 0

	if not (callback()) then
		while timer < timeout do
			if callback() then
				timer = timeout
			else
				timer += task.wait()
			end
		end
	end

	return true
end

-- Public
function QuestService:EnterQuest(player: Player, questName: string): boolean | nil
	if not (player and questName) then
		return
	end
	if not self.LoadedPlayers[player] then
		waitForOutcome(3, function()
			return self.LoadedPlayers[player] ~= nil
		end)
	end

	-- Get the quest data
	local replicatedQuestData = QuestData[questName]

	-- Check if this player has already picked up this quest
	local playerQuestData = self._dataService:Get(player, "Quests", questName)
	if playerQuestData then
		-- If this quest isn't repeatable then let's stop it here
		if not playerQuestData.Completed then
			warn(`The quest {questName} has already been picked up for player: {player.Name}`)
			return
		end

		-- Check if this quest is repeatable
		if not replicatedQuestData.CanRepeat then
			warn(`The quest {questName} has already been completed for player: {player.Name}`)
			return
		end
	end

	-- Check the verification function
	local verificationFunc = if replicatedQuestData then replicatedQuestData.Verify else nil
	if verificationFunc then
		-- If the player failes the verification function then discontinue entering
		if not verificationFunc(player) then
			return
		end
	end

	-- Get the quest segment's function
	local segmentData = if replicatedQuestData then replicatedQuestData.Segments[1] else nil
	local serverFunction = if segmentData then segmentData.Server else nil

	if serverFunction then
		-- Set up the segment completed function
		local segmentCompleted = serverFunction(player)
		self.LoadedPlayers[player][questName] = segmentCompleted
	end

	-- Set the player's data
	self._dataService:Set(player, "Quests", questName, {
		Segment = 1,
		State = 0,
	})

	-- Communicate the new quest with the client
	self.Client.EnteredQuest:Fire(player, questName)

	return true
end

function QuestService:IncrementQuest(player: Player, questName: string, amount: number): boolean | nil
	if not (player and questName) then
		return
	end
	if not self.LoadedPlayers[player] then
		waitForOutcome(3, function()
			return self.LoadedPlayers[player] ~= nil
		end)
	end

	-- Make sure there's an increment amount
	if not amount then
		amount = 1
	end

	-- Update the player's data
	self._dataService:Update(player, "Quests", questName, function(playerQuestData)
		-- Check if this quest is already completed
		if playerQuestData.Completed then
			warn(`The quest {questName} has already been completed for player: {player.Name}`)
			return playerQuestData
		end

		-- Get the player's quest state
		local questSegment: number | boolean = if playerQuestData then playerQuestData.Segment else nil
		local questState: number = if playerQuestData then playerQuestData.State else nil
		if not (questSegment and questState) then
			return playerQuestData
		end

		-- Store the next segment number
		local replicatedQuestData = QuestData[questName]
		local segmentData = if replicatedQuestData then replicatedQuestData.Segments[questSegment] else nil
		local segmentRequirement: number = if segmentData then segmentData.Requirement else 1
		if not segmentData then
			return playerQuestData
		end

		-- Check if the player should go up a segment
		if questState + amount >= segmentRequirement then
			playerQuestData.Segment += 1
			playerQuestData.State = 0

			-- Attempt the next segment now that we went up by one!
			self:AttemptNextSegment(player, questName)
		else
			playerQuestData.State += 1
		end

		-- Communicate with the client to let them know the changes
		self.Client.IncrementQuest:Fire(player, {
			questName,
			playerQuestData.Segment,
			playerQuestData.State,
		})

		return playerQuestData
	end)

	return true
end

function QuestService:AttemptNextSegment(player: Player, questName: string): boolean | nil
	if not (player and questName) then
		return
	end
	if not self.LoadedPlayers[player] then
		waitForOutcome(3, function()
			return self.LoadedPlayers[player] ~= nil
		end)
	end

	-- Check the player's data
	local playerQuestData = self:GetPlayerQuestData(player, questName)
	local questSegment: number | boolean = if playerQuestData then playerQuestData.Segment else nil
	if not questSegment then
		return
	end

	-- Make sure the quest is not already completed
	if playerQuestData.Completed then
		warn(`The quest {questName} has already been completed for player: {player.Name}`)
		return
	end

	-- Cannot run this code if the segment is higher than the quest length
	local questLength: number = self:GetQuestLength(questName)
	if questSegment > questLength then
		self:CompleteQuest(player, questName)
	else
		self:ForceNextSegment(player, questName)
	end

	return true
end

function QuestService:ForceNextSegment(player: Player, questName: string): boolean | nil
	if not (player and questName) then
		return
	end
	if not self.LoadedPlayers[player] then
		waitForOutcome(3, function()
			return self.LoadedPlayers[player] ~= nil
		end)
	end

	-- Update player data
	self._dataService:Update(player, "Quests", questName, function(playerQuestData)
		if not (playerQuestData.Segment and playerQuestData.State) then
			return playerQuestData
		end

		-- Run the current segment completed function
		if self.LoadedPlayers[player][questName] then
			self.LoadedPlayers[player][questName](player)
		end

		-- Get quest data
		local replicatedQuestData = QuestData[questName]
		local segmentData = if replicatedQuestData then replicatedQuestData.Segments[playerQuestData.Segment] else nil
		local serverFunction = if segmentData then segmentData.Server else nil
		if serverFunction then
			-- Set up the segment completion function
			local segmentCompleted = serverFunction(player)
			if segmentCompleted then
				self.LoadedPlayers[player][questName] = segmentCompleted
			end
		end

		-- Tell the client it got to the next segment
		self.Client.NextSegment:Fire(player, {
			questName,
			playerQuestData.Segment,
		})

		return playerQuestData
	end)

	return true
end

function QuestService:CompleteQuest(player: Player, questName: string): boolean | nil
	if not (player and questName) then
		return
	end
	if not self.LoadedPlayers[player] then
		waitForOutcome(3, function()
			return self.LoadedPlayers[player] ~= nil
		end)
	end

	-- Run the current segment completed function
	if self.LoadedPlayers[player][questName] then
		self.LoadedPlayers[player][questName](player)
	end

	-- Update the player's quest data
	self._dataService:Update(player, "Quests", questName, function(playerQuestData)
		playerQuestData.Completed = true
		return playerQuestData
	end)

	-- Run the quest completion function if there is one
	local replicatedQuestData = QuestData[questName]
	local questOnComplete = if replicatedQuestData then replicatedQuestData.OnCompletion else nil
	if questOnComplete then
		questOnComplete(player)
	end

	-- Update the client
	self.Client.CompletedQuest:Fire(player, questName)

	return true
end

function QuestService:HasCompletedQuest(player: Player, questName: string): boolean | nil
	if not (player and questName) then
		return
	end

	-- Get the player's quest data
	local playerQuestData = self._dataService:Get(player, "Quests", questName)
	local hasCompleted: boolean = if playerQuestData then playerQuestData.Completed else nil
	if not hasCompleted then
		return
	end

	return true
end

function QuestService:GetQuestLength(questName: string): number | nil
	if not questName then
		return
	end

	-- Get the data for this quest
	local replicatedQuestData = QuestData[questName]
	local questSegments = if replicatedQuestData then replicatedQuestData.Segments else nil
	if not questSegments then
		return
	end

	return #questSegments
end

function QuestService:GetSegmentData(questName: string, segmentId: number): {} | nil
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

-- Player Related
function QuestService:_playerAdded(player: Player)
	if not player then
		return
	end
	if not self.LoadedPlayers[player] then
		waitForOutcome(3, function()
			return self.LoadedPlayers[player] ~= nil
		end)
	end

	-- Get player's quest data
	local playerQuestData = self:GetPlayerQuestData(player)
	if not playerQuestData then
		return
	end

	-- Load in all current segment functions
	for questName: string, savedData in pairs(playerQuestData) do
		if savedData.Completed then
			continue
		end

		-- Make sure we can find data for this quest's saved segment
		local replicatedQuestData = QuestData[questName]
		local segmentData = if replicatedQuestData then replicatedQuestData.Segments[savedData.Segment] else nil
		if not segmentData then
			continue
		end

		-- Run the startup function and store the completion function
		local startupFunction = segmentData.Server
		if startupFunction then
			local segmentCompleted = startupFunction(player)
			if segmentCompleted then
				self.LoadedPlayers[player][questName] = segmentCompleted
			end
		end
	end
end

function QuestService:_playerRemoving(player: Player)
	if not player then
		return
	end
	if not QuestService.LoadedPlayers[player] then
		return
	end

	QuestService.LoadedPlayers[player] = nil
end

function QuestService:GetPlayerQuestData(player: Player, questName: string): {} | nil
	if not player then
		return
	end

	-- Get the player data
	local playerQuestData = self._dataService:Get(player, "Quests")
	if not playerQuestData then
		return
	end

	if not questName then
		return playerQuestData :: {}
	else
		return playerQuestData[questName] :: {}
	end
end

-- Private
function QuestService:_clientLoaded(player: Player): {} | nil
	if not player then
		return
	end

	if not self.LoadedPlayers[player] then
		self.LoadedPlayers[player] = {}
	end

	-- Get player's quest data
	local playerQuestData = self._dataService:Get(player, "Quests")
	return playerQuestData :: {}
end

-- Client
function QuestService.Client:EnterQuest(player: Player, questName: string): boolean | nil
	return self.Server:EnterQuest(player, questName) :: boolean
end

function QuestService.Client:GetPlayerQuestData(player: Player): {} | nil
	return self.Server:GetPlayerQuestData(player) :: {}
end

function QuestService.Client:ClientLoaded(player: Player): {}
	return self.Server:_clientLoaded(player) :: {}
end

-- Startup
function QuestService:KnitInit()
	-- Services
	self._dataService = Knit.GetService("DataService")

	-- Properties
	self.LoadedPlayers = {}
end

function QuestService:KnitStart()
	-- Setup all player related content
	task.spawn(function()
		for _, player: Player in ipairs(Players:GetPlayers()) do
			self:_playerAdded(player)
		end
	end)

	Players.PlayerAdded:Connect(function(player: Player)
		self:_playerAdded(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self:_playerRemoving(player)
	end)
end

return QuestService