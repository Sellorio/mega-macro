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

local function ParseResult(parsingContext, length, colour)
    if length == 0 then return "" end

    local text = string.sub(parsingContext.Code,
                            parsingContext.Index,
                            parsingContext.Index + length - 1)
    parsingContext.Index = parsingContext.Index + length

    -- 11.2: colour may be a Color object (from HexToColor) or a raw hex string.
    if type(colour) == "table" and colour.GetRGB then
        -- Convert the Color object back to a hex string for legacy text output.
        local r,g,b = colour:GetRGB()
        colour = string.format("%02x%02x%02x", r*255, g*255, b*255)
    end

    if parsingContext.Index > (MegaMacroCodeMaxLengthForNative + 1) then
        local overflow = parsingContext.Index - (MegaMacroCodeMaxLengthForNative + 1)
        local valid   = text:sub(1, #text - overflow)
        local excess  = text:sub(#valid + 1)
        return valid .. "|c"..GetMegaMacroParsingColourData().Error..excess.."|r"
    else
        return colour and "|c"..colour..text.."|r" or text
    end
end

function GetMegaMacroParsingFunctions()
    return GetCharacter, GetWord, ParseResult
end
