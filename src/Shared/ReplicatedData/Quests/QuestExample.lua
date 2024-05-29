-- Services
local RunService = game:GetService("RunService")

-- Local Utility Functions
local function ForServer<T>(value): T | nil -- Verifies this value is only true when initiated on the server
	if not RunService:IsServer() then
		return
	end
	return value :: T
end

return {
	CanRepeat = true,

	-- If the "Verify" function exists within a quest
	-- it will run prior to entering the quest to ensure the player can start this quest.
	-- Use this with means to provide requirements to start this quest.
	-- EXAMPLE: Position checking to make sure a player is near the gather point, or this player completed a different quest.
	Verify = ForServer(function(player): boolean
		return true
	end),

	-- This function will run on the server once the player completes the final segment to the quest.
	-- It's not a required value to have, but helpful when needed.
	OnCompletion = ForServer(function(player: Player): nil
		return nil
	end),

	-- Table list of segments for the quest
	Segments = {
		[1] = {
			SegmentTitle = "SEGMENT_TITLE",
			Requirement = 3,

			Server = ForServer(function(player: Player): () -> ()
				return function() end
			end),

			Client = function(): () -> ()
				return function() end
			end,
		},

		[2] = {
			SegmentTitle = "SEGMENT_TITLE",
			Requirement = 1,

			Server = ForServer(function(player: Player): () -> ()
				return function() end
			end),

			Client = function(): () -> ()
				return function() end
			end,
		},

		[3] = {
			SegmentTitle = "SEGMENT_TITLE",
			Requirement = 1,

			Server = ForServer(function(player: Player): () -> ()
				return function() end
			end),

			Client = function(): () -> ()
				return function() end
			end,
		},
	},
}