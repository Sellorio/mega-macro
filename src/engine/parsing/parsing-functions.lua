local function GetCharacter(parsingContext, offset)
    local index = parsingContext.Index + (offset or 0)
    local result = string.sub(parsingContext.Code, index, index)
    return #result > 0 and result or nil
end

local function GetWord(parsingContext, offset)
    local index = parsingContext.Index + (offset or 0)
    local text = ""
    local character = GetCharacter({ Code = parsingContext.Code, Index = index })
    while character and (string.match(character, "[a-z]") or string.match(character, "[A-Z]") or string.match(character, "[0-9]") or character == "_") do
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
    return colour and "|c"..colour..text.."|r" or text
end

function GetMegaMacroParsingFunctions()
    return GetCharacter, GetWord, ParseResult
end
