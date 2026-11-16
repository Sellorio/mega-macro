local function GetCharacter(parsingContext, offset)
    local index = parsingContext.Index + (offset or 0)
    local result = string.sub(parsingContext.Code, index, index)
    return #result > 0 and result or nil
end

local function GetWord(parsingContext, offset)
    local index = parsingContext.Index + (offset or 0)
    local text = ""
    local character = GetCharacter({ Code = parsingContext.Code, Index = index })
    while character and (string.match(character, "[a-z]") or string.match(character, "[A-Z]") or string.match(character, "[0-9]") or character == "_" or character == "/") do
        text = text..character
        index = index + 1
        character = GetCharacter({ Code = parsingContext.Code, Index = index })
    end
    return text
end

local ErrorColour = "ffff4444"
local DefaultColour = "ffffffff"
local DimmedColours = {}

-- Faded version of a colour, for parts of the macro that wouldn't run right now
local function Dimmed(colour)
    local dimmed = DimmedColours[colour]
    if not dimmed then
        local hex = string.sub(colour, -6)
        local function Fade(part)
            return math.floor(tonumber(string.sub(hex, part, part + 1), 16) * 0.35 + 45)
        end
        dimmed = string.format("ff%02x%02x%02x", Fade(1), Fade(3), Fade(5))
        DimmedColours[colour] = dimmed
    end
    return dimmed
end

-- Colour of one character, taking the length limit and fading into account
local function ColourAt(parsingContext, index, colour)
    if index > MegaMacroCodeMaxLengthForNative then
        colour = ErrorColour
    end
    if parsingContext.Dim and parsingContext.Dim[index] then
        colour = Dimmed(colour or DefaultColour)
    end
    return colour
end

local function ParseResult(parsingContext, length, colour)
    if length == 0 then return "" end

    local start = parsingContext.Index
    local text = string.sub(parsingContext.Code, start, start + length - 1)
    parsingContext.Index = start + length

    -- 11.2: colour may be a Color object (from HexToColor) or a raw hex string.
    if type(colour) == "table" and colour.GetRGB then
        local r,g,b = colour:GetRGB()
        colour = string.format("ff%02x%02x%02x", r*255, g*255, b*255)
    end

    -- Split into runs of the same colour
    local result = ""
    local runStart = 1
    local runColour = ColourAt(parsingContext, start, colour)

    for i = 2, #text + 1 do
        local charColour = i <= #text and ColourAt(parsingContext, start + i - 1, colour) or nil
        if i > #text or charColour ~= runColour then
            local run = string.sub(text, runStart, i - 1)
            result = result..(runColour and "|c"..runColour..run.."|r" or run)
            runStart = i
            runColour = charColour
        end
    end

    return result
end

function GetMegaMacroParsingFunctions()
    return GetCharacter, GetWord, ParseResult
end
