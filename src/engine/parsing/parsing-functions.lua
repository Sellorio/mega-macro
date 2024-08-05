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
    if length == 0 then
        return ""
    end
    local text = string.sub(parsingContext.Code, parsingContext.Index, parsingContext.Index + length - 1)
    parsingContext.Index = parsingContext.Index + length

    if parsingContext.Index > (MegaMacroCodeMaxLengthForNative + 1) then
        local validText = #text - (parsingContext.Index - (MegaMacroCodeMaxLengthForNative + 1)) >= 1 and text:sub(1, #text - (parsingContext.Index - (MegaMacroCodeMaxLengthForNative + 1))) or ""
        local overflowText = #validText > 0 and text:sub(#text - (parsingContext.Index - (MegaMacroCodeMaxLengthForNative + 2))) or text
        return validText .. "|c"..GetMegaMacroParsingColourData().Error..overflowText.."|r"
    else
        return colour and "|c"..colour..text.."|r" or text
    end
end

function GetMegaMacroParsingFunctions()
    return GetCharacter, GetWord, ParseResult
end
