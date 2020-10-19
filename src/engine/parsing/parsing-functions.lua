local function HandleFormattingAndLinks(text, defaultColour)
    local openCode = defaultColour and "|c"..defaultColour or ""
    local closeCode = defaultColour and "|r" or ""
    local result = openCode
    local isInLink = false

    local i = 1
    while i <= #text do
        -- local tag = string.sub(text, i, i + 2)
        -- if tag == '|rc' then
        --     print("In colour")
        --     result = result..closeCode..tag
        --     i = i + 2
        -- elseif tag == "|rH" then
        --     print("In link")
        --     result = result..tag
        --     isInLink = true
        --     i = i + 2
        -- elseif tag == "|rr" and isInLink then
        --     print("Out link")
        --     result = result..tag..openCode
        --     isInLink = false
        --     i = i + 2
        -- elseif string.sub(tag, 1, 2) == "|r" and not isInLink then
        --     print("Out colour")
        --     result = result.."|r"..openCode
        -- else
            result = result..string.sub(text, i, i)
        -- end

        i = i + 1
    end

    return closeCode..result
end

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
    local text = HandleFormattingAndLinks(string.sub(parsingContext.Code, parsingContext.Index, parsingContext.Index + length - 1), colour)
    parsingContext.Index = parsingContext.Index + length
    return text
end

function GetMegaMacroParsingFunctions()
    return GetCharacter, GetWord, ParseResult
end
