--[[
    Author(s):
        Alex/EnDarke
    Description:
        Handles number suffixing.
]]

--\\ Variables //--
local abs = math.abs
local floor = math.floor
local round = math.round

local textSuffixes = {
    "k", "M", "B", "T", "qd", "Qn", "sx", "Sp", "O", "N", "de", "Ud", "DD",
	"tdD", "qdD", "QnD", "sxD", "SpD", "OcD", "NvD", "Vgn", "UVg", "DVg",
	"TVg", "qtV", "QnV", "SeV", "SPG", "OVG", "NVG", "TGN", "UTG", "DTG",
	"tsTG", "qtTG", "QnTG", "ssTG", "SpTG", "OcTG", "NoTG", "QdDR", "uQDR",
	"dQDR", "tQDR", "qdQDR", "QnQDR", "sxQDR", "SpQDR", "OQDDr", "NQDDr",
	"qQGNT", "uQGNT", "dQGNT", "tQGNT", "qdQGNT", "QnQGNT", "sxQGNT",
	"SpQGNT", "OQQGNT", "NQQGNT", "SXGNTL",
}

--\\ Module Code //--
local Suffix = {}

function Suffix.Shorten(input: number): string
    local negative: boolean = input < 0
    local paired: boolean = false
    input = round(input)
    input = abs(input)

    for i, _ in ipairs(textSuffixes) do
        if not (input >= 10 ^ (3 * i)) then
            input = input / 10 ^ (3 * (i - 1))

            local isComplex = (string.find(tostring(input), ".") and string.sub(tostring(input), 4, 4) ~= ".")

            input = string.sub(tostring(input), 1, (isComplex and 4) or 3)..(textSuffixes[i - 1] or "")
            paired = true

            break
        end
    end

    local inputString: string = tostring(input)

    if not paired then
        local rounded: number = floor(input)
        inputString = tostring(rounded)
    end

    if negative then
        return string.format("-%s", inputString)
    end

    return inputString :: string
end

function Suffix.AddCommas(input: number): string
    input = round(input)

    local inputString: string = tostring(input)

    for i = 1, string.len(inputString), 1 do
        inputString, i = string.gsub(inputString, "^(-?%d+)(%d%d%d)", '%1,%2')
        if i < 1 then
            break
        end
    end

    return inputString :: string
end

function Suffix.AffixedSuffix(input: number): string | nil
    if not input then return end

    local inputString: string = nil

    if input > 999999 then
        inputString = Suffix.Shorten(input)
    else
        inputString = Suffix.AddCommas(input)
    end

    return inputString :: string | nil
end

return Suffix