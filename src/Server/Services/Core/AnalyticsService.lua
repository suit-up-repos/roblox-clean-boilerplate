--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

-- Packages
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Promise = require(Packages.Promise)

-- DevPackages
local DevPackages = ServerStorage.DevPackages
local GameAnalytics = require(DevPackages.GameAnalytics)

-- Prevent unwanted SDK warnings and errors from showing in production
if not RunService:IsStudio() then
	GameAnalytics.Logger.w = function() end -- Force disable warnings
	GameAnalytics.Logger.e = function() end -- Force disable errors
end

--[=[
	@class AnalyticsService

	Author: Javi M (dig1t)

	Knit service that handles GameAnalytics API requests.

	The API keys can be found inside game settings of your GameAnalytics game page.

	Events that happen during a mission (kills, deaths, rewards) should be
	tracked and logged after the event ends	to avoid hitting API limits.
	For example, if a player kills an enemy during a mission, the kill should be
	tracked and logged (sum of kills) at the end of the mission.

	Refer to [GameAnalytics docs](https://docs.gameanalytics.com/integrations/sdk/roblox/event-tracking) for more information and use cases.

	### Quick Start

	In order to use this service, you must first configure it with `AnalyticsService:SetOptions()` (example: in the main server script)

	To configure AnalyticsService:
	```lua
	local AnalyticsService = Knit.GetService("AnalyticsService")

	AnalyticsService:SetOptions({
		currencies = { "Coins" },
		build = "1.0.0",
		gameKey = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
		secretKey = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
		logErrors = false, -- Optional, defaults to false
	})
	```

	Using AnalyticsService to track events on the client:
	```lua
	-- Inside a LocalScript
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Players = game:GetService("Players")

	local Packages = ReplicatedStorage.Packages
	local Knit = require(Packages.Knit)

	Knit.Start():await() -- Wait for Knit to start

	AnalyticsService.AddTrackedValue:Fire({ -- This adds a value to a tracked event
		event = "UIEvent:OpenedShop",
		value = 1
	})

	AnalyticsService.LogEvent:Fire({ -- This logs an event
		event = "UIEvent:FTUE:Completed"
	})

	AnalyticsService.AddDelayedEvent:Fire({ -- This adds a delayed event that fires when the player leaves
		event = "UIEvent:ClaimedReward"
	})
	```

	Logging currency transactions
	```lua
	-- Log 100 coins being gained for completing FTUE
	AnalyticsService:LogResourceEvent({
		userId = player.UserId,
		eventType = "Reward",
		currency = "Coins",
		itemId = "FTUE Reward",
		flowType = "Source",
		amount = 100
	})

	-- Log 100 coins being spent in a shop
	AnalyticsService:LogPurchase({
		userId = player.UserId,
		eventType = "Shop",
		currency = "Coins",
		itemId = "Red Car",
		amount = 100
	})
	```

	### Setting up impression parts

	To track impressions, you must first add a part anywhere in the workspace with the tag `ImpressionPart`.

	Then, add an attribute to the part named `ImpressionName` to define the name of the impression. (example: "BrandLogo", "BrandBillboard")

	If there is no `ImpressionName` attribute, then the part's name will be used as the impression's name.
]=]
local AnalyticsService = Knit.CreateService({
	Name = "AnalyticsService",
	Client = {
		LogEvent = Knit.CreateSignal(),
		AddDelayedEvent = Knit.CreateSignal(),
		AddTrackedValue = Knit.CreateSignal(),
		SetCustomDimension = Knit.CreateSignal(),
	},
})

--[=[
	@interface DimensionData
	.userId number
	.dimension string -- Allowed dimensions: "dimension01", "dimension02", "dimension03"
	.value string
	@within AnalyticsService
]=]
export type DimensionData = {
	userId: number,
	dimension: string,
	value: string,
}

--[=[
	@interface CustomDimensions
	.dimension01 string?
	.dimension02 string?
	.dimension03 string?
	@within AnalyticsService
]=]
export type CustomDimensions = {
	dimension01: string?,
	dimension02: string?,
	dimension03: string?,
}

--[=[
	@interface AnalyticsOptions
	.currencies { string? }? -- List of all in-game currencies (defaults to { "Coins" })
	.build string? -- Game version
	.gameKey string -- GameAnalytics game key
	.secretKey string -- GameAnalytics secret key
	.customDimensions CustomDimensions? -- Custom dimensions to be used in GameAnalytics (refer to [GameAnalytics docs](https://docs.gameanalytics.com/advanced-tracking/custom-dimensions) about dimensions)
	.logErrors boolean? -- Whether or not to log errors (defaults to false)
	@within AnalyticsService
]=]
export type AnalyticsOptions = {
	currencies: { string? }?,
	build: string?,
	gameKey: string,
	secretKey: string,
	customDimensions: CustomDimensions?,
	logErrors: boolean?,
}

--[=[
	@interface PlayerEvent
	.userId number
	.event string
	.value number?
	@within AnalyticsService
]=]
export type PlayerEvent = {
	userId: number,
	event: string,
	value: number?,
}

--[=[
	@interface MarketplacePurchaseEvent
	.userId number
	.itemType string
	.id number | string
	.robuxPrice number?
	.cartType string
	@within AnalyticsService
]=]
export type MarketplacePurchaseEvent = {
	userId: number,
	itemType: string,
	id: number | string,
	robuxPrice: number?,
	cartType: string,
}

--[=[
	@interface PurchaseEvent
	.userId number
	.eventType string -- 1 by default
	.itemId string
	.currency string -- In-game currency type used
	.flowType string? -- Allowed flow types: "Sink", "Source" (defaults to "Sink")
	.amount number?
	@within AnalyticsService

	- Currency is the in-game currency type used, it must be defined in `AnalyticsService:SetOptions()`
]=]
export type PurchaseEvent = {
	userId: number,
	eventType: string,
	itemId: string,
	currency: string,
	flowType: string?,
	amount: number?,
}

--[=[
	@interface ResourceEvent
	.userId number
	.eventType string
	.itemId string -- unique id of item (example: "100 Coins", "Coin Pack", "Red Loot Box", "Extra Life")
	.currency string
	.flowType string
	.amount number
	@within AnalyticsService

	- Currency is the in-game currency type used, it must be defined in `AnalyticsService:SetOptions()`
]=]
export type ResourceEvent = {
	userId: number,
	eventType: string,
	itemId: string,
	currency: string,
	flowType: string,
	amount: number,
}

--[=[
	@interface ErrorEvent
	.message string
	.severity string? -- Allowed severities: "debug", "info", "warning", "error", "critical" (defaults to "error")
	.userId number
	@within AnalyticsService
]=]
export type ErrorEvent = {
	message: string,
	severity: string?,
	userId: number,
}

--[=[
	@interface ProgressionEvent
	.userId number
	.status string -- Allowed statuses: "Start", "Fail", "Complete"
	.progression01 string -- Mission, Level, etc.
	.progression02 string? -- Location, etc.
	.progression03 string? -- Level, etc. (if used then progression02 is required)
	.score number? -- Adding a score is optional
	@within AnalyticsService
]=]
export type ProgressionEvent = {
	userId: number,
	status: string,
	progression01: string,
	progression02: string?,
	progression03: string?,
	score: number?,
}

--[=[
	@interface DelayedEvent
	.userId number?
	.event string
	.value number?
	@within AnalyticsService
]=]
export type DelayedEvent = {
	userId: number?,
	event: string,
	value: number?,
}

--[=[
	@interface TrackedValueEvent
	.userId number?
	.event string
	.value number?
	@within AnalyticsService
]=]
export type TrackedValueEvent = {
	userId: number?,
	event: string,
	value: number?,
}

--[=[
	@interface DimensionEvent
	.dimension string -- Allowed dimensions: "dimension01", "dimension02", "dimension03"
	.value string
	@within AnalyticsService
]=]
export type DimensionEvent = {
	dimension: string,
	value: string,
}

--[=[
	@interface RemoteConfig
	.player Player?
	.name string
	.defaultValue string
	.value string?
	@within AnalyticsService
]=]
export type RemoteConfig = {
	player: Player?,
	name: string,
	defaultValue: string,
	value: string?,
}

--[=[
	@interface PsuedoPlayerData
	.OS string -- "uwp_desktop 0.0.0"
	.Platform string
	.SessionID string -- lowercase GenerateGUID(false)
	.Sessions number -- 1
	.CustomUserId string -- "Server
	@within AnalyticsService
]=]
export type PsuedoPlayerData = {
	OS: "uwp_desktop 0.0.0",
	Platform: "uwp_desktop",
	SessionID: string,
	Sessions: number,
	CustomUserId: "Server",
}

--[=[
	@interface ServerPsuedoPlayer
	.id string -- "DummyId"
	.PlayerData PsuedoPlayerData
	@within AnalyticsService
]=]
export type ServerPsuedoPlayer = {
	id: "DummyId",
	PlayerData: PsuedoPlayerData,
}

function AnalyticsService:KnitInit()
	self._events = {}
	self._trackedEvents = {}
	self._cache = {}
	self._resourceEventTypes = {}
end

function AnalyticsService:_getProductInfo(
	productId: number,
	infoType: Enum.InfoType?
): { Name: string, PriceInRobux: number }?
	local _infoType: Enum.InfoType = typeof(infoType) == "EnumItem" and infoType or Enum.InfoType.Asset
	local infoTypeName: string = _infoType.Name

	local success, result = pcall(function()
		local cacheIndex: string = `{infoTypeName}-{productId}`

		if self._cache[cacheIndex] then
			return self._cache[cacheIndex]
		end

		local productInfo: {} = MarketplaceService:GetProductInfo(productId, _infoType)

		self._cache[cacheIndex] = productInfo

		return productInfo
	end)

	return success and result or nil
end

--- @private
function AnalyticsService:_start(): nil
	GameAnalytics:configureBuild(self._options.build)

	if self._options.customDimensions.dimension01 then
		GameAnalytics:configureAvailableCustomDimensions01(self._options.customDimensions.dimension01)
	end

	if self._options.customDimensions.dimension02 then
		GameAnalytics:configureAvailableCustomDimensions02(self._options.customDimensions.dimension02)
	end

	if self._options.customDimensions.dimension03 then
		GameAnalytics:configureAvailableCustomDimensions03(self._options.customDimensions.dimension03)
	end

	GameAnalytics:configureAvailableResourceCurrencies(self._options.currencies)

	GameAnalytics:setEnabledInfoLog(false)
	GameAnalytics:setEnabledVerboseLog(false)
	GameAnalytics:setEnabledDebugLog(false)

	GameAnalytics:setEnabledReportErrors(self._options.logErrors == true)

	GameAnalytics:setEnabledAutomaticSendBusinessEvents(false)

	GameAnalytics:initServer(self._options.gameKey, self._options.secretKey)

	self.Client.LogEvent:Connect(function(
		player: Player,
		data: {
			event: string,
			value: number?,
		}
	)
		if data == nil or type(data) ~= "table" then
			return
		end

		if data.event == nil then
			return
		end

		if type(data.event) ~= "string" then
			return
		end

		if data.value ~= nil and type(data.value) ~= "number" then
			return
		end

		self:LogPlayerEvent({
			userId = player.UserId,
			event = data.event,
			value = data.value,
		})
	end)

	-- Logs an event to be sent once the player is leaving the game
	self.Client.AddDelayedEvent:Connect(function(player: Player, data: DelayedEvent)
		if data == nil or type(data) ~= "table" then
			return
		end

		if data.event == nil then
			return
		end

		if type(data.event) ~= "string" then
			return
		end

		if data.userId ~= nil and type(data.userId) ~= "number" then
			return
		end

		if data.value ~= nil and type(data.value) ~= "number" then
			return
		end

		self:AddDelayedEvent({
			userId = player.UserId,
			event = data.event,
			value = data.value,
		})
	end)

	-- Adds a value to a tracked event, it will be sent once the player is leaving the game
	self.Client.AddTrackedValue:Connect(function(player: Player, data: TrackedValueEvent)
		if data == nil or type(data) ~= "table" then
			return
		end

		if data.event == nil then
			return
		end

		if type(data.event) ~= "string" then
			return
		end

		if data.userId ~= nil and type(data.userId) ~= "number" then
			return
		end

		if data.value ~= nil and type(data.value) ~= "number" then
			return
		end

		self:AddTrackedValue({
			userId = player.UserId,
			event = data.event,
			value = data.value,
		})
	end)

	self.Client.SetCustomDimension:Connect(function(player: Player, data: DimensionEvent)
		if data == nil or type(data) ~= "table" then
			return
		end

		if data.value == nil or data.dimension == nil then
			return
		end

		if type(data.value) ~= "string" then
			return
		end

		if type(data.dimension) ~= "string" then
			return
		end

		self:SetCustomDimension({
			userId = player.UserId,
			dimension = data.dimension,
			value = data.value,
		})
	end)

	MarketplaceService.PromptBundlePurchaseFinished:Connect(
		function(player: Player | Instance, bundleId: number, purchased: boolean): ()
			if not purchased then return end
            if not player:IsA("Player") then return end

			local productInfo = self:_getProductInfo(bundleId, Enum.InfoType.Bundle)

			self:LogMarketplacePurchase({
				userId = player.UserId,
				itemType = "Bundle",
				id = productInfo and productInfo.Name or bundleId,
				cartType = "PromptPurchase",
				robuxPrice = productInfo and productInfo.PriceInRobux,
			})
		end
	)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, gamePassId: number, purchased: boolean)
			if not purchased then
				return
			end

			local productInfo = self:_getProductInfo(gamePassId, Enum.InfoType.GamePass)

			self:LogMarketplacePurchase({
				userId = player.UserId,
				itemType = "GamePass",
				id = productInfo and productInfo.Name or gamePassId,
				cartType = "PromptPurchase",
				robuxPrice = productInfo and productInfo.PriceInRobux,
			})
		end
	)

	MarketplaceService.PromptProductPurchaseFinished:Connect(
		function(userId: number, productId: number, purchased: boolean)
			if not purchased then
				return
			end

			local productInfo = self:_getProductInfo(productId, Enum.InfoType.Product)

			self:LogMarketplacePurchase({
				userId = userId,
				itemType = "Product",
				id = productInfo and productInfo.Name or productId,
				cartType = "PromptPurchase",
				robuxPrice = productInfo and productInfo.PriceInRobux,
			})
		end
	)

	MarketplaceService.PromptPurchaseFinished:Connect(function(player: Player, assetId: number, purchased: boolean)
		if not purchased then
			return
		end

		local productInfo = self:_getProductInfo(assetId, Enum.InfoType.Asset)

		self:LogMarketplacePurchase({
			userId = player.UserId,
			itemType = "Asset",
			id = productInfo and productInfo.Name or assetId,
			cartType = "PromptPurchase",
			robuxPrice = productInfo and productInfo.PriceInRobux,
		})
	end)

	MarketplaceService.PromptSubscriptionPurchaseFinished:Connect(
		function(player: Player, subscriptionId: string, didTryPurchasing: boolean)
			if not didTryPurchasing then
				return
			end

			local success, result = pcall(function()
				local cacheIndex: string = `subscription-{subscriptionId}`

				if self._cache[cacheIndex] then
					return self._cache[cacheIndex]
				end

				local productInfo = MarketplaceService:GetSubscriptionProductInfoAsync(subscriptionId)

				self._cache[cacheIndex] = productInfo

				return productInfo
			end)

			local robuxPrice = 0

			if success then
				local priceNumberString = string.match(result.DisplayPrice, "%d+%.?%d*")
				local dollarPrice = tonumber(priceNumberString or "")

				if dollarPrice ~= nil then
					-- Convert from USD to Robux using GA's conversion rate
					robuxPrice = ((dollarPrice * 100) / 0.7) / 0.35
				end
			end

			self:LogMarketplacePurchase({
				userId = player.UserId,
				itemType = "Subscription",
				id = success and result.Name or subscriptionId,
				amount = robuxPrice,
				cartType = "PromptPurchase",
			})
		end
	)

	Players.PlayerAdded:Connect(function(player: Player)
		if player.FollowUserId ~= 0 then
			self:LogPlayerEvent({
				userId = player.UserId,
				event = "Player:FollowedPlayer",
			})
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self:_flushTrackedEvents(player)
	end)

	return
end

--[=[
	@private
	@param fn string
	@param ... any
]=]
function AnalyticsService:_wrapper(fn: string, ...): nil
	local args = { ... }

	local promiseFunction = Promise.promisify(GameAnalytics[fn])
	promiseFunction(GameAnalytics, unpack(args)):catch(warn)

	return
end

--- @private
function AnalyticsService:_flushTrackedEvents(player: Player): nil
	if not player or not self._enabled then
		return
	end

	local userId: number = player.UserId

	if self._events[userId] then
		for _, event in pairs(self._events[userId]) do
			self:LogPlayerEvent({
				userId = userId,
				event = event.event,
				value = event.value,
			})
		end

		self._events[userId] = nil
	end

	if self._trackedEvents[userId] then
		for event, value in pairs(self._trackedEvents[userId]) do
			self:LogPlayerEvent({
				userId = userId,
				event = event,
				value = value,
			})
		end

		self._trackedEvents[userId] = nil
	end

	return
end

--[=[
	Used to set the options for AnalyticsService

	@param options table
	@return nil
]=]
function AnalyticsService:SetOptions(options: AnalyticsOptions): nil
	if self._enabled then
		warn("AnalyticsService:SetOptions() - AnalyticsService is already configured")

		return
	end

	assert(typeof(options) == "table", "AnalyticsService.SetConfig - options is required")
	assert(options.gameKey, "AnalyticsService.SetConfig - gameKey is required")
	assert(options.secretKey, "AnalyticsService.SetConfig - secretKey is required")
	assert(
		typeof(options.logErrors) == "boolean" or options.logErrors == nil,
		"AnalyticsService.SetConfig - logErrors must be a boolean or nil"
	)

	if options.customDimensions then
		assert(
			typeof(options.customDimensions) == "table",
			"AnalyticsService.SetConfig - customDimensions must be a table"
		)

		local availableDimensions: { string } = {
			"dimension01",
			"dimension02",
			"dimension03",
		}

		for dimension: string?, values: { string? }? in pairs(options.customDimensions) do
			assert(typeof(dimension) == "string", "AnalyticsService.SetConfig - dimension index must be a string")
			assert(
				table.find(availableDimensions, dimension),
				"AnalyticsService.SetConfig - customDimensions." .. dimension .. " is not a valid dimension"
			)
			assert(typeof(values) == "table", "AnalyticsService.SetConfig - " .. dimension .. " must be a table")

			for _, value: string? in pairs(values) do
				assert(
					typeof(value) == "string",
					"AnalyticsService.SetConfig - customDimensions." .. dimension .. " table can only contain strings"
				)
			end
		end
	end

	self._enabled = true
	self._options = {}
	self._options.currencies = options.currencies or { "Coins" }
	self._options.build = options.build or "dev"
	self._options.gameKey = options.gameKey
	self._options.secretKey = options.secretKey
	self._options.customDimensions = options.customDimensions or {}
	self._options.logErrors = options.logErrors or false

	self:_start()

	return
end

--[=[
	Used to track player events (example: player killed an enemy, player completed a mission, etc.)

	Examples
	```lua
	AnalyticsService:LogPlayerEvent({
		userId = player.UserId,
		event = "Player:KilledEnemy",
		value = 1 -- Killed 1 enemy
	})
	AnalyticsService:LogPlayerEvent({
		userId = player.UserId,
		event = "Player:CompletedMission",
		value = 1 -- Completed 1 mission
	})
	AnalyticsService:LogPlayerEvent({
		userId = player.UserId,
		event = "Player:Death",
		value = 1
	})
	```

	@param data PlayerEvent
	@return Promise<T>
]=]
function AnalyticsService:LogPlayerEvent(data: PlayerEvent)
	return Promise.new(function(resolve, reject)
		if not self._enabled then
			return reject("AnalyticsService must be configured with :SetOptions()")
		elseif not data then
			return reject("AnalyticsService.LogPlayerEvent - data is required")
		elseif not data.userId then
			return reject("AnalyticsService.LogPlayerEvent - userId is required")
		elseif not data.event then
			return reject("AnalyticsService.LogPlayerEvent - event is required")
		elseif data.value ~= nil and typeof(data.value) ~= "number" then
			return reject("AnalyticsService.LogPlayerEvent - value must be a number")
		end

		-- Sanitize event string to prevent errors
		data.event = string.gsub(data.event, "[^%w%-_%.%s:]", "_")

		-- Trim trailing colon and spaces
		data.event = string.gsub(data.event, ":%s*$", "")

		self:_wrapper("addDesignEvent", data.userId, {
			eventId = data.event,
			value = data.value,
		})

		return resolve()
	end)
end

--[=[
	AnalyticsService:LogMarketplacePurchase({
		userId = player.UserId,
		itemType = "Product",
		id = 000000000, -- Asset Id
		cartType = "PromptPurchase",
		robuxPrice = 100
	})
	```

	@param data MarketplacePurchaseEvent
	@return Promise<T>
]=]
function AnalyticsService:LogMarketplacePurchase(data: MarketplacePurchaseEvent)
	return Promise.new(function(resolve, reject)
		if not self._enabled then
			return reject("AnalyticsService must be configured with :SetOptions()")
		elseif not data.userId then
			return reject("userId is required")
		elseif not data.itemType then
			return reject("itemType is required")
		elseif not data.id then
			return reject("id is required")
		elseif not data.cartType then
			return reject("cartType is required")
		end

		self:_wrapper("addBusinessEvent", data.userId, {
			itemType = data.itemType,
			itemId = typeof(data.id) == "number" and tostring(data.id) or data.id,
			amount = data.robuxPrice or 0,
			cartType = data.cartType,
		})

		return resolve()
	end)
end

--[=[
	Shortcut function for LogResourceEvent
	Used to log in-game currency purchases

	Example Use:
	```lua
	AnalyticsService:LogPurchase({
		userId = player.UserId,
		eventType = "Shop",
		currency = "Coins",
		itemId = "Red Paintball Gun"
	})
	```

	@param data PurchaseEvent
	@return Promise<T>
]=]
function AnalyticsService:LogPurchase(data: PurchaseEvent)
	return Promise.new(function(resolve, reject)
		if not self._enabled then
			return reject("AnalyticsService must be configured with :SetOptions()")
		elseif not data.userId then
			return reject("userId is required")
		elseif typeof(data.eventType) ~= "string" then
			return reject("eventType must be a string")
		elseif not data.itemId then
			return reject("itemId is required")
		elseif not data.currency then
			return reject("currency is required")
		elseif not table.find(self._options.currencies, data.currency) then
			return reject("currency type is invalid")
		elseif data.amount ~= nil and typeof(data.amount) ~= "number" then
			return reject("amount is required")
		elseif data.flowType ~= nil and not GameAnalytics.EGAResourceFlowType[data.flowType] then
			return reject("flow type is invalid")
		end

		self:LogResourceEvent({
			userId = data.userId,
			amount = data.amount or 1,
			currency = data.currency,
			flowType = (
				data.flowType == GameAnalytics.EGAResourceFlowType.Source
				and GameAnalytics.EGAResourceFlowType.Source
			)
				or (data.flowType == GameAnalytics.EGAResourceFlowType.Sink and GameAnalytics.EGAResourceFlowType.Sink)
				or GameAnalytics.EGAResourceFlowType.Sink,
			eventType = data.eventType,
			itemId = data.itemId,
		})

		return resolve()
	end)
end

--[=[
	Used to log in-game currency changes (example: player spent coins in a shop,
	player purchased coins, player won coins in a mission)

	Example Use:
	```lua
	-- Player purchased 100 coins with Robux
	AnalyticsService:LogResourceEvent({
		userId = player.UserId,
		eventType = "Purchase",
		currency = "Coins",
		itemId = "100 Coins",
		flowType = "Source",
		amount = 100
	})
	```

	@param data ResourceEvent
	@return Promise<T>
]=]
function AnalyticsService:LogResourceEvent(data: ResourceEvent)
	return Promise.new(function(resolve, reject)
		if not self._enabled then
			return reject("AnalyticsService must be configured with :SetOptions()")
		elseif not data.userId then
			return reject("userId is required")
		elseif typeof(data.eventType) ~= "string" then
			return reject("eventType must be a string")
		elseif not data.itemId then
			return reject("itemId is required")
		elseif not data.currency then
			return reject("currency is required")
		elseif not table.find(self._options.currencies, data.currency) then
			return reject("currency type is invalid")
		elseif not GameAnalytics.EGAResourceFlowType[data.flowType] then
			return reject("flow type is invalid")
		elseif typeof(data.amount) ~= "number" then
			return reject("amount is required")
		end

		if not table.find(self._resourceEventTypes, data.eventType) then
			self._resourceEventTypes[#self._resourceEventTypes + 1] = data.eventType
			GameAnalytics.Events:setAvailableResourceItemTypes(self._resourceEventTypes) -- Update the SDK
		end

		self:_wrapper("addResourceEvent", data.userId, {
			-- FlowType is Sink by default
			flowType = data.flowType,
			currency = data.currency,
			amount = data.amount,
			itemType = data.eventType,
			itemId = data.itemId,
		})

		return resolve()
	end)
end

--[=[
	Used to log errors

	Example Use:
	```lua
	local missionName: string = "Invalid Mission Name"

	AnalyticsService:LogError({
		userId = player.UserId,
		message = "Player tried to join a mission that doesn't exist named " .. missionName,
		severity = "Error"
	})
	```

	@param data ErrorEvent
	@return Promise<T>
]=]
function AnalyticsService:LogError(data: ErrorEvent)
	return Promise.new(function(resolve, reject)
		if not self._enabled then
			return reject("AnalyticsService must be configured with :SetOptions()")
		elseif not data.userId then
			return reject("userId is required")
		elseif not data.message then
			return reject("message is required")
		elseif data.severity ~= nil and not GameAnalytics.EGAErrorSeverity[data.severity] then
			return reject("severity is invalid")
		end

		local errorSeverity: string = data.severity or GameAnalytics.EGAErrorSeverity.error

		self:_wrapper("addErrorEvent", data.userId, {
			message = data.message,
			severity = GameAnalytics.EGAErrorSeverity[errorSeverity],
		})

		return resolve()
	end)
end

--[=[
	Used to track player progression (example: player score in a mission or level).

	A progression can have up to 3 levels (example: Mission 1, Location 1, Level 1)

	If a progression has 3 levels, then progression01, progression02, and progression03 are required.

	If a progression has 2 levels, then progression01 and progression02 are required.

	Otherwise, only progression01 is required.

	Example:
	```lua
	AnalyticsService:LogProgression({
		userId = player.UserId,
		status = "Start",
		progression01 = "Mission X",
		progression02 = "Location X",
		score = 100 -- Started with score of 100
	})
	AnalyticsService:LogProgression({
		userId = player.UserId,
		status = "Complete",
		progression01 = "Mission X",
		progression02 = "Location X",
		score = 400 -- Completed the mission with a score of 400
	})
	```

	For more information about progression events, refer to [GameAnalytics docs](https://docs.gameanalytics.com/integrations/sdk/roblox/event-tracking?_highlight=teleportdata#progression) on progression.

	@param data ProgressionEvent
	@return Promise<T>
]=]
function AnalyticsService:LogProgression(data: ProgressionEvent)
	return Promise.new(function(resolve, reject)
		if not self._enabled then
			return reject("AnalyticsService must be configured with AnalyticsService:SetOptions()")
		elseif not data.userId then
			return reject("userId is required")
		elseif not data.status then
			return reject("status is required")
		elseif not GameAnalytics.EGAProgressionStatus[data.status] then
			return reject("status is invalid")
		elseif not data.progression01 then
			return reject("progression01 is required")
		elseif data.progression02 ~= nil and typeof(data.progression02) ~= "string" then
			return reject("progression02 must be a string")
		elseif data.progression03 ~= nil and typeof(data.progression03) ~= "string" then
			return reject("progression03 must be a string")
		elseif data.progression03 ~= nil and not data.progression02 then
			return reject("progression02 is required if progression03 is used")
		elseif data.score ~= nil and typeof(data.score) ~= "number" then
			return reject("score must be a number")
		end

		self:_wrapper("addProgressionEvent", data.userId, {
			progressionStatus = GameAnalytics.EGAProgressionStatus[data.status],
			progression01 = data.progression01,
			progression02 = data.progression02,
			progression03 = data.progression03,
			score = data.score or 0,
		})

		return resolve()
	end)
end

--[=[
	Used to add a delayed event that fires when the player leaves

	Example Use:
	```lua
	AnalyticsService:AddDelayedEvent({
		userId = player.UserId,
		event = "Player:ClaimedReward"
	})
	```

	Example client use:
	```lua
	AnalyticsService.AddDelayedEvent:Fire({
		event = "UIEvent:FTUE:Completed"
	})
	```

	@param data DelayedEvent
	@return nil
]=]
function AnalyticsService:AddDelayedEvent(data: DelayedEvent): nil
	if not self._enabled or not data.userId then
		return
	end

	if not self._events[data.userId] then
		self._events[data.userId] = {}
	end

	if not data.event then
		return
	elseif data.value ~= nil and typeof(data.value) ~= "number" then
		return
	end

	self._events[data.userId][#self._events[data.userId] + 1] = {
		event = data.event,
		value = data.value,
	}

	return
end

--[=[
	Used to add a value to a tracked event

	Example Use:
	```lua
	AnalyticsService:AddTrackedValue({
		userId = player.UserId,
		event = "Player:Kills",
		value = 2 -- Optional, defaults to 1
	})
	```

	Example client use:
	```lua
	AnalyticsService.AddTrackedValue:Fire({
		event = "UIEvent:OpenedShop"
	})
	```

	@param data TrackedValueEvent
	@return nil
]=]
function AnalyticsService:AddTrackedValue(data: TrackedValueEvent): nil
	if not self._enabled or not data.userId or not data.event then
		return
	end

	if data.value ~= nil and typeof(data.value) ~= "number" then
		return
	end

	if not self._trackedEvents[data.userId] then
		self._trackedEvents[data.userId] = {}
	end

	if not data.event then
		return
	elseif data.value ~= nil and typeof(data.value) ~= "number" then
		return
	end

	if not self._trackedEvents[data.userId][data.event] then
		self._trackedEvents[data.userId][data.event] = 0
	end

	self._trackedEvents[data.userId][data.event] += data.value or 1

	return
end

--[=[
	Get the psuedo server player data that's used to communicate with GameAnalytics APIs

	@private
	@within AnalyticsService
	@return ServerPsuedoPlayer
]=]
function AnalyticsService:_getServerPsuedoPlayer(): ServerPsuedoPlayer
	return {
		id = "DummyId",
		PlayerData = {
			OS = "uwp_desktop 0.0.0",
			Platform = "uwp_desktop",
			SessionID = HttpService:GenerateGUID(false):lower(),
			Sessions = 1,
			CustomUserId = "Server",
		},
	}
end

--[=[
	Get the value of a remote configuration or A/B test given context ( player.UserId )

	Example Use:
	```lua
	local remoteValue = AnalyticsService:GetRemoteConfig({
		player = player,
		name = "Test",
		defaultValue = "Default"
	}):await()
	```

	```lua
	AnalyticsService:GetRemoteConfig({
		player = player,
		name = "Test",
		defaultValue = "Default"
	})
		:andThen(
		function(remoteValue)
			print(remoteValue)
		end)
		:catch(function(err)
			warn(err)
		end)
	```

	@within AnalyticsService
	@param remote RemoteConfig -- The name, default value, and context of the remote configuration
	@return Promise<T>
]=]
function AnalyticsService:GetRemoteConfig(remote: RemoteConfig)
	return Promise.new(function(resolve, reject)
		if not remote then
			return reject("AnalyticsService.GetRemoteConfig - remote is required")
		elseif not remote.name then
			return reject("AnalyticsService.GetRemoteConfig - remote.name is required")
		elseif not remote.defaultValue then
			return reject("AnalyticsService.GetRemoteConfig - remote.defaultValue is required")
		end

		if not self._enabled then
			return resolve(remote.defaultValue)
		end

		local player: Player? = remote.player
		local context: ServerPsuedoPlayer = self:_getServerPsuedoPlayer()
		local server = if player == nil
			then -- Using Luau conditional expression so type can be inferred https://luau-lang.org/syntax#if-then-else-expressions
				GameAnalytics.HttpApi:initRequest(
					self._options.gameKey,
					self._options.secretKey,
					self._options.build,
					context.PlayerData,
					""
				)
			else nil

		if server and server.statusCode >= 9 then
			for _, config in (server.body.configs or {}) do
				if config.key == remote.name then
					return resolve(config.value)
				end
			end
		end

		if player and not GameAnalytics:isRemoteConfigsReady(player.UserId) then
			return resolve(remote.defaultValue)
		end

		return resolve(player and GameAnalytics:getRemoteConfigsValueAsString(player.UserId, {
			key = remote.name,
			defaultValue = remote.defaultValue,
		}) or remote.defaultValue)
	end)
end

-- GameAnalytics method aliases for custom dimensions
local dimensionSetter: { [string]: string } = {
	dimension01 = "setCustomDimension01",
	dimension02 = "setCustomDimension02",
	dimension03 = "setCustomDimension03",
}

--[=[
	Used to set a custom dimension for a player

	Example Use:
	```lua
	AnalyticsService:SetCustomDimension({
		userId = player.UserId,
		dimension = "dimension01",
		value = "value"
	})
	```

	To remove a custom dimension from a player, set the value to "".

	For more information about dimensions, refer to [GameAnalytics docs](https://docs.gameanalytics.com/integrations/sdk/roblox/sdk-features?_highlight=dimension#custom-dimensions) on dimensions.

	@param data DimensionData
	@return Promise<T>
]=]
function AnalyticsService:SetCustomDimension(data: DimensionData)
	return Promise.new(function(resolve, reject)
		if not self._enabled then
			return reject("AnalyticsService must be configured with :SetOptions()")
		elseif not data then
			return reject("AnalyticsService.SetCustomDimension - data is required")
		elseif not data.userId then
			return reject("AnalyticsService.SetCustomDimension - userId is required")
		elseif not data.dimension then
			return reject("AnalyticsService.SetCustomDimension - dimension is required")
		elseif not self._options.customDimensions[data.dimension] then
			return reject(
				"AnalyticsService.SetCustomDimension - dimension is invalid, please define it in customDimensions during AnalyticsService:SetOptions()"
			)
		elseif not table.find(self._options.customDimensions[data.dimension], data.value) then
			return reject(
				"AnalyticsService.SetCustomDimension - dimension value is invalid, please define it as a value in customDimensions during AnalyticsService:SetOptions()"
			)
		end

		local setter: string? = dimensionSetter[data.dimension]

		if not setter then
			return reject("AnalyticsService.SetCustomDimension - dimension is invalid")
		end

		self:_wrapper(setter, data.userId, data.value)

		return resolve()
	end)
end

return AnalyticsService