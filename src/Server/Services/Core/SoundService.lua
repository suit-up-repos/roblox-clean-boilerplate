--[[
    Author(s):
        Alex/EnDarke
    Description:
        Handles sending sound effect play requests through the network from server to client.
]]

-- Declaring Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Declaring Packages
local Packages = ReplicatedStorage.Packages
local Knit = require( Packages.Knit )

-- Knit
local SoundService = Knit.CreateService {
    Name = "SoundService",
    Client = {
        PlaySFX = Knit.CreateSignal(),
        PlayAdvancedSFX = Knit.CreateSignal(),
    },
}

function SoundService:PlaySFX(player: Player, name: string, settings: {})
    if not ( player and name) then return end

    -- Play SFX
    self.Client.PlaySFX:Fire(player, name, settings)
end

function SoundService:PlayAdvancedSFX(player: Player, name: string, settings: {})
    if not ( player and name ) then return end

    -- Play SFX
    self.Client.PlayAdvancedSFX:Fire(player, name, settings)
end

-- Knit Startup
function SoundService:KnitInit()
end

function SoundService:KnitStart()
end

return SoundService