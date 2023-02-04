local function GetCharacter(parsingContext, offset)
    local index = parsingContext.Index + (offset or 0)
    local result = string.utf8sub(parsingContext.Code, index, index)
    -- string.utf8sub returns inpput itself if index is out of bounds
    -- string.utf8sub("Foo", 4, 4) -> "Foo"
    if result == parsingContext.Code then
        return nil
    end
    return #result > 0 and result or nil
end

local function GetWord(parsingContext, offset)
    local index = parsingContext.Index + (offset or 0)
    local text = ""
    local character = GetCharacter({ Code = parsingContext.Code, Index = index })
    while character and (string.match(character, "[a-zA-Z0-9_äöüÄÖÜß]")) do
        text = text .. character
        index = index + 1
        character = GetCharacter({ Code = parsingContext.Code, Index = index })
    end
    return text
end

local function ParseResult(parsingContext, length, colour)
    if length == 0 then
        return ""
    end
    local text = string.utf8sub(parsingContext.Code, parsingContext.Index, parsingContext.Index + length - 1)
    parsingContext.Index = parsingContext.Index + length
    return colour and "|c" .. colour .. text .. "|r" or text
end

function GetMegaMacroParsingFunctions()
    return GetCharacter, GetWord, ParseResult
end
