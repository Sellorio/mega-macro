local CodeInfoCache = {}
--[[
{
    "macroid": {
        {
            type: "cast",               cast/stopmacro/use/castsequence/showtooltip
            body: "[mod:alt] X; Y"
        },
        ...
    }
}
--]]

local function trim(s)
    return s:gsub("^%s*(.-)%s*$", "%1")
end

local function Char(string, index)
    return string.sub(string, index, index)
end

local function ParseSpaces(parsingContext)
    local result = false

    while Char(parsingContext.Code, parsingContext.Index) == " " do
        result = true
        parsingContext.Index = parsingContext.Index + 1
    end

    return result
end

local function ParseEndOfLine(parsingContext)
    local result = false

    while Char(parsingContext.Code, parsingContext.Index) == "\n" do
        result = true
        parsingContext.Index = parsingContext.Index + 1
        ParseSpaces(parsingContext)
    end

    return result
end

local function ParseWord(parsingContext)
    local result = false
    local word = ""

    local character = Char(parsingContext.Code, parsingContext.Index)
    while string.match(character, "[a-z]") or string.match(character, "[A-Z]") or string.match(character, "[0-9]") or character == "_" do
        word = word .. character
        result = true
        parsingContext.Index = parsingContext.Index + 1
        character = Char(parsingContext.Code, parsingContext.Index)
    end
    
    return result, word
end

local function GrabRemainingLineCode(parsingContext)
    local code = ""
    local character = Char(parsingContext.Code, parsingContext.Index)
    local appendToCode = true -- ignore comments trailing lines of code

    while character ~= nil and character ~= "\n" do
        if character == "#" then
            appendToCode = false
        end

        if appendToCode then
            code = code .. character
        end

        parsingContext.Index = parsingContext.Index + 1
        character = Char(parsingContext.Code, parsingContext.Index)
    end

    return code
end

local function ParseCastCommand(parsingContext)
    -- todo
end

local function ParseCastsequenceCommand(parsingContext)
    -- todo
end

local function ParseStopmacroCommand(parsingContext)
    -- todo
end

local function ParseCommand(parsingContext)
    local result = false

    if Char(parsingContext.Code, parsingContext.Index) == "/" then
        parsingContext.Index = parsingContext.Index + 1
        local wordResult, word = ParseWord(parsingContext)

        if wordResult then
            word = string.lower(word)
            result = true
            ParseSpaces(parsingContext)

            if word == "cast" or word == "use" then
                ParseCastCommand(parsingContext)
            elseif word == "castsequence" then
                ParseCastsequenceCommand(parsingContext)
            elseif word == "stopmacro" then
                ParseStopmacroCommand(parsingContext)
            end
        end
        
        GrabRemainingLineCode(parsingContext)
        ParseEndOfLine(parsingContext)
    end

    return result
end

local function ParseShowtooltip(parsingContext)
    if Char(parsingContext.Code, parsingContext.Index) == "#" then
        parsingContext.Index = parsingContext.Index + 1
        local wordResult, word = ParseWord(parsingContext)

        if wordResult and string.lower(word) == "showtooltip" then
            table.insert(
                CodeInfoCache[parsingContext.MacroId],
                {
                    Type = "showtooltip",
                    Body = trim(GrabRemainingLineCode(parsingContext))
                })

            return true
        end
    end

    return false
end

local function CalculateMacroInfo(macro)
    local parsingContext = { MacroId = macro.Id, Index = 1, Code = macro.Code }
    CodeInfoCache[macro.Id] = {}

    -- skip to start of code
    ParseSpaces(parsingContext)
    ParseEndOfLine(parsingContext)

    if parsingContext.Index < string.len(parsingContext.Code) then
        if not ParseShowtooltip(parsingContext) then
            while ParseCommand(parsingContext) do
            end
        end
    end

    return CodeInfoCache[macro.Id]
end

MegaMacroCodeInfo = {}

function MegaMacroCodeInfo.Get(macro)
    return CodeInfoCache[macro.Id] or CalculateMacroInfo(macro)
end

function MegaMacroCodeInfo.Clear(macroId)
    
    CodeInfoCache[macroId] = nil
end

function MegaMacroCodeInfo.ClearAll()
    CodeInfoCache = {}
end