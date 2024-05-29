--[[
    Author(s):
        Alex/EnDarke
    Description:
        Handles playing sound effects in-game.
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Packages
local Packages = ReplicatedStorage.Packages
local Knit = require( Packages.Knit )
local Dumpster = require( Packages.Dumpster )
local Sequence = require( Packages.Sequence )

-- Modules
local Shared = ReplicatedStorage.Shared
local Util = require( Shared.Util ) :: {}

-- Types
type void = nil

-- Replicated Data
local ReplicatedData = require( Shared.ReplicatedData )
local SoundEffectData: {} = ReplicatedData["SoundEffects"]

-- Globals
local newTweenInfo = TweenInfo.new

-- Player
local Player: Player = Knit.Player

-- Initializing Knit
local SoundController = Knit.CreateController {
    Name = "SoundController"
}

-- Knit Client
function SoundController:PlaySFX(name: string, settings): Sound | nil
    if not name then return end

    -- Local Variables
    local soundData = SoundEffectData[name]
    if not soundData then return end

    -- Settings
    settings = settings or {}
    local soundId: number = soundData.SoundId
    local volume: number = settings.Volume or soundData.Volume
    local octave: number = settings.Octave or soundData.Octave or nil
    local looped: boolean = settings.Looped or false
    local position: Vector3 = settings.Position or nil

    -- Finding Sound Effect
    local soundPooled: Sound = self._soundFolder:FindFirstChild(name)
    if not soundPooled then
        soundPooled = self._dumpster:Construct("Sound") :: Sound
        if not soundPooled then return end

        soundPooled.Name = name
        soundPooled.Parent = self._soundFolder

        if octave then
            local pitchShift: PitchShiftSoundEffect = self._dumpster:Construct("PitchShiftSoundEffect")
            pitchShift.Octave = octave
            pitchShift.Parent = soundPooled
        end
    end

    -- Setting up Sound Effect
    soundPooled.SoundId = `rbxassetid://{soundId}`
    soundPooled.Volume = volume
    soundPooled.Looped = looped

    if ( position ) then
        local attachment: Attachment = self._dumpster:Construct("Attachment")
        attachment.Position = position
        attachment.Parent = workspace.Terrain

        soundPooled.Parent = attachment
    end

    -- Add to playing sequence
    self._playSequence:Includes(soundPooled)

    return soundPooled
end

function SoundController:PlayAdvancedSFX(name: string, settings): ()
    if not ( name and settings ) then return end

    -- Find sound
    local sound: Sound = self:PlaySFX(name, settings)
    if not sound then return end

    -- Local Variables
    local fadeTime: number = settings.FadeTime or 3
    local duration: number = sound.TimeLength - sound.TimePosition
    local timeTillFade: number = duration - fadeTime

    -- Fade sound effect
    task.delay(timeTillFade, function()
        local fadeTween: Tween = TweenService:Create(
            sound,
            newTweenInfo(fadeTime, Enum.EasingStyle.Linear),
            { Volume = 0 }
        ):Play()

        -- Wait for completion or timeout
        local signal = Util.WaitForEvent(duration, fadeTween.Completed)
        signal:Wait()
        signal:Destroy()

        -- Cleanup
        self:StopSFX(sound)
        fadeTween:Destroy()
    end)
end

function SoundController:StopSFX(sfx: Sound): ()
    if not ( sfx ) then return end
    self._stopSequence:Includes(sfx)
end

-- Knit Startup
function SoundController:KnitInit(): ()
    -- Knit Services
    self._soundService = Knit.GetService("SoundService")

    -- Objects & Info
    self._dumpster = Dumpster.new()

    self._soundFolder = self._dumpster:Construct("SoundGroup")
    self._soundFolder.Name = "Sounds"
    self._soundFolder.Parent = Player
end

function SoundController:KnitStart(): ()
    -- Sequences
    self._playSequence = Sequence.new({ Autotick = true }, function(soundEffects)
        for _, sound: Sound in ipairs( soundEffects ) do
            if not ( sound:IsA("Sound") ) then continue end
            sound:Play()
        end
    end)

    self._stopSequence = Sequence.new({}, function(soundEffects)
        for _, sound: Sound in ipairs( soundEffects ) do
            if not ( sound:IsA("Sound") ) then continue end

            -- Local Variables
            local soundParent: Instance? = sound.Parent

            -- Cleanup
            sound:Stop()
            sound:Destroy()

            -- Positioned based audio only
            if ( soundParent and soundParent:IsA("Attachment") ) then
                soundParent:Destroy()
            end
        end
    end)

    -- Listeners
    self._soundService.PlaySFX:Connect(function(...): ()
        self:PlaySFX(...)
    end)

    self._soundService.PlayAdvancedSFX:Connect(function(...): ()
        self:PlayAdvancedSFX(...)
    end)
end

return SoundController