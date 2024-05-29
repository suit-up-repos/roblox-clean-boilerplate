--[[
    Author(s):
        Alex/EnDarke
    Description:
        Handles player teleporting on the server.
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Packages = ReplicatedStorage.Packages
local Knit = require( Packages.Knit )

-- Types
type void = nil

-- Objects
local random = Random.new()

-- Initializing Knit
local TeleportSystem = Knit.CreateService({
    Name = "TeleportSystem",
    Client = {},
})

-- Public Methods
function TeleportSystem:AttemptTeleport(player: Player, location: Part | Vector3 | CFrame, offset: Vector3): any
    if not ( player and location ) then return end

    -- Local Variables
    local character = player.Character or player.CharacterAdded:Wait()
    local rootPart: Part = if character then character.HumanoidRootPart else nil
    if not rootPart then return end

    -- Ensure location is a CFrame
    if typeof(location) == "Vector3" then
        location = CFrame.new(location)
    elseif typeof(location) == "Instance" then
        if location:IsA("Part") then
            location = location:GetPivot() :: CFrame
        end
    end

    -- Make sure the location remains a CFrame!
    if typeof(location) ~= "CFrame" then return end

    -- Apply offset
    if offset then
        location += offset
    end

    -- Waiting period in case player just spawned in
    task.wait()

    -- Attempt to teleport player
    local status = xpcall(function(): ()
        rootPart:PivotTo(location)
    end, function(errorMessage): ()
        warn(errorMessage)
    end)

    return status
end

function TeleportSystem:TeleportInRegion(player: Player, location: Part): ()
    if not ( player and location ) then return end

    -- Get region sizing
    local regionSize: Vector3 = location.Size
    local halfRegionX: number = regionSize.X / 2
    local halfRegionZ: number = regionSize.Z / 2

    -- Create teleport offset
    local randomX: number = random:NextNumber(-halfRegionX, halfRegionX)
    local randomZ: number = random:NextNumber(-halfRegionZ, halfRegionZ)
    local offset: Vector3 = Vector3.new(randomX, 0, randomZ)

    -- Teleport the player
    self:AttemptTeleport(player, location, offset)
end

-- Startup
function TeleportSystem:KnitInit(): ()
end

function TeleportSystem:KnitStart(): ()
end

return TeleportSystem